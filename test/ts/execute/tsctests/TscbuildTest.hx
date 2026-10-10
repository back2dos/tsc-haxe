package ts.execute.tsctests;

import ts.core.Compileroptions.CompilerOptions;
import ts.execute.tsctests.Runner.FileMap;
import ts.testutil.harnessutil.Harnessutil.Harnessutil;
import ts.tsoptions.Tsoptions.Tsoptions;
import go.Time;

// Port of internal/execute/tsctests/tscbuild_test.go (scenario data).
// PORT: the Go test functions are at column 0 inside the class so that multi-line raw strings that are
// not dedented keep their exact text.

// Go local struct types of the test functions.
@:structInit
class TscOutputPathScenario {
	public var subScenario:String = "";
	public var files:Null<FileMap> = null;
	public var expectedDtsNames:Null<Array<String>> = null;
}

@:structInit
class BuildResolveJsonModuleScenario {
	public var subScenario:String = "";
	public var tsconfigFiles:String = "";
	public var additionalCompilerOptions:String = "";
	public var skipOutdir:Bool = false;
	public var modifyFiles:Null<(files:FileMap) -> Void> = null;
	public var edits:Null<Array<TscEdit>> = null;
}

class TscbuildTest {
	// PORT: runner.go package vars noChange / noChangeOnlyEdit (used only by the scenario data).
	static var noChange(get, never):TscEdit;

	static function get_noChange():TscEdit {
		return {caption: "no change"};
	}

	static var noChangeOnlyEdit(get, never):Array<TscEdit>;

	static function get_noChangeOnlyEdit():Array<TscEdit> {
		return [noChange];
	}

	// PORT: fmt.Sprintf with the %t verb (not in go.Fmt): bools are passed as "true"/"false" with %s.
	static function sprintf(format:String, ...args:Any):String {
		final a:Array<Any> = [for (x in args) Std.isOfType(x, Bool) ? ((x : Bool) ? "true" : "false") : x];
		return Fmt.Sprintf(StringTools.replace(format, "%t", "%s"), a);
	}

	// PORT: Go `append(s, xs...)`; the scenario code only appends to slices it owns or to fresh
	// literals, so a copy keeps Go's result without aliasing.
	static function append<E>(s:Null<Array<E>>, ...xs:E):Array<E> {
		final r = s == null ? [] : s.copy();
		for (x in xs)
			r.push(x);
		return r;
	}

	public static function run() {
		TestBuildCommandLine();
		TestBuildClean();
		TestBuildConfigFileErrors();
		TestBuildDemoProject();
		TestBuildEmitDeclarationOnly();
		TestBuildFileDelete();
		TestBuildDependencyUpdate();
		TestBuildInferredTypeFromTransitiveModule();
		TestBuildInferredTypeFromMonorepoReference();
		TestBuildDeclarationEmitForReferencedProjectTypesSubpath();
		TestBuildJavascriptProjectEmit();
		TestBuildLateBoundSymbol();
		TestBuildModuleSpecifiers();
		TestBuildOutputPaths();
		TestBuildProgramUpdates();
		TestBuildProjectsBuilding();
		TestBuildProjectReferenceWithRootDirInParent();
		TestBuildReexport();
		TestBuildResolveJsonModule();
		TestBuildRoots();
		TestBuildSample();
		TestBuildTransitiveReferences();
		TestBuildSolutionProject();
		TestBuildProjectReferenceRedirectWithMultipleSubProjects();
	}

public static function TestBuildCommandLine() {
	var getBuildCommandLineDifferentOptionsMap = function(optionName:String):FileMap {
		return ([
			"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent(sprintf("
			{
				\"compilerOptions\": {
					\"%s\": true
				}
			}", optionName)),
			"/home/src/workspaces/project/a.ts" => "export const a = 10;const aLocal = 10;",
			"/home/src/workspaces/project/b.ts" => "export const b = 10;const bLocal = 10;",
			"/home/src/workspaces/project/c.ts" => "import { a } from \"./a\";export const c = a;",
			"/home/src/workspaces/project/d.ts" => "import { b } from \"./b\";export const d = b;"
		] : FileMap);
	};
	var getBuildCommandLineEmitDeclarationOnlyMap = function(options:Array<String>):FileMap {
		// PORT: strings.Join → Array.join.
		var compilerOptionsStr = Core.Map(options, function(opt:String):String {
			return sprintf("\"%s\": true", opt);
		}).join(", ");
		return ([
			"/home/src/workspaces/solution/project1/src/tsconfig.json" => Stringtestutil.Dedent(sprintf("
			{
				\"compilerOptions\": { %s }
			}", compilerOptionsStr)),
			"/home/src/workspaces/solution/project1/src/a.ts" => "export const a = 10;const aLocal = 10;",
			"/home/src/workspaces/solution/project1/src/b.ts" => "export const b = 10;const bLocal = 10;",
			"/home/src/workspaces/solution/project1/src/c.ts" => "import { a } from \"./a\";export const c = a;",
			"/home/src/workspaces/solution/project1/src/d.ts" => "import { b } from \"./b\";export const d = b;",
			"/home/src/workspaces/solution/project2/src/tsconfig.json" => Stringtestutil.Dedent(sprintf("
			{
				\"compilerOptions\": { %s },
				\"references\": [{ \"path\": \"../../project1/src\" }]
			}", compilerOptionsStr)),
			"/home/src/workspaces/solution/project2/src/e.ts" => "export const e = 10;",
			"/home/src/workspaces/solution/project2/src/f.ts" => "import { a } from \"../../project1/src/a\"; export const f = a;",
			"/home/src/workspaces/solution/project2/src/g.ts" => "import { b } from \"../../project1/src/b\"; export const g = b;"
		] : FileMap);
	};
	var getBuildCommandLineEmitDeclarationOnlyTestCases = function(options:Array<String>, suffix:String):Array<TscInput> {
		return ([
			{
				subScenario:     "emitDeclarationOnly on commandline" + suffix,
				files:           getBuildCommandLineEmitDeclarationOnlyMap(options),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--b", "project2/src", "--verbose", "--emitDeclarationOnly"],
				edits: ([
					noChange,
					{
						caption: "local change",
						edit: function(sys:TestSys) {
							sys.appendFile("/home/src/workspaces/solution/project1/src/a.ts", "const aa = 10;");
						}
					},
					{
						caption: "non local change",
						edit: function(sys:TestSys) {
							sys.appendFile("/home/src/workspaces/solution/project1/src/a.ts", "export const aaa = 10;");
						}
					},
					{
						caption:         "emit js files",
						commandLineArgs: ["--b", "project2/src", "--verbose"]
					},
					noChange,
					{
						caption: "js emit with change without emitDeclarationOnly",
						edit: function(sys:TestSys) {
							sys.appendFile("/home/src/workspaces/solution/project1/src/b.ts", "const alocal = 10;");
						},
						commandLineArgs: ["--b", "project2/src", "--verbose"]
					},
					{
						caption: "local change",
						edit: function(sys:TestSys) {
							sys.appendFile("/home/src/workspaces/solution/project1/src/b.ts", "const aaaa = 10;");
						}
					},
					{
						caption: "non local change",
						edit: function(sys:TestSys) {
							sys.appendFile("/home/src/workspaces/solution/project1/src/b.ts", "export const aaaaa = 10;");
						}
					},
					{
						caption: "js emit with change without emitDeclarationOnly",
						edit: function(sys:TestSys) {
							sys.appendFile("/home/src/workspaces/solution/project1/src/b.ts", "export const a2 = 10;");
						},
						commandLineArgs: ["--b", "project2/src", "--verbose"]
					}
				] : Array<TscEdit>)
			},
			{
				subScenario:     "emitDeclarationOnly false on commandline" + suffix,
				files:           getBuildCommandLineEmitDeclarationOnlyMap(Slices.Concat(options, ["emitDeclarationOnly"])),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--b", "project2/src", "--verbose"],
				edits: ([
					noChange,
					{
						caption: "change",
						edit: function(sys:TestSys) {
							sys.appendFile("/home/src/workspaces/solution/project1/src/a.ts", "const aa = 10;");
						}
					},
					{
						caption:         "emit js files",
						commandLineArgs: ["--b", "project2/src", "--verbose", "--emitDeclarationOnly", "false"]
					},
					noChange,
					{
						caption:         "no change run with js emit",
						commandLineArgs: ["--b", "project2/src", "--verbose", "--emitDeclarationOnly", "false"]
					},
					{
						caption: "js emit with change",
						edit: function(sys:TestSys) {
							sys.appendFile("/home/src/workspaces/solution/project1/src/b.ts", "const blocal = 10;");
						},
						commandLineArgs: ["--b", "project2/src", "--verbose", "--emitDeclarationOnly", "false"]
					}
				] : Array<TscEdit>)
			}
		] : Array<TscInput>);
	};
	var testCases = Slices.Concat(
		([
			{
				subScenario: "included tsconfig json can be imported as json input",
				files: ([
					"/home/src/workspaces/project/index.ts" => "import tsconfig from \"./tsconfig.json\" with { type: \"json\" };
declare global {
    interface ImportAttributes {
        type: \"json\";
    }
}
console.log(tsconfig);",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"module\": \"preserve\",
							\"moduleResolution\": \"bundler\",
							\"noEmit\": true,
							\"resolveJsonModule\": true,
							\"strict\": true,
							\"target\": \"esnext\"
						},
						\"include\": [\"index.ts\", \"tsconfig.json\"]
					}")
				] : FileMap),
				commandLineArgs: ["--build"]
			},
			{
				subScenario:     "help",
				files:           ([] : FileMap),
				commandLineArgs: ["--build", "--help"]
			},
			{
				subScenario:     "locale",
				files:           ([] : FileMap),
				commandLineArgs: ["--build", "--help", "--locale", "en"]
			},
			{
				subScenario:     "bad locale",
				files:           ([] : FileMap),
				commandLineArgs: ["--build", "--help", "--locale", "whoops"]
			},
			{
				subScenario:     "different options",
				files:           getBuildCommandLineDifferentOptionsMap("composite"),
				commandLineArgs: ["--build", "--verbose"],
				edits: ([
					{
						caption:         "with sourceMap",
						commandLineArgs: ["--build", "--verbose", "--sourceMap"]
					},
					{
						caption: "should re-emit only js so they dont contain sourcemap"
					},
					{
						caption:         "with declaration should not emit anything",
						commandLineArgs: ["--build", "--verbose", "--declaration"]
					},
					noChange,
					{
						caption:         "with declaration and declarationMap",
						commandLineArgs: ["--build", "--verbose", "--declaration", "--declarationMap"]
					},
					{
						caption: "should re-emit only dts so they dont contain sourcemap"
					},
					{
						caption:         "with emitDeclarationOnly should not emit anything",
						commandLineArgs: ["--build", "--verbose", "--emitDeclarationOnly"]
					},
					noChange,
					{
						caption: "local change",
						edit: function(sys:TestSys) {
							sys.replaceFileText("/home/src/workspaces/project/a.ts", "Local = 1", "Local = 10");
						}
					},
					{
						caption:         "with declaration should not emit anything",
						commandLineArgs: ["--build", "--verbose", "--declaration"]
					},
					{
						caption:         "with inlineSourceMap",
						commandLineArgs: ["--build", "--verbose", "--inlineSourceMap"]
					},
					{
						caption:         "with sourceMap",
						commandLineArgs: ["--build", "--verbose", "--sourceMap"]
					}
				] : Array<TscEdit>)
			},
			{
				subScenario:     "different options with incremental",
				files:           getBuildCommandLineDifferentOptionsMap("incremental"),
				commandLineArgs: ["--build", "--verbose"],
				edits: ([
					{
						caption:         "with sourceMap",
						commandLineArgs: ["--build", "--verbose", "--sourceMap"]
					},
					{
						caption: "should re-emit only js so they dont contain sourcemap"
					},
					{
						caption:         "with declaration, emit Dts and should not emit js",
						commandLineArgs: ["--build", "--verbose", "--declaration"]
					},
					{
						caption:         "with declaration and declarationMap",
						commandLineArgs: ["--build", "--verbose", "--declaration", "--declarationMap"]
					},
					noChange,
					{
						caption: "local change",
						edit: function(sys:TestSys) {
							sys.replaceFileText("/home/src/workspaces/project/a.ts", "Local = 1", "Local = 10");
						}
					},
					{
						caption:         "with declaration and declarationMap",
						commandLineArgs: ["--build", "--verbose", "--declaration", "--declarationMap"]
					},
					noChange,
					{
						caption:         "with inlineSourceMap",
						commandLineArgs: ["--build", "--verbose", "--inlineSourceMap"]
					},
					{
						caption:         "with sourceMap",
						commandLineArgs: ["--build", "--verbose", "--sourceMap"]
					},
					{
						caption: "emit js files"
					},
					{
						caption:         "with declaration and declarationMap",
						commandLineArgs: ["--build", "--verbose", "--declaration", "--declarationMap"]
					},
					{
						caption:         "with declaration and declarationMap, should not re-emit",
						commandLineArgs: ["--build", "--verbose", "--declaration", "--declarationMap"]
					}
				] : Array<TscEdit>)
			}
		] : Array<TscInput>),
		getBuildCommandLineEmitDeclarationOnlyTestCases(["composite"], ""),
		getBuildCommandLineEmitDeclarationOnlyTestCases(["incremental", "declaration"], " with declaration and incremental"),
		getBuildCommandLineEmitDeclarationOnlyTestCases(["declaration"], " with declaration")
	);

	for (test in testCases) {
		test.run("commandLine");
	}
}

public static function TestBuildClean() {
	var testCases = ([
		{
			subScenario: "file name and output name clashing",
			files: ([
				"/home/src/workspaces/solution/index.js" => "",
				"/home/src/workspaces/solution/bar.ts" =>   "",
				"/home/src/workspaces/solution/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": { \"allowJs\": true }
				}")
			] : FileMap),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "--clean"]
		},
		{
			subScenario: "tsx with dts emit",
			files: ([
				"/home/src/workspaces/solution/project/src/main.tsx" => "export const x = 10;",
				"/home/src/workspaces/solution/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": { \"declaration\": true },
					\"include\": [\"src/**/*.tsx\", \"src/**/*.ts\"]
				}")
			] : FileMap),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "project", "-v", "--explainFiles"],
			edits: ([
				noChange,
				{
					caption:         "clean build",
					commandLineArgs: ["-b", "project", "--clean"]
				}
			] : Array<TscEdit>)
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("clean");
	}
}

public static function TestBuildConfigFileErrors() {
	var testCases = ([
		{
			subScenario: "when tsconfig extends the missing file",
			files: ([
				"/home/src/workspaces/project/tsconfig.first.json" => Stringtestutil.Dedent("
					{
						\"extends\": \"./foobar.json\",
						\"compilerOptions\": {
							\"composite\": true
						}
					}"),
				"/home/src/workspaces/project/tsconfig.second.json" => Stringtestutil.Dedent("
					{
						\"extends\": \"./foobar.json\",
						\"compilerOptions\": {
							\"composite\": true
						}
					}"),
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true
						},
						\"references\": [
							{ \"path\": \"./tsconfig.first.json\" },
							{ \"path\": \"./tsconfig.second.json\" }
						]
					}")
			] : FileMap),
			commandLineArgs: ["--b"]
		},
		{
			subScenario: "reports syntax errors in config file",
			files: ([
				"/home/src/workspaces/project/a.ts" => "export function foo() { }",
				"/home/src/workspaces/project/b.ts" => "export function bar() { }",
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
						},
						\"files\": [
							\"a.ts\"
							\"b.ts\"
						]
					}")
			] : FileMap),
			commandLineArgs: ["--b"],
			edits: ([
				{
					caption: "reports syntax errors after change to config file",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/project/tsconfig.json", ",", ", \"declaration\": true");
					}
				},
				{
					caption: "reports syntax errors after change to ts file",
					edit: function(sys:TestSys) {
						sys.appendFile("/home/src/workspaces/project/a.ts", "export function fooBar() { }");
					}
				},
				noChange,
				{
					caption: "builds after fixing config file errors",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/home/src/workspaces/project/tsconfig.json", Stringtestutil.Dedent("
							{
								\"compilerOptions\": {
									\"composite\": true, \"declaration\": true
								},
								\"files\": [
									\"a.ts\",
									\"b.ts\"
								]
							}"));
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario:     "missing config file",
			files:           ([] : FileMap),
			commandLineArgs: ["--b", "bogus.json"]
		},
		{
			subScenario: "reports syntax errors in config file",
			files: ([
				"/home/src/workspaces/project/a.ts" => "export function foo() { }",
				"/home/src/workspaces/project/b.ts" => "export function bar() { }",
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
						},
						\"files\": [
							\"a.ts\"
							\"b.ts\"
						]
					}")
			] : FileMap),
			commandLineArgs: ["--b", "-w"],
			edits: ([
				{
					caption: "reports syntax errors after change to config file",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/project/tsconfig.json", ",", ", \"declaration\": true");
					}
				},
				{
					caption: "reports syntax errors after change to ts file",
					edit: function(sys:TestSys) {
						sys.appendFile("/home/src/workspaces/project/a.ts", "export function fooBar() { }");
					}
				},
				{
					caption: "reports error when there is no change to tsconfig file",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/project/tsconfig.json", "", "");
					}
				},
				{
					caption: "builds after fixing config file errors",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/home/src/workspaces/project/tsconfig.json", Stringtestutil.Dedent("
							{
								\"compilerOptions\": {
									\"composite\": true, \"declaration\": true
								},
								\"files\": [
									\"a.ts\",
									\"b.ts\"
								]
							}"));
					}
				}
			] : Array<TscEdit>)
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("configFileErrors");
	}
}

