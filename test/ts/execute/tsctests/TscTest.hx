package ts.execute.tsctests;

import ts.execute.tsctests.Runner.FileMap;

// Port of internal/execute/tsctests/tsc_test.go (scenario data).

// Go local struct types of the test functions.
@:structInit
class NoCheckScenario {
	public var subScenario:String = "";
	public var aText:String = "";
}

@:structInit
class TscNoEmitScenario {
	public var subScenario:String = "";
	public var aText:String = "";
	public var dtsEnabled:Bool = false;
}

@:structInit
class TscNoEmitChangesScenario {
	public var subScenario:String = "";
	public var optionsString:String = "";
}

@:structInit
class TscNoEmitOnErrorScenario {
	public var subScenario:String = "";
	public var mainErrorContent:String = "";
	public var fixedErrorContent:String = "";
}

class TscTest {
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
		TestTscCommandline();
		TestTscMissingFiles();
		TestTscComposite();
		TestTscDeclarationEmit();
		TestTscExtends();
		TestForceConsistentCasingInFileNames();
		TestTscIgnoreConfig();
		TestTscIncremental();
		TestTscLibraryResolution();
		TestTscListFilesOnly();
		TestTscModuleResolution();
		TestTscNoCheck();
		TestTscNoEmit();
		TestTscNoEmitOnError();
		TestTscProjectReferences();
		TestTypeAcquisition();
		TestGenerateTrace();
	}

	public static function TestTscCommandline() {
		var testCases = ([
			{
				subScenario: "show help with ExitStatus.DiagnosticsPresent_OutputsSkipped",
				env: [
					"TS_TEST_TERMINAL_WIDTH" => "120"
				],
				commandLineArgs: null
			},
			{
				subScenario:     "show help with ExitStatus.DiagnosticsPresent_OutputsSkipped when host cannot provide terminal width",
				commandLineArgs: null
			},
			{
				subScenario: "does not add color when NO_COLOR is set",
				env: [
					"NO_COLOR" => "true"
				],
				commandLineArgs: null
			},
			{
				subScenario: "adds color when FORCE_COLOR is set",
				env: [
					"FORCE_COLOR" => "true"
				],
				commandLineArgs: null
			},
			{
				subScenario: "does not add color when NO_COLOR is set even if FORCE_COLOR is set",
				env: [
					"NO_COLOR" =>    "true",
					"FORCE_COLOR" => "true"
				],
				commandLineArgs: null
			},
			{
				subScenario:     "when build not first argument",
				commandLineArgs: ["--verbose", "--build"]
			},
			{
				subScenario:     "Initialized TSConfig with files options",
				commandLineArgs: ["--init", "file0.st", "file1.ts", "file2.ts"]
			},
			{
				subScenario:     "Initialized TSConfig with boolean value compiler options",
				commandLineArgs: ["--init", "--noUnusedLocals"]
			},
			{
				subScenario:     "Initialized TSConfig with enum value compiler options",
				commandLineArgs: ["--init", "--target", "es5", "--jsx", "react"]
			},
			{
				subScenario:     "Initialized TSConfig with list compiler options",
				commandLineArgs: ["--init", "--types", "jquery,mocha"]
			},
			{
				subScenario:     "Initialized TSConfig with list compiler options with enum value",
				commandLineArgs: ["--init", "--lib", "es5,es2015.core"]
			},
			{
				subScenario:     "Initialized TSConfig with incorrect compiler option",
				commandLineArgs: ["--init", "--someNonExistOption"]
			},
			{
				subScenario:     "Initialized TSConfig with incorrect compiler option value",
				commandLineArgs: ["--init", "--lib", "nonExistLib,es5,es2015.promise"]
			},
			{
				subScenario:     "Initialized TSConfig with advanced options",
				commandLineArgs: ["--init", "--declaration", "--declarationDir", "lib", "--skipLibCheck", "--noErrorTruncation"]
			},
			{
				subScenario:     "Initialized TSConfig with --help",
				commandLineArgs: ["--init", "--help"]
			},
			{
				subScenario:     "Initialized TSConfig with --watch",
				commandLineArgs: ["--init", "--watch"]
			},
			{
				subScenario:     "Initialized TSConfig with tsconfig.json",
				commandLineArgs: ["--init"],
				files: ([
					"/home/src/workspaces/project/first.ts" => "export const a = 1",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"strict\": true,
						\"noEmit\": true
					}
				}")
				] : FileMap)
			},
			{
				subScenario:     "help",
				commandLineArgs: ["--help"]
			},
			{
				subScenario:     "help all",
				commandLineArgs: ["--help", "--all"]
			},
			{
				subScenario:     "Parse --lib option with file name",
				files:           (["/home/src/workspaces/project/first.ts" => "export const Key = Symbol()"] : FileMap),
				commandLineArgs: ["--lib", "es6 ", "first.ts"]
			},
			{
				subScenario:     "option diagnostics are suppressed when there are syntactic errors",
				files:           (["/home/src/workspaces/project/a.ts" => "const x: = 1;"] : FileMap),
				commandLineArgs: ["--strictPropertyInitialization", "--strictNullChecks", "false", "a.ts"]
			},
			{
				subScenario: "Project is empty string",
				files: ([
					"/home/src/workspaces/project/first.ts" => "export const a = 1",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"strict\": true,
						\"noEmit\": true
					}
				}")
				] : FileMap),
				commandLineArgs: []
			},
			{
				subScenario: "Parse -p",
				files: ([
					"/home/src/workspaces/project/first.ts" => "export const a = 1",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"strict\": true,
						\"noEmit\": true
					}
				}")
				] : FileMap),
				commandLineArgs: ["-p", "."]
			},
			{
				subScenario: "Parse -p with path to tsconfig file",
				files: ([
					"/home/src/workspaces/project/first.ts" => "export const a = 1",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"strict\": true,
						\"noEmit\": true
					}
				}")
				] : FileMap),
				commandLineArgs: ["-p", "/home/src/workspaces/project/tsconfig.json"]
			},
			{
				subScenario: "Parse -p with path to tsconfig folder",
				files: ([
					"/home/src/workspaces/project/first.ts" => "export const a = 1",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"strict\": true,
						\"noEmit\": true
					}
				}")
				] : FileMap),
				commandLineArgs: ["-p", "/home/src/workspaces/project"]
			},
			{
				subScenario: "Parse -p with empty tsconfig file",
				files: ([
					"/home/src/workspaces/project/first.ts" =>      "export const a = 1",
					"/home/src/workspaces/project/tsconfig.json" => ""
				] : FileMap),
				commandLineArgs: ["-p", "."]
			},
			{
				subScenario:     "Parse enum type options",
				commandLineArgs: ["--moduleResolution", "nodenext ", "first.ts", "--module", "nodenext", "--target", "esnext", "--moduleDetection", "auto", "--jsx", "react", "--newLine", "crlf"]
			},
			{
				subScenario: "Parse watch interval option",
				files: ([
					"/home/src/workspaces/project/first.ts" => "export const a = 1",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"strict\": true,
						\"noEmit\": true
					}
				}")
				] : FileMap),
				commandLineArgs: ["-w", "--watchInterval", "1000"]
			},
			{
				subScenario:     "Parse watch interval option without tsconfig.json",
				commandLineArgs: ["-w", "--watchInterval", "1000"]
			},
			{
				subScenario: "Config with references and empty file and refers to config with noEmit",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("{
					\"files\": [],
					\"references\": [
						{
							\"path\": \"./packages/pkg1\"
						},
					],
				}"),
					"/home/src/workspaces/project/packages/pkg1/tsconfig.json" => Stringtestutil.Dedent("{
					\"compilerOptions\": {
						\"composite\": true,
						\"noEmit\": true
					},
					\"files\": [
						\"./index.ts\",
					],
				}"),
					"/home/src/workspaces/project/packages/pkg1/index.ts" => "export const a = 1;"
				] : FileMap),
				commandLineArgs: ["-p", "."]
			},
			{
				subScenario:     "locale",
				commandLineArgs: ["--locale", "cs", "--version"]
			},
			{
				subScenario:     "bad locale",
				commandLineArgs: ["--locale", "whoops", "--version"]
			}
		] : Array<TscInput>);

		for (testCase in testCases) {
			testCase.run("commandLine");
		}
	}

	public static function TestTscMissingFiles() {
		var testCases = ([
			{
				subScenario: "file in tsconfig does not exist",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent(
						"{
					\"files\": [\"./src/doesNotExist.ts\"]
					}"
					)
				] : FileMap),
				commandLineArgs: ["-p", "./tsconfig.json"]
			},
			{
				subScenario: "extensionless file in tsconfig does not exist",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent(
						"{
					\"files\": [\"./src/doesNotExist\"]
					}"
					)
				] : FileMap),
				commandLineArgs: ["-p", "./tsconfig.json"]
			},
			{
				subScenario: "extensionless file in extended tsconfig in different folder does not exist",
				files: ([
					"/home/src/workspaces/project/src/tsconfig.json" => Stringtestutil.Dedent(
						"{
					\"extends\": \"./../tsconfig.base.json\",
					}"
					),
					"/home/src/workspaces/project/src/oops.ts" => "export const abc = 10;",
					"/home/src/workspaces/project/tsconfig.base.json" => Stringtestutil.Dedent(
						"{
					\"files\": [\"./oops\"],
					}"
					)
				] : FileMap),
				commandLineArgs: ["-p", "./src/tsconfig.json"]
			}
		] : Array<TscInput>);

		for (testCase in testCases) {
			testCase.run("commandLine");
		}
	}

	public static function TestTscComposite() {
		var testCases = ([
			{
				subScenario: "when setting composite false on command line",
				files: ([
					"/home/src/workspaces/project/src/main.ts" => "export const x = 10;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"target\": \"es5\",
						\"module\": \"commonjs\",
						\"composite\": true,
					},
					\"include\": [
						\"src/**/*.ts\",
					],
				}")
				] : FileMap),
				commandLineArgs: ["--composite", "false"]
			},
			{
				subScenario: "when setting composite null on command line",
				files: ([
					"/home/src/workspaces/project/src/main.ts" => "export const x = 10;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"target\": \"es5\",
						\"module\": \"commonjs\",
						\"composite\": true,
					},
					\"include\": [
						\"src/**/*.ts\",
					],
				}")
				] : FileMap),
				commandLineArgs: ["--composite", "null"]
			},
			{
				subScenario: "when setting composite false on command line but has tsbuild info in config",
				files: ([
					"/home/src/workspaces/project/src/main.ts" => "export const x = 10;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"target\": \"es5\",
						\"module\": \"commonjs\",
						\"composite\": true,
						\"tsBuildInfoFile\": \"tsconfig.json.tsbuildinfo\",
					},
					\"include\": [
						\"src/**/*.ts\",
					],
				}")
				] : FileMap),
				commandLineArgs: ["--composite", "false"]
			},
			{
				subScenario: "when setting composite false and tsbuildinfo as null on command line but has tsbuild info in config",
				files: ([
					"/home/src/workspaces/project/src/main.ts" => "export const x = 10;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"target\": \"es5\",
						\"module\": \"commonjs\",
						\"composite\": true,
						\"tsBuildInfoFile\": \"tsconfig.json.tsbuildinfo\",
					},
					\"include\": [
						\"src/**/*.ts\",
					],
				}")
				] : FileMap),
				commandLineArgs: ["--composite", "false", "--tsBuildInfoFile", "null"]
			},
			{
				subScenario: "converting to modules",
				files: ([
					"/home/src/workspaces/project/src/main.ts" => "const x = 10;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"module\": \"none\",
						\"composite\": true,
					},
				}")
				] : FileMap),
				edits: ([
					{
						caption: "convert to modules",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/home/src/workspaces/project/tsconfig.json", "none", "es2015");
						}
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "synthetic jsx import of ESM module from CJS module no crash no jsx element",
				files: ([
					"/home/src/projects/project/src/main.ts" => "export default 42;",
					"/home/src/projects/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"module\": \"Node16\",
						\"jsx\": \"react-jsx\",
						\"jsxImportSource\": \"solid-js\",
					},
				}"),
					"/home/src/projects/project/node_modules/solid-js/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"solid-js\",
						\"type\": \"module\"
					}
				"),
					"/home/src/projects/project/node_modules/solid-js/jsx-runtime.d.ts" => Stringtestutil.Dedent("
					export namespace JSX {
						type IntrinsicElements = { div: {}; };
					}
				")
				] : FileMap),
				cwd: "/home/src/projects/project"
			},
			{
				subScenario: "synthetic jsx import of ESM module from CJS module error on jsx element",
				files: ([
					"/home/src/projects/project/src/main.tsx" => "export default <div/>;",
					"/home/src/projects/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"module\": \"Node16\",
						\"jsx\": \"react-jsx\",
						\"jsxImportSource\": \"solid-js\",
					},
				}"),
					"/home/src/projects/project/node_modules/solid-js/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"solid-js\",
						\"type\": \"module\"
					}
				"),
					"/home/src/projects/project/node_modules/solid-js/jsx-runtime.d.ts" => Stringtestutil.Dedent("
					export namespace JSX {
						type IntrinsicElements = { div: {}; };
					}
				")
				] : FileMap),
				cwd: "/home/src/projects/project"
			}
		] : Array<TscInput>);

		for (testCase in testCases) {
			testCase.run("composite");
		}
	}

	public static function TestTscDeclarationEmit() {
		var getBuildDeclarationEmitDtsReferenceAsTrippleSlashMap = function(useNoRef:Bool):FileMap {
			var files = ([
				"/home/src/workspaces/solution/tsconfig.base.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"rootDir\": \"./\",
						\"outDir\": \"lib\",
					},
				}"),
				"/home/src/workspaces/solution/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": { \"composite\": true },
					\"references\": [{ \"path\": \"./src\" }],
					\"include\": [],
				}"),
				"/home/src/workspaces/solution/src/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": { \"composite\": true },
					\"references\": [{ \"path\": \"./subProject\" }, { \"path\": \"./subProject2\" }],
					\"include\": [],
				}"),
				"/home/src/workspaces/solution/src/subProject/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"../../tsconfig.base.json\",
					\"compilerOptions\": { \"composite\": true },
					\"references\": [{ \"path\": \"../common\" }],
					\"include\": [\"./index.ts\"],
				}"),
				"/home/src/workspaces/solution/src/subProject/index.ts" => Stringtestutil.Dedent("
				import { Nominal } from '../common/nominal';
				export type MyNominal = Nominal<string, 'MyNominal'>;"),
				"/home/src/workspaces/solution/src/subProject2/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"../../tsconfig.base.json\",
					\"compilerOptions\": { \"composite\": true },
					\"references\": [{ \"path\": \"../subProject\" }],
					\"include\": [\"./index.ts\"],
				}"),
				"/home/src/workspaces/solution/src/subProject2/index.ts" => Stringtestutil.Dedent("
				import { MyNominal } from '../subProject/index';
				const variable = {
					key: 'value' as MyNominal,
				};
				export function getVar(): keyof typeof variable {
					return 'key';
				}"),
				"/home/src/workspaces/solution/src/common/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"../../tsconfig.base.json\",
					\"compilerOptions\": { \"composite\": true },
					\"include\": [\"./nominal.ts\"],
				}"),
				"/home/src/workspaces/solution/src/common/nominal.ts" => Stringtestutil.Dedent("
				/// <reference path=\"./types.d.ts\" preserve=\"true\" />
				export declare type Nominal<T, Name extends string> = MyNominal<T, Name>;"),
				"/home/src/workspaces/solution/src/common/types.d.ts" => Stringtestutil.Dedent("
				declare type MyNominal<T, Name extends string> = T & {
					specialKey: Name;
				};")
			] : FileMap);
			if (useNoRef) {
				files["/home/src/workspaces/solution/tsconfig.json"] = Stringtestutil.Dedent("
			{
				\"extends\": \"./tsconfig.base.json\",
				\"compilerOptions\": { \"composite\": true },
				\"include\": [\"./src/**/*.ts\"],
			}");
			}
			return files;
		};

		var getTscDeclarationEmitDtsErrorsFileMap = function(composite:Bool, incremental:Bool):FileMap {
			return ([
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent(sprintf("
				{
					\"compilerOptions\": {
						\"module\": \"NodeNext\",
						\"moduleResolution\": \"NodeNext\",
						\"composite\": %t,
						\"incremental\": %t,
						\"declaration\": true,
						\"skipLibCheck\": true,
						\"skipDefaultLibCheck\": true,
					},
				}", composite, incremental)),
				"/home/src/workspaces/project/index.ts" => Stringtestutil.Dedent("
				import ky from 'ky';
				export const api = ky.extend({});
			"),
				"/home/src/workspaces/project/package.json" => Stringtestutil.Dedent("
				{
					\"type\": \"module\"
				}"),
				"/home/src/workspaces/project/node_modules/ky/distribution/index.d.ts" => Stringtestutil.Dedent("
				type KyInstance = {
					extend(options: Record<string,unknown>): KyInstance;
				}
				declare const ky: KyInstance;
				export default ky;
			"),
				"/home/src/workspaces/project/node_modules/ky/package.json" => Stringtestutil.Dedent("
				{
					\"name\": \"ky\",
					\"type\": \"module\",
					\"main\": \"./distribution/index.js\"
				}
			")
			] : FileMap);
		};

		var pluginOneConfig = function():String {
			return Stringtestutil.Dedent("
		{
			\"compilerOptions\": {
				\"target\": \"es5\",
				\"declaration\": true,
				\"traceResolution\": true,
			},
		}");
		};

		var pluginOneIndex = function():String {
			return "import pluginTwo from \"plugin-two\"; // include this to add reference to symlink";
		};

		var pluginOneAction = function():String {
			return Stringtestutil.Dedent("
			import { actionCreatorFactory } from \"typescript-fsa\"; // Include version of shared lib
			const action = actionCreatorFactory(\"somekey\");
			const featureOne = action<{ route: string }>(\"feature-one\");
			export const actions = { featureOne };");
		};

		var pluginTwoDts = function():String {
			return Stringtestutil.Dedent("
			declare const _default: {
				features: {
					featureOne: {
						actions: {
							featureOne: {
								(payload: {
									name: string;
									order: number;
								}, meta?: {
									[key: string]: any;
								}): import(\"typescript-fsa\").Action<{
									name: string;
									order: number;
								}>;
							};
						};
						path: string;
					};
				};
			};
			export default _default;");
		};

		var fsaPackageJson = function():String {
			return Stringtestutil.Dedent("
			{
				\"name\": \"typescript-fsa\",
				\"version\": \"3.0.0-beta-2\"
			}");
		};

		var fsaIndex = function():String {
			return Stringtestutil.Dedent("
			export interface Action<Payload> {
				type: string;
				payload: Payload;
			}
			export declare type ActionCreator<Payload> = {
				type: string;
				(payload: Payload): Action<Payload>;
			}
			export interface ActionCreatorFactory {
				<Payload = void>(type: string): ActionCreator<Payload>;
			}
			export declare function actionCreatorFactory(prefix?: string | null): ActionCreatorFactory;
			export default actionCreatorFactory;");
		};
		var testCases = ([
			{
				subScenario:     "when declaration file is referenced through triple slash",
				files:           getBuildDeclarationEmitDtsReferenceAsTrippleSlashMap(false),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--b", "--verbose"]
			},
			{
				subScenario:     "when declaration file is referenced through triple slash but uses no references",
				files:           getBuildDeclarationEmitDtsReferenceAsTrippleSlashMap(true),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--b", "--verbose"]
			},
			{
				subScenario: "when ts file is referenced through triple slash from another project",
				files: ([
					"/home/src/workspaces/solution/include/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": { \"composite\": true, \"declaration\": true },
					}"),
					"/home/src/workspaces/solution/include/include.ts" => Stringtestutil.Dedent("
					export const include = 1;"),
					"/home/src/workspaces/solution/src/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": { \"composite\": true, \"declaration\": true },
						\"references\": [{ \"path\": \"../include\" }],
					}"),
					"/home/src/workspaces/solution/src/main.ts" => Stringtestutil.Dedent("
					/// <reference path=\"../include/include.ts\" preserve=\"true\" />
					export const main = 23;")
				] : FileMap),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--b", "src", "--verbose"]
			},
			{
				subScenario: "when declaration file used inferred type from referenced project",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
							\"paths\": { \"@fluentui/*\": [\"./packages/*/src\"] },
						},
					}"),
					"/home/src/workspaces/project/packages/pkg1/src/index.ts" => Stringtestutil.Dedent("
					export interface IThing {
						a: string;
					}
					export interface IThings {
						thing1: IThing;
					}
				"),
					"/home/src/workspaces/project/packages/pkg1/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"extends\": \"../../tsconfig\",
						\"compilerOptions\": { \"outDir\": \"lib\" },
						\"include\": [\"src\"],
					}
				"),
					"/home/src/workspaces/project/packages/pkg2/src/index.ts" => Stringtestutil.Dedent("
					import { IThings } from '@fluentui/pkg1';
					export function fn4() {
						const a: IThings = { thing1: { a: 'b' } };
						return a.thing1;
					}
				"),
					"/home/src/workspaces/project/packages/pkg2/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"extends\": \"../../tsconfig\",
						\"compilerOptions\": { \"outDir\": \"lib\" },
						\"include\": [\"src\"],
						\"references\": [{ \"path\": \"../pkg1\" }],
					}
				")
				] : FileMap),
				commandLineArgs: ["--b", "packages/pkg2/tsconfig.json", "--verbose"]
			},
			{
				subScenario: "when inferred export should reuse imported type alias across a module boundary",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"strict\": true,
							\"declaration\": true,
							\"emitDeclarationOnly\": true,
							\"target\": \"es2022\",
							\"module\": \"esnext\",
						},
						\"files\": [\"./a.ts\", \"./factory.ts\", \"./state.ts\"],
					}"),
					Tsctests.tscLibPath + "/lib.es2022.full.d.ts" => Tsctests.tscDefaultLibContent + "\n" + Stringtestutil.Dedent("
					type Partial<T> = {
						[K in keyof T]?: T[K];
					};
				"),
					"/home/src/workspaces/project/a.ts" => Stringtestutil.Dedent("
					interface ISettings {
						age: number;
					}

					export type Settings = Partial<ISettings>;
				"),
					"/home/src/workspaces/project/factory.ts" => Stringtestutil.Dedent("
					import type { Settings } from \"./a\";

					export const makeObj = () => ({
						fn: (s?: Settings): Settings | undefined => s,
					});
				"),
					"/home/src/workspaces/project/state.ts" => Stringtestutil.Dedent("
					import { makeObj } from \"./factory\";

					export const obj = makeObj();
				")
				] : FileMap),
				commandLineArgs: ["--p", "tsconfig.json"]
			},
			{
				subScenario:     "reports dts generation errors",
				files:           getTscDeclarationEmitDtsErrorsFileMap(false, false),
				commandLineArgs: ["-b", "--explainFiles", "--listEmittedFiles", "--v"],
				edits:           noChangeOnlyEdit
			},
			{
				subScenario:     "reports dts generation errors with incremental",
				files:           getTscDeclarationEmitDtsErrorsFileMap(false, true),
				commandLineArgs: ["-b", "--explainFiles", "--listEmittedFiles", "--v"],
				edits:           noChangeOnlyEdit
			},
			{
				subScenario:     "reports dts generation errors",
				files:           getTscDeclarationEmitDtsErrorsFileMap(false, false),
				commandLineArgs: ["--explainFiles", "--listEmittedFiles"],
				edits: ([
					noChange,
					{
						caption:         "build -b",
						commandLineArgs: ["-b", "--explainFiles", "--listEmittedFiles", "--v"]
					}
				] : Array<TscEdit>)
			},
			{
				subScenario:     "reports dts generation errors with incremental",
				files:           getTscDeclarationEmitDtsErrorsFileMap(true, true),
				commandLineArgs: ["--explainFiles", "--listEmittedFiles"],
				edits: ([
					noChange,
					{
						caption:         "build -b",
						commandLineArgs: ["-b", "--explainFiles", "--listEmittedFiles", "--v"]
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "when using Windows paths and uppercase letters",
				files: ([
					"D:/Work/pkg1/package.json" => Stringtestutil.Dedent("
				{
					\"name\": \"ts-specifier-bug\",
					\"version\": \"1.0.0\",
					\"main\": \"index.js\"
				}"),
					"D:/Work/pkg1/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"declaration\": true,
						\"target\": \"es2017\",
						\"outDir\": \"./dist\",
					},
					\"include\": [\"src\"],
				}"),
					"D:/Work/pkg1/src/main.ts" => Stringtestutil.Dedent("
					import { PartialType } from './utils';

					class Common {}
					
					export class Sub extends PartialType(Common) {
						id: string;
					}
				"),
					"D:/Work/pkg1/src/utils/index.ts" => Stringtestutil.Dedent("
					import { MyType, MyReturnType } from './type-helpers';

					export function PartialType<T>(classRef: MyType<T>) {
						abstract class PartialClassType {
							constructor() {}
						}
					
						return PartialClassType as MyReturnType;
					}
				"),
					"D:/Work/pkg1/src/utils/type-helpers.ts" => Stringtestutil.Dedent("
					export type MyReturnType = {	
						new (...args: any[]): any;
					};
				
					export interface MyType<T = any> extends Function {
						new (...args: any[]): T;
					}
				")
				] : FileMap),
				cwd:              "D:/Work/pkg1",
				windowsStyleRoot: "D:/",
				ignoreCase:       true,
				commandLineArgs:  ["-p", "D:\\Work\\pkg1", "--explainFiles"]
			},
			{
				subScenario: "when same version is referenced through source and another symlinked package",
				files: ([
					"/user/username/projects/myproject/plugin-two/index.d.ts" =>                               pluginTwoDts(),
					"/user/username/projects/myproject/plugin-two/node_modules/typescript-fsa/package.json" => fsaPackageJson(),
					"/user/username/projects/myproject/plugin-two/node_modules/typescript-fsa/index.d.ts" =>   fsaIndex(),
					"/user/username/projects/myproject/plugin-one/tsconfig.json" =>                            pluginOneConfig(),
					"/user/username/projects/myproject/plugin-one/index.ts" =>                                 pluginOneIndex(),
					"/user/username/projects/myproject/plugin-one/action.ts" =>                                pluginOneAction(),
					"/user/username/projects/myproject/plugin-one/node_modules/typescript-fsa/package.json" => fsaPackageJson(),
					"/user/username/projects/myproject/plugin-one/node_modules/typescript-fsa/index.d.ts" =>   fsaIndex(),
					"/user/username/projects/myproject/plugin-one/node_modules/plugin-two" =>                  Vfstest.Symlink("/user/username/projects/myproject/plugin-two")
				] : FileMap),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: ["-p", "plugin-one", "--explainFiles"]
			},
			{
				subScenario: "when same version is referenced through source and another symlinked package with indirect link",
				files: ([
					"/user/username/projects/myproject/plugin-two/package.json" => Stringtestutil.Dedent("
				{
					\"name\": \"plugin-two\",
					\"version\": \"0.1.3\",
					\"main\": \"dist/commonjs/index.js\"
				}"),
					"/user/username/projects/myproject/plugin-two/dist/commonjs/index.d.ts" =>                 pluginTwoDts(),
					"/user/username/projects/myproject/plugin-two/node_modules/typescript-fsa/package.json" => fsaPackageJson(),
					"/user/username/projects/myproject/plugin-two/node_modules/typescript-fsa/index.d.ts" =>   fsaIndex(),
					"/user/username/projects/myproject/plugin-one/tsconfig.json" =>                            pluginOneConfig(),
					"/user/username/projects/myproject/plugin-one/index.ts" =>                                 pluginOneIndex() + "\n" + pluginOneAction(),
					"/user/username/projects/myproject/plugin-one/node_modules/typescript-fsa/package.json" => fsaPackageJson(),
					"/user/username/projects/myproject/plugin-one/node_modules/typescript-fsa/index.d.ts" =>   fsaIndex(),
					"/temp/yarn/data/link/plugin-two" =>                                                       Vfstest.Symlink("/user/username/projects/myproject/plugin-two"),
					"/user/username/projects/myproject/plugin-one/node_modules/plugin-two" =>                  Vfstest.Symlink("/temp/yarn/data/link/plugin-two")
				] : FileMap),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: ["-p", "plugin-one", "--explainFiles"]
			},
			{
				// !!! sheetal strada has error for d.ts generation in pkg3/src/keys.ts but corsa doesnt have that
				subScenario: "when pkg references sibling package through indirect symlink",
				files: ([
					"/user/username/projects/myproject/pkg1/dist/index.d.ts" => "export * from './types';",
					"/user/username/projects/myproject/pkg1/dist/types.d.ts" => Stringtestutil.Dedent("
					export declare type A = {
						id: string;
					};
					export declare type B = {
						id: number;
					};
					export declare type IdType = A | B;
					export declare class MetadataAccessor<T, D extends IdType = IdType> {
						readonly key: string;
						private constructor();
						toString(): string;
						static create<T, D extends IdType = IdType>(key: string): MetadataAccessor<T, D>;
					}"),
					"/user/username/projects/myproject/pkg1/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"@raymondfeng/pkg1\",
						\"version\": \"1.0.0\",
						\"main\": \"dist/index.js\",
						\"typings\": \"dist/index.d.ts\"
					}"),
					"/user/username/projects/myproject/pkg2/dist/index.d.ts" => "export * from './types';",
					"/user/username/projects/myproject/pkg2/dist/types.d.ts" => "export {MetadataAccessor} from '@raymondfeng/pkg1';",
					"/user/username/projects/myproject/pkg2/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"@raymondfeng/pkg2\",
						\"version\": \"1.0.0\",
						\"main\": \"dist/index.js\",
						\"typings\": \"dist/index.d.ts\"
					}"),
					"/user/username/projects/myproject/pkg3/src/index.ts" => "export * from './keys';",
					"/user/username/projects/myproject/pkg3/src/keys.ts" => Stringtestutil.Dedent("
					import {MetadataAccessor} from \"@raymondfeng/pkg2\";
					export const ADMIN = MetadataAccessor.create<boolean>('1');"),
					"/user/username/projects/myproject/pkg3/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": {
                            \"outDir\": \"dist\",
                            \"rootDir\": \"src\",
                            \"target\": \"es5\",
                            \"module\": \"commonjs\",
                            \"strict\": true,
                            \"esModuleInterop\": true,
                            \"declaration\": true,
                        },
                    }"),
					"/user/username/projects/myproject/pkg2/node_modules/@raymondfeng/pkg1" => Vfstest.Symlink("/user/username/projects/myproject/pkg1"),
					"/user/username/projects/myproject/pkg3/node_modules/@raymondfeng/pkg2" => Vfstest.Symlink("/user/username/projects/myproject/pkg2")
				] : FileMap),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: ["-p", "pkg3", "--explainFiles"]
			}
		] : Array<TscInput>);

		for (test in testCases) {
			test.run("declarationEmit");
		}
	}

	public static function TestTscExtends() {
		var getBuildConfigFileExtendsFileMap = function():FileMap {
			return ([
				"/home/src/workspaces/solution/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"references\": [
						{ \"path\": \"./shared/tsconfig.json\" },
						{ \"path\": \"./webpack/tsconfig.json\" },
					],
					\"files\": [],
				}"),
				"/home/src/workspaces/solution/shared/tsconfig-base.json" => Stringtestutil.Dedent("
				{
					\"include\": [\"./typings-base/\"],
				}"),
				"/home/src/workspaces/solution/shared/typings-base/globals.d.ts" => "type Unrestricted = any;",
				"/home/src/workspaces/solution/shared/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"./tsconfig-base.json\",
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"../target-tsc-build/\",
						\"rootDir\": \"..\",
					},
					\"files\": [\"./index.ts\"],
				}"),
				"/home/src/workspaces/solution/shared/index.ts" => "export const a: Unrestricted = 1;",
				"/home/src/workspaces/solution/webpack/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"../shared/tsconfig-base.json\",
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"../target-tsc-build/\",
						\"rootDir\": \"..\",
					},
					\"files\": [\"./index.ts\"],
					\"references\": [{ \"path\": \"../shared/tsconfig.json\" }],
				}"),
				"/home/src/workspaces/solution/webpack/index.ts" => "export const b: Unrestricted = 1;"
			] : FileMap);
		};
		var getTscExtendsWithSymlinkTestCase = function(builtType:String):TscInput {
			return ({
				subScenario: "resolves the symlink path",
				files: ([
					"/users/user/projects/myconfigs/node_modules/@something/tsconfig-node/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"extends\": \"@something/tsconfig-base/tsconfig.json\",
						\"compilerOptions\": {
							\"removeComments\": true
						}
					}
				"),
					"/users/user/projects/myconfigs/node_modules/@something/tsconfig-base/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": { \"composite\": true }
					}
				"),
					"/users/user/projects/myproject/src/index.ts" => Stringtestutil.Dedent("
					// some comment
					export const x = 10;
				"),
					"/users/user/projects/myproject/src/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"extends\": \"@something/tsconfig-node/tsconfig.json\"
					}"),
					"/users/user/projects/myproject/node_modules/@something/tsconfig-node" => Vfstest.Symlink("/users/user/projects/myconfigs/node_modules/@something/tsconfig-node")
				] : FileMap),
				cwd:             "/users/user/projects/myproject",
				commandLineArgs: [builtType, "src", "--extendedDiagnostics"]
			} : TscInput);
		};
		var getTscExtendsConfigDirTestCase = function(subScenarioSufix:String, commandLineArgs:Array<String>, edits:Array<TscEdit>):TscInput {
			return ({
				subScenario: "configDir template" + subScenarioSufix,
				files: ([
					"/home/src/projects/configs/first/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"../second/tsconfig.json\",
					\"include\": [\"${configDir}/src\"],
					\"compilerOptions\": {
						\"typeRoots\": [\"root1\", \"${configDir}/root2\", \"root3\"],
						\"types\": [],
					},
				}"),
					"/home/src/projects/configs/second/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"files\": [\"${configDir}/main.ts\"],
					\"compilerOptions\": {
						\"declarationDir\": \"${configDir}/decls\",
						\"paths\": {
							\"@myscope/*\": [\"${configDir}/types/*\"],
						},
					},
					\"watchOptions\": {
						\"excludeFiles\": [\"${configDir}/main.ts\"],
					},
				}"),
					"/home/src/projects/myproject/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"../configs/first/tsconfig.json\",
					\"compilerOptions\": {
						\"declaration\": true,
						\"outDir\": \"outDir\",
						\"traceResolution\": true,
					},
				}"),
					"/home/src/projects/myproject/main.ts" => Stringtestutil.Dedent("
					// some comment
					export const y = 10;
					import { x } from \"@myscope/sometype\";
				"),
					"/home/src/projects/myproject/types/sometype.ts" => Stringtestutil.Dedent("
					export const x = 10;
				")
				] : FileMap),
				cwd:             "/home/src/projects/myproject",
				commandLineArgs: commandLineArgs,
				edits:           edits
			} : TscInput);
		};
		var getTscExtendsNonStringPathTestCase = function(propertyName:String):TscInput {
			return ({
				subScenario: "extends config with non-string " + propertyName,
				files: ([
					"/home/src/projects/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"extends\": \"./base.json\",
					}"),
					"/home/src/projects/project/base.json" => Stringtestutil.Dedent("
					{
						\"" + propertyName + "\": [1],
					}"),
					"/home/src/projects/project/main.ts" => "export const x = 1;"
				] : FileMap),
				cwd:             "/home/src/projects/project",
				commandLineArgs: ["-p", "tsconfig.json", "--pretty", "false"]
			} : TscInput);
		};
		var getTscExtendsBase = function(baseContents:String):FileMap {
			return ([
				"/home/src/projects/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"./base.json\",
				}"),
				"/home/src/projects/project/base.json" => Stringtestutil.Dedent(baseContents),
				"/home/src/projects/project/main.ts" =>   "export const x = 1;"
			] : FileMap);
		};
		var testCases = ([
			{
				subScenario:     "when building solution with projects extends config with include",
				files:           getBuildConfigFileExtendsFileMap(),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--b", "--v", "--listFiles"]
			},
			getTscExtendsNonStringPathTestCase("include"),
			getTscExtendsNonStringPathTestCase("exclude"),
			getTscExtendsNonStringPathTestCase("files"),
			{
				subScenario: "extends config with mixed valid and non-string include",
				files: getTscExtendsBase("
				{
					\"include\": [\"main.ts\", 1],
				}"),
				cwd:             "/home/src/projects/project",
				commandLineArgs: ["-p", "tsconfig.json", "--pretty", "false"]
			},
			{
				subScenario:     "when building project uses reference and both extend config with include",
				files:           getBuildConfigFileExtendsFileMap(),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--b", "webpack/tsconfig.json", "--v", "--listFiles"]
			},
			getTscExtendsWithSymlinkTestCase("-p"),
			getTscExtendsWithSymlinkTestCase("-b"),
			getTscExtendsConfigDirTestCase("", ["--explainFiles"], null),
			getTscExtendsConfigDirTestCase(" showConfig", ["--showConfig"], null),
			getTscExtendsConfigDirTestCase(" with commandline", ["--explainFiles", "--outDir", "${configDir}/outDir"], null),
			getTscExtendsConfigDirTestCase("", ["--b", "--explainFiles", "--v"], null),
			getTscExtendsConfigDirTestCase("", ["--b", "-w", "--explainFiles", "--v"], ([
				{
					caption: "edit extended config file",
					edit: (sys:TestSys) -> {
						sys.writeFileNoError(
							"/home/src/projects/configs/first/tsconfig.json",
							Stringtestutil.Dedent("
						{
							\"extends\": \"../second/tsconfig.json\",
							\"include\": [\"${configDir}/src\"],
							\"compilerOptions\": {
								\"typeRoots\": [\"${configDir}/root2\"],
								\"types\": [],
							},
						}")
						);
					}
				}
			] : Array<TscEdit>))
		] : Array<TscInput>);

		for (test in testCases) {
			test.run("extends");
		}
	}

	public static function TestForceConsistentCasingInFileNames() {
		var testCases = ([
			{
				subScenario: "with relative and non relative file resolutions",
				files: ([
					"/user/username/projects/myproject/src/struct.d.ts" => Stringtestutil.Dedent("
                    import * as xs1 from \"fp-ts/lib/Struct\";
                    import * as xs2 from \"fp-ts/lib/struct\";
                    import * as xs3 from \"./Struct\";
                    import * as xs4 from \"./struct\";
                "),
					"/user/username/projects/myproject/node_modules/fp-ts/lib/struct.d.ts" => "export function foo(): void"
				] : FileMap),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: ["/user/username/projects/myproject/src/struct.d.ts", "--forceConsistentCasingInFileNames", "--explainFiles"],
				ignoreCase:      true
			},
			{
				subScenario: "when file is included from multiple places with different casing",
				files: ([
					"/home/src/projects/project/src/struct.d.ts" => Stringtestutil.Dedent("
					import * as xs1 from \"fp-ts/lib/Struct\";
					import * as xs2 from \"fp-ts/lib/struct\";
					import * as xs3 from \"./Struct\";
					import * as xs4 from \"./struct\";
				"),
					"/home/src/projects/project/src/anotherFile.ts" => Stringtestutil.Dedent("
					import * as xs1 from \"fp-ts/lib/Struct\";
					import * as xs2 from \"fp-ts/lib/struct\";
					import * as xs3 from \"./Struct\";
					import * as xs4 from \"./struct\";
				"),
					"/home/src/projects/project/src/oneMore.ts" => Stringtestutil.Dedent("
					import * as xs1 from \"fp-ts/lib/Struct\";
					import * as xs2 from \"fp-ts/lib/struct\";
					import * as xs3 from \"./Struct\";
					import * as xs4 from \"./struct\";
				"),
					"/home/src/projects/project/tsconfig.json" =>                      "{}",
					"/home/src/projects/project/node_modules/fp-ts/lib/struct.d.ts" => "export function foo(): void"
				] : FileMap),
				cwd:             "/home/src/projects/project",
				commandLineArgs: ["--explainFiles"],
				ignoreCase:      true
			},
			{
				subScenario: "with type ref from file",
				files: ([
					"/user/username/projects/myproject/src/fileOne.d.ts" => "declare class c { }",
					"/user/username/projects/myproject/src/file2.d.ts" => Stringtestutil.Dedent("
                    /// <reference types=\"./fileOne.d.ts\"/>
                    declare const y: c;
                "),
					"/user/username/projects/myproject/tsconfig.json" => "{ }"
				] : FileMap),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: ["-p", "/user/username/projects/myproject", "--explainFiles", "--traceResolution"],
				ignoreCase:      true
			},
			{
				subScenario: "with triple slash ref from file",
				files: ([
					"/home/src/workspaces/project/src/c.ts" =>      "/// <reference path=\"./D.ts\"/>",
					"/home/src/workspaces/project/src/d.ts" =>      "declare class c { }",
					"/home/src/workspaces/project/tsconfig.json" => "{ }"
				] : FileMap),
				ignoreCase: true
			},
			{
				subScenario: "two files exist on disk that differs only in casing",
				files: ([
					"/home/src/workspaces/project/c.ts" => "import {x} from \"./D\"",
					"/home/src/workspaces/project/D.ts" => "export const x = 10;",
					"/home/src/workspaces/project/d.ts" => "export const y = 20;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"files\": [\"c.ts\", \"d.ts\"]
					}")
				] : FileMap)
			}
		] : Array<TscInput>);
		for (test in testCases) {
			test.run("forceConsistentCasingInFileNames");
		}
	}

	public static function TestTscIgnoreConfig() {
		var filesWithoutConfig = function():FileMap {
			return ([
				"/home/src/workspaces/project/src/a.ts" => "export const a = 10;",
				"/home/src/workspaces/project/src/b.ts" => "export const b = 10;",
				"/home/src/workspaces/project/c.ts" =>     "export const c = 10;"
			] : FileMap);
		};
		var filesWithConfig = function():FileMap {
			var files = filesWithoutConfig();
			files["/home/src/workspaces/project/tsconfig.json"] = Stringtestutil.Dedent("
			{
                \"include\": [\"src\"],
			}");
			return files;
		};
		var getScenarios = function(subScenario:String, commandLineArgs:Array<String>):Array<TscInput> {
			var commandLineArgsIgnoreConfig = append(commandLineArgs, "--ignoreConfig");
			return ([
				{
					subScenario:     subScenario,
					files:           filesWithConfig(),
					commandLineArgs: commandLineArgs
				},
				{
					subScenario:     subScenario + " with --ignoreConfig",
					files:           filesWithConfig(),
					commandLineArgs: commandLineArgsIgnoreConfig
				},
				{
					subScenario:     subScenario + " when config file absent",
					files:           filesWithoutConfig(),
					commandLineArgs: commandLineArgs
				},
				{
					subScenario:     subScenario + " when config file absent with --ignoreConfig",
					files:           filesWithoutConfig(),
					commandLineArgs: commandLineArgsIgnoreConfig
				}
			] : Array<TscInput>);
		};
		var testCases = Slices.Concat(
			getScenarios("without any options", null),
			getScenarios("specifying files", ["src/a.ts"]),
			getScenarios("specifying project", ["-p", "."]),
			getScenarios("mixing project and files", ["-p", ".", "src/a.ts", "c.ts"])
		);
		for (test in testCases) {
			test.run("ignoreConfig");
		}
	}

	public static function TestTscIncremental() {
		var getConstEnumTest = function(bdsContents:String, changeEnumFile:String, testSuffix:String):TscInput {
			return ({
				subScenario: "const enums" + testSuffix,
				files: ([
					"/home/src/workspaces/project/a.ts" => Stringtestutil.Dedent("
					import {A} from \"./c\"
					let a = A.ONE
				"),
					"/home/src/workspaces/project/b.d.ts" => Stringtestutil.Dedent(bdsContents),
					"/home/src/workspaces/project/c.ts" => Stringtestutil.Dedent("
					import {A} from \"./b\"
					let b = A.ONE
					export {A}
				"),
					"/home/src/workspaces/project/worker.d.ts" => Stringtestutil.Dedent("
					export const enum AWorker {
						ONE = 1
					}
				")
				] : FileMap),
				commandLineArgs: ["-i", "a.ts", "--tsbuildinfofile", "a.tsbuildinfo"],
				edits: ([
					{
						caption: "change enum value",
						edit: (sys:TestSys) -> {
							sys.replaceFileText(changeEnumFile, "1", "2");
						}
					},
					{
						caption: "change enum value again",
						edit: (sys:TestSys) -> {
							sys.replaceFileText(changeEnumFile, "2", "3");
						}
					},
					{
						caption: "something else changes in b.d.ts",
						edit: (sys:TestSys) -> {
							sys.appendFile("/home/src/workspaces/project/b.d.ts", "export const randomThing = 10;");
						}
					},
					{
						caption: "something else changes in b.d.ts again",
						edit: (sys:TestSys) -> {
							sys.appendFile("/home/src/workspaces/project/b.d.ts", "export const randomThing2 = 10;");
						}
					}
				] : Array<TscEdit>)
			} : TscInput);
		};
		var testCases = ([
			{
				subScenario: "serializing error chain",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"incremental\": true,
                        \"strict\": true,
                        \"jsx\": \"react\",
                        \"module\": \"esnext\",
                    },
                }"),
					"/home/src/workspaces/project/index.tsx" => Stringtestutil.Dedent("
                    declare namespace JSX {
                        interface ElementChildrenAttribute { children: {}; }
                        interface IntrinsicElements { div: {} }
                    }

                    declare var React: any;

                    declare function Component(props: never): any;
                    declare function Component(props: { children?: number }): any;
                    (<Component>
                        <div />
                        <div />
                    </Component>)")
				] : FileMap),
				edits: noChangeOnlyEdit
			},
			{
				subScenario: "serializing composite project",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"composite\": true,
                        \"strict\": true,
                        \"module\": \"esnext\",
                    },
                }"),
					"/home/src/workspaces/project/index.tsx" => "export const a = 1;",
					"/home/src/workspaces/project/other.ts" =>  "export const b = 2;"
				] : FileMap)
			},
			{
				subScenario: "change to modifier of class expression field with declaration emit enabled",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{ 
					\"compilerOptions\": {
						\"module\": \"esnext\",
						\"declaration\": true
					}
				}"),
					"/home/src/workspaces/project/main.ts" => Stringtestutil.Dedent("
                        import MessageablePerson from './MessageablePerson.js';
                        function logMessage( person: MessageablePerson ) {
                            console.log( person.message );
                        }"),
					"/home/src/workspaces/project/MessageablePerson.ts" => Stringtestutil.Dedent("
                        const Messageable = () => {
                            return class MessageableClass {
                                public message = 'hello';
                            }
                        };
                        const wrapper = () => Messageable();
                        type MessageablePerson = InstanceType<ReturnType<typeof wrapper>>;
                        export default MessageablePerson;"),
					Tsctests.tscLibPath + "/lib.d.ts" => Tsctests.tscDefaultLibContent + "\n" + Stringtestutil.Dedent("
					type ReturnType<T extends (...args: any) => any> = T extends (...args: any) => infer R ? R : any;
                    type InstanceType<T extends abstract new (...args: any) => any> = T extends abstract new (...args: any) => infer R ? R : any;")
				] : FileMap),
				commandLineArgs: ["--incremental"],
				edits: ([
					noChange,
					{
						caption: "modify public to protected",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/home/src/workspaces/project/MessageablePerson.ts", "public", "protected");
						}
					},
					noChange,
					{
						caption: "modify protected to public",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/home/src/workspaces/project/MessageablePerson.ts", "protected", "public");
						}
					},
					noChange
				] : Array<TscEdit>)
			},
			{
				subScenario: "change to modifier of class expression field",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{ 
					\"compilerOptions\": { 
						\"module\": \"esnext\"
					}
				}"),
					"/home/src/workspaces/project/main.ts" => Stringtestutil.Dedent("
					import MessageablePerson from './MessageablePerson.js';
					function logMessage( person: MessageablePerson ) {
						console.log( person.message );
					}"),
					"/home/src/workspaces/project/MessageablePerson.ts" => Stringtestutil.Dedent("
					const Messageable = () => {
						return class MessageableClass {
							public message = 'hello';
						}
					};
					const wrapper = () => Messageable();
					type MessageablePerson = InstanceType<ReturnType<typeof wrapper>>;
					export default MessageablePerson;"),
					Tsctests.tscLibPath + "/lib.d.ts" => Tsctests.tscDefaultLibContent + "\n" + Stringtestutil.Dedent("
					type ReturnType<T extends (...args: any) => any> = T extends (...args: any) => infer R ? R : any;
                    type InstanceType<T extends abstract new (...args: any) => any> = T extends abstract new (...args: any) => infer R ? R : any;")
				] : FileMap),
				commandLineArgs: ["--incremental"],
				edits: ([
					noChange,
					{
						caption: "modify public to protected",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/home/src/workspaces/project/MessageablePerson.ts", "public", "protected");
						}
					},
					noChange,
					{
						caption: "modify protected to public",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/home/src/workspaces/project/MessageablePerson.ts", "protected", "public");
						}
					},
					noChange
				] : Array<TscEdit>)
			},
			{
				subScenario: "when passing filename for buildinfo on commandline",
				files: ([
					"/home/src/workspaces/project/src/main.ts" => "export const x = 10;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"target\": \"es5\",
                        \"module\": \"commonjs\"
                    },
                    \"include\": [
                        \"src/**/*.ts\"
                    ],
                }")
				] : FileMap),
				commandLineArgs: ["--incremental", "--tsBuildInfoFile", ".tsbuildinfo", "--explainFiles"],
				edits:           noChangeOnlyEdit
			},
			{
				subScenario: "when passing rootDir from commandline",
				files: ([
					"/home/src/workspaces/project/src/main.ts" => "export const x = 10;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"incremental\": true,
                        \"outDir\": \"dist\"
                    }
                }")
				] : FileMap),
				commandLineArgs: ["--rootDir", "src"],
				edits:           noChangeOnlyEdit
			},
			{
				subScenario: "with only dts files",
				files: ([
					"/home/src/workspaces/project/src/main.d.ts" =>    "export const x = 10;",
					"/home/src/workspaces/project/src/another.d.ts" => "export const y = 10;",
					"/home/src/workspaces/project/tsconfig.json" =>    "{}"
				] : FileMap),
				commandLineArgs: ["--incremental"],
				edits: ([
					noChange,
					{
						caption: "modify d.ts file",
						edit: (sys:TestSys) -> {
							sys.appendFile("/home/src/workspaces/project/src/main.d.ts", "export const xy = 100;");
						}
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "when passing rootDir is in the tsconfig",
				files: ([
					"/home/src/workspaces/project/src/main.ts" => "export const x = 10;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"incremental\": true,
                        \"outDir\": \"dist\",
						\"rootDir\": \"./\"
                    }
                }")
				] : FileMap),
				edits: noChangeOnlyEdit
			},
			{
				subScenario: "tsbuildinfo has error",
				files: ([
					"/home/src/workspaces/project/main.ts" =>              "export const x = 10;",
					"/home/src/workspaces/project/tsconfig.json" =>        "{}",
					"/home/src/workspaces/project/tsconfig.tsbuildinfo" => "Some random string"
				] : FileMap),
				commandLineArgs: ["-i"],
				edits: ([
					{
						caption: "tsbuildinfo written has error",
						edit: (sys:TestSys) -> {
							sys.prependFile("/home/src/workspaces/project/tsconfig.tsbuildinfo", "Some random string");
						}
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "when global file is added, the signatures are updated",
				files: ([
					"/home/src/workspaces/project/src/main.ts" => Stringtestutil.Dedent("
                    /// <reference path=\"./filePresent.ts\"/>
                    /// <reference path=\"./fileNotFound.ts\"/>
                    function main() { }
                "),
					"/home/src/workspaces/project/src/anotherFileWithSameReferenes.ts" => Stringtestutil.Dedent("
                    /// <reference path=\"./filePresent.ts\"/>
                    /// <reference path=\"./fileNotFound.ts\"/>
                    function anotherFileWithSameReferenes() { }
                "),
					"/home/src/workspaces/project/src/filePresent.ts" => "function something() { return 10; }",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": { \"composite\": true },
                    \"include\": [\"src/**/*.ts\"],
                }")
				] : FileMap),
				commandLineArgs: [],
				edits: ([
					noChange,
					{
						caption: "Modify main file",
						edit: (sys:TestSys) -> {
							sys.appendFile("/home/src/workspaces/project/src/main.ts", "something();");
						}
					},
					{
						caption: "Modify main file again",
						edit: (sys:TestSys) -> {
							sys.appendFile("/home/src/workspaces/project/src/main.ts", "something();");
						}
					},
					{
						caption: "Add new file and update main file",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/home/src/workspaces/project/src/newFile.ts", "function foo() { return 20; }");
							sys.prependFile(
								"/home/src/workspaces/project/src/main.ts",
								"/// <reference path=\"./newFile.ts\"/>
"
							);
							sys.appendFile("/home/src/workspaces/project/src/main.ts", "foo();");
						}
					},
					{
						caption: "Write file that could not be resolved",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/home/src/workspaces/project/src/fileNotFound.ts", "function something2() { return 20; }");
						}
					},
					{
						caption: "Modify main file",
						edit: (sys:TestSys) -> {
							sys.appendFile("/home/src/workspaces/project/src/main.ts", "something();");
						}
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "react-jsx-emit-mode with no backing types found doesnt crash",
				files: ([
					"/home/src/workspaces/project/node_modules/react/jsx-runtime.js" => "export {}", // js needs to be present so there's a resolution result
					"/home/src/workspaces/project/node_modules/@types/react/index.d.ts" => Stringtestutil.Dedent("
					export {};
					declare global {
						namespace JSX {
							interface Element {}
							interface IntrinsicElements {
								div: {
									propA?: boolean;
								};
							}
						}
					}"), // doesn't contain a jsx-runtime definition
					"/home/src/workspaces/project/src/index.tsx" => "export const App = () => <div propA={true}></div>;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{ 
					\"compilerOptions\": { 
						\"module\": \"commonjs\",
						\"jsx\": \"react-jsx\", 
						\"incremental\": true, 
						\"jsxImportSource\": \"react\" 
					} 
				}")
				] : FileMap)
			},
			{
				subScenario: "react-jsx-emit-mode with no backing types found doesnt crash under --strict",
				files: ([
					"/home/src/workspaces/project/node_modules/react/jsx-runtime.js" => "export {}", // js needs to be present so there's a resolution result
					"/home/src/workspaces/project/node_modules/@types/react/index.d.ts" => Stringtestutil.Dedent("
					export {};
					declare global {
						namespace JSX {
							interface Element {}
							interface IntrinsicElements {
								div: {
									propA?: boolean;
								};
							}
						}
					}"), // doesn't contain a jsx-runtime definition
					"/home/src/workspaces/project/src/index.tsx" => "export const App = () => <div propA={true}></div>;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{ 
					\"compilerOptions\": { 
						\"module\": \"commonjs\",
						\"jsx\": \"react-jsx\", 
						\"incremental\": true, 
						\"jsxImportSource\": \"react\" 
					} 
				}")
				] : FileMap),
				commandLineArgs: ["--strict"]
			},
			{
				subScenario: "change to type that gets used as global through export in another file",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true
					}
				}"),
					"/home/src/workspaces/project/class1.ts" => Stringtestutil.Dedent("
					const a: MagicNumber = 1;
					console.log(a);"),
					"/home/src/workspaces/project/constants.ts" => "export default 1;",
					"/home/src/workspaces/project/types.d.ts" =>   "type MagicNumber = typeof import('./constants').default"
				] : FileMap),
				edits: ([
					{
						caption: "Modify imports used in global file",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/home/src/workspaces/project/constants.ts", "export default 2;");
						}
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "change to type that gets used as global through export in another file through indirect import",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true
					}
				}"),
					"/home/src/workspaces/project/class1.ts" => Stringtestutil.Dedent("
					const a: MagicNumber = 1;
					console.log(a);"),
					"/home/src/workspaces/project/constants.ts" => "export default 1;",
					"/home/src/workspaces/project/reexport.ts" =>  "export { default as ConstantNumber } from \"./constants\"",
					"/home/src/workspaces/project/types.d.ts" =>   "type MagicNumber = typeof import('./reexport').ConstantNumber"
				] : FileMap),
				edits: ([
					{
						caption: "Modify imports used in global file",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/home/src/workspaces/project/constants.ts", "export default 2;");
						}
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "when file is deleted",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"outDir\"
					}
				}"),
					"/home/src/workspaces/project/file1.ts" => "export class  C { }",
					"/home/src/workspaces/project/file2.ts" => "export class D { }"
				] : FileMap),
				edits: ([
					{
						caption: "delete file with imports",
						edit: (sys:TestSys) -> {
							sys.removeNoError("/home/src/workspaces/project/file2.ts");
						}
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "generates typerefs correctly",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"outDir\",
						\"checkJs\": true
					},
					\"include\": [\"src\"],
				}"),
					"/home/src/workspaces/project/src/box.ts" => Stringtestutil.Dedent("
                    export interface Box<T> {
                        unbox(): T
                    }
                "),
					"/home/src/workspaces/project/src/bug.js" => Stringtestutil.Dedent("
                    import * as B from \"./box.js\"
                    import * as W from \"./wrap.js\"

                    /**
                     * @template {object} C
                     * @param {C} source
                     * @returns {W.Wrap<C>}
                     */
                    const wrap = source => {
                    throw source
                    }

                    /**
                     * @returns {B.Box<number>}
                     */
                    const box = (n = 0) => ({ unbox: () => n })

                    export const bug = wrap({ n: box(1) });
                "),
					"/home/src/workspaces/project/src/wrap.ts" => Stringtestutil.Dedent("
                    export type Wrap<C> = {
                        [K in keyof C]: { wrapped: C[K] }
                    }
                ")
				] : FileMap),
				edits: ([
					{
						caption: "modify js file",
						edit: (sys:TestSys) -> {
							sys.appendFile("/home/src/workspaces/project/src/bug.js", "export const something = 1;");
						}
					}
				] : Array<TscEdit>)
			},
			getConstEnumTest("
			export const enum A {
				ONE = 1
			}
		", "/home/src/workspaces/project/b.d.ts", ""),
			getConstEnumTest("
			export const enum AWorker {
				ONE = 1
			}
			export { AWorker as A };
		", "/home/src/workspaces/project/b.d.ts", " aliased"),
			getConstEnumTest("export { AWorker as A } from \"./worker\";", "/home/src/workspaces/project/worker.d.ts", " aliased in different file"),
			{
				subScenario: "option changes with composite",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
					}
				}"),
					"/home/src/workspaces/project/a.ts" => "export const a = 10;const aLocal = 10;",
					"/home/src/workspaces/project/b.ts" => "export const b = 10;const bLocal = 10;",
					"/home/src/workspaces/project/c.ts" => "import { a } from \"./a\";export const c = a;",
					"/home/src/workspaces/project/d.ts" => "import { b } from \"./b\";export const d = b;"
				] : FileMap),
				edits: ([
					{
						caption:         "with sourceMap",
						commandLineArgs: ["--sourceMap"]
					},
					{
						caption: "should re-emit only js so they dont contain sourcemap"
					},
					{
						caption:         "with declaration should not emit anything",
						commandLineArgs: ["--declaration"]
						// discrepancyExplanation: () => [
						// 	`Clean build tsbuildinfo will have compilerOptions with composite and ${option.replace(/-/g, "")}`,
						// 	`Incremental build will detect that it doesnt need to rebuild so tsbuild info is from before which has option composite only`,
						// ],
					},
					noChange,
					{
						caption:         "with declaration and declarationMap",
						commandLineArgs: ["--declaration", "--declarationMap"]
					},
					{
						caption: "should re-emit only dts so they dont contain sourcemap"
					},
					{
						caption:         "with emitDeclarationOnly should not emit anything",
						commandLineArgs: ["--emitDeclarationOnly"]
						// discrepancyExplanation: () => [
						// 	`Clean build tsbuildinfo will have compilerOptions with composite and ${option.replace(/-/g, "")}`,
						// 	`Incremental build will detect that it doesnt need to rebuild so tsbuild info is from before which has option composite only`,
						// ],
					},
					noChange,
					{
						caption: "local change",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/home/src/workspaces/project/a.ts", "Local = 1", "Local = 10");
						}
					},
					{
						caption:         "with declaration should not emit anything",
						commandLineArgs: ["--declaration"]
						// discrepancyExplanation: () => [
						// 	`Clean build tsbuildinfo will have compilerOptions with composite and ${option.replace(/-/g, "")}`,
						// 	`Incremental build will detect that it doesnt need to rebuild so tsbuild info is from before which has option composite only`,
						// ],
					},
					{
						caption:         "with inlineSourceMap",
						commandLineArgs: ["--inlineSourceMap"]
					},
					{
						caption:         "with sourceMap",
						commandLineArgs: ["--sourceMap"]
					},
					{
						caption: "declarationMap enabling",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/home/src/workspaces/project/tsconfig.json", "\"composite\": true,", "\"composite\": true,        \"declarationMap\": true");
						}
					},
					{
						caption:         "with sourceMap should not emit d.ts",
						commandLineArgs: ["--sourceMap"]
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "option changes with incremental",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"incremental\": true,
					}
				}"),
					"/home/src/workspaces/project/a.ts" => "export const a = 10;const aLocal = 10;",
					"/home/src/workspaces/project/b.ts" => "export const b = 10;const bLocal = 10;",
					"/home/src/workspaces/project/c.ts" => "import { a } from \"./a\";export const c = a;",
					"/home/src/workspaces/project/d.ts" => "import { b } from \"./b\";export const d = b;"
				] : FileMap),
				edits: ([
					{
						caption:         "with sourceMap",
						commandLineArgs: ["--sourceMap"]
					},
					{
						caption: "should re-emit only js so they dont contain sourcemap"
					},
					{
						caption:         "with declaration, emit Dts and should not emit js",
						commandLineArgs: ["--declaration"]
					},
					{
						caption:         "with declaration and declarationMap",
						commandLineArgs: ["--declaration", "--declarationMap"]
					},
					{
						caption: "no change"
						// discrepancyExplanation: () => [
						// 	`Clean build tsbuildinfo will have compilerOptions {}`,
						// 	`Incremental build will detect that it doesnt need to rebuild so tsbuild info is from before which has option declaration and declarationMap`,
						// ],
					},
					{
						caption: "local change",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/home/src/workspaces/project/a.ts", "Local = 1", "Local = 10");
						}
					},
					{
						caption:         "with declaration and declarationMap",
						commandLineArgs: ["--declaration", "--declarationMap"]
					},
					{
						caption: "no change"
						// discrepancyExplanation: () => [
						// 	`Clean build tsbuildinfo will have compilerOptions {}`,
						// 	`Incremental build will detect that it doesnt need to rebuild so tsbuild info is from before which has option declaration and declarationMap`,
						// ],
					},
					{
						caption:         "with inlineSourceMap",
						commandLineArgs: ["--inlineSourceMap"]
					},
					{
						caption:         "with sourceMap",
						commandLineArgs: ["--sourceMap"]
					},
					{
						caption: "emit js files"
					},
					{
						caption:         "with declaration and declarationMap",
						commandLineArgs: ["--declaration", "--declarationMap"]
					},
					{
						caption:         "with declaration and declarationMap, should not re-emit",
						commandLineArgs: ["--declaration", "--declarationMap"]
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "when there is bind diagnostics thats ignored",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"skipLibCheck\": true,
						\"incremental\": true,
					}
				}"),
					"/home/src/workspaces/project/a.ts" => "export const a = 10;",
					"/home/src/workspaces/project/b.d.ts" => Stringtestutil.Dedent("
					interface NoName {
						Profiler: new ({ sampleInterval: number, maxBufferSize: number }) => {
							stop: () => Promise<any>;
						};
					}
				")
				] : FileMap),
				commandLineArgs: [""],
				edits: ([
					noChange,
					{
						caption:         "no change and tsc -b",
						commandLineArgs: ["-b", "-v"]
					}
				] : Array<TscEdit>)
			},
			{
				subScenario:     "Compile incremental with case insensitive file names",
				commandLineArgs: ["-p", "."],
				files: ([
					"/home/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"incremental\": true
						},
					}"),
					"/home/project/src/index.ts" => Stringtestutil.Dedent("
					import type { Foo1 } from 'lib1';
					import type { Foo2 } from 'lib2';
					export const foo1: Foo1 = { foo: \"a\" };
					export const foo2: Foo2 = { foo: \"b\" };"),
					"/home/node_modules/lib1/index.d.ts" => Stringtestutil.Dedent("
					import type { Foo } from 'someLib';
					export type { Foo as Foo1 };"),
					"/home/node_modules/lib1/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"lib1\"
					}"),
					"/home/node_modules/lib2/index.d.ts" => Stringtestutil.Dedent("
					import type { Foo } from 'somelib';
					export type { Foo as Foo2 };
					export declare const foo2: Foo;"),
					"/home/node_modules/lib2/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"lib2\"
					}
					"),
					"/home/node_modules/someLib/index.d.ts" => Stringtestutil.Dedent("
					import type { Str } from 'otherLib';
					export type Foo = { foo: Str; };"),
					"/home/node_modules/someLib/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"somelib\"
					}"),
					"/home/node_modules/otherLib/index.d.ts" => Stringtestutil.Dedent("
					export type Str = string;"),
					"/home/node_modules/otherLib/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"otherlib\"
					}")
				] : FileMap),
				cwd:        "/home/project",
				ignoreCase: true
			},
			{
				subScenario: "const enums with refCycle",
				files: ([
					"/home/src/workspaces/project/file.ts" => Stringtestutil.Dedent("
					import {A} from \"./c\"
					let a = A.ONE
				"),
					"/home/src/workspaces/project/b.ts" => Stringtestutil.Dedent("
					import { AWorker } from \"./aworker\"
					import { A as ACycle } from \"./c\"
					export const enum A {
						ONE = 1
					}
				"),
					"/home/src/workspaces/project/c.ts" => Stringtestutil.Dedent("
					import {A} from \"./b\"
					let b = A.ONE
					export {A}
				"),
					"/home/src/workspaces/project/aworker.ts" => Stringtestutil.Dedent("
					export const AWorker  = 10
				"),
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
					}
				}")
				] : FileMap),
				commandLineArgs: [],
				edits: ([
					{
						caption: "change aworker",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/home/src/workspaces/project/aworker.ts", "10", "20");
						}
					},
					{
						caption: "change aworker and enum value",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/home/src/workspaces/project/aworker.ts", "20", "30");
							sys.replaceFileText("/home/src/workspaces/project/b.ts", "1", "2");
						}
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "internal symbolname in tsbuildInfo",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"target\": \"es2017\",
						\"strict\": true,
						\"esModuleInterop\": true
					}
				}"),
					"/home/src/workspaces/project/a.ts" => Stringtestutil.Dedent("
					const createFileListFromFiles = (files: File[]): FileList => {
					const fileList: FileList = {
						length: files.length,
						item: (index: number): File | null => files[index] || null,
						[Symbol.iterator]: function* (): IterableIterator<File> {
						for (const file of files) yield file;
						},
						...files,
					} as unknown as FileList;

					return fileList;
					};
				"),
					Tsctests.getTestLibPathFor("es2015.iterable") => Stringtestutil.Dedent("
					interface SymbolConstructor {
						readonly iterator: unique symbol;
					}
					interface IteratorYieldResult<TYield> {
						done?: false;
						value: TYield;
					}
					interface IteratorReturnResult<TReturn> {
						done: true;
						value: TReturn;
					}
					type IteratorResult<T, TReturn = any> = IteratorYieldResult<T> | IteratorReturnResult<TReturn>;
					interface Iterator<T, TReturn = any, TNext = any> {
						// NOTE: 'next' is defined using a tuple to ensure we report the correct assignability errors in all places.
						next(...[value]: [] | [TNext]): IteratorResult<T, TReturn>;
						return?(value?: TReturn): IteratorResult<T, TReturn>;
						throw?(e?: any): IteratorResult<T, TReturn>;
					}
					interface Iterable<T, TReturn = any, TNext = any> {
						[Symbol.iterator](): Iterator<T, TReturn, TNext>;
					}
					interface IterableIterator<T, TReturn = any, TNext = any> extends Iterator<T, TReturn, TNext> {
						[Symbol.iterator](): IterableIterator<T, TReturn, TNext>;
					}
					interface IteratorObject<T, TReturn = unknown, TNext = unknown> extends Iterator<T, TReturn, TNext> {
						[Symbol.iterator](): IteratorObject<T, TReturn, TNext>;
					}
					type BuiltinIteratorReturn = intrinsic;
					interface ArrayIterator<T> extends IteratorObject<T, BuiltinIteratorReturn, unknown> {
						[Symbol.iterator](): ArrayIterator<T>;
					}
					interface Array<T> {
						[Symbol.iterator](): ArrayIterator<T>;
						entries(): ArrayIterator<[number, T]>;
						keys(): ArrayIterator<number>;
						values(): ArrayIterator<T>;
					}
				"),
					Tsctests.getTestLibPathFor("es2017.full") => Stringtestutil.Dedent("
					/// <reference lib=\"es2015.iterable\"/>
					interface File {
					}
					interface FileList {
						readonly length: number;
						item(index: number): File | null;
						[index: number]: File;
						[Symbol.iterator](): ArrayIterator<File>;
					}
				") + Tsctests.tscDefaultLibContent
				] : FileMap),
				commandLineArgs: [""],
				edits: ([
					noChange,
					{
						caption:         "no change with incremental",
						commandLineArgs: ["--incremental"]
					},
					{
						caption:         "no change with incremental that reads buildInfo",
						commandLineArgs: ["--incremental"]
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "js file with import in jsdoc in composite project",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => "{\"compilerOptions\": {\"allowJs\": true, \"composite\": true}}",
					"/home/src/workspaces/project/index.js" => Stringtestutil.Dedent("
					test(\"\", async function () {
					  ;(/** @type {typeof import(\"a\")} */ ({}))
					})

					test(\"\", async function () {
					  ;(/** @type {typeof import(\"a\")} */ a)
					})

					test(\"\", async function () {
					  (/** @type {typeof import(\"a\")} */ ({}))
					  ;(/** @type {typeof import(\"a\")} */ ({}))
					})

					test(\"\", async function () {
					  (/** @type {typeof import(\"a\")} */ a)
					  ;(/** @type {typeof import(\"a\")} */ a)
					})

					test(\"\", async function () {
					  (/** @type {typeof import(\"a\")} */ ({}))
					  ;(/** @type {typeof import(\"a\")} */ ({}))
					})
				")
				] : FileMap),
				commandLineArgs: ["--noEmit"]
			}
		] : Array<TscInput>);

		for (test in testCases) {
			test.run("incremental");
		}
	}

	public static function TestTscLibraryResolution() {
		var getTscLibraryResolutionFileMap = function(libReplacement:Bool):FileMap {
			var files = ([
				"/home/src/workspace/projects/project1/utils.d.ts" => "export const y = 10;",
				"/home/src/workspace/projects/project1/file.ts" =>    "export const file = 10;",
				"/home/src/workspace/projects/project1/core.d.ts" =>  "export const core = 10;",
				"/home/src/workspace/projects/project1/index.ts" =>   "export const x = \"type1\";",
				"/home/src/workspace/projects/project1/file2.ts" => Stringtestutil.Dedent("
				/// <reference lib=\"webworker\"/>
				/// <reference lib=\"scripthost\"/>
				/// <reference lib=\"es5\"/>
			"),
				"/home/src/workspace/projects/project1/tsconfig.json" => Stringtestutil.Dedent(sprintf("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"typeRoots\": [\"./typeroot1\"],
						\"lib\": [\"es5\", \"dom\"],
						\"traceResolution\": true,
						\"libReplacement\": %t
					}
				}
			", libReplacement)),
				"/home/src/workspace/projects/project1/typeroot1/sometype/index.d.ts" => "export type TheNum = \"type1\";",
				"/home/src/workspace/projects/project2/utils.d.ts" =>                    "export const y = 10;",
				"/home/src/workspace/projects/project2/index.ts" =>                      "export const y = 10",
				"/home/src/workspace/projects/project2/tsconfig.json" => Stringtestutil.Dedent(sprintf("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"lib\": [\"es5\", \"dom\"],
						\"traceResolution\": true,
						\"libReplacement\": %t
					}
				}
			", libReplacement)),
				"/home/src/workspace/projects/project3/utils.d.ts" => "export const y = 10;",
				"/home/src/workspace/projects/project3/index.ts" =>   "export const z = 10",
				"/home/src/workspace/projects/project3/tsconfig.json" => Stringtestutil.Dedent(sprintf("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"lib\": [\"es5\", \"dom\"],
						\"traceResolution\": true,
						\"libReplacement\": %t
					}
				}
			", libReplacement)),
				"/home/src/workspace/projects/project4/utils.d.ts" => "export const y = 10;",
				"/home/src/workspace/projects/project4/index.ts" =>   "export const z = 10",
				"/home/src/workspace/projects/project4/tsconfig.json" => Stringtestutil.Dedent(sprintf("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"lib\": [\"esnext\", \"dom\", \"webworker\"],
						\"traceResolution\": true,
						\"libReplacement\": %t
					}
				}
			", libReplacement)),
				Tsctests.getTestLibPathFor("dom") =>        "interface DOMInterface { }",
				Tsctests.getTestLibPathFor("webworker") =>  "interface WebWorkerInterface { }",
				Tsctests.getTestLibPathFor("scripthost") => "interface ScriptHostInterface { }",
				"/home/src/workspace/projects/node_modules/@typescript/unlreated/index.d.ts" => "export const unrelated = 10;"
			] : FileMap);
			if (libReplacement) {
				files["/home/src/workspace/projects/node_modules/@typescript/lib-es5/index.d.ts"] = Tsctests.tscDefaultLibContent;
				files["/home/src/workspace/projects/node_modules/@typescript/lib-esnext/index.d.ts"] = Tsctests.tscDefaultLibContent;
				files["/home/src/workspace/projects/node_modules/@typescript/lib-dom/index.d.ts"] = "interface DOMInterface { }";
				files["/home/src/workspace/projects/node_modules/@typescript/lib-webworker/index.d.ts"] = "interface WebWorkerInterface { }";
				files["/home/src/workspace/projects/node_modules/@typescript/lib-scripthost/index.d.ts"] = "interface ScriptHostInterface { }";
			}
			return files;
		};
		var getTscLibResolutionTestCases = function(commandLineArgs:Array<String>):Array<TscInput> {
			return ([
				{
					subScenario:     "with config",
					files:           getTscLibraryResolutionFileMap(false),
					cwd:             "/home/src/workspace/projects",
					commandLineArgs: commandLineArgs
				},
				{
					subScenario:     "with config with libReplacement",
					files:           getTscLibraryResolutionFileMap(true),
					cwd:             "/home/src/workspace/projects",
					commandLineArgs: commandLineArgs
				}
			] : Array<TscInput>);
		};
		var getTscLibraryResolutionUnknown = function():FileMap {
			return ([
				"/home/src/workspace/projects/project1/utils.d.ts" => "export const y = 10;",
				"/home/src/workspace/projects/project1/file.ts" =>    "export const file = 10;",
				"/home/src/workspace/projects/project1/core.d.ts" =>  "export const core = 10;",
				"/home/src/workspace/projects/project1/index.ts" =>   "export const x = \"type1\";",
				"/home/src/workspace/projects/project1/file2.ts" => Stringtestutil.Dedent("
				/// <reference lib=\"webworker2\"/>
				/// <reference lib=\"unknownlib\"/>
				/// <reference lib=\"scripthost\"/>
			"),
				"/home/src/workspace/projects/project1/tsconfig.json" => Stringtestutil.Dedent("
			{
				\"compilerOptions\": {
					\"composite\": true,
					\"traceResolution\": true,
					\"libReplacement\": true
				}
			}"),
				Tsctests.getTestLibPathFor("webworker") =>  "interface WebWorkerInterface { }",
				Tsctests.getTestLibPathFor("scripthost") => "interface ScriptHostInterface { }"
			] : FileMap);
		};
		var testCases = Slices.Concat(
			getTscLibResolutionTestCases(["-b", "project1", "project2", "project3", "project4", "--verbose", "--explainFiles"]),
			getTscLibResolutionTestCases(["-p", "project1", "--explainFiles"]),
			getTscLibResolutionTestCases(["-b", "-w", "project1", "project2", "project3", "project4", "--verbose", "--explainFiles"]),
			([
				{
					subScenario:     "unknown lib",
					files:           getTscLibraryResolutionUnknown(),
					cwd:             "/home/src/workspace/projects",
					commandLineArgs: ["-p", "project1", "--explainFiles"]
				},
				{
					subScenario: "when noLib toggles",
					files: ([
						"/home/src/workspaces/project/a.d.ts" => "declare const a = \"hello\";",
						"/home/src/workspaces/project/b.ts" =>   "const b = 10;",
						"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": {
                            \"declaration\": true,
                            \"incremental\": true,
                            \"lib\": [\"es6\"],
                        },
                    }
                ")
					] : FileMap),
					edits: ([
						{
							caption:         "with --noLib",
							commandLineArgs: ["--noLib"]
						}
					] : Array<TscEdit>)
				}
			] : Array<TscInput>)
		);

		for (test in testCases) {
			test.run("libraryResolution");
		}
	}

	public static function TestTscListFilesOnly() {
		var testCases = ([
			{
				subScenario: "loose file",
				files: ([
					"/home/src/workspaces/project/test.ts" => "export const x = 1;"
				] : FileMap),
				commandLineArgs: ["test.ts", "--listFilesOnly"]
			},
			{
				subScenario: "combined with incremental",
				files: ([
					"/home/src/workspaces/project/test.ts" =>       "export const x = 1;",
					"/home/src/workspaces/project/tsconfig.json" => "{}"
				] : FileMap),
				commandLineArgs: ["--incremental", "--listFilesOnly"],
				edits: ([
					{
						caption:         "incremental actual build",
						commandLineArgs: ["--incremental"]
					},
					noChange,
					{
						caption:         "incremental should not build",
						commandLineArgs: ["--incremental"]
					}
				] : Array<TscEdit>)
			}
		] : Array<TscInput>);

		for (testCase in testCases) {
			testCase.run("listFilesOnly");
		}
	}

	public static function TestTscModuleResolution() {
		var getBuildModuleResolutionInProjectRefTestCase = function(preserveSymlinks:Bool):TscInput {
			return ({
				subScenario: "resolves specifier in output declaration file from referenced project correctly" + Core.IfElse(preserveSymlinks, " with preserveSymlinks", ""),
				files: ([
					"/user/username/projects/myproject/packages/pkg1/index.ts" => Stringtestutil.Dedent("
					import type { TheNum } from 'pkg2'
					export const theNum: TheNum = 42;"),
					"/user/username/projects/myproject/packages/pkg1/tsconfig.json" => Stringtestutil.Dedent(sprintf("
					{
						\"compilerOptions\": { 
							\"outDir\": \"build\",
							\"preserveSymlinks\": %t
						},
						\"references\": [{ \"path\": \"../pkg2\" }]
					}
				", preserveSymlinks)),
					"/user/username/projects/myproject/packages/pkg2/const.ts" => Stringtestutil.Dedent("
					export type TheNum = 42;
				"),
					"/user/username/projects/myproject/packages/pkg2/index.ts" => Stringtestutil.Dedent("
					export type { TheNum } from 'const';
				"),
					"/user/username/projects/myproject/packages/pkg2/tsconfig.json" => Stringtestutil.Dedent(sprintf("
					{
						\"compilerOptions\": {
							\"composite\": true,
							\"outDir\": \"build\",
							\"paths\": {
								\"const\": [\"./const\"]
							},
							\"preserveSymlinks\": %t,
						},
					}
				", preserveSymlinks)),
					"/user/username/projects/myproject/packages/pkg2/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"pkg2\",
						\"version\": \"1.0.0\",
						\"main\": \"build/index.js\"
					}
				"),
					"/user/username/projects/myproject/node_modules/pkg2" => Vfstest.Symlink("/user/username/projects/myproject/packages/pkg2")
				] : FileMap),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: ["-b", "packages/pkg1", "--verbose", "--traceResolution"]
			} : TscInput);
		};
		var getTscModuleResolutionSharingFileMap = function():FileMap {
			return ([
				"/home/src/workspaces/project/packages/a/index.js" =>      "export const a = 'a';",
				"/home/src/workspaces/project/packages/a/test/index.js" => "import 'a';",
				"/home/src/workspaces/project/packages/a/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"checkJs\": true,
						\"composite\": true,
						\"declaration\": true,
						\"emitDeclarationOnly\": true,
						\"module\": \"nodenext\",
						\"outDir\": \"types\",
					},
				}"),
				"/home/src/workspaces/project/packages/a/package.json" => Stringtestutil.Dedent("
				{
					\"name\": \"a\",
					\"version\": \"0.0.0\",
					\"type\": \"module\",
					\"exports\": {
						\".\": {
							\"types\": \"./types/index.d.ts\",
							\"default\": \"./index.js\"
						}
					}
				}"),
				"/home/src/workspaces/project/packages/b/index.js" => "export { a } from 'a';",
				"/home/src/workspaces/project/packages/b/tsconfig.json" => Stringtestutil.Dedent("
				{
				\"references\": [{ \"path\": \"../a\" }],
					\"compilerOptions\": {
						\"checkJs\": true,
						\"module\": \"nodenext\",
						\"noEmit\": true,
						\"noImplicitAny\": true,
					},
				}"),
				"/home/src/workspaces/project/packages/b/package.json" => Stringtestutil.Dedent("
				{
					\"name\": \"b\",
					\"version\": \"0.0.0\",
					\"type\": \"module\"
				}"),
				"/home/src/workspaces/project/node_modules/a" => Vfstest.Symlink("/home/src/workspaces/project/packages/a")
			] : FileMap);
		};
		var getTscModuleResolutionAlternateResultAtTypesPackageJson = function(packageName:String, addTypesCondition:Bool):String {
			var typesString = "";
			if (addTypesCondition) {
				typesString = "\"types\": \"./index.d.ts\",";
			}
			return Stringtestutil.Dedent(sprintf("
			{
				\"name\": \"@types/%s\",
				\"version\": \"1.0.0\",
				\"types\": \"index.d.ts\",
				\"exports\": {
					\".\": {
						%s
						\"require\": \"./index.d.ts\"
					}
				}
			}", packageName, typesString));
		};
		var getTscModuleResolutionAlternateResultPackageJson = function(packageName:String, addTypes:Bool, addTypesCondition:Bool):String {
			var types = "";
			if (addTypes) {
				types = "\"types\": \"index.d.ts\",";
			}
			var typesString = "";
			if (addTypesCondition) {
				typesString = "\"types\": \"./index.d.ts\",";
			}
			return Stringtestutil.Dedent(sprintf("
		{
			\"name\": \"%s\",
			\"version\": \"1.0.0\",
			\"main\": \"index.js\",
			%s
			\"exports\": {
				\".\": {
					%s
					\"import\": \"./index.mjs\",
					\"require\": \"./index.js\"
				}
			}
		}", packageName, types, typesString));
		};
		var getTscModuleResolutionAlternateResultDts = function(packageName:String):String {
			return sprintf("export declare const %s: number;", packageName);
		};
		var getTscModuleResolutionAlternateResultJs = function(packageName:String):String {
			return sprintf("module.exports = { %s: 1 };", packageName);
		};
		var getTscModuleResolutionAlternateResultMjs = function(packageName:String):String {
			return sprintf("export const %s = 1;", packageName);
		};
		var testCases = ([
			getBuildModuleResolutionInProjectRefTestCase(false),
			getBuildModuleResolutionInProjectRefTestCase(true),
			{
				subScenario: "type reference resolution uses correct options for different resolution options referenced project",
				files: ([
					"/home/src/workspaces/project/packages/pkg1_index.ts" => "export const theNum: TheNum = \"type1\";",
					"/home/src/workspaces/project/packages/pkg1.tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": {
                            \"composite\": true,
                            \"typeRoots\": [\"./typeroot1\"]
                        },
                        \"files\": [\"./pkg1_index.ts\"],
                    }
                "),
					"/home/src/workspaces/project/packages/typeroot1/sometype/index.d.ts" => "declare type TheNum = \"type1\";",
					"/home/src/workspaces/project/packages/pkg2_index.ts" =>                 "export const theNum: TheNum2 = \"type2\";",
					"/home/src/workspaces/project/packages/pkg2.tsconfig.json" => Stringtestutil.Dedent("
                    {
                        \"compilerOptions\": {
                            \"composite\": true,
                            \"typeRoots\": [\"./typeroot2\"]
                        },
                        \"files\": [\"./pkg2_index.ts\"],
                    }
                "),
					"/home/src/workspaces/project/packages/typeroot2/sometype/index.d.ts" => "declare type TheNum2 = \"type2\";"
				] : FileMap),
				commandLineArgs: ["-b", "packages/pkg1.tsconfig.json", "packages/pkg2.tsconfig.json", "--verbose", "--traceResolution"]
			},
			{
				subScenario: "impliedNodeFormat differs between projects for shared file",
				files: ([
					"/home/src/workspaces/project/a/src/index.ts" => "",
					"/home/src/workspaces/project/a/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
						\"strict\": true
					}
				}
                "),
					"/home/src/workspaces/project/b/src/index.ts" => Stringtestutil.Dedent("
                    import pg from \"pg\";
                    pg.foo();
                "),
					"/home/src/workspaces/project/b/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": { 
						\"strict\": true,
						\"module\": \"node16\"
					},
                }"),
					"/home/src/workspaces/project/b/package.json" => Stringtestutil.Dedent("
				{
                    \"name\": \"b\",
                    \"type\": \"module\"
                }"),
					"/home/src/workspaces/project/node_modules/@types/pg/index.d.ts" => "export function foo(): void;",
					"/home/src/workspaces/project/node_modules/@types/pg/package.json" => Stringtestutil.Dedent("
				{
                    \"name\": \"@types/pg\",
                    \"types\": \"index.d.ts\"
                }")
				] : FileMap),
				commandLineArgs: ["-b", "a", "b", "--verbose", "--traceResolution", "--explainFiles"],
				edits:           noChangeOnlyEdit
			},
			{
				subScenario:     "shared resolution should not report error",
				files:           getTscModuleResolutionSharingFileMap(),
				commandLineArgs: ["-b", "packages/b", "--verbose", "--traceResolution", "--explainFiles"]
			},
			{
				subScenario:     "when resolution is not shared",
				files:           getTscModuleResolutionSharingFileMap(),
				commandLineArgs: ["-b", "packages/a", "--verbose", "--traceResolution", "--explainFiles"],
				edits: ([
					{
						caption:         "build b",
						commandLineArgs: ["-b", "packages/b", "--verbose", "--traceResolution", "--explainFiles"]
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "pnpm style layout",
				files: ([
					// button@0.0.1
					"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+button@0.0.1/node_modules/@component-type-checker/button/src/index.ts" => Stringtestutil.Dedent("
                    export interface Button {
                        a: number;
                        b: number;
                    }
                    export function createButton(): Button {
                        return {
                            a: 0,
                            b: 1,
                        };
                    }
                "),
					"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+button@0.0.1/node_modules/@component-type-checker/button/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"@component-type-checker/button\",
						\"version\": \"0.0.1\",
						\"main\": \"./src/index.ts\"
					}"),

					// button@0.0.2
					"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+button@0.0.2/node_modules/@component-type-checker/button/src/index.ts" => Stringtestutil.Dedent("
                    export interface Button {
                        a: number;
                        c: number;
                    }
                    export function createButton(): Button {
                        return {
                            a: 0,
                            c: 2,
                        };
                    }
                "),
					"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+button@0.0.2/node_modules/@component-type-checker/button/package.json" => Stringtestutil.Dedent("
                    {
                        \"name\": \"@component-type-checker/button\",
                        \"version\": \"0.0.2\",
                        \"main\": \"./src/index.ts\"
                    }"),

					// @component-type-checker+components@0.0.1_@component-type-checker+button@0.0.1
					"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+components@0.0.1_@component-type-checker+button@0.0.1/node_modules/@component-type-checker/button" => Vfstest.Symlink(
						"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+button@0.0.1/node_modules/@component-type-checker/button"
					),
					"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+components@0.0.1_@component-type-checker+button@0.0.1/node_modules/@component-type-checker/components/src/index.ts" => Stringtestutil.Dedent("
                    export { createButton, Button } from \"@component-type-checker/button\";
                "),
					"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+components@0.0.1_@component-type-checker+button@0.0.1/node_modules/@component-type-checker/components/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"@component-type-checker/components\",
						\"version\": \"0.0.1\",
						\"main\": \"./src/index.ts\",
						\"peerDependencies\": {
							\"@component-type-checker/button\": \"*\"
						},
						\"devDependencies\": {
							\"@component-type-checker/button\": \"0.0.2\"
						}
					}"),

					// @component-type-checker+components@0.0.1_@component-type-checker+button@0.0.2
					"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+components@0.0.1_@component-type-checker+button@0.0.2/node_modules/@component-type-checker/button" => Vfstest.Symlink(
						"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+button@0.0.2/node_modules/@component-type-checker/button"
					),
					"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+components@0.0.1_@component-type-checker+button@0.0.2/node_modules/@component-type-checker/components/src/index.ts" => Stringtestutil.Dedent("
                    export { createButton, Button } from \"@component-type-checker/button\";
                "),
					"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+components@0.0.1_@component-type-checker+button@0.0.2/node_modules/@component-type-checker/components/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"@component-type-checker/components\",
						\"version\": \"0.0.1\",
						\"main\": \"./src/index.ts\",
						\"peerDependencies\": {
							\"@component-type-checker/button\": \"*\"
						},
						\"devDependencies\": {
							\"@component-type-checker/button\": \"0.0.2\"
						}
					}"),

					// sdk => @component-type-checker+components@0.0.1_@component-type-checker+button@0.0.1
					"/home/src/projects/component-type-checker/packages/sdk/src/index.ts" => Stringtestutil.Dedent("
                    export { Button, createButton } from \"@component-type-checker/components\";
                    export const VERSION = \"0.0.2\";
                "),
					"/home/src/projects/component-type-checker/packages/sdk/package.json" => Stringtestutil.Dedent("
                    {
                        \"name\": \"@component-type-checker/sdk1\",
                        \"version\": \"0.0.2\",
                        \"main\": \"./src/index.ts\",
                        \"dependencies\": {
                            \"@component-type-checker/components\": \"0.0.1\",
                            \"@component-type-checker/button\": \"0.0.1\"
                        }
                    }"),
					"/home/src/projects/component-type-checker/packages/sdk/node_modules/@component-type-checker/button" => Vfstest.Symlink(
						"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+button@0.0.1/node_modules/@component-type-checker/button"
					),
					"/home/src/projects/component-type-checker/packages/sdk/node_modules/@component-type-checker/components" => Vfstest.Symlink(
						"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+components@0.0.1_@component-type-checker+button@0.0.1/node_modules/@component-type-checker/components"
					),

					// app => @component-type-checker+components@0.0.1_@component-type-checker+button@0.0.2
					"/home/src/projects/component-type-checker/packages/app/src/app.tsx" => Stringtestutil.Dedent("
                    import { VERSION } from \"@component-type-checker/sdk\";
                    import { Button } from \"@component-type-checker/components\";
                    import { createButton } from \"@component-type-checker/button\";
                    const button: Button = createButton();
                "),
					"/home/src/projects/component-type-checker/packages/app/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"app\",
						\"version\": \"1.0.0\",
						\"dependencies\": {
							\"@component-type-checker/button\": \"0.0.2\",
							\"@component-type-checker/components\": \"0.0.1\",
							\"@component-type-checker/sdk\": \"0.0.2\"
						}
					}"),
					"/home/src/projects/component-type-checker/packages/app/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"target\": \"es5\",
							\"module\": \"esnext\",
							\"lib\": [\"ES5\"],
							\"outDir\": \"dist\",
						},
						\"include\": [\"src\"],
					}"),
					"/home/src/projects/component-type-checker/packages/app/node_modules/@component-type-checker/button" => Vfstest.Symlink(
						"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+button@0.0.2/node_modules/@component-type-checker/button"
					),
					"/home/src/projects/component-type-checker/packages/app/node_modules/@component-type-checker/components" => Vfstest.Symlink(
						"/home/src/projects/component-type-checker/node_modules/.pnpm/@component-type-checker+components@0.0.1_@component-type-checker+button@0.0.2/node_modules/@component-type-checker/components"
					),
					"/home/src/projects/component-type-checker/packages/app/node_modules/@component-type-checker/sdk" => Vfstest.Symlink(
						"/home/src/projects/component-type-checker/packages/sdk"
					)
				] : FileMap),
				cwd:             "/home/src/projects/component-type-checker/packages/app",
				commandLineArgs: ["--traceResolution", "--explainFiles"]
			},
			{
				subScenario: "package json scope",
				files: ([
					"/home/src/workspaces/project/src/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"target\": \"ES2016\",
							\"composite\": true,
							\"module\": \"Node16\",
							\"traceResolution\": true,
						},
						\"files\": [
							\"main.ts\",
							\"fileA.ts\",
							\"fileB.mts\",
						],
					}"),
					"/home/src/workspaces/project/src/main.ts" => "export const x = 10;",
					"/home/src/workspaces/project/src/fileA.ts" => Stringtestutil.Dedent("
                    import { foo } from \"./fileB.mjs\";
                    foo();
                "),
					"/home/src/workspaces/project/src/fileB.mts" => "export function foo() {}",
					"/home/src/workspaces/project/package.json" => Stringtestutil.Dedent("
                    {
                        \"name\": \"app\",
                        \"version\": \"1.0.0\"
                    }
                ")
				] : FileMap),
				commandLineArgs: ["-p", "src", "--explainFiles", "--extendedDiagnostics"],
				edits: ([
					{
						caption: "Delete package.json",
						edit: (sys:TestSys) -> {
							sys.removeNoError("/home/src/workspaces/project/package.json");
						}
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "alternateResult",
				files: ([
					"/home/src/projects/project/node_modules/@types/bar/package.json" =>  getTscModuleResolutionAlternateResultAtTypesPackageJson("bar" /*addTypesCondition*/, false),
					"/home/src/projects/project/node_modules/@types/bar/index.d.ts" =>    getTscModuleResolutionAlternateResultDts("bar"),
					"/home/src/projects/project/node_modules/bar/package.json" =>         getTscModuleResolutionAlternateResultPackageJson("bar" /*addTypes*/, false /*addTypesCondition*/, false),
					"/home/src/projects/project/node_modules/bar/index.js" =>             getTscModuleResolutionAlternateResultJs("bar"),
					"/home/src/projects/project/node_modules/bar/index.mjs" =>            getTscModuleResolutionAlternateResultMjs("bar"),
					"/home/src/projects/project/node_modules/foo/package.json" =>         getTscModuleResolutionAlternateResultPackageJson("foo" /*addTypes*/, true /*addTypesCondition*/, false),
					"/home/src/projects/project/node_modules/foo/index.js" =>             getTscModuleResolutionAlternateResultJs("foo"),
					"/home/src/projects/project/node_modules/foo/index.mjs" =>            getTscModuleResolutionAlternateResultMjs("foo"),
					"/home/src/projects/project/node_modules/foo/index.d.ts" =>           getTscModuleResolutionAlternateResultDts("foo"),
					"/home/src/projects/project/node_modules/@types/bar2/package.json" => getTscModuleResolutionAlternateResultAtTypesPackageJson("bar2" /*addTypesCondition*/, true),
					"/home/src/projects/project/node_modules/@types/bar2/index.d.ts" =>   getTscModuleResolutionAlternateResultDts("bar2"),
					"/home/src/projects/project/node_modules/bar2/package.json" =>        getTscModuleResolutionAlternateResultPackageJson("bar2" /*addTypes*/, false /*addTypesCondition*/, false),
					"/home/src/projects/project/node_modules/bar2/index.js" =>            getTscModuleResolutionAlternateResultJs("bar2"),
					"/home/src/projects/project/node_modules/bar2/index.mjs" =>           getTscModuleResolutionAlternateResultMjs("bar2"),
					"/home/src/projects/project/node_modules/foo2/package.json" =>        getTscModuleResolutionAlternateResultPackageJson("foo2" /*addTypes*/, true /*addTypesCondition*/, true),
					"/home/src/projects/project/node_modules/foo2/index.js" =>            getTscModuleResolutionAlternateResultJs("foo2"),
					"/home/src/projects/project/node_modules/foo2/index.mjs" =>           getTscModuleResolutionAlternateResultMjs("foo2"),
					"/home/src/projects/project/node_modules/foo2/index.d.ts" =>          getTscModuleResolutionAlternateResultDts("foo2"),
					"/home/src/projects/project/index.mts" => Stringtestutil.Dedent("
					import { foo } from \"foo\";
					import { bar } from \"bar\";
					import { foo2 } from \"foo2\";
					import { bar2 } from \"bar2\";
				"),
					"/home/src/projects/project/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"module\": \"node16\",
							\"moduleResolution\": \"node16\",
							\"traceResolution\": true,
							\"incremental\": true,
							\"strict\": true,
							\"types\": [],
						},
						\"files\": [\"index.mts\"],
					}")
				] : FileMap),
				cwd: "/home/src/projects/project",
				edits: ([
					{
						caption: "delete the alternateResult in @types",
						edit: (sys:TestSys) -> {
							sys.removeNoError("/home/src/projects/project/node_modules/@types/bar/index.d.ts");
						}
					},
					{
						caption: "delete the node10Result in package/types",
						edit: (sys:TestSys) -> {
							sys.removeNoError("/home/src/projects/project/node_modules/foo/index.d.ts");
						}
					},
					{
						caption: "add the alternateResult in @types",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/home/src/projects/project/node_modules/@types/bar/index.d.ts", getTscModuleResolutionAlternateResultDts("bar"));
						}
					},
					{
						caption: "add the alternateResult in package/types",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/home/src/projects/project/node_modules/foo/index.d.ts", getTscModuleResolutionAlternateResultDts("foo"));
						}
					},
					{
						caption: "update package.json from @types so error is fixed",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/home/src/projects/project/node_modules/@types/bar/package.json", getTscModuleResolutionAlternateResultAtTypesPackageJson("bar" /*addTypesCondition*/, true));
						}
					},
					{
						caption: "update package.json so error is fixed",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/home/src/projects/project/node_modules/foo/package.json", getTscModuleResolutionAlternateResultPackageJson("foo" /*addTypes*/, true /*addTypesCondition*/, true));
						}
					},
					{
						caption: "update package.json from @types so error is introduced",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/home/src/projects/project/node_modules/@types/bar2/package.json", getTscModuleResolutionAlternateResultAtTypesPackageJson("bar2" /*addTypesCondition*/, false));
						}
					},
					{
						caption: "update package.json so error is introduced",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/home/src/projects/project/node_modules/foo2/package.json", getTscModuleResolutionAlternateResultPackageJson("foo2" /*addTypes*/, true /*addTypesCondition*/, false));
						}
					},
					{
						caption: "delete the alternateResult in @types",
						edit: (sys:TestSys) -> {
							sys.removeNoError("/home/src/projects/project/node_modules/@types/bar2/index.d.ts");
						}
					},
					{
						caption: "delete the node10Result in package/types",
						edit: (sys:TestSys) -> {
							sys.removeNoError("/home/src/projects/project/node_modules/foo2/index.d.ts");
						}
					},
					{
						caption: "add the alternateResult in @types",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/home/src/projects/project/node_modules/@types/bar2/index.d.ts", getTscModuleResolutionAlternateResultDts("bar2"));
						}
					},
					{
						caption: "add the ndoe10Result in package/types",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/home/src/projects/project/node_modules/foo2/index.d.ts", getTscModuleResolutionAlternateResultDts("foo2"));
						}
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "handles the cache correctly when two projects use different module resolution settings",
				files: ([
					"/user/username/projects/myproject/project1/index.ts" =>                     "import { foo } from \"file\";",
					"/user/username/projects/myproject/project1/node_modules/file/index.d.ts" => "export const foo = 10;",
					"/user/username/projects/myproject/project1/tsconfig.json" => Stringtestutil.Dedent("
				   {
                       \"compilerOptions\": {
						   \"composite\": true,
						   \"types\": [\"foo\", \"bar\"]
					   },
                       \"files\": [\"index.ts\"],
                   }"),
					"/user/username/projects/myproject/project2/index.ts" =>                     "import { foo } from \"file\";",
					"/user/username/projects/myproject/project2/node_modules/file/index.d.ts" => "export const foo = 10;",
					"/user/username/projects/myproject/project2/tsconfig.json" => Stringtestutil.Dedent("
				   {
                       \"compilerOptions\": {
						   \"composite\": true,
						   \"types\": [\"foo\"],
						   \"module\": \"nodenext\",
						   \"moduleResolution\": \"nodenext\"
					   },
                       \"files\": [\"index.ts\"],
                   }"),
					"/user/username/projects/myproject/node_modules/@types/foo/index.d.ts" => "export const foo = 10;",
					"/user/username/projects/myproject/node_modules/@types/bar/index.d.ts" => "export const bar = 10;",
					"/user/username/projects/myproject/tsconfig.json" => Stringtestutil.Dedent("
				   {
						\"files\": [],
						\"references\": [
							{ \"path\": \"./project1\" },
							{ \"path\": \"./project2\" },
						],
                   }")
				] : FileMap),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: ["--b", "-w", "-v"],
				edits: ([
					{
						caption: "Append text",
						edit: (sys:TestSys) -> {
							sys.appendFile("/user/username/projects/myproject/project1/index.ts", "const bar = 10;");
						}
					}
				] : Array<TscEdit>)
			},
			{
				// !!! sheetal package.json watches not yet implemented
				subScenario: "resolves specifier in output declaration file from referenced project correctly with cts and mts extensions",
				files: ([
					"/user/username/projects/myproject/packages/pkg1/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"pkg1\",
						\"version\": \"1.0.0\",
						\"main\": \"build/index.js\",
						\"type\": \"module\"
					}"),
					"/user/username/projects/myproject/packages/pkg1/index.ts" => Stringtestutil.Dedent("
					import type { TheNum } from 'pkg2'
					export const theNum: TheNum = 42;"),
					"/user/username/projects/myproject/packages/pkg1/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"outDir\": \"build\",
							\"module\": \"node16\",
						},
						\"references\": [{ \"path\": \"../pkg2\" }],
					}"),
					"/user/username/projects/myproject/packages/pkg2/const.cts" => "export type TheNum = 42;",
					"/user/username/projects/myproject/packages/pkg2/index.ts" =>  "export type { TheNum } from './const.cjs';",
					"/user/username/projects/myproject/packages/pkg2/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"composite\": true,
							\"outDir\": \"build\",
							\"module\": \"node16\",
						},
					}"),
					"/user/username/projects/myproject/packages/pkg2/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"pkg2\",
						\"version\": \"1.0.0\",
						\"main\": \"build/index.js\",
						\"type\": \"module\"
					}"),
					"/user/username/projects/myproject/node_modules/pkg2" => Vfstest.Symlink("/user/username/projects/myproject/packages/pkg2")
				] : FileMap),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: ["-b", "packages/pkg1", "-w", "--verbose", "--traceResolution"],
				edits: ([
					{
						caption: "reports import errors after change to package file",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/user/username/projects/myproject/packages/pkg1/package.json", "\"module\"", "\"commonjs\"");
						}
					},
					{
						caption: "removes those errors when a package file is changed back",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/user/username/projects/myproject/packages/pkg1/package.json", "\"commonjs\"", "\"module\"");
						}
					},
					{
						caption: "reports import errors after change to package file",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/user/username/projects/myproject/packages/pkg1/package.json", "\"module\"", "\"commonjs\"");
						}
					},
					{
						caption: "removes those errors when a package file is changed to cjs extensions",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/user/username/projects/myproject/packages/pkg2/package.json", "\"build/index.js\"", "\"build/index.cjs\"");
							sys.renameFileNoError("/user/username/projects/myproject/packages/pkg2/index.ts", "/user/username/projects/myproject/packages/pkg2/index.cts");
						}
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "build mode watches for changes to package-json main fields",
				files: ([
					"/user/username/projects/myproject/packages/pkg1/package.json" => Stringtestutil.Dedent("
					{
                        \"name\": \"pkg1\",
                        \"version\": \"1.0.0\",
                        \"main\": \"build/index.js\"
                    }"),
					"/user/username/projects/myproject/packages/pkg1/index.ts" => Stringtestutil.Dedent("
                    import type { TheNum } from 'pkg2'
                    export const theNum: TheNum = 42;"),
					"/user/username/projects/myproject/packages/pkg1/tsconfig.json" => Stringtestutil.Dedent("
					{
                        \"compilerOptions\": {
                            \"outDir\": \"build\",
                        },
                        \"references\": [{ \"path\": \"../pkg2\" }],
                    }"),
					"/user/username/projects/myproject/packages/pkg2/tsconfig.json" => Stringtestutil.Dedent("
					{
                        \"compilerOptions\": {
                            \"composite\": true,
                            \"outDir\": \"build\",
                        },
                    }"),
					"/user/username/projects/myproject/packages/pkg2/const.ts" => "export type TheNum = 42;",
					"/user/username/projects/myproject/packages/pkg2/index.ts" => "export type { TheNum } from './const.js';",
					"/user/username/projects/myproject/packages/pkg2/other.ts" => "export type TheStr = string;",
					"/user/username/projects/myproject/packages/pkg2/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"pkg2\",
                        \"version\": \"1.0.0\",
                        \"main\": \"build/index.js\"
                    }"),
					"/user/username/projects/myproject/node_modules/pkg2" => Vfstest.Symlink("/user/username/projects/myproject/packages/pkg2")
				] : FileMap),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: ["-b", "packages/pkg1", "--verbose", "-w", "--traceResolution"],
				edits: ([
					{
						caption: "reports import errors after change to package file",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/user/username/projects/myproject/packages/pkg2/package.json", "index.js", "other.js");
						}
					},
					{
						caption: "removes those errors when a package file is changed back",
						edit: (sys:TestSys) -> {
							sys.replaceFileText("/user/username/projects/myproject/packages/pkg2/package.json", "other.js", "index.js");
						}
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "build mode watches missing package-json lookups",
				files: ([
					"/user/username/projects/myproject/packages/pkg1/index.ts" => Stringtestutil.Dedent("
					import type { TheNum } from 'pkg2'
					export const theNum: TheNum = 42;"),
					"/user/username/projects/myproject/packages/pkg1/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"outDir\": \"build\",
						},
					}")
				] : FileMap),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: ["-b", "packages/pkg1", "-w", "--verbose", "--traceResolution"],
				edits: ([
					{
						caption: "resolves import after package is installed",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/user/username/projects/myproject/node_modules/pkg2/package.json", Stringtestutil.Dedent("
							{
								\"name\": \"pkg2\",
								\"version\": \"1.0.0\",
								\"types\": \"index.d.ts\"
							}"));
							sys.writeFileNoError("/user/username/projects/myproject/node_modules/pkg2/index.d.ts", "export type TheNum = 42;");
						}
					},
					{
						caption: "reports import errors after package is removed",
						edit: (sys:TestSys) -> {
							sys.removeNoError("/user/username/projects/myproject/node_modules/pkg2/package.json");
							sys.removeNoError("/user/username/projects/myproject/node_modules/pkg2/index.d.ts");
						}
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "build mode watches package-json lookups from existing buildinfo",
				files: Tsctests.GetFileMapWithBuild(([
					"/user/username/projects/myproject/packages/pkg1/index.ts" => Stringtestutil.Dedent("
					import type { TheNum } from 'pkg2'
					export const theNum: TheNum = 42;"),
					"/user/username/projects/myproject/packages/pkg1/tsconfig.json" => Stringtestutil.Dedent("
					{
						\"compilerOptions\": {
							\"outDir\": \"zzbuild\",
						},
					}"),
					"/user/username/projects/myproject/node_modules/pkg2/package.json" => Stringtestutil.Dedent("
					{
						\"name\": \"pkg2\",
						\"version\": \"1.0.0\",
						\"types\": \"index.d.ts\"
					}"),
					"/user/username/projects/myproject/node_modules/pkg2/index.d.ts" => "export type TheNum = 42;"
				] : FileMap), ["-b", "/user/username/projects/myproject/packages/pkg1", "--verbose", "--traceResolution"]),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: ["-b", "packages/pkg1", "-w", "--verbose", "--traceResolution"],
				edits: ([
					{
						caption: "reports import errors after package is removed",
						edit: (sys:TestSys) -> {
							sys.removeNoError("/user/username/projects/myproject/node_modules/pkg2/package.json");
							sys.removeNoError("/user/username/projects/myproject/node_modules/pkg2/index.d.ts");
						}
					}
				] : Array<TscEdit>)
			},
			{
				subScenario: "resolution from d.ts of referenced project",
				files: ([
					"/home/src/workspaces/project/common.d.ts" => "export type OnValue = (value: number) => void",
					"/home/src/workspaces/project/producer/index.ts" => Stringtestutil.Dedent("
                    export { ValueProducerDeclaration } from \"./in-js\"
                    import { OnValue } from \"@common\"
                    export interface ValueProducerFromTs {
                        onValue: OnValue;
                    }
                "),
					"/home/src/workspaces/project/producer/in-js.d.ts" => Stringtestutil.Dedent("
                    import { OnValue } from \"@common\"
                    export interface ValueProducerDeclaration {
                        onValue: OnValue;
                    }
                "),
					"/home/src/workspaces/project/producer/tsconfig.json" => Stringtestutil.Dedent("
				{
                    \"compilerOptions\": {
                        \"strict\": true,
                        \"composite\": true,
                        \"module\": \"nodenext\",
                        \"moduleResolution\": \"nodenext\",
                        \"paths\": {
                            \"@common\": [\"../common.d.ts\"],
                        },
                    },
                }"),
					"/home/src/workspaces/project/consumer/index.ts" => Stringtestutil.Dedent("
                    import { ValueProducerDeclaration, ValueProducerFromTs } from \"@producer\"
                    declare let v: ValueProducerDeclaration;
					// n is implicitly any because onValue is actually any (despite what the tooltip says)
					v.onValue = (n) => {
                    }
                    // n is implicitly number as expected
                    declare let v2: ValueProducerFromTs;
                    v2.onValue = (n) => {
                    }"),
					"/home/src/workspaces/project/consumer/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"strict\": true,
						\"module\": \"nodenext\",
						\"moduleResolution\": \"nodenext\",
						\"paths\": {
							\"@producer\": [\"../producer/index\"],
						},
					},
					\"references\": [
						{ \"path\": \"../producer\" },
                    ],
                }")
				] : FileMap),
				commandLineArgs: ["--b", "consumer", "--traceResolution", "-v"]
			}
		] : Array<TscInput>);

		for (test in testCases) {
			test.run("moduleResolution");
		}
	}

	public static function TestTscNoCheck() {
		var getTscNoCheckTestCase = function(scenario:NoCheckScenario, incremental:Bool, commandLineArgs:Array<String>):TscInput {
			var noChangeWithCheck = ({
				caption:         "No Change run with checking",
				commandLineArgs: commandLineArgs
			} : TscEdit);
			var fixErrorNoCheck = ({
				caption: "Fix `a` error with noCheck",
				edit: (sys:TestSys) -> {
					sys.writeFileNoError("/home/src/workspaces/project/a.ts", "export const a = \"hello\";");
				}
			} : TscEdit);
			var addErrorNoCheck = ({
				caption: "Introduce error with noCheck",
				edit: (sys:TestSys) -> {
					sys.writeFileNoError("/home/src/workspaces/project/a.ts", scenario.aText);
				}
			} : TscEdit);
			return ({
				subScenario: scenario.subScenario + Core.IfElse(incremental, " with incremental", ""),
				files: ([
					"/home/src/workspaces/project/a.ts" => scenario.aText,
					"/home/src/workspaces/project/b.ts" => "export const b = 10;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent(sprintf("
				{
					\"compilerOptions\": {
						\"declaration\": true,
						\"incremental\": %t
					}
				}", incremental))
				] : FileMap),
				commandLineArgs: Slices.Concat(commandLineArgs, ["--noCheck"]),
				edits: ([
					noChange,
					fixErrorNoCheck,   // Fix error with noCheck
					noChange,          // Should be no op
					noChangeWithCheck, // Check errors - should not report any errors - update buildInfo
					noChangeWithCheck, // Should be no op
					noChange,          // Should be no op
					addErrorNoCheck,
					noChange,          // Should be no op
					noChangeWithCheck, // Should check errors and update buildInfo
					fixErrorNoCheck,   // Fix error with noCheck
					noChangeWithCheck, // Should check errors and update buildInfo
					{
						caption: "Add file with error",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/home/src/workspaces/project/c.ts", "export const c: number = \"hello\";");
						},
						commandLineArgs: commandLineArgs
					},
					addErrorNoCheck,
					fixErrorNoCheck,
					noChangeWithCheck,
					noChange,          // Should be no op
					noChangeWithCheck // Should be no op
				] : Array<TscEdit>)
			} : TscInput);
		};

		var cases = ([
			{subScenario: "syntax errors", aText: "export const a = \"hello"},
			{subScenario: "semantic errors", aText: "export const a: number = \"hello\";"},
			{subScenario: "dts errors", aText: "export const a = class { private p = 10; };"}
		] : Array<NoCheckScenario>);
		var testCases = Core.FlatMap(cases, function(c:NoCheckScenario):Array<TscInput> {
			return ([
				getTscNoCheckTestCase(c, false, []),
				getTscNoCheckTestCase(c, true, []),
				getTscNoCheckTestCase(c, false, ["-b", "-v"]),
				getTscNoCheckTestCase(c, true, ["-b", "-v"])
			] : Array<TscInput>);
		});
		for (test in testCases) {
			test.run("noCheck");
		}
	}

	public static function TestTscNoEmit() {
		var noEmitScenarios = ([
			{
				subScenario: "syntax errors",
				aText:       "const a = \"hello"
			},
			{
				subScenario: "semantic errors",
				aText:       "const a: number = \"hello\""
			},
			{
				subScenario: "dts errors",
				aText:       "const a = class { private p = 10; };",
				dtsEnabled:  true
			},
			{
				subScenario: "dts errors without dts enabled",
				aText:       "const a = class { private p = 10; };"
			}
		] : Array<TscNoEmitScenario>);
		var getTscNoEmitAndErrorsFileMap = function(scenario:TscNoEmitScenario, incremental:Bool, asModules:Bool, modify:(FileMap) -> Void):FileMap {
			var files = ([
				"/home/src/projects/project/a.ts" => Core.IfElse(asModules, "export ", "") + scenario.aText,
				"/home/src/projects/project/tsconfig.json" => Stringtestutil.Dedent(sprintf("
				{
					\"compilerOptions\": {
						\"incremental\": %t,
						\"declaration\": %t
					}
				}
		", incremental, scenario.dtsEnabled))
			] : FileMap);
			if (asModules) {
				files["/home/src/projects/project/b.ts"] = "export const b = 10;";
			}
			if (modify != null) {
				modify(files);
			}
			return files;
		};
		var getTscNoEmitAndErrorsTestCasesWorker = function(commandLineArgs:Array<String>, addNoEmitOnCommandLine:Bool, modify:(FileMap) -> Void, edits:(TscNoEmitScenario, Array<String>, Bool) -> Array<TscEdit>):Array<TscInput> {
			var testingCases = ([] : Array<TscInput>);
			var commandLineArgsForInput = commandLineArgs;
			if (addNoEmitOnCommandLine) {
				commandLineArgsForInput = Slices.Concat(commandLineArgs, ["--noEmit"]);
			}
			for (scenario in noEmitScenarios) {
				testingCases = append(
					testingCases,
					({
						subScenario:     scenario.subScenario,
						commandLineArgs: commandLineArgsForInput,
						files:           getTscNoEmitAndErrorsFileMap(scenario, false, false, modify),
						cwd:             "/home/src/projects/project",
						edits:           edits(scenario, commandLineArgs, false)
					} : TscInput),
					({
						subScenario:     scenario.subScenario + " with incremental",
						commandLineArgs: commandLineArgsForInput,
						files:           getTscNoEmitAndErrorsFileMap(scenario, true, false, modify),
						cwd:             "/home/src/projects/project",
						edits:           edits(scenario, commandLineArgs, false)
					} : TscInput),
					({
						subScenario:     scenario.subScenario + " with incremental as modules",
						commandLineArgs: commandLineArgsForInput,
						files:           getTscNoEmitAndErrorsFileMap(scenario, true, true, modify),
						cwd:             "/home/src/projects/project",
						edits:           edits(scenario, commandLineArgs, true)
					} : TscInput)
				);
			}
			return testingCases;
		};
		var getTscNoEmitAndErrorsTestCases = function(commandLineArgs:Array<String>):Array<TscInput> {
			return getTscNoEmitAndErrorsTestCasesWorker(
				commandLineArgs,
				true,
				null,
				function(scenario:TscNoEmitScenario, commandLineArgs:Array<String>, asModules:Bool):Array<TscEdit> {
					var fixedATsContent = Core.IfElse(asModules, "export ", "") + "const a = \"hello\";";
					return ([
						noChange,
						{
							caption: "Fix error",
							edit: (sys:TestSys) -> {
								sys.writeFileNoError("/home/src/projects/project/a.ts", fixedATsContent);
							}
						},
						noChange,
						{
							caption:         "Emit after fixing error",
							commandLineArgs: commandLineArgs
						},
						noChange,
						{
							caption: "Introduce error",
							edit: (sys:TestSys) -> {
								sys.writeFileNoError("/home/src/projects/project/a.ts", scenario.aText);
							}
						},
						{
							caption:         "Emit when error",
							commandLineArgs: commandLineArgs
						},
						noChange
					] : Array<TscEdit>);
				}
			);
		};
		var getTscNoEmitAndErrorsWatchTestCases = function(commandLineArgs:Array<String>):Array<TscInput> {
			return getTscNoEmitAndErrorsTestCasesWorker(
				commandLineArgs,
				false,
				function(files:FileMap) {
					files["/home/src/projects/project/tsconfig.json"] = Strings.Replace((cast files["/home/src/projects/project/tsconfig.json"] : String), "}", ", \"noEmit\": true }", 1);
				},
				function(scenario:TscNoEmitScenario, commandLineArgs:Array<String>, asModules:Bool):Array<TscEdit> {
					var fixedATsContent = Core.IfElse(asModules, "export ", "") + "const a = \"hello\";";
					return ([
						{
							caption: "Fix error",
							edit: (sys:TestSys) -> {
								sys.writeFileNoError("/home/src/projects/project/a.ts", fixedATsContent);
							}
						},
						{
							caption: "Emit after fixing error",
							edit: (sys:TestSys) -> {
								sys.replaceFileText("/home/src/projects/project/tsconfig.json", "\"noEmit\": true", "\"noEmit\": false");
							}
						},
						{
							caption: "no Emit run after fixing error",
							edit: (sys:TestSys) -> {
								sys.replaceFileText("/home/src/projects/project/tsconfig.json", "\"noEmit\": false", "\"noEmit\": true");
							}
						},
						{
							caption: "Introduce error",
							edit: (sys:TestSys) -> {
								sys.writeFileNoError("/home/src/projects/project/a.ts", scenario.aText);
							}
						},
						{
							caption: "Emit when error",
							edit: (sys:TestSys) -> {
								sys.replaceFileText("/home/src/projects/project/tsconfig.json", "\"noEmit\": true", "\"noEmit\": false");
							}
						},
						{
							caption: "no Emit run when error",
							edit: (sys:TestSys) -> {
								sys.replaceFileText("/home/src/projects/project/tsconfig.json", "\"noEmit\": false", "\"noEmit\": true");
							}
						}
					] : Array<TscEdit>);
				}
			);
		};
		var getTscNoEmitChangesFileMap = function(optionsStr:String):FileMap {
			return ([
				"/home/src/workspaces/project/src/class.ts" => Stringtestutil.Dedent("
				export class classC {
					prop = 1;
				}"),
				"/home/src/workspaces/project/src/indirectClass.ts" => Stringtestutil.Dedent("
				import { classC } from './class';
				export class indirectClass {
					classC = new classC();
				}"),
				"/home/src/workspaces/project/src/directUse.ts" => Stringtestutil.Dedent("
				import { indirectClass } from './indirectClass';
				new indirectClass().classC.prop;"),
				"/home/src/workspaces/project/src/indirectUse.ts" => Stringtestutil.Dedent("
				import { indirectClass } from './indirectClass';
				new indirectClass().classC.prop;"),
				"/home/src/workspaces/project/src/noChangeFile.ts" => Stringtestutil.Dedent("
				export function writeLog(s: string) {
				}"),
				"/home/src/workspaces/project/src/noChangeFileWithEmitSpecificError.ts" => Stringtestutil.Dedent("
				function someFunc(arguments: boolean, ...rest: any[]) {
				}"),
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent(sprintf("
				{
					\"compilerOptions\":  { %s }
				}", optionsStr))
			] : FileMap);
		};

		var noEmitChangesScenarios = ([
			{
				// !!! sheetal missing initial reporting of Duplicate_identifier_arguments_Compiler_uses_arguments_to_initialize_rest_parameters is absent
				subScenario:   "composite",
				optionsString: "\"composite\": true"
			},
			{
				subScenario:   "incremental declaration",
				optionsString: "\"incremental\": true, \"declaration\": true"
			},
			{
				subScenario:   "incremental",
				optionsString: "\"incremental\": true"
			}
		] : Array<TscNoEmitChangesScenario>);
		var getTscNoEmitChangesTestCases = function(commandLineArgs:Array<String>):Array<TscInput> {
			var noChangeWithNoEmit = ({
				caption:         "No Change run with noEmit",
				commandLineArgs: Slices.Concat(commandLineArgs, ["--noEmit"])
			} : TscEdit);
			var noChangeWithEmit = ({
				caption:         "No Change run with emit",
				commandLineArgs: commandLineArgs
			} : TscEdit);
			var introduceError = (sys:TestSys) -> {
				sys.replaceFileText("/home/src/workspaces/project/src/class.ts", "prop", "prop1");
			};
			var fixError = (sys:TestSys) -> {
				sys.replaceFileText("/home/src/workspaces/project/src/class.ts", "prop1", "prop");
			};
			var testCases = ([] : Array<TscInput>);
			for (scenario in noEmitChangesScenarios) {
				testCases = append(
					testCases,
					({
						subScenario:     "changes " + scenario.subScenario,
						commandLineArgs: commandLineArgs,
						files:           getTscNoEmitChangesFileMap(scenario.optionsString),
						edits: ([
							noChangeWithNoEmit,
							noChangeWithNoEmit,
							{
								caption:         "Introduce error but still noEmit",
								commandLineArgs: noChangeWithNoEmit.commandLineArgs,
								edit:            introduceError
							},
							{
								caption: "Fix error and emit",
								edit:    fixError
							},
							noChangeWithEmit,
							noChangeWithNoEmit,
							noChangeWithNoEmit,
							noChangeWithEmit,
							{
								caption: "Introduce error and emit",
								edit:    introduceError
							},
							noChangeWithEmit,
							noChangeWithNoEmit,
							noChangeWithNoEmit,
							noChangeWithEmit,
							{
								caption:         "Fix error and no emit",
								commandLineArgs: noChangeWithNoEmit.commandLineArgs,
								edit:            fixError
							},
							noChangeWithEmit,
							noChangeWithNoEmit,
							noChangeWithNoEmit,
							noChangeWithEmit
						] : Array<TscEdit>)
					} : TscInput),
					({
						subScenario:     "changes with initial noEmit " + scenario.subScenario,
						commandLineArgs: noChangeWithNoEmit.commandLineArgs,
						files:           getTscNoEmitChangesFileMap(scenario.optionsString),
						edits: ([
							noChangeWithEmit,
							{
								caption:         "Introduce error with emit",
								commandLineArgs: commandLineArgs,
								edit:            introduceError
							},
							{
								caption: "Fix error and no emit",
								edit:    fixError
							},
							noChangeWithEmit
						] : Array<TscEdit>)
					} : TscInput)
				);
			}
			return testCases;
		};
		var getTscNoEmitDtsChangesFileMap = function(incremental:Bool, asModules:Bool):FileMap {
			var files = ([
				"/home/src/projects/project/a.ts" => Core.IfElse(asModules, "export const a = class { private p = 10; };", "const a = class { private p = 10; };"),
				"/home/src/projects/project/tsconfig.json" => Stringtestutil.Dedent(sprintf("
				{
					\"compilerOptions\": {
						\"incremental\": %t,
					}
				}
		", incremental))
			] : FileMap);
			if (asModules) {
				files["/home/src/projects/project/b.ts"] = "export const b = 10;";
			}
			return files;
		};
		var getTscNoEmitDtsChangesEdits = function(commandLineArgs:Array<String>):Array<TscEdit> {
			return ([
				noChange,
				{
					caption:         "With declaration enabled noEmit - Should report errors",
					commandLineArgs: Slices.Concat(commandLineArgs, ["--noEmit", "--declaration"])
				},
				{
					caption:         "With declaration and declarationMap noEmit - Should report errors",
					commandLineArgs: Slices.Concat(commandLineArgs, ["--noEmit", "--declaration", "--declarationMap"])
				},
				noChange,
				{
					caption:         "Dts Emit with error",
					commandLineArgs: Slices.Concat(commandLineArgs, ["--declaration"])
				},
				{
					caption: "Fix the error",
					edit: (sys:TestSys) -> {
						sys.replaceFileText("/home/src/projects/project/a.ts", "private", "public");
					}
				},
				{
					caption:         "With declaration enabled noEmit",
					commandLineArgs: Slices.Concat(commandLineArgs, ["--noEmit", "--declaration"])
				},
				{
					caption:         "With declaration and declarationMap noEmit",
					commandLineArgs: Slices.Concat(commandLineArgs, ["--noEmit", "--declaration", "--declarationMap"])
				}
			] : Array<TscEdit>);
		};
		var getTscNoEmitDtsChangesTestCases = function():Array<TscInput> {
			return ([
				{
					subScenario:     "dts errors with declaration enable changes",
					commandLineArgs: ["-b", "-v", "--noEmit"],
					files:           getTscNoEmitDtsChangesFileMap(false, false),
					cwd:             "/home/src/projects/project",
					edits:           getTscNoEmitDtsChangesEdits(["-b", "-v"])
				},
				{
					subScenario:     "dts errors with declaration enable changes with incremental",
					commandLineArgs: ["-b", "-v", "--noEmit"],
					files:           getTscNoEmitDtsChangesFileMap(true, false),
					cwd:             "/home/src/projects/project",
					edits:           getTscNoEmitDtsChangesEdits(["-b", "-v"])
				},
				{
					subScenario:     "dts errors with declaration enable changes with incremental as modules",
					commandLineArgs: ["-b", "-v", "--noEmit"],
					files:           getTscNoEmitDtsChangesFileMap(true, true),
					cwd:             "/home/src/projects/project",
					edits:           getTscNoEmitDtsChangesEdits(["-b", "-v"])
				}
			] : Array<TscInput>);
		};
		var getTscNoEmitDtsChangesMultiFileErrorsTestCases = function(commandLineArgs:Array<String>):Array<TscInput> {
			var aContent = "export const a = class { private p = 10; };";
			return ([
				{
					subScenario:     "dts errors with declaration enable changes with multiple files",
					commandLineArgs: Slices.Concat(commandLineArgs, ["--noEmit"]),
					files: ([
						"/home/src/projects/project/a.ts" => aContent,
						"/home/src/projects/project/b.ts" => "export const b = 10;",
						"/home/src/projects/project/c.ts" => Strings.Replace(aContent, "a", "c", 1),
						"/home/src/projects/project/d.ts" => Strings.Replace(aContent, "a", "d", 1),
						"/home/src/projects/project/tsconfig.json" => Stringtestutil.Dedent("
						{
							\"compilerOptions\": {
								\"incremental\": true,
							}
						}
				")
					] : FileMap),
					cwd: "/home/src/projects/project",
					edits: Slices.Concat(
						getTscNoEmitDtsChangesEdits(commandLineArgs),
						([
							{
								caption: "Fix the another ",
								edit: (sys:TestSys) -> {
									sys.replaceFileText("/home/src/projects/project/c.ts", "private", "public");
								},
								commandLineArgs: Slices.Concat(commandLineArgs, ["--noEmit", "--declaration", "--declarationMap"])
							}
						] : Array<TscEdit>)
					)
				}
			] : Array<TscInput>);
		};
		var getTscNoEmitLoopTestCase = function(suffix:String, commandLineArgs:Array<String>):TscInput {
			return ({
				subScenario: "does not go in loop when watching when no files are emitted" + suffix,
				files: ([
					"/user/username/projects/myproject/a.js" => "",
					"/user/username/projects/myproject/b.ts" => "",
					"/user/username/projects/myproject/tsconfig.json" => Stringtestutil.Dedent("
					{
                        \"compilerOptions\": {
                            \"allowJs\": true,
                            \"noEmit\": true,
                        },
                    }")
				] : FileMap),
				cwd:             "/user/username/projects/myproject",
				commandLineArgs: commandLineArgs,
				edits: ([
					{
						caption: "No change",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/user/username/projects/myproject/a.js", sys.readFileNoError("/user/username/projects/myproject/a.js"));
						}
					},
					{
						caption: "change",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/user/username/projects/myproject/a.js", "const x = 10;");
						}
					}
				] : Array<TscEdit>)
			} : TscInput);
		};
		var testCases = Slices.Concat(
			([
				{
					subScenario: "when project has strict true",
					files: ([
						"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
						{
							\"compilerOptions\": {
								\"incremental\": true,
								\"strict\": true
							}
						}"),
						"/home/src/workspaces/project/class1.ts" => "export class class1 {}"
					] : FileMap),
					commandLineArgs: ["--noEmit"],
					edits:           noChangeOnlyEdit
				},
				getTscNoEmitLoopTestCase("", ["-b", "-w", "-verbose"]),
				getTscNoEmitLoopTestCase(" with incremental", ["-b", "-w", "-verbose", "--incremental"])
			] : Array<TscInput>),
			getTscNoEmitAndErrorsTestCases([]),
			getTscNoEmitAndErrorsTestCases(["-b", "-v"]),
			getTscNoEmitChangesTestCases([]),
			getTscNoEmitChangesTestCases(["-b", "-v"]),
			getTscNoEmitDtsChangesTestCases(),
			getTscNoEmitDtsChangesMultiFileErrorsTestCases([]),
			getTscNoEmitDtsChangesMultiFileErrorsTestCases(["-b", "-v"]),
			getTscNoEmitAndErrorsWatchTestCases(["-b", "-verbose", "-w"])
		);

		for (test in testCases) {
			test.run("noEmit");
		}
	}

	public static function TestTscNoEmitOnError() {
		var getTscNoEmitOnErrorFileMap = function(scenario:TscNoEmitOnErrorScenario, declaration:Bool, incremental:Bool):FileMap {
			return ([
				"/user/username/projects/noEmitOnError/tsconfig.json" => Stringtestutil.Dedent(sprintf("
			{
				\"compilerOptions\": {
					\"outDir\": \"./dev-build\",
					\"declaration\": %t,
					\"incremental\": %t,
					\"noEmitOnError\": true,
				},
			}", declaration, incremental)),
				"/user/username/projects/noEmitOnError/shared/types/db.ts" => Stringtestutil.Dedent("
				export interface A {
					name: string;
				}
			"),
				"/user/username/projects/noEmitOnError/src/main.ts" => scenario.mainErrorContent,
				"/user/username/projects/noEmitOnError/src/other.ts" => Stringtestutil.Dedent("
				console.log(\"hi\");
				export { }
			")
			] : FileMap);
		};
		var getTscNoEmitOnErrorTestCases = function(scenarios:Array<TscNoEmitOnErrorScenario>, commandLineArgs:Array<String>):Array<TscInput> {
			var testCases = ([] : Array<TscInput>);
			for (scenario in scenarios) {
				var edits = ([
					noChange,
					{
						caption: "Fix error",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/user/username/projects/noEmitOnError/src/main.ts", scenario.fixedErrorContent);
						}
					},
					noChange
				] : Array<TscEdit>);
				testCases = append(
					testCases,
					({
						subScenario:     scenario.subScenario,
						files:           getTscNoEmitOnErrorFileMap(scenario, false, false),
						cwd:             "/user/username/projects/noEmitOnError",
						commandLineArgs: commandLineArgs,
						edits:           edits
					} : TscInput),
					({
						subScenario:     scenario.subScenario + " with declaration",
						files:           getTscNoEmitOnErrorFileMap(scenario, true, false),
						cwd:             "/user/username/projects/noEmitOnError",
						commandLineArgs: commandLineArgs,
						edits:           edits
					} : TscInput),
					({
						subScenario:     scenario.subScenario + " with incremental",
						files:           getTscNoEmitOnErrorFileMap(scenario, false, true),
						cwd:             "/user/username/projects/noEmitOnError",
						commandLineArgs: commandLineArgs,
						edits:           edits
					} : TscInput),
					({
						subScenario:     scenario.subScenario + " with declaration with incremental",
						files:           getTscNoEmitOnErrorFileMap(scenario, true, true),
						cwd:             "/user/username/projects/noEmitOnError",
						commandLineArgs: commandLineArgs,
						edits:           edits
					} : TscInput)
				);
			}
			return testCases;
		};
		var getTscWatchNoEmitOnErrorTestCases = function(scenarios:Array<TscNoEmitOnErrorScenario>, commandLineArgs:Array<String>):Array<TscInput> {
			var edits:Array<TscEdit> = null;
			for (scenario in scenarios) {
				if (edits != null) {
					edits = append(edits, ({
						caption: scenario.subScenario,
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/user/username/projects/noEmitOnError/src/main.ts", scenario.mainErrorContent);
						}
					} : TscEdit));
				}
				edits = append(
					edits,
					({
						caption: "No Change",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/user/username/projects/noEmitOnError/src/main.ts", sys.readFileNoError("/user/username/projects/noEmitOnError/src/main.ts"));
						}
					} : TscEdit),
					({
						caption: "Fix " + scenario.subScenario,
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/user/username/projects/noEmitOnError/src/main.ts", scenario.fixedErrorContent);
						}
					} : TscEdit),
					({
						caption: "No Change",
						edit: (sys:TestSys) -> {
							sys.writeFileNoError("/user/username/projects/noEmitOnError/src/main.ts", sys.readFileNoError("/user/username/projects/noEmitOnError/src/main.ts"));
						}
					} : TscEdit)
				);
			}
			return ([
				{
					subScenario:     "noEmitOnError",
					files:           getTscNoEmitOnErrorFileMap(scenarios[0], false, false),
					cwd:             "/user/username/projects/noEmitOnError",
					commandLineArgs: commandLineArgs,
					edits:           edits
				},
				{
					subScenario:     "noEmitOnError with declaration",
					files:           getTscNoEmitOnErrorFileMap(scenarios[0], true, false),
					cwd:             "/user/username/projects/noEmitOnError",
					commandLineArgs: commandLineArgs,
					edits:           edits
				},
				{
					subScenario:     "noEmitOnError with incremental",
					files:           getTscNoEmitOnErrorFileMap(scenarios[0], false, true),
					cwd:             "/user/username/projects/noEmitOnError",
					commandLineArgs: commandLineArgs,
					edits:           edits
				},
				{
					subScenario:     "noEmitOnError with declaration with incremental",
					files:           getTscNoEmitOnErrorFileMap(scenarios[0], true, true),
					cwd:             "/user/username/projects/noEmitOnError",
					commandLineArgs: commandLineArgs,
					edits:           edits
				}
			] : Array<TscInput>);
		};
		var scenarios = ([
			{
				subScenario: "syntax errors",
				mainErrorContent: Stringtestutil.Dedent("
                import { A } from \"../shared/types/db\";
                const a = {
                    lastName: 'sdsd'
                ;
            "),
				fixedErrorContent: Stringtestutil.Dedent("
                import { A } from \"../shared/types/db\";
                const a = {
                    lastName: 'sdsd'
                };")
			},
			{
				subScenario: "semantic errors",
				mainErrorContent: Stringtestutil.Dedent("
                import { A } from \"../shared/types/db\";
                const a: string = 10;"),
				fixedErrorContent: Stringtestutil.Dedent("
                import { A } from \"../shared/types/db\";
                const a: string = \"hello\";")
			},
			{
				subScenario: "dts errors",
				mainErrorContent: Stringtestutil.Dedent("
                import { A } from \"../shared/types/db\";
                export const a = class { private p = 10; };
            "),
				fixedErrorContent: Stringtestutil.Dedent("
                import { A } from \"../shared/types/db\";
                export const a = class { p = 10; };
            ")
			}
		] : Array<TscNoEmitOnErrorScenario>);
		var testCases = Slices.Concat(
			getTscNoEmitOnErrorTestCases(scenarios, []),
			getTscNoEmitOnErrorTestCases(scenarios, ["-b", "-v"]),
			([
				{
					subScenario: "when declarationMap changes",
					files: ([
						"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
						{
							\"compilerOptions\": {
								\"noEmitOnError\": true,
								\"declaration\": true,
								\"composite\": true,
							},
						}"),
						"/home/src/workspaces/project/a.ts" => "const x = 10;",
						"/home/src/workspaces/project/b.ts" => "const y = 10;"
					] : FileMap),
					edits: ([
						{
							caption: "error and enable declarationMap",
							edit: (sys:TestSys) -> {
								sys.replaceFileText("/home/src/workspaces/project/a.ts", "x", "x: 20");
							},
							commandLineArgs: ["--declarationMap"]
						},
						{
							caption: "fix error declarationMap",
							edit: (sys:TestSys) -> {
								sys.replaceFileText("/home/src/workspaces/project/a.ts", "x: 20", "x");
							},
							commandLineArgs: ["--declarationMap"]
						}
					] : Array<TscEdit>)
				},
				{
					subScenario: "file deleted before fixing error with noEmitOnError",
					files: ([
						"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
						{
							\"compilerOptions\": {
								\"outDir\": \"outDir\",
								\"noEmitOnError\": true,
							},
						}"),
						"/home/src/workspaces/project/file1.ts" => "export const x: 30 = \"hello\";",
						"/home/src/workspaces/project/file2.ts" => "export class D { }"
					] : FileMap),
					commandLineArgs: ["-i"],
					edits: ([
						{
							caption: "delete file without error",
							edit: (sys:TestSys) -> {
								sys.removeNoError("/home/src/workspaces/project/file2.ts");
							}
						}
					] : Array<TscEdit>)
				}
			] : Array<TscInput>),
			getTscWatchNoEmitOnErrorTestCases(scenarios, ["-b", "-w", "-v"])
		);

		for (test in testCases) {
			test.run("noEmitOnError");
		}
	}

	public static function TestTscProjectReferences() {
		var cases = ([
			{
				subScenario: "when project references composite project with noEmit",
				files: ([
					"/home/src/workspaces/solution/utils/index.ts" => "export const x = 10;",
					"/home/src/workspaces/solution/utils/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"noEmit\": true
					}
				}"),
					"/home/src/workspaces/solution/project/index.ts" => "import { x } from \"../utils\";",
					"/home/src/workspaces/solution/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"references\": [
						{ \"path\": \"../utils\" },
					],
				}")
				] : FileMap),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--p", "project"]
			},
			{
				subScenario: "when project references composite",
				files: ([
					"/home/src/workspaces/solution/utils/index.ts" =>   "export const x = 10;",
					"/home/src/workspaces/solution/utils/index.d.ts" => "export declare const x = 10;",
					"/home/src/workspaces/solution/utils/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true
					}
				}"),
					"/home/src/workspaces/solution/project/index.ts" => "import { x } from \"../utils\";",
					"/home/src/workspaces/solution/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"references\": [
						{ \"path\": \"../utils\" },
					],
				}")
				] : FileMap),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--p", "project"]
			},
			{
				subScenario: "when project reference is not built",
				files: ([
					"/home/src/workspaces/solution/utils/index.ts" => "export const x = 10;",
					"/home/src/workspaces/solution/utils/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true
					}
				}"),
					"/home/src/workspaces/solution/project/index.ts" => "import { x } from \"../utils\";",
					"/home/src/workspaces/solution/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"references\": [
						{ \"path\": \"../utils\" },
					],
				}")
				] : FileMap),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--p", "project"]
			},
			{
				subScenario: "when project contains invalid project reference",
				files: ([
					"/home/src/workspaces/solution/project/index.ts" => "export const x = 10;",
					"/home/src/workspaces/solution/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"references\": [
						{ \"path\": \"../utils\" },
					],
				}")
				] : FileMap),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--p", "project"]
			},
			{
				subScenario: "default import interop uses referenced project settings",
				files: ([
					"/home/src/workspaces/project/node_modules/ambiguous-package/package.json" => Stringtestutil.Dedent("
				{
					\"name\": \"ambiguous-package\"
				}"),
					"/home/src/workspaces/project/node_modules/ambiguous-package/index.d.ts" => "export declare const ambiguous: number;",
					"/home/src/workspaces/project/node_modules/esm-package/package.json" => Stringtestutil.Dedent("
				{
					\"name\": \"esm-package\",
					\"type\": \"module\"
				}"),
					"/home/src/workspaces/project/node_modules/esm-package/index.d.ts" => "export declare const esm: number;",
					"/home/src/workspaces/project/lib/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"declaration\": true,
						\"rootDir\": \"src\",
						\"outDir\": \"dist\",
						\"module\": \"esnext\",
						\"moduleResolution\": \"bundler\",
					},
					\"include\": [\"src\"],
				}"),
					"/home/src/workspaces/project/lib/src/a.ts" =>    "export const a = 0;",
					"/home/src/workspaces/project/lib/dist/a.d.ts" => "export declare const a = 0;",
					"/home/src/workspaces/project/app/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"module\": \"esnext\",
						\"moduleResolution\": \"bundler\",
						\"rootDir\": \"src\",
						\"outDir\": \"dist\",
					},
					\"include\": [\"src\"],
					\"references\": [
						{ \"path\": \"../lib\" },
					],
				}"),
					"/home/src/workspaces/project/app/src/local.ts" => "export const local = 0;",
					"/home/src/workspaces/project/app/src/index.ts" => Stringtestutil.Dedent("
					import local from \"./local\"; // Error
					import esm from \"esm-package\"; // Error
					import referencedSource from \"../../lib/src/a\"; // Error
					import referencedDeclaration from \"../../lib/dist/a\"; // Error
					import ambiguous from \"ambiguous-package\"; // Ok")
				] : FileMap),
				commandLineArgs: ["--p", "app", "--pretty", "false"]
			},
			{
				subScenario: "referenced project with esnext module disallows synthetic default imports",
				files: ([
					"/home/src/workspaces/project/lib/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"declaration\": true,
						\"module\": \"esnext\",
						\"moduleResolution\": \"bundler\",
						\"rootDir\": \"src\",
						\"outDir\": \"dist\"
					},
					\"include\": [\"src\"]
				}"),
					"/home/src/workspaces/project/lib/src/utils.ts" =>    "export const test = () => 'test';",
					"/home/src/workspaces/project/lib/dist/utils.d.ts" => "export declare const test: () => string;",
					"/home/src/workspaces/project/app/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"module\": \"esnext\",
						\"moduleResolution\": \"bundler\"
					},
					\"references\": [
						{ \"path\": \"../lib\" }
					]
				}"),
					"/home/src/workspaces/project/app/index.ts" => Stringtestutil.Dedent("
					import TestSrc from '../lib/src/utils'; // Error
					import TestDecl from '../lib/dist/utils'; // Error
					console.log(TestSrc.test());
					console.log(TestDecl.test());")
				] : FileMap),
				commandLineArgs: ["--p", "app", "--pretty", "false"]
			},
			{
				subScenario: "referencing ambient const enum from referenced project with preserveConstEnums",
				files: ([
					"/home/src/workspaces/solution/utils/index.ts" =>   "export const enum E { A = 1 }",
					"/home/src/workspaces/solution/utils/index.d.ts" => "export declare const enum E { A = 1 }",
					"/home/src/workspaces/solution/utils/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"declaration\": true,
						\"preserveConstEnums\": true,
					},
				}"),
					"/home/src/workspaces/solution/project/index.ts" => "import { E } from \"../utils\"; E.A;",
					"/home/src/workspaces/solution/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"isolatedModules\": true,
					},
					\"references\": [
						{ \"path\": \"../utils\" },
					],
				}")
				] : FileMap),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--p", "project"]
			},
			{
				subScenario: "importing const enum from referenced project with preserveConstEnums and verbatimModuleSyntax",
				files: ([
					"/home/src/workspaces/solution/preserve/index.ts" =>   "export const enum E { A = 1 }",
					"/home/src/workspaces/solution/preserve/index.d.ts" => "export declare const enum E { A = 1 }",
					"/home/src/workspaces/solution/preserve/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"declaration\": true,
						\"preserveConstEnums\": true,
					},
				}"),
					"/home/src/workspaces/solution/no-preserve/index.ts" =>   "export const enum E { A = 1 }",
					"/home/src/workspaces/solution/no-preserve/index.d.ts" => "export declare const enum F { A = 1 }",
					"/home/src/workspaces/solution/no-preserve/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"declaration\": true,
						\"preserveConstEnums\": false,
					},
				}"),
					"/home/src/workspaces/solution/project/index.ts" => Stringtestutil.Dedent("
					import { E } from \"../preserve\";
					import { F } from \"../no-preserve\";
					E.A;
					F.A;"),
					"/home/src/workspaces/solution/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"module\": \"preserve\",
						\"verbatimModuleSyntax\": true,
					},
					\"references\": [
						{ \"path\": \"../preserve\" },
						{ \"path\": \"../no-preserve\" },
					],
				}")
				] : FileMap),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--p", "project", "--pretty", "false"]
			},
			{
				subScenario: "rewriteRelativeImportExtensionsProjectReferences1",
				files: ([
					"/home/src/workspaces/packages/common/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"rootDir\": \"src\",
						\"outDir\": \"dist\", 
						\"module\": \"nodenext\"
					}
				}"),
					"/home/src/workspaces/packages/common/package.json" => Stringtestutil.Dedent("
				{
						\"name\": \"common\",
						\"version\": \"1.0.0\",
						\"type\": \"module\",
						\"exports\": {
							\".\": {
								\"source\": \"./src/index.ts\",
								\"default\": \"./dist/index.js\"
							}
						}
				}"),
					"/home/src/workspaces/packages/common/src/index.ts" =>    "export {};",
					"/home/src/workspaces/packages/common/dist/index.d.ts" => "export {};",
					"/home/src/workspaces/packages/main/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"module\": \"nodenext\",
						\"rewriteRelativeImportExtensions\": true,
						\"rootDir\": \"src\",
						\"outDir\": \"dist\"
					},
					\"references\": [
						{ \"path\": \"../common\" }
					]
				}"),
					"/home/src/workspaces/packages/main/package.json" => Stringtestutil.Dedent("
				{
					\"type\": \"module\"
				}"),
					"/home/src/workspaces/packages/main/src/index.ts" => "import {} from \"../../common/src/index.ts\";"
				] : FileMap),
				cwd:             "/home/src/workspaces",
				commandLineArgs: ["-p", "packages/main", "--pretty", "false"]
			},
			{
				subScenario: "rewriteRelativeImportExtensionsProjectReferences2",
				files: ([
					"/home/src/workspaces/solution/src/tsconfig-base.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"module\": \"nodenext\",
						\"composite\": true,
						\"rootDir\": \".\",
						\"outDir\": \"../dist\",
						\"rewriteRelativeImportExtensions\": true
					}
				}"),
					"/home/src/workspaces/solution/src/compiler/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"../tsconfig-base.json\",
					\"compilerOptions\": {}
				}"),
					"/home/src/workspaces/solution/src/compiler/parser.ts" =>    "export {};",
					"/home/src/workspaces/solution/dist/compiler/parser.d.ts" => "export {};",
					"/home/src/workspaces/solution/src/services/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"../tsconfig-base.json\",
					\"compilerOptions\": {},
					\"references\": [
						{ \"path\": \"../compiler\" }
					]
				}"),
					"/home/src/workspaces/solution/src/services/services.ts" => "import {} from \"../compiler/parser.ts\";"
				] : FileMap),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--p", "src/services", "--pretty", "false"]
			},
			{
				subScenario: "rewriteRelativeImportExtensionsProjectReferences3",
				files: ([
					"/home/src/workspaces/solution/src/tsconfig-base.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": { 
						\"module\": \"nodenext\",
						\"composite\": true,
						\"rewriteRelativeImportExtensions\": true
					}
				}"),
					"/home/src/workspaces/solution/src/compiler/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"../tsconfig-base.json\",
					\"compilerOptions\": {
						\"rootDir\": \".\",
						\"outDir\": \"../../dist/compiler\"
					}
				}"),
					"/home/src/workspaces/solution/src/compiler/parser.ts" =>    "export {};",
					"/home/src/workspaces/solution/dist/compiler/parser.d.ts" => "export {};",
					"/home/src/workspaces/solution/src/services/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"extends\": \"../tsconfig-base.json\",
					\"compilerOptions\": {
						\"rootDir\": \".\", 
						\"outDir\": \"../../dist/services\"
					},
					\"references\": [
						{ \"path\": \"../compiler\" }
					]
				}"),
					"/home/src/workspaces/solution/src/services/services.ts" => "import {} from \"../compiler/parser.ts\";"
				] : FileMap),
				cwd:             "/home/src/workspaces/solution",
				commandLineArgs: ["--p", "src/services", "--pretty", "false"]
			},
			{
				subScenario: "default setup was created correctly",
				files: ([
					"/home/src/workspaces/project/primary/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"bin\",
					}
				}"),
					"/home/src/workspaces/project/primary/a.ts" => "export { };",
					"/home/src/workspaces/project/secondary/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"bin\",
					},
					\"references\": [{
						\"path\": \"../primary\"
					}]
				}"),
					"/home/src/workspaces/project/secondary/b.ts" => "import * as mod_1 from \"../primary/a\";"
				] : FileMap),
				commandLineArgs: ["--p", "primary/tsconfig.json"]
			},
			{
				subScenario: "errors when declaration = false",
				files: ([
					"/home/src/workspaces/project/primary/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"bin\",
						\"declaration\": false
					}
				}"),
					"/home/src/workspaces/project/primary/a.ts" => "export { };"
				] : FileMap),
				commandLineArgs: ["--p", "primary/tsconfig.json"]
			},
			{
				subScenario: "errors when the referenced project doesnt have composite",
				files: ([
					"/home/src/workspaces/project/primary/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": false,
						\"outDir\": \"bin\",
					}
				}"),
					"/home/src/workspaces/project/primary/a.ts" => "export { };",
					"/home/src/workspaces/project/reference/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"bin\",
					},
					\"files\": [ \"b.ts\" ],
					\"references\": [ { \"path\": \"../primary\" } ]
				}"),
					"/home/src/workspaces/project/reference/b.ts" => "import * as mod_1 from \"../primary/a\";"
				] : FileMap),
				commandLineArgs: ["--p", "reference/tsconfig.json"]
			},
			{
				subScenario: "does not error when the referenced project doesnt have composite if its a container project",
				files: ([
					"/home/src/workspaces/project/primary/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": false,
						\"outDir\": \"bin\",
					}
				}"),
					"/home/src/workspaces/project/primary/a.ts" => "export { };",
					"/home/src/workspaces/project/reference/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"bin\",
					},
					\"files\": [ ],
					\"references\": [{
						\"path\": \"../primary\"
					}]
				}"),
					"/home/src/workspaces/project/reference/b.ts" => "import * as mod_1 from \"../primary/a\";"
				] : FileMap),
				commandLineArgs: ["--p", "reference/tsconfig.json"]
			},
			{
				subScenario: "errors when the file list is not exhaustive",
				files: ([
					"/home/src/workspaces/project/primary/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"bin\",
					},
					\"files\": [ \"a.ts\" ]
				}"),
					"/home/src/workspaces/project/primary/a.ts" => "import * as b from './b'",
					"/home/src/workspaces/project/primary/b.ts" => "export {}"
				] : FileMap),
				commandLineArgs: ["--p", "primary/tsconfig.json"]
			},
			{
				subScenario: "errors when the referenced project doesnt exist",
				files: ([
					"/home/src/workspaces/project/primary/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"bin\",
					},
					\"references\": [{
						\"path\": \"../foo\"
					}]
				}"),
					"/home/src/workspaces/project/primary/a.ts" => "export { };"
				] : FileMap),
				commandLineArgs: ["--p", "primary/tsconfig.json"]
			},
			{
				subScenario: "redirects to the output dts file",
				files: ([
					"/home/src/workspaces/project/alpha/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"bin\",
					}
				}"),
					"/home/src/workspaces/project/alpha/a.ts" =>       "export const m: number = 3;",
					"/home/src/workspaces/project/alpha/bin/a.d.ts" => "export { };",
					"/home/src/workspaces/project/beta/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"bin\",
					},
					\"references\": [ { \"path\": \"../alpha\" } ]
				}"),
					"/home/src/workspaces/project/beta/b.ts" => "import { m } from '../alpha/a'"
				] : FileMap),
				commandLineArgs: ["--p", "beta/tsconfig.json", "--explainFiles"]
			},
			{
				subScenario: "issues a nice error when the input file is missing",
				files: ([
					"/home/src/workspaces/project/alpha/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"bin\",
					},
					\"references\": []
				}"),
					"/home/src/workspaces/project/alpha/a.ts" => "export const m: number = 3;",
					"/home/src/workspaces/project/beta/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"bin\",
					},
					\"references\": [ { \"path\": \"../alpha\" } ]
				}"),
					"/home/src/workspaces/project/beta/b.ts" => "import { m } from '../alpha/a'"
				] : FileMap),
				commandLineArgs: ["--p", "beta/tsconfig.json"]
			},
			{
				subScenario: "issues a nice error when the input file is missing when module reference is not relative",
				files: ([
					"/home/src/workspaces/project/alpha/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"bin\",
					}
				}"),
					"/home/src/workspaces/project/alpha/a.ts" => "export const m: number = 3;",
					"/home/src/workspaces/project/beta/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"bin\",
						\"paths\": {
                            \"@alpha/*\": [\"../alpha/*\"],
                        },
					},
					\"references\": [ { \"path\": \"../alpha\" } ]
				}"),
					"/home/src/workspaces/project/beta/b.ts" => "import { m } from '@alpha/a'"
				] : FileMap),
				commandLineArgs: ["--p", "beta/tsconfig.json"]
			},
			{
				subScenario: "doesnt infer the rootDir from source paths",
				files: ([
					"/home/src/workspaces/project/alpha/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"bin\",
					},
					\"references\": []
				}"),
					"/home/src/workspaces/project/alpha/src/a.ts" => "export const m: number = 3;"
				] : FileMap),
				commandLineArgs: ["--p", "alpha/tsconfig.json"]
			},
			{
				// !!! sheetal rootDir error not reported
				subScenario: "errors when a file is outside the rootdir",
				files: ([
					"/home/src/workspaces/project/alpha/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"outDir\": \"bin\",
					},
					\"references\": []
				}"),
					"/home/src/workspaces/project/alpha/src/a.ts" => "import * as b from '../../beta/b'",
					"/home/src/workspaces/project/beta/b.ts" =>      "export { }"
				] : FileMap),
				commandLineArgs: ["--p", "alpha/tsconfig.json"]
			}
		] : Array<TscInput>);

		for (c in cases) {
			c.run("projectReferences");
		}
	}

	public static function TestTypeAcquisition() {
		(({
			subScenario: "parse tsconfig with typeAcquisition",
			files: ([
				"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
			{
				\"compilerOptions\": {
					\"composite\": true,
					\"noEmit\": true,
				},
				\"typeAcquisition\": {
					\"enable\": true,
					\"include\": [\"0.d.ts\", \"1.d.ts\"],
					\"exclude\": [\"0.js\", \"1.js\"],
					\"disableFilenameBasedTypeAcquisition\": true,
				},
			}")
			] : FileMap),
			commandLineArgs: []
		} : TscInput)).run("typeAcquisition");
	}

	public static function TestGenerateTrace() {
		var cases = ([
			{
				subScenario: "generateTrace generates types file",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"strict\": true,
						\"noEmit\": true
					}
				}"),
					"/home/src/workspaces/project/a.ts" => Stringtestutil.Dedent("
				interface Person {
					name: string;
					age: number;
				}
				const p: Person = { name: \"Alice\", age: 30 };
				")
				] : FileMap),
				commandLineArgs: ["--generateTrace", "/home/src/workspaces/project/trace", "--singleThreaded"]
			},
			{
				subScenario: "generateTrace with multiple files and complex types",
				files: ([
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"strict\": true,
						\"noEmit\": true
					}
				}"),
					"/home/src/workspaces/project/types.ts" => Stringtestutil.Dedent("
				export interface Container<T> {
					value: T;
					map<U>(fn: (x: T) => U): Container<U>;
				}
				export type Nullable<T> = T | null | undefined;
				"),
					"/home/src/workspaces/project/main.ts" => Stringtestutil.Dedent("
				import { Container, Nullable } from \"./types\";
				const c: Container<number> = { value: 42, map: (fn) => ({ value: fn(42), map: c.map }) };
				const n: Nullable<string> = \"hello\";
				")
				] : FileMap),
				commandLineArgs: ["--generateTrace", "/home/src/workspaces/project/trace", "--singleThreaded"]
			}
		] : Array<TscInput>);

		for (c in cases) {
			c.run("generateTrace");
		}
	}
}
