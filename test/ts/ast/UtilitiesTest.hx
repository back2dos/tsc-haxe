package ts.ast;

// Tests for utilities.go and precedence.go (upstream has no *_test.go for them). Expected values
// are derived from the Go code; the broad per-kind / per-node coverage is the golden replay in
// UtilitiesGolden.hx (test/ts/ast/utilities.golden.txt, written by the Go reference).
class UtilitiesTest {
	public static function run() {
		T.run("TestBinaryOperatorPrecedence", TestBinaryOperatorPrecedence);
		T.run("TestOperatorPrecedence", TestOperatorPrecedence);
		T.run("TestExpressionPrecedence", TestExpressionPrecedence);
		T.run("TestTypeNodePrecedence", TestTypeNodePrecedence);
		T.run("TestKindPredicates", TestKindPredicates);
		T.run("TestModifierFlags", TestModifierFlags);
		T.run("TestCombinedFlags", TestCombinedFlags);
		T.run("TestAncestors", TestAncestors);
		T.run("TestAssignmentTarget", TestAssignmentTarget);
		T.run("TestNames", TestNames);
		T.run("TestFindImportOrRequire", TestFindImportOrRequire);
		T.run("TestModuleInstanceState", TestModuleInstanceState);
		T.run("TestOuterExpressions", TestOuterExpressions);
		T.run("TestNodeIds", TestNodeIds);
	}

	static function factory():NodeFactory {
		return Ast.NewNodeFactory(new NodeFactoryHooks());
	}

	static function id(f:NodeFactory, s:String):Node {
		return f.NewIdentifier(s);
	}

	static function bin(f:NodeFactory, l:Node, op:Kind, r:Node):Node {
		return f.NewBinaryExpression(null, l, null, f.NewToken(op), r);
	}

	static function TestBinaryOperatorPrecedence() {
		final cases:Array<Array<Int>> = [
			[KindQuestionQuestionToken, OperatorPrecedenceCoalesce],
			[KindBarBarToken, OperatorPrecedenceLogicalOR],
			[KindAmpersandAmpersandToken, OperatorPrecedenceLogicalAND],
			[KindBarToken, OperatorPrecedenceBitwiseOR],
			[KindCaretToken, OperatorPrecedenceBitwiseXOR],
			[KindAmpersandToken, OperatorPrecedenceBitwiseAND],
			[KindEqualsEqualsToken, OperatorPrecedenceEquality],
			[KindExclamationEqualsToken, OperatorPrecedenceEquality],
			[KindEqualsEqualsEqualsToken, OperatorPrecedenceEquality],
			[KindExclamationEqualsEqualsToken, OperatorPrecedenceEquality],
			[KindLessThanToken, OperatorPrecedenceRelational],
			[KindGreaterThanToken, OperatorPrecedenceRelational],
			[KindLessThanEqualsToken, OperatorPrecedenceRelational],
			[KindGreaterThanEqualsToken, OperatorPrecedenceRelational],
			[KindInstanceOfKeyword, OperatorPrecedenceRelational],
			[KindInKeyword, OperatorPrecedenceRelational],
			[KindAsKeyword, OperatorPrecedenceRelational],
			[KindSatisfiesKeyword, OperatorPrecedenceRelational],
			[KindLessThanLessThanToken, OperatorPrecedenceShift],
			[KindGreaterThanGreaterThanToken, OperatorPrecedenceShift],
			[KindGreaterThanGreaterThanGreaterThanToken, OperatorPrecedenceShift],
			[KindPlusToken, OperatorPrecedenceAdditive],
			[KindMinusToken, OperatorPrecedenceAdditive],
			[KindAsteriskToken, OperatorPrecedenceMultiplicative],
			[KindSlashToken, OperatorPrecedenceMultiplicative],
			[KindPercentToken, OperatorPrecedenceMultiplicative],
			[KindAsteriskAsteriskToken, OperatorPrecedenceExponentiation],
			[KindEqualsToken, OperatorPrecedenceInvalid],
			[KindCommaToken, OperatorPrecedenceInvalid],
			[KindPlusPlusToken, OperatorPrecedenceInvalid],
			[KindIdentifier, OperatorPrecedenceInvalid],
		];
		for (c in cases) {
			T.eq(c[1], (Ast.GetBinaryOperatorPrecedence(c[0]) : Int));
		}
		// The enum values (iota order) are part of the contract.
		T.eq(0, (OperatorPrecedenceComma : Int));
		T.eq(5, (OperatorPrecedenceCoalesce : Int));
		T.eq(15, (OperatorPrecedenceExponentiation : Int));
		T.eq(22, (OperatorPrecedenceHighest : Int));
		T.eq(2, (OperatorPrecedenceDisallowComma : Int));
		T.eq(-1, (OperatorPrecedenceInvalid : Int));
		T.eq(7, (TypePrecedenceHighest : Int));
	}

