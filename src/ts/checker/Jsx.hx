package ts.checker;

import ts.parser.Parser;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/jsx.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

enum abstract JsxFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:JsxFlags, b:JsxFlags):JsxFlags;
	@:op(A & B) static function and(a:JsxFlags, b:JsxFlags):JsxFlags;
	@:op(~A) static function not(a:JsxFlags):JsxFlags;

	var JsxFlagsNone = 0;
	var JsxFlagsIntrinsicNamedElement = 1 << 0; // An element from a named property of the JSX.IntrinsicElements interface
	var JsxFlagsIntrinsicIndexedElement = 1 << 1; // An element inferred from the string index signature of the JSX.IntrinsicElements interface
	var JsxFlagsIntrinsicElement = 3;
}

enum abstract JsxReferenceKind(Int) from Int to Int {
	var JsxReferenceKindComponent = 0;
	var JsxReferenceKindFunction = 1;
	var JsxReferenceKindMixed = 2;
}

@:allow(ts.checker)
class JsxElementLinks {
	var jsxFlags:JsxFlags = 0; // Flags for the JSX element
	var resolvedJsxElementAttributesType:Type = null; // Resolved element attributes type of a JSX opening-like element
	var jsxNamespace:Symbol = null; // Resolved JSX namespace symbol for this node
	var jsxImplicitImportContainer:Symbol = null; // Resolved module symbol the implicit JSX import of this file should refer to

	public function new() {}
}

@:allow(ts.checker)
class JsxElaborationElement {
	var errorNode:Node = null;
	var innerExpression:Node = null;
	var nameType:Type = null;
	var createDiagnostic:(prop:Node) -> Diagnostic = null; // Optional: creates a custom diagnostic for this element

	public function new() {}
}

