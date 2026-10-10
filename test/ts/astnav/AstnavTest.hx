package ts.astnav;

// Port of tokens_test.go.
// PORT: repo.TypeScriptSubmodulePath() → T.UPSTREAM + "/_submodules/TypeScript"; baseline.Run
// compares against upstream testdata/baselines/reference/astnav (exact text compare, as Go).
class AstnavTest {
	static final testFiles = [T.UPSTREAM + "/_submodules/TypeScript/src/services/mapCode.ts"];

	public static function run() {
		T.run("TestGetTokenAtPosition", TestGetTokenAtPosition);
		T.run("TestGetTouchingPropertyName", TestGetTouchingPropertyName);
		T.run("TestFindPrecedingToken", TestFindPrecedingToken);
		T.run("TestFindNextToken", TestFindNextToken);
		T.run("TestUnitFindPrecedingToken", TestUnitFindPrecedingToken);
	}

	static function parse(fileName:String, text:String, scriptKind:ScriptKind):SourceFile {
		final opts = new SourceFileParseOptions();
		opts.FileName = fileName;
		opts.Path = fileName;
		return Parser.ParseSourceFile(opts, text, scriptKind);
	}

	static function TestGetTokenAtPosition() {
		// PORT: skipped, needs node_modules/typescript (TS 6 JS, jstest.EvalNodeScriptWithTS): subtest
		// "baseline" (baselineTokens with tsGetTokensAtPositions). upstream/ has no installed
		// typescript package, so the TS side of the GetTokenAtPosition.*.baseline.txt diff cannot be produced.

		T.run("TestGetTokenAtPosition/go baseline json", function() {
			baselineGoTokensJSON("GetTokenAtPosition", function(file:SourceFile, pos:Int):TokenInfo {
				return toTokenInfo(Astnav.GetTokenAtPosition(file, pos));
			});
		});

		T.run("TestGetTokenAtPosition/JSDoc type assertion", function() {
			final fileText = "function foo(x) {
    const s = /**@type {string}*/(x)
}";
			final file = parse("/test.js", fileText, ScriptKindJS);

			// Position of 'x' inside the parenthesized expression (position 52)
			final position = 52;

			// This should not panic - it previously panicked with:
			// "did not expect KindParenthesizedExpression to have KindIdentifier in its trivia"
			final token = Astnav.GetTouchingPropertyName(file, position);
			if (token == null) {
				T.fail("Expected to get a token, got nil");
				return;
			}

			// The function may return either the identifier itself or the containing
			// parenthesized expression, depending on how the AST is structured
			T.isTrue(token.Kind == KindIdentifier || token.Kind == KindParenthesizedExpression,
				'Expected identifier or parenthesized expression, got ${token.Kind.String()}');
		});