	static function TestOperatorPrecedence() {
		final n = OperatorPrecedenceFlagsNone;
		final oc = OperatorPrecedenceFlagsOptionalChain;
		final nw = OperatorPrecedenceFlagsNewWithoutArguments;
		T.eq(OperatorPrecedenceComma, Ast.GetOperatorPrecedence(KindBinaryExpression, KindCommaToken, n));
		for (op in [
			KindEqualsToken, KindPlusEqualsToken, KindMinusEqualsToken, KindAsteriskAsteriskEqualsToken, KindAsteriskEqualsToken, KindSlashEqualsToken,
			KindPercentEqualsToken, KindLessThanLessThanEqualsToken, KindGreaterThanGreaterThanEqualsToken,
			KindGreaterThanGreaterThanGreaterThanEqualsToken, KindAmpersandEqualsToken, KindCaretEqualsToken, KindBarEqualsToken,
			KindBarBarEqualsToken, KindAmpersandAmpersandEqualsToken, KindQuestionQuestionEqualsToken
		]) {
			T.eq(OperatorPrecedenceAssignment, Ast.GetOperatorPrecedence(KindBinaryExpression, op, n));
		}
		T.eq(OperatorPrecedenceMultiplicative, Ast.GetOperatorPrecedence(KindBinaryExpression, KindAsteriskToken, n));
		T.eq(OperatorPrecedenceInvalid, Ast.GetOperatorPrecedence(KindBinaryExpression, KindPlusPlusToken, n));
		T.eq(OperatorPrecedenceSpread, Ast.GetOperatorPrecedence(KindSpreadElement, KindUnknown, n));
		T.eq(OperatorPrecedenceYield, Ast.GetOperatorPrecedence(KindYieldExpression, KindUnknown, n));
		T.eq(OperatorPrecedenceAssignment, Ast.GetOperatorPrecedence(KindArrowFunction, KindUnknown, n));
		T.eq(OperatorPrecedenceConditional, Ast.GetOperatorPrecedence(KindConditionalExpression, KindUnknown, n));
		for (k in [
			KindTypeAssertionExpression, KindNonNullExpression, KindPrefixUnaryExpression, KindTypeOfExpression, KindVoidExpression,
			KindDeleteExpression, KindAwaitExpression
		]) {
			T.eq(OperatorPrecedenceUnary, Ast.GetOperatorPrecedence(k, KindUnknown, n));
		}
		T.eq(OperatorPrecedenceUpdate, Ast.GetOperatorPrecedence(KindPostfixUnaryExpression, KindPlusPlusToken, n));
		for (k in [KindPropertyAccessExpression, KindElementAccessExpression, KindCallExpression]) {
			T.eq(OperatorPrecedenceMember, Ast.GetOperatorPrecedence(k, k, n));
			T.eq(OperatorPrecedenceOptionalChain, Ast.GetOperatorPrecedence(k, k, oc));
			T.eq(OperatorPrecedenceMember, Ast.GetOperatorPrecedence(k, k, nw));
		}
		T.eq(OperatorPrecedenceMember, Ast.GetOperatorPrecedence(KindNewExpression, KindNewExpression, n));
		T.eq(OperatorPrecedenceLeftHandSide, Ast.GetOperatorPrecedence(KindNewExpression, KindNewExpression, nw));
		T.eq(OperatorPrecedenceMember, Ast.GetOperatorPrecedence(KindNewExpression, KindNewExpression, oc));
		for (k in [KindTaggedTemplateExpression, KindMetaProperty, KindExpressionWithTypeArguments]) {
			T.eq(OperatorPrecedenceMember, Ast.GetOperatorPrecedence(k, k, n));
		}
		T.eq(OperatorPrecedenceRelational, Ast.GetOperatorPrecedence(KindAsExpression, KindAsExpression, n));
		T.eq(OperatorPrecedenceRelational, Ast.GetOperatorPrecedence(KindSatisfiesExpression, KindSatisfiesExpression, n));
		for (k in [
			KindThisKeyword, KindSuperKeyword, KindImportKeyword, KindIdentifier, KindPrivateIdentifier, KindNullKeyword, KindTrueKeyword,
			KindFalseKeyword, KindNumericLiteral, KindBigIntLiteral, KindStringLiteral, KindArrayLiteralExpression, KindObjectLiteralExpression,
			KindFunctionExpression, KindClassExpression, KindRegularExpressionLiteral, KindNoSubstitutionTemplateLiteral, KindTemplateExpression,
			KindOmittedExpression, KindJsxElement, KindJsxSelfClosingElement, KindJsxFragment, KindMissingDeclaration
		]) {
			T.eq(OperatorPrecedencePrimary, Ast.GetOperatorPrecedence(k, k, n));
		}
		T.eq(OperatorPrecedenceParentheses, Ast.GetOperatorPrecedence(KindParenthesizedExpression, KindUnknown, n));
		T.eq(OperatorPrecedenceInvalid, Ast.GetOperatorPrecedence(KindBlock, KindUnknown, n));
		T.eq(OperatorPrecedenceInvalid, Ast.GetOperatorPrecedence(KindJsxText, KindUnknown, n));
	}

