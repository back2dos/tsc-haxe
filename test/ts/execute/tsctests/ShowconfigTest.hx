package ts.execute.tsctests;

// Port of internal/execute/tsctests/showconfig_test.go (scenario data).
class ShowconfigTest {
	public static function run() {
		TestShowConfig();
	}

	public static function TestShowConfig() {
		var testCases = ([
			{
				subScenario:     "Default initialized TSConfig",
				commandLineArgs: ["--showConfig"]
			},
			{
				subScenario:     "Show TSConfig with files options",
				commandLineArgs: ["--showConfig", "file0.ts", "file1.ts", "file2.ts"]
			},
			{
				subScenario:     "Show TSConfig with boolean value compiler options",
				commandLineArgs: ["--showConfig", "--noUnusedLocals"]
			},
			{
				subScenario:     "Show TSConfig with enum value compiler options",
				commandLineArgs: ["--showConfig", "--target", "es5", "--jsx", "react"]
			},
			{
				subScenario:     "Show TSConfig with list compiler options",
				commandLineArgs: ["--showConfig", "--types", "jquery,mocha"]
			},
			{
				subScenario:     "Show TSConfig with list compiler options with enum value",
				commandLineArgs: ["--showConfig", "--lib", "es5,es2015.core"]
			},
			{
				subScenario:     "Show TSConfig with incorrect compiler option",
				commandLineArgs: ["--showConfig", "--someNonExistOption"]
			},
			{
				subScenario:     "Show TSConfig with incorrect compiler option value",
				commandLineArgs: ["--showConfig", "--lib", "nonExistLib,es5,es2015.promise"]
			},
			{
				subScenario:     "Show TSConfig with advanced options",
				commandLineArgs: ["--showConfig", "--declaration", "--declarationDir", "lib", "--skipLibCheck", "--noErrorTruncation"]
			},
			{
				subScenario: "Show TSConfig with compileOnSave and more",
				files: ([
					"/home/src/workspaces/project/src/index.ts" => "export const a = 1;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"esModuleInterop\": true,
						\"target\": \"es5\",
						\"module\": \"commonjs\",
						\"strict\": true
					},
					\"compileOnSave\": true,
					\"exclude\": [
						\"dist\"
					],
					\"files\": [],
					\"include\": [
						\"src/*\"
					],
					\"references\": [
						{ \"path\": \"./test\" }
					]
				}")
				] : FileMap),
				commandLineArgs: ["-p", "tsconfig.json", "--showConfig"]
			},
			{
				subScenario: "Show TSConfig with paths and more",
				files: ([
					"/home/src/workspaces/project/src/index.ts" => "export const a = 1;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"allowJs\": true,
						\"outDir\": \"./lib\",
						\"esModuleInterop\": true,
						\"module\": \"commonjs\",
						\"moduleResolution\": \"node\",
						\"target\": \"ES2017\",
						\"sourceMap\": true,
						\"baseUrl\": \".\",
						\"paths\": {
							\"@root/*\": [\"./*\"],
							\"@configs/*\": [\"src/configs/*\"],
							\"@common/*\": [\"src/common/*\"],
							\"*\": [
								\"node_modules/*\",
								\"src/types/*\"
							]
						},
						\"experimentalDecorators\": true,
						\"emitDecoratorMetadata\": true,
						\"resolveJsonModule\": true
					},
					\"include\": [
						\"./src/**/*\"
					]
				}")
				] : FileMap),
				commandLineArgs: ["-p", "tsconfig.json", "--showConfig"]
			},
			{
				subScenario: "Show TSConfig with include filtering files",
				files: ([
					"/home/src/workspaces/project/src/main.ts" => "export const a = 1;",
					"/home/src/workspaces/project/src/util.ts" => "export const b = 2;",
					"/home/src/workspaces/project/extra.ts" =>    "export const c = 3;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"strict\": true
					},
					\"include\": [
						\"src/**/*\"
					]
				}")
				] : FileMap),
				commandLineArgs: ["-p", "tsconfig.json", "--showConfig"]
			},
			{
				subScenario: "Show TSConfig with references",
				files: ([
					"/home/src/workspaces/project/src/index.ts" => "export const a = 1;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"composite\": true,
						\"strict\": true
					},
					\"references\": [
						{ \"path\": \"./packages/a\" },
						{ \"path\": \"./packages/b\" }
					]
				}")
				] : FileMap),
				commandLineArgs: ["-p", "tsconfig.json", "--showConfig"]
			},
			{
				subScenario: "Show TSConfig with exclude",
				files: ([
					"/home/src/workspaces/project/src/index.ts" =>  "export const a = 1;",
					"/home/src/workspaces/project/test/test1.ts" => "import { a } from \"../src\";",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"strict\": true
					},
					\"exclude\": [
						\"test\"
					]
				}")
				] : FileMap),
				commandLineArgs: ["-p", "tsconfig.json", "--showConfig"]
			},
			{
				subScenario: "Show TSConfig with files and include",
				files: ([
					"/home/src/workspaces/project/src/main.ts" => "export const a = 1;",
					"/home/src/workspaces/project/extra.ts" =>    "export const c = 3;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"strict\": true
					},
					\"files\": [
						\"extra.ts\"
					],
					\"include\": [
						\"src/**/*\"
					]
				}")
				] : FileMap),
				commandLineArgs: ["-p", "tsconfig.json", "--showConfig"]
			},
			{
				subScenario: "Show TSConfig with transitively implied options",
				files: ([
					"/home/src/workspaces/project/src/index.ts" => "export const a = 1;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"module\": \"nodenext\"
					}
				}")
				] : FileMap),
				commandLineArgs: ["-p", "tsconfig.json", "--showConfig"]
			},
			{
				subScenario: "Show TSConfig with exclude and outDir",
				files: ([
					"/home/src/workspaces/project/src/index.ts" =>    "export const a = 1;",
					"/home/src/workspaces/project/src/bin/tool.ts" => "export const b = 2;",
					"/home/src/workspaces/project/tsconfig.json" => Stringtestutil.Dedent("
				{
					\"compilerOptions\": {
						\"strict\": true,
						\"outDir\": \"./build\"
					},
					\"exclude\": [
						\"build\"
					]
				}")
				] : FileMap),
				commandLineArgs: ["-p", "tsconfig.json", "--showConfig"]
			}
		] : Array<TscInput>);

		for (test in testCases) {
			test.run("showConfig");
		}
	}
}
