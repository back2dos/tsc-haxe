package ts.transformers.tstransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/tstransforms/Tstransforms.hx (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Package class: package-level funcs, vars and consts of internal/transformers/tstransforms (all files).
@:allow(ts.transformers.tstransforms)
class Tstransforms {
	// PORT: Go `range` over a possibly-nil slice (parser lists of zero elements have nil Nodes).
	static inline function rangeOf<T>(a:Null<Array<T>>):Array<T> {
		return a == null ? [] : a;
	}


	// --- importelision.go ---

	public static function NewImportElisionTransformer(opt:TransformOptions):Transformer {
		final compilerOptions = opt.CompilerOptions;
		final emitContext = opt.Context;
		if (compilerOptions.VerbatimModuleSyntax.IsTrue()) {
			throw "ImportElisionTransformer should not be used with VerbatimModuleSyntax";
		}
		final tx = new ImportElisionTransformer();
		tx.compilerOptions = compilerOptions;
		tx.emitResolver = opt.EmitResolver;
		return tx.Transformer.NewTransformer(tx.visit, emitContext);
	}

	// --- legacydecorators.go ---

	public static function NewLegacyDecoratorsTransformer(opt:TransformOptions):Transformer {
		final tx = new LegacyDecoratorsTransformer();
		tx.languageVersion = opt.CompilerOptions.GetEmitScriptTarget();
		tx.referenceResolver = opt.Resolver;
		return tx.Transformer.NewTransformer(tx.visit, opt.Context);
	}

	static function elideNodes(f:ts.printer.Factory.NodeFactory, nodes:NodeList):NodeList {
		if (nodes == null) {
			return null;
		}
		if (Core.len(nodes.Nodes) == 0) {
			return nodes;
		}
		final replacement = f.NewNodeList([]);
		replacement.Loc = nodes.Loc;
		return replacement;
	}

	static function elideModifiers(f:ts.printer.Factory.NodeFactory, nodes:ModifierList):ModifierList {
		if (nodes == null) {
			return null;
		}
		if (Core.len(nodes.Nodes) == 0) {
			return nodes;
		}
		final replacement = f.NewModifierList([]);
		replacement.Loc = nodes.Loc;
		return replacement;
	}

	static function isClassStaticBlockDeclarationOrStaticProperty(node:Node):Bool {
		return Ast.IsClassStaticBlockDeclaration(node) || (Ast.IsPropertyDeclaration(node) && Ast.HasStaticModifier(node));
	}

	static function isNotExportOrDefaultOrDecorator(node:Node):Bool {
		return !(Ast.IsDecorator(node) || node.Kind == KindExportKeyword || node.Kind == KindDefaultKeyword);
	}

	static function decoratorContainsPrivateIdentifierInExpression(decorator:Node):Bool {
		return (decorator.SubtreeFacts() & SubtreeContainsPrivateIdentifierInExpression) != 0;
	}

	static function parameterDecoratorsContainPrivateIdentifierInExpression(parameterDecorators:Array<Node>):Bool {
		return Core.Some(parameterDecorators, decoratorContainsPrivateIdentifierInExpression);
	}

	static function hasClassElementWithDecoratorContainingPrivateIdentifierInExpression(node:ClassDeclaration):Bool {
		if (node.Members == null || Core.len(node.Members.Nodes) == 0) {
			return false;
		}
		for (member in rangeOf(node.Members.Nodes)) {
			if (!Ast.CanHaveDecorators(member)) {
				continue;
			}
			final allDecorators = getAllDecoratorsOfClassElement(member, node, true);
			if (allDecorators == null) {
				continue;
			}
			if (Core.Some(allDecorators.decorators, decoratorContainsPrivateIdentifierInExpression)) {
				return true;
			}
			if (Core.Some(allDecorators.parameters, parameterDecoratorsContainPrivateIdentifierInExpression)) {
				return true;
			}
		}
		return false;
	}

	/**
	 * Gets an allDecorators object containing the decorators for the class and the decorators for the
	 * parameters of the constructor of the class.
	 *
	 * @param node The class node.
	 *
	 * @internal
	 */
	static function getAllDecoratorsOfClass(node:ClassDeclaration, useLegacyDecorators:Bool):AllDecorators {
		final decorators = node.AsNode().Decorators();
		var parameters:Array<Array<Node>> = null;
		if (useLegacyDecorators) {
			parameters = getDecoratorsOfParameters(Ast.GetFirstConstructorWithBody(node.AsNode()));
		}
		if (Core.len(decorators) == 0 && Core.len(parameters) == 0) {
			return null;
		}
		return new AllDecorators(decorators, parameters);
	}

	/**
	 * Gets an allDecorators object containing the decorators for the member and its parameters.
	 *
	 * @param parent The class node that contains the member.
	 * @param member The class member.
	 *
	 * @internal
	 */
	static function getAllDecoratorsOfClassElement(member:Node, parent:ClassDeclaration, useLegacyDecorators:Bool):AllDecorators {
		switch (member.Kind) {
			case KindGetAccessor | KindSetAccessor:
				if (!useLegacyDecorators) {
					return getAllDecoratorsOfMethod(member, false);
				}
				return getAllDecoratorsOfAccessors(member, parent, true);
			case KindMethodDeclaration:
				return getAllDecoratorsOfMethod(member, useLegacyDecorators);
			case KindPropertyDeclaration:
				return getAllDecoratorsOfProperty(member);
			default:
				return null;
		}
	}

	/**
	 * Gets an allDecorators object containing the decorators for the accessor and its parameters.
	 *
	 * @param parent The class node that contains the accessor.
	 * @param accessor The class accessor member.
	 */
	static function getAllDecoratorsOfAccessors(accessor:Node, parent:ClassDeclaration, useLegacyDecorators:Bool):AllDecorators {
		if (accessor.Body() == null) {
			return null;
		}
		final decls = Ast.GetAllAccessorDeclarations(parent.Members.Nodes, accessor);
		var firstAccessorWithDecorators:Node = null;
		if (Ast.HasDecorators(decls.FirstAccessor)) {
			firstAccessorWithDecorators = decls.FirstAccessor;
		} else if (decls.SecondAccessor != null && Ast.HasDecorators(decls.SecondAccessor)) {
			firstAccessorWithDecorators = decls.SecondAccessor;
		}

		if (firstAccessorWithDecorators == null || accessor != firstAccessorWithDecorators) {
			return null;
		}

		final decorators = firstAccessorWithDecorators.Decorators();
		var parameters:Array<Array<Node>> = null;
		if (useLegacyDecorators && decls.SetAccessor != null) {
			parameters = getDecoratorsOfParameters(decls.SetAccessor.AsNode());
		}

		if (Core.len(decorators) == 0 && Core.len(parameters) == 0) {
			return null;
		}

		return new AllDecorators(decorators, parameters);
	}

	static function getAllDecoratorsOfProperty(property:Node):AllDecorators {
		final decorators = property.Decorators();
		if (Core.len(decorators) == 0) {
			return null;
		}
		return new AllDecorators(decorators);
	}

	static function getAllDecoratorsOfMethod(method:Node, useLegacyDecorators:Bool):AllDecorators {
		if (method.Body() == null) {
			return null;
		}
		final decorators = method.Decorators();
		var parameters:Array<Array<Node>> = null;
		if (useLegacyDecorators) {
			parameters = getDecoratorsOfParameters(method);
		}
		if (Core.len(decorators) == 0 && Core.len(parameters) == 0) {
			return null;
		}
		return new AllDecorators(decorators, parameters);
	}

	/**
	 * Gets an array of arrays of decorators for the parameters of a function-like node.
	 * The offset into the result array should correspond to the offset of the parameter.
	 *
	 * @param node The function-like node.
	 */
	static function getDecoratorsOfParameters(node:Node):Array<Array<Node>> {
		var decorators:Array<Array<Node>> = null;
		if (node != null) {
			final parameters = node.Parameters();
			final firstParameterIsThis = Core.len(parameters) > 0 && Ast.IsThisParameter(parameters[0]);
			var firstParameterOffset = 0;
			var numParameters = Core.len(parameters);
			if (firstParameterIsThis) {
				firstParameterOffset = 1;
				numParameters = numParameters - 1;
			}
			for (i in 0...numParameters) {
				final p = parameters[i + firstParameterOffset];
				if (Core.len(decorators) > 0 || Ast.HasDecorators(p)) {
					if (Core.len(decorators) == 0) {
						decorators = [for (_ in 0...numParameters) null];
					}
					decorators[i] = p.Decorators();
				}
			}
		}
		return decorators;
	}

	/**
	* Determines whether a class member is either a static or an instance member of a class
	* that is decorated, or has parameters that are decorated.
	*
	* @param member The class member.
	 */
	static function isDecoratedClassElement(member:Node, isStaticElement:Bool, parent:ClassDeclaration):Bool {
		return isStaticElement == Ast.IsStatic(member) && Ast.NodeOrChildIsDecorated(true, member, parent.AsNode(), null);
	}

	/**
	* Gets either the static or instance members of a class that are decorated, or have
	* parameters that are decorated.
	*
	* @param node The class containing the member.
	* @param isStatic A value indicating whether to retrieve static or instance members of
	*                 the class.
	 */
	static function getDecoratedClassElements(node:ClassDeclaration, isStatic:Bool):Array<Node> {
		if (node.Members == null || Core.len(node.Members.Nodes) == 0) {
			return null;
		}
		var members:Array<Node> = null;
		for (member in rangeOf(node.Members.Nodes)) {
			if (isDecoratedClassElement(member, isStatic, node)) {
				if (members == null)
					members = [];
				members.push(member);
			}
		}
		return members;
	}

	// --- metadata.go ---

	public static inline final USE_NEW_TYPE_METADATA_FORMAT:Bool = false;

	public static function NewMetadataTransformer(opt:TransformOptions):Transformer {
		final tx = new MetadataTransformer();
		tx.legacyDecorators = opt.CompilerOptions.ExperimentalDecorators.IsTrue();
		tx.resolver = opt.EmitResolver;
		tx.languageVersion = opt.CompilerOptions.GetEmitScriptTarget();
		tx.strictNullChecks = opt.CompilerOptions.GetStrictOptionValue(opt.CompilerOptions.StrictNullChecks);
		return tx.Transformer.NewTransformer(tx.visit, opt.Context);
	}

	// --- runtimesyntax.go ---

	public static function NewRuntimeSyntaxTransformer(opt:TransformOptions):Transformer {
		final compilerOptions = opt.CompilerOptions;
		final emitContext = opt.Context;
		final tx = new RuntimeSyntaxTransformer();
		tx.compilerOptions = compilerOptions;
		tx.resolver = opt.Resolver;
		tx.emitResolver = opt.EmitResolver;
		return tx.Transformer.NewTransformer(tx.visit, emitContext);
	}

	static function getInnermostModuleDeclarationFromDottedModule(moduleDeclaration:ModuleDeclaration):ModuleDeclaration {
		while (moduleDeclaration.Body != null && moduleDeclaration.Body.Kind == KindModuleDeclaration) {
			moduleDeclaration = moduleDeclaration.Body.AsModuleDeclaration();
		}
		return moduleDeclaration;
	}

	// --- typeeraser.go ---

	public static function NewTypeEraserTransformer(opt:TransformOptions):Transformer {
		final compilerOptions = opt.CompilerOptions;
		final emitContext = opt.Context;
		final tx = new TypeEraserTransformer();
		tx.compilerOptions = compilerOptions;
		return tx.Transformer.NewTransformer(tx.visit, emitContext);
	}

	// --- typeserializer.go ---

	static function newMetadataSerializer(resolver:EmitResolver, f:ts.printer.Factory.NodeFactory, ec:EmitContext, languageVersion:ScriptTarget, strictNullChecks:Bool):MetadataSerializer {
		final s = new MetadataSerializer();
		s.resolver = resolver;
		s.languageVersion = languageVersion;
		s.f = f;
		s.ec = ec;
		s.strictNullChecks = strictNullChecks;
		return s;
	}

	public static function GetSetAccessorValueParameter(node:SetAccessorDeclaration):Node {
		if (node != null && Core.len(node.Parameters.Nodes) > 0) {
			if (Core.len(node.Parameters.Nodes) >= 2 && Ast.IsThisParameter(node.Parameters.Nodes[0])) {
				return node.Parameters.Nodes[1];
			}
			return node.Parameters.Nodes[0];
		}
		return null;
	}

	/**
	 * Get the type annotation for the value parameter.
	 *
	 * @internal
	 */
	static function getSetAccessorTypeAnnotationNode(node:SetAccessorDeclaration):Node {
		final p = GetSetAccessorValueParameter(node);
		if (p != null && p.Type() != null) {
			return p.Type();
		}
		return null;
	}

	static function getAccessorTypeNode(node:Node, container:Node):Node {
		final accessors = Ast.GetAllAccessorDeclarations(container.Members(), node);
		if (accessors.SetAccessor != null) {
			return getSetAccessorTypeAnnotationNode(accessors.SetAccessor);
		}
		if (accessors.GetAccessor != null) {
			return accessors.GetAccessor.Type;
		}
		return null;
	}

	static function getParametersOfDecoratedDeclaration(node:Node, container:Node):NodeList {
		if (container != null && node.Kind == KindGetAccessor) {
			final acc = Ast.GetAllAccessorDeclarations(container.Members(), node);
			if (acc.SetAccessor != null) {
				return acc.SetAccessor.Parameters;
			}
		}
		return node.ParameterList();
	}

	// --- utilities.go ---

	static function constantExpression(value:Any, factory:ts.printer.Factory.NodeFactory):Expression {
		// PORT: Go type switch on `any`; a jsnum.Number in `any` is a raw Float (PORTING.md §3).
		if (Std.isOfType(value, std.String)) {
			return factory.NewStringLiteral((value : std.String), TokenFlagsNone);
		} else if (Std.isOfType(value, Float)) {
			final value:Number = (value : Float);
			if (value.IsInf()) {
				if (value > 0) {
					return factory.NewIdentifier("Infinity");
				}
				return factory.NewPrefixUnaryExpression(KindMinusToken, factory.NewIdentifier("Infinity"));
			}
			if (value.IsNaN()) {
				return factory.NewIdentifier("NaN");
			}
			if (value < 0) {
				return factory.NewPrefixUnaryExpression(KindMinusToken, constantExpression((-value : Float), factory));
			}
			return factory.NewNumericLiteral(value.String(), TokenFlagsNone);
		}
		return null;
	}
}
