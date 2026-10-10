package ts.testrunner;

// Port of compiler_runner.go: types and methods (the package-level funcs and vars are in Testrunner.hx).

enum abstract CompilerTestType(Int) from Int to Int {
	var TestTypeConformance = 0;
	var TestTypeRegression = 1;

	public function String():String {
		if ((cast this : CompilerTestType) == TestTypeRegression) {
			return "compiler";
		}
		return "conformance";
	}
}

@:allow(ts.testrunner)
class CompilerBaselineRunner implements Runner {
	var isSubmodule:Bool = false;
	var testFiles:Array<String> = null;
	var basePath:String = "";
	var testSuitName:String = "";

	public function new() {}

	public function TestSuitName():String {
		return testSuitName;
	}

	public function EnumerateTestFiles():Array<String> {
		if (Core.len(this.testFiles) > 0) {
			return this.testFiles;
		}
		final files = Harnessutil.EnumerateFiles(this.basePath, Testrunner.compilerBaselineRegex, true /*recursive*/);
		this.testFiles = files;
		return files;
	}

	public function RunTests(t:T):Void {
		this.cleanUpLocal(t);
		final files = this.EnumerateTestFiles();

		for (filename in files) {
			if (Testrunner.skippedTests.indexOf(Tspath.GetBaseFileName(filename)) >= 0) {
				continue;
			}
			this.runTest(t, filename);
		}
	}

	// PORT: Go removes testdata/baselines/local/...; the local baselines of the port are under
	// Baseline.LocalRoot and are replaced file by file.
	function cleanUpLocal(t:T):Void {}

	// PORT: public so a gate can run single tests (Go runs them only through RunTests).
	public function runTest(t:T, filename:String):Void {
		final test = Testrunner.getCompilerFileBasedTest(t, filename);
		final basename = Tspath.GetBaseFileName(filename);
		if (Core.len(test.configurations) > 0) {
			for (config in test.configurations) {
				var testName = basename;
				if (config.Name != "") {
					testName += " " + config.Name;
				}
				t.Run(testName, function(t:T) this.runSingleConfigTest(t, testName, test, config));
			}
		} else {
			t.Run(basename, function(t:T) this.runSingleConfigTest(t, basename, test, null));
		}
	}

	function runSingleConfigTest(t:T, testName:String, test:CompilerFileBasedTest, config:NamedTestConfiguration):Void {
		t.Parallel();
		try {
			final payload = Testrunner.makeUnitsFromTest(test.content, test.filename);
			final compilerTest = Testrunner.newCompilerTest(t, testName, test.filename, payload, config);

			Harnessutil.SkipUnsupportedCompilerOptions(t, compilerTest.options);

			compilerTest.verifyDiagnostics(t, this.testSuitName, this.isSubmodule);
			compilerTest.verifyJavaScriptOutput(t, this.testSuitName, this.isSubmodule);
			compilerTest.verifySourceMapOutput(t, this.testSuitName, this.isSubmodule);
			compilerTest.verifySourceMapRecord(t, this.testSuitName, this.isSubmodule);
			compilerTest.verifyTypesAndSymbols(t, this.testSuitName, this.isSubmodule);
			compilerTest.verifyModuleResolution(t, this.testSuitName, this.isSubmodule);
			compilerTest.verifyUnionOrdering(t);
			compilerTest.verifyParentPointers(t);
		} catch (e:haxe.Exception) {
			Testutil.RecoverAndFail(t, "Panic on compiling test " + test.filename, e);
		}
	}
}

@:allow(ts.testrunner)
class CompilerFileBasedTest {
	var filename:String = "";
	var content:String = "";
	var configurations:Array<NamedTestConfiguration> = null;

	public function new() {}
}

@:allow(ts.testrunner)
class CompilerTest {
	var testName:String = "";
	var filename:String = "";
	var basename:String = "";
	var configuredName:String = ""; // name with configuration description, e.g. `file`
	var options:CompilerOptions = null;
	var harnessOptions:HarnessOptions = null;
	var result:CompilationResult = null;
	var tsConfigFiles:Array<TestFile> = null;
	var toBeCompiled:Array<TestFile> = null; // equivalent to the files that will be passed on the command line
	var otherFiles:Array<TestFile> = null; // equivalent to other files on the file system not directly passed to the compiler (ie things that are referenced by other files)
	var hasNonDtsFiles:Bool = false;