public static function TestBuildDemoProject() {

	var getBuildDemoFileMap = function(modify:(FileMap) -> Void):FileMap {
		var files = ([
			"/user/username/projects/demo/animals/animal.ts" => Stringtestutil.Dedent("
				export type Size = \"small\" | \"medium\" | \"large\";
				export default interface Animal {
					size: Size;
				}
			"),
			"/user/username/projects/demo/animals/dog.ts" => Stringtestutil.Dedent("
				import Animal from '.';
				import { makeRandomName } from '../core/utilities';

				export interface Dog extends Animal {
					woof(): void;
					name: string;
				}

				export function createDog(): Dog {
					return ({
						size: \"medium\",
						woof: function(this: Dog) {
							console.log(" + "`" + "${ this.name } says \"Woof\"!" + "`" + ");
						},
						name: makeRandomName()
					});
				}
			"),
			"/user/username/projects/demo/animals/index.ts" => Stringtestutil.Dedent("
				import Animal from './animal';

				export default Animal;
				import { createDog, Dog } from './dog';
				export { createDog, Dog };
			"),
			"/user/username/projects/demo/animals/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"../tsconfig-base.json\",
					\"compilerOptions\": {
						\"outDir\": \"../lib/animals\",
						\"rootDir\": \".\"
					},
					\"references\": [
						{ \"path\": \"../core\" }
					]
				}
			"),
			"/user/username/projects/demo/core/utilities.ts" => Stringtestutil.Dedent("

				export function makeRandomName() {
					return \"Bob!?! \";
				}

				export function lastElementOf<T>(arr: T[]): T | undefined {
					if (arr.length === 0) return undefined;
					return arr[arr.length - 1];
				}
			"),
			"/user/username/projects/demo/core/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"../tsconfig-base.json\",
					\"compilerOptions\": {
						\"outDir\": \"../lib/core\",
						\"rootDir\": \".\"
					},
				}
			"),
			"/user/username/projects/demo/zoo/zoo.ts" => Stringtestutil.Dedent("
				import { Dog, createDog } from '../animals/index';

				export function createZoo(): Array<Dog> {
					return [
						createDog()
					];
				}
			"),
			"/user/username/projects/demo/zoo/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"../tsconfig-base.json\",
					\"compilerOptions\": {
						\"outDir\": \"../lib/zoo\",
						\"rootDir\": \".\"
					},
					\"references\": [
						{
							\"path\": \"../animals\"
						}
					]
				}
			"),
			"/user/username/projects/demo/tsconfig-base.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"declaration\": true,
						\"target\": \"es5\",
						\"module\": \"commonjs\",
						\"strict\": true,
						\"noUnusedLocals\": true,
						\"noUnusedParameters\": true,
						\"noImplicitReturns\": true,
						\"noFallthroughCasesInSwitch\": true,
						\"composite\": true,
					},
				}
			"),
			"/user/username/projects/demo/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"files\": [],
					\"references\": [
						{
							\"path\": \"./core\"
						},
						{
							\"path\": \"./animals\",
						},
						{
							\"path\": \"./zoo\",
						},
					],
				}
			")
		] : FileMap);
		if (modify != null) {
			modify(files);
		}
		return files;
	};
	var testCases = ([
		{
			subScenario:     "in master branch with everything setup correctly and reports no error",
			files:           getBuildDemoFileMap(null),
			cwd:             "/user/username/projects/demo",
			commandLineArgs: ["--b", "--verbose"],
			edits:           noChangeOnlyEdit
		},
		{
			subScenario: "in circular branch reports the error about it by stopping build",
			files: getBuildDemoFileMap(function(files:FileMap) {
				files["/user/username/projects/demo/core/tsconfig.json"] = Stringtestutil.Dedent("
					{
						\"extends\": \"../tsconfig-base.json\",
						\"compilerOptions\": {
							\"outDir\": \"../lib/core\",
							\"rootDir\": \".\"
						},
						\"references\": [
							{
								\"path\": \"../zoo\",
							}
						]
					}
				");
			}),
			cwd:             "/user/username/projects/demo",
			commandLineArgs: ["--b", "--verbose"]
		},
		{
			// !!! sheetal - this has missing errors from strada about files not in rootDir (3)
			subScenario: "in bad-ref branch reports the error about files not in rootDir at the import location",
			files: getBuildDemoFileMap(function(files:FileMap) {
				files["/user/username/projects/demo/core/utilities.ts"] = "import * as A from '../animals'
" + (files["/user/username/projects/demo/core/utilities.ts"] : String);
			}),
			cwd:             "/user/username/projects/demo",
			commandLineArgs: ["--b", "--verbose"]
		},
		{
			subScenario: "in circular is set in the reference",
			files: getBuildDemoFileMap(function(files:FileMap) {
				files["/user/username/projects/demo/a/tsconfig.json"] = Stringtestutil.Dedent("
				{
					\"extends\": \"../tsconfig-base.json\",
					\"compilerOptions\": {
						\"outDir\": \"../lib/a\",
						\"rootDir\": \".\"
					},
					\"references\": [
						{
							\"path\": \"../b\",
							\"circular\": true
						}
					]
				}");
				files["/user/username/projects/demo/b/tsconfig.json"] = Stringtestutil.Dedent("
				{
					\"extends\": \"../tsconfig-base.json\",
					\"compilerOptions\": {
						\"outDir\": \"../lib/b\",
						\"rootDir\": \".\"
					},
					\"references\": [
						{
							\"path\": \"../a\",
						}
					]
				}");
				files["/user/username/projects/demo/a/index.ts"] = "export const a = 10;";
				files["/user/username/projects/demo/b/index.ts"] = "export const b = 10;";
				files["/user/username/projects/demo/tsconfig.json"] = Stringtestutil.Dedent("
				{
					\"files\": [],
					\"references\": [
						{
							\"path\": \"./core\"
						},
						{
							\"path\": \"./animals\",
						},
						{
							\"path\": \"./zoo\",
						},
						{
							\"path\": \"./a\",
						},
						{
							\"path\": \"./b\",
						},
					],
				}");
			}),
			cwd:             "/user/username/projects/demo",
			commandLineArgs: ["--b", "--verbose"]
		},
		{
			subScenario: "updates with circular reference",
			files: getBuildDemoFileMap(function(files:FileMap) {
				files["/user/username/projects/demo/core/tsconfig.json"] = Stringtestutil.Dedent("
					{
						\"extends\": \"../tsconfig-base.json\",
						\"compilerOptions\": {
							\"outDir\": \"../lib/core\",
							\"rootDir\": \".\"
						},
						\"references\": [
							{
								\"path\": \"../zoo\",
							}
						]
					}
				");
			}),
			cwd:             "/user/username/projects/demo",
			commandLineArgs: ["--b", "-w", "--verbose"],
			edits: ([
				{
					caption: "Fix error",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/user/username/projects/demo/core/tsconfig.json", Stringtestutil.Dedent("
							{
								\"extends\": \"../tsconfig-base.json\",
								\"compilerOptions\": {
									\"outDir\": \"../lib/core\",
									\"rootDir\": \".\"
								},
							}
						"));
					}
				}
			] : Array<TscEdit>)
		},
		{
			// !!! sheetal - this has missing errors from strada about files not in rootDir (3)
			subScenario: "updates with bad reference",
			files: getBuildDemoFileMap(function(files:FileMap) {
				files["/user/username/projects/demo/core/utilities.ts"] = "import * as A from '../animals'
" + (files["/user/username/projects/demo/core/utilities.ts"] : String);
			}),
			cwd:             "/user/username/projects/demo",
			commandLineArgs: ["--b", "-w", "--verbose"],
			edits: ([
				{
					caption: "Prepend a line",
					edit: function(sys:TestSys) {
						sys.prependFile("/user/username/projects/demo/core/utilities.ts", "\n");
					}
				}
			] : Array<TscEdit>)
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("demo");
	}
}

