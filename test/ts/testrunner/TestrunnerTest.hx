package ts.testrunner;

// Port of test_case_parser_test.go and compiler_runner_test.go.
// PORT: TestLocal / TestSubmodule (the compiler baseline runs) are the checker gate
// (tools/gate/checker.sh, test/ts/harness/CheckerGate.hx), not unit tests.
class TestrunnerTest {
	public static function run() {
		T.run("TestMakeUnitsFromTest", () -> {
			final code = '// @strict: true
// @noEmit: true
// @filename: firstFile.ts
function foo() { return "a"; }
// normal comment
// @filename: secondFile.ts
// some other comment
function bar() { return "b"; }';
			final testUnit1 = new TestUnit('function foo() { return "a"; }
// normal comment', "firstFile.ts");
			final testUnit2 = new TestUnit('// some other comment
function bar() { return "b"; }', "secondFile.ts");
			final actual = @:privateAccess Testrunner.makeUnitsFromTest(code, "simpleTest.ts");
			@:privateAccess {
				T.eq(2, actual.testUnitData.length);
				T.eq(testUnit1.content, actual.testUnitData[0].content);
				T.eq(testUnit1.name, actual.testUnitData[0].name);
				T.eq(testUnit2.content, actual.testUnitData[1].content);
				T.eq(testUnit2.name, actual.testUnitData[1].name);
				T.eq(null, actual.tsConfig);
				T.eq(null, actual.tsConfigFileUnitData);
				T.isTrue(actual.symlinks != null && !actual.symlinks.keys().hasNext());
			}
		});
	}
}
