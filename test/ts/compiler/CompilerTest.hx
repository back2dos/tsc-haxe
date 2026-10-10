package ts.compiler;

import ts.vfs.vfstest.Vfstest.Vfstest;
import ts.compiler.Program;
import ts.bundled.Bundled;
import ts.tsoptions.Parsedcommandline;
import ts.core.Parsedoptions;
import ts.core.Compileroptions;
import ts.core.Compileroptions.ScriptTarget.*;
import ts.core.Tristate.Tristate.*;

// Port of program_test.go and emit_test.go.
// Benchmarks not ported: BenchmarkNewProgram, BenchmarkEmitLongLines.
class CompilerTest {
	static final esnextLibs = [
		"lib.es5.d.ts",
		"lib.es2015.d.ts",
		"lib.es2016.d.ts",
		"lib.es2017.d.ts",
		"lib.es2018.d.ts",
		"lib.es2019.d.ts",
		"lib.es2020.d.ts",
		"lib.es2021.d.ts",
		"lib.es2022.d.ts",
		"lib.es2023.d.ts",
		"lib.es2024.d.ts",
		"lib.es2025.d.ts",
		"lib.esnext.d.ts",
		"lib.dom.d.ts",
		"lib.dom.iterable.d.ts",
		"lib.dom.asynciterable.d.ts",
		"lib.webworker.importscripts.d.ts",
		"lib.scripthost.d.ts",
		"lib.es2015.core.d.ts",
		"lib.es2015.collection.d.ts",
		"lib.es2015.generator.d.ts",
		"lib.es2015.iterable.d.ts",
		"lib.es2015.promise.d.ts",
		"lib.es2015.proxy.d.ts",
		"lib.es2015.reflect.d.ts",
		"lib.es2015.symbol.d.ts",
		"lib.es2015.symbol.wellknown.d.ts",
		"lib.es2016.array.include.d.ts",
		"lib.es2016.intl.d.ts",
		"lib.es2017.arraybuffer.d.ts",
		"lib.es2017.date.d.ts",
		"lib.es2017.object.d.ts",
		"lib.es2017.sharedmemory.d.ts",
		"lib.es2017.string.d.ts",
		"lib.es2017.intl.d.ts",
		"lib.es2017.typedarrays.d.ts",
		"lib.es2018.asyncgenerator.d.ts",
		"lib.es2018.asynciterable.d.ts",
		"lib.es2018.intl.d.ts",
		"lib.es2018.promise.d.ts",
		"lib.es2018.regexp.d.ts",
		"lib.es2019.array.d.ts",
		"lib.es2019.object.d.ts",
		"lib.es2019.string.d.ts",
		"lib.es2019.symbol.d.ts",
		"lib.es2019.intl.d.ts",
		"lib.es2020.bigint.d.ts",
		"lib.es2020.date.d.ts",
		"lib.es2020.promise.d.ts",
		"lib.es2020.sharedmemory.d.ts",
		"lib.es2020.string.d.ts",
		"lib.es2020.symbol.wellknown.d.ts",
		"lib.es2020.intl.d.ts",
		"lib.es2020.number.d.ts",
		"lib.es2021.promise.d.ts",
		"lib.es2021.string.d.ts",
		"lib.es2021.weakref.d.ts",
		"lib.es2021.intl.d.ts",
		"lib.es2022.array.d.ts",
		"lib.es2022.error.d.ts",
		"lib.es2022.intl.d.ts",
		"lib.es2022.object.d.ts",
		"lib.es2022.string.d.ts",
		"lib.es2022.regexp.d.ts",
		"lib.es2023.array.d.ts",
		"lib.es2023.collection.d.ts",
		"lib.es2023.intl.d.ts",
		"lib.es2024.arraybuffer.d.ts",
		"lib.es2024.collection.d.ts",
		"lib.es2024.object.d.ts",
		"lib.es2024.promise.d.ts",
		"lib.es2024.regexp.d.ts",
		"lib.es2024.sharedmemory.d.ts",
		"lib.es2024.string.d.ts",
		"lib.es2025.collection.d.ts",
		"lib.es2025.float16.d.ts",
		"lib.es2025.intl.d.ts",
		"lib.es2025.iterator.d.ts",
		"lib.es2025.promise.d.ts",
		"lib.es2025.regexp.d.ts",
		"lib.esnext.array.d.ts",
		"lib.esnext.collection.d.ts",
		"lib.esnext.date.d.ts",
		"lib.esnext.decorators.d.ts",
		"lib.esnext.disposable.d.ts",
		"lib.esnext.error.d.ts",
		"lib.esnext.intl.d.ts",
		"lib.esnext.sharedmemory.d.ts",
		"lib.esnext.temporal.d.ts",
		"lib.esnext.typedarrays.d.ts",
		"lib.decorators.d.ts",
		"lib.decorators.legacy.d.ts",
		"lib.esnext.full.d.ts"
	];

