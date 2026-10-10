package ts.compiler;

// Port of projectreferenceparser.go (types and methods; createProjectReferenceParseTasks is in Compiler.hx).

@:allow(ts.compiler)
class ProjectReferenceParseTask {
	var configName:std.String = "";
	var resolved:ParsedCommandLine = null;
	var subTasks:Array<ProjectReferenceParseTask> = null;

	public function new() {}

	function parse(projectReferenceParser:ProjectReferenceParser):Void {
		final loader = projectReferenceParser.loader;
		var done:() -> Void = null;
		final tr = loader.opts.Tracing;
		if (tr != null) {
			final args = new StringMap<Any>();
			args.set("path", this.configName);
			done = tr.Push(PhaseParse, "parseJsonSourceFileConfigFileContent", args, false);
		}
		try {
			this.resolved = loader.opts.Host.GetResolvedProjectReference(this.configName, loader.toPath(this.configName));
			if (this.resolved != null) {
				this.resolved.ParseInputOutputNames();
				final subReferences = this.resolved.ResolvedProjectReferencePaths();
				if (Core.len(subReferences) > 0) {
					this.subTasks = Compiler.createProjectReferenceParseTasks(subReferences);
				}
			}
		} catch (e:Dynamic) {
			if (done != null)
				done();
			throw e;
		}
		if (done != null)
			done();
	}
}

@:allow(ts.compiler)
class ProjectReferenceParser {
	var loader:FileLoader = null;
	var wg:WorkGroup = null;
	var tasksByFileName:StringMap<ProjectReferenceParseTask> = new StringMap(); // PORT: SyncMap → StringMap
	var tasksByFileNameSize:Int = 0;

	public function new() {}

	function parse(tasks:Array<ProjectReferenceParseTask>):Void {
		this.loader.projectReferenceFileMapper.loader = this.loader;
		this.start(tasks);
		this.wg.RunAndWait();
		this.initMapper(tasks);
	}

	function start(tasks:Array<ProjectReferenceParseTask>):Void {
		if (tasks == null)
			return;
		for (i in 0...tasks.length) {
			final task = tasks[i];
			final path = this.loader.toPath(task.configName);
			final loadedTask = this.tasksByFileName.get(path);
			if (loadedTask != null) {
				// dedup tasks to ensure correct file order, regardless of which task would be started first
				tasks[i] = loadedTask;
			} else {
				this.tasksByFileName.set(path, task);
				this.tasksByFileNameSize++;
				this.wg.Queue(function() {
					task.parse(this);
					this.start(task.subTasks);
				});
			}
		}
	}

	function initMapper(tasks:Array<ProjectReferenceParseTask>):Void {
		final mapper = this.loader.projectReferenceFileMapper;
		mapper.configToProjectReference = new StringMap();
		mapper.referencesInConfigFile = new StringMap();
		mapper.sourceToProjectReference = new StringMap();
		mapper.outputDtsToProjectReference = new StringMap();
		mapper.referencesInConfigFile.set(this.loader.opts.Config.ConfigFile.SourceFile.Path(),
			this.initMapperWorker(tasks, new Set<ProjectReferenceParseTask>()));
		if (mapper.opts.canUseProjectReferenceSource() && Lambda.count(mapper.outputDtsToProjectReference) != 0) {
			mapper.host = Compiler.newProjectReferenceDtsFakingHost(this.loader);
		}
	}

	function initMapperWorker(tasks:Array<ProjectReferenceParseTask>, seen:Set<ProjectReferenceParseTask>):Array<Path> {
		if (Core.len(tasks) == 0) {
			return null;
		}
		final mapper = this.loader.projectReferenceFileMapper;
		final results:Array<Path> = [];
		for (task in tasks) {
			final path = this.loader.toPath(task.configName);
			results.push(path);
			// ensure we only walk each task once
			if (!seen.AddIfAbsent(task)) {
				continue;
			}
			mapper.configToProjectReference.set(path, task.resolved);
			if (task.resolved != null && mapper.opts.Config.ConfigFile != task.resolved.ConfigFile) {
				// Map current task's files first, before recursing into subtasks.
				// This matches TypeScript's behavior where child project references
				// overwrite parent entries when a file belongs to multiple projects.
				final s2p = task.resolved.SourceToProjectReference();
				if (s2p != null)
					for (k => v in s2p)
						mapper.sourceToProjectReference.set(k, v);
				final o2p = task.resolved.OutputDtsToProjectReference();
				if (o2p != null)
					for (k => v in o2p)
						mapper.outputDtsToProjectReference.set(k, v);
				if (mapper.opts.canUseProjectReferenceSource()) {
					var declDir = task.resolved.CompilerOptions().DeclarationDir;
					if (declDir == "") {
						declDir = task.resolved.CompilerOptions().OutDir;
					}
					if (declDir != "") {
						this.loader.dtsDirectories.Add(this.loader.toPath(declDir));
					}
				}
			}
			final referencesInConfig = this.initMapperWorker(task.subTasks, seen);
			mapper.referencesInConfigFile.set(path, referencesInConfig);
		}
		return results;
	}
}
