package ts.transformers.tstransforms;

// Port of internal/transformers/tstransforms/typeeraser_test.go.
private class TypeEraserCase {
	public final title:std.String;
	public final input:std.String;
	public final output:std.String;
	public final jsx:Bool;
	public final vms:Bool;

	public function new(title:std.String, input:std.String, output:std.String, jsx:Bool = false, vms:Bool = false) {
		this.title = title;
		this.input = input;
		this.output = output;
		this.jsx = jsx;
		this.vms = vms;
	}
}

class TypeeraserTest {
	public static function run() {
		T.run("TestTypeEraser", TestTypeEraser);
	}

	static function TestTypeEraser() {
		final data = [
			new TypeEraserCase("Modifiers", "class C { public x; private y }", "class C {\n    x;\n    y;\n}"),
			new TypeEraserCase("InterfaceDeclaration", "interface I { }", ""),
			new TypeEraserCase("TypeAliasDeclaration", "type T = U;", ""),
			new TypeEraserCase("NamespaceExportDeclaration", "export as namespace N;", ""),
			new TypeEraserCase("UninstantiatedNamespace1", "namespace N {}", ""),
			new TypeEraserCase("UninstantiatedNamespace2", "namespace N { export interface I {} }", ""),
			new TypeEraserCase("UninstantiatedNamespace3", "namespace N { export type T = U; }", ""),
			new TypeEraserCase("ExpressionWithTypeArguments", "F<T>", "F;"),
			new TypeEraserCase("PropertyDeclaration1", "class C { declare x; }", "class C {\n}"),
			new TypeEraserCase("PropertyDeclaration2", "class C { public x: number; }", "class C {\n    x;\n}"),
			new TypeEraserCase("PropertyDeclaration3", "class C { public static x: number; }", "class C {\n    static x;\n}"),
			new TypeEraserCase("ConstructorDeclaration1", "class C { constructor(); }", "class C {\n}"),
			new TypeEraserCase("ConstructorDeclaration2", "class C { public constructor() {} }", "class C {\n    constructor() { }\n}"),
			new TypeEraserCase("MethodDeclaration1", "class C { m(); }", "class C {\n}"),
			new TypeEraserCase("MethodDeclaration2", "class C { public m<T>(): U {} }", "class C {\n    m() { }\n}"),
			new TypeEraserCase("MethodDeclaration3", "class C { public static m<T>(): U {} }", "class C {\n    static m() { }\n}"),
			new TypeEraserCase("GetAccessorDeclaration1", "class C { get m(); }", "class C {\n    get m() { }\n}"),
			new TypeEraserCase("GetAccessorDeclaration2", "class C { public get m<T>(): U {} }", "class C {\n    get m() { }\n}"),
			new TypeEraserCase("GetAccessorDeclaration3", "class C { public static get m<T>(): U {} }", "class C {\n    static get m() { }\n}"),
			new TypeEraserCase("SetAccessorDeclaration1", "class C { set m(v); }", "class C {\n    set m(v) { }\n}"),
			new TypeEraserCase("SetAccessorDeclaration2", "class C { public set m<T>(v): U {} }", "class C {\n    set m(v) { }\n}"),
			new TypeEraserCase("SetAccessorDeclaration3", "class C { public static set m<T>(v): U {} }", "class C {\n    static set m(v) { }\n}"),
			new TypeEraserCase("IndexSignature", "class C { [key: string]: number; }", "class C {\n}"),
			new TypeEraserCase("VariableDeclaration1", "declare var a;", ""),
			new TypeEraserCase("VariableDeclaration2", "var a: number", "var a;"),
			new TypeEraserCase("HeritageClause", "class C implements I {}", "class C {\n}"),
			new TypeEraserCase("ClassDeclaration1", "declare class C {}", ""),
			new TypeEraserCase("ClassDeclaration2", "class C<T> {}", "class C {\n}"),
			new TypeEraserCase("ClassExpression", "(class C<T> {})", "(class C {\n});"),
			new TypeEraserCase("FunctionDeclaration1", "declare function f() {}", ""),
			new TypeEraserCase("FunctionDeclaration2", "function f();", ""),
			new TypeEraserCase("FunctionDeclaration3", "function f<T>(): U {}", "function f() { }"),
			new TypeEraserCase("FunctionExpression", "(function f<T>(): U {})", "(function f() { });"),
			new TypeEraserCase("ArrowFunction", "(<T>(): U => {})", "(() => { });"),
			new TypeEraserCase("ParameterDeclaration", "function f(this: x, a: number, b?: boolean) {}", "function f(a, b) { }"),
			new TypeEraserCase("CallExpression", "f<T>()", "f();"),
			new TypeEraserCase("NewExpression1", "new f<T>()", "new f();"),
			new TypeEraserCase("NewExpression2", "new f<T>", "new f;"),
			new TypeEraserCase("TaggedTemplateExpression", "f<T>``", "f ``;"),
			new TypeEraserCase("NonNullExpression", "x!", "x;"),
			new TypeEraserCase("TypeAssertionExpression#1", "<T>x", "x;"),
			new TypeEraserCase("TypeAssertionExpression#2", "(<T>x).c", "x.c;"),
			new TypeEraserCase("AsExpression#1", "x as T", "x;"),
			new TypeEraserCase("AsExpression#2", "(x as T).c", "x.c;"),
			new TypeEraserCase("SatisfiesExpression#1", "x satisfies T", "x;"),
			new TypeEraserCase("SatisfiesExpression#2", "(x satisfies T).c", "x.c;"),
			new TypeEraserCase("JsxSelfClosingElement", "<x<T> />", "<x />;", true),
			new TypeEraserCase("JsxOpeningElement", "<x<T>></x>", "<x></x>;", true),
			new TypeEraserCase("ImportEqualsDeclaration#1", "import x = require(\"m\");", "import x = require(\"m\");"),
			new TypeEraserCase("ImportEqualsDeclaration#2", "import type x = require(\"m\");", ""),
			new TypeEraserCase("ImportEqualsDeclaration#3", "import x = y;", "import x = y;"),
			new TypeEraserCase("ImportEqualsDeclaration#4", "import type x = y;", ""),
			new TypeEraserCase("ImportDeclaration#1", "import \"m\";", "import \"m\";"),
			new TypeEraserCase("ImportDeclaration#2", "import * as x from \"m\"; x;", "import * as x from \"m\";\nx;"),
			new TypeEraserCase("ImportDeclaration#3", "import x from \"m\"; x;", "import x from \"m\";\nx;"),
			new TypeEraserCase("ImportDeclaration#4", "import { x } from \"m\"; x;", "import { x } from \"m\";\nx;"),
			new TypeEraserCase("ImportDeclaration#5", "import type * as x from \"m\";", ""),
			new TypeEraserCase("ImportDeclaration#6", "import type x from \"m\";", ""),
			new TypeEraserCase("ImportDeclaration#7", "import type { x } from \"m\";", ""),
			new TypeEraserCase("ImportDeclaration#8", "import { type x } from \"m\";", ""),
			new TypeEraserCase("ImportDeclaration#9", "import { type x } from \"m\";", "import {} from \"m\";", false, true),
			new TypeEraserCase("ExportDeclaration#1", "export * from \"m\";", "export * from \"m\";"),
			new TypeEraserCase("ExportDeclaration#2", "export * as x from \"m\";", "export * as x from \"m\";"),
			new TypeEraserCase("ExportDeclaration#3", "export { x } from \"m\";", "export { x } from \"m\";"),
			new TypeEraserCase("ExportDeclaration#4", "export type * from \"m\";", ""),
			new TypeEraserCase("ExportDeclaration#5", "export type * as x from \"m\";", ""),
			new TypeEraserCase("ExportDeclaration#6", "export type { x } from \"m\";", ""),
			new TypeEraserCase("ExportDeclaration#7", "export { type x } from \"m\";", ""),
			new TypeEraserCase("ExportDeclaration#7", "export { type x } from \"m\";", "export {} from \"m\";", false, true),
		];

		for (rec in data) {
			T.run("TestTypeEraser/" + rec.title, () -> {
				final file = Parsetestutil.ParseTypeScript(rec.input, rec.jsx);
				Parsetestutil.CheckDiagnostics(file);
				final compilerOptions = new CompilerOptions();
				if (rec.vms) {
					compilerOptions.VerbatimModuleSyntax = TSTrue;
				}
				final opts = new TransformOptions();
				opts.CompilerOptions = compilerOptions;
				opts.Context = Printer.NewEmitContext();
				Emittestutil.CheckEmit(null, Tstransforms.NewTypeEraserTransformer(opts).TransformSourceFile(file), rec.output);
			});
		}
	}
}
