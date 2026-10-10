package ts.transformers;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/destructuring.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// FlattenLevel controls how deeply binding/assignment patterns are decomposed.
enum abstract FlattenLevel(Int) from Int to Int {
	var FlattenLevelAll = 0; // Fully decompose all patterns into individual assignments/bindings
	var FlattenLevelObjectRest = 1; // Only decompose patterns containing object rest elements
}

// CreateAssignmentCallback is a callback used to create custom assignment expressions during destructuring flattening.
// When provided, the target will always be an Identifier, and the callback can wrap the assignment with additional logic
// (e.g., export expressions in CJS modules or namespace member assignments).
typedef CreateAssignmentCallback = (name:IdentifierNode, value:Expression, location:TextRange) -> Expression;

// pendingDecl tracks a pending variable declaration during binding flattening.
@:allow(ts.transformers)
class PendingDecl {
	var pendingExpressions:Array<Node> = null;
	var name:Node = null;
	var value:Node = null;
	var location:TextRange = null /* PORT: Go zero struct */;
	var original:Node = null;

	public function new() {}
}

// flattener encapsulates the state and logic for flattening destructuring patterns.
// It is equivalent to TypeScript's FlattenContext in destructuring.ts.
@:allow(ts.transformers)
class Flattener {
	var tx:Transformer = null;
	var level:FlattenLevel = 0;
	var createAssignmentCallback:CreateAssignmentCallback = null;
	// State
	var expressions:Array<Node> = null;
	var declarations:Array<PendingDecl> = null;
	var hasTransformedPriorElement:Bool = false;
	var hoistTempVariables:Bool = false;
	// Mode callbacks (set by FlattenDestructuringAssignment or FlattenDestructuringBinding)
	var emitBindingOrAssignment:(f:Flattener, target:Node, value:Node, location:TextRange, original:Node) -> Void = null;
	var createArrayBindingOrAssignmentPattern:(f:Flattener, elements:Array<Node>) -> Node = null;
	var createObjectBindingOrAssignmentPattern:(f:Flattener, elements:Array<Node>) -> Node = null;
	var createArrayBindingOrAssignmentElement:(f:Flattener, expr:Node) -> Node = null;

	public function new() {}

	function createArrayAssignmentPattern(elements:Array<Node>):Node {
		return tx.Factory().NewArrayLiteralExpression(tx.Factory().NewNodeList(elements), false);
	}

	function createObjectAssignmentPattern(elements:Array<Node>):Node {
		return tx.Factory().NewObjectLiteralExpression(tx.Factory().NewNodeList(elements), false);
	}

	function createArrayAssignmentElement(expr:Node):Node {
		return expr;
	}

	function emitAssignment(target:Node, value:Node, location:TextRange, original:Node):Void {
		var expression:Expression;
		if (createAssignmentCallback != null && Ast.IsIdentifier(target)) {
			// PORT: pointer — Go passes &location; TextRange is immutable here.
			expression = createAssignmentCallback(target, value, location);
		} else {
			expression = tx.Factory().NewAssignmentExpression(tx.Visitor().VisitNode(target), value);
			expression.Loc = location;
		}
		tx.EmitContext().SetOriginal(expression, original);
		emitExpression(expression);
	}

	function createArrayBindingPattern(elements:Array<Node>):Node {
		return tx.Factory().NewBindingPattern(KindArrayBindingPattern, tx.Factory().NewNodeList(elements));
	}

	function createObjectBindingPattern(elements:Array<Node>):Node {
		return tx.Factory().NewBindingPattern(KindObjectBindingPattern, tx.Factory().NewNodeList(elements));
	}

	function createArrayBindingElement(expr:Node):Node {
		return tx.Factory().NewBindingElement(null, null, expr, null);
	}

	function emitBinding(target:Node, value:Node, location:TextRange, original:Node):Void {
		if (Core.len(expressions) > 0) {
			expressions.push(value);
			value = tx.Factory().InlineExpressions(expressions);
			expressions = null;
		}
		final d = new PendingDecl();
		d.name = target;
		d.value = value;
		d.location = location;
		d.original = original;
		if (declarations == null) {
			declarations = [];
		}
		declarations.push(d);
	}

	function emitExpression(expr:Node):Void {
		if (expressions == null) {
			expressions = [];
		}
		expressions.push(expr);
	}