public static function TestBuildEmitDeclarationOnly() {
	var getBuildEmitDeclarationOnlyImportFileMap = function(declarationMap:Bool, circularRef:Bool):FileMap {
		var files = ([
			"/home/src/workspaces/project/src/a.ts" => Stringtestutil.Dedent("
				import { B } from \"./b\";

				export interface A {
					b: B;
				}
			"),
			"/home/src/workspaces/project/src/b.ts" => Stringtestutil.Dedent("
				import { C } from \"./c\";

				export interface B {
					b: C;
				}
			"),
			"/home/src/workspaces/project/src/c.ts" => Stringtestutil.Dedent("
				import { A } from \"./a\";

				export interface C {
					a: A;
				}
			"),
			"/home/src/workspaces/project/src/index.ts" => Stringtestutil.Dedent("
				export { A } from \"./a\";
				export { B } from \"./b\";
				export { C } from \"./c\";
			"),
			"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent(sprintf("
				{
					\"compilerOptions\": {
						\"incremental\": true,
						\"target\": \"es5\",
						\"module\": \"commonjs\",
						\"declaration\": true,
						\"declarationMap\": %t,
						\"sourceMap\": true,
						\"outDir\": \"./lib\",
						\"composite\": true,
						\"strict\": true,
						\"esModuleInterop\": true,
						\"alwaysStrict\": true,
						\"rootDir\": \"src\",
						\"emitDeclarationOnly\": true,
					},
				}", declarationMap))
		] : FileMap);
		if (!circularRef) {
			files.remove("/home/src/workspaces/project/src/index.ts");
			files["/home/src/workspaces/project/src/a.ts"] = Stringtestutil.Dedent("
				export class B { prop = \"hello\"; }

				export interface A {
					b: B;
				}
			");
		}
		return files;
	};
	var getBuildEmitDeclarationOnlyTestCase = function(declarationMap:Bool):TscInput {
		return ({
			subScenario:     "only dts output in circular import project with emitDeclarationOnly" + Core.IfElse(declarationMap, " and declarationMap", ""),
			files:           getBuildEmitDeclarationOnlyImportFileMap(declarationMap, true),
			commandLineArgs: ["--b", "--verbose"],
			edits: ([
				{
					caption: "incremental-declaration-changes",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/project/src/a.ts", "b: B;", "b: B; foo: any;");
					}
				}
			] : Array<TscEdit>)
		} : TscInput);
	};
	var testCases = ([
		getBuildEmitDeclarationOnlyTestCase(false),
		getBuildEmitDeclarationOnlyTestCase(true),
		{
			subScenario:     "only dts output in non circular imports project with emitDeclarationOnly",
			files:           getBuildEmitDeclarationOnlyImportFileMap(true, false),
			commandLineArgs: ["--b", "--verbose"],
			edits: ([
				{
					caption: "incremental-declaration-doesnt-change",
					edit: function(sys:TestSys) {
						sys.replaceFileText(
							"/home/src/workspaces/project/src/a.ts",
							"export interface A {",
							Stringtestutil.Dedent("
								class C { }
								export interface A {")
						);
					}
				},
				{
					caption: "incremental-declaration-changes",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/project/src/a.ts", "b: B;", "b: B; foo: any;");
					}
				}
			] : Array<TscEdit>)
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("emitDeclarationOnly");
	}
}

public static function TestBuildFileDelete() {
	var testCases = ([
		{
			subScenario: "detects deleted file",
			files: ([
				"/home/src/workspaces/solution/child/child.ts" => Stringtestutil.Dedent("
					import { child2 } from \"../child/child2\";
					export function child() {
						child2();
					}
				"),
				"/home/src/workspaces/solution/child/child2.ts" => Stringtestutil.Dedent("
					export function child2() {
					}
				"),
				"/home/src/workspaces/solution/child/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": { \"composite\": true }
					}
				"),
				"/home/src/workspaces/solution/main/main.ts" => Stringtestutil.Dedent("
                    import { child } from \"../child/child\";
                    export function main() {
                        child();
                    }
                "),
				"/home/src/workspaces/solution/main/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": { \"composite\": true },
						\"references\": [{ \"path\": \"../child\" }],
					}
				")
			] : FileMap),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "main/tsconfig.json", "-v", "--traceResolution", "--explainFiles"],
			edits: ([
				{
					caption: "delete child2 file",
					edit: function(sys:TestSys) {
						sys.removeNoError("/home/src/workspaces/solution/child/child2.ts");
						sys.removeNoError("/home/src/workspaces/solution/child/child2.js");
						sys.removeNoError("/home/src/workspaces/solution/child/child2.d.ts");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "deleted file without composite",
			files: ([
				"/home/src/workspaces/solution/child/child.ts" => Stringtestutil.Dedent("
					import { child2 } from \"../child/child2\";
					export function child() {
						child2();
					}
				"),
				"/home/src/workspaces/solution/child/child2.ts" => Stringtestutil.Dedent("
					export function child2() {
					}
				"),
				"/home/src/workspaces/solution/child/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": { }
					}
				")
			] : FileMap),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "child/tsconfig.json", "-v", "--traceResolution", "--explainFiles"],
			edits: ([
				{
					caption: "delete child2 file",
					edit: function(sys:TestSys) {
						sys.removeNoError("/home/src/workspaces/solution/child/child2.ts");
						sys.removeNoError("/home/src/workspaces/solution/child/child2.js");
					}
				}
			] : Array<TscEdit>)
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("fileDelete");
	}
}

public static function TestBuildDependencyUpdate() {
	var testCases = ([
		{
			// https://github.com/microsoft/typescript-go/issues/2666
			subScenario: "rebuilds when dependency in node_modules is updated",
			files: ([
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
							\"outDir\": \"dist\",
							\"strict\": true
						},
						\"include\": [\"src/**/*\"]
					}
				"),
				"/home/src/workspaces/project/src/index.ts" => Stringtestutil.Dedent("
					import { myValue } from \"my-dep\";
					export const value: string = myValue;
				"),
				"/home/src/workspaces/project/node_modules/my-dep/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"my-dep\",
						\"version\": \"1.0.0\",
						\"types\": \"index.d.ts\"
					}
				"),
				"/home/src/workspaces/project/node_modules/my-dep/index.d.ts" => "export declare const myValue: string;"
			] : FileMap),
			cwd:             "/home/src/workspaces/project",
			commandLineArgs: ["--b", "--verbose"],
			edits: ([
				noChange,
				{
					caption: "update dependency d.ts with breaking type change",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/home/src/workspaces/project/node_modules/my-dep/index.d.ts", "export declare const myValue: number;");
					}
				},
				{
					caption: "restore dependency d.ts",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/home/src/workspaces/project/node_modules/my-dep/index.d.ts", "export declare const myValue: string;");
					}
				},
				{
					caption: "update dependency d.ts timestamp without changing text",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/home/src/workspaces/project/node_modules/my-dep/index.d.ts", "export declare const myValue: string;");
					}
				},
				noChange,
				{
					caption: "delete dependency d.ts",
					edit: function(sys:TestSys) {
						sys.removeNoError("/home/src/workspaces/project/node_modules/my-dep/index.d.ts");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "rebuilds when missing dependency package json is added",
			files: ([
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
							\"outDir\": \"dist\",
							\"strict\": true
						},
						\"include\": [\"src/**/*\"]
					}
				"),
				"/home/src/workspaces/project/src/index.ts" => Stringtestutil.Dedent("
					import { myValue } from \"my-dep\";
					export const value: string = myValue;
				"),
				"/home/src/workspaces/project/node_modules/my-dep/index.d.ts" => "export declare const myValue: string;",
				"/home/src/workspaces/project/node_modules/my-dep/alt.d.ts" =>   "export declare const myValue: number;"
			] : FileMap),
			cwd:             "/home/src/workspaces/project",
			commandLineArgs: ["--b", "--verbose"],
			edits: ([
				{
					caption: "add package json redirecting types to a declaration file with a breaking type change",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/home/src/workspaces/project/node_modules/my-dep/package.json", "{\"types\":\"alt.d.ts\"}");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "rebuilds when dependency package json redirects to a different declaration file",
			files: ([
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
							\"outDir\": \"dist\",
							\"strict\": true
						},
						\"include\": [\"src/**/*\"]
					}
				"),
				"/home/src/workspaces/project/src/index.ts" => Stringtestutil.Dedent("
					import { myValue } from \"my-dep\";
					export const value: string = myValue;
				"),
				"/home/src/workspaces/project/node_modules/my-dep/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"my-dep\",
						\"version\": \"1.0.0\",
						\"types\": \"index.d.ts\"
					}
				"),
				"/home/src/workspaces/project/node_modules/my-dep/index.d.ts" => "export declare const myValue: string;",
				"/home/src/workspaces/project/node_modules/my-dep/alt.d.ts" =>   "export declare const myValue: number;"
			] : FileMap),
			cwd:             "/home/src/workspaces/project",
			commandLineArgs: ["--b", "--verbose"],
			edits: ([
				{
					caption: "redirect package types to a declaration file with a breaking type change",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/project/node_modules/my-dep/package.json", "index.d.ts", "alt.d.ts");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "rebuilds when absolute non-root dependency is updated",
			files: ([
				"C:/work/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
							\"outDir\": \"dist\",
							\"paths\": {
								\"abs-dep\": [\"D:/work/deps/dep.d.ts\"]
							},
							\"strict\": true
						},
						\"include\": [\"src/**/*\"]
					}
				"),
				"C:/work/project/src/index.ts" => Stringtestutil.Dedent("
					import { myValue } from \"abs-dep\";
					export const value: string = myValue;
				"),
				"D:/work/deps/dep.d.ts" => "export declare const myValue: string;"
			] : FileMap),
			cwd:              "C:/work/project",
			windowsStyleRoot: "C:/",
			ignoreCase:       true,
			commandLineArgs:  ["--b", "--verbose"],
			edits: ([
				{
					caption: "update absolute non-root dependency with breaking type change",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("D:/work/deps/dep.d.ts", "export declare const myValue: number;");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "watches absolute non-root dependency updates",
			files: ([
				"C:/work/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
							\"outDir\": \"dist\",
							\"paths\": {
								\"abs-dep\": [\"D:/work/deps/dep.d.ts\"]
							},
							\"strict\": true
						},
						\"include\": [\"src/**/*\"]
					}
				"),
				"C:/work/project/src/index.ts" => Stringtestutil.Dedent("
					import { myValue } from \"abs-dep\";
					export const value: string = myValue;
				"),
				"D:/work/deps/dep.d.ts" => "export declare const myValue: string;"
			] : FileMap),
			cwd:              "C:/work/project",
			windowsStyleRoot: "C:/",
			ignoreCase:       true,
			commandLineArgs:  ["--b", "--verbose", "--watch"],
			edits: ([
				{
					caption: "update absolute non-root dependency with breaking type change",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("D:/work/deps/dep.d.ts", "export declare const myValue: number;");
					}
				}
			] : Array<TscEdit>)
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("dependencyUpdate");
	}
}

public static function TestBuildInferredTypeFromTransitiveModule() {
	var getBuildInferredTypeFromTransitiveModuleMap = function(isolatedModules:Bool, lazyExtraContents:String):FileMap {
		return ([
			"/home/src/workspaces/project/bar.ts" => Stringtestutil.Dedent("
				interface RawAction {
					(...args: any[]): Promise<any> | void;
				}
				interface ActionFactory {
					<T extends RawAction>(target: T): T;
				}
				declare function foo<U extends any[] = any[]>(): ActionFactory;
				export default foo()(function foobar(param: string): void {
				});
			"),
			"/home/src/workspaces/project/bundling.ts" => Stringtestutil.Dedent("
				export class LazyModule<TModule> {
					constructor(private importCallback: () => Promise<TModule>) {}
				}

				export class LazyAction<
					TAction extends (...args: any[]) => any,
					TModule
				>  {
					constructor(_lazyModule: LazyModule<TModule>, _getter: (module: TModule) => TAction) {
					}
				}
			"),
			"/home/src/workspaces/project/global.d.ts" => Stringtestutil.Dedent("
				interface PromiseConstructor {
					new <T>(): Promise<T>;
				}
				declare var Promise: PromiseConstructor;
				interface Promise<T> {
				}
			"),
			"/home/src/workspaces/project/index.ts" => Stringtestutil.Dedent("
				import { LazyAction, LazyModule } from './bundling';
				const lazyModule = new LazyModule(() =>
					import('./lazyIndex')
				);
				export const lazyBar = new LazyAction(lazyModule, m => m.bar);
			"),
			"/home/src/workspaces/project/lazyIndex.ts" => Stringtestutil.Dedent("
				export { default as bar } from './bar';
			") + lazyExtraContents,
			"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent(sprintf("
				{
					\"compilerOptions\": {
						\"target\": \"es5\",
						\"declaration\": true,
						\"outDir\": \"obj\",
						\"incremental\": true,
						\"isolatedModules\": %t,
					},
				}", isolatedModules))
		] : FileMap);
	};
	var testCases = ([
		{
			subScenario:     "inferred type from transitive module",
			files:           getBuildInferredTypeFromTransitiveModuleMap(false, ""),
			commandLineArgs: ["--b", "--verbose"],
			edits: ([
				{
					caption: "incremental-declaration-changes",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/project/bar.ts", "param: string", "");
					}
				},
				{
					caption: "incremental-declaration-changes",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/project/bar.ts", "foobar()", "foobar(param: string)");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario:     "inferred type from transitive module with isolatedModules",
			files:           getBuildInferredTypeFromTransitiveModuleMap(true, ""),
			commandLineArgs: ["--b", "--verbose"],
			edits: ([
				{
					caption: "incremental-declaration-changes",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/project/bar.ts", "param: string", "");
					}
				},
				{
					caption: "incremental-declaration-changes",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/project/bar.ts", "foobar()", "foobar(param: string)");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "reports errors in files affected by change in signature with isolatedModules",
			files: getBuildInferredTypeFromTransitiveModuleMap(true, Stringtestutil.Dedent("
				import { default as bar } from './bar';
				bar(\"hello\");
			")),
			commandLineArgs: ["--b", "--verbose"],
			edits: ([
				{
					caption: "incremental-declaration-changes",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/project/bar.ts", "param: string", "");
					}
				},
				{
					caption: "incremental-declaration-changes",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/project/bar.ts", "foobar()", "foobar(param: string)");
					}
				},
				{
					caption: "incremental-declaration-changes",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/project/bar.ts", "param: string", "");
					}
				},
				{
					caption: "Fix Error",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/project/lazyIndex.ts", "bar(\"hello\")", "bar()");
					}
				}
			] : Array<TscEdit>)
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("inferredTypeFromTransitiveModule");
	}
}

public static function TestBuildInferredTypeFromMonorepoReference() {
	var testCases = ([
		{
			subScenario: "inferred type from referenced project that references another project in monorepo",
			files: ([
				// Root package.json and tsconfig.json
				"/home/src/workspaces/solution/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"tsgo-monorepo-issue\",
						\"private\": true,
						\"workspaces\": [\"packages/*\"]
					}"),
				"/home/src/workspaces/solution/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"files\": [],
						\"include\": [],
						\"references\": [
							{ \"path\": \"packages/package-a\" },
							{ \"path\": \"packages/package-b\" },
							{ \"path\": \"packages/package-c\" }
						]
					}"),
				// package-c: exports MyType interface
				"/home/src/workspaces/solution/packages/package-c/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"package-c\",
						\"version\": \"1.0.0\",
						\"private\": true,
						\"type\": \"module\",
						\"main\": \"./src/index.ts\",
						\"types\": \"./src/index.ts\",
						\"exports\": {
							\".\": \"./src/index.ts\"
						}
					}"),
				"/home/src/workspaces/solution/packages/package-c/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
							\"declaration\": true,
							\"emitDeclarationOnly\": true,
							\"module\": \"ESNext\",
							\"moduleResolution\": \"Bundler\",
							\"target\": \"ES2022\",
							\"outDir\": \"./out\",
							\"rootDir\": \"./src\"
						},
						\"include\": [\"src/**/*\"]
					}"),
				"/home/src/workspaces/solution/packages/package-c/src/index.ts" => Stringtestutil.Dedent("
					export interface MyType {
						id: string;
						name: string;
						enabled: boolean;
					}"),
				// package-b: project reference to package-c, exports createThing() returning MyType
				"/home/src/workspaces/solution/packages/package-b/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"package-b\",
						\"version\": \"1.0.0\",
						\"private\": true,
						\"type\": \"module\",
						\"main\": \"./src/index.ts\",
						\"types\": \"./src/index.ts\",
						\"exports\": {
							\".\": \"./src/index.ts\"
						},
						\"dependencies\": {
							\"package-c\": \"workspace:*\"
						}
					}"),
				"/home/src/workspaces/solution/packages/package-b/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
							\"declaration\": true,
							\"emitDeclarationOnly\": true,
							\"module\": \"ESNext\",
							\"moduleResolution\": \"Bundler\",
							\"target\": \"ES2022\",
							\"outDir\": \"./out\",
							\"rootDir\": \"./src\"
						},
						\"include\": [\"src/**/*\"],
						\"references\": [{ \"path\": \"../package-c\" }]
					}"),
				"/home/src/workspaces/solution/packages/package-b/src/index.ts" => Stringtestutil.Dedent("
					import type { MyType } from \"package-c\";

					export function createThing(input: MyType): MyType {
						return { ...input };
					}"),
				// package-a: project reference to package-b only (not package-c), uses createThing() without type annotation
				"/home/src/workspaces/solution/packages/package-a/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"package-a\",
						\"version\": \"1.0.0\",
						\"private\": true,
						\"type\": \"module\",
						\"main\": \"./src/index.ts\",
						\"types\": \"./src/index.ts\",
						\"exports\": {
							\".\": \"./src/index.ts\"
						},
						\"dependencies\": {
							\"package-b\": \"workspace:*\"
						}
					}"),
				"/home/src/workspaces/solution/packages/package-a/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
							\"declaration\": true,
							\"emitDeclarationOnly\": true,
							\"module\": \"ESNext\",
							\"moduleResolution\": \"Bundler\",
							\"target\": \"ES2022\",
							\"outDir\": \"./out\",
							\"rootDir\": \"./src\"
						},
						\"include\": [\"src/**/*\"],
						\"references\": [{ \"path\": \"../package-b\" }]
					}"),
				"/home/src/workspaces/solution/packages/package-a/src/index.ts" => Stringtestutil.Dedent("
					import { createThing } from \"package-b\";

					class MyClass {
						public thing = createThing({ id: \"1\", name: \"test\", enabled: true });
					}

					export { MyClass };"),
				// Symlinks for node_modules to simulate pnpm/yarn workspace hoisting
				"/home/src/workspaces/solution/node_modules/package-a" => Vfstest.Symlink("/home/src/workspaces/solution/packages/package-a"),
				"/home/src/workspaces/solution/node_modules/package-b" => Vfstest.Symlink("/home/src/workspaces/solution/packages/package-b"),
				"/home/src/workspaces/solution/node_modules/package-c" => Vfstest.Symlink("/home/src/workspaces/solution/packages/package-c")
			] : FileMap),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "--verbose"]
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("inferredTypeFromMonorepoReference");
	}
}

public static function TestBuildDeclarationEmitForReferencedProjectTypesSubpath() {
	var testCases = ([
		{
			// https://github.com/microsoft/typescript-go/issues/3617
			// This package.json exposes the same files under two exports subpaths
			// (`./src/*` and `./types/*`), so both `import("@scope/dep/src/...")` and
			// `import("@scope/dep/types/...")` are technically valid module specifiers for
			// the inferred type. The point of this test is not that one is "correct" and
			// the other "wrong", but that we pick the same one Strada does: when ranking
			// candidate paths, project-reference redirects (here the emitted `./types`
			// `.d.ts`) sort ahead of non-redirect paths (the symlinked `./src` source).
			// A regression in `comparePathsByRedirect` had inverted that ordering, causing
			// the `./src/*` specifier to win instead.
			subScenario: "declaration emit names referenced project type via types subpath",
			files: ([
				"/home/src/workspaces/solution/packages/dep/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"@scope/dep\",
						\"version\": \"1.0.0\",
						\"exports\": {
							\"./src/*\": \"./src/*\",
							\"./types/*\": \"./types/*\",
							\".\": { \"types\": \"./types/index.d.ts\", \"default\": \"./src/index.ts\" }
						}
					}"),
				"/home/src/workspaces/solution/packages/dep/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
							\"declaration\": true,
							\"emitDeclarationOnly\": true,
							\"module\": \"esnext\",
							\"moduleResolution\": \"bundler\",
							\"rootDir\": \"src\",
							\"outDir\": \"types\",
							\"declarationDir\": \"types\",
							\"strict\": true
						},
						\"include\": [\"src\"]
					}"),
				"/home/src/workspaces/solution/packages/dep/src/index.ts" => Stringtestutil.Dedent("
					import type { ComponentTypes as NewComponentTypes } from \"./themes/componentTypes/index.js\"
					export type { NewComponentTypes }"),
				"/home/src/workspaces/solution/packages/dep/src/themes/componentTypes/index.ts" => Stringtestutil.Dedent("
					import type FormFieldLayout from \"./formFieldLayout.js\"
					export type ComponentTypes = {
						formFieldLayout: () => FormFieldLayout
					}"),
				"/home/src/workspaces/solution/packages/dep/src/themes/componentTypes/formFieldLayout.ts" => Stringtestutil.Dedent("
					export type FormFieldLayout = {
						textColor: string
						fontSize: string
					}
					export default FormFieldLayout"),
				"/home/src/workspaces/solution/packages/consumer/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"@scope/consumer\",
						\"version\": \"1.0.0\"
					}"),
				"/home/src/workspaces/solution/packages/consumer/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
							\"declaration\": true,
							\"emitDeclarationOnly\": true,
							\"module\": \"esnext\",
							\"moduleResolution\": \"bundler\",
							\"rootDir\": \"src\",
							\"outDir\": \"types\",
							\"declarationDir\": \"types\",
							\"strict\": true
						},
						\"include\": [\"src\"],
						\"references\": [{ \"path\": \"../dep\" }]
					}"),
				"/home/src/workspaces/solution/packages/consumer/src/index.ts" => Stringtestutil.Dedent("
					import type { NewComponentTypes } from \"@scope/dep\"
					declare const c: NewComponentTypes
					export const style = c.formFieldLayout()"),
				"/home/src/workspaces/solution/node_modules/@scope/dep" =>      Vfstest.Symlink("/home/src/workspaces/solution/packages/dep"),
				"/home/src/workspaces/solution/node_modules/@scope/consumer" => Vfstest.Symlink("/home/src/workspaces/solution/packages/consumer")
			] : FileMap),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "packages/consumer", "--verbose"]
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("declarationEmitForReferencedProjectTypesSubpath");
	}
}

public static function TestBuildJavascriptProjectEmit() {
	var testCases = ([
		{
			// !!! sheetal errors seem different
			subScenario: "loads js-based projects and emits them correctly",
			files: ([
				"/home/src/workspaces/solution/common/nominal.js" => Stringtestutil.Dedent("
                    /**
                     * @template T, Name
                     * @typedef {T & {[Symbol.species]: Name}} Nominal
                     */
                    module.exports = {};
				"),
				"/home/src/workspaces/solution/common/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"extends\": \"../tsconfig.base.json\",
						\"compilerOptions\": {
							\"composite\": true,
						},
						\"include\": [\"nominal.js\"],
					}
				"),
				"/home/src/workspaces/solution/sub-project/index.js" => Stringtestutil.Dedent("
                    import { Nominal } from '../common/nominal';

                    /**
                     * @typedef {Nominal<string, 'MyNominal'>} MyNominal
                     */
				"),
				"/home/src/workspaces/solution/sub-project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"../tsconfig.base.json\",
					\"compilerOptions\": {
						\"composite\": true,
					},
					\"references\": [
						{ \"path\": \"../common\" },
					],
					\"include\": [\"./index.js\"],
				}"),
				"/home/src/workspaces/solution/sub-project-2/index.js" => Stringtestutil.Dedent("
                    import { MyNominal } from '../sub-project/index';

                    const variable = {
                        key: /** @type {MyNominal} */('value'),
                    };

                    /**
                     * @return {keyof typeof variable}
                     */
                    export function getVar() {
                        return 'key';
                    }
				"),
				"/home/src/workspaces/solution/sub-project-2/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"extends\": \"../tsconfig.base.json\",
                    \"compilerOptions\": {
                        \"composite\": true,
                    },
                    \"references\": [
                        { \"path\": \"../sub-project\" },
                    ],
                    \"include\": [\"./index.js\"],
                }"),
				"/home/src/workspaces/solution/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"composite\": true,
                    },
                    \"references\": [
                        { \"path\": \"./sub-project\" },
                        { \"path\": \"./sub-project-2\" },
                    ],
                    \"include\": [],
                }"),
				"/home/src/workspaces/solution/tsconfig.base.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"skipLibCheck\": true,
                        \"rootDir\": \"./\",
                        \"outDir\": \"../lib\",
                        \"allowJs\": true,
                        \"checkJs\": true,
                        \"declaration\": true,
                    },
                }"),
				Tsctests.tscLibPath + "/lib.d.ts" => Strings.Replace(Tsctests.tscDefaultLibContent, "interface SymbolConstructor {", "interface SymbolConstructor {\n    readonly species: symbol;", 1)
			] : FileMap),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b"]
		},
		{
			subScenario: "loads js-based projects with non-moved json files and emits them correctly",
			files: ([
				"/home/src/workspaces/solution/common/obj.json" => Stringtestutil.Dedent("
				{
                    \"val\": 42,
                }"),
				"/home/src/workspaces/solution/common/index.ts" => Stringtestutil.Dedent("
                    import x = require(\"./obj.json\");
                    export = x;
                "),
				"/home/src/workspaces/solution/common/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"extends\": \"../tsconfig.base.json\",
                    \"compilerOptions\": {
                        \"outDir\": null,
                        \"composite\": true,
                    },
                    \"include\": [\"index.ts\", \"obj.json\"],
                }"),
				"/home/src/workspaces/solution/sub-project/index.js" => Stringtestutil.Dedent("
                    import mod from '../common';

                    export const m = mod;
				"),
				"/home/src/workspaces/solution/sub-project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"extends\": \"../tsconfig.base.json\",
                    \"compilerOptions\": {
                        \"composite\": true,
                    },
                    \"references\": [
                        { \"path\": \"../common\" },
                    ],
                    \"include\": [\"./index.js\"],
                }"),
				"/home/src/workspaces/solution/sub-project-2/index.js" => Stringtestutil.Dedent("
                    import { m } from '../sub-project/index';

                    const variable = {
                        key: m,
                    };

                    export function getVar() {
                        return variable;
                    }
				"),
				"/home/src/workspaces/solution/sub-project-2/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"../tsconfig.base.json\",
					\"compilerOptions\": {
						\"composite\": true,
					},
                    \"references\": [
                        { \"path\": \"../sub-project\" },
                    ],
                    \"include\": [\"./index.js\"],
                }"),
				"/home/src/workspaces/solution/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
					},
					\"references\": [
						{ \"path\": \"./sub-project\" },
						{ \"path\": \"./sub-project-2\" },
                    ],
                    \"include\": [],
                }"),
				"/home/src/workspaces/solution/tsconfig.base.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"skipLibCheck\": true,
						\"rootDir\": \"./\",
						\"outDir\": \"../out\",
						\"allowJs\": true,
						\"checkJs\": true,
						\"resolveJsonModule\": true,
						\"esModuleInterop\": true,
						\"declaration\": true,
					},
                }")
			] : FileMap),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["-b"]
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("javascriptProjectEmit");
	}
}

public static function TestBuildLateBoundSymbol() {
	var testCases = ([
		{
			subScenario: "interface is merged and contains late bound member",
			files: ([
				"/home/src/workspaces/project/src/globals.d.ts" => Stringtestutil.Dedent("
                    interface SymbolConstructor {
                        (description?: string | number): symbol;
                    }
                    declare var Symbol: SymbolConstructor;
                "),
				"/home/src/workspaces/project/src/hkt.ts" => "export interface HKT<T> { }",
				"/home/src/workspaces/project/src/main.ts" => Stringtestutil.Dedent("
                    import { HKT } from \"./hkt\";

                    const sym = Symbol();

                    declare module \"./hkt\" {
                        interface HKT<T> {
                            [sym]: { a: T }
                        }
                    }
                    const x = 10;
                    type A = HKT<number>[typeof sym];
                "),
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"rootDir\": \"src\",
                        \"incremental\": true,
                    },
                }")
			] : FileMap),
			commandLineArgs: ["--b", "--verbose"],
			edits: ([
				{
					caption: "incremental-declaration-doesnt-change",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/project/src/main.ts", "const x = 10;", "");
					}
				},
				{
					caption: "incremental-declaration-doesnt-change",
					edit: function(sys:TestSys) {
						sys.appendFile("/home/src/workspaces/project/src/main.ts", "const x = 10;");
					}
				}
			] : Array<TscEdit>)
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("lateBoundSymbol");
	}
}

public static function TestBuildModuleSpecifiers() {
	var testCases = ([
		{
			subScenario: "synthesized module specifiers resolve correctly",
			files: ([
				"/home/src/workspaces/packages/solution/common/nominal.ts" => Stringtestutil.Dedent("
                    export declare type Nominal<T, Name extends string> = T & {
                        [Symbol.species]: Name;
                    };
				"),
				"/home/src/workspaces/packages/solution/common/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"extends\": \"../../tsconfig.base.json\",
                    \"compilerOptions\": {
                        \"composite\": true
                    },
                    \"include\": [\"nominal.ts\"]
				}
				"),
				"/home/src/workspaces/packages/solution/sub-project/index.ts" => Stringtestutil.Dedent("
                    import { Nominal } from '../common/nominal';

                    export type MyNominal = Nominal<string, 'MyNominal'>;
				"),
				"/home/src/workspaces/packages/solution/sub-project/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"extends\": \"../../tsconfig.base.json\",
                        \"compilerOptions\": {
                            \"composite\": true
                        },
                        \"references\": [
                            { \"path\": \"../common\" }
                        ],
                        \"include\": [\"./index.ts\"]
                    }
                "),
				"/home/src/workspaces/packages/solution/sub-project-2/index.ts" => Stringtestutil.Dedent("
                    import { MyNominal } from '../sub-project/index';

                    const variable = {
                        key: 'value' as MyNominal,
                    };

                    export function getVar(): keyof typeof variable {
                        return 'key';
                    }
				"),
				"/home/src/workspaces/packages/solution/sub-project-2/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"extends\": \"../../tsconfig.base.json\",
                        \"compilerOptions\": {
                            \"composite\": true
                        },
                        \"references\": [
                            { \"path\": \"../sub-project\" }
                        ],
                        \"include\": [\"./index.ts\"]
                    }
                "),
				"/home/src/workspaces/packages/solution/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": {
                            \"composite\": true
                        },
                        \"references\": [
                            { \"path\": \"./sub-project\" },
                            { \"path\": \"./sub-project-2\" }
                        ],
                        \"include\": []
                    }
                "),
				"/home/src/workspaces/packages/tsconfig.base.json" => Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": {
                            \"skipLibCheck\": true,
                            \"rootDir\": \"./\",
                            \"outDir\": \"lib\"
						}
                    }
                "),
				"/home/src/workspaces/packages/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": {
                            \"composite\": true
                        },
                        \"references\": [
                            { \"path\": \"./solution\" },
                        ],
                        \"include\": [],
                    }
                "),
				Tsctests.tscLibPath + "/lib.d.ts" => Strings.Replace(Tsctests.tscDefaultLibContent, "interface SymbolConstructor {", "interface SymbolConstructor {\n    readonly species: symbol;", 1)
			] : FileMap),
			cwd:             "/home/src/workspaces/packages",
			commandLineArgs: ["-b", "--verbose"]
		},
		{
			subScenario: "synthesized module specifiers across projects resolve correctly",
			files: ([
				"/home/src/workspaces/packages/src-types/index.ts" => Stringtestutil.Dedent("
                    export * from './dogconfig.js';"),
				"/home/src/workspaces/packages/src-types/dogconfig.ts" => Stringtestutil.Dedent("
                    export interface DogConfig {
                        name: string;
					}
				"),
				"/home/src/workspaces/packages/src-dogs/index.ts" => Stringtestutil.Dedent("
                    export * from 'src-types';
                    export * from './lassie/lassiedog.js';
				"),
				"/home/src/workspaces/packages/src-dogs/dogconfig.ts" => Stringtestutil.Dedent("
                    import { DogConfig } from 'src-types';

                    export const DOG_CONFIG: DogConfig = {
                        name: 'Default dog',
                    };
				"),
				"/home/src/workspaces/packages/src-dogs/dog.ts" => Stringtestutil.Dedent("
                    import { DogConfig } from 'src-types';
                    import { DOG_CONFIG } from './dogconfig.js';
                    
                    export abstract class Dog {
                    
                        public static getCapabilities(): DogConfig {
                            return DOG_CONFIG;
                        }
                    }
				"),
				"/home/src/workspaces/packages/src-dogs/lassie/lassiedog.ts" => Stringtestutil.Dedent("
                    import { Dog } from '../dog.js';
                    import { LASSIE_CONFIG } from './lassieconfig.js';
                    
                    export class LassieDog extends Dog {
                        protected static getDogConfig = () => LASSIE_CONFIG;
                    }
				"),
				"/home/src/workspaces/packages/src-dogs/lassie/lassieconfig.ts" => Stringtestutil.Dedent("
                    import { DogConfig } from 'src-types';

                    export const LASSIE_CONFIG: DogConfig = { name: 'Lassie' };
				"),
				"/home/src/workspaces/packages/tsconfig-base.json" => Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": {
                            \"declaration\": true,
                            \"module\": \"node16\",
                        },
                    }
				"),
				"/home/src/workspaces/packages/src-types/package.json" => Stringtestutil.Dedent("
				{
                    \"type\": \"module\",
                    \"exports\": \"./index.js\"
                }"),
				"/home/src/workspaces/packages/src-dogs/package.json" => Stringtestutil.Dedent("
				{
                    \"type\": \"module\",
                    \"exports\": \"./index.js\"
                }"),
				"/home/src/workspaces/packages/src-types/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"extends\": \"../tsconfig-base.json\",
                    \"compilerOptions\": {
                        \"composite\": true,
                    },
                    \"include\": [
                        \"**/*\",
                    ],
                }"),
				"/home/src/workspaces/packages/src-dogs/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"extends\": \"../tsconfig-base.json\",
                    \"compilerOptions\": {
                        \"composite\": true,
                    },
                    \"references\": [
                        { \"path\": \"../src-types\" },
                    ],
                    \"include\": [
                        \"**/*\",
                    ],
                }"),
				"/home/src/workspaces/packages/src-types/node_modules" => Vfstest.Symlink("/home/src/workspaces/packages"),
				"/home/src/workspaces/packages/src-dogs/node_modules" =>  Vfstest.Symlink("/home/src/workspaces/packages")
			] : FileMap),
			cwd:             "/home/src/workspaces/packages",
			commandLineArgs: ["-b", "src-types", "src-dogs", "--verbose"]
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("moduleSpecifiers");
	}
}

public static function TestBuildOutputPaths() {
	// PORT: local type tscOutputPathScenario → class TscOutputPathScenario (top of file).
	var runOutputPaths = function(s:TscOutputPathScenario) {
		var input = ({
			subScenario:     s.subScenario,
			files:           s.files,
			commandLineArgs: ["-b", "-v"],
			edits: ([
				noChange,
				{
					caption:         "Normal build without change, that does not block emit on error to show files that get emitted",
					commandLineArgs: ["-p", "/home/src/workspaces/project/tsconfig.json"]
				}
			] : Array<TscEdit>)
		} : TscInput);
		input.run("outputPaths");
		// PORT: t.Run subtest → T.run, selected by the gate filter like the scenarios; assert.DeepEqual on
		// []string → compare the joined lists.
		if (Gate.Filter == null || Gate.Filter("GetOutputFileNames/" + s.subScenario)) {
			T.run("GetOutputFileNames/" + s.subScenario, function() {
				var sys = Tsctests.newTestSys(input, false);
				var config = Tsoptions.GetParsedCommandLineOfConfigFile("/home/src/workspaces/project/tsconfig.json", new CompilerOptions(), null, sys, null).a;
				T.eq((s.expectedDtsNames == null ? [] : s.expectedDtsNames).join("\n"), [for (f in config.GetOutputFileNames()) f].join("\n"));
			});
		}
	};
	var testCases = ([
		{
			subScenario: "when rootDir is not specified",
			files: ([
				"/home/src/workspaces/project/src/index.ts" => "export const x = 10;",
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"outDir\": \"dist\",
                    },
                }")
			] : FileMap),
			expectedDtsNames: [
				"/home/src/workspaces/project/dist/src/index.js"
			]
		},
		{
			subScenario: "when rootDir is not specified and is composite",
			files: ([
				"/home/src/workspaces/project/src/index.ts" => "export const x = 10;",
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"outDir\": \"dist\",
						\"composite\": true,
                    },
                }")
			] : FileMap),
			expectedDtsNames: [
				"/home/src/workspaces/project/dist/src/index.js",
				"/home/src/workspaces/project/dist/src/index.d.ts"
			]
		},
		{
			subScenario: "when rootDir is specified",
			files: ([
				"/home/src/workspaces/project/src/index.ts" => "export const x = 10;",
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"outDir\": \"dist\",
						\"rootDir\": \"src\",
                    },
                }")
			] : FileMap),
			expectedDtsNames: [
				"/home/src/workspaces/project/dist/index.js"
			]
		},
		{
			// !!! sheetal error missing as not yet implemented
			subScenario: "when rootDir is specified but not all files belong to rootDir",
			files: ([
				"/home/src/workspaces/project/src/index.ts" =>  "export const x = 10;",
				"/home/src/workspaces/project/types/type.ts" => "export type t = string;",
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"outDir\": \"dist\",
						\"rootDir\": \"src\",
                    },
                }")
			] : FileMap),
			expectedDtsNames: [
				"/home/src/workspaces/project/dist/index.js",
				"/home/src/workspaces/project/types/type.js"
			]
		},
		{
			// !!! sheetal error missing as not yet implemented
			subScenario: "when rootDir is specified but not all files belong to rootDir and is composite",
			files: ([
				"/home/src/workspaces/project/src/index.ts" =>  "export const x = 10;",
				"/home/src/workspaces/project/types/type.ts" => "export type t = string;",
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"outDir\": \"dist\",
						\"rootDir\": \"src\",
						\"composite\": true
                    },
                }")
			] : FileMap),
			expectedDtsNames: [
				"/home/src/workspaces/project/dist/index.js",
				"/home/src/workspaces/project/dist/index.d.ts",
				"/home/src/workspaces/project/types/type.js",
				"/home/src/workspaces/project/types/type.d.ts"
			]
		}
	] : Array<TscOutputPathScenario>);
	for (test in testCases) {
		runOutputPaths(test);
	}
}

