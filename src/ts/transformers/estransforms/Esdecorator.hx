package ts.transformers.estransforms;

import ts.printer.Generatedidentifierflags.GeneratedIdentifierFlags;
import ts.printer.Generatedidentifierflags.GeneratedIdentifierFlags.*;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/estransforms/esdecorator.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// lexicalEntryKind discriminates the kind of lexical scope entry.
enum abstract LexicalEntryKind(Int) from Int to Int {
	var lexicalEntryKindClass = 0;
	var lexicalEntryKindClassElement = 1;
	var lexicalEntryKindName = 2;
	var lexicalEntryKindOther = 3;
}

// lexicalEntry represents a single entry in the lexical scope stack used to track
// nested class declarations and their state during transformation.
@:allow(ts.transformers.estransforms)
class LexicalEntry {
	var kind:LexicalEntryKind = 0;
	var next:LexicalEntry = null;
	var classInfoData:ClassInfo = null;
	var savedPendingExpressions:Array<Expression> = null;
	var classThisData:IdentifierNode = null;
	var classSuperData:IdentifierNode = null;
	var depth:Int = 0;

	public function new() {}
}

// memberInfo stores decoration-related data for a single class element.
@:allow(ts.transformers.estransforms)
class MemberInfo {
	var memberDecoratorsName:IdentifierNode = null; // used in class definition step 4.a
	var memberInitializersName:IdentifierNode = null; // used in class definition step 12 and constructor evaluation step 2.a
	var memberExtraInitializersName:IdentifierNode = null; // used in class definition step 12 and constructor evaluation step 2.b
	var memberDescriptorName:IdentifierNode = null;

	public function new() {}
}

// classInfo stores all transformation data for a single decorated class.
@:allow(ts.transformers.estransforms)
class ClassInfo {
	var class_:Node = null;
	var classDecoratorsName:IdentifierNode = null; // used in class definition step 2
	var classDescriptorName:IdentifierNode = null; // used in class definition step 10
	var classExtraInitializersName:IdentifierNode = null; // used in class definition step 13
	var classThis:IdentifierNode = null; // `_classThis`, if needed.
	var classSuper:IdentifierNode = null; // `_classSuper`, if needed.
	var metadataReference:IdentifierNode = null;
	var memberInfos:OrderedMap<Node, MemberInfo> = new OrderedMap<Node, MemberInfo>(null); // used in class definition step 4.a, 12, and constructor evaluation
	var instanceMethodExtraInitializersName:IdentifierNode = null; // used in constructor evaluation step 1
	var staticMethodExtraInitializersName:IdentifierNode = null; // used in class definition step 11
	var staticNonFieldDecorationStatements:Array<Statement> = null;
	var nonStaticNonFieldDecorationStatements:Array<Statement> = null;
	var staticFieldDecorationStatements:Array<Statement> = null;
	var nonStaticFieldDecorationStatements:Array<Statement> = null;
	var hasStaticInitializers:Bool = false;
	var hasNonAmbientInstanceFields:Bool = false;
	var hasStaticPrivateClassElements:Bool = false;
	var pendingStaticInitializers:Array<Expression> = null;
	var pendingInstanceInitializers:Array<Expression> = null;

	public function new() {}
}

