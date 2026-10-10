package ts.printer;

// Port of internal/printer/printer_test.go (package printer_test).
// Go subtests (t.Run) are nested T.run calls named "<Test>/<subtest>".

// Row of the TestEmit data table.
class EmitRow {
	public final title:std.String;
	public final input:std.String;
	public final output:std.String;
	public final jsx:Bool;

	public function new(title:std.String, input:std.String, output:std.String, jsx:Bool) {
		this.title = title;
		this.input = input;
		this.output = output;
		this.jsx = jsx;
	}
}

// Row of the TestParenthesizeBinary data table (Go zero Kind = KindUnknown).
class BinaryRow {
	public final left:Kind;
	public final operator_:Kind;
	public final right:Kind;
	public final output:std.String;

	public function new(left:Kind, operator_:Kind, right:Kind, output:std.String) {
		this.left = left;
		this.operator_ = operator_;
		this.right = right;
		this.output = output;
	}
}

// Row of the TestParenthesizeBinaryExpressionMixingNullishCoalescing data table.
class MixingRow {
	public final title:std.String;
	public final innerOp:Kind;
	public final outerOp:Kind;
	public final side:std.String;
	public final output:std.String;

	public function new(title:std.String, innerOp:Kind, outerOp:Kind, side:std.String, output:std.String) {
		this.title = title;
		this.innerOp = innerOp;
		this.outerOp = outerOp;
		this.side = side;
		this.output = output;
	}
}

class PrinterTest {
	public static function run() {
		T.run("TestEmit", TestEmit);
		T.run("TestParenthesizeDecorator", TestParenthesizeDecorator);
		T.run("TestParenthesizeComputedPropertyName", TestParenthesizeComputedPropertyName);
		T.run("TestParenthesizeArrayLiteral", TestParenthesizeArrayLiteral);
		T.run("TestParenthesizePropertyAccess1", TestParenthesizePropertyAccess1);
		T.run("TestParenthesizePropertyAccess2", TestParenthesizePropertyAccess2);
		T.run("TestParenthesizePropertyAccess3", TestParenthesizePropertyAccess3);
		T.run("TestParenthesizeElementAccess1", TestParenthesizeElementAccess1);
		T.run("TestParenthesizeElementAccess2", TestParenthesizeElementAccess2);
		T.run("TestParenthesizeElementAccess3", TestParenthesizeElementAccess3);
		T.run("TestParenthesizeCall1", TestParenthesizeCall1);
		T.run("TestParenthesizeCall2", TestParenthesizeCall2);
		T.run("TestParenthesizeCall3", TestParenthesizeCall3);
		T.run("TestParenthesizeCall4", TestParenthesizeCall4);
		T.run("TestParenthesizeNew1", TestParenthesizeNew1);
		T.run("TestParenthesizeNew2", TestParenthesizeNew2);
		T.run("TestParenthesizeNew3", TestParenthesizeNew3);
		T.run("TestParenthesizeTaggedTemplate1", TestParenthesizeTaggedTemplate1);
		T.run("TestParenthesizeTaggedTemplate2", TestParenthesizeTaggedTemplate2);
		T.run("TestParenthesizeTypeAssertion1", TestParenthesizeTypeAssertion1);
		T.run("TestParenthesizeArrowFunction1", TestParenthesizeArrowFunction1);
		T.run("TestParenthesizeArrowFunction2", TestParenthesizeArrowFunction2);
		T.run("TestParenthesizeDelete", TestParenthesizeDelete);
		T.run("TestParenthesizeVoid", TestParenthesizeVoid);
		T.run("TestParenthesizeTypeOf", TestParenthesizeTypeOf);
		T.run("TestParenthesizeAwait", TestParenthesizeAwait);
		T.run("TestParenthesizeBinary", TestParenthesizeBinary);
		T.run("TestParenthesizeConditional1", TestParenthesizeConditional1);
		T.run("TestParenthesizeConditional2", TestParenthesizeConditional2);
		T.run("TestParenthesizeConditional3", TestParenthesizeConditional3);
		T.run("TestParenthesizeConditional4", TestParenthesizeConditional4);
		T.run("TestParenthesizeConditional5", TestParenthesizeConditional5);
		T.run("TestParenthesizeConditional6", TestParenthesizeConditional6);
		T.run("TestParenthesizeYield1", TestParenthesizeYield1);
		T.run("TestParenthesizeSpreadElement1", TestParenthesizeSpreadElement1);
		T.run("TestParenthesizeSpreadElement2", TestParenthesizeSpreadElement2);
		T.run("TestParenthesizeSpreadElement3", TestParenthesizeSpreadElement3);
		T.run("TestParenthesizeExpressionWithTypeArguments", TestParenthesizeExpressionWithTypeArguments);
		T.run("TestParenthesizeAsExpression", TestParenthesizeAsExpression);
		T.run("TestParenthesizeSatisfiesExpression", TestParenthesizeSatisfiesExpression);
		T.run("TestParenthesizeNonNullExpression", TestParenthesizeNonNullExpression);
		T.run("TestParenthesizeExpressionStatement1", TestParenthesizeExpressionStatement1);
		T.run("TestParenthesizeExpressionStatement2", TestParenthesizeExpressionStatement2);
		T.run("TestParenthesizeExpressionStatement3", TestParenthesizeExpressionStatement3);
		T.run("TestParenthesizeExpressionDefault1", TestParenthesizeExpressionDefault1);
		T.run("TestParenthesizeExpressionDefault2", TestParenthesizeExpressionDefault2);
		T.run("TestParenthesizeExpressionDefault3", TestParenthesizeExpressionDefault3);
		T.run("TestParenthesizeArrayType", TestParenthesizeArrayType);
		T.run("TestParenthesizeOptionalType", TestParenthesizeOptionalType);
		T.run("TestParenthesizeUnionType1", TestParenthesizeUnionType1);
		T.run("TestParenthesizeUnionType2", TestParenthesizeUnionType2);
		T.run("TestParenthesizeIntersectionType", TestParenthesizeIntersectionType);
		T.run("TestParenthesizeReadonlyTypeOperator1", TestParenthesizeReadonlyTypeOperator1);
		T.run("TestParenthesizeReadonlyTypeOperator2", TestParenthesizeReadonlyTypeOperator2);
		T.run("TestParenthesizeKeyofTypeOperator", TestParenthesizeKeyofTypeOperator);
		T.run("TestParenthesizeIndexedAccessType", TestParenthesizeIndexedAccessType);
		T.run("TestParenthesizeConditionalType1", TestParenthesizeConditionalType1);
		T.run("TestParenthesizeConditionalType2", TestParenthesizeConditionalType2);
		T.run("TestParenthesizeConditionalType3", TestParenthesizeConditionalType3);
		T.run("TestParenthesizeConditionalType4", TestParenthesizeConditionalType4);
		T.run("TestNameGeneration", TestNameGeneration);
		T.run("TestNoTrailingCommaAfterTransform", TestNoTrailingCommaAfterTransform);
		T.run("TestTrailingCommaAfterTransform", TestTrailingCommaAfterTransform);
		// PORT: skipped, needs transformers (tstransforms.NewTypeEraserTransformer): TestPartiallyEmittedExpression
		T.run("TestParenthesizeBinaryExpressionMixingNullishCoalescing", TestParenthesizeBinaryExpressionMixingNullishCoalescing);
	}

	// Go `ast.SourceFileParseOptions{FileName: "/file.ts", Path: "/file.ts"}`.
	static function fileOpts():SourceFileParseOptions {
		final opts = new SourceFileParseOptions();
		opts.FileName = "/file.ts";
		opts.Path = "/file.ts";
		return opts;
	}

