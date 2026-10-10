package ts.transformers.tstransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/tstransforms/legacydecorators.go (upstream v7.0.2).
// Ported from internal/transformers/tstransforms/legacydecorators.go (upstream v7.0.2).

@:allow(ts.transformers.tstransforms)
class LegacyDecoratorsTransformer {
	// PORT: Go `range` over a possibly-nil slice (parser lists of zero elements have nil Nodes).
	static inline function rangeOf<T>(a:Null<Array<T>>):Array<T> {
		return a == null ? [] : a;
	}

	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var languageVersion:ScriptTarget = 0;
	var referenceResolver:ReferenceResolver = null;
	/**
		 * A map that keeps track of aliases created for classes with decorators to avoid issues
		 * with the double-binding behavior of classes.
		 */
	var classAliases:IdentityMap<Node, Node> = null;
	var enclosingClasses:Array<ClassDeclaration> = null;

	public function new() {}

	// PORT: promoted methods of embedded transformers.Transformer
	inline function EmitContext():ts.printer.Emitcontext.EmitContext return Transformer.EmitContext();

	inline function Factory():ts.printer.Factory.NodeFactory return Transformer.Factory();

	inline function Visitor():NodeVisitor return Transformer.Visitor();

	function visit(node:Node):Node {
		// we have to visit all identifiers in classes, just in case they require substitution
		if ((node.SubtreeFacts() & SubtreeContainsDecorators) == 0 && Core.len(enclosingClasses) == 0) {
			return node;
		}

		switch (node.Kind) {
			case KindIdentifier:
				return visitIdentifier(node.AsIdentifier());
			case KindPropertyAccessExpression:
				return visitPropertyAccessExpression(node.AsPropertyAccessExpression());
			case KindDecorator:
				// Decorators are elided. They will be emitted as part of `visitClassDeclaration`.
				return null;
			case KindClassDeclaration:
				return visitClassDeclaration(node.AsClassDeclaration());
			case KindClassExpression:
				return visitClassExpression(node.AsClassExpression());
			case KindConstructor:
				return visitConstructorDeclaration(node.AsConstructorDeclaration());
			case KindMethodDeclaration:
				return visitMethodDeclaration(node.AsMethodDeclaration());
			case KindSetAccessor:
				return visitSetAccessorDeclaration(node.AsSetAccessorDeclaration());
			case KindGetAccessor:
				return visitGetAccessorDeclaration(node.AsGetAccessorDeclaration());
			case KindPropertyDeclaration:
				return visitPropertyDeclaration(node.AsPropertyDeclaration());
			case KindParameter:
				return visitParamerDeclaration(node.AsParameterDeclaration());
			case KindSourceFile:
				classAliases = new IdentityMap<Node, Node>();
				enclosingClasses = null;
				final result = Visitor().VisitEachChild(node);
				EmitContext().AddEmitHelper(result, ...Core.Coalesce(EmitContext().ReadEmitHelpers(), [])); // PORT: spread of a nil slice is an empty variadic call
				classAliases = null;
				enclosingClasses = null;
				return result;
			default:
				return Visitor().VisitEachChild(node);
		}
	}

	function visitIdentifier(node:Identifier):Node {
		// takes the place of `substituteIdentifier` in the strada transform
		if (enclosingClasses != null) {
			for (d in enclosingClasses) {
				// PORT: a Go nil map read is ok=false; guard the Haxe null map.
				if (classAliases != null && classAliases.exists(d.AsNode())
					&& referenceResolver.GetReferencedValueDeclaration(EmitContext().MostOriginal(node.AsNode())) == EmitContext().MostOriginal(d.AsNode())) {
					return classAliases.get(d.AsNode());
				}
			}
		}
		return node.AsNode();
	}

	function visitPropertyAccessExpression(node:PropertyAccessExpression):Node {
		// Visit the expression but not the name, since property access names should not be substituted.
		// Strada's onSubstituteNode only fires for EmitHint.Expression, which excludes the
		// .name of PropertyAccessExpression.
		final expression = Visitor().VisitNode(node.Expression);
		if (expression != node.Expression) {
			return Factory().UpdatePropertyAccessExpression(node, expression, node.QuestionDotToken, node.Name(), node.Flags);
		}
		return node.AsNode();
	}

