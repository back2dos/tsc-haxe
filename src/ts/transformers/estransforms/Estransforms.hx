package ts.transformers.estransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/estransforms/Estransforms.hx (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Package class: package-level funcs, vars and consts of internal/transformers/estransforms (all files).
@:allow(ts.transformers.estransforms)
class Estransforms {

	// --- async.go ---

	static function newAsyncTransformer(opts:TransformOptions):Transformer {
		final tx = new AsyncTransformer();
		final result = tx.Transformer.NewTransformer(tx.visit, opts.Context);
		tx.superAccessState.initSuperAccessVisitor(tx.EmitContext(), tx.Factory());
		tx.asyncBodyVisitor = tx.EmitContext().NewNodeVisitor(tx.visitAsyncBodyNode);
		tx.fallbackNodeVisitor = tx.EmitContext().NewNodeVisitor(tx.visitFallback);
		return result;
	}

	// assignmentTargetContainsSuperProperty checks top-down whether an assignment target
	// expression contains a super property or element access (super.x or super[x]).
	// This avoids relying on parent pointers (IsAssignmentTarget) which may not be set
	// on synthesized AST nodes from prior transforms.
	static function assignmentTargetContainsSuperProperty(node:Node):Bool {
		switch (node.Kind) {
			case KindPropertyAccessExpression, KindElementAccessExpression:
				return node.Expression().Kind == KindSuperKeyword;
			case KindParenthesizedExpression:
				return assignmentTargetContainsSuperProperty(node.AsParenthesizedExpression().Expression);
			case KindArrayLiteralExpression:
				// PORT: slices.ContainsFunc → Core.Some (same semantics).
				return Core.Some(node.AsArrayLiteralExpression().Elements.Nodes, assignmentTargetContainsSuperProperty);
			case KindObjectLiteralExpression:
				for (prop in node.AsObjectLiteralExpression().Properties.Nodes) {
					switch (prop.Kind) {
						case KindPropertyAssignment:
							if (assignmentTargetContainsSuperProperty(prop.AsPropertyAssignment().Initializer)) {
								return true;
							}
						case KindShorthandPropertyAssignment:
							if (assignmentTargetContainsSuperProperty(prop.AsShorthandPropertyAssignment().Name())) {
								return true;
							}
						case KindSpreadAssignment:
							if (assignmentTargetContainsSuperProperty(prop.AsSpreadAssignment().Expression)) {
								return true;
							}
						default:
					}
				}
			case KindSpreadElement:
				return assignmentTargetContainsSuperProperty(node.AsSpreadElement().Expression);
			default:
		}
		return false;
	}

	// isUpdateExpression checks if a prefix/postfix unary expression is ++ or --.
	static function isUpdateExpression(node:Node):Bool {
		if (Ast.IsPrefixUnaryExpression(node)) {
			final op = node.AsPrefixUnaryExpression().Operator;
			return op == KindPlusPlusToken || op == KindMinusMinusToken;
		}
		if (Ast.IsPostfixUnaryExpression(node)) {
			final op = node.AsPostfixUnaryExpression().Operator;
			return op == KindPlusPlusToken || op == KindMinusMinusToken;
		}
		return false;
	}

	// isSimpleParameterList checks if every parameter has no initializer and an Identifier name.
	static function isSimpleParameterList(params:Array<Node>):Bool {
		// PORT: range over a possibly-nil slice.
		if (params != null) {
			for (param in params) {
				final p = param.AsParameterDeclaration();
				if (p.Initializer != null || !Ast.IsIdentifier(p.Name())) {
					return false;
				}
			}
		}
		return true;
	}

	// isNodeWithPossibleHoistedDeclaration checks if a node could contain hoisted declarations.
	static function isNodeWithPossibleHoistedDeclaration(node:Node):Bool {
		switch (node.Kind) {
			case KindBlock, KindVariableStatement, KindWithStatement, KindIfStatement, KindSwitchStatement, KindCaseBlock, KindCaseClause,
				KindDefaultClause, KindLabeledStatement, KindForStatement, KindForInStatement, KindForOfStatement, KindDoStatement,
				KindWhileStatement, KindTryStatement, KindCatchClause:
				return true;
			default:
		}
		return false;
	}

	// --- classfields.go ---

	static function newClassFieldsTransformer(opts:TransformOptions):Transformer {
		final languageVersion = opts.CompilerOptions.GetEmitScriptTarget();
		final useDefineForClassFields = opts.CompilerOptions.GetUseDefineForClassFields();

		// When targeting ESNext+ with useDefineForClassFields (the default), there are no class
		// field transformations to perform and no prior transform sets EFTransformPrivateStaticElements,
		// so every node would be returned unchanged. Skip entirely.
		if ((languageVersion : Int) >= (ScriptTargetESNext : Int) && useDefineForClassFields) {
			return null;
		}

		final tx = new ClassFieldsTransformer();
		tx.compilerOptions = opts.CompilerOptions;
		tx.resolver = opts.Resolver;
		tx.legacyDecorators = opts.CompilerOptions.ExperimentalDecorators.IsTrue();

		// Always transform field initializers using Set semantics when `useDefineForClassFields: false`.
		tx.shouldTransformInitializersUsingSet = !useDefineForClassFields;

		// Transform field initializers using Define semantics when `useDefineForClassFields: true` and target < ES2022.
		tx.shouldTransformInitializersUsingDefine = useDefineForClassFields && (languageVersion : Int) < (ScriptTargetES2022 : Int);

		tx.shouldTransformInitializers = tx.shouldTransformInitializersUsingSet || tx.shouldTransformInitializersUsingDefine;

		// We need to transform private members and class static blocks when target < ES2022.
		tx.shouldTransformPrivateElementsOrClassStaticBlocks = (languageVersion : Int) < (ScriptTargetES2022 : Int);

		// We need to transform `accessor` fields when target < ESNext.
		// We may need to transform `accessor` fields when `useDefineForClassFields: false`
		tx.shouldTransformAutoAccessors = (languageVersion : Int) < (ScriptTargetESNext : Int);

		// We need to transform `this` in a static initializer into a reference to the class
		// when target < ES2022 since the assignment will be moved outside of the class body.
		tx.shouldTransformThisInStaticInitializers = (languageVersion : Int) < (ScriptTargetES2022 : Int);

		// Since target is always >= ES2015, this is always the same as
		// shouldTransformThisInStaticInitializers.
		tx.shouldTransformSuperInStaticInitializers = tx.shouldTransformThisInStaticInitializers;

		final result = tx.Transformer.NewTransformer(tx.visit, opts.Context);
		tx.modifierVisitor = tx.Transformer.EmitContext().NewNodeVisitor(tx.visitModifier);
		tx.discardedValueVisitor = tx.Transformer.EmitContext().NewNodeVisitor(tx.visitDiscardedValue);
		tx.heritageClauseVisitor = tx.Transformer.EmitContext().NewNodeVisitor(tx.visitHeritageClause);
		tx.assignmentTargetVisitor = tx.Transformer.EmitContext().NewNodeVisitor(tx.visitAssignmentTarget);
		tx.classElementVisitor = tx.Transformer.EmitContext().NewNodeVisitor(tx.visitClassElement);
		tx.accessorFieldResultVisitor = tx.Transformer.EmitContext().NewNodeVisitor(tx.visitAccessorFieldResult);
		tx.arrayAssignmentElementVisitor = tx.Transformer.EmitContext().NewNodeVisitor(tx.visitArrayAssignmentElement);
		tx.objectAssignmentElementVisitor = tx.Transformer.EmitContext().NewNodeVisitor(tx.visitObjectAssignmentElement);
		tx.substitutionVisitor = tx.Transformer.EmitContext().NewNodeVisitor(tx.visitForSubstitution);
		tx.isAnonymousClassNeedingAssignedName = tx.isAnonymousClassNeedingAssignedNameWorker;

		return result;
	}

	static function createPrivateStaticFieldInitializer(factory:ts.printer.Factory.NodeFactory, variableName:IdentifierNode, initializer:Expression):Expression {
		if (initializer == null) {
			initializer = factory.NewVoidZeroExpression();
		}
		return factory.NewAssignmentExpression(variableName,
			factory.NewObjectLiteralExpression(factory.NewNodeList([
				factory.NewPropertyAssignment(null, factory.NewIdentifier("value"), null, null, initializer),
			]), false));
	}

	static function createPrivateInstanceFieldInitializer(factory:ts.printer.Factory.NodeFactory, receiver:Expression, initializer:Expression, weakMapName:IdentifierNode):Expression {
		if (initializer == null) {
			initializer = factory.NewVoidZeroExpression();
		}
		return factory.NewMethodCall(weakMapName, factory.NewIdentifier("set"), [receiver, initializer]);
	}

	static function createPrivateInstanceMethodInitializer(factory:ts.printer.Factory.NodeFactory, receiver:Expression, weakSetName:IdentifierNode):Expression {
		return factory.NewMethodCall(weakSetName, factory.NewIdentifier("add"), [receiver]);
	}

	static function isStaticPropertyDeclarationOrClassStaticBlock(node:Node):Bool {
		return Ast.IsClassStaticBlockDeclaration(node) || (Ast.IsPropertyDeclaration(node) && Ast.HasStaticModifier(node));
	}

	// classHasClassThisAssignment checks if a class has a static block that is a class-this assignment.
	static function classHasClassThisAssignment(emitContext:EmitContext, node:Node):Bool {
		for (member in (node.Members() ?? [])) { // PORT: range over a possibly-nil slice
			if (isClassThisAssignmentBlock(emitContext, member)) {
				return true;
			}
		}
		return false;
	}

	static function isNonStaticMethodOrAccessorWithPrivateName(member:Node):Bool {
		return !Ast.IsStatic(member) && (Ast.IsMethodOrAccessor(member) || Ast.IsAutoAccessorPropertyDeclaration(member))
			&& Ast.IsPrivateIdentifier(member.Name());
	}

	static function createMemberAccessForPropertyName(factory:ts.printer.Factory.NodeFactory, emitContext:EmitContext, receiver:Expression, name:PropertyName, location:PropertyName):Expression {
		if (Ast.IsComputedPropertyName(name)) {
			final expression = factory.NewElementAccessExpression(receiver, null, name.Expression(), NodeFlagsNone);
			expression.Loc = location.Loc;
			return expression;
		}
		var expression:Expression = null;
		if (Ast.IsIdentifier(name) || Ast.IsPrivateIdentifier(name)) {
			expression = factory.NewPropertyAccessExpression(receiver, null, name, NodeFlagsNone);
		} else {
			// string or numeric literal
			expression = factory.NewElementAccessExpression(receiver, null, name, NodeFlagsNone);
		}
		emitContext.SetCommentRange(expression, name.Loc);
		emitContext.SetSourceMapRange(expression, name.Loc);
		emitContext.AddEmitFlags(expression, EFNoNestedSourceMaps);
		return expression;
	}

	static function shouldBeCapturedInTempVariable(node:Node):Bool {
		final target = Ast.SkipParentheses(node);
		switch (target.Kind) {
			case KindIdentifier, KindThisKeyword, KindNumericLiteral, KindBigIntLiteral, KindStringLiteral:
				return false;
			default:
				return true;
		}
	}

	// flattenCommaList decomposes a comma expression tree into a sequence of expressions.
	static function flattenCommaList(node:Expression):(yield:(Expression) -> Bool) -> Void {
		return function(yield:(Expression) -> Bool):Void {
			flattenCommaListWorker(node, yield);
		};
	}

	static function flattenCommaListWorker(node:Expression, yield:(Expression) -> Bool):Bool {
		if (Ast.IsParenthesizedExpression(node) && Ast.NodeIsSynthesized(node)) {
			return flattenCommaListWorker(node.Expression(), yield);
		} else if (Ast.IsCommaExpression(node.AsNode())) {
			return flattenCommaListWorker(node.AsBinaryExpression().Left, yield) && flattenCommaListWorker(node.AsBinaryExpression().Right, yield);
		} else {
			return yield(node);
		}
	}

	static function findComputedPropertyNameCacheAssignment(emitContext:EmitContext, name:Node):BinaryExpression {
		var node = name.Expression();
		while (true) {
			node = Ast.SkipOuterExpressions(node, 0);
			if (Ast.IsBinaryExpression(node) && node.AsBinaryExpression().OperatorToken.Kind == KindCommaToken) {
				node = node.AsBinaryExpression().Right;
				continue;
			}
			if (Ast.IsAssignmentExpression(node, true /*excludeCompoundAssignment*/) && Ast.IsIdentifier(node.AsBinaryExpression().Left)) {
				return node.AsBinaryExpression();
			}
			break;
		}
		return null;
	}

	static function expandPreOrPostfixIncrementOrDecrementExpression(factory:ts.printer.Factory.NodeFactory, emitContext:EmitContext, node:Node, expression:Expression, resultVariable:IdentifierNode):Expression {
		var operator_:Kind = KindUnknown;
		var operand:Node = null;
		if (Ast.IsPrefixUnaryExpression(node)) {
			operator_ = node.AsPrefixUnaryExpression().Operator;
			operand = node.AsPrefixUnaryExpression().Operand;
		} else {
			operator_ = node.AsPostfixUnaryExpression().Operator;
			operand = node.AsPostfixUnaryExpression().Operand;
		}

		final temp = factory.NewTempVariable();
		emitContext.AddVariableDeclaration(temp);
		expression = factory.NewAssignmentExpression(temp, expression);
		expression.Loc = operand.Loc;

		var operation:Expression = null;
		if (Ast.IsPrefixUnaryExpression(node)) {
			operation = factory.NewPrefixUnaryExpression(operator_, temp);
		} else {
			operation = factory.NewPostfixUnaryExpression(temp, operator_);
		}
		operation.Loc = node.Loc;

		if (resultVariable != null) {
			operation = factory.NewAssignmentExpression(resultVariable, operation);
			operation.Loc = node.Loc;
		}

		expression = factory.NewCommaExpression(expression, operation);
		expression.Loc = node.Loc;

		if (Ast.IsPostfixUnaryExpression(node)) {
			expression = factory.NewCommaExpression(expression, temp);
			expression.Loc = node.Loc;
		}

		return expression;
	}

	// --- classthis.go ---

	// Gets whether a node is a `static {}` block containing only a single assignment of the static `this` to the `_classThis`
	// (or similar) variable stored in the `classthis` property of the block's `EmitNode`.
	static function isClassThisAssignmentBlock(emitContext:EmitContext, node:Node):Bool {
		if (Ast.IsClassStaticBlockDeclaration(node)) {
			final n = node.AsClassStaticBlockDeclaration();
			final body = n.Body.AsBlock();
			if (Core.len(body.Statements.Nodes) == 1) {
				final statement = body.Statements.Nodes[0];
				if (Ast.IsExpressionStatement(statement)) {
					final expression = statement.Expression();
					if (Ast.IsAssignmentExpression(expression, true /*excludeCompoundAssignment*/)) {
						final binary = expression.AsBinaryExpression();
						return Ast.IsIdentifier(binary.Left) && emitContext.ClassThis(node) == binary.Left && binary.Right.Kind == KindThisKeyword;
					}
				}
			}
		}
		return false;
	}

	// --- definitions.go ---

	// PORT: Go package vars initialized at package init → lazy getters (static init order is undefined in Haxe).
	static var esDecoratorAndClassFields(get, never):TransformerFactory;
	static var esDecoratorAndClassFields_:TransformerFactory = null;

	static function get_esDecoratorAndClassFields():TransformerFactory {
		if (esDecoratorAndClassFields_ == null) {
			esDecoratorAndClassFields_ = Transformers.Chain(newESDecoratorTransformer, newClassFieldsTransformer);
		}
		return esDecoratorAndClassFields_;
	}

	public static var NewESNextTransformer(get, never):TransformerFactory;
	static var NewESNextTransformer_:TransformerFactory = null;

	static function get_NewESNextTransformer():TransformerFactory {
		if (NewESNextTransformer_ == null) {
			NewESNextTransformer_ = Transformers.Chain(newUsingDeclarationTransformer, esDecoratorAndClassFields);
		}
		return NewESNextTransformer_;
	}

	// 2025: only module system syntax (import attributes, json modules), untransformed regex modifiers
	// 2024: no new downlevel syntax
	// 2023: no new downlevel syntax
	// 2022: class static blocks and class fields are handled by newClassFieldsTransformer
	public static var NewES2021Transformer(get, never):TransformerFactory;
	static var NewES2021Transformer_:TransformerFactory = null;

	static function get_NewES2021Transformer():TransformerFactory {
		if (NewES2021Transformer_ == null) {
			NewES2021Transformer_ = Transformers.Chain(NewESNextTransformer, newLogicalAssignmentTransformer);
		}
		return NewES2021Transformer_;
	}

	public static var NewES2020Transformer(get, never):TransformerFactory;
	static var NewES2020Transformer_:TransformerFactory = null;

	static function get_NewES2020Transformer():TransformerFactory {
		if (NewES2020Transformer_ == null) {
			NewES2020Transformer_ = Transformers.Chain(NewES2021Transformer, newNullishCoalescingTransformer, newOptionalChainTransformer);
		}
		return NewES2020Transformer_;
	}

	public static var NewES2019Transformer(get, never):TransformerFactory;
	static var NewES2019Transformer_:TransformerFactory = null;

	static function get_NewES2019Transformer():TransformerFactory {
		if (NewES2019Transformer_ == null) {
			NewES2019Transformer_ = Transformers.Chain(NewES2020Transformer, newOptionalCatchTransformer);
		}
		return NewES2019Transformer_;
	}

	public static var NewES2018Transformer(get, never):TransformerFactory;
	static var NewES2018Transformer_:TransformerFactory = null;

	static function get_NewES2018Transformer():TransformerFactory {
		if (NewES2018Transformer_ == null) {
			NewES2018Transformer_ = Transformers.Chain(NewES2019Transformer, newObjectRestSpreadTransformer, newforawaitTransformer,
				newTaggedTemplateLiftRestrictionTransformer);
		}
		return NewES2018Transformer_;
	}

	public static var NewES2017Transformer(get, never):TransformerFactory;
	static var NewES2017Transformer_:TransformerFactory = null;

	static function get_NewES2017Transformer():TransformerFactory {
		if (NewES2017Transformer_ == null) {
			NewES2017Transformer_ = Transformers.Chain(NewES2018Transformer, newAsyncTransformer);
		}
		return NewES2017Transformer_;
	}

	public static var NewES2016Transformer(get, never):TransformerFactory;
	static var NewES2016Transformer_:TransformerFactory = null;

	static function get_NewES2016Transformer():TransformerFactory {
		if (NewES2016Transformer_ == null) {
			NewES2016Transformer_ = Transformers.Chain(NewES2017Transformer, newExponentiationTransformer);
		}
		return NewES2016Transformer_;
	}

	public static function GetESTransformer(opts:TransformOptions):Transformer {
		final options = opts.CompilerOptions;
		switch (options.GetEmitScriptTarget()) {
			case ScriptTargetESNext:
				return esDecoratorAndClassFields(opts);
			case ScriptTargetES2025, ScriptTargetES2024, ScriptTargetES2023, ScriptTargetES2022, ScriptTargetES2021:
				return NewESNextTransformer(opts);
			case ScriptTargetES2020:
				return NewES2021Transformer(opts);
			case ScriptTargetES2019:
				return NewES2020Transformer(opts);
			case ScriptTargetES2018:
				return NewES2019Transformer(opts);
			case ScriptTargetES2017:
				return NewES2018Transformer(opts);
			case ScriptTargetES2016:
				return NewES2017Transformer(opts);
			default: // other, older, option, transform maximally
				return NewES2016Transformer(opts);
		}
	}

	// --- esdecorator.go ---

	static function newESDecoratorTransformer(opts:TransformOptions):Transformer {
		// When experimentalDecorators is set, the legacy decorator transformer handles all
		// decorators. When targeting ESNext with useDefineForClassFields, there's nothing to
		// transform. In either case every node would be returned unchanged, so skip entirely.
		if (opts.CompilerOptions.ExperimentalDecorators.IsTrue()
			|| (opts.CompilerOptions.GetEmitScriptTarget() >= ScriptTargetESNext && opts.CompilerOptions.GetUseDefineForClassFields())) {
			return null;
		}
		final tx = new EsDecoratorTransformer();
		tx.compilerOptions = opts.CompilerOptions;
		final result = tx.Transformer.NewTransformer(tx.visit, opts.Context);
		final ec = tx.Transformer.EmitContext();
		tx.outerThisVisitor = ec.NewNodeVisitor(tx.outerThisVisit);
		tx.discardedVisitor = ec.NewNodeVisitor(tx.discardedValueVisit);
		tx.modifierVisitor = ec.NewNodeVisitor(tx.modifierVisitorVisit);
		tx.exportStrippingModifierVisitor = ec.NewNodeVisitor(tx.exportStrippingModifierVisit);
		tx.classElementVisitor = ec.NewNodeVisitor(tx.classElementVisitorVisit);
		tx.nonConstructorClassElementVisitor = ec.NewNodeVisitor(tx.nonConstructorClassElementVisit);
		tx.constructorClassElementVisitor = ec.NewNodeVisitor(tx.constructorClassElementVisit);
		tx.arrayAssignmentVisitor = ec.NewNodeVisitor(tx.visitArrayAssignmentElement);
		tx.objectAssignmentVisitor = ec.NewNodeVisitor(tx.visitObjectAssignmentElement);
		tx.staticOnlyModifierVisitor = ec.NewNodeVisitor(function(node:Node):Node {
			if (node.Kind == KindStaticKeyword) {
				return node;
			}
			return null;
		});
		tx.asyncOnlyModifierVisitor = ec.NewNodeVisitor(function(node:Node):Node {
			if (node.Kind == KindAsyncKeyword) {
				return node;
			}
			return null;
		});
		tx.accessorStrippingModifierVisitor = ec.NewNodeVisitor(function(node:Node):Node {
			if (node.Kind == KindAccessorKeyword) {
				return null;
			}
			return node;
		});
		// PORT: cached method values, see EsDecoratorTransformer.createMethodDescriptorObjectFunc.
		tx.createMethodDescriptorObjectFunc = tx.createMethodDescriptorObject;
		tx.createGetAccessorDescriptorObjectFunc = tx.createGetAccessorDescriptorObject;
		tx.createSetAccessorDescriptorObjectFunc = tx.createSetAccessorDescriptorObject;
		tx.createAccessorPropertyDescriptorObjectFunc = tx.createAccessorPropertyDescriptorObject;
		return result;
	}

	static function getHelperVariableName(ec:EmitContext, node:Node):std.String {
		final name = node.Name();
		var declarationName = "";
		if (name != null && Ast.IsIdentifier(name) && !Transformers.IsGeneratedIdentifier(ec, name)) {
			declarationName = name.Text();
		} else if (name != null && Ast.IsPrivateIdentifier(name) && !ec.HasAutoGenerateInfo(name)) {
			final text = name.Text();
			if (text.length > 1) {
				declarationName = text.substring(1);
			}
		} else if (name != null && Ast.IsStringLiteral(name) && Scanner.IsIdentifierText(name.Text(), LanguageVariantStandard)) {
			declarationName = name.Text();
		} else if (Ast.IsClassLike(node)) {
			declarationName = "class";
		} else {
			declarationName = "member";
		}

		if (Ast.IsGetAccessorDeclaration(node)) {
			declarationName = "get_" + declarationName;
		}
		if (Ast.IsSetAccessorDeclaration(node)) {
			declarationName = "set_" + declarationName;
		}
		if (name != null && Ast.IsPrivateIdentifier(name)) {
			declarationName = "private_" + declarationName;
		}
		if (Ast.IsStatic(node)) {
			declarationName = "static_" + declarationName;
		}
		return "_" + declarationName;
	}

	static function isDecoratedClassLike(node:Node):Bool {
		return Ast.ClassOrConstructorParameterIsDecorated(false, node) || Ast.ChildIsDecorated(false, node, null);
	}

	static function isAnonymousClassNeedingAssignedName(node:Node):Bool {
		return Ast.IsClassExpression(node) && node.Name() == null && isDecoratedClassLike(node);
	}

	// The IIFE produced for `(@dec class {})` will result in an assigned name of the form
	// `var class_1 = class { };`, and thus the empty string cannot be ignored. However, The IIFE
	// produced for `(class { @dec x; })` will not result in an assigned name since it
	// transforms to `return class { };`, and thus the empty string *can* be ignored.
	static function canIgnoreEmptyStringLiteralInAssignedName(node:Node):Bool {
		if (node == null) {
			return false;
		}
		final innerExpression = Ast.SkipOuterExpressions(node, OEKAll);
		return Ast.IsClassExpression(innerExpression) && innerExpression.Name() == null
			&& !Ast.ClassOrConstructorParameterIsDecorated(false, innerExpression);
	}

	static function injectClassThisAssignmentIfMissing(ec:EmitContext, f:ts.printer.Factory.NodeFactory, node:Node, classThis:IdentifierNode):Node {
		if (classHasClassThisAssignment(ec, node)) {
			return node;
		}

		// Create: static { _classThis = this; }
		final expression = f.NewAssignmentExpression(classThis, f.NewThisExpression());
		final statement = f.NewExpressionStatement(expression);
		final body = f.NewBlock(f.NewNodeList([statement]), false);
		final staticBlock = f.NewClassStaticBlockDeclaration(null, body);
		ec.SetClassThis(staticBlock, classThis);

		if (node.Name() != null) {
			ec.SetSourceMapRange(statement, node.Name().Loc);
		}

		final newMembers:Array<Node> = [staticBlock];
		for (m in EsDecoratorTransformer.nilSlice(node.Members()))
			newMembers.push(m);
		final membersList = f.NewNodeList(newMembers);
		membersList.Loc = node.MemberList().Loc;

		var updatedNode:Node = null;
		if (Ast.IsClassDeclaration(node)) {
			final cd = node.AsClassDeclaration();
			updatedNode = f.UpdateClassDeclaration(cd, cd.Modifiers(), cd.Name(), null, cd.HeritageClauses, membersList);
		} else {
			final ce = node.AsClassExpression();
			updatedNode = f.UpdateClassExpression(ce, ce.Modifiers(), ce.Name(), null, ce.HeritageClauses, membersList);
		}
		ec.SetClassThis(updatedNode, classThis);
		return updatedNode;
	}

	// --- exponentiation.go ---

	static function newExponentiationTransformer(opts:TransformOptions):Transformer {
		final tx = new ExponentiationTransformer();
		return tx.Transformer.NewTransformer(tx.visit, opts.Context);
	}

	// --- forawait.go ---

	static inline final forAwaitHierarchyFactsAncestorFactsMask:Int = 3;

	static function newforawaitTransformer(opts:TransformOptions):Transformer {
		final tx = new ForawaitTransformer();
		tx.compilerOptions = opts.CompilerOptions;
		final result = tx.Transformer.NewTransformer(tx.visit, opts.Context);
		tx.superAccessState.initSuperAccessVisitor(tx.EmitContext(), tx.Factory());
		tx.fallbackNodeVisitor = tx.EmitContext().NewNodeVisitor(tx.visitFallback);
		tx.noAsyncModifierVisitor = tx.EmitContext().NewNodeVisitor(function(node:Node):Node {
			if (node.Kind == KindAsyncKeyword) {
				return null;
			}
			return node;
		});
		return result;
	}

	// unwrapInnermostStatementOfLabel follows LabeledStatement chains to find the innermost statement.
	static function unwrapInnermostStatementOfLabel(node:LabeledStatement):Node {
		while (true) {
			if (node.Statement.Kind != KindLabeledStatement) {
				return node.Statement;
			}
			node = node.Statement.AsLabeledStatement();
		}
	}

	// --- logicalassignment.go ---

	static function newLogicalAssignmentTransformer(opts:TransformOptions):Transformer {
		final tx = new LogicalAssignmentTransformer();
		return tx.Transformer.NewTransformer(tx.visit, opts.Context);
	}

	// --- namedevaluation.go ---

	/**
	 * Gets whether a node is a `static {}` block containing only a single call to the `__setFunctionName` helper where that
	 * call's second argument is the value stored in the `assignedName` property of the block's `EmitNode`.
	 * @internal
	 */
	static function isClassNamedEvaluationHelperBlock(emitContext:EmitContext, node:Node):Bool {
		if (!Ast.IsClassStaticBlockDeclaration(node) || node.AsClassStaticBlockDeclaration().Body.Statements().length != 1) {
			return false;
		}

		final statement = node.AsClassStaticBlockDeclaration().Body.Statements()[0];
		if (Ast.IsExpressionStatement(statement)) {
			final expression = statement.Expression();
			if (emitContext.IsCallToHelper(expression, "__setFunctionName")) {
				final arguments = expression.AsCallExpression().Arguments;
				return arguments.Nodes.length >= 2 && arguments.Nodes[1] == emitContext.AssignedName(node.AsNode());
			}
		}
		return false;
	}

	/**
	 * Gets whether a `ClassLikeDeclaration` has a `static {}` block containing only a single call to the
	 * `__setFunctionName` helper.
	 * @internal
	 */
	static function classHasExplicitlyAssignedName(emitContext:EmitContext, node:ClassLikeDeclaration):Bool {
		final assignedName = emitContext.AssignedName(node);
		if (assignedName != null) {
			final members = node.Members();
			if (members != null) for (member in members) { // PORT: range over possibly-nil slice
				if (isClassNamedEvaluationHelperBlock(emitContext, member)) {
					return true;
				}
			}
		}
		return false;
	}

	/**
	 * Gets whether a `ClassLikeDeclaration` has a declared name or contains a `static {}` block containing only a single
	 * call to the `__setFunctionName` helper.
	 * @internal
	 */
	static function classHasDeclaredOrExplicitlyAssignedName(emitContext:EmitContext, node:ClassLikeDeclaration):Bool {
		return node.Name() != null || classHasExplicitlyAssignedName(emitContext, node);
	}

	// Indicates whether an expression is an anonymous function definition.
	//
	// See https://tc39.es/ecma262/#sec-isanonymousfunctiondefinition
	static function isAnonymousFunctionDefinition(emitContext:EmitContext, node:Expression, cb:(AnonymousFunctionDefinition) -> Bool):Bool {
		node = Ast.SkipOuterExpressions(node, OEKAll);
		switch (node.Kind) {
			case KindClassExpression:
				if (classHasDeclaredOrExplicitlyAssignedName(emitContext, node)) {
					return false;
				}
			case KindFunctionExpression:
				if (node.AsFunctionExpression().Name() != null) {
					return false;
				}
			case KindArrowFunction:
			default:
				return false;
		}
		if (cb != null) {
			return cb(node);
		}
		return true;
	}

	static function isNamedEvaluation(emitContext:EmitContext, node:Node):Bool {
		return isNamedEvaluationAnd(emitContext, node, null);
	}

	static function isNamedEvaluationAnd(emitContext:EmitContext, node:Node, cb:(AnonymousFunctionDefinition) -> Bool):Bool {
		if (!Ast.IsNamedEvaluationSource(node)) {
			return false;
		}
		switch (node.Kind) {
			case KindShorthandPropertyAssignment:
				return isAnonymousFunctionDefinition(emitContext, node.AsShorthandPropertyAssignment().ObjectAssignmentInitializer, cb);
			case KindPropertyAssignment, KindVariableDeclaration, KindParameter, KindBindingElement, KindPropertyDeclaration:
				return isAnonymousFunctionDefinition(emitContext, node.Initializer(), cb);
			case KindBinaryExpression:
				return isAnonymousFunctionDefinition(emitContext, node.AsBinaryExpression().Right, cb);
			case KindExportAssignment:
				return isAnonymousFunctionDefinition(emitContext, node.Expression(), cb);
			default:
				Debug.Fail("Unhandled case in isNamedEvaluation");
				return false;
		}
	}

	// Gets a string literal to use as the assigned name of an anonymous class or function declaration.
	static function getAssignedNameOfIdentifier(emitContext:EmitContext, name:IdentifierNode, expression:Node /*WrappedExpression<AnonymousFunctionDefinition>*/):StringLiteralNode {
		final original = emitContext.MostOriginal(Ast.SkipOuterExpressions(expression, OEKAll));
		if ((Ast.IsClassDeclaration(original) || Ast.IsFunctionDeclaration(original))
			&& original.Name() == null && Ast.HasSyntacticModifier(original, ModifierFlagsDefault)) {
			return emitContext.Factory.NewStringLiteral("default", TokenFlagsNone);
		}
		return emitContext.Factory.NewStringLiteralFromNode(name);
	}

	static function getAssignedNameOfPropertyName(emitContext:EmitContext, name:PropertyName, assignedNameText:std.String):Pair<Expression, PropertyName> {
		final factory = emitContext.Factory;
		if (assignedNameText.length > 0) {
			final assignedName = factory.NewStringLiteral(assignedNameText, TokenFlagsNone);
			return new Pair(assignedName, name);
		}

		if (Ast.IsPropertyNameLiteral(name) || Ast.IsPrivateIdentifier(name)) {
			final assignedName = factory.NewStringLiteralFromNode(name);
			return new Pair(assignedName, name);
		}

		final expression = name.Expression();
		if (Ast.IsPropertyNameLiteral(expression) && !Ast.IsIdentifier(expression)) {
			final assignedName = factory.NewStringLiteralFromNode(expression);
			return new Pair(assignedName, name);
		}

		Debug.Assert(Ast.IsComputedPropertyName(name), "Expected computed property name");

		final assignedName = factory.NewGeneratedNameForNode(name);
		emitContext.AddVariableDeclaration(assignedName);

		final key = factory.NewPropKeyHelper(expression);
		final assignment = factory.NewAssignmentExpression(assignedName, key);
		final updatedName = factory.UpdateComputedPropertyName(name.AsComputedPropertyName(), assignment);
		return new Pair(assignedName, updatedName);
	}

	// Creates a class `static {}` block used to dynamically set the name of a class.
	//
	// The assignedName parameter is the expression used to resolve the assigned name at runtime. This expression should not produce
	// side effects.
	// The thisExpression parameter overrides the expression to use for the actual `this` reference. This can be used to provide an
	// expression that has already had its `EmitFlags` set or may have been tracked to prevent substitution.
	static function createClassNamedEvaluationHelperBlock(emitContext:EmitContext, assignedName:Expression, thisExpression:Expression):Node {
		// produces:
		//
		//  static { __setFunctionName(this, "C"); }
		//

		if (thisExpression == null) {
			thisExpression = emitContext.Factory.NewThisExpression();
		}

		final factory = emitContext.Factory;
		final expression = factory.NewSetFunctionNameHelper(thisExpression, assignedName, "" /*prefix*/);
		final statement = factory.NewExpressionStatement(expression);
		final body = factory.NewBlock(factory.NewNodeList([statement]), false /*multiLine*/);
		final block = factory.NewClassStaticBlockDeclaration(null /*modifiers*/, body);

		// We use `emitNode.assignedName` to indicate this is a NamedEvaluation helper block
		// and to stash the expression used to resolve the assigned name.
		emitContext.SetAssignedName(block, assignedName);
		return block.AsNode();
	}

	// Injects a class `static {}` block used to dynamically set the name of a class, if one does not already exist.
	static function injectClassNamedEvaluationHelperBlockIfMissing(emitContext:EmitContext, node:ClassLikeDeclaration, assignedName:Expression, thisExpression:Expression):ClassLikeDeclaration {
		// given:
		//
		//  let C = class {
		//  };
		//
		// produces:
		//
		//  let C = class {
		//      static { __setFunctionName(this, "C"); }
		//  };

		// NOTE: If the class has a `_classThis` assignment block, this helper will be injected after that block.

		if (classHasExplicitlyAssignedName(emitContext, node)) {
			return node;
		}

		final factory = emitContext.Factory;
		final namedEvaluationBlock = createClassNamedEvaluationHelperBlock(emitContext, assignedName, thisExpression);
		if (node.Name() != null) {
			emitContext.SetSourceMapRange(namedEvaluationBlock.Body().Statements()[0], node.Name().Loc);
		}

		final insertionIndex = Core.FindIndex(node.Members(), (n:Node) -> isClassThisAssignmentBlock(emitContext, n)) + 1;
		final nodeMembers = node.Members();
		final leading = nodeMembers != null ? nodeMembers.slice(0, insertionIndex) : []; // PORT: nil slice
		final trailing = nodeMembers != null ? nodeMembers.slice(insertionIndex) : [];

		var members:Array<ClassElement> = [];
		for (m in leading) members.push(m);
		members.push(namedEvaluationBlock);
		for (m in trailing) members.push(m);
		final membersList = factory.NewNodeList(members);
		membersList.Loc = node.MemberList().Loc;

		final oldNode = node;
		if (Ast.IsClassDeclaration(node)) {
			node = factory.UpdateClassDeclaration(
				node.AsClassDeclaration(),
				node.Modifiers(),
				node.Name(),
				node.TypeParameterList(),
				node.AsClassDeclaration().HeritageClauses,
				membersList
			);
		} else {
			node = factory.UpdateClassExpression(
				node.AsClassExpression(),
				node.Modifiers(),
				node.Name(),
				node.TypeParameterList(),
				node.AsClassExpression().HeritageClauses,
				membersList
			);
		}

		emitContext.SetAssignedName(node, assignedName);

		// Transfer ClassThis from old to new node, since UpdateClassExpression creates
		// a new node that won't have ClassThis set on it.
		final ct = emitContext.ClassThis(oldNode);
		if (ct != null) {
			emitContext.SetClassThis(node, ct);
		}

		return node;
	}

	static function finishTransformNamedEvaluation(emitContext:EmitContext, expression:Node /* WrappedExpression<AnonymousFunctionDefinition> */, assignedName:Expression, ignoreEmptyStringLiteral:Bool):Expression {
		if (ignoreEmptyStringLiteral && Ast.IsStringLiteral(assignedName) && assignedName.Text().length == 0) {
			return expression;
		}

		final factory = emitContext.Factory;
		final innerExpression = Ast.SkipOuterExpressions(expression, OEKAll);

		var updatedExpression:Expression = null;
		if (Ast.IsClassExpression(innerExpression)) {
			updatedExpression = injectClassNamedEvaluationHelperBlockIfMissing(emitContext, innerExpression, assignedName, null /*thisExpression*/);
		} else {
			updatedExpression = factory.NewSetFunctionNameHelper(innerExpression, assignedName, "" /*prefix*/);
		}

		return factory.RestoreOuterExpressions(expression, updatedExpression, OEKAll);
	}

	static function transformNamedEvaluationOfPropertyAssignment(context:EmitContext, node:PropertyAssignment /*NamedEvaluation & PropertyAssignment*/, ignoreEmptyStringLiteral:Bool, assignedNameText:std.String):Expression {
		// 13.2.5.5 RS: PropertyDefinitionEvaluation
		//   PropertyAssignment : PropertyName `:` AssignmentExpression
		//     ...
		//     5. If IsAnonymousFunctionDefinition(|AssignmentExpression|) is *true* and _isProtoSetter_ is *false*, then
		//        a. Let _popValue_ be ? NamedEvaluation of |AssignmentExpression| with argument _propKey_.
		//     ...

		final factory = context.Factory;
		final r = getAssignedNameOfPropertyName(context, node.AsNode().Name(), assignedNameText);
		final assignedName = r.a, name = r.b;
		final initializer = finishTransformNamedEvaluation(context, node.Initializer, assignedName, ignoreEmptyStringLiteral);
		return factory.UpdatePropertyAssignment(node, null /*modifiers*/, name, null /*postfixToken*/, null /*typeNode*/, initializer);
	}

	static function transformNamedEvaluationOfShorthandAssignmentProperty(emitContext:EmitContext, node:ShorthandPropertyAssignment /*NamedEvaluation & ShorthandPropertyAssignment*/, ignoreEmptyStringLiteral:Bool, assignedNameText:std.String):Expression {
		// 13.15.5.3 RS: PropertyDestructuringAssignmentEvaluation
		//   AssignmentProperty : IdentifierReference Initializer?
		//     ...
		//     4. If |Initializer?| is present and _v_ is *undefined*, then
		//        a. If IsAnonymousFunctionDefinition(|Initializer|) is *true*, then
		//           i. Set _v_ to ? NamedEvaluation of |Initializer| with argument _P_.
		//     ...

		final factory = emitContext.Factory;
		var assignedName:Expression = null;
		if (assignedNameText.length > 0) {
			assignedName = factory.NewStringLiteral(assignedNameText, TokenFlagsNone);
		} else {
			assignedName = getAssignedNameOfIdentifier(emitContext, node.AsNode().Name(), node.ObjectAssignmentInitializer);
		}
		final objectAssignmentInitializer = finishTransformNamedEvaluation(emitContext, node.ObjectAssignmentInitializer, assignedName, ignoreEmptyStringLiteral);
		return factory.UpdateShorthandPropertyAssignment(
			node,
			null, /*modifiers*/
			node.AsNode().Name(),
			null, /*postfixToken*/
			null, /*typeNode*/
			node.EqualsToken,
			objectAssignmentInitializer
		);
	}

	static function transformNamedEvaluationOfVariableDeclaration(emitContext:EmitContext, node:VariableDeclaration /*NamedEvaluation & VariableDeclaration*/, ignoreEmptyStringLiteral:Bool, assignedNameText:std.String):Expression {
		// 14.3.1.2 RS: Evaluation
		//   LexicalBinding : BindingIdentifier Initializer
		//     ...
		//     3. If IsAnonymousFunctionDefinition(|Initializer|) is *true*, then
		//        a. Let _value_ be ? NamedEvaluation of |Initializer| with argument _bindingId_.
		//     ...
		//
		// 14.3.2.1 RS: Evaluation
		//   VariableDeclaration : BindingIdentifier Initializer
		//     ...
		//     3. If IsAnonymousFunctionDefinition(|Initializer|) is *true*, then
		//        a. Let _value_ be ? NamedEvaluation of |Initializer| with argument _bindingId_.
		//     ...

		final factory = emitContext.Factory;
		var assignedName:Expression = null;
		if (assignedNameText.length > 0) {
			assignedName = factory.NewStringLiteral(assignedNameText, TokenFlagsNone);
		} else {
			assignedName = getAssignedNameOfIdentifier(emitContext, node.AsNode().Name(), node.Initializer);
		}
		final initializer = finishTransformNamedEvaluation(emitContext, node.Initializer, assignedName, ignoreEmptyStringLiteral);
		return factory.UpdateVariableDeclaration(
			node,
			node.AsNode().Name(),
			null, /*exclamationToken*/
			null, /*typeNode*/
			initializer
		);
	}

	static function transformNamedEvaluationOfParameterDeclaration(emitContext:EmitContext, node:ParameterDeclaration /*NamedEvaluation & ParameterDeclaration*/, ignoreEmptyStringLiteral:Bool, assignedNameText:std.String):Expression {
		// 8.6.3 RS: IteratorBindingInitialization
		//   SingleNameBinding : BindingIdentifier Initializer?
		//     ...
		//     5. If |Initializer| is present and _v_ is *undefined*, then
		//        a. If IsAnonymousFunctionDefinition(|Initializer|) is *true*, then
		//           i. Set _v_ to ? NamedEvaluation of |Initializer| with argument _bindingId_.
		//     ...
		//
		// 14.3.3.3 RS: KeyedBindingInitialization
		//   SingleNameBinding : BindingIdentifier Initializer?
		//     ...
		//     4. If |Initializer| is present and _v_ is *undefined*, then
		//        a. If IsAnonymousFunctionDefinition(|Initializer|) is *true*, then
		//           i. Set _v_ to ? NamedEvaluation of |Initializer| with argument _bindingId_.
		//     ...

		final factory = emitContext.Factory;
		var assignedName:Expression = null;
		if (assignedNameText.length > 0) {
			assignedName = factory.NewStringLiteral(assignedNameText, TokenFlagsNone);
		} else {
			assignedName = getAssignedNameOfIdentifier(emitContext, node.AsNode().Name(), node.Initializer);
		}
		final initializer = finishTransformNamedEvaluation(emitContext, node.Initializer, assignedName, ignoreEmptyStringLiteral);
		return factory.UpdateParameterDeclaration(
			node,
			null, /*modifiers*/
			node.DotDotDotToken,
			node.AsNode().Name(),
			null, /*questionToken*/
			null, /*typeNode*/
			initializer
		);
	}

	static function transformNamedEvaluationOfBindingElement(emitContext:EmitContext, node:BindingElement /*NamedEvaluation & BindingElement*/, ignoreEmptyStringLiteral:Bool, assignedNameText:std.String):Expression {
		// 8.6.3 RS: IteratorBindingInitialization
		//   SingleNameBinding : BindingIdentifier Initializer?
		//     ...
		//     5. If |Initializer| is present and _v_ is *undefined*, then
		//        a. If IsAnonymousFunctionDefinition(|Initializer|) is *true*, then
		//           i. Set _v_ to ? NamedEvaluation of |Initializer| with argument _bindingId_.
		//     ...
		//
		// 14.3.3.3 RS: KeyedBindingInitialization
		//   SingleNameBinding : BindingIdentifier Initializer?
		//     ...
		//     4. If |Initializer| is present and _v_ is *undefined*, then
		//        a. If IsAnonymousFunctionDefinition(|Initializer|) is *true*, then
		//           i. Set _v_ to ? NamedEvaluation of |Initializer| with argument _bindingId_.
		//     ...

		final factory = emitContext.Factory;
		var assignedName:Expression = null;
		if (assignedNameText.length > 0) {
			assignedName = factory.NewStringLiteral(assignedNameText, TokenFlagsNone);
		} else {
			assignedName = getAssignedNameOfIdentifier(emitContext, node.AsNode().Name(), node.Initializer);
		}
		final initializer = finishTransformNamedEvaluation(emitContext, node.Initializer, assignedName, ignoreEmptyStringLiteral);
		return factory.UpdateBindingElement(
			node,
			node.DotDotDotToken,
			node.PropertyName,
			node.AsNode().Name(),
			initializer
		);
	}

	static function transformNamedEvaluationOfPropertyDeclaration(emitContext:EmitContext, node:PropertyDeclaration /*NamedEvaluation & PropertyDeclaration*/, ignoreEmptyStringLiteral:Bool, assignedNameText:std.String):Expression {
		// 10.2.1.3 RS: EvaluateBody
		//   Initializer : `=` AssignmentExpression
		//     ...
		//     3. If IsAnonymousFunctionDefinition(|AssignmentExpression|) is *true*, then
		//        a. Let _value_ be ? NamedEvaluation of |Initializer| with argument _functionObject_.[[ClassFieldInitializerName]].
		//     ...

		final factory = emitContext.Factory;
		final r = getAssignedNameOfPropertyName(emitContext, node.AsNode().Name(), assignedNameText);
		final assignedName = r.a, name = r.b;
		final initializer = finishTransformNamedEvaluation(emitContext, node.Initializer, assignedName, ignoreEmptyStringLiteral);
		return factory.UpdatePropertyDeclaration(
			node,
			node.AsNode().Modifiers(),
			name,
			null, /*postfixToken*/
			null, /*typeNode*/
			initializer
		);
	}

	static function transformNamedEvaluationOfAssignmentExpression(emitContext:EmitContext, node:BinaryExpression /*NamedEvaluation & BinaryExpression*/, ignoreEmptyStringLiteral:Bool, assignedNameText:std.String):Expression {
		// 13.15.2 RS: Evaluation
		//   AssignmentExpression : LeftHandSideExpression `=` AssignmentExpression
		//     1. If |LeftHandSideExpression| is neither an |ObjectLiteral| nor an |ArrayLiteral|, then
		//        a. Let _lref_ be ? Evaluation of |LeftHandSideExpression|.
		//        b. If IsAnonymousFunctionDefinition(|AssignmentExpression|) and IsIdentifierRef of |LeftHandSideExpression| are both *true*, then
		//           i. Let _rval_ be ? NamedEvaluation of |AssignmentExpression| with argument _lref_.[[ReferencedName]].
		//     ...
		//
		//   AssignmentExpression : LeftHandSideExpression `&&=` AssignmentExpression
		//     ...
		//     5. If IsAnonymousFunctionDefinition(|AssignmentExpression|) is *true* and IsIdentifierRef of |LeftHandSideExpression| is *true*, then
		//        a. Let _rval_ be ? NamedEvaluation of |AssignmentExpression| with argument _lref_.[[ReferencedName]].
		//     ...
		//
		//   AssignmentExpression : LeftHandSideExpression `||=` AssignmentExpression
		//     ...
		//     5. If IsAnonymousFunctionDefinition(|AssignmentExpression|) is *true* and IsIdentifierRef of |LeftHandSideExpression| is *true*, then
		//        a. Let _rval_ be ? NamedEvaluation of |AssignmentExpression| with argument _lref_.[[ReferencedName]].
		//     ...
		//
		//   AssignmentExpression : LeftHandSideExpression `??=` AssignmentExpression
		//     ...
		//     4. If IsAnonymousFunctionDefinition(|AssignmentExpression|) is *true* and IsIdentifierRef of |LeftHandSideExpression| is *true*, then
		//        a. Let _rval_ be ? NamedEvaluation of |AssignmentExpression| with argument _lref_.[[ReferencedName]].
		//     ...

		final factory = emitContext.Factory;
		var assignedName:Expression = null;
		if (assignedNameText.length > 0) {
			assignedName = factory.NewStringLiteral(assignedNameText, TokenFlagsNone);
		} else {
			assignedName = getAssignedNameOfIdentifier(emitContext, node.Left, node.Right);
		}
		final right = finishTransformNamedEvaluation(emitContext, node.Right, assignedName, ignoreEmptyStringLiteral);
		return factory.UpdateBinaryExpression(
			node,
			null, /*modifiers*/
			node.Left,
			null, /*typeNode*/
			node.OperatorToken,
			right
		);
	}

	static function transformNamedEvaluationOfExportAssignment(emitContext:EmitContext, node:ExportAssignment /*NamedEvaluation & ExportAssignment*/, ignoreEmptyStringLiteral:Bool, assignedNameText:std.String):Expression {
		// 16.2.3.7 RS: Evaluation
		//   ExportDeclaration : `export` `default` AssignmentExpression `;`
		//     1. If IsAnonymousFunctionDefinition(|AssignmentExpression|) is *true*, then
		//        a. Let _value_ be ? NamedEvaluation of |AssignmentExpression| with argument `"default"`.
		//     ...

		// NOTE: Since emit for `export =` translates to `module.exports = ...`, the assigned name of the class or function
		// is `""`.

		final factory = emitContext.Factory;
		var assignedName:Expression = null;
		if (assignedNameText.length > 0) {
			assignedName = factory.NewStringLiteral(assignedNameText, TokenFlagsNone);
		} else if (node.IsExportEquals) {
			assignedName = factory.NewStringLiteral("", TokenFlagsNone);
		} else {
			assignedName = factory.NewStringLiteral("default", TokenFlagsNone);
		}
		final expression = finishTransformNamedEvaluation(emitContext, node.Expression, assignedName, ignoreEmptyStringLiteral);
		return factory.UpdateExportAssignment(
			node,
			null, /*modifiers*/
			node.IsExportEquals,
			null, /*typeNode*/
			expression
		);
	}

	// Performs a shallow transformation of a `NamedEvaluation` node, such that a valid name will be assigned.
	static function transformNamedEvaluation(context:EmitContext, node:Node /*NamedEvaluation*/, ignoreEmptyStringLiteral:Bool, assignedName:std.String):Expression {
		switch (node.Kind) {
			case KindPropertyAssignment:
				return transformNamedEvaluationOfPropertyAssignment(context, node.AsPropertyAssignment(), ignoreEmptyStringLiteral, assignedName);
			case KindShorthandPropertyAssignment:
				return transformNamedEvaluationOfShorthandAssignmentProperty(context, node.AsShorthandPropertyAssignment(), ignoreEmptyStringLiteral, assignedName);
			case KindVariableDeclaration:
				return transformNamedEvaluationOfVariableDeclaration(context, node.AsVariableDeclaration(), ignoreEmptyStringLiteral, assignedName);
			case KindParameter:
				return transformNamedEvaluationOfParameterDeclaration(context, node.AsParameterDeclaration(), ignoreEmptyStringLiteral, assignedName);
			case KindBindingElement:
				return transformNamedEvaluationOfBindingElement(context, node.AsBindingElement(), ignoreEmptyStringLiteral, assignedName);
			case KindPropertyDeclaration:
				return transformNamedEvaluationOfPropertyDeclaration(context, node.AsPropertyDeclaration(), ignoreEmptyStringLiteral, assignedName);
			case KindBinaryExpression:
				return transformNamedEvaluationOfAssignmentExpression(context, node.AsBinaryExpression(), ignoreEmptyStringLiteral, assignedName);
			case KindExportAssignment:
				return transformNamedEvaluationOfExportAssignment(context, node.AsExportAssignment(), ignoreEmptyStringLiteral, assignedName);
			default:
				Debug.Fail("Unhandled case in transformNamedEvaluation");
				return node;
		}
	}

	// --- nullishcoalescing.go ---

	static function newNullishCoalescingTransformer(opts:TransformOptions):Transformer {
		final tx = new NullishCoalescingTransformer();
		return tx.Transformer.NewTransformer(tx.visit, opts.Context);
	}

	// --- objectrestspread.go ---

	static function newObjectRestSpreadTransformer(opts:TransformOptions):Transformer {
		final tx = new ObjectRestSpreadTransformer();
		tx.compilerOptions = opts.CompilerOptions;
		return tx.Transformer.NewTransformer(tx.visit, opts.Context);
	}

	// --- optionalcatch.go ---

	static function newOptionalCatchTransformer(opts:TransformOptions):Transformer {
		final tx = new OptionalCatchTransformer();
		return tx.Transformer.NewTransformer(tx.visit, opts.Context);
	}

	// --- optionalchain.go ---

	static function isNonNullChain(node:Node):Bool {
		return Ast.IsNonNullExpression(node) && (node.Flags & NodeFlagsOptionalChain) != 0;
	}

	static function flattenChain(chain:Node):FlattenResult {
		Debug.Assert(!isNonNullChain(chain));
		final links:Array<Node> = [chain];
		while (!Ast.IsTaggedTemplateExpression(chain) && chain.QuestionDotToken() == null) {
			chain = Ast.SkipPartiallyEmittedExpressions(chain.Expression());
			Debug.Assert(!isNonNullChain(chain));
			links.unshift(chain); // Go: append([]*ast.Node{chain}, links...)
		}
		final r = new FlattenResult();
		r.expression = chain.Expression();
		r.chain = links;
		return r;
	}

	static function isCallChain(node:Node):Bool {
		return Ast.IsCallExpression(node) && (node.Flags & NodeFlagsOptionalChain) != 0;
	}

	static function newOptionalChainTransformer(opts:TransformOptions):Transformer {
		final tx = new OptionalChainTransformer();
		return tx.Transformer.NewTransformer(tx.visit, opts.Context);
	}

	// --- taggedtemplate.go ---

	static var newlineNormalizer(get, never):Replacer;
	static var newlineNormalizer_:Replacer = null;

	// PORT: lazy package var (static init order); Go `strings.Replacer` is the local Replacer class (Taggedtemplate.hx).
	static function get_newlineNormalizer():Replacer {
		if (newlineNormalizer_ == null) {
			newlineNormalizer_ = Replacer.NewReplacer("\r\n", "\n", "\r", "\n");
		}
		return newlineNormalizer_;
	}

	static function newTaggedTemplateLiftRestrictionTransformer(opts:TransformOptions):Transformer {
		final tx = new TaggedTemplateTransformer();
		return tx.Transformer.NewTransformer(tx.visit, opts.Context);
	}

	static function createTemplateCooked(f:ts.printer.Factory.NodeFactory, template:TemplateLiteralLikeNodeBase):Node {
		if ((template.TemplateFlags & TokenFlagsIsInvalid) != 0) {
			return f.NewVoidZeroExpression();
		}
		return f.NewStringLiteral(template.Text, TokenFlagsNone);
	}

	static function getRawLiteral(f:ts.printer.Factory.NodeFactory, node:Node):Node {
		var text = node.TemplateLiteralLikeData().RawText;
		if (text == "") {
			text = Scanner.GetSourceTextOfNodeFromSourceFile(Ast.GetSourceFileOfNode(node), node, false /*includeTrivia*/);
			// text contains the original source, it will also contain quotes ("`"), dollar signs and braces ("${" and "}"),
			// thus we need to remove those characters.
			// First template piece starts with "`", others with "}"
			// Last template piece ends with "`", others with "${"
			final isLast = node.Kind == KindNoSubstitutionTemplateLiteral || node.Kind == KindTemplateTail;
			var endLen = 2;
			if (isLast) {
				endLen = 1;
			}
			text = text.substring(1, text.length - endLen);
		}

		// Newline normalization:
		// ES6 Spec 11.8.6.1 - Static Semantics of TV's and TRV's
		// <CR><LF> and <CR> LineTerminatorSequences are normalized to <LF> for both TV and TRV.
		text = newlineNormalizer.Replace(text);

		final result = f.NewStringLiteral(text, TokenFlagsNone);
		result.Loc = node.Loc;
		return result;
	}

	static function hasInvalidEscape(template:Node):Bool {
		if (Ast.IsNoSubstitutionTemplateLiteral(template)) {
			return (template.TemplateLiteralLikeData().TemplateFlags & TokenFlagsContainsInvalidEscape) != 0;
		}
		final te = template.AsTemplateExpression();
		if ((te.Head.TemplateLiteralLikeData().TemplateFlags & TokenFlagsContainsInvalidEscape) != 0) {
			return true;
		}
		for (span in te.TemplateSpans.Nodes) {
			if ((span.AsTemplateSpan().Literal.TemplateLiteralLikeData().TemplateFlags & TokenFlagsContainsInvalidEscape) != 0) {
				return true;
			}
		}
		return false;
	}

	// --- usestrict.go ---

	public static function NewUseStrictTransformer(opts:TransformOptions):Transformer {
		final tx = new UseStrictTransformer();
		tx.compilerOptions = opts.CompilerOptions;
		tx.getEmitModuleFormatOfFile = opts.GetEmitModuleFormatOfFile;
		return tx.Transformer.NewTransformer(tx.visit, opts.Context);
	}

	// --- using.go ---

	static function newUsingDeclarationTransformer(opts:TransformOptions):Transformer {
		final tx = new UsingDeclarationTransformer();
		return tx.Transformer.NewTransformer(tx.visit, opts.Context);
	}

	static function isUsingVariableDeclarationList(node:ForInitializer):Bool {
		return Ast.IsVariableDeclarationList(node) && getUsingKindOfVariableDeclarationList(node.AsVariableDeclarationList()) != usingKindNone;
	}

	static function getUsingKindOfVariableDeclarationList(node:VariableDeclarationList):UsingKind {
		// PORT: switch → if/else (NodeFlagsAwaitUsing is not a constant pattern in Haxe).
		final blockScoped = node.Flags & NodeFlagsBlockScoped;
		if (blockScoped == NodeFlagsAwaitUsing) {
			return usingKindAsync;
		} else if (blockScoped == NodeFlagsUsing) {
			return usingKindSync;
		} else {
			return usingKindNone;
		}
	}

	static function getUsingKindOfVariableStatement(node:VariableStatement):UsingKind {
		return getUsingKindOfVariableDeclarationList(node.DeclarationList.AsVariableDeclarationList());
	}

	static function getUsingKind(statement:Node):UsingKind {
		if (Ast.IsVariableStatement(statement)) {
			return getUsingKindOfVariableStatement(statement.AsVariableStatement());
		}
		return usingKindNone;
	}

	static function getUsingKindOfStatements(statements:Array<Node>):UsingKind {
		var result = usingKindNone;
		if (statements != null) for (statement in statements) { // PORT: range over possibly-nil slice
			final usingKind = getUsingKind(statement);
			if (usingKind == usingKindAsync) {
				return usingKindAsync;
			}
			if ((usingKind : Int) > (result : Int)) {
				result = usingKind;
			}
		}
		return result;
	}

	// --- utilities.go ---

	static function convertClassDeclarationToClassExpression(emitContext:EmitContext, node:ClassDeclaration):Expression {
		final updated = emitContext.Factory.NewClassExpression(Transformers.ExtractModifiers(emitContext, node.Modifiers(), ~ModifierFlagsExportDefault),
			node.Name(), node.TypeParameters, node.HeritageClauses, node.Members);
		emitContext.SetOriginal(updated, node.AsNode());
		updated.Loc = node.Loc;
		return updated;
	}

	static function createNotNullCondition(emitContext:EmitContext, left:Node, right:Node, invert:Bool):Node {
		var token = KindExclamationEqualsEqualsToken;
		var op = KindAmpersandAmpersandToken;
		if (invert) {
			token = KindEqualsEqualsEqualsToken;
			op = KindBarBarToken;
		}

		return emitContext.Factory.NewBinaryExpression(null,
			emitContext.Factory.NewBinaryExpression(null, left, null, emitContext.Factory.NewToken(token),
				emitContext.Factory.NewKeywordExpression(KindNullKeyword)),
			null, emitContext.Factory.NewToken(op),
			emitContext.Factory.NewBinaryExpression(null, right, null, emitContext.Factory.NewToken(token), emitContext.Factory.NewVoidZeroExpression()));
	}

	// createAccessorPropertyBackingField creates a private backing field for an `accessor` PropertyDeclaration.
	static function createAccessorPropertyBackingField(f:ts.printer.Factory.NodeFactory, node:PropertyDeclaration, modifiers:ModifierList, initializer:Expression):Node {
		return f.UpdatePropertyDeclaration(node, modifiers, f.NewGeneratedPrivateNameForNodeEx(node.Name(), new AutoGenerateOptions(GeneratedIdentifierFlagsNone, "", "_accessor_storage")),
			null, /*postfixToken*/
			null, /*typeNode*/
			initializer);
	}
}