	static function programTestCases():Array<{testName:String, files:Array<Array<String>>, expectedFiles:Array<String>, target:ScriptTarget}> {
		return [
			{
				testName: "BasicFileOrdering",
				files: [
					["c:/dev/src/index.ts", "/// <reference path='c:/dev/src2/a/5.ts' />\n/// <reference path='c:/dev/src2/a/10.ts' />"],
					["c:/dev/src2/a/5.ts", "/// <reference path='4.ts' />"],
					["c:/dev/src2/a/4.ts", "/// <reference path='b/3.ts' />"],
					["c:/dev/src2/a/b/3.ts", "/// <reference path='2.ts' />"],
					["c:/dev/src2/a/b/2.ts", "/// <reference path='c/1.ts' />"],
					["c:/dev/src2/a/b/c/1.ts", "console.log('hello');"],
					["c:/dev/src2/a/10.ts", "/// <reference path='b/c/d/9.ts' />"],
					["c:/dev/src2/a/b/c/d/9.ts", "/// <reference path='e/8.ts' />"],
					["c:/dev/src2/a/b/c/d/e/8.ts", "/// <reference path='7.ts' />"],
					["c:/dev/src2/a/b/c/d/e/7.ts", "/// <reference path='f/6.ts' />"],
					["c:/dev/src2/a/b/c/d/e/f/6.ts", "console.log('world!');"]
				],
				expectedFiles: esnextLibs.concat([
					"c:/dev/src2/a/b/c/1.ts",
					"c:/dev/src2/a/b/2.ts",
					"c:/dev/src2/a/b/3.ts",
					"c:/dev/src2/a/4.ts",
					"c:/dev/src2/a/5.ts",
					"c:/dev/src2/a/b/c/d/e/f/6.ts",
					"c:/dev/src2/a/b/c/d/e/7.ts",
					"c:/dev/src2/a/b/c/d/e/8.ts",
					"c:/dev/src2/a/b/c/d/9.ts",
					"c:/dev/src2/a/10.ts",
					"c:/dev/src/index.ts"
				]),
				target: ScriptTargetESNext
			},
			{
				testName: "FileOrderingImports",
				files: [
					["c:/dev/src/index.ts", "import * as five from '../src2/a/5.ts';\nimport * as ten from '../src2/a/10.ts';"],
					["c:/dev/src2/a/5.ts", "import * as four from './4.ts';"],
					["c:/dev/src2/a/4.ts", "import * as three from './b/3.ts';"],
					["c:/dev/src2/a/b/3.ts", "import * as two from './2.ts';"],
					["c:/dev/src2/a/b/2.ts", "import * as one from './c/1.ts';"],
					["c:/dev/src2/a/b/c/1.ts", "console.log('hello');"],
					["c:/dev/src2/a/10.ts", "import * as nine from './b/c/d/9.ts';"],
					["c:/dev/src2/a/b/c/d/9.ts", "import * as eight from './e/8.ts';"],
					["c:/dev/src2/a/b/c/d/e/8.ts", "import * as seven from './7.ts';"],
					["c:/dev/src2/a/b/c/d/e/7.ts", "import * as six from './f/6.ts';"],
					["c:/dev/src2/a/b/c/d/e/f/6.ts", "console.log('world!');"]
				],
				expectedFiles: esnextLibs.concat([
					"c:/dev/src2/a/b/c/1.ts",
					"c:/dev/src2/a/b/2.ts",
					"c:/dev/src2/a/b/3.ts",
					"c:/dev/src2/a/4.ts",
					"c:/dev/src2/a/5.ts",
					"c:/dev/src2/a/b/c/d/e/f/6.ts",
					"c:/dev/src2/a/b/c/d/e/7.ts",
					"c:/dev/src2/a/b/c/d/e/8.ts",
					"c:/dev/src2/a/b/c/d/9.ts",
					"c:/dev/src2/a/10.ts",
					"c:/dev/src/index.ts"
				]),
				target: ScriptTargetESNext
			},
			{
				testName: "FileOrderingCycles",
				files: [
					["c:/dev/src/index.ts", "import * as five from '../src2/a/5.ts';\nimport * as ten from '../src2/a/10.ts';"],
					["c:/dev/src2/a/5.ts", "import * as four from './4.ts';"],
					["c:/dev/src2/a/4.ts", "import * as three from './b/3.ts';"],
					["c:/dev/src2/a/b/3.ts", "import * as two from './2.ts';\nimport * as cycle from 'c:/dev/src/index.ts'; "],
					["c:/dev/src2/a/b/2.ts", "import * as one from './c/1.ts';"],
					["c:/dev/src2/a/b/c/1.ts", "console.log('hello');"],
					["c:/dev/src2/a/10.ts", "import * as nine from './b/c/d/9.ts';"],
					["c:/dev/src2/a/b/c/d/9.ts", "import * as eight from './e/8.ts';\nimport * as cycle from 'c:/dev/src/index.ts';"],
					["c:/dev/src2/a/b/c/d/e/8.ts", "import * as seven from './7.ts';"],
					["c:/dev/src2/a/b/c/d/e/7.ts", "import * as six from './f/6.ts';"],
					["c:/dev/src2/a/b/c/d/e/f/6.ts", "console.log('world!');"]
				],
				expectedFiles: esnextLibs.concat([
					"c:/dev/src2/a/b/c/1.ts",
					"c:/dev/src2/a/b/2.ts",
					"c:/dev/src2/a/b/3.ts",
					"c:/dev/src2/a/4.ts",
					"c:/dev/src2/a/5.ts",
					"c:/dev/src2/a/b/c/d/e/f/6.ts",
					"c:/dev/src2/a/b/c/d/e/7.ts",
					"c:/dev/src2/a/b/c/d/e/8.ts",
					"c:/dev/src2/a/b/c/d/9.ts",
					"c:/dev/src2/a/10.ts",
					"c:/dev/src/index.ts"
				]),
				target: ScriptTargetESNext
			}
		];
	}

