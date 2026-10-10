package ts.transformers;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/Transformers.hx (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Package class: package-level funcs, vars and consts of internal/transformers (all files).
@:allow(ts.transformers)
class Transformers {

	// --- chain.go ---

	// Chains transforms in left-to-right order, running them one at a time in order (as opposed to interleaved at each node)
	// - the resulting combined transform only operates on SourceFile nodes
	public static function Chain(...transforms:TransformerFactory):TransformerFactory {
		if (transforms.length < 2) {
			if (transforms.length == 0) {
				throw "Expected some number of transforms to chain, but got none";
			}
			return transforms[0];
		}
		final transforms = transforms.toArray();
		return function(opt:TransformOptions):Transformer {
			final constructed:Array<Transformer> = [];
			for (t in transforms) {
				// TODO: flatten nested chains?
				final result = t(opt);
				if (result != null) {
					constructed.push(result);
				}
			}
			switch (constructed.length) {
				case 0:
					return null;
				case 1:
					return constructed[0];
				default:
			}
			final ch = new ChainedTransformer();
			ch.components = constructed;
			return ch.NewTransformer(ch.visit, opt.Context);
		};
	}

	// --- destructuring.go ---

	// FlattenDestructuringAssignment flattens a destructuring assignment expression into a sequence of
	// individual property/element access assignments. Supports custom assignment callbacks for module
	// export or namespace member expressions.
	public static function FlattenDestructuringAssignment(tx:Transformer, node:Node, needsValue:Bool, level:FlattenLevel, createAssignmentCallback:CreateAssignmentCallback):Expression {
		final f = newFlattener(tx, level);
		f.createAssignmentCallback = createAssignmentCallback;
		f.hoistTempVariables = true;
		// Assignment mode callbacks
		f.emitBindingOrAssignment = (f, target, value, location, original) -> f.emitAssignment(target, value, location, original);
		f.createArrayBindingOrAssignmentPattern = (f, elements) -> f.createArrayAssignmentPattern(elements);
		f.createObjectBindingOrAssignmentPattern = (f, elements) -> f.createObjectAssignmentPattern(elements);
		f.createArrayBindingOrAssignmentElement = (f, expr) -> f.createArrayAssignmentElement(expr);
		return f.flattenDestructuringAssignment(node, needsValue);
	}

	// FlattenDestructuringBinding flattens a binding pattern in a variable declaration or parameter
	// into individual variable declarations. Returns a single VariableDeclaration, a SyntaxList of
	// declarations, or nil.
	public static function FlattenDestructuringBinding(tx:Transformer, node:Node, rval:Node, level:FlattenLevel, hoistTempVariables:Bool, skipInitializer:Bool):Node {
		final f = newFlattener(tx, level);
		f.hoistTempVariables = hoistTempVariables;
		// Binding mode callbacks
		f.emitBindingOrAssignment = (f, target, value, location, original) -> f.emitBinding(target, value, location, original);
		f.createArrayBindingOrAssignmentPattern = (f, elements) -> f.createArrayBindingPattern(elements);
		f.createObjectBindingOrAssignmentPattern = (f, elements) -> f.createObjectBindingPattern(elements);
		f.createArrayBindingOrAssignmentElement = (f, expr) -> f.createArrayBindingElement(expr);
		return f.flattenDestructuringBinding(node, rval, skipInitializer);
	}

	static function newFlattener(tx:Transformer, level:FlattenLevel):Flattener {
		final f = new Flattener();
		f.tx = tx;
		f.level = level;
		return f;
	}

	// BindingOrAssignmentElementAssignsToName checks if any target in a binding/assignment pattern assigns to the given name.
	public static function BindingOrAssignmentElementAssignsToName(element:Node, name:std.String):Bool {
		final target = Ast.GetTargetOfBindingOrAssignmentElement(element);
		if (target == null) {
			return false;
		}
		if (Ast.IsBindingPattern(target) || Ast.IsAssignmentPattern(target)) {
			return bindingOrAssignmentPatternAssignsToName(target, name);
		} else if (Ast.IsIdentifier(target)) {
			return target.Text() == name;
		}
		return false;
	}

	static function bindingOrAssignmentPatternAssignsToName(pattern:Node, name:std.String):Bool {
		final elements = Ast.GetElementsOfBindingOrAssignmentPattern(pattern);
		if (elements != null) {
			for (element in elements) {
				if (BindingOrAssignmentElementAssignsToName(element, name)) {
					return true;
				}
			}
		}
		return false;
	}

	// BindingOrAssignmentElementContainsNonLiteralComputedName checks if any element has a non-literal computed property name.
	public static function BindingOrAssignmentElementContainsNonLiteralComputedName(element:Node):Bool {
		final propertyName = Ast.TryGetPropertyNameOfBindingOrAssignmentElement(element);
		if (propertyName != null && Ast.IsComputedPropertyName(propertyName) && !Ast.IsLiteralExpression(propertyName.Expression())) {
			return true;
		}
		final target = Ast.GetTargetOfBindingOrAssignmentElement(element);
		return target != null && (Ast.IsBindingPattern(target) || Ast.IsAssignmentPattern(target))
			&& bindingOrAssignmentPatternContainsNonLiteralComputedName(target);
	}

	static function bindingOrAssignmentPatternContainsNonLiteralComputedName(pattern:Node):Bool {
		final elements = Ast.GetElementsOfBindingOrAssignmentPattern(pattern);
		if (elements != null) {
			for (e in elements) {
				if (BindingOrAssignmentElementContainsNonLiteralComputedName(e)) {
					return true;
				}
			}
		}
		return false;
	}

	// GetInitializerOfBindingOrAssignmentElement returns the initializer/default value of a binding or assignment element.
	public static function GetInitializerOfBindingOrAssignmentElement(bindingElement:Node):Node {
		if (bindingElement == null) {
			return null;
		}
		if (Ast.IsDeclarationBindingElement(bindingElement)) {
			return bindingElement.Initializer();
		}
		if (Ast.IsPropertyAssignment(bindingElement)) {
			final initializer = bindingElement.Initializer();
			if (Ast.IsAssignmentExpression(initializer, true)) {
				return initializer.AsBinaryExpression().Right;
			}
			return null;
		}
		if (Ast.IsShorthandPropertyAssignment(bindingElement)) {
			return bindingElement.AsShorthandPropertyAssignment().ObjectAssignmentInitializer;
		}
		if (Ast.IsAssignmentExpression(bindingElement, true)) {
			return bindingElement.AsBinaryExpression().Right;
		}
		if (Ast.IsSpreadElement(bindingElement)) {
			return GetInitializerOfBindingOrAssignmentElement(bindingElement.Expression());
		}
		return null;
	}

	static function isObjectBindingOrAssignmentPattern(node:Node):Bool {
		return node != null && (node.Kind == KindObjectBindingPattern || node.Kind == KindObjectLiteralExpression);
	}

	static function isArrayBindingOrAssignmentPattern(node:Node):Bool {
		return node != null && (node.Kind == KindArrayBindingPattern || node.Kind == KindArrayLiteralExpression);
	}

	static function isSimpleBindingOrAssignmentElement(element:Node):Bool {
		final target = Ast.GetTargetOfBindingOrAssignmentElement(element);
		if (target == null || Ast.IsOmittedExpression(target)) {
			return true;
		}
		final propertyName = Ast.TryGetPropertyNameOfBindingOrAssignmentElement(element);
		if (propertyName != null && !Ast.IsPropertyNameLiteral(propertyName)) {
			return false;
		}
		final initializer = GetInitializerOfBindingOrAssignmentElement(element);
		if (initializer != null && !IsSimpleInlineableExpression(initializer)) {
			return false;
		}
		if (Ast.IsBindingPattern(target) || Ast.IsAssignmentPattern(target)) {
			return Core.Every(Ast.GetElementsOfBindingOrAssignmentPattern(target), isSimpleBindingOrAssignmentElement);
		}
		return Ast.IsIdentifier(target);
	}

	// --- modifiervisitor.go ---

	public static function ExtractModifiers(emitContext:EmitContext, modifiers:ModifierList, allowed:ModifierFlags):ModifierList {
		if (modifiers == null) {
			return null;
		}
		final tx = new ModifierVisitor();
		tx.AllowedModifiers = allowed;
		tx.NewTransformer(tx.visit, emitContext);
		return tx.visitor.VisitModifiers(modifiers);
	}

	// --- utilities.go ---

	public static function IsGeneratedIdentifier(emitContext:EmitContext, name:IdentifierNode):Bool {
		return emitContext.HasAutoGenerateInfo(name);
	}

	public static function IsHelperName(emitContext:EmitContext, name:IdentifierNode):Bool {
		return (emitContext.EmitFlags(name) & EFHelperName) != 0;
	}

	public static function IsLocalName(emitContext:EmitContext, name:IdentifierNode):Bool {
		return (emitContext.EmitFlags(name) & EFLocalName) != 0;
	}

	public static function IsExportName(emitContext:EmitContext, name:IdentifierNode):Bool {
		return (emitContext.EmitFlags(name) & EFExportName) != 0;
	}

	public static function IsIdentifierReference(name:IdentifierNode, parent:Node):Bool {
		switch (parent.Kind) {
			case KindBinaryExpression, KindPrefixUnaryExpression, KindPostfixUnaryExpression, KindYieldExpression, KindAsExpression, KindSatisfiesExpression,
				KindElementAccessExpression, KindNonNullExpression, KindSpreadElement, KindSpreadAssignment, KindParenthesizedExpression,
				KindArrayLiteralExpression, KindDeleteExpression, KindTypeOfExpression, KindVoidExpression, KindAwaitExpression,
				KindTypeAssertionExpression, KindExpressionWithTypeArguments, KindJsxSelfClosingElement, KindJsxSpreadAttribute, KindJsxExpression,
				KindPartiallyEmittedExpression:
				// all immediate children that can be `Identifier` would be instances of `IdentifierReference`
				return true;
			case KindComputedPropertyName, KindDecorator, KindIfStatement, KindDoStatement, KindWhileStatement, KindWithStatement, KindReturnStatement,
				KindSwitchStatement, KindCaseClause, KindThrowStatement, KindExpressionStatement, KindExportAssignment, KindPropertyAccessExpression,
				KindTemplateSpan:
				// only an `Expression()` child that can be `Identifier` would be an instance of `IdentifierReference`
				return parent.Expression() == name;
			case KindVariableDeclaration, KindParameter, KindBindingElement, KindPropertyDeclaration, KindPropertySignature, KindPropertyAssignment,
				KindEnumMember, KindJsxAttribute:
				// only an `Initializer()` child that can be `Identifier` would be an instance of `IdentifierReference`
				return parent.Initializer() == name;
			case KindShorthandPropertyAssignment:
				return parent.AsShorthandPropertyAssignment().ObjectAssignmentInitializer == name;
			case KindForStatement:
				return parent.Initializer() == name || parent.AsForStatement().Condition == name || parent.AsForStatement().Incrementor == name;
			case KindForInStatement, KindForOfStatement:
				return parent.Initializer() == name || parent.Expression() == name;
			case KindImportEqualsDeclaration:
				return parent.AsImportEqualsDeclaration().ModuleReference == name;
			case KindArrowFunction:
				return parent.Body() == name;
			case KindConditionalExpression:
				return parent.AsConditionalExpression().Condition == name || parent.AsConditionalExpression().WhenTrue == name
					|| parent.AsConditionalExpression().WhenFalse == name;
			case KindCallExpression, KindNewExpression:
				return parent.Expression() == name || Slices.Contains(parent.Arguments(), name);
			case KindTaggedTemplateExpression:
				return parent.AsTaggedTemplateExpression().Tag == name;
			case KindImportAttribute:
				return parent.AsImportAttribute().Value == name;
			case KindJsxOpeningElement, KindJsxClosingElement:
				return parent.TagName() == name;
			default:
				return false;
		}
	}

	static function convertBindingElementToArrayAssignmentElement(emitContext:EmitContext, element:BindingElement):Expression {
		if (element.Name() == null) {
			final elision = emitContext.Factory.NewOmittedExpression();
			emitContext.SetOriginal(elision, element.AsNode());
			emitContext.AssignCommentAndSourceMapRanges(elision, element.AsNode());
			return elision;
		}
		if (element.DotDotDotToken != null) {
			final spread = emitContext.Factory.NewSpreadElement(element.Name());
			emitContext.SetOriginal(spread, element.AsNode());
			emitContext.AssignCommentAndSourceMapRanges(spread, element.AsNode());
			return spread;
		}
		final expression = convertBindingNameToAssignmentElementTarget(emitContext, element.Name());
		if (element.Initializer != null) {
			final assignment = emitContext.Factory.NewAssignmentExpression(expression, element.Initializer);
			emitContext.SetOriginal(assignment, element.AsNode());
			emitContext.AssignCommentAndSourceMapRanges(assignment, element.AsNode());
			return assignment;
		}
		return expression;
	}

	static function convertBindingElementToObjectAssignmentElement(emitContext:EmitContext, element:BindingElement):ObjectLiteralElement {
		if (element.DotDotDotToken != null) {
			final spread = emitContext.Factory.NewSpreadAssignment(element.Name());
			emitContext.SetOriginal(spread, element.AsNode());
			emitContext.AssignCommentAndSourceMapRanges(spread, element.AsNode());
			return spread;
		}
		if (element.PropertyName != null) {
			var expression = convertBindingNameToAssignmentElementTarget(emitContext, element.Name());
			if (element.Initializer != null) {
				expression = emitContext.Factory.NewAssignmentExpression(expression, element.Initializer);
			}
			final assignment = emitContext.Factory.NewPropertyAssignment(null /*modifiers*/, element.PropertyName, null /*postfixToken*/, null /*typeNode*/,
				expression);
			emitContext.SetOriginal(assignment, element.AsNode());
			emitContext.AssignCommentAndSourceMapRanges(assignment, element.AsNode());
			return assignment;
		}
		var equalsToken:TokenNode = null;
		if (element.Initializer != null) {
			equalsToken = emitContext.Factory.NewToken(KindEqualsToken);
		}
		final assignment = emitContext.Factory.NewShorthandPropertyAssignment(null, /*modifiers*/
			element.Name(), null, /*postfixToken*/
			null, /*typeNode*/
			equalsToken, element.Initializer);
		emitContext.SetOriginal(assignment, element.AsNode());
		emitContext.AssignCommentAndSourceMapRanges(assignment, element.AsNode());
		return assignment;
	}

	public static function ConvertBindingPatternToAssignmentPattern(emitContext:EmitContext, element:BindingPattern):Expression {
		switch (element.Kind) {
			case KindArrayBindingPattern:
				return convertBindingElementToArrayAssignmentPattern(emitContext, element);
			case KindObjectBindingPattern:
				return convertBindingElementToObjectAssignmentPattern(emitContext, element);
			default:
				throw "Unknown binding pattern";
		}
	}

	static function convertBindingElementToObjectAssignmentPattern(emitContext:EmitContext, element:BindingPattern):Expression {
		var properties:Array<ObjectLiteralElement> = null;
		for (element in element.Elements.Nodes) {
			if (properties == null) {
				properties = [];
			}
			properties.push(convertBindingElementToObjectAssignmentElement(emitContext, element.AsBindingElement()));
		}
		final propertyList = emitContext.Factory.NewNodeList(properties);
		propertyList.Loc = element.Elements.Loc;
		final object = emitContext.Factory.NewObjectLiteralExpression(propertyList, false /*multiLine*/);
		emitContext.SetOriginal(object, element.AsNode());
		emitContext.AssignCommentAndSourceMapRanges(object, element.AsNode());
		return object;
	}

	static function convertBindingElementToArrayAssignmentPattern(emitContext:EmitContext, element:BindingPattern):Expression {
		var elements:Array<Expression> = null;
		for (element in element.Elements.Nodes) {
			if (elements == null) {
				elements = [];
			}
			elements.push(convertBindingElementToArrayAssignmentElement(emitContext, element.AsBindingElement()));
		}
		final elementList = emitContext.Factory.NewNodeList(elements);
		elementList.Loc = element.Elements.Loc;
		final object = emitContext.Factory.NewArrayLiteralExpression(elementList, false /*multiLine*/);
		emitContext.SetOriginal(object, element.AsNode());
		emitContext.AssignCommentAndSourceMapRanges(object, element.AsNode());
		return object;
	}

	static function convertBindingNameToAssignmentElementTarget(emitContext:EmitContext, element:Node):Expression {
		if (Ast.IsBindingPattern(element)) {
			return ConvertBindingPatternToAssignmentPattern(emitContext, element.AsBindingPattern());
		}
		return element;
	}

	public static function ConvertVariableDeclarationToAssignmentExpression(emitContext:EmitContext, element:VariableDeclaration):Expression {
		if (element.Initializer == null) {
			return null;
		}
		final expression = convertBindingNameToAssignmentElementTarget(emitContext, element.Name());
		final assignment = emitContext.Factory.NewAssignmentExpression(expression, element.Initializer);
		emitContext.SetOriginal(assignment, element.AsNode());
		emitContext.AssignCommentAndSourceMapRanges(assignment, element.AsNode());
		return assignment;
	}

	public static function SingleOrMany(nodes:Array<Node>, factory:ts.printer.Factory.NodeFactory):Node {
		if (nodes == null) {
			return null;
		}
		if (nodes.length == 1) {
			return nodes[0];
		}
		return factory.NewSyntaxList(nodes);
	}

	// Used in the module transformer to check if an expression is reasonably without sideeffect,
	//
	//	and thus better to copy into multiple places rather than to cache in a temporary variable
	//	- this is mostly subjective beyond the requirement that the expression not be sideeffecting
	//
	// Also used by the logical assignment downleveling transform to skip temp variables when they're
	// not needed.
	public static function IsSimpleCopiableExpression(expression:Expression):Bool {
		return Ast.IsStringLiteralLike(expression) || Ast.IsNumericLiteral(expression) || Ast.IsKeywordKind(expression.Kind) || Ast.IsIdentifier(expression);
	}

	public static function IsOriginalNodeSingleLine(emitContext:EmitContext, node:Node):Bool {
		if (node == null) {
			return false;
		}
		final original = emitContext.MostOriginal(node);
		if (original == null) {
			return false;
		}
		final source = Ast.GetSourceFileOfNode(original);
		if (source == null) {
			return false;
		}
		final startLine = Scanner.GetECMALineOfPosition(source, original.Loc.Pos());
		final endLine = Scanner.GetECMALineOfPosition(source, original.Loc.End());
		return startLine == endLine;
	}

	/**
	 * A simple inlinable expression is an expression which can be copied into multiple locations
	 * without risk of repeating any sideeffects and whose value could not possibly change between
	 * any such locations
	 */
	public static function IsSimpleInlineableExpression(expression:Expression):Bool {
		return !Ast.IsIdentifier(expression) && IsSimpleCopiableExpression(expression);
	}

	// FindSuperStatementIndexPath finds a path of indices to a statement containing a `super()` call.
	public static function FindSuperStatementIndexPath(statements:Array<Statement>, start:Int):Array<Int> {
		final indices = findSuperStatementIndexPathWorker(statements, start, null);
		if (indices != null) {
			indices.reverse();
		}
		return indices;
	}

	static function findSuperStatementIndexPathWorker(statements:Array<Statement>, start:Int, indices:Array<Int>):Array<Int> {
		var i = start;
		while (i < Core.len(statements)) {
			final statement = statements[i];
			if (GetSuperCallFromStatement(statement) != null) {
				return append(indices, i);
			} else if (Ast.IsTryStatement(statement)) {
				final result = findSuperStatementIndexPathWorker(statement.AsTryStatement().TryBlock.Statements(), 0, indices);
				if (result != null) {
					return append(result, i);
				}
			}
			i++;
		}
		return null;
	}

	// GetSuperCallFromStatement extracts the super() call expression from an expression statement, if any.
	public static function GetSuperCallFromStatement(statement:Statement):Node {
		if (!Ast.IsExpressionStatement(statement)) {
			return null;
		}
		final expression = Ast.SkipParentheses(statement.Expression());
		if (Ast.IsSuperCall(expression)) {
			return expression;
		}
		return null;
	}

	// MoveRangePastModifiers returns a text range that starts past any modifiers on the node.
	public static function MoveRangePastModifiers(node:Node):TextRange {
		if (Ast.IsPropertyDeclaration(node) || Ast.IsMethodDeclaration(node)) {
			return Core.NewTextRange(node.Name().Pos(), node.End());
		}

		var lastModifier:Node = null;
		if (Ast.CanHaveModifiers(node)) {
			lastModifier = Core.LastOrNil(node.ModifierNodes());
		}

		if (lastModifier != null && !Ast.PositionIsSynthesized(lastModifier.End())) {
			return Core.NewTextRange(lastModifier.End(), node.End());
		}
		return MoveRangePastDecorators(node);
	}

	// MoveRangePastDecorators returns a text range that starts past any decorators on the node.
	public static function MoveRangePastDecorators(node:Node):TextRange {
		var lastDecorator:Node = null;
		if (Ast.CanHaveModifiers(node)) {
			final nodes = node.ModifierNodes();
			if (nodes != null) {
				lastDecorator = Core.FindLast(nodes, Ast.IsDecorator);
			}
		}

		if (lastDecorator != null && !Ast.PositionIsSynthesized(lastDecorator.End())) {
			return Core.NewTextRange(lastDecorator.End(), node.End());
		}
		return node.Loc;
	}

	// GetNonAssignmentOperatorForCompoundAssignment returns the non-assignment operator for a compound assignment.
	public static function GetNonAssignmentOperatorForCompoundAssignment(kind:Kind):Kind {
		switch (kind) {
			case KindPlusEqualsToken:
				return KindPlusToken;
			case KindMinusEqualsToken:
				return KindMinusToken;
			case KindAsteriskEqualsToken:
				return KindAsteriskToken;
			case KindAsteriskAsteriskEqualsToken:
				return KindAsteriskAsteriskToken;
			case KindSlashEqualsToken:
				return KindSlashToken;
			case KindPercentEqualsToken:
				return KindPercentToken;
			case KindLessThanLessThanEqualsToken:
				return KindLessThanLessThanToken;
			case KindGreaterThanGreaterThanEqualsToken:
				return KindGreaterThanGreaterThanToken;
			case KindGreaterThanGreaterThanGreaterThanEqualsToken:
				return KindGreaterThanGreaterThanGreaterThanToken;
			case KindAmpersandEqualsToken:
				return KindAmpersandToken;
			case KindBarEqualsToken:
				return KindBarToken;
			case KindCaretEqualsToken:
				return KindCaretToken;
			case KindBarBarEqualsToken:
				return KindBarBarToken;
			case KindAmpersandAmpersandEqualsToken:
				return KindAmpersandAmpersandToken;
			case KindQuestionQuestionEqualsToken:
				return KindQuestionQuestionToken;
			default:
		}
		return kind;
	}

	// PORT: Go `append(indices, i)` on a nil-able slice. The worker's recursive appends share the
	// caller's backing array in Go only when capacity allows; each result is used once, so a push
	// on the (owned) array is equivalent.
	static function append(s:Array<Int>, x:Int):Array<Int> {
		if (s == null) {
			s = [];
		}
		s.push(x);
		return s;
	}
}
