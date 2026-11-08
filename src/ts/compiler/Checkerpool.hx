package ts.compiler;

// Port of checkerpool.go (types and methods; newCheckerPool, newCheckerPoolWithTracing and noop are in Compiler.hx).
// PORT: single-threaded port (PORTING.md §4): the mutexes are kept as opaque values and never locked;
// the release functions are no-ops. The number of checkers and the file→checker assignment are
// those of Go (in the single-threaded mode used by the test harness there is exactly one checker).

// CheckerPool is implemented by the project system to provide checkers with
// request-scoped lifetime and reclamation. It returns a checker and a release
// function that must be called when the caller is done with the checker.
// The returned checker must not be accessed concurrently; each acquisition is exclusive.
// If file is non-nil, the pool may use it as an affinity hint to return the same
// checker for the same file across calls.
interface CheckerPool {
	// PORT: (*checker.Checker, func()) → Pair
	function GetChecker(ctx:Context, file:SourceFile):Pair<Checker, () -> Void>;
}

// Go type checkerPool (the exported name CheckerPool is the interface).
@:allow(ts.compiler)
class CheckerPool_ implements CheckerPool {
	var program:Program = null;
	var tracing:Tracing = null;

	var createCheckersOnce:Bool = false; // PORT: sync.Once → flag
	var checkers:Array<Checker> = null;
	var locks:Array<Any> = null; // PORT: []*sync.Mutex → the checkers' mutexes (sys.thread.Mutex with -D tshx-parallel, else null and never locked)
	var fileAssociations:IdentityMap<SourceFile, Checker> = null;

	public function new() {}

	// GetChecker implements CheckerPool. When file is non-nil, returns the checker
	// associated with that file; otherwise returns the first checker.
	public function GetChecker(ctx:Context, file:SourceFile):Pair<Checker, () -> Void> {
		if (file != null) {
			return this.getCheckerForFileExclusive(ctx, file);
		}
		this.createCheckers();
		final c = this.checkers[0];
		// p.locks[0].Lock(); release: sync.OnceFunc(unlock)
		#if tshx_parallel
		return new Pair<Checker, () -> Void>(c, this.lock(0));
		#else
		return new Pair<Checker, () -> Void>(c, Compiler.noop);
		#end
	}

	// getCheckerForFileNonExclusive returns the checker for the given file without locking.
	// This is only safe when the caller guarantees no concurrent access to the same checker,
	// e.g. for read-only operations like obtaining an emit resolver.
	function getCheckerForFileNonExclusive(file:SourceFile):Pair<Checker, () -> Void> {
		this.createCheckers();
		return new Pair<Checker, () -> Void>(this.fileAssociations.get(file), Compiler.noop);
	}

	function getCheckerForFileExclusive(ctx:Context, file:SourceFile):Pair<Checker, () -> Void> {
		this.createCheckers();
		final c = this.fileAssociations.get(file);
		// idx := slices.Index(p.checkers, c); p.locks[idx].Lock()
		#if tshx_parallel
		return new Pair<Checker, () -> Void>(c, this.lock(this.checkers.indexOf(c)));
		#else
		return new Pair<Checker, () -> Void>(c, Compiler.noop);
		#end
	}

	#if tshx_parallel
	// PORT: hxmc (-D tshx-parallel) — p.locks[idx].Lock(), and its release as sync.OnceFunc(Unlock)
	function lock(idx:Int):() -> Void {
		final m:sys.thread.Mutex = cast this.locks[idx];
		m.acquire();
		var released = false;
		return function() {
			if (!released) {
				released = true;
				m.release();
			}
		};
	}
	#end

	// getCheckerNonExclusive returns the first checker without locking.
	function getCheckerNonExclusive():Pair<Checker, () -> Void> {
		this.createCheckers();
		return new Pair<Checker, () -> Void>(this.checkers[0], Compiler.noop);
	}

