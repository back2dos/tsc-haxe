package ts.execute.tsctests;

import go.Errors.Error;
import go.Io.Writer;
import go.Time;
import ts.collections.Syncmap;
import ts.collections.Syncset;
import ts.compiler.Host.TraceFunc;
import ts.compiler.Program.EmitResult;
import ts.diagnostics.Diagnostics;
import ts.execute.tsc.Compile;
import ts.locale.Locale;
import ts.tspath.Path;
import ts.tspath.Tspath;
import ts.vfs.Vfs;
import ts.vfs.iovfs.Iofs.FsWithSys;
import ts.vfs.vfstest.Vfstest.Clock;
import ts.vfs.vfstest.Vfstest.MapFS;
import ts.testutil.harnessutil.Harnessutil;

// Port of internal/execute/tsctests/sys.go (types and methods; package-level vars/funcs are in Tsctests.hx).

class TestClock implements Clock {
	public var start:Time = Time.Zero();
	public var now:Time = Time.Zero();

	public function new(start:Time) {
		this.start = start;
	}

	public function Now():Time {
		if (this.now.IsZero()) {
			this.now = this.start;
		}
		this.now = this.now.Add(1000000000); // Simulate some time passing
		return this.now;
	}

	public function SinceStart():Duration {
		return this.Now().Sub(this.start);
	}
}

// PORT: Go `*strings.Builder` used as io.Writer; one adapter per builder so `w == s.Writer()` works.
class BuilderWriter implements Writer {
	public final b:Builder;

	public function new(b:Builder) {
		this.b = b;
	}

	public function Write(p:String):ValueError<Int> {
		this.b.WriteString(p);
		return new ValueError<Int>(p.length, null);
	}
}

class TestSys implements System implements CommandLineTesting {
	public var currentWrite:Builder = null;
	var currentWriter:BuilderWriter = null;
	public var programBaselines:Builder = new Builder();
	public var programIncludeBaselines:Builder = new Builder();
	public var tracer:TracerForBaselining = null;
	public var fsDiffer:FSDiffer = null;
	public var forIncrementalCorrectness:Bool = false;
	// PORT: mockWatchBackend (watch mode) is not ported.

	public var fs:TestFs = null;
	public var defaultLibraryPath:String = "";
	public var cwd:String = "";
	public var env:Null<Map<String, String>> = null;
	public var clock:TestClock = null;

	public function new() {}

	// PORT: sets currentWrite and its io.Writer adapter together.
	public function setCurrentWrite(b:Builder):Void {
		this.currentWrite = b;
		this.currentWriter = new BuilderWriter(b);
	}

	public function Now():Time {
		return this.clock.Now();
	}

	public function SinceStart():Duration {
		return this.clock.SinceStart();
	}

	public function FS():FS {
		return this.fs;
	}

	public function fsFromFileMap():FsWithSys {
		return this.fsDiffer.FS;
	}

	public function mapFs():MapFS {
		return this.fsDiffer.MapFs();
	}

	public function ensureLibPathExists(path:String):Void {
		path = this.defaultLibraryPath + "/" + path;
		if (!this.fsFromFileMap().ReadFile(path).ok) {
			if (this.fs.defaultLibs == null) {
				this.fs.defaultLibs = new SyncSet<String>();
			}
			this.fs.defaultLibs.Add(path);
			final err = this.fsFromFileMap().WriteFile(path, Tsctests.tscDefaultLibContent);
			if (err != null) {
				throw "Failed to write default library file: " + err.Error();
			}
		}
	}

	public function DefaultLibraryPath():String {
		return this.defaultLibraryPath;
	}

	public function GetCurrentDirectory():String {
		return this.cwd;
	}

	public function Writer():Writer {
		return this.currentWriter;
	}

	public function WriteOutputIsTTY():Bool {
		return true;
	}

	public function GetWidthOfTerminal():Int {
		final widthStr = this.GetEnvironmentVariable("TS_TEST_TERMINAL_WIDTH");
		if (widthStr != "") {
			final n = Std.parseInt(widthStr);
			if (n == null)
				throw "strconv.Atoi: parsing " + widthStr + ": invalid syntax"; // core.Must
			return n;
		}
		return 0;
	}

	public function GetEnvironmentVariable(name:String):String {
		if (this.env == null || !this.env.exists(name))
			return "";
		return this.env.get(name);
	}