	static function TestExpressionPrecedence() {
		final f = factory();
		T.eq(OperatorPrecedenceAdditive, Ast.GetExpressionPrecedence(bin(f, id(f, "a"), KindPlusToken, id(f, "b"))));
		T.eq(OperatorPrecedenceAssignment, Ast.GetExpressionPrecedence(bin(f, id(f, "a"), KindBarBarEqualsToken, id(f, "b"))));
		T.eq(OperatorPrecedenceUnary, Ast.GetExpressionPrecedence(f.NewPrefixUnaryExpression(KindMinusToken, id(f, "a"))));
		T.eq(OperatorPrecedenceUpdate, Ast.GetExpressionPrecedence(f.NewPostfixUnaryExpression(id(f, "a"), KindPlusPlusToken)));
		T.eq(OperatorPrecedenceLeftHandSide, Ast.GetExpressionPrecedence(f.NewNewExpression(id(f, "C"), null, null)));
		T.eq(OperatorPrecedenceMember, Ast.GetExpressionPrecedence(f.NewNewExpression(id(f, "C"), null, f.NewNodeList([]))));
		T.eq(OperatorPrecedenceMember,
			Ast.GetExpressionPrecedence(f.NewPropertyAccessExpression(id(f, "a"), null, id(f, "b"), NodeFlagsNone)));
		T.eq(OperatorPrecedenceOptionalChain,
			Ast.GetExpressionPrecedence(f.NewPropertyAccessExpression(id(f, "a"), f.NewToken(KindQuestionDotToken), id(f, "b"),
				NodeFlagsOptionalChain)));
		T.eq(OperatorPrecedencePrimary, Ast.GetExpressionPrecedence(id(f, "a")));

		// GetLeftmostExpression: `a.b + c` → a; `f()` stops at the call only when asked.
		final a = id(f, "a");
		final sum = bin(f, f.NewPropertyAccessExpression(a, null, id(f, "b"), NodeFlagsNone), KindPlusToken, id(f, "c"));
		T.isTrue(Ast.GetLeftmostExpression(sum, false) == a);
		final callee = id(f, "g");
		final call = f.NewCallExpression(callee, null, null, f.NewNodeList([]), NodeFlagsNone);
		final post = f.NewPostfixUnaryExpression(call, KindPlusPlusToken);
		T.isTrue(Ast.GetLeftmostExpression(post, true) == call);
		T.isTrue(Ast.GetLeftmostExpression(post, false) == callee);
	}

	static function TestTypeNodePrecedence() {
		final f = factory();
		T.eq(TypePrecedenceNonArray, Ast.GetTypeNodePrecedence(f.NewKeywordTypeNode(KindStringKeyword)));
		T.eq(TypePrecedencePostfix, Ast.GetTypeNodePrecedence(f.NewArrayTypeNode(f.NewKeywordTypeNode(KindStringKeyword))));
		final tp = f.NewTypeParameterDeclaration(null, id(f, "T"), null, null, null);
		T.eq(TypePrecedenceTypeOperator, Ast.GetTypeNodePrecedence(f.NewInferTypeNode(tp)));
		final tpc = f.NewTypeParameterDeclaration(null, id(f, "T"), f.NewKeywordTypeNode(KindStringKeyword), null, null);
		T.eq(TypePrecedenceFunction, Ast.GetTypeNodePrecedence(f.NewInferTypeNode(tpc)));
		var threw = false;
		try {
			Ast.GetTypeNodePrecedence(id(f, "x"));
		} catch (e:Dynamic) {
			threw = true;
			T.eq("unhandled TypeNode: KindIdentifier", Std.string(e));
		}
		T.isTrue(threw);
	}