	function ensureIdentifier(value:Node, reuseIdentifierExpressions:Bool, location:TextRange):Node {
		if (reuseIdentifierExpressions && Ast.IsIdentifier(value)) {
			return value;
		}
		final temp = tx.Factory().NewTempVariable();
		if (hoistTempVariables) {
			tx.EmitContext().AddVariableDeclaration(temp);
			final assign = tx.Factory().NewAssignmentExpression(temp, value);
			assign.Loc = location;
			emitExpression(assign);
		} else {
			emitBindingOrAssignment(this, temp, value, location, null);
		}
		return temp;
	}

	function createDefaultValueCheck(value:Expression, defaultValue:Expression, location:TextRange):Node {
		value = ensureIdentifier(value, true, location);
		return tx.Factory().NewConditionalExpression(tx.Factory().NewTypeCheck(value, "undefined"), tx.Factory().NewToken(KindQuestionToken), defaultValue,
			tx.Factory().NewToken(KindColonToken), value);
	}

	function createDestructuringPropertyAccess(value:Node, propertyName:Node):Node {
		if (Ast.IsComputedPropertyName(propertyName)) {
			final argumentExpression = ensureIdentifier(tx.Visitor().VisitNode(propertyName.Expression()), false, propertyName.Loc);
			return tx.Factory().NewElementAccessExpression(value, null, argumentExpression, NodeFlagsNone);
		} else if (Ast.IsStringOrNumericLiteralLike(propertyName) || Ast.IsBigIntLiteral(propertyName)) {
			final argumentExpression = propertyName.Clone(tx.Factory());
			return tx.Factory().NewElementAccessExpression(value, null, argumentExpression, NodeFlagsNone);
		} else {
			final name = tx.Factory().NewIdentifier(propertyName.Text());
			return tx.Factory().NewPropertyAccessExpression(value, null, name, NodeFlagsNone);
		}
	}

	function flattenDestructuringAssignment(node:Node, needsValue:Bool):Expression {
		var location = node.Loc;
		var value:Node = null;
		if (Ast.IsDestructuringAssignment(node)) {
			value = node.AsBinaryExpression().Right;
			while (Ast.IsEmptyArrayLiteral(node.AsBinaryExpression().Left) || Ast.IsEmptyObjectLiteral(node.AsBinaryExpression().Left)) {
				if (Ast.IsDestructuringAssignment(value)) {
					node = value;
					location = node.Loc;
					value = node.AsBinaryExpression().Right;
				} else {
					return tx.Visitor().VisitNode(value);
				}
			}
		}

		if (value != null) {
			value = tx.Visitor().VisitNode(value);
			if (Ast.IsIdentifier(value) && Transformers.BindingOrAssignmentElementAssignsToName(node, value.Text())
				|| Transformers.BindingOrAssignmentElementContainsNonLiteralComputedName(node)) {
				value = ensureIdentifier(value, false, location);
			} else if (needsValue) {
				value = ensureIdentifier(value, true, location);
			} else if (Ast.NodeIsSynthesized(node)) {
				location = value.Loc;
			}
		}

		flattenBindingOrAssignmentElement(node, value, location, Ast.IsDestructuringAssignment(node));

		if (value != null && needsValue) {
			if (Core.len(expressions) == 0) {
				return value;
			}
			expressions.push(value);
		}

		final res = tx.Factory().InlineExpressions(expressions);
		if (res != null) {
			return res;
		}
		return tx.Factory().NewOmittedExpression();
	}

