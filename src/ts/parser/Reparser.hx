package ts.parser;

// Port of reparser.go: the Parser methods of reparser.go as a static extension (PORTING.md §2),
// used via `using ts.parser.Reparser`. The package-level funcs of reparser.go are in class Parser.
@:allow(ts.parser)
class Reparser {
	static function finishReparsedNode(p:Parser, node:Node, locationNode:Node):Void {
		node.Flags = p.contextFlags | NodeFlagsReparsed;
		node.Loc = locationNode.Loc;
		p.overrideParentInImmediateChildren(node);
	}

	static function finishMutatedNode(p:Parser, node:Node):Void {
		p.overrideParentInImmediateChildren(node);
	}

	// Deep-clone the given node and add the clone to the reparsed clone list. The list is used by ast.GetReparsedNodeForNode
	// to locate reparsed clones of JSDoc nodes. Since the binder attaches symbols to reparsed nodes and not to JSDoc nodes, we
	// need the mapping when obtaining symbols and types from JSDoc nodes.
	static function addDeepCloneReparse(p:Parser, node:Node):Node {
		var clone = p.factory.DeepCloneReparse(node);
		if (clone != null) {
			p.reparsedClones = Parser.append(p.reparsedClones, clone);
		}
		return clone;
	}

	static function addTransformedReparse(p:Parser, newNode:Node, old:Node):Node {
		p.finishReparsedNode(newNode, old);
		newNode.Flags |= NodeFlagsReparserTransformedLiteral;
		p.reparsedClones = Parser.append(p.reparsedClones, newNode);
		return newNode;
	}

	static function checkNonIdentifierName(p:Parser, name:Node):Node {
		if (Ast.IsIdentifier(name) && !Scanner.IsValidIdentifier(name.AsIdentifier().Text)) {
			var errLoc = name.Loc;
			if (errLoc.Len() == 0) { // missing name, emit error on the character before the missing name node
				errLoc = Core.NewTextRange(name.Loc.Pos()-1, name.Loc.Pos());
			}
			p.parseErrorAtRange(errLoc, Diagnostics.Identifier_expected);
		}
		return name;
	}

	// Hosted tags find a host and add their children to the correct location under the host.
	// Unhosted tags add synthetic nodes to the reparse list.
	static function reparseTags(p:Parser, parent:Node, jsDoc:Array<Node>):Void {
		for (j in jsDoc) {
			var isLast = j == jsDoc[jsDoc.length - 1];
			var tags = j.AsJSDoc().Tags;
			if (tags == null) {
				continue;
			}
			for (tag in Parser.nodesOf(tags.Nodes)) {
				p.reparseUnhosted(tag, parent, j);
				if (isLast) {
					p.reparseHosted(tag, parent, j);
				}
			}
		}
	}

