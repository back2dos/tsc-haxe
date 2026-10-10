package ts.printer;

// Port of internal/printer/namegenerator_test.go (package printer_test).
class NamegeneratorTest {
	// Go method expression `(*ast.Node).Text`.
	static final fn_Text:(node:Node) -> std.String = (node:Node) -> node.Text();

	public static function run() {
		T.run("TestTempVariable1", TestTempVariable1);
		T.run("TestTempVariable2", TestTempVariable2);
		T.run("TestTempVariable3", TestTempVariable3);
		T.run("TestTempVariableScoped", TestTempVariableScoped);
		T.run("TestTempVariableScopedReserved", TestTempVariableScopedReserved);
		T.run("TestLoopVariable1", TestLoopVariable1);
		T.run("TestLoopVariable2", TestLoopVariable2);
		T.run("TestLoopVariable3", TestLoopVariable3);
		T.run("TestLoopVariableScoped", TestLoopVariableScoped);
		T.run("TestUniqueName1", TestUniqueName1);
		T.run("TestUniqueName2", TestUniqueName2);
		T.run("TestUniqueNameScoped", TestUniqueNameScoped);
		T.run("TestUniquePrivateName1", TestUniquePrivateName1);
		T.run("TestUniquePrivateName2", TestUniquePrivateName2);
		T.run("TestUniquePrivateNameScoped", TestUniquePrivateNameScoped);
		T.run("TestGeneratedNameForIdentifier1", TestGeneratedNameForIdentifier1);
		T.run("TestGeneratedNameForIdentifier2", TestGeneratedNameForIdentifier2);
		T.run("TestGeneratedNameForIdentifier3", TestGeneratedNameForIdentifier3);
		T.run("TestGeneratedNameForNamespace1", TestGeneratedNameForNamespace1);
		T.run("TestGeneratedNameForNamespace2", TestGeneratedNameForNamespace2);
		T.run("TestGeneratedNameForNamespace3", TestGeneratedNameForNamespace3);
		T.run("TestGeneratedNameForNamespace4", TestGeneratedNameForNamespace4);
		T.run("TestGeneratedNameForNodeCached", TestGeneratedNameForNodeCached);
		T.run("TestGeneratedNameForImport", TestGeneratedNameForImport);
		T.run("TestGeneratedNameForExport", TestGeneratedNameForExport);
		T.run("TestGeneratedNameForFunctionDeclaration1", TestGeneratedNameForFunctionDeclaration1);
		T.run("TestGeneratedNameForFunctionDeclaration2", TestGeneratedNameForFunctionDeclaration2);
		T.run("TestGeneratedNameForClassDeclaration1", TestGeneratedNameForClassDeclaration1);
		T.run("TestGeneratedNameForClassDeclaration2", TestGeneratedNameForClassDeclaration2);
		T.run("TestGeneratedNameForExportAssignment", TestGeneratedNameForExportAssignment);
		T.run("TestGeneratedNameForClassExpression", TestGeneratedNameForClassExpression);
		T.run("TestGeneratedNameForMethod1", TestGeneratedNameForMethod1);
		T.run("TestGeneratedNameForMethod2", TestGeneratedNameForMethod2);
		T.run("TestGeneratedPrivateNameForMethod", TestGeneratedPrivateNameForMethod);
		T.run("TestGeneratedNameForComputedPropertyName", TestGeneratedNameForComputedPropertyName);
		T.run("TestGeneratedNameForOther", TestGeneratedNameForOther);
	}

	static function TestTempVariable1():Void {

		final ec = Printer.NewEmitContext();
		final name1 = ec.Factory.NewTempVariable();
		final name2 = ec.Factory.NewTempVariable();

		final g = new NameGenerator();
		g.Context = ec;
		final text1 = g.GenerateName(name1);
		final text2 = g.GenerateName(name2);

		T.eq("_a", text1);
		T.eq("_b", text2);
	}

	static function TestTempVariable2():Void {

		final ec = Printer.NewEmitContext();
		final name1 = ec.Factory.NewTempVariableEx(new AutoGenerateOptions(GeneratedIdentifierFlagsNone, "A", "B"));
		final name2 = ec.Factory.NewTempVariableEx(new AutoGenerateOptions(GeneratedIdentifierFlagsNone, "A", "B"));

		final g = new NameGenerator();
		g.Context = ec;
		final text1 = g.GenerateName(name1);
		final text2 = g.GenerateName(name2);

		T.eq("A_aB", text1);
		T.eq("A_bB", text2);
	}

