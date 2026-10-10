package ts.transformers.estransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/estransforms/utilities.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// superAccessState tracks super property/element accesses and super property assignments
// within async function or async generator bodies. It is embedded by both asyncTransformer
// and forawaitTransformer to share the tracking logic.
@:allow(ts.transformers.estransforms)
class SuperAccessState {
	var factory:ts.printer.Factory.NodeFactory = null;
	// Keeps track of property names accessed on super (`super.x`) within async functions.
	var capturedSuperProperties:OrderedSet<std.String> = null;
	// Whether the async function contains an element access on super (`super[x]`).
	var hasSuperElementAccess:Bool = false;
	var hasSuperPropertyAssignment:Bool = false;
	var superBinding:IdentifierNode = null;
	var superIndexBinding:IdentifierNode = null;
	var superAccessVisitor:NodeVisitor = null;

	public function new() {}

	// PORT: Go method value `s.visitSuperAccessNode`, created once.
	var visitSuperAccessNodeFn:(node:Node) -> Node = null;

	function initSuperAccessVisitor(emitContext:EmitContext, factory:ts.printer.Factory.NodeFactory):Void {
		this.factory = factory;
		if (visitSuperAccessNodeFn == null) {
			visitSuperAccessNodeFn = visitSuperAccessNode;
		}
		superAccessVisitor = emitContext.NewNodeVisitor(visitSuperAccessNodeFn);
	}

	// visitSuperAccessNode walks the async/generator body and replaces super property/element
	// accesses with _super/_superIndex references. This is necessary because the async body
	// ends up inside a generator function where `super` is not valid.
	function visitSuperAccessNode(node:Node):Node {
		switch (node.Kind) {
			case KindCallExpression:
				final call = node.AsCallExpression();
				if (Ast.IsSuperProperty(call.Expression)) {
					return substituteCallExpressionWithSuperAccess(call, superAccessVisitor);
				}
				return superAccessVisitor.VisitEachChild(node);
			case KindPropertyAccessExpression:
				if (node.Expression().Kind == KindSuperKeyword) {
					// super.x → _super.x
					return factory.NewPropertyAccessExpression(superBinding, null, node.Name(), NodeFlagsNone);
				}
				return superAccessVisitor.VisitEachChild(node);
			case KindElementAccessExpression:
				if (node.Expression().Kind == KindSuperKeyword) {
					// super[x] → _superIndex(x) or _superIndex(x).value
					return createSuperElementAccessInAsyncMethod(node.AsElementAccessExpression().ArgumentExpression);
				}
				return superAccessVisitor.VisitEachChild(node);
			// Don't recurse into non-arrow function scopes or classes
			case KindFunctionExpression, KindFunctionDeclaration, KindMethodDeclaration, KindGetAccessor, KindSetAccessor, KindConstructor,
				KindClassDeclaration, KindClassExpression:
				return node;
			default:
				return superAccessVisitor.VisitEachChild(node);
		}
	}

	function substituteSuperAccessesInBody(body:Node):Node {
		return superAccessVisitor.VisitNode(body);
	}

	// substituteCallExpressionWithSuperAccess handles super.x(args) and super[x](args).
	function substituteCallExpressionWithSuperAccess(call:CallExpression, visitor:NodeVisitor):Node {
		final expression = call.Expression;
		var target:Node = null;

		if (Ast.IsPropertyAccessExpression(expression)) {
			// super.x(args) → _super.x.call(this, args)
			target = factory.NewPropertyAccessExpression(superBinding, null, expression.AsPropertyAccessExpression().Name(), NodeFlagsNone);
		} else if (Ast.IsElementAccessExpression(expression)) {
			// super[x](args) → _superIndex(x).call(this, args) or _superIndex(x).value.call(this, args)
			target = createSuperElementAccessInAsyncMethod(expression.AsElementAccessExpression().ArgumentExpression);
		} else {
			return visitor.VisitEachChild(call.AsNode());
		}

		final callTarget = factory.NewPropertyAccessExpression(target, null, factory.NewIdentifier("call"), NodeFlagsNone);

		final allArgs:Array<Node> = [];
		allArgs.push(factory.NewThisExpression());
		if (call.Arguments != null) {
			final visitedArgs = visitor.VisitNodes(call.Arguments);
			if (visitedArgs != null) {
				for (a in visitedArgs.Nodes) {
					allArgs.push(a);
				}
			}
		}

		final result = factory.NewCallExpression(callTarget, null, null, factory.NewNodeList(allArgs), NodeFlagsNone);
		result.Loc = call.Loc;
		return result;
	}