	static function reparseUnhosted(p:Parser, tag:Node, parent:Node, jsDoc:Node):Void {
		switch (tag.Kind) {
		case KindJSDocTypedefTag:
			var typeExpression = tag.TypeExpression();
			if (typeExpression == null) {
				return; // PORT: Go `break` out of the switch (nothing follows it)
			}
			var fullName = tag.Name();
			var isNamespace = fullName != null && Ast.IsModuleDeclaration(fullName);
			var modifiers:ModifierList = null;
			if (isNamespace) {
				modifiers = p.createExportModifier(tag);
			}
			var typeAlias = p.factory.NewJSTypeAliasDeclaration(modifiers, p.addDeepCloneReparse(p.checkNonIdentifierName(p.getInnermostNameOfJSDocNamespace(fullName))), null, null);
			typeAlias.AsTypeAliasDeclaration().TypeParameters = p.gatherTypeParameters(jsDoc, true /*typedefOrCallback*/);
			var t:Node = null;
			switch (typeExpression.Kind) {
			case KindJSDocTypeExpression:
				t = p.addDeepCloneReparse(typeExpression.Type());
			case KindJSDocTypeLiteral:
				t = p.reparseJSDocTypeLiteral(typeExpression);
			default:
				throw "typedef tag type expression should be a name reference or a type expression" + typeExpression.Kind.String();
			}
			typeAlias.AsTypeAliasDeclaration().Type = t;
			p.finishReparsedNode(typeAlias, tag);
			p.jsdocInfos = Parser.append(p.jsdocInfos, new JSDocInfo(typeAlias, [jsDoc]));
			typeAlias.Flags |= NodeFlagsHasJSDoc;
			var result = p.wrapInJSDocNamespace(fullName, typeAlias, false /*nested*/);
			p.reparseList = Parser.append(p.reparseList, result);
		case KindJSDocCallbackTag:
			var typeExpression = tag.TypeExpression();
			if (typeExpression == null) {
				return; // PORT: Go `break` out of the switch (nothing follows it)
			}
			var fullName = tag.Name();
			var isNamespace = fullName != null && Ast.IsModuleDeclaration(fullName);
			var modifiers:ModifierList = null;
			if (isNamespace) {
				modifiers = p.createExportModifier(tag);
			}
			var functionType = p.reparseJSDocSignature(typeExpression, tag, jsDoc, tag, null);
			var typeAlias = p.factory.NewJSTypeAliasDeclaration(modifiers, p.addDeepCloneReparse(p.getInnermostNameOfJSDocNamespace(fullName)), null, functionType);
			typeAlias.AsTypeAliasDeclaration().TypeParameters = p.gatherTypeParameters(jsDoc, true /*typedefOrCallback*/);
			p.finishReparsedNode(typeAlias, tag);
			p.jsdocInfos = Parser.append(p.jsdocInfos, new JSDocInfo(typeAlias, [jsDoc]));
			typeAlias.Flags |= NodeFlagsHasJSDoc;
			var result = p.wrapInJSDocNamespace(fullName, typeAlias, false /*nested*/);
			p.reparseList = Parser.append(p.reparseList, result);
		case KindJSDocImportTag:
			var importTag = tag.AsJSDocImportTag();
			if (importTag.ImportClause == null) {
				return; // PORT: Go `break` out of the switch (nothing follows it)
			}
			var importClause = p.addDeepCloneReparse(importTag.ImportClause);
			importClause.AsImportClause().PhaseModifier = KindTypeKeyword;
			var importDeclaration = p.factory.NewJSImportDeclaration(p.factory.DeepCloneReparseModifiers(importTag.Modifiers()), importClause,
				p.addDeepCloneReparse(importTag.ModuleSpecifier), p.addDeepCloneReparse(importTag.Attributes));
			p.finishReparsedNode(importDeclaration, tag);
			p.reparseList = Parser.append(p.reparseList, importDeclaration);
		case KindJSDocOverloadTag:
			// Create overload signatures only for function, method, and constructor declarations outside object literals
			if ((Ast.IsFunctionDeclaration(parent) || Ast.IsMethodDeclaration(parent) || Ast.IsConstructorDeclaration(parent)) && p.parsingContexts & (1 << PCObjectLiteralMembers) == 0) {
				p.reparseList = Parser.append(p.reparseList, p.reparseJSDocSignature(tag.AsJSDocOverloadTag().TypeExpression, parent, jsDoc, tag, parent.Modifiers()));
			}
		default:
		}
	}