	static function TestKindPredicates() {
		T.isTrue(Ast.IsKeyword(KindBreakKeyword));
		T.isTrue(Ast.IsKeyword(KindAbstractKeyword));
		T.isTrue(!Ast.IsKeyword(KindIdentifier));
		T.isTrue(!Ast.IsKeyword(KindNumericLiteral));
		T.isTrue(Ast.IsContextualKeyword(KindAbstractKeyword));
		T.isTrue(!Ast.IsContextualKeyword(KindClassKeyword));
		T.isTrue(Ast.IsNonContextualKeyword(KindClassKeyword));
		T.isTrue(!Ast.IsNonContextualKeyword(KindAbstractKeyword));
		T.isTrue(Ast.IsTrivia(KindWhitespaceTrivia));
		T.isTrue(Ast.IsTrivia(KindSingleLineCommentTrivia));
		T.isTrue(!Ast.IsTrivia(KindNumericLiteral));
		T.isTrue(Ast.IsCompoundAssignment(KindPlusEqualsToken));
		T.isTrue(!Ast.IsCompoundAssignment(KindEqualsToken));
		T.isTrue(Ast.IsLogicalOrCoalescingBinaryOperator(KindQuestionQuestionToken));
		T.isTrue(!Ast.IsLogicalBinaryOperator(KindQuestionQuestionToken));
		T.isTrue(Ast.IsTypeNodeKind(KindAnyKeyword));
		T.isTrue(Ast.IsTypeNodeKind(KindExpressionWithTypeArguments));
		T.isTrue(Ast.IsTypeNodeKind(KindUnionType));
		T.isTrue(!Ast.IsTypeNodeKind(KindIdentifier));
		T.isTrue(Ast.IsFunctionLikeKind(KindArrowFunction));
		T.isTrue(Ast.IsFunctionLikeKind(KindJSDocSignature));
		T.isTrue(!Ast.IsFunctionLikeKind(KindClassDeclaration));
		T.isTrue(Ast.IsTemplateLiteralKind(KindTemplateHead));
		T.isTrue(Ast.IsTemplateLiteralKind(KindNoSubstitutionTemplateLiteral));
		T.isTrue(!Ast.IsTemplateLiteralKind(KindStringLiteral));
		T.isTrue(Ast.IsClassMemberModifier(KindReadonlyKeyword));
		T.isTrue(Ast.IsParameterPropertyModifier(KindOverrideKeyword));
		T.isTrue(!Ast.IsClassMemberModifier(KindExportKeyword));
		T.isTrue(Ast.IsInfinityOrNaNString("-Infinity"));
		T.isTrue(Ast.IsInfinityOrNaNString("NaN"));
		T.isTrue(!Ast.IsInfinityOrNaNString("-NaN"));
		T.isTrue(Ast.IsAmbientModuleSymbolName('"m"'));
		T.isTrue(Ast.IsAmbientModuleSymbolName('"')); // prefix and suffix may overlap, as in Go
		T.isTrue(!Ast.IsAmbientModuleSymbolName("m"));
	}

	static function TestModifierFlags() {
		final f = factory();
		final mods = [f.NewModifier(KindExportKeyword), f.NewModifier(KindDeclareKeyword), f.NewModifier(KindAsyncKeyword)];
		T.eq((ModifierFlagsExport | ModifierFlagsAmbient | ModifierFlagsAsync : Int), (Ast.ModifiersToFlags(mods) : Int));
		T.eq((ModifierFlagsNone : Int), (Ast.ModifiersToFlags(null) : Int));
		T.eq((ModifierFlagsDecorator : Int), (Ast.ModifierToFlag(KindDecorator) : Int));
		T.eq((ModifierFlagsNone : Int), (Ast.ModifierToFlag(KindIdentifier) : Int));

		// CreateModifiersFromModifierFlags emits in a fixed order, independent of the flag bits.
		final all = ModifierFlagsOut | ModifierFlagsIn | ModifierFlagsAsync | ModifierFlagsAccessor | ModifierFlagsReadonly | ModifierFlagsOverride |
			ModifierFlagsStatic | ModifierFlagsAbstract | ModifierFlagsProtected | ModifierFlagsPrivate | ModifierFlagsPublic | ModifierFlagsConst |
			ModifierFlagsDefault | ModifierFlagsAmbient | ModifierFlagsExport;
		final created = Ast.CreateModifiersFromModifierFlags(all, k -> f.NewModifier(k));
		T.eq("ExportKeyword DeclareKeyword DefaultKeyword ConstKeyword PublicKeyword PrivateKeyword ProtectedKeyword AbstractKeyword StaticKeyword OverrideKeyword ReadonlyKeyword AccessorKeyword AsyncKeyword InKeyword OutKeyword",
			[for (m in created) m.Kind.String().substr(4)].join(" "));
		T.isTrue(Ast.CreateModifiersFromModifierFlags(ModifierFlagsNone, k -> f.NewModifier(k)) == null);
		T.eq(2, Ast.CreateModifiersFromModifierFlags(ModifierFlagsStatic | ModifierFlagsDecorator | ModifierFlagsExport, k -> f.NewModifier(k)).length);

		// Class member modifiers and IsStatic.
		final prop = f.NewPropertyDeclaration(f.NewModifierList([f.NewModifier(KindStaticKeyword), f.NewModifier(KindAccessorKeyword)]), id(f, "p"),
			null, null, null);
		final cls = f.NewClassDeclaration(null, id(f, "C"), null, null, f.NewNodeList([prop]));
		Ast.SetParentInChildren(cls);
		T.isTrue(Ast.HasStaticModifier(prop));
		T.isTrue(Ast.IsStatic(prop));
		T.isTrue(Ast.IsAutoAccessorPropertyDeclaration(prop));
		T.isTrue(!Ast.HasAbstractModifier(prop));
		T.isTrue(Ast.GetContainingClass(prop) == cls);
		T.isTrue(Ast.IsClassElement(prop));
		T.isTrue(!Ast.IsStatic(cls));
	}