public static function TestBuildProgramUpdates() {
	var testCases = ([
		{
			subScenario: "when referenced project change introduces error in the down stream project and then fixes it",
			files: ([
				"/user/username/projects/sample1/Library/tsconfig.json" => Stringtestutil.Dedent("
				{ 
					\"compilerOptions\": {
						\"composite\": true
					}
				}"),
				"/user/username/projects/sample1/Library/library.ts" => Stringtestutil.Dedent("
					interface SomeObject
					{
						message: string;
					}

					export function createSomeObject(): SomeObject
					{
						return {
							message: \"new Object\"
						};
					}
				"),
				"/user/username/projects/sample1/App/tsconfig.json" => Stringtestutil.Dedent("
				{ 
					\"references\": [{ \"path\": \"../Library\" }]
				}"),
				"/user/username/projects/sample1/App/app.ts" => Stringtestutil.Dedent("
					import { createSomeObject } from \"../Library/library\";
					createSomeObject().message;
				")
			] : FileMap),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["-b", "-w", "App"],
			edits: ([
				{
					caption: "Introduce error",
					// Change message in library to message2
					edit: function(sys:TestSys) {
						sys.replaceFileTextAll("/user/username/projects/sample1/Library/library.ts", "message", "message2");
					}
				},
				{
					caption: "Fix error",
					// Revert library changes
					edit: function(sys:TestSys) {
						sys.replaceFileTextAll("/user/username/projects/sample1/Library/library.ts", "message2", "message");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "declarationEmitErrors when fixing error files all files are emitted",
			files: ([
				"/user/username/projects/solution/app/fileWithError.ts" => Stringtestutil.Dedent("
					export var myClassWithError = class {
						tags() { }
						private p = 12
					};
				"),
				"/user/username/projects/solution/app/fileWithoutError.ts" => "export class myClass { }",
				"/user/username/projects/solution/app/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true
					}
				}")
			] : FileMap),
			cwd:             "/user/username/projects/solution",
			commandLineArgs: ["-b", "-w", "app"],
			edits: ([
				{
					caption: "Fix error",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/user/username/projects/solution/app/fileWithError.ts", "private p = 12", "");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "declarationEmitErrors when file with no error changes",
			files: ([
				"/user/username/projects/solution/app/fileWithError.ts" => Stringtestutil.Dedent("
					export var myClassWithError = class {
						tags() { }
						private p = 12
					};
				"),
				"/user/username/projects/solution/app/fileWithoutError.ts" => "export class myClass { }",
				"/user/username/projects/solution/app/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true
					}
				}")
			] : FileMap),
			cwd:             "/user/username/projects/solution",
			commandLineArgs: ["-b", "-w", "app"],
			edits: ([
				{
					caption: "Change fileWithoutError",
					edit: function(sys:TestSys) {
						sys.replaceFileTextAll("/user/username/projects/solution/app/fileWithoutError.ts", "myClass", "myClass2");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "declarationEmitErrors introduceError when fixing errors only changed file is emitted",
			files: ([
				"/user/username/projects/solution/app/fileWithError.ts" => Stringtestutil.Dedent("
					export var myClassWithError = class {
						tags() { }
						
					};
				"),
				"/user/username/projects/solution/app/fileWithoutError.ts" => "export class myClass { }",
				"/user/username/projects/solution/app/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true
					}
				}")
			] : FileMap),
			cwd:             "/user/username/projects/solution",
			commandLineArgs: ["-b", "-w", "app"],
			edits: ([
				{
					caption: "Introduce error",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/user/username/projects/solution/app/fileWithError.ts", Stringtestutil.Dedent("
							export var myClassWithError = class {
								tags() { }
								private p = 12
							};
						"));
					}
				},
				{
					caption: "Fix error",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/user/username/projects/solution/app/fileWithError.ts", "private p = 12", "");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "declarationEmitErrors introduceError when file with no error changes",
			files: ([
				"/user/username/projects/solution/app/fileWithError.ts" => Stringtestutil.Dedent("
					export var myClassWithError = class {
						tags() { }
						
					};
				"),
				"/user/username/projects/solution/app/fileWithoutError.ts" => "export class myClass { }",
				"/user/username/projects/solution/app/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true
					}
				}")
			] : FileMap),
			cwd:             "/user/username/projects/solution",
			commandLineArgs: ["-b", "-w", "app"],
			edits: ([
				{
					caption: "Introduce error",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/user/username/projects/solution/app/fileWithError.ts", Stringtestutil.Dedent("
							export var myClassWithError = class {
								tags() { }
								private p = 12
							};
						"));
					}
				},
				{
					caption: "Change fileWithoutError",
					edit: function(sys:TestSys) {
						sys.replaceFileTextAll("/user/username/projects/solution/app/fileWithoutError.ts", "myClass", "myClass2");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "works when noUnusedParameters changes to false",
			files: ([
				"/user/username/projects/myproject/index.ts" => "const fn = (a: string, b: string) => b;",
				"/user/username/projects/myproject/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"noUnusedParameters\": true,
					},
				}")
			] : FileMap),
			cwd:             "/user/username/projects/myproject",
			commandLineArgs: ["-b", "-w"],

			edits: ([
				{
					caption: "Change tsconfig to set noUnusedParameters to false",
					edit: function(sys:TestSys) {
						sys.writeFileNoError(
							"/user/username/projects/myproject/tsconfig.json",
							Stringtestutil.Dedent("
							{
								\"compilerOptions\": {
									\"noUnusedParameters\": false,
								},
							}")
						);
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "works with extended source files",
			cwd:         "/user/username/projects/project",
			files: ([
				"/user/username/projects/project/commonFile1.ts" =>      "let x = 1",
				"/user/username/projects/project/commonFile2.ts" =>      "let y = 1",
				"/user/username/projects/project/alpha.tsconfig.json" => "{}",
				"/user/username/projects/project/project1.tsconfig.json" => Stringtestutil.Dedent("
					{
						\"extends\": \"./alpha.tsconfig.json\",
						\"compilerOptions\": {
							\"composite\": true,
						},
						\"files\": [\"commonFile1.ts\", \"commonFile2.ts\"],
					}
				"),
				"/user/username/projects/project/bravo.tsconfig.json" => Stringtestutil.Dedent("
					{
						\"extends\": \"./alpha.tsconfig.json\",
					}
				"),
				"/user/username/projects/project/other.ts" => "let z = 0;",
				"/user/username/projects/project/project2.tsconfig.json" => Stringtestutil.Dedent("
					{
						\"extends\": \"./bravo.tsconfig.json\",
						\"compilerOptions\": {
							\"composite\": true,
						},
						\"files\": [\"other.ts\"],
					}
				"),
				"/user/username/projects/project/other2.ts" => "let k = 0;",
				"/user/username/projects/project/extendsConfig1.tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
						},
					}
				"),
				"/user/username/projects/project/extendsConfig2.tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"strictNullChecks\": false,
						},
					}
				"),
				"/user/username/projects/project/extendsConfig3.tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"noImplicitAny\": true,
						},
					}
				"),
				"/user/username/projects/project/project3.tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"extends\": [
                        \"./extendsConfig1.tsconfig.json\",
                        \"./extendsConfig2.tsconfig.json\",
                        \"./extendsConfig3.tsconfig.json\",
                    ],
                    \"compilerOptions\": {
                        \"composite\": false,
                    },
                    \"files\": [\"other2.ts\"],
                }")
			] : FileMap),
			commandLineArgs: ["-b", "-w", "-v", "project1.tsconfig.json", "project2.tsconfig.json", "project3.tsconfig.json"],
			edits: ([
				{
					caption: "Modify alpha config",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/user/username/projects/project/alpha.tsconfig.json", Stringtestutil.Dedent("
						{
                            \"compilerOptions\": {
								\"strict\": true
							}
                        }"));
					}
				},
				{
					caption: "change bravo config",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/user/username/projects/project/bravo.tsconfig.json", Stringtestutil.Dedent("
						{
                            \"extends\": \"./alpha.tsconfig.json\",
                            \"compilerOptions\": { \"strict\": false }
                        }"));
					}
				},
				{
					caption: "project 2 extends alpha",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/user/username/projects/project/project2.tsconfig.json", Stringtestutil.Dedent("
						{
                            \"extends\": \"./alpha.tsconfig.json\",
                            \"files\": [\"other.ts\"]
                        }"));
					}
				},
				{
					caption: "update aplha config",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/user/username/projects/project/alpha.tsconfig.json", "{}");
					}
				},
				{
					caption: "Modify extendsConfigFile2",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/user/username/projects/project/extendsConfig2.tsconfig.json", Stringtestutil.Dedent("
						{
                            \"compilerOptions\": { \"strictNullChecks\": true }
                        }"));
					}
				},
				{
					caption: "Modify project 3",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/user/username/projects/project/project3.tsconfig.json", Stringtestutil.Dedent("
						{
                            \"extends\": [\"./extendsConfig1.tsconfig.json\", \"./extendsConfig2.tsconfig.json\"],
                            \"compilerOptions\": { \"composite\": false },
                            \"files\": [\"other2.ts\"],
                        }"));
					}
				},
				{
					caption: "Delete extendedConfigFile2 and report error",
					edit: function(sys:TestSys) {
						sys.removeNoError("/user/username/projects/project/extendsConfig2.tsconfig.json");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "works correctly when project with extended config is removed",
			files: ([
				"/user/username/projects/project/commonFile1.ts" => "let x = 1",
				"/user/username/projects/project/commonFile2.ts" => "let y = 1",
				"/user/username/projects/project/alpha.tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"strict\": true,
                    },
                }"),
				"/user/username/projects/project/project1.tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"extends\": \"./alpha.tsconfig.json\",
                    \"compilerOptions\": {
                        \"composite\": true,
                    },
                    \"files\": [\"commonFile1.ts\", \"commonFile2.ts\"],
                }"),
				"/user/username/projects/project/bravo.tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"strict\": true,
                    },
                }"),
				"/user/username/projects/project/other.ts" => "let z = 0;",
				"/user/username/projects/project/project2.tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"extends\": \"./bravo.tsconfig.json\",
                    \"compilerOptions\": {
                        \"composite\": true,
                    },
                    \"files\": [\"other.ts\"],
                }"),
				"/user/username/projects/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"references\": [
                        {
                            \"path\": \"./project1.tsconfig.json\",
                        },
                        {
                            \"path\": \"./project2.tsconfig.json\",
                        },
                    ],
                    \"files\": [],
                }")
			] : FileMap),
			cwd:             "/user/username/projects/project",
			commandLineArgs: ["-b", "-w", "-v"],
			edits: ([
				{
					caption: "Remove project2 from base config",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/user/username/projects/project/tsconfig.json", Stringtestutil.Dedent("
						{
                            \"references\": [
                                {
                                    \"path\": \"./project1.tsconfig.json\",
                                },
                            ],
                            \"files\": [],
                        }"));
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "tsbuildinfo has error",
			files: ([
				"/user/username/projects/project/main.ts" =>              "export const x = 10;",
				"/user/username/projects/project/tsconfig.json" =>        "{}",
				"/user/username/projects/project/tsconfig.tsbuildinfo" => "Some random string"
			] : FileMap),
			cwd:             "/user/username/projects/project",
			commandLineArgs: ["--b", "-i", "-w"]
		},
		{
			subScenario: "tsbuildinfo has fewer fileInfos than fileNames",
			files: ([
				"/user/username/projects/project/src/a.ts" =>      "export const a = 1;",
				"/user/username/projects/project/src/b.ts" =>      "export const b = 2;",
				"/user/username/projects/project/tsconfig.json" => "{\"compilerOptions\":{\"composite\":true,\"outDir\":\"dist\"},\"files\":[\"src/a.ts\",\"src/b.ts\"]}",
				"/user/username/projects/project/dist/tsconfig.tsbuildinfo" => "{
					\"version\": \"FakeTSVersion\",
					\"fileNames\": [\"lib.es2025.full.d.ts\", \"../src/a.ts\", \"../src/b.ts\"],
					\"fileInfos\": [\"abc123\"],
					\"options\": {\"composite\": true, \"outDir\": \"./\"},
					\"root\": [2, 3]
				}"
			] : FileMap),
			cwd:             "/user/username/projects/project",
			commandLineArgs: ["--b", "-v"]
		},
		{
			subScenario: "when root is source from project reference",
			files: ([
				"/home/src/workspaces/project/lib/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
							\"outDir\": \"./dist\"
						}
					}"),
				"/home/src/workspaces/project/lib/foo.ts" => "export const FOO: string = 'THEFOOEXPORT';",
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"references\": [ { \"path\": \"./lib\" } ]
					}"),
				"/home/src/workspaces/project/index.ts" => "import { FOO } from \"./lib/foo\";"
			] : FileMap),
			commandLineArgs: ["--b"],
			edits: ([
				{
					caption: "dts doesnt change",
					edit: function(sys:TestSys) {
						sys.appendFile("/home/src/workspaces/project/lib/foo.ts", "const Bar = 10;");
					}
				}
			] : Array<TscEdit>),
			cwd: "/home/src/workspaces/project"
		},
		{
			subScenario: "when root is source from project reference with composite",
			files: ([
				"/home/src/workspaces/project/lib/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
							\"outDir\": \"./dist\"
						}
					}"),
				"/home/src/workspaces/project/lib/foo.ts" => "export const FOO: string = 'THEFOOEXPORT';",
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
						},
						\"references\": [ { \"path\": \"./lib\" } ]
					}"),
				"/home/src/workspaces/project/index.ts" => "import { FOO } from \"./lib/foo\";"
			] : FileMap),
			commandLineArgs: ["--b"],
			edits: ([
				{
					caption: "dts doesnt change",
					edit: function(sys:TestSys) {
						sys.appendFile("/home/src/workspaces/project/lib/foo.ts", "const Bar = 10;");
					}
				}
			] : Array<TscEdit>),
			cwd: "/home/src/workspaces/project"
		}
	] : Array<TscInput>);
	for (test in testCases) {
		test.run("programUpdates");
	}
}