	// createSuperElementAccessInAsyncMethod creates _superIndex(x) or _superIndex(x).value.
	function createSuperElementAccessInAsyncMethod(argumentExpression:Node):Node {
		final superIndexCall = factory.NewCallExpression(superIndexBinding, null, null, factory.NewNodeList([argumentExpression]), NodeFlagsNone);
		if (hasSuperPropertyAssignment) {
			return factory.NewPropertyAccessExpression(superIndexCall, null, factory.NewIdentifier("value"), NodeFlagsNone);
		}
		return superIndexCall;
	}

	// createSuperAccessVariableStatement creates a variable named `_super` with accessor
	// properties for the given property names.
	//
	// Create a variable declaration with a getter/setter (if binding) definition for each name:
	//
	//	const _super = Object.create(null, {
	//	    x: { get: () => super.x },                           // read-only
	//	    x: { get: () => super.x, set: (v) => super.x = v }, // read-write
	//	});
	function createSuperAccessVariableStatement():Node {
		final f = factory;
		var accessors:Array<Node> = null;

		for (name in capturedSuperProperties.Values()) {
			final descriptorProperties:Array<Node> = [];

			// getter: get: () => super.name
			final getterBody = f.NewPropertyAccessExpression(f.NewKeywordExpression(KindSuperKeyword), null, f.NewIdentifier(name), NodeFlagsNone);
			final getterArrow = f.NewArrowFunction(null, null, f.NewNodeList([]), null, null, f.NewToken(KindEqualsGreaterThanToken), getterBody);
			final getter = f.NewPropertyAssignment(null, f.NewIdentifier("get"), null, null, getterArrow);
			descriptorProperties.push(getter);

			if (hasSuperPropertyAssignment) {
				// setter: set: v => super.name = v
				final vParam = f.NewParameterDeclaration(null, null, f.NewIdentifier("v"), null, null, null);
				final superProp = f.NewPropertyAccessExpression(f.NewKeywordExpression(KindSuperKeyword), null, f.NewIdentifier(name), NodeFlagsNone);
				final assignExpr = f.NewAssignmentExpression(superProp, f.NewIdentifier("v"));
				final setterArrow = f.NewArrowFunction(null, null, f.NewNodeList([vParam]), null, null, f.NewToken(KindEqualsGreaterThanToken), assignExpr);
				final setter = f.NewPropertyAssignment(null, f.NewIdentifier("set"), null, null, setterArrow);
				descriptorProperties.push(setter);
			}

			final descriptor = f.NewObjectLiteralExpression(f.NewNodeList(descriptorProperties), false);
			final accessor = f.NewPropertyAssignment(null, f.NewIdentifier(name), null, null, descriptor);
			if (accessors == null) {
				accessors = [];
			}
			accessors.push(accessor);
		}

		final descriptorsObject = f.NewObjectLiteralExpression(f.NewNodeList(accessors), true);

		final objectCreateCall = f.NewCallExpression(f.NewPropertyAccessExpression(f.NewIdentifier("Object"), null, f.NewIdentifier("create"), NodeFlagsNone),
			null, null, f.NewNodeList([f.NewKeywordExpression(KindNullKeyword), descriptorsObject]), NodeFlagsNone);

		final decl = f.NewVariableDeclaration(superBinding, null, null, objectCreateCall);
		final declList = f.NewVariableDeclarationList(f.NewNodeList([decl]), NodeFlagsConst);
		return f.NewVariableStatement(null, declList);
	}

	// trackSuperAccess records super property/element accesses and super property assignments
	// for the enclosing async method body. Called from both the main visitor and auxiliary
	// visitors to ensure super accesses are tracked regardless of whether the node has
	// transform flags.
	function trackSuperAccess(node:Node):Void {
		if (capturedSuperProperties == null) {
			return;
		}
		switch (node.Kind) {
			case KindPropertyAccessExpression:
				if (node.Expression().Kind == KindSuperKeyword) {
					capturedSuperProperties.Add(node.Name().Text());
				}
			case KindElementAccessExpression:
				if (node.Expression().Kind == KindSuperKeyword) {
					hasSuperElementAccess = true;
				}
			case KindBinaryExpression:
				if (Ast.IsAssignmentOperator(node.AsBinaryExpression().OperatorToken.Kind)
					&& Estransforms.assignmentTargetContainsSuperProperty(node.AsBinaryExpression().Left)) {
					hasSuperPropertyAssignment = true;
				}
			case KindPrefixUnaryExpression:
				if (Estransforms.isUpdateExpression(node) && Estransforms.assignmentTargetContainsSuperProperty(node.AsPrefixUnaryExpression().Operand)) {
					hasSuperPropertyAssignment = true;
				}
			case KindPostfixUnaryExpression:
				if (Estransforms.isUpdateExpression(node) && Estransforms.assignmentTargetContainsSuperProperty(node.AsPostfixUnaryExpression().Operand)) {
					hasSuperPropertyAssignment = true;
				}
			default:
		}
	}
}