	static function TestTempVariable3():Void {

		final ec = Printer.NewEmitContext();
		final name1 = ec.Factory.NewTempVariable();

		final g = new NameGenerator();
		g.Context = ec;
		final text1 = g.GenerateName(name1);
		final text2 = g.GenerateName(name1);

		T.eq("_a", text1);
		T.eq("_a", text2);
	}

	static function TestTempVariableScoped():Void {

		final ec = Printer.NewEmitContext();
		final name1 = ec.Factory.NewTempVariable();
		final name2 = ec.Factory.NewTempVariable();

		final g = new NameGenerator();
		g.Context = ec;
		final text1 = g.GenerateName(name1);
		g.PushScope(false);
		final text2 = g.GenerateName(name2);
		g.PopScope(false);

		T.eq("_a", text1);
		T.eq("_a", text2);
	}

	static function TestTempVariableScopedReserved():Void {

		final ec = Printer.NewEmitContext();
		final name1 = ec.Factory.NewTempVariableEx(new AutoGenerateOptions(GeneratedIdentifierFlagsReservedInNestedScopes, "", ""));
		final name2 = ec.Factory.NewTempVariable();

		final g = new NameGenerator();
		g.Context = ec;
		final text1 = g.GenerateName(name1);
		g.PushScope(false);
		final text2 = g.GenerateName(name2);
		g.PopScope(false);

		T.eq("_a", text1);
		T.eq("_b", text2);
	}

	static function TestLoopVariable1():Void {

		final ec = Printer.NewEmitContext();
		final name1 = ec.Factory.NewLoopVariable();
		final name2 = ec.Factory.NewLoopVariable();

		final g = new NameGenerator();
		g.Context = ec;
		final text1 = g.GenerateName(name1);
		final text2 = g.GenerateName(name2);

		T.eq("_i", text1);
		T.eq("_a", text2);
	}

	static function TestLoopVariable2():Void {

		final ec = Printer.NewEmitContext();
		final name1 = ec.Factory.NewLoopVariableEx(new AutoGenerateOptions(GeneratedIdentifierFlagsNone, "A", "B"));
		final name2 = ec.Factory.NewLoopVariableEx(new AutoGenerateOptions(GeneratedIdentifierFlagsNone, "A", "B"));

		final g = new NameGenerator();
		g.Context = ec;
		final text1 = g.GenerateName(name1);
		final text2 = g.GenerateName(name2);

		T.eq("A_iB", text1);
		T.eq("A_aB", text2);
	}

	static function TestLoopVariable3():Void {

		final ec = Printer.NewEmitContext();
		final name1 = ec.Factory.NewLoopVariable();

		final g = new NameGenerator();
		g.Context = ec;
		final text1 = g.GenerateName(name1);
		final text2 = g.GenerateName(name1);

		T.eq("_i", text1);
		T.eq("_i", text2);
	}

	static function TestLoopVariableScoped():Void {

		final ec = Printer.NewEmitContext();
		final name1 = ec.Factory.NewLoopVariable();
		final name2 = ec.Factory.NewLoopVariable();

		final g = new NameGenerator();
		g.Context = ec;
		final text1 = g.GenerateName(name1);
		g.PushScope(false);
		final text2 = g.GenerateName(name2);
		g.PopScope(false);

		T.eq("_i", text1);
		T.eq("_i", text2);
	}

	static function TestUniqueName1():Void {

		final ec = Printer.NewEmitContext();
		final name1 = ec.Factory.NewUniqueName("foo");
		final name2 = ec.Factory.NewUniqueName("foo");

		final g = new NameGenerator();
		g.Context = ec;
		final text1 = g.GenerateName(name1);
		final text2 = g.GenerateName(name2);

		T.eq("foo_1", text1);
		T.eq("foo_2", text2);
	}

	static function TestUniqueName2():Void {

		final ec = Printer.NewEmitContext();
		final name1 = ec.Factory.NewUniqueName("foo");

		final g = new NameGenerator();
		g.Context = ec;
		final text1 = g.GenerateName(name1);
		final text2 = g.GenerateName(name1);

		T.eq("foo_1", text1);
		// Expected to be same because GenerateName goes off object identity
		T.eq("foo_1", text2);
	}