	function finishClassElement(updated:Node, original:Node):Node {
		if (updated != original) {
			// While we emit the source map for the node after skipping decorators and modifiers,
			// we need to emit the comments for the original range.
			EmitContext().SetCommentRange(updated, original.Loc);
			EmitContext().SetSourceMapRange(updated, Transformers.MoveRangePastModifiers(original));
		}
		return updated;
	}

	function visitParamerDeclaration(node:ParameterDeclaration):Node {
		final updated = Factory().UpdateParameterDeclaration(node, Tstransforms.elideModifiers(Factory(), node.Modifiers()), node.DotDotDotToken,
			Visitor().VisitNode(node.Name()), null, null, Visitor().VisitNode(node.Initializer));
		if (updated != node.AsNode()) {
			// While we emit the source map for the node after skipping decorators and modifiers,
			// we need to emit the comments for the original range.
			EmitContext().SetCommentRange(updated, node.Loc);
			final newLoc = Transformers.MoveRangePastModifiers(node.AsNode());
			updated.Loc = newLoc;
			EmitContext().SetSourceMapRange(updated, newLoc);
			EmitContext().SetEmitFlags(updated.Name(), EFNoTrailingSourceMap);
		}
		return updated;
	}

	// visitPropertyNameOfClassElement visits the property name of a class element,
	// for use when emitting property initializers. For a computed property on a node
	// with decorators, a temporary value is stored for later use.
	function visitPropertyNameOfClassElement(member:Node):Node {
		final name = member.Name();
		if (Ast.IsComputedPropertyName(name) && Ast.HasDecorators(member)) {
			final expression = Visitor().VisitNode(name.AsComputedPropertyName().Expression);
			final innerExpression = Ast.SkipPartiallyEmittedExpressions(expression);
			if (!Transformers.IsSimpleInlineableExpression(innerExpression)) {
				final generatedName = Factory().NewGeneratedNameForNode(name);
				EmitContext().AddVariableDeclaration(generatedName);
				return Factory().UpdateComputedPropertyName(name.AsComputedPropertyName(), Factory().NewAssignmentExpression(generatedName.AsNode(), expression));
			}
		}
		return Visitor().VisitNode(name);
	}

	function visitPropertyDeclaration(node:PropertyDeclaration):Node {
		if ((node.Flags & NodeFlagsAmbient) != 0) {
			return null;
		}
		if (Ast.HasSyntacticModifier(node.AsNode(), ModifierFlagsAmbient | ModifierFlagsAbstract)) {
			return null;
		}

		return finishClassElement(Factory().UpdatePropertyDeclaration(node, Visitor().VisitModifiers(node.Modifiers()),
			visitPropertyNameOfClassElement(node.AsNode()), null, null, Visitor().VisitNode(node.Initializer)),
			node.AsNode());
	}

	function visitGetAccessorDeclaration(node:GetAccessorDeclaration):Node {
		return finishClassElement(Factory().UpdateGetAccessorDeclaration(node, Visitor().VisitModifiers(node.Modifiers()),
			visitPropertyNameOfClassElement(node.AsNode()), null, Visitor().VisitNodes(node.Parameters), null, null, Visitor().VisitNode(node.Body)),
			node.AsNode());
	}

	function visitSetAccessorDeclaration(node:SetAccessorDeclaration):Node {
		return finishClassElement(Factory().UpdateSetAccessorDeclaration(node, Visitor().VisitModifiers(node.Modifiers()),
			visitPropertyNameOfClassElement(node.AsNode()), null, Visitor().VisitNodes(node.Parameters), null, null, Visitor().VisitNode(node.Body)),
			node.AsNode());
	}