	static function reparseJSDocSignature(p:Parser, jsSignature:Node, fun:Node, jsDoc:Node, tag:Node, modifiers:ModifierList):Node {
		var signature:Node = null;
		var clonedModifiers = p.factory.DeepCloneReparseModifiers(modifiers);
		switch (fun.Kind) {
		case KindFunctionDeclaration:
			signature = p.factory.NewFunctionDeclaration(clonedModifiers, null, p.factory.DeepCloneReparse(p.checkNonIdentifierName(fun.Name())), null, null, null, null, null);
		case KindMethodDeclaration:
			signature = p.factory.NewMethodDeclaration(clonedModifiers, null, p.factory.DeepCloneReparse(p.checkNonIdentifierName(fun.Name())), null, null, null, null, null, null);
		case KindConstructor:
			signature = p.factory.NewConstructorDeclaration(clonedModifiers, null, null, null, null, null);
		case KindJSDocCallbackTag:
			signature = p.factory.NewFunctionTypeNode(null, null, p.factory.NewKeywordTypeNode(KindAnyKeyword));
		default:
			throw "Unexpected kind " + fun.Kind.String();
		}

		if (tag.Kind != KindJSDocCallbackTag) {
			signature.FunctionLikeData().TypeParameters = p.gatherTypeParameters(jsDoc, false /*typedefOrCallback*/);
		}
		var parameters:Array<Node> = null; // PORT: arena — Go p.nodeSliceArena.NewSlice(0) (nil)
		final jsParameters = jsSignature.Parameters();
		for (pi in 0...Core.len(jsParameters)) {
			final param = jsParameters[pi];
			var parameter:Node = null;
			if (param.Kind == KindJSDocThisTag) {
				var thisTag = param.AsJSDocThisTag();
				var thisIdent = p.factory.NewIdentifier("this");
				thisIdent.Loc = thisTag.Loc;
				thisIdent.Flags = p.contextFlags | NodeFlagsReparsed;
				parameter = p.factory.NewParameterDeclaration(null, null, thisIdent, null, null, null);
				if (thisTag.TypeExpression != null) {
					parameter.AsParameterDeclaration().Type = p.addDeepCloneReparse(thisTag.TypeExpression.Type());
				}
			} else if (param.Kind == KindJSDocParameterTag || param.Kind == KindJSDocPropertyTag) {
				var jsparam = param.AsJSDocParameterOrPropertyTag();
				// Skip sub-property parameters (e.g., @param x.y) - these have QualifiedNames
				// and describe properties of a parent parameter, not standalone parameters.
				if (Ast.IsQualifiedName(jsparam.Name())) {
					continue;
				}
				var dotDotDotToken:Node = null;
				var paramType:TypeNode = null;

				if (jsparam.TypeExpression != null) {
					if (jsparam.TypeExpression.Type().Kind == KindJSDocVariadicType) {
						dotDotDotToken = p.factory.NewToken(KindDotDotDotToken);
						dotDotDotToken.Loc = jsparam.Loc;
						dotDotDotToken.Flags = p.contextFlags | NodeFlagsReparsed;

						var variadicType = jsparam.TypeExpression.Type().AsJSDocVariadicType();
						paramType = p.reparseJSDocTypeLiteral(variadicType.Type);
					} else {
						paramType = p.reparseJSDocTypeLiteral(jsparam.TypeExpression.Type());
					}
				}
				var name = jsparam.Name();
				if (Ast.IsIdentifier(name) && !Scanner.IsValidIdentifier(name.AsIdentifier().Text)) {
					// drop invalid chars for _, if empty, write _0, etc., so we have a valid param name to emit later
					var result = new StringBuf();
					// PORT: utf16 — Go ranges over runes (i is the byte offset; only i == 0 is tested).
					final text = name.AsIdentifier().Text;
					var i = 0;
					while (i < text.length) {
						final ch = Utf16.DecodeRuneInString(text, i);
						if (i == 0) {
							if (!Scanner.IsIdentifierStart(ch)) {
								Utf16.WriteRune(result, "_".code);
							} else {
								Utf16.WriteRune(result, ch);
							}
						} else if (!Scanner.IsIdentifierPart(ch)) {
							Utf16.WriteRune(result, "_".code);
						} else {
							Utf16.WriteRune(result, ch);
						}
						i += Utf16.RuneLen(ch);
					}
					if (result.length == 0) {
						Utf16.WriteRune(result, "_".code);
						result.add(Std.string(pi));
					}
					name = p.addTransformedReparse(p.factory.NewIdentifier(result.toString()), name);
				} else {
					name = p.addDeepCloneReparse(name);
				}
				parameter = p.factory.NewParameterDeclaration(null, dotDotDotToken, name, p.makeQuestionIfOptional(jsparam), paramType, null);
			}
			p.finishReparsedNode(parameter, param);
			parameters = Parser.append(parameters, parameter);
			p.reparseJSDocComment(parameter, param);
		}
		signature.FunctionLikeData().Parameters = p.newNodeList(jsSignature.AsJSDocSignature().Parameters.Loc, parameters);

		if (jsSignature.Type() != null && jsSignature.Type().TypeExpression() != null) {
			signature.FunctionLikeData().Type = p.addDeepCloneReparse(jsSignature.Type().TypeExpression().Type());
		}
		var loc = jsSignature;
		if (tag.Kind == KindJSDocOverloadTag) {
			loc = tag.TagName();
		}
		p.finishReparsedNode(signature, loc);
		return signature;
	}