	function createCheckers():Void {
		if (this.createCheckersOnce)
			return;
		this.createCheckersOnce = true;
		final checkerCount = this.checkers.length;
		#if tshx_parallel
		// PORT: hxmc (-D tshx-parallel) — the checkers are created on threads, as in Go
		final wg:WorkGroup = this.program.SingleThreaded() ? Core.NewWorkGroup(true) : new ParallelWorkGroup();
		#else
		final wg = Core.NewWorkGroup(this.program.SingleThreaded());
		#end
		for (i in 0...checkerCount) {
			wg.Queue(function() {
				var tracer:ts.checker.Tracer = null;
				if (this.tracing != null) {
					tracer = Checker.NewTracer(this.tracing, i);
				}
				final r = Checker.NewChecker(this.program, tracer);
				this.checkers[i] = r.a;
				this.locks[i] = r.b;
			});
		}

		wg.RunAndWait();

		this.fileAssociations = new IdentityMap();
		final files = this.program.processedFiles.files;
		// PORT: perf — TypeScript 7.1's assignment of files to checkers by balanced import affinity
		// (microsoft/typescript-go#4313) in place of i % checkerCount: which checker checks a file, not what
		// is checked (output identical at any checker count, gated)
		final associations = [for (_ in 0...files.length) 0];
		if (checkerCount > 1) {
			final baseWeights = [for (_ in 0...files.length) 0];
			final importCounts = [for (_ in 0...files.length) 0];
			final isDeclarationFile = [for (_ in 0...files.length) false];
			var totalBaseWeight = 0;
			var declarationBaseWeight = 0;
			for (i in 0...files.length) {
				final file = files[i];
				final baseWeight = CheckerAssociation.baseWeight(file.NodeCount, go.Utf8.ByteLen(file.Text()));
				totalBaseWeight += baseWeight;
				if (file.IsDeclarationFile)
					declarationBaseWeight += baseWeight;
				baseWeights[i] = baseWeight;
				importCounts[i] = Core.len(file.Imports());
				isDeclarationFile[i] = file.IsDeclarationFile;
			}
			final policy = CheckerAssociation.policy(totalBaseWeight, declarationBaseWeight, checkerCount);
			if (policy.prioritizeSourceFiles && !CheckerAssociation.shouldPrioritizeSourceFiles(totalBaseWeight, declarationBaseWeight, checkerCount)) {
				// PORT: perf — our prioritized-source deviation (see CheckerAssociation.policy) places the source files
				// first, largest first. When one source file outweighs half of an average checker's share of the source
				// weight, that file and the files drawn to it by affinity fill a checker that has little to check
				// (mui-docs: mui-icons-material/lib/index.mjs re-exports ~2000 icon modules, weight 610k from its import
				// fanout; that checker took 60 ms of 3.5 s): use Go's choice (strong balance) there.
				final w = CheckerAssociation.weights(baseWeights, importCounts);
				var sourceWeight = 0, maxSourceWeight = 0;
				for (i in 0...files.length)
					if (!isDeclarationFile[i]) {
						sourceWeight += w[i];
						if (w[i] > maxSourceWeight)
							maxSourceWeight = w[i];
					}
				if (maxSourceWeight * 2 * checkerCount > sourceWeight) {
					policy.prioritizeSourceFiles = false;
					policy.sourceFileWeightMultiplier = CheckerAssociation.SourceFileWeightMultiplier;
					policy.balancePenaltyMultiplier = CheckerAssociation.BalancePenaltyMultiplier;
				}
			}
			// PORT: debug knob, not in Go. TSHX_POLICY=p,m,b overrides the policy (p: 1 = prioritize source files,
			// m: source file weight multiplier, b: balance penalty multiplier); TSHX_POLICY=show prints the chosen one.
			final policyEnv = Sys.getEnv("TSHX_POLICY");
			if (policyEnv == "show")
				Sys.stderr().writeString('checker association policy: ${policy.prioritizeSourceFiles ? 1 : 0},${policy.sourceFileWeightMultiplier},${policy.balancePenaltyMultiplier} (checkers $checkerCount, declaration weight $declarationBaseWeight of $totalBaseWeight)\n');
			else if (policyEnv != null) {
				final a = policyEnv.split(",");
				policy.prioritizeSourceFiles = a[0] == "1";
				policy.sourceFileWeightMultiplier = Std.parseInt(a[1]);
				policy.balancePenaltyMultiplier = Std.parseInt(a[2]);
			}
			if (policy.sourceFileWeightMultiplier != 1) {
				// Apply this before import normalization. The policy intentionally
				// increases both source-file work and the normalized import unit.
				for (i in 0...files.length)
					if (!isDeclarationFile[i])
						baseWeights[i] *= policy.sourceFileWeightMultiplier;
			}
			final fileWeights = CheckerAssociation.weights(baseWeights, importCounts);
			final adjacentFiles = this.getImportAdjacency(files);
			final fileOrder = CheckerAssociation.order(fileWeights, isDeclarationFile, policy.prioritizeSourceFiles);
			final a = CheckerAssociation.associationsInOrder(fileWeights, adjacentFiles, fileOrder, checkerCount, policy.balancePenaltyMultiplier);
			for (i in 0...files.length)
				associations[i] = a[i];
		}
		for (i in 0...files.length) {
			this.fileAssociations.set(files[i], this.checkers[associations[i]]);
		}
	}