	function flattenDestructuringBinding(node:Node, rval:Node, skipInitializer:Bool):Node {
		if (Ast.IsVariableDeclaration(node)) {
			var initializer = Transformers.GetInitializerOfBindingOrAssignmentElement(node);
			if (initializer != null
				&& (Ast.IsIdentifier(initializer) && Transformers.BindingOrAssignmentElementAssignsToName(node, initializer.Text())
					|| Transformers.BindingOrAssignmentElementContainsNonLiteralComputedName(node))) {
				initializer = ensureIdentifier(tx.Visitor().VisitNode(initializer), false, initializer.Loc);
				node = tx.Factory().UpdateVariableDeclaration(node.AsVariableDeclaration(), node.Name(), null, null, initializer);
			}
		}

		flattenBindingOrAssignmentElement(node, rval, node.Loc, skipInitializer);

		if (Core.len(expressions) > 0) {
			final temp = tx.Factory().NewTempVariable();
			if (hoistTempVariables) {
				final value = tx.Factory().InlineExpressions(expressions);
				expressions = null;
				emitBindingOrAssignment(this, temp, value, new TextRange(0, 0), null);
			} else {
				tx.EmitContext().AddVariableDeclaration(temp);
				final last = declarations[declarations.length - 1];
				if (last.pendingExpressions == null) {
					last.pendingExpressions = [];
				}
				last.pendingExpressions.push(tx.Factory().NewAssignmentExpression(temp, last.value));
				for (e in expressions) {
					last.pendingExpressions.push(e);
				}
				last.value = temp;
			}
		}

		final decls:Array<Node> = [];
		if (declarations != null) {
			for (pending in declarations) {
				var expr = pending.value;
				if (Core.len(pending.pendingExpressions) > 0) {
					// PORT: Go append on the pending's own slice; it is not used afterwards.
					final list = pending.pendingExpressions.copy();
					list.push(pending.value);
					expr = tx.Factory().InlineExpressions(list);
				}
				final decl = tx.Factory().NewVariableDeclaration(pending.name, null, null, expr);
				decl.Loc = pending.location;
				if (pending.original != null) {
					tx.EmitContext().SetOriginal(decl, pending.original);
				}
				decls.push(decl);
			}
		}

		if (decls.length == 1) {
			return decls[0];
		}
		if (decls.length == 0) {
			return null;
		}
		return tx.Factory().NewSyntaxList(decls);
	}

	function flattenBindingOrAssignmentElement(element:Node, value:Node, location:TextRange, skipInitializer:Bool):Void {
		final bindingTarget = Ast.GetTargetOfBindingOrAssignmentElement(element);
		if (bindingTarget == null) {
			return;
		}
		if (!skipInitializer) {
			final initializer = tx.Visitor().VisitNode(Transformers.GetInitializerOfBindingOrAssignmentElement(element));
			if (initializer != null) {
				if (value != null) {
					value = createDefaultValueCheck(value, initializer, location);
					if (!Transformers.IsSimpleCopiableExpression(initializer) && (Ast.IsBindingPattern(bindingTarget) || Ast.IsAssignmentPattern(bindingTarget))) {
						value = ensureIdentifier(value, true, location);
					}
				} else {
					value = initializer;
				}
			} else if (value == null) {
				value = tx.Factory().NewVoidZeroExpression();
			}
		}

		if (Transformers.isObjectBindingOrAssignmentPattern(bindingTarget)) {
			flattenObjectBindingOrAssignmentPattern(element, bindingTarget, value, location);
		} else if (Transformers.isArrayBindingOrAssignmentPattern(bindingTarget)) {
			flattenArrayBindingOrAssignmentPattern(element, bindingTarget, value, location);
		} else {
			emitBindingOrAssignment(this, bindingTarget, value, location, element);
		}
	}