	static function reparseJSDocTypeLiteral(p:Parser, t:TypeNode):Node {
		if (t == null) {
			return null;
		}
		if (t.Kind == KindJSDocTypeLiteral) {
			var jstypeliteral = t.AsJSDocTypeLiteral();
			var isArrayType = jstypeliteral.IsArrayType;
			var properties:Array<Node> = null; // PORT: arena — Go p.nodeSliceArena.NewSlice(0) (nil)
			for (prop in Parser.nodesOf(jstypeliteral.JSDocPropertyTags)) {
				if (prop.Kind != KindJSDocPropertyTag && prop.Kind != KindJSDocParameterTag) {
					continue;
				}
				var jsprop = prop.AsJSDocParameterOrPropertyTag();
				var name = prop.Name();
				if (name.Kind == KindQualifiedName) {
					name = name.AsQualifiedName().Right;
				}
				if (Ast.IsIdentifier(name) && !Scanner.IsValidIdentifier(name.AsIdentifier().Text)) {
					name = p.addTransformedReparse(p.factory.NewStringLiteral(name.AsIdentifier().Text, TokenFlagsNone), name);
				} else {
					name = p.addDeepCloneReparse(name);
				}
				var property = p.factory.NewPropertySignatureDeclaration(null, name, p.makeQuestionIfOptional(jsprop), null, null);
				if (jsprop.TypeExpression != null) {
					property.AsPropertySignatureDeclaration().Type = p.reparseJSDocTypeLiteral(jsprop.TypeExpression.Type());
				}
				p.finishReparsedNode(property, prop);
				properties = Parser.append(properties, property);
				p.reparseJSDocComment(property, prop);
			}
			t = p.factory.NewTypeLiteralNode(p.newNodeList(jstypeliteral.Loc, properties));
			if (isArrayType) {
				p.finishReparsedNode(t, jstypeliteral.AsNode());
				t = p.factory.NewArrayTypeNode(t);
			}
			p.finishReparsedNode(t, jstypeliteral.AsNode());
			return t;
		}
		return p.addDeepCloneReparse(t);
	}

	static function reparseJSDocComment(p:Parser, node:Node, tag:Node):Void {
		final comment = tag.CommentList();
		if (comment != null) {
			var newComment = p.factory.NewNodeList(Core.Map(comment.Nodes, p.factory.DeepCloneReparse));
			newComment.Loc = comment.Loc;
			var propJSDoc = p.factory.NewJSDoc(newComment, null);
			p.finishReparsedNode(propJSDoc, tag);
			propJSDoc.Parent = node;
			p.jsdocInfos = Parser.append(p.jsdocInfos, new JSDocInfo(node, [propJSDoc]));
			node.Flags |= NodeFlagsHasJSDoc;
		}
	}

	static function gatherTypeParameters(p:Parser, j:Node, typedefOrCallback:Bool):NodeList {
		var typeParameters:Array<Node> = null;
		var pos = -1;
		var endPos = -1;
		var firstTemplate = true;
		for (tag in Parser.nodesOf(j.AsJSDoc().Tags.Nodes)) {
			// When a JSDoc comment contains an `@typedef` or `@callback` tag, `@template` type parameter
			// declarations apply to the type being defined.
			if (!typedefOrCallback && (Ast.IsJSDocTypedefTag(tag) || Ast.IsJSDocCallbackTag(tag))) {
				return null;
			}
			if (!Ast.IsJSDocTemplateTag(tag)) {
				continue;
			}
			if (firstTemplate) {
				pos = tag.Pos();
				firstTemplate = false;
			}
			endPos = tag.End();
			var constraint = tag.AsJSDocTemplateTag().Constraint;
			var firstTypeParameter = true;
			for (tp in Parser.nodesOf(tag.TypeParameters())) {
				var reparse:Node = null;
				if (constraint != null && firstTypeParameter) {
					reparse = p.factory.NewTypeParameterDeclaration(p.factory.DeepCloneReparseModifiers(tp.Modifiers()),
						p.addDeepCloneReparse(p.checkNonIdentifierName(tp.Name())), p.addDeepCloneReparse(constraint.Type()), null, // expression
						p.addDeepCloneReparse(tp.AsTypeParameterDeclaration().DefaultType));
					p.finishReparsedNode(reparse, tp);
				} else {
					reparse = p.addDeepCloneReparse(tp);
				}
				if (typeParameters == null) {
					typeParameters = null;
				}
				typeParameters = Parser.append(typeParameters, reparse);
				firstTypeParameter = false;
			}
		}
		if (Core.len(typeParameters) == 0) {
			return null;
		} else {
			return p.newNodeList(Core.NewTextRange(pos, endPos), typeParameters);
		}
	}