	// groupFilesByChecker returns, per checker, the indices of the given files associated with it (TypeScript main's
	// #64922: emit transforms the files of each checker in one task).
	function groupFilesByChecker(files:Array<SourceFile>):Array<Array<Int>> {
		this.createCheckers();
		final groups:Array<Array<Int>> = [for (_ in 0...this.checkers.length) null];
		for (i in 0...files.length) {
			final idx = this.checkers.indexOf(this.fileAssociations.get(files[i]));
			if (groups[idx] == null)
				groups[idx] = [];
			groups[idx].push(i);
		}
		return groups;
	}

	// getImportAdjacency returns an undirected import graph represented by file
	// index. A directed import from A to B makes both files adjacent because either
	// file can benefit from sharing checker caches with the other.
	function getImportAdjacency(files:Array<SourceFile>):Array<Array<Int>> {
		final fileIndices = new IdentityMap<SourceFile, Int>();
		for (i in 0...files.length)
			fileIndices.set(files[i], i);
		final adjacentFiles:Array<Array<Int>> = [for (_ in 0...files.length) []];
		for (fileIndex in 0...files.length) {
			final file = files[fileIndex];
			final resolvedModules = @:privateAccess this.program.resolvedModules.get(file.Path());
			if (resolvedModules == null)
				continue;
			for (resolved in resolvedModules) {
				if (resolved == null || !resolved.IsResolved())
					continue;
				final importedFile = this.program.GetSourceFileForResolvedModule(resolved.ResolvedFileName);
				final importedIndex = importedFile == null ? null : fileIndices.get(importedFile);
				if (importedIndex == null || importedIndex == fileIndex)
					continue;
				adjacentFiles[fileIndex].push(importedIndex);
				adjacentFiles[importedIndex].push(fileIndex);
			}
		}
		return adjacentFiles;
	}

	// Runs `cb` for each checker in the pool concurrently, locking and unlocking checker mutexes as it goes,
	// making it safe to call `forEachCheckerParallel` from many threads simultaneously.
	function forEachCheckerParallel(cb:(idx:Int, c:Checker) -> Void):Void {
		this.createCheckers();
		final wg = Core.NewWorkGroup(this.program.SingleThreaded());
		for (idx in 0...this.checkers.length) {
			final checker = this.checkers[idx];
			wg.Queue(function() {
				#if tshx_parallel
				final release = this.lock(idx);
				cb(idx, checker);
				release();
				#else
				cb(idx, checker);
				#end
			});
		}
		wg.RunAndWait();
	}

	public function GetGlobalDiagnostics():Array<Diagnostic> {
		this.createCheckers();
		final globalDiagnostics:Array<Array<Diagnostic>> = [for (_ in 0...this.checkers.length) null];
		this.forEachCheckerParallel(function(idx:Int, checker:Checker) {
			globalDiagnostics[idx] = checker.GetGlobalDiagnostics();
		});
		return Compiler.SortAndDeduplicateDiagnostics(Slices.Concat(...globalDiagnostics));
	}

	// forEachCheckerGroupDo runs one task per checker in parallel. Each task iterates
	// the provided files, processing only those assigned to its checker. Within each
	// checker's set, files are visited in their original order.
	function forEachCheckerGroupDo(ctx:Context, files:Array<SourceFile>, singleThreaded:Bool, cb:(c:Checker, fileIndex:Int, file:SourceFile) -> Void):Void {
		this.createCheckers();

		final checkerCount = this.checkers.length;
		#if tshx_parallel
		// PORT: hxmc (-D tshx-parallel) — the checkers run on threads, as in Go
		final wg:WorkGroup = singleThreaded ? Core.NewWorkGroup(true) : new ParallelWorkGroup();
		#else
		final wg = Core.NewWorkGroup(singleThreaded);
		#end
		for (checkerIdx in 0...checkerCount) {
			wg.Queue(function() {
				#if tshx_parallel
				final release = this.lock(checkerIdx);
				final t0 = haxe.Timer.stamp();
				#end
				var count = 0;
				for (i in 0...files.length) {
					final file = files[i];
					final checker = this.checkers[checkerIdx];
					if (checker == this.fileAssociations.get(file)) {
						cb(checker, i, file);
						count++;
					}
				}
				#if tshx_parallel
				if (Sys.getEnv("TSHX_DEBUG") != null)
					Sys.stderr().writeString("checker " + checkerIdx + " on slot " + go.Par.slot + ": " + count + " files, " + Std.int((haxe.Timer.stamp() - t0) * 1000) + " ms\n");
				release();
				#end
			});
		}
		#if (tshx_parallel && hxmc.gc_suspend)
		// PORT: hxmc (-D tshx-parallel, -D hxmc.gc-suspend) — no minor collection while the checkers run on threads
		// (each would stop all of them; what they allocate mostly lives on): the nursery grows instead, up to
		// TSHX_GC_SUSPEND_MB (1024; 0: collections as usual)
		final suspendMB = singleThreaded ? 0 : (Sys.getEnv("TSHX_GC_SUSPEND_MB") != null ? Std.parseInt(Sys.getEnv("TSHX_GC_SUSPEND_MB")) : 1024);
		if (suspendMB > 0)
			hxmc.rt.Gc.suspendMinor(suspendMB);
		wg.RunAndWait();
		if (suspendMB > 0)
			hxmc.rt.Gc.resumeMinor();
		#else
		wg.RunAndWait();
		#end
	}
}