	function visitMethodDeclaration(node:MethodDeclaration):Node {
		return finishClassElement(Factory().UpdateMethodDeclaration(node, Visitor().VisitModifiers(node.Modifiers()), node.AsteriskToken,
			visitPropertyNameOfClassElement(node.AsNode()), null, null, Visitor().VisitNodes(node.Parameters), null, null,
			Visitor().VisitNode(node.Body)),
			node.AsNode());
	}

	function visitConstructorDeclaration(node:ConstructorDeclaration):Node {
		return Factory().UpdateConstructorDeclaration(node, Visitor().VisitModifiers(node.Modifiers()), null, Visitor().VisitNodes(node.Parameters), null,
			null, Visitor().VisitNode(node.Body));
	}

	function visitClassExpression(node:ClassExpression):Node {
		// Legacy decorators were not supported on class expressions
		return Factory().UpdateClassExpression(node, Visitor().VisitModifiers(node.Modifiers()), node.Name(), null, Visitor().VisitNodes(node.HeritageClauses),
			Visitor().VisitNodes(node.Members));
	}

	function visitClassDeclaration(node:ClassDeclaration):Node {
		final decorated = Ast.ClassOrConstructorParameterIsDecorated(true, node.AsNode());
		if (!(decorated || Ast.ChildIsDecorated(true, node.AsNode(), null))) {
			return Visitor().VisitEachChild(node.AsNode());
		}

		if (decorated) {
			return transformClassDeclarationWithClassDecorators(node, node.Name());
		}
		return transformClassDeclarationWithoutClassDecorators(node, node.Name());
	}

	/**
	* Transforms a non-decorated class declaration.
	*
	* @param node A ClassDeclaration node.
	* @param name The name of the class.
	 */
	function transformClassDeclarationWithoutClassDecorators(node:ClassDeclaration, name:DeclarationName):Node {
		//  ${modifiers} class ${name} ${heritageClauses} {
		//      ${members}
		//  }
		final modifiers = Visitor().VisitModifiers(node.Modifiers());
		final heritageClauses = Visitor().VisitNodes(node.HeritageClauses);
		final initialMembers = Visitor().VisitNodes(node.Members);
		final r = transformDecoratorsOfClassElements(node, initialMembers);
		final members = r.a;
		final decorationStatements = r.b;

		if (name == null && Core.len(decorationStatements) > 0) {
			name = Factory().NewGeneratedNameForNode(node.AsNode());
		}

		final updated = Factory().UpdateClassDeclaration(node, modifiers, name, null, heritageClauses, members);

		if (Core.len(decorationStatements) == 0) {
			return updated;
		}
		final list:Array<Node> = [updated];
		for (s in decorationStatements)
			list.push(s);
		return Factory().NewSyntaxList(list);
	}

	function popEnclosingClass():Void {
		enclosingClasses.pop();
	}

	function pushEnclosingClass(cls:ClassDeclaration):Void {
		if (enclosingClasses == null) {
			enclosingClasses = [];
		}
		enclosingClasses.push(cls);
	}

