package ts.execute.tsctests;

import go.Time;
import go.Patience;
import ts.collections.Syncset;
import ts.diagnostics.Diagnostics;
import ts.execute.Execute;
import ts.locale.Locale;
import ts.tspath.Tspath;
import ts.tspath.Path.ComparePathsOptions;
import ts.tsoptions.Tsoptions;
import ts.vfs.iovfs.Iofs.FsWithSys;
import ts.testutil.harnessutil.Harnessutil;

// Package-level vars and funcs of internal/execute/tsctests (sys.go, runner.go).
class Tsctests {
	// --- sys.go ---

	public static var tscLibPath = "/home/src/tslibs/TS/Lib";

	public static var tscDefaultLibContent(get, never):String;
	static var _tscDefaultLibContent:Null<String> = null;

	static function get_tscDefaultLibContent():String {
		if (_tscDefaultLibContent == null) {
			_tscDefaultLibContent = Stringtestutil.Dedent("
/// <reference no-default-lib=\"true\"/>
interface Boolean {}
interface Function {}
interface CallableFunction {}
interface NewableFunction {}
interface IArguments {}
interface Number { toExponential: any; }
interface Object {}
interface RegExp {}
interface String { charAt: any; }
interface Array<T> { length: number; [n: number]: T; }
interface ReadonlyArray<T> {}
interface SymbolConstructor {
    (desc?: string | number): symbol;
    for(name: string): symbol;
    readonly toStringTag: symbol;
}
declare var Symbol: SymbolConstructor;
interface Symbol {
    readonly [Symbol.toStringTag]: string;
}
declare const console: { log(msg: any): void; };
");
		}
		return _tscDefaultLibContent;
	}

	public static function getTestLibPathFor(libName:String):String {
		var libFile:String;
		final r = Tsoptions.LibMap.Get(libName);
		if (r.ok) {
			libFile = (r.value : String);
		} else {
			libFile = "lib." + libName + ".d.ts";
		}
		return tscLibPath + "/" + libFile;
	}

	public static function NewTscSystem(files:Null<FileMap>, useCaseSensitiveFileNames:Bool, cwd:String):TestSys {
		final clock = new TestClock(Time.Now());
		final sys = new TestSys();
		sys.fs = new TestFs(Vfstest.FromMapWithClock(files, useCaseSensitiveFileNames, clock));
		sys.cwd = cwd;
		sys.clock = clock;
		return sys;
	}

	public static function GetFileMapWithBuild(files:FileMap, commandLineArgs:Array<String>):FileMap {
		final input:TscInput = {files: files.copy()};
		final sys = newTestSys(input, false);
		Execute.CommandLine(go.Context.Background(), sys, commandLineArgs, sys);
		sys.fs.writtenFiles.Range(function(key:String):Bool {
			final r = sys.fsFromFileMap().ReadFile(key);
			if (r.ok) {
				files.set(key, r.value);
			}
			return true;
		});
		return files;
	}

	public static function newTestSys(tscInput:TscInput, forIncrementalCorrectness:Bool):TestSys {
		var cwd = tscInput.cwd;
		if (cwd == "") {
			cwd = "/home/src/workspaces/project";
		}
		var libPath = tscLibPath;
		if (tscInput.windowsStyleRoot != "") {
			libPath = tscInput.windowsStyleRoot + libPath.substring(1);
		}
		final currentWrite = new Builder();
		final sys = NewTscSystem(tscInput.files, !tscInput.ignoreCase, cwd);
		sys.defaultLibraryPath = libPath;
		sys.setCurrentWrite(currentWrite);
		sys.tracer = Harnessutil.NewTracerForBaselining(new ComparePathsOptions(!tscInput.ignoreCase, cwd), currentWrite);
		sys.env = tscInput.env;
		sys.forIncrementalCorrectness = forIncrementalCorrectness;
		// PORT: mockWatchBackend (watch mode) is not ported.
		final differ = new FSDiffer();
		differ.FS = cast(sys.fs.FS, FsWithSys);
		differ.DefaultLibs = function() return sys.fs.defaultLibs;
		differ.getWrittenFiles = function() return sys.fs.writtenFiles;
		differ.setWrittenFiles = function(s) sys.fs.writtenFiles = s;
		sys.fsDiffer = differ;

		// Ensure the default library file is present
		sys.ensureLibPathExists("lib.d.ts");
		// PORT: Go ranges over a map (random order); only the set of files matters.
		for (libFile in Tsoptions.TargetToLibMap()) {
			sys.ensureLibPathExists(libFile);
		}
		for (libFile in Tsoptions.LibFilesSet.Keys().keys()) {
			sys.ensureLibPathExists(libFile);
		}
		return sys;
	}

	public static final fakeTimeStamp = "HH:MM:SS AM";
	public static final fakeDuration = "d.ddds";

	public static final buildStartingAt = "build starting at ";
	public static final buildFinishedIn = "build finished in ";
	public static final listFileStart = "!!! List files start";
	public static final listFileEnd = "!!! List files end";
	public static final statisticsStart = "!!! Statistics start";
	public static final statisticsEnd = "!!! Statistics end";
	public static final buildStatusReportStart = "!!! Build Status Report Start";
	public static final buildStatusReportEnd = "!!! Build Status Report End";
	public static final watchStatusReportStart = "!!! Watch Status Report Start";
	public static final watchStatusReportEnd = "!!! Watch Status Report End";
	public static final traceStart = "!!! Trace start";
	public static final traceEnd = "!!! Trace end";

	public static var englishVersion(get, never):String;

	static function get_englishVersion():String {
		return Diagnostics.Version_0.Localize(Locale.Default, [Core.Version()]);
	}

	public static var fakeEnglishVersion(get, never):String;

	static function get_fakeEnglishVersion():String {
		return Diagnostics.Version_0.Localize(Locale.Default, [Harnessutil.FakeTSVersion]);
	}

	public static var czech(get, never):Locale;

	static function get_czech():Locale {
		return go.text.language.Language.MustParse("cs");
	}

	public static var czechVersion(get, never):String;

	static function get_czechVersion():String {
		return Diagnostics.Version_0.Localize(czech, [Core.Version()]);
	}

	public static var fakeCzechVersion(get, never):String;

	static function get_fakeCzechVersion():String {
		return Diagnostics.Version_0.Localize(czech, [Harnessutil.FakeTSVersion]);
	}

	// --- runner.go ---

	public static function getDiffForIncremental(incrementalSys:TestSys, nonIncrementalSys:TestSys):String {
		final diffBuilder = new Builder();

		final nonIncrementalOutputs = nonIncrementalSys.fs.writtenFiles.ToSlice();
		nonIncrementalOutputs.sort(go.Strings.Compare);
		for (nonIncrementalOutput in nonIncrementalOutputs) {
			if (Tspath.FileExtensionIs(nonIncrementalOutput, Tspath.ExtensionTsBuildInfo)
				|| StringTools.endsWith(nonIncrementalOutput, ".readable.baseline.txt")) {
				// Just check existence
				if (!incrementalSys.fsFromFileMap().FileExists(nonIncrementalOutput)) {
					diffBuilder.WriteString(DiffText("nonIncremental " + nonIncrementalOutput, "incremental " + nonIncrementalOutput, "Exists", ""));
					diffBuilder.WriteString("\n");
				}
			} else {
				final r = nonIncrementalSys.fsFromFileMap().ReadFile(nonIncrementalOutput);
				if (!r.ok) {
					throw "Written file not found " + nonIncrementalOutput;
				}
				final nonIncrementalText = r.value;
				final r2 = incrementalSys.fsFromFileMap().ReadFile(nonIncrementalOutput);
				final incrementalText = r2.value;
				if (!r2.ok || incrementalText != nonIncrementalText) {
					diffBuilder.WriteString(DiffText("nonIncremental " + nonIncrementalOutput, "incremental " + nonIncrementalOutput, nonIncrementalText,
						incrementalText));
					diffBuilder.WriteString("\n");
				}
			}
		}

		final incrementalOutput = incrementalSys.getOutput(true);
		final nonIncrementalOutput = nonIncrementalSys.getOutput(true);
		if (incrementalOutput != nonIncrementalOutput) {
			diffBuilder.WriteString(DiffText("nonIncremental.output.txt", "incremental.output.txt", nonIncrementalOutput, incrementalOutput));
		}
		return diffBuilder.String();
	}

	// baseline.DiffText (internal/testutil/baseline). PORT: lives here (test/ts/testutil is not this lane's).
	public static function DiffText(oldName:String, newName:String, expected:String, actual:String):String {
		final lines = Patience.Diff(ts.stringutil.Stringutil.SplitLines(expected), ts.stringutil.Stringutil.SplitLines(actual));
		return Patience.UnifiedDiffTextWithOptions(lines, new UnifiedDiffOptions(3, 3, oldName, newName));
	}
}