public static function TestBuildProjectsBuilding() {
	var addPackageFiles = function(files:FileMap, index:Int) {
		files[sprintf("/user/username/projects/myproject/pkg%d/index.ts", index)] = sprintf("export const pkg%d = %d;", index, index);
		var references = "";
		if (index > 0) {
			references = "\"references\": [{ \"path\": \"../pkg0\" }],";
		}
		files[sprintf("/user/username/projects/myproject/pkg%d/tsconfig.json", index)] = Stringtestutil.Dedent(sprintf("
		{
			\"compilerOptions\": { \"composite\": true },
			%s
		}", references));
	};
	var addSolution = function(files:FileMap, count:Int) {
		var pkgReferences:Array<String> = null;
		for (i in 0...count) {
			pkgReferences = append(pkgReferences, sprintf("{ \"path\": \"./pkg%d\" }", i));
		}
		files["/user/username/projects/myproject/tsconfig.json"] = Stringtestutil.Dedent(sprintf("
		{
			\"compilerOptions\": { \"composite\": true },
			\"references\": [
				%s
			]
		}", pkgReferences.join(",\n\t\t\t\t")));
	};
	var files = function(count:Int):FileMap {
		var files = ([] : FileMap);
		for (i in 0...count) {
			addPackageFiles(files, i);
		}
		addSolution(files, count);
		return files;
	};

	var getTestCases = function(pkgCount:Int, builders:Int):Array<TscInput> {
		var edits = ([
			{
				caption: "dts doesn't change",
				edit: function(sys:TestSys) {
					sys.appendFile("/user/username/projects/myproject/pkg0/index.ts", "const someConst2 = 10;");
				}
			},
			noChange,
			{
				caption: "dts change",
				edit: function(sys:TestSys) {
					sys.appendFile("/user/username/projects/myproject/pkg0/index.ts", "export const someConst = 10;");
				}
			},
			noChange
		] : Array<TscEdit>);
		return ([
			{
				subScenario:     sprintf("when there are %d projects in a solution", pkgCount),
				files:           files(pkgCount),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: ["-b", "-v"],
				edits:           edits
			},
			{
				subScenario:     sprintf("when there are %d projects in a solution with --builders %d", pkgCount, builders),
				files:           files(pkgCount),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: ["-b", "-v", "--builders", Std.string(builders)],
				edits:           edits
			},
			{
				subScenario:     sprintf("when there are %d projects in a solution", pkgCount),
				files:           files(pkgCount),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: ["-b", "-w", "-v"],
				edits:           edits
			},
			{
				subScenario:     sprintf("when there are %d projects in a solution with --builders %d", pkgCount, builders),
				files:           files(pkgCount),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: ["-b", "-w", "-v", "--builders", Std.string(builders)],
				edits:           edits
			}
		] : Array<TscInput>);
	};

	var testCases = Slices.Concat(
		getTestCases(3, 1),
		getTestCases(5, 2),
		getTestCases(8, 3),
		getTestCases(23, 3)
	);

	for (test in testCases) {
		test.run("projectsBuilding");
	}
}

public static function TestBuildProjectReferenceWithRootDirInParent() {
	var getBuildProjectReferenceWithRootDirInParentFileMap = function(modify:(FileMap) -> Void):FileMap {
		var files = ([
			"/home/src/workspaces/solution/src/main/a.ts" => Stringtestutil.Dedent("
				import { b } from './b';
				const a = b;
			"),
			"/home/src/workspaces/solution/src/main/b.ts" => Stringtestutil.Dedent("
				export const b = 0;
			"),
			"/home/src/workspaces/solution/src/main/tsconfig.json" => Stringtestutil.Dedent("
			{
				\"extends\": \"../../tsconfig.base.json\",
				\"references\": [
					{ \"path\": \"../other\" },
				],
			}"),
			"/home/src/workspaces/solution/src/other/other.ts" => Stringtestutil.Dedent("
				export const Other = 0;
			"),
			"/home/src/workspaces/solution/src/other/tsconfig.json" => Stringtestutil.Dedent("
			{
				\"extends\": \"../../tsconfig.base.json\",
			}
			"),
			"/home/src/workspaces/solution/tsconfig.base.json" => Stringtestutil.Dedent("
			{
				\"compilerOptions\": {
					\"composite\": true,
					\"declaration\": true,
					\"rootDir\": \"./src/\",
					\"outDir\": \"./dist/\",
					\"skipDefaultLibCheck\": true,
				},
				\"exclude\": [
					\"node_modules\",
				],
			}")
		] : FileMap);
		if (modify != null) {
			modify(files);
		}
		return files;
	};
	var testCases = ([
		{
			subScenario:     "builds correctly",
			files:           getBuildProjectReferenceWithRootDirInParentFileMap(null),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "src/main", "/home/src/workspaces/solution/src/other"]
		},
		{
			subScenario: "reports error for same tsbuildinfo file because no rootDir in the base",
			files: getBuildProjectReferenceWithRootDirInParentFileMap(
				function(files:FileMap) {
					var text = files["/home/src/workspaces/solution/tsconfig.base.json"];
					files["/home/src/workspaces/solution/tsconfig.base.json"] = Strings.Replace((text : String), "\"rootDir\": \"./src/\",", "", 1);
				}
			),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "src/main", "--verbose"]
		},
		{
			subScenario: "reports error for same tsbuildinfo file",
			files: getBuildProjectReferenceWithRootDirInParentFileMap(
				function(files:FileMap) {
					files["/home/src/workspaces/solution/src/main/tsconfig.json"] = Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": { \"composite\": true, \"outDir\": \"../../dist/\" },
                        \"references\": [{ \"path\": \"../other\" }]
                    }");
					files["/home/src/workspaces/solution/src/other/tsconfig.json"] = Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": { \"composite\": true, \"outDir\": \"../../dist/\" },
                    }");
				}
			),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "src/main", "--verbose"],
			edits:           noChangeOnlyEdit
		},
		{
			subScenario: "reports error for same tsbuildinfo file without incremental",
			files: getBuildProjectReferenceWithRootDirInParentFileMap(
				function(files:FileMap) {
					files["/home/src/workspaces/solution/src/main/tsconfig.json"] = Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": { \"outDir\": \"../../dist/\" },
                        \"references\": [{ \"path\": \"../other\" }]
                    }");
					files["/home/src/workspaces/solution/src/other/tsconfig.json"] = Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": { \"composite\": true, \"outDir\": \"../../dist/\" },
                    }");
				}
			),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "src/main", "--verbose"]
		},
		{
			subScenario: "reports error for same tsbuildinfo file without incremental with tsc",
			files: getBuildProjectReferenceWithRootDirInParentFileMap(
				function(files:FileMap) {
					files["/home/src/workspaces/solution/src/main/tsconfig.json"] = Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": { \"outDir\": \"../../dist/\" },
                        \"references\": [{ \"path\": \"../other\" }]
                    }");
					files["/home/src/workspaces/solution/src/other/tsconfig.json"] = Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": { \"composite\": true, \"outDir\": \"../../dist/\" },
                    }");
				}
			),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "src/other", "--verbose"],
			edits: ([
				{
					caption:         "Running tsc on main",
					commandLineArgs: ["-p", "src/main"]
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "reports no error when tsbuildinfo differ",
			files: getBuildProjectReferenceWithRootDirInParentFileMap(
				function(files:FileMap) {
					files.remove("/home/src/workspaces/solution/src/main/tsconfig.json");
					files.remove("/home/src/workspaces/solution/src/other/tsconfig.json");
					files["/home/src/workspaces/solution/src/main/tsconfig.main.json"] = Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": { \"composite\": true, \"outDir\": \"../../dist/\" },
                        \"references\": [{ \"path\": \"../other/tsconfig.other.json\" }]
                    }");
					files["/home/src/workspaces/solution/src/other/tsconfig.other.json"] = Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": { \"composite\": true, \"outDir\": \"../../dist/\" },
                    }");
				}
			),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "src/main/tsconfig.main.json", "--verbose"],
			edits:           noChangeOnlyEdit
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("projectReferenceWithRootDirInParent");
	}
}