	static function reparseHosted(p:Parser, tag:Node, parent:Node, jsDoc:Node):Void {
		switch (tag.Kind) {
		case KindJSDocTypeTag:
			switch (parent.Kind) {
			case KindVariableStatement:
				if (parent.AsVariableStatement().DeclarationList != null) {
					for (declaration in Parser.nodesOf(parent.AsVariableStatement().DeclarationList.AsVariableDeclarationList().Declarations.Nodes)) {
						if (declaration.Type() == null && tag.TypeExpression() != null) {
							declaration.AsMutable().SetType(p.addDeepCloneReparse(tag.TypeExpression().Type()));
							p.finishMutatedNode(declaration);
							return;
						}
					}
				}
			case KindVariableDeclaration | KindExportAssignment | KindPropertyDeclaration | KindPropertyAssignment | KindShorthandPropertyAssignment |
				KindGetAccessor:
				if (parent.Type() == null && tag.TypeExpression() != null) {
					parent.AsMutable().SetType(p.addDeepCloneReparse(tag.TypeExpression().Type()));
					p.finishMutatedNode(parent);
					return;
				}
			case KindParameter:
				if (parent.Type() == null && tag.TypeExpression() != null) {
					parent.AsMutable().SetType(p.reparseJSDocTypeLiteral(tag.TypeExpression().Type()));
					p.finishMutatedNode(parent);
					return;
				}
			case KindExpressionStatement:
				if (parent.Expression().Kind == KindBinaryExpression) {
					var bin = parent.Expression().AsBinaryExpression();
					final kind = Ast.GetAssignmentDeclarationKind(bin.AsNode());
					if (kind != JSDeclarationKindNone && tag.TypeExpression() != null) {
						bin.AsNode().AsMutable().SetType(p.addDeepCloneReparse(tag.TypeExpression().Type()));
						p.finishMutatedNode(bin.AsNode());
						return;
					}
				}
			case KindReturnStatement | KindParenthesizedExpression:
				if (parent.Expression() != null && tag.TypeExpression() != null) {
					parent.AsMutable().SetExpression(p.makeNewCast(p.addDeepCloneReparse(tag.TypeExpression().Type()), parent.Expression(), true /*isAssertion*/));
					p.finishMutatedNode(parent);
					return;
				}
			default:
			}
			final fun = Parser.getFunctionLikeHost(parent);
			if (fun != null) {
				var noTypedParams = Core.Every(fun.Parameters(), Parser.paramHasNoType);
				if (fun.TypeParameterList() == null && fun.Type() == null && noTypedParams && tag.TypeExpression() != null) {
					fun.FunctionLikeData().FullSignature = p.addDeepCloneReparse(tag.TypeExpression().Type());
					p.finishMutatedNode(fun);
				}
			}
		case KindJSDocSatisfiesTag:
			switch (parent.Kind) {
			case KindVariableStatement:
				if (parent.AsVariableStatement().DeclarationList != null) {
					for (declaration in Parser.nodesOf(parent.AsVariableStatement().DeclarationList.AsVariableDeclarationList().Declarations.Nodes)) {
						if (declaration.Initializer() != null && tag.TypeExpression() != null) {
							declaration.AsMutable().SetInitializer(p.makeNewCast(p.addDeepCloneReparse(tag.TypeExpression().Type()), declaration.Initializer(), false /*isAssertion*/));
							p.finishMutatedNode(declaration);
							break;
						}
					}
				}
			case KindVariableDeclaration | KindPropertyDeclaration | KindPropertyAssignment:
				if (parent.Initializer() != null && tag.TypeExpression() != null) {
					parent.AsMutable().SetInitializer(p.makeNewCast(p.addDeepCloneReparse(tag.TypeExpression().Type()), parent.Initializer(), false /*isAssertion*/));
					p.finishMutatedNode(parent);
				}
			case KindShorthandPropertyAssignment:
				var shorthand = parent.AsShorthandPropertyAssignment();
				if (shorthand.ObjectAssignmentInitializer != null && tag.AsJSDocSatisfiesTag().TypeExpression != null) {
					shorthand.ObjectAssignmentInitializer = p.makeNewCast(p.addDeepCloneReparse(tag.AsJSDocSatisfiesTag().TypeExpression.Type()),
						shorthand.ObjectAssignmentInitializer, false /*isAssertion*/);
					p.finishMutatedNode(parent);
				}
			case KindReturnStatement | KindParenthesizedExpression | KindExportAssignment:
				if (parent.Expression() != null && tag.TypeExpression() != null) {
					parent.AsMutable().SetExpression(p.makeNewCast(p.addDeepCloneReparse(tag.TypeExpression().Type()), parent.Expression(), false /*isAssertion*/));
					p.finishMutatedNode(parent);
				}
			case KindExpressionStatement:
				if (parent.Expression().Kind == KindBinaryExpression) {
					var bin = parent.Expression().AsBinaryExpression();
					final kind = Ast.GetAssignmentDeclarationKind(bin.AsNode());
					if (kind != JSDeclarationKindNone && tag.TypeExpression() != null) {
						bin.Right = p.makeNewCast(p.addDeepCloneReparse(tag.TypeExpression().Type()), bin.Right, false /*isAssertion*/);
						p.finishMutatedNode(bin.AsNode());
					}
				}
			default:
			}
		case KindJSDocTemplateTag:
			final fun = Parser.getFunctionLikeHost(parent);
			if (fun != null) {
				if (fun.TypeParameters() == null && fun.FunctionLikeData().FullSignature == null) {
					fun.FunctionLikeData().TypeParameters = p.gatherTypeParameters(jsDoc, false /*typedefOrCallback*/);
					p.finishMutatedNode(fun);
				}
			} else if (parent.Kind == KindClassDeclaration) {
				var class_ = parent.AsClassDeclaration();
				if (class_.TypeParameters == null) {
					class_.TypeParameters = p.gatherTypeParameters(jsDoc, false /*typedefOrCallback*/);
					p.finishMutatedNode(parent);
				}
			} else if (parent.Kind == KindClassExpression) {
				var class_ = parent.AsClassExpression();
				if (class_.TypeParameters == null) {
					class_.TypeParameters = p.gatherTypeParameters(jsDoc, false /*typedefOrCallback*/);
					p.finishMutatedNode(parent);
				}
			}
		case KindJSDocParameterTag:
			final fun = Parser.getFunctionLikeHost(parent);
			if (fun != null && fun.FunctionLikeData().FullSignature == null) {
				var parameterTag = tag.AsJSDocParameterOrPropertyTag();
				final param = Parser.findMatchingParameter(fun, parameterTag, jsDoc);
				if (param != null) { // PORT: Go `ok`
					if (param.Type == null && parameterTag.TypeExpression != null) {
						param.AsNode().AsParameterDeclaration().Type = p.reparseJSDocTypeLiteral(parameterTag.TypeExpression.Type());
					}
					if (param.QuestionToken == null) {
						final question = p.makeQuestionIfOptional(parameterTag);
						if (question != null) {
							param.QuestionToken = question;
						}
					}
					p.finishMutatedNode(param.AsNode());
				}
			}
		case KindJSDocThisTag:
			final fun = Parser.getFunctionLikeHost(parent);
			if (fun != null) {
				var params = fun.Parameters();
				if (Core.len(params) == 0 || (params[0].Name().Kind != KindThisKeyword && !Ast.IsThisIdentifier(params[0].Name()))) {
					var thisParam = p.factory.NewParameterDeclaration(null /* decorators */, null /* modifiers */, p.factory.NewIdentifier("this"),
						null /* questionToken */, null /* type */, null /* initializer */);
					if (tag.AsJSDocThisTag().TypeExpression != null) {
						thisParam.AsParameterDeclaration().Type = p.addDeepCloneReparse(tag.AsJSDocThisTag().TypeExpression.Type());
					}
					p.finishReparsedNode(thisParam, tag.TagName());

					var newParams:Array<Node> = [thisParam]; // PORT: arena — Go p.nodeSliceArena.NewSlice(len(params) + 1)
					for (i in 0...Core.len(params)) {
						newParams[i + 1] = params[i];
					}

					fun.FunctionLikeData().Parameters = p.newNodeList(fun.ParameterList().Loc, newParams);
					p.finishMutatedNode(fun);
				}
			}
		case KindJSDocReturnTag:
			final fun = Parser.getFunctionLikeHost(parent);
			if (fun != null && fun.FunctionLikeData().FullSignature == null) {
				if (fun.Type() == null && tag.TypeExpression() != null) {
					fun.FunctionLikeData().Type = p.addDeepCloneReparse(tag.TypeExpression().Type());
					p.finishMutatedNode(fun);
				}
			}
		case KindJSDocReadonlyTag | KindJSDocPrivateTag | KindJSDocPublicTag | KindJSDocProtectedTag | KindJSDocOverrideTag:
			if (parent.Kind == KindExpressionStatement) {
				parent = parent.Expression();
			}
			// PORT: `fallthrough` from the method/accessor case → local function.
			inline function modifierCase():Void {
				var keyword:Kind = KindUnknown;
				switch (tag.Kind) {
				case KindJSDocReadonlyTag:
					keyword = KindReadonlyKeyword;
				case KindJSDocPrivateTag:
					keyword = KindPrivateKeyword;
				case KindJSDocPublicTag:
					keyword = KindPublicKeyword;
				case KindJSDocProtectedTag:
					keyword = KindProtectedKeyword;
				case KindJSDocOverrideTag:
					keyword = KindOverrideKeyword;
				default:
				}
				var modifier = p.factory.NewModifier(keyword);
				modifier.Loc = tag.Loc;
				modifier.Flags = p.contextFlags | NodeFlagsReparsed;
				var nodes:Array<Node> = null;
				var loc:TextRange = new TextRange(0, 0);
				if (parent.Modifiers() == null) {
					nodes = [modifier]; // PORT: arena — Go p.nodeSliceArena.NewSlice(1)
					loc = tag.Loc;
				} else {
					// PORT: Go `append(parent.ModifierNodes(), modifier)` never changes the old list's
					// length; copy so the old ModifierList keeps its nodes.
					nodes = parent.ModifierNodes().copy();
					nodes.push(modifier);
					loc = parent.Modifiers().Loc;
				}
				parent.AsMutable().SetModifiers(p.newModifierList(loc, nodes));
				p.finishMutatedNode(parent);
			}
			switch (parent.Kind) {
			case KindMethodDeclaration | KindGetAccessor | KindSetAccessor:
				// In object literals these aren't class-like members, so JSDoc modifiers like @override
				// or @readonly aren't real modifiers there; reparsing them produces spurious grammar errors (#4437).
				if (p.parsingContexts & (1 << PCObjectLiteralMembers) != 0) {
					return;
				}
				modifierCase();
			case KindPropertyDeclaration | KindConstructor | KindBinaryExpression:
				modifierCase();
			default:
			}
		case KindJSDocImplementsTag:
			final class_ = Parser.getClassLikeData(parent);
			if (class_ != null) {
				var implementsTag = tag.AsJSDocImplementsTag();

				if (class_.HeritageClauses != null) {
					final implementsClause = Core.Find(class_.HeritageClauses.Nodes, Parser.isImplementsClauseFn);
					if (implementsClause != null) {
						implementsClause.AsHeritageClause().Types.Nodes = Parser.append(implementsClause.AsHeritageClause().Types.Nodes,
							p.addDeepCloneReparse(implementsTag.ClassName));
						p.finishMutatedNode(implementsClause);
						return;
					}
				}
				var typesList = p.newNodeList(implementsTag.ClassName.Loc, [p.addDeepCloneReparse(implementsTag.ClassName)]);

				var heritageClause = p.factory.NewHeritageClause(KindImplementsKeyword, typesList);
				p.finishReparsedNode(heritageClause, implementsTag.ClassName);

				if (class_.HeritageClauses == null) {
					var heritageClauses = p.newNodeList(implementsTag.ClassName.Loc, [heritageClause]);
					class_.HeritageClauses = heritageClauses;
				} else {
					class_.HeritageClauses.Nodes = Parser.append(class_.HeritageClauses.Nodes, heritageClause);
				}
				p.finishMutatedNode(parent);
			}
		case KindJSDocAugmentsTag:
			final class_ = Parser.getClassLikeData(parent);
			if (class_ != null && class_.HeritageClauses != null) {
				final extendsClause = Core.Find(class_.HeritageClauses.Nodes, Parser.isExtendsClauseFn);
				if (extendsClause != null && Core.len(extendsClause.AsHeritageClause().Types.Nodes) == 1) {
					var target = extendsClause.AsHeritageClause().Types.Nodes[0].AsExpressionWithTypeArguments();
					var source = tag.ClassName().AsExpressionWithTypeArguments();
					if (Ast.HasSamePropertyAccessName(target.Expression, source.Expression)) {
						if (target.TypeArguments == null && source.TypeArguments != null) {
							var newArguments:Array<Node> = []; // PORT: arena — Go p.nodeSliceArena.NewSlice(len)
							for (i in 0...Core.len(source.TypeArguments.Nodes)) {
								newArguments[i] = p.addDeepCloneReparse(source.TypeArguments.Nodes[i]);
							}
							target.TypeArguments = p.newNodeList(source.TypeArguments.Loc, Core.len(newArguments) == 0 ? null : newArguments);
							p.finishMutatedNode(target.AsNode());
						}
					}
				}
			}
		default:
		}
	}