	static function TestUniqueNameScoped():Void {

		final ec = Printer.NewEmitContext();
		final name1 = ec.Factory.NewUniqueName("foo");
		final name2 = ec.Factory.NewUniqueName("foo");

		final g = new NameGenerator();
		g.Context = ec;
		T.eq("foo_1", g.GenerateName(name1));

		g.PushScope(false);
		T.eq("foo_2", g.GenerateName(name2)); // Matches Strada, but is incorrect
		// T.eq("foo_1", g.GenerateName(name2)); // TODO: Fix after Strada port is complete.
		g.PopScope(false);
	}

	static function TestUniquePrivateName1():Void {

		final ec = Printer.NewEmitContext();
		final name1 = ec.Factory.NewUniquePrivateName("#foo");
		final name2 = ec.Factory.NewUniquePrivateName("#foo");

		final g = new NameGenerator();
		g.Context = ec;
		final text1 = g.GenerateName(name1);
		final text2 = g.GenerateName(name2);

		T.eq("#foo_1", text1);
		T.eq("#foo_2", text2);
	}

	static function TestUniquePrivateName2():Void {

		final ec = Printer.NewEmitContext();
		final name1 = ec.Factory.NewUniquePrivateName("#foo");

		final g = new NameGenerator();
		g.Context = ec;
		final text1 = g.GenerateName(name1);
		final text2 = g.GenerateName(name1);

		T.eq("#foo_1", text1);
		T.eq("#foo_1", text2);
	}

	static function TestUniquePrivateNameScoped():Void {

		final ec = Printer.NewEmitContext();
		final name1 = ec.Factory.NewUniquePrivateName("#foo");
		final name2 = ec.Factory.NewUniquePrivateName("#foo");

		final g = new NameGenerator();
		g.Context = ec;
		T.eq("#foo_1", g.GenerateName(name1));

		g.PushScope(false); // private names are always reserved in nested scopes
		T.eq("#foo_2", g.GenerateName(name2));
		g.PopScope(false);
	}

	static function TestGeneratedNameForIdentifier1():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("function f() {}", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = file.Statements.Nodes[0].Name();
		final name1 = ec.Factory.NewGeneratedNameForNode(n);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("f_1", text1);
	}

	static function TestGeneratedNameForIdentifier2():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("function f() {}", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = file.Statements.Nodes[0].Name();
		final name1 = ec.Factory.NewGeneratedNameForNodeEx(n, new AutoGenerateOptions(GeneratedIdentifierFlagsNone, "a", "b"));

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("afb", text1);
	}

	static function TestGeneratedNameForIdentifier3():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("function f() {}", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = file.Statements.Nodes[0].Name();
		final name1 = ec.Factory.NewGeneratedNameForNodeEx(n, new AutoGenerateOptions(GeneratedIdentifierFlagsNone, "a", "b"));
		final name2 = ec.Factory.NewGeneratedNameForNode(name1);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name2);