// PORT: TypeScript 7.1's checker association (microsoft/typescript-go#4313, compiler/checkerpool.go), with Go's
// comments:
/*
Checker association is a balanced graph-partitioning problem:

  - A vertex is a source file.
  - An undirected edge connects two files for each resolved, in-program import
    entry between them. Multiple entries may connect the same pair and therefore
    strengthen their affinity. Self-imports and unresolved or external targets do
    not create edges.
  - A partition is a checker with its own symbol, type, and instantiation caches.

Putting related files on the same checker reduces duplicated cache construction,
but concentrating too many roots on one checker increases the parallel critical
path. We use weighted FENNEL to trade off those objectives:

  affinity(partition) - alpha * incrementalLoadPenalty(partition)

(Tsourakakis et al., "FENNEL: Streaming Graph Partitioning for Massive Scale Graphs", WSDM 2014.) The constants
are Go's empirical operating points (swept over VS Code, TypeScript, MUI docs, XState and Bluesky at 2, 4 and 8
checkers).
*/
class CheckerAssociation {
	static inline final TextWeightDivisor = 100;
	static inline final PrioritizedSourcePenalty = 12;
	static inline final StrongBalanceMinCheckerCount = 4;
	public static inline final SourceFileWeightMultiplier = 4;
	public static inline final BalancePenaltyMultiplier = 16;

	public static function shouldPrioritizeSourceFiles(totalWeight:Int, declarationWeight:Int, checkerCount:Int):Bool {
		return declarationWeight * checkerCount * 2 <= totalWeight;
	}

	public static function policy(totalWeight:Int, declarationWeight:Int, checkerCount:Int):{prioritizeSourceFiles:Bool, sourceFileWeightMultiplier:Int, balancePenaltyMultiplier:Int} {
		// PORT: Go uses "strong balance" (source weight x4, penalty 16) at >= 4 checkers when declarations are a large
		// share of the program. In the port that breaks import affinity: each checker re-infers the project's
		// imported source symbols (t3code-server: +680 MB going from 3 to 4 checkers). We use the prioritized-source
		// policy (Go's shouldPrioritizeSourceFiles operating point) there instead. Sweep at 4 checkers, best of 3-5,
		// output byte-identical: t3code-server 5.58 -> 5.08 s, 2.97 -> 2.86 GB; ts6-solution build decl
		// 1.67 -> 1.56 s, full 2.97 -> 2.93 s; native-preview 0.30 -> 0.29 s; tsc-extension 0.21 -> 0.20 s;
		// ts6-compiler already prioritized (unchanged). TSHX_POLICY=0,4,16 restores Go's choice.
		if (declarationWeight * checkerCount * 2 <= totalWeight || checkerCount >= StrongBalanceMinCheckerCount) // shouldPrioritizeSourceFiles
			return {prioritizeSourceFiles: true, sourceFileWeightMultiplier: 1, balancePenaltyMultiplier: PrioritizedSourcePenalty};
		return {prioritizeSourceFiles: false, sourceFileWeightMultiplier: 1, balancePenaltyMultiplier: 1};
	}

	public static function baseWeight(nodeCount:Int, textLength:Int):Int {
		final w = nodeCount + Std.int(textLength / TextWeightDivisor);
		return w > 1 ? w : 1;
	}