	static function TestEmit():Void {
		final data:Array<EmitRow> = [
			new EmitRow("StringLiteral#1", ";\"test\"", ";\n\"test\";", false),
			new EmitRow("StringLiteral#2", ";'test'", ";\n'test';", false),
			new EmitRow("NumericLiteral#1", "0", "0;", false),
			new EmitRow("NumericLiteral#2", "10_000", "10000;", false),
			new EmitRow("BigIntLiteral#1", "0n", "0n;", false),
			new EmitRow("BigIntLiteral#2", "10_000n", "10000n;", false), // TODO: Preserve numeric literal separators after Strada migration
			new EmitRow("BooleanLiteral#1", "true", "true;", false),
			new EmitRow("BooleanLiteral#2", "false", "false;", false),
			new EmitRow("NoSubstitutionTemplateLiteral", "``", "``;", false),
			new EmitRow("NoSubstitutionTemplateLiteral#2", "`\n`", "`\n`;", false),

			new EmitRow("RegularExpressionLiteral#1", "/a/", "/a/;", false),
			new EmitRow("RegularExpressionLiteral#2", "/a/g", "/a/g;", false),
			new EmitRow("NullLiteral", "null", "null;", false),
			new EmitRow("ThisExpression", "this", "this;", false),
			new EmitRow("SuperExpression", "super()", "super();", false),
			new EmitRow("ImportExpression", "import()", "import();", false),
			new EmitRow("PropertyAccess#1", "a.b", "a.b;", false),
			new EmitRow("PropertyAccess#2", "a.#b", "a.#b;", false),
			new EmitRow("PropertyAccess#3", "a?.b", "a?.b;", false),
			new EmitRow("PropertyAccess#4", "a?.b.c", "a?.b.c;", false),
			new EmitRow("PropertyAccess#5", "1..b", "1..b;", false),
			new EmitRow("PropertyAccess#6", "1.0.b", "1.0.b;", false),
			new EmitRow("PropertyAccess#7", "0x1.b", "0x1.b;", false),
			new EmitRow("PropertyAccess#8", "0b1.b", "0b1.b;", false),
			new EmitRow("PropertyAccess#9", "0o1.b", "0o1.b;", false),
			new EmitRow("PropertyAccess#10", "10e1.b", "10e1.b;", false),
			new EmitRow("PropertyAccess#11", "10E1.b", "10E1.b;", false),
			new EmitRow("PropertyAccess#12", "a.b?.c", "a.b?.c;", false),
			new EmitRow("PropertyAccess#13", "a\n.b", "a\n    .b;", false),
			new EmitRow("PropertyAccess#14", "a.\nb", "a.\n    b;", false),
			new EmitRow("ElementAccess#1", "a[b]", "a[b];", false),
			new EmitRow("ElementAccess#2", "a?.[b]", "a?.[b];", false),
			new EmitRow("ElementAccess#3", "a?.[b].c", "a?.[b].c;", false),
			new EmitRow("CallExpression#1", "a()", "a();", false),
			new EmitRow("CallExpression#2", "a<T>()", "a<T>();", false),
			new EmitRow("CallExpression#3", "a(b)", "a(b);", false),
			new EmitRow("CallExpression#4", "a<T>(b)", "a<T>(b);", false),
			new EmitRow("CallExpression#5", "a(b).c", "a(b).c;", false),
			new EmitRow("CallExpression#6", "a<T>(b).c", "a<T>(b).c;", false),
			new EmitRow("CallExpression#7", "a?.(b)", "a?.(b);", false),
			new EmitRow("CallExpression#8", "a?.<T>(b)", "a?.<T>(b);", false),
			new EmitRow("CallExpression#9", "a?.(b).c", "a?.(b).c;", false),
			new EmitRow("CallExpression#10", "a?.<T>(b).c", "a?.<T>(b).c;", false),
			new EmitRow("CallExpression#11", "a<T, U>()", "a<T, U>();", false),
			// new EmitRow("CallExpression#12", "a<T,>()", "a<T,>();", false), // TODO: preserve trailing comma after Strada migration
			new EmitRow("CallExpression#13", "a?.b()", "a?.b();", false),
			new EmitRow("NewExpression#1", "new a", "new a;", false),
			new EmitRow("NewExpression#2", "new a.b", "new a.b;", false),
			new EmitRow("NewExpression#3", "new a()", "new a();", false),
			new EmitRow("NewExpression#4", "new a.b()", "new a.b();", false),
			new EmitRow("NewExpression#5", "new a<T>()", "new a<T>();", false),
			new EmitRow("NewExpression#6", "new a.b<T>()", "new a.b<T>();", false),
			new EmitRow("NewExpression#7", "new a(b)", "new a(b);", false),
			new EmitRow("NewExpression#8", "new a.b(c)", "new a.b(c);", false),
			new EmitRow("NewExpression#9", "new a<T>(b)", "new a<T>(b);", false),
			new EmitRow("NewExpression#10", "new a.b<T>(c)", "new a.b<T>(c);", false),
			new EmitRow("NewExpression#11", "new a(b).c", "new a(b).c;", false),
			new EmitRow("NewExpression#12", "new a<T>(b).c", "new a<T>(b).c;", false),
			new EmitRow("TaggedTemplateExpression#1", "tag``", "tag ``;", false),
			new EmitRow("TaggedTemplateExpression#2", "tag<T>``", "tag<T> ``;", false),
			new EmitRow("TypeAssertionExpression#1", "<T>a", "<T>a;", false),
			new EmitRow("FunctionExpression#1", "(function(){})", "(function () { });", false),
			new EmitRow("FunctionExpression#2", "(function f(){})", "(function f() { });", false),
			new EmitRow("FunctionExpression#3", "(function*f(){})", "(function* f() { });", false),
			new EmitRow("FunctionExpression#4", "(async function f(){})", "(async function f() { });", false),
			new EmitRow("FunctionExpression#5", "(async function*f(){})", "(async function* f() { });", false),
			new EmitRow("FunctionExpression#6", "(function<T>(){})", "(function <T>() { });", false),
			new EmitRow("FunctionExpression#7", "(function(a){})", "(function (a) { });", false),
			new EmitRow("FunctionExpression#8", "(function():T{})", "(function (): T { });", false),
			new EmitRow("ArrowFunction#1", "a=>{}", "a => { };", false),
			new EmitRow("ArrowFunction#2", "()=>{}", "() => { };", false),
			new EmitRow("ArrowFunction#3", "(a)=>{}", "(a) => { };", false),
			new EmitRow("ArrowFunction#4", "<T>(a)=>{}", "<T>(a) => { };", false),
			new EmitRow("ArrowFunction#5", "async a=>{}", "async (a) => { };", false),
			new EmitRow("ArrowFunction#6", "async()=>{}", "async () => { };", false),
			new EmitRow("ArrowFunction#7", "async<T>()=>{}", "async <T>() => { };", false),
			new EmitRow("ArrowFunction#8", "():T=>{}", "(): T => { };", false),
			new EmitRow("ArrowFunction#9", "()=>a", "() => a;", false),
			new EmitRow("DeleteExpression", "delete a", "delete a;", false),
			new EmitRow("TypeOfExpression", "typeof a", "typeof a;", false),
			new EmitRow("VoidExpression", "void a", "void a;", false),
			new EmitRow("AwaitExpression", "await a", "await a;", false),
			new EmitRow("PrefixUnaryExpression#1", "+a", "+a;", false),
			new EmitRow("PrefixUnaryExpression#2", "++a", "++a;", false),
			new EmitRow("PrefixUnaryExpression#3", "+ +a", "+ +a;", false),
			new EmitRow("PrefixUnaryExpression#4", "+ ++a", "+ ++a;", false),
			new EmitRow("PrefixUnaryExpression#5", "-a", "-a;", false),
			new EmitRow("PrefixUnaryExpression#6", "--a", "--a;", false),
			new EmitRow("PrefixUnaryExpression#7", "- -a", "- -a;", false),
			new EmitRow("PrefixUnaryExpression#8", "- --a", "- --a;", false),
			new EmitRow("PrefixUnaryExpression#9", "+-a", "+-a;", false),
			new EmitRow("PrefixUnaryExpression#10", "+--a", "+--a;", false),
			new EmitRow("PrefixUnaryExpression#11", "-+a", "-+a;", false),
			new EmitRow("PrefixUnaryExpression#12", "-++a", "-++a;", false),
			new EmitRow("PrefixUnaryExpression#13", "~a", "~a;", false),
			new EmitRow("PrefixUnaryExpression#14", "!a", "!a;", false),
			new EmitRow("PostfixUnaryExpression#1", "a++", "a++;", false),
			new EmitRow("PostfixUnaryExpression#2", "a--", "a--;", false),
			new EmitRow("BinaryExpression#1", "a,b", "a, b;", false),
			new EmitRow("BinaryExpression#2", "a+b", "a + b;", false),
			new EmitRow("BinaryExpression#3", "a**b", "a ** b;", false),
			new EmitRow("BinaryExpression#4", "a instanceof b", "a instanceof b;", false),
			new EmitRow("BinaryExpression#5", "a in b", "a in b;", false),
			new EmitRow("BinaryExpression#6", "a\n&& b", "a\n    && b;", false),
			new EmitRow("BinaryExpression#7", "a &&\nb", "a &&\n    b;", false),
			new EmitRow("ConditionalExpression#1", "a?b:c", "a ? b : c;", false),
			new EmitRow("ConditionalExpression#2", "a\n?b:c", "a\n    ? b : c;", false),
			new EmitRow("ConditionalExpression#3", "a?\nb:c", "a ?\n    b : c;", false),
			new EmitRow("ConditionalExpression#4", "a?b\n:c", "a ? b\n    : c;", false),
			new EmitRow("ConditionalExpression#5", "a?b:\nc", "a ? b :\n    c;", false),
			new EmitRow("TemplateExpression#1", "`a${b}c`", "`a${b}c`;", false),
			new EmitRow("TemplateExpression#2", "`a${b}c${d}e`", "`a${b}c${d}e`;", false),
			new EmitRow("YieldExpression#1", "(function*() { yield })", "(function* () { yield; });", false),
			new EmitRow("YieldExpression#2", "(function*() { yield a })", "(function* () { yield a; });", false),
			new EmitRow("YieldExpression#3", "(function*() { yield*a })", "(function* () { yield* a; });", false),
			new EmitRow("SpreadElement", "[...a]", "[...a];", false),
			new EmitRow("ClassExpression#1", "(class {})", "(class {\n});", false),
			new EmitRow("ClassExpression#2", "(class a {})", "(class a {\n});", false),
			new EmitRow("ClassExpression#3", "(class<T>{})", "(class<T> {\n});", false),
			new EmitRow("ClassExpression#4", "(class a<T>{})", "(class a<T> {\n});", false),
			new EmitRow("ClassExpression#5", "(class extends b {})", "(class extends b {\n});", false),
			new EmitRow("ClassExpression#6", "(class a extends b {})", "(class a extends b {\n});", false),
			new EmitRow("ClassExpression#7", "(class implements b {})", "(class implements b {\n});", false),
			new EmitRow("ClassExpression#8", "(class a implements b {})", "(class a implements b {\n});", false),
			new EmitRow("ClassExpression#9", "(class implements b, c {})", "(class implements b, c {\n});", false),
			new EmitRow("ClassExpression#10", "(class a implements b, c {})", "(class a implements b, c {\n});", false),
			new EmitRow("ClassExpression#11", "(class extends b implements c, d {})", "(class extends b implements c, d {\n});", false),
			new EmitRow("ClassExpression#12", "(class a extends b implements c, d {})", "(class a extends b implements c, d {\n});", false),
			new EmitRow("ClassExpression#13", "(@a class {})", "(\n@a\nclass {\n});", false),
			new EmitRow("OmittedExpression", "[,]", "[,];", false),
			new EmitRow("ExpressionWithTypeArguments", "a<T>", "a<T>;", false),
			new EmitRow("AsExpression", "a as T", "a as T;", false),
			new EmitRow("SatisfiesExpression", "a satisfies T", "a satisfies T;", false),
			new EmitRow("NonNullExpression", "a!", "a!;", false),
			new EmitRow("MetaProperty#1", "new.target", "new.target;", false),
			new EmitRow("MetaProperty#2", "import.meta", "import.meta;", false),
			new EmitRow("ArrayLiteralExpression#1", "[]", "[];", false),
			new EmitRow("ArrayLiteralExpression#2", "[a]", "[a];", false),
			new EmitRow("ArrayLiteralExpression#3", "[a,]", "[a,];", false),
			new EmitRow("ArrayLiteralExpression#4", "[,a]", "[, a];", false),
			new EmitRow("ArrayLiteralExpression#5", "[...a]", "[...a];", false),
			new EmitRow("ArrayLiteralExpression#6", "const array = [/* comment */];", "const array = [ /* comment */];", false),
			new EmitRow("ObjectLiteralExpression#1", "({})", "({});", false),
			new EmitRow("ObjectLiteralExpression#2", "({a,})", "({ a, });", false),
			new EmitRow("ShorthandPropertyAssignment", "({a})", "({ a });", false),
			new EmitRow("PropertyAssignment", "({a:b})", "({ a: b });", false),
			new EmitRow("SpreadAssignment", "({...a})", "({ ...a });", false),
			new EmitRow("Block", "{}", "{ }", false),
			new EmitRow("VariableStatement#1", "var a", "var a;", false),
			new EmitRow("VariableStatement#2", "let a", "let a;", false),
			new EmitRow("VariableStatement#3", "const a = b", "const a = b;", false),
			new EmitRow("VariableStatement#4", "using a = b", "using a = b;", false),
			new EmitRow("VariableStatement#5", "await using a = b", "await using a = b;", false),
			new EmitRow("EmptyStatement", ";", ";", false),
			new EmitRow("IfStatement#1", "if(a);", "if (a)\n    ;", false),
			new EmitRow("IfStatement#2", "if(a);else;", "if (a)\n    ;\nelse\n    ;", false),
			new EmitRow("IfStatement#3", "if(a);else{}", "if (a)\n    ;\nelse { }", false),
			new EmitRow("IfStatement#4", "if(a);else if(b);", "if (a)\n    ;\nelse if (b)\n    ;", false),
			new EmitRow("IfStatement#5", "if(a);else if(b) {}", "if (a)\n    ;\nelse if (b) { }", false),
			new EmitRow("IfStatement#6", "if(a) {}", "if (a) { }", false),
			new EmitRow("IfStatement#7", "if(a) {} else;", "if (a) { }\nelse\n    ;", false),
			new EmitRow("IfStatement#8", "if(a) {} else {}", "if (a) { }\nelse { }", false),
			new EmitRow("IfStatement#9", "if(a) {} else if(b);", "if (a) { }\nelse if (b)\n    ;", false),
			new EmitRow("IfStatement#10", "if(a) {} else if(b){}", "if (a) { }\nelse if (b) { }", false),
			new EmitRow("DoStatement#1", "do;while(a);", "do\n    ;\nwhile (a);", false),
			new EmitRow("DoStatement#2", "do {} while(a);", "do { } while (a);", false),
			new EmitRow("WhileStatement#1", "while(a);", "while (a)\n    ;", false),
			new EmitRow("WhileStatement#2", "while(a) {}", "while (a) { }", false),
			new EmitRow("ForStatement#1", "for(;;);", "for (;;)\n    ;", false),
			new EmitRow("ForStatement#2", "for(a;;);", "for (a;;)\n    ;", false),
			new EmitRow("ForStatement#3", "for(var a;;);", "for (var a;;)\n    ;", false),
			new EmitRow("ForStatement#4", "for(;a;);", "for (; a;)\n    ;", false),
			new EmitRow("ForStatement#5", "for(;;a);", "for (;; a)\n    ;", false),
			new EmitRow("ForStatement#6", "for(;;){}", "for (;;) { }", false),
			new EmitRow("ForInStatement#1", "for(a in b);", "for (a in b)\n    ;", false),
			new EmitRow("ForInStatement#2", "for(var a in b);", "for (var a in b)\n    ;", false),
			new EmitRow("ForInStatement#3", "for(a in b){}", "for (a in b) { }", false),
			new EmitRow("ForOfStatement#1", "for(a of b);", "for (a of b)\n    ;", false),
			new EmitRow("ForOfStatement#2", "for(var a of b);", "for (var a of b)\n    ;", false),
			new EmitRow("ForOfStatement#3", "for(a of b){}", "for (a of b) { }", false),
			new EmitRow("ForOfStatement#4", "for await(a of b);", "for await (a of b)\n    ;", false),
			new EmitRow("ForOfStatement#5", "for await(var a of b);", "for await (var a of b)\n    ;", false),
			new EmitRow("ForOfStatement#6", "for await(a of b){}", "for await (a of b) { }", false),
			new EmitRow("ContinueStatement#1", "continue", "continue;", false),
			new EmitRow("ContinueStatement#2", "continue a", "continue a;", false),
			new EmitRow("BreakStatement#1", "break", "break;", false),
			new EmitRow("BreakStatement#2", "break a", "break a;", false),
			new EmitRow("ReturnStatement#1", "return", "return;", false),
			new EmitRow("ReturnStatement#2", "return a", "return a;", false),
			new EmitRow("WithStatement#1", "with(a);", "with (a)\n    ;", false),
			new EmitRow("WithStatement#2", "with(a){}", "with (a) { }", false),
			new EmitRow("SwitchStatement", "switch (a) {}", "switch (a) {\n}", false),
			new EmitRow("CaseClause#1", "switch (a) {case b:}", "switch (a) {\n    case b:\n}", false),
			new EmitRow("CaseClause#2", "switch (a) {case b:;}", "switch (a) {\n    case b: ;\n}", false),
			new EmitRow("DefaultClause#1", "switch (a) {default:}", "switch (a) {\n    default:\n}", false),
			new EmitRow("DefaultClause#2", "switch (a) {default:;}", "switch (a) {\n    default: ;\n}", false),
			new EmitRow("LabeledStatement", "a:;", "a: ;", false),
			new EmitRow("ThrowStatement", "throw a", "throw a;", false),
			new EmitRow("TryStatement#1", "try {} catch {}", "try { }\ncatch { }", false),
			new EmitRow("TryStatement#2", "try {} finally {}", "try { }\nfinally { }", false),
			new EmitRow("TryStatement#3", "try {} catch {} finally {}", "try { }\ncatch { }\nfinally { }", false),
			new EmitRow("DebuggerStatement", "debugger", "debugger;", false),
			new EmitRow("FunctionDeclaration#1", "export default function(){}", "export default function () { }", false),
			new EmitRow("FunctionDeclaration#2", "function f(){}", "function f() { }", false),
			new EmitRow("FunctionDeclaration#3", "function*f(){}", "function* f() { }", false),
			new EmitRow("FunctionDeclaration#4", "async function f(){}", "async function f() { }", false),
			new EmitRow("FunctionDeclaration#5", "async function*f(){}", "async function* f() { }", false),
			new EmitRow("FunctionDeclaration#6", "function f<T>(){}", "function f<T>() { }", false),
			new EmitRow("FunctionDeclaration#7", "function f(a){}", "function f(a) { }", false),
			new EmitRow("FunctionDeclaration#8", "function f():T{}", "function f(): T { }", false),
			new EmitRow("FunctionDeclaration#9", "function f();", "function f();", false),
			new EmitRow("ClassDeclaration#1", "class a {}", "class a {\n}", false),
			new EmitRow("ClassDeclaration#2", "class a<T>{}", "class a<T> {\n}", false),
			new EmitRow("ClassDeclaration#3", "class a extends b {}", "class a extends b {\n}", false),
			new EmitRow("ClassDeclaration#4", "class a implements b {}", "class a implements b {\n}", false),
			new EmitRow("ClassDeclaration#5", "class a implements b, c {}", "class a implements b, c {\n}", false),
			new EmitRow("ClassDeclaration#6", "class a extends b implements c, d {}", "class a extends b implements c, d {\n}", false),
			new EmitRow("ClassDeclaration#7", "export default class {}", "export default class {\n}", false),
			new EmitRow("ClassDeclaration#8", "export default class<T>{}", "export default class<T> {\n}", false),
			new EmitRow("ClassDeclaration#9", "export default class extends b {}", "export default class extends b {\n}", false),
			new EmitRow("ClassDeclaration#10", "export default class implements b {}", "export default class implements b {\n}", false),
			new EmitRow("ClassDeclaration#11", "export default class implements b, c {}", "export default class implements b, c {\n}", false),
			new EmitRow("ClassDeclaration#12", "export default class extends b implements c, d {}", "export default class extends b implements c, d {\n}", false),
			new EmitRow("ClassDeclaration#13", "@a class b {}", "@a\nclass b {\n}", false),
			new EmitRow("ClassDeclaration#14", "@a export class b {}", "@a\nexport class b {\n}", false),
			new EmitRow("ClassDeclaration#15", "export @a class b {}", "export \n@a\nclass b {\n}", false),
			new EmitRow("InterfaceDeclaration#1", "interface a {}", "interface a {\n}", false),
			new EmitRow("InterfaceDeclaration#2", "interface a<T>{}", "interface a<T> {\n}", false),
			new EmitRow("InterfaceDeclaration#3", "interface a extends b {}", "interface a extends b {\n}", false),
			new EmitRow("InterfaceDeclaration#4", "interface a extends b, c {}", "interface a extends b, c {\n}", false),
			new EmitRow("TypeAliasDeclaration#1", "type a = b", "type a = b;", false),
			new EmitRow("TypeAliasDeclaration#2", "type a<T> = b", "type a<T> = b;", false),
			new EmitRow("EnumDeclaration#1", "enum a{}", "enum a {\n}", false),
			new EmitRow("EnumDeclaration#2", "enum a{b}", "enum a {\n    b\n}", false),
			new EmitRow("EnumDeclaration#3", "enum a{b=c}", "enum a {\n    b = c\n}", false),
			new EmitRow("ModuleDeclaration#1", "module a{}", "module a { }", false),
			new EmitRow("ModuleDeclaration#2", "module a.b{}", "module a.b { }", false),
			new EmitRow("ModuleDeclaration#3", "module \"a\";", "module \"a\";", false),
			new EmitRow("ModuleDeclaration#4", "module \"a\"{}", "module \"a\" { }", false),
			new EmitRow("ModuleDeclaration#5", "namespace a{}", "namespace a { }", false),
			new EmitRow("ModuleDeclaration#6", "namespace a.b{}", "namespace a.b { }", false),
			new EmitRow("ModuleDeclaration#7", "global;", "global;", false),
			new EmitRow("ModuleDeclaration#8", "global{}", "global { }", false),
			new EmitRow("ImportEqualsDeclaration#1", "import a = b", "import a = b;", false),
			new EmitRow("ImportEqualsDeclaration#2", "import a = b.c", "import a = b.c;", false),
			new EmitRow("ImportEqualsDeclaration#3", "import a = require(\"b\")", "import a = require(\"b\");", false),
			new EmitRow("ImportEqualsDeclaration#4", "export import a = b", "export import a = b;", false),
			new EmitRow("ImportEqualsDeclaration#5", "export import a = require(\"b\")", "export import a = require(\"b\");", false),
			new EmitRow("ImportEqualsDeclaration#6", "import type a = b", "import type a = b;", false),
			new EmitRow("ImportEqualsDeclaration#7", "import type a = b.c", "import type a = b.c;", false),
			new EmitRow("ImportEqualsDeclaration#8", "import type a = require(\"b\")", "import type a = require(\"b\");", false),
			new EmitRow("ImportDeclaration#1", "import \"a\"", "import \"a\";", false),
			new EmitRow("ImportDeclaration#2", "import a from \"b\"", "import a from \"b\";", false),
			new EmitRow("ImportDeclaration#3", "import type a from \"b\"", "import type a from \"b\";", false),
			new EmitRow("ImportDeclaration#4", "import * as a from \"b\"", "import * as a from \"b\";", false),
			new EmitRow("ImportDeclaration#5", "import type * as a from \"b\"", "import type * as a from \"b\";", false),
			new EmitRow("ImportDeclaration#6", "import {} from \"b\"", "import {} from \"b\";", false),
			new EmitRow("ImportDeclaration#7", "import type {} from \"b\"", "import type {} from \"b\";", false),
			new EmitRow("ImportDeclaration#8", "import { a } from \"b\"", "import { a } from \"b\";", false),
			new EmitRow("ImportDeclaration#9", "import type { a } from \"b\"", "import type { a } from \"b\";", false),
			new EmitRow("ImportDeclaration#8", "import { a as b } from \"c\"", "import { a as b } from \"c\";", false),
			new EmitRow("ImportDeclaration#9", "import type { a as b } from \"c\"", "import type { a as b } from \"c\";", false),
			new EmitRow("ImportDeclaration#10", "import { \"a\" as b } from \"c\"", "import { \"a\" as b } from \"c\";", false),
			new EmitRow("ImportDeclaration#11", "import type { \"a\" as b } from \"c\"", "import type { \"a\" as b } from \"c\";", false),
			new EmitRow("ImportDeclaration#12", "import a, {} from \"b\"", "import a, {} from \"b\";", false),
			new EmitRow("ImportDeclaration#13", "import a, * as b from \"c\"", "import a, * as b from \"c\";", false),
			new EmitRow("ImportDeclaration#14", "import {} from \"a\" with {}", "import {} from \"a\" with {};", false),
			new EmitRow("ImportDeclaration#15", "import {} from \"a\" with { b: \"c\" }", "import {} from \"a\" with { b: \"c\" };", false),
			new EmitRow("ImportDeclaration#16", "import {} from \"a\" with { \"b\": \"c\" }", "import {} from \"a\" with { \"b\": \"c\" };", false),
			new EmitRow("ExportAssignment#1", "export = a", "export = a;", false),
			new EmitRow("ExportAssignment#2", "export default a", "export default a;", false),
			new EmitRow("NamespaceExportDeclaration", "export as namespace a", "export as namespace a;", false),
			new EmitRow("ExportDeclaration#1", "export * from \"a\"", "export * from \"a\";", false),
			new EmitRow("ExportDeclaration#2", "export type * from \"a\"", "export type * from \"a\";", false),
			new EmitRow("ExportDeclaration#3", "export * as a from \"b\"", "export * as a from \"b\";", false),
			new EmitRow("ExportDeclaration#4", "export type * as a from \"b\"", "export type * as a from \"b\";", false),
			new EmitRow("ExportDeclaration#5", "export { } from \"a\"", "export {} from \"a\";", false),
			new EmitRow("ExportDeclaration#6", "export type { } from \"a\"", "export type {} from \"a\";", false),
			new EmitRow("ExportDeclaration#7", "export { a } from \"b\"", "export { a } from \"b\";", false),
			new EmitRow("ExportDeclaration#8", "export { type a } from \"b\"", "export { type a } from \"b\";", false),
			new EmitRow("ExportDeclaration#9", "export type { a } from \"b\"", "export type { a } from \"b\";", false),
			new EmitRow("ExportDeclaration#10", "export { a as b } from \"c\"", "export { a as b } from \"c\";", false),
			new EmitRow("ExportDeclaration#11", "export { type a as b } from \"c\"", "export { type a as b } from \"c\";", false),
			new EmitRow("ExportDeclaration#12", "export type { a as b } from \"c\"", "export type { a as b } from \"c\";", false),
			new EmitRow("ExportDeclaration#13", "export { a as \"b\" } from \"c\"", "export { a as \"b\" } from \"c\";", false),
			new EmitRow("ExportDeclaration#14", "export { type a as \"b\" } from \"c\"", "export { type a as \"b\" } from \"c\";", false),
			new EmitRow("ExportDeclaration#15", "export type { a as \"b\" } from \"c\"", "export type { a as \"b\" } from \"c\";", false),
			new EmitRow("ExportDeclaration#16", "export { \"a\" } from \"b\"", "export { \"a\" } from \"b\";", false),
			new EmitRow("ExportDeclaration#17", "export { type \"a\" } from \"b\"", "export { type \"a\" } from \"b\";", false),
			new EmitRow("ExportDeclaration#18", "export type { \"a\" } from \"b\"", "export type { \"a\" } from \"b\";", false),
			new EmitRow("ExportDeclaration#19", "export { \"a\" as b } from \"c\"", "export { \"a\" as b } from \"c\";", false),
			new EmitRow("ExportDeclaration#20", "export { type \"a\" as b } from \"c\"", "export { type \"a\" as b } from \"c\";", false),
			new EmitRow("ExportDeclaration#21", "export type { \"a\" as b } from \"c\"", "export type { \"a\" as b } from \"c\";", false),
			new EmitRow("ExportDeclaration#22", "export { \"a\" as \"b\" } from \"c\"", "export { \"a\" as \"b\" } from \"c\";", false),
			new EmitRow("ExportDeclaration#23", "export { type \"a\" as \"b\" } from \"c\"", "export { type \"a\" as \"b\" } from \"c\";", false),
			new EmitRow("ExportDeclaration#24", "export type { \"a\" as \"b\" } from \"c\"", "export type { \"a\" as \"b\" } from \"c\";", false),
			new EmitRow("ExportDeclaration#25", "export { }", "export {};", false),
			new EmitRow("ExportDeclaration#26", "export type { }", "export type {};", false),
			new EmitRow("ExportDeclaration#27", "export { a }", "export { a };", false),
			new EmitRow("ExportDeclaration#28", "export { type a }", "export { type a };", false),
			new EmitRow("ExportDeclaration#29", "export type { a }", "export type { a };", false),
			new EmitRow("ExportDeclaration#30", "export { a as b }", "export { a as b };", false),
			new EmitRow("ExportDeclaration#31", "export { type a as b }", "export { type a as b };", false),
			new EmitRow("ExportDeclaration#32", "export type { a as b }", "export type { a as b };", false),
			new EmitRow("ExportDeclaration#33", "export { a as \"b\" }", "export { a as \"b\" };", false),
			new EmitRow("ExportDeclaration#34", "export { type a as \"b\" }", "export { type a as \"b\" };", false),
			new EmitRow("ExportDeclaration#35", "export type { a as \"b\" }", "export type { a as \"b\" };", false),
			new EmitRow("ExportDeclaration#36", "export {} from \"a\" with {}", "export {} from \"a\" with {};", false),
			new EmitRow("ExportDeclaration#37", "export {} from \"a\" with { b: \"c\" }", "export {} from \"a\" with { b: \"c\" };", false),
			new EmitRow("ExportDeclaration#38", "export {} from \"a\" with { \"b\": \"c\" }", "export {} from \"a\" with { \"b\": \"c\" };", false),
			new EmitRow("KeywordTypeNode#1", "type T = any", "type T = any;", false),
			new EmitRow("KeywordTypeNode#2", "type T = unknown", "type T = unknown;", false),
			new EmitRow("KeywordTypeNode#3", "type T = never", "type T = never;", false),
			new EmitRow("KeywordTypeNode#4", "type T = void", "type T = void;", false),
			new EmitRow("KeywordTypeNode#5", "type T = undefined", "type T = undefined;", false),
			new EmitRow("KeywordTypeNode#6", "type T = null", "type T = null;", false),
			new EmitRow("KeywordTypeNode#7", "type T = object", "type T = object;", false),
			new EmitRow("KeywordTypeNode#8", "type T = string", "type T = string;", false),
			new EmitRow("KeywordTypeNode#9", "type T = symbol", "type T = symbol;", false),
			new EmitRow("KeywordTypeNode#10", "type T = number", "type T = number;", false),
			new EmitRow("KeywordTypeNode#11", "type T = bigint", "type T = bigint;", false),
			new EmitRow("KeywordTypeNode#12", "type T = boolean", "type T = boolean;", false),
			new EmitRow("KeywordTypeNode#13", "type T = intrinsic", "type T = intrinsic;", false),
			new EmitRow("TypePredicateNode#1", "function f(): asserts a", "function f(): asserts a;", false),
			new EmitRow("TypePredicateNode#2", "function f(): asserts a is b", "function f(): asserts a is b;", false),
			new EmitRow("TypePredicateNode#3", "function f(): asserts this", "function f(): asserts this;", false),
			new EmitRow("TypePredicateNode#4", "function f(): asserts this is b", "function f(): asserts this is b;", false),
			new EmitRow("TypeReferenceNode#1", "type T = a", "type T = a;", false),
			new EmitRow("TypeReferenceNode#2", "type T = a.b", "type T = a.b;", false),
			new EmitRow("TypeReferenceNode#3", "type T = a<U>", "type T = a<U>;", false),
			new EmitRow("TypeReferenceNode#4", "type T = a.b<U>", "type T = a.b<U>;", false),
			new EmitRow("FunctionTypeNode#1", "type T = () => a", "type T = () => a;", false),
			new EmitRow("FunctionTypeNode#2", "type T = <T>() => a", "type T = <T>() => a;", false),
			new EmitRow("FunctionTypeNode#3", "type T = (a) => b", "type T = (a) => b;", false),
			new EmitRow("ConstructorTypeNode#1", "type T = new () => a", "type T = new () => a;", false),
			new EmitRow("ConstructorTypeNode#2", "type T = new <T>() => a", "type T = new <T>() => a;", false),
			new EmitRow("ConstructorTypeNode#3", "type T = new (a) => b", "type T = new (a) => b;", false),
			new EmitRow("ConstructorTypeNode#4", "type T = abstract new () => a", "type T = abstract new () => a;", false),
			new EmitRow("TypeQueryNode#1", "type T = typeof a", "type T = typeof a;", false),
			new EmitRow("TypeQueryNode#2", "type T = typeof a.b", "type T = typeof a.b;", false),
			new EmitRow("TypeQueryNode#3", "type T = typeof a<U>", "type T = typeof a<U>;", false),
			new EmitRow("TypeLiteralNode#1", "type T = {}", "type T = {};", false),
			new EmitRow("TypeLiteralNode#2", "type T = {a}", "type T = {\n    a;\n};", false),
			new EmitRow("ArrayTypeNode", "type T = a[]", "type T = a[];", false),
			new EmitRow("TupleTypeNode#1", "type T = []", "type T = [\n];", false),
			new EmitRow("TupleTypeNode#2", "type T = [a]", "type T = [\n    a\n];", false),
			new EmitRow("TupleTypeNode#3", "type T = [a,]", "type T = [\n    a\n];", false),
			new EmitRow("RestTypeNode", "type T = [...a]", "type T = [\n    ...a\n];", false),
			new EmitRow("OptionalTypeNode", "type T = [a?]", "type T = [\n    a?\n];", false),
			new EmitRow("NamedTupleMember#1", "type T = [a: b]", "type T = [\n    a: b\n];", false),
			new EmitRow("NamedTupleMember#2", "type T = [a?: b]", "type T = [\n    a?: b\n];", false),
			new EmitRow("NamedTupleMember#3", "type T = [...a: b]", "type T = [\n    ...a: b\n];", false),
			new EmitRow("UnionTypeNode#1", "type T = a | b", "type T = a | b;", false),
			new EmitRow("UnionTypeNode#2", "type T = a | b | c", "type T = a | b | c;", false),
			new EmitRow("UnionTypeNode#3", "type T = | a | b", "type T = a | b;", false),
			new EmitRow("IntersectionTypeNode#1", "type T = a & b", "type T = a & b;", false),
			new EmitRow("IntersectionTypeNode#2", "type T = a & b & c", "type T = a & b & c;", false),
			new EmitRow("IntersectionTypeNode#3", "type T = & a & b", "type T = a & b;", false),
			new EmitRow("ConditionalTypeNode", "type T = a extends b ? c : d", "type T = a extends b ? c : d;", false),
			new EmitRow("InferTypeNode#1", "type T = a extends infer b ? c : d", "type T = a extends infer b ? c : d;", false),
			new EmitRow("InferTypeNode#2", "type T = a extends infer b extends c ? d : e", "type T = a extends infer b extends c ? d : e;", false),
			new EmitRow("ParenthesizedTypeNode", "type T = (U)", "type T = (U);", false),
			new EmitRow("ThisTypeNode", "type T = this", "type T = this;", false),
			new EmitRow("TypeOperatorNode#1", "type T = keyof U", "type T = keyof U;", false),
			new EmitRow("TypeOperatorNode#2", "type T = readonly U[]", "type T = readonly U[];", false),
			new EmitRow("TypeOperatorNode#3", "type T = unique symbol", "type T = unique symbol;", false),
			new EmitRow("IndexedAccessTypeNode", "type T = a[b]", "type T = a[b];", false),
			new EmitRow("MappedTypeNode#1", "type T = { [a in b]: c }", "type T = {\n    [a in b]: c;\n};", false),
			new EmitRow("MappedTypeNode#2", "type T = { [a in b as c]: d }", "type T = {\n    [a in b as c]: d;\n};", false),
			new EmitRow("MappedTypeNode#3", "type T = { readonly [a in b]: c }", "type T = {\n    readonly [a in b]: c;\n};", false),
			new EmitRow("MappedTypeNode#4", "type T = { +readonly [a in b]: c }", "type T = {\n    +readonly [a in b]: c;\n};", false),
			new EmitRow("MappedTypeNode#5", "type T = { -readonly [a in b]: c }", "type T = {\n    -readonly [a in b]: c;\n};", false),
			new EmitRow("MappedTypeNode#6", "type T = { [a in b]?: c }", "type T = {\n    [a in b]?: c;\n};", false),
			new EmitRow("MappedTypeNode#7", "type T = { [a in b]+?: c }", "type T = {\n    [a in b]+?: c;\n};", false),
			new EmitRow("MappedTypeNode#8", "type T = { [a in b]-?: c }", "type T = {\n    [a in b]-?: c;\n};", false),
			new EmitRow("MappedTypeNode#9", "type T = { [a in b]: c; d }", "type T = {\n    [a in b]: c;\n    d;\n};", false),
			new EmitRow("LiteralTypeNode#1", "type T = null", "type T = null;", false),
			new EmitRow("LiteralTypeNode#2", "type T = true", "type T = true;", false),
			new EmitRow("LiteralTypeNode#3", "type T = false", "type T = false;", false),
			new EmitRow("LiteralTypeNode#4", "type T = \"\"", "type T = \"\";", false),
			new EmitRow("LiteralTypeNode#5", "type T = ''", "type T = '';", false),
			new EmitRow("LiteralTypeNode#6", "type T = ``", "type T = ``;", false),
			new EmitRow("LiteralTypeNode#7", "type T = 0", "type T = 0;", false),
			new EmitRow("LiteralTypeNode#8", "type T = 0n", "type T = 0n;", false),
			new EmitRow("LiteralTypeNode#9", "type T = -0", "type T = -0;", false),
			new EmitRow("LiteralTypeNode#10", "type T = -0n", "type T = -0n;", false),
			new EmitRow("TemplateTypeNode#1", "type T = `a${b}c`", "type T = `a${b}c`;", false),
			new EmitRow("TemplateTypeNode#2", "type T = `a${b}c${d}e`", "type T = `a${b}c${d}e`;", false),
			new EmitRow("ImportTypeNode#1", "type T = import(a)", "type T = import(a);", false),
			new EmitRow("ImportTypeNode#2", "type T = import(a).b", "type T = import(a).b;", false),
			new EmitRow("ImportTypeNode#3", "type T = import(a).b<U>", "type T = import(a).b<U>;", false),
			new EmitRow("ImportTypeNode#4", "type T = typeof import(a)", "type T = typeof import(a);", false),
			new EmitRow("ImportTypeNode#5", "type T = typeof import(a).b", "type T = typeof import(a).b;", false),
			new EmitRow("ImportTypeNode#6", "type T = import(a, { with: { } })", "type T = import(a, { with: {} });", false),
			new EmitRow("ImportTypeNode#6", "type T = import(a, { with: { b: \"c\" } })", "type T = import(a, { with: { b: \"c\" } });", false),
			new EmitRow("ImportTypeNode#7", "type T = import(a, { with: { \"b\": \"c\" } })", "type T = import(a, { with: { \"b\": \"c\" } });", false),
			new EmitRow("PropertySignature#1", "interface I {a}", "interface I {\n    a;\n}", false),
			new EmitRow("PropertySignature#2", "interface I {readonly a}", "interface I {\n    readonly a;\n}", false),
			new EmitRow("PropertySignature#3", "interface I {\"a\"}", "interface I {\n    \"a\";\n}", false),
			new EmitRow("PropertySignature#4", "interface I {'a'}", "interface I {\n    'a';\n}", false),
			new EmitRow("PropertySignature#5", "interface I {0}", "interface I {\n    0;\n}", false),
			new EmitRow("PropertySignature#6", "interface I {0n}", "interface I {\n    0n;\n}", false),
			new EmitRow("PropertySignature#7", "interface I {[a]}", "interface I {\n    [a];\n}", false),
			new EmitRow("PropertySignature#8", "interface I {a?}", "interface I {\n    a?;\n}", false),
			new EmitRow("PropertySignature#9", "interface I {a: b}", "interface I {\n    a: b;\n}", false),
			new EmitRow("MethodSignature#1", "interface I {a()}", "interface I {\n    a();\n}", false),
			new EmitRow("MethodSignature#2", "interface I {\"a\"()}", "interface I {\n    \"a\"();\n}", false),
			new EmitRow("MethodSignature#3", "interface I {'a'()}", "interface I {\n    'a'();\n}", false),
			new EmitRow("MethodSignature#4", "interface I {0()}", "interface I {\n    0();\n}", false),
			new EmitRow("MethodSignature#5", "interface I {0n()}", "interface I {\n    0n();\n}", false),
			new EmitRow("MethodSignature#6", "interface I {[a]()}", "interface I {\n    [a]();\n}", false),
			new EmitRow("MethodSignature#7", "interface I {a?()}", "interface I {\n    a?();\n}", false),
			new EmitRow("MethodSignature#8", "interface I {a<T>()}", "interface I {\n    a<T>();\n}", false),
			new EmitRow("MethodSignature#9", "interface I {a(): b}", "interface I {\n    a(): b;\n}", false),
			new EmitRow("MethodSignature#10", "interface I {a(b): c}", "interface I {\n    a(b): c;\n}", false),
			new EmitRow("CallSignature#1", "interface I {()}", "interface I {\n    ();\n}", false),
			new EmitRow("CallSignature#2", "interface I {():a}", "interface I {\n    (): a;\n}", false),
			new EmitRow("CallSignature#3", "interface I {(p)}", "interface I {\n    (p);\n}", false),
			new EmitRow("CallSignature#4", "interface I {<T>()}", "interface I {\n    <T>();\n}", false),
			new EmitRow("ConstructSignature#1", "interface I {new ()}", "interface I {\n    new ();\n}", false),
			new EmitRow("ConstructSignature#2", "interface I {new ():a}", "interface I {\n    new (): a;\n}", false),
			new EmitRow("ConstructSignature#3", "interface I {new (p)}", "interface I {\n    new (p);\n}", false),
			new EmitRow("ConstructSignature#4", "interface I {new <T>()}", "interface I {\n    new <T>();\n}", false),
			new EmitRow("IndexSignatureDeclaration#1", "interface I {[a]}", "interface I {\n    [a];\n}", false),
			new EmitRow("IndexSignatureDeclaration#2", "interface I {[a: b]}", "interface I {\n    [a: b];\n}", false),
			new EmitRow("IndexSignatureDeclaration#3", "interface I {[a: b]: c}", "interface I {\n    [a: b]: c;\n}", false),
			new EmitRow("PropertyDeclaration#1", "class C {a}", "class C {\n    a;\n}", false),
			new EmitRow("PropertyDeclaration#2", "class C {readonly a}", "class C {\n    readonly a;\n}", false),
			new EmitRow("PropertyDeclaration#3", "class C {static a}", "class C {\n    static a;\n}", false),
			new EmitRow("PropertyDeclaration#4", "class C {accessor a}", "class C {\n    accessor a;\n}", false),
			new EmitRow("PropertyDeclaration#5", "class C {\"a\"}", "class C {\n    \"a\";\n}", false),
			new EmitRow("PropertyDeclaration#6", "class C {'a'}", "class C {\n    'a';\n}", false),
			new EmitRow("PropertyDeclaration#7", "class C {0}", "class C {\n    0;\n}", false),
			new EmitRow("PropertyDeclaration#8", "class C {0n}", "class C {\n    0n;\n}", false),
			new EmitRow("PropertyDeclaration#9", "class C {[a]}", "class C {\n    [a];\n}", false),
			new EmitRow("PropertyDeclaration#10", "class C {#a}", "class C {\n    #a;\n}", false),
			new EmitRow("PropertyDeclaration#11", "class C {a?}", "class C {\n    a?;\n}", false),
			new EmitRow("PropertyDeclaration#12", "class C {a!}", "class C {\n    a!;\n}", false),
			new EmitRow("PropertyDeclaration#13", "class C {a: b}", "class C {\n    a: b;\n}", false),
			new EmitRow("PropertyDeclaration#14", "class C {a = b}", "class C {\n    a = b;\n}", false),
			new EmitRow("PropertyDeclaration#15", "class C {@a b}", "class C {\n    @a\n    b;\n}", false),
			new EmitRow("MethodDeclaration#1", "class C {a()}", "class C {\n    a();\n}", false),
			new EmitRow("MethodDeclaration#2", "class C {\"a\"()}", "class C {\n    \"a\"();\n}", false),
			new EmitRow("MethodDeclaration#3", "class C {'a'()}", "class C {\n    'a'();\n}", false),
			new EmitRow("MethodDeclaration#4", "class C {0()}", "class C {\n    0();\n}", false),
			new EmitRow("MethodDeclaration#5", "class C {0n()}", "class C {\n    0n();\n}", false),
			new EmitRow("MethodDeclaration#6", "class C {[a]()}", "class C {\n    [a]();\n}", false),
			new EmitRow("MethodDeclaration#7", "class C {#a()}", "class C {\n    #a();\n}", false),
			new EmitRow("MethodDeclaration#8", "class C {a?()}", "class C {\n    a?();\n}", false),
			new EmitRow("MethodDeclaration#9", "class C {a<T>()}", "class C {\n    a<T>();\n}", false),
			new EmitRow("MethodDeclaration#10", "class C {a(): b}", "class C {\n    a(): b;\n}", false),
			new EmitRow("MethodDeclaration#11", "class C {a(b): c}", "class C {\n    a(b): c;\n}", false),
			new EmitRow("MethodDeclaration#12", "class C {a() {} }", "class C {\n    a() { }\n}", false),
			new EmitRow("MethodDeclaration#13", "class C {@a b() {} }", "class C {\n    @a\n    b() { }\n}", false),
			new EmitRow("MethodDeclaration#14", "class C {static a() {} }", "class C {\n    static a() { }\n}", false),
			new EmitRow("MethodDeclaration#15", "class C {async a() {} }", "class C {\n    async a() { }\n}", false),
			new EmitRow("GetAccessorDeclaration#1", "class C {get a()}", "class C {\n    get a();\n}", false),
			new EmitRow("GetAccessorDeclaration#2", "class C {get \"a\"()}", "class C {\n    get \"a\"();\n}", false),
			new EmitRow("GetAccessorDeclaration#3", "class C {get 'a'()}", "class C {\n    get 'a'();\n}", false),
			new EmitRow("GetAccessorDeclaration#4", "class C {get 0()}", "class C {\n    get 0();\n}", false),
			new EmitRow("GetAccessorDeclaration#5", "class C {get 0n()}", "class C {\n    get 0n();\n}", false),
			new EmitRow("GetAccessorDeclaration#6", "class C {get [a]()}", "class C {\n    get [a]();\n}", false),
			new EmitRow("GetAccessorDeclaration#7", "class C {get #a()}", "class C {\n    get #a();\n}", false),
			new EmitRow("GetAccessorDeclaration#8", "class C {get a(): b}", "class C {\n    get a(): b;\n}", false),
			new EmitRow("GetAccessorDeclaration#9", "class C {get a(b): c}", "class C {\n    get a(b): c;\n}", false),
			new EmitRow("GetAccessorDeclaration#10", "class C {get a() {} }", "class C {\n    get a() { }\n}", false),
			new EmitRow("GetAccessorDeclaration#11", "class C {@a get b() {} }", "class C {\n    @a\n    get b() { }\n}", false),
			new EmitRow("GetAccessorDeclaration#12", "class C {static get a() {} }", "class C {\n    static get a() { }\n}", false),
			new EmitRow("SetAccessorDeclaration#1", "class C {set a()}", "class C {\n    set a();\n}", false),
			new EmitRow("SetAccessorDeclaration#2", "class C {set \"a\"()}", "class C {\n    set \"a\"();\n}", false),
			new EmitRow("SetAccessorDeclaration#3", "class C {set 'a'()}", "class C {\n    set 'a'();\n}", false),
			new EmitRow("SetAccessorDeclaration#4", "class C {set 0()}", "class C {\n    set 0();\n}", false),
			new EmitRow("SetAccessorDeclaration#5", "class C {set 0n()}", "class C {\n    set 0n();\n}", false),
			new EmitRow("SetAccessorDeclaration#6", "class C {set [a]()}", "class C {\n    set [a]();\n}", false),
			new EmitRow("SetAccessorDeclaration#7", "class C {set #a()}", "class C {\n    set #a();\n}", false),
			new EmitRow("SetAccessorDeclaration#8", "class C {set a(): b}", "class C {\n    set a(): b;\n}", false),
			new EmitRow("SetAccessorDeclaration#9", "class C {set a(b): c}", "class C {\n    set a(b): c;\n}", false),
			new EmitRow("SetAccessorDeclaration#10", "class C {set a() {} }", "class C {\n    set a() { }\n}", false),
			new EmitRow("SetAccessorDeclaration#11", "class C {@a set b() {} }", "class C {\n    @a\n    set b() { }\n}", false),
			new EmitRow("SetAccessorDeclaration#12", "class C {static set a() {} }", "class C {\n    static set a() { }\n}", false),
			new EmitRow("ConstructorDeclaration#1", "class C {constructor()}", "class C {\n    constructor();\n}", false),
			new EmitRow("ConstructorDeclaration#2", "class C {constructor(): b}", "class C {\n    constructor(): b;\n}", false),
			new EmitRow("ConstructorDeclaration#3", "class C {constructor(b): c}", "class C {\n    constructor(b): c;\n}", false),
			new EmitRow("ConstructorDeclaration#4", "class C {constructor() {} }", "class C {\n    constructor() { }\n}", false),
			new EmitRow("ConstructorDeclaration#5", "class C {@a constructor() {} }", "class C {\n    constructor() { }\n}", false),
			new EmitRow("ConstructorDeclaration#6", "class C {private constructor() {} }", "class C {\n    private constructor() { }\n}", false),
			new EmitRow("ClassStaticBlockDeclaration", "class C {static { }}", "class C {\n    static { }\n}", false),
			new EmitRow("SemicolonClassElement#1", "class C {;}", "class C {\n    ;\n}", false),
			new EmitRow("ParameterDeclaration#1", "function f(a)", "function f(a);", false),
			new EmitRow("ParameterDeclaration#2", "function f(a: b)", "function f(a: b);", false),
			new EmitRow("ParameterDeclaration#3", "function f(a = b)", "function f(a = b);", false),
			new EmitRow("ParameterDeclaration#4", "function f(a?)", "function f(a?);", false),
			new EmitRow("ParameterDeclaration#5", "function f(...a)", "function f(...a);", false),
			new EmitRow("ParameterDeclaration#6", "function f(this)", "function f(this);", false),
			// new EmitRow("ParameterDeclaration#7", "function f(a,)", "function f(a,);", false), // TODO: preserve trailing comma after Strada migration
			new EmitRow("ObjectBindingPattern#1", "function f({})", "function f({});", false),
			new EmitRow("ObjectBindingPattern#2", "function f({a})", "function f({ a });", false),
			new EmitRow("ObjectBindingPattern#3", "function f({a = b})", "function f({ a = b });", false),
			new EmitRow("ObjectBindingPattern#4", "function f({a: b})", "function f({ a: b });", false),
			new EmitRow("ObjectBindingPattern#5", "function f({a: b = c})", "function f({ a: b = c });", false),
			new EmitRow("ObjectBindingPattern#6", "function f({\"a\": b})", "function f({ \"a\": b });", false),
			new EmitRow("ObjectBindingPattern#7", "function f({'a': b})", "function f({ 'a': b });", false),
			new EmitRow("ObjectBindingPattern#8", "function f({0: b})", "function f({ 0: b });", false),
			new EmitRow("ObjectBindingPattern#9", "function f({[a]: b})", "function f({ [a]: b });", false),
			new EmitRow("ObjectBindingPattern#10", "function f({...a})", "function f({ ...a });", false),
			new EmitRow("ObjectBindingPattern#11", "function f({a: {}})", "function f({ a: {} });", false),
			new EmitRow("ObjectBindingPattern#12", "function f({a: []})", "function f({ a: [] });", false),
			new EmitRow("ArrayBindingPattern#1", "function f([])", "function f([]);", false),
			new EmitRow("ArrayBindingPattern#2", "function f([,])", "function f([,]);", false),
			new EmitRow("ArrayBindingPattern#3", "function f([a])", "function f([a]);", false),
			new EmitRow("ArrayBindingPattern#4", "function f([a, b])", "function f([a, b]);", false),
			new EmitRow("ArrayBindingPattern#5", "function f([a, , b])", "function f([a, , b]);", false),
			new EmitRow("ArrayBindingPattern#6", "function f([a = b])", "function f([a = b]);", false),
			new EmitRow("ArrayBindingPattern#7", "function f([...a])", "function f([...a]);", false),
			new EmitRow("ArrayBindingPattern#8", "function f([{}])", "function f([{}]);", false),
			new EmitRow("ArrayBindingPattern#9", "function f([[]])", "function f([[]]);", false),
			new EmitRow("TypeParameterDeclaration#1", "function f<T>();", "function f<T>();", false),
			new EmitRow("TypeParameterDeclaration#2", "function f<in T>();", "function f<in T>();", false),
			new EmitRow("TypeParameterDeclaration#3", "function f<T extends U>();", "function f<T extends U>();", false),
			new EmitRow("TypeParameterDeclaration#4", "function f<T = U>();", "function f<T = U>();", false),
			new EmitRow("TypeParameterDeclaration#5", "function f<T extends U = V>();", "function f<T extends U = V>();", false),
			new EmitRow("TypeParameterDeclaration#6", "function f<T, U>();", "function f<T, U>();", false),
			// new EmitRow("TypeParameterDeclaration#7", "function f<T,>();", "function f<T,>();", false), // TODO: preserve trailing comma after Strada migration
			new EmitRow("JsxElement1", "<a></a>", "<a></a>;", true),
			new EmitRow("JsxElement2", "<this></this>", "<this></this>;", true),
			new EmitRow("JsxElement3", "<a:b></a:b>", "<a:b></a:b>;", true),
			new EmitRow("JsxElement4", "<a.b></a.b>", "<a.b></a.b>;", true),
			new EmitRow("JsxElement5", "<a<b>></a>", "<a<b>></a>;", true),
			new EmitRow("JsxElement6", "<a b></a>", "<a b></a>;", true),
			new EmitRow("JsxElement7", "<a>b</a>", "<a>b</a>;", true),
			new EmitRow("JsxElement8", "<a>{b}</a>", "<a>{b}</a>;", true),
			new EmitRow("JsxElement9", "<a><b></b></a>", "<a><b></b></a>;", true),
			new EmitRow("JsxElement10", "<a><b /></a>", "<a><b /></a>;", true),
			new EmitRow("JsxElement11", "<a><></></a>", "<a><></></a>;", true),
			new EmitRow("JsxElement12", "<a>\n    {/* missing */}\n    {\n        // foo\n    }\n</a>", "<a>\n    {/* missing */}\n    {\n    // foo\n    }\n</a>;", true),
			new EmitRow("JsxSelfClosingElement1", "<a />", "<a />;", true),
			new EmitRow("JsxSelfClosingElement2", "<this />", "<this />;", true),
			new EmitRow("JsxSelfClosingElement3", "<a:b />", "<a:b />;", true),
			new EmitRow("JsxSelfClosingElement4", "<a.b />", "<a.b />;", true),
			new EmitRow("JsxSelfClosingElement5", "<a<b> />", "<a<b> />;", true),
			new EmitRow("JsxSelfClosingElement6", "<a b/>", "<a b/>;", true),
			new EmitRow("JsxFragment1", "<></>", "<></>;", true),
			new EmitRow("JsxFragment2", "<>b</>", "<>b</>;", true),
			new EmitRow("JsxFragment3", "<>{b}</>", "<>{b}</>;", true),
			new EmitRow("JsxFragment4", "<><b></b></>", "<><b></b></>;", true),
			new EmitRow("JsxFragment5", "<><b /></>", "<><b /></>;", true),
			new EmitRow("JsxFragment6", "<><></></>", "<><></></>;", true),
			new EmitRow("JsxAttribute1", "<a b/>", "<a b/>;", true),
			new EmitRow("JsxAttribute2", "<a b:c/>", "<a b:c/>;", true),
			new EmitRow("JsxAttribute3", "<a b=\"c\"/>", "<a b=\"c\"/>;", true),
			new EmitRow("JsxAttribute4", "<a b='c'/>", "<a b='c'/>;", true),
			new EmitRow("JsxAttribute5", "<a b={c}/>", "<a b={c}/>;", true),
			new EmitRow("JsxAttribute6", "<a b=<c></c>/>", "<a b=<c></c>/>;", true),
			new EmitRow("JsxAttribute7", "<a b=<c />/>", "<a b=<c />/>;", true),
			new EmitRow("JsxAttribute8", "<a b=<></>/>", "<a b=<></>/>;", true),
			new EmitRow("JsxSpreadAttribute", "<a {...b}/>", "<a {...b}/>;", true),
		];

		for (rec in data) {
			T.run("TestEmit/" + rec.title, function() {
				final file = Parsetestutil.ParseTypeScript(rec.input, rec.jsx);
				Parsetestutil.CheckDiagnostics(file);
				Emittestutil.CheckEmit(null, file, rec.output);
			});
		}
	}