	public function OnEmittedFiles(result:Null<EmitResult>, mTimesCache:Null<SyncMap<String, Time>>):Void {
		if (result != null) {
			for (file in result.EmittedFiles) {
				final modTime = this.mapFs().GetModTime(file);
				final serializedDiff = this.fsDiffer.SerializedDiff();
				if (serializedDiff != null) {
					final diff = serializedDiff.Snap.get(file);
					if (diff != null && diff.MTime.Equal(modTime)) {
						// Even though written, timestamp was reverted
						continue;
					}
				}

				// Ensure that the timestamp for emitted files is in the order
				final now = this.Now();
				final err = this.fsFromFileMap().Chtimes(file, Time.Zero(), now);
				if (err != null) {
					throw "Failed to change time for emitted file: " + file + ": " + err.Error();
				}
				// Update the mTime cache in --b mode to store the updated timestamp so tests will behave deteministically when finding newest output
				if (mTimesCache != null) {
					final path:String = Tspath.ToPath(file, this.GetCurrentDirectory(), this.FS().UseCaseSensitiveFileNames());
					if (mTimesCache.Load(path).ok) {
						mTimesCache.Store(path, now);
					}
				}
			}
		}
	}

	public function OnListFilesStart(w:Writer):Void {
		w.Write(Tsctests.listFileStart + "\n");
	}

	public function OnListFilesEnd(w:Writer):Void {
		w.Write(Tsctests.listFileEnd + "\n");
	}

	public function OnStatisticsStart(w:Writer):Void {
		w.Write(Tsctests.statisticsStart + "\n");
	}

	public function OnStatisticsEnd(w:Writer):Void {
		w.Write(Tsctests.statisticsEnd + "\n");
	}

	public function OnBuildStatusReportStart(w:Writer):Void {
		w.Write(Tsctests.buildStatusReportStart + "\n");
	}

	public function OnBuildStatusReportEnd(w:Writer):Void {
		w.Write(Tsctests.buildStatusReportEnd + "\n");
	}

	public function OnWatchStatusReportStart():Void {
		this.Writer().Write(Tsctests.watchStatusReportStart + "\n");
	}

	public function OnWatchStatusReportEnd():Void {
		this.Writer().Write(Tsctests.watchStatusReportEnd + "\n");
	}

	public function GetTrace(w:Writer, locale:Locale):TraceFunc {
		return function(msg:Message, args:Array<Any>) {
			w.Write(Tsctests.traceStart + "\n");
			// With tsc -b building projects in parallel we cannot serialize the package.json lookup trace
			// so trace as if it wasnt cached
			final str = msg.Localize(locale, args);
			// PORT: TracerForBaselining.TraceWithWriter takes the strings.Builder behind the writer.
			this.tracer.TraceWithWriter((cast w : BuilderWriter).b, str, w == this.Writer());
			w.Write(Tsctests.traceEnd + "\n");
		};
	}

	function writeHeaderToBaseline(builder:Builder, program:ts.execute.incremental.Program.Program):Void {
		if (builder.Len() != 0) {
			builder.WriteString("\n");
		}

		final configFilePath = program.Options().ConfigFilePath;
		if (configFilePath != "") {
			builder.WriteString(Tspath.GetRelativePathFromDirectory(this.cwd, configFilePath,
				new ComparePathsOptions(this.FS().UseCaseSensitiveFileNames(), this.GetCurrentDirectory())));
			builder.WriteString("::\n");
		}
	}

	// PORT: WatchBackend() (watchmanager) is not ported.