		T.run("TestGetTokenAtPosition/JSDoc type assertion with comment", function() {
			// Exact code from the issue report
			final fileText = "function foo(x) {
    const s = /**@type {string}*/(x)  // Go-to-definition on x causes panic
}";
			final file = parse("/test.js", fileText, ScriptKindJS);

			// Find position of 'x' in the type assertion
			final xPos = 52; // Position of 'x' in (x)

			// This should not panic
			final token = Astnav.GetTouchingPropertyName(file, xPos);
			T.isTrue(token != null, "Expected to get a token");
		});

		T.run("TestGetTokenAtPosition/pointer equality", function() {
			final fileText = "
			function foo() {
				return 0;
			}
		";
			final file = parse("/file.ts", fileText, ScriptKindTS);
			T.isTrue(Astnav.GetTokenAtPosition(file, 0) == Astnav.GetTokenAtPosition(file, 0));
		});
	}

	static function TestGetTouchingPropertyName() {
		// PORT: skipped, needs node_modules/typescript (TS 6 JS): baselineTokens with
		// tsGetTouchingPropertyName (GetTouchingPropertyName.*.baseline.txt).

		T.run("TestGetTouchingPropertyName/go baseline json", function() {
			baselineGoTokensJSON("GetTouchingPropertyName", function(file:SourceFile, pos:Int):TokenInfo {
				return toTokenInfo(Astnav.GetTouchingPropertyName(file, pos));
			});
		});
	}

	// PORT: baselineTokens, tsGetTokensAtPositions, tsGetTouchingPropertyName, tsFindPrecedingTokens,
	// writeRangeDiff, tokenDiff, diffEqual: not ported (only used by the skipped TS-comparison subtests).

	static function baselineGoTokensJSON(testName:String, getGoToken:(file:SourceFile, pos:Int) -> TokenInfo) {
		for (fileName in testFiles) {
			final fileText = sys.io.File.getContent(fileName);

			final file = parse("/file.ts", fileText, ScriptKindTS);

			final maxPos = fileText.length;
			var runs:Array<TokenRun> = null;
			var current:TokenRun = null;

			for (pos in 0...maxPos) {
				final token = getGoToken(file, pos);
				if (current != null && token != null && current.Kind == token.Kind && current.NodePos == token.Pos && current.NodeEnd == token.End) {
					current.EndPos = pos;
				} else {
					if (current != null) {
						if (runs == null)
							runs = [];
						runs.push(current);
					}
					if (token != null) {
						current = new TokenRun(pos, pos, token.Kind, token.Pos, token.End);
					} else {
						current = null;
					}
				}
			}
			if (current != null) {
				if (runs == null)
					runs = [];
				runs.push(current);
			}

			final output = stringifyRuns(runs);

			final baseName = fileName.substring(fileName.lastIndexOf("/") + 1);
			final reference = T.UPSTREAM + '/testdata/baselines/reference/astnav/$testName.$baseName.baseline.json';
			final expected = sys.FileSystem.exists(reference) ? sys.io.File.getContent(reference) : "<no content>";
			if (expected != output) {
				T.fail('baseline $testName.$baseName.baseline.json differs (got ${output.length} chars, expected ${expected.length})');
			} else {
				T.checks++;
			}
		}
	}

	// PORT: core.StringifyJson(runs, "", "  ") (go-json-experiment, indented) written by hand:
	// ts.json.Json has no Go-compatible ordered marshaller (PORTING.md §7).
	static function stringifyRuns(runs:Array<TokenRun>):String {
		if (runs == null)
			return "null";
		if (runs.length == 0)
			return "[]";
		final sb = new StringBuf();
		sb.add("[\n");
		for (i in 0...runs.length) {
			final r = runs[i];
			sb.add("  {\n");
			sb.add('    "startPos": ${r.StartPos},\n');
			sb.add('    "endPos": ${r.EndPos},\n');
			sb.add('    "kind": "${r.Kind}",\n');
			sb.add('    "nodePos": ${r.NodePos},\n');
			sb.add('    "nodeEnd": ${r.NodeEnd}\n');
			sb.add(i < runs.length - 1 ? "  },\n" : "  }\n");
		}
		sb.add("]");
		return sb.toString();
	}

	static function toTokenInfo(node:Node):TokenInfo {
		if (node == null) {
			return null;
		}
		var kind = node.Kind.String();
		final idx = kind.indexOf("Kind");
		if (idx >= 0) {
			kind = kind.substring(0, idx) + kind.substring(idx + 4);
		}
		if (kind == "EndOfFile") {
			kind = "EndOfFileToken";
		}
		return new TokenInfo(kind, node.Pos(), node.End());
	}

	static function TestFindPrecedingToken() {
		// PORT: skipped, needs node_modules/typescript (TS 6 JS): subtest "baseline" (baselineTokens with
		// tsFindPrecedingTokens, FindPrecedingToken.*.baseline.txt).

		T.run("TestFindPrecedingToken/go baseline json", function() {
			baselineGoTokensJSON("FindPrecedingToken", function(file:SourceFile, pos:Int):TokenInfo {
				return toTokenInfo(Astnav.FindPrecedingToken(file, pos));
			});
		});
	}

	static function TestFindNextToken() {
		T.run("TestFindNextToken/go baseline json", function() {
			baselineGoTokensJSON("FindNextToken", function(file:SourceFile, pos:Int):TokenInfo {
				// FindNextToken panics (like Go's assert) when the scanner finds trivia between
				// previousToken.End() and the next syntactic token. Catch those to avoid crashing
				// the baseline generator; those positions will be absent from the baseline.
				try {
					final token = Astnav.GetTokenAtPosition(file, pos);
					final next = Astnav.FindNextToken(token, file.AsNode(), file);
					return toTokenInfo(next);
				} catch (e:Dynamic) {
					return null;
				}
			});
		});
	}

	static function TestUnitFindPrecedingToken() {
		final testCases:Array<{name:String, fileContent:String, position:Int, expectedKind:Kind}> = [
			{
				name: "after dot in jsdoc",
				fileContent: 'import {
    CharacterCodes,
    compareStringsCaseInsensitive,
    compareStringsCaseSensitive,
    compareValues,
    Comparison,
    Debug,
    endsWith,
    equateStringsCaseInsensitive,
    equateStringsCaseSensitive,
    GetCanonicalFileName,
    getDeclarationFileExtension,
    getStringComparer,
    identity,
    lastOrUndefined,
    Path,
    some,
    startsWith,
} from "./_namespaces/ts.js";

/**
 * Internally, we represent paths as strings with \'/\' as the directory separator.
 * When we make system calls (eg: LanguageServiceHost.getDirectory()),
 * we expect the host to correctly handle paths in our specified format.
 *
 * @internal
 */
export const directorySeparator = "/";
/** @internal */
export const altDirectorySeparator = "\\\\";
const urlSchemeSeparator = "://";
const backslashRegExp = /\\\\/g;


backslashRegExp.

//Path Tests

/**
 * Determines whether a charCode corresponds to \'/\' or \'\\\'.
 *
 * @internal
 */
export function isAnyDirectorySeparator(charCode: number): boolean {
    return charCode === CharacterCodes.slash || charCode === CharacterCodes.backslash;
}',
				position: 839,
				expectedKind: KindDotToken,
			},
			{
				name: "after comma in parameter list",
				fileContent: "takesCb((n, s, ))",
				position: 15,
				expectedKind: KindCommaToken,
			},
		];
		for (testCase in testCases) {
			T.run("TestUnitFindPrecedingToken/" + testCase.name, function() {
				final file = parse("/file.ts", testCase.fileContent, ScriptKindTS);
				final token = Astnav.FindPrecedingToken(file, testCase.position);
				T.eq(testCase.expectedKind, token.Kind);
			});
		}
	}
}

class TokenRun {
	public var StartPos:Int = 0;
	public var EndPos:Int = 0;
	public var Kind:std.String = "";
	public var NodePos:Int = 0;
	public var NodeEnd:Int = 0;

	public function new(startPos:Int, endPos:Int, kind:std.String, nodePos:Int, nodeEnd:Int) {
		StartPos = startPos;
		EndPos = endPos;
		Kind = kind;
		NodePos = nodePos;
		NodeEnd = nodeEnd;
	}
}

class TokenInfo {
	public var Kind:std.String = "";
	public var Pos:Int = 0;
	public var End:Int = 0;

	public function new(kind:std.String, pos:Int, end:Int) {
		Kind = kind;
		Pos = pos;
		End = end;
	}
}
