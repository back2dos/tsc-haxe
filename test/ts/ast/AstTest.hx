package ts.ast;

import haxe.ds.ObjectMap;

// Tests of package ast:
// - ported upstream tests: positionmap_test.go (deepclone_test.go needs the parser: skipped);
// - TestFactoryGolden: replays test/ts/ast/factory.golden.txt, written by the Go reference
//   program tools/gen/ast/goref (run tools/gen/ast/goref.sh). For every NodeFactory.New* method it
//   compares Kind String(), ForEachChild order, data accessors, *Node accessors, SubtreeFacts,
//   VisitEachChild, Clone, DeepCloneNode and factory hooks with upstream.
class AstTest {
	public static function run() {
		// --- deepclone_test.go ---
		// PORT: skipped, needs parser (TestDeepCloneNodeSanityCheck parses its inputs with
		// parsetestutil.ParseTypeScript).

		// --- positionmap_test.go ---
		T.run("TestPositionMapASCII", TestPositionMapASCII);
		T.run("TestPositionMapTwoByte", TestPositionMapTwoByte);
		T.run("TestPositionMapFourByte", TestPositionMapFourByte);
		T.run("TestPositionMapMultipleNonASCII", TestPositionMapMultipleNonASCII);
		T.run("TestPositionMapLoneSurrogateSentinel", TestPositionMapLoneSurrogateSentinel);
		T.run("TestPositionMapRoundtrip", TestPositionMapRoundtrip);
		// Benchmark* functions are not ported.

		// --- golden tests against the Go reference ---
		T.run("TestFactoryGolden", TestFactoryGolden);
		T.run("TestSymbolNames", TestSymbolNames);
	}

	// PORT: Go `len(text)` is the UTF-8 byte length; Haxe strings are UTF-16.
	static function utf8Len(s:String):Int {
		var n = 0;
		var i = 0;
		while (i < s.length) {
			final r = Stringutil.DecodeJSStringRune(s, i);
			n += r < 0x80 ? 1 : (r < 0x800 ? 2 : (r < 0x10000 ? 3 : 4));
			i += Utf16.RuneLen(r);
		}
		return n;
	}

	// PORT: Go `strings.LastIndex(text, x)` is a byte offset.
	static function utf8LastIndex(s:String, sub:String):Int {
		return utf8Len(s.substring(0, s.lastIndexOf(sub)));
	}

	static function TestPositionMapASCII() {
		final text = "const x = 1;";
		final pm = Ast.ComputePositionMap(text);
		if (!pm.IsAsciiOnly()) {
			T.fail("expected ASCII-only");
			return;
		}
		for (i in 0...utf8Len(text) + 1) {
			T.eq(i, pm.UTF8ToUTF16(i));
			T.eq(i, pm.UTF16ToUTF8(i));
		}
	}

	static function TestPositionMapTwoByte() {
		// "café" — é (U+00E9) is 2 bytes UTF-8, 1 code unit UTF-16
		final text = "const café = 1;\nconst x = 2;";
		final pm = Ast.ComputePositionMap(text);
		if (pm.IsAsciiOnly()) {
			T.fail("expected non-ASCII");
			return;
		}

		// Everything before é (byte offset 9) should be identity
		for (i in 0...10) {
			T.eq(i, pm.UTF8ToUTF16(i));
		}

		// é starts at UTF-8 byte 9, UTF-16 offset 9: same
		T.eq(9, pm.UTF8ToUTF16(9));

		// After é (byte 11 in UTF-8 = code unit 10 in UTF-16), delta is 1
		// ' ' after café: UTF-8 byte 11, UTF-16 offset 10
		T.eq(10, pm.UTF8ToUTF16(11));

		// 'x' on second line: UTF-8 byte 23, UTF-16 offset 22
		final xUTF8 = utf8LastIndex(text, "x");
		T.eq(xUTF8 - 1, pm.UTF8ToUTF16(xUTF8));

		// Reverse: UTF-16 offset 22 should map to UTF-8 byte 23
		final xUTF16 = xUTF8 - 1;
		T.eq(xUTF8, pm.UTF16ToUTF8(xUTF16));
	}

	static function TestPositionMapFourByte() {
		// 🎉 (U+1F389) is 4 bytes UTF-8, 2 code units UTF-16
		final text = 'const a = "🎉";' + "\nconst b = 2;";
		final pm = Ast.ComputePositionMap(text);
		if (pm.IsAsciiOnly()) {
			T.fail("expected non-ASCII");
			return;
		}

		// 'b' on second line
		final bUTF8 = utf8LastIndex(text, "b");
		final bUTF16 = bUTF8 - 2; // delta of 2 from emoji
		T.eq(bUTF16, pm.UTF8ToUTF16(bUTF8));
		T.eq(bUTF8, pm.UTF16ToUTF8(bUTF16));
	}