	/**
	* Transforms a decorated class declaration and appends the resulting statements. If
	* the class requires an alias to avoid issues with double-binding, the alias is returned.
	 */
	function transformClassDeclarationWithClassDecorators(node:ClassDeclaration, name:DeclarationName):Node {
		// When we emit an ES6 class that has a class decorator, we must tailor the
		// emit to certain specific cases.
		//
		// In the simplest case, we emit the class declaration as a let declaration, and
		// evaluate decorators after the close of the class body:
		//
		//  [Example 1]
		//  ---------------------------------------------------------------------
		//  TypeScript                      | Javascript
		//  ---------------------------------------------------------------------
		//  @dec                            | let C = class C {
		//  class C {                       | }
		//  }                               | C = __decorate([dec], C);
		//  ---------------------------------------------------------------------
		//  @dec                            | let C = class C {
		//  export class C {                | }
		//  }                               | C = __decorate([dec], C);
		//                                  | export { C };
		//  ---------------------------------------------------------------------
		//
		// If a class declaration contains a reference to itself *inside* of the class body,
		// this introduces two bindings to the class: One outside of the class body, and one
		// inside of the class body. If we apply decorators as in [Example 1] above, there
		// is the possibility that the decorator `dec` will return a new value for the
		// constructor, which would result in the binding inside of the class no longer
		// pointing to the same reference as the binding outside of the class.
		//
		// As a result, we must instead rewrite all references to the class *inside* of the
		// class body to instead point to a local temporary alias for the class:
		//
		//  [Example 2]
		//  ---------------------------------------------------------------------
		//  TypeScript                      | Javascript
		//  ---------------------------------------------------------------------
		//  @dec                            | let C = C_1 = class C {
		//  class C {                       |   static x() { return C_1.y; }
		//    static x() { return C.y; }    | }
		//    static y = 1;                 | C.y = 1;
		//  }                               | C = C_1 = __decorate([dec], C);
		//                                  | var C_1;
		//  ---------------------------------------------------------------------
		//  @dec                            | let C = class C {
		//  export class C {                |   static x() { return C_1.y; }
		//    static x() { return C.y; }    | }
		//    static y = 1;                 | C.y = 1;
		//  }                               | C = C_1 = __decorate([dec], C);
		//                                  | export { C };
		//                                  | var C_1;
		//  ---------------------------------------------------------------------
		//
		// If a class declaration is the default export of a module, we instead emit
		// the export after the decorated declaration:
		//
		//  [Example 3]
		//  ---------------------------------------------------------------------
		//  TypeScript                      | Javascript
		//  ---------------------------------------------------------------------
		//  @dec                            | let default_1 = class {
		//  export default class {          | }
		//  }                               | default_1 = __decorate([dec], default_1);
		//                                  | export default default_1;
		//  ---------------------------------------------------------------------
		//  @dec                            | let C = class C {
		//  export default class C {        | }
		//  }                               | C = __decorate([dec], C);
		//                                  | export default C;
		//  ---------------------------------------------------------------------
		//
		// If the class declaration is the default export and a reference to itself
		// inside of the class body, we must emit both an alias for the class *and*
		// move the export after the declaration:
		//
		//  [Example 4]
		//  ---------------------------------------------------------------------
		//  TypeScript                      | Javascript
		//  ---------------------------------------------------------------------
		//  @dec                            | let C = class C {
		//  export default class C {        |   static x() { return C_1.y; }
		//    static x() { return C.y; }    | }
		//    static y = 1;                 | C.y = 1;
		//  }                               | C = C_1 = __decorate([dec], C);
		//                                  | export default C;
		//                                  | var C_1;
		//  ---------------------------------------------------------------------
		//

		final isExport = Ast.HasSyntacticModifier(node.AsNode(), ModifierFlagsExport);
		final isDefault = Ast.HasSyntacticModifier(node.AsNode(), ModifierFlagsDefault);
		var modifiers:ModifierList = null;
		if (node.Modifiers() != null && Core.len(node.Modifiers().Nodes) > 0) {
			final modifierNodes = Core.Filter(node.Modifiers().Nodes, Tstransforms.isNotExportOrDefaultOrDecorator);
			if (Core.len(modifierNodes) != Core.len(node.Modifiers().Nodes)) {
				modifiers = Factory().NewModifierList(modifierNodes);
				modifiers.Loc = node.Modifiers().Loc;
			} else {
				modifiers = node.Modifiers();
			}
		}

		final location = Transformers.MoveRangePastModifiers(node.AsNode());
		final classAlias = getClassAliasIfNeeded(node);
		if (classAlias != null) {
			pushEnclosingClass(node);
		}

		// When we used to transform to ES5/3 this would be moved inside an IIFE and should reference the name
		// without any block-scoped variable collision handling - but we don't support that anymore, so we always
		// use the local name for the class
		final declName = Factory().GetLocalNameEx(node.AsNode(), new AssignedNameOptions(false, true));

		//  ... = class ${name} ${heritageClauses} {
		//      ${members}
		//  }
		final heritageClauses = Visitor().VisitNodes(node.HeritageClauses);
		var members = Visitor().VisitNodes(node.Members);

		final r = transformDecoratorsOfClassElements(node, members);
		members = r.a;
		final decorationStatements = r.b;

		// If we're emitting to ES2022 or later then we need to reassign the class alias before
		// static initializers are evaluated.
		final assignClassAliasInStaticBlock = (languageVersion : Int) >= (ScriptTargetES2022 : Int) && classAlias != null && members != null
			&& Core.len(members.Nodes) > 0 && Core.Some(members.Nodes, Tstransforms.isClassStaticBlockDeclarationOrStaticProperty);
		if (assignClassAliasInStaticBlock) {
			final memberList:Array<Node> = [];
			memberList.push(Factory().NewClassStaticBlockDeclaration(null,
				Factory().NewBlock(Factory().NewNodeList([
					Factory().NewExpressionStatement(Factory().NewAssignmentExpression(classAlias, Factory().NewKeywordExpression(KindThisKeyword)))
				]), false)));
			for (m in rangeOf(members.Nodes))
				memberList.push(m);
			final newList = Factory().NewNodeList(memberList);
			newList.Loc = members.Loc;
			members = newList;
		}

		var exprName = name;
		if (name != null && Transformers.IsGeneratedIdentifier(EmitContext(), name)) {
			exprName = null;
		}
		final classExpression = Factory().NewClassExpression(modifiers, exprName, null, heritageClauses, members);

		EmitContext().SetOriginal(classExpression, node.AsNode());
		classExpression.Loc = location;

		//  let ${name} = ${classExpression} where name is either declaredName if the class doesn't contain self-reference
		//                                         or decoratedClassAlias if the class contain self-reference.
		var varInitializer = classExpression;
		if (classAlias != null && !assignClassAliasInStaticBlock) {
			varInitializer = Factory().NewAssignmentExpression(classAlias, classExpression);
		}
		final varDecl = Factory().NewVariableDeclaration(declName, null, null, varInitializer);
		EmitContext().SetOriginal(varDecl, node.AsNode());

		final varDeclList = Factory().NewVariableDeclarationList(Factory().NewNodeList([varDecl]), NodeFlagsLet);
		final varStatement = Factory().NewVariableStatement(null, varDeclList);
		EmitContext().SetOriginal(varStatement, node.AsNode());
		varStatement.Loc = location;
		EmitContext().SetCommentRange(varStatement, node.Loc);

		final statements:Array<Node> = [varStatement];
		if (decorationStatements != null) {
			for (s in decorationStatements)
				statements.push(s);
		}
		statements.push(getConstructorDecorationStatement(node));

		if (isExport) {
			var exportStatement:Node = null;
			if (isDefault) {
				exportStatement = Factory().NewExportDefault(declName);
			} else {
				exportStatement = Factory().NewExternalModuleExport(Factory().GetDeclarationName(node.AsNode()));
			}
			statements.push(exportStatement);
		}

		// PORT: defer popEnclosingClass() (registered when classAlias != nil) runs after the result is built.
		final result = if (statements.length == 1) statements[0] else Factory().NewSyntaxList(statements);
		if (classAlias != null) {
			popEnclosingClass();
		}
		return result;
	}