	public function new() {}

	function verifyDiagnostics(t:T, suiteName:String, isSubmodule:Bool):Void {
		t.Run("error", function(t:T) {
			try {
				final files = Core.Concatenate(this.tsConfigFiles, Core.Concatenate(this.toBeCompiled, this.otherFiles));
				final opts = new Options(suiteName, isSubmodule);
				opts.DiffFixupOld = function(old:String):String {
					final sb = new StringBuf();
					for (line0 in old.split("\n")) {
						var line = line0;
						final relativePrefixNew = "==== ";
						final relativePrefixOld = relativePrefixNew + "./";
						if (StringTools.startsWith(line, relativePrefixOld)) {
							line = relativePrefixNew + line.substring(relativePrefixOld.length);
						}

						sb.add(line);
						sb.add("\n");
					}

					final s = sb.toString();
					return s.substring(0, s.length - 1);
				};
				Tsbaseline.DoErrorBaseline(t, this.configuredName, files == null ? [] : files, this.result.Diagnostics, this.result.Options.Pretty.IsTrue(), opts);
			} catch (e:haxe.Exception) {
				Testutil.RecoverAndFail(t, "Panic on creating error baseline for test " + this.filename, e);
			}
		});
	}

	function testHeader(isSubmodule:Bool):String {
		var headerComponents = Tspath.GetPathComponentsRelativeTo(Repo.TestDataPath(), this.filename, new ComparePathsOptions());
		if (isSubmodule) {
			headerComponents = headerComponents.slice(4); // Strip "./../_submodules/TypeScript" prefix
		}
		return Tspath.GetPathFromPathComponents(headerComponents);
	}

	function verifyJavaScriptOutput(t:T, suiteName:String, isSubmodule:Bool):Void {
		if (!this.hasNonDtsFiles) {
			return;
		}

		t.Run("output", function(t:T) {
			if (Testrunner.skippedEmitTests.exists(this.basename)) {
				t.Skip(Testrunner.skippedEmitTests.get(this.basename));
			}

			try {
				final header = testHeader(isSubmodule);
				Tsbaseline.DoJSEmitBaseline(t, this.configuredName, header, this.options, this.result, this.tsConfigFiles, this.toBeCompiled,
					this.otherFiles, this.harnessOptions, new Options(suiteName, isSubmodule));
			} catch (e:haxe.Exception) {
				Testutil.RecoverAndFail(t, "Panic on creating js output for test " + this.filename, e);
			}
		});
	}

	function verifySourceMapOutput(t:T, suiteName:String, isSubmodule:Bool):Void {
		t.Run("sourcemap", function(t:T) {
			try {
				final header = testHeader(isSubmodule);
				Tsbaseline.DoSourcemapBaseline(t, this.configuredName, header, this.options, this.result, this.harnessOptions,
					new Options(suiteName, isSubmodule));
			} catch (e:haxe.Exception) {
				Testutil.RecoverAndFail(t, "Panic on creating source map output for test " + this.filename, e);
			}
		});
	}

	function verifySourceMapRecord(t:T, suiteName:String, isSubmodule:Bool):Void {
		t.Run("sourcemap record", function(t:T) {
			try {
				final header = testHeader(isSubmodule);
				Tsbaseline.DoSourcemapRecordBaseline(t, this.configuredName, header, this.options, this.result, this.harnessOptions,
					new Options(suiteName, isSubmodule));
			} catch (e:haxe.Exception) {
				Testutil.RecoverAndFail(t, "Panic on creating source map record for test " + this.filename, e);
			}
		});
	}