public static function TestBuildReexport() {
	var testCases = ([
		{
			subScenario: "Reports errors correctly",
			files: ([
				"/user/username/projects/reexport/src/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"files\": [],
                    \"include\": [],
                    \"references\": [{ \"path\": \"./pure\" }, { \"path\": \"./main\" }],
                }"),
				"/user/username/projects/reexport/src/main/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"outDir\": \"../../out\",
                        \"rootDir\": \"../\",
                    },
                    \"include\": [\"**/*.ts\"],
                    \"references\": [{ \"path\": \"../pure\" }],
                }"),
				"/user/username/projects/reexport/src/main/index.ts" => Stringtestutil.Dedent("
                    import { Session } from \"../pure\";

                    export const session: Session = {
                        foo: 1
                    };
                "),
				"/user/username/projects/reexport/src/pure/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"composite\": true,
                        \"outDir\": \"../../out\",
                        \"rootDir\": \"../\",
                    },
                    \"include\": [\"**/*.ts\"],
                }"),
				"/user/username/projects/reexport/src/pure/index.ts" => "export * from \"./session\";",
				"/user/username/projects/reexport/src/pure/session.ts" => Stringtestutil.Dedent("
                    export interface Session {
                        foo: number;
                        // bar: number;
                    }
                ")
			] : FileMap),
			cwd:             "/user/username/projects/reexport",
			commandLineArgs: ["-b", "-w", "-verbose", "src"],
			edits: ([
				{
					caption: "Introduce error",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/user/username/projects/reexport/src/pure/session.ts", "// ", "");
					}
				},
				{
					caption: "Fix error",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/user/username/projects/reexport/src/pure/session.ts", "bar: ", "// bar: ");
					}
				}
			] : Array<TscEdit>)
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("reexport");
	}
}