	function hasInternalStaticReference(node:ClassDeclaration):Bool {
		final classNode = EmitContext().MostOriginal(node.AsNode());
		var isOrContainsStaticSelfReference:(n:Node) -> Bool = null;
		isOrContainsStaticSelfReference = function(n:Node):Bool {
			if (Ast.IsIdentifier(n) && referenceResolver.GetReferencedValueDeclaration(EmitContext().MostOriginal(n)) == classNode) {
				return true;
			}
			// For PropertyAccessExpression, only check the expression, not the name.
			// The .Name() is a property access name, not a value reference to the class.
			if (Ast.IsPropertyAccessExpression(n)) {
				return isOrContainsStaticSelfReference(n.Expression());
			}
			return n.ForEachChild(isOrContainsStaticSelfReference);
		};
		for (member in rangeOf(node.Members.Nodes)) {
			if (member.ForEachChild(isOrContainsStaticSelfReference)) {
				return true;
			}
		}
		return false;
	}

	/**
	* Gets a local alias for a class declaration if it is a decorated class with an internal
	* reference to the static side of the class. This is necessary to avoid issues with
	* double-binding semantics for the class name.
	 */
	function getClassAliasIfNeeded(node:ClassDeclaration):Node {
		if (!hasInternalStaticReference(node)) {
			return null;
		}
		var nameText = "default";
		if (node.Name() != null && !Transformers.IsGeneratedIdentifier(EmitContext(), node.Name())) {
			nameText = node.Name().Text();
		}

		final classAlias = Factory().NewUniqueName(nameText);
		EmitContext().AddVariableDeclaration(classAlias);
		classAliases.set(node.AsNode(), classAlias);

		return classAlias;
	}

