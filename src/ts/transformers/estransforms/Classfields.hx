package ts.transformers.estransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/estransforms/classfields.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

import ts.printer.Emitcontext.AutoGenerateOptions;
import ts.printer.Generatedidentifierflags.GeneratedIdentifierFlags.*;

// classFacts tracks various facts about a class being transformed.
enum abstract ClassFacts(Int) from Int to Int {
	@:op(A | B) static function or(a:ClassFacts, b:ClassFacts):ClassFacts;
	@:op(A & B) static function and(a:ClassFacts, b:ClassFacts):ClassFacts;
	@:op(~A) static function not(a:ClassFacts):ClassFacts;

	var classFactsNone = 0;
	var classFactsClassWasDecorated = 1 << 0;
	var classFactsNeedsClassConstructorReference = 1 << 1;
	var classFactsNeedsClassSuperReference = 1 << 2;
	var classFactsNeedsSubstitutionForThisInClassStaticField = 1 << 3;
	var classFactsWillHoistInitializersToConstructor = 1 << 4;
}

// privateIdentifierKind represents the kind of private identifier declaration.
// privateIdentifierInfo stores information about a private identifier during transformation.
@:allow(ts.transformers.estransforms)
class PrivateIdentifierInfo {
	var kind:PrivateIdentifierKind = cast "";
	// brandCheckIdentifier can contain:
	//  - For instance field: The WeakMap that will be the storage for the field.
	//  - For instance methods or accessors: The WeakSet that will be used for brand checking.
	//  - For static members: The constructor that will be used for brand checking.
	var brandCheckIdentifier:IdentifierNode = null;
	// isStatic stores if the identifier is static or not.
	var isStatic:Bool = false;
	// isValid stores if the identifier declaration is valid or not. Reserved names (e.g. #constructor)
	// or duplicate identifiers are considered invalid.
	var isValid:Bool = false;
	// variableName contains the variable that will serve as the storage for a static field.
	var variableName:IdentifierNode = null;
	// methodName is the identifier for a variable that will contain the private method implementation.
	var methodName:IdentifierNode = null;
	// getterName is the identifier for a variable that will contain the private get accessor implementation, if any.
	var getterName:IdentifierNode = null;
	// setterName is the identifier for a variable that will contain the private set accessor implementation, if any.
	var setterName:IdentifierNode = null;

	public function new() {}
}

// privateEnvironmentData stores class-scoped environment data for private identifiers.
@:allow(ts.transformers.estransforms)
class PrivateEnvironmentData {
	// className is used for prefixing generated variable names.
	var className:IdentifierNode = null;
	// weakSetName is used for brand check on private methods.
	var weakSetName:IdentifierNode = null;

	public function new() {}
}

// privateEnvironment stores a map of private identifier names to their transform info.
// Like Strada, it uses two separate maps: one for non-generated identifiers (keyed by text)
// and one for generated identifiers (keyed by original AST node). This prevents collisions
// when different auto-accessors produce generated backing field names with the same text.
@:allow(ts.transformers.estransforms)
class PrivateEnvironment {
	var data:PrivateEnvironmentData = new PrivateEnvironmentData();
	var members:StringMap<PrivateIdentifierInfo> = null;
	var generatedIdentifiers:IdentityMap<Node, PrivateIdentifierInfo> = null;

	public function new() {}
}

// classLexicalEnvironment stores information about the lexical environment of a class.
@:allow(ts.transformers.estransforms)
class ClassLexicalEnvironment {
	var facts:ClassFacts = 0;
	// classConstructor is used for brand checks on static members, and `this` references in static initializers.
	var classConstructor:IdentifierNode = null;
	var classThis:IdentifierNode = null;
	// superClassReference is used for `super` references in static initializers.
	var superClassReference:IdentifierNode = null;

	public function new() {}
}

// classLexicalEnv is a linked list of class lexical environments.
@:allow(ts.transformers.estransforms)
class ClassLexicalEnv {
	var previous:ClassLexicalEnv = null;
	var data:ClassLexicalEnvironment = null;
	var privateEnv:PrivateEnvironment = null;

	public function new() {}
}