	// `export const {a: [b]} = x;` and `let y;`
	static function TestCombinedFlags() {
		final f = factory();
		final b = f.NewBindingElement(null, null, id(f, "b"), null);
		final inner = f.NewBindingPattern(KindArrayBindingPattern, f.NewNodeList([b]));
		final a = f.NewBindingElement(null, id(f, "a"), inner, null);
		final outer = f.NewBindingPattern(KindObjectBindingPattern, f.NewNodeList([a]));
		final decl = f.NewVariableDeclaration(outer, null, null, id(f, "x"));
		final list = f.NewVariableDeclarationList(f.NewNodeList([decl]), NodeFlagsConst);
		final stmt = f.NewVariableStatement(f.NewModifierList([f.NewModifier(KindExportKeyword)]), list);
		Ast.SetParentInChildren(stmt);
		T.isTrue(Ast.GetRootDeclaration(b) == decl);
		T.isTrue(Ast.GetRootDeclaration(decl) == decl);
		T.isTrue(Ast.WalkUpBindingElementsAndPatterns(b) == decl);
		T.eq((ModifierFlagsExport : Int), (Ast.GetCombinedModifierFlags(b) : Int));
		T.eq((NodeFlagsConst : Int), (Ast.GetCombinedNodeFlags(b) & NodeFlagsBlockScoped : Int));
		T.isTrue(Ast.IsVarConst(decl));
		T.isTrue(Ast.IsVarConstLike(b));
		T.isTrue(!Ast.IsVarLet(decl));
		T.isTrue(!Ast.IsVarUsing(decl));
		T.isTrue(Ast.IsBlockOrCatchScoped(b));
		T.isTrue(!Ast.IsPartOfParameterDeclaration(b));

		final y = f.NewVariableDeclaration(id(f, "y"), null, null, null);
		final ylist = f.NewVariableDeclarationList(f.NewNodeList([y]), NodeFlagsAwaitUsing);
		Ast.SetParentInChildren(ylist);
		T.isTrue(Ast.IsVarAwaitUsing(y));
		T.isTrue(!Ast.IsVarUsing(y));
		T.isTrue(Ast.IsVarConstLike(y));
		T.isTrue(!Ast.IsVarConst(y));
		T.eq((ModifierFlagsNone : Int), (Ast.GetCombinedModifierFlags(y) : Int));
	}

	// function f() { if (c) { return (a); } }
	static function TestAncestors() {
		final f = factory();
		final a = id(f, "a");
		final paren = f.NewParenthesizedExpression(a);
		final ret = f.NewReturnStatement(paren);
		final thenBlock = f.NewBlock(f.NewNodeList([ret]), true);
		final ifs = f.NewIfStatement(id(f, "c"), thenBlock, null);
		final body = f.NewBlock(f.NewNodeList([ifs]), true);
		final fn = f.NewFunctionDeclaration(null, null, id(f, "f"), null, f.NewNodeList([]), null, null, body);
		Ast.SetParentInChildren(fn);

		T.isTrue(Ast.FindAncestor(a, Ast.IsFunctionLike) == fn);
		T.isTrue(Ast.FindAncestor(a, n -> n.Kind == KindClassDeclaration) == null);
		T.isTrue(Ast.FindAncestorKind(a, KindIfStatement) == ifs);
		T.isTrue(Ast.FindAncestorKind(a, KindSourceFile) == null);
		T.isTrue(Ast.FindAncestorOrQuit(a, n -> n.Kind == KindBlock ? FindAncestorQuit : Ast.ToFindAncestorResult(IsFunctionDeclarationNode(n))) == null);
		T.isTrue(Ast.FindAncestorOrQuit(a, n -> Ast.ToFindAncestorResult(n.Kind == KindBlock)) == thenBlock);
		T.isTrue(Ast.IsNodeDescendantOf(a, fn));
		T.isTrue(!Ast.IsNodeDescendantOf(fn, a));
		T.isTrue(Ast.WalkUpParenthesizedExpressions(paren) == ret);
		T.isTrue(Ast.GetContainingFunction(a) == fn);
		T.isTrue(Ast.GetThisContainer(a, false, false) == fn);
		T.isTrue(Ast.IsFunctionBlock(body));
		T.isTrue(!Ast.IsFunctionBlock(thenBlock));
		T.isTrue(Ast.IsStatement(thenBlock));
		T.isTrue(!Ast.IsStatement(body));
		T.isTrue(Ast.GetSourceFileOfNode(a) == null);
		var returns = [];
		T.isTrue(!Ast.ForEachReturnStatement(body, function(s) {
			returns.push(s);
			return false;
		}));
		T.eq(1, returns.length);
		T.isTrue(returns[0] == ret);
		T.isTrue(Ast.ForEachReturnStatement(body, s -> true));
		var threw = false;
		try {
			Ast.GetThisContainer(fn, false, false);
		} catch (e:Dynamic) {
			threw = true;
			T.eq("nil parent in getThisContainer", Std.string(e));
		}
		T.isTrue(threw);
	}