	public function OnProgram(program:ts.execute.incremental.Program.Program):Void {
		this.writeHeaderToBaseline(this.programBaselines, program);

		final testingData = program.GetTestingData();
		this.programBaselines.WriteString("SemanticDiagnostics::\n");
		for (file in program.GetProgram().GetSourceFiles()) {
			final d = testingData.SemanticDiagnosticsPerFile.Load(file.Path());
			if (d.ok) {
				final diagnostics = d.value;
				final old = testingData.OldProgramSemanticDiagnosticsPerFile.Load(file.Path());
				if (!old.ok || old.value != diagnostics) {
					this.programBaselines.WriteString("*refresh*    ");
					this.programBaselines.WriteString(file.FileName());
					this.programBaselines.WriteString("\n");
				}
			} else {
				this.programBaselines.WriteString("*not cached* ");
				this.programBaselines.WriteString(file.FileName());
				this.programBaselines.WriteString("\n");
			}
		}

		// Write signature updates
		this.programBaselines.WriteString("Signatures::\n");
		for (file in program.GetProgram().GetSourceFiles()) {
			final path:String = file.Path();
			if (testingData.UpdatedSignatureKinds.exists(path)) {
				final kind = testingData.UpdatedSignatureKinds.get(path);
				if (kind == SignatureUpdateKindComputedDts) {
					this.programBaselines.WriteString("(computed .d.ts) ");
					this.programBaselines.WriteString(file.FileName());
					this.programBaselines.WriteString("\n");
				} else if (kind == SignatureUpdateKindStoredAtEmit) {
					this.programBaselines.WriteString("(stored at emit) ");
					this.programBaselines.WriteString(file.FileName());
					this.programBaselines.WriteString("\n");
				} else if (kind == SignatureUpdateKindUsedVersion) {
					this.programBaselines.WriteString("(used version)   ");
					this.programBaselines.WriteString(file.FileName());
					this.programBaselines.WriteString("\n");
				}
			}
		}

		var filesWithoutIncludeReason:Array<String> = [];
		var fileNotInProgramWithIncludeReason:Array<String> = [];
		final includeReasons = program.GetProgram().GetIncludeReasons();
		for (file in program.GetProgram().GetSourceFiles()) {
			if (includeReasons == null || !includeReasons.exists(file.Path())) {
				filesWithoutIncludeReason.push(file.Path());
			}
		}
		if (includeReasons != null) {
			// PORT: Go map iteration order is random; the order only affects a failure message.
			for (path in includeReasons.keys()) {
				if (program.GetProgram().GetSourceFileByPath(path) == null && !program.GetProgram().IsMissingPath(path)) {
					fileNotInProgramWithIncludeReason.push(path);
				}
			}
		}
		if (filesWithoutIncludeReason.length > 0 || fileNotInProgramWithIncludeReason.length > 0) {
			this.writeHeaderToBaseline(this.programIncludeBaselines, program);
			this.programIncludeBaselines.WriteString("!!! Expected all files to have include reasons\nfilesWithoutIncludeReason::\n");
			for (file in filesWithoutIncludeReason) {
				this.programIncludeBaselines.WriteString("  ");
				this.programIncludeBaselines.WriteString(file);
				this.programIncludeBaselines.WriteString("\n");
			}
			this.programIncludeBaselines.WriteString("filesNotInProgramWithIncludeReason::\n");
			for (file in fileNotInProgramWithIncludeReason) {
				this.programIncludeBaselines.WriteString("  ");
				this.programIncludeBaselines.WriteString(file);
				this.programIncludeBaselines.WriteString("\n");
			}
		}
	}

	public function baselinePrograms(baseline:Builder, header:String):String {
		baseline.WriteString(this.programBaselines.String());
		this.programBaselines.Reset();
		var result = "";
		if (this.programIncludeBaselines.Len() > 0) {
			result += "\n\n" + header + "\n!!! Include reasons expectations don't match pls review!!!\n";
			result += this.programIncludeBaselines.String();
			this.programIncludeBaselines.Reset();
			baseline.WriteString(result);
		}
		return result;
	}

	public function serializeState(baseline:Builder):Void {
		this.baselineOutput(baseline);
		this.baselineFSwithDiff(baseline);
		// todo watch
		// this.serializeWatches(baseline);
		// this.timeoutCallbacks.serialize(baseline);
		// this.immediateCallbacks.serialize(baseline);
		// this.pendingInstalls.serialize(baseline);
		// this.service?.baseline();
	}

	function baselineOutput(baseline:Builder):Void {
		baseline.WriteString("\nOutput::\n");
		final output = this.getOutput(false);
		baseline.WriteString(output);
	}

	public function getOutput(forComparing:Bool):String {
		final lines = go.Strings.Split(this.currentWrite.String(), "\n");
		final transformer = new OutputSanitizer(forComparing, lines);
		return transformer.transformLines();
	}

	public function clearOutput():Void {
		this.currentWrite.Reset();
		this.tracer.Reset();
	}

	public function baselineFSwithDiff(baseline:Builder):Void {
		this.fsDiffer.BaselineFSwithDiff(baseline);
	}

	public function writeFileNoError(path:String, content:String):Void {
		final err = this.fsFromFileMap().WriteFile(path, content);
		if (err != null) {
			throw err;
		}
	}

	public function removeNoError(path:String):Void {
		final err = this.fsFromFileMap().Remove(path);
		if (err != null) {
			throw err;
		}
	}

	public function readFileNoError(path:String):String {
		final r = this.fsFromFileMap().ReadFile(path);
		if (!r.ok) {
			throw "File not found: " + path;
		}
		return r.value;
	}

	public function renameFileNoError(oldPath:String, newPath:String):Void {
		this.writeFileNoError(newPath, this.readFileNoError(oldPath));
		this.removeNoError(oldPath);
	}