public static function TestBuildResolveJsonModule() {
	// PORT: local type buildResolveJsonModuleScenario → class BuildResolveJsonModuleScenario (top of file).
	var getBuildResolveJsonModuleFileMap = function(composite:Bool, s:BuildResolveJsonModuleScenario):FileMap {
		var outDirStr = "";
		if (!s.skipOutdir) {
			outDirStr = "\"outDir\": \"dist\",";
		}
		var files = ([
			"/home/src/workspaces/solution/project/src/hello.json" => Stringtestutil.Dedent("
			{
				\"hello\": \"world\"
			}"),
			"/home/src/workspaces/solution/project/src/index.ts" => Stringtestutil.Dedent("
				import hello from \"./hello.json\"
				export default hello.hello
			"),
			"/home/src/workspaces/solution/project/tsconfig.json" => Stringtestutil.Dedent(sprintf("
			{
				\"compilerOptions\": {
					\"composite\": %t,
					\"module\": \"commonjs\",
					\"resolveJsonModule\": true,
					\"esModuleInterop\": true,
					\"allowSyntheticDefaultImports\": true,
					%s
					\"skipDefaultLibCheck\": true,
					%s
				},
				%s
			}", composite, outDirStr, s.additionalCompilerOptions, s.tsconfigFiles))
		] : FileMap);
		if (s.modifyFiles != null) {
			s.modifyFiles(files);
		}
		return files;
	};
	var getBuildResolveJsonModuleTestCases = function(scenarios:Array<BuildResolveJsonModuleScenario>):Array<TscInput> {
		var testCases:Array<TscInput> = [];
		for (s in scenarios) {
			testCases = append(
				testCases,
				({
					subScenario:     s.subScenario,
					files:           getBuildResolveJsonModuleFileMap(true, s),
					cwd:             "/home/src/workspaces/solution",
					commandLineArgs: ["--b", "project", "--v", "--explainFiles", "--listEmittedFiles"],
					edits:           s.edits
				} : TscInput),
				({
					subScenario:     s.subScenario + " non-composite",
					files:           getBuildResolveJsonModuleFileMap(false, s),
					cwd:             "/home/src/workspaces/solution",
					commandLineArgs: ["--b", "project", "--v", "--explainFiles", "--listEmittedFiles"],
					edits:           s.edits
				} : TscInput)
			);
		}
		return testCases;
	};
	var scenarios = ([
		{
			subScenario:   "include only",
			tsconfigFiles: "\"include\": [ \"src/**/*\" ],"
		},
		{
			subScenario:   "include only without outDir",
			tsconfigFiles: "\"include\": [ \"src/**/*\" ],",
			skipOutdir:    true
		},
		{
			subScenario:               "include only with json not in rootDir",
			tsconfigFiles:             "\"include\": [ \"src/**/*\" ],",
			additionalCompilerOptions: "\"rootDir\": \"src\",",
			modifyFiles: function(files:FileMap) {
				var text = files["/home/src/workspaces/solution/project/src/hello.json"];
				files.remove("/home/src/workspaces/solution/project/src/hello.json");
				files["/home/src/workspaces/solution/project/hello.json"] = text;
				text = files["/home/src/workspaces/solution/project/src/index.ts"];
				files["/home/src/workspaces/solution/project/src/index.ts"] = Strings.Replace((text : String), "./hello.json", "../hello.json", 1);
			}
		},
		{
			subScenario:   "include only with json without rootDir but outside configDirectory",
			tsconfigFiles: "\"include\": [ \"src/**/*\" ],",
			modifyFiles: function(files:FileMap) {
				var text = files["/home/src/workspaces/solution/project/src/hello.json"];
				files.remove("/home/src/workspaces/solution/project/src/hello.json");
				files["/home/src/workspaces/solution/hello.json"] = text;
				text = files["/home/src/workspaces/solution/project/src/index.ts"];
				files["/home/src/workspaces/solution/project/src/index.ts"] = Strings.Replace((text : String), "./hello.json", "../../hello.json", 1);
			}
		},
		{
			subScenario:   "include of json along with other include",
			tsconfigFiles: "\"include\": [ \"src/**/*\", \"src/**/*.json\" ],"
		},
		{
			subScenario:   "include of json along with other include and file name matches ts file",
			tsconfigFiles: "\"include\": [ \"src/**/*\", \"src/**/*.json\" ],",
			modifyFiles: function(files:FileMap) {
				var text = files["/home/src/workspaces/solution/project/src/hello.json"];
				files.remove("/home/src/workspaces/solution/project/src/hello.json");
				files["/home/src/workspaces/solution/project/src/index.json"] = text;
				text = files["/home/src/workspaces/solution/project/src/index.ts"];
				files["/home/src/workspaces/solution/project/src/index.ts"] = Strings.Replace((text : String), "./hello.json", "./index.json", 1);
			}
		},
		{
			subScenario:   "files containing json file",
			tsconfigFiles: "\"files\": [ \"src/index.ts\", \"src/hello.json\", ],"
		},
		{
			subScenario:   "include and files",
			tsconfigFiles: "\"files\": [ \"src/hello.json\" ], \"include\": [ \"src/**/*\" ],"
		},
		{
			subScenario:               "sourcemap",
			tsconfigFiles:             "\"files\": [ \"src/index.ts\", \"src/hello.json\", ],",
			additionalCompilerOptions: "\"sourceMap\": true,",
			edits:                     noChangeOnlyEdit
		},
		{
			subScenario:   "without outDir",
			tsconfigFiles: "\"files\": [ \"src/index.ts\", \"src/hello.json\", ],",
			skipOutdir:    true,
			edits:         noChangeOnlyEdit
		}
	] : Array<BuildResolveJsonModuleScenario>);
	var testCases = Slices.Concat(
		getBuildResolveJsonModuleTestCases(scenarios),
		([
			{
				subScenario: "importing json module from project reference",
				files: ([
					"/home/src/workspaces/solution/project/strings/foo.json" => Stringtestutil.Dedent("
						{
							\"foo\": \"bar baz\"
						}
					"),
					"/home/src/workspaces/solution/project/strings/tsconfig.json" => Stringtestutil.Dedent("
						{
							\"extends\": \"../tsconfig.json\",
							\"include\": [\"foo.json\"],
							\"references\": [],
						}
					"),
					"/home/src/workspaces/solution/project/main/index.ts" => Stringtestutil.Dedent("
						import { foo } from '../strings/foo.json';
						console.log(foo);
					"),
					"/home/src/workspaces/solution/project/main/tsconfig.json" => Stringtestutil.Dedent("
						{
							\"extends\": \"../tsconfig.json\",
							\"include\": [
								\"./**/*.ts\",
							],
							\"references\": [{
								\"path\": \"../strings/tsconfig.json\",
							}],
						}
					"),
					"/home/src/workspaces/solution/project/tsconfig.json" => Stringtestutil.Dedent("
						{
							\"compilerOptions\": {
								\"target\": \"es5\",
								\"module\": \"commonjs\",
								\"rootDir\": \"./\",
								\"composite\": true,
								\"resolveJsonModule\": true,
								\"strict\": true,
								\"esModuleInterop\": true,
							},
							\"references\": [
								{ \"path\": \"./strings/tsconfig.json\" },
								{ \"path\": \"./main/tsconfig.json\" },
							],
							\"files\": [],
						}
					")
				] : FileMap),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--b", "project", "--verbose", "--explainFiles"],
				edits:           noChangeOnlyEdit
			}
		] : Array<TscInput>)
	);

	for (test in testCases) {
		test.run("resolveJsonModule");
	}
}

public static function TestBuildRoots() {
	var getBuildRootsFromProjectReferencedProjectFileMap = function(serverFirst:Bool):FileMap {
		var include = Core.IfElse(serverFirst, "\"src/**/*.ts\", \"../shared/src/**/*.ts\"", "\"../shared/src/**/*.ts\", \"src/**/*.ts\"");
		return ([
			"/home/src/workspaces/solution/tsconfig.json" => Stringtestutil.Dedent("
			{
				\"compilerOptions\": {
					\"composite\": true,
				},
				\"references\": [
					{ \"path\": \"projects/server\" },
					{ \"path\": \"projects/shared\" },
				],
			}"),
			"/home/src/workspaces/solution/projects/shared/src/myClass.ts" => "export class MyClass { }",
			"/home/src/workspaces/solution/projects/shared/src/logging.ts" => Stringtestutil.Dedent("
				export function log(str: string) {
					console.log(str);
				}
			"),
			"/home/src/workspaces/solution/projects/shared/src/random.ts" => Stringtestutil.Dedent("
				export function randomFn(str: string) {
					console.log(str);
				}
			"),
			"/home/src/workspaces/solution/projects/shared/tsconfig.json" => Stringtestutil.Dedent("
			{
				\"extends\": \"../../tsconfig.json\",
				\"compilerOptions\": {
					\"outDir\": \"./dist\",
				},
				\"include\": [\"src/**/*.ts\"],
			}"),
			"/home/src/workspaces/solution/projects/server/src/server.ts" => Stringtestutil.Dedent("
				import { MyClass } from ':shared/myClass.js';
				console.log('Hello, world!');
			"),
			"/home/src/workspaces/solution/projects/server/tsconfig.json" => Stringtestutil.Dedent(sprintf("
			{
				\"extends\": \"../../tsconfig.json\",
				\"compilerOptions\": {
					\"rootDir\": \"..\",
					\"outDir\": \"./dist\",
					\"paths\": {
						\":shared/*\": [\"./src/../../shared/src/*\"],
					},
				},
				\"include\": [ %s ],
				\"references\": [
					{ \"path\": \"../shared\" },
				],
			}", include))
		] : FileMap);
	};
	var getBuildRootsFromProjectReferencedProjectTestEdits = function():Array<TscEdit> {
		return ([
			noChange,
			{
				caption: "edit logging file",
				edit: function(sys:TestSys) {
					sys.appendFile("/home/src/workspaces/solution/projects/shared/src/logging.ts", "export const x = 10;");
				}
			},
			noChange,
			{
				caption: "delete random file",
				edit: function(sys:TestSys) {
					sys.removeNoError("/home/src/workspaces/solution/projects/shared/src/random.ts");
				}
			},
			noChange
		] : Array<TscEdit>);
	};
	var testCases = ([
		{
			subScenario: "when two root files are consecutive",
			files: ([
				"/home/src/workspaces/project/file1.ts" => "export const x = \"hello\";",
				"/home/src/workspaces/project/file2.ts" => "export const y = \"world\";",
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": { \"composite\": true },
                    \"include\": [\"*.ts\"],
                }")
			] : FileMap),
			commandLineArgs: ["--b", "-v"],
			edits: ([
				{
					caption: "delete file1",
					edit: function(sys:TestSys) {
						sys.removeNoError("/home/src/workspaces/project/file1.ts");
						sys.removeNoError("/home/src/workspaces/project/file1.js");
						sys.removeNoError("/home/src/workspaces/project/file1.d.ts");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "when multiple root files are consecutive",
			files: ([
				"/home/src/workspaces/project/file1.ts" => "export const x = \"hello\";",
				"/home/src/workspaces/project/file2.ts" => "export const y = \"world\";",
				"/home/src/workspaces/project/file3.ts" => "export const y = \"world\";",
				"/home/src/workspaces/project/file4.ts" => "export const y = \"world\";",
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": { \"composite\": true },
                    \"include\": [\"*.ts\"],
                }")
			] : FileMap),
			commandLineArgs: ["--b", "-v"],
			edits: ([
				{
					caption: "delete file1",
					edit: function(sys:TestSys) {
						sys.removeNoError("/home/src/workspaces/project/file1.ts");
						sys.removeNoError("/home/src/workspaces/project/file1.js");
						sys.removeNoError("/home/src/workspaces/project/file1.d.ts");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "when files are not consecutive",
			files: ([
				"/home/src/workspaces/project/file1.ts" =>    "export const x = \"hello\";",
				"/home/src/workspaces/project/random.d.ts" => "export const random = \"world\";",
				"/home/src/workspaces/project/file2.ts" => Stringtestutil.Dedent("
                    import { random } from \"./random\";
                    export const y = \"world\";
                "),
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": { \"composite\": true },
                    \"include\": [\"file*.ts\"],
                }")
			] : FileMap),
			commandLineArgs: ["--b", "-v"],
			edits: ([
				{
					caption: "delete file1",
					edit: function(sys:TestSys) {
						sys.removeNoError("/home/src/workspaces/project/file1.ts");
						sys.removeNoError("/home/src/workspaces/project/file1.js");
						sys.removeNoError("/home/src/workspaces/project/file1.d.ts");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "when consecutive and non consecutive are mixed",
			files: ([
				"/home/src/workspaces/project/file1.ts" =>    "export const x = \"hello\";",
				"/home/src/workspaces/project/file2.ts" =>    "export const y = \"world\";",
				"/home/src/workspaces/project/random.d.ts" => "export const random = \"hello\";",
				"/home/src/workspaces/project/nonconsecutive.ts" => Stringtestutil.Dedent("
                import { random } from \"./random\";
					export const nonConsecutive = \"hello\";
				"),
				"/home/src/workspaces/project/random1.d.ts" => "export const random = \"hello\";",
				"/home/src/workspaces/project/asArray1.ts" => Stringtestutil.Dedent("
					import { random } from \"./random1\";
					export const x = \"hello\";
				"),
				"/home/src/workspaces/project/asArray2.ts" =>  "export const x = \"hello\";",
				"/home/src/workspaces/project/asArray3.ts" =>  "export const x = \"hello\";",
				"/home/src/workspaces/project/random2.d.ts" => "export const random = \"hello\";",
				"/home/src/workspaces/project/anotherNonConsecutive.ts" => Stringtestutil.Dedent("
					import { random } from \"./random2\";
					export const nonConsecutive = \"hello\";
				"),
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": { \"composite\": true },
                    \"include\": [\"file*.ts\", \"nonconsecutive*.ts\", \"asArray*.ts\", \"anotherNonConsecutive.ts\"],
                }")
			] : FileMap),
			commandLineArgs: ["--b", "-v"],
			edits: ([
				{
					caption: "delete file1",
					edit: function(sys:TestSys) {
						sys.removeNoError("/home/src/workspaces/project/file1.ts");
						sys.removeNoError("/home/src/workspaces/project/file1.js");
						sys.removeNoError("/home/src/workspaces/project/file1.d.ts");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario:     "when root file is from referenced project",
			files:           getBuildRootsFromProjectReferencedProjectFileMap(true),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "projects/server", "-v", "--traceResolution", "--explainFiles"],
			edits:           getBuildRootsFromProjectReferencedProjectTestEdits()
		},
		{
			subScenario:     "when root file is from referenced project and shared is first",
			files:           getBuildRootsFromProjectReferencedProjectFileMap(false),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "projects/server", "-v", "--traceResolution", "--explainFiles"],
			edits:           getBuildRootsFromProjectReferencedProjectTestEdits()
		},
		{
			subScenario:     "when root file is from referenced project",
			files:           getBuildRootsFromProjectReferencedProjectFileMap(true),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "-w", "projects/server", "-v", "--traceResolution", "--explainFiles"],
			edits:           getBuildRootsFromProjectReferencedProjectTestEdits()
		},
		{
			subScenario:     "when root file is from referenced project and shared is first",
			files:           getBuildRootsFromProjectReferencedProjectFileMap(false),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "-w", "projects/server", "-v", "--traceResolution", "--explainFiles"],
			edits:           getBuildRootsFromProjectReferencedProjectTestEdits()
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("roots");
	}
}

public static function TestBuildSample() {

	var getLogicConfig = function():String {
		return Stringtestutil.Dedent("
			{
				\"compilerOptions\": {
					\"composite\": true,
					\"declaration\": true,
					\"sourceMap\": true,
					\"skipDefaultLibCheck\": true,
				},
				\"references\": [
					{ \"path\": \"../core\" },
				],
			}");
	};

	var getBuildSampleFileMap = function(modify:(FileMap) -> Void):FileMap {
		var files = ([
			"/user/username/projects/sample1/core/tsconfig.json" => Stringtestutil.Dedent("
			{
				\"compilerOptions\": {
					\"composite\": true,
					\"declaration\": true,
					\"declarationMap\": true,
					\"skipDefaultLibCheck\": true,
				},
			}"),
			"/user/username/projects/sample1/core/index.ts" => Stringtestutil.Dedent("
				export const someString: string = \"HELLO WORLD\";
				export function leftPad(s: string, n: number) { return s + n; }
				export function multiply(a: number, b: number) { return a * b; }
			"),
			"/user/username/projects/sample1/core/some_decl.d.ts" =>   "declare const dts: any;",
			"/user/username/projects/sample1/core/anotherModule.ts" => "export const World = \"hello\";",
			"/user/username/projects/sample1/logic/tsconfig.json" =>   getLogicConfig(),
			"/user/username/projects/sample1/logic/index.ts" => Stringtestutil.Dedent("
				import * as c from '../core/index';
				export function getSecondsInDay() {
					return c.multiply(10, 15);
				}
				import * as mod from '../core/anotherModule';
				export const m = mod;
			"),
			"/user/username/projects/sample1/tests/tsconfig.json" => Stringtestutil.Dedent("
			{
				\"references\": [
					{ \"path\": \"../core\" },
					{ \"path\": \"../logic\" },
				],
				\"files\": [\"index.ts\"],
				\"compilerOptions\": {
					\"composite\": true,
					\"declaration\": true,
					\"skipDefaultLibCheck\": true,
				},
			}"),
			"/user/username/projects/sample1/tests/index.ts" => Stringtestutil.Dedent("
				import * as c from '../core/index';
				import * as logic from '../logic/index';

				c.leftPad(\"\", 10);
				logic.getSecondsInDay();

				import * as mod from '../core/anotherModule';
				export const m = mod;
			")
		] : FileMap);
		if (modify != null) {
			modify(files);
		}
		return files;
	};
	var getStopBuildOnErrorTests = function(options:Array<String>):Array<TscInput> {
		var noChange = Core.IfElse(options == null, noChangeOnlyEdit, null);
		return ([
			{
				subScenario: "skips builds downstream projects if upstream projects have errors with stopBuildOnErrors",
				files: getBuildSampleFileMap(function(files:FileMap) {
					var text = files["/user/username/projects/sample1/core/index.ts"];
					files["/user/username/projects/sample1/core/index.ts"] = (text : String) + "multiply();";
				}),
				cwd:             "/user/username/projects/sample1",
				commandLineArgs: Slices.Concat(["--b", "tests", "--verbose", "--stopBuildOnErrors"], options),
				edits: Slices.Concat(
					noChange,
					([
						{
							caption: "fix error",
							edit: function(sys:TestSys) {
								sys.replaceFileText("/user/username/projects/sample1/core/index.ts", "multiply();", "");
							}
						}
					] : Array<TscEdit>)
				)
			},
			{
				subScenario: "skips builds downstream projects if upstream projects have errors with stopBuildOnErrors when test does not reference core",
				files: getBuildSampleFileMap(function(files:FileMap) {
					files["/user/username/projects/sample1/tests/tsconfig.json"] = Stringtestutil.Dedent("
					{
						\"references\": [
							{ \"path\": \"../logic\" },
						],
						\"files\": [\"index.ts\"],
						\"compilerOptions\": {
							\"composite\": true,
							\"declaration\": true,
							\"skipDefaultLibCheck\": true,
						},
					}");
					var text = files["/user/username/projects/sample1/core/index.ts"];
					files["/user/username/projects/sample1/core/index.ts"] = (text : String) + "multiply();";
				}),
				cwd:             "/user/username/projects/sample1",
				commandLineArgs: Slices.Concat(["--b", "tests", "--verbose", "--stopBuildOnErrors"], options),
				edits: Slices.Concat(
					noChange,
					([
						{
							caption: "fix error",
							edit: function(sys:TestSys) {
								sys.replaceFileText("/user/username/projects/sample1/core/index.ts", "multiply();", "");
							}
						}
					] : Array<TscEdit>)
				)
			}
		] : Array<TscInput>);
	};
	var getBuildSampleCoreChangeEdits = function():Array<TscEdit> {
		return ([
			{
				caption: "incremental-declaration-changes",
				edit: function(sys:TestSys) {
					sys.appendFile(
						"/user/username/projects/sample1/core/index.ts",
						"
export class someClass { }"
					);
				}
			},
			{
				caption: "incremental-declaration-doesnt-change",
				edit: function(sys:TestSys) {
					sys.appendFile(
						"/user/username/projects/sample1/core/index.ts",
						"
class someClass2 { }"
					);
				}
			},
			noChange
		] : Array<TscEdit>);
	};
	var getBuildSampleWatchDtsChangingEdits = function():Array<TscEdit> {
		return ([
			{
				caption: "Make change to core",
				edit: function(sys:TestSys) {
					sys.appendFile("/user/username/projects/sample1/core/index.ts", "\nexport class someClass { }");
				}
			},
			{
				caption: "Revert core file",
				edit: function(sys:TestSys) {
					sys.replaceFileText("/user/username/projects/sample1/core/index.ts", "\nexport class someClass { }", "");
				}
			},
			{
				caption: "Make two changes",
				edit: function(sys:TestSys) {
					sys.appendFile("/user/username/projects/sample1/core/index.ts", "\nexport class someClass { }");
					sys.appendFile("/user/username/projects/sample1/core/index.ts", "\nexport class someClass2 { }");
				}
			}
		] : Array<TscEdit>);
	};
	var getBuildSampleWatchNonDtsChangingEdits = function():Array<TscEdit> {
		return ([
			{
				caption: "Make local change to core",
				edit: function(sys:TestSys) {
					sys.appendFile("/user/username/projects/sample1/core/index.ts", "\nfunction foo() { }");
				}
			}
		] : Array<TscEdit>);
	};
	var getBuildSampleWatchNewFileEdits = function():Array<TscEdit> {
		return ([
			{
				caption: "Change to new File and build core",
				edit: function(sys:TestSys) {
					sys.writeFileNoError("/user/username/projects/sample1/core/newfile.ts", "export const newFileConst = 30;");
				}
			},
			{
				caption: "Change to new File and build core",
				edit: function(sys:TestSys) {
					sys.writeFileNoError("/user/username/projects/sample1/core/newfile.ts", "\nexport class someClass2 { }");
				}
			}
		] : Array<TscEdit>);
	};
	var makeCircularReferences = function(files:FileMap) {
		files["/user/username/projects/sample1/core/tsconfig.json"] = Stringtestutil.Dedent("
		{
			\"compilerOptions\": {
				\"composite\": true,
				\"declaration\": true
			},
			\"references\": [
				{ \"path\": \"../tests\", \"circular\": true }
			],
		}");
	};
	var getIncrementalErrorTest = function(subScenario:String, options:Array<String>):TscInput {
		var expectedDiffWithLogicError = "";
		if (Slices.Contains(options, "--stopBuildOnErrors")) {
			expectedDiffWithLogicError = Stringtestutil.Dedent("
				Clean build will stop on error in core and will not report error in logic
				Watch build will retain previous errors from logic and report it
			");
		}
		return ({
			subScenario:     "reportErrors " + subScenario,
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: Slices.Concat(["-b", "-w", "tests"], options),
			edits: ([
				{
					caption: "change logic",
					edit: function(sys:TestSys) {
						sys.appendFile("/user/username/projects/sample1/logic/index.ts", "\nlet y: string = 10;");
					}
				},
				{
					caption: "change core",
					edit: function(sys:TestSys) {
						sys.appendFile("/user/username/projects/sample1/core/index.ts", "\nlet x: string = 10;");
					},
					expectedDiff: expectedDiffWithLogicError
				},
				{
					caption: "fix error in logic",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/user/username/projects/sample1/logic/index.ts", "\nlet y: string = 10;", "");
					}
				}
			] : Array<TscEdit>)
		} : TscInput);
	};
	var testCases = Slices.Concat(([
		{
			subScenario: "builds correctly when outDir is specified",
			files: getBuildSampleFileMap(function(files:FileMap) {
				files["/user/username/projects/sample1/logic/tsconfig.json"] = Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"declaration\": true,
						\"sourceMap\": true,
						\"outDir\": \"outDir\",
					},
					\"references\": [
						{ \"path\": \"../core\" },
					],
				}");
			}),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests"]
		},
		{
			subScenario: "builds correctly when declarationDir is specified",
			files: getBuildSampleFileMap(function(files:FileMap) {
				files["/user/username/projects/sample1/logic/tsconfig.json"] = Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"declaration\": true,
						\"sourceMap\": true,
						\"declarationDir\": \"out/decls\",
					},
					\"references\": [
						{ \"path\": \"../core\" },
					],
				}");
			}),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests"]
		},
		{
			subScenario: "builds correctly when project is not composite or doesnt have any references",
			files: getBuildSampleFileMap(function(files:FileMap) {
				var text = files["/user/username/projects/sample1/core/tsconfig.json"];
				files["/user/username/projects/sample1/core/tsconfig.json"] = Strings.Replace((text : String), "\"composite\": true,", "", 1);
			}),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "core", "--verbose"]
		},
		{
			subScenario:     "does not write any files in a dry build",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--dry"]
		},
		{
			subScenario:     "removes all files it built",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests"],
			edits: ([
				{
					caption:         "removes all files it built",
					commandLineArgs: ["--b", "tests", "--clean"]
				},
				{
					caption:         "no change --clean",
					commandLineArgs: ["--b", "tests", "--clean"]
				}
			] : Array<TscEdit>)
		},
		{
			subScenario:     "cleaning project in not build order doesnt throw error",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "logic2", "--clean"]
		},
		{
			subScenario:     "always builds under with force option",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--force"],
			edits:           noChangeOnlyEdit
		},
		{
			subScenario:     "can detect when and what to rebuild",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--verbose"],
			edits: ([
				noChange,
				{
					// Update a file in the leaf node (tests), only it should rebuild the last one
					caption: "Only builds the leaf node project",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/user/username/projects/sample1/tests/index.ts", "const m = 10;");
					}
				},
				{
					// Update a file in the parent (without affecting types), should get fast downstream builds
					caption: "Detects type-only changes in upstream projects",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/user/username/projects/sample1/core/index.ts", "HELLO WORLD", "WELCOME PLANET");
					}
				},
				{
					caption: "rebuilds when tsconfig changes",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/user/username/projects/sample1/tests/tsconfig.json", "\"composite\": true", "\"composite\": true, \"target\": \"es2020\"");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario:     "when input file text does not change but its modified time changes",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--verbose"],
			edits: ([
				{
					caption: "upstream project changes without changing file text",
					edit: function(sys:TestSys) {
						var err = sys.FS().Chtimes("/user/username/projects/sample1/core/index.ts", Time.Zero(), sys.Now());
						if (err != null) {
							throw(err);
						}
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario:     "when declarationMap changes",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--verbose"],
			edits: ([
				{
					caption: "Disable declarationMap",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/user/username/projects/sample1/core/tsconfig.json", "\"declarationMap\": true,", "\"declarationMap\": false,");
					}
				},
				{
					caption: "Enable declarationMap",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/user/username/projects/sample1/core/tsconfig.json", "\"declarationMap\": false,", "\"declarationMap\": true,");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario:     "indicates that it would skip builds during a dry build",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests"],
			edits: ([
				{
					caption:         "--dry",
					commandLineArgs: ["--b", "tests", "--dry"]
				}
			] : Array<TscEdit>)
		},
		{
			subScenario:     "rebuilds from start if force option is set",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests"],
			edits: ([
				{
					caption:         "--force build",
					commandLineArgs: ["--b", "tests", "--verbose", "--force"]
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "tsbuildinfo has error",
			files: ([
				"/home/src/workspaces/project/main.ts" =>              "export const x = 10;",
				"/home/src/workspaces/project/tsconfig.json" =>        "{}",
				"/home/src/workspaces/project/tsconfig.tsbuildinfo" => "Some random string"
			] : FileMap),
			commandLineArgs: ["--b", "-i", "-v"],
			edits: ([
				{
					caption: "tsbuildinfo written has error",
					edit: function(sys:TestSys) {
						// This is to ensure the non incremental doesnt crash - as it wont have tsbuildInfo
						if (!sys.forIncrementalCorrectness) {
							sys.prependFile("/home/src/workspaces/project/tsconfig.tsbuildinfo", "Some random string");
							sys.replaceFileText("/home/src/workspaces/project/tsconfig.tsbuildinfo", sprintf("\"version\":\"%s\"", Core.Version()), sprintf("\"version\":\"%s\"", Harnessutil.FakeTSVersion)); // build info won't parse, need to manually sterilize for baseline
						}
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario:     "rebuilds completely when version in tsbuildinfo doesnt match ts version",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--verbose"],
			edits: ([
				{
					caption: "convert tsbuildInfo version to something that is say to previous version",
					edit: function(sys:TestSys) {
						// This is to ensure the non incremental doesnt crash - as it wont have tsbuildInfo
						if (!sys.forIncrementalCorrectness) {
							sys.replaceFileText("/user/username/projects/sample1/core/tsconfig.tsbuildinfo", sprintf("\"version\":\"%s\"", Harnessutil.FakeTSVersion), sprintf("\"version\":\"%s\"", "FakeTsPreviousVersion"));
							sys.replaceFileText("/user/username/projects/sample1/logic/tsconfig.tsbuildinfo", sprintf("\"version\":\"%s\"", Harnessutil.FakeTSVersion), sprintf("\"version\":\"%s\"", "FakeTsPreviousVersion"));
							sys.replaceFileText("/user/username/projects/sample1/tests/tsconfig.tsbuildinfo", sprintf("\"version\":\"%s\"", Harnessutil.FakeTSVersion), sprintf("\"version\":\"%s\"", "FakeTsPreviousVersion"));
						}
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "rebuilds when extended config file changes",
			files: getBuildSampleFileMap(function(files:FileMap) {
				files["/user/username/projects/sample1/tests/tsconfig.base.json"] = Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"target\": \"es5\"
					}
				}");
				var text = files["/user/username/projects/sample1/tests/tsconfig.json"];
				files["/user/username/projects/sample1/tests/tsconfig.json"] = Strings.Replace((text : String), "\"references\": [", "\"extends\": \"./tsconfig.base.json\", \"references\": [", 1);
			}),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--verbose"],
			edits: ([
				{
					caption: "change extended file",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/user/username/projects/sample1/tests/tsconfig.base.json", Stringtestutil.Dedent("
						{
							\"compilerOptions\": { }
						}"));
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario:     "building project in not build order doesnt throw error",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "logic2/tsconfig.json", "--verbose"]
		},
		{
			subScenario: "builds downstream projects even if upstream projects have errors",
			files: getBuildSampleFileMap(function(files:FileMap) {
				var text = files["/user/username/projects/sample1/logic/index.ts"];
				files["/user/username/projects/sample1/logic/index.ts"] = Strings.Replace((text : String), "c.multiply(10, 15)", "c.muitply()", 1);
			}),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--verbose"],
			edits:           noChangeOnlyEdit
		},
		{
			subScenario:     "listFiles",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--listFiles"],
			edits:           getBuildSampleCoreChangeEdits()
		},
		{
			subScenario:     "listEmittedFiles",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--listEmittedFiles"],
			edits:           getBuildSampleCoreChangeEdits()
		},
		{
			subScenario:     "explainFiles",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--explainFiles", "--v"],
			edits:           getBuildSampleCoreChangeEdits()
		},
		{
			subScenario:     "sample",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--verbose"],
			edits: Slices.Concat(
				getBuildSampleCoreChangeEdits(),
				([
					{
						caption: "when logic config changes declaration dir",
						edit: function(sys:TestSys) {
							sys.replaceFileText(
								"/user/username/projects/sample1/logic/tsconfig.json",
								"\"declaration\": true,",
								"\"declaration\": true,
        \"declarationDir\": \"decls\","
							);
						}
					},
					noChange
				] : Array<TscEdit>)
			)
		},
		{
			subScenario: "when logic specifies tsBuildInfoFile",
			files: getBuildSampleFileMap(function(files:FileMap) {
				var text = files["/user/username/projects/sample1/logic/tsconfig.json"];
				files["/user/username/projects/sample1/logic/tsconfig.json"] = Strings.Replace(
					(text : String),
					"\"composite\": true,",
					"\"composite\": true,
    \"tsBuildInfoFile\": \"ownFile.tsbuildinfo\",",
					1
				);
			}),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--verbose"]
		},
		{
			subScenario: "when declaration option changes",
			files: getBuildSampleFileMap(function(files:FileMap) {
				files["/user/username/projects/sample1/core/tsconfig.json"] = Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"incremental\": true,
						\"skipDefaultLibCheck\": true,
					},
				}");
			}),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "core", "--verbose"],
			edits: ([
				{
					caption: "incremental-declaration-changes",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/user/username/projects/sample1/core/tsconfig.json", "\"incremental\": true,", "\"incremental\": true, \"declaration\": true,");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "when target option changes",
			files: getBuildSampleFileMap(function(files:FileMap) {
				files[Tsctests.getTestLibPathFor("esnext.full")] = "/// <reference no-default-lib=\"true\"/>
/// <reference lib=\"esnext\" />";
				files[Tsctests.tscLibPath+"/lib.d.ts"] = "/// <reference no-default-lib=\"true\"/>
/// <reference lib=\"esnext\" />";
				files["/user/username/projects/sample1/core/tsconfig.json"] = Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"incremental\": true,
						\"listFiles\": true,
						\"listEmittedFiles\": true,
						\"target\": \"esnext\",
					},
				}");
			}),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "core", "--verbose"],
			edits: ([
				{
					caption: "incremental-declaration-changes",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/user/username/projects/sample1/core/tsconfig.json", "esnext", "es5");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "when module option changes",
			files: getBuildSampleFileMap(function(files:FileMap) {
				files["/user/username/projects/sample1/core/tsconfig.json"] = Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"incremental\": true,
						\"module\": \"node18\",
					},
				}");
			}),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "core", "--verbose"],
			edits: ([
				{
					caption: "incremental-declaration-changes",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/user/username/projects/sample1/core/tsconfig.json", "node18", "nodenext");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "when esModuleInterop option changes",
			files: getBuildSampleFileMap(function(files:FileMap) {
				files["/user/username/projects/sample1/tests/tsconfig.json"] = Stringtestutil.Dedent("
				{
					\"references\": [
						{ \"path\": \"../core\" },
						{ \"path\": \"../logic\" },
					],
					\"files\": [\"index.ts\"],
					\"compilerOptions\": {
						\"composite\": true,
						\"declaration\": true,
						\"skipDefaultLibCheck\": true,
						\"esModuleInterop\": false,
					},
				}");
			}),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--verbose"],
			edits: ([
				{
					caption: "incremental-declaration-changes",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/user/username/projects/sample1/tests/tsconfig.json", "\"esModuleInterop\": false", "\"esModuleInterop\": true");
					}
				}
			] : Array<TscEdit>)
		},
		{
			// !!! sheetal this is not reporting error as file not found is not yet implemented
			subScenario: "reports error if input file is missing",
			files: getBuildSampleFileMap(function(files:FileMap) {
				files["/user/username/projects/sample1/core/tsconfig.json"] = Stringtestutil.Dedent("
				{
					 \"compilerOptions\": { \"composite\": true },
					 \"files\": [\"anotherModule.ts\", \"index.ts\", \"some_decl.d.ts\"],
				}");
				files.remove("/user/username/projects/sample1/core/anotherModule.ts");
			}),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--verbose"]
		},
		{
			// !!! sheetal this is not reporting error as file not found is not yet implemented
			subScenario: "reports error if input file is missing with force",
			files: getBuildSampleFileMap(function(files:FileMap) {
				files["/user/username/projects/sample1/core/tsconfig.json"] = Stringtestutil.Dedent("
				{
					 \"compilerOptions\": { \"composite\": true },
					 \"files\": [\"anotherModule.ts\", \"index.ts\", \"some_decl.d.ts\"],
				}");
				files.remove("/user/username/projects/sample1/core/anotherModule.ts");
			}),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "tests", "--verbose", "--force"]
		},
		{
			subScenario:     "change builds changes and reports found errors message",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "-w", "tests"],
			edits:           getBuildSampleWatchDtsChangingEdits()
		},
		{
			subScenario:     "non local change does not start build of referencing projects",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "-w", "tests"],
			edits:           getBuildSampleWatchNonDtsChangingEdits()
		},
		{
			subScenario:     "builds when new file is added, and its subsequent updates",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "-w", "tests"],
			edits:           getBuildSampleWatchNewFileEdits()
		},
		{
			subScenario:     "change builds changes and reports found errors message with circular references",
			files:           getBuildSampleFileMap(makeCircularReferences),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "-w", "tests"],
			edits:           getBuildSampleWatchDtsChangingEdits()
		},
		{
			subScenario:     "non local change does not start build of referencing projects with circular references",
			files:           getBuildSampleFileMap(makeCircularReferences),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "-w", "tests"],
			edits:           getBuildSampleWatchNonDtsChangingEdits()
		},
		{
			subScenario:     "builds when new file is added, and its subsequent updates with circular references",
			files:           getBuildSampleFileMap(makeCircularReferences),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "-w", "tests"],
			edits:           getBuildSampleWatchNewFileEdits()
		},
		{
			subScenario: "watches config files that are not present",
			files: getBuildSampleFileMap(function(files:FileMap) {
				files.remove("/user/username/projects/sample1/logic/tsconfig.json");
			}),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "-w", "tests"],
			edits: ([
				{
					caption: "Write logic",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/user/username/projects/sample1/logic/tsconfig.json", getLogicConfig());
					}
				}
			] : Array<TscEdit>)
		},
		getIncrementalErrorTest("when preserveWatchOutput is not used", null),
		getIncrementalErrorTest("when preserveWatchOutput is passed on command line", ["--preserveWatchOutput"]),
		getIncrementalErrorTest("when stopBuildOnErrors is passed on command line", ["--stopBuildOnErrors"]),
		{
			subScenario:     "incremental updates in verbose mode",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "-w", "tests", "--verbose"],
			edits: ([
				{
					caption: "Make non dts change",
					edit: function(sys:TestSys) {
						sys.appendFile("/user/username/projects/sample1/logic/index.ts", "\nfunction someFn() { }");
					}
				},
				{
					caption: "Make dts change",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/user/username/projects/sample1/logic/index.ts", "\nfunction someFn() { }", "\nexport function someFn() { }");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario:     "should not trigger recompilation because of program emit",
			files:           getBuildSampleFileMap(null),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "-w", "core", "--verbose"],
			edits: ([
				noChange,
				{
					caption: "Add new file",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/user/username/projects/sample1/core/file3.ts", "export const y = 10;");
					}
				},
				noChange
			] : Array<TscEdit>)
		},
		{
			subScenario: "should not trigger recompilation because of program emit with outDir specified",
			files: getBuildSampleFileMap(function(files:FileMap) {
				files["/user/username/projects/sample1/core/tsconfig.json"] = Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"outDir\"
					}
                }");
			}),
			cwd:             "/user/username/projects/sample1",
			commandLineArgs: ["--b", "-w", "core", "--verbose"],
			edits: ([
				noChange,
				{
					caption: "Add new file",
					edit: function(sys:TestSys) {
						sys.writeFileNoError("/user/username/projects/sample1/core/file3.ts", "export const y = 10;");
					}
				},
				noChange
			] : Array<TscEdit>)
		}
	] : Array<TscInput>), getStopBuildOnErrorTests(null), getStopBuildOnErrorTests(["--watch"]));

	for (test in testCases) {
		test.run("sample");
	}
}

public static function TestBuildTransitiveReferences() {

	var getBuildTransitiveReferencesFileMap = function(modify:(FileMap) -> Void):FileMap {
		var files = ([
			"/user/username/projects/transitiveReferences/refs/a.d.ts" => Stringtestutil.Dedent("
				export class X {}
				export class A {}
			"),
			"/user/username/projects/transitiveReferences/a.ts" => Stringtestutil.Dedent("
				export class A {}
			"),
			"/user/username/projects/transitiveReferences/b.ts" => Stringtestutil.Dedent("
				import {A} from '@ref/a';
				export const b = new A();
			"),
			"/user/username/projects/transitiveReferences/c.ts" => Stringtestutil.Dedent("
				import {b} from './b';
				import {X} from \"@ref/a\";
				b;
				X;
			"),
			"/user/username/projects/transitiveReferences/tsconfig.a.json" => Stringtestutil.Dedent("
			{
				\"files\": [\"a.ts\"],
				\"compilerOptions\": {
					\"composite\": true,
				},
			}"),
			"/user/username/projects/transitiveReferences/tsconfig.b.json" => Stringtestutil.Dedent("
			{
				\"files\": [\"b.ts\"],
				\"compilerOptions\": {
					\"composite\": true,
					\"paths\": {
						\"@ref/*\": [\"./*\"],
					},
				},
				\"references\": [{ \"path\": \"tsconfig.a.json\" }],
			}"),
			"/user/username/projects/transitiveReferences/tsconfig.c.json" => Stringtestutil.Dedent("
			{
				\"files\": [\"c.ts\"],
				\"compilerOptions\": {
					\"paths\": {
						\"@ref/*\": [\"./refs/*\"],
					},
				},
				\"references\": [{ \"path\": \"tsconfig.b.json\" }],
			}")
		] : FileMap);
		if (modify != null) {
			modify(files);
		}
		return files;
	};
	var testCases = ([
		{
			subScenario:     "builds correctly",
			files:           getBuildTransitiveReferencesFileMap(null),
			cwd:             "/user/username/projects/transitiveReferences",
			commandLineArgs: ["--b", "tsconfig.c.json", "--listFiles"]
		},
		{
			subScenario: "reports error about module not found with node resolution with external module name",
			files: getBuildTransitiveReferencesFileMap(function(files:FileMap) {
				files["/user/username/projects/transitiveReferences/b.ts"] = "import {A} from 'a';
export const b = new A();";
				files["/user/username/projects/transitiveReferences/tsconfig.b.json"] = Stringtestutil.Dedent("
				{
					\"files\": [\"b.ts\"],
					\"compilerOptions\": {
						\"composite\": true,
						\"module\": \"nodenext\",
					},
					\"references\": [{ \"path\": \"tsconfig.a.json\" }],
				}");
			}),
			cwd:             "/user/username/projects/transitiveReferences",
			commandLineArgs: ["--b", "tsconfig.c.json", "--listFiles"]
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("transitiveReferences");
	}
}

public static function TestBuildSolutionProject() {
	var testCases = ([
		{
			subScenario: "verify that subsequent builds after initial build doesnt build anything",
			files: ([
				"/home/src/workspaces/solution/src/folder/index.ts" => "export const x = 10;",
				"/home/src/workspaces/solution/src/folder/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"files\": [\"index.ts\"],
                        \"compilerOptions\": {
                            \"composite\": true
                        }
                    }
                "),
				"/home/src/workspaces/solution/src/folder2/index.ts" => "export const x = 10;",
				"/home/src/workspaces/solution/src/folder2/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"files\": [\"index.ts\"],
                        \"compilerOptions\": {
                            \"composite\": true
                        }
                    }
                "),
				"/home/src/workspaces/solution/src/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"files\": [],
                        \"compilerOptions\": {
                            \"composite\": true
                        },
						\"references\": [
							{ \"path\": \"./folder\" },
							{ \"path\": \"./folder2\" },
						]
                }"),
				"/home/src/workspaces/solution/tests/index.ts" => "export const x = 10;",
				"/home/src/workspaces/solution/tests/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"files\": [\"index.ts\"],
                        \"compilerOptions\": {
                            \"composite\": true
                        },
                        \"references\": [
                            { \"path\": \"../src\" }
                        ]
                    }
                "),
				"/home/src/workspaces/solution/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"files\": [],
                        \"compilerOptions\": {
                            \"composite\": true
                        },
                        \"references\": [
                            { \"path\": \"./src\" },
                            { \"path\": \"./tests\" }
                        ]
                    }
                ")
			] : FileMap),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "--v"],
			edits:           noChangeOnlyEdit
		},
		{
			subScenario: "when solution is referenced indirectly",
			files: ([
				"/home/src/workspaces/solution/project1/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": { \"composite\": true },
                        \"references\": []
                    }
                "),
				"/home/src/workspaces/solution/project2/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": { \"composite\": true },
                        \"references\": []
                    }
                "),
				"/home/src/workspaces/solution/project2/src/b.ts" => "export const b = 10;",
				"/home/src/workspaces/solution/project3/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": { \"composite\": true },
                        \"references\": [
							{ \"path\": \"../project1\" },
							{ \"path\": \"../project2\" }
						]
                    }
                "),
				"/home/src/workspaces/solution/project3/src/c.ts" => "export const c = 10;",
				"/home/src/workspaces/solution/project4/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": { \"composite\": true },
                        \"references\": [{ \"path\": \"../project3\" }]
                    }
                "),
				"/home/src/workspaces/solution/project4/src/d.ts" => "export const d = 10;"
			] : FileMap),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "project4", "--verbose", "--explainFiles"],
			edits: ([
				{
					caption: "modify project3 file",
					edit: function(sys:TestSys) {
						sys.replaceFileText("/home/src/workspaces/solution/project3/src/c.ts", "c = ", "cc = ");
					}
				}
			] : Array<TscEdit>)
		},
		{
			subScenario: "has empty files diagnostic when files is empty and no references are provided",
			files: ([
				"/home/src/workspaces/solution/no-references/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"references\": [],
                        \"files\": [],
                        \"compilerOptions\": {
                            \"composite\": true,
                            \"declaration\": true,
                            \"forceConsistentCasingInFileNames\": true,
                            \"skipDefaultLibCheck\": true,
                        },
                    }")
			] : FileMap),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "no-references"]
		},
		{
			subScenario: "does not have empty files diagnostic when files is empty and references are provided",
			files: ([
				"/home/src/workspaces/solution/core/index.ts" => "export function multiply(a: number, b: number) { return a * b; }",
				"/home/src/workspaces/solution/core/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": {
                            \"composite\": true,
                            \"declaration\": true,
                            \"declarationMap\": true,
                            \"skipDefaultLibCheck\": true,
                        },
                    }"),
				"/home/src/workspaces/solution/with-references/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"references\": [
                            { \"path\": \"../core\" },
                        ],
                        \"files\": [],
                        \"compilerOptions\": {
                            \"composite\": true,
                            \"declaration\": true,
                            \"forceConsistentCasingInFileNames\": true,
                            \"skipDefaultLibCheck\": true,
                        },
                    }")
			] : FileMap),
			cwd:             "/home/src/workspaces/solution",
			commandLineArgs: ["--b", "with-references"]
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("solution");
	}
}

public static function TestBuildProjectReferenceRedirectWithMultipleSubProjects() {
	var testCases = ([
		{
			subScenario: "uses correct project reference redirect when file belongs to multiple sub-projects",
			files: ([
				// Consumer tsconfig - uses customConditions and moduleSuffixes for react-native
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"module\": \"esnext\",
							\"moduleResolution\": \"bundler\",
							\"customConditions\": [\"react-native\"],
							\"moduleSuffixes\": [\".native\", \"\"],
							\"strict\": true,
							\"noEmit\": true
						},
						\"include\": [\"app.ts\"],
						\"references\": [
							{ \"path\": \"./pkg\" }
						]
					}"),
				// Consumer app - imports from pkg, expects native platform
				"/home/src/workspaces/project/app.ts" => Stringtestutil.Dedent("
					import { platform } from \"pkg\";
					const check: \"native\" = platform;"),
				// Package - web tsconfig (includes all files via **/*)
				"/home/src/workspaces/project/pkg/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"module\": \"esnext\",
							\"moduleResolution\": \"bundler\",
							\"composite\": true,
							\"declaration\": true,
							\"emitDeclarationOnly\": true,
							\"outDir\": \"./dist\",
							\"strict\": true
						},
						\"include\": [\"**/*\"],
						\"exclude\": [\"dist\"],
						\"references\": [
							{ \"path\": \"./tsconfig.native.json\" }
						]
					}"),
				// Package - native tsconfig (includes specific files, has customConditions)
				"/home/src/workspaces/project/pkg/tsconfig.native.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"module\": \"esnext\",
							\"moduleResolution\": \"bundler\",
							\"composite\": true,
							\"declaration\": true,
							\"emitDeclarationOnly\": true,
							\"outDir\": \"./dist\",
							\"strict\": true,
							\"customConditions\": [\"react-native\"],
							\"moduleSuffixes\": [\".native\", \"\"]
						},
						\"include\": [\"index.native.ts\", \"src/util.native.ts\", \"src/util.ts\"],
						\"exclude\": [\"dist\"]
					}"),
				// Package exports - react-native condition maps to index.native.ts
				"/home/src/workspaces/project/pkg/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"pkg\",
						\"exports\": {
							\".\": {
								\"react-native\": \"./index.native.ts\",
								\"types\": \"./index.ts\",
								\"default\": \"./index.ts\"
							}
						}
					}"),
				// Web entry point
				"/home/src/workspaces/project/pkg/index.ts" => "export { platform } from \"./src/util\";",
				// Native entry point (same content, but should resolve internal imports using native tsconfig)
				"/home/src/workspaces/project/pkg/index.native.ts" => "export { platform } from \"./src/util\";",
				// Web util
				"/home/src/workspaces/project/pkg/src/util.ts" => "export const platform = \"web\" as const;",
				// Native util
				"/home/src/workspaces/project/pkg/src/util.native.ts" => "export const platform = \"native\" as const;",
				// node_modules symlink
				"/home/src/workspaces/project/node_modules/pkg" => Vfstest.Symlink("/home/src/workspaces/project/pkg")
			] : FileMap),
			cwd:             "/home/src/workspaces/project",
			commandLineArgs: ["--b", "--verbose"]
		}
	] : Array<TscInput>);

	for (test in testCases) {
		test.run("projectReferenceRedirect");
	}
}

}