	/**
	* Generates a __decorate helper call for a class constructor.
	*
	* @param node The class node.
	 */
	function getConstructorDecorationStatement(node:ClassDeclaration):Node {
		final expression = generateConstructorDecorationExpression(node);
		if (expression != null) {
			final result = Factory().NewExpressionStatement(expression);
			EmitContext().SetOriginal(result, node.AsNode());
			return result;
		}
		return null;
	}

	/**
	* Generates a __decorate helper call for a class constructor.
	*
	* @param node The class node.
	 */
	function generateConstructorDecorationExpression(node:ClassDeclaration):Node {
		final allDecorators = Tstransforms.getAllDecoratorsOfClass(node, true);
		// Decorator expressions are evaluated outside the class body, so references to the
		// class name should use the original binding, not the class alias. In Strada, this is
		// handled by NodeCheckFlags.ConstructorReference which is only set for identifiers
		// inside the class body. Since Corsa lacks per-node flags, we temporarily pop the
		// enclosing class to prevent alias substitution during decorator expression visiting.
		final hasAlias = Core.len(enclosingClasses) > 0 && enclosingClasses[enclosingClasses.length - 1] == node;
		if (hasAlias) {
			popEnclosingClass();
		}
		final decoratorExpressions = transformAllDecoratorsOfDeclaration(allDecorators);
		if (hasAlias) {
			pushEnclosingClass(node);
		}
		if (Core.len(decoratorExpressions) == 0) {
			return null;
		}

		var classAlias:Node = null;
		if (classAliases != null) {
			classAlias = classAliases.get(node.AsNode());
		}

		// When we used to transform to ES5/3 this would be moved inside an IIFE and should reference the name
		// without any block-scoped variable collision handling - but we don't support that anymore, so we always
		// use the local name for the class
		final localName = Factory().GetDeclarationNameEx(node.AsNode(), new NameOptions(false, true));
		final decorate = Factory().NewDecorateHelper(decoratorExpressions, localName, null, null);
		var assignmentTarget = decorate;
		if (classAlias != null) {
			assignmentTarget = Factory().NewAssignmentExpression(classAlias, decorate);
		}
		final expression = Factory().NewAssignmentExpression(localName, assignmentTarget);
		EmitContext().SetEmitFlags(expression, EFNoComments);
		EmitContext().SetSourceMapRange(expression, Transformers.MoveRangePastModifiers(node.AsNode()));
		return expression;
	}

	function transformDecoratorsOfClassElements(node:ClassDeclaration, members:NodeList):Pair<NodeList, Array<Node>> {
		var decorationStatements:Array<Node> = null;
		final s1 = getClassElementDecorationStatements(node, false);
		final s2 = getClassElementDecorationStatements(node, true);
		if (s1 != null) {
			for (s in s1) {
				if (decorationStatements == null)
					decorationStatements = [];
				decorationStatements.push(s);
			}
		}
		if (s2 != null) {
			for (s in s2) {
				if (decorationStatements == null)
					decorationStatements = [];
				decorationStatements.push(s);
			}
		}
		if (Tstransforms.hasClassElementWithDecoratorContainingPrivateIdentifierInExpression(node)) {
			var memberNodes:Array<Node> = null;
			if (members != null && Core.len(members.Nodes) > 0) {
				memberNodes = members.Nodes;
			}
			final list:Array<Node> = memberNodes == null ? [] : memberNodes.copy();
			list.push(Factory().NewClassStaticBlockDeclaration(null, Factory().NewBlock(Factory().NewNodeList(decorationStatements), true)));
			members = Factory().NewNodeList(list);
			decorationStatements = null;
		}

		return new Pair(members, decorationStatements);
	}