	// getCheckerAssociationWeights: local syntax work plus normalized syntactic import fanout
	public static function weights(baseWeights:Array<Int>, importCounts:Array<Int>):Array<Int> {
		var totalBaseWeight = 0, totalImports = 0;
		for (i in 0...baseWeights.length) {
			totalBaseWeight += baseWeights[i];
			totalImports += importCounts[i];
		}
		var importWeight = 0;
		if (totalImports > 0) {
			importWeight = Std.int(totalBaseWeight / totalImports);
			if (importWeight < 1)
				importWeight = 1;
		}
		return [for (i in 0...baseWeights.length) baseWeights[i] + importCounts[i] * importWeight];
	}

	// getCheckerAssociationOrder: source files before declarations, each by descending weight (null: program order)
	public static function order(fileWeights:Array<Int>, isDeclarationFile:Array<Bool>, prioritizeSourceFiles:Bool):Null<Array<Int>> {
		if (!prioritizeSourceFiles)
			return null;
		final fileOrder = [for (i in 0...fileWeights.length) i];
		fileOrder.sort((left, right) -> {
			if (isDeclarationFile[left] != isDeclarationFile[right])
				return isDeclarationFile[left] ? 1 : -1;
			if (fileWeights[left] != fileWeights[right])
				return fileWeights[left] > fileWeights[right] ? -1 : 1;
			return left < right ? -1 : (left > right ? 1 : 0);
		});
		return fileOrder;
	}

	// getCheckerAssociationsInOrder: weighted FENNEL with gamma = 3/2; the preferred maximum checker weight is the
	// larger of the largest file and roughly 101% of average; ties deterministic
	public static function associationsInOrder(fileWeights:Array<Int>, adjacentFiles:Array<Array<Int>>, fileOrder:Null<Array<Int>>, checkerCount:Int,
			penaltyMultiplier:Int):Array<Int> {
		final n = fileWeights.length;
		if (n == 0)
			return [];
		var totalWeight = 0, maxFileWeight = 0, edgeCount = 0;
		for (i in 0...n) {
			totalWeight += fileWeights[i];
			if (fileWeights[i] > maxFileWeight)
				maxFileWeight = fileWeights[i];
			edgeCount += adjacentFiles[i].length;
		}
		final associations = [for (_ in 0...n) -1];
		final checkerWeights = [for (_ in 0...checkerCount) 0];
		final averageCheckerWeight = Std.int((totalWeight + checkerCount - 1) / checkerCount);
		final cap = averageCheckerWeight + Std.int(averageCheckerWeight / 100);
		final maxCheckerWeight = maxFileWeight > cap ? maxFileWeight : cap;
		final totalWeightFloat:Float = totalWeight;
		final alpha = penaltyMultiplier * Std.int(edgeCount / 2) * Math.sqrt(checkerCount) / (totalWeightFloat * Math.sqrt(totalWeightFloat));
		final neighborCounts = [for (_ in 0...checkerCount) 0];
		for (position in 0...n) {
			final fileIndex = fileOrder != null ? fileOrder[position] : position;
			for (k in 0...checkerCount)
				neighborCounts[k] = 0;
			for (adjacentFile in adjacentFiles[fileIndex]) {
				final checkerIndex = associations[adjacentFile];
				if (checkerIndex >= 0)
					neighborCounts[checkerIndex]++;
			}
			var bestChecker = -1;
			var bestScore = Math.NEGATIVE_INFINITY;
			for (checkerIndex in 0...checkerCount) {
				final checkerWeight = checkerWeights[checkerIndex];
				if (checkerWeight + fileWeights[fileIndex] > maxCheckerWeight)
					continue;
				final oldWeight:Float = checkerWeight;
				final newWeight:Float = checkerWeight + fileWeights[fileIndex];
				final penalty = alpha * (newWeight * Math.sqrt(newWeight) - oldWeight * Math.sqrt(oldWeight));
				final score = neighborCounts[checkerIndex] - penalty;
				if (score > bestScore || score == bestScore && (bestChecker < 0 || checkerWeight < checkerWeights[bestChecker])) {
					bestChecker = checkerIndex;
					bestScore = score;
				}
			}
			if (bestChecker < 0) {
				bestChecker = 0;
				for (checkerIndex in 1...checkerCount)
					if (checkerWeights[checkerIndex] < checkerWeights[bestChecker])
						bestChecker = checkerIndex;
			}
			associations[fileIndex] = bestChecker;
			checkerWeights[bestChecker] += fileWeights[fileIndex];
		}
		return associations;
	}
}