	function flattenObjectBindingOrAssignmentPattern(parent:Node, pattern:Node, value:Node, location:TextRange):Void {
		final elements = Ast.GetElementsOfBindingOrAssignmentPattern(pattern);
		final numElements = Core.len(elements);
		if (numElements != 1) {
			final reuseIdentifierExpressions = !Ast.IsDeclarationBindingElement(parent) || numElements != 0;
			value = ensureIdentifier(value, reuseIdentifierExpressions, location);
		}
		var bindingElements:Array<Node> = null;
		var computedTempVariables:Array<Node> = null;
		for (i in 0...numElements) {
			final element = elements[i];
			if (Ast.GetRestIndicatorOfBindingOrAssignmentElement(element) == null) {
				final propertyName = Ast.TryGetPropertyNameOfBindingOrAssignmentElement(element);
				if ((level : Int) >= (FlattenLevelObjectRest : Int)
					&& (element.SubtreeFacts() & (SubtreeContainsRestOrSpread | SubtreeContainsObjectRestOrSpread)) == 0
					&& (Ast.GetTargetOfBindingOrAssignmentElement(element).SubtreeFacts() & (SubtreeContainsRestOrSpread | SubtreeContainsObjectRestOrSpread)) == 0
					&& !Ast.IsComputedPropertyName(propertyName)) {
					if (bindingElements == null) {
						bindingElements = [];
					}
					bindingElements.push(tx.Visitor().VisitNode(element));
				} else {
					if (Core.len(bindingElements) > 0) {
						emitBindingOrAssignment(this, createObjectBindingOrAssignmentPattern(this, bindingElements), value, location, pattern);
						bindingElements = null;
					}
					final rhsValue = createDestructuringPropertyAccess(value, propertyName);
					if (Ast.IsComputedPropertyName(propertyName)) {
						if (computedTempVariables == null) {
							computedTempVariables = [];
						}
						computedTempVariables.push(rhsValue.AsElementAccessExpression().ArgumentExpression);
					}
					flattenBindingOrAssignmentElement(element, rhsValue, element.Loc, false);
				}
			} else if (i == numElements - 1) {
				if (Core.len(bindingElements) > 0) {
					emitBindingOrAssignment(this, createObjectBindingOrAssignmentPattern(this, bindingElements), value, location, pattern);
					bindingElements = null;
				}
				final rhsValue = tx.Factory().NewRestHelper(value, elements, computedTempVariables, pattern.Loc);
				flattenBindingOrAssignmentElement(element, rhsValue, element.Loc, false);
			}
		}
		if (Core.len(bindingElements) > 0) {
			emitBindingOrAssignment(this, createObjectBindingOrAssignmentPattern(this, bindingElements), value, location, pattern);
		}
	}

	function flattenArrayBindingOrAssignmentPattern(parent:Node, pattern:Node, value:Node, location:TextRange):Void {
		final elements = Ast.GetElementsOfBindingOrAssignmentPattern(pattern);
		final numElements = Core.len(elements);
		if (numElements != 1 && ((level : Int) < (FlattenLevelObjectRest : Int) || numElements == 0) || Core.Every(elements, Ast.IsOmittedExpression)) {
			final reuseIdentifierExpressions = !Ast.IsDeclarationBindingElement(parent) || numElements != 0;
			value = ensureIdentifier(value, reuseIdentifierExpressions, location);
		}
		var bindingElements:Array<Node> = null;
		var restContainingElements:Array<RestIdElemPair> = null;
		for (i in 0...numElements) {
			final element = elements[i];
			if ((level : Int) >= (FlattenLevelObjectRest : Int)) {
				if ((element.SubtreeFacts() & SubtreeContainsObjectRestOrSpread) != 0
					|| hasTransformedPriorElement && !Transformers.isSimpleBindingOrAssignmentElement(element)) {
					hasTransformedPriorElement = true;
					final temp = tx.Factory().NewTempVariable();
					if (hoistTempVariables) {
						tx.EmitContext().AddVariableDeclaration(temp);
					}
					final pair = new RestIdElemPair();
					pair.id = temp;
					pair.element = element;
					if (restContainingElements == null) {
						restContainingElements = [];
					}
					restContainingElements.push(pair);
					if (bindingElements == null) {
						bindingElements = [];
					}
					bindingElements.push(createArrayBindingOrAssignmentElement(this, temp));
				} else {
					if (bindingElements == null) {
						bindingElements = [];
					}
					bindingElements.push(element);
				}
			} else if (Ast.IsOmittedExpression(element)) {
				continue;
			} else if (Ast.GetRestIndicatorOfBindingOrAssignmentElement(element) == null) {
				final rhsValue = tx.Factory().NewElementAccessExpression(value, null, tx.Factory().NewNumericLiteral(Std.string(i), TokenFlagsNone), NodeFlagsNone);
				flattenBindingOrAssignmentElement(element, rhsValue, element.Loc, false);
			} else if (i == numElements - 1) {
				final rhsValue = tx.Factory().NewArraySliceCall(value, i);
				flattenBindingOrAssignmentElement(element, rhsValue, element.Loc, false);
			}
		}
		if (Core.len(bindingElements) > 0) {
			emitBindingOrAssignment(this, createArrayBindingOrAssignmentPattern(this, bindingElements), value, location, pattern);
		}
		if (Core.len(restContainingElements) > 0) {
			for (pair in restContainingElements) {
				flattenBindingOrAssignmentElement(pair.element, pair.id, pair.element.Loc, false);
			}
		}
	}
}

@:allow(ts.transformers)
class RestIdElemPair {
	var id:Node = null;
	var element:Node = null;

	public function new() {}
}