	/**
	* Generates statements used to apply decorators to either the static or instance members
	* of a class.
	*
	* @param node The class node.
	* @param isStatic A value indicating whether to generate statements for static or
	*                 instance members.
	 */
	function getClassElementDecorationStatements(node:ClassDeclaration, isStatic:Bool):Array<Node> {
		final exprs = generateClassElementDecorationExpressions(node, isStatic);
		var statements:Array<Node> = null;
		if (exprs != null) {
			for (e in exprs) {
				if (statements == null)
					statements = [];
				statements.push(Factory().NewExpressionStatement(e));
			}
		}
		return statements;
	}

	/**
	* Generates expressions used to apply decorators to either the static or instance members
	* of a class.
	*
	* @param node The class node.
	* @param isStatic A value indicating whether to generate expressions for static or
	*                 instance members.
	 */
	function generateClassElementDecorationExpressions(node:ClassDeclaration, isStatic:Bool):Array<Node> {
		final members = Tstransforms.getDecoratedClassElements(node, isStatic);
		var expressions:Array<Node> = null;
		if (members != null) {
			for (member in members) {
				final expr = generateClassElementDecorationExpression(node, member);
				if (expr != null) {
					if (expressions == null)
						expressions = [];
					expressions.push(expr);
				}
			}
		}
		return expressions;
	}

	/**
	* Generates an expression used to evaluate class element decorators at runtime.
	*
	* @param node The class node that contains the member.
	* @param member The class member.
	 */
	function generateClassElementDecorationExpression(node:ClassDeclaration, member:Node):Node {
		final allDecorators = Tstransforms.getAllDecoratorsOfClassElement(member, node, true);
		final decoratorExpressions = transformAllDecoratorsOfDeclaration(allDecorators);
		if (Core.len(decoratorExpressions) == 0) {
			return null;
		}

		// Emit the call to __decorate. Given the following:
		//
		//   class C {
		//     @dec method(@dec2 x) {}
		//     @dec get accessor() {}
		//     @dec prop;
		//   }
		//
		// The emit for a method is:
		//
		//   __decorate([
		//       dec,
		//       __param(0, dec2),
		//       __metadata("design:type", Function),
		//       __metadata("design:paramtypes", [Object]),
		//       __metadata("design:returntype", void 0)
		//   ], C.prototype, "method", null);
		//
		// The emit for an accessor is:
		//
		//   __decorate([
		//       dec
		//   ], C.prototype, "accessor", null);
		//
		// The emit for a property is:
		//
		//   __decorate([
		//       dec
		//   ], C.prototype, "prop");
		//

		final prefix = getClassMemberPrefix(node, member);
		final memberName = getExpressionForPropertyName(member, (member.Flags & NodeFlagsAmbient) == 0);
		var descriptor:Node = null;
		if (Ast.IsPropertyDeclaration(member) && !Ast.HasAccessorModifier(member)) {
			// We emit `void 0` here to indicate to `__decorate` that it can invoke `Object.defineProperty` directly, but that it
			// should not invoke `Object.getOwnPropertyDescriptor`.
			descriptor = Factory().NewVoidZeroExpression();
		} else {
			// We emit `null` here to indicate to `__decorate` that it can invoke `Object.getOwnPropertyDescriptor` directly.
			// We have this extra argument here so that we can inject an explicit property descriptor at a later date.
			descriptor = Factory().NewKeywordExpression(KindNullKeyword);
		}

		final helper = Factory().NewDecorateHelper(decoratorExpressions, prefix, memberName, descriptor);

		EmitContext().SetEmitFlags(helper, EFNoComments);
		EmitContext().SetSourceMapRange(helper, Transformers.MoveRangePastModifiers(member));
		return helper;
	}