	static function TestPositionMapMultipleNonASCII() {
		// Mix of 2-byte and 4-byte characters
		// "à" (U+00E0) = 2 bytes UTF-8, 1 code unit UTF-16 (delta +1)
		// "🎉" (U+1F389) = 4 bytes UTF-8, 2 code units UTF-16 (delta +2)
		final text = "à🎉x";
		final pm = Ast.ComputePositionMap(text);

		// à: UTF-8 [0,2), UTF-16 [0,1)
		// 🎉: UTF-8 [2,6), UTF-16 [1,3)
		// x: UTF-8 [6,7), UTF-16 [3,4)
		final tests = [[0, 0], [2, 1], [6, 3], [7, 4]];
		for (tt in tests) {
			T.eq(tt[1], pm.UTF8ToUTF16(tt[0]));
			T.eq(tt[0], pm.UTF16ToUTF8(tt[1]));
		}
	}

	static function TestPositionMapLoneSurrogateSentinel() {
		final text = "a" + Stringutil.EncodeJSStringRune(0xD800) + "b";
		final pm = Ast.ComputePositionMap(text);
		if (pm.IsAsciiOnly()) {
			T.fail("expected non-ASCII");
			return;
		}

		T.eq(3, pm.UTF8ToUTF16(utf8Len(text)));
		T.eq(utf8Len(text) - 1, pm.UTF16ToUTF8(2));
	}

	static function TestPositionMapRoundtrip() {
		final text = "let café = \"🎉\"; // naïve";
		final pm = Ast.ComputePositionMap(text);

		// Convert every valid UTF-16 position to UTF-8 and back
		final utf16Len = pm.UTF8ToUTF16(utf8Len(text));
		for (i in 0...utf16Len + 1) {
			final utf8Pos = pm.UTF16ToUTF8(i);
			final back = pm.UTF8ToUTF16(utf8Pos);
			T.eq(i, back);
		}
	}

	static function TestSymbolNames() {
		T.eq("__call", Ast.EscapeInternalSymbolName(Ast.InternalSymbolNameCall));
		T.eq("___x", Ast.EscapeSymbolName("__x"));
		T.eq("__class", Ast.EscapeSymbolName(Ast.InternalSymbolNameClass));
		T.eq("a__new", Ast.EscapeAllInternalSymbolNames("a" + Ast.InternalSymbolNameNew));
		T.eq("x", Ast.EscapeSymbolName("x"));
	}

	// ── Golden replay ──────────────────────────────────────────────────────────────────────

	static final NODE_FLAGS_ARG:NodeFlags = NodeFlagsOptionalChain | NodeFlagsLet;
	static final TOKEN_FLAGS_ARG:TokenFlags = TokenFlagsUnterminated | TokenFlagsScientific | TokenFlagsContainsInvalidEscape | TokenFlagsSingleQuote
		| TokenFlagsHexSpecifier;

	static final ACCESSORS = [
		"Expression", "Type", "Initializer", "Name", "TagName", "PropertyName", "PropertyNameOrName", "PostfixToken", "QuestionToken",
		"QuestionDotToken", "TypeExpression", "ClassName", "Label", "Attributes", "Children", "ModuleSpecifier", "ImportClause", "Statement", "Body",
		"ArgumentList", "TypeArgumentList", "TypeParameterList", "MemberList", "StatementList", "CommentList", "PropertyList", "ElementList",
		"IsTypeOnly", "CanHaveStatements", "ModifierFlags", "Text", "RawText", "Decorators", "ModifierNodes", "Symbol", "LocalSymbol", "Locals",
		"IsJSDoc"
	];

	static var casesRun = 0;

	static function TestFactoryGolden() {
		final golden = sys.io.File.getContent("test/ts/ast/factory.golden.txt").split("\n");
		var i = 0;
		// Kind String() for all kinds (and one beyond each end).
		var kinds = 0;
		while (i < golden.length && StringTools.startsWith(golden[i], "kind ")) {
			final parts = golden[i].split(" ");
			final k:Kind = Std.parseInt(parts[1]);
			T.eq(parts[2], k.String());
			kinds++;
			i++;
		}
		T.isTrue(kinds > 350, "kind lines");
		var mismatchedCases = 0;
		while (i < golden.length) {
			if (golden[i] == "") {
				i++;
				continue;
			}
			final header = golden[i];
			final expected = [];
			i++;
			while (i < golden.length && !StringTools.startsWith(golden[i], "case ") && golden[i] != "") {
				expected.push(golden[i]);
				i++;
			}
			final actual = [];
			try {
				replayCase(header, actual);
			} catch (e:Dynamic) {
				actual.push("exception " + Std.string(e));
			}
			casesRun++;
			var ok = true;
			for (j in 0...(expected.length > actual.length ? expected.length : actual.length)) {
				final e = j < expected.length ? expected[j] : "<missing>";
				final a = j < actual.length ? actual[j] : "<missing>";
				T.checks++;
				if (e != a) {
					if (ok)
						T.fail('$header\n  expected: $e\n  actual:   $a');
					ok = false;
				}
			}
			if (!ok)
				mismatchedCases++;
		}
		T.isTrue(casesRun > 200, "cases run: " + casesRun);
		T.eq(0, mismatchedCases);
	}