// Methods of jsx.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class Jsx {

	static function checkJsxElement(c:Checker, node:Node, checkMode:CheckMode):Type {
		c.checkNodeDeferred(node);
		return c.getJsxElementTypeAt(node);
	}

	static function checkJsxElementDeferred(c:Checker, node:Node):Void {
		final jsxElement = node.AsJsxElement();
		c.checkJsxOpeningLikeElementOrOpeningFragment(jsxElement.OpeningElement);
		// Perform resolution on the closing tag so that rename/go to definition/etc work
		if (Checker.isJsxIntrinsicTagName(jsxElement.ClosingElement.TagName())) {
			c.getIntrinsicTagSymbol(jsxElement.ClosingElement);
		} else {
			c.checkExpression(jsxElement.ClosingElement.TagName());
		}
		c.checkJsxChildren(node, CheckModeNormal);
	}

	static function checkJsxExpression(c:Checker, node:Node, checkMode:CheckMode):Type {
		c.checkGrammarJsxExpression(node.AsJsxExpression());
		if (node.Expression() == null) {
			return c.errorType;
		}
		final t = c.checkExpressionEx(node.Expression(), checkMode);
		if (node.AsJsxExpression().DotDotDotToken != null && t != c.anyType && !c.isArrayType(t)) {
			c.error(node, Diagnostics.JSX_spread_child_must_be_an_array_type);
		}
		return t;
	}

	static function checkJsxSelfClosingElement(c:Checker, node:Node, checkMode:CheckMode):Type {
		c.checkNodeDeferred(node);
		return c.getJsxElementTypeAt(node);
	}

	static function checkJsxSelfClosingElementDeferred(c:Checker, node:Node):Void {
		c.checkJsxOpeningLikeElementOrOpeningFragment(node);
	}

	static function checkJsxFragment(c:Checker, node:Node):Type {
		c.checkJsxOpeningLikeElementOrOpeningFragment(node.AsJsxFragment().OpeningFragment);
		// by default, jsx:'react' will use jsxFactory = React.createElement and jsxFragmentFactory = React.Fragment
		// if jsxFactory compiler option is provided, ensure jsxFragmentFactory compiler option or @jsxFrag pragma is provided too
		final nodeSourceFile = Ast.GetSourceFileOfNode(node);
		if (c.compilerOptions.GetJSXTransformEnabled() && (c.compilerOptions.JsxFactory != "" || Ast.GetPragmaFromSourceFile(nodeSourceFile, "jsx") != null) && c.compilerOptions.JsxFragmentFactory == "" && Ast.GetPragmaFromSourceFile(nodeSourceFile, "jsxfrag") == null) {
			final message = Core.IfElse(c.compilerOptions.JsxFactory != "",
				Diagnostics.The_jsxFragmentFactory_compiler_option_must_be_provided_to_use_JSX_fragments_with_the_jsxFactory_compiler_option,
				Diagnostics.An_jsxFrag_pragma_is_required_when_using_an_jsx_pragma_with_JSX_fragments);
			c.error(node, message);
		}
		c.checkJsxChildren(node, CheckModeNormal);
		final t = c.getJsxElementTypeAt(node);
		return Core.IfElse(c.isErrorType(t), c.anyType, t);
	}

	static function checkJsxAttributes(c:Checker, node:Node, checkMode:CheckMode):Type {
		return c.createJsxAttributesTypeFromAttributesProperty(node.Parent, checkMode);
	}

	static function checkJsxOpeningLikeElementOrOpeningFragment(c:Checker, node:Node):Void {
		final isNodeOpeningLikeElement = Ast.IsJsxOpeningLikeElement(node);
		if (isNodeOpeningLikeElement) {
			c.checkGrammarJsxElement(node);
		}
		c.checkJsxPreconditions(node);
		c.markJsxAliasReferenced(node);
		final sig = c.getResolvedSignature(node, null, CheckModeNormal);
		c.checkDeprecatedSignature(sig, node);
		if (isNodeOpeningLikeElement) {
			final elementTypeConstraint = c.getJsxElementTypeTypeAt(node);
			if (elementTypeConstraint != null) {
				final tagName = node.TagName();
				var tagType:Type = null;
				if (Checker.isJsxIntrinsicTagName(tagName)) {
					tagType = c.getStringLiteralType(tagName.Text());
				} else {
					tagType = c.checkExpression(tagName);
				}
				final diags:Array<Diagnostic> = [];
				if (!c.checkTypeRelatedToEx(tagType, elementTypeConstraint, c.assignableRelation, tagName, Diagnostics.Its_type_0_is_not_a_valid_JSX_element_type, diags)) {
					c.addDiagnostic(Ast.NewDiagnosticChain(diags[0], Diagnostics.X_0_cannot_be_used_as_a_JSX_component, Scanner.GetTextOfNode(tagName)));
				}
			} else {
				c.checkJsxReturnAssignableToAppropriateBound(c.getJsxReferenceKind(node), c.getReturnTypeOfSignature(sig), node);
			}
		}
	}

	static function checkJsxPreconditions(c:Checker, errorNode:Node):Void {
		// Preconditions for using JSX
		if (c.compilerOptions.Jsx == JsxEmitNone) {
			c.error(errorNode, Diagnostics.Cannot_use_JSX_unless_the_jsx_flag_is_provided);
		}
		if (c.noImplicitAny && c.getJsxElementTypeAt(errorNode) == null) {
			c.error(errorNode, Diagnostics.JSX_element_implicitly_has_type_any_because_the_global_type_JSX_Element_does_not_exist);
		}
	}

	static function checkJsxReturnAssignableToAppropriateBound(c:Checker, refKind:JsxReferenceKind, elemInstanceType:Type, openingLikeElement:Node):Void {
		final diags:Array<Diagnostic> = [];
		switch (refKind) {
			case JsxReferenceKindFunction:
				final sfcReturnConstraint = c.getJsxStatelessElementTypeAt(openingLikeElement);
				if (sfcReturnConstraint != null) {
					c.checkTypeRelatedToEx(elemInstanceType, sfcReturnConstraint, c.assignableRelation, openingLikeElement.TagName(), Diagnostics.Its_return_type_0_is_not_a_valid_JSX_element, diags);
				}
			case JsxReferenceKindComponent:
				final classConstraint = c.getJsxElementClassTypeAt(openingLikeElement);
				if (classConstraint != null) {
					// Issue an error if this return type isn't assignable to JSX.ElementClass, failing that
					c.checkTypeRelatedToEx(elemInstanceType, classConstraint, c.assignableRelation, openingLikeElement.TagName(), Diagnostics.Its_instance_type_0_is_not_a_valid_JSX_element, diags);
				}
			default:
				final sfcReturnConstraint = c.getJsxStatelessElementTypeAt(openingLikeElement);
				final classConstraint = c.getJsxElementClassTypeAt(openingLikeElement);
				if (sfcReturnConstraint == null || classConstraint == null) {
					return;
				}
				final combined = c.getUnionType([sfcReturnConstraint, classConstraint]);
				c.checkTypeRelatedToEx(elemInstanceType, combined, c.assignableRelation, openingLikeElement.TagName(), Diagnostics.Its_element_type_0_is_not_a_valid_JSX_element, diags);
		}
		if (diags.length != 0) {
			c.addDiagnostic(Ast.NewDiagnosticChain(diags[0], Diagnostics.X_0_cannot_be_used_as_a_JSX_component, Scanner.GetTextOfNode(openingLikeElement.TagName())));
		}
	}

	static function inferJsxTypeArguments(c:Checker, node:Node, signature:Signature, checkMode:CheckMode, context:InferenceContext):Array<Type> {
		final paramType = c.getEffectiveFirstArgumentForJsxSignature(signature, node);
		final checkAttrType = c.checkExpressionWithContextualType(node.Attributes(), paramType, context, checkMode);
		c.inferTypes(context.inferences, checkAttrType, paramType, InferencePriorityNone, false);
		return c.getInferredTypes(context);
	}

	static function getContextualTypeForJsxExpression(c:Checker, node:Node, contextFlags:ContextFlags):Type {
		if (Ast.IsJsxAttributeLike(node.Parent)) {
			return c.getContextualType(node, contextFlags);
		} else if (Ast.IsJsxElement(node.Parent)) {
			return c.getContextualTypeForChildJsxExpression(node.Parent, node, contextFlags);
		}
		return null;
	}

	static function getContextualTypeForJsxAttribute(c:Checker, attribute:Node, contextFlags:ContextFlags):Type {
		// When we trying to resolve JsxOpeningLikeElement as a stateless function element, we will already give its attributes a contextual type
		// which is a type of the parameter of the signature we are trying out.
		// If there is no contextual type (e.g. we are trying to resolve stateful component), get attributes type from resolving element's tagName
		if (Ast.IsJsxAttribute(attribute)) {
			final attributesType = c.getApparentTypeOfContextualType(attribute.Parent, contextFlags);
			if (attributesType == null || Checker.IsTypeAny(attributesType)) {
				return null;
			}
			return c.getTypeOfPropertyOfContextualType(attributesType, attribute.Name().Text());
		}
		return c.getContextualType(attribute.Parent, contextFlags);
	}

	static function getContextualJsxElementAttributesType(c:Checker, node:Node, contextFlags:ContextFlags):Type {
		if (Ast.IsJsxOpeningElement(node) && contextFlags != ContextFlagsIgnoreNodeInferences) {
			final index = c.findContextualNode(node.Parent, contextFlags == ContextFlagsNone);
			if (index >= 0) {
				// Contextually applied type is moved from attributes up to the outer jsx attributes so when walking up from the children they get hit
				// _However_ to hit them from the _attributes_ we must look for them here; otherwise we'll used the declared type
				// (as below) instead!
				return c.contextualInfos[index].t;
			}
		}
		return c.getContextualTypeForArgumentAtIndex(node, 0);
	}

	static function getContextualTypeForChildJsxExpression(c:Checker, node:Node, child:JsxChild, contextFlags:ContextFlags):Type {
		final attributesType = c.getApparentTypeOfContextualType(node.AsJsxElement().OpeningElement.Attributes(), contextFlags);
		// JSX expression is in children of JSX Element, we will look for an "children" attribute (we get the name from JSX.ElementAttributesProperty)
		final jsxChildrenPropertyName = c.getJsxElementChildrenPropertyName(c.getJsxNamespaceAt(node));
		if (!(attributesType != null && !Checker.IsTypeAny(attributesType) && jsxChildrenPropertyName != Ast.InternalSymbolNameMissing && jsxChildrenPropertyName != "")) {
			return null;
		}
		final realChildren = Ast.GetSemanticJsxChildren(node.Children().Nodes);
		final childIndex = Slices.Index(realChildren, child);
		final childFieldType = c.getTypeOfPropertyOfContextualType(attributesType, jsxChildrenPropertyName);
		if (childFieldType == null) {
			return null;
		}
		if (Core.len(realChildren) == 1) {
			return childFieldType;
		}
		return c.mapTypeEx(childFieldType, t -> {
			if (c.isArrayLikeType(t)) {
				return c.getIndexedAccessType(t, c.getNumberLiteralType(childIndex));
			}
			return t;
		}, true /*noReductions*/);
	}

	static function discriminateContextualTypeByJSXAttributes(c:Checker, node:Node, contextualType:Type):Type {
		final key = DiscriminatedContextualTypeKey.keyOf(Ast.GetNodeId(node), contextualType.id);
		final discriminated = c.discriminatedContextualTypes.get(key);
		if (discriminated != null) {
			return discriminated;
		}
		final jsxChildrenPropertyName = c.getJsxElementChildrenPropertyName(c.getJsxNamespaceAt(node));
		final discriminantProperties = Core.Filter(node.Properties(), p -> {
			final symbol = p.Symbol();
			if (symbol == null || !Ast.IsJsxAttribute(p)) {
				return false;
			}
			final initializer = p.Initializer();
			return (initializer == null || c.isPossiblyDiscriminantValue(initializer)) && c.isDiscriminantProperty(contextualType, symbol.Name);
		});
		final discriminantMembers = Core.Filter(c.getPropertiesOfType(contextualType), s -> {
			if ((s.Flags & SymbolFlagsOptional) == 0 || node.Symbol() == null) {
				return false;
			}
			final element = node.Parent.Parent;
			if (s.Name == jsxChildrenPropertyName && Ast.IsJsxElement(element) && Core.len(Ast.GetSemanticJsxChildren(element.Children().Nodes)) != 0) {
				return false;
			}
			return symbolTableGet(node.Symbol().Members, s.Name) == null && c.isDiscriminantProperty(contextualType, s.Name);
		});
		final discriminator = new ObjectLiteralDiscriminator();
		discriminator.c = c;
		discriminator.props = discriminantProperties;
		discriminator.members = discriminantMembers;
		final discriminated = c.discriminateTypeByDiscriminableItems(contextualType, discriminator);
		c.discriminatedContextualTypes.set(key, discriminated);
		return discriminated;
	}

	static function elaborateJsxComponents(c:Checker, node:Node, source:Type, target:Type, relation:Relation, diagnosticOutput:Array<Diagnostic>):Bool {
		var reportedError = false;
		for (prop in rangeOf(node.Properties())) {
			if (!Ast.IsJsxSpreadAttribute(prop) && !Checker.isHyphenatedJsxName(prop.Name().Text())) {
				final nameType = c.getStringLiteralType(prop.Name().Text());
				if (nameType != null && (nameType.flags & TypeFlagsNever) == 0) {
					reportedError = c.elaborateElement(source, target, relation, prop.Name(), prop.Initializer(), nameType, null, null, diagnosticOutput) || reportedError;
				}
			}
		}
		if (Ast.IsJsxOpeningElement(node.Parent) && Ast.IsJsxElement(node.Parent.Parent)) {
			final containingElement = node.Parent.Parent; // Containing JSXElement
			var childrenPropName = c.getJsxElementChildrenPropertyName(c.getJsxNamespaceAt(node));
			if (childrenPropName == Ast.InternalSymbolNameMissing) {
				childrenPropName = "children";
			}
			final childrenNameType = c.getStringLiteralType(childrenPropName);
			final childrenTargetType = c.getIndexedAccessType(target, childrenNameType);
			final validChildren = Ast.GetSemanticJsxChildren(containingElement.Children().Nodes);
			if (Core.len(validChildren) == 0) {
				return reportedError;
			}
			final moreThanOneRealChildren = validChildren.length > 1;
			var arrayLikeTargetParts:Type = null;
			var nonArrayLikeTargetParts:Type = null;
			final iterableType = c.getGlobalIterableType();
			if (iterableType != c.emptyGenericType) {
				final anyIterable = c.createIterableType(c.anyType);
				arrayLikeTargetParts = c.filterType(childrenTargetType, t -> c.isTypeAssignableTo(t, anyIterable));
				nonArrayLikeTargetParts = c.filterType(childrenTargetType, t -> !c.isTypeAssignableTo(t, anyIterable));
			} else {
				arrayLikeTargetParts = c.filterType(childrenTargetType, t -> c.isArrayOrTupleLikeType(t));
				nonArrayLikeTargetParts = c.filterType(childrenTargetType, t -> !c.isArrayOrTupleLikeType(t));
			}
			var invalidTextDiagnostic:Message = null;
			var invalidTextDiagnosticArgs:Array<Any> = null;
			final getInvalidTextualChildDiagnostic = () -> {
				if (invalidTextDiagnostic == null) {
					final tagNameText = Scanner.GetTextOfNode(node.Parent.TagName());
					invalidTextDiagnostic = Diagnostics.X_0_components_don_t_accept_text_as_child_elements_Text_in_JSX_has_the_type_string_but_the_expected_type_of_1_is_2;
					invalidTextDiagnosticArgs = [tagNameText, childrenPropName, c.TypeToString(childrenTargetType)];
				}
				return new Pair<Message, Array<Any>>(invalidTextDiagnostic, invalidTextDiagnosticArgs);
			};
			if (moreThanOneRealChildren) {
				if (arrayLikeTargetParts != c.neverType) {
					final realSource = c.createTupleType(c.checkJsxChildren(containingElement, CheckModeNormal));
					final children = c.generateJsxChildren(containingElement, getInvalidTextualChildDiagnostic);
					reportedError = c.elaborateIterableOrArrayLikeTargetElementwise(children, realSource, arrayLikeTargetParts, relation, diagnosticOutput) || reportedError;
				} else if (!c.isTypeRelatedTo(c.getIndexedAccessType(source, childrenNameType), childrenTargetType, relation)) {
					// arity mismatch
					final diag = c.error(containingElement.AsJsxElement().OpeningElement.TagName(), Diagnostics.This_JSX_tag_s_0_prop_expects_a_single_child_of_type_1_but_multiple_children_were_provided, childrenPropName, c.TypeToString(childrenTargetType));
					c.reportDiagnostic(diag, diagnosticOutput);
					reportedError = true;
				}
			} else {
				if (nonArrayLikeTargetParts != c.neverType) {
					final child = validChildren[0];
					final e = c.getElaborationElementForJsxChild(child, childrenNameType, getInvalidTextualChildDiagnostic);
					if (e.errorNode != null) {
						reportedError = c.elaborateElement(source, target, relation, e.errorNode, e.innerExpression, e.nameType, null, e.createDiagnostic, diagnosticOutput) || reportedError;
					}
				} else if (!c.isTypeRelatedTo(c.getIndexedAccessType(source, childrenNameType), childrenTargetType, relation)) {
					// arity mismatch
					final diag = c.error(containingElement.AsJsxElement().OpeningElement.TagName(), Diagnostics.This_JSX_tag_s_0_prop_expects_type_1_which_requires_multiple_children_but_only_a_single_child_was_provided, childrenPropName, c.TypeToString(childrenTargetType));
					c.reportDiagnostic(diag, diagnosticOutput);
					reportedError = true;
				}
			}
		}
		return reportedError;
	}

	static function generateJsxChildren(c:Checker, node:Node, getInvalidTextDiagnostic:() -> Pair<Message, Array<Any>>):(yield:(JsxElaborationElement) -> Bool) -> Void {
		return (yield:(JsxElaborationElement) -> Bool) -> {
			var memberOffset = 0;
			final nodes = rangeOf(node.Children().Nodes);
			for (i in 0...nodes.length) {
				final child = nodes[i];
				final nameType = c.getNumberLiteralType(i - memberOffset);
				final e = c.getElaborationElementForJsxChild(child, nameType, getInvalidTextDiagnostic);
				if (e.errorNode != null) {
					if (!yield(e)) {
						return;
					}
				} else {
					memberOffset++;
				}
			}
		};
	}

	static function getElaborationElementForJsxChild(c:Checker, child:Node, nameType:Type, getInvalidTextDiagnostic:() -> Pair<Message, Array<Any>>):JsxElaborationElement {
		switch (child.Kind) {
			case KindJsxExpression:
				// child is of the type of the expression
				return newElaborationElement(child, child.Expression(), nameType, null);
			case KindJsxText:
				if (child.AsJsxText().ContainsOnlyTriviaWhiteSpaces) {
					// Whitespace only jsx text isn't real jsx text
					return new JsxElaborationElement();
				}
				// child is a string
				return newElaborationElement(child, null, nameType, (prop:Node) -> {
					final d = getInvalidTextDiagnostic();
					final errorMessage = d.a;
					final errorArgs = d.b;
					return Checker.NewDiagnosticForNode(prop, errorMessage, ...errorArgs);
				});
			case KindJsxElement | KindJsxSelfClosingElement | KindJsxFragment:
				// child is of type JSX.Element
				return newElaborationElement(child, child, nameType, null);
			default:
		}
		throw "Unhandled case in getElaborationElementForJsxChild";
	}

	static function elaborateIterableOrArrayLikeTargetElementwise(c:Checker, iterator:(yield:(JsxElaborationElement) -> Bool) -> Void, source:Type, target:Type, relation:Relation, diagnosticOutput:Array<Diagnostic>):Bool {
		final tupleOrArrayLikeTargetParts = c.filterType(target, t -> c.isArrayOrTupleLikeType(t));
		final nonTupleOrArrayLikeTargetParts = c.filterType(target, t -> !c.isArrayOrTupleLikeType(t));
		// If `nonTupleOrArrayLikeTargetParts` is not `never`, then that should mean `Iterable` is defined.
		var iterationType:Type = null;
		if (nonTupleOrArrayLikeTargetParts != c.neverType) {
			iterationType = c.getIterationTypeOfIterable(IterationUseForOf, IterationTypeKindYield, nonTupleOrArrayLikeTargetParts, null /*errorNode*/);
		}
		var reportedError = false;
		// PORT: `for e := range iterator` over the yield-func form; `continue` is `return true`.
		iterator(e -> {
			final prop = e.errorNode;
			final next = e.innerExpression;
			final nameType = e.nameType;
			var targetPropType = iterationType;
			var targetIndexedPropType:Type = null;
			if (tupleOrArrayLikeTargetParts != c.neverType) {
				targetIndexedPropType = c.getBestMatchIndexedAccessTypeOrUndefined(source, tupleOrArrayLikeTargetParts, nameType);
			}
			if (targetIndexedPropType != null && (targetIndexedPropType.flags & TypeFlagsIndexedAccess) == 0) {
				if (iterationType != null) {
					targetPropType = c.getUnionType([iterationType, targetIndexedPropType]);
				} else {
					targetPropType = targetIndexedPropType;
				}
			}
			if (targetPropType == null) {
				return true;
			}
			var sourcePropType = c.getIndexedAccessTypeOrUndefined(source, nameType, AccessFlagsNone, null, null);
			if (sourcePropType == null) {
				return true;
			}
			final propName = c.getPropertyNameFromIndex(nameType, null /*accessNode*/);
			if (!c.checkTypeRelatedTo(sourcePropType, targetPropType, relation, null /*errorNode*/)) {
				final elaborated = next != null && c.elaborateError(next, sourcePropType, targetPropType, relation, null /*headMessage*/, diagnosticOutput);
				reportedError = true;
				if (!elaborated) {
					// Issue error on the prop itself, since the prop couldn't elaborate the error. Use the expression type, if available.
					var specificSource = sourcePropType;
					if (next != null) {
						specificSource = c.checkExpressionForMutableLocationWithContextualType(next, sourcePropType);
					}
					if (e.createDiagnostic != null) {
						// Use the custom diagnostic factory if provided (e.g., for JSX text children with dynamic error messages)
						c.reportDiagnostic(e.createDiagnostic(prop), diagnosticOutput);
					} else if (c.exactOptionalPropertyTypes && c.isExactOptionalPropertyMismatch(specificSource, targetPropType)) {
						final diag = Checker.createDiagnosticForNode(prop, Diagnostics.Type_0_is_not_assignable_to_type_1_with_exactOptionalPropertyTypes_Colon_true_Consider_adding_undefined_to_the_type_of_the_target, c.TypeToString(specificSource), c.TypeToString(targetPropType));
						c.reportDiagnostic(diag, diagnosticOutput);
					} else {
						final targetIsOptional = propName != Ast.InternalSymbolNameMissing && (Core.OrElse(c.getPropertyOfType(tupleOrArrayLikeTargetParts, propName), c.unknownSymbol).Flags & SymbolFlagsOptional) != 0;
						final sourceIsOptional = propName != Ast.InternalSymbolNameMissing && (Core.OrElse(c.getPropertyOfType(source, propName), c.unknownSymbol).Flags & SymbolFlagsOptional) != 0;
						targetPropType = c.removeMissingType(targetPropType, targetIsOptional);
						sourcePropType = c.removeMissingType(sourcePropType, targetIsOptional && sourceIsOptional);
						final result = c.checkTypeRelatedToEx(specificSource, targetPropType, relation, prop, null, diagnosticOutput);
						if (result && specificSource != sourcePropType) {
							// If for whatever reason the expression type doesn't yield an error, make sure we still issue an error on the sourcePropType
							c.checkTypeRelatedToEx(sourcePropType, targetPropType, relation, prop, null, diagnosticOutput);
						}
					}
				}
			}
			return true;
		});
		return reportedError;
	}

	static function getSuggestedSymbolForNonexistentJSXAttribute(c:Checker, name:std.String, containingType:Type):Symbol {
		final properties = c.getPropertiesOfType(containingType);
		var jsxSpecific:Symbol = null;
		switch (name) {
			case "for":
				jsxSpecific = Core.Find(properties, x -> Ast.SymbolName(x) == "htmlFor");
			case "class":
				jsxSpecific = Core.Find(properties, x -> Ast.SymbolName(x) == "className");
			default:
		}
		if (jsxSpecific != null) {
			return jsxSpecific;
		}
		// PORT: slices.Values(properties) as the yield-func form of iter.Seq.
		return c.getSpellingSuggestionForName(name, (yield:(Symbol) -> Bool) -> {
			for (p in rangeOf(properties)) {
				if (!yield(p)) {
					return;
				}
			}
		}, SymbolFlagsValue);
	}

	static function getJSXFragmentType(c:Checker, node:Node):Type {
		// An opening fragment is required in order for `getJsxNamespace` to give the fragment factory
		final links = c.sourceFileLinks.Get(Ast.GetSourceFileOfNode(node));
		if (links.jsxFragmentType != null) {
			return links.jsxFragmentType;
		}
		final jsxFragmentFactoryName = c.getJsxNamespace(node);
		// #38720/60122, allow null as jsxFragmentFactory
		final shouldResolveFactoryReference = (c.compilerOptions.Jsx == JsxEmitReact || c.compilerOptions.JsxFragmentFactory != "") && jsxFragmentFactoryName != "null";
		if (!shouldResolveFactoryReference) {
			links.jsxFragmentType = c.anyType;
			return links.jsxFragmentType;
		}
		var jsxFactorySymbol = c.getJsxNamespaceContainerForImplicitImport(node);
		if (jsxFactorySymbol == null) {
			final shouldModuleRefErr = c.compilerOptions.Jsx != JsxEmitPreserve && c.compilerOptions.Jsx != JsxEmitReactNative;
			var flags = SymbolFlagsValue;
			if (!shouldModuleRefErr) {
				flags = flags & ~SymbolFlagsEnum;
			}
			jsxFactorySymbol = c.resolveName(node, jsxFragmentFactoryName, flags, Diagnostics.Using_JSX_fragments_requires_fragment_factory_0_to_be_in_scope_but_it_could_not_be_found, true /*isUse*/, false /*excludeGlobals*/);
		}
		if (jsxFactorySymbol == null) {
			links.jsxFragmentType = c.errorType;
			return links.jsxFragmentType;
		}
		if (jsxFactorySymbol.Name == Checker.ReactNames.Fragment) {
			links.jsxFragmentType = c.getTypeOfSymbol(jsxFactorySymbol);
			return links.jsxFragmentType;
		}
		var resolvedAlias = jsxFactorySymbol;
		if ((jsxFactorySymbol.Flags & SymbolFlagsAlias) != 0) {
			resolvedAlias = c.resolveAlias(jsxFactorySymbol);
		}

		final reactExports = c.getExportsOfSymbol(resolvedAlias);
		final typeSymbol = c.getSymbol(reactExports, Checker.ReactNames.Fragment, SymbolFlagsBlockScopedVariable);
		if (typeSymbol != null) {
			links.jsxFragmentType = c.getTypeOfSymbol(typeSymbol);
		} else {
			links.jsxFragmentType = c.errorType;
		}
		return links.jsxFragmentType;
	}

	static function resolveJsxOpeningLikeElement(c:Checker, node:Node, candidatesOutArray:Array<Signature>, checkMode:CheckMode):Signature {
		final isJsxOpenFragment = Ast.IsJsxOpeningFragment(node);
		var exprTypes:Type = null;
		if (!isJsxOpenFragment) {
			if (Checker.isJsxIntrinsicTagName(node.TagName())) {
				final result = c.getIntrinsicAttributesTypeFromJsxOpeningLikeElement(node);
				final fakeSignature = c.createSignatureForJSXIntrinsic(node, result);
				c.checkTypeAssignableToAndOptionallyElaborate(c.checkExpressionWithContextualType(node.Attributes(), c.getEffectiveFirstArgumentForJsxSignature(fakeSignature, node), null /*inferenceContext*/, CheckModeNormal), result, node.TagName(), node.Attributes(), null, null);
				final typeArguments = node.TypeArguments();
				if (Core.len(typeArguments) != 0) {
					c.checkSourceElements(typeArguments);
					final sourceFile = Ast.GetSourceFileOfNode(node);
					final typeArgumentList = node.TypeArgumentList();
					final loc = Core.NewTextRange(Scanner.SkipTrivia(sourceFile.Text(), typeArgumentList.Loc.Pos()), typeArgumentList.Loc.End());
					c.addDiagnostic(Ast.NewDiagnostic(sourceFile, loc, Diagnostics.Expected_0_type_arguments_but_got_1, 0, typeArguments.length));
				}
				return fakeSignature;
			}
			exprTypes = c.checkExpression(node.TagName());
		} else {
			exprTypes = c.getJSXFragmentType(node);
		}
		final apparentType = c.getApparentType(exprTypes);
		if (c.isErrorType(apparentType)) {
			return c.resolveErrorCall(node);
		}
		final signatures = c.getUninstantiatedJsxSignaturesOfType(exprTypes, node);
		if (c.isUntypedFunctionCall(exprTypes, apparentType, Core.len(signatures), 0 /*constructSignatures*/)) {
			return c.resolveUntypedCall(node);
		}
		if (Core.len(signatures) == 0) {
			// We found no signatures at all, which is an error
			if (isJsxOpenFragment) {
				c.error(node, Diagnostics.JSX_element_type_0_does_not_have_any_construct_or_call_signatures, Scanner.GetTextOfNode(node));
			} else {
				c.error(node.TagName(), Diagnostics.JSX_element_type_0_does_not_have_any_construct_or_call_signatures, Scanner.GetTextOfNode(node.TagName()));
			}
			return c.resolveErrorCall(node);
		}
		return c.resolveCall(node, signatures, candidatesOutArray, checkMode, SignatureFlagsNone, null);
	}

	// Check if the given signature can possibly be a signature called by the JSX opening-like element.
	// @param node a JSX opening-like element we are trying to figure its call signature
	// @param signature a candidate signature we are trying whether it is a call signature
	// @param relation a relationship to check parameter and argument type
	static function checkApplicableSignatureForJsxCallLikeElement(c:Checker, node:Node, signature:Signature, relation:Relation, checkMode:CheckMode, reportErrors:Bool, diagnosticOutput:Array<Diagnostic>):Bool {
		// Stateless function components can have maximum of three arguments: "props", "context", and "updater".
		// However "context" and "updater" are implicit and can't be specify by users. Only the first parameter, props,
		// can be specified by users through attributes property.
		final paramType = c.getEffectiveFirstArgumentForJsxSignature(signature, node);
		var attributesType:Type = null;
		if (Ast.IsJsxOpeningFragment(node)) {
			attributesType = c.createJsxAttributesTypeFromAttributesProperty(node, CheckModeNormal);
		} else {
			attributesType = c.checkExpressionWithContextualType(node.Attributes(), paramType, null /*inferenceContext*/, checkMode);
		}
		var checkAttributesType:Type = null;
		final checkTagNameDoesNotExpectTooManyArguments = () -> {
			if (c.getJsxNamespaceContainerForImplicitImport(node) != null) {
				return true; // factory is implicitly jsx/jsxdev - assume it fits the bill, since we don't strongly look for the jsx/jsxs/jsxDEV factory APIs anywhere else (at least not yet)
			}
			// We assume fragments have the correct arity since the node does not have attributes
			var tagType:Type = null;
			if ((Ast.IsJsxOpeningElement(node) || Ast.IsJsxSelfClosingElement(node)) && !(Checker.isJsxIntrinsicTagName(node.TagName()) || Ast.IsJsxNamespacedName(node.TagName()))) {
				tagType = c.checkExpression(node.TagName());
			}
			if (tagType == null) {
				return true;
			}
			final tagCallSignatures = c.getSignaturesOfType(tagType, SignatureKindCall);
			if (Core.len(tagCallSignatures) == 0) {
				return true;
			}
			final factory = c.getJsxFactoryEntity(node);
			if (factory == null) {
				return true;
			}
			final factorySymbol = c.resolveEntityName(factory, SymbolFlagsValue, true /*ignoreErrors*/, false /*dontResolveAlias*/, node);
			if (factorySymbol == null) {
				return true;
			}

			final factoryType = c.getTypeOfSymbol(factorySymbol);
			final callSignatures = c.getSignaturesOfType(factoryType, SignatureKindCall);
			if (Core.len(callSignatures) == 0) {
				return true;
			}
			var hasFirstParamSignatures = false;
			var maxParamCount = 0;
			// Check that _some_ first parameter expects a FC-like thing, and that some overload of the SFC expects an acceptable number of arguments
			for (sig in callSignatures) {
				final firstparam = c.getTypeAtPosition(sig, 0);
				final signaturesOfParam = c.getSignaturesOfType(firstparam, SignatureKindCall);
				if (Core.len(signaturesOfParam) == 0) {
					continue;
				}
				for (paramSig in signaturesOfParam) {
					hasFirstParamSignatures = true;
					if (c.hasEffectiveRestParameter(paramSig)) {
						return true; // some signature has a rest param, so function components can have an arbitrary number of arguments
					}
					final paramCount = c.getParameterCount(paramSig);
					if (paramCount > maxParamCount) {
						maxParamCount = paramCount;
					}
				}
			}
			if (!hasFirstParamSignatures) {
				// Not a single signature had a first parameter which expected a signature - for back compat, and
				// to guard against generic factories which won't have signatures directly, do not error
				return true;
			}
			var absoluteMinArgCount = 2147483647; // PORT: Go math.MaxInt (argument counts fit in 32 bits)
			for (tagSig in tagCallSignatures) {
				final tagRequiredArgCount = c.getMinArgumentCount(tagSig);
				if (tagRequiredArgCount < absoluteMinArgCount) {
					absoluteMinArgCount = tagRequiredArgCount;
				}
			}
			if (absoluteMinArgCount <= maxParamCount) {
				return true; // some signature accepts the number of arguments the function component provides
			}
			if (reportErrors) {
				final tagName = node.TagName();
				// We will not report errors in this function for fragments, since we do not check them in this function
				final diag = Checker.NewDiagnosticForNode(tagName, Diagnostics.Tag_0_expects_at_least_1_arguments_but_the_JSX_factory_2_provides_at_most_3, Checker.entityNameToString(tagName), absoluteMinArgCount, Checker.entityNameToString(factory), maxParamCount);
				final tagNameSymbol = c.getSymbolAtLocation(tagName, false);
				if (tagNameSymbol != null && tagNameSymbol.ValueDeclaration != null) {
					diag.AddRelatedInfo(Checker.NewDiagnosticForNode(tagNameSymbol.ValueDeclaration, Diagnostics.X_0_is_declared_here, Checker.entityNameToString(tagName)));
				}
				c.reportDiagnostic(diag, diagnosticOutput);
			}
			return false;
		};
		if ((checkMode & CheckModeSkipContextSensitive) != 0) {
			checkAttributesType = c.getRegularTypeOfObjectLiteral(attributesType);
		} else {
			checkAttributesType = attributesType;
		}
		if (!checkTagNameDoesNotExpectTooManyArguments()) {
			return false;
		}
		var errorNode:Node = null;
		if (reportErrors) {
			if (Ast.IsJsxOpeningFragment(node)) {
				errorNode = node;
			} else {
				errorNode = node.TagName();
			}
		}
		var attributes:Node = null;
		if (!Ast.IsJsxOpeningFragment(node)) {
			attributes = node.Attributes();
		}
		return c.checkTypeRelatedToAndOptionallyElaborate(checkAttributesType, paramType, relation, errorNode, attributes, null, diagnosticOutput);
	}

	// Get attributes type of the JSX opening-like element. The result is from resolving "attributes" property of the opening-like element.
	//
	// @param openingLikeElement a JSX opening-like element
	// @param filter a function to remove attributes that will not participate in checking whether attributes are assignable
	// @return an anonymous type (similar to the one returned by checkObjectLiteral) in which its properties are attributes property.
	// @remarks Because this function calls getSpreadType, it needs to use the same checks as checkObjectLiteral,
	// which also calls getSpreadType.
	static function createJsxAttributesTypeFromAttributesProperty(c:Checker, openingLikeElement:Node, checkMode:CheckMode):Type {
		var allAttributesTable:SymbolTable = null;
		if (c.strictNullChecks) {
			allAttributesTable = new SymbolTable();
		}
		var attributesTable = new SymbolTable();
		var attributesSymbol:Symbol = null;
		var attributeParent = openingLikeElement;
		var spread = c.emptyJsxObjectType;
		var hasSpreadAnyType = false;
		var typeToIntersect:Type = null;
		var explicitlySpecifyChildrenAttribute = false;
		var objectFlags = ObjectFlagsJsxAttributes;
		final createJsxAttributesType = () -> {
			objectFlags |= ObjectFlagsFreshLiteral;
			final result = c.newAnonymousType(attributesSymbol, attributesTable, null, null, null);
			result.objectFlags |= objectFlags | ObjectFlagsObjectLiteral | ObjectFlagsContainsObjectOrArrayLiteral;
			return result;
		};
		final jsxChildrenPropertyName = c.getJsxElementChildrenPropertyName(c.getJsxNamespaceAt(openingLikeElement));
		final isJsxOpenFragment = Ast.IsJsxOpeningFragment(openingLikeElement);
		if (!isJsxOpenFragment) {
			final attributes = openingLikeElement.Attributes();
			attributesSymbol = attributes.Symbol();
			attributeParent = attributes;
			final contextualType = c.getContextualType(attributes, ContextFlagsNone);
			// Create anonymous type from given attributes symbol table.
			// @param symbol a symbol of JsxAttributes containing attributes corresponding to attributesTable
			// @param attributesTable a symbol table of attributes property
			for (attributeDecl in rangeOf(attributes.Properties())) {
				final member = attributeDecl.Symbol();
				if (Ast.IsJsxAttribute(attributeDecl)) {
					final exprType = c.checkJsxAttribute(attributeDecl, checkMode);
					objectFlags |= (exprType.objectFlags & ObjectFlagsPropagatingFlags);
					final attributeSymbol = c.newSymbol(SymbolFlagsProperty | member.Flags, member.Name);
					attributeSymbol.Declarations = member.Declarations;
					attributeSymbol.Parent = member.Parent;
					if (member.ValueDeclaration != null) {
						attributeSymbol.ValueDeclaration = member.ValueDeclaration;
					}
					final links = c.valueSymbolLinks.Get(attributeSymbol);
					links.resolvedType = exprType;
					links.target = member;
					attributesTable.set(attributeSymbol.Name, attributeSymbol);
					if (allAttributesTable != null) {
						allAttributesTable.set(attributeSymbol.Name, attributeSymbol);
					}
					if (attributeDecl.Name().Text() == jsxChildrenPropertyName) {
						explicitlySpecifyChildrenAttribute = true;
					}
					if (contextualType != null) {
						final prop = c.getPropertyOfType(contextualType, member.Name);
						if (prop != null && prop.Declarations != null && c.isDeprecatedSymbol(prop) && Ast.IsIdentifier(attributeDecl.Name())) {
							c.addDeprecatedSuggestion(attributeDecl.Name(), prop.Declarations, attributeDecl.Name().Text());
						}
					}
					if (contextualType != null && (checkMode & CheckModeInferential) != 0 && (checkMode & CheckModeSkipContextSensitive) == 0 && c.isContextSensitive(attributeDecl)) {
						final inferenceContext = c.getInferenceContext(attributes);
						Debug.Assert(inferenceContext != null);
						// In CheckMode.Inferential we should always have an inference context
						final inferenceNode = attributeDecl.Initializer().Expression();
						c.addIntraExpressionInferenceSite(inferenceContext, inferenceNode, exprType);
					}
				} else {
					Debug.Assert(attributeDecl.Kind == KindJsxSpreadAttribute);
					if (symbolTableHasEntries(attributesTable)) {
						spread = c.getSpreadType(spread, createJsxAttributesType(), attributesSymbol, objectFlags, false /*readonly*/);
						attributesTable = new SymbolTable();
					}
					final exprType = c.getReducedType(c.checkExpressionEx(attributeDecl.Expression(), checkMode & CheckModeInferential));
					if (Checker.IsTypeAny(exprType)) {
						hasSpreadAnyType = true;
					}
					if (c.isValidSpreadType(exprType)) {
						spread = c.getSpreadType(spread, exprType, attributesSymbol, objectFlags, false /*readonly*/);
						if (allAttributesTable != null) {
							c.checkSpreadPropOverrides(exprType, allAttributesTable, attributeDecl);
						}
					} else {
						c.error(attributeDecl.Expression(), Diagnostics.Spread_types_may_only_be_created_from_object_types);
						if (typeToIntersect != null) {
							typeToIntersect = c.getIntersectionType([typeToIntersect, exprType]);
						} else {
							typeToIntersect = exprType;
						}
					}
				}
			}
			if (!hasSpreadAnyType) {
				if (symbolTableHasEntries(attributesTable)) {
					spread = c.getSpreadType(spread, createJsxAttributesType(), attributesSymbol, objectFlags, false /*readonly*/);
				}
			}
		}
		final parentHasSemanticJsxChildren = (openingLikeElement:Node) -> {
			// Handle children attribute
			final parent = openingLikeElement.Parent;
			if (parent == null) {
				return false;
			}
			var children:Array<Node> = null;

			if (Ast.IsJsxElement(parent)) {
				// We have to check that openingElement of the parent is the one we are visiting as this may not be true for selfClosingElement
				if (parent.AsJsxElement().OpeningElement == openingLikeElement) {
					children = parent.Children().Nodes;
				}
			} else if (Ast.IsJsxFragment(parent)) {
				if (parent.AsJsxFragment().OpeningFragment == openingLikeElement) {
					children = parent.Children().Nodes;
				}
			}
			return Core.len(Ast.GetSemanticJsxChildren(children)) != 0;
		};
		if (parentHasSemanticJsxChildren(openingLikeElement)) {
			final childTypes:Array<Type> = c.checkJsxChildren(openingLikeElement.Parent, checkMode);
			if (!hasSpreadAnyType && jsxChildrenPropertyName != Ast.InternalSymbolNameMissing && jsxChildrenPropertyName != "") {
				// Error if there is a attribute named "children" explicitly specified and children element.
				// This is because children element will overwrite the value from attributes.
				// Note: we will not warn "children" attribute overwritten if "children" attribute is specified in object spread.
				if (explicitlySpecifyChildrenAttribute) {
					c.error(attributeParent, Diagnostics.X_0_are_specified_twice_The_attribute_named_0_will_be_overwritten, jsxChildrenPropertyName);
				}
				var childrenContextualType:Type = null;
				if (Ast.IsJsxOpeningElement(openingLikeElement)) {
					final contextualType = c.getApparentTypeOfContextualType(openingLikeElement.Attributes(), ContextFlagsNone);
					if (contextualType != null) {
						childrenContextualType = c.getTypeOfPropertyOfContextualType(contextualType, jsxChildrenPropertyName);
					}
				}
				// If there are children in the body of JSX element, create dummy attribute "children" with the union of children types so that it will pass the attribute checking process
				final childrenPropSymbol = c.newSymbol(SymbolFlagsProperty, jsxChildrenPropertyName);
				final links = c.valueSymbolLinks.Get(childrenPropSymbol);
				if (Core.len(childTypes) == 1) {
					links.resolvedType = childTypes[0];
				} else if (childrenContextualType != null && Checker.someType(childrenContextualType, t -> c.isTupleLikeType(t))) {
					links.resolvedType = c.createTupleType(childTypes);
				} else {
					links.resolvedType = c.createArrayType(c.getUnionType(childTypes));
				}
				// Fake up a property declaration for the children
				childrenPropSymbol.ValueDeclaration = c.factory.NewPropertySignatureDeclaration(null, c.factory.NewIdentifier(jsxChildrenPropertyName), null /*postfixToken*/, null /*type*/, null /*initializer*/);
				childrenPropSymbol.ValueDeclaration.Parent = attributeParent;
				childrenPropSymbol.ValueDeclaration.AsPropertySignatureDeclaration().Symbol = childrenPropSymbol;
				final childPropMap = new SymbolTable();
				childPropMap.set(jsxChildrenPropertyName, childrenPropSymbol);
				spread = c.getSpreadType(spread, c.newAnonymousType(attributesSymbol, childPropMap, null, null, null), attributesSymbol, objectFlags | c.getPropagatingFlagsOfTypes(childTypes, TypeFlagsNone), false /*readonly*/);
			}
		}
		if (hasSpreadAnyType) {
			return c.anyType;
		}
		if (typeToIntersect != null) {
			if (spread != c.emptyJsxObjectType) {
				return c.getIntersectionType([typeToIntersect, spread]);
			}
			return typeToIntersect;
		}
		if (spread == c.emptyJsxObjectType) {
			return createJsxAttributesType();
		}
		return spread;
	}

	static function checkJsxAttribute(c:Checker, node:Node, checkMode:CheckMode):Type {
		if (node.Initializer() != null) {
			return c.checkExpressionForMutableLocation(node.Initializer(), checkMode);
		}
		// <Elem attr /> is sugar for <Elem attr={true} />
		return c.trueType;
	}

	static function checkJsxChildren(c:Checker, node:Node, checkMode:CheckMode):Array<Type> {
		var childTypes:Array<Type> = null;
		for (child in rangeOf(node.Children().Nodes)) {
			// In React, JSX text that contains only whitespaces will be ignored so we don't want to type-check that
			// because then type of children property will have constituent of string type.
			if (Ast.IsJsxText(child)) {
				if (!child.AsJsxText().ContainsOnlyTriviaWhiteSpaces) {
					childTypes = appendType(childTypes, c.stringType);
				}
			} else if (Ast.IsJsxExpression(child) && child.Expression() == null) {
				// empty jsx expressions don't *really* count as present children
				continue;
			} else {
				childTypes = appendType(childTypes, c.checkExpressionForMutableLocation(child, checkMode));
			}
		}
		return childTypes;
	}

	static function getUninstantiatedJsxSignaturesOfType(c:Checker, elementType:Type, caller:Node):Array<Signature> {
		if ((elementType.flags & TypeFlagsString) != 0) {
			return [c.anySignature];
		}
		if ((elementType.flags & TypeFlagsStringLiteral) != 0) {
			final intrinsicType = c.getIntrinsicAttributesTypeFromStringLiteralType(elementType, caller);
			if (intrinsicType == null) {
				c.error(caller, Diagnostics.Property_0_does_not_exist_on_type_1, Checker.getStringLiteralValue(elementType), "JSX." + Checker.JsxNames.IntrinsicElements);
				return null;
			}
			final fakeSignature = c.createSignatureForJSXIntrinsic(caller, intrinsicType);
			return [fakeSignature];
		}
		final apparentElemType = c.getApparentType(elementType);
		// Resolve the signatures, preferring constructor
		var signatures = c.getSignaturesOfType(apparentElemType, SignatureKindConstruct);
		if (Core.len(signatures) == 0) {
			// No construct signatures, try call signatures
			signatures = c.getSignaturesOfType(apparentElemType, SignatureKindCall);
		}
		if (Core.len(signatures) == 0 && (apparentElemType.flags & TypeFlagsUnion) != 0) {
			// If each member has some combination of new/call signatures; make a union signature list for those
			signatures = c.getUnionSignatures(Core.Map(apparentElemType.Types(), t -> c.getUninstantiatedJsxSignaturesOfType(t, caller)));
		}
		return signatures;
	}

	static function getEffectiveFirstArgumentForJsxSignature(c:Checker, signature:Signature, node:Node):Type {
		if (Ast.IsJsxOpeningFragment(node) || c.getJsxReferenceKind(node) != JsxReferenceKindComponent) {
			return c.getJsxPropsTypeFromCallSignature(signature, node);
		}
		return c.getJsxPropsTypeFromClassType(signature, node);
	}

	static function getJsxPropsTypeFromCallSignature(c:Checker, sig:Signature, context:Node):Type {
		var propsType = c.getTypeOfFirstParameterOfSignatureWithFallback(sig, c.unknownType);
		propsType = c.getJsxManagedAttributesFromLocatedAttributes(context, c.getJsxNamespaceAt(context), propsType);
		final intrinsicAttribs = c.getJsxType(Checker.JsxNames.IntrinsicAttributes, context);
		if (!c.isErrorType(intrinsicAttribs)) {
			propsType = c.intersectTypes(intrinsicAttribs, propsType);
		}
		return propsType;
	}

	static function getJsxPropsTypeFromClassType(c:Checker, sig:Signature, context:Node):Type {
		final ns = c.getJsxNamespaceAt(context);
		final forcedLookupLocation = c.getJsxElementPropertiesName(ns);
		var attributesType:Type = null;
		// PORT: Go switch on a string with a non-literal case value as if/else.
		if (forcedLookupLocation == Ast.InternalSymbolNameMissing) {
			attributesType = c.getTypeOfFirstParameterOfSignatureWithFallback(sig, c.unknownType);
		} else if (forcedLookupLocation == "") {
			attributesType = c.getReturnTypeOfSignature(sig);
		} else {
			attributesType = c.getJsxPropsTypeForSignatureFromMember(sig, forcedLookupLocation);
			if (attributesType == null && Core.len(context.Attributes().Properties()) != 0) {
				// There is no property named 'props' on this instance type
				c.error(context, Diagnostics.JSX_element_class_does_not_support_attributes_because_it_does_not_have_a_0_property, forcedLookupLocation);
			}
		}
		if (attributesType == null) {
			return c.unknownType;
		}
		attributesType = c.getJsxManagedAttributesFromLocatedAttributes(context, ns, attributesType);
		if (Checker.IsTypeAny(attributesType)) {
			// Props is of type 'any' or unknown
			return attributesType;
		}
		// Normal case -- add in IntrinsicClassAttributes<T> and IntrinsicAttributes
		var apparentAttributesType = attributesType;
		final intrinsicClassAttribs = c.getJsxType(Checker.JsxNames.IntrinsicClassAttributes, context);
		if (!c.isErrorType(intrinsicClassAttribs)) {
			final typeParams = c.getLocalTypeParametersOfClassOrInterfaceOrTypeAlias(intrinsicClassAttribs.symbol);
			final hostClassType = c.getReturnTypeOfSignature(sig);
			var libraryManagedAttributeType:Type = null;
			if (typeParams != null) {
				// apply JSX.IntrinsicClassAttributes<hostClassType, ...>
				final inferredArgs = c.fillMissingTypeArguments([hostClassType], typeParams, c.getMinTypeArgumentCount(typeParams), Ast.IsInJSFile(context));
				libraryManagedAttributeType = c.instantiateType(intrinsicClassAttribs, Checker.newTypeMapper(typeParams, inferredArgs));
			} else {
				libraryManagedAttributeType = intrinsicClassAttribs;
			}
			apparentAttributesType = c.intersectTypes(libraryManagedAttributeType, apparentAttributesType);
		}
		final intrinsicAttribs = c.getJsxType(Checker.JsxNames.IntrinsicAttributes, context);
		if (!c.isErrorType(intrinsicAttribs)) {
			apparentAttributesType = c.intersectTypes(intrinsicAttribs, apparentAttributesType);
		}
		return apparentAttributesType;
	}

	static function getJsxPropsTypeForSignatureFromMember(c:Checker, sig:Signature, forcedLookupLocation:std.String):Type {
		if (sig.composite != null) {
			// JSX Elements using the legacy `props`-field based lookup (eg, react class components) need to treat the `props` member as an input
			// instead of an output position when resolving the signature. We need to go back to the input signatures of the composite signature,
			// get the type of `props` on each return type individually, and then _intersect them_, rather than union them (as would normally occur
			// for a union signature). It's an unfortunate quirk of looking in the output of the signature for the type we want to use for the input.
			// The default behavior of `getTypeOfFirstParameterOfSignatureWithFallback` when no `props` member name is defined is much more sane.
			var results:Array<Type> = null;
			for (signature in rangeOf(sig.composite.signatures)) {
				final instance = c.getReturnTypeOfSignature(signature);
				if (Checker.IsTypeAny(instance)) {
					return instance;
				}
				final propType = c.getTypeOfPropertyOfType(instance, forcedLookupLocation);
				if (propType == null) {
					return null;
				}
				results = appendType(results, propType);
			}
			return c.getIntersectionType(results);
			// Same result for both union and intersection signatures
		}
		final instanceType = c.getReturnTypeOfSignature(sig);
		if (Checker.IsTypeAny(instanceType)) {
			return instanceType;
		}
		return c.getTypeOfPropertyOfType(instanceType, forcedLookupLocation);
	}

	static function getJsxManagedAttributesFromLocatedAttributes(c:Checker, context:Node, ns:Symbol, attributesType:Type):Type {
		final managedSym = c.getJsxLibraryManagedAttributes(ns);
		if (managedSym != null) {
			final ctorType = c.getStaticTypeOfReferencedJsxConstructor(context);
			final result = c.instantiateAliasOrInterfaceWithDefaults(managedSym, [ctorType, attributesType], Ast.IsInJSFile(context));
			if (result != null) {
				return result;
			}
		}
		return attributesType;
	}

	static function instantiateAliasOrInterfaceWithDefaults(c:Checker, managedSym:Symbol, typeArguments:Array<Type>, inJavaScript:Bool):Type {
		final declaredManagedType = c.getDeclaredTypeOfSymbol(managedSym);
		// fetches interface type, or initializes symbol links type parameters
		if ((managedSym.Flags & SymbolFlagsTypeAlias) != 0) {
			final params = c.typeAliasLinks.Get(managedSym).typeParameters;
			if (Core.len(params) >= Core.len(typeArguments)) {
				final args = c.fillMissingTypeArguments(typeArguments, params, Core.len(typeArguments), inJavaScript);
				if (Core.len(args) == 0) {
					return declaredManagedType;
				}
				return c.getTypeAliasInstantiation(managedSym, args, null);
			}
		}
		if ((declaredManagedType.objectFlags & ObjectFlagsClassOrInterface) != 0 && Core.len(declaredManagedType.AsInterfaceType().TypeParameters()) >= Core.len(typeArguments)) {
			final args = c.fillMissingTypeArguments(typeArguments, declaredManagedType.AsInterfaceType().TypeParameters(), Core.len(typeArguments), inJavaScript);
			return c.createTypeReference(declaredManagedType, args);
		}
		return null;
	}

	static function getJsxLibraryManagedAttributes(c:Checker, jsxNamespace:Symbol):Symbol {
		if (jsxNamespace != null) {
			return c.getSymbol(jsxNamespace.Exports, Checker.JsxNames.LibraryManagedAttributes, SymbolFlagsType);
		}
		return null;
	}

	static function getJsxElementTypeSymbol(c:Checker, jsxNamespace:Symbol):Symbol {
		// JSX.ElementType [symbol]
		if (jsxNamespace != null) {
			return c.getSymbol(jsxNamespace.Exports, Checker.JsxNames.ElementType, SymbolFlagsType);
		}
		return null;
	}

	// e.g. "props" for React.d.ts,
	// or InternalSymbolNameMissing if ElementAttributesProperty doesn't exist (which means all
	//
	//	non-intrinsic elements' attributes type is 'any'),
	//
	// or "" if it has 0 properties (which means every
	//
	//	non-intrinsic elements' attributes type is the element instance type)
	static function getJsxElementPropertiesName(c:Checker, jsxNamespace:Symbol):std.String {
		return c.getNameFromJsxElementAttributesContainer(Checker.JsxNames.ElementAttributesPropertyNameContainer, jsxNamespace);
	}

	static function getJsxElementChildrenPropertyName(c:Checker, jsxNamespace:Symbol):std.String {
		if (c.compilerOptions.Jsx == JsxEmitReactJSX || c.compilerOptions.Jsx == JsxEmitReactJSXDev) {
			// In these JsxEmit modes the children property is fixed to 'children'
			return "children";
		}
		return c.getNameFromJsxElementAttributesContainer(Checker.JsxNames.ElementChildrenAttributeNameContainer, jsxNamespace);
	}

	// Look into JSX namespace and then look for container with matching name as nameOfAttribPropContainer.
	// Get a single property from that container if existed. Report an error if there are more than one property.
	//
	// @param nameOfAttribPropContainer a string of value JsxNames.ElementAttributesPropertyNameContainer or JsxNames.ElementChildrenAttributeNameContainer
	//
	//	if other string is given or the container doesn't exist, return undefined.
	static function getNameFromJsxElementAttributesContainer(c:Checker, nameOfAttribPropContainer:std.String, jsxNamespace:Symbol):std.String {
		// JSX.ElementAttributesProperty | JSX.ElementChildrenAttribute [symbol]
		if (jsxNamespace != null) {
			final jsxElementAttribPropInterfaceSym = c.getSymbol(jsxNamespace.Exports, nameOfAttribPropContainer, SymbolFlagsType);
			if (jsxElementAttribPropInterfaceSym != null) {
				final jsxElementAttribPropInterfaceType = c.getDeclaredTypeOfSymbol(jsxElementAttribPropInterfaceSym);
				final propertiesOfJsxElementAttribPropInterface = c.getPropertiesOfType(jsxElementAttribPropInterfaceType);
				// Element Attributes has zero properties, so the element attributes type will be the class instance type
				if (Core.len(propertiesOfJsxElementAttribPropInterface) == 0) {
					return "";
				}
				if (propertiesOfJsxElementAttribPropInterface.length == 1) {
					return propertiesOfJsxElementAttribPropInterface[0].Name;
				}
				if (propertiesOfJsxElementAttribPropInterface.length > 1 && Core.len(jsxElementAttribPropInterfaceSym.Declarations) != 0) {
					// More than one property on ElementAttributesProperty is an error
					c.error(jsxElementAttribPropInterfaceSym.Declarations[0], Diagnostics.The_global_type_JSX_0_may_not_have_more_than_one_property, nameOfAttribPropContainer);
				}
			}
		}
		return Ast.InternalSymbolNameMissing;
	}

	static function getStaticTypeOfReferencedJsxConstructor(c:Checker, context:Node):Type {
		if (Ast.IsJsxOpeningFragment(context)) {
			return c.getJSXFragmentType(context);
		}
		if (Checker.isJsxIntrinsicTagName(context.TagName())) {
			final result = c.getIntrinsicAttributesTypeFromJsxOpeningLikeElement(context);
			final fakeSignature = c.createSignatureForJSXIntrinsic(context, result);
			return c.getOrCreateTypeFromSignature(fakeSignature);
		}
		final tagType = c.checkExpressionCached(context.TagName());
		if ((tagType.flags & TypeFlagsStringLiteral) != 0) {
			final result = c.getIntrinsicAttributesTypeFromStringLiteralType(tagType, context);
			if (result == null) {
				return c.errorType;
			}
			final fakeSignature = c.createSignatureForJSXIntrinsic(context, result);
			return c.getOrCreateTypeFromSignature(fakeSignature);
		}
		return tagType;
	}

	static function getIntrinsicAttributesTypeFromStringLiteralType(c:Checker, t:Type, location:Node):Type {
		// If the elemType is a stringLiteral type, we can then provide a check to make sure that the string literal type is one of the Jsx intrinsic element type
		// For example:
		//      var CustomTag: "h1" = "h1";
		//      <CustomTag> Hello World </CustomTag>
		final intrinsicElementsType = c.getJsxType(Checker.JsxNames.IntrinsicElements, location);
		if (!c.isErrorType(intrinsicElementsType)) {
			final stringLiteralTypeName = Checker.getStringLiteralValue(t);
			final intrinsicProp = c.getPropertyOfType(intrinsicElementsType, stringLiteralTypeName);
			if (intrinsicProp != null) {
				return c.getTypeOfSymbol(intrinsicProp);
			}
			final indexSignatureType = c.getIndexTypeOfType(intrinsicElementsType, c.stringType);
			if (indexSignatureType != null) {
				return indexSignatureType;
			}
			return null;
		}
		// If we need to report an error, we already done so here. So just return any to prevent any more error downstream
		return c.anyType;
	}

	static function getJsxReferenceKind(c:Checker, node:Node):JsxReferenceKind {
		if (Checker.isJsxIntrinsicTagName(node.TagName())) {
			return JsxReferenceKindMixed;
		}
		final tagType = c.getApparentType(c.checkExpression(node.TagName()));
		if (Core.len(c.getSignaturesOfType(tagType, SignatureKindConstruct)) != 0) {
			return JsxReferenceKindComponent;
		}
		if (Core.len(c.getSignaturesOfType(tagType, SignatureKindCall)) != 0) {
			return JsxReferenceKindFunction;
		}
		return JsxReferenceKindMixed;
	}

	static function createSignatureForJSXIntrinsic(c:Checker, node:Node, result:Type):Signature {
		var elementType = c.errorType;
		final namespace = c.getJsxNamespaceAt(node);
		if (namespace != null) {
			final typeSymbol = c.getSymbol(c.getExportsOfSymbol(namespace), Checker.JsxNames.Element, SymbolFlagsType);
			if (typeSymbol != null) {
				elementType = c.getDeclaredTypeOfSymbol(typeSymbol);
			}
		}
		// returnNode := typeSymbol && c.nodeBuilder.symbolToEntityName(typeSymbol, ast.SymbolFlagsType, node)
		// declaration := factory.createFunctionTypeNode(nil, []ParameterDeclaration{factory.createParameterDeclaration(nil, nil /*dotDotDotToken*/, "props", nil /*questionToken*/, c.nodeBuilder.typeToTypeNode(result, node))}, ifElse(returnNode != nil, factory.createTypeReferenceNode(returnNode, nil /*typeArguments*/), factory.createKeywordTypeNode(ast.KindAnyKeyword)))
		final parameterSymbol = c.newSymbol(SymbolFlagsFunctionScopedVariable, "props");
		c.valueSymbolLinks.Get(parameterSymbol).resolvedType = result;
		return c.newSignature(SignatureFlagsNone, null, null, null, [parameterSymbol], elementType, null, 1);
	}

	// Get attributes type of the given intrinsic opening-like Jsx element by resolving the tag name.
	// The function is intended to be called from a function which has checked that the opening element is an intrinsic element.
	// @param node an intrinsic JSX opening-like element
	static function getIntrinsicAttributesTypeFromJsxOpeningLikeElement(c:Checker, node:Node):Type {
		Debug.Assert(Checker.isJsxIntrinsicTagName(node.TagName()));
		final links = c.jsxElementLinks.Get(node);
		if (links.resolvedJsxElementAttributesType != null) {
			return links.resolvedJsxElementAttributesType;
		}
		final symbol = c.getIntrinsicTagSymbol(node);
		if ((links.jsxFlags & JsxFlagsIntrinsicNamedElement) != 0) {
			links.resolvedJsxElementAttributesType = Core.OrElse(c.getTypeOfSymbol(symbol), c.errorType);
			return links.resolvedJsxElementAttributesType;
		}
		if ((links.jsxFlags & JsxFlagsIntrinsicIndexedElement) != 0) {
			final indexInfo = c.getApplicableIndexInfoForName(c.getJsxType(Checker.JsxNames.IntrinsicElements, node), node.TagName().Text());
			if (indexInfo != null) {
				links.resolvedJsxElementAttributesType = indexInfo.valueType;
				return links.resolvedJsxElementAttributesType;
			}
		}
		links.resolvedJsxElementAttributesType = c.errorType;
		return links.resolvedJsxElementAttributesType;
	}

	// Looks up an intrinsic tag name and returns a symbol that either points to an intrinsic
	// property (in which case nodeLinks.jsxFlags will be IntrinsicNamedElement) or an intrinsic
	// string index signature (in which case nodeLinks.jsxFlags will be IntrinsicIndexedElement).
	// May also return unknownSymbol if both of these lookups fail.
	static function getIntrinsicTagSymbol(c:Checker, node:Node):Symbol {
		final links = c.symbolNodeLinks.Get(node);
		if (links.resolvedSymbol != null) {
			return links.resolvedSymbol;
		}
		final intrinsicElementsType = c.getJsxType(Checker.JsxNames.IntrinsicElements, node);
		if (!c.isErrorType(intrinsicElementsType)) {
			// Property case
			final tagName = node.TagName();
			if (!Ast.IsIdentifier(tagName) && !Ast.IsJsxNamespacedName(tagName)) {
				throw "Invalid tag name";
			}
			final propName = tagName.Text();
			final intrinsicProp = c.getPropertyOfType(intrinsicElementsType, propName);
			if (intrinsicProp != null) {
				c.jsxElementLinks.Get(node).jsxFlags |= JsxFlagsIntrinsicNamedElement;
				links.resolvedSymbol = intrinsicProp;
				return links.resolvedSymbol;
			}
			// Intrinsic string indexer case
			final indexSymbol = c.getApplicableIndexSymbol(intrinsicElementsType, c.getStringLiteralType(propName));
			if (indexSymbol != null) {
				c.jsxElementLinks.Get(node).jsxFlags |= JsxFlagsIntrinsicIndexedElement;
				links.resolvedSymbol = indexSymbol;
				return links.resolvedSymbol;
			}
			if (c.getTypeOfPropertyOrIndexSignatureOfType(intrinsicElementsType, propName) != null) {
				c.jsxElementLinks.Get(node).jsxFlags |= JsxFlagsIntrinsicIndexedElement;
				links.resolvedSymbol = intrinsicElementsType.symbol;
				return links.resolvedSymbol;
			}
			// Wasn't found
			c.error(node, Diagnostics.Property_0_does_not_exist_on_type_1, tagName.Text(), "JSX." + Checker.JsxNames.IntrinsicElements);
			links.resolvedSymbol = c.unknownSymbol;
			return links.resolvedSymbol;
		}
		if (c.noImplicitAny) {
			c.error(node, Diagnostics.JSX_element_implicitly_has_type_any_because_no_interface_JSX_0_exists, Checker.JsxNames.IntrinsicElements);
		}
		links.resolvedSymbol = c.unknownSymbol;
		return links.resolvedSymbol;
	}

	static function getJsxStatelessElementTypeAt(c:Checker, location:Node):Type {
		final jsxElementType = c.getJsxElementTypeAt(location);
		if (jsxElementType == null) {
			return null;
		}
		return c.getUnionType([jsxElementType, c.nullType]);
	}

	static function getJsxElementClassTypeAt(c:Checker, location:Node):Type {
		final t = c.getJsxType(Checker.JsxNames.ElementClass, location);
		if (c.isErrorType(t)) {
			return null;
		}
		return t;
	}

	static function getJsxElementTypeAt(c:Checker, location:Node):Type {
		return c.getJsxType(Checker.JsxNames.Element, location);
	}

	static function getJsxElementTypeTypeAt(c:Checker, location:Node):Type {
		final ns = c.getJsxNamespaceAt(location);
		if (ns == null) {
			return null;
		}
		final sym = c.getJsxElementTypeSymbol(ns);
		if (sym == null) {
			return null;
		}
		final t = c.instantiateAliasOrInterfaceWithDefaults(sym, null, Ast.IsInJSFile(location));
		if (t == null || c.isErrorType(t)) {
			return null;
		}
		return t;
	}

	static function getJsxType(c:Checker, name:std.String, location:Node):Type {
		final namespace = c.getJsxNamespaceAt(location);
		if (namespace != null) {
			final exports = c.getExportsOfSymbol(namespace);
			if (exports != null) {
				final typeSymbol = c.getSymbol(exports, name, SymbolFlagsType);
				if (typeSymbol != null) {
					return c.getDeclaredTypeOfSymbol(typeSymbol);
				}
			}
		}
		return c.errorType;
	}

	static function getJsxNamespaceAt(c:Checker, location:Node):Symbol {
		var links:JsxElementLinks = null;
		if (location != null) {
			links = c.jsxElementLinks.Get(location);
		}
		if (links != null && links.jsxNamespace != null && links.jsxNamespace != c.unknownSymbol) {
			return links.jsxNamespace;
		}
		if (links == null || links.jsxNamespace != c.unknownSymbol) {
			var resolvedNamespace = c.getJsxNamespaceContainerForImplicitImport(location);
			if (resolvedNamespace == null || resolvedNamespace == c.unknownSymbol) {
				final namespaceName = c.getJsxNamespace(location);
				resolvedNamespace = c.resolveName(location, namespaceName, SymbolFlagsNamespace, null /*nameNotFoundMessage*/, false /*isUse*/, false /*excludeGlobals*/);
			}
			if (resolvedNamespace != null) {
				final candidate = c.resolveSymbol(c.getSymbol(c.getExportsOfSymbol(c.resolveSymbol(resolvedNamespace)), Checker.JsxNames.JSX, SymbolFlagsNamespace));
				if (candidate != null && candidate != c.unknownSymbol) {
					if (links != null) {
						links.jsxNamespace = candidate;
					}
					return candidate;
				}
			}
			if (links != null) {
				links.jsxNamespace = c.unknownSymbol;
			}
		}
		// JSX global fallback
		final s = c.resolveSymbol(c.getGlobalSymbol(Checker.JsxNames.JSX, SymbolFlagsNamespace, null /*diagnostic*/));
		if (s == c.unknownSymbol) {
			return null;
		}
		return s;
	}

	static function getJsxNamespace(c:Checker, location:Node):std.String {
		if (location != null) {
			final file = Ast.GetSourceFileOfNode(location);
			if (file != null) {
				final links = c.sourceFileLinks.Get(file);
				if (Ast.IsJsxOpeningFragment(location)) {
					if (links.localJsxFragmentNamespace != "") {
						return links.localJsxFragmentNamespace;
					}
					final jsxFragmentPragma = Ast.GetPragmaFromSourceFile(file, "jsxfrag");
					if (jsxFragmentPragma != null) {
						links.localJsxFragmentFactory = c.parseIsolatedEntityName(pragmaArgValue(jsxFragmentPragma, "factory"));
						if (links.localJsxFragmentFactory != null) {
							links.localJsxFragmentNamespace = Ast.GetFirstIdentifier(links.localJsxFragmentFactory).Text();
							return links.localJsxFragmentNamespace;
						}
					}
					final entity = c.getJsxFragmentFactoryEntity(location);
					if (entity != null) {
						links.localJsxFragmentFactory = entity;
						links.localJsxFragmentNamespace = Ast.GetFirstIdentifier(entity).Text();
						return links.localJsxFragmentNamespace;
					}
				} else {
					final localJsxNamespace = c.getLocalJsxNamespace(file);
					if (localJsxNamespace != "") {
						links.localJsxNamespace = localJsxNamespace;
						return links.localJsxNamespace;
					}
				}
			}
		}
		if (c._jsxNamespace == "") {
			c._jsxNamespace = "React";
			if (c.compilerOptions.JsxFactory != "") {
				c._jsxFactoryEntity = c.parseIsolatedEntityName(c.compilerOptions.JsxFactory);
				if (c._jsxFactoryEntity != null) {
					c._jsxNamespace = Ast.GetFirstIdentifier(c._jsxFactoryEntity).Text();
				}
			} else if (c.compilerOptions.ReactNamespace != "") {
				c._jsxNamespace = c.compilerOptions.ReactNamespace;
			}
		}
		if (c._jsxFactoryEntity == null) {
			c._jsxFactoryEntity = c.factory.NewQualifiedName(c.factory.NewIdentifier(c._jsxNamespace), c.factory.NewIdentifier("createElement"));
		}
		return c._jsxNamespace;
	}

	static function getLocalJsxNamespace(c:Checker, file:SourceFile):std.String {
		final links = c.sourceFileLinks.Get(file);
		if (links.localJsxNamespace != "") {
			return links.localJsxNamespace;
		}
		final jsxPragma = Ast.GetPragmaFromSourceFile(file, "jsx");
		if (jsxPragma != null) {
			links.localJsxFactory = c.parseIsolatedEntityName(pragmaArgValue(jsxPragma, "factory"));
			if (links.localJsxFactory != null) {
				links.localJsxNamespace = Ast.GetFirstIdentifier(links.localJsxFactory).Text();
				return links.localJsxNamespace;
			}
		}
		return "";
	}

	static function getJsxFactoryEntity(c:Checker, location:Node):Node {
		if (location != null) {
			c.getJsxNamespace(location);
			final localJsxFactory = c.sourceFileLinks.Get(Ast.GetSourceFileOfNode(location)).localJsxFactory;
			if (localJsxFactory != null) {
				return localJsxFactory;
			}
		}
		return c._jsxFactoryEntity;
	}

	static function getJsxFragmentFactoryEntity(c:Checker, location:Node):EntityName {
		if (location != null) {
			final file = Ast.GetSourceFileOfNode(location);
			if (file != null) {
				final links = c.sourceFileLinks.Get(file);
				if (links.localJsxFragmentFactory != null) {
					return links.localJsxFragmentFactory;
				}
				final jsxFragPragma = Ast.GetPragmaFromSourceFile(file, "jsxfrag");
				if (jsxFragPragma != null) {
					links.localJsxFragmentFactory = c.parseIsolatedEntityName(pragmaArgValue(jsxFragPragma, "factory"));
					return links.localJsxFragmentFactory;
				}
			}
		}
		if (c.compilerOptions.JsxFragmentFactory != "") {
			return c.parseIsolatedEntityName(c.compilerOptions.JsxFragmentFactory);
		}
		return null;
	}

	static function parseIsolatedEntityName(c:Checker, name:std.String):Node {
		final result = Parser.ParseIsolatedEntityName(name);
		if (result != null) {
			Checker.markAsSynthetic(result);
		}
		return result;
	}

	static function getJsxNamespaceContainerForImplicitImport(c:Checker, location:Node):Symbol {
		var file:SourceFile = null;
		var links:JsxElementLinks = null;
		if (location != null) {
			file = Ast.GetSourceFileOfNode(location);
			if (file != null) {
				links = c.jsxElementLinks.Get(file.AsNode());
			}
		}
		if (links != null && links.jsxImplicitImportContainer != null) {
			return Core.IfElse(links.jsxImplicitImportContainer == c.unknownSymbol, null, links.jsxImplicitImportContainer);
		}
		final r = c.getJSXRuntimeImportSpecifier(file);
		final moduleReference = r.a;
		final specifier = r.b;
		if (moduleReference == "") {
			return null;
		}
		final errorMessage = Diagnostics.This_JSX_tag_requires_the_module_path_0_to_exist_but_none_could_be_found_Make_sure_you_have_types_for_the_appropriate_package_installed;
		final mod = c.resolveExternalModule(Core.OrElse(specifier, location), moduleReference, errorMessage, location, false);
		var result:Symbol = null;
		if (mod != null && mod != c.unknownSymbol) {
			result = c.getMergedSymbol(c.resolveSymbol(mod));
		}
		if (links != null) {
			links.jsxImplicitImportContainer = Core.OrElse(result, c.unknownSymbol);
		}
		return result;
	}

	static function getJSXRuntimeImportSpecifier(c:Checker, file:SourceFile):Pair<std.String, Node> {
		return c.program.GetJSXRuntimeImportSpecifier(file.Path());
	}

	// --- private helpers (PORT) ---

	// PORT: Go `range` over a possibly-nil slice.
	static inline function rangeOf<T>(s:Null<Array<T>>):Array<T> {
		return s != null ? s : [];
	}

	// PORT: Go map lookup `table[name]` on a possibly-nil ast.SymbolTable (nil map reads as empty).
	static inline function symbolTableGet(table:SymbolTable, name:std.String):Symbol {
		return table != null ? table.get(name) : null;
	}

	// PORT: Go `len(table) != 0` on an ast.SymbolTable.
	static inline function symbolTableHasEntries(table:SymbolTable):Bool {
		return table != null && table.keys().hasNext();
	}

	// PORT: Go `append(s, t)` on a possibly-nil []*Type owned by the caller.
	static inline function appendType(s:Array<Type>, t:Type):Array<Type> {
		if (s == null) {
			return [t];
		}
		s.push(t);
		return s;
	}

	// PORT: Go `pragma.Args[name].Value`: a missing key reads as the zero PragmaArgument (Value "").
	static function pragmaArgValue(pragma:Pragma, name:std.String):std.String {
		final arg = pragma.Args != null ? pragma.Args.get(name) : null;
		return arg != null ? arg.Value : "";
	}

	// PORT: Go composite literal JsxElaborationElement{errorNode: ..., innerExpression: ..., nameType: ..., createDiagnostic: ...}.
	static function newElaborationElement(errorNode:Node, innerExpression:Node, nameType:Type, createDiagnostic:(prop:Node) -> Diagnostic):JsxElaborationElement {
		final e = new JsxElaborationElement();
		e.errorNode = errorNode;
		e.innerExpression = innerExpression;
		e.nameType = nameType;
		e.createDiagnostic = createDiagnostic;
		return e;
	}
}