	static function makeQuestionIfOptional(p:Parser, parameter:JSDocParameterOrPropertyTag):Node {
		var questionToken:Node = null;
		if (parameter.IsBracketed || parameter.TypeExpression != null && parameter.TypeExpression.Type().Kind == KindJSDocOptionalType) {
			questionToken = p.factory.NewToken(KindQuestionToken);
			questionToken.Loc = parameter.Loc;
			questionToken.Flags = p.contextFlags | NodeFlagsReparsed;
		}
		return questionToken;
	}

	static function makeNewCast(p:Parser, t:TypeNode, e:Node, isAssertion:Bool):Node {
		var assert:Node = null;
		if (isAssertion) {
			assert = p.factory.NewAsExpression(e, t);
		} else {
			assert = p.factory.NewSatisfiesExpression(e, t);
		}
		p.finishNodeWithEnd(assert, e.Pos(), e.End());
		return assert;
	}

	static function createExportModifier(p:Parser, locationNode:Node):ModifierList {
		var exportModifier = p.factory.NewModifier(KindExportKeyword);
		exportModifier.Loc = locationNode.Loc;
		exportModifier.Flags = p.contextFlags | NodeFlagsReparsed;
		var nodes = [exportModifier] /* PORT: arena — Go NewSlice1 */;
		return p.newModifierList(locationNode.Loc, nodes);
	}