	static function replayCase(header:String, out:Array<String>) {
		final h = header.split(" ");
		final name = h[1];
		final types = h[2] == "" ? [] : h[2].split(",");
		final kind:Kind = Std.parseInt(h[3]);
		final boolValue = h[4] == "1";

		final childFactory = Ast.NewNodeFactory(new NodeFactoryHooks());
		var creates = 0, updates = 0, clones = 0;
		final hooks = new NodeFactoryHooks();
		hooks.OnCreate = function(node:Node) creates++;
		hooks.OnUpdate = function(node:Node, original:Node) updates++;
		hooks.OnClone = function(node:Node, original:Node) clones++;
		final f = Ast.NewNodeFactory(hooks);

		final lb = new ObjectMap<Node, String>();
		var counter = 0;
		function newChild(label:String):Node {
			counter++;
			final c = childFactory.NewIdentifier("c" + counter);
			lb.set(c, label);
			return c;
		}
		final args:Array<Dynamic> = [];
		for (i in 0...types.length) {
			final p = "p" + i;
			switch (types[i]) {
				case "*ast.Node":
					args.push(newChild(p));
				case "*ast.NodeList":
					final a = newChild(p + ".0");
					final b = newChild(p + ".1");
					args.push(childFactory.NewNodeList([a, b]));
				case "*ast.ModifierList":
					final m0 = childFactory.NewToken(KindExportKeyword);
					final m1 = childFactory.NewToken(KindAsyncKeyword);
					lb.set(m0, p + ".0");
					lb.set(m1, p + ".1");
					args.push(childFactory.NewModifierList([m0, m1]));
				case "[]*ast.Node":
					final a = newChild(p + ".0");
					final b = newChild(p + ".1");
					args.push(([a, b] : Array<Node>));
				case "[]string":
					args.push([p + "a", p + "b"]);
				case "string":
					args.push("s" + p);
				case "bool":
					args.push(boolValue);
				case "int":
					args.push(7);
				case "ast.Kind":
					args.push((kind : Int));
				case "ast.NodeFlags":
					args.push((NODE_FLAGS_ARG : Int));
				case "ast.TokenFlags":
					args.push((TOKEN_FLAGS_ARG : Int));
				case "any":
					args.push(null);
				default:
					throw "unhandled param type " + types[i];
			}
		}
		final node:Node = Reflect.callMethod(f, Reflect.field(f, name), args);

		function label(n:Node, m:ObjectMap<Node, String>):String {
			if (n == null)
				return "nil";
			final s = m.get(n);
			return s != null ? s : "?" + n.Kind.String();
		}
		function listLabel(l:NodeList):String {
			if (l == null)
				return "nil";
			for (i in 0...args.length) {
				if (Std.isOfType(args[i], NodeList) && (args[i] : NodeList) == l)
					return "p" + i;
			}
			return "?list";
		}
		function forEachChild(n:Node, m:ObjectMap<Node, String>):String {
			final parts = [];
			n.ForEachChild(function(c:Node):Bool {
				parts.push(label(c, m));
				return false;
			});
			return parts.length == 0 ? "-" : parts.join(" ");
		}

		out.push('kind ${node.Kind.String()} flags ${(node.Flags : Int)}');
		out.push('fec ${forEachChild(node, lb)}');
		out.push('data ${dataAccessors(node)}');
		out.push('modifiers ${node.Modifiers() == null ? "nil" : listLabel(node.Modifiers())}');
		for (acc in ACCESSORS)
			out.push('acc $acc ${callAccessor(node, acc, n -> label(n, lb), listLabel)}');
		if (node.FunctionLikeData() != null)
			out.push('params ${listLabel(node.ParameterList())}');

		out.push('facts ${(node.SubtreeFacts() : Int)}');
		final wrapper = childFactory.NewExpressionStatement(node);
		out.push('pfacts ${(wrapper.SubtreeFacts() : Int)}');

		// VisitEachChild with the identity visitor: no update.
		final same = Ast.NewNodeVisitor(n -> n, f, new NodeVisitorHooks()).VisitEachChild(node);
		out.push('vec-same ${same == node}');

		// VisitEachChild with a changing visitor: every child is replaced by a new identifier.
		final rl = new ObjectMap<Node, String>();
		for (k in lb.keys())
			rl.set(k, lb.get(k));
		final changed = Ast.NewNodeVisitor(function(n:Node):Node {
			final r = childFactory.NewIdentifier("r");
			rl.set(r, "r" + label(n, lb));
			return r;
		}, f, new NodeVisitorHooks()).VisitEachChild(node);
		out.push('vec-changed ${changed == node} ${changed.Kind.String()} fec ${forEachChild(changed, rl)}');

		// Clone
		node.Loc = Core.NewTextRange(3, 9);
		node.Flags |= NodeFlagsAmbient;
		final clone = node.Clone(f);
		if (clone == null) {
			out.push("clone nil");
		} else {
			out.push('clone ${clone == node} ${clone.Kind.String()} ${clone.Pos()} ${clone.End()} ${(clone.Flags : Int)} fec ${forEachChild(clone, lb)}');
		}

		// DeepCloneNode: preorder kinds and locations of the copy.
		var deep = "";
		try {
			final d = f.DeepCloneNode(node);
			final b = new StringBuf();
			var walk:(n:Node) -> Bool = null;
			walk = function(n:Node):Bool {
				b.add(' ${n.Kind.String()}@${n.Pos()},${n.End()}');
				if (lb.exists(n))
					b.add("!shared");
				n.ForEachChild(walk);
				return false;
			};
			walk(d);
			deep = b.toString();
		} catch (e:Dynamic) {
			deep = " panic";
		}
		out.push('deep$deep');

		out.push('hooks $creates $updates $clones');
	}