@:allow(ts.transformers.estransforms)
class EsDecoratorTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var compilerOptions:CompilerOptions = null;
	var top:LexicalEntry = null;
	var classInfoStack:ClassInfo = null;
	var classThis:IdentifierNode = null;
	var classSuper:IdentifierNode = null;
	var pendingExpressions:Array<Expression> = null;
	var outerThis:IdentifierNode = null;
	var shouldTransformPrivateStaticElementsInFile:Bool = false;
	var outerThisVisitor:NodeVisitor = null;
	var discardedVisitor:NodeVisitor = null;
	var modifierVisitor:NodeVisitor = null;
	var exportStrippingModifierVisitor:NodeVisitor = null;
	var classElementVisitor:NodeVisitor = null;
	var nonConstructorClassElementVisitor:NodeVisitor = null;
	var constructorClassElementVisitor:NodeVisitor = null;
	var arrayAssignmentVisitor:NodeVisitor = null;
	var objectAssignmentVisitor:NodeVisitor = null;
	var staticOnlyModifierVisitor:NodeVisitor = null;
	var asyncOnlyModifierVisitor:NodeVisitor = null;
	var accessorStrippingModifierVisitor:NodeVisitor = null;

	// PORT: cached method values (Go passes tx.createXDescriptorObject per class element; PORTING §7a).
	var createMethodDescriptorObjectFunc:CreateDescriptorFunc = null;
	var createGetAccessorDescriptorObjectFunc:CreateDescriptorFunc = null;
	var createSetAccessorDescriptorObjectFunc:CreateDescriptorFunc = null;
	var createAccessorPropertyDescriptorObjectFunc:CreateDescriptorFunc = null;

	public function new() {}

	// PORT: Go ranges over a nil slice as empty; Haxe `for` crashes on null.
	static inline function nilSlice<T>(s:Null<Array<T>>):Array<T> {
		return s == null ? [] : s;
	}

	// PORT: promoted methods of the embedded transformers.Transformer.
	inline function Visitor():NodeVisitor return Transformer.Visitor();
	inline function Factory():ts.printer.Factory.NodeFactory return Transformer.Factory();
	inline function EmitContext():EmitContext return Transformer.EmitContext();

	function updateState():Void {
		classInfoStack = null;
		classThis = null;
		classSuper = null;
		if (top == null) {
			return;
		}
		switch (top.kind) {
			case lexicalEntryKindClass:
				classInfoStack = top.classInfoData;
			case lexicalEntryKindClassElement:
				classInfoStack = top.next.classInfoData;
				classThis = top.classThisData;
				classSuper = top.classSuperData;
			case lexicalEntryKindName:
				final grandparent = top.next.next.next;
				if (grandparent != null && grandparent.kind == lexicalEntryKindClassElement) {
					classInfoStack = grandparent.next.classInfoData;
					classThis = grandparent.classThisData;
					classSuper = grandparent.classSuperData;
				}
			default:
		}
	}

	function enterClass(ci:ClassInfo):Void {
		final entry = new LexicalEntry();
		entry.kind = lexicalEntryKindClass;
		entry.next = top;
		entry.classInfoData = ci;
		entry.savedPendingExpressions = pendingExpressions;
		top = entry;
		pendingExpressions = null;
		updateState();
	}

	function exitClass():Void {
		Debug.Assert(top != null && top.kind == lexicalEntryKindClass, "Incorrect value for top.kind. Expected top.kind to be 'class' but got '", top.kind,
			"' instead.");
		pendingExpressions = top.savedPendingExpressions;
		top = top.next;
		updateState();
	}

	function enterClassElement(node:Node):Void {
		Debug.Assert(top != null && top.kind == lexicalEntryKindClass, "Incorrect value for top.kind. Expected top.kind to be 'class' but got '", top.kind,
			"' instead.");
		final entry = new LexicalEntry();
		entry.kind = lexicalEntryKindClassElement;
		entry.next = top;
		top = entry;
		if (Ast.IsClassStaticBlockDeclaration(node) || Ast.IsPropertyDeclaration(node) && Ast.HasStaticModifier(node)) {
			if (top.next.classInfoData != null) {
				top.classThisData = top.next.classInfoData.classThis;
				top.classSuperData = top.next.classInfoData.classSuper;
			}
		}
		updateState();
	}

	function exitClassElement():Void {
		Debug.Assert(top != null && top.kind == lexicalEntryKindClassElement,
			"Incorrect value for top.kind. Expected top.kind to be 'class-element' but got '", top.kind, "' instead.");
		Debug.Assert(top.next != null && top.next.kind == lexicalEntryKindClass,
			"Incorrect value for top.next.kind. Expected top.next.kind to be 'class' but got '", top.next.kind, "' instead.");
		top = top.next;
		updateState();
	}

	function enterName():Void {
		Debug.Assert(top != null && top.kind == lexicalEntryKindClassElement,
			"Incorrect value for top.kind. Expected top.kind to be 'class-element' but got '", top.kind, "' instead.");
		final entry = new LexicalEntry();
		entry.kind = lexicalEntryKindName;
		entry.next = top;
		top = entry;
		updateState();
	}

	function exitName():Void {
		Debug.Assert(top != null && top.kind == lexicalEntryKindName, "Incorrect value for top.kind. Expected top.kind to be 'name' but got '", top.kind,
			"' instead.");
		top = top.next;
		updateState();
	}

	function enterOther():Void {
		if (top != null && top.kind == lexicalEntryKindOther) {
			Debug.Assert(Core.len(pendingExpressions) == 0);
			top.depth++;
		} else {
			final entry = new LexicalEntry();
			entry.kind = lexicalEntryKindOther;
			entry.next = top;
			entry.savedPendingExpressions = pendingExpressions;
			top = entry;
			pendingExpressions = null;
			updateState();
		}
	}

	function exitOther():Void {
		Debug.Assert(top != null && top.kind == lexicalEntryKindOther, "Incorrect value for top.kind. Expected top.kind to be 'other' but got '", top.kind,
			"' instead.");
		if (top.depth > 0) {
			Debug.Assert(Core.len(pendingExpressions) == 0);
			top.depth--;
		} else {
			pendingExpressions = top.savedPendingExpressions;
			top = top.next;
			updateState();
		}
	}

	function visitSourceFile(node:SourceFile):Node {
		top = null;
		shouldTransformPrivateStaticElementsInFile = false;
		final visited = Visitor().VisitEachChild(node.AsNode());
		EmitContext().AddEmitHelper(visited, ...EmitContext().ReadEmitHelpers());
		if (shouldTransformPrivateStaticElementsInFile) {
			EmitContext().AddEmitFlags(visited, EFTransformPrivateStaticElements);
			shouldTransformPrivateStaticElementsInFile = false;
		}
		return visited;
	}

	function outerThisVisit(n:Node):Node {
		if ((n.SubtreeFacts() & SubtreeContainsLexicalThis) == 0 && n.Kind != KindThisKeyword) {
			return n;
		}
		if (n.Kind == KindThisKeyword) {
			if (outerThis == null) {
				outerThis = Factory().NewUniqueNameEx("_outerThis", new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic));
			}
			return outerThis;
		}
		return outerThisVisitor.VisitEachChild(n);
	}

	function shouldVisitNode(node:Node):Bool {
		return (node.SubtreeFacts() & SubtreeContainsDecorators) != 0
			|| (classThis != null && (node.SubtreeFacts() & SubtreeContainsLexicalThis) != 0)
			|| (classThis != null && classSuper != null && (node.SubtreeFacts() & SubtreeContainsLexicalSuper) != 0);
	}

	function visit(node:Node):Node {
		if (node.Kind == KindSourceFile) {
			return visitSourceFile(node.AsSourceFile());
		}
		if (!shouldVisitNode(node)) {
			return node;
		}
		switch (node.Kind) {
			case KindDecorator:
				// Decorators are elided. In Strada, a separate `modifierVisitor` drops decorators
				// before they reach `visitor` via visitEachChild. Here, `visit` serves as both
				// visitors, so decorators from modifier lists reach it directly.
				return null;
			case KindClassDeclaration:
				return visitClassDeclaration(node.AsClassDeclaration());
			case KindClassExpression:
				return visitClassExpression(node.AsClassExpression());
			case KindConstructor, KindPropertyDeclaration, KindClassStaticBlockDeclaration:
				Debug.Fail("Not supported outside of a class. Use 'classElementVisitor' instead.");
				return null;
			case KindParameter:
				return visitParameterDeclaration(node.AsParameterDeclaration());
			// Support NamedEvaluation to ensure the correct class name for class expressions.
			case KindBinaryExpression:
				return visitBinaryExpression(node, false /*discarded*/);
			case KindPropertyAssignment, KindVariableDeclaration, KindBindingElement:
				return visitNamedEvaluationSite(node, node.Initializer());
			case KindExportAssignment:
				return visitExportAssignment(node);
			case KindThisKeyword:
				return visitThisExpression(node);
			case KindForStatement:
				return visitForStatement(node);
			case KindExpressionStatement:
				return visitExpressionStatement(node);
			case KindParenthesizedExpression:
				return visitParenthesizedExpression(node, false /*discarded*/);
			case KindPartiallyEmittedExpression:
				return visitPartiallyEmittedExpression(node, false /*discarded*/);
			case KindCallExpression:
				return visitCallExpression(node);
			case KindTaggedTemplateExpression:
				return visitTaggedTemplateExpression(node);
			case KindPrefixUnaryExpression, KindPostfixUnaryExpression:
				return visitPreOrPostfixUnaryExpression(node, false /*discarded*/);
			case KindPropertyAccessExpression:
				return visitPropertyAccessExpression(node);
			case KindElementAccessExpression:
				return visitElementAccessExpression(node);
			case KindComputedPropertyName:
				return visitComputedPropertyName(node);
			case KindMethodDeclaration, KindSetAccessor, KindGetAccessor, KindFunctionExpression, KindFunctionDeclaration:
				enterOther();
				final result = Visitor().VisitEachChild(node);
				exitOther();
				return result;
			default:
				return Visitor().VisitEachChild(node);
		}
	}

	function modifierVisitorVisit(node:Node):Node {
		if (node.Kind == KindDecorator) {
			return null;
		}
		return node;
	}

	function classElementVisitorVisit(node:Node):Node {
		switch (node.Kind) {
			case KindConstructor:
				return visitConstructorDeclaration(node);
			case KindMethodDeclaration:
				return visitMethodDeclaration(node);
			case KindGetAccessor:
				return visitGetAccessorDeclaration(node);
			case KindSetAccessor:
				return visitSetAccessorDeclaration(node);
			case KindPropertyDeclaration:
				return visitPropertyDeclaration(node);
			case KindClassStaticBlockDeclaration:
				return visitClassStaticBlockDeclaration(node);
			default:
				return visit(node);
		}
	}

	function discardedValueVisit(node:Node):Node {
		switch (node.Kind) {
			case KindPrefixUnaryExpression, KindPostfixUnaryExpression:
				return visitPreOrPostfixUnaryExpression(node, true /*discarded*/);
			case KindBinaryExpression:
				return visitBinaryExpression(node, true /*discarded*/);
			case KindParenthesizedExpression:
				return visitParenthesizedExpression(node, true /*discarded*/);
			case KindPartiallyEmittedExpression:
				return visitPartiallyEmittedExpression(node, true /*discarded*/);
			default:
				return visit(node);
		}
	}

	function nonConstructorClassElementVisit(node:Node):Node {
		if (Ast.IsConstructorDeclaration(node)) {
			return node; // skip constructors in pass 1
		}
		return classElementVisitorVisit(node);
	}

	function constructorClassElementVisit(node:Node):Node {
		if (Ast.IsConstructorDeclaration(node)) {
			return classElementVisitorVisit(node);
		}
		return node;
	}

	function exportStrippingModifierVisit(node:Node):Node {
		if (node.Kind == KindExportKeyword) {
			return null;
		}
		return modifierVisitorVisit(node);
	}

	function createHelperVariable(node:Node, suffix:std.String):IdentifierNode {
		return Factory().NewUniqueNameEx(Estransforms.getHelperVariableName(EmitContext(), node) + "_" + suffix,
			new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsReservedInNestedScopes));
	}

	function createLet(name:IdentifierNode, initializer:Expression):Statement {
		return Factory().NewVariableStatement(null,
			Factory().NewVariableDeclarationList(Factory().NewNodeList([Factory().NewVariableDeclaration(name, null, null, initializer),]), NodeFlagsLet));
	}

	function createClassInfo(node:Node):ClassInfo {
		final f = Factory();
		final ci = new ClassInfo();
		ci.class_ = node;
		ci.metadataReference = f.NewUniqueNameEx("_metadata", new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel));

		// Before visiting we perform a first pass to collect information we'll need
		// as we descend.

		// If the class itself is decorated, create a _classThis binding
		if (Ast.NodeIsDecorated(false, node, null, null)) {
			final needsUniqueClassThis = Core.Some(node.Members(), function(member:Node):Bool {
				return (Ast.IsPrivateIdentifierClassElementDeclaration(member) || Ast.IsAutoAccessorPropertyDeclaration(member))
					&& Ast.HasStaticModifier(member);
			});
			// We do not mark _classThis as FileLevel if it may be reused by class private fields, which requires the
			// ability access the captured `_classThis` of outer scopes.
			var flags:GeneratedIdentifierFlags = GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel;
			if (needsUniqueClassThis) {
				flags = GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsReservedInNestedScopes;
			}
			ci.classThis = f.NewUniqueNameEx("_classThis", new AutoGenerateOptions(flags));
		}

		for (member in nilSlice(node.Members())) {
			if (Ast.IsMethodOrAccessor(member) && Ast.NodeOrChildIsDecorated(false, member, node, null)) {
				if (Ast.HasStaticModifier(member)) {
					if (ci.staticMethodExtraInitializersName == null) {
						ci.staticMethodExtraInitializersName = f.NewUniqueNameEx("_staticExtraInitializers",
							new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel));
						var renamedClassThis:Node = null;
						if (ci.classThis != null) {
							renamedClassThis = ci.classThis;
						} else {
							renamedClassThis = f.NewThisExpression();
						}
						final initializer = f.NewRunInitializersHelper(renamedClassThis, ci.staticMethodExtraInitializersName, null);
						final nameRange = node.Name();
						if (nameRange != null) {
							EmitContext().SetSourceMapRange(initializer, nameRange.Loc);
						} else {
							EmitContext().SetSourceMapRange(initializer, Transformers.MoveRangePastDecorators(node));
						}
						if (ci.pendingStaticInitializers == null)
							ci.pendingStaticInitializers = [];
						ci.pendingStaticInitializers.push(initializer);
					}
				} else {
					if (ci.instanceMethodExtraInitializersName == null) {
						ci.instanceMethodExtraInitializersName = f.NewUniqueNameEx("_instanceExtraInitializers",
							new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel));
						final initializer = f.NewRunInitializersHelper(f.NewThisExpression(), ci.instanceMethodExtraInitializersName, null);
						final nameRange = node.Name();
						if (nameRange != null) {
							EmitContext().SetSourceMapRange(initializer, nameRange.Loc);
						} else {
							EmitContext().SetSourceMapRange(initializer, Transformers.MoveRangePastDecorators(node));
						}
						if (ci.pendingInstanceInitializers == null)
							ci.pendingInstanceInitializers = [];
						ci.pendingInstanceInitializers.push(initializer);
					}
				}
			}

			if (Ast.IsClassStaticBlockDeclaration(member)) {
				if (!Estransforms.isClassNamedEvaluationHelperBlock(EmitContext(), member)) {
					ci.hasStaticInitializers = true;
				}
			} else if (Ast.IsPropertyDeclaration(member)) {
				if (Ast.HasStaticModifier(member)) {
					ci.hasStaticInitializers = ci.hasStaticInitializers || member.Initializer() != null || Ast.HasDecorators(member);
				} else {
					ci.hasNonAmbientInstanceFields = ci.hasNonAmbientInstanceFields || !Ast.HasSyntacticModifier(member, ModifierFlagsAmbient);
				}
			}

			if ((Ast.IsPrivateIdentifierClassElementDeclaration(member) || Ast.IsAutoAccessorPropertyDeclaration(member))
				&& Ast.HasStaticModifier(member)) {
				ci.hasStaticPrivateClassElements = true;
			}

			// exit early if possible
			if (ci.staticMethodExtraInitializersName != null
				&& ci.instanceMethodExtraInitializersName != null
				&& ci.hasStaticInitializers
				&& ci.hasNonAmbientInstanceFields
				&& ci.hasStaticPrivateClassElements) {
				break;
			}
		}

		return ci;
	}

	function transformClassLike(node:Node):Expression {
		final f = Factory();
		final ec = EmitContext();

		ec.StartVariableEnvironment();

		// When a class has class decorators we end up transforming it into a statement that would otherwise give it an
		// assigned name. If the class doesn't have an assigned name, we'll give it an assigned name of `""`.
		if (!Estransforms.classHasDeclaredOrExplicitlyAssignedName(ec, node) && Ast.ClassOrConstructorParameterIsDecorated(false, node)) {
			node = Estransforms.injectClassNamedEvaluationHelperBlockIfMissing(ec, node, f.NewStringLiteral("", 0), null);
		}

		final classReference = f.GetLocalNameEx(node, new AssignedNameOptions());
		final ci = createClassInfo(node);
		var classDefinitionStatements:Array<Statement> = [];
		var leadingBlockStatements:Array<Statement> = []; // PORT: nil slice → empty array (only len/append/spread used)
		var trailingBlockStatements:Array<Statement> = []; // PORT: nil slice → empty array (only len/append/spread used)
		var syntheticConstructor:Node = null;
		var heritageClauses:NodeList = null;
		var shouldTransformPrivateStaticElementsInClass = false;

		// 1. Class decorators are evaluated outside the private name scope of the class.
		//
		// - Since class decorators don't have privileged access to private names defined inside the class,
		//   they must be evaluated outside of the class body.
		// - Since a class decorator can replace the class constructor, we must define a variable to keep track
		//   of the mutated class.
		// - Since a class decorator can add extra initializers, we must define a variable to keep track of
		//   extra initializers.
		final classDecorators = transformAllDecoratorsOfDeclaration(node.Decorators());
		if (Core.len(classDecorators) > 0) {
			Debug.Assert(ci.classThis != null);

			ci.classDecoratorsName = f.NewUniqueNameEx("_classDecorators",
				new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel));
			ci.classDescriptorName = f.NewUniqueNameEx("_classDescriptor",
				new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel));
			ci.classExtraInitializersName = f.NewUniqueNameEx("_classExtraInitializers",
				new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel));

			final decoratorsArray = f.NewArrayLiteralExpression(f.NewNodeList(classDecorators), false);
			classDefinitionStatements.push(createLet(ci.classDecoratorsName, decoratorsArray));
			classDefinitionStatements.push(createLet(ci.classDescriptorName, null));
			classDefinitionStatements.push(createLet(ci.classExtraInitializersName, f.NewArrayLiteralExpression(f.NewNodeList(null), false)));
			classDefinitionStatements.push(createLet(ci.classThis, null));

			if (Core.len(classDecorators) > 0 && ci.hasStaticPrivateClassElements) {
				shouldTransformPrivateStaticElementsInClass = true;
				shouldTransformPrivateStaticElementsInFile = true;
			}
		}

		// 2. ClassHeritage clause is evaluated outside of the private name scope of the class.
		final extendsClause = Ast.GetHeritageClause(node, KindExtendsKeyword);
		var extendsElement:Node = null;
		if (extendsClause != null) {
			final hc = extendsClause.AsHeritageClause();
			if (hc.Types != null && hc.Types.Nodes.length > 0) {
				extendsElement = hc.Types.Nodes[0];
			}
		}
		var extendsExpression:Expression = null;
		if (extendsElement != null) {
			extendsExpression = Visitor().VisitNode(extendsElement.AsExpressionWithTypeArguments().Expression);
		}

		if (extendsExpression != null) {
			// Rewrite `super` in static initializers so that we can use the correct `this`.
			ci.classSuper = f.NewUniqueNameEx("_classSuper", new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel));

			// Ensure we do not give the class or function an assigned name due to the variable by prefixing it
			// with `0, `.
			final unwrapped = Ast.SkipOuterExpressions(extendsExpression, OEKAll);
			var safeExtendsExpression = extendsExpression;
			if ((Ast.IsClassExpression(unwrapped) && unwrapped.Name() == null)
				|| (Ast.IsFunctionExpression(unwrapped) && unwrapped.Name() == null)
				|| Ast.IsArrowFunction(unwrapped)) {
				safeExtendsExpression = f.NewCommaExpression(f.NewNumericLiteral("0", 0), extendsExpression);
			}
			classDefinitionStatements.push(createLet(ci.classSuper, safeExtendsExpression));

			final updatedExtendsElement = f.UpdateExpressionWithTypeArguments(extendsElement.AsExpressionWithTypeArguments(), ci.classSuper, null);
			final hc = extendsClause.AsHeritageClause();
			final updatedExtendsClause = f.UpdateHeritageClause(hc, hc.Token, f.NewNodeList([updatedExtendsElement]));
			heritageClauses = f.NewNodeList([updatedExtendsClause]);
		}

		var renamedClassThis:Node = null;
		if (ci.classThis != null) {
			renamedClassThis = ci.classThis;
		} else {
			renamedClassThis = f.NewThisExpression();
		}

		// 3. The name of the class is assigned.
		//
		// If the class did not have a name, the caller should have performed injectClassNamedEvaluationHelperBlockIfMissing
		// prior to calling this function if a name was needed.

		// 4. For each member:
		//    a. Member Decorators are evaluated
		//    b. Computed Property Name is evaluated, if present
		//
		// We visit members in two passes:
		// - The first pass visits methods, accessors, and fields to collect decorators and computed property names.
		// - The second pass visits the constructor to add instance initializers.
		//
		// NOTE: If there are no constructors, but there are instance initializers, a synthetic constructor is added.
		enterClass(ci);

		leadingBlockStatements.push(createMetadata(ci.metadataReference, ci.classSuper));

		// Since the constructor can appear anywhere in the class body and its transform depends on other class elements,
		// we must first visit all non-constructor members, then visit the constructor, all while maintaining document order.
		var members = nonConstructorClassElementVisitor.VisitNodes(node.MemberList());
		members = constructorClassElementVisitor.VisitNodes(members);

		// Handle pending expressions (computed property names and decorator evaluations)
		if (Core.len(pendingExpressions) > 0) {
			// If a pending expression contains a lexical `this`, we'll need to capture the lexical `this` of the
			// container and transform it in the expression. This ensures we use the correct `this` in the resulting
			// class `static` block. We don't use substitution here because the size of the tree we are visiting
			// is likely to be small and doesn't justify the complexity of introducing substitution.
			outerThis = null;
			for (expr0 in pendingExpressions) {
				var expr = expr0;
				// If a pending expression contains lexical `this`, capture it
				if ((expr.SubtreeFacts() & SubtreeContainsLexicalThis) != 0) {
					expr = outerThisVisitor.VisitNode(expr);
				}
				final statement = f.NewExpressionStatement(expr);
				leadingBlockStatements.push(statement);
			}
			if (outerThis != null) {
				classDefinitionStatements = [createLet(outerThis, f.NewThisExpression())].concat(classDefinitionStatements);
			}
			pendingExpressions = null;
		}
		exitClass();

		// If there are instance initializers but no constructor, synthesize one
		if (Core.len(ci.pendingInstanceInitializers) > 0 && Ast.GetFirstConstructorWithBody(node) == null) {
			final initializerStatements = prepareConstructor(ci);
			if (Core.len(initializerStatements) > 0) {
				final isDerivedClass = extendsElement != null
					&& Ast.SkipOuterExpressions(extendsElement.AsExpressionWithTypeArguments().Expression, OEKAll).Kind != KindNullKeyword;
				final constructorStatements:Array<Statement> = [];
				if (isDerivedClass) {
					final spreadArguments = f.NewSpreadElement(f.NewIdentifier("arguments"));
					final superCall = f.NewCallExpression(f.NewKeywordExpression(KindSuperKeyword), null, null, f.NewNodeList([spreadArguments]), NodeFlagsNone);
					constructorStatements.push(f.NewExpressionStatement(superCall));
				}
				for (s in initializerStatements)
					constructorStatements.push(s);
				final constructorBody = f.NewBlock(f.NewNodeList(constructorStatements), true);
				syntheticConstructor = f.NewConstructorDeclaration(null, null, f.NewNodeList(null), null, null, constructorBody);
			}
		}

		// Used in class definition steps 5,7,11
		if (ci.staticMethodExtraInitializersName != null) {
			classDefinitionStatements.push(createLet(ci.staticMethodExtraInitializersName, f.NewArrayLiteralExpression(f.NewNodeList(null), false)));
		}

		// Used in class definition steps 6,8, and construction
		if (ci.instanceMethodExtraInitializersName != null) {
			classDefinitionStatements.push(createLet(ci.instanceMethodExtraInitializersName, f.NewArrayLiteralExpression(f.NewNodeList(null), false)));
		}

		// Used in class definition steps 7, 8, 12, and construction.
		// Emit member info variable declarations; the reference implementation emits static member vars first, then non-static.
		if (ci.memberInfos.Size() > 0) {
			for (s in emitMemberInfoDeclarations(ci, true /*isStatic*/))
				classDefinitionStatements.push(s);
			for (s in emitMemberInfoDeclarations(ci, false /*isStatic*/))
				classDefinitionStatements.push(s);
		}

		// 5. Static non-field element decorators are applied
		if (ci.staticNonFieldDecorationStatements != null)
			for (s in ci.staticNonFieldDecorationStatements)
				leadingBlockStatements.push(s);

		// 6. Non-static non-field element decorators are applied
		if (ci.nonStaticNonFieldDecorationStatements != null)
			for (s in ci.nonStaticNonFieldDecorationStatements)
				leadingBlockStatements.push(s);

		// 7. Static field element decorators are applied
		if (ci.staticFieldDecorationStatements != null)
			for (s in ci.staticFieldDecorationStatements)
				leadingBlockStatements.push(s);

		// 8. Non-static field element decorators are applied
		if (ci.nonStaticFieldDecorationStatements != null)
			for (s in ci.nonStaticFieldDecorationStatements)
				leadingBlockStatements.push(s);

		// 9. Class decorators are applied
		// 10. Class binding is initialized
		//
		// produces:
		//   __esDecorate(null, _classDescriptor = { value: this }, _classDecorators, { kind: "class", name: this.name, metadata }, null, _classExtraInitializers);
		if (ci.classDescriptorName != null && ci.classDecoratorsName != null && ci.classExtraInitializersName != null && ci.classThis != null) {
			final valueProperty = f.NewPropertyAssignment(null, f.NewIdentifier("value"), null, null, renamedClassThis);
			final classDescriptor = f.NewObjectLiteralExpression(f.NewNodeList([valueProperty]), false);
			final classDescriptorAssignment = f.NewAssignmentExpression(ci.classDescriptorName, classDescriptor);
			final classNameReference = f.NewPropertyAccessExpression(renamedClassThis, null, f.NewIdentifier("name"), NodeFlagsNone);

			final contextObj = f.NewESDecorateClassContextObject(classNameReference, ci.metadataReference);

			final esDecorateHelper = f.NewESDecorateHelper(f.NewToken(KindNullKeyword), classDescriptorAssignment, ci.classDecoratorsName, contextObj,
				f.NewToken(KindNullKeyword), ci.classExtraInitializersName);
			final esDecorateStatement = f.NewExpressionStatement(esDecorateHelper);
			ec.SetSourceMapRange(esDecorateStatement, Transformers.MoveRangePastDecorators(node));
			leadingBlockStatements.push(esDecorateStatement);

			// produces:
			//   C = _classThis = _classDescriptor.value;
			final classDescriptorValueRef = f.NewPropertyAccessExpression(ci.classDescriptorName, null, f.NewIdentifier("value"), NodeFlagsNone);
			final classThisAssignment = f.NewAssignmentExpression(ci.classThis, classDescriptorValueRef);
			final classReferenceAssignment = f.NewAssignmentExpression(classReference, classThisAssignment);
			leadingBlockStatements.push(f.NewExpressionStatement(classReferenceAssignment));
		}

		// produces:
		//   if (metadata) Object.defineProperty(C, Symbol.metadata, { configurable: true, writable: true, value: metadata });
		leadingBlockStatements.push(createSymbolMetadata(renamedClassThis, ci.metadataReference));

		// 11. Static extra initializers
		// 12. Static fields are initialized
		if (Core.len(ci.pendingStaticInitializers) > 0) {
			for (initializer in ci.pendingStaticInitializers) {
				final initializerStatement = f.NewExpressionStatement(initializer);
				ec.SetSourceMapRange(initializerStatement, ec.SourceMapRange(initializer));
				trailingBlockStatements.push(initializerStatement);
			}
			ci.pendingStaticInitializers = null;
		}

		// 13. Class extra initializers
		if (ci.classExtraInitializersName != null) {
			final runClassInitializersHelper = f.NewRunInitializersHelper(renamedClassThis, ci.classExtraInitializersName, null);
			final runClassInitializersStatement = f.NewExpressionStatement(runClassInitializersHelper);
			if (node.Name() != null) {
				ec.SetSourceMapRange(runClassInitializersStatement, node.Name().Loc);
			} else {
				ec.SetSourceMapRange(runClassInitializersStatement, Transformers.MoveRangePastDecorators(node));
			}
			trailingBlockStatements.push(runClassInitializersStatement);
		}

		// If there are no other static initializers to run, combine the leading and trailing block statements
		if (leadingBlockStatements.length > 0 && trailingBlockStatements.length > 0 && !ci.hasStaticInitializers) {
			for (s in trailingBlockStatements)
				leadingBlockStatements.push(s);
			trailingBlockStatements = [];
		}

		// prepare a leading `static {}` block, if necessary
		//
		// produces:
		//   class C {
		//       static { ... }
		//       ...
		//   }
		var leadingStaticBlock:Node = null;
		if (leadingBlockStatements.length > 0) {
			leadingStaticBlock = f.NewClassStaticBlockDeclaration(null, f.NewBlock(f.NewNodeList(leadingBlockStatements), true));
		}

		if (leadingStaticBlock != null && shouldTransformPrivateStaticElementsInClass) {
			// We use EFTransformPrivateStaticElements as a marker on a class static block
			// to inform the classFields transform that it shouldn't rename `this` to `_classThis` in the
			// transformed class static block.
			ec.SetEmitFlags(leadingStaticBlock, EFTransformPrivateStaticElements);
		}

		// prepare a trailing `static {}` block, if necessary
		//
		// produces:
		//   class C {
		//       ...
		//       static { ... }
		//   }
		var trailingStaticBlock:Node = null;
		if (trailingBlockStatements.length > 0) {
			trailingStaticBlock = f.NewClassStaticBlockDeclaration(null, f.NewBlock(f.NewNodeList(trailingBlockStatements), true));
		}

		// Assemble new members list
		if (leadingStaticBlock != null || syntheticConstructor != null || trailingStaticBlock != null) {
			var newMembers:Array<Node> = [];

			// Find the existing NamedEvaluation helper block index
			var existingNamedEvaluationHelperBlockIndex = -1;
			for (i in 0...Core.len(members.Nodes)) {
				final m = members.Nodes[i];
				if (Estransforms.isClassNamedEvaluationHelperBlock(ec, m)) {
					existingNamedEvaluationHelperBlockIndex = i;
					break;
				}
			}

			// add the leading `static {}` block
			if (leadingStaticBlock != null) {
				// add the `static {}` block after any existing NamedEvaluation helper block, if one exists.
				for (m in nilSlice(members.Nodes).slice(0, existingNamedEvaluationHelperBlockIndex + 1))
					newMembers.push(m);
				newMembers.push(leadingStaticBlock);
				for (m in nilSlice(members.Nodes).slice(existingNamedEvaluationHelperBlockIndex + 1))
					newMembers.push(m);
			} else {
				for (m in nilSlice(members.Nodes))
					newMembers.push(m);
			}

			// append the synthetic constructor, if necessary
			if (syntheticConstructor != null) {
				newMembers.push(syntheticConstructor);
			}

			// append a trailing `static {}` block, if necessary
			if (trailingStaticBlock != null) {
				newMembers.push(trailingStaticBlock);
			}

			final membersList = f.NewNodeList(newMembers);
			membersList.Loc = members.Loc;
			members = membersList;
		}

		final lexicalEnvironment = ec.EndVariableEnvironment();

		var classExpression:Node = null;
		if (Core.len(classDecorators) > 0) {
			classExpression = f.NewClassExpression(null, null, null, heritageClauses, members);
			ec.SetOriginal(classExpression, node);
			if (ci.classThis != null) {
				classExpression = Estransforms.injectClassThisAssignmentIfMissing(ec, f, classExpression, ci.classThis);
			}

			// We use `var` instead of `let` so we can leverage NamedEvaluation to define the class name
			// and still be able to ensure it is initialized prior to any use in `static {}`.

			// produces:
			//   (() => {
			//       let _classDecorators = [...];
			//       let _classDescriptor;
			//       let _classExtraInitializers = [];
			//       let _classThis;
			//       ...
			//       var C = class {
			//           static {
			//               __esDecorate(null, _classDescriptor = { value: this }, _classDecorators, ...);
			//               C = _classThis = _classDescriptor.value;
			//           }
			//           static x = 1;
			//           static y = C.x; // `C` will already be defined here.
			//           static { ... }
			//       };
			//       return C;
			//   })();

			final classReferenceDeclaration = f.NewVariableDeclaration(classReference, null, null, classExpression);
			final classReferenceVarDeclList = f.NewVariableDeclarationList(f.NewNodeList([classReferenceDeclaration]), NodeFlagsNone);
			var returnExpr:Expression = null;
			if (ci.classThis != null) {
				returnExpr = f.NewAssignmentExpression(classReference, ci.classThis);
			} else {
				returnExpr = classReference;
			}
			classDefinitionStatements.push(f.NewVariableStatement(null, classReferenceVarDeclList));
			classDefinitionStatements.push(f.NewReturnStatement(returnExpr));
		} else {
			// produces:
			//   return <classExpression>;
			classExpression = f.NewClassExpression(null, node.Name(), null, heritageClauses, members);
			ec.SetOriginal(classExpression, node);
			classDefinitionStatements.push(f.NewReturnStatement(classExpression));
		}

		if (shouldTransformPrivateStaticElementsInClass) {
			ec.AddEmitFlags(classExpression, EFTransformPrivateStaticElements);
			for (member in nilSlice(classExpression.Members())) {
				if ((Ast.IsPrivateIdentifierClassElementDeclaration(member) || Ast.IsAutoAccessorPropertyDeclaration(member))
					&& Ast.HasStaticModifier(member)) {
					ec.AddEmitFlags(member, EFTransformPrivateStaticElements);
				}
			}
		}

		final mergedStatements = ec.MergeEnvironment(classDefinitionStatements, lexicalEnvironment);
		return f.NewImmediatelyInvokedArrowFunction(mergedStatements);
	}

	// Generates let declarations for member decorator info variables, filtered by static/non-static.
	function emitMemberInfoDeclarations(ci:ClassInfo, isStatic:Bool):Array<Statement> {
		final f = Factory();
		final stmts:Array<Statement> = []; // PORT: nil slice → empty array (the caller only spreads it)
		for (member => mi in ci.memberInfos.Entries()) {
			if (Ast.IsStatic(member) != isStatic) {
				continue;
			}
			stmts.push(createLet(mi.memberDecoratorsName, null));
			if (mi.memberInitializersName != null) {
				stmts.push(createLet(mi.memberInitializersName, f.NewArrayLiteralExpression(f.NewNodeList(null), false)));
			}
			if (mi.memberExtraInitializersName != null) {
				stmts.push(createLet(mi.memberExtraInitializersName, f.NewArrayLiteralExpression(f.NewNodeList(null), false)));
			}
			if (mi.memberDescriptorName != null) {
				stmts.push(createLet(mi.memberDescriptorName, null));
			}
		}
		return stmts;
	}

	function visitClassDeclaration(node:ClassDeclaration):Node {
		if (Estransforms.isDecoratedClassLike(node.AsNode())) {
			final f = Factory();
			final ec = EmitContext();
			final statements:Array<Statement> = [];

			var originalClass = ec.MostOriginal(node.AsNode());
			if (!Ast.IsClassLike(originalClass)) {
				originalClass = node.AsNode();
			}
			var className:Expression = null;
			if (originalClass.Name() != null) {
				className = f.NewStringLiteralFromNode(originalClass.Name());
			} else {
				className = f.NewStringLiteral("default", 0);
			}

			final isExport = Ast.HasSyntacticModifier(node.AsNode(), ModifierFlagsExport);
			final isDefault = Ast.HasSyntacticModifier(node.AsNode(), ModifierFlagsDefault);

			var classNode = node.AsNode();
			if (node.Name() == null) {
				classNode = Estransforms.injectClassNamedEvaluationHelperBlockIfMissing(ec, classNode, className, null);
			}

			if (isExport && isDefault) {
				final iife = transformClassLike(classNode);
				if (classNode.Name() != null) {
					// produces:
					//   let C = (() => { ... })();
					//   export default C;
					final varDecl = f.NewVariableDeclaration(f.GetLocalName(classNode), null, null, iife);
					ec.SetOriginal(varDecl, classNode);
					final varDecls = f.NewVariableDeclarationList(f.NewNodeList([varDecl]), NodeFlagsLet);
					final varStatement = f.NewVariableStatement(null, varDecls);
					statements.push(varStatement);

					final exportStatement = f.NewExportDefault(f.GetDeclarationName(classNode));
					ec.SetOriginal(exportStatement, classNode);
					ec.AssignCommentRange(exportStatement, classNode);
					ec.SetSourceMapRange(exportStatement, Transformers.MoveRangePastDecorators(classNode));
					statements.push(exportStatement);
				} else {
					// produces:
					//   export default (() => { ... })();
					final exportStatement = f.NewExportDefault(iife);
					ec.SetOriginal(exportStatement, classNode);
					ec.AssignCommentRange(exportStatement, classNode);
					ec.SetSourceMapRange(exportStatement, Transformers.MoveRangePastDecorators(classNode));
					statements.push(exportStatement);
				}
			} else {
				Debug.Assert(classNode.Name() != null, "A class declaration that is not a default export must have a name.");
				// produces:
				//   let C = (() => { ... })();
				final iife = transformClassLike(classNode);
				final modifiers = exportStrippingModifierVisitor.VisitModifiers(classNode.Modifiers());

				final declName = f.GetLocalNameEx(classNode, new AssignedNameOptions(false, true /*AllowSourceMaps*/));
				final varDecl = f.NewVariableDeclaration(declName, null, null, iife);
				ec.SetOriginal(varDecl, classNode);
				final varDecls = f.NewVariableDeclarationList(f.NewNodeList([varDecl]), NodeFlagsLet);
				final varStatement = f.NewVariableStatement(modifiers, varDecls);
				ec.SetOriginal(varStatement, classNode);
				ec.AssignCommentRange(varStatement, classNode);
				statements.push(varStatement);

				if (isExport) {
					// produces:
					//   export { C };
					final exportStatement = f.NewExternalModuleExport(declName);
					ec.SetOriginal(exportStatement, classNode);
					statements.push(exportStatement);
				}
			}

			return Transformers.SingleOrMany(statements, f);
		}

		// Non-decorated class
		final modifiers = modifierVisitor.VisitModifiers(node.Modifiers());
		final heritageClauses = Visitor().VisitNodes(node.HeritageClauses);
		enterClass(null);
		final members = classElementVisitor.VisitNodes(node.Members);
		exitClass();
		return Factory().UpdateClassDeclaration(node, modifiers, node.Name(), null, heritageClauses, members);
	}

	function visitClassExpression(node:ClassExpression):Node {
		if (Estransforms.isDecoratedClassLike(node.AsNode())) {
			final iife = transformClassLike(node.AsNode());
			EmitContext().SetOriginal(iife, node.AsNode());
			return iife;
		}

		final modifiers = modifierVisitor.VisitModifiers(node.Modifiers());
		final heritageClauses = Visitor().VisitNodes(node.HeritageClauses);
		enterClass(null);
		final members = classElementVisitor.VisitNodes(node.Members);
		exitClass();
		return Factory().UpdateClassExpression(node, modifiers, node.Name(), null, heritageClauses, members);
	}

	function prepareConstructor(ci:ClassInfo):Array<Statement> {
		// Decorated instance members can add "extra" initializers to the instance. If a class contains any instance
		// fields, we'll inject the `__runInitializers()` call for these extra initializers into the initializer of
		// the first class member that will be initialized. However, if the class does not contain any fields that
		// we can piggyback on, we need to synthesize a `__runInitializers()` call in the constructor instead.
		if (Core.len(ci.pendingInstanceInitializers) == 0) {
			return null;
		}
		final f = Factory();
		final statements:Array<Statement> = [f.NewExpressionStatement(f.InlineExpressions(ci.pendingInstanceInitializers)),];
		ci.pendingInstanceInitializers = null;
		return statements;
	}

	function transformConstructorBodyWorker(statementsOut:Array<Statement>, statementsIn:Array<Statement>, statementOffset:Int, superPath:Array<Int>,
			superPathDepth:Int, initializerStatements:Array<Statement>):Array<Statement> {
		if (statementsOut == null)
			statementsOut = [];
		final superStatementIndex = superPath[superPathDepth];
		// Visit statements before super
		if (superStatementIndex > statementOffset) {
			for (s in statementsIn.slice(statementOffset, superStatementIndex)) {
				statementsOut.push(Visitor().VisitNode(s));
			}
		}

		final superStatement = statementsIn[superStatementIndex];
		if (Ast.IsTryStatement(superStatement)) {
			// Recurse into try block
			final tryBlockNode = superStatement.AsTryStatement().TryBlock;
			final tryBlock = tryBlockNode.AsBlock();
			final tryBlockStatements = transformConstructorBodyWorker(null, tryBlock.Statements.Nodes, 0, superPath, superPathDepth + 1, initializerStatements);

			final newTryBlock = Factory().NewBlock(Factory().NewNodeList(tryBlockStatements), true);
			// Use the original try block's range even though the statements may differ due to
			// injected initializer statements. This preserves source map fidelity for the enclosing
			// try statement.
			newTryBlock.Loc = tryBlockNode.Loc;

			var catchClause:Node = null;
			if (superStatement.AsTryStatement().CatchClause != null) {
				catchClause = Visitor().VisitNode(superStatement.AsTryStatement().CatchClause);
			}
			var finallyBlock:Node = null;
			if (superStatement.AsTryStatement().FinallyBlock != null) {
				finallyBlock = Visitor().VisitNode(superStatement.AsTryStatement().FinallyBlock);
			}
			final updated = Factory().UpdateTryStatement(superStatement.AsTryStatement(), newTryBlock, catchClause, finallyBlock);
			statementsOut.push(updated);
		} else {
			statementsOut.push(Visitor().VisitNode(superStatement));
			if (initializerStatements != null)
				for (s in initializerStatements)
					statementsOut.push(s);
		}

		// Visit statements after super
		if (superStatementIndex + 1 < statementsIn.length) {
			for (s in statementsIn.slice(superStatementIndex + 1)) {
				statementsOut.push(Visitor().VisitNode(s));
			}
		}
		return statementsOut;
	}

	function visitConstructorDeclaration(node:Node):Node {
		enterClassElement(node);
		final modifiers = modifierVisitor.VisitModifiers(node.Modifiers());
		final parameters = Visitor().VisitNodes(node.ParameterList());

		var body:Node = null;
		final ctor = node.AsConstructorDeclaration();
		if (ctor.Body != null && classInfoStack != null) {
			// If there are instance extra initializers we need to add them to the body along with any
			// field initializers
			final initializerStatements = prepareConstructor(classInfoStack);
			if (Core.len(initializerStatements) > 0) {
				var stmts:Array<Statement> = [];
				final split = Factory().SplitStandardPrologue(ctor.Body.AsBlock().Statements.Nodes);
				final prologue = split.a;
				final rest = split.b;
				if (prologue != null)
					for (s in prologue)
						stmts.push(s);

				final superStatementIndices = Transformers.FindSuperStatementIndexPath(rest, 0);
				if (Core.len(superStatementIndices) > 0) {
					stmts = transformConstructorBodyWorker(stmts, rest, 0, superStatementIndices, 0, initializerStatements);
				} else {
					for (s in initializerStatements)
						stmts.push(s);
					final visited = Visitor().VisitSlice(rest);
					if (visited != null)
						for (s in visited)
							stmts.push(s);
				}

				body = Factory().NewBlock(Factory().NewNodeList(stmts), true);
				EmitContext().SetOriginal(body, ctor.Body.AsNode());
				body.Loc = ctor.Body.Loc;
			}
		}

		if (body == null) {
			body = Visitor().VisitNode(ctor.Body); // PORT: Go `ctor.Body.AsNode()` (nil-safe in Go)
		}
		exitClassElement();
		return Factory().UpdateConstructorDeclaration(ctor, modifiers, null, parameters, null, null, body);
	}

	function finishClassElement(updated:Node, original:Node):Node {
		if (updated != original) {
			// While we emit the source map for the node after skipping decorators and modifiers,
			// we need to emit the comments for the original range.
			EmitContext().AssignCommentRange(updated, original);
			EmitContext().SetSourceMapRange(updated, Transformers.MoveRangePastDecorators(original));
		}
		return updated;
	}

	function partialTransformClassElement(member:Node, ci:ClassInfo, createDescriptor:CreateDescriptorFunc):PartialResult {
		final f = Factory();
		final ec = EmitContext();

		if (ci == null) {
			final modifiers = modifierVisitor.VisitModifiers(member.Modifiers());
			enterName();
			final name = visitPropertyName(member.Name());
			exitName();
			final r = new PartialResult();
			r.modifiers = modifiers;
			r.name = name;
			return r;
		}

		// Member decorators require privileged access to private names. However, computed property
		// evaluation occurs interspersed with decorator evaluation. This means that if we encounter
		// a computed property name we must inline decorator evaluation.

		// Collect decorators for this member. Decorator expressions evaluate outside the class body,
		// so `this` should NOT be replaced with `_classThis`.
		final savedClassThis = classThis;
		classThis = null;
		final memberDecorators = transformAllDecoratorsOfDeclaration(member.Decorators());
		classThis = savedClassThis;
		final modifiers = modifierVisitor.VisitModifiers(member.Modifiers());

		final result = new PartialResult();
		result.modifiers = modifiers;

		if (Core.len(memberDecorators) > 0) {
			final memberDecoratorsName = createHelperVariable(member, "decorators");
			final memberDecoratorsArray = f.NewArrayLiteralExpression(f.NewNodeList(memberDecorators), false);
			final memberDecoratorsAssignment = f.NewAssignmentExpression(memberDecoratorsName, memberDecoratorsArray);
			final mi = new MemberInfo();
			mi.memberDecoratorsName = memberDecoratorsName;
			ci.memberInfos.Set(member, mi);
			if (pendingExpressions == null)
				pendingExpressions = [];
			pendingExpressions.push(memberDecoratorsAssignment);

			// 5. Static non-field (method/getter/setter/auto-accessor) element decorators are applied
			// 6. Non-static non-field (method/getter/setter/auto-accessor) element decorators are applied
			// 7. Static field (excl. auto-accessor) element decorators are applied
			// 8. Non-static field (excl. auto-accessor) element decorators are applied

			// Determine decorator kind
			var kind:std.String = "";
			if (Ast.IsGetAccessorDeclaration(member)) {
				kind = "getter";
			} else if (Ast.IsSetAccessorDeclaration(member)) {
				kind = "setter";
			} else if (Ast.IsMethodDeclaration(member)) {
				kind = "method";
			} else if (Ast.IsAutoAccessorPropertyDeclaration(member)) {
				kind = "accessor";
			} else if (Ast.IsPropertyDeclaration(member)) {
				kind = "field";
			} else {
				Debug.Fail("Unexpected class element kind.");
			}

			// Determine the property name for the context
			var propertyNameComputed = false;
			var propertyNameExpr:Expression = null;
			if (member.Name() != null && (Ast.IsIdentifier(member.Name()) || Ast.IsPrivateIdentifier(member.Name()))) {
				propertyNameComputed = false;
				propertyNameExpr = member.Name();
			} else if (member.Name() != null && Ast.IsPropertyNameLiteral(member.Name())) {
				propertyNameComputed = true;
				propertyNameExpr = f.NewStringLiteralFromNode(member.Name());
			} else if (member.Name() != null && Ast.IsComputedPropertyName(member.Name())) {
				final cpn = member.Name().AsComputedPropertyName();
				if (Ast.IsPropertyNameLiteral(cpn.Expression) && !Ast.IsIdentifier(cpn.Expression)) {
					propertyNameComputed = true;
					propertyNameExpr = f.NewStringLiteralFromNode(cpn.Expression);
				} else {
					enterName();
					final referenced = visitReferencedPropertyName(member.Name());
					result.referencedName = referenced.a;
					result.name = referenced.b;
					exitName();
					propertyNameComputed = true;
					propertyNameExpr = result.referencedName;
				}
			}

			final contextObj = f.NewESDecorateClassElementContextObject(kind, propertyNameComputed, propertyNameExpr, Ast.IsStatic(member),
				member.Name() != null && Ast.IsPrivateIdentifier(member.Name()),
				// 15.7.3 CreateDecoratorAccessObject (kind, name)
				// 2. If _kind_ is ~field~, ~method~, ~accessor~, or ~getter~, then ...
				Ast.IsPropertyDeclaration(member) || Ast.IsGetAccessorDeclaration(member) || Ast.IsMethodDeclaration(member),
				// 3. If _kind_ is ~field~, ~accessor~, or ~setter~, then ...
				Ast.IsPropertyDeclaration(member) || Ast.IsSetAccessorDeclaration(member), ci.metadataReference);

			if (Ast.IsMethodOrAccessor(member)) {
				// produces (public elements):
				//   __esDecorate(this, null, _static_member_decorators, { kind: "method", name: "...", static: true, private: false, access: { ... } }, _staticExtraInitializers);
				//   __esDecorate(this, null, _member_decorators, { kind: "method", name: "...", static: false, private: false, access: { ... } }, _instanceExtraInitializers);
				//   __esDecorate(this, null, _static_member_decorators, { kind: "getter", name: "...", static: true, private: false, access: { ... } }, _staticExtraInitializers);
				//   __esDecorate(this, null, _member_decorators, { kind: "getter", name: "...", static: false, private: false, access: { ... } }, _instanceExtraInitializers);
				//   __esDecorate(this, null, _static_member_decorators, { kind: "setter", name: "...", static: true, private: false, access: { ... } }, _staticExtraInitializers);
				//   __esDecorate(this, null, _member_decorators, { kind: "setter", name: "...", static: false, private: false, access: { ... } }, _instanceExtraInitializers);
				//
				// produces (private elements):
				//   __esDecorate(this, _static_member_descriptor = { value() { ... } }, _static_member_decorators, { kind: "method", name: "...", static: true, private: true, access: { ... } }, _staticExtraInitializers);
				//   __esDecorate(this, _member_descriptor = { value() { ... } }, _member_decorators, { kind: "method", name: "...", static: false, private: true, access: { ... } }, _instanceExtraInitializers);
				//   __esDecorate(this, _static_member_descriptor = { get() { ... } }, _static_member_decorators, { kind: "getter", name: "...", static: true, private: true, access: { ... } }, _staticExtraInitializers);
				//   __esDecorate(this, _member_descriptor = { get() { ... } }, _member_decorators, { kind: "getter", name: "...", static: false, private: true, access: { ... } }, _instanceExtraInitializers);
				//   __esDecorate(this, _static_member_descriptor = { set() { ... } }, _static_member_decorators, { kind: "setter", name: "...", static: true, private: true, access: { ... } }, _staticExtraInitializers);
				//   __esDecorate(this, _member_descriptor = { set() { ... } }, _member_decorators, { kind: "setter", name: "...", static: false, private: true, access: { ... } }, _instanceExtraInitializers);
				var methodExtraInitializersName = ci.instanceMethodExtraInitializersName;
				if (Ast.IsStatic(member)) {
					methodExtraInitializersName = ci.staticMethodExtraInitializersName;
				}
				Debug.Assert(methodExtraInitializersName != null, "methodExtraInitializersName should be defined");

				var descriptorArg:Expression = null;
				if (Ast.IsPrivateIdentifierClassElementDeclaration(member) && createDescriptor != null) {
					// For private members, extract the method/accessor body into a descriptor object.
					// Filter modifiers to only keep async.
					final asyncMods = asyncOnlyModifierVisitor.VisitModifiers(modifiers);
					final descriptor = createDescriptor(member, asyncMods);
					mi.memberDescriptorName = createHelperVariable(member, "descriptor");
					result.descriptorName = mi.memberDescriptorName;
					descriptorArg = f.NewAssignmentExpression(mi.memberDescriptorName, descriptor);
				} else {
					descriptorArg = f.NewToken(KindNullKeyword);
				}

				final esDecorateExpr = f.NewESDecorateHelper(f.NewThisExpression(), descriptorArg, memberDecoratorsName, contextObj, f.NewToken(KindNullKeyword),
					methodExtraInitializersName);
				final esDecorateStatement = f.NewExpressionStatement(esDecorateExpr);
				ec.SetSourceMapRange(esDecorateStatement, Transformers.MoveRangePastDecorators(member));
				appendDecorationStatement(ci, member, esDecorateStatement);
			} else if (Ast.IsPropertyDeclaration(member)) {
				mi.memberInitializersName = createHelperVariable(member, "initializers");
				mi.memberExtraInitializersName = createHelperVariable(member, "extraInitializers");
				result.initializersName = mi.memberInitializersName;
				result.extraInitializersName = mi.memberExtraInitializersName;
				if (Ast.IsStatic(member)) {
					result.thisArg = ci.classThis;
				}

				var ctorArg:Node = null;
				if (Ast.IsAutoAccessorPropertyDeclaration(member)) {
					ctorArg = f.NewThisExpression();
				} else {
					ctorArg = f.NewToken(KindNullKeyword);
				}

				var descriptorArg:Expression = null;
				if (Ast.IsPrivateIdentifierClassElementDeclaration(member) && Ast.HasAccessorModifier(member) && createDescriptor != null) {
					final descriptor = createDescriptor(member, null);
					mi.memberDescriptorName = createHelperVariable(member, "descriptor");
					result.descriptorName = mi.memberDescriptorName;
					descriptorArg = f.NewAssignmentExpression(mi.memberDescriptorName, descriptor);
				} else {
					descriptorArg = f.NewToken(KindNullKeyword);
				}

				// produces:
				//   __esDecorate(null, null, _static_member_decorators, { kind: "field", name: "...", static: true, private: ..., access: { ... } }, _staticExtraInitializers);
				//   __esDecorate(null, null, _member_decorators, { kind: "field", name: "...", static: false, private: ..., access: { ... } }, _instanceExtraInitializers);
				final esDecorateExpr = f.NewESDecorateHelper(ctorArg, descriptorArg, memberDecoratorsName, contextObj, mi.memberInitializersName,
					mi.memberExtraInitializersName);
				final esDecorateStatement = f.NewExpressionStatement(esDecorateExpr);
				ec.SetSourceMapRange(esDecorateStatement, Transformers.MoveRangePastDecorators(member));
				appendDecorationStatement(ci, member, esDecorateStatement);
			}
		}

		if (result.name == null) {
			enterName();
			result.name = visitPropertyName(member.Name());
			exitName();
		}

		if ((modifiers == null || modifiers.Nodes.length == 0) && (Ast.IsMethodDeclaration(member) || Ast.IsPropertyDeclaration(member))) {
			// Don't emit leading comments on the name for methods and properties without modifiers, otherwise we
			// will end up printing duplicate comments.
			ec.SetEmitFlags(result.name, EFNoLeadingComments);
		}

		return result;
	}

	// appendDecorationStatement appends an __esDecorate statement to the appropriate
	// decoration statement list on classInfo based on the member's kind and static-ness.
	function appendDecorationStatement(ci:ClassInfo, member:Node, stmt:Statement):Void {
		if (Ast.IsMethodOrAccessor(member) || Ast.IsAutoAccessorPropertyDeclaration(member)) {
			if (Ast.IsStatic(member)) {
				if (ci.staticNonFieldDecorationStatements == null)
					ci.staticNonFieldDecorationStatements = [];
				ci.staticNonFieldDecorationStatements.push(stmt);
			} else {
				if (ci.nonStaticNonFieldDecorationStatements == null)
					ci.nonStaticNonFieldDecorationStatements = [];
				ci.nonStaticNonFieldDecorationStatements.push(stmt);
			}
		} else if (Ast.IsPropertyDeclaration(member) && !Ast.IsAutoAccessorPropertyDeclaration(member)) {
			if (Ast.IsStatic(member)) {
				if (ci.staticFieldDecorationStatements == null)
					ci.staticFieldDecorationStatements = [];
				ci.staticFieldDecorationStatements.push(stmt);
			} else {
				if (ci.nonStaticFieldDecorationStatements == null)
					ci.nonStaticFieldDecorationStatements = [];
				ci.nonStaticFieldDecorationStatements.push(stmt);
			}
		} else {
			Debug.Fail("Unexpected class element kind.");
		}
	}

	function visitMethodDeclaration(node:Node):Node {
		enterClassElement(node);
		final result = partialTransformClassElement(node, classInfoStack, createMethodDescriptorObjectFunc);
		if (result.descriptorName != null) {
			exitClassElement();
			return finishClassElement(createMethodDescriptorForwarder(result.modifiers, result.name, result.descriptorName), node);
		}
		final parameters = Visitor().VisitNodes(node.ParameterList());
		final body = Visitor().VisitNode(node.Body());
		exitClassElement();
		final method = node.AsMethodDeclaration();
		return finishClassElement(Factory().UpdateMethodDeclaration(method, result.modifiers, method.AsteriskToken, result.name, null, null, parameters, null, null,
			body), node);
	}

	function visitGetAccessorDeclaration(node:Node):Node {
		enterClassElement(node);
		final result = partialTransformClassElement(node, classInfoStack, createGetAccessorDescriptorObjectFunc);
		if (result.descriptorName != null) {
			exitClassElement();
			return finishClassElement(createGetAccessorDescriptorForwarder(result.modifiers, result.name, result.descriptorName), node);
		}
		final parameters = Visitor().VisitNodes(node.ParameterList());
		final body = Visitor().VisitNode(node.Body());
		exitClassElement();
		final accessor = node.AsGetAccessorDeclaration();
		return finishClassElement(Factory().UpdateGetAccessorDeclaration(accessor, result.modifiers, result.name, null, parameters, null, null, body), node);
	}

	function visitSetAccessorDeclaration(node:Node):Node {
		enterClassElement(node);
		final result = partialTransformClassElement(node, classInfoStack, createSetAccessorDescriptorObjectFunc);
		if (result.descriptorName != null) {
			exitClassElement();
			return finishClassElement(createSetAccessorDescriptorForwarder(result.modifiers, result.name, result.descriptorName), node);
		}
		final parameters = Visitor().VisitNodes(node.ParameterList());
		final body = Visitor().VisitNode(node.Body());
		exitClassElement();
		final accessor = node.AsSetAccessorDeclaration();
		return finishClassElement(Factory().UpdateSetAccessorDeclaration(accessor, result.modifiers, result.name, null, parameters, null, null, body), node);
	}

	function visitClassStaticBlockDeclaration(node:Node):Node {
		enterClassElement(node);
		final f = Factory();

		var result:Node = null;
		if (Estransforms.isClassNamedEvaluationHelperBlock(EmitContext(), node)) {
			result = Visitor().VisitEachChild(node);
			// Transfer AssignedName metadata to the new node so isClassNamedEvaluationHelperBlock
			// can still find it after visiting (visiting may create a new node when this->_classThis)
			final assignedName = EmitContext().AssignedName(node);
			if (assignedName != null && result != node) {
				EmitContext().SetAssignedName(result, assignedName);
			}
		} else if (Estransforms.isClassThisAssignmentBlock(EmitContext(), node)) {
			final savedClassThis = classThis;
			classThis = null;
			result = Visitor().VisitEachChild(node);
			classThis = savedClassThis;
		} else {
			// Use a nested variable environment so temp vars generated during static block
			// content transformation (e.g., super access temps) stay scoped to the static block.
			final ec = EmitContext();
			ec.StartVariableEnvironment();
			result = Visitor().VisitEachChild(node);
			final varStatements = ec.EndVariableEnvironment();
			if (Core.len(varStatements) > 0) {
				// Inject var declarations at the start of the static block's body
				final blockBody = result.AsClassStaticBlockDeclaration().Body.AsBlock();
				final newStmts:Array<Statement> = varStatements.concat(nilSlice(blockBody.Statements.Nodes));
				result = f.NewClassStaticBlockDeclaration(null, f.NewBlock(f.NewNodeList(newStmts), blockBody.MultiLine));
			}
			if (classInfoStack != null) {
				classInfoStack.hasStaticInitializers = true;
				if (Core.len(classInfoStack.pendingStaticInitializers) > 0) {
					// If we tried to inject the pending initializers into the current block, we might run into
					// variable name collisions due to sharing this blocks scope. To avoid this, we inject a new
					// static block that contains the pending initializers that precedes this block.
					final stmts:Array<Node> = [];
					for (init in classInfoStack.pendingStaticInitializers) {
						final initStmt = f.NewExpressionStatement(init);
						EmitContext().SetSourceMapRange(initStmt, EmitContext().SourceMapRange(init));
						stmts.push(initStmt);
					}
					final body = f.NewBlock(f.NewNodeList(stmts), true);
					final staticBlock = f.NewClassStaticBlockDeclaration(null, body);
					classInfoStack.pendingStaticInitializers = null;
					// Return both the new static block and the original
					exitClassElement();
					return Transformers.SingleOrMany([staticBlock, result], Factory());
				}
			}
		}

		exitClassElement();
		return result;
	}

	function visitPropertyDeclaration(node:Node):Node {
		if (Estransforms.isNamedEvaluationAnd(EmitContext(), node, Estransforms.isAnonymousClassNeedingAssignedName)) {
			node = Estransforms.transformNamedEvaluation(EmitContext(), node, Estransforms.canIgnoreEmptyStringLiteralInAssignedName(node.Initializer()), "");
		}

		enterClassElement(node);

		// TODO(rbuckton): We support decorating `declare x` fields with legacyDecorators, but we currently don't
		//                 support them with esDecorators. We need to consider whether we will support them in the
		//                 future, and how. For now, these should be elided by the `ts` transform.
		Debug.Assert(!Ast.HasSyntacticModifier(node, ModifierFlagsAmbient), "Not yet implemented.");

		// 10.2.1.3 RS: EvaluateBody
		//   Initializer : `=` AssignmentExpression
		//     ...
		//     3. If IsAnonymousFunctionDefinition(|AssignmentExpression|) is *true*, then
		//        a. Let _value_ be ? NamedEvaluation of |Initializer| with argument _functionObject_.[[ClassFieldInitializerName]].
		//     ...

		final f = Factory();
		final ec = EmitContext();

		var createDescriptor:CreateDescriptorFunc = null;
		if (Ast.HasAccessorModifier(node)) {
			createDescriptor = createAccessorPropertyDescriptorObjectFunc;
		}
		final result = partialTransformClassElement(node, classInfoStack, createDescriptor);

		ec.StartVariableEnvironment();

		var initializer = Visitor().VisitNode(node.Initializer());
		if (result.initializersName != null) {
			var thisArg:Node = null;
			if (result.thisArg != null) {
				thisArg = result.thisArg;
			} else {
				thisArg = f.NewThisExpression();
			}
			if (initializer == null) {
				initializer = f.NewVoidZeroExpression();
			}
			initializer = f.NewRunInitializersHelper(thisArg, result.initializersName, initializer);
		}

		if (Ast.IsStatic(node) && classInfoStack != null && initializer != null) {
			classInfoStack.hasStaticInitializers = true;
		}

		final declarations = ec.EndVariableEnvironment();
		if (Core.len(declarations) > 0) {
			final stmts:Array<Statement> = declarations.copy();
			stmts.push(f.NewReturnStatement(initializer));
			initializer = f.NewImmediatelyInvokedArrowFunction(stmts);
		}

		if (classInfoStack != null) {
			if (Ast.IsStatic(node)) {
				initializer = injectPendingInitializers(classInfoStack, true, initializer);
				if (result.extraInitializersName != null) {
					var thisArg:Node = null;
					if (classInfoStack.classThis != null) {
						thisArg = classInfoStack.classThis;
					} else {
						thisArg = f.NewThisExpression();
					}
					if (classInfoStack.pendingStaticInitializers == null)
						classInfoStack.pendingStaticInitializers = [];
					classInfoStack.pendingStaticInitializers.push(f.NewRunInitializersHelper(thisArg, result.extraInitializersName, null));
				}
			} else {
				initializer = injectPendingInitializers(classInfoStack, false, initializer);
				if (result.extraInitializersName != null) {
					if (classInfoStack.pendingInstanceInitializers == null)
						classInfoStack.pendingInstanceInitializers = [];
					classInfoStack.pendingInstanceInitializers.push(f.NewRunInitializersHelper(f.NewThisExpression(), result.extraInitializersName, null));
				}
			}
		}

		exitClassElement();

		if (Ast.HasAccessorModifier(node) && result.descriptorName != null) {
			// given:
			//  accessor #x = 1;
			//
			// emits:
			//  static {
			//      _esDecorate(null, _private_x_descriptor = { get() { return this.#x_1; }, set(value) { this.#x_1 = value; } }, ...)
			//  }
			//  ...
			//  #x_1 = 1;
			//  get #x() { return _private_x_descriptor.get.call(this); }
			//  set #x(value) { _private_x_descriptor.set.call(this, value); }

			final commentRange = ec.CommentRange(node);
			final sourceMapRange = ec.SourceMapRange(node);

			// Since we're creating two declarations where there was previously one, cache
			// the expression for any computed property names.
			final propName = node.Name();
			var getterName = result.name;
			var setterName = result.name;
			if (Ast.IsComputedPropertyName(propName) && !Transformers.IsSimpleInlineableExpression(propName.Expression())) {
				final cacheAssignment = Estransforms.findComputedPropertyNameCacheAssignment(ec, propName);
				if (cacheAssignment != null) {
					getterName = f.UpdateComputedPropertyName(propName.AsComputedPropertyName(), Visitor().VisitNode(propName.Expression()));
					setterName = f.UpdateComputedPropertyName(propName.AsComputedPropertyName(), cacheAssignment.Left);
				} else {
					final temp = f.NewTempVariable();
					ec.SetSourceMapRange(temp, propName.Expression().Loc);
					ec.AddVariableDeclaration(temp);
					final expression = Visitor().VisitNode(propName.Expression());
					final assignment = f.NewAssignmentExpression(temp, expression);
					ec.SetSourceMapRange(assignment, propName.Expression().Loc);
					getterName = f.UpdateComputedPropertyName(propName.AsComputedPropertyName(), assignment);
					setterName = f.UpdateComputedPropertyName(propName.AsComputedPropertyName(), temp);
				}
			}

			final modifiersWithoutAccessor = accessorStrippingModifierVisitor.VisitModifiers(result.modifiers);

			final backingField = Estransforms.createAccessorPropertyBackingField(f, node.AsPropertyDeclaration(), modifiersWithoutAccessor, initializer);
			ec.SetOriginal(backingField, node);
			ec.SetEmitFlags(backingField, EFNoComments);
			ec.SetSourceMapRange(backingField, sourceMapRange);
			ec.SetSourceMapRange(backingField.AsPropertyDeclaration().Name(), ec.SourceMapRange(node.Name()));

			final getter = createGetAccessorDescriptorForwarder(modifiersWithoutAccessor, getterName, result.descriptorName);
			ec.SetOriginal(getter, node);
			ec.SetCommentRange(getter, commentRange);
			ec.SetSourceMapRange(getter, sourceMapRange);

			final setter = createSetAccessorDescriptorForwarder(modifiersWithoutAccessor, setterName, result.descriptorName);
			ec.SetOriginal(setter, node);
			ec.SetEmitFlags(setter, EFNoComments);
			ec.SetSourceMapRange(setter, sourceMapRange);

			return Transformers.SingleOrMany([backingField, getter, setter], f);
		}

		final prop = node.AsPropertyDeclaration();
		return finishClassElement(f.UpdatePropertyDeclaration(prop, result.modifiers, result.name, null, null, initializer), node);
	}

	function visitThisExpression(node:Node):Node {
		if (classThis != null) {
			return classThis;
		}
		return node;
	}

	function visitCallExpression(node:Node):Node {
		final call = node.AsCallExpression();
		if (Ast.IsSuperProperty(call.Expression) && classThis != null) {
			final expression = Visitor().VisitNode(call.Expression);
			final argumentsList = Visitor().VisitNodes(call.Arguments);
			final invocation = Factory().NewFunctionCallCall(expression, classThis, argumentsList.Nodes);
			EmitContext().SetOriginal(invocation, node);
			invocation.Loc = node.Loc;
			return invocation;
		}
		return Visitor().VisitEachChild(node);
	}

	function visitTaggedTemplateExpression(node:Node):Node {
		final tte = node.AsTaggedTemplateExpression();
		if (Ast.IsSuperProperty(tte.Tag) && classThis != null) {
			final tag = Visitor().VisitNode(tte.Tag);
			final boundTag = Factory().NewFunctionBindCall(tag, classThis, []);
			EmitContext().SetOriginal(boundTag, node);
			boundTag.Loc = node.Loc;
			final template = Visitor().VisitNode(tte.Template);
			return Factory().UpdateTaggedTemplateExpression(tte, boundTag, null, null, template, tte.Flags);
		}
		return Visitor().VisitEachChild(node);
	}

	function visitPropertyAccessExpression(node:Node):Node {
		final pa = node.AsPropertyAccessExpression();
		if (Ast.IsSuperProperty(node) && Ast.IsIdentifier(pa.Name()) && classThis != null && classSuper != null) {
			final propertyName = Factory().NewStringLiteralFromNode(pa.Name());
			final superProperty = Factory().NewReflectGetCall(classSuper, propertyName, classThis);
			EmitContext().SetOriginal(superProperty, pa.Expression);
			superProperty.Loc = pa.Expression.Loc;
			return superProperty;
		}
		return Visitor().VisitEachChild(node);
	}

	function visitElementAccessExpression(node:Node):Node {
		final ea = node.AsElementAccessExpression();
		if (Ast.IsSuperProperty(node) && classThis != null && classSuper != null) {
			final propertyName = Visitor().VisitNode(ea.ArgumentExpression);
			final superProperty = Factory().NewReflectGetCall(classSuper, propertyName, classThis);
			EmitContext().SetOriginal(superProperty, ea.Expression);
			superProperty.Loc = ea.Expression.Loc;
			return superProperty;
		}
		return Visitor().VisitEachChild(node);
	}

	// 8.6.3 RS: IteratorBindingInitialization
	//
	//	SingleNameBinding : BindingIdentifier Initializer?
	//	  ...
	//	  5. If |Initializer| is present and _v_ is *undefined*, then
	//	     a. If IsAnonymousFunctionDefinition(|Initializer|) is *true*, then
	//	        i. Set _v_ to ? NamedEvaluation of |Initializer| with argument _bindingId_.
	//	  ...
	//
	// 14.3.3.3 RS: KeyedBindingInitialization
	//
	//	SingleNameBinding : BindingIdentifier Initializer?
	//	  ...
	//	  4. If |Initializer| is present and _v_ is *undefined*, then
	//	     a. If IsAnonymousFunctionDefinition(|Initializer|) is *true*, then
	//	        i. Set _v_ to ? NamedEvaluation of |Initializer| with argument _bindingId_.
	//	  ...
	function visitParameterDeclaration(node:ParameterDeclaration):Node {
		var paramNode = node.AsNode();
		if (Estransforms.isNamedEvaluationAnd(EmitContext(), paramNode, Estransforms.isAnonymousClassNeedingAssignedName)) {
			paramNode = Estransforms.transformNamedEvaluation(EmitContext(), paramNode,
				Estransforms.canIgnoreEmptyStringLiteralInAssignedName(paramNode.Initializer()), "");
			node = paramNode.AsParameterDeclaration();
		}

		final updated = Factory().UpdateParameterDeclaration(node, null, // modifiers - strip all modifiers (including decorators)
			node.DotDotDotToken, Visitor().VisitNode(node.Name()), null, // questionToken
			null, // type
			Visitor().VisitNode(node.Initializer));
		if (updated != paramNode) {
			// While we emit the source map for the node after skipping decorators and modifiers,
			// we need to emit the comments for the original range.
			EmitContext().SetCommentRange(updated, paramNode.Loc);
			final newLoc = Transformers.MoveRangePastModifiers(paramNode);
			updated.Loc = newLoc;
			EmitContext().SetSourceMapRange(updated, newLoc);
			EmitContext().SetEmitFlags(updated.Name(), EFNoTrailingSourceMap);
		}
		return updated;
	}

	// visitNamedEvaluationSite replaces Strada's visitPropertyAssignment, visitVariableDeclaration,
	// and visitBindingElement, which all share the same logic.
	//
	// 13.2.5.5 RS: PropertyDefinitionEvaluation (PropertyAssignment)
	//
	//	PropertyAssignment : PropertyName `:` AssignmentExpression
	//	  ...
	//	  5. If IsAnonymousFunctionDefinition(|AssignmentExpression|) is *true* and _isProtoSetter_ is *false*, then
	//	     a. Let _popValue_ be ? NamedEvaluation of |AssignmentExpression| with argument _propKey_.
	//	  ...
	//
	// 14.3.1.2 RS: Evaluation (VariableDeclaration)
	//
	//	LexicalBinding : BindingIdentifier Initializer
	//	  ...
	//	  3. If IsAnonymousFunctionDefinition(|Initializer|) is *true*, then
	//	     a. Let _value_ be ? NamedEvaluation of |Initializer| with argument _bindingId_.
	//	  ...
	//
	// 14.3.2.1 RS: Evaluation (VariableDeclaration)
	//
	//	VariableDeclaration : BindingIdentifier Initializer
	//	  ...
	//	  3. If IsAnonymousFunctionDefinition(|Initializer|) is *true*, then
	//	     a. Let _value_ be ? NamedEvaluation of |Initializer| with argument _bindingId_.
	//	  ...
	//
	// 8.6.3 RS: IteratorBindingInitialization (BindingElement)
	//
	//	SingleNameBinding : BindingIdentifier Initializer?
	//	  ...
	//	  5. If |Initializer| is present and _v_ is *undefined*, then
	//	     a. If IsAnonymousFunctionDefinition(|Initializer|) is *true*, then
	//	        i. Set _v_ to ? NamedEvaluation of |Initializer| with argument _bindingId_.
	//	  ...
	//
	// 14.3.3.3 RS: KeyedBindingInitialization (BindingElement)
	//
	//	SingleNameBinding : BindingIdentifier Initializer?
	//	  ...
	//	  4. If |Initializer| is present and _v_ is *undefined*, then
	//	     a. If IsAnonymousFunctionDefinition(|Initializer|) is *true*, then
	//	        i. Set _v_ to ? NamedEvaluation of |Initializer| with argument _bindingId_.
	//	  ...
	function visitNamedEvaluationSite(node:Node, classExpr:Node):Node {
		if (Estransforms.isNamedEvaluationAnd(EmitContext(), node, Estransforms.isAnonymousClassNeedingAssignedName)) {
			node = Estransforms.transformNamedEvaluation(EmitContext(), node, Estransforms.canIgnoreEmptyStringLiteralInAssignedName(classExpr), "");
		}
		return Visitor().VisitEachChild(node);
	}

	function visitForStatement(node:Node):Node {
		final f = Factory();
		final forStmt = node.AsForStatement();
		return f.UpdateForStatement(forStmt, discardedVisitor.VisitNode(forStmt.Initializer), Visitor().VisitNode(forStmt.Condition),
			discardedVisitor.VisitNode(forStmt.Incrementor), EmitContext().VisitIterationBody(forStmt.Statement, Visitor()));
	}

	function visitExpressionStatement(node:Node):Node {
		return discardedVisitor.VisitEachChild(node);
	}

	function visitBinaryExpression(node:Node, discarded:Bool):Node {
		final f = Factory();
		final ec = EmitContext();
		final bin = node.AsBinaryExpression();

		if (Ast.IsDestructuringAssignment(node)) {
			final left = visitAssignmentPattern(bin.Left);
			final right = Visitor().VisitNode(bin.Right);
			return f.UpdateBinaryExpression(bin, null, left, null, bin.OperatorToken, right);
		}

		if (Ast.IsAssignmentExpression(node, false)) {
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

			if (Estransforms.isNamedEvaluationAnd(ec, node, Estransforms.isAnonymousClassNeedingAssignedName)) {
				node = Estransforms.transformNamedEvaluation(ec, node, Estransforms.canIgnoreEmptyStringLiteralInAssignedName(bin.Right), "");
				return Visitor().VisitEachChild(node);
			}

			if (Ast.IsSuperProperty(bin.Left) && classThis != null && classSuper != null) {
				var setterName:Expression = null;
				if (Ast.IsElementAccessExpression(bin.Left)) {
					setterName = Visitor().VisitNode(bin.Left.AsElementAccessExpression().ArgumentExpression);
				} else if (Ast.IsPropertyAccessExpression(bin.Left) && Ast.IsIdentifier(bin.Left.AsPropertyAccessExpression().Name())) {
					setterName = f.NewStringLiteralFromNode(bin.Left.AsPropertyAccessExpression().Name());
				}
				if (setterName != null) {
					// super.x = ...
					// super.x += ...
					// super[x] = ...
					// super[x] += ...
					var expression = Visitor().VisitNode(bin.Right);
					if (Ast.IsCompoundAssignment(bin.OperatorToken.Kind)) {
						var getterName = setterName;
						if (!Transformers.IsSimpleInlineableExpression(setterName)) {
							getterName = f.NewTempVariable();
							ec.AddVariableDeclaration(getterName);
							setterName = f.NewAssignmentExpression(getterName, setterName);
						}
						final superPropertyGet = f.NewReflectGetCall(classSuper, getterName, classThis);
						ec.SetOriginal(superPropertyGet, bin.Left);
						superPropertyGet.Loc = bin.Left.Loc;
						expression = f.AsNodeFactory()
							.NewBinaryExpression(null, superPropertyGet, null,
								f.NewToken(Transformers.GetNonAssignmentOperatorForCompoundAssignment(bin.OperatorToken.Kind)), expression);
						expression.Loc = node.Loc;
					}
					var temp:Expression = null;
					if (!discarded) {
						temp = f.NewTempVariable();
						ec.AddVariableDeclaration(temp);
					}
					if (temp != null) {
						expression = f.NewAssignmentExpression(temp, expression);
						expression.Loc = node.Loc;
					}
					expression = f.NewReflectSetCall(classSuper, setterName, expression, classThis);
					ec.SetOriginal(expression, node);
					expression.Loc = node.Loc;
					if (temp != null) {
						expression = f.NewCommaExpression(expression, temp);
						expression.Loc = node.Loc;
					}
					return expression;
				}
			}
		}

		if (bin.OperatorToken.Kind == KindCommaToken) {
			final left = discardedVisitor.VisitNode(bin.Left);
			var right:Node = null;
			if (discarded) {
				right = discardedVisitor.VisitNode(bin.Right);
			} else {
				right = Visitor().VisitNode(bin.Right);
			}
			return f.UpdateBinaryExpression(bin, null, left, null, bin.OperatorToken, right);
		}

		return Visitor().VisitEachChild(node);
	}

	function visitPreOrPostfixUnaryExpression(node:Node, discarded:Bool):Node {
		final f = Factory();
		final ec = EmitContext();

		var operator_:Kind = KindUnknown;
		var operandNode:Node = null;
		if (Ast.IsPrefixUnaryExpression(node)) {
			operator_ = node.AsPrefixUnaryExpression().Operator;
			operandNode = node.AsPrefixUnaryExpression().Operand;
		} else {
			operator_ = node.AsPostfixUnaryExpression().Operator;
			operandNode = node.AsPostfixUnaryExpression().Operand;
		}

		if (operator_ == KindPlusPlusToken || operator_ == KindMinusMinusToken) {
			final operand = Ast.SkipParentheses(operandNode);
			if (Ast.IsSuperProperty(operand) && classThis != null && classSuper != null) {
				var setterName:Expression = null;
				if (Ast.IsElementAccessExpression(operand)) {
					setterName = Visitor().VisitNode(operand.AsElementAccessExpression().ArgumentExpression);
				} else if (Ast.IsPropertyAccessExpression(operand) && Ast.IsIdentifier(operand.AsPropertyAccessExpression().Name())) {
					setterName = f.NewStringLiteralFromNode(operand.AsPropertyAccessExpression().Name());
				}
				if (setterName != null) {
					var getterName = setterName;
					if (!Transformers.IsSimpleInlineableExpression(setterName)) {
						getterName = f.NewTempVariable();
						ec.AddVariableDeclaration(getterName);
						setterName = f.NewAssignmentExpression(getterName, setterName);
					}

					var expression = f.NewReflectGetCall(classSuper, getterName, classThis);
					ec.SetOriginal(expression, node);
					expression.Loc = node.Loc;

					// If the result of this expression is discarded (i.e., it's in a position where the result
					// will be otherwise unused, such as in an expression statement or the left side of a comma), we
					// don't need to create an extra temp variable to hold the result:
					//
					//  source (discarded):
					//    super.x++;
					//  generated:
					//    _a = Reflect.get(_super, "x"), _a++, Reflect.set(_super, "x", _a);
					//
					// Above, the temp variable `_a` is used to perform the correct coercion (i.e., number or
					// bigint). Since the result of the postfix unary is discarded, we don't need to capture the
					// result of the expression.
					//
					//  source (not discarded):
					//    y = super.x++;
					//  generated:
					//    y = (_a = Reflect.get(_super, "x"), _b = _a++, Reflect.set(_super, "x", _a), _b);
					//
					// When the result isn't discarded, we introduce a new temp variable (`_b`) to capture the
					// result of the operation so that we can provide it to `y` when the assignment is complete.
					var temp:IdentifierNode = null;
					if (!discarded) {
						temp = f.NewTempVariable();
						ec.AddVariableDeclaration(temp);
					}

					expression = Estransforms.expandPreOrPostfixIncrementOrDecrementExpression(f, ec, node, expression, temp);

					expression = f.NewReflectSetCall(classSuper, setterName, expression, classThis);
					ec.SetOriginal(expression, node);
					expression.Loc = node.Loc;

					if (temp != null) {
						expression = f.NewCommaExpression(expression, temp);
						expression.Loc = node.Loc;
					}

					return expression;
				}
			}
		}

		return Visitor().VisitEachChild(node);
	}

	function visitReferencedPropertyName(node:Node):Pair<Expression, Node> {
		if (Ast.IsPropertyNameLiteral(node) || Ast.IsPrivateIdentifier(node)) {
			return new Pair(Factory().NewStringLiteralFromNode(node), Visitor().VisitNode(node));
		}

		final cpn = node.AsComputedPropertyName();
		if (Ast.IsPropertyNameLiteral(cpn.Expression) && !Ast.IsIdentifier(cpn.Expression)) {
			return new Pair(Factory().NewStringLiteralFromNode(cpn.Expression), Visitor().VisitNode(node));
		}

		final referencedName = Factory().NewGeneratedNameForNode(node);
		EmitContext().AddVariableDeclaration(referencedName);

		final key = Factory().NewPropKeyHelper(Visitor().VisitNode(cpn.Expression));
		final assignment = Factory().NewAssignmentExpression(referencedName, key);
		final updatedName = Factory().UpdateComputedPropertyName(cpn, injectPendingExpressions(assignment));
		return new Pair(referencedName, updatedName);
	}

	function visitPropertyName(node:Node):Node {
		if (Ast.IsComputedPropertyName(node)) {
			return visitComputedPropertyName(node);
		}
		return Visitor().VisitNode(node);
	}

	function visitComputedPropertyName(node:Node):Node {
		final cpn = node.AsComputedPropertyName();
		var expression = Visitor().VisitNode(cpn.Expression);
		if (!Transformers.IsSimpleInlineableExpression(expression)) {
			expression = injectPendingExpressions(expression);
		}
		return Factory().UpdateComputedPropertyName(cpn, expression);
	}

	function visitDestructuringAssignmentTarget(node:Node):Node {
		if (Ast.IsObjectLiteralExpression(node) || Ast.IsArrayLiteralExpression(node)) {
			return visitAssignmentPattern(node);
		}

		if (Ast.IsSuperProperty(node) && classThis != null && classSuper != null) {
			final f = Factory();
			final ec = EmitContext();
			var propertyName:Expression = null;
			if (Ast.IsElementAccessExpression(node)) {
				propertyName = Visitor().VisitNode(node.AsElementAccessExpression().ArgumentExpression);
			} else if (Ast.IsPropertyAccessExpression(node) && Ast.IsIdentifier(node.AsPropertyAccessExpression().Name())) {
				propertyName = f.NewStringLiteralFromNode(node.AsPropertyAccessExpression().Name());
			}
			if (propertyName != null) {
				final paramName = f.NewTempVariable();
				final expression = f.NewAssignmentTargetWrapper(paramName, f.NewReflectSetCall(classSuper, propertyName, paramName, classThis));
				ec.SetOriginal(expression, node);
				expression.Loc = node.Loc;
				return expression;
			}
		}

		return Visitor().VisitEachChild(node);
	}

	function visitAssignmentElement(node:Node):Node {
		// 13.15.5.5 RS: IteratorDestructuringAssignmentEvaluation
		//   AssignmentElement : DestructuringAssignmentTarget Initializer?
		//     ...
		//     4. If |Initializer| is present and _value_ is *undefined*, then
		//        a. If IsAnonymousFunctionDefinition(|Initializer|) and IsIdentifierRef of |DestructuringAssignmentTarget| are both *true*, then
		//           i. Let _v_ be ? NamedEvaluation of |Initializer| with argument _lref_.[[ReferencedName]].
		//     ...
		if (Ast.IsAssignmentExpression(node, true /*excludeCompoundAssignment*/)) {
			final f = Factory();
			var bin = node.AsBinaryExpression();
			if (Estransforms.isNamedEvaluationAnd(EmitContext(), node, Estransforms.isAnonymousClassNeedingAssignedName)) {
				node = Estransforms.transformNamedEvaluation(EmitContext(), node, Estransforms.canIgnoreEmptyStringLiteralInAssignedName(bin.Right), "");
				bin = node.AsBinaryExpression();
			}
			final assignmentTarget = visitDestructuringAssignmentTarget(bin.Left);
			final initializer = Visitor().VisitNode(bin.Right);
			return f.UpdateBinaryExpression(bin, null, assignmentTarget, null, bin.OperatorToken, initializer);
		}
		return visitDestructuringAssignmentTarget(node);
	}

	function visitAssignmentRestElement(node:Node):Node {
		final se = node.AsSpreadElement();
		if (Ast.IsLeftHandSideExpression(se.Expression)) {
			final f = Factory();
			final expression = visitDestructuringAssignmentTarget(se.Expression);
			return f.UpdateSpreadElement(se, expression);
		}
		return Visitor().VisitEachChild(node);
	}

	function visitArrayAssignmentElement(node:Node):Node {
		Debug.Assert(Ast.IsArrayBindingOrAssignmentElement(node));
		if (Ast.IsSpreadElement(node)) {
			return visitAssignmentRestElement(node);
		}
		if (!Ast.IsOmittedExpression(node)) {
			return visitAssignmentElement(node);
		}
		return Visitor().VisitEachChild(node);
	}

	function visitAssignmentPropertyNode(node:Node):Node {
		// AssignmentProperty : PropertyName `:` AssignmentElement
		// AssignmentElement : DestructuringAssignmentTarget Initializer?

		// 13.15.5.6 RS: KeyedDestructuringAssignmentEvaluation
		//   AssignmentElement : DestructuringAssignmentTarget Initializer?
		//     ...
		//     3. If |Initializer| is present and _v_ is *undefined*, then
		//        a. If IsAnonymousfunctionDefinition(|Initializer|) and IsIdentifierRef of |DestructuringAssignmentTarget| are both *true*, then
		//           i. Let _rhsValue_ be ? NamedEvaluation of |Initializer| with argument _lref_.[[ReferencedName]].
		//     ...

		final f = Factory();
		final pa = node.AsPropertyAssignment();
		final name = Visitor().VisitNode(pa.Name());
		if (Ast.IsAssignmentExpression(pa.Initializer, true /*excludeCompoundAssignment*/)) {
			final assignmentElement = visitAssignmentElement(pa.Initializer);
			return f.UpdatePropertyAssignment(pa, null, name, null, null, assignmentElement);
		}
		if (Ast.IsLeftHandSideExpression(pa.Initializer)) {
			final assignmentElement = visitDestructuringAssignmentTarget(pa.Initializer);
			return f.UpdatePropertyAssignment(pa, null, name, null, null, assignmentElement);
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
		if (Estransforms.isNamedEvaluationAnd(EmitContext(), node, Estransforms.isAnonymousClassNeedingAssignedName)) {
			node = Estransforms.transformNamedEvaluation(EmitContext(), node,
				Estransforms.canIgnoreEmptyStringLiteralInAssignedName(node.AsShorthandPropertyAssignment().ObjectAssignmentInitializer), "");
		}
		return Visitor().VisitEachChild(node);
	}

	function visitAssignmentRestProperty(node:Node):Node {
		final sa = node.AsSpreadAssignment();
		if (Ast.IsLeftHandSideExpression(sa.Expression)) {
			final f = Factory();
			final expression = visitDestructuringAssignmentTarget(sa.Expression);
			return f.UpdateSpreadAssignment(sa, expression);
		}
		return Visitor().VisitEachChild(node);
	}

	function visitObjectAssignmentElement(node:Node):Node {
		Debug.Assert(Ast.IsObjectBindingOrAssignmentElement(node));
		if (Ast.IsSpreadAssignment(node)) {
			return visitAssignmentRestProperty(node);
		}
		if (Ast.IsShorthandPropertyAssignment(node)) {
			return visitShorthandAssignmentProperty(node);
		}
		if (Ast.IsPropertyAssignment(node)) {
			return visitAssignmentPropertyNode(node);
		}
		return Visitor().VisitEachChild(node);
	}

	function visitAssignmentPattern(node:Node):Node {
		final f = Factory();
		if (Ast.IsArrayLiteralExpression(node)) {
			final ale = node.AsArrayLiteralExpression();
			final elements = arrayAssignmentVisitor.VisitNodes(ale.Elements);
			return f.UpdateArrayLiteralExpression(ale, elements, ale.MultiLine);
		}
		final ole = node.AsObjectLiteralExpression();
		final properties = objectAssignmentVisitor.VisitNodes(ole.Properties);
		return f.UpdateObjectLiteralExpression(ole, properties, ole.MultiLine);
	}

	function visitExportAssignment(node:Node):Node {
		// 16.2.3.7 RS: Evaluation
		//   ExportDeclaration : `export` `default` AssignmentExpression `;`
		//     1. If IsAnonymousFunctionDefinition(|AssignmentExpression|) is *true*, then
		//        a. Let _value_ be ? NamedEvaluation of |AssignmentExpression| with argument `"default"`.
		//     ...
		return visitNamedEvaluationSite(node, node.Expression());
	}

	function visitParenthesizedExpression(node:Node, discarded:Bool):Node {
		// 8.4.5 RS: NamedEvaluation
		//   ParenthesizedExpression : `(` Expression `)`
		//     ...
		//     2. Return ? NamedEvaluation of |Expression| with argument _name_.

		final f = Factory();
		final pe = node.AsParenthesizedExpression();
		var expression:Node = null;
		if (discarded) {
			expression = discardedVisitor.VisitNode(pe.Expression);
		} else {
			expression = Visitor().VisitNode(pe.Expression);
		}
		return f.UpdateParenthesizedExpression(pe, expression);
	}

	function visitPartiallyEmittedExpression(node:Node, discarded:Bool):Node {
		// Emulates 8.4.5 RS: NamedEvaluation
		final pe = node.AsPartiallyEmittedExpression();
		var expression:Node = null;
		if (discarded) {
			expression = discardedVisitor.VisitNode(pe.Expression);
		} else {
			expression = Visitor().VisitNode(pe.Expression);
		}
		return Factory().UpdatePartiallyEmittedExpression(pe, expression);
	}

	// prependExpressions prepends a list of expressions before a target expression, preserving
	// parenthesization. If expression is nil, the pending expressions are inlined alone.
	function prependExpressions(pending:Array<Expression>, expression:Expression):Expression {
		final f = Factory();
		if (Core.len(pending) == 0) {
			return expression;
		}
		if (expression == null) {
			return f.InlineExpressions(pending);
		}
		if (Ast.IsParenthesizedExpression(expression)) {
			final pe = expression.AsParenthesizedExpression();
			final exprs:Array<Expression> = pending.copy();
			exprs.push(pe.Expression);
			return f.UpdateParenthesizedExpression(pe, f.InlineExpressions(exprs));
		}
		final exprs:Array<Expression> = pending.copy();
		exprs.push(expression);
		return f.InlineExpressions(exprs);
	}

	function injectPendingExpressions(expression:Expression):Expression {
		final result = prependExpressions(pendingExpressions, expression);
		Debug.Assert(result != null);
		if (result != expression) {
			pendingExpressions = null;
		}
		return result;
	}

	function injectPendingInitializers(ci:ClassInfo, isStatic:Bool, expression:Expression):Expression {
		// PORT: pointer — Go takes `&ci.pendingStaticInitializers` / `&ci.pendingInstanceInitializers`.
		final pending = isStatic ? ci.pendingStaticInitializers : ci.pendingInstanceInitializers;
		final result = prependExpressions(pending, expression);
		if (result != expression) {
			if (isStatic) {
				ci.pendingStaticInitializers = null;
			} else {
				ci.pendingInstanceInitializers = null;
			}
		}
		return result;
	}

	// Transforms all of the decorators for a declaration into an array of expressions.
	function transformAllDecoratorsOfDeclaration(decorators:Array<Node>):Array<Expression> {
		if (Core.len(decorators) == 0) {
			return null;
		}
		final result:Array<Expression> = [];
		for (d in decorators) {
			result.push(transformDecorator(d));
		}
		return result;
	}

	// Transforms a decorator into an expression.
	function transformDecorator(decorator:Node):Expression {
		final expression = Visitor().VisitNode(decorator.AsDecorator().Expression);
		EmitContext().SetEmitFlags(expression, EFNoComments);

		// preserve the 'this' binding for an access expression
		final innerExpression = Ast.SkipOuterExpressions(expression, OEKAll);
		if (Ast.IsAccessExpression(innerExpression)) {
			final binding = createCallBinding(expression);
			final target = binding.a;
			final thisArg = binding.b;
			final bindCall = Factory().NewFunctionBindCall(target, thisArg, null);
			return Factory().RestoreOuterExpressions(expression, bindCall, OEKAll);
		}
		return expression;
	}

	function createCallBinding(expression:Expression):Pair<Expression, Expression> {
		final f = Factory();
		final callee = Ast.SkipOuterExpressions(expression, OEKAll);
		if (Ast.IsSuperProperty(callee)) {
			return new Pair(callee, f.NewThisExpression());
		}
		if (callee.Kind == KindSuperKeyword) {
			return new Pair(callee, f.NewThisExpression());
		}
		if ((EmitContext().EmitFlags(callee) & EFHelperName) != 0) {
			return new Pair(callee, f.NewVoidZeroExpression());
		}
		if (Ast.IsPropertyAccessExpression(callee)) {
			final pa = callee.AsPropertyAccessExpression();
			if (shouldBeCapturedInTempVariable(pa.Expression)) {
				final thisArg = f.NewTempVariable();
				EmitContext().AddVariableDeclaration(thisArg);
				final assign = f.NewAssignmentExpression(thisArg, pa.Expression);
				assign.Loc = pa.Expression.Loc;
				final target = f.NewPropertyAccessExpression(assign, null, pa.Name(), NodeFlagsNone);
				target.Loc = callee.Loc;
				return new Pair(target, thisArg);
			}
			return new Pair(callee, pa.Expression);
		}
		if (Ast.IsElementAccessExpression(callee)) {
			final ea = callee.AsElementAccessExpression();
			if (shouldBeCapturedInTempVariable(ea.Expression)) {
				final thisArg = f.NewTempVariable();
				EmitContext().AddVariableDeclaration(thisArg);
				final assign = f.NewAssignmentExpression(thisArg, ea.Expression);
				assign.Loc = ea.Expression.Loc;
				final target = f.NewElementAccessExpression(assign, null, ea.ArgumentExpression, NodeFlagsNone);
				target.Loc = callee.Loc;
				return new Pair(target, thisArg);
			}
			return new Pair(callee, ea.Expression);
		}
		return new Pair(expression, f.NewVoidZeroExpression());
	}

	function shouldBeCapturedInTempVariable(node:Expression):Bool {
		// This is a simplified version of the general shouldBeCapturedInTempVariable from
		// nodeFactory with cacheIdentifiers=true, since createCallBinding in this transform
		// always caches identifiers.
		final target = Ast.SkipParentheses(node);
		switch (target.Kind) {
			case KindIdentifier:
				// cacheIdentifiers is always true for this transform's createCallBinding
				return true;
			case KindThisKeyword, KindNumericLiteral, KindBigIntLiteral, KindStringLiteral:
				return false;
			default:
				return true;
		}
	}

	// Creates a "value", "get", or "set" method for a pseudo-PropertyDescriptor object created for
	// a private element.
	function createDescriptorMethod(original:Node, name:Node, modifiers:ModifierList, asteriskToken:TokenNode, kind:std.String, parameters:NodeList,
			body:Node):Node {
		final f = Factory();
		final ec = EmitContext();

		if (body == null) {
			body = f.NewBlock(f.NewNodeList([]), false);
		}

		final funcExpr = f.NewFunctionExpression(modifiers, asteriskToken, null, // name
			null, // typeParameters
			parameters, null, // type
			null, // fullSignature
			body);
		ec.SetOriginal(funcExpr, original);
		ec.SetSourceMapRange(funcExpr, Transformers.MoveRangePastDecorators(original));
		ec.SetEmitFlags(funcExpr, EFNoComments);

		var prefix = "";
		if (kind == "get" || kind == "set") {
			prefix = kind;
		}
		final functionName = f.NewStringLiteralFromNode(name);
		final namedFunction = f.NewSetFunctionNameHelper(funcExpr, functionName, prefix);

		final method = f.NewPropertyAssignment(null, f.NewIdentifier(kind), null, null, namedFunction);
		ec.SetOriginal(method, original);
		ec.SetSourceMapRange(method, Transformers.MoveRangePastDecorators(original));
		ec.SetEmitFlags(method, EFNoComments);
		return method;
	}

	// Creates a pseudo-PropertyDescriptor object used when decorating a private MethodDeclaration.
	function createMethodDescriptorObject(member:Node, modifiers:ModifierList):Expression {
		final f = Factory();
		final parameters = Visitor().VisitNodes(member.ParameterList());
		final body = Visitor().VisitNode(member.Body());
		final method = member.AsMethodDeclaration();
		return f.NewObjectLiteralExpression(f.NewNodeList([
			createDescriptorMethod(member, member.Name(), modifiers, method.AsteriskToken, "value", parameters, body),
		]), false);
	}

	// Creates a pseudo-PropertyDescriptor object used when decorating a private GetAccessor.
	function createGetAccessorDescriptorObject(member:Node, modifiers:ModifierList):Expression {
		final f = Factory();
		final body = Visitor().VisitNode(member.Body());
		return f.NewObjectLiteralExpression(f.NewNodeList([
			createDescriptorMethod(member, member.Name(), modifiers, null, "get", f.NewNodeList([]), body),
		]), false);
	}

	// Creates a pseudo-PropertyDescriptor object used when decorating a private SetAccessor.
	function createSetAccessorDescriptorObject(member:Node, modifiers:ModifierList):Expression {
		final f = Factory();
		final parameters = Visitor().VisitNodes(member.ParameterList());
		final body = Visitor().VisitNode(member.Body());
		return f.NewObjectLiteralExpression(f.NewNodeList([
			createDescriptorMethod(member, member.Name(), modifiers, null, "set", parameters, body),
		]), false);
	}

	// Creates a pseudo-PropertyDescriptor object used when decorating a private auto-accessor PropertyDeclaration.
	// The descriptor contains get/set methods that access the generated backing field.
	function createAccessorPropertyDescriptorObject(member:Node, _:ModifierList):Expression {
		//  {
		//      get() { return this.${privateName}; },
		//      set(value) { this.${privateName} = value; },
		//  }
		final f = Factory();
		final backingFieldName = f.NewGeneratedPrivateNameForNodeEx(member.Name(), new AutoGenerateOptions(GeneratedIdentifierFlagsNone, "", "_accessor_storage"));
		return f.NewObjectLiteralExpression(f.NewNodeList([
			createDescriptorMethod(member, member.Name(), null, null, "get", f.NewNodeList([]),
				f.NewBlock(f.NewNodeList([
					f.NewReturnStatement(f.NewPropertyAccessExpression(f.NewThisExpression(), null, backingFieldName, NodeFlagsNone)),
				]), false)),
			createDescriptorMethod(member, member.Name(), null, null, "set",
				f.NewNodeList([f.NewParameterDeclaration(null, null, f.NewIdentifier("value"), null, null, null),]),
				f.NewBlock(f.NewNodeList([
					f.NewExpressionStatement(f.NewAssignmentExpression(f.NewPropertyAccessExpression(f.NewThisExpression(), null, backingFieldName, NodeFlagsNone),
						f.NewIdentifier("value"))),
				]), false)),
		]), false);
	}

	// Creates a MethodDeclaration that forwards its invocation to a PropertyDescriptor object.
	function createMethodDescriptorForwarder(modifiers:ModifierList, name:Node, descriptorName:IdentifierNode):Node {
		final f = Factory();
		final staticOnly = staticOnlyModifierVisitor.VisitModifiers(modifiers);
		return f.NewGetAccessorDeclaration(staticOnly, name, null, // typeParameters
			f.NewNodeList([]), null, // type
			null, // fullSignature
			f.NewBlock(f.NewNodeList([
				f.NewReturnStatement(f.NewPropertyAccessExpression(descriptorName, null, f.NewIdentifier("value"), NodeFlagsNone)),
			]), false));
	}

	// Creates a GetAccessor that forwards its invocation to a PropertyDescriptor object.
	function createGetAccessorDescriptorForwarder(modifiers:ModifierList, name:Node, descriptorName:IdentifierNode):Node {
		final f = Factory();
		final staticOnly = staticOnlyModifierVisitor.VisitModifiers(modifiers);
		return f.NewGetAccessorDeclaration(staticOnly, name, null, // typeParameters
			f.NewNodeList([]), null, // type
			null, // fullSignature
			f.NewBlock(f.NewNodeList([
				f.NewReturnStatement(f.NewFunctionCallCall(f.NewPropertyAccessExpression(descriptorName, null, f.NewIdentifier("get"), NodeFlagsNone),
					f.NewThisExpression(), null)),
			]), false));
	}

	// Creates a SetAccessor that forwards its invocation to a PropertyDescriptor object.
	function createSetAccessorDescriptorForwarder(modifiers:ModifierList, name:Node, descriptorName:IdentifierNode):Node {
		final f = Factory();
		final staticOnly = staticOnlyModifierVisitor.VisitModifiers(modifiers);
		return f.NewSetAccessorDeclaration(staticOnly, name, null, // typeParameters
			f.NewNodeList([f.NewParameterDeclaration(null, null, f.NewIdentifier("value"), null, null, null),]), null, // type
			null, // fullSignature
			f.NewBlock(f.NewNodeList([
				f.NewReturnStatement(f.NewFunctionCallCall(f.NewPropertyAccessExpression(descriptorName, null, f.NewIdentifier("set"), NodeFlagsNone),
					f.NewThisExpression(), [f.NewIdentifier("value")])),
			]), false));
	}

	function createMetadata(name:IdentifierNode, classSuper:IdentifierNode):Statement {
		final f = Factory();

		var superMetadata:Expression = null;
		if (classSuper != null) {
			superMetadata = createSymbolMetadataReference(classSuper);
		} else {
			superMetadata = f.NewToken(KindNullKeyword);
		}

		final objectCreate = f.NewCallExpression(f.NewPropertyAccessExpression(f.NewIdentifier("Object"), null, f.NewIdentifier("create"), NodeFlagsNone), null,
			null, f.NewNodeList([superMetadata]), NodeFlagsNone);

		final symbolCheck = f.NewLogicalANDExpression(f.NewTypeCheck(f.NewIdentifier("Symbol"), "function"),
			f.NewPropertyAccessExpression(f.NewIdentifier("Symbol"), null, f.NewIdentifier("metadata"), NodeFlagsNone));

		final conditional = f.NewConditionalExpression(symbolCheck, f.NewToken(KindQuestionToken), objectCreate, f.NewToken(KindColonToken),
			f.NewVoidZeroExpression());

		final varDecl = f.NewVariableDeclaration(name, null, null, conditional);
		final varDeclList = f.NewVariableDeclarationList(f.NewNodeList([varDecl]), NodeFlagsConst);
		return f.NewVariableStatement(null, varDeclList);
	}

	function createSymbolMetadata(target:Expression, value:IdentifierNode):Statement {
		final f = Factory();

		// Object.defineProperty(target, Symbol.metadata, { configurable: true, writable: true, enumerable: true, value })
		final symbolMetadata = f.NewPropertyAccessExpression(f.NewIdentifier("Symbol"), null, f.NewIdentifier("metadata"), NodeFlagsNone);

		final descriptorProps:Array<Node> = [
			f.NewPropertyAssignment(null, f.NewIdentifier("enumerable"), null, null, f.NewTrueExpression()),
			f.NewPropertyAssignment(null, f.NewIdentifier("configurable"), null, null, f.NewTrueExpression()),
			f.NewPropertyAssignment(null, f.NewIdentifier("writable"), null, null, f.NewTrueExpression()),
			f.NewPropertyAssignment(null, f.NewIdentifier("value"), null, null, value),
		];
		final descriptor = f.NewObjectLiteralExpression(f.NewNodeList(descriptorProps), false);

		final defineProperty = f.NewCallExpression(f.NewPropertyAccessExpression(f.NewIdentifier("Object"), null, f.NewIdentifier("defineProperty"),
			NodeFlagsNone), null, null, f.NewNodeList([target, symbolMetadata, descriptor]), NodeFlagsNone);

		final ifStatement = f.NewIfStatement(value, f.NewExpressionStatement(defineProperty), null);
		EmitContext().SetEmitFlags(ifStatement, EFSingleLine);
		return ifStatement;
	}

	function createSymbolMetadataReference(classSuper:IdentifierNode):Expression {
		final f = Factory();
		final symbolMetadata = f.NewPropertyAccessExpression(f.NewIdentifier("Symbol"), null, f.NewIdentifier("metadata"), NodeFlagsNone);
		final elementAccess = f.NewElementAccessExpression(classSuper, null, symbolMetadata, NodeFlagsNone);
		return f.NewBinaryExpression(null, elementAccess, null, f.NewToken(KindQuestionQuestionToken), f.NewToken(KindNullKeyword));
	}
}


@:allow(ts.transformers.estransforms)
class PartialResult {
	var modifiers:ModifierList = null;
	var referencedName:Expression = null;
	var name:Node = null;
	var initializersName:IdentifierNode = null;
	var extraInitializersName:IdentifierNode = null;
	var descriptorName:IdentifierNode = null;
	var thisArg:IdentifierNode = null;

	public function new() {}
}

typedef CreateDescriptorFunc = (member:Node, modifiers:ModifierList) -> Expression;