	static function IsFunctionDeclarationNode(n:Node):Bool {
		return n.Kind == KindFunctionDeclaration;
	}

	// ({ p: b, ...r } = c); [x] = d; !(e && g); i++;
	static function TestAssignmentTarget() {
		final f = factory();
		final p = id(f, "p");
		final b = id(f, "b");
		final r = id(f, "r");
		final obj = f.NewObjectLiteralExpression(f.NewNodeList([f.NewPropertyAssignment(null, p, null, null, b), f.NewSpreadAssignment(r)]), false);
		final assign = bin(f, obj, KindEqualsToken, id(f, "c"));
		final stmt = f.NewExpressionStatement(f.NewParenthesizedExpression(assign));
		Ast.SetParentInChildren(stmt);
		T.isTrue(Ast.GetAssignmentTarget(b) == assign);
		T.isTrue(Ast.GetAssignmentTarget(r) == assign);
		T.isTrue(Ast.GetAssignmentTarget(p) == null);
		T.isTrue(Ast.IsAssignmentTarget(obj));
		T.isTrue(Ast.IsDestructuringAssignment(assign));
		T.isTrue(Ast.IsAssignmentExpression(assign, true));

		final x = id(f, "x");
		final arr = f.NewArrayLiteralExpression(f.NewNodeList([x]), false);
		final assign2 = bin(f, arr, KindPlusEqualsToken, id(f, "d"));
		Ast.SetParentInChildren(assign2);
		T.isTrue(Ast.GetAssignmentTarget(x) == assign2);
		T.isTrue(!Ast.IsDestructuringAssignment(assign2));
		T.isTrue(!Ast.IsAssignmentExpression(assign2, true));
		T.isTrue(Ast.IsAssignmentExpression(assign2, false));

		final logical = f.NewPrefixUnaryExpression(KindExclamationToken, f.NewParenthesizedExpression(bin(f, id(f, "e"), KindAmpersandAmpersandToken, id(f, "g"))));
		T.isTrue(Ast.IsLogicalExpression(logical));
		T.isTrue(!Ast.IsLogicalExpression(f.NewPrefixUnaryExpression(KindMinusToken, bin(f, id(f, "e"), KindBarBarToken, id(f, "g")))));

		final i = id(f, "i");
		final inc = f.NewPostfixUnaryExpression(i, KindPlusPlusToken);
		Ast.SetParentInChildren(inc);
		T.isTrue(Ast.GetAssignmentTarget(i) == inc);
		final j = id(f, "j");
		final neg = f.NewPrefixUnaryExpression(KindMinusToken, j);
		Ast.SetParentInChildren(neg);
		T.isTrue(Ast.GetAssignmentTarget(j) == null);

		// GetRightMostAssignedExpression: a = b = c → c
		final c = id(f, "c");
		T.isTrue(Ast.GetRightMostAssignedExpression(bin(f, id(f, "a"), KindEqualsToken, bin(f, id(f, "b"), KindEqualsToken, c))) == c);
	}