	public static function run() {
		T.run("TestProgram", () -> {
			for (testCase in programTestCases()) {
				T.run("TestProgram/" + testCase.testName, () -> {
					final libPrefix = Bundled.LibPath() + "/";
					var fs = Vfstest.FromMap((null : Map<String, Any>), false /*useCaseSensitiveFileNames*/);
					fs = Bundled.WrapFS(fs);

					for (testFile in testCase.files) {
						fs.WriteFile(testFile[0], testFile[1]);
					}

					final opts = new CompilerOptions();
					opts.Target = testCase.target;

					final config = new ParsedCommandLine();
					config.ParsedConfig = new ParsedOptions();
					config.ParsedConfig.FileNames = ["c:/dev/src/index.ts"];
					config.ParsedConfig.CompilerOptions = opts;
					final programOptions = new ProgramOptions();
					programOptions.Config = config;
					programOptions.Host = Compiler.NewCompilerHost("c:/dev/src", fs, Bundled.LibPath(), null, null);
					final program = Compiler.NewProgram(programOptions);

					final actualFiles:Array<String> = [];
					for (file in program.GetSourceFiles()) {
						actualFiles.push(StringTools.startsWith(file.FileName(), libPrefix) ? file.FileName().substring(libPrefix.length) : file.FileName());
					}

					T.eq(testCase.expectedFiles.join("\n"), actualFiles.join("\n"));
				});
			}
		});

		T.run("TestIncludeProcessorDiagnosticsWithMissingFileCasing", () -> {
			// Use case-sensitive file names so that /src/MyFile.ts and /src/myFile.ts
			// have different canonical paths but the same lower-case path, triggering
			// file casing diagnostics in the include processor.
			var fs = Vfstest.FromMap((null : Map<String, Any>), true /*useCaseSensitiveFileNames*/);
			fs = Bundled.WrapFS(fs);

			// Only create the lowercase version; /src/MyFile.ts does not exist.
			fs.WriteFile("/src/myFile.ts", "export const y = 2;");

			final opts = new CompilerOptions();
			opts.SkipDefaultLibCheck = TSTrue;

			// List both casings as root files. The first one (/src/MyFile.ts) will fail
			// to load because it does not exist on the case-sensitive filesystem.
			final config = new ParsedCommandLine();
			config.ParsedConfig = new ParsedOptions();
			config.ParsedConfig.FileNames = ["/src/MyFile.ts", "/src/myFile.ts"];
			config.ParsedConfig.CompilerOptions = opts;
			final programOptions = new ProgramOptions();
			programOptions.Config = config;
			programOptions.Host = Compiler.NewCompilerHost("/", fs, Bundled.LibPath(), null, null);
			final program = Compiler.NewProgram(programOptions);

			// GetProgramDiagnostics triggers getDiagnostics which processes all
			// include processor diagnostics including the casing diagnostic whose
			// file path points to the missing /src/MyFile.ts. Before the fix this
			// panicked with a nil pointer dereference.
			var err:String = null;
			try {
				program.GetProgramDiagnostics();
			} catch (e:Dynamic) {
				err = "panic: " + Std.string(e);
			}
			T.eq(null, err);
		});
	}
}