	// getInnermostNameOfJSDocNamespace returns the innermost identifier from a
	// JSDoc namespace chain (ModuleDeclaration). For a simple identifier, it returns
	// the identifier itself. For "A.B.C", it returns the identifier "C".
	static function getInnermostNameOfJSDocNamespace(p:Parser, fullName:Node):Node {
		if (fullName == null) {
			return null;
		}
		while (fullName.Kind == KindModuleDeclaration) {
			var body = fullName.AsModuleDeclaration().Body;
			if (body == null) {
				return fullName.Name();
			}
			fullName = body;
		}
		return fullName;
	}

	// wrapInJSDocNamespace wraps a statement (typically a type alias) in namespace
	// declarations corresponding to a JSDoc dotted name. For example, given name
	// "A.B.C" and a type alias for C, this produces:
	//
	//	namespace A { namespace B { type C = ... } }
	//
	// If the name is a simple identifier (not a ModuleDeclaration), it returns the
	// statement as-is.
	static function wrapInJSDocNamespace(p:Parser, fullName:Node, statement:Node, nested:Bool):Node {
		if (fullName == null || !Ast.IsModuleDeclaration(fullName)) {
			return statement;
		}
		// Recursively wrap from outermost to innermost. Inner namespaces always get an export modifier
		// so members are accessible via dotted access from outside. The outermost namespace is treated as
		// exported only in module files via IsImplicitlyExportedJSDocDeclaration (in the binder), so it
		// does not get an explicit export modifier here.
		var wrapped = p.wrapInJSDocNamespace(fullName.Body(), statement, true /*nested*/);
		var block = p.factory.NewModuleBlock(p.newNodeList(fullName.Loc, [wrapped] /* PORT: arena — Go NewSlice1 */));
		p.finishReparsedNode(block, fullName);
		var modifiers:ModifierList = null;
		if (nested) {
			modifiers = p.createExportModifier(fullName);
		}
		var result = p.factory.NewModuleDeclaration(modifiers, KindNamespaceKeyword, p.addDeepCloneReparse(fullName.Name()), block);
		p.finishReparsedNode(result, fullName);
		p.reparsedClones = Parser.append(p.reparsedClones, result);
		return result;
	}
}