	static function TestNames() {
		final f = factory();
		final qn = f.NewQualifiedName(f.NewQualifiedName(id(f, "a"), id(f, "b")), id(f, "c"));
		T.eq("a.b.c", Ast.EntityNameToString(qn, null));
		// Synthesized identifiers (pos -1) ignore getTextOfNode.
		T.eq("a.b.c", Ast.EntityNameToString(qn, n -> "X"));
		final real = id(f, "r");
		real.Loc = new TextRange(0, 1);
		final pa = f.NewPropertyAccessExpression(f.NewKeywordExpression(KindThisKeyword), null, real, NodeFlagsNone);
		T.eq("this.X", Ast.EntityNameToString(pa, n -> "X"));
		T.eq("this.r", Ast.EntityNameToString(pa, null));
		T.eq("ns:n", Ast.EntityNameToString(f.NewJsxNamespacedName(id(f, "ns"), id(f, "n")), null));
		var threw = false;
		try {
			Ast.EntityNameToString(f.NewStringLiteral("s", TokenFlagsNone), null);
		} catch (e:Dynamic) {
			threw = true;
		}
		T.isTrue(threw);

		T.eq("s", Ast.GetTextOfPropertyName(f.NewStringLiteral("s", TokenFlagsNone)));
		T.eq("1", Ast.GetTextOfPropertyName(f.NewComputedPropertyName(f.NewNumericLiteral("1", TokenFlagsNone))));
		final r = Ast.TryGetTextOfPropertyName(f.NewComputedPropertyName(id(f, "x")));
		T.isTrue(!r.ok);
		T.eq("", r.value);
		T.eq("ns:n", Ast.GetTextOfPropertyName(f.NewJsxNamespacedName(id(f, "ns"), id(f, "n"))));

		T.eq("-5", Ast.GetPropertyNameForPropertyNameNode(f.NewComputedPropertyName(f.NewPrefixUnaryExpression(KindMinusToken,
			f.NewNumericLiteral("5", TokenFlagsNone)))));
		T.eq("5", Ast.GetPropertyNameForPropertyNameNode(f.NewComputedPropertyName(f.NewPrefixUnaryExpression(KindPlusToken,
			f.NewNumericLiteral("5", TokenFlagsNone)))));
		T.eq(Ast.InternalSymbolNameMissing, Ast.GetPropertyNameForPropertyNameNode(f.NewComputedPropertyName(id(f, "k"))));
		T.isTrue(Ast.IsDynamicName(f.NewComputedPropertyName(id(f, "k"))));
		T.isTrue(!Ast.IsDynamicName(f.NewComputedPropertyName(f.NewPrefixUnaryExpression(KindMinusToken, f.NewNumericLiteral("5", TokenFlagsNone)))));

		// a.b vs a.b / a.c
		final ab1 = f.NewPropertyAccessExpression(id(f, "a"), null, id(f, "b"), NodeFlagsNone);
		final ab2 = f.NewPropertyAccessExpression(id(f, "a"), null, id(f, "b"), NodeFlagsNone);
		final ac = f.NewPropertyAccessExpression(id(f, "a"), null, id(f, "c"), NodeFlagsNone);
		T.isTrue(Ast.HasSamePropertyAccessName(ab1, ab2));
		T.isTrue(!Ast.HasSamePropertyAccessName(ab1, ac));
		T.isTrue(Ast.IsDottedName(f.NewParenthesizedExpression(ab1)));
		T.isTrue(Ast.IsEntityNameExpression(ab1));
		final proto = f.NewPropertyAccessExpression(id(f, "F"), null, id(f, "prototype"), NodeFlagsNone);
		T.isTrue(Ast.IsPrototypeAccess(proto));
		T.isTrue(!Ast.IsPrototypeAccess(ab1));
		T.isTrue(Ast.IsPushOrUnshiftIdentifier(id(f, "unshift")));
	}

	static function TestFindImportOrRequire() {
		final text = "x import y require(z) importe";
		var r = Ast.findImportOrRequire(text, 0);
		T.eq(2, r.a);
		T.eq(6, r.b);
		r = Ast.findImportOrRequire(text, r.a + r.b);
		T.eq(11, r.a);
		T.eq(7, r.b);
		r = Ast.findImportOrRequire(text, r.a + r.b);
		T.eq(22, r.a);
		T.eq(6, r.b);
		r = Ast.findImportOrRequire(text, r.a + r.b);
		T.eq(-1, r.a);
		T.eq(0, r.b);
		r = Ast.findImportOrRequire("requir impor", -5);
		T.eq(-1, r.a);
		// Offsets are UTF-16 code units (PORTING.md §5).
		r = Ast.findImportOrRequire("\u{1F600}é import", 0);
		T.eq(4, r.a);
	}