@:allow(ts.transformers.estransforms)
class ClassFieldsTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var compilerOptions:CompilerOptions = null;
	var resolver:ReferenceResolver = null;
	// Computed configuration flags
	var shouldTransformInitializersUsingSet:Bool = false;
	var shouldTransformInitializersUsingDefine:Bool = false;
	var shouldTransformInitializers:Bool = false;
	var shouldTransformPrivateElementsOrClassStaticBlocks:Bool = false;
	var shouldTransformAutoAccessors:Bool = false;
	var shouldTransformThisInStaticInitializers:Bool = false;
	var shouldTransformSuperInStaticInitializers:Bool = false;
	var shouldTransformPrivateStaticElementsInFile:Bool = false;
	var legacyDecorators:Bool = false;
	// pendingExpressions tracks what computed name expressions originating from elided names
	// must be inlined at the next execution site, in document order.
	var pendingExpressions:Array<Expression> = null;
	// pendingStatements tracks what computed name expression statements and static property
	// initializers must be emitted at the next execution site, in document order (for decorated classes).
	var pendingStatements:Array<Statement> = null;
	var lexicalEnvironment:ClassLexicalEnv = null;
	var currentClassContainer:ClassLikeDeclaration = null;
	var currentClassElement:ClassElement = null;
	// classAliases maps class declarations to alias identifiers for substituting class name
	// references in static initializers. Replaces Strada's onSubstituteNode/trySubstituteClassAlias.
	var classAliases:IdentityMap<Node, IdentifierNode> = null;
	var enclosingClassDeclarations:Set<Node> = new Set<Node>();
	var inIterationStatement:Bool = false;
	// insideComputedPropertyName replaces Strada's onEmitNode for ComputedPropertyName, which
	// switches to the outer lexical environment. Used by visitThisExpression() to apply
	// the outer environment's substitution without requiring currentClassElement to be static.
	var insideComputedPropertyName:Bool = false;
	var parentNode:Node = null;
	var currentNode:Node = null;
	// Visitors
	var modifierVisitor:NodeVisitor = null;
	var discardedValueVisitor:NodeVisitor = null;
	var heritageClauseVisitor:NodeVisitor = null;
	var assignmentTargetVisitor:NodeVisitor = null;
	var classElementVisitor:NodeVisitor = null;
	var accessorFieldResultVisitor:NodeVisitor = null;
	var arrayAssignmentElementVisitor:NodeVisitor = null;
	var objectAssignmentElementVisitor:NodeVisitor = null;
	var substitutionVisitor:NodeVisitor = null;
	// Pre-bound callbacks to avoid repeated closure allocation.
	var isAnonymousClassNeedingAssignedName:(AnonymousFunctionDefinition) -> Bool = null;

	public function new() {}

	// PORT: promoted methods of the embedded transformers.Transformer.
	inline function Visitor():NodeVisitor return Transformer.Visitor();
	inline function Factory():ts.printer.Factory.NodeFactory return Transformer.Factory();
	inline function EmitContext():EmitContext return Transformer.EmitContext();

	// PORT: Go method expressions `(*classFieldsTransformer).m`, created once (PORTING §7a).
	static final mxVisitEachChildOfNode:(tx:ClassFieldsTransformer, node:Node) -> Node = (tx, node) -> tx.visitEachChildOfNode(node);
	static final mxVisitFunctionExpressionOrDeclaration:(tx:ClassFieldsTransformer, node:Node) -> Node = (tx, node) -> tx.visitFunctionExpressionOrDeclaration(node);
	static final mxSetClassElementAndVisitEachChild:(tx:ClassFieldsTransformer, node:Node) -> Node = (tx, node) -> tx.setClassElementAndVisitEachChild(node);
	static final mxVisitConstructorDeclaration:(tx:ClassFieldsTransformer, node:Node) -> Node = (tx, node) -> tx.visitConstructorDeclaration(node);
	static final mxVisitMethodOrAccessorDeclaration:(tx:ClassFieldsTransformer, node:Node) -> Node = (tx, node) -> tx.visitMethodOrAccessorDeclaration(node);
	static final mxVisitPropertyDeclaration:(tx:ClassFieldsTransformer, node:Node) -> Node = (tx, node) -> tx.visitPropertyDeclaration(node);
	static final mxVisitClassStaticBlockDeclaration:(tx:ClassFieldsTransformer, node:Node) -> Node = (tx, node) -> tx.visitClassStaticBlockDeclaration(node);
	static final mxTransformClassStaticBlockDeclaration:(tx:ClassFieldsTransformer, node:Node) -> Node = (tx, node) -> tx.transformClassStaticBlockDeclaration(node);
	static final mxVisitClassDeclarationInNewClassLexicalEnvironment:(tx:ClassFieldsTransformer, node:Node, facts:ClassFacts) -> Node = (tx, node,
		facts) -> tx.visitClassDeclarationInNewClassLexicalEnvironment(node, facts);
	static final mxVisitClassExpressionInNewClassLexicalEnvironment:(tx:ClassFieldsTransformer, node:Node, facts:ClassFacts) -> Node = (tx, node,
		facts) -> tx.visitClassExpressionInNewClassLexicalEnvironment(node, facts);

	// requiresBlockScopedVar returns true when private field temp variables should be
	// declared as block-scoped (let) rather than function-scoped (var). This occurs when
	// a class expression is directly inside a loop body.
	// Replaces Strada's resolver.hasNodeCheckFlag(node, NodeCheckFlags.BlockScopedBindingInLoop).
	function requiresBlockScopedVar():Bool {
		return inIterationStatement && currentClassContainer != null && Ast.IsClassExpression(currentClassContainer);
	}

	// classExpressionNeedsBlockScopedTemp returns true when the class expression's temp variable
	// must be block-scoped. This is more specific than requiresBlockScopedVar: the class temp only
	// needs to be block-scoped when the class expression has a non-static property with a computed
	// property name inside a loop (matching the checker's BlockScopedBindingInLoop on the class node).
	function classExpressionNeedsBlockScopedTemp():Bool {
		if (!requiresBlockScopedVar()) {
			return false;
		}
		for (member in (currentClassContainer.Members() ?? [])) { // PORT: range over a possibly-nil slice
			if (Ast.IsPropertyDeclaration(member) && !Ast.HasStaticModifier(member) && member.Name() != null
				&& Ast.IsComputedPropertyName(member.Name())) {
				return true;
			}
		}
		return false;
	}

	function visitSourceFile(node:SourceFile):Node {
		if (node.IsDeclarationFile) {
			return node.AsNode();
		}
		lexicalEnvironment = null;
		shouldTransformPrivateStaticElementsInFile = (EmitContext().EmitFlags(node.AsNode()) & EFTransformPrivateStaticElements) != 0;
		classAliases = new IdentityMap<Node, IdentifierNode>();
		enclosingClassDeclarations.Clear();
		final visited = Visitor().VisitEachChild(node.AsNode());
		EmitContext().AddEmitHelper(visited, ...EmitContext().ReadEmitHelpers());
		classAliases = null;
		enclosingClassDeclarations.Clear();
		return visited;
	}

	function visitModifier(node:Node):Node {
		if (node.Kind == KindAccessorKeyword) {
			if (shouldTransformAutoAccessorsInCurrentClass()) {
				return null;
			}
			return node;
		}
		if (Ast.IsModifier(node)) {
			return node;
		}
		return null;
	}

	function pushNode(node:Node):Node {
		final grandparentNode = parentNode;
		parentNode = currentNode;
		currentNode = node;
		return grandparentNode;
	}

	function popNode(grandparentNode:Node):Void {
		currentNode = parentNode;
		parentNode = grandparentNode;
	}

	// visitForSubstitution visits nodes solely for class alias substitution in subtrees
	// that don't contain class field or lexical this/super transforms. It substitutes
	// identifiers that reference class declarations with their aliases, while skipping
	// the .Name() of PropertyAccessExpressions since Strada's onSubstituteNode only
	// fires for EmitHint.Expression, which excludes property access names.
	function visitForSubstitution(node:Node):Node {
		if (node.Kind == KindIdentifier) {
			return visitIdentifier(node.AsIdentifier());
		}
		if (node.Kind == KindPropertyAccessExpression && Ast.IsIdentifier(node.AsPropertyAccessExpression().Name())) {
			return visitPropertyAccessExpressionForSubstitution(node.AsPropertyAccessExpression());
		}
		return substitutionVisitor.VisitEachChild(node);
	}

	// visit is the main visitor.
	function visit(node:Node):Node {
		final grandparentNode = pushNode(node);
		// PORT: defer tx.popNode(grandparentNode); the body is visitWorker.
		final result = try visitWorker(node) catch (e:Dynamic) {
			popNode(grandparentNode);
			throw e;
		}
		popNode(grandparentNode);
		return result;
	}

	// PORT: body of visit after the deferred popNode (see visit).
	function visitWorker(node:Node):Node {
		if ((node.SubtreeFacts() & (SubtreeContainsClassFields | SubtreeContainsLexicalThisOrSuper)) == 0) {
			// PORT: len(tx.classAliases) > 0 on a possibly-nil map.
			if (currentClassContainer != null && classAliases != null && classAliases.keys().hasNext()) {
				// Continue visiting for alias substitution even in non-class-field subtrees.
				return visitForSubstitution(node);
			}
			return node;
		}

		switch (node.Kind) {
			case KindSourceFile:
				return visitSourceFile(node.AsSourceFile());
			case KindClassDeclaration:
				return visitClassDeclaration(node.AsClassDeclaration());
			case KindClassExpression:
				return visitClassExpression(node.AsClassExpression());
			case KindClassStaticBlockDeclaration, KindPropertyDeclaration:
				throw "Use `classElementVisitor` instead.";
			case KindPropertyAssignment:
				return visitPropertyAssignment(node.AsPropertyAssignment());
			case KindVariableStatement:
				return visitVariableStatement(node.AsVariableStatement());
			case KindVariableDeclaration:
				return visitVariableDeclaration(node.AsVariableDeclaration());
			case KindParameter:
				return visitParameterDeclaration(node.AsParameterDeclaration());
			case KindBindingElement:
				return visitBindingElement(node.AsBindingElement());
			case KindExportAssignment:
				return visitExportAssignment(node.AsExportAssignment());
			case KindPrivateIdentifier:
				return visitPrivateIdentifier(node);
			case KindPropertyAccessExpression:
				return visitPropertyAccessExpression(node.AsPropertyAccessExpression());
			case KindElementAccessExpression:
				return visitElementAccessExpression(node.AsElementAccessExpression());
			case KindPrefixUnaryExpression, KindPostfixUnaryExpression:
				return visitPreOrPostfixUnaryExpression(node, false /*discarded*/);
			case KindBinaryExpression:
				return visitBinaryExpression(node.AsBinaryExpression(), false /*discarded*/);
			case KindParenthesizedExpression:
				return visitParenthesizedExpression(node.AsParenthesizedExpression(), false /*discarded*/);
			case KindCallExpression:
				return visitCallExpression(node.AsCallExpression());
			case KindExpressionStatement:
				return visitExpressionStatement(node.AsExpressionStatement());
			case KindTaggedTemplateExpression:
				return visitTaggedTemplateExpression(node.AsTaggedTemplateExpression());
			case KindForStatement:
				return visitForStatement(node.AsForStatement());
			case KindForInStatement, KindForOfStatement, KindDoStatement, KindWhileStatement:
				return setInIterationStatementAnd(true, mxVisitEachChildOfNode, node);
			case KindThisKeyword:
				return visitThisExpression(node);
			case KindFunctionDeclaration, KindFunctionExpression:
				return setInIterationStatementAnd(false, mxVisitFunctionExpressionOrDeclaration, node);
			case KindConstructor, KindMethodDeclaration, KindGetAccessor, KindSetAccessor:
				return setInIterationStatementAnd(false, mxSetClassElementAndVisitEachChild, node);
			default:
				return Visitor().VisitEachChild(node);
		}
	}

	// visitDiscardedValue visits a node in an expression whose result is discarded.
	function visitDiscardedValue(node:Node):Node {
		switch (node.Kind) {
			case KindPrefixUnaryExpression, KindPostfixUnaryExpression:
				return visitPreOrPostfixUnaryExpression(node, true /*discarded*/);
			case KindBinaryExpression:
				return visitBinaryExpression(node.AsBinaryExpression(), true /*discarded*/);
			case KindParenthesizedExpression:
				return visitParenthesizedExpression(node.AsParenthesizedExpression(), true /*discarded*/);
			default:
				return visit(node);
		}
	}

	// visitHeritageClause visits a node in a HeritageClause.
	function visitHeritageClause(node:Node):Node {
		switch (node.Kind) {
			case KindHeritageClause:
				return heritageClauseVisitor.VisitEachChild(node);
			case KindExpressionWithTypeArguments:
				return visitExpressionWithTypeArgumentsInHeritageClause(node.AsExpressionWithTypeArguments());
			default:
				return visit(node);
		}
	}

	// visitAssignmentTarget visits the assignment target of a destructuring assignment.
	function visitAssignmentTarget(node:Node):Node {
		switch (node.Kind) {
			case KindObjectLiteralExpression, KindArrayLiteralExpression:
				return visitAssignmentPattern(node);
			default:
				return visit(node);
		}
	}

	function visitDestructuringAssignmentTarget(node:Node):Node {
		if (Ast.IsObjectLiteralExpression(node) || Ast.IsArrayLiteralExpression(node)) {
			return visitAssignmentPattern(node);
		}
		if (Ast.IsPropertyAccessExpression(node) && Ast.IsPrivateIdentifier(node.AsPropertyAccessExpression().Name())) {
			return wrapPrivateIdentifierForDestructuringTarget(node);
		}
		if (shouldTransformSuperInStaticInitializers && currentClassElement != null && Ast.IsSuperProperty(node)
			&& Estransforms.isStaticPropertyDeclarationOrClassStaticBlock(currentClassElement) && lexicalEnvironment != null
			&& lexicalEnvironment.data != null) {
			final data = lexicalEnvironment.data;
			if ((data.facts & classFactsClassWasDecorated) != 0) {
				return visitInvalidSuperProperty(node);
			}
			if (data.classConstructor != null && data.superClassReference != null) {
				var name:Expression = null;
				if (Ast.IsElementAccessExpression(node)) {
					name = Visitor().VisitNode(node.AsElementAccessExpression().ArgumentExpression);
				} else if (Ast.IsPropertyAccessExpression(node) && Ast.IsIdentifier(node.AsPropertyAccessExpression().Name())) {
					name = Factory().NewStringLiteralFromNode(node.AsPropertyAccessExpression().Name());
				}
				if (name != null) {
					final temp = Factory().NewTempVariable();
					final setExpr = Factory().NewReflectSetCall(data.superClassReference, name, temp, data.classConstructor);
					return Factory().NewAssignmentTargetWrapper(temp, setExpr);
				}
			}
		}
		return Visitor().VisitEachChild(node);
	}

	// visitClassElement visits a member of a class.
	function visitClassElement(node:Node):Node {
		switch (node.Kind) {
			case KindConstructor:
				return setCurrentClassElementAnd(node, mxVisitConstructorDeclaration, node);
			case KindGetAccessor, KindSetAccessor, KindMethodDeclaration:
				return setCurrentClassElementAnd(node, mxVisitMethodOrAccessorDeclaration, node);
			case KindPropertyDeclaration:
				return setCurrentClassElementAnd(node, mxVisitPropertyDeclaration, node);
			case KindClassStaticBlockDeclaration:
				return setCurrentClassElementAnd(node, mxVisitClassStaticBlockDeclaration, node);
			case KindComputedPropertyName:
				return visitComputedPropertyName(node.AsComputedPropertyName());
			case KindSemicolonClassElement:
				return node;
			default:
				if (Ast.IsModifierLike(node)) {
					return visitModifier(node);
				}
				return visit(node);
		}
	}

	// visitPropertyName visits a property name of a class member.
	function visitPropertyName(name:PropertyName):PropertyName {
		if (Ast.IsComputedPropertyName(name)) {
			return visitComputedPropertyName(name.AsComputedPropertyName());
		}
		return Visitor().VisitNode(name);
	}

	// visitAccessorFieldResult visits the results of an auto-accessor field transformation in a second pass.
	function visitAccessorFieldResult(node:Node):Node {
		switch (node.Kind) {
			case KindPropertyDeclaration:
				return transformFieldInitializer(node.AsPropertyDeclaration());
			case KindGetAccessor, KindSetAccessor:
				return visitClassElement(node);
			default:
				Debug.FailBadSyntaxKind({KindString: () -> node.KindString()}, "Expected node to either be a PropertyDeclaration, GetAccessorDeclaration, or SetAccessorDeclaration");
				return null;
		}
	}

	// visitIdentifier replaces Strada's onSubstituteNode/trySubstituteClassAlias. Instead of
	// substituting at emit time using NodeCheckFlags.ConstructorReference, we resolve the
	// identifier to its declaration and check if that declaration has a registered alias.
	function visitIdentifier(node:Identifier):Node {
		final declaration = resolver.GetReferencedValueDeclaration(EmitContext().MostOriginal(node.AsNode()));
		if (declaration != null) {
			final alias = classAliases == null ? null : classAliases.get(declaration);
			final ok = classAliases != null && classAliases.exists(declaration);
			if (ok && enclosingClassDeclarations.Has(declaration)) {
				final clone = alias.Clone(Factory());
				EmitContext().SetSourceMapRange(clone, node.Loc);
				EmitContext().SetCommentRange(clone, node.Loc);
				return clone;
			}
		}
		return node.AsNode();
	}

	// visitPrivateIdentifier handles an undeclared private name. Replace it with an empty
	// identifier to indicate a problem with the code.
	// Note: private identifiers in statement position (e.g., `#;`) are intercepted earlier
	// by visitExpressionStatement, which preserves them so the runtime throws a SyntaxError.
	function visitPrivateIdentifier(node:Node):Node {
		if (!shouldTransformPrivateElementsOrClassStaticBlocks) {
			return node;
		}
		if (parentNode != null && Ast.IsStatement(parentNode)) {
			return node;
		}
		final result = Factory().NewIdentifier("");
		EmitContext().SetOriginal(result, node);
		return result;
	}

	// transformPrivateIdentifierInInExpression visits `#id in expr`.
	function transformPrivateIdentifierInInExpression(node:BinaryExpression):Node {
		final info = accessPrivateIdentifier(node.Left);
		if (info != null) {
			final receiver = Visitor().VisitNode(node.Right);
			final result = Factory().NewClassPrivateFieldInHelper(info.brandCheckIdentifier, receiver);
			EmitContext().SetOriginal(result, node.AsNode());
			return result;
		}
		// Private name has not been declared. Subsequent transformers will handle this error
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitPropertyAssignment(node:PropertyAssignment):Node {
		// 13.2.5.5 RS: PropertyDefinitionEvaluation
		//   PropertyAssignment : PropertyName `:` AssignmentExpression
		//     ...
		//     5. If IsAnonymousFunctionDefinition(|AssignmentExpression|) is *true* and _isProtoSetter_ is *false*, then
		//        a. Let _popValue_ be ? NamedEvaluation of |AssignmentExpression| with argument _propKey_.
		//     ...

		if (Estransforms.isNamedEvaluationAnd(EmitContext(), node.AsNode(), isAnonymousClassNeedingAssignedName)) {
			node = Estransforms.transformNamedEvaluation(EmitContext(), node.AsNode(), false /*ignoreEmptyStringLiteral*/, "" /*assignedName*/)
				.AsPropertyAssignment();
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitVariableStatement(node:VariableStatement):Node {
		final savedPendingStatements = pendingStatements;
		pendingStatements = null;

		final visitedNode = Visitor().VisitEachChild(node.AsNode());

		if (pendingStatements != null && pendingStatements.length > 0) {
			final result:Array<Node> = [];
			result.push(visitedNode);
			for (s in pendingStatements) {
				result.push(s);
			}
			pendingStatements = savedPendingStatements;
			return Factory().NewSyntaxList(result);
		}

		pendingStatements = savedPendingStatements;
		return visitedNode;
	}

	function visitVariableDeclaration(node:VariableDeclaration):Node {
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

		if (Estransforms.isNamedEvaluationAnd(EmitContext(), node.AsNode(), isAnonymousClassNeedingAssignedName)) {
			node = Estransforms.transformNamedEvaluation(EmitContext(), node.AsNode(), false, "").AsVariableDeclaration();
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitParameterDeclaration(node:ParameterDeclaration):Node {
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

		if (Estransforms.isNamedEvaluationAnd(EmitContext(), node.AsNode(), isAnonymousClassNeedingAssignedName)) {
			node = Estransforms.transformNamedEvaluation(EmitContext(), node.AsNode(), false, "").AsParameterDeclaration();
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitBindingElement(node:BindingElement):Node {
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

		if (Estransforms.isNamedEvaluationAnd(EmitContext(), node.AsNode(), isAnonymousClassNeedingAssignedName)) {
			node = Estransforms.transformNamedEvaluation(EmitContext(), node.AsNode(), false, "").AsBindingElement();
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitExportAssignment(node:ExportAssignment):Node {
		// 16.2.3.7 RS: Evaluation
		//   ExportDeclaration : `export` `default` AssignmentExpression `;`
		//     1. If IsAnonymousFunctionDefinition(|AssignmentExpression|) is *true*, then
		//        a. Let _value_ be ? NamedEvaluation of |AssignmentExpression| with argument `"default"`.
		//     ...

		// NOTE: Since emit for `export =` translates to `module.exports = ...`, the assigned name of the class
		// is `""`.

		if (Estransforms.isNamedEvaluationAnd(EmitContext(), node.AsNode(), isAnonymousClassNeedingAssignedName)) {
			var assignedName = "";
			if (!node.IsExportEquals) {
				assignedName = "default";
			}
			node = Estransforms.transformNamedEvaluation(EmitContext(), node.AsNode(), true /*ignoreEmptyStringLiteral*/, assignedName)
				.AsExportAssignment();
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function injectPendingExpressions(expression:Expression):Expression {
		if (pendingExpressions != null && pendingExpressions.length > 0) {
			if (Ast.IsParenthesizedExpression(expression)) {
				pendingExpressions.push(expression.Expression());
				expression = Factory().UpdateParenthesizedExpression(expression.AsParenthesizedExpression(), Factory().InlineExpressions(pendingExpressions));
			} else {
				final exprs = pendingExpressions.concat([expression]);
				expression = Factory().InlineExpressions(exprs);
			}
			pendingExpressions = null;
		}
		return expression;
	}

	function visitComputedPropertyName(node:ComputedPropertyName):Node {
		// Computed property names are evaluated in the enclosing scope, not the current class.
		// Replaces Strada's onEmitNode for ComputedPropertyName which switches to
		// lexicalEnvironment?.previous. We do this explicitly during transformation.
		final savedLexicalEnvironment = lexicalEnvironment;
		final savedInsideComputedPropertyName = insideComputedPropertyName;
		insideComputedPropertyName = true;
		if (lexicalEnvironment != null && lexicalEnvironment.previous != null) {
			lexicalEnvironment = lexicalEnvironment.previous;
		}
		final expression = Visitor().VisitNode(node.Expression);
		lexicalEnvironment = savedLexicalEnvironment;
		insideComputedPropertyName = savedInsideComputedPropertyName;
		return Factory().UpdateComputedPropertyName(node, injectPendingExpressions(expression));
	}

	function visitConstructorDeclaration(node:Node):Node {
		if (currentClassContainer != null) {
			return transformConstructor(node.AsConstructorDeclaration(), currentClassContainer);
		}
		return Visitor().VisitEachChild(node);
	}

	function shouldTransformClassElementToWeakMap(node:Node):Bool {
		if (shouldTransformPrivateElementsOrClassStaticBlocks) {
			return true;
		}
		return shouldAlwaysTransformPrivateStaticElements(node);
	}

	function shouldAlwaysTransformPrivateStaticElements(node:Node):Bool {
		return Ast.HasStaticModifier(node) && (EmitContext().EmitFlags(node) & EFTransformPrivateStaticElements) != 0;
	}

	// nodeHasTransformPrivateStaticElementsFlag checks the emit flag on a class node (not a member).
	// Unlike shouldAlwaysTransformPrivateStaticElements, this does not check HasStaticModifier,
	// since class nodes themselves don't have a static modifier.
	function nodeHasTransformPrivateStaticElementsFlag(node:Node):Bool {
		return (EmitContext().EmitFlags(node) & EFTransformPrivateStaticElements) != 0;
	}

	function visitMethodOrAccessorDeclaration(node:Node):Node {
		Debug.Assert(!Ast.HasDecorators(node));

		if (!Ast.IsPrivateIdentifierClassElementDeclaration(node) || !shouldTransformClassElementToWeakMap(node)) {
			return classElementVisitor.VisitEachChild(node);
		}

		// leave invalid code untransformed
		final info = accessPrivateIdentifier(node.Name());
		Debug.Assert(info != null, "Undeclared private name for property declaration.");
		if (!info.isValid) {
			return node;
		}

		final functionName = getHoistedFunctionName(node);
		if (functionName != null) {
			final modifiers = extractNonStaticNonAccessorModifiers(node);
			EmitContext().StartVariableEnvironment();
			final saved = inIterationStatement;
			inIterationStatement = false;
			final body = EmitContext().VisitFunctionBody(node.Body(), Visitor());
			final params = Visitor().VisitNodes(node.ParameterList());
			inIterationStatement = saved;

			final funcExpr = Factory().NewFunctionExpression(modifiers, node.BodyData().AsteriskToken, functionName, null, params, null, null, body);
			final assignment = Factory().NewAssignmentExpression(functionName, funcExpr);
			addPendingExpressions(assignment);
		}

		// remove method declaration from class
		return null;
	}

	function extractNonStaticNonAccessorModifiers(node:Node):ModifierList {
		return Transformers.ExtractModifiers(EmitContext(), node.Modifiers(), ~(ModifierFlagsStatic | ModifierFlagsAccessor));
	}

	function setCurrentClassElementAnd(classElement:ClassElement, visitor:(tx:ClassFieldsTransformer, node:Node) -> Node, node:Node):Node {
		if (classElement != currentClassElement) {
			final saved = currentClassElement;
			currentClassElement = classElement;
			final result = visitor(this, node);
			currentClassElement = saved;
			return result;
		}
		return visitor(this, node);
	}

	// visitEachChildOfNode just calls Visitor.VisitEachChild, but is necessary to avoid repeated closure allocations when passing as a callback.
	function visitEachChildOfNode(node:Node):Node {
		return Visitor().VisitEachChild(node);
	}

	function setInIterationStatementAnd(inIteration:Bool, visitor:(tx:ClassFieldsTransformer, node:Node) -> Node, node:Node):Node {
		if (inIterationStatement != inIteration) {
			final saved = inIterationStatement;
			inIterationStatement = inIteration;
			final result = visitor(this, node);
			inIterationStatement = saved;
			return result;
		}
		return visitor(this, node);
	}

	function clearClassElementAndVisitEachChild(node:Node):Node {
		return setCurrentClassElementAnd(null, mxVisitEachChildOfNode, node);
	}

	// visitFunctionExpressionOrDeclaration handles lexical environment scoping for function
	// expressions and declarations, mirroring Strada's onEmitNode behavior.
	//
	// In Strada, onEmitNode checks whether a FunctionExpression has been registered in
	// lexicalEnvironmentMap (via its original node). If found, the lexical environment is
	// restored; otherwise it is cleared (since regular functions create a new `this` scope).
	//
	// Since Corsa performs substitution eagerly (no emit-time hooks), we replicate this by
	// preserving currentClassElement for function expressions whose original node is a class
	// member of the current class. This allows visitThisExpression to correctly substitute
	// `this` -> `_classThis` inside synthesized functions (e.g., ES decorator descriptor
	// methods for static private auto-accessors).
	function visitFunctionExpressionOrDeclaration(node:Node):Node {
		if (currentClassElement != null) {
			final original = EmitContext().MostOriginal(node);
			if (original != node && currentClassContainer != null) {
				for (member in (currentClassContainer.Members() ?? [])) { // PORT: range over a possibly-nil slice
					if (EmitContext().MostOriginal(member) == original && Ast.IsStatic(member)) {
						// The function expression originates from a static class member (e.g., a
						// descriptor method synthesized by the ES decorator transformer for a
						// static private auto-accessor). Preserve the current class element so
						// that visitThisExpression can substitute `this` with `_classThis`.
						// Non-static members must NOT preserve the class element because `this`
						// inside their descriptor functions should remain dynamic.
						return visitEachChildOfNode(node);
					}
				}
			}
		}
		return setCurrentClassElementAnd(null, mxVisitEachChildOfNode, node);
	}

	function setClassElementAndVisitEachChild(node:Node):Node {
		return setCurrentClassElementAnd(node, mxVisitEachChildOfNode, node);
	}

	function getHoistedFunctionName(node:Node):IdentifierNode {
		Debug.Assert(node.Name() != null && Ast.IsPrivateIdentifier(node.Name()));
		final info = accessPrivateIdentifier(node.Name());
		Debug.Assert(info != null, "Undeclared private name for property declaration.");
		if (info.kind == PrivateIdentifierKindMethod) {
			return info.methodName;
		}
		if (info.kind == PrivateIdentifierKindAccessor) {
			if (Ast.IsGetAccessorDeclaration(node)) {
				return info.getterName;
			}
			if (Ast.IsSetAccessorDeclaration(node)) {
				return info.setterName;
			}
		}
		return null;
	}

	function tryGetClassThis():Expression {
		final classThis = tryGetClassThisNoContainer();
		if (classThis != null) {
			return classThis;
		}
		if (currentClassContainer != null) {
			return currentClassContainer.Name();
		}
		return null;
	}

	function tryGetClassThisNoContainer():Expression {
		final lex = getClassLexicalEnvironment();
		if (lex.classThis != null) {
			return lex.classThis;
		}
		if (lex.classConstructor != null) {
			return lex.classConstructor;
		}
		return null;
	}

	// transformAutoAccessor transforms an auto-accessor property:
	//
	//	accessor x = 1;
	//
	// into:
	//
	//	#x = 1;
	//	get x() { return this.#x; }
	//	set x(value) { this.#x = value; }
	function transformAutoAccessor(node:PropertyDeclaration):Node {
		final commentRange = EmitContext().CommentRange(node.AsNode());
		final sourceMapRange = EmitContext().SourceMapRange(node.AsNode());

		// Since we're creating two declarations where there was previously one, cache
		// the expression for any computed property names.
		final name = node.Name();
		var getterName = name;
		var setterName = name;
		if (Ast.IsComputedPropertyName(name) && !Transformers.IsSimpleInlineableExpression(name.Expression())) {
			final cacheAssignment = Estransforms.findComputedPropertyNameCacheAssignment(EmitContext(), name);
			if (cacheAssignment != null) {
				getterName = Factory().UpdateComputedPropertyName(name.AsComputedPropertyName(), Visitor().VisitNode(name.Expression()));
				setterName = Factory().UpdateComputedPropertyName(name.AsComputedPropertyName(), cacheAssignment.Left);
			} else {
				final temp = Factory().NewTempVariable();
				EmitContext().SetSourceMapRange(temp, name.Expression().Loc);
				EmitContext().AddVariableDeclaration(temp);
				final expression = Visitor().VisitNode(name.Expression());
				final assignment = Factory().NewAssignmentExpression(temp, expression);
				EmitContext().SetSourceMapRange(assignment, name.Expression().Loc);
				getterName = Factory().UpdateComputedPropertyName(name.AsComputedPropertyName(), assignment);
				setterName = Factory().UpdateComputedPropertyName(name.AsComputedPropertyName(), temp);
			}
		}

		final modifiers = modifierVisitor.VisitModifiers(node.Modifiers());
		final backingField = Estransforms.createAccessorPropertyBackingField(Factory(), node, modifiers, node.Initializer);
		EmitContext().SetOriginal(backingField, node.AsNode());
		EmitContext().AddEmitFlags(backingField, EFNoComments);
		EmitContext().SetSourceMapRange(backingField, sourceMapRange);

		var receiver:Expression = null;
		if (Ast.IsStatic(node.AsNode())) {
			receiver = tryGetClassThis();
			if (receiver == null) {
				receiver = Factory().NewThisExpression();
			}
		} else {
			receiver = Factory().NewThisExpression();
		}

		final getter = createAccessorPropertyGetRedirector(node, modifiers, getterName, receiver);
		EmitContext().SetOriginal(getter, node.AsNode());
		EmitContext().SetCommentRange(getter, commentRange);
		EmitContext().SetSourceMapRange(getter, sourceMapRange);

		// create a fresh copy of the modifiers so that we don't duplicate comments
		var setterModifiers:ModifierList = null;
		if (modifiers != null) {
			setterModifiers = Factory().NewModifierList(Ast.CreateModifiersFromModifierFlags(modifiers.ModifierFlags, k -> Factory().NewModifier(k)));
		}
		final setter = createAccessorPropertySetRedirector(node, setterModifiers, setterName, receiver);
		EmitContext().SetOriginal(setter, node.AsNode());
		EmitContext().AddEmitFlags(setter, EFNoComments);
		EmitContext().SetSourceMapRange(setter, sourceMapRange);

		// Visit the results in a second pass
		final visited = accessorFieldResultVisitor.VisitSlice([backingField, getter, setter]).a;
		return Factory().NewSyntaxList(visited);
	}

	function transformPrivateFieldInitializer(node:PropertyDeclaration):Node {
		if (shouldTransformClassElementToWeakMap(node.AsNode())) {
			// If we are transforming private elements into WeakMap/WeakSet, we should elide the node.
			final info = accessPrivateIdentifier(node.Name());
			Debug.Assert(info != null, "Undeclared private name for property declaration.");

			// Leave invalid code untransformed
			if (!info.isValid) {
				return node.AsNode();
			}

			// If we encounter a valid private static field and we're not transforming
			// class static blocks, convert to a static block initializer.
			if (info.isStatic && !shouldTransformPrivateElementsOrClassStaticBlocks) {
				// TODO: fix
				final statement = transformPropertyOrClassStaticBlock(node.AsNode(), Factory().NewThisExpression());
				if (statement != null) {
					return Factory().NewClassStaticBlockDeclaration(null /*modifiers*/, Factory().NewBlock(Factory().NewNodeList([statement]), true /*multiLine*/));
				}
			}

			return null;
		}

		if (shouldTransformInitializersUsingSet && !Ast.HasStaticModifier(node.AsNode()) && lexicalEnvironment != null
			&& lexicalEnvironment.data != null && (lexicalEnvironment.data.facts & classFactsWillHoistInitializersToConstructor) != 0) {
			return Factory().UpdatePropertyDeclaration(node, Visitor().VisitModifiers(node.Modifiers()), node.Name(), null /*postfixToken*/, null /*typeNode*/,
				null /*initializer*/);
		}

		if (Estransforms.isNamedEvaluationAnd(EmitContext(), node.AsNode(), isAnonymousClassNeedingAssignedName)) {
			node = Estransforms.transformNamedEvaluation(EmitContext(), node.AsNode(), false, "").AsPropertyDeclaration();
		}

		return Factory().UpdatePropertyDeclaration(node, modifierVisitor.VisitModifiers(node.Modifiers()), visitPropertyName(node.Name()), null /*postfixToken*/,
			null /*typeNode*/, Visitor().VisitNode(node.Initializer));
	}

	function transformPublicFieldInitializer(node:PropertyDeclaration):Node {
		if (shouldTransformInitializers && !Ast.IsAutoAccessorPropertyDeclaration(node.AsNode())) {
			// Elide the property declaration; the initializer will be moved to the constructor.
			// For computed property names, we still need to emit the expression.
			final expr = getPropertyNameExpressionIfNeeded(node.Name(), node.Initializer != null || compilerOptions.GetUseDefineForClassFields());
			if (expr != null) {
				Estransforms.flattenCommaList(expr)(function(e:Expression):Bool {
					addPendingExpressions(e);
					return true;
				});
			}

			// When target >= ES2022 (i.e., !shouldTransformPrivateElementsOrClassStaticBlocks) and we
			// still need to transform initializers (useDefineForClassFields: false), static property
			// initializers must be converted into `static { this.x = ...; }` blocks so that `this`
			// refers to the class constructor inside the static block.
			if (Ast.IsStatic(node.AsNode()) && !shouldTransformPrivateElementsOrClassStaticBlocks) {
				final initializerStatement = transformPropertyOrClassStaticBlock(node.AsNode(), Factory().NewThisExpression());
				if (initializerStatement != null) {
					final staticBlock = Factory().NewClassStaticBlockDeclaration(null /*modifiers*/,
						Factory().NewBlock(Factory().NewNodeList([initializerStatement]), false));

					EmitContext().SetOriginal(staticBlock, node.AsNode());
					EmitContext().SetCommentRange(staticBlock, node.Loc);

					EmitContext().AddEmitFlags(initializerStatement, EFNoComments);
					return staticBlock;
				}
			}

			return null;
		}

		return Factory().UpdatePropertyDeclaration(node, modifierVisitor.VisitModifiers(node.Modifiers()), visitPropertyName(node.Name()), null /*postfixToken*/,
			null /*typeNode*/, Visitor().VisitNode(node.Initializer));
	}

	function transformFieldInitializer(node:PropertyDeclaration):Node {
		Debug.Assert(!Ast.HasDecorators(node.AsNode()), "Decorators should already have been transformed and elided.");
		if (Ast.IsPrivateIdentifierClassElementDeclaration(node.AsNode())) {
			return transformPrivateFieldInitializer(node);
		}
		return transformPublicFieldInitializer(node);
	}

	function shouldTransformAutoAccessorsInCurrentClass():Bool {
		if (shouldTransformAutoAccessors) {
			return true;
		}
		// When targeting ESNext with useDefineForClassFields: false, auto-accessors are only
		// transformed if the current class will hoist initializers to the constructor.
		return lexicalEnvironment != null && lexicalEnvironment.data != null
			&& (lexicalEnvironment.data.facts & classFactsWillHoistInitializersToConstructor) != 0;
	}

	function visitPropertyDeclaration(node:Node):Node {
		// If this is an auto-accessor, we defer to `transformAutoAccessor`. That function
		// will in turn call `transformFieldInitializer` as needed.
		final propDecl = node.AsPropertyDeclaration();
		if (Ast.IsAutoAccessorPropertyDeclaration(node)
			&& (shouldTransformAutoAccessorsInCurrentClass() || (Ast.HasStaticModifier(node) && shouldAlwaysTransformPrivateStaticElements(node)))) {
			return transformAutoAccessor(propDecl);
		}
		return transformFieldInitializer(propDecl);
	}

	function createPrivateIdentifierAccess(info:PrivateIdentifierInfo, receiver:Expression):Expression {
		receiver = Visitor().VisitNode(receiver);
		return createPrivateIdentifierAccessHelper(info, receiver);
	}

	function createPrivateIdentifierAccessHelper(info:PrivateIdentifierInfo, receiver:Expression):Expression {
		EmitContext().SetCommentRange(receiver, Core.NewTextRange(-1, receiver.End()));

		switch (info.kind) {
			case PrivateIdentifierKindAccessor:
				return Factory().NewClassPrivateFieldGetHelper(receiver, info.brandCheckIdentifier, info.kind, info.getterName);
			case PrivateIdentifierKindMethod:
				return Factory().NewClassPrivateFieldGetHelper(receiver, info.brandCheckIdentifier, info.kind, info.methodName);
			case PrivateIdentifierKindField:
				var f:IdentifierNode = null;
				if (info.isStatic) {
					f = info.variableName;
				}
				return Factory().NewClassPrivateFieldGetHelper(receiver, info.brandCheckIdentifier, info.kind, f);
			case PrivateIdentifierKindUntransformed:
				Debug.Fail("Access helpers should not be created for untransformed private elements");
				return null;
			default:
		}
		Debug.AssertNever(info, "Unknown private element type");
		return null;
	}

	function visitPropertyAccessExpression(node:PropertyAccessExpression):Node {
		if (Ast.IsPrivateIdentifier(node.Name())) {
			final info = accessPrivateIdentifier(node.Name());
			if (info != null) {
				final result = createPrivateIdentifierAccess(info, node.Expression);
				EmitContext().SetOriginal(result, node.AsNode());
				result.Loc = node.Loc;
				return result;
			}
		}
		if (shouldTransformSuperInStaticInitializers && currentClassElement != null && Ast.IsSuperProperty(node.AsNode())
			&& Ast.IsIdentifier(node.Name()) && Estransforms.isStaticPropertyDeclarationOrClassStaticBlock(currentClassElement)
			&& lexicalEnvironment != null && lexicalEnvironment.data != null) {
			final data = lexicalEnvironment.data;
			if ((data.facts & classFactsClassWasDecorated) != 0) {
				return visitInvalidSuperProperty(node.AsNode());
			}
			if (data.classConstructor != null && data.superClassReference != null) {
				// converts `super.x` into `Reflect.get(_baseTemp, "x", _classTemp)`
				final superProperty = Factory().NewReflectGetCall(data.superClassReference, Factory().NewStringLiteralFromNode(node.Name()),
					data.classConstructor);
				EmitContext().SetOriginal(superProperty, node.Expression);
				superProperty.Loc = node.Expression.Loc;
				return superProperty;
			}
		}
		// Visit only the expression, not the name (when it's a regular identifier), to prevent
		// substitution of property names. Strada's onSubstituteNode only fires for
		// EmitHint.Expression, which excludes the .name of PropertyAccessExpression.
		// Private identifier names are still visited through VisitEachChild so they can be
		// transformed by visitPrivateIdentifier.
		if (Ast.IsIdentifier(node.Name())) {
			return visitPropertyAccessExpressionForSubstitution(node);
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	// visitPropertyAccessExpressionForSubstitution visits only the expression of a PropertyAccessExpression,
	// leaving the name unchanged. This prevents the name from being treated as a standalone identifier
	// reference and incorrectly substituted with a class alias.
	function visitPropertyAccessExpressionForSubstitution(node:PropertyAccessExpression):Node {
		final expression = Visitor().VisitNode(node.Expression);
		if (expression != node.Expression) {
			return Factory().UpdatePropertyAccessExpression(node, expression, node.QuestionDotToken, node.Name(), node.Flags);
		}
		return node.AsNode();
	}

	function visitElementAccessExpression(node:ElementAccessExpression):Node {
		if (shouldTransformSuperInStaticInitializers && currentClassElement != null && Ast.IsSuperProperty(node.AsNode())
			&& Estransforms.isStaticPropertyDeclarationOrClassStaticBlock(currentClassElement) && lexicalEnvironment != null
			&& lexicalEnvironment.data != null) {
			final data = lexicalEnvironment.data;
			if ((data.facts & classFactsClassWasDecorated) != 0) {
				return visitInvalidSuperProperty(node.AsNode());
			}
			if (data.classConstructor != null && data.superClassReference != null) {
				// converts `super[x]` into `Reflect.get(_baseTemp, x, _classTemp)`
				final superProperty = Factory().NewReflectGetCall(data.superClassReference, Visitor().VisitNode(node.ArgumentExpression), data.classConstructor);
				EmitContext().SetOriginal(superProperty, node.Expression);
				superProperty.Loc = node.Expression.Loc;
				return superProperty;
			}
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitPreOrPostfixUnaryExpression(node:Node, discarded:Bool):Node {
		var operator_:Kind = KindUnknown;
		var operand:Node = null;
		if (Ast.IsPrefixUnaryExpression(node)) {
			operator_ = node.AsPrefixUnaryExpression().Operator;
			operand = node.AsPrefixUnaryExpression().Operand;
		} else {
			operator_ = node.AsPostfixUnaryExpression().Operator;
			operand = node.AsPostfixUnaryExpression().Operand;
		}

		if (operator_ == KindPlusPlusToken || operator_ == KindMinusMinusToken) {
			final operandSkipped = Ast.SkipParentheses(operand);

			// Private identifier property access
			if (Ast.IsPropertyAccessExpression(operandSkipped) && Ast.IsPrivateIdentifier(operandSkipped.Name())) {
				final info = accessPrivateIdentifier(operandSkipped.Name());
				if (info != null) {
					final receiver = Visitor().VisitNode(operandSkipped.Expression());
					final copiable = createCopiableReceiverExpr(receiver);
					final readExpression = copiable.a;
					final initializeExpression = copiable.b;

					var expression = createPrivateIdentifierAccessHelper(info, readExpression);
					var temp:IdentifierNode = null;
					if (!Ast.IsPrefixUnaryExpression(node) && !discarded) {
						temp = Factory().NewTempVariable();
						EmitContext().AddVariableDeclaration(temp);
					}
					expression = Estransforms.expandPreOrPostfixIncrementOrDecrementExpression(Factory(), EmitContext(), node, expression, temp);
					var assignReceiver = readExpression;
					if (initializeExpression != null) {
						assignReceiver = initializeExpression;
					}
					expression = createPrivateIdentifierAssignment(info, assignReceiver, expression, KindEqualsToken);
					EmitContext().SetOriginal(expression, node);
					expression.Loc = node.Loc;
					if (temp != null) {
						expression = Factory().NewCommaExpression(expression, temp);
						expression.Loc = node.Loc;
					}
					return expression;
				}
			} else if (shouldTransformSuperInStaticInitializers && currentClassElement != null && Ast.IsSuperProperty(operandSkipped)
				&& Estransforms.isStaticPropertyDeclarationOrClassStaticBlock(currentClassElement) && lexicalEnvironment != null
				&& lexicalEnvironment.data != null) {
				// converts `++super.a` into `(Reflect.set(_baseTemp, "a", (_a = Reflect.get(_baseTemp, "a", _classTemp), _b = ++_a), _classTemp), _b)`
				// converts `++super[f()]` into `(Reflect.set(_baseTemp, _a = f(), (_b = Reflect.get(_baseTemp, _a, _classTemp), _c = ++_b), _classTemp), _c)`
				// converts `--super.a` into `(Reflect.set(_baseTemp, "a", (_a = Reflect.get(_baseTemp, "a", _classTemp), _b = --_a), _classTemp), _b)`
				// converts `--super[f()]` into `(Reflect.set(_baseTemp, _a = f(), (_b = Reflect.get(_baseTemp, _a, _classTemp), _c = --_b), _classTemp), _c)`
				// converts `super.a++` into `(Reflect.set(_baseTemp, "a", (_a = Reflect.get(_baseTemp, "a", _classTemp), _b = _a++), _classTemp), _b)`
				// converts `super[f()]++` into `(Reflect.set(_baseTemp, _a = f(), (_b = Reflect.get(_baseTemp, _a, _classTemp), _c = _b++), _classTemp), _c)`
				// converts `super.a--` into `(Reflect.set(_baseTemp, "a", (_a = Reflect.get(_baseTemp, "a", _classTemp), _b = _a--), _classTemp), _b)`
				// converts `super[f()]--` into `(Reflect.set(_baseTemp, _a = f(), (_b = Reflect.get(_baseTemp, _a, _classTemp), _c = _b--), _classTemp), _c)`
				final data = lexicalEnvironment.data;
				if ((data.facts & classFactsClassWasDecorated) != 0) {
					final visitedExpr = visitInvalidSuperProperty(operandSkipped);
					if (Ast.IsPrefixUnaryExpression(node)) {
						return Factory().UpdatePrefixUnaryExpression(node.AsPrefixUnaryExpression(), node.AsPrefixUnaryExpression().Operator, visitedExpr);
					}
					return Factory().UpdatePostfixUnaryExpression(node.AsPostfixUnaryExpression(), visitedExpr, node.AsPostfixUnaryExpression().Operator);
				}
				if (data.classConstructor != null && data.superClassReference != null) {
					var setterName:Expression = null;
					var getterName:Expression = null;
					if (Ast.IsPropertyAccessExpression(operandSkipped)) {
						if (Ast.IsIdentifier(operandSkipped.Name())) {
							getterName = Factory().NewStringLiteralFromNode(operandSkipped.Name());
							setterName = getterName;
						}
					} else if (Ast.IsElementAccessExpression(operandSkipped)) {
						if (Transformers.IsSimpleInlineableExpression(operandSkipped.AsElementAccessExpression().ArgumentExpression)) {
							getterName = operandSkipped.AsElementAccessExpression().ArgumentExpression;
							setterName = getterName;
						} else {
							getterName = Factory().NewTempVariable();
							EmitContext().AddVariableDeclaration(getterName);
							setterName = Factory().NewAssignmentExpression(getterName,
								Visitor().VisitNode(operandSkipped.AsElementAccessExpression().ArgumentExpression));
						}
					}
					if (setterName != null && getterName != null) {
						var expression = Factory().NewReflectGetCall(data.superClassReference, getterName, data.classConstructor);
						expression.Loc = operandSkipped.Loc;

						var temp:IdentifierNode = null;
						if (!discarded) {
							temp = Factory().NewTempVariable();
							EmitContext().AddVariableDeclaration(temp);
						}
						expression = Estransforms.expandPreOrPostfixIncrementOrDecrementExpression(Factory(), EmitContext(), node, expression, temp);
						expression = Factory().NewReflectSetCall(data.superClassReference, setterName, expression, data.classConstructor);
						EmitContext().SetOriginal(expression, node);
						expression.Loc = node.Loc;
						if (temp != null) {
							expression = Factory().NewCommaExpression(expression, temp);
							expression.Loc = node.Loc;
						}
						return expression;
					}
				}
			}
		}
		return Visitor().VisitEachChild(node);
	}

	function visitForStatement(node:ForStatement):Node {
		final initializer = discardedValueVisitor.VisitNode(node.Initializer);
		final condition = Visitor().VisitNode(node.Condition);
		final incrementor = discardedValueVisitor.VisitNode(node.Incrementor);
		final saved = inIterationStatement;
		inIterationStatement = true;
		final body = EmitContext().VisitIterationBody(node.Statement, Visitor());
		inIterationStatement = saved;
		return Factory().UpdateForStatement(node, initializer, condition, incrementor, body);
	}

	function visitExpressionStatement(node:ExpressionStatement):Node {
		// Preserve private identifiers that appear directly as the expression of an
		// ExpressionStatement (e.g., `#;`). This is error-recovery output from the parser
		// for invalid syntax. Keeping it ensures the runtime throws a SyntaxError rather
		// than silently succeeding with an empty statement.
		if (Ast.IsPrivateIdentifier(node.Expression) && shouldTransformPrivateElementsOrClassStaticBlocks) {
			return node.AsNode();
		}
		return Factory().UpdateExpressionStatement(node, discardedValueVisitor.VisitNode(node.Expression));
	}

	function createCopiableReceiverExpr(receiver:Expression):Pair<Expression, Expression> {
		var clone = receiver;
		if (!Ast.NodeIsSynthesized(receiver)) {
			clone = receiver.Clone(Factory());
		}
		if (Transformers.IsSimpleInlineableExpression(receiver)) {
			return new Pair<Expression, Expression>(clone, null);
		}
		final readExpression = Factory().NewTempVariable();
		EmitContext().AddVariableDeclaration(readExpression);
		final initializeExpression = Factory().NewAssignmentExpression(readExpression, clone);
		return new Pair<Expression, Expression>(readExpression, initializeExpression);
	}

	function visitCallExpression(node:CallExpression):Node {
		if (Ast.IsPropertyAccessExpression(node.Expression) && Ast.IsPrivateIdentifier(node.Expression.AsPropertyAccessExpression().Name())
			&& accessPrivateIdentifier(node.Expression.AsPropertyAccessExpression().Name()) != null) {
			// obj.#x()

			// Transform call expressions of private names to properly bind the `this` parameter.
			final binding = createCallBinding(node.Expression);
			final thisArg = binding.a;
			final target = binding.b;
			final visitedTarget = Visitor().VisitNode(target);
			final visitedThisArg = Visitor().VisitNode(thisArg);
			final visitedArgs = Visitor().VisitNodes(node.Arguments);
			final allArgs:Array<Node> = [];
			allArgs.push(visitedThisArg);
			for (a in (visitedArgs.Nodes ?? [])) { // PORT: range over a possibly-nil slice
				allArgs.push(a);
			}
			if ((node.Flags & NodeFlagsOptionalChain) != 0) {
				return Factory().UpdateCallExpression(node,
					Factory().NewPropertyAccessExpression(visitedTarget, node.QuestionDotToken, Factory().NewIdentifier("call"), NodeFlagsOptionalChain),
					null /*questionDotToken*/, null /*typeArguments*/, Factory().NewNodeList(allArgs), node.Flags);
			}
			return Factory().UpdateCallExpression(node, Factory().NewPropertyAccessExpression(visitedTarget, null, Factory().NewIdentifier("call"), NodeFlagsNone),
				null /*questionDotToken*/, null /*typeArguments*/, Factory().NewNodeList(allArgs), node.Flags);
		}

		if (shouldTransformSuperInStaticInitializers && currentClassElement != null && Ast.IsSuperProperty(node.Expression)
			&& Estransforms.isStaticPropertyDeclarationOrClassStaticBlock(currentClassElement) && lexicalEnvironment != null
			&& lexicalEnvironment.data != null && lexicalEnvironment.data.classConstructor != null) {
			// super.x()
			// super[x]()

			// converts `super.f(...)` into `Reflect.get(_baseTemp, "f", _classTemp).call(_classTemp, ...)`
			final invocation = Factory().NewFunctionCallCall(Visitor().VisitNode(node.Expression), lexicalEnvironment.data.classConstructor,
				Visitor().VisitNodes(node.Arguments).Nodes);
			EmitContext().SetOriginal(invocation, node.AsNode());
			invocation.Loc = node.Loc;
			return invocation;
		}

		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitTaggedTemplateExpression(node:TaggedTemplateExpression):Node {
		if (Ast.IsPropertyAccessExpression(node.Tag) && Ast.IsPrivateIdentifier(node.Tag.AsPropertyAccessExpression().Name())
			&& accessPrivateIdentifier(node.Tag.AsPropertyAccessExpression().Name()) != null) {
			// Bind the `this` correctly for tagged template literals when the tag is a private identifier property access.
			final binding = createCallBinding(node.Tag);
			final thisArg = binding.a;
			final target = binding.b;
			final bindExpr = Factory().NewCallExpression(Factory().NewPropertyAccessExpression(Visitor().VisitNode(target), null,
				Factory().NewIdentifier("bind"), NodeFlagsNone),
				null /*questionDotToken*/, null /*typeArguments*/, Factory().NewNodeList([Visitor().VisitNode(thisArg)]), NodeFlagsNone);
			return Factory().UpdateTaggedTemplateExpression(node, bindExpr, null /*questionDotToken*/, null /*typeArguments*/, Visitor().VisitNode(node.Template),
				node.Flags);
		}

		if (shouldTransformSuperInStaticInitializers && currentClassElement != null && Ast.IsSuperProperty(node.Tag)
			&& Estransforms.isStaticPropertyDeclarationOrClassStaticBlock(currentClassElement) && lexicalEnvironment != null
			&& lexicalEnvironment.data != null && lexicalEnvironment.data.classConstructor != null) {
			// converts `` super.f`x` `` into `` Reflect.get(_baseTemp, "f", _classTemp).bind(_classTemp)`x` ``
			final invocation = Factory().NewFunctionBindCall(Visitor().VisitNode(node.Tag), lexicalEnvironment.data.classConstructor, null);
			EmitContext().SetOriginal(invocation, node.AsNode());
			invocation.Loc = node.Loc;
			return Factory().UpdateTaggedTemplateExpression(node, invocation, null /*questionDotToken*/, null /*typeArguments*/,
				Visitor().VisitNode(node.Template), node.Flags);
		}

		return Visitor().VisitEachChild(node.AsNode());
	}

	function transformClassStaticBlockDeclaration(node:Node):Expression {
		if (shouldTransformPrivateElementsOrClassStaticBlocks) {
			if (Estransforms.isClassThisAssignmentBlock(EmitContext(), node)) {
				final result = Visitor().VisitNode(node.AsClassStaticBlockDeclaration().Body.AsBlock().Statements.Nodes[0].Expression());
				// If the generated `_classThis` assignment is a noop (i.e., `_classThis = _classThis`), we can
				// eliminate the expression
				if (Ast.IsAssignmentExpression(result, true /*excludeCompoundAssignment*/)) {
					final binary = result.AsBinaryExpression();
					if (binary.Left == binary.Right) {
						return null;
					}
				}
				return result;
			}

			if (Estransforms.isClassNamedEvaluationHelperBlock(EmitContext(), node)) {
				return Visitor().VisitNode(node.AsClassStaticBlockDeclaration().Body.AsBlock().Statements.Nodes[0].Expression());
			}

			EmitContext().StartVariableEnvironment();
			var statements = setCurrentClassElementAndVisitStatements(node, node.AsClassStaticBlockDeclaration().Body.AsBlock().Statements.Nodes);
			statements = EmitContext().EndAndMergeVariableEnvironment(statements);

			final iife = Factory().NewImmediatelyInvokedArrowFunction(statements);
			final arrowFunction = Ast.SkipParentheses(iife.Expression());
			EmitContext().SetOriginal(arrowFunction, node);
			EmitContext().AddEmitFlags(arrowFunction, EFNoLexicalArguments);
			// Preserve the statement list source range so the printer can emit detached comments
			// (e.g., `// do` inside an otherwise empty static block)
			arrowFunction.AsArrowFunction().Body.AsBlock().Statements.Loc = node.AsClassStaticBlockDeclaration().Body.AsBlock().Statements.Loc;
			EmitContext().SetOriginal(iife, node);
			EmitContext().AssignSourceMapRange(iife, node);
			EmitContext().AddEmitFlags(arrowFunction, EFNoLexicalThis);
			return iife;
		}
		return null;
	}

	function setCurrentClassElementAndVisitStatements(classElement:Node, statements:Array<Statement>):Array<Statement> {
		final savedCurrentClassElement = currentClassElement;
		currentClassElement = classElement;
		final result = Visitor().VisitSlice(statements).a;
		currentClassElement = savedCurrentClassElement;
		return result;
	}

	function isAnonymousClassNeedingAssignedNameWorker(node:AnonymousFunctionDefinition):Bool {
		if (Ast.IsClassExpression(node) && node.Name() == null) {
			final staticPropertiesOrClassStaticBlocks = getStaticPropertiesAndClassStaticBlock(node);
			if (Core.Some(staticPropertiesOrClassStaticBlocks, function(n:Node):Bool {
				return Estransforms.isClassNamedEvaluationHelperBlock(EmitContext(), n);
			})) {
				return false;
			}
			final hasTransformableStatics = (shouldTransformPrivateElementsOrClassStaticBlocks || nodeHasTransformPrivateStaticElementsFlag(node))
				&& Core.Some(staticPropertiesOrClassStaticBlocks, function(n:Node):Bool {
					return Ast.IsClassStaticBlockDeclaration(n) || Ast.IsPrivateIdentifierClassElementDeclaration(n)
						|| (shouldTransformInitializers && Ast.IsInitializedProperty(n));
				});
			return hasTransformableStatics;
		}
		return false;
	}

	function visitBinaryExpression(node:BinaryExpression, discarded:Bool):Node {
		if (Ast.IsDestructuringAssignment(node.AsNode())) {
			// ({ x: obj.#x } = ...)
			// ({ x: super.x } = ...)
			// ({ x: super[x] } = ...)
			final savedPendingExpressions = pendingExpressions;
			pendingExpressions = null;
			final updated = Factory().UpdateBinaryExpression(node, null, assignmentTargetVisitor.VisitNode(node.Left), null, node.OperatorToken,
				Visitor().VisitNode(node.Right));
			var result:Expression = null;
			if (pendingExpressions != null && pendingExpressions.length > 0) {
				final exprs = pendingExpressions.concat([updated]);
				result = Factory().InlineExpressions(exprs);
			} else {
				result = updated;
			}
			pendingExpressions = savedPendingExpressions;
			return result;
		}

		if (Ast.IsAssignmentExpression(node.AsNode(), false /*excludeCompound*/)) {
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

			if (Estransforms.isNamedEvaluationAnd(EmitContext(), node.AsNode(), isAnonymousClassNeedingAssignedName)) {
				node = Estransforms.transformNamedEvaluation(EmitContext(), node.AsNode(), false, "").AsBinaryExpression();
				Debug.Assert(node.AsNode() != null && Ast.IsAssignmentExpression(node.AsNode(), false));
			}

			final left = Ast.SkipOuterExpressions(node.Left, OEKPartiallyEmittedExpressions | OEKParentheses);
			if (Ast.IsPropertyAccessExpression(left) && Ast.IsPrivateIdentifier(left.Name())) {
				// obj.#x = ...
				final info = accessPrivateIdentifier(left.Name());
				if (info != null) {
					final result = createPrivateIdentifierAssignment(info, left.Expression(), node.Right, node.OperatorToken.Kind);
					EmitContext().SetOriginal(result, node.AsNode());
					result.Loc = node.Loc;
					return result;
				}
			} else if (shouldTransformSuperInStaticInitializers && currentClassElement != null && Ast.IsSuperProperty(node.Left)
				&& Estransforms.isStaticPropertyDeclarationOrClassStaticBlock(currentClassElement) && lexicalEnvironment != null
				&& lexicalEnvironment.data != null) {
				// super.x = ...
				// super[x] = ...
				// super.x += ...
				// super.x -= ...
				final data = lexicalEnvironment.data;
				if ((data.facts & classFactsClassWasDecorated) != 0) {
					return Factory().UpdateBinaryExpression(node, null, visitInvalidSuperProperty(node.Left), null, node.OperatorToken,
						Visitor().VisitNode(node.Right));
				}
				if (data.classConstructor != null && data.superClassReference != null) {
					var setterName:Expression = null;
					if (Ast.IsElementAccessExpression(node.Left)) {
						setterName = Visitor().VisitNode(node.Left.AsElementAccessExpression().ArgumentExpression);
					} else if (Ast.IsPropertyAccessExpression(node.Left) && Ast.IsIdentifier(node.Left.AsPropertyAccessExpression().Name())) {
						setterName = Factory().NewStringLiteralFromNode(node.Left.AsPropertyAccessExpression().Name());
					}
					if (setterName != null) {
						// converts `super.x = 1` into `(Reflect.set(_baseTemp, "x", _a = 1, _classTemp), _a)`
						// converts `super[f()] = 1` into `(Reflect.set(_baseTemp, f(), _a = 1, _classTemp), _a)`
						// converts `super.x += 1` into `(Reflect.set(_baseTemp, "x", _a = Reflect.get(_baseTemp, "x", _classtemp) + 1, _classTemp), _a)`
						// converts `super[f()] += 1` into `(Reflect.set(_baseTemp, _a = f(), _b = Reflect.get(_baseTemp, _a, _classtemp) + 1, _classTemp), _b)`

						var expression = Visitor().VisitNode(node.Right);
						if (Ast.IsCompoundAssignment(node.OperatorToken.Kind)) {
							var getterName = setterName;
							if (!Transformers.IsSimpleInlineableExpression(setterName)) {
								getterName = Factory().NewTempVariable();
								EmitContext().AddVariableDeclaration(getterName);
								setterName = Factory().NewAssignmentExpression(getterName, setterName);
							}
							final superPropertyGet = Factory().NewReflectGetCall(data.superClassReference, getterName, data.classConstructor);
							EmitContext().SetOriginal(superPropertyGet, node.Left);
							superPropertyGet.Loc = node.Left.Loc;
							expression = Factory().NewBinaryExpression(null, superPropertyGet, null,
								Factory().NewToken(Transformers.GetNonAssignmentOperatorForCompoundAssignment(node.OperatorToken.Kind)), expression);
							expression.Loc = node.Loc;
						}

						var temp:IdentifierNode = null;
						if (!discarded) {
							temp = Factory().NewTempVariable();
							EmitContext().AddVariableDeclaration(temp);
						}
						if (temp != null) {
							expression = Factory().NewAssignmentExpression(temp, expression);
							expression.Loc = node.Loc;
						}

						expression = Factory().NewReflectSetCall(data.superClassReference, setterName, expression, data.classConstructor);
						EmitContext().SetOriginal(expression, node.AsNode());
						expression.Loc = node.Loc;

						if (temp != null) {
							expression = Factory().NewCommaExpression(expression, temp);
							expression.Loc = node.Loc;
						}
						return expression;
					}
				}
			}
		}

		if (node.OperatorToken.Kind == KindInKeyword && Ast.IsPrivateIdentifier(node.Left)) {
			// #x in obj
			return transformPrivateIdentifierInInExpression(node);
		}

		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitParenthesizedExpression(node:ParenthesizedExpression, discarded:Bool):Node {
		// 8.4.5 RS: NamedEvaluation
		//   ParenthesizedExpression : `(` Expression `)`
		//     ...
		//     2. Return ? NamedEvaluation of |Expression| with argument _name_.
		if (discarded) {
			final expression = discardedValueVisitor.VisitNode(node.Expression);
			return Factory().UpdateParenthesizedExpression(node, expression);
		}
		final expression = Visitor().VisitNode(node.Expression);
		return Factory().UpdateParenthesizedExpression(node, expression);
	}

	function createPrivateIdentifierAssignment(info:PrivateIdentifierInfo, receiver:Expression, right:Expression, operator_:Kind):Expression {
		receiver = Visitor().VisitNode(receiver);
		right = Visitor().VisitNode(right);

		if (Ast.IsCompoundAssignment(operator_)) {
			final copiable = createCopiableReceiverExpr(receiver);
			final readExpression = copiable.a;
			final initializeExpression = copiable.b;
			if (initializeExpression != null) {
				receiver = initializeExpression;
			} else {
				receiver = readExpression;
			}
			right = Factory().NewBinaryExpression(null, createPrivateIdentifierAccessHelper(info, readExpression), null,
				Factory().NewToken(Transformers.GetNonAssignmentOperatorForCompoundAssignment(operator_)), right);
		}

		EmitContext().SetCommentRange(receiver, Core.NewTextRange(-1, receiver.End()));

		switch (info.kind) {
			case PrivateIdentifierKindAccessor:
				return Factory().NewClassPrivateFieldSetHelper(receiver, info.brandCheckIdentifier, right, info.kind, info.setterName);
			case PrivateIdentifierKindMethod:
				return Factory().NewClassPrivateFieldSetHelper(receiver, info.brandCheckIdentifier, right, info.kind, null);
			case PrivateIdentifierKindField:
				var f:IdentifierNode = null;
				if (info.isStatic) {
					f = info.variableName;
				}
				return Factory().NewClassPrivateFieldSetHelper(receiver, info.brandCheckIdentifier, right, info.kind, f);
			case PrivateIdentifierKindUntransformed:
				Debug.Fail("Access helpers should not be created for untransformed private elements");
				return null;
			default:
		}
		Debug.AssertNever(info, "Unknown private element type");
		return null;
	}

	function getPrivateInstanceMethodsAndAccessors(node:Node):Array<Node> {
		return Core.Filter(node.Members(), Estransforms.isNonStaticMethodOrAccessorWithPrivateName);
	}

	// memberContainsConstructorReference checks if a class member's body contains an identifier
	// that resolves to the class declaration. Replaces Strada's resolver.hasNodeCheckFlag(member,
	// NodeCheckFlags.ContainsConstructorReference) by walking the AST with the EmitResolver.
	// Only checks member bodies (not computed property names), since computed property names
	// are evaluated during class definition when the binding is still correct.
	function memberContainsConstructorReference(member:Node, classDecl:Node):Bool {
		final classOriginal = EmitContext().MostOriginal(classDecl);
		final className = Ast.GetNameOfDeclaration(classDecl);
		function check(n:Node):Bool {
			if (Ast.IsIdentifier(n) && n != className) {
				final decl = resolver.GetReferencedValueDeclaration(n);
				if (decl == classOriginal) {
					return true;
				}
			}
			// For PropertyAccessExpression, only check the expression, not the name.
			// The .Name() is a property access name, not a value reference to the class.
			if (Ast.IsPropertyAccessExpression(n)) {
				return check(n.Expression());
			}
			return n.ForEachChild(check);
		}
		// Check only the body/initializer of the member, not the name (which may be
		// a computed property name that shouldn't trigger alias substitution).
		if (Ast.IsClassStaticBlockDeclaration(member)) {
			final body = member.AsClassStaticBlockDeclaration().Body;
			if (body != null && check(body.AsNode())) {
				return true;
			}
		} else {
			final body = member.Body();
			if (body != null && check(body)) {
				return true;
			}
		}
		if (Ast.IsPropertyDeclaration(member)) {
			final init = member.Initializer();
			if (init != null && check(init)) {
				return true;
			}
		}
		return false;
	}

	// classContainsConstructorReference checks if any member of a class contains
	// references to the class's own constructor. Replaces Strada's
	// resolver.hasNodeCheckFlag(node, NodeCheckFlags.ContainsConstructorReference).
	function classContainsConstructorReference(node:Node):Bool {
		for (member in (node.Members() ?? [])) { // PORT: range over a possibly-nil slice
			if (memberContainsConstructorReference(member, node)) {
				return true;
			}
		}
		return false;
	}

	function getClassFacts(node:Node):ClassFacts {
		var facts = classFactsNone;

		final original = EmitContext().MostOriginal(node);
		if (Ast.IsClassLike(original) && Ast.ClassOrConstructorParameterIsDecorated(legacyDecorators /*useLegacyDecorators*/, original)) {
			facts |= classFactsClassWasDecorated;
		}

		if (shouldTransformPrivateElementsOrClassStaticBlocks
			&& (Estransforms.classHasClassThisAssignment(EmitContext(), node) || Estransforms.classHasExplicitlyAssignedName(EmitContext(), node))) {
			facts |= classFactsNeedsClassConstructorReference;
		}

		var containsPublicInstanceFields = false;
		var containsInitializedPublicInstanceFields = false;
		var containsInstancePrivateElements = false;
		var containsInstanceAutoAccessors = false;

		for (member in (node.Members() ?? [])) { // PORT: range over a possibly-nil slice
			if (Ast.IsStatic(member)) {
				if (member.Name() != null && (Ast.IsPrivateIdentifier(member.Name()) || Ast.IsAutoAccessorPropertyDeclaration(member))
					&& shouldTransformPrivateElementsOrClassStaticBlocks) {
					facts |= classFactsNeedsClassConstructorReference;
				} else if (Ast.IsAutoAccessorPropertyDeclaration(member) && shouldTransformAutoAccessors && node.Name() == null
					&& EmitContext().ClassThis(node) == null) {
					facts |= classFactsNeedsClassConstructorReference;
				}
				if (Ast.IsPropertyDeclaration(member) || Ast.IsClassStaticBlockDeclaration(member)) {
					if (shouldTransformThisInStaticInitializers && (member.SubtreeFacts() & SubtreeContainsLexicalThis) != 0) {
						facts |= classFactsNeedsSubstitutionForThisInClassStaticField;
						if ((facts & classFactsClassWasDecorated) == 0) {
							facts |= classFactsNeedsClassConstructorReference;
						}
					}
					if (shouldTransformSuperInStaticInitializers && (member.SubtreeFacts() & SubtreeContainsLexicalSuper) != 0) {
						if ((facts & classFactsClassWasDecorated) == 0) {
							facts |= classFactsNeedsClassConstructorReference | classFactsNeedsClassSuperReference;
						}
					}
				}
			} else if (!Ast.HasAbstractModifier(EmitContext().MostOriginal(member))) {
				if (Ast.IsAutoAccessorPropertyDeclaration(member)) {
					containsInstanceAutoAccessors = true;
					containsInstancePrivateElements = containsInstancePrivateElements || Ast.IsPrivateIdentifierClassElementDeclaration(member);
				} else if (Ast.IsPrivateIdentifierClassElementDeclaration(member)) {
					containsInstancePrivateElements = true;
					if (memberContainsConstructorReference(member, node)) {
						facts |= classFactsNeedsClassConstructorReference;
					}
				} else if (Ast.IsPropertyDeclaration(member)) {
					containsPublicInstanceFields = true;
					containsInitializedPublicInstanceFields = containsInitializedPublicInstanceFields || member.Initializer() != null;
				}
			}
		}

		final willHoistInitializersToConstructor = (shouldTransformInitializersUsingDefine && containsPublicInstanceFields)
			|| (shouldTransformInitializersUsingSet && containsInitializedPublicInstanceFields)
			|| (shouldTransformPrivateElementsOrClassStaticBlocks && containsInstancePrivateElements)
			|| (shouldTransformPrivateElementsOrClassStaticBlocks && containsInstanceAutoAccessors && shouldTransformAutoAccessors);

		if (willHoistInitializersToConstructor) {
			facts |= classFactsWillHoistInitializersToConstructor;
		}

		return facts;
	}

	function visitExpressionWithTypeArgumentsInHeritageClause(node:ExpressionWithTypeArguments):Node {
		var facts = classFactsNone;
		if (lexicalEnvironment != null && lexicalEnvironment.data != null) {
			facts = lexicalEnvironment.data.facts;
		}
		if ((facts & classFactsNeedsClassSuperReference) != 0) {
			final temp = Factory().NewTempVariableEx(new AutoGenerateOptions(GeneratedIdentifierFlagsReservedInNestedScopes));
			EmitContext().AddVariableDeclaration(temp);
			getClassLexicalEnvironment().superClassReference = temp;
			return Factory().UpdateExpressionWithTypeArguments(node, Factory().NewAssignmentExpression(temp, Visitor().VisitNode(node.Expression)),
				null /*typeArguments*/);
		}
		return heritageClauseVisitor.VisitEachChild(node.AsNode());
	}

	function visitInNewClassLexicalEnvironment(node:Node, visitor:(tx:ClassFieldsTransformer, node:Node, facts:ClassFacts) -> Node):Node {
		final savedCurrentClassContainer = currentClassContainer;
		final savedPendingExpressions = pendingExpressions;
		final savedLexicalEnvironment = lexicalEnvironment;
		currentClassContainer = node;
		pendingExpressions = null;
		startClassLexicalEnvironment();
		final original = EmitContext().MostOriginal(node);
		enclosingClassDeclarations.Add(original);

		if (shouldTransformPrivateElementsOrClassStaticBlocks || nodeHasTransformPrivateStaticElementsFlag(node)) {
			final name = Ast.GetNameOfDeclaration(node);
			if (name != null && Ast.IsIdentifier(name)) {
				getPrivateIdentifierEnvironment().data.className = name;
			} else {
				final assignedName = EmitContext().AssignedName(node);
				if (assignedName != null) {
					if (Ast.IsStringLiteral(assignedName)) {
						// If the assigned name has a textSourceNode that is an identifier, use it directly.
						final textSourceNode = EmitContext().TextSource(assignedName);
						if (textSourceNode != null && Ast.IsIdentifier(textSourceNode)) {
							getPrivateIdentifierEnvironment().data.className = textSourceNode;
						} else if (Scanner.IsIdentifierText(assignedName.Text(), LanguageVariantStandard)) {
							// If the text is a valid identifier, create an identifier from it.
							final prefixName = Factory().NewIdentifier(assignedName.Text());
							getPrivateIdentifierEnvironment().data.className = prefixName;
						}
					}
				}
			}
		}

		if (shouldTransformPrivateElementsOrClassStaticBlocks) {
			final privateInstanceMethodsAndAccessors = getPrivateInstanceMethodsAndAccessors(node);
			if (privateInstanceMethodsAndAccessors != null && privateInstanceMethodsAndAccessors.length > 0) {
				getPrivateIdentifierEnvironment().data.weakSetName = createHoistedVariableForClass("instances", privateInstanceMethodsAndAccessors[0].Name(), "");
			}
		}

		final facts = getClassFacts(node);
		if (facts != classFactsNone) {
			getClassLexicalEnvironment().facts = facts;
		}

		final result = visitor(this, node, facts);
		enclosingClassDeclarations.Delete(original);
		endClassLexicalEnvironment();
		Debug.Assert(lexicalEnvironment == savedLexicalEnvironment);
		currentClassContainer = savedCurrentClassContainer;
		pendingExpressions = savedPendingExpressions;
		lexicalEnvironment = savedLexicalEnvironment;
		return result;
	}

	function visitClassDeclaration(node:ClassDeclaration):Node {
		return visitInNewClassLexicalEnvironment(node.AsNode(), mxVisitClassDeclarationInNewClassLexicalEnvironment);
	}

	function visitClassDeclarationInNewClassLexicalEnvironment(node:Node, facts:ClassFacts):Node {
		final classDecl = node.AsClassDeclaration();
		// If a class has private static fields, or a static field has a `this` or `super` reference,
		// then we need to allocate a temp variable to hold on to that reference.
		var pendingClassReferenceAssignment:Expression = null;
		if ((facts & classFactsNeedsClassConstructorReference) != 0) {
			// If we aren't transforming class static blocks, then we can't reuse `_classThis` since in
			// `class C { ... static { _classThis = ... } }; _classThis = C` the outer assignment would occur *after*
			// class static blocks evaluate and would overwrite the replacement constructor produced by class
			// decorators.

			// If we are transforming class static blocks, then we can reuse `_classThis` since the assignment
			// will be evaluated *before* the transformed static blocks are evaluated and thus won't overwrite
			// the replacement constructor.

			if (shouldTransformPrivateElementsOrClassStaticBlocks && EmitContext().ClassThis(node) != null) {
				final classThis = EmitContext().ClassThis(node);
				getClassLexicalEnvironment().classConstructor = classThis;
				pendingClassReferenceAssignment = Factory().NewAssignmentExpression(classThis, Factory().GetLocalName(node));
			} else {
				final temp = Factory().NewTempVariableEx(new AutoGenerateOptions(GeneratedIdentifierFlagsReservedInNestedScopes));
				EmitContext().AddVariableDeclaration(temp);
				getClassLexicalEnvironment().classConstructor = temp.Clone(Factory());
				pendingClassReferenceAssignment = Factory().NewAssignmentExpression(temp, Factory().GetLocalName(node));
			}
		}

		if (EmitContext().ClassThis(node) != null) {
			getClassLexicalEnvironment().classThis = EmitContext().ClassThis(node);
		}

		final isClassWithConstructorReference = classContainsConstructorReference(node);

		// Register class alias BEFORE visiting members (Strada registers after, since its
		// onSubstituteNode runs at emit time; we substitute eagerly during transformation).
		final alias = getClassLexicalEnvironment().classConstructor;
		if (isClassWithConstructorReference && alias != null) {
			classAliases.set(EmitContext().MostOriginal(node), alias);
		}

		var modifiers = modifierVisitor.VisitModifiers(classDecl.Modifiers());
		final heritageClauses = heritageClauseVisitor.VisitNodes(classDecl.HeritageClauses);
		final transformed = transformClassMembers(node);
		final members = transformed.a;
		final membersPrologue = transformed.b;

		var statements:Array<Node> = null;

		if (pendingClassReferenceAssignment != null) {
			final pe:Array<Expression> = [pendingClassReferenceAssignment];
			if (pendingExpressions != null) {
				for (e in pendingExpressions) {
					pe.push(e);
				}
			}
			pendingExpressions = pe;
		}

		// Write any pending expressions from elided or moved computed property names
		if (pendingExpressions != null && pendingExpressions.length > 0) {
			if (statements == null) {
				statements = [];
			}
			statements.push(Factory().NewExpressionStatement(Factory().InlineExpressions(pendingExpressions)));
		}

		// A class declaration without a name needs a generated name if it has static
		// initialized properties, since those will be moved outside the class body and
		// need to reference the class by name.
		var name = classDecl.Name();

		if (shouldTransformInitializersUsingSet || shouldTransformPrivateElementsOrClassStaticBlocks) {
			// Emit static property assignment. Because classDeclaration is lexically evaluated,
			// it is safe to emit static property assignment after classDeclaration
			// From ES6 specification:
			//   HasLexicalDeclaration (N) : Determines if the argument identifier has a binding in this environment record that was created using
			//                               a lexical declaration such as a LexicalDeclaration or a ClassDeclaration.
			final staticProperties = getStaticPropertiesAndClassStaticBlock(node);
			if (staticProperties != null && staticProperties.length > 0) {
				if (name == null) {
					name = Factory().NewGeneratedNameForNode(node);
				}
				statements = addPropertyOrClassStaticBlockStatements(statements, staticProperties, Factory().GetLocalName(node));
			}
		}

		final isExport = Ast.HasSyntacticModifier(node, ModifierFlagsExport);
		final isDefault = Ast.HasSyntacticModifier(node, ModifierFlagsDefault);

		if (statements != null && statements.length > 0 && isExport && isDefault) {
			modifiers = Transformers.ExtractModifiers(EmitContext(), modifiers, ~ModifierFlagsExportDefault);
			final exportAssignment = Factory().NewExportAssignment(null, false /*isExportEquals*/, null /*typeNode*/, Factory().GetLocalName(node));
			statements.push(exportAssignment);
		}

		final updatedClass = Factory().UpdateClassDeclaration(classDecl, modifiers, name, null /*typeParameters*/, heritageClauses, members);

		final result:Array<Node> = [];
		if (membersPrologue != null) {
			result.push(Factory().NewExpressionStatement(membersPrologue));
		}
		result.push(updatedClass);
		if (statements != null) {
			for (s in statements) {
				result.push(s);
			}
		}
		return Factory().NewSyntaxList(result);
	}

	function visitClassExpression(node:ClassExpression):Node {
		return visitInNewClassLexicalEnvironment(node.AsNode(), mxVisitClassExpressionInNewClassLexicalEnvironment);
	}

	function visitClassExpressionInNewClassLexicalEnvironment(node:Node, facts:ClassFacts):Node {
		final classExpr = node.AsClassExpression();

		// If this class expression is a transformation of a decorated class declaration,
		// then we want to output the pendingExpressions as statements, not as inlined
		// expressions with the class statement.
		//
		// In this case, we use pendingStatements to produce the same output as the
		// class declaration transformation. The VariableStatement visitor will insert
		// these statements after the class expression variable statement.
		final isDecoratedClassDeclaration = (facts & classFactsClassWasDecorated) != 0;

		if (EmitContext().ClassThis(node) != null) {
			getClassLexicalEnvironment().classThis = EmitContext().ClassThis(node);
		}

		var temp:IdentifierNode = null;
		if ((facts & classFactsNeedsClassConstructorReference) != 0) {
			if ((shouldTransformPrivateElementsOrClassStaticBlocks || nodeHasTransformPrivateStaticElementsFlag(node))
				&& EmitContext().ClassThis(node) != null) {
				final classThis = EmitContext().ClassThis(node);
				getClassLexicalEnvironment().classConstructor = classThis;
				temp = classThis;
			} else {
				temp = Factory().NewTempVariableEx(new AutoGenerateOptions(GeneratedIdentifierFlagsReservedInNestedScopes));
				if (classExpressionNeedsBlockScopedTemp()) {
					EmitContext().AddLexicalDeclaration(temp);
				} else {
					EmitContext().AddVariableDeclaration(temp);
				}
				getClassLexicalEnvironment().classConstructor = temp.Clone(Factory());
			}
		}

		final staticPropertiesOrClassStaticBlocks = getStaticPropertiesAndClassStaticBlock(node);

		// Pre-compute whether the class expression will need a temp variable wrapper.
		// Strada registers class aliases AFTER transformClassMembers (since onSubstituteNode runs
		// at emit time), but we must predict this before visiting members since we substitute
		// eagerly. This requires pre-detecting willHavePrivatePendingExpressions.
		var isClassWithConstructorReference = false;
		var hasTransformableStatics = false;
		var deferTempDeclaration = false;
		if (!isDecoratedClassDeclaration) {
			isClassWithConstructorReference = classContainsConstructorReference(node);
			hasTransformableStatics = (shouldTransformPrivateElementsOrClassStaticBlocks || nodeHasTransformPrivateStaticElementsFlag(node))
				&& Core.Some(staticPropertiesOrClassStaticBlocks, function(n:Node):Bool {
					return Ast.IsClassStaticBlockDeclaration(n) || Ast.IsPrivateIdentifierClassElementDeclaration(n)
						|| (shouldTransformInitializers && Ast.IsInitializedProperty(n));
				});

			// Private instance elements (fields, methods, accessors) transformed to
			// WeakMap/WeakSet will add initialization expressions to pendingExpressions
			// during transformClassMembers. Pre-detect this so we know whether the class
			// will be wrapped with a temp variable.
			final willHavePrivatePendingExpressions = shouldTransformPrivateElementsOrClassStaticBlocks && Core.Some(node.Members(), function(n:Node):Bool {
				return Ast.IsPrivateIdentifierClassElementDeclaration(n) && !Ast.HasStaticModifier(n) && shouldTransformClassElementToWeakMap(n);
			});
			final willNeedTempWrapper = hasTransformableStatics || willHavePrivatePendingExpressions;

			// Register class alias BEFORE visiting members (Strada registers after, since its
			// onSubstituteNode runs at emit time). Only register when the class will be wrapped
			// with a temp, matching Strada's conditional registration.
			if (isClassWithConstructorReference && willNeedTempWrapper && getClassLexicalEnvironment().classConstructor == null) {
				// Create temp early so the alias is available during member visiting, even though in the Strada
				// reference the temp would be created later in the pendingExpressions branch.
				temp = Factory().NewTempVariableEx(new AutoGenerateOptions(GeneratedIdentifierFlagsReservedInNestedScopes));
				// Defer AddVariableDeclaration to preserve Strada's variable declaration ordering.
				deferTempDeclaration = true;
				getClassLexicalEnvironment().classConstructor = temp.Clone(Factory());
			}
			final alias = getClassLexicalEnvironment().classConstructor;
			if (isClassWithConstructorReference && willNeedTempWrapper && alias != null) {
				classAliases.set(EmitContext().MostOriginal(node), alias);
			}
		}

		final modifiers = modifierVisitor.VisitModifiers(classExpr.Modifiers());
		final heritageClauses = heritageClauseVisitor.VisitNodes(classExpr.HeritageClauses);
		final transformed = transformClassMembers(node);
		final members = transformed.a;
		final membersPrologue = transformed.b;

		if (deferTempDeclaration) {
			if (classExpressionNeedsBlockScopedTemp()) {
				EmitContext().AddLexicalDeclaration(temp);
			} else {
				EmitContext().AddVariableDeclaration(temp);
			}
		}

		final classExpression = Factory().UpdateClassExpression(classExpr, modifiers, classExpr.Name(), null /*typeParameters*/, heritageClauses, members);

		final expressions:Array<Expression> = [];
		if (membersPrologue != null) {
			expressions.push(membersPrologue);
		}

		if (!isDecoratedClassDeclaration) {
			if (hasTransformableStatics || (pendingExpressions != null && pendingExpressions.length > 0)) {
				if (temp == null) {
					temp = Factory().NewTempVariableEx(new AutoGenerateOptions(GeneratedIdentifierFlagsReservedInNestedScopes));
					if (classExpressionNeedsBlockScopedTemp()) {
						EmitContext().AddLexicalDeclaration(temp);
					} else {
						EmitContext().AddVariableDeclaration(temp);
					}
					getClassLexicalEnvironment().classConstructor = temp.Clone(Factory());
					if (isClassWithConstructorReference) {
						classAliases.set(EmitContext().MostOriginal(node), getClassLexicalEnvironment().classConstructor);
					}
				}

				expressions.push(Factory().NewAssignmentExpression(temp, classExpression));

				// Add any pending expressions leftover from elided or relocated computed property names
				if (pendingExpressions != null) {
					for (e in pendingExpressions) {
						expressions.push(e);
					}
				}

				final initialized = generateInitializedPropertyExpressionsOrClassStaticBlock(staticPropertiesOrClassStaticBlocks, temp);
				if (initialized != null) {
					for (e in initialized) {
						expressions.push(e);
					}
				}
				expressions.push(temp.Clone(Factory()));
			} else {
				expressions.push(classExpression);
			}
		} else {
			// Decorated class declaration path: emit static properties as separate statements
			// via pendingStatements, matching the class declaration output structure.

			// Write any pending expressions from elided or moved computed property names
			if (pendingExpressions != null && pendingExpressions.length > 0) {
				for (expr in pendingExpressions) {
					if (pendingStatements == null) {
						pendingStatements = [];
					}
					pendingStatements.push(Factory().NewExpressionStatement(expr));
				}
			}

			// Emit static properties as statements (via pendingStatements) using the class's
			// internal name as the receiver, matching the class declaration output structure.
			if (staticPropertiesOrClassStaticBlocks != null && staticPropertiesOrClassStaticBlocks.length > 0) {
				var classThisOrName = EmitContext().ClassThis(node);
				if (classThisOrName == null) {
					classThisOrName = Factory().GetLocalName(node);
				}
				pendingStatements = addPropertyOrClassStaticBlockStatements(pendingStatements, staticPropertiesOrClassStaticBlocks, classThisOrName);
			}

			if (temp != null) {
				expressions.push(Factory().NewAssignmentExpression(temp, classExpression));
			} else if (shouldTransformPrivateElementsOrClassStaticBlocks && EmitContext().ClassThis(node) != null) {
				expressions.push(Factory().NewAssignmentExpression(EmitContext().ClassThis(node), classExpression));
			} else {
				expressions.push(classExpression);
			}
		}

		if (expressions.length > 1) {
			EmitContext().AddEmitFlags(classExpression, EFIndented);
			for (expr in expressions) {
				EmitContext().AddEmitFlags(expr, EFStartOnNewLine);
			}
		}
		return Factory().InlineExpressions(expressions);
	}

	function visitClassStaticBlockDeclaration(node:Node):Node {
		if (!shouldTransformPrivateElementsOrClassStaticBlocks) {
			return Visitor().VisitEachChild(node);
		}
		// ClassStaticBlockDeclaration for classes are transformed in visitClassDeclaration/visitClassExpression.
		return null;
	}

	// visitThisExpression replaces Strada's substituteThisExpression / onSubstituteNode.
	// Strada substitutes `this` at emit time; we do it eagerly during transformation.
	//
	// The Strada noSubstitution set (ensureDynamicThisIfNeeded) is not needed because
	// transformAutoAccessor() passes the receiver directly rather than emitting `this`.
	function visitThisExpression(node:Node):Node {
		if (insideComputedPropertyName && shouldTransformThisInStaticInitializers && lexicalEnvironment != null && lexicalEnvironment.data != null) {
			// Don't replace `this` in computed property names for ES-decorated classes.
			// The esDecorator transformer wraps them in an arrow IIFE where `this` already
			// refers to the correct outer scope.
			if ((lexicalEnvironment.data.facts & classFactsClassWasDecorated) == 0 || legacyDecorators) {
				final classThis = tryGetClassThisNoContainer();
				if (classThis != null) {
					return classThis;
				}
			}
		}
		if (shouldTransformThisInStaticInitializers && currentClassElement != null
			&& (Ast.IsClassStaticBlockDeclaration(currentClassElement)
				|| (Ast.IsPropertyDeclaration(currentClassElement) && Ast.HasStaticModifier(currentClassElement)))
			&& lexicalEnvironment != null && lexicalEnvironment.data != null) {
			final classThis = tryGetClassThisNoContainer();
			if (classThis != null) {
				return classThis;
			}
			// When the class was decorated with legacy decorators and no class constructor
			// reference is available, the decorator may replace the constructor, so `this`
			// cannot reliably point to the class. Use `(void 0)` instead.
			if ((lexicalEnvironment.data.facts & classFactsClassWasDecorated) != 0 && legacyDecorators) {
				return Factory().NewParenthesizedExpression(Factory().NewVoidZeroExpression());
			}
		}
		return node;
	}

	function transformClassMembers(node:Node):Pair<NodeList, Expression> {
		var members:NodeList = null;
		var prologue:Expression = null;
		final shouldTransformPrivateStaticElementsInClass = (EmitContext().EmitFlags(node) & EFTransformPrivateStaticElements) != 0;

		// Declare private names
		if (shouldTransformPrivateElementsOrClassStaticBlocks || shouldTransformPrivateStaticElementsInFile) {
			for (member in (node.Members() ?? [])) { // PORT: range over a possibly-nil slice
				if (Ast.IsPrivateIdentifierClassElementDeclaration(member)) {
					if (shouldTransformClassElementToWeakMap(member)) {
						addPrivateIdentifierToEnvironment(member);
					} else {
						final env = getPrivateIdentifierEnvironment();
						final info = new PrivateIdentifierInfo();
						info.kind = PrivateIdentifierKindUntransformed;
						setPrivateIdentifier(env, member.Name(), info);
					}
				}
			}

			if (shouldTransformPrivateElementsOrClassStaticBlocks) {
				final m = getPrivateInstanceMethodsAndAccessors(node);
				if (m != null && m.length > 0) {
					createBrandCheckWeakSetForPrivateMethods();
				}
			}

			if (shouldTransformAutoAccessorsInCurrentClass()) {
				for (member in (node.Members() ?? [])) { // PORT: range over a possibly-nil slice
					if (Ast.IsAutoAccessorPropertyDeclaration(member)) {
						final storageName = Factory().NewGeneratedPrivateNameForNodeEx(member.Name(), new AutoGenerateOptions(GeneratedIdentifierFlagsNone, "", "_accessor_storage"));
						if (shouldTransformPrivateElementsOrClassStaticBlocks
							|| (shouldTransformPrivateStaticElementsInClass && Ast.HasStaticModifier(member))) {
							addPrivateIdentifierPropertyDeclarationToEnvironment(member, storageName);
						} else {
							final env = getPrivateIdentifierEnvironment();
							// Only register as untransformed if it hasn't already been registered
							// by the first loop (e.g., if esDecorators expanded a private auto-accessor
							// into a backing field with the same generated name).
							if (!getPrivateIdentifier(env, storageName).ok) {
								final info = new PrivateIdentifierInfo();
								info.kind = PrivateIdentifierKindUntransformed;
								setPrivateIdentifier(env, storageName, info);
							}
						}
					}
				}
			}
		}

		members = classElementVisitor.VisitNodes(node.MemberList());

		// Create a synthetic constructor if necessary
		var syntheticConstructor:Node = null;
		if (!Core.Some(members.Nodes, Ast.IsConstructorDeclaration)) {
			syntheticConstructor = transformConstructor(null, node);
		}

		// If there are pending expressions create a class static block in which to evaluate them, but only if
		// class static blocks are not also being transformed. This block will be injected at the top of the class
		// to ensure that expressions from computed property names are evaluated before any other static
		// initializers.
		var syntheticStaticBlock:Node = null;
		if (!shouldTransformPrivateElementsOrClassStaticBlocks && pendingExpressions != null && pendingExpressions.length > 0) {
			var statement = Factory().NewExpressionStatement(Factory().InlineExpressions(pendingExpressions));
			if ((statement.SubtreeFacts() & SubtreeContainsLexicalThisOrSuper) != 0) {
				// If there are `this` or `super` references from computed property names, shift the expression
				// into an arrow function to be evaluated in the outer scope so that `this` and `super` are
				// properly captured.
				final temp = Factory().NewTempVariable();
				EmitContext().AddVariableDeclaration(temp);
				final arrow = Factory().NewArrowFunction(null /*modifiers*/, null /*typeParameters*/, Factory().NewNodeList(null) /*parameters*/, null /*returnType*/,
					null /*fullSignature*/, Factory().NewToken(KindEqualsGreaterThanToken) /*equalsGreaterThanToken*/,
					Factory().NewBlock(Factory().NewNodeList([statement]), false /*multiline*/));
				prologue = Factory().NewAssignmentExpression(temp, arrow);
				statement = Factory().NewExpressionStatement(Factory().NewCallExpression(temp, null /*questionDotToken*/, null /*typeArguments*/,
					Factory().NewNodeList(null), NodeFlagsNone));
			}

			final block = Factory().NewBlock(Factory().NewNodeList([statement]), false /*multiline*/);
			syntheticStaticBlock = Factory().NewClassStaticBlockDeclaration(null /*modifiers*/, block);
			pendingExpressions = null;
		}

		// If we created a synthetic constructor or class static block, add them to the visited members
		if (syntheticConstructor != null || syntheticStaticBlock != null) {
			final membersArray:Array<Node> = [];

			// Find and preserve classThis assignment block and named evaluation helper block at the top
			// PORT: slices.IndexFunc → Core.FindIndex.
			final classThisIdx = Core.FindIndex(members.Nodes, function(n:Node):Bool {
				return Estransforms.isClassThisAssignmentBlock(EmitContext(), n);
			});
			final namedEvalIdx = Core.FindIndex(members.Nodes, function(n:Node):Bool {
				return Estransforms.isClassNamedEvaluationHelperBlock(EmitContext(), n);
			});

			if (classThisIdx >= 0) {
				membersArray.push(members.Nodes[classThisIdx]);
			}
			if (namedEvalIdx >= 0) {
				membersArray.push(members.Nodes[namedEvalIdx]);
			}
			if (syntheticConstructor != null) {
				membersArray.push(syntheticConstructor);
			}
			if (syntheticStaticBlock != null) {
				membersArray.push(syntheticStaticBlock);
			}

			if (members.Nodes != null) {
				for (i in 0...members.Nodes.length) {
					final member = members.Nodes[i];
					if (i != classThisIdx && i != namedEvalIdx) {
						membersArray.push(member);
					}
				}
			}
			members = Factory().NewNodeList(membersArray);
			members.Loc = node.MemberList().Loc;
		}

		return new Pair<NodeList, Expression>(members, prologue);
	}

	function createBrandCheckWeakSetForPrivateMethods():Void {
		final env = getPrivateIdentifierEnvironment();
		final weakSetName = env.data.weakSetName;
		Debug.Assert(weakSetName != null, "weakSetName should be set in private identifier environment");

		addPendingExpressions(Factory().NewAssignmentExpression(weakSetName,
			Factory().NewNewExpression(Factory().NewIdentifier("WeakSet"), null /*typeArguments*/, Factory().NewNodeList(null))));
	}

	function transformConstructor(constructor:ConstructorDeclaration, container:Node):Node {
		// NOTE: The Strada reference pre-visits the constructor via `visitNode(constructor, visitor)` before
		// checking WillHoistInitializersToConstructor. This is not done here because Go's variable environment
		// (StartVariableEnvironment/EndAndMergeVariableEnvironment) is scoped inside transformConstructorBody.
		// Pre-visiting would hoist variables outside that scope, causing them to appear after field initializers
		// instead of before. Instead, we visit parameters and body separately within the correct scopes.
		if (lexicalEnvironment == null || lexicalEnvironment.data == null
			|| (lexicalEnvironment.data.facts & classFactsWillHoistInitializersToConstructor) == 0) {
			if (constructor != null) {
				return Visitor().VisitEachChild(constructor.AsNode());
			}
			return null;
		}

		final extendsClauseElement = Ast.GetClassExtendsHeritageElement(container);
		final isDerivedClass = extendsClauseElement != null
			&& Ast.SkipOuterExpressions(extendsClauseElement.Expression(), OEKAll).Kind != KindNullKeyword;

		var parameters:NodeList = null;
		if (constructor != null) {
			parameters = Visitor().VisitNodes(constructor.Parameters);
		}

		final body = transformConstructorBody(container, constructor, isDerivedClass);
		if (body == null) {
			if (constructor != null) {
				return Visitor().VisitEachChild(constructor.AsNode());
			}
			return null;
		}

		if (constructor != null) {
			Debug.Assert(parameters != null);
			return Factory().UpdateConstructorDeclaration(constructor, null /*modifiers*/, null /*typeParameters*/, parameters, null /*returnType*/,
				null /*fullSignature*/, body);
		}

		if (parameters == null) {
			parameters = Factory().NewNodeList(null);
		}

		final result = Factory().NewConstructorDeclaration(null /*modifiers*/, null /*typeParameters*/, parameters, null /*returnType*/,
			null /*fullSignature*/, body);
		result.Loc = container.Loc;
		return result;
	}

	function transformConstructorBodyWorker(statementsOut:Array<Statement>, statementsIn:Array<Statement>, statementOffset:Int, superPath:Array<Int>, superPathDepth:Int, initializerStatements:Array<Statement>, constructor:ConstructorDeclaration):Array<Statement> {
		final superStatementIndex = superPath[superPathDepth];
		final superStatement = statementsIn[superStatementIndex];

		// PORT: statementsOut may be nil in Go; append to a nil slice.
		if (statementsOut == null) {
			statementsOut = [];
		}

		// Visit statements before super
		final visited = Visitor().VisitSlice(statementsIn.slice(statementOffset, superStatementIndex)).a;
		if (visited != null) {
			for (s in visited) {
				statementsOut.push(s);
			}
		}
		statementOffset = superStatementIndex + 1;

		if (Ast.IsTryStatement(superStatement)) {
			final tryBlock = superStatement.AsTryStatement().TryBlock.AsBlock();
			final tryBlockStatements = transformConstructorBodyWorker(null, tryBlock.Statements.Nodes, 0 /*statementOffset*/, superPath, superPathDepth + 1,
				initializerStatements, constructor);
			final tryStatementList = Factory().NewNodeList(tryBlockStatements);
			tryStatementList.Loc = tryBlock.Statements.Loc;

			final catchClause = Visitor().VisitNode(superStatement.AsTryStatement().CatchClause);
			final finallyBlock = Visitor().VisitNode(superStatement.AsTryStatement().FinallyBlock);

			final updated = Factory().UpdateTryStatement(superStatement.AsTryStatement(), Factory().UpdateBlock(tryBlock, tryStatementList, tryBlock.MultiLine),
				catchClause, finallyBlock);
			statementsOut.push(updated);
		} else {
			final visited = Visitor().VisitSlice(statementsIn.slice(superStatementIndex, superStatementIndex + 1)).a;
			if (visited != null) {
				for (s in visited) {
					statementsOut.push(s);
				}
			}

			// Add the property initializers. Transforms this:
			//
			//  public x = 1;
			//
			// Into this:
			//
			//  constructor() {
			//      this.x = 1;
			//  }
			//
			// If we do useDefineForClassFields, they'll be converted elsewhere.
			// We instead *remove* them from the transformed output at this stage.

			// parameter-property assignments should occur immediately after the prologue and `super()`,
			// so only count the statements that immediately follow.
			while (statementOffset < statementsIn.length) {
				final stmt = statementsIn[statementOffset];
				final orig = EmitContext().MostOriginal(stmt);
				if (Ast.IsParameterPropertyDeclaration(orig, constructor.AsNode())) {
					statementOffset++;
				} else {
					break;
				}
			}

			if (initializerStatements != null) {
				for (s in initializerStatements) {
					statementsOut.push(s);
				}
			}
		}

		// Visit remaining statements
		final visited2 = Visitor().VisitSlice(statementsIn.slice(statementOffset)).a;
		if (visited2 != null) {
			for (s in visited2) {
				statementsOut.push(s);
			}
		}
		return statementsOut;
	}

	function transformConstructorBody(container:Node, constructor:ConstructorDeclaration, isDerivedClass:Bool):Node {
		final instanceProperties = getProperties(container, false /*requireInitializer*/, false /*isStatic*/);
		var properties = instanceProperties;
		if (!compilerOptions.GetUseDefineForClassFields()) {
			properties = Core.Filter(properties, function(prop:Node):Bool {
				return prop.Initializer() != null || Ast.IsPrivateIdentifier(prop.Name()) || Ast.HasAccessorModifier(prop);
			});
		}

		final privateMethodsAndAccessors = getPrivateInstanceMethodsAndAccessors(container);
		final needsConstructorBody = Core.len(properties) > 0 || Core.len(privateMethodsAndAccessors) > 0;

		// Only generate synthetic constructor when there are property initializers to move.
		if (constructor == null && !needsConstructorBody) {
			return EmitContext().VisitFunctionBody(null, Visitor());
		}

		EmitContext().StartVariableEnvironment();

		final needsSyntheticConstructor = constructor == null && isDerivedClass;
		var statements:Array<Statement> = null;

		// Add the property initializers. Transforms this:
		//
		//  public x = 1;
		//
		// Into this:
		//
		//  constructor() {
		//      this.x = 1;
		//  }
		//
		var initializerStatements:Array<Statement> = null;
		final receiver = Factory().NewThisExpression();

		// private methods can be called in property initializers, they should execute first
		initializerStatements = addInstanceMethodStatements(initializerStatements, privateMethodsAndAccessors, receiver);

		if (constructor != null) {
			final parameterProperties = Core.Filter(instanceProperties, function(prop:Node):Bool {
				return Ast.IsParameterPropertyDeclaration(EmitContext().MostOriginal(prop), constructor.AsNode());
			});
			final nonParameterProperties = Core.Filter(properties, function(prop:Node):Bool {
				return !Ast.IsParameterPropertyDeclaration(EmitContext().MostOriginal(prop), constructor.AsNode());
			});
			initializerStatements = addPropertyOrClassStaticBlockStatements(initializerStatements, parameterProperties, receiver);
			initializerStatements = addPropertyOrClassStaticBlockStatements(initializerStatements, nonParameterProperties, receiver);
		} else {
			initializerStatements = addPropertyOrClassStaticBlockStatements(initializerStatements, properties, receiver);
		}

		if (constructor != null && constructor.Body != null) {
			final body = constructor.Body.AsBlock();

			// Copy prologue
			for (stmt in (body.Statements.Nodes ?? [])) { // PORT: range over a possibly-nil slice
				if (Ast.IsPrologueDirective(stmt)) {
					if (statements == null) {
						statements = [];
					}
					statements.push(stmt);
				} else {
					break;
				}
			}
			var statementOffset = Core.len(statements);

			final superPath = Transformers.FindSuperStatementIndexPath(body.Statements.Nodes, statementOffset);
			if (Core.len(superPath) > 0) {
				statements = transformConstructorBodyWorker(statements, body.Statements.Nodes, statementOffset, superPath, 0, initializerStatements, constructor);
			} else {
				// parameter-property assignments should occur immediately after the prologue and `super()`,
				// so only count the statements that immediately follow.
				while (statementOffset < Core.len(body.Statements.Nodes)) {
					final stmt = body.Statements.Nodes[statementOffset];
					final orig = EmitContext().MostOriginal(stmt);
					if (Ast.IsParameterPropertyDeclaration(orig, constructor.AsNode())) {
						statementOffset++;
					} else {
						break;
					}
				}
				if (initializerStatements != null) {
					for (s in initializerStatements) {
						if (statements == null) {
							statements = [];
						}
						statements.push(s);
					}
				}
				final visited = Visitor().VisitSlice(body.Statements.Nodes == null ? null : body.Statements.Nodes.slice(statementOffset)).a;
				if (visited != null) {
					for (s in visited) {
						if (statements == null) {
							statements = [];
						}
						statements.push(s);
					}
				}
			}
		} else {
			if (needsSyntheticConstructor) {
				// Add a synthetic `super` call:
				//
				//  super(...arguments);
				//
				final superCall = Factory().NewExpressionStatement(Factory().NewCallExpression(Factory().NewKeywordExpression(KindSuperKeyword),
					null /*typeArguments*/, null /*questionDotToken*/, Factory().NewNodeList([Factory().NewSpreadElement(Factory().NewIdentifier("arguments"))]),
					NodeFlagsNone));
				if (statements == null) {
					statements = [];
				}
				statements.push(superCall);
			}
			if (initializerStatements != null) {
				for (s in initializerStatements) {
					if (statements == null) {
						statements = [];
					}
					statements.push(s);
				}
			}
		}

		statements = EmitContext().EndAndMergeVariableEnvironment(statements);

		if (Core.len(statements) == 0 && constructor == null) {
			return null;
		}

		var multiLine = false;
		if (constructor != null && constructor.Body != null && Core.len(constructor.Body.AsBlock().Statements.Nodes) >= Core.len(statements)) {
			multiLine = constructor.Body.AsBlock().MultiLine;
		} else {
			multiLine = Core.len(statements) > 0;
		}

		final statementList = Factory().NewNodeList(statements);
		if (constructor != null && constructor.Body != null) {
			statementList.Loc = constructor.Body.AsBlock().Statements.Loc;
		} else {
			statementList.Loc = Core.NewTextRange(container.MemberList().Loc.Pos(), container.MemberList().Loc.End());
		}

		final block = Factory().NewBlock(statementList, multiLine);
		if (constructor != null && constructor.Body != null) {
			block.Loc = constructor.Body.Loc;
		}
		return block;
	}

	// addPropertyOrClassStaticBlockStatements generates assignment statements for property initializers.
	function addPropertyOrClassStaticBlockStatements(statements:Array<Node>, properties:Array<Node>, receiver:Expression):Array<Node> {
		if (properties != null) {
			for (property in properties) {
				if (Ast.IsStatic(property) && !shouldTransformPrivateElementsOrClassStaticBlocks) {
					continue;
				}
				final statement = transformPropertyOrClassStaticBlock(property, receiver);
				if (statement != null) {
					if (statements == null) {
						statements = [];
					}
					statements.push(statement);
				}
			}
		}
		return statements;
	}

	function transformPropertyOrClassStaticBlock(property:Node, receiver:Expression):Node {
		var expression:Expression = null;
		if (Ast.IsClassStaticBlockDeclaration(property)) {
			expression = setCurrentClassElementAnd(property, mxTransformClassStaticBlockDeclaration, property);
		} else {
			expression = transformProperty(property.AsPropertyDeclaration(), receiver);
		}
		if (expression == null) {
			return null;
		}

		final statement = Factory().NewExpressionStatement(expression);
		EmitContext().SetOriginal(statement, property);
		EmitContext().AddEmitFlags(statement, EmitContext().EmitFlags(property) & EFNoComments);
		EmitContext().SetCommentRange(statement, property.Loc);

		final propertyOriginalNode = EmitContext().MostOriginal(property);
		if (Ast.IsParameterDeclaration(propertyOriginalNode)) {
			EmitContext().SetSourceMapRange(statement, propertyOriginalNode.Loc);
			EmitContext().AddEmitFlags(statement, EFNoComments);
		} else {
			EmitContext().SetSourceMapRange(statement, Transformers.MoveRangePastModifiers(property));
		}

		// `setOriginalNode` *copies* the `emitNode` from `property`, so now both
		// `statement` and `expression` have a copy of the synthesized comments.
		// Drop the comments from expression to avoid printing them twice.
		EmitContext().SetSyntheticLeadingComments(expression, null);
		EmitContext().SetSyntheticTrailingComments(expression, null);

		// If the property was originally an auto-accessor, don't emit comments here since they will be attached to
		// the synthesized getter.
		if (Ast.HasAccessorModifier(propertyOriginalNode)) {
			EmitContext().AddEmitFlags(statement, EFNoComments);
		}

		return statement;
	}

	// generateInitializedPropertyExpressionsOrClassStaticBlock generates assignment expressions for property initializers.
	function generateInitializedPropertyExpressionsOrClassStaticBlock(propertiesOrClassStaticBlocks:Array<Node>, receiver:Expression):Array<Expression> {
		var expressions:Array<Expression> = null;
		if (propertiesOrClassStaticBlocks != null) {
			for (property in propertiesOrClassStaticBlocks) {
				var expression:Expression = null;
				if (Ast.IsClassStaticBlockDeclaration(property)) {
					expression = setCurrentClassElementAnd(property, mxTransformClassStaticBlockDeclaration, property);
				} else {
					expression = transformProperty(property.AsPropertyDeclaration(), receiver);
				}
				if (expression == null) {
					continue;
				}
				EmitContext().SetOriginalEx(expression, property, true /*allowOverwrite*/);
				EmitContext().AssignCommentAndSourceMapRanges(expression, property);
				if (expressions == null) {
					expressions = [];
				}
				expressions.push(expression);
			}
		}
		return expressions;
	}

	// transformProperty transforms a property initializer into an assignment expression.
	function transformProperty(property:PropertyDeclaration, receiver:Expression):Expression {
		final savedCurrentClassElement = currentClassElement;
		final transformed = transformPropertyWorker(property, receiver);
		if (transformed != null && Ast.HasStaticModifier(property.AsNode())) {
			EmitContext().AddEmitFlags(transformed, EFNoLexicalThis);
		}
		if (transformed != null && Ast.HasStaticModifier(property.AsNode()) && lexicalEnvironment != null && lexicalEnvironment.data != null
			&& lexicalEnvironment.data.facts != 0) {
			// capture the lexical environment for the member
			EmitContext().SetOriginal(transformed, property.AsNode());
			EmitContext().SetSourceMapRange(transformed, EmitContext().SourceMapRange(property.Name()));
		}
		currentClassElement = savedCurrentClassElement;
		return transformed;
	}

	function transformPropertyWorker(property:PropertyDeclaration, receiver:Expression):Expression {
		// We generate a name here in order to reuse the value cached by the relocated computed name expression (which uses the same generated name)
		final emitAssignment = !compilerOptions.GetUseDefineForClassFields();

		if (Estransforms.isNamedEvaluationAnd(EmitContext(), property.AsNode(), isAnonymousClassNeedingAssignedName)) {
			property = Estransforms.transformNamedEvaluation(EmitContext(), property.AsNode(), false, "").AsPropertyDeclaration();
		}

		var propertyName = property.Name();
		if (Ast.HasAccessorModifier(property.AsNode())) {
			propertyName = Factory().NewGeneratedPrivateNameForNodeEx(property.Name(), new AutoGenerateOptions(GeneratedIdentifierFlagsNone, "", "_accessor_storage"));
		} else if (Ast.IsComputedPropertyName(propertyName) && !Transformers.IsSimpleInlineableExpression(propertyName.Expression())) {
			propertyName = Factory().UpdateComputedPropertyName(propertyName.AsComputedPropertyName(), Factory().NewGeneratedNameForNode(propertyName));
		}

		if (Ast.HasStaticModifier(property.AsNode())) {
			currentClassElement = property.AsNode();
		}

		if (Ast.IsPrivateIdentifier(propertyName) && shouldTransformClassElementToWeakMap(property.AsNode())) {
			final info = accessPrivateIdentifier(propertyName);
			if (info != null) {
				if (info.kind == PrivateIdentifierKindField) {
					if (!info.isStatic) {
						return Estransforms.createPrivateInstanceFieldInitializer(Factory(), receiver, Visitor().VisitNode(property.Initializer),
							info.brandCheckIdentifier);
					}
					return Estransforms.createPrivateStaticFieldInitializer(Factory(), info.variableName, Visitor().VisitNode(property.Initializer));
				}
				return null;
			} else {
				Debug.Fail("Undeclared private name for property declaration.");
			}
		}

		if ((Ast.IsPrivateIdentifier(propertyName) || Ast.HasStaticModifier(property.AsNode())) && property.Initializer == null) {
			return null;
		}

		// TODO: can we get rid of this original checking and better coordinate with runtimesyntax?
		if (Ast.HasAbstractModifier(EmitContext().MostOriginal(property.AsNode()))) {
			return null;
		}

		var initializer = Visitor().VisitNode(property.Initializer);
		final propertyOriginalNode = EmitContext().MostOriginal(property.AsNode());
		if (Ast.IsParameterPropertyDeclaration(propertyOriginalNode, propertyOriginalNode.Parent) && Ast.IsIdentifier(propertyName)) {
			// A parameter-property declaration always overrides the initializer. The only time a parameter-property
			// declaration *should* have an initializer is when decorators have added initializers that need to run before
			// any other initializer
			final localName = propertyName.Clone(Factory());
			if (initializer != null) {
				// unwrap `(__runInitializers(this, _instanceExtraInitializers), void 0)`
				if (Ast.IsParenthesizedExpression(initializer) && Ast.IsCommaExpression(initializer.Expression())
					&& EmitContext().IsCallToHelper(initializer.Expression().AsBinaryExpression().Left, "__runInitializers")
					&& Ast.IsVoidExpression(initializer.Expression().AsBinaryExpression().Right)
					&& Ast.IsNumericLiteral(initializer.Expression().AsBinaryExpression().Right.Expression())) {
					initializer = initializer.Expression().AsBinaryExpression().Left;
				}
				initializer = Factory().InlineExpressions([initializer, localName]);
			} else {
				initializer = localName;
			}
			EmitContext().AddEmitFlags(propertyName, EFNoComments | EFNoSourceMap);
			EmitContext().SetSourceMapRange(localName, propertyOriginalNode.Name().Loc);
			EmitContext().AddEmitFlags(localName, EFNoComments);
		} else if (initializer == null) {
			initializer = Factory().NewVoidZeroExpression();
		}

		if (emitAssignment || Ast.IsPrivateIdentifier(propertyName)) {
			final memberAccess = Estransforms.createMemberAccessForPropertyName(Factory(), EmitContext(), receiver, propertyName, propertyName);
			EmitContext().AddEmitFlags(memberAccess, EFNoLeadingComments);
			return Factory().NewAssignmentExpression(memberAccess, initializer);
		}

		// useDefineForClassFields: Object.defineProperty
		var name:Expression = null;
		if (Ast.IsComputedPropertyName(propertyName)) {
			name = propertyName.Expression();
		} else if (Ast.IsIdentifier(propertyName)) {
			name = Factory().NewStringLiteral(propertyName.Text(), TokenFlagsNone);
		} else {
			name = propertyName;
		}
		final descriptor = Factory().NewObjectLiteralExpression(Factory().NewNodeList([
			Factory().NewPropertyAssignment(null, Factory().NewIdentifier("enumerable"), null, null, Factory().NewTrueExpression()),
			Factory().NewPropertyAssignment(null, Factory().NewIdentifier("configurable"), null, null, Factory().NewTrueExpression()),
			Factory().NewPropertyAssignment(null, Factory().NewIdentifier("writable"), null, null, Factory().NewTrueExpression()),
			Factory().NewPropertyAssignment(null, Factory().NewIdentifier("value"), null, null, initializer),
		]), true);
		return Factory().NewObjectDefinePropertyCall(receiver, name, descriptor);
	}

	// addInstanceMethodStatements generates brand-check initializer for private methods.
	function addInstanceMethodStatements(statements:Array<Statement>, methods:Array<Node>, receiver:Expression):Array<Statement> {
		if (!shouldTransformPrivateElementsOrClassStaticBlocks || Core.len(methods) == 0) {
			return statements;
		}

		final env = getPrivateIdentifierEnvironment();
		final weakSetName = env.data.weakSetName;
		Debug.Assert(weakSetName != null, "weakSetName should be set in private identifier environment");

		// PORT: append to a possibly-nil slice.
		if (statements == null) {
			statements = [];
		}
		statements.push(Factory().NewExpressionStatement(Estransforms.createPrivateInstanceMethodInitializer(Factory(), receiver, weakSetName)));
		return statements;
	}

	function visitInvalidSuperProperty(node:Node):Node {
		if (Ast.IsPropertyAccessExpression(node)) {
			return Factory().UpdatePropertyAccessExpression(node.AsPropertyAccessExpression(), Factory().NewVoidZeroExpression(), null, node.Name(), node.Flags);
		}
		return Factory().UpdateElementAccessExpression(node.AsElementAccessExpression(), Factory().NewVoidZeroExpression(), null,
			Visitor().VisitNode(node.AsElementAccessExpression().ArgumentExpression), node.Flags);
	}

	// getPropertyNameExpressionIfNeeded transforms a computed property name, then either returns an expression
	// which caches the value of the result or the expression itself if the value is either unused or safe to
	// inline into multiple locations.
	// shouldHoist indicates whether the expression needs to be reused (i.e., for an initializer or a decorator).
	function getPropertyNameExpressionIfNeeded(name:PropertyName, shouldHoist:Bool):Expression {
		if (!Ast.IsComputedPropertyName(name)) {
			return null;
		}
		final cacheAssignment = Estransforms.findComputedPropertyNameCacheAssignment(EmitContext(), name);
		// Switch to outer lex env for computed property name expressions, matching
		// Strada reference's onEmitNode behavior for ComputedPropertyName.
		final savedLexicalEnvironment = lexicalEnvironment;
		final savedInsideComputedPropertyName = insideComputedPropertyName;
		insideComputedPropertyName = true;
		if (lexicalEnvironment != null && lexicalEnvironment.previous != null) {
			lexicalEnvironment = lexicalEnvironment.previous;
		}
		final expression = Visitor().VisitNode(name.Expression());
		lexicalEnvironment = savedLexicalEnvironment;
		insideComputedPropertyName = savedInsideComputedPropertyName;
		final innerExpression = Ast.SkipPartiallyEmittedExpressions(expression);
		final inlinable = Transformers.IsSimpleInlineableExpression(innerExpression);
		final alreadyTransformed = cacheAssignment != null
			|| (Ast.IsAssignmentExpression(innerExpression, true /*excludeCompoundAssignment*/)
				&& Ast.IsIdentifier(innerExpression.AsBinaryExpression().Left)
				&& Transformers.IsGeneratedIdentifier(EmitContext(), innerExpression.AsBinaryExpression().Left));
		if (!alreadyTransformed && !inlinable && shouldHoist) {
			final generatedName = Factory().NewGeneratedNameForNode(name);
			if (requiresBlockScopedVar()) {
				EmitContext().AddLexicalDeclaration(generatedName);
			} else {
				EmitContext().AddVariableDeclaration(generatedName);
			}
			return Factory().NewAssignmentExpression(generatedName, expression);
		}
		if (inlinable || Ast.IsIdentifier(innerExpression)) {
			return null;
		}
		return expression;
	}

	function startClassLexicalEnvironment():Void {
		final env = new ClassLexicalEnv();
		env.previous = lexicalEnvironment;
		lexicalEnvironment = env;
	}

	function endClassLexicalEnvironment():Void {
		lexicalEnvironment = lexicalEnvironment.previous;
	}

	function getClassLexicalEnvironment():ClassLexicalEnvironment {
		Debug.Assert(lexicalEnvironment != null);
		if (lexicalEnvironment.data == null) {
			lexicalEnvironment.data = new ClassLexicalEnvironment();
		}
		return lexicalEnvironment.data;
	}

	function getPrivateIdentifierEnvironment():PrivateEnvironment {
		Debug.Assert(lexicalEnvironment != null);
		if (lexicalEnvironment.privateEnv == null) {
			final env = new PrivateEnvironment();
			env.members = new StringMap<PrivateIdentifierInfo>();
			lexicalEnvironment.privateEnv = env;
		}
		return lexicalEnvironment.privateEnv;
	}

	function addPendingExpressions(...exprs:Expression):Void {
		if (pendingExpressions == null) {
			pendingExpressions = [];
		}
		for (e in exprs) {
			pendingExpressions.push(e);
		}
	}

	function addPrivateIdentifierPropertyDeclarationToEnvironment(node:Node, name:Node):Void {
		final lex = getClassLexicalEnvironment();
		final env = getPrivateIdentifierEnvironment();
		final isStatic = Ast.HasStaticModifier(node);
		final previousInfo = getPrivateIdentifier(env, name).value;
		final isValid = !isReservedPrivateName(name) && previousInfo == null;

		if (isStatic) {
			var brandCheckIdentifier = lex.classThis;
			if (brandCheckIdentifier == null) {
				brandCheckIdentifier = lex.classConstructor;
			}
			final variableName = createHoistedVariableForPrivateName(name, "");
			final info = new PrivateIdentifierInfo();
			info.kind = PrivateIdentifierKindField;
			info.isStatic = true;
			info.brandCheckIdentifier = brandCheckIdentifier;
			info.variableName = variableName;
			info.isValid = isValid;
			setPrivateIdentifier(env, name, info);
		} else {
			final weakMapName = createHoistedVariableForPrivateName(name, "");
			final info = new PrivateIdentifierInfo();
			info.kind = PrivateIdentifierKindField;
			info.isStatic = false;
			info.brandCheckIdentifier = weakMapName;
			info.isValid = isValid;
			setPrivateIdentifier(env, name, info);
			addPendingExpressions(Factory().NewAssignmentExpression(weakMapName,
				Factory().NewNewExpression(Factory().NewIdentifier("WeakMap"), null /*typeArguments*/, Factory().NewNodeList(null))));
		}
	}

	function addPrivateIdentifierMethodToEnvironment(name:Node, lex:ClassLexicalEnvironment, env:PrivateEnvironment, isStatic:Bool, isValid:Bool):Void {
		final methodName = createHoistedVariableForPrivateName(name, "");
		var brandCheckIdentifier:IdentifierNode = null;
		if (isStatic) {
			brandCheckIdentifier = lex.classThis;
			if (brandCheckIdentifier == null) {
				brandCheckIdentifier = lex.classConstructor;
			}
			Debug.Assert(brandCheckIdentifier != null, "classConstructor should be set in private identifier environment");
		} else {
			brandCheckIdentifier = env.data.weakSetName;
		}
		final info = new PrivateIdentifierInfo();
		info.kind = PrivateIdentifierKindMethod;
		info.methodName = methodName;
		info.brandCheckIdentifier = brandCheckIdentifier;
		info.isStatic = isStatic;
		info.isValid = isValid;
		setPrivateIdentifier(env, name, info);
	}

	function addPrivateIdentifierGetAccessorToEnvironment(name:Node, lex:ClassLexicalEnvironment, env:PrivateEnvironment, isStatic:Bool, isValid:Bool, previousInfo:PrivateIdentifierInfo):Void {
		final getterName = createHoistedVariableForPrivateName(name, "_get");
		var brandCheckIdentifier:IdentifierNode = null;
		if (isStatic) {
			brandCheckIdentifier = lex.classThis;
			if (brandCheckIdentifier == null) {
				brandCheckIdentifier = lex.classConstructor;
			}
			Debug.Assert(brandCheckIdentifier != null, "classConstructor should be set in private identifier environment");
		} else {
			brandCheckIdentifier = env.data.weakSetName;
			Debug.Assert(brandCheckIdentifier != null, "weakSetName should be set in private identifier environment");
		}

		if (previousInfo != null && previousInfo.kind == PrivateIdentifierKindAccessor && previousInfo.isStatic == isStatic
			&& previousInfo.getterName == null) {
			previousInfo.getterName = getterName;
		} else {
			final info = new PrivateIdentifierInfo();
			info.kind = PrivateIdentifierKindAccessor;
			info.getterName = getterName;
			info.brandCheckIdentifier = brandCheckIdentifier;
			info.isStatic = isStatic;
			info.isValid = isValid;
			setPrivateIdentifier(env, name, info);
		}
	}

	function addPrivateIdentifierSetAccessorToEnvironment(name:Node, lex:ClassLexicalEnvironment, env:PrivateEnvironment, isStatic:Bool, isValid:Bool, previousInfo:PrivateIdentifierInfo):Void {
		final setterName = createHoistedVariableForPrivateName(name, "_set");
		var brandCheckIdentifier:IdentifierNode = null;
		if (isStatic) {
			brandCheckIdentifier = lex.classThis;
			if (brandCheckIdentifier == null) {
				brandCheckIdentifier = lex.classConstructor;
			}
			Debug.Assert(brandCheckIdentifier != null, "classConstructor should be set in private identifier environment");
		} else {
			brandCheckIdentifier = env.data.weakSetName;
			Debug.Assert(brandCheckIdentifier != null, "weakSetName should be set in private identifier environment");
		}

		if (previousInfo != null && previousInfo.kind == PrivateIdentifierKindAccessor && previousInfo.isStatic == isStatic
			&& previousInfo.setterName == null) {
			previousInfo.setterName = setterName;
		} else {
			final info = new PrivateIdentifierInfo();
			info.kind = PrivateIdentifierKindAccessor;
			info.setterName = setterName;
			info.brandCheckIdentifier = brandCheckIdentifier;
			info.isStatic = isStatic;
			info.isValid = isValid;
			setPrivateIdentifier(env, name, info);
		}
	}

	function addPrivateIdentifierAutoAccessorToEnvironment(node:Node, name:Node, lex:ClassLexicalEnvironment, env:PrivateEnvironment, isStatic:Bool, isValid:Bool):Void {
		final getterName = createHoistedVariableForPrivateName(name, "_get");
		final setterName = createHoistedVariableForPrivateName(name, "_set");
		var brandCheckIdentifier:IdentifierNode = null;
		if (isStatic) {
			brandCheckIdentifier = lex.classThis;
			if (brandCheckIdentifier == null) {
				brandCheckIdentifier = lex.classConstructor;
			}
			Debug.Assert(brandCheckIdentifier != null, "classConstructor should be set in private identifier environment");
		} else {
			brandCheckIdentifier = env.data.weakSetName;
			Debug.Assert(brandCheckIdentifier != null, "weakSetName should be set in private identifier environment");
		}

		final info = new PrivateIdentifierInfo();
		info.kind = PrivateIdentifierKindAccessor;
		info.getterName = getterName;
		info.setterName = setterName;
		info.brandCheckIdentifier = brandCheckIdentifier;
		info.isStatic = isStatic;
		info.isValid = isValid;
		setPrivateIdentifier(env, name, info);
	}

	function addPrivateIdentifierToEnvironment(node:Node):Void {
		final lex = getClassLexicalEnvironment();
		final env = getPrivateIdentifierEnvironment();
		final name = node.Name();
		final isStatic = Ast.HasStaticModifier(node);
		final previousInfo = getPrivateIdentifier(env, name).value;
		final isValid = !isReservedPrivateName(name) && previousInfo == null;

		if (Ast.IsAutoAccessorPropertyDeclaration(node)) {
			addPrivateIdentifierAutoAccessorToEnvironment(node, name, lex, env, isStatic, isValid);
		} else if (Ast.IsPropertyDeclaration(node)) {
			addPrivateIdentifierPropertyDeclarationToEnvironment(node, name);
		} else if (Ast.IsMethodDeclaration(node)) {
			addPrivateIdentifierMethodToEnvironment(name, lex, env, isStatic, isValid);
		} else if (Ast.IsGetAccessorDeclaration(node)) {
			addPrivateIdentifierGetAccessorToEnvironment(name, lex, env, isStatic, isValid, previousInfo);
		} else if (Ast.IsSetAccessorDeclaration(node)) {
			addPrivateIdentifierSetAccessorToEnvironment(name, lex, env, isStatic, isValid, previousInfo);
		}
	}

	function setPrivateIdentifier(env:PrivateEnvironment, name:Node, info:PrivateIdentifierInfo):Void {
		if (EmitContext().HasAutoGenerateInfo(name)) {
			if (env.generatedIdentifiers == null) {
				env.generatedIdentifiers = new IdentityMap<Node, PrivateIdentifierInfo>();
			}
			env.generatedIdentifiers.set(EmitContext().GetNodeForGeneratedName(name), info);
		} else {
			env.members.set(name.Text(), info);
		}
	}

	function getPrivateIdentifier(env:PrivateEnvironment, name:Node):ValueOk<PrivateIdentifierInfo> {
		if (EmitContext().HasAutoGenerateInfo(name)) {
			// PORT: lookup in a possibly-nil Go map.
			if (env.generatedIdentifiers == null) {
				return new ValueOk<PrivateIdentifierInfo>(null, false);
			}
			final key = EmitContext().GetNodeForGeneratedName(name);
			return new ValueOk<PrivateIdentifierInfo>(env.generatedIdentifiers.get(key), env.generatedIdentifiers.exists(key));
		}
		final text = name.Text();
		return new ValueOk<PrivateIdentifierInfo>(env.members.get(text), env.members.exists(text));
	}

	function createHoistedVariableForClass(nameText:std.String, node:Node, suffix:std.String):IdentifierNode {
		final env = getPrivateIdentifierEnvironment();
		var identifier:IdentifierNode = null;
		if (env.data.className != null) {
			final prefix = "_" + env.data.className.Text() + "_";
			identifier = Factory().NewUniqueNameEx(prefix + nameText,
				new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsReservedInNestedScopes, "", suffix));
		} else {
			identifier = Factory().NewUniqueNameEx("_" + nameText,
				new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsReservedInNestedScopes, "", suffix));
		}
		if (requiresBlockScopedVar()) {
			EmitContext().AddLexicalDeclaration(identifier);
		} else {
			EmitContext().AddVariableDeclaration(identifier);
		}
		return identifier;
	}

	function createHoistedVariableForClassFromNode(name:Node, suffix:std.String):IdentifierNode {
		final env = getPrivateIdentifierEnvironment();
		var prefix = "";
		if (env.data.className != null) {
			prefix = "_" + env.data.className.Text() + "_";
		} else {
			prefix = "_";
		}
		final identifier = Factory().NewGeneratedNameForNodeEx(name,
			new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsReservedInNestedScopes, prefix, suffix));
		if (requiresBlockScopedVar()) {
			EmitContext().AddLexicalDeclaration(identifier);
		} else {
			EmitContext().AddVariableDeclaration(identifier);
		}
		return identifier;
	}

	function createHoistedVariableForPrivateName(name:Node, suffix:std.String):IdentifierNode {
		// If the name is a generated identifier (e.g., auto-accessor backing field),
		// use node-based name generation so the emitter can resolve the name properly.
		if (EmitContext().HasAutoGenerateInfo(name)) {
			return createHoistedVariableForClassFromNode(name, suffix);
		}
		var text = name.Text();
		if (text.length >= 1 && StringTools.fastCodeAt(text, 0) == "#".code) {
			text = text.substring(1); // strip leading '#'
		}
		return createHoistedVariableForClass(text, name, suffix);
	}

	// accessPrivateIdentifier accesses an already defined PrivateIdentifier in the current
	// PrivateIdentifierEnvironment.
	function accessPrivateIdentifier(name:Node):PrivateIdentifierInfo {
		var env = lexicalEnvironment;
		while (env != null) {
			if (env.privateEnv != null) {
				final r = getPrivateIdentifier(env.privateEnv, name);
				if (r.ok) {
					final info = r.value;
					if (info.kind == PrivateIdentifierKindUntransformed) {
						return null;
					}
					return info;
				}
			}
			env = env.previous;
		}
		return null;
	}

	function wrapPrivateIdentifierForDestructuringTarget(node:Node):Node {
		final prop = node.AsPropertyAccessExpression();
		final parameter = Factory().NewGeneratedNameForNode(node);
		final info = accessPrivateIdentifier(prop.Name());
		if (info == null) {
			return Visitor().VisitEachChild(node);
		}
		var receiver = prop.Expression;
		// We cannot copy `this` or `super` into the function because they will be bound
		// differently inside the function.
		final isThisOrSuperProperty = prop.Expression.Kind == KindThisKeyword || prop.Expression.Kind == KindSuperKeyword;
		if (isThisOrSuperProperty || !Transformers.IsSimpleCopiableExpression(prop.Expression)) {
			receiver = Factory().NewTempVariableEx(new AutoGenerateOptions(GeneratedIdentifierFlagsReservedInNestedScopes));
			EmitContext().AddVariableDeclaration(receiver);
			if (pendingExpressions == null) {
				pendingExpressions = [];
			}
			pendingExpressions.push(Factory().NewAssignmentExpression(receiver, Visitor().VisitNode(prop.Expression)));
		}
		final assignExpr = createPrivateIdentifierAssignment(info, receiver, parameter, KindEqualsToken);
		return Factory().NewAssignmentTargetWrapper(parameter, assignExpr);
	}

	function visitAssignmentElement(node:Node):Node {
		// 13.15.5.5 RS: IteratorDestructuringAssignmentEvaluation
		//   AssignmentElement : DestructuringAssignmentTarget Initializer?
		//     ...
		//     4. If |Initializer| is present and _value_ is *undefined*, then
		//        a. If IsAnonymousFunctionDefinition(|Initializer|) and IsIdentifierRef of |DestructuringAssignmentTarget| are both *true*, then
		//           i. Let _v_ be ? NamedEvaluation of |Initializer| with argument _lref_.[[ReferencedName]].
		//     ...

		if (Estransforms.isNamedEvaluationAnd(EmitContext(), node, isAnonymousClassNeedingAssignedName)) {
			node = Estransforms.transformNamedEvaluation(EmitContext(), node, false /*ignoreEmptyStringLiteral*/, "" /*assignedName*/);
		}
		if (Ast.IsAssignmentExpression(node, true /*excludeCompoundAssignment*/)) {
			final left = visitDestructuringAssignmentTarget(node.AsBinaryExpression().Left);
			final right = Visitor().VisitNode(node.AsBinaryExpression().Right);
			return Factory().UpdateBinaryExpression(node.AsBinaryExpression(), null, left, null, node.AsBinaryExpression().OperatorToken, right);
		}
		return visitDestructuringAssignmentTarget(node);
	}

	function visitAssignmentRestElement(node:Node):Node {
		final spread = node.AsSpreadElement();
		if (Ast.IsLeftHandSideExpression(spread.Expression)) {
			final expr = visitDestructuringAssignmentTarget(spread.Expression);
			return Factory().UpdateSpreadElement(spread, expr);
		}
		return Visitor().VisitEachChild(node);
	}

	function visitArrayAssignmentElement(node:Node):Node {
		if (Ast.IsArrayBindingOrAssignmentElement(node)) {
			if (Ast.IsSpreadElement(node)) {
				return visitAssignmentRestElement(node);
			}
			if (node.Kind != KindOmittedExpression) {
				return visitAssignmentElement(node);
			}
		}
		return Visitor().VisitEachChild(node);
	}

	function visitAssignmentProperty(node:Node):Node {
		// AssignmentProperty : PropertyName `:` AssignmentElement
		// AssignmentElement : DestructuringAssignmentTarget Initializer?

		// 13.15.5.6 RS: KeyedDestructuringAssignmentEvaluation
		//   AssignmentElement : DestructuringAssignmentTarget Initializer?
		//     ...
		//     3. If |Initializer| is present and _v_ is *undefined*, then
		//        a. If IsAnonymousfunctionDefinition(|Initializer|) and IsIdentifierRef of |DestructuringAssignmentTarget| are both *true*, then
		//           i. Let _rhsValue_ be ? NamedEvaluation of |Initializer| with argument _lref_.[[ReferencedName]].
		//     ...

		final prop = node.AsPropertyAssignment();
		final name = Visitor().VisitNode(prop.Name());
		final init = prop.Initializer;
		if (Ast.IsAssignmentExpression(init, true /*excludeCompoundAssignment*/)) {
			final assignElem = visitAssignmentElement(init);
			return Factory().UpdatePropertyAssignment(prop, null, name, null, null, assignElem);
		}
		if (Ast.IsLeftHandSideExpression(init)) {
			final target = visitDestructuringAssignmentTarget(init);
			return Factory().UpdatePropertyAssignment(prop, null, name, null, null, target);
		}
		return Visitor().VisitEachChild(node);
	}

	function visitShorthandAssignmentProperty(node:Node):Node {
		// AssignmentProperty : IdentifierReference Initializer?

		// 13.15.5.3 RS: PropertyDestructuringAssignmentEvaluation
		//   AssignmentProperty : IdentifierReference Initializer?
		//     ...
		//     4. If |Initializer?| is present and _v_ is *undefined*, then
		//        a. If IsAnonymousFunctionDefinition(|Initializer|) is *true*, then
		//           i. Set _v_ to ? NamedEvaluation of |Initializer| with argument _P_.
		//     ...

		if (Estransforms.isNamedEvaluationAnd(EmitContext(), node, isAnonymousClassNeedingAssignedName)) {
			node = Estransforms.transformNamedEvaluation(EmitContext(), node, false /*ignoreEmptyStringLiteral*/, "" /*assignedName*/);
		}
		return Visitor().VisitEachChild(node);
	}

	function visitAssignmentRestProperty(node:Node):Node {
		final spread = node.AsSpreadAssignment();
		if (Ast.IsLeftHandSideExpression(spread.Expression)) {
			final expr = visitDestructuringAssignmentTarget(spread.Expression);
			return Factory().UpdateSpreadAssignment(spread, expr);
		}
		return Visitor().VisitEachChild(node);
	}

	function visitObjectAssignmentElement(node:Node):Node {
		Debug.Assert(node != null && Ast.IsObjectBindingOrAssignmentElement(node));
		if (Ast.IsSpreadAssignment(node)) {
			return visitAssignmentRestProperty(node);
		}
		if (Ast.IsShorthandPropertyAssignment(node)) {
			return visitShorthandAssignmentProperty(node);
		}
		if (Ast.IsPropertyAssignment(node)) {
			return visitAssignmentProperty(node);
		}
		return Visitor().VisitEachChild(node);
	}

	function visitAssignmentPattern(node:Node):Node {
		if (Ast.IsArrayLiteralExpression(node)) {
			// Transforms private names in destructuring assignment array bindings.
			// Transforms SuperProperty assignments in destructuring assignment array bindings in static initializers.
			//
			// Source:
			// ([ this.#myProp ] = [ "hello" ]);
			//
			// Transformation:
			// [ { set value(x) { this.#myProp = x; } }.value ] = [ "hello" ];
			return Factory().UpdateArrayLiteralExpression(node.AsArrayLiteralExpression(),
				arrayAssignmentElementVisitor.VisitNodes(node.AsArrayLiteralExpression().Elements), node.AsArrayLiteralExpression().MultiLine);
		}
		// Transforms private names in destructuring assignment object bindings.
		// Transforms SuperProperty assignments in destructuring assignment object bindings in static initializers.
		//
		// Source:
		// ({ stringProperty: this.#myProp } = { stringProperty: "hello" });
		//
		// Transformation:
		// ({ stringProperty: { set value(x) { this.#myProp = x; } }.value }) = { stringProperty: "hello" };
		return Factory().UpdateObjectLiteralExpression(node.AsObjectLiteralExpression(),
			objectAssignmentElementVisitor.VisitNodes(node.AsObjectLiteralExpression().Properties), node.AsObjectLiteralExpression().MultiLine);
	}

	function isReservedPrivateName(node:Node):Bool {
		return !(Ast.IsPrivateIdentifier(node) && EmitContext().HasAutoGenerateInfo(node)) && node.Text() == "#constructor";
	}

	function getProperties(node:Node, requireInitializer:Bool, isStatic:Bool):Array<Node> {
		var result:Array<Node> = null;
		for (member in (node.Members() ?? [])) { // PORT: range over a possibly-nil slice
			if (Ast.IsPropertyDeclaration(member) && (!requireInitializer || member.Initializer() != null) && Ast.HasStaticModifier(member) == isStatic) {
				if (result == null) {
					result = [];
				}
				result.push(member);
			}
		}
		return result;
	}

	function getStaticPropertiesAndClassStaticBlock(node:Node):Array<Node> {
		var result:Array<Node> = null;
		for (member in (node.Members() ?? [])) { // PORT: range over a possibly-nil slice
			if (Ast.IsClassStaticBlockDeclaration(member) || (Ast.IsPropertyDeclaration(member) && Ast.HasStaticModifier(member))) {
				if (result == null) {
					result = [];
				}
				result.push(member);
			}
		}
		return result;
	}

	function createCallBinding(node:Node):Pair<Expression, Expression> {
		var thisArg:Expression = null;
		var target:Expression = null;
		if (Ast.IsSuperProperty(node)) {
			return new Pair<Expression, Expression>(Factory().NewThisExpression(), node);
		}
		if (Ast.IsPropertyAccessExpression(node)) {
			final expr = node.AsPropertyAccessExpression();
			if (Estransforms.shouldBeCapturedInTempVariable(expr.Expression)) {
				thisArg = Factory().NewTempVariable();
				EmitContext().AddVariableDeclaration(thisArg);
				target = Factory().NewPropertyAccessExpression(Factory().NewParenthesizedExpression( // TODO: do we even need these?
					Factory().NewAssignmentExpression(thisArg, expr.Expression)), null, expr.Name(), NodeFlagsNone);
				return new Pair<Expression, Expression>(thisArg, target);
			}
			return new Pair<Expression, Expression>(expr.Expression, node);
		}
		thisArg = Factory().NewVoidZeroExpression();
		target = node;
		return new Pair<Expression, Expression>(thisArg, target);
	}

	function createAccessorPropertyGetRedirector(node:PropertyDeclaration, modifiers:ModifierList, name:PropertyName, receiver:Expression):Node {
		final backingFieldName = Factory().NewGeneratedPrivateNameForNodeEx(node.Name(), new AutoGenerateOptions(GeneratedIdentifierFlagsNone, "", "_accessor_storage"));
		final returnExpr = Factory().NewPropertyAccessExpression(receiver, null, backingFieldName, NodeFlagsNone);
		final returnStmt = Factory().NewReturnStatement(returnExpr);
		final body = Factory().NewBlock(Factory().NewNodeList([returnStmt]), false);
		return Factory().NewGetAccessorDeclaration(modifiers, name, null /*typeParameters*/, Factory().NewNodeList([]), null /*returnType*/,
			null /*fullSignature*/, body);
	}

	function createAccessorPropertySetRedirector(node:PropertyDeclaration, modifiers:ModifierList, name:PropertyName, receiver:Expression):Node {
		final backingFieldName = Factory().NewGeneratedPrivateNameForNodeEx(node.Name(), new AutoGenerateOptions(GeneratedIdentifierFlagsNone, "", "_accessor_storage"));
		final valueParam = Factory().NewParameterDeclaration(null /*modifiers*/, null /*dotDotDotToken*/, Factory().NewIdentifier("value"), null /*questionToken*/,
			null /*typeNode*/, null /*initializer*/);
		final assignExpr = Factory().NewAssignmentExpression(Factory().NewPropertyAccessExpression(receiver, null, backingFieldName, NodeFlagsNone),
			Factory().NewIdentifier("value"));
		final exprStmt = Factory().NewExpressionStatement(assignExpr);
		final body = Factory().NewBlock(Factory().NewNodeList([exprStmt]), false);
		return Factory().NewSetAccessorDeclaration(modifiers, name, null /*typeParameters*/, Factory().NewNodeList([valueParam]), null /*returnType*/,
			null /*fullSignature*/, body);
	}
}