	static function b2s(b:Bool):String
		return b ? "1" : "0";

	static function dataAccessors(n:Node):String {
		return b2s(n.FlowNodeData() != null) + b2s(n.DeclarationData() != null) + b2s(n.ExportableData() != null) + b2s(n.LocalsContainerData() != null)
			+ b2s(n.FunctionLikeData() != null) + b2s(n.ClassLikeData() != null) + b2s(n.BodyData() != null) + b2s(n.LiteralLikeData() != null)
			+ b2s(n.TemplateLiteralLikeData() != null);
	}

	static function callAccessor(n:Node, name:String, lb:(Node) -> String, listLabel:(NodeList) -> String):String {
		try {
			return switch (name) {
				case "Expression": lb(n.Expression());
				case "Type": lb(n.Type());
				case "Initializer": lb(n.Initializer());
				case "Name": lb(n.Name());
				case "TagName": lb(n.TagName());
				case "PropertyName": lb(n.PropertyName());
				case "PropertyNameOrName": lb(n.PropertyNameOrName());
				case "PostfixToken": lb(n.PostfixToken());
				case "QuestionToken": lb(n.QuestionToken());
				case "QuestionDotToken": lb(n.QuestionDotToken());
				case "TypeExpression": lb(n.TypeExpression());
				case "ClassName": lb(n.ClassName());
				case "Label": lb(n.Label());
				case "Attributes": lb(n.Attributes());
				case "Children": listLabel(n.Children());
				case "ModuleSpecifier": lb(n.ModuleSpecifier());
				case "ImportClause": lb(n.ImportClause());
				case "Statement": lb(n.Statement());
				case "Body": lb(n.Body());
				case "ArgumentList": listLabel(n.ArgumentList());
				case "TypeArgumentList": listLabel(n.TypeArgumentList());
				case "TypeParameterList": listLabel(n.TypeParameterList());
				case "MemberList": listLabel(n.MemberList());
				case "StatementList": listLabel(n.StatementList());
				case "CommentList": listLabel(n.CommentList());
				case "PropertyList": listLabel(n.PropertyList());
				case "ElementList": listLabel(n.ElementList());
				case "IsTypeOnly": Std.string(n.IsTypeOnly());
				case "CanHaveStatements": Std.string(n.CanHaveStatements());
				case "ModifierFlags": Std.string((n.ModifierFlags() : Int));
				case "Text": '"${n.Text()}"';
				case "RawText": '"${n.RawText()}"';
				case "Decorators":
					final d = n.Decorators();
					d == null ? "nil" : Std.string(d.length);
				case "ModifierNodes":
					final m = n.ModifierNodes();
					m == null ? "nil" : [for (x in m) lb(x)].join(",");
				case "Symbol": Std.string(n.Symbol() == null);
				case "LocalSymbol": Std.string(n.LocalSymbol() == null);
				case "Locals": Std.string(n.Locals() == null);
				case "IsJSDoc": Std.string(n.IsJSDoc());
				default: throw "unknown accessor " + name;
			}
		} catch (e:Dynamic) {
			return "panic";
		}
	}
}