	static function TestModuleInstanceState() {
		final f = factory();
		function ns(statements:Array<Node>):Node {
			final m = f.NewModuleDeclaration(null, KindNamespaceKeyword, id(f, "N"), f.NewModuleBlock(f.NewNodeList(statements)));
			Ast.SetParentInChildren(m);
			return m;
		}
		function iface(name:String):Node {
			return f.NewInterfaceDeclaration(null, id(f, name), null, null, f.NewNodeList([]));
		}
		function enm(name:String, isConst:Bool):Node {
			return f.NewEnumDeclaration(isConst ? f.NewModifierList([f.NewModifier(KindConstKeyword)]) : null, id(f, name),
				f.NewNodeList([f.NewEnumMember(id(f, "A"), null)]));
		}
		function exportNames(names:Array<String>):Node {
			return f.NewExportDeclaration(null, false, f.NewNamedExports(f.NewNodeList([for (n in names) f.NewExportSpecifier(false, null, id(f, n))])), null,
				null);
		}
		T.eq(ModuleInstanceStateNonInstantiated, Ast.GetModuleInstanceState(ns([])));
		T.eq(ModuleInstanceStateNonInstantiated, Ast.GetModuleInstanceState(ns([iface("I")])));
		T.eq(ModuleInstanceStateConstEnumOnly, Ast.GetModuleInstanceState(ns([iface("I"), enm("E", true)])));
		T.eq(ModuleInstanceStateInstantiated, Ast.GetModuleInstanceState(ns([enm("E", true), enm("F", false)])));
		T.eq(ModuleInstanceStateInstantiated, Ast.GetModuleInstanceState(f.NewModuleDeclaration(null, KindNamespaceKeyword, id(f, "N"), null)));
		T.eq(ModuleInstanceStateNonInstantiated, Ast.GetModuleInstanceState(ns([iface("I"), exportNames(["I"])])));
		T.eq(ModuleInstanceStateConstEnumOnly, Ast.GetModuleInstanceState(ns([enm("E", true), exportNames(["E"])])));
		// Unknown name: could refer to a value.
		T.eq(ModuleInstanceStateInstantiated, Ast.GetModuleInstanceState(ns([iface("I"), exportNames(["I", "Z"])])));
		// Nested namespace with only types.
		final inner = f.NewModuleDeclaration(null, KindNamespaceKeyword, id(f, "M"), f.NewModuleBlock(f.NewNodeList([iface("J")])));
		T.eq(ModuleInstanceStateNonInstantiated, Ast.GetModuleInstanceState(ns([inner])));
		T.isTrue(Ast.IsInstantiatedModule(ns([enm("E", true)]), true));
		T.isTrue(!Ast.IsInstantiatedModule(ns([enm("E", true)]), false));
	}

	static function TestOuterExpressions() {
		final f = factory();
		final a = id(f, "a");
		final e = f.NewNonNullExpression(f.NewParenthesizedExpression(f.NewAsExpression(a, f.NewKeywordTypeNode(KindAnyKeyword))), NodeFlagsNone);
		T.isTrue(Ast.SkipOuterExpressions(e, OEKAll) == a);
		T.isTrue(Ast.SkipOuterExpressions(e, OEKParentheses) == e);
		T.isTrue(Ast.SkipParentheses(e.Expression()) != a);
		T.eq(OEKParentheses | OEKPartiallyEmittedExpressions, OEKAllExceptAssertionsOrExpressionsWithTypeArguments);
		final c = id(f, "c");
		final comma = bin(f, id(f, "b"), KindCommaToken, bin(f, id(f, "x"), KindEqualsToken, c));
		T.isTrue(Ast.SkipOuterExpressions(comma, OEKExpressionTypePassthrough) == c);
		T.isTrue(Ast.IsCommaSequence(comma));
		final t = f.NewKeywordTypeNode(KindStringKeyword);
		final pt = f.NewParenthesizedTypeNode(f.NewParenthesizedTypeNode(t));
		T.isTrue(Ast.SkipTypeParentheses(pt) == t);
	}

	static function TestNodeIds() {
		final f = factory();
		final n1 = id(f, "a");
		final n2 = id(f, "b");
		final i1 = Ast.GetNodeId(n1);
		final i2 = Ast.GetNodeId(n2);
		T.isTrue(i1 > 0);
		T.eq(i1 + 1, i2);
		T.eq(i1, Ast.GetNodeId(n1));
		final s = new Symbol();
		final sid = Ast.GetSymbolId(s);
		T.isTrue(sid > 0);
		T.eq(sid, Ast.GetSymbolId(s));
		T.isTrue(s.Members == null);
		final members = Ast.GetMembers(s);
		T.isTrue(members != null && s.Members == members);
		T.isTrue(Ast.GetExports(s) == s.Exports && s.Exports != null);
		T.isTrue(Ast.FindLastVisibleNode(null) == null);
		final r = id(f, "r");
		r.Flags = NodeFlagsReparsed;
		T.isTrue(Ast.FindLastVisibleNode([n1, n2, r]) == n2);
		T.isTrue(Ast.FindLastVisibleNode([r]) == null);
		T.isTrue(Ast.NodeKindIs(n1, KindStringLiteral, KindIdentifier));
		T.isTrue(!Ast.NodeKindIs(n1));
		// IndexOfNode is a binary search by position.
		n1.Loc = new TextRange(0, 1);
		n2.Loc = new TextRange(2, 3);
		r.Loc = new TextRange(2, 3);
		T.eq(1, Ast.IndexOfNode([n1, n2], n2));
		T.eq(1, Ast.IndexOfNode([n1, n2], r));
		T.eq(-1, Ast.IndexOfNode([n1], n2));
	}
}