	function verifyTypesAndSymbols(t:T, suiteName:String, isSubmodule:Bool):Void {
		final noTypesAndSymbols = this.harnessOptions.NoTypesAndSymbols;
		if (noTypesAndSymbols) {
			return;
		}
		final program = this.result.Program;
		final allFiles = Core.Filter(Core.Concatenate(this.toBeCompiled, this.otherFiles), function(f:TestFile):Bool {
			return program.GetSourceFile(f.UnitName) != null;
		});

		var headerComponents = Tspath.GetPathComponentsRelativeTo(Repo.TestDataPath(), this.filename, new ComparePathsOptions());
		if (isSubmodule) {
			headerComponents = headerComponents.slice(4); // Strip "./../_submodules/TypeScript" prefix
		}
		final header = Tspath.GetPathFromPathComponents(headerComponents);
		Tsbaseline.DoTypeAndSymbolBaseline(t, this.configuredName, header, program, allFiles == null ? [] : allFiles, new Options(suiteName, isSubmodule), false,
			false, Core.len(this.result.Diagnostics) > 0);
	}

	function verifyModuleResolution(t:T, suiteName:String, isSubmodule:Bool):Void {
		if (!this.options.TraceResolution.IsTrue()) {
			return;
		}

		t.Run("module resolution", function(t:T) {
			try {
				final opts = new Options(suiteName, isSubmodule);
				opts.SkipDiffWithOld = true;
				Tsbaseline.DoModuleResolutionBaseline(t, this.configuredName, this.result.Trace, opts);
			} catch (e:haxe.Exception) {
				Testutil.RecoverAndFail(t, "Panic on creating module resolution baseline for test " + this.filename, e);
			}
		});
	}

	// PORT: union ordering check: the Go version shuffles with math/rand/v2 PCG(1234, 5678); here the
	// shuffles are replaced by a deterministic reversal + rotation sequence (the check sorts and compares
	// with the union's order, so any permutation exercises it).
	function verifyUnionOrdering(t:T):Void {
		t.Run("union ordering", function(t:T) {
			final p = this.result.Program.Program();
			p.ForEachCheckerParallel(function(_:Int, c:Checker) {
				c.UnionTypes()(function(union:ts.checker.Types.Type):Bool {
					final types = union.Types();

					final reversed = Slices.Clone(types);
					Slices.Reverse(reversed);
					Slices.SortFunc(reversed, Checker.CompareTypes);
					if (!Slices.Equal(reversed, types)) {
						t.Fatal("compareTypes does not sort union types consistently");
					}

					final shuffled = Slices.Clone(types);
					for (k in 0...10) {
						if (shuffled.length > 1) {
							final first = shuffled.shift();
							shuffled.insert((k * 7 + 3) % shuffled.length, first);
						}
						Slices.SortFunc(shuffled, Checker.CompareTypes);
						if (!Slices.Equal(shuffled, types)) {
							t.Fatal("compareTypes does not sort union types consistently");
						}
					}
					return true;
				});
			});
		});
	}

	function verifyParentPointers(t:T):Void {
		t.Run("source file parent pointers", function(t:T) {
			var parent:Node = null;
			var verifier:(n:Node) -> Bool = null;
			verifier = function(n:Node):Bool {
				if (n == null) {
					return false;
				}
				if (n.Parent == null)
					t.Fatal("parent node does not exist");
				var elab = "";
				if (!Ast.NodeIsSynthesized(n)) {
					elab += Ast.GetSourceFileOfNode(n).Text().substring(n.Loc.Pos(), n.Loc.End());
				} else {
					elab += "!synthetic! no text available";
				}
				if (n.Parent != parent)
					t.Fatal("parent node does not match traversed parent: " + n.Kind.String() + ": " + elab);
				final oldParent = parent;
				parent = n;
				n.ForEachChild(verifier);
				parent = oldParent;
				return false;
			};
			for (f in this.result.Program.GetSourceFiles()) {
				if (this.result.Program.IsSourceFileDefaultLibrary(f.Path())) {
					continue;
				}
				parent = f.AsNode();
				f.AsNode().ForEachChild(verifier);
			}
		});
	}
}

@:allow(ts.testrunner)
class TestCaseContentWithConfig {
	// PORT: embedded testCaseContent → composition field.
	var testCaseContent:TestCaseContent = null;
	var configuration:TestConfiguration = null;

	public function new() {}
}