		T.eq("afb_1", text1);
	}

	// namespace reuses name if it does not collide with locals
	static function TestGeneratedNameForNamespace1():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("namespace foo { }", false /*jsx*/);
		Binder.BindSourceFile(file);

		final ns1 = file.Statements.Nodes[0];
		final name1 = ec.Factory.NewGeneratedNameForNode(ns1);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("foo", text1);
	}

	// namespace uses generated name if it collides with locals
	static function TestGeneratedNameForNamespace2():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("namespace foo { var foo; }", false /*jsx*/);
		Binder.BindSourceFile(file);

		final ns1 = file.Statements.Nodes[0];
		final name1 = ec.Factory.NewGeneratedNameForNode(ns1);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("foo_1", text1);
	}

	// avoids collisions when unscoped
	static function TestGeneratedNameForNamespace3():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("namespace ns1 { namespace foo { var foo; } } namespace ns2 { namespace foo { var foo; } }", false /*jsx*/);
		Binder.BindSourceFile(file);

		final ns1 = file.Statements.Nodes[0].Body().Statements()[0];
		final ns2 = file.Statements.Nodes[1].Body().Statements()[0];
		final name1 = ec.Factory.NewGeneratedNameForNode(ns1);
		final name2 = ec.Factory.NewGeneratedNameForNode(ns2);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);
		final text2 = g.GenerateName(name2);

		T.eq("foo_1", text1);
		T.eq("foo_2", text2);
	}

	// reuse name when scoped
	static function TestGeneratedNameForNamespace4():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("namespace ns1 { namespace foo { var foo; } } namespace ns2 { namespace foo { var foo; } }", false /*jsx*/);
		Binder.BindSourceFile(file);

		final ns1 = file.Statements.Nodes[0].Body().Statements()[0];
		final ns2 = file.Statements.Nodes[1].Body().Statements()[0];
		final name1 = ec.Factory.NewGeneratedNameForNode(ns1);
		final name2 = ec.Factory.NewGeneratedNameForNode(ns2);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		g.PushScope(false);
		final text1 = g.GenerateName(name1);
		g.PopScope(false);

		g.PushScope(false);
		final text2 = g.GenerateName(name2);
		g.PopScope(false);

		T.eq("foo_1", text1);
		T.eq("foo_2", text2); // Matches Strada, but is incorrect
		// T.eq("foo_1", text2); // TODO: Fix after Strada port is complete.
	}

	static function TestGeneratedNameForNodeCached():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("namespace foo { var foo; }", false /*jsx*/);
		Binder.BindSourceFile(file);

		final ns1 = file.Statements.Nodes[0];
		final name1 = ec.Factory.NewGeneratedNameForNode(ns1);
		final name2 = ec.Factory.NewGeneratedNameForNode(ns1);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);
		final text2 = g.GenerateName(name2);

		T.eq("foo_1", text1);
		T.eq("foo_1", text2);
	}

	static function TestGeneratedNameForImport():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("import * as foo from 'foo'", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = file.Statements.Nodes[0];
		final name1 = ec.Factory.NewGeneratedNameForNode(n);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("foo_1", text1);
	}

	static function TestGeneratedNameForExport():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("export * as foo from 'foo'", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = file.Statements.Nodes[0];
		final name1 = ec.Factory.NewGeneratedNameForNode(n);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("foo_1", text1);
	}

	static function TestGeneratedNameForFunctionDeclaration1():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("export function f() {}", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = file.Statements.Nodes[0];
		final name1 = ec.Factory.NewGeneratedNameForNode(n);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("f_1", text1);
	}

	static function TestGeneratedNameForFunctionDeclaration2():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("export default function () {}", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = file.Statements.Nodes[0];
		final name1 = ec.Factory.NewGeneratedNameForNode(n);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("default_1", text1);
	}

	static function TestGeneratedNameForClassDeclaration1():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("export class C {}", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = file.Statements.Nodes[0];
		final name1 = ec.Factory.NewGeneratedNameForNode(n);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("C_1", text1);
	}

	static function TestGeneratedNameForClassDeclaration2():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("export default class {}", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = file.Statements.Nodes[0];
		final name1 = ec.Factory.NewGeneratedNameForNode(n);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("default_1", text1);
	}

	static function TestGeneratedNameForExportAssignment():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("export default 0", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = file.Statements.Nodes[0];
		final name1 = ec.Factory.NewGeneratedNameForNode(n);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("default_1", text1);
	}

	static function TestGeneratedNameForClassExpression():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("(class {})", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = file.Statements.Nodes[0].Expression().Expression();
		final name1 = ec.Factory.NewGeneratedNameForNode(n);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("class_1", text1);
	}

	static function TestGeneratedNameForMethod1():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("class C { m() {} }", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = file.Statements.Nodes[0].Members()[0];
		final name1 = ec.Factory.NewGeneratedNameForNode(n);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("m_1", text1);
	}

	static function TestGeneratedNameForMethod2():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("class C { 0() {} }", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = file.Statements.Nodes[0].Members()[0];
		final name1 = ec.Factory.NewGeneratedNameForNode(n);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("_a", text1);
	}

	static function TestGeneratedPrivateNameForMethod():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("class C { m() {} }", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = file.Statements.Nodes[0].Members()[0];
		final name1 = ec.Factory.NewGeneratedPrivateNameForNode(n);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("#m_1", text1);
	}

	static function TestGeneratedNameForComputedPropertyName():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("class C { [x] }", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = file.Statements.Nodes[0].Members()[0].Name();
		final name1 = ec.Factory.NewGeneratedNameForNode(n);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("_a", text1);
	}

	static function TestGeneratedNameForOther():Void {

		final ec = Printer.NewEmitContext();

		final file = Parsetestutil.ParseTypeScript("class C { [x] }", false /*jsx*/);
		Binder.BindSourceFile(file);

		final n = ec.Factory.NewObjectLiteralExpression(
			ec.Factory.NewNodeList([]),
			false /*multiLine*/
		);
		final name1 = ec.Factory.NewGeneratedNameForNode(n);

		final g = new NameGenerator();
		g.Context = ec;
		g.GetTextOfNode = fn_Text;
		final text1 = g.GenerateName(name1);

		T.eq("_a", text1);
	}
}