	function isSyntheticMetadataDecorator(node:Node):Bool {
		return EmitContext().IsCallToHelper(node.Expression(), "__metadata");
	}

	/**
	* Transforms all of the decorators for a declaration into an array of expressions.
	*
	* @param allDecorators An object containing all of the decorators for the declaration.
	 */
	function transformAllDecoratorsOfDeclaration(allDecorators:AllDecorators):Array<Node> {
		if (allDecorators == null) {
			return null;
		}

		// ensure that metadata decorators are last
		// PORT: collections.GroupBy with a bool key (go.GoMap has no Bool keys) → two order-preserving groups.
		var metadata:Array<Node> = null;
		var decorators:Array<Node> = null;
		if (allDecorators.decorators != null) {
			for (d in allDecorators.decorators) {
				if (isSyntheticMetadataDecorator(d)) {
					if (metadata == null)
						metadata = [];
					metadata.push(d);
				} else {
					if (decorators == null)
						decorators = [];
					decorators.push(d);
				}
			}
		}

		var decoratorExpressions:Array<Node> = null;
		for (part in [
			transformDecorators(decorators),
			transformDecoratorsOfParameters(allDecorators.parameters),
			transformDecorators(metadata)
		]) {
			if (part != null) {
				for (e in part) {
					if (decoratorExpressions == null)
						decoratorExpressions = [];
					decoratorExpressions.push(e);
				}
			}
		}
		return decoratorExpressions;
	}

	function transformDecoratorsOfParameters(parameters:Array<Array<Node>>):Array<Node> {
		var results:Array<Node> = null;
		if (parameters != null) {
			for (i in 0...parameters.length) {
				final decorators = parameters[i];
				if (Core.len(decorators) > 0) {
					for (decorator in decorators) {
						final helper = Factory().NewParamHelper(Visitor().VisitNode(decorator.Expression()), i, decorator.Expression().Loc);
						EmitContext().SetEmitFlags(helper, EFNoComments);
						if (results == null)
							results = [];
						results.push(helper);
					}
				}
			}
		}
		return results;
	}

	/**
	* Transforms a list of decorators into an expression.
	*
	* @param decorator The decorator node.
	 */
	function transformDecorators(decorators:Array<Node>):Array<Node> {
		var results:Array<Node> = null;
		if (decorators != null) {
			for (d in decorators) {
				if (results == null)
					results = [];
				results.push(Visitor().VisitNode(d.Expression()));
			}
		}
		return results;
	}

	function getClassMemberPrefix(node:ClassDeclaration, member:Node):Node {
		if (Ast.IsStatic(member)) {
			return Factory().GetDeclarationName(node.AsNode());
		}
		return getClassPrototype(node);
	}

	function getClassPrototype(node:ClassDeclaration):Node {
		return Factory().NewPropertyAccessExpression(Factory().GetDeclarationName(node.AsNode()), null, Factory().NewIdentifier("prototype"), NodeFlagsNone);
	}

	function getExpressionForPropertyName(member:Node, generateNameForComputedPropertyName:Bool):Node {
		final name = member.Name();
		if (Ast.IsPrivateIdentifier(name)) {
			return Factory().NewIdentifier("");
		} else if (Ast.IsComputedPropertyName(name)) {
			if (generateNameForComputedPropertyName && !Transformers.IsSimpleInlineableExpression(name.AsComputedPropertyName().Expression)) {
				return Factory().NewGeneratedNameForNode(name);
			}
			return name.AsComputedPropertyName().Expression;
		} else if (Ast.IsIdentifier(name)) {
			return Factory().NewStringLiteral(name.Text(), TokenFlagsNone);
		} else {
			return ts.ast.Deepclone.DeepCloneNode(Factory(), name);
		}
	}
}

@:allow(ts.transformers.tstransforms)
class AllDecorators {
	var decorators:Array<Node> = null;
	var parameters:Array<Array<Node>> = null;

	public function new(decorators:Array<Node> = null, parameters:Array<Array<Node>> = null) {
		this.decorators = decorators;
		this.parameters = parameters;
	}
}