	static function TestParenthesizeDecorator():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewClassDeclaration(
					factory.NewModifierList(
						[
							factory.NewDecorator(
								factory.NewBinaryExpression(
									null, /*modifiers*/
									factory.NewIdentifier("a"),
									null, /*typeNode*/
									factory.NewToken(KindPlusToken),
									factory.NewIdentifier("b")
								)
							)
						]
					),
					factory.NewIdentifier("C"),
					null,
					null,
					factory.NewNodeList([])
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "@(a + b)\nclass C {\n}");
	}

	static function TestParenthesizeComputedPropertyName():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewClassDeclaration(
					null, /*modifiers*/
					factory.NewIdentifier("C"),
					null, /*typeParameters*/
					null, /*heritageClauses*/
					factory.NewNodeList([
						factory.NewPropertyDeclaration(
							null, /*modifiers*/
							factory.NewComputedPropertyName(
								// will be parenthesized on emit:
								factory.NewBinaryExpression(
									null, /*modifiers*/
									factory.NewIdentifier("a"),
									null, /*typeNode*/
									factory.NewToken(KindCommaToken),
									factory.NewIdentifier("b")
								)
							),
							null, /*postfixToken*/
							null, /*typeNode*/
							null /*initializer*/
						)
					])
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "class C {\n    [(a, b)];\n}");
	}

	static function TestParenthesizeArrayLiteral():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewArrayLiteralExpression(
						factory.NewNodeList(
							[
								// will be parenthesized on emit:
								factory.NewBinaryExpression(
									null, /*modifiers*/
									factory.NewIdentifier("a"),
									null, /*typeNode*/
									factory.NewToken(KindCommaToken),
									factory.NewIdentifier("b")
								)
							]
						),
						false /*multiLine*/
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "[(a, b)];");
	}

	static function TestParenthesizePropertyAccess1():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewPropertyAccessExpression(
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindCommaToken),
							factory.NewIdentifier("b")
						),
						null, /*questionDotToken*/
						factory.NewIdentifier("c"),
						NodeFlagsNone
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(a, b).c;");
	}

	static function TestParenthesizePropertyAccess2():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewPropertyAccessExpression(
						// will be parenthesized on emit:
						factory.NewPropertyAccessExpression(
							factory.NewIdentifier("a"),
							factory.NewToken(KindQuestionDotToken),
							factory.NewIdentifier("b"),
							NodeFlagsOptionalChain
						),
						null, /*questionDotToken*/
						factory.NewIdentifier("c"),
						NodeFlagsNone
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(a?.b).c;");
	}

	static function TestParenthesizePropertyAccess3():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewPropertyAccessExpression(
						// will be parenthesized on emit:
						factory.NewNewExpression(
							factory.NewIdentifier("a"),
							null, /*typeArguments*/
							null /*arguments*/
						),
						null, /*questionDotToken*/
						factory.NewIdentifier("b"),
						NodeFlagsNone
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(new a).b;");
	}

	static function TestParenthesizeElementAccess1():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewElementAccessExpression(
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindCommaToken),
							factory.NewIdentifier("b")
						),
						null, /*questionDotToken*/
						factory.NewIdentifier("c"),
						NodeFlagsNone
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(a, b)[c];");
	}

	static function TestParenthesizeElementAccess2():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewElementAccessExpression(
						// will be parenthesized on emit:
						factory.NewPropertyAccessExpression(
							factory.NewIdentifier("a"),
							factory.NewToken(KindQuestionDotToken),
							factory.NewIdentifier("b"),
							NodeFlagsOptionalChain
						),
						null, /*questionDotToken*/
						factory.NewIdentifier("c"),
						NodeFlagsNone
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(a?.b)[c];");
	}

	static function TestParenthesizeElementAccess3():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewElementAccessExpression(
						// will be parenthesized on emit:
						factory.NewNewExpression(
							factory.NewIdentifier("a"),
							null, /*typeArguments*/
							null /*arguments*/
						),
						null, /*questionDotToken*/
						factory.NewIdentifier("b"),
						NodeFlagsNone
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(new a)[b];");
	}

	static function TestParenthesizeCall1():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewCallExpression(
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindCommaToken),
							factory.NewIdentifier("b")
						),
						null, /*questionDotToken*/
						null, /*typeArguments*/
						factory.NewNodeList([]),
						NodeFlagsNone
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(a, b)();");
	}

	static function TestParenthesizeCall2():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewCallExpression(
						// will be parenthesized on emit:
						factory.NewPropertyAccessExpression(
							factory.NewIdentifier("a"),
							factory.NewToken(KindQuestionDotToken),
							factory.NewIdentifier("b"),
							NodeFlagsOptionalChain
						),
						null, /*questionDotToken*/
						null, /*typeArguments*/
						factory.NewNodeList([]),
						NodeFlagsNone
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(a?.b)();");
	}

	static function TestParenthesizeCall3():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewCallExpression(
						// will be parenthesized on emit:
						factory.NewNewExpression(
							factory.NewIdentifier("C"),
							null, /*typeArguments*/
							null /*arguments*/
						),
						null, /*questionDotToken*/
						null, /*typeArguments*/
						factory.NewNodeList([]),
						NodeFlagsNone
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(new C)();");
	}

	static function TestParenthesizeCall4():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewCallExpression(
						factory.NewIdentifier("a"),
						null, /*questionDotToken*/
						null, /*typeArguments*/
						factory.NewNodeList([
							factory.NewBinaryExpression(
								null, /*modifiers*/
								factory.NewIdentifier("b"),
								null, /*typeNode*/
								factory.NewToken(KindCommaToken),
								factory.NewIdentifier("c")
							)
						]),
						NodeFlagsNone
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "a((b, c));");
	}

	static function TestParenthesizeNew1():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewNewExpression(
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindCommaToken),
							factory.NewIdentifier("b")
						),
						null, /*typeArguments*/
						factory.NewNodeList([])
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "new (a, b)();");
	}

	static function TestParenthesizeNew2():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewNewExpression(
						// will be parenthesized on emit:
						factory.NewCallExpression(
							factory.NewIdentifier("C"),
							null, /*questionDotToken*/
							null, /*typeArguments*/
							factory.NewNodeList([]),
							NodeFlagsNone
						),
						null, /*typeArguments*/
						null /*arguments*/
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "new (C());");
	}

	static function TestParenthesizeNew3():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewNewExpression(
						factory.NewIdentifier("C"),
						null, /*typeArguments*/
						factory.NewNodeList([
							factory.NewBinaryExpression(
								null, /*modifiers*/
								factory.NewIdentifier("a"),
								null, /*typeNode*/
								factory.NewToken(KindCommaToken),
								factory.NewIdentifier("b")
							)
						])
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "new C((a, b));");
	}

	static function TestParenthesizeTaggedTemplate1():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewTaggedTemplateExpression(
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindCommaToken),
							factory.NewIdentifier("b")
						),
						null, /*questionDotToken*/
						null, /*typeArguments*/
						factory.NewNoSubstitutionTemplateLiteral("", TokenFlagsNone),
						NodeFlagsNone
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(a, b) ``;");
	}

	static function TestParenthesizeTaggedTemplate2():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewTaggedTemplateExpression(
						// will be parenthesized on emit:
						factory.NewPropertyAccessExpression(
							factory.NewIdentifier("a"),
							factory.NewToken(KindQuestionDotToken),
							factory.NewIdentifier("b"),
							NodeFlagsOptionalChain
						),
						null, /*questionDotToken*/
						null, /*typeArguments*/
						factory.NewNoSubstitutionTemplateLiteral("", TokenFlagsNone),
						NodeFlagsNone
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(a?.b) ``;");
	}

	static function TestParenthesizeTypeAssertion1():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewTypeAssertion(
						factory.NewTypeReferenceNode(
							factory.NewIdentifier("T"),
							null /*typeArguments*/
						),
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindPlusToken),
							factory.NewIdentifier("b")
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "<T>(a + b);");
	}

	static function TestParenthesizeArrowFunction1():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewArrowFunction(
						null, /*modifiers*/
						null, /*typeParameters*/
						factory.NewNodeList([]),
						null, /*returnType*/
						null, /*fullSignature*/
						factory.NewToken(KindEqualsGreaterThanToken),
						// will be parenthesized on emit:
						factory.NewObjectLiteralExpression(
							factory.NewNodeList([]),
							false /*multiLine*/
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "() => ({});");
	}

	static function TestParenthesizeArrowFunction2():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewArrowFunction(
						null, /*modifiers*/
						null, /*typeParameters*/
						factory.NewNodeList([]),
						null, /*returnType*/
						null, /*fullSignature*/
						factory.NewToken(KindEqualsGreaterThanToken),
						// will be parenthesized on emit:
						factory.NewPropertyAccessExpression(
							factory.NewObjectLiteralExpression(
								factory.NewNodeList([]),
								false /*multiLine*/
							),
							null, /*questionDotToken*/
							factory.NewIdentifier("a"),
							NodeFlagsNone
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "() => ({}.a);");
	}

	static function TestParenthesizeDelete():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewDeleteExpression(
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindPlusToken),
							factory.NewIdentifier("b")
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "delete (a + b);");
	}

	static function TestParenthesizeVoid():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewVoidExpression(
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindPlusToken),
							factory.NewIdentifier("b")
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "void (a + b);");
	}

	static function TestParenthesizeTypeOf():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewTypeOfExpression(
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindPlusToken),
							factory.NewIdentifier("b")
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "typeof (a + b);");
	}

	static function TestParenthesizeAwait():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewAwaitExpression(
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindPlusToken),
							factory.NewIdentifier("b")
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "await (a + b);");
	}

	static function isBinaryOperator(token:Kind):Bool {
		switch (token) {
			case KindCommaToken | KindLessThanToken | KindGreaterThanToken | KindLessThanEqualsToken | KindGreaterThanEqualsToken | KindEqualsEqualsToken |
				KindEqualsEqualsEqualsToken | KindExclamationEqualsToken | KindExclamationEqualsEqualsToken | KindPlusToken | KindMinusToken | KindAsteriskToken |
				KindAsteriskAsteriskToken | KindSlashToken | KindPercentToken | KindLessThanLessThanToken | KindGreaterThanGreaterThanToken |
				KindGreaterThanGreaterThanGreaterThanToken | KindAmpersandToken | KindBarToken | KindCaretToken | KindAmpersandAmpersandToken | KindBarBarToken |
				KindQuestionQuestionToken | KindEqualsToken | KindPlusEqualsToken | KindMinusEqualsToken | KindAsteriskEqualsToken |
				KindAsteriskAsteriskEqualsToken | KindSlashEqualsToken | KindPercentEqualsToken | KindLessThanLessThanEqualsToken |
				KindGreaterThanGreaterThanEqualsToken | KindGreaterThanGreaterThanGreaterThanEqualsToken | KindAmpersandEqualsToken | KindBarEqualsToken |
				KindBarBarEqualsToken | KindAmpersandAmpersandEqualsToken | KindQuestionQuestionEqualsToken | KindCaretEqualsToken | KindInKeyword |
				KindInstanceOfKeyword:
				return true;
			default:
		}
		return false;
	}

	static function makeSide(label:std.String, kind:Kind, factory:ts.ast.Ast.NodeFactory):Node {
		if (kind == KindIdentifier || kind == KindUnknown) {
			return factory.NewIdentifier(label);
		} else if (kind == KindArrowFunction) {
			return factory.NewArrowFunction(
				null, /*modifiers*/
				null, /*typeParameters*/
				factory.NewNodeList([]),
				null, /*returnType*/
				null, /*fullSignature*/
				factory.NewToken(KindEqualsGreaterThanToken),
				factory.NewBlock(factory.NewNodeList([]), false /*multiLine*/)
			);
		} else if (isBinaryOperator(kind)) {
			return factory.NewBinaryExpression(
				null, /*modifiers*/
				factory.NewIdentifier(label + "l"),
				null, /*typeNode*/
				factory.NewToken(kind),
				factory.NewIdentifier(label + "r")
			);
		} else {
			throw "unsupported kind";
		}
	}

	static function TestParenthesizeBinary():Void {
		final data:Array<BinaryRow> = [
			new BinaryRow(KindUnknown, KindCommaToken, KindUnknown, "l, r"),
			new BinaryRow(KindPlusToken, KindCommaToken, KindUnknown, "ll + lr, r"),
			new BinaryRow(KindPlusToken, KindAsteriskToken, KindUnknown, "(ll + lr) * r"),
			new BinaryRow(KindUnknown, KindAsteriskToken, KindPlusToken, "l * (rl + rr)"),
			new BinaryRow(KindAsteriskToken, KindPlusToken, KindUnknown, "ll * lr + r"),
			new BinaryRow(KindUnknown, KindPlusToken, KindAsteriskToken, "l + rl * rr"),
			new BinaryRow(KindAsteriskToken, KindSlashToken, KindUnknown, "ll * lr / r"),
			new BinaryRow(KindAsteriskAsteriskToken, KindSlashToken, KindUnknown, "ll ** lr / r"),
			new BinaryRow(KindAsteriskToken, KindAsteriskAsteriskToken, KindUnknown, "(ll * lr) ** r"),
			new BinaryRow(KindAsteriskAsteriskToken, KindAsteriskAsteriskToken, KindUnknown, "(ll ** lr) ** r"),
			new BinaryRow(KindUnknown, KindAsteriskToken, KindAsteriskToken, "l * rl * rr"),
			new BinaryRow(KindUnknown, KindBarToken, KindBarToken, "l | rl | rr"),
			new BinaryRow(KindUnknown, KindAmpersandToken, KindAmpersandToken, "l & rl & rr"),
			new BinaryRow(KindUnknown, KindCaretToken, KindCaretToken, "l ^ rl ^ rr"),
			new BinaryRow(KindUnknown, KindAmpersandAmpersandToken, KindArrowFunction, "l && (() => { })"),
		];
		for (rec in data) {
			T.run("TestParenthesizeBinary/" + rec.output, function() {
				final factory = new ts.ast.Ast.NodeFactory();
				final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
					[
						factory.NewExpressionStatement(
							factory.NewBinaryExpression(
								null, /*modifiers*/
								makeSide("l", rec.left, factory),
								null, /*typeNode*/
								factory.NewToken(rec.operator_),
								makeSide("r", rec.right, factory)
							)
						)
					]
				), factory.NewToken(KindEndOfFile));

				Parsetestutil.MarkSyntheticRecursive(file);
				Emittestutil.CheckEmit(null, file.AsSourceFile(), rec.output + ";");
			});
		}
	}

	static function TestParenthesizeConditional1():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewConditionalExpression(
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindCommaToken),
							factory.NewIdentifier("b")
						),
						factory.NewToken(KindQuestionToken),
						factory.NewIdentifier("c"),
						factory.NewToken(KindColonToken),
						factory.NewIdentifier("d")
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(a, b) ? c : d;");
	}

	static function TestParenthesizeConditional2():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewConditionalExpression(
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindEqualsToken),
							factory.NewIdentifier("b")
						),
						factory.NewToken(KindQuestionToken),
						factory.NewIdentifier("c"),
						factory.NewToken(KindColonToken),
						factory.NewIdentifier("d")
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(a = b) ? c : d;");
	}

	static function TestParenthesizeConditional3():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewConditionalExpression(
						// will be parenthesized on emit:
						factory.NewArrowFunction(
							null, /*modifiers*/
							null, /*typeParameters*/
							factory.NewNodeList([]),
							null, /*returnType*/
							null, /*fullSignature*/
							factory.NewToken(KindEqualsGreaterThanToken),
							factory.NewBlock(
								factory.NewNodeList([]),
								false /*multiLine*/
							)
						),
						factory.NewToken(KindQuestionToken),
						factory.NewIdentifier("a"),
						factory.NewToken(KindColonToken),
						factory.NewIdentifier("b")
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(() => { }) ? a : b;");
	}

	static function TestParenthesizeConditional4():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewConditionalExpression(
						// will be parenthesized on emit:
						factory.NewYieldExpression(null, null),
						factory.NewToken(KindQuestionToken),
						factory.NewIdentifier("a"),
						factory.NewToken(KindColonToken),
						factory.NewIdentifier("b")
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(yield) ? a : b;");
	}

	static function TestParenthesizeConditional5():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewConditionalExpression(
						factory.NewIdentifier("a"),
						factory.NewToken(KindQuestionToken),
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("b"),
							null, /*typeNode*/
							factory.NewToken(KindCommaToken),
							factory.NewIdentifier("c")
						),
						factory.NewToken(KindColonToken),
						factory.NewIdentifier("d")
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "a ? (b, c) : d;");
	}

	static function TestParenthesizeConditional6():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewConditionalExpression(
						factory.NewIdentifier("a"),
						factory.NewToken(KindQuestionToken),
						factory.NewIdentifier("b"),
						factory.NewToken(KindColonToken),
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("c"),
							null, /*typeNode*/
							factory.NewToken(KindCommaToken),
							factory.NewIdentifier("d")
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "a ? b : (c, d);");
	}

	static function TestParenthesizeYield1():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewYieldExpression(
						null, /*asteriskToken*/
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindCommaToken),
							factory.NewIdentifier("b")
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "yield (a, b);");
	}

	// !!! test ASI avoidance from emitExpressionNoASI
	////func TestParenthesizeYield2(t *testing.T) {
	////}

	static function TestParenthesizeSpreadElement1():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewArrayLiteralExpression(
						factory.NewNodeList(
							[
								factory.NewSpreadElement(
									// will be parenthesized on emit:
									factory.NewBinaryExpression(
										null, /*modifiers*/
										factory.NewIdentifier("a"),
										null, /*typeNode*/
										factory.NewToken(KindCommaToken),
										factory.NewIdentifier("b")
									)
								)
							]
						),
						false /*multiLine*/
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "[...(a, b)];");
	}

	static function TestParenthesizeSpreadElement2():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewCallExpression(
						factory.NewIdentifier("a"),
						null, /*questionDotToken*/
						null, /*typeArguments*/
						factory.NewNodeList(
							[
								factory.NewSpreadElement(
									// will be parenthesized on emit:
									factory.NewBinaryExpression(
										null, /*modifiers*/
										factory.NewIdentifier("b"),
										null, /*typeNode*/
										factory.NewToken(KindCommaToken),
										factory.NewIdentifier("c")
									)
								)
							]
						),
						NodeFlagsNone
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "a(...(b, c));");
	}

	static function TestParenthesizeSpreadElement3():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewNewExpression(
						factory.NewIdentifier("a"),
						null, /*typeArguments*/
						factory.NewNodeList(
							[
								factory.NewSpreadElement(
									// will be parenthesized on emit:
									factory.NewBinaryExpression(
										null, /*modifiers*/
										factory.NewIdentifier("b"),
										null, /*typeNode*/
										factory.NewToken(KindCommaToken),
										factory.NewIdentifier("c")
									)
								)
							]
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "new a(...(b, c));");
	}

	static function TestParenthesizeExpressionWithTypeArguments():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewExpressionWithTypeArguments(
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindCommaToken),
							factory.NewIdentifier("b")
						),
						factory.NewNodeList(
							[
								factory.NewTypeReferenceNode(
									factory.NewIdentifier("c"),
									null
								)
							]
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(a, b)<c>;");
	}

	static function TestParenthesizeAsExpression():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewAsExpression(
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindCommaToken),
							factory.NewIdentifier("b")
						),
						factory.NewTypeReferenceNode(
							factory.NewIdentifier("c"),
							null
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(a, b) as c;");
	}

	static function TestParenthesizeSatisfiesExpression():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewSatisfiesExpression(
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindCommaToken),
							factory.NewIdentifier("b")
						),
						factory.NewTypeReferenceNode(
							factory.NewIdentifier("c"),
							null
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(a, b) satisfies c;");
	}

	static function TestParenthesizeNonNullExpression():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewNonNullExpression(
						// will be parenthesized on emit:
						factory.NewBinaryExpression(
							null, /*modifiers*/
							factory.NewIdentifier("a"),
							null, /*typeNode*/
							factory.NewToken(KindCommaToken),
							factory.NewIdentifier("b")
						),
						NodeFlagsNone
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(a, b)!;");
	}

	static function TestParenthesizeExpressionStatement1():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewObjectLiteralExpression(
						factory.NewNodeList(
							[]
						),
						false /*multiLine*/
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "({});");
	}

	static function TestParenthesizeExpressionStatement2():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewFunctionExpression(
						null, /*modifiers*/
						null, /*asteriskToken*/
						null, /*name*/
						null, /*typeParameters*/
						factory.NewNodeList(
							[]
						),
						null, /*returnType*/
						null, /*fullSignature*/
						factory.NewBlock(
							factory.NewNodeList([]),
							false /*multiLine*/
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "(function () { });");
	}

	static function TestParenthesizeExpressionStatement3():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExpressionStatement(
					factory.NewClassExpression(
						null, /*modifiers*/
						null, /*name*/
						null, /*typeParameters*/
						null, /*heritageClauses*/
						factory.NewNodeList(
							[]
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "class {\n};");
	}

	static function TestParenthesizeExpressionDefault1():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExportAssignment(
					null,   /*modifiers*/
					false, /*isExportEquals*/
					null,   /*typeNode*/
					// will be parenthesized on emit:
					factory.NewClassExpression(
						null, /*modifiers*/
						null, /*name*/
						null, /*typeParameters*/
						null, /*heritageClauses*/
						factory.NewNodeList(
							[]
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "export default (class {\n});");
	}

	static function TestParenthesizeExpressionDefault2():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExportAssignment(
					null,   /*modifiers*/
					false, /*isExportEquals*/
					null,   /*typeNode*/
					// will be parenthesized on emit:
					factory.NewFunctionExpression(
						null, /*modifiers*/
						null, /*asteriskToken*/
						null, /*name*/
						null, /*typeParameters*/
						factory.NewNodeList(
							[]
						),
						null, /*returnType*/
						null, /*fullSignature*/
						factory.NewBlock(
							factory.NewNodeList(
								[]
							),
							false /*multiLine*/
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "export default (function () { });");
	}

	static function TestParenthesizeExpressionDefault3():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewExportAssignment(
					null,   /*modifiers*/
					false, /*isExportEquals*/
					null,   /*typeNode*/
					// will be parenthesized on emit:
					factory.NewBinaryExpression(
						null, /*modifiers*/
						factory.NewIdentifier("a"),
						null, /*typeNode*/
						factory.NewToken(KindCommaToken),
						factory.NewIdentifier("b")
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "export default (a, b);");
	}

	static function TestParenthesizeArrayType():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewTypeAliasDeclaration(
					null,                        /*modifiers*/
					factory.NewIdentifier("_"), /*name*/
					null,                        /*typeParameters*/
					factory.NewArrayTypeNode(
						// will be parenthesized on emit:
						factory.NewUnionTypeNode(
							factory.NewNodeList(
								[
									factory.NewTypeReferenceNode(factory.NewIdentifier("a"), null /*typeArguments*/),
									factory.NewTypeReferenceNode(factory.NewIdentifier("b"), null /*typeArguments*/)
								]
							)
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "type _ = (a | b)[];");
	}

	static function TestParenthesizeOptionalType():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewTypeAliasDeclaration(
					null,                        /*modifiers*/
					factory.NewIdentifier("_"), /*name*/
					null,                        /*typeParameters*/
					factory.NewTupleTypeNode(
						factory.NewNodeList(
							[
								factory.NewOptionalTypeNode(
									// will be parenthesized on emit:
									factory.NewUnionTypeNode(
										factory.NewNodeList(
											[
												factory.NewTypeReferenceNode(factory.NewIdentifier("a"), null /*typeArguments*/),
												factory.NewTypeReferenceNode(factory.NewIdentifier("b"), null /*typeArguments*/)
											]
										)
									)
								)
							]
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "type _ = [\n    (a | b)?\n];");
	}

	static function TestParenthesizeUnionType1():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewTypeAliasDeclaration(
					null,                        /*modifiers*/
					factory.NewIdentifier("_"), /*name*/
					null,                        /*typeParameters*/
					factory.NewUnionTypeNode(
						factory.NewNodeList(
							[
								factory.NewTypeReferenceNode(factory.NewIdentifier("a"), null /*typeArguments*/),
								// will be parenthesized on emit:
								factory.NewFunctionTypeNode(
									null, /*typeParameters*/
									factory.NewNodeList(
										[]
									),
									factory.NewTypeReferenceNode(factory.NewIdentifier("b"), null /*typeArguments*/)
								)
							]
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "type _ = a | (() => b);");
	}

	static function TestParenthesizeUnionType2():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewTypeAliasDeclaration(
					null,                        /*modifiers*/
					factory.NewIdentifier("_"), /*name*/
					null,                        /*typeParameters*/
					factory.NewUnionTypeNode(
						factory.NewNodeList(
							[
								// will be parenthesized on emit:
								factory.NewInferTypeNode(
									factory.NewTypeParameterDeclaration(
										null,
										factory.NewIdentifier("a"),
										factory.NewTypeReferenceNode(factory.NewIdentifier("b"), null /*typeArguments*/),
										null, /*expression*/
										null /*defaultType*/
									)
								),
								factory.NewTypeReferenceNode(factory.NewIdentifier("c"), null /*typeArguments*/)
							]
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "type _ = (infer a extends b) | c;");
	}

	static function TestParenthesizeIntersectionType():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewTypeAliasDeclaration(
					null,                        /*modifiers*/
					factory.NewIdentifier("_"), /*name*/
					null,                        /*typeParameters*/
					factory.NewIntersectionTypeNode(
						factory.NewNodeList(
							[
								factory.NewTypeReferenceNode(factory.NewIdentifier("a"), null /*typeArguments*/),
								// will be parenthesized on emit:
								factory.NewUnionTypeNode(
									factory.NewNodeList(
										[
											factory.NewTypeReferenceNode(factory.NewIdentifier("b"), null /*typeArguments*/),
											factory.NewTypeReferenceNode(factory.NewIdentifier("c"), null /*typeArguments*/)
										]
									)
								)
							]
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "type _ = a & (b | c);");
	}

	static function TestParenthesizeReadonlyTypeOperator1():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewTypeAliasDeclaration(
					null,                        /*modifiers*/
					factory.NewIdentifier("_"), /*name*/
					null,                        /*typeParameters*/
					factory.NewTypeOperatorNode(
						KindReadonlyKeyword,
						// will be parenthesized on emit:
						factory.NewUnionTypeNode(
							factory.NewNodeList(
								[
									factory.NewTypeReferenceNode(factory.NewIdentifier("a"), null /*typeArguments*/),
									factory.NewTypeReferenceNode(factory.NewIdentifier("b"), null /*typeArguments*/)
								]
							)
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "type _ = readonly (a | b);");
	}

	static function TestParenthesizeReadonlyTypeOperator2():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewTypeAliasDeclaration(
					null,                        /*modifiers*/
					factory.NewIdentifier("_"), /*name*/
					null,                        /*typeParameters*/
					factory.NewTypeOperatorNode(
						KindReadonlyKeyword,
						// will be parenthesized on emit:
						factory.NewTypeOperatorNode(
							KindKeyOfKeyword,
							factory.NewTypeReferenceNode(factory.NewIdentifier("a"), null /*typeArguments*/)
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "type _ = readonly (keyof a);");
	}

	static function TestParenthesizeKeyofTypeOperator():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewTypeAliasDeclaration(
					null,                        /*modifiers*/
					factory.NewIdentifier("_"), /*name*/
					null,                        /*typeParameters*/
					factory.NewTypeOperatorNode(
						KindKeyOfKeyword,
						// will be parenthesized on emit:
						factory.NewUnionTypeNode(
							factory.NewNodeList(
								[
									factory.NewTypeReferenceNode(factory.NewIdentifier("a"), null /*typeArguments*/),
									factory.NewTypeReferenceNode(factory.NewIdentifier("b"), null /*typeArguments*/)
								]
							)
						)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "type _ = keyof (a | b);");
	}

	static function TestParenthesizeIndexedAccessType():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewTypeAliasDeclaration(
					null,                        /*modifiers*/
					factory.NewIdentifier("_"), /*name*/
					null,                        /*typeParameters*/
					factory.NewIndexedAccessTypeNode(
						// will be parenthesized on emit:
						factory.NewUnionTypeNode(
							factory.NewNodeList(
								[
									factory.NewTypeReferenceNode(factory.NewIdentifier("a"), null /*typeArguments*/),
									factory.NewTypeReferenceNode(factory.NewIdentifier("b"), null /*typeArguments*/)
								]
							)
						),
						factory.NewTypeReferenceNode(factory.NewIdentifier("c"), null /*typeArguments*/)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "type _ = (a | b)[c];");
	}

	static function TestParenthesizeConditionalType1():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewTypeAliasDeclaration(
					null,                        /*modifiers*/
					factory.NewIdentifier("_"), /*name*/
					null,                        /*typeParameters*/
					factory.NewConditionalTypeNode(
						// will be parenthesized on emit:
						factory.NewFunctionTypeNode(
							null, /*typeParameters*/
							factory.NewNodeList(
								[]
							),
							factory.NewTypeReferenceNode(factory.NewIdentifier("a"), null /*typeArguments*/)
						),
						factory.NewTypeReferenceNode(factory.NewIdentifier("b"), null /*typeArguments*/),
						factory.NewTypeReferenceNode(factory.NewIdentifier("c"), null /*typeArguments*/),
						factory.NewTypeReferenceNode(factory.NewIdentifier("d"), null /*typeArguments*/)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "type _ = (() => a) extends b ? c : d;");
	}

	static function TestParenthesizeConditionalType2():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewTypeAliasDeclaration(
					null,                        /*modifiers*/
					factory.NewIdentifier("_"), /*name*/
					null,                        /*typeParameters*/
					factory.NewConditionalTypeNode(
						factory.NewTypeReferenceNode(factory.NewIdentifier("a"), null /*typeArguments*/),
						// will be parenthesized on emit:
						factory.NewConditionalTypeNode(
							factory.NewTypeReferenceNode(factory.NewIdentifier("b"), null /*typeArguments*/),
							factory.NewTypeReferenceNode(factory.NewIdentifier("c"), null /*typeArguments*/),
							factory.NewTypeReferenceNode(factory.NewIdentifier("d"), null /*typeArguments*/),
							factory.NewTypeReferenceNode(factory.NewIdentifier("e"), null /*typeArguments*/)
						),
						factory.NewTypeReferenceNode(factory.NewIdentifier("f"), null /*typeArguments*/),
						factory.NewTypeReferenceNode(factory.NewIdentifier("g"), null /*typeArguments*/)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "type _ = a extends (b extends c ? d : e) ? f : g;");
	}

	static function TestParenthesizeConditionalType3():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
			[
				factory.NewTypeAliasDeclaration(
					null,                        /*modifiers*/
					factory.NewIdentifier("_"), /*name*/
					null,                        /*typeParameters*/
					factory.NewConditionalTypeNode(
						factory.NewTypeReferenceNode(factory.NewIdentifier("a"), null /*typeArguments*/),
						factory.NewFunctionTypeNode(
							null, /*typeParameters*/
							factory.NewNodeList(
								[]
							),
							// will be parenthesized on emit:
							factory.NewInferTypeNode(
								factory.NewTypeParameterDeclaration(
									null,
									factory.NewIdentifier("b"),
									factory.NewTypeReferenceNode(factory.NewIdentifier("c"), null /*typeArguments*/),
									null, /*expression*/
									null /*defaultType*/
								)
							)
						),
						factory.NewTypeReferenceNode(factory.NewIdentifier("d"), null /*typeArguments*/),
						factory.NewTypeReferenceNode(factory.NewIdentifier("e"), null /*typeArguments*/)
					)
				)
			]
		), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "type _ = a extends () => (infer b extends c) ? d : e;");
	}

	static function TestParenthesizeConditionalType4():Void {

		final factory = new ts.ast.Ast.NodeFactory();
		final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList([
			factory.NewTypeAliasDeclaration(
				null,                        /*modifiers*/
				factory.NewIdentifier("_"), /*name*/
				null,                        /*typeParameters*/
				factory.NewConditionalTypeNode(
					factory.NewTypeReferenceNode(factory.NewIdentifier("a"), null /*typeArguments*/),
					factory.NewFunctionTypeNode(
						null, /*typeParameters*/
						factory.NewNodeList(
							[]
						),
						// will be parenthesized on emit:
						factory.NewUnionTypeNode(
							factory.NewNodeList(
								[
									factory.NewInferTypeNode(
										factory.NewTypeParameterDeclaration(
											null,
											factory.NewIdentifier("b"),
											factory.NewTypeReferenceNode(factory.NewIdentifier("c"), null /*typeArguments*/),
											null, /*expression*/
											null /*defaultType*/
										)
									),
									factory.NewTypeReferenceNode(factory.NewIdentifier("d"), null /*typeArguments*/)
								]
							)
						)
					),
					factory.NewTypeReferenceNode(factory.NewIdentifier("e"), null /*typeArguments*/),
					factory.NewTypeReferenceNode(factory.NewIdentifier("f"), null /*typeArguments*/)
				)
			)
		]), factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(null, file.AsSourceFile(), "type _ = a extends () => (infer b extends c) | d ? e : f;");
	}

	static function TestNameGeneration():Void {
		final ec = Printer.NewEmitContext();
		final file = ec.Factory.NewSourceFile(fileOpts(), "", ec.Factory.NewNodeList([
			ec.Factory.NewVariableStatement(null, ec.Factory.NewVariableDeclarationList(
				ec.Factory.NewNodeList([
					ec.Factory.NewVariableDeclaration(ec.Factory.NewTempVariable(), null, null, null),
				]),
				NodeFlagsNone
			)),
			ec.Factory.NewFunctionDeclaration(
				null,
				null,
				ec.Factory.NewIdentifier("f"),
				null,
				ec.Factory.NewNodeList([]),
				null,
				null,
				ec.Factory.NewBlock(ec.Factory.NewNodeList([
					ec.Factory.NewVariableStatement(null, ec.Factory.NewVariableDeclarationList(
						ec.Factory.NewNodeList([
							ec.Factory.NewVariableDeclaration(ec.Factory.NewTempVariable(), null, null, null),
						]),
						NodeFlagsNone
					)),
				]), true)
			),
		]), ec.Factory.NewToken(KindEndOfFile));

		Parsetestutil.MarkSyntheticRecursive(file);
		Emittestutil.CheckEmit(ec, file.AsSourceFile(), "var _a;\nfunction f() {\n    var _a;\n}");
	}

	static function TestNoTrailingCommaAfterTransform():Void {
		var file = Parsetestutil.ParseTypeScript("[a!]", false /*jsx*/);
		final emitContext = Printer.NewEmitContext();

		var visitor:NodeVisitor = null;
		visitor = emitContext.NewNodeVisitor(function(node:Node):Node {
			switch (node.Kind) {
				case KindNonNullExpression:
					node = node.Expression();
				default:
					node = node.VisitEachChild(visitor);
			}
			return node;
		});
		file = visitor.VisitSourceFile(file);

		Emittestutil.CheckEmit(emitContext, file.AsNode().AsSourceFile(), "[a];");
	}

	static function TestTrailingCommaAfterTransform():Void {
		var file = Parsetestutil.ParseTypeScript("[a!,]", false /*jsx*/);
		final emitContext = Printer.NewEmitContext();

		var visitor:NodeVisitor = null;
		visitor = emitContext.NewNodeVisitor(function(node:Node):Node {
			switch (node.Kind) {
				case KindNonNullExpression:
					node = node.Expression();
				default:
					node = node.VisitEachChild(visitor);
			}
			return node;
		});
		file = visitor.VisitSourceFile(file);

		Emittestutil.CheckEmit(emitContext, file.AsNode().AsSourceFile(), "[a,];");
	}

	// PORT: skipped, needs transformers (tstransforms.NewTypeEraserTransformer)
	// func TestPartiallyEmittedExpression(t *testing.T) {
	// 	t.Parallel()
	//
	// 	compilerOptions := &core.CompilerOptions{}
	//
	// 	file := parsetestutil.ParseTypeScript(`return ((container.parent
	//     .left as PropertyAccessExpression)
	//     .expression as PropertyAccessExpression)
	//     .expression;`, false /*jsx*/)
	//
	// 	emitContext := printer.NewEmitContext()
	// 	file = tstransforms.NewTypeEraserTransformer(&transformers.TransformOptions{CompilerOptions: compilerOptions, Context: emitContext}).TransformSourceFile(file)
	// 	emittestutil.CheckEmit(t, emitContext, file.AsSourceFile(), `return container.parent
	//     .left
	//     .expression
	//     .expression;`)
	// }

	static function TestParenthesizeBinaryExpressionMixingNullishCoalescing():Void {
		final tests:Array<MixingRow> = [
			// inner ?? on left side of || or &&
			new MixingRow("BarBarWithLeftQuestionQuestion", KindQuestionQuestionToken, KindBarBarToken, "left", "(a ?? b) || c;"),
			new MixingRow("AmpersandAmpersandWithLeftQuestionQuestion", KindQuestionQuestionToken, KindAmpersandAmpersandToken, "left", "(a ?? b) && c;"),
			// inner ?? on right side of || or &&
			new MixingRow("BarBarWithRightQuestionQuestion", KindQuestionQuestionToken, KindBarBarToken, "right", "a || (b ?? c);"),
			new MixingRow("AmpersandAmpersandWithRightQuestionQuestion", KindQuestionQuestionToken, KindAmpersandAmpersandToken, "right", "a && (b ?? c);"),
			// inner || or && on left side of ??
			new MixingRow("QuestionQuestionWithLeftBarBar", KindBarBarToken, KindQuestionQuestionToken, "left", "(a || b) ?? c;"),
			new MixingRow("QuestionQuestionWithLeftAmpersandAmpersand", KindAmpersandAmpersandToken, KindQuestionQuestionToken, "left", "(a && b) ?? c;"),
			// inner || or && on right side of ??
			new MixingRow("QuestionQuestionWithRightBarBar", KindBarBarToken, KindQuestionQuestionToken, "right", "a ?? (b || c);"),
			new MixingRow("QuestionQuestionWithRightAmpersandAmpersand", KindAmpersandAmpersandToken, KindQuestionQuestionToken, "right", "a ?? (b && c);"),
		];

		for (tt in tests) {
			T.run("TestParenthesizeBinaryExpressionMixingNullishCoalescing/" + tt.title, function() {
				final factory = new ts.ast.Ast.NodeFactory();
				final innerExpr = factory.NewBinaryExpression(
					null, /*modifiers*/
					factory.NewIdentifier("a"),
					null, /*typeNode*/
					factory.NewToken(tt.innerOp),
					factory.NewIdentifier("b")
				);
				var outerExpr:Node = null;
				if (tt.side == "left") {
					outerExpr = factory.NewBinaryExpression(
						null, /*modifiers*/
						innerExpr, /*left: (a innerOp b)*/
						null, /*typeNode*/
						factory.NewToken(tt.outerOp),
						factory.NewIdentifier("c")
					);
				} else {
					outerExpr = factory.NewBinaryExpression(
						null, /*modifiers*/
						factory.NewIdentifier("a"),
						null, /*typeNode*/
						factory.NewToken(tt.outerOp),
						innerExpr /*right: (b innerOp c)*/
					);
					// adjust identifiers for right side
					innerExpr.AsBinaryExpression().Left = factory.NewIdentifier("b");
					innerExpr.AsBinaryExpression().Right = factory.NewIdentifier("c");
				}
				final file = factory.NewSourceFile(fileOpts(), "", factory.NewNodeList(
					[
						factory.NewExpressionStatement(outerExpr),
					]
				), factory.NewToken(KindEndOfFile));

				Parsetestutil.MarkSyntheticRecursive(file);
				Emittestutil.CheckEmit(null, file.AsSourceFile(), tt.output);
			});
		}
	}
}