	public function replaceFileText(path:String, oldText:String, newText:String):Void {
		var content = this.readFileNoError(path);
		content = go.Strings.Replace(content, oldText, newText, 1);
		this.writeFileNoError(path, content);
	}

	public function replaceFileTextAll(path:String, oldText:String, newText:String):Void {
		var content = this.readFileNoError(path);
		content = go.Strings.ReplaceAll(content, oldText, newText);
		this.writeFileNoError(path, content);
	}

	public function appendFile(path:String, text:String):Void {
		final content = this.readFileNoError(path);
		this.writeFileNoError(path, content + text);
	}

	public function prependFile(path:String, text:String):Void {
		final content = this.readFileNoError(path);
		this.writeFileNoError(path, text + content);
	}
}

// Go type `outputSanitizer` (unexported).
class OutputSanitizer {
	var forComparing:Bool = false;
	var lines:Array<String> = null;
	var index:Int = 0;
	var outputLines:Array<String> = null;

	public function new(forComparing:Bool, lines:Array<String>) {
		this.forComparing = forComparing;
		this.lines = lines;
		this.outputLines = [];
	}

	function addOutputLine(s:String):Void {
		s = go.Strings.ReplaceAll(s, "'" + Core.Version() + "'", "'" + Harnessutil.FakeTSVersion + "'");
		s = go.Strings.ReplaceAll(s, Tsctests.englishVersion, Tsctests.fakeEnglishVersion);
		// PORT: the Czech replacement (czechVersion → fakeCzechVersion) needs localized messages,
		// which the diagnostics port does not have (locale has no tag matching).
		s = Fsbaselineutil.SanitizeInternalSymbolName(s);
		this.outputLines.push(s);
	}

	function sanitizeBuildStatusTimeStamp():String {
		final statusLine = this.lines[this.index];
		final hhSeparator = statusLine.indexOf(":");
		if (hhSeparator < 2) {
			throw "Expected timestamp";
		}
		return statusLine.substring(0, hhSeparator - 2) + Tsctests.fakeTimeStamp + statusLine.substring(hhSeparator + Tsctests.fakeTimeStamp.length - 2);
	}

	public function transformLines():String {
		while (this.index < this.lines.length) {
			final line = this.lines[this.index];
			if (StringTools.startsWith(line, Tsctests.buildStartingAt)) {
				if (!this.forComparing) {
					this.addOutputLine(Tsctests.buildStartingAt + Tsctests.fakeTimeStamp);
				}
				this.index++;
				continue;
			}
			if (StringTools.startsWith(line, Tsctests.buildFinishedIn)) {
				if (!this.forComparing) {
					this.addOutputLine(Tsctests.buildFinishedIn + Tsctests.fakeDuration);
				}
				this.index++;
				continue;
			}
			if (!this.addOrSkipLinesForComparing(Tsctests.listFileStart, Tsctests.listFileEnd, false, null)
				&& !this.addOrSkipLinesForComparing(Tsctests.statisticsStart, Tsctests.statisticsEnd, true, null)
				&& !this.addOrSkipLinesForComparing(Tsctests.traceStart, Tsctests.traceEnd, false, null)
				&& !this.addOrSkipLinesForComparing(Tsctests.buildStatusReportStart, Tsctests.buildStatusReportEnd, false, this.sanitizeBuildStatusTimeStamp)
				&& !this.addOrSkipLinesForComparing(Tsctests.watchStatusReportStart, Tsctests.watchStatusReportEnd, false, this.sanitizeBuildStatusTimeStamp)) {
				this.addOutputLine(line);
			}
			this.index++;
		}
		return this.outputLines.join("\n");
	}

	function addOrSkipLinesForComparing(lineStart:String, lineEnd:String, skipEvenIfNotComparing:Bool, sanitizeFirstLine:Null<() -> String>):Bool {
		if (this.lines[this.index] != lineStart) {
			return false;
		}
		this.index++;
		var isFirstLine = true;
		while (this.index < this.lines.length) {
			if (this.lines[this.index] == lineEnd) {
				return true;
			}
			if (!this.forComparing && !skipEvenIfNotComparing) {
				var line = this.lines[this.index];
				if (isFirstLine && sanitizeFirstLine != null) {
					line = sanitizeFirstLine();
					isFirstLine = false;
				}
				this.addOutputLine(line);
			}
			this.index++;
		}
		throw "Expected lineEnd" + lineEnd + " not found after " + lineStart;
	}
}
