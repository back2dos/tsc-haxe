package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/grammarchecks.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Methods of grammarchecks.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class Grammarchecks {

	static function grammarErrorOnFirstToken(c:Checker, node:Node, message:Message, ...args:Any):Bool {
		final sourceFile = Ast.GetSourceFileOfNode(node);
		if (!c.hasParseDiagnostics(sourceFile)) {
			final span = Scanner.GetRangeOfTokenAtPosition(sourceFile, node.Pos());
			c.addDiagnostic(Ast.NewDiagnostic(sourceFile, span, message, ...args));
			return true;
		}
		return false;
	}

	static function grammarErrorAtPos(c:Checker, nodeForSourceFile:Node, start:Int, length:Int, message:Message, ...args:Any):Bool {
		final sourceFile = Ast.GetSourceFileOfNode(nodeForSourceFile);
		if (!c.hasParseDiagnostics(sourceFile)) {
			c.addDiagnostic(Ast.NewDiagnostic(sourceFile, Core.NewTextRange(start, start + length), message, ...args));
			return true;
		}
		return false;
	}

	static function grammarErrorOnNode(c:Checker, node:Node, message:Message, ...args:Any):Bool {
		final sourceFile = Ast.GetSourceFileOfNode(node);
		if (!c.hasParseDiagnostics(sourceFile)) {
			c.error(node, message, ...args);
			return true;
		}
		return false;
	}

	static function grammarErrorOnNodeSkippedOnNoEmit(c:Checker, node:Node, message:Message, ...args:Any):Bool {
		final sourceFile = Ast.GetSourceFileOfNode(node);
		if (!c.hasParseDiagnostics(sourceFile)) {
			final d = Checker.NewDiagnosticForNode(node, message, ...args);
			d.SetSkippedOnNoEmit();
			c.addDiagnostic(d);
			return true;
		}
		return false;
	}

	static function checkGrammarRegularExpressionLiteral(c:Checker, node:RegularExpressionLiteral):Bool {
		final sourceFile = Ast.GetSourceFileOfNode(node.AsNode());
		if (!c.hasParseDiagnostics(sourceFile)) {
			var lastError:Diagnostic = null;
			if (c.regExpScanner == null) {
				c.regExpScanner = Scanner.NewScanner();
			}
			c.regExpScanner.SetScriptTarget(c.languageVersion);
			c.regExpScanner.SetLanguageVariant(sourceFile.LanguageVariant);
			function onError(message:Message, start:Int, length:Int, ...args:Any):Void {
				if (message.Category() == CategoryMessage && lastError != null && start == lastError.Pos() && length == lastError.Len()) {
					// For providing spelling suggestions.
					final err = Ast.NewDiagnostic(null, Core.NewTextRange(start, start + length), message, ...args);
					lastError.AddRelatedInfo(err);
				} else if (lastError == null || start != lastError.Pos()) {
					lastError = Ast.NewDiagnostic(sourceFile, Core.NewTextRange(start, start + length), message, ...args);
					c.addDiagnostic(lastError);
				}
			}
			c.regExpScanner.SetOnError(onError);
			c.regExpScanner.SetText(sourceFile.Text());
			c.regExpScanner.ResetTokenState(node.AsNode().Pos());
			c.regExpScanner.Scan();
			final tokenIsRegularExpressionLiteral = c.regExpScanner.ReScanSlashToken(true) == KindRegularExpressionLiteral;
			c.regExpScanner.SetText("");
			c.regExpScanner.SetOnError(null);
			Debug.Assert(tokenIsRegularExpressionLiteral);
			return lastError != null;
		}
		return false;
	}

	static function checkGrammarPrivateIdentifierExpression(c:Checker, privId:PrivateIdentifier):Bool {
		final privIdAsNode = privId.AsNode();
		if (Ast.GetContainingClass(privId.AsNode()) == null) {
			return c.grammarErrorOnNode(privId.AsNode(), Diagnostics.Private_identifiers_are_not_allowed_outside_class_bodies);
		}

		if (!Ast.IsForInStatement(privId.Parent)) {
			if (!Ast.IsExpressionNode(privIdAsNode)) {
				return c.grammarErrorOnNode(privIdAsNode, Diagnostics.Private_identifiers_are_only_allowed_in_class_bodies_and_may_only_be_used_as_part_of_a_class_member_declaration_property_access_or_on_the_left_hand_side_of_an_in_expression);
			}

			final isInOperation = Ast.IsBinaryExpression(privId.Parent) && privId.Parent.AsBinaryExpression().OperatorToken.Kind == KindInKeyword;
			if (c.getSymbolForPrivateIdentifierExpression(privIdAsNode) == null && !isInOperation) {
				return c.grammarErrorOnNode(privIdAsNode, Diagnostics.Cannot_find_name_0, privId.Text);
			}
		}

		return false;
	}

	static function checkGrammarMappedType(c:Checker, node:MappedTypeNode):Bool {
		if (Core.len(node.Members.Nodes) > 0) {
			return c.grammarErrorOnNode(node.Members.Nodes[0], Diagnostics.A_mapped_type_may_not_declare_properties_or_methods);
		}
		return false;
	}

	static function checkGrammarDecorator(c:Checker, decorator:Decorator):Bool {
		final sourceFile = Ast.GetSourceFileOfNode(decorator.AsNode());
		if (!c.hasParseDiagnostics(sourceFile)) {
			var node = decorator.Expression;

			// DecoratorParenthesizedExpression :
			//   `(` Expression `)`

			if (Ast.IsParenthesizedExpression(node)) {
				return false;
			}

			var canHaveCallExpression = true;
			var errorNode:Node = null;
			while (true) {
				// Allow TS syntax such as non-null assertions and instantiation expressions
				if (Ast.IsExpressionWithTypeArguments(node) || Ast.IsNonNullExpression(node)) {
					node = node.Expression();
					continue;
				}

				// DecoratorCallExpression :
				//   DecoratorMemberExpression Arguments

				if (Ast.IsCallExpression(node)) {
					final callExpr = node.AsCallExpression();
					if (!canHaveCallExpression) {
						errorNode = node;
					}
					if (callExpr.QuestionDotToken != null) {
						// Even if we already have an error node, error at the `?.` token since it appears earlier.
						errorNode = callExpr.QuestionDotToken;
					}
					node = callExpr.Expression;
					canHaveCallExpression = false;
					continue;
				}

				// DecoratorMemberExpression :
				//   IdentifierReference
				//   DecoratorMemberExpression `.` IdentifierName
				//   DecoratorMemberExpression `.` PrivateIdentifier

				if (Ast.IsPropertyAccessExpression(node)) {
					final propertyAccessExpr = node.AsPropertyAccessExpression();
					if (propertyAccessExpr.QuestionDotToken != null) {
						// Even if we already have an error node, error at the `?.` token since it appears earlier.
						errorNode = propertyAccessExpr.QuestionDotToken;
					}
					node = propertyAccessExpr.Expression;
					canHaveCallExpression = false;
					continue;
				}

				if (!Ast.IsIdentifier(node)) {
					// Even if we already have an error node, error at this node since it appears earlier.
					errorNode = node;
				}

				break;
			}

			if (errorNode != null) {
				final err = c.error(decorator.Expression, Diagnostics.Expression_must_be_enclosed_in_parentheses_to_be_used_as_a_decorator);
				err.AddRelatedInfo(Checker.createDiagnosticForNode(errorNode, Diagnostics.Invalid_syntax_in_decorator));
				return true;
			}
		}

		return false;
	}

	static function checkGrammarExportDeclaration(c:Checker, node:ExportDeclaration):Bool {
		if (node.IsTypeOnly && node.ExportClause != null && node.ExportClause.Kind == KindNamedExports) {
			return c.checkGrammarTypeOnlyNamedImportsOrExports(node.ExportClause);
		}
		return false;
	}

	static function checkGrammarModuleElementContext(c:Checker, node:Statement, errorMessage:Message):Bool {
		final isInAppropriateContext = node.Parent.Kind == KindSourceFile || node.Parent.Kind == KindModuleBlock || node.Parent.Kind == KindModuleDeclaration;
		if (!isInAppropriateContext) {
			c.grammarErrorOnFirstToken(node, errorMessage);
		}
		return !isInAppropriateContext;
	}

	static function checkGrammarModifiers(c:Checker, node:Node):Bool {
		if (node.Modifiers() == null) {
			return false;
		}
		if (c.reportObviousDecoratorErrors(node) || c.reportObviousModifierErrors(node)) {
			return true;
		}
		if (Ast.IsThisParameter(node)) {
			return c.grammarErrorOnFirstToken(node, Diagnostics.Neither_decorators_nor_modifiers_may_be_applied_to_this_parameters);
		}
		var blockScopeKind = NodeFlagsNone;
		if (Ast.IsVariableStatement(node)) {
			blockScopeKind = node.AsVariableStatement().DeclarationList.Flags & NodeFlagsBlockScoped;
		}
		var lastStatic:Node = null;
		var lastDeclare:Node = null;
		var lastAsync:Node = null;
		var lastOverride:Node = null;
		var firstDecorator:Node = null;
		var flags = ModifierFlagsNone;
		var sawExportBeforeDecorators = false;
		// We parse decorators and modifiers in four contiguous chunks:
		// [...leadingDecorators, ...leadingModifiers, ...trailingDecorators, ...trailingModifiers]. It is an error to
		// have both leading and trailing decorators.
		var hasLeadingDecorators = false;
		final modifiers = node.ModifierNodes();
		for (modifier in rangeOf(modifiers)) {
			if (Ast.IsDecorator(modifier)) {
				if (!Ast.NodeCanBeDecorated(c.legacyDecorators, node, node.Parent, node.Parent.Parent)) {
					if (node.Kind == KindMethodDeclaration && !Ast.NodeIsPresent(node.Body())) {
						return c.grammarErrorOnFirstToken(node, Diagnostics.A_decorator_can_only_decorate_a_method_implementation_not_an_overload);
					} else {
						return c.grammarErrorOnFirstToken(node, Diagnostics.Decorators_are_not_valid_here);
					}
				} else if (c.legacyDecorators && (node.Kind == KindGetAccessor || node.Kind == KindSetAccessor)) {
					final accessors = Ast.GetAllAccessorDeclarationsForDeclaration(node, c.getSymbolOfDeclaration(node).Declarations);
					if (Ast.HasDecorators(accessors.FirstAccessor) && node == accessors.SecondAccessor) {
						return c.grammarErrorOnFirstToken(node, Diagnostics.Decorators_cannot_be_applied_to_multiple_get_Slashset_accessors_of_the_same_name);
					}
				}

				// if we've seen any modifiers aside from `export`, `default`, or another decorator, then this is an invalid position
				if ((flags & ~(ModifierFlagsExportDefault | ModifierFlagsDecorator)) != 0) {
					return c.grammarErrorOnNode(modifier, Diagnostics.Decorators_are_not_valid_here);
				}

				// if we've already seen leading decorators and leading modifiers, then trailing decorators are an invalid position
				if (hasLeadingDecorators && (flags & ModifierFlagsModifier) != 0) {
					if (firstDecorator == null) {
						throw "Expected firstDecorator to be set";
					}
					final sourceFile = Ast.GetSourceFileOfNode(modifier);
					if (!c.hasParseDiagnostics(sourceFile)) {
						final err = c.error(modifier, Diagnostics.Decorators_may_not_appear_after_export_or_export_default_if_they_also_appear_before_export);
						err.AddRelatedInfo(Checker.createDiagnosticForNode(firstDecorator, Diagnostics.Decorator_used_before_export_here));
						return true;
					}
					return false;
				}

				flags |= ModifierFlagsDecorator;

				// if we have not yet seen a modifier, then these are leading decorators
				if ((flags & ModifierFlagsModifier) == 0) {
					hasLeadingDecorators = true;
				} else if ((flags & ModifierFlagsExport) != 0) {
					sawExportBeforeDecorators = true;
				}

				if (firstDecorator == null) {
					firstDecorator = modifier;
				}
			} else {
				if (modifier.Kind != KindReadonlyKeyword) {
					if (node.Kind == KindPropertySignature || node.Kind == KindMethodSignature) {
						return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_a_type_member, Scanner.TokenToString(modifier.Kind));
					}
					if (node.Kind == KindIndexSignature && (modifier.Kind != KindStaticKeyword || !Ast.IsClassLike(node.Parent))) {
						return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_an_index_signature, Scanner.TokenToString(modifier.Kind));
					}
				}
				if (modifier.Kind != KindInKeyword && modifier.Kind != KindOutKeyword && modifier.Kind != KindConstKeyword) {
					if (node.Kind == KindTypeParameter) {
						return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_a_type_parameter, Scanner.TokenToString(modifier.Kind));
					}
				}
				switch (modifier.Kind) {
					case KindConstKeyword:
						if (node.Kind != KindEnumDeclaration && node.Kind != KindTypeParameter) {
							return c.grammarErrorOnNode(node, Diagnostics.A_class_member_cannot_have_the_0_keyword, Scanner.TokenToString(KindConstKeyword));
						}
						final parent = node.Parent;
						if (node.Kind == KindTypeParameter) {
							if (!(Ast.IsFunctionLikeDeclaration(parent) || Ast.IsClassLike(parent)
								|| Ast.IsFunctionTypeNode(parent) || Ast.IsConstructorTypeNode(parent)
								|| Ast.IsCallSignatureDeclaration(parent) || Ast.IsConstructSignatureDeclaration(parent)
								|| Ast.IsMethodSignatureDeclaration(parent))) {
								return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_can_only_appear_on_a_type_parameter_of_a_function_method_or_class, Scanner.TokenToString(modifier.Kind));
							}
						}
					case KindOverrideKeyword:
						// If node.kind === SyntaxKind.Parameter, checkParameter reports an error if it's not a parameter property.
						if ((flags & ModifierFlagsOverride) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_already_seen, "override");
						} else if ((flags & ModifierFlagsAmbient) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_be_used_with_1_modifier, "override", "declare");
						} else if ((flags & ModifierFlagsReadonly) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, "override", "readonly");
						} else if ((flags & ModifierFlagsAccessor) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, "override", "accessor");
						} else if ((flags & ModifierFlagsAsync) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, "override", "async");
						}
						flags |= ModifierFlagsOverride;
						lastOverride = modifier;

					case KindPublicKeyword | KindProtectedKeyword | KindPrivateKeyword:
						final text = Checker.visibilityToString(Ast.ModifierToFlag(modifier.Kind));

						if ((flags & ModifierFlagsAccessibilityModifier) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.Accessibility_modifier_already_seen);
						} else if ((flags & ModifierFlagsOverride) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, text, "override");
						} else if ((flags & ModifierFlagsStatic) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, text, "static");
						} else if ((flags & ModifierFlagsAccessor) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, text, "accessor");
						} else if ((flags & ModifierFlagsReadonly) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, text, "readonly");
						} else if ((flags & ModifierFlagsAsync) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, text, "async");
						} else if (node.Parent.Kind == KindModuleBlock || node.Parent.Kind == KindSourceFile) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_a_module_or_namespace_element, text);
						} else if ((flags & ModifierFlagsAbstract) != 0) {
							if (modifier.Kind == KindPrivateKeyword) {
								return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_be_used_with_1_modifier, text, "abstract");
							} else if ((modifier.Flags & NodeFlagsReparsed) == 0) {
								return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, text, "abstract");
							}
						} else if (Ast.IsPrivateIdentifierClassElementDeclaration(node)) {
							return c.grammarErrorOnNode(modifier, Diagnostics.An_accessibility_modifier_cannot_be_used_with_a_private_identifier);
						}
						flags |= Ast.ModifierToFlag(modifier.Kind);
					case KindStaticKeyword:
						if ((flags & ModifierFlagsStatic) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_already_seen, "static");
						} else if ((flags & ModifierFlagsReadonly) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, "static", "readonly");
						} else if ((flags & ModifierFlagsAsync) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, "static", "async");
						} else if ((flags & ModifierFlagsAccessor) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, "static", "accessor");
						} else if (node.Parent.Kind == KindModuleBlock || node.Parent.Kind == KindSourceFile) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_a_module_or_namespace_element, "static");
						} else if (node.Kind == KindParameter) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_a_parameter, "static");
						} else if ((flags & ModifierFlagsAbstract) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_be_used_with_1_modifier, "static", "abstract");
						} else if ((flags & ModifierFlagsOverride) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, "static", "override");
						}
						flags |= ModifierFlagsStatic;
						lastStatic = modifier;
					case KindAccessorKeyword:
						if ((flags & ModifierFlagsAccessor) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_already_seen, "accessor");
						} else if ((flags & ModifierFlagsReadonly) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_be_used_with_1_modifier, "accessor", "readonly");
						} else if ((flags & ModifierFlagsAmbient) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_be_used_with_1_modifier, "accessor", "declare");
						} else if (node.Kind != KindPropertyDeclaration) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_accessor_modifier_can_only_appear_on_a_property_declaration);
						}

						flags |= ModifierFlagsAccessor;
					case KindReadonlyKeyword:
						if ((flags & ModifierFlagsReadonly) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_already_seen, "readonly");
						} else if (node.Kind != KindPropertyDeclaration && node.Kind != KindPropertySignature && node.Kind != KindIndexSignature && node.Kind != KindParameter) {
							// If node.kind === SyntaxKind.Parameter, checkParameter reports an error if it's not a parameter property.
							return c.grammarErrorOnNode(modifier, Diagnostics.X_readonly_modifier_can_only_appear_on_a_property_declaration_or_index_signature);
						} else if ((flags & ModifierFlagsAccessor) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_be_used_with_1_modifier, "readonly", "accessor");
						}
						flags |= ModifierFlagsReadonly;
					case KindExportKeyword:
						if (c.compilerOptions.VerbatimModuleSyntax == TSTrue && (node.Flags & NodeFlagsAmbient) == 0 && node.Kind != KindTypeAliasDeclaration && node.Kind != KindInterfaceDeclaration && node.Kind != KindModuleDeclaration && node.Parent.Kind == KindSourceFile && c.program.GetEmitModuleFormatOfFile(hasFileName(Ast.GetSourceFileOfNode(node))) == ModuleKindCommonJS) {
							return c.grammarErrorOnNode(modifier, Diagnostics.A_top_level_export_modifier_cannot_be_used_on_value_declarations_in_a_CommonJS_module_when_verbatimModuleSyntax_is_enabled);
						}
						if ((flags & ModifierFlagsExport) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_already_seen, "export");
						} else if ((flags & ModifierFlagsAmbient) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, "export", "declare");
						} else if ((flags & ModifierFlagsAbstract) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, "export", "abstract");
						} else if ((flags & ModifierFlagsAsync) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, "export", "async");
						} else if (Ast.IsClassLike(node.Parent) && !Ast.IsJSTypeAliasDeclaration(node)) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_class_elements_of_this_kind, "export");
						} else if (node.Kind == KindParameter) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_a_parameter, "export");
						} else if (blockScopeKind == NodeFlagsUsing) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_a_using_declaration, "export");
						} else if (blockScopeKind == NodeFlagsAwaitUsing) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_an_await_using_declaration, "export");
						}
						flags |= ModifierFlagsExport;
					case KindDefaultKeyword:
						var container:Node = null;
						if (node.Parent.Kind == KindSourceFile) {
							container = node.Parent;
						} else {
							container = node.Parent.Parent;
						}
						if (container.Kind == KindModuleDeclaration && !Ast.IsAmbientModule(container)) {
							return c.grammarErrorOnNode(modifier, Diagnostics.A_default_export_can_only_be_used_in_an_ECMAScript_style_module);
						} else if (blockScopeKind == NodeFlagsUsing) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_a_using_declaration, "default");
						} else if (blockScopeKind == NodeFlagsAwaitUsing) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_an_await_using_declaration, "default");
						} else if ((flags & ModifierFlagsExport) == 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, "export", "default");
						} else if (sawExportBeforeDecorators) {
							return c.grammarErrorOnNode(firstDecorator, Diagnostics.Decorators_are_not_valid_here);
						}

						flags |= ModifierFlagsDefault;
					case KindDeclareKeyword:
						if ((flags & ModifierFlagsAmbient) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_already_seen, "declare");
						} else if ((flags & ModifierFlagsAsync) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_be_used_in_an_ambient_context, "async");
						} else if ((flags & ModifierFlagsOverride) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_be_used_in_an_ambient_context, "override");
						} else if (Ast.IsClassLike(node.Parent) && !Ast.IsPropertyDeclaration(node)) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_class_elements_of_this_kind, "declare");
						} else if (node.Kind == KindParameter) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_a_parameter, "declare");
						} else if (blockScopeKind == NodeFlagsUsing) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_a_using_declaration, "declare");
						} else if (blockScopeKind == NodeFlagsAwaitUsing) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_an_await_using_declaration, "declare");
						} else if ((node.Parent.Flags & NodeFlagsAmbient) != 0 && node.Parent.Kind == KindModuleBlock) {
							return c.grammarErrorOnNode(modifier, Diagnostics.A_declare_modifier_cannot_be_used_in_an_already_ambient_context);
						} else if (Ast.IsPrivateIdentifierClassElementDeclaration(node)) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_be_used_with_a_private_identifier, "declare");
						} else if ((flags & ModifierFlagsAccessor) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_be_used_with_1_modifier, "declare", "accessor");
						}
						flags |= ModifierFlagsAmbient;
						lastDeclare = modifier;
					case KindAbstractKeyword:
						if ((flags & ModifierFlagsAbstract) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_already_seen, "abstract");
						}
						if (node.Kind != KindClassDeclaration && node.Kind != KindConstructorType) {
							if (node.Kind != KindMethodDeclaration && node.Kind != KindPropertyDeclaration && node.Kind != KindGetAccessor && node.Kind != KindSetAccessor) {
								return c.grammarErrorOnNode(modifier, Diagnostics.X_abstract_modifier_can_only_appear_on_a_class_method_or_property_declaration);
							}
							if (!(node.Parent.Kind == KindClassDeclaration && Ast.HasSyntacticModifier(node.Parent, ModifierFlagsAbstract))) {
								var message:Message = null;
								if (node.Kind == KindPropertyDeclaration) {
									message = Diagnostics.Abstract_properties_can_only_appear_within_an_abstract_class;
								} else {
									message = Diagnostics.Abstract_methods_can_only_appear_within_an_abstract_class;
								}
								return c.grammarErrorOnNode(modifier, message);
							}
							if ((flags & ModifierFlagsStatic) != 0) {
								return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_be_used_with_1_modifier, "static", "abstract");
							}
							if ((flags & ModifierFlagsPrivate) != 0) {
								return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_be_used_with_1_modifier, "private", "abstract");
							}
							if ((flags & ModifierFlagsAsync) != 0 && lastAsync != null) {
								return c.grammarErrorOnNode(lastAsync, Diagnostics.X_0_modifier_cannot_be_used_with_1_modifier, "async", "abstract");
							}
							if ((flags & ModifierFlagsOverride) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
								return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, "abstract", "override");
							}
							if ((flags & ModifierFlagsAccessor) != 0 && (modifier.Flags & NodeFlagsReparsed) == 0) {
								return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, "abstract", "accessor");
							}
						}
						final name = node.Name();
						if (name != null && name.Kind == KindPrivateIdentifier) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_be_used_with_a_private_identifier, "abstract");
						}

						flags |= ModifierFlagsAbstract;
					case KindAsyncKeyword:
						if ((flags & ModifierFlagsAsync) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_already_seen, "async");
						} else if ((flags & ModifierFlagsAmbient) != 0 || (node.Parent.Flags & NodeFlagsAmbient) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_be_used_in_an_ambient_context, "async");
						} else if (node.Kind == KindParameter) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_appear_on_a_parameter, "async");
						}
						if ((flags & ModifierFlagsAbstract) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_cannot_be_used_with_1_modifier, "async", "abstract");
						}
						flags |= ModifierFlagsAsync;
						lastAsync = modifier;
					case KindInKeyword | KindOutKeyword:
						var inOutFlag:ModifierFlags = ModifierFlagsNone;
						if (modifier.Kind == KindInKeyword) {
							inOutFlag = ModifierFlagsIn;
						} else {
							inOutFlag = ModifierFlagsOut;
						}
						var inOutText:std.String = "";
						if (modifier.Kind == KindInKeyword) {
							inOutText = "in";
						} else {
							inOutText = "out";
						}
						final parent = node.Parent;
						if (node.Kind != KindTypeParameter || parent != null && !(Ast.IsInterfaceDeclaration(parent) || Ast.IsClassLike(parent) || Ast.IsTypeOrJSTypeAliasDeclaration(parent))) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_can_only_appear_on_a_type_parameter_of_a_class_interface_or_type_alias, inOutText);
						}
						if ((flags & inOutFlag) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_already_seen, inOutText);
						}
						if ((inOutFlag & ModifierFlagsIn) != 0 && (flags & ModifierFlagsOut) != 0) {
							return c.grammarErrorOnNode(modifier, Diagnostics.X_0_modifier_must_precede_1_modifier, "in", "out");
						}
						flags |= inOutFlag;
					default:
				}
			}
		}

		if (node.Kind == KindConstructor) {
			if ((flags & ModifierFlagsStatic) != 0) {
				return c.grammarErrorOnNode(lastStatic, Diagnostics.X_0_modifier_cannot_appear_on_a_constructor_declaration, "static");
			}
			if ((flags & ModifierFlagsOverride) != 0) {
				return c.grammarErrorOnNode(lastOverride, Diagnostics.X_0_modifier_cannot_appear_on_a_constructor_declaration, "override");
			}
			if ((flags & ModifierFlagsAsync) != 0) {
				return c.grammarErrorOnNode(lastAsync, Diagnostics.X_0_modifier_cannot_appear_on_a_constructor_declaration, "async");
			}
			return false;
		} else if ((node.Kind == KindImportDeclaration || node.Kind == KindJSImportDeclaration || node.Kind == KindImportEqualsDeclaration) && (flags & ModifierFlagsAmbient) != 0) {
			return c.grammarErrorOnNode(lastDeclare, Diagnostics.A_0_modifier_cannot_be_used_with_an_import_declaration, "declare");
		} else if (node.Kind == KindParameter && ((flags & ModifierFlagsParameterPropertyModifier) != 0) && Ast.IsBindingPattern(node.Name())) {
			return c.grammarErrorOnNode(node, Diagnostics.A_parameter_property_may_not_be_declared_using_a_binding_pattern);
		} else if (node.Kind == KindParameter && ((flags & ModifierFlagsParameterPropertyModifier) != 0) && node.AsParameterDeclaration().DotDotDotToken != null) {
			return c.grammarErrorOnNode(node, Diagnostics.A_parameter_property_cannot_be_declared_using_a_rest_parameter);
		}
		if ((flags & ModifierFlagsAsync) != 0) {
			return c.checkGrammarAsyncModifier(node, lastAsync);
		}
		return false;
	}

	static function reportObviousModifierErrors(c:Checker, node:Node):Bool {
		final modifier = c.findFirstIllegalModifier(node);
		if (modifier == null) {
			return false;
		}
		return c.grammarErrorOnFirstToken(modifier, Diagnostics.Modifiers_cannot_appear_here);
	}

	static function findFirstModifierExcept(c:Checker, node:Node, allowedModifier:Kind):Node {
		final modifier = Core.Find(node.ModifierNodes(), fn_IsModifier);
		if (modifier != null && modifier.Kind != allowedModifier) {
			return modifier;
		}
		return null;
	}

	static function findFirstIllegalModifier(c:Checker, node:Node):Node {
		switch (node.Kind) {
			case KindGetAccessor | KindSetAccessor | KindConstructor | KindPropertyDeclaration | KindPropertySignature | KindMethodDeclaration
				| KindMethodSignature | KindIndexSignature | KindModuleDeclaration | KindImportDeclaration | KindJSImportDeclaration
				| KindImportEqualsDeclaration | KindExportDeclaration | KindExportAssignment | KindFunctionExpression | KindArrowFunction
				| KindParameter | KindTypeParameter | KindJSTypeAliasDeclaration:
				return null;
			case KindClassStaticBlockDeclaration | KindPropertyAssignment | KindShorthandPropertyAssignment | KindNamespaceExportDeclaration
				| KindMissingDeclaration:
				return Core.Find(node.ModifierNodes(), fn_IsModifier);
			default:
				if (node.Parent.Kind == KindModuleBlock || node.Parent.Kind == KindSourceFile) {
					return null;
				}
				switch (node.Kind) {
					case KindFunctionDeclaration:
						return c.findFirstModifierExcept(node, KindAsyncKeyword);
					case KindClassDeclaration | KindConstructorType:
						return c.findFirstModifierExcept(node, KindAbstractKeyword);
					case KindClassExpression | KindInterfaceDeclaration | KindTypeAliasDeclaration:
						return Core.Find(node.ModifierNodes(), fn_IsModifier);
					case KindVariableStatement:
						if ((node.AsVariableStatement().DeclarationList.Flags & NodeFlagsUsing) != 0) {
							return c.findFirstModifierExcept(node, KindAwaitKeyword);
						}
						return Core.Find(node.ModifierNodes(), fn_IsModifier);
					case KindEnumDeclaration:
						return c.findFirstModifierExcept(node, KindConstKeyword);
					default:
						throw "Unhandled case in findFirstIllegalModifier.";
				}
		}
	}

	static function reportObviousDecoratorErrors(c:Checker, node:Node):Bool {
		final decorator = c.findFirstIllegalDecorator(node);
		if (decorator == null) {
			return false;
		}
		return c.grammarErrorOnFirstToken(decorator, Diagnostics.Decorators_are_not_valid_here);
	}

	static function findFirstIllegalDecorator(c:Checker, node:Node):Node {
		if (Ast.CanHaveIllegalDecorators(node)) {
			final decorator = Core.Find(node.ModifierNodes(), fn_IsDecorator);
			return decorator;
		} else {
			return null;
		}
	}

	static function checkGrammarAsyncModifier(c:Checker, node:Node, asyncModifier:Node):Bool {
		switch (node.Kind) {
			case KindMethodDeclaration | KindFunctionDeclaration | KindFunctionExpression | KindArrowFunction:
				return false;
			default:
		}

		return c.grammarErrorOnNode(asyncModifier, Diagnostics.X_0_modifier_cannot_be_used_here, "async");
	}

	static function checkGrammarForDisallowedTrailingComma(c:Checker, list:NodeList, diag:Message):Bool {
		if (list != null && list.HasTrailingComma()) {
			return c.grammarErrorAtPos(list.Nodes[0], list.End() - ",".length, ",".length, diag);
		}
		return false;
	}

	static function checkGrammarTypeParameterList(c:Checker, typeParameters:NodeList, file:SourceFile):Bool {
		if (typeParameters != null && Core.len(typeParameters.Nodes) == 0) {
			final start = typeParameters.Pos() - "<".length;
			final end = Scanner.SkipTrivia(file.Text(), typeParameters.End()) + ">".length;
			return c.grammarErrorAtPos(file.AsNode(), start, end - start, Diagnostics.Type_parameter_list_cannot_be_empty);
		}
		return false;
	}

	static function checkGrammarParameterList(c:Checker, parameters:NodeList):Bool {
		var seenOptionalParameter = false;
		final parameterCount = Core.len(parameters.Nodes);

		for (i in 0...parameterCount) {
			final parameter = parameters.Nodes[i].AsParameterDeclaration();
			if (parameter.DotDotDotToken != null) {
				if (i != parameterCount - 1) {
					return c.grammarErrorOnNode(parameter.DotDotDotToken, Diagnostics.A_rest_parameter_must_be_last_in_a_parameter_list);
				}
				if ((parameter.Flags & NodeFlagsAmbient) == 0) {
					c.checkGrammarForDisallowedTrailingComma(parameters, Diagnostics.A_rest_parameter_or_binding_pattern_may_not_have_a_trailing_comma);
				}

				if (parameter.QuestionToken != null) {
					return c.grammarErrorOnNode(parameter.QuestionToken, Diagnostics.A_rest_parameter_cannot_be_optional);
				}

				if (parameter.Initializer != null) {
					return c.grammarErrorOnNode(parameter.Name(), Diagnostics.A_rest_parameter_cannot_have_an_initializer);
				}
			} else if (Checker.isOptionalDeclaration(parameter.AsNode())) {
				seenOptionalParameter = true;
				// A reparsed '?' token indicates a bracketed name in @param tag
				if (parameter.QuestionToken != null && (parameter.QuestionToken.Flags & NodeFlagsReparsed) == 0 && parameter.Initializer != null) {
					return c.grammarErrorOnNode(parameter.Name(), Diagnostics.Parameter_cannot_have_question_mark_and_initializer);
				}
			} else if (seenOptionalParameter && parameter.Initializer == null) {
				return c.grammarErrorOnNode(parameter.Name(), Diagnostics.A_required_parameter_cannot_follow_an_optional_parameter);
			}
		}

		return false;
	}

	static function checkGrammarForUseStrictSimpleParameterList(c:Checker, node:Node):Bool {
		if (c.languageVersion >= ScriptTargetES2016) {
			final body = node.Body();
			var useStrictDirective:Node = null;
			if (body != null && Ast.IsBlock(body)) {
				useStrictDirective = Binder.FindUseStrictPrologue(Ast.GetSourceFileOfNode(node), body.Statements());
			}
			if (useStrictDirective != null) {
				final nonSimpleParameters = Core.Filter(node.Parameters(), n -> {
					final parameter = n.AsParameterDeclaration();
					return parameter.Initializer != null || Ast.IsBindingPattern(parameter.Name()) || Checker.isRestParameter(parameter.AsNode());
				});
				if (Core.len(nonSimpleParameters) != 0) {
					for (parameter in nonSimpleParameters) {
						final err = c.error(parameter, Diagnostics.This_parameter_is_not_allowed_with_use_strict_directive);
						err.AddRelatedInfo(Checker.createDiagnosticForNode(useStrictDirective, Diagnostics.X_use_strict_directive_used_here));
					}

					final err = c.error(useStrictDirective, Diagnostics.X_use_strict_directive_cannot_be_used_with_non_simple_parameter_list);
					for (index in 0...nonSimpleParameters.length) {
						final parameter = nonSimpleParameters[index];
						var relatedMessage:Message = null;
						if (index == 0) {
							relatedMessage = Diagnostics.Non_simple_parameter_declared_here;
						} else {
							relatedMessage = Diagnostics.X_and_here;
						}
						err.AddRelatedInfo(Checker.createDiagnosticForNode(parameter, relatedMessage));
					}

					return true;
				}
			}
		}
		return false;
	}

	static function checkGrammarFunctionLikeDeclaration(c:Checker, node:Node):Bool {
		// Prevent cascading error by short-circuit
		final file = Ast.GetSourceFileOfNode(node);
		final funcData = node.FunctionLikeData();
		return c.checkGrammarModifiers(node) || c.checkGrammarTypeParameterList(funcData.TypeParameters, file)
			|| c.checkGrammarParameterList(funcData.Parameters) || c.checkGrammarArrowFunction(node, file)
			|| (Ast.IsFunctionLikeDeclaration(node) && c.checkGrammarForUseStrictSimpleParameterList(node));
	}

	static function checkGrammarClassLikeDeclaration(c:Checker, node:Node):Bool {
		final file = Ast.GetSourceFileOfNode(node);
		return c.checkGrammarClassDeclarationHeritageClauses(node, file) || c.checkGrammarTypeParameterList(node.TypeParameterList(), file);
	}

	static function checkGrammarArrowFunction(c:Checker, node:Node, file:SourceFile):Bool {
		if (!Ast.IsArrowFunction(node)) {
			return false;
		}

		final arrowFunc = node.AsArrowFunction();
		final typeParameters = arrowFunc.TypeParameters;
		if (typeParameters != null) {
			final typeParamNodes = typeParameters.Nodes;
			final hasConstraint = Core.len(typeParamNodes) > 0 && typeParamNodes[0].AsTypeParameterDeclaration().Constraint != null;
			if (!(Core.len(typeParamNodes) > 1 || typeParameters.HasTrailingComma() || hasConstraint)) {
				if (Tspath.FileExtensionIsOneOf(file.FileName(), [Tspath.ExtensionMts, Tspath.ExtensionCts])) {
					// TODO(danielr): should we return early here?
					c.grammarErrorOnNode(typeParameters.Nodes[0], Diagnostics.This_syntax_is_reserved_in_files_with_the_mts_or_cts_extension_Add_a_trailing_comma_or_explicit_constraint);
				}
			}
		}

		final equalsGreaterThanToken = arrowFunc.EqualsGreaterThanToken;
		final startLine = Scanner.GetECMALineOfPosition(file, equalsGreaterThanToken.Pos());
		final endLine = Scanner.GetECMALineOfPosition(file, equalsGreaterThanToken.End());
		return startLine != endLine && c.grammarErrorOnNode(equalsGreaterThanToken, Diagnostics.Line_terminator_not_permitted_before_arrow);
	}

	static function checkGrammarIndexSignatureParameters(c:Checker, node:IndexSignatureDeclaration):Bool {
		final paramNodes = node.Parameters.Nodes;

		if (Core.len(paramNodes) == 0) {
			return c.grammarErrorOnNode(node.AsNode(), Diagnostics.An_index_signature_must_have_exactly_one_parameter);
		}

		final parameter = paramNodes[0].AsParameterDeclaration();
		if (paramNodes.length != 1) {
			return c.grammarErrorOnNode(parameter.Name(), Diagnostics.An_index_signature_must_have_exactly_one_parameter);
		}

		c.checkGrammarForDisallowedTrailingComma(node.Parameters, Diagnostics.An_index_signature_cannot_have_a_trailing_comma);
		if (parameter.DotDotDotToken != null) {
			return c.grammarErrorOnNode(parameter.DotDotDotToken, Diagnostics.An_index_signature_cannot_have_a_rest_parameter);
		}
		if (parameter.Modifiers() != null) {
			return c.grammarErrorOnNode(parameter.Name(), Diagnostics.An_index_signature_parameter_cannot_have_an_accessibility_modifier);
		}
		if (parameter.QuestionToken != null) {
			return c.grammarErrorOnNode(parameter.QuestionToken, Diagnostics.An_index_signature_parameter_cannot_have_a_question_mark);
		}
		if (parameter.Initializer != null) {
			return c.grammarErrorOnNode(parameter.Name(), Diagnostics.An_index_signature_parameter_cannot_have_an_initializer);
		}
		final typeNode = parameter.Type;
		if (typeNode == null) {
			return c.grammarErrorOnNode(parameter.Name(), Diagnostics.An_index_signature_parameter_must_have_a_type_annotation);
		}
		final t = c.getTypeFromTypeNode(typeNode);
		if (Checker.someType(t, t -> (t.flags & TypeFlagsStringOrNumberLiteralOrUnique) != 0) || c.isGenericType(t)) {
			return c.grammarErrorOnNode(parameter.Name(), Diagnostics.An_index_signature_parameter_type_cannot_be_a_literal_type_or_generic_type_Consider_using_a_mapped_object_type_instead);
		}
		if (!Checker.everyType(t, t -> c.isValidIndexKeyType(t))) {
			return c.grammarErrorOnNode(parameter.Name(), Diagnostics.An_index_signature_parameter_type_must_be_string_number_symbol_or_a_template_literal_type);
		}
		if (node.Type == null) {
			return c.grammarErrorOnNode(node.AsNode(), Diagnostics.An_index_signature_must_have_a_type_annotation);
		}
		return false;
	}

	static function checkGrammarIndexSignature(c:Checker, node:IndexSignatureDeclaration):Bool {
		// Prevent cascading error by short-circuit
		return c.checkGrammarModifiers(node.AsNode()) || c.checkGrammarIndexSignatureParameters(node);
	}

	static function checkGrammarForAtLeastOneTypeArgument(c:Checker, node:Node, typeArguments:NodeList):Bool {
		if (typeArguments != null && Core.len(typeArguments.Nodes) == 0) {
			final sourceFile = Ast.GetSourceFileOfNode(node);
			final start = typeArguments.Pos() - "<".length;
			final end = Scanner.SkipTrivia(sourceFile.Text(), typeArguments.End()) + ">".length;
			return c.grammarErrorAtPos(sourceFile.AsNode(), start, end - start, Diagnostics.Type_argument_list_cannot_be_empty);
		}
		return false;
	}

	static function checkGrammarTypeArguments(c:Checker, node:Node, typeArguments:NodeList):Bool {
		return c.checkGrammarForDisallowedTrailingComma(typeArguments, Diagnostics.Trailing_comma_not_allowed) || c.checkGrammarForAtLeastOneTypeArgument(node, typeArguments);
	}

	static function checkGrammarTaggedTemplateChain(c:Checker, node:TaggedTemplateExpression):Bool {
		if (node.QuestionDotToken != null || (node.Flags & NodeFlagsOptionalChain) != 0) {
			return c.grammarErrorOnNode(node.Template, Diagnostics.Tagged_template_expressions_are_not_permitted_in_an_optional_chain);
		}
		return false;
	}

	static function checkGrammarHeritageClause(c:Checker, node:HeritageClause):Bool {
		final types = node.Types;
		if (c.checkGrammarForDisallowedTrailingComma(types, Diagnostics.Trailing_comma_not_allowed)) {
			return true;
		}
		if (types != null && Core.len(types.Nodes) == 0) {
			final listType = Scanner.TokenToString(node.Token);
			// TODO(danielr): why not error on the token?
			return c.grammarErrorAtPos(node.AsNode(), types.Pos(), 0, Diagnostics.X_0_list_cannot_be_empty, listType);
		}

		for (node in rangeOf(types.Nodes)) {
			if (c.checkGrammarExpressionWithTypeArguments(node)) {
				return true;
			}
		}
		return false;
	}

	static function checkGrammarExpressionWithTypeArguments(c:Checker, node:Node):Bool {
		if (Ast.IsExpressionWithTypeArguments(node) && node.Expression().Kind == KindImportKeyword && node.TypeArgumentList() != null) {
			return c.grammarErrorOnNode(node, Diagnostics.This_use_of_import_is_invalid_import_calls_can_be_written_but_they_must_have_parentheses_and_cannot_have_type_arguments);
		}
		return c.checkGrammarTypeArguments(node, node.TypeArgumentList());
	}

	static function checkGrammarClassDeclarationHeritageClauses(c:Checker, node:ClassLikeDeclaration, file:SourceFile):Bool {
		var seenExtendsClause = false;
		var seenImplementsClause = false;

		final classLikeData = node.ClassLikeData();

		if (!c.checkGrammarModifiers(node) && classLikeData.HeritageClauses != null) {
			for (heritageClauseNode in rangeOf(classLikeData.HeritageClauses.Nodes)) {
				final heritageClause = heritageClauseNode.AsHeritageClause();
				if (heritageClause.Token == KindExtendsKeyword) {
					if (seenExtendsClause) {
						return c.grammarErrorOnFirstToken(heritageClauseNode, Diagnostics.X_extends_clause_already_seen);
					}

					if (seenImplementsClause) {
						return c.grammarErrorOnFirstToken(heritageClauseNode, Diagnostics.X_extends_clause_must_precede_implements_clause);
					}

					final typeNodes = heritageClause.Types.Nodes;
					if (Core.len(typeNodes) > 1) {
						return c.grammarErrorOnFirstToken(typeNodes[1], Diagnostics.Classes_can_only_extend_a_single_class);
					}

					if (Core.len(typeNodes) > 0) {
						for (j in rangeOf(node.EagerJSDoc(file))) {
							if (j.AsJSDoc().Tags == null) {
								continue;
							}
							for (tag in rangeOf(j.AsJSDoc().Tags.Nodes)) {
								if (tag.Kind == KindJSDocAugmentsTag) {
									final target = typeNodes[0].AsExpressionWithTypeArguments();
									final source = tag.ClassName().AsExpressionWithTypeArguments();
									final targetName = Checker.getIdentifierFromEntityNameExpression(target.Expression);
									final sourceName = Checker.getIdentifierFromEntityNameExpression(source.Expression);
									if (targetName != null && sourceName != null && targetName.Text() != sourceName.Text()) {
										return c.grammarErrorOnNode(sourceName, Diagnostics.JSDoc_0_1_does_not_match_the_extends_2_clause, tag.TagName().Text(), sourceName.Text(), targetName.Text());
									}
								}
							}
						}
					}
					seenExtendsClause = true;
				} else {
					if (heritageClause.Token != KindImplementsKeyword) {
						throw "Unexpected token " + Strconv.Quote(heritageClause.Token.String());
					}
					if (seenImplementsClause) {
						return c.grammarErrorOnFirstToken(heritageClauseNode, Diagnostics.X_implements_clause_already_seen);
					}

					seenImplementsClause = true;
				}

				// Grammar checking heritageClause inside class declaration
				c.checkGrammarHeritageClause(heritageClause);
			}
		}

		return false;
	}

	static function checkGrammarInterfaceDeclaration(c:Checker, node:InterfaceDeclaration):Bool {
		if (node.HeritageClauses != null) {
			var seenExtendsClause = false;
			for (heritageClauseNode in rangeOf(node.HeritageClauses.Nodes)) {
				final heritageClause = heritageClauseNode.AsHeritageClause();

				switch (heritageClause.Token) {
					case KindExtendsKeyword:
						if (seenExtendsClause) {
							return c.grammarErrorOnFirstToken(heritageClauseNode, Diagnostics.X_extends_clause_already_seen);
						}
						seenExtendsClause = true;
					case KindImplementsKeyword:
						return c.grammarErrorOnFirstToken(heritageClauseNode, Diagnostics.Interface_declaration_cannot_have_implements_clause);
					default:
						throw "Unexpected token " + Strconv.Quote(heritageClause.Token.String());
				}

				// Grammar checking heritageClause inside class declaration
				c.checkGrammarHeritageClause(heritageClause);
			}
		}

		return false;
	}

	static function checkGrammarComputedPropertyName(c:Checker, node:Node):Bool {
		// If node is not a computedPropertyName, just skip the grammar checking
		if (node.Kind != KindComputedPropertyName) {
			return false;
		}

		final computedPropertyName = node.AsComputedPropertyName();
		if (computedPropertyName.Expression.Kind == KindBinaryExpression && computedPropertyName.Expression.AsBinaryExpression().OperatorToken.Kind == KindCommaToken) {
			return c.grammarErrorOnNode(computedPropertyName.Expression, Diagnostics.A_comma_expression_is_not_allowed_in_a_computed_property_name);
		}
		return false;
	}

	static function checkGrammarForGenerator(c:Checker, node:Node):Bool {
		final bodyData = node.BodyData();
		if (bodyData != null && bodyData.AsteriskToken != null) {
			if (node.Kind != KindFunctionDeclaration && node.Kind != KindFunctionExpression && node.Kind != KindMethodDeclaration) {
				throw "Unexpected node kind " + Strconv.Quote(node.Kind.String());
			}
			if ((node.Flags & NodeFlagsAmbient) != 0) {
				return c.grammarErrorOnNode(bodyData.AsteriskToken, Diagnostics.Generators_are_not_allowed_in_an_ambient_context);
			}
			if (bodyData.Body == null) {
				return c.grammarErrorOnNode(bodyData.AsteriskToken, Diagnostics.An_overload_signature_cannot_be_declared_as_a_generator);
			}
		}

		return false;
	}

	static function checkGrammarForInvalidQuestionMark(c:Checker, postfixToken:TokenNode, message:Message):Bool {
		return postfixToken != null && postfixToken.Kind == KindQuestionToken && c.grammarErrorOnNode(postfixToken, message);
	}

	static function checkGrammarForInvalidExclamationToken(c:Checker, postfixToken:TokenNode, message:Message):Bool {
		return postfixToken != null && postfixToken.Kind == KindExclamationToken && c.grammarErrorOnNode(postfixToken, message);
	}

	static function checkGrammarObjectLiteralExpression(c:Checker, node:ObjectLiteralExpression, inDestructuring:Bool):Bool {
		final seen = new StringMap<DeclarationMeaning>();

		var properties:Array<Node> = null;
		if (node.Properties != null) {
			properties = node.Properties.Nodes;
		}
		for (prop in rangeOf(properties)) {
			if (prop.Kind == KindSpreadAssignment) {
				final spreadAssignment = prop.AsSpreadAssignment();
				if (inDestructuring) {
					// a rest property cannot be destructured any further
					final expression = Ast.SkipParentheses(spreadAssignment.Expression);
					if (Ast.IsArrayLiteralExpression(expression) || Ast.IsObjectLiteralExpression(expression)) {
						return c.grammarErrorOnNode(spreadAssignment.Expression, Diagnostics.A_rest_element_cannot_contain_a_binding_pattern);
					}
				}
				continue;
			}
			final name = prop.Name();
			if (name.Kind == KindComputedPropertyName) {
				// If the name is not a ComputedPropertyName, the grammar checking will skip it
				c.checkGrammarComputedPropertyName(name);
			}

			if (prop.Kind == KindShorthandPropertyAssignment && !inDestructuring) {
				final shorthandProp = prop.AsShorthandPropertyAssignment();
				if (shorthandProp.ObjectAssignmentInitializer != null) {
					// having objectAssignmentInitializer is only valid in an ObjectAssignmentPattern.
					// Outside of destructuring, it is a syntax error.

					// Try to grab the last node prior to the initializer,
					// then error on the first token following (which should be the `=` token).
					var lastNodeBeforeInitializer:Node = null;
					shorthandProp.ForEachChild(child -> {
						if (child != shorthandProp.ObjectAssignmentInitializer) {
							lastNodeBeforeInitializer = child;
							return false;
						}
						return true;
					});

					c.grammarErrorOnFirstToken(lastNodeBeforeInitializer, Diagnostics.Did_you_mean_to_use_a_Colon_An_can_only_follow_a_property_name_when_the_containing_object_literal_is_part_of_a_destructuring_pattern);
				}
			}

			if (name.Kind == KindPrivateIdentifier) {
				c.grammarErrorOnNode(name, Diagnostics.Private_identifiers_are_not_allowed_outside_class_bodies);
			}

			// Modifiers are never allowed on properties except for 'async' on a method declaration
			final modifiers = prop.ModifierNodes();
			if (Core.len(modifiers) != 0) {
				if (Ast.CanHaveModifiers(prop)) {
					for (mod in modifiers) {
						if (Ast.IsModifier(mod) && (mod.Kind != KindAsyncKeyword || prop.Kind != KindMethodDeclaration)) {
							c.grammarErrorOnNode(mod, Diagnostics.X_0_modifier_cannot_be_used_here, Scanner.GetTextOfNode(mod));
						}
					}
				} else if (Ast.CanHaveIllegalModifiers(prop)) {
					for (mod in modifiers) {
						if (Ast.IsModifier(mod)) {
							c.grammarErrorOnNode(mod, Diagnostics.X_0_modifier_cannot_be_used_here, Scanner.GetTextOfNode(mod));
						}
					}
				}
			}

			// ECMA-262 11.1.5 Object Initializer
			// If previous is not undefined then throw a SyntaxError exception if any of the following conditions are true
			// a.This production is contained in strict code and IsDataDescriptor(previous) is true and
			// IsDataDescriptor(propId.descriptor) is true.
			//    b.IsDataDescriptor(previous) is true and IsAccessorDescriptor(propId.descriptor) is true.
			//    c.IsAccessorDescriptor(previous) is true and IsDataDescriptor(propId.descriptor) is true.
			//    d.IsAccessorDescriptor(previous) is true and IsAccessorDescriptor(propId.descriptor) is true
			// and either both previous and propId.descriptor have[[Get]] fields or both previous and propId.descriptor have[[Set]] fields
			var currentKind:DeclarationMeaning = 0;
			switch (prop.Kind) {
				case KindShorthandPropertyAssignment | KindPropertyAssignment:
					var commonProp:NamedMemberBase = null;
					if (prop.Kind == KindShorthandPropertyAssignment) {
						prop.ClassLikeData();
						commonProp = prop.AsShorthandPropertyAssignment();
					} else {
						commonProp = prop.AsPropertyAssignment();
					}

					// Grammar checking for computedPropertyName and shorthandPropertyAssignment
					c.checkGrammarForInvalidExclamationToken(commonProp.PostfixToken, Diagnostics.A_definite_assignment_assertion_is_not_permitted_in_this_context);
					c.checkGrammarForInvalidQuestionMark(commonProp.PostfixToken, Diagnostics.An_object_member_cannot_be_declared_optional);

					if (name.Kind == KindNumericLiteral) {
						c.checkGrammarNumericLiteral(name.AsNumericLiteral());
					}

					if (name.Kind == KindBigIntLiteral) {
						c.addErrorOrSuggestion(true, Checker.createDiagnosticForNode(name, Diagnostics.A_bigint_literal_cannot_be_used_as_a_property_name));
					}

					currentKind = DeclarationMeaningPropertyAssignment;
				case KindMethodDeclaration:
					currentKind = DeclarationMeaningMethod;
				case KindGetAccessor:
					currentKind = DeclarationMeaningGetAccessor;
				case KindSetAccessor:
					currentKind = DeclarationMeaningSetAccessor;
				default:
					throw "Unexpected node kind " + Strconv.Quote(prop.Kind.String());
			}

			if (!inDestructuring) {
				final effectiveNameOk = c.getEffectivePropertyNameForPropertyNameNode(name);
				final effectiveName = effectiveNameOk.value;
				if (!effectiveNameOk.ok) {
					continue;
				}

				final existing = seen.get(effectiveName);
				final existingKind:DeclarationMeaning = existing != null ? existing : 0;
				if (existingKind == 0) {
					seen.set(effectiveName, currentKind);
				} else {
					if (((currentKind & DeclarationMeaningMethod) != 0) && ((existingKind & DeclarationMeaningMethod) != 0)) {
						c.grammarErrorOnNode(name, Diagnostics.Duplicate_identifier_0, Scanner.GetTextOfNode(name));
					} else if (((currentKind & DeclarationMeaningPropertyAssignment) != 0) && ((existingKind & DeclarationMeaningPropertyAssignment) != 0)) {
						c.grammarErrorOnNode(name, Diagnostics.An_object_literal_cannot_have_multiple_properties_with_the_same_name, Scanner.GetTextOfNode(name));
					} else if (((currentKind & DeclarationMeaningGetOrSetAccessor) != 0) && ((existingKind & DeclarationMeaningGetOrSetAccessor) != 0)) {
						if (existingKind != DeclarationMeaningGetOrSetAccessor && currentKind != existingKind) {
							seen.set(effectiveName, currentKind | existingKind);
						} else {
							return c.grammarErrorOnNode(name, Diagnostics.An_object_literal_cannot_have_multiple_get_Slashset_accessors_with_the_same_name);
						}
					} else {
						return c.grammarErrorOnNode(name, Diagnostics.An_object_literal_cannot_have_property_and_accessor_with_the_same_name);
					}
				}
			}
		}

		return false;
	}

	static function checkGrammarJsxElement(c:Checker, node:Node):Bool {
		c.checkGrammarJsxName(node.TagName());
		c.checkGrammarTypeArguments(node, node.TypeArgumentList());
		final seen = new Set<std.String>();
		for (attrNode in rangeOf(node.Attributes().Properties())) {
			if (attrNode.Kind == KindJsxSpreadAttribute) {
				continue;
			}
			final attr = attrNode.AsJsxAttribute();
			final name = attr.Name();
			final initializer = attr.Initializer;
			final textOfName = name.Text();
			if (!seen.Has(textOfName)) {
				seen.Add(textOfName);
			} else {
				return c.grammarErrorOnNode(name, Diagnostics.JSX_elements_cannot_have_multiple_attributes_with_the_same_name);
			}
			if (initializer != null && initializer.Kind == KindJsxExpression && initializer.Expression() == null) {
				return c.grammarErrorOnNode(initializer, Diagnostics.JSX_attributes_must_only_be_assigned_a_non_empty_expression);
			}
		}
		return false;
	}

	static function checkGrammarJsxName(c:Checker, node:JsxTagNameExpression):Bool {
		if (Ast.IsPropertyAccessExpression(node) && Ast.IsJsxNamespacedName(node.Expression())) {
			return c.grammarErrorOnNode(node.Expression(), Diagnostics.JSX_property_access_expressions_cannot_include_JSX_namespace_names);
		}

		if (Ast.IsJsxNamespacedName(node) && c.compilerOptions.GetJSXTransformEnabled() && !Scanner.IsIntrinsicJsxName(node.AsJsxNamespacedName().Namespace.Text())) {
			return c.grammarErrorOnNode(node, Diagnostics.React_components_cannot_include_JSX_namespace_names);
		}

		return false;
	}

	static function checkGrammarJsxExpression(c:Checker, node:JsxExpression):Bool {
		if (node.Expression != null && Ast.IsCommaSequence(node.Expression)) {
			return c.grammarErrorOnNode(node.Expression, Diagnostics.JSX_expressions_may_not_use_the_comma_operator_Did_you_mean_to_write_an_array);
		}

		return false;
	}

	static function checkGrammarForInOrForOfStatement(c:Checker, forInOrOfStatement:ForInOrOfStatement):Bool {
		final asNode = forInOrOfStatement.AsNode();
		if (c.checkGrammarStatementInAmbientContext(asNode)) {
			return true;
		}

		if (forInOrOfStatement.Kind == KindForOfStatement && forInOrOfStatement.AwaitModifier != null) {
			if ((forInOrOfStatement.Flags & NodeFlagsAwaitContext) == 0) {
				final sourceFile = Ast.GetSourceFileOfNode(asNode);
				if (Ast.IsInTopLevelContext(asNode)) {
					if (!c.hasParseDiagnostics(sourceFile)) {
						if (!Ast.IsEffectiveExternalModule(sourceFile, c.compilerOptions)) {
							c.addDiagnostic(Checker.createDiagnosticForNode(forInOrOfStatement.AwaitModifier, Diagnostics.X_for_await_loops_are_only_allowed_at_the_top_level_of_a_file_when_that_file_is_a_module_but_this_file_has_no_imports_or_exports_Consider_adding_an_empty_export_to_make_this_file_a_module));
						}
						// PORT: Go switch with `break`/`fallthrough` restructured; reportDefault = reaching the `default:` body.
						var reportDefault = false;
						switch (c.moduleKind) {
							case ModuleKindNode16 | ModuleKindNode18 | ModuleKindNode20 | ModuleKindNodeNext:
								final sourceFileMetaData = c.program.GetSourceFileMetaData(sourceFile.Path());
								if (sourceFileMetaData.ImpliedNodeFormat == ModuleKindCommonJS) {
									c.addDiagnostic(Checker.createDiagnosticForNode(forInOrOfStatement.AwaitModifier, Diagnostics.The_current_file_is_a_CommonJS_module_and_cannot_use_await_at_the_top_level));
								} else {
									// fallthrough
									reportDefault = !(c.languageVersion >= ScriptTargetES2017);
								}
							case ModuleKindES2022 | ModuleKindESNext | ModuleKindPreserve | ModuleKindSystem:
								reportDefault = !(c.languageVersion >= ScriptTargetES2017);
							default:
								reportDefault = true;
						}
						if (reportDefault) {
							c.addDiagnostic(Checker.createDiagnosticForNode(forInOrOfStatement.AwaitModifier, Diagnostics.Top_level_for_await_loops_are_only_allowed_when_the_module_option_is_set_to_es2022_esnext_system_node16_node18_node20_nodenext_or_preserve_and_the_target_option_is_set_to_es2017_or_higher));
						}
					}
				} else {
					// use of 'for-await-of' in non-async function
					if (!c.hasParseDiagnostics(sourceFile)) {
						final diagnostic = Checker.createDiagnosticForNode(forInOrOfStatement.AwaitModifier, Diagnostics.X_for_await_loops_are_only_allowed_within_async_functions_and_at_the_top_levels_of_modules);
						final containingFunc = Ast.GetContainingFunction(forInOrOfStatement.AsNode());
						if (containingFunc != null && containingFunc.Kind != KindConstructor) {
							Debug.Assert((Ast.GetFunctionFlags(containingFunc) & FunctionFlagsAsync) == 0, "Enclosing function should never be an async function.");
							final relatedInfo = Checker.createDiagnosticForNode(containingFunc, Diagnostics.Did_you_mean_to_mark_this_function_as_async);
							diagnostic.AddRelatedInfo(relatedInfo);
						}
						c.addDiagnostic(diagnostic);
						return true;
					}
				}
			}
		}

		if (Ast.IsForOfStatement(asNode) && (forInOrOfStatement.Flags & NodeFlagsAwaitContext) == 0 && Ast.IsIdentifier(forInOrOfStatement.Initializer) && forInOrOfStatement.Initializer.Text() == "async") {
			c.grammarErrorOnNode(forInOrOfStatement.Initializer, Diagnostics.The_left_hand_side_of_a_for_of_statement_may_not_be_async);
			return false;
		}

		if (forInOrOfStatement.Initializer.Kind == KindVariableDeclarationList) {
			final variableList = forInOrOfStatement.Initializer.AsVariableDeclarationList();
			if (!c.checkGrammarVariableDeclarationList(variableList)) {
				final declarations = variableList.Declarations;

				// declarations.length can be zero if there is an error in variable declaration in for-of or for-in
				// See http://www.ecma-international.org/ecma-262/6.0/#sec-for-in-and-for-of-statements for details
				// For example:
				//      var let = 10;
				//      for (let of [1,2,3]) {} // this is invalid ES6 syntax
				//      for (let in [1,2,3]) {} // this is invalid ES6 syntax
				// We will then want to skip on grammar checking on variableList declaration
				if (Core.len(declarations.Nodes) == 0) {
					return false;
				}

				if (declarations.Nodes.length > 1) {
					var diagnostic:Message = null;
					if (forInOrOfStatement.Kind == KindForInStatement) {
						diagnostic = Diagnostics.Only_a_single_variable_declaration_is_allowed_in_a_for_in_statement;
					} else {
						diagnostic = Diagnostics.Only_a_single_variable_declaration_is_allowed_in_a_for_of_statement;
					}
					return c.grammarErrorOnFirstToken(declarations.Nodes[1], diagnostic);
				}

				final firstVariableDeclaration = declarations.Nodes[0].AsVariableDeclaration();
				if (firstVariableDeclaration.Initializer != null) {
					var diagnostic:Message = null;
					if (forInOrOfStatement.Kind == KindForInStatement) {
						diagnostic = Diagnostics.The_variable_declaration_of_a_for_in_statement_cannot_have_an_initializer;
					} else {
						diagnostic = Diagnostics.The_variable_declaration_of_a_for_of_statement_cannot_have_an_initializer;
					}
					return c.grammarErrorOnNode(firstVariableDeclaration.Name(), diagnostic);
				}
				if (firstVariableDeclaration.Type != null) {
					var diagnostic:Message = null;
					if (forInOrOfStatement.Kind == KindForInStatement) {
						diagnostic = Diagnostics.The_left_hand_side_of_a_for_in_statement_cannot_use_a_type_annotation;
					} else {
						diagnostic = Diagnostics.The_left_hand_side_of_a_for_of_statement_cannot_use_a_type_annotation;
					}
					return c.grammarErrorOnNode(firstVariableDeclaration.AsNode(), diagnostic);
				}
			}
		}

		return false;
	}

	static function checkGrammarAccessor(c:Checker, accessor:AccessorDeclaration):Bool {
		final body = accessor.Body();
		if ((accessor.Flags & NodeFlagsAmbient) == 0 && (accessor.Parent.Kind != KindTypeLiteral) && (accessor.Parent.Kind != KindInterfaceDeclaration)) {
			if (body == null && !Ast.HasSyntacticModifier(accessor, ModifierFlagsAbstract)) {
				return c.grammarErrorAtPos(accessor, accessor.End() - 1, ";".length, Diagnostics.X_0_expected, "{");
			}
		}
		if (body != null) {
			if (Ast.HasSyntacticModifier(accessor, ModifierFlagsAbstract)) {
				return c.grammarErrorOnNode(accessor, Diagnostics.An_abstract_accessor_cannot_have_an_implementation);
			}
			if (accessor.Parent.Kind == KindTypeLiteral || accessor.Parent.Kind == KindInterfaceDeclaration) {
				return c.grammarErrorOnNode(body, Diagnostics.An_implementation_cannot_be_declared_in_ambient_contexts);
			}
		}

		final funcData = accessor.FunctionLikeData();
		var typeParameters:NodeList = null;
		if (funcData != null) {
			typeParameters = funcData.TypeParameters;
		}

		if (typeParameters != null) {
			return c.grammarErrorOnNode(accessor.Name(), Diagnostics.An_accessor_cannot_have_type_parameters);
		}
		if (!c.doesAccessorHaveCorrectParameterCount(accessor)) {
			return c.grammarErrorOnNode(accessor.Name(), Core.IfElse(accessor.Kind == KindGetAccessor, Diagnostics.A_get_accessor_cannot_have_parameters, Diagnostics.A_set_accessor_must_have_exactly_one_parameter));
		}
		if (accessor.Kind == KindSetAccessor) {
			if (funcData.Type != null) {
				return c.grammarErrorOnNode(accessor.Name(), Diagnostics.A_set_accessor_cannot_have_a_return_type_annotation);
			}

			final parameterNode = Checker.GetSetAccessorValueParameter(accessor);
			if (parameterNode == null) {
				throw "Return value does not match parameter count assertion.";
			}
			final parameter = parameterNode.AsParameterDeclaration();
			if (parameter.DotDotDotToken != null) {
				return c.grammarErrorOnNode(parameter.DotDotDotToken, Diagnostics.A_set_accessor_cannot_have_rest_parameter);
			}
			if (parameter.QuestionToken != null) {
				return c.grammarErrorOnNode(parameter.QuestionToken, Diagnostics.A_set_accessor_cannot_have_an_optional_parameter);
			}
			if (parameter.Initializer != null) {
				return c.grammarErrorOnNode(accessor.Name(), Diagnostics.A_set_accessor_parameter_cannot_have_an_initializer);
			}
		}

		return false;
	}

	// Does the accessor have the right number of parameters?
	//
	//	A `get` accessor has no parameters or a single `this` parameter.
	//	A `set` accessor has one parameter or a `this` parameter and one more parameter.
	static function doesAccessorHaveCorrectParameterCount(c:Checker, accessor:AccessorDeclaration):Bool {
		// `getAccessorThisParameter` returns `nil` if the accessor's arity is incorrect,
		// even if there is a `this` parameter declared.
		return c.getAccessorThisParameter(accessor) != null || Core.len(accessor.Parameters()) == (accessor.Kind == KindGetAccessor ? 0 : 1);
	}

	static function checkGrammarTypeOperatorNode(c:Checker, node:TypeOperatorNode):Bool {
		if (node.Operator == KindUniqueKeyword) {
			final innerType = node.Type;
			if (innerType.Kind != KindSymbolKeyword) {
				return c.grammarErrorOnNode(innerType, Diagnostics.X_0_expected, Scanner.TokenToString(KindSymbolKeyword));
			}
			final parent = Ast.WalkUpParenthesizedTypes(node.Parent);
			switch (parent.Kind) {
				case KindVariableDeclaration:
					final decl = parent.AsVariableDeclaration();
					if (decl.Name().Kind != KindIdentifier) {
						return c.grammarErrorOnNode(node.AsNode(), Diagnostics.X_unique_symbol_types_may_not_be_used_on_a_variable_declaration_with_a_binding_name);
					}
					if (!Checker.isVariableDeclarationInVariableStatement(decl.AsNode())) {
						return c.grammarErrorOnNode(node.AsNode(), Diagnostics.X_unique_symbol_types_are_only_allowed_on_variables_in_a_variable_statement);
					}
					if ((decl.Parent.Flags & NodeFlagsConst) == 0) {
						return c.grammarErrorOnNode(parent.AsVariableDeclaration().Name(), Diagnostics.A_variable_whose_type_is_a_unique_symbol_type_must_be_const);
					}
				case KindPropertyDeclaration:
					if (!Ast.IsStatic(parent) || !Checker.hasReadonlyModifier(parent)) {
						return c.grammarErrorOnNode(parent.AsPropertyDeclaration().Name(), Diagnostics.A_property_of_a_class_whose_type_is_a_unique_symbol_type_must_be_both_static_and_readonly);
					}
				case KindPropertySignature:
					if (!Ast.HasSyntacticModifier(parent, ModifierFlagsReadonly)) {
						return c.grammarErrorOnNode(parent.AsPropertySignatureDeclaration().Name(), Diagnostics.A_property_of_an_interface_or_type_literal_whose_type_is_a_unique_symbol_type_must_be_readonly);
					}
				default:
					return c.grammarErrorOnNode(node.AsNode(), Diagnostics.X_unique_symbol_types_are_not_allowed_here);
			}
		} else if (node.Operator == KindReadonlyKeyword) {
			final innerType = node.Type;
			if (innerType.Kind != KindArrayType && innerType.Kind != KindTupleType) {
				return c.grammarErrorOnFirstToken(node.AsNode(), Diagnostics.X_readonly_type_modifier_is_only_permitted_on_array_and_tuple_literal_types, Scanner.TokenToString(KindSymbolKeyword));
			}
		}

		return false;
	}

	static function checkGrammarForInvalidDynamicName(c:Checker, node:DeclarationName, message:Message):Bool {
		if (!c.isNonBindableDynamicName(node)) {
			return false;
		}
		var expression:Node = null;
		if (Ast.IsElementAccessExpression(node)) {
			expression = Ast.SkipParentheses(node.AsElementAccessExpression().ArgumentExpression);
		} else {
			expression = node.Expression();
		}

		if (!Ast.IsEntityNameExpression(expression)) {
			return c.grammarErrorOnNode(node, message);
		}

		return false;
	}

	// Indicates whether a declaration name is a dynamic name that cannot be late-bound.
	static function isNonBindableDynamicName(c:Checker, node:DeclarationName):Bool {
		return Ast.IsDynamicName(node) && !c.isLateBindableName(node);
	}

	static function checkGrammarMethod(c:Checker, node:Node):Bool {
		if (c.checkGrammarFunctionLikeDeclaration(node)) {
			return true;
		}

		if (node.Kind == KindMethodDeclaration) {
			if (node.Parent.Kind == KindObjectLiteralExpression) {
				// We only disallow modifier on a method declaration if it is a property of object-literal-expression
				final modifiers = node.Modifiers();
				if (modifiers != null && !(Core.len(modifiers.Nodes) == 1 && modifiers.Nodes[0].Kind == KindAsyncKeyword)) {
					return c.grammarErrorOnFirstToken(node, Diagnostics.Modifiers_cannot_appear_here);
				}

				final methodDecl = node.AsMethodDeclaration();
				if (c.checkGrammarForInvalidQuestionMark(methodDecl.PostfixToken, Diagnostics.An_object_member_cannot_be_declared_optional)) {
					return true;
				}
				if (c.checkGrammarForInvalidExclamationToken(methodDecl.PostfixToken, Diagnostics.A_definite_assignment_assertion_is_not_permitted_in_this_context)) {
					return true;
				}
				if (node.Body() == null) {
					return c.grammarErrorAtPos(node, node.End() - 1, ";".length, Diagnostics.X_0_expected, "{");
				}
			}
			if (c.checkGrammarForGenerator(node)) {
				return true;
			}
		}

		if (Ast.IsClassLike(node.Parent)) {
			// Technically, computed properties in ambient contexts is disallowed
			// for property declarations and accessors too, not just methods.
			// However, property declarations disallow computed names in general,
			// and accessors are not allowed in ambient contexts in general,
			// so this error only really matters for methods.
			if ((node.Flags & NodeFlagsAmbient) != 0) {
				return c.checkGrammarForInvalidDynamicName(node.Name(), Diagnostics.A_computed_property_name_in_an_ambient_context_must_refer_to_an_expression_whose_type_is_a_literal_type_or_a_unique_symbol_type);
			} else if (node.Kind == KindMethodDeclaration && node.Body() == null) {
				return c.checkGrammarForInvalidDynamicName(node.Name(), Diagnostics.A_computed_property_name_in_a_method_overload_must_refer_to_an_expression_whose_type_is_a_literal_type_or_a_unique_symbol_type);
			}
		} else if (node.Parent.Kind == KindInterfaceDeclaration) {
			return c.checkGrammarForInvalidDynamicName(node.Name(), Diagnostics.A_computed_property_name_in_an_interface_must_refer_to_an_expression_whose_type_is_a_literal_type_or_a_unique_symbol_type);
		} else if (node.Parent.Kind == KindTypeLiteral) {
			return c.checkGrammarForInvalidDynamicName(node.Name(), Diagnostics.A_computed_property_name_in_a_type_literal_must_refer_to_an_expression_whose_type_is_a_literal_type_or_a_unique_symbol_type);
		}

		return false;
	}

	static function checkGrammarBreakOrContinueStatement(c:Checker, node:Node):Bool {
		final targetLabel = node.Label();
		var current:Node = node;
		while (current != null) {
			if (Ast.IsFunctionLikeOrClassStaticBlockDeclaration(current)) {
				return c.grammarErrorOnNode(node, Diagnostics.Jump_target_cannot_cross_function_boundary);
			}

			switch (current.Kind) {
				case KindLabeledStatement:
					if (targetLabel != null && current.Label().Text() == targetLabel.Text()) {
						// found matching label - verify that label usage is correct
						// continue can only target labels that are on iteration statements
						final isMisplacedContinueLabel = node.Kind == KindContinueStatement && !Ast.IsIterationStatement(current.Statement(), true /*lookInLabeledStatements*/);

						if (isMisplacedContinueLabel) {
							return c.grammarErrorOnNode(node, Diagnostics.A_continue_statement_can_only_jump_to_a_label_of_an_enclosing_iteration_statement);
						}

						return false;
					}
				case KindSwitchStatement:
					if (node.Kind == KindBreakStatement && targetLabel == null) {
						// unlabeled break within switch statement - ok
						return false;
					}
				default:
					if (Ast.IsIterationStatement(current, false /*lookInLabeledStatements*/) && targetLabel == null) {
						// unlabeled break or continue within iteration statement - ok
						return false;
					}
			}

			current = current.Parent;
		}

		if (targetLabel != null) {
			var message:Message = null;
			if (node.Kind == KindBreakStatement) {
				message = Diagnostics.A_break_statement_can_only_jump_to_a_label_of_an_enclosing_statement;
			} else {
				message = Diagnostics.A_continue_statement_can_only_jump_to_a_label_of_an_enclosing_iteration_statement;
			}

			return c.grammarErrorOnNode(node, message);
		} else {
			var message:Message = null;
			if (node.Kind == KindBreakStatement) {
				message = Diagnostics.A_break_statement_can_only_be_used_within_an_enclosing_iteration_or_switch_statement;
			} else {
				message = Diagnostics.A_continue_statement_can_only_be_used_within_an_enclosing_iteration_statement;
			}
			return c.grammarErrorOnNode(node, message);
		}
	}

	static function checkGrammarBindingElement(c:Checker, node:BindingElement):Bool {
		if (node.DotDotDotToken != null) {
			final elements = node.Parent.ElementList();
			if (node.AsNode() != Core.LastOrNil(elements.Nodes)) {
				return c.grammarErrorOnNode(node.AsNode(), Diagnostics.A_rest_element_must_be_last_in_a_destructuring_pattern);
			}
			c.checkGrammarForDisallowedTrailingComma(elements, Diagnostics.A_rest_parameter_or_binding_pattern_may_not_have_a_trailing_comma);

			if (node.PropertyName != null) {
				return c.grammarErrorOnNode(node.Name(), Diagnostics.A_rest_element_cannot_have_a_property_name);
			}
		}

		if (node.DotDotDotToken != null && node.Initializer != null) {
			// Error on equals token which immediately precedes the initializer
			return c.grammarErrorAtPos(node.AsNode(), node.Initializer.Pos() - 1, 1, Diagnostics.A_rest_element_cannot_have_an_initializer);
		}

		return false;
	}

	static function checkGrammarVariableDeclaration(c:Checker, node:VariableDeclaration):Bool {
		final nodeFlags = c.getCombinedNodeFlagsCached(node.AsNode());
		final blockScopeKind = nodeFlags & NodeFlagsBlockScoped;
		if (Ast.IsBindingPattern(node.Name())) {
			// PORT: switch on NodeFlagsAwaitUsing (a computed enum-abstract value, not a pattern) as if/else.
			if (blockScopeKind == NodeFlagsAwaitUsing) {
				return c.grammarErrorOnNode(node.AsNode(), Diagnostics.X_0_declarations_may_not_have_binding_patterns, "await using");
			} else if (blockScopeKind == NodeFlagsUsing) {
				return c.grammarErrorOnNode(node.AsNode(), Diagnostics.X_0_declarations_may_not_have_binding_patterns, "using");
			}
		}

		if (node.Parent.Parent.Kind != KindForInStatement && node.Parent.Parent.Kind != KindForOfStatement) {
			if ((nodeFlags & NodeFlagsAmbient) != 0) {
				c.checkAmbientInitializer(node.AsNode());
			} else if (node.Initializer == null) {
				if (Ast.IsBindingPattern(node.Name()) && !Ast.IsBindingPattern(node.Parent)) {
					return c.grammarErrorOnNode(node.AsNode(), Diagnostics.A_destructuring_declaration_must_have_an_initializer);
				}
				// PORT: switch on NodeFlagsAwaitUsing (a computed enum-abstract value, not a pattern) as if/else.
				if (blockScopeKind == NodeFlagsAwaitUsing) {
					return c.grammarErrorOnNode(node.AsNode(), Diagnostics.X_0_declarations_must_be_initialized, "await using");
				} else if (blockScopeKind == NodeFlagsUsing) {
					return c.grammarErrorOnNode(node.AsNode(), Diagnostics.X_0_declarations_must_be_initialized, "using");
				} else if (blockScopeKind == NodeFlagsConst) {
					return c.grammarErrorOnNode(node.AsNode(), Diagnostics.X_0_declarations_must_be_initialized, "const");
				}
			}
		}

		if (node.ExclamationToken != null && (node.Parent.Parent.Kind != KindVariableStatement || node.Type == null || node.Initializer != null || (nodeFlags & NodeFlagsAmbient) != 0)) {
			var message:Message = null;
			if (node.Initializer != null) {
				message = Diagnostics.Declarations_with_initializers_cannot_also_have_definite_assignment_assertions;
			} else if (node.Type == null) {
				message = Diagnostics.Declarations_with_definite_assignment_assertions_must_also_have_type_annotations;
			} else {
				message = Diagnostics.A_definite_assignment_assertion_is_not_permitted_in_this_context;
			}
			return c.grammarErrorOnNode(node.ExclamationToken, message);
		}

		if (c.program.GetEmitModuleFormatOfFile(hasFileName(Ast.GetSourceFileOfNode(node.AsNode()))) < ModuleKindSystem && ((node.Parent.Parent.Flags & NodeFlagsAmbient) == 0) && Ast.HasSyntacticModifier(node.Parent.Parent, ModifierFlagsExport)) {
			c.checkGrammarForEsModuleMarkerInBindingName(node.Name());
		}

		// 1. LexicalDeclaration : LetOrConst BindingList ;
		// It is a Syntax Error if the BoundNames of BindingList contains "let".
		// 2. ForDeclaration: ForDeclaration : LetOrConst ForBinding
		// It is a Syntax Error if the BoundNames of ForDeclaration contains "let".

		// It is a SyntaxError if a VariableDeclaration or VariableDeclarationNoIn occurs within strict code
		// and its Identifier is eval or arguments
		return blockScopeKind != 0 && c.checkGrammarNameInLetOrConstDeclarations(node.Name());
	}

	static function checkGrammarForEsModuleMarkerInBindingName(c:Checker, name:Node):Bool {
		if (Ast.IsIdentifier(name)) {
			if (name.Text() == "__esModule") {
				return c.grammarErrorOnNodeSkippedOnNoEmit(name, Diagnostics.Identifier_expected_esModule_is_reserved_as_an_exported_marker_when_transforming_ECMAScript_modules);
			}
		} else {
			for (element in rangeOf(name.Elements())) {
				if (element.Name() != null) {
					return c.checkGrammarForEsModuleMarkerInBindingName(element.Name());
				}
			}
		}
		return false;
	}

	static function checkGrammarNameInLetOrConstDeclarations(c:Checker, name:Node):Bool {
		if (name.Kind == KindIdentifier) {
			if (name.Text() == "let") {
				return c.grammarErrorOnNode(name, Diagnostics.X_let_is_not_allowed_to_be_used_as_a_name_in_let_or_const_declarations);
			}
		} else {
			final elements = name.Elements();
			for (element in rangeOf(elements)) {
				final bindingElement = element.AsBindingElement();
				if (bindingElement.Name() != null) {
					c.checkGrammarNameInLetOrConstDeclarations(bindingElement.Name());
				}
			}
		}
		return false;
	}

	static function checkGrammarVariableDeclarationList(c:Checker, declarationList:VariableDeclarationList):Bool {
		final declarations = declarationList.Declarations;
		if (c.checkGrammarForDisallowedTrailingComma(declarations, Diagnostics.Trailing_comma_not_allowed)) {
			return true;
		}

		if (Core.len(declarations.Nodes) == 0) {
			return c.grammarErrorAtPos(declarationList.AsNode(), declarations.Pos(), declarations.End() - declarations.Pos(), Diagnostics.Variable_declaration_list_cannot_be_empty);
		}

		final blockScopeFlags = declarationList.Flags & NodeFlagsBlockScoped;
		if (blockScopeFlags == NodeFlagsUsing || blockScopeFlags == NodeFlagsAwaitUsing) {
			if (Ast.IsForInStatement(declarationList.Parent)) {
				return c.grammarErrorOnNode(declarationList.AsNode(), Core.IfElse(blockScopeFlags == NodeFlagsUsing, Diagnostics.The_left_hand_side_of_a_for_in_statement_cannot_be_a_using_declaration, Diagnostics.The_left_hand_side_of_a_for_in_statement_cannot_be_an_await_using_declaration));
			}
			if ((declarationList.Flags & NodeFlagsAmbient) != 0) {
				return c.grammarErrorOnNode(declarationList.AsNode(), Core.IfElse(blockScopeFlags == NodeFlagsUsing, Diagnostics.X_using_declarations_are_not_allowed_in_ambient_contexts, Diagnostics.X_await_using_declarations_are_not_allowed_in_ambient_contexts));
			}
			if (Ast.IsVariableStatement(declarationList.Parent) && (Ast.IsCaseClause(declarationList.Parent.Parent) || Ast.IsDefaultClause(declarationList.Parent.Parent))) {
				return c.grammarErrorOnNode(declarationList.AsNode(), Core.IfElse(blockScopeFlags == NodeFlagsUsing, Diagnostics.X_using_declarations_are_not_allowed_in_case_or_default_clauses_unless_contained_within_a_block, Diagnostics.X_await_using_declarations_are_not_allowed_in_case_or_default_clauses_unless_contained_within_a_block));
			}
		}

		if (blockScopeFlags == NodeFlagsAwaitUsing) {
			return c.checkGrammarAwaitOrAwaitUsing(declarationList.AsNode());
		}

		return false;
	}

	static function checkGrammarAwaitOrAwaitUsing(c:Checker, node:Node):Bool {
		// Grammar checking
		var hasError = false;
		final container = Checker.getContainingFunctionOrClassStaticBlock(node);
		if (container != null && Ast.IsClassStaticBlockDeclaration(container)) {
			// NOTE: We report this regardless as to whether there are parse diagnostics.
			var message:Message = null;
			if (Ast.IsAwaitExpression(node)) {
				message = Diagnostics.X_await_expression_cannot_be_used_inside_a_class_static_block;
			} else {
				message = Diagnostics.X_await_using_statements_cannot_be_used_inside_a_class_static_block;
			}
			c.error(node, message);
			hasError = true;
		} else if ((node.Flags & NodeFlagsAwaitContext) == 0) {
			if (Ast.IsInTopLevelContext(node)) {
				final sourceFile = Ast.GetSourceFileOfNode(node);
				if (!c.hasParseDiagnostics(sourceFile)) {
					var span:TextRange = null;
					var spanCalculated = false;
					if (!Ast.IsEffectiveExternalModule(sourceFile, c.compilerOptions)) {
						span = Scanner.GetRangeOfTokenAtPosition(sourceFile, node.Pos());
						spanCalculated = true;
						var message:Message = null;
						if (Ast.IsAwaitExpression(node)) {
							message = Diagnostics.X_await_expressions_are_only_allowed_at_the_top_level_of_a_file_when_that_file_is_a_module_but_this_file_has_no_imports_or_exports_Consider_adding_an_empty_export_to_make_this_file_a_module;
						} else {
							message = Diagnostics.X_await_using_statements_are_only_allowed_at_the_top_level_of_a_file_when_that_file_is_a_module_but_this_file_has_no_imports_or_exports_Consider_adding_an_empty_export_to_make_this_file_a_module;
						}
						final diagnostic = Ast.NewDiagnostic(sourceFile, span, message);
						c.addDiagnostic(diagnostic);
						hasError = true;
					}
					// PORT: Go switch with `break`/`fallthrough` restructured; reportDefault = reaching the `default:` body.
					var reportDefault = false;
					switch (c.moduleKind) {
						case ModuleKindNode16 | ModuleKindNode18 | ModuleKindNode20 | ModuleKindNodeNext:
							final sourceFileMetaData = c.program.GetSourceFileMetaData(sourceFile.Path());
							if (sourceFileMetaData.ImpliedNodeFormat == ModuleKindCommonJS) {
								if (!spanCalculated) {
									span = Scanner.GetRangeOfTokenAtPosition(sourceFile, node.Pos());
								}
								c.addDiagnostic(Ast.NewDiagnostic(sourceFile, span, Diagnostics.The_current_file_is_a_CommonJS_module_and_cannot_use_await_at_the_top_level));
								hasError = true;
							} else {
								// fallthrough
								reportDefault = !(c.languageVersion >= ScriptTargetES2017);
							}
						case ModuleKindES2022 | ModuleKindESNext | ModuleKindPreserve | ModuleKindSystem:
							reportDefault = !(c.languageVersion >= ScriptTargetES2017);
						default:
							reportDefault = true;
					}
					if (reportDefault) {
						if (!spanCalculated) {
							span = Scanner.GetRangeOfTokenAtPosition(sourceFile, node.Pos());
						}
						var message:Message = null;
						if (Ast.IsAwaitExpression(node)) {
							message = Diagnostics.Top_level_await_expressions_are_only_allowed_when_the_module_option_is_set_to_es2022_esnext_system_node16_node18_node20_nodenext_or_preserve_and_the_target_option_is_set_to_es2017_or_higher;
						} else {
							message = Diagnostics.Top_level_await_using_statements_are_only_allowed_when_the_module_option_is_set_to_es2022_esnext_system_node16_node18_node20_nodenext_or_preserve_and_the_target_option_is_set_to_es2017_or_higher;
						}
						c.addDiagnostic(Ast.NewDiagnostic(sourceFile, span, message));
						hasError = true;
					}
				}
			} else {
				// use of 'await' in non-async function
				final sourceFile = Ast.GetSourceFileOfNode(node);
				if (!c.hasParseDiagnostics(sourceFile)) {
					final span = Scanner.GetRangeOfTokenAtPosition(sourceFile, node.Pos());
					var message:Message = null;
					if (Ast.IsAwaitExpression(node)) {
						message = Diagnostics.X_await_expressions_are_only_allowed_within_async_functions_and_at_the_top_levels_of_modules;
					} else {
						message = Diagnostics.X_await_using_statements_are_only_allowed_within_async_functions_and_at_the_top_levels_of_modules;
					}
					final diagnostic = Ast.NewDiagnostic(sourceFile, span, message);
					if (container != null && container.Kind != KindConstructor && !Checker.hasAsyncModifier(container)) {
						final relatedInfo = Checker.NewDiagnosticForNode(container, Diagnostics.Did_you_mean_to_mark_this_function_as_async);
						diagnostic.AddRelatedInfo(relatedInfo);
					}
					c.addDiagnostic(diagnostic);
					hasError = true;
				}
			}
		}

		if (Ast.IsAwaitExpression(node) && c.isInParameterInitializerBeforeContainingFunction(node)) {
			// NOTE: We report this regardless as to whether there are parse diagnostics.
			c.error(node, Diagnostics.X_await_expressions_cannot_be_used_in_a_parameter_initializer);
			hasError = true;
		}

		return hasError;
	}

	static function checkGrammarYieldExpression(c:Checker, node:Node):Bool {
		var hasError = false;
		if ((node.Flags & NodeFlagsYieldContext) == 0) {
			c.grammarErrorOnFirstToken(node, Diagnostics.A_yield_expression_is_only_allowed_in_a_generator_body);
			hasError = true;
		}
		if (c.isInParameterInitializerBeforeContainingFunction(node)) {
			c.error(node, Diagnostics.X_yield_expressions_cannot_be_used_in_a_parameter_initializer);
			hasError = true;
		}
		return hasError;
	}

	static function checkGrammarForDisallowedBlockScopedVariableStatement(c:Checker, node:VariableStatement):Bool {
		if (!c.containerAllowsBlockScopedVariable(node.Parent)) {
			final blockScopeKind = c.getCombinedNodeFlagsCached(node.DeclarationList) & NodeFlagsBlockScoped;
			if (blockScopeKind != 0) {
				var keyword:std.String = "";
				if (blockScopeKind == NodeFlagsLet) {
					keyword = "let";
				} else if (blockScopeKind == NodeFlagsConst) {
					keyword = "const";
				} else if (blockScopeKind == NodeFlagsUsing) {
					keyword = "using";
				} else if (blockScopeKind == NodeFlagsAwaitUsing) {
					keyword = "await using";
				} else {
					throw "Unknown BlockScope flag";
				}
				c.error(node.AsNode(), Diagnostics.X_0_declarations_can_only_be_declared_inside_a_block, keyword);
			}
		}

		return false;
	}

	static function containerAllowsBlockScopedVariable(c:Checker, parent:Node):Bool {
		switch (parent.Kind) {
			case KindIfStatement | KindDoStatement | KindWhileStatement | KindWithStatement | KindForStatement | KindForInStatement | KindForOfStatement:
				return false;
			case KindLabeledStatement:
				return c.containerAllowsBlockScopedVariable(parent.Parent);
			default:
		}

		return true;
	}

	static function checkGrammarMetaProperty(c:Checker, node:MetaProperty):Bool {
		final nodeName = node.Name();
		final nameText = nodeName.Text();

		switch (node.KeywordToken) {
			case KindNewKeyword:
				if (nameText != "target") {
					return c.grammarErrorOnNode(nodeName, Diagnostics.X_0_is_not_a_valid_meta_property_for_keyword_1_Did_you_mean_2, nameText, Scanner.TokenToString(node.KeywordToken), "target");
				}
			case KindImportKeyword:
				if (nameText != "meta") {
					final isCallee = Ast.IsCallExpression(node.Parent) && node.Parent.Expression() == node.AsNode();
					if (nameText == "defer") {
						if (!isCallee) {
							return c.grammarErrorAtPos(node.AsNode(), node.AsNode().End(), 0, Diagnostics.X_0_expected, "(");
						}
					} else {
						if (isCallee) {
							return c.grammarErrorOnNode(nodeName, Diagnostics.X_0_is_not_a_valid_meta_property_for_keyword_import_Did_you_mean_meta_or_defer, nameText);
						}
						return c.grammarErrorOnNode(nodeName, Diagnostics.X_0_is_not_a_valid_meta_property_for_keyword_1_Did_you_mean_2, nameText, Scanner.TokenToString(node.KeywordToken), "meta");
					}
				}
			default:
		}

		return false;
	}

	static function checkGrammarConstructorTypeParameters(c:Checker, node:ConstructorDeclaration):Bool {
		final range_ = node.TypeParameters;
		if (range_ != null) {
			var pos = 0;
			if (range_.Pos() == range_.End()) {
				pos = range_.Pos();
			} else {
				pos = Scanner.SkipTrivia(Ast.GetSourceFileOfNode(node.AsNode()).Text(), range_.Pos());
			}
			return c.grammarErrorAtPos(node.AsNode(), pos, range_.End() - pos, Diagnostics.Type_parameters_cannot_appear_on_a_constructor_declaration);
		}

		return false;
	}

	static function checkGrammarConstructorTypeAnnotation(c:Checker, node:ConstructorDeclaration):Bool {
		final t = node.Type;
		if (t != null) {
			return c.grammarErrorOnNode(t, Diagnostics.Type_annotation_cannot_appear_on_a_constructor_declaration);
		}
		return false;
	}

	static function checkGrammarProperty(c:Checker, node:Node):Bool {
		final propertyName = node.Name();
		if (Ast.IsComputedPropertyName(propertyName) && Ast.IsBinaryExpression(propertyName.Expression()) && propertyName.Expression().AsBinaryExpression().OperatorToken.Kind == KindInKeyword) {
			return c.grammarErrorOnNode(node.Parent.Members()[0], Diagnostics.A_mapped_type_may_not_declare_properties_or_methods);
		}
		if (Ast.IsClassLike(node.Parent)) {
			if (Ast.IsStringLiteral(propertyName) && propertyName.Text() == "constructor") {
				return c.grammarErrorOnNode(propertyName, Diagnostics.Classes_may_not_have_a_field_named_constructor);
			}
			if (c.checkGrammarForInvalidDynamicName(propertyName, Diagnostics.A_computed_property_name_in_a_class_property_declaration_must_have_a_simple_literal_type_or_a_unique_symbol_type)) {
				return true;
			}
			if (Ast.IsAutoAccessorPropertyDeclaration(node) && c.checkGrammarForInvalidQuestionMark(node.PostfixToken(), Diagnostics.An_accessor_property_cannot_be_declared_optional)) {
				return true;
			}
		} else if (Ast.IsInterfaceDeclaration(node.Parent)) {
			if (c.checkGrammarForInvalidDynamicName(propertyName, Diagnostics.A_computed_property_name_in_an_interface_must_refer_to_an_expression_whose_type_is_a_literal_type_or_a_unique_symbol_type)) {
				return true;
			}
			if (!Ast.IsPropertySignatureDeclaration(node)) {
				// Interfaces cannot contain property declarations
				throw "Unexpected node kind " + Strconv.Quote(node.Kind.String());
			}
			final initializer = node.Initializer();
			if (initializer != null) {
				return c.grammarErrorOnNode(initializer, Diagnostics.An_interface_property_cannot_have_an_initializer);
			}
		} else if (Ast.IsTypeLiteralNode(node.Parent)) {
			if (c.checkGrammarForInvalidDynamicName(node.Name(), Diagnostics.A_computed_property_name_in_a_type_literal_must_refer_to_an_expression_whose_type_is_a_literal_type_or_a_unique_symbol_type)) {
				return true;
			}
			if (!Ast.IsPropertySignatureDeclaration(node)) {
				// Type literals cannot contain property declarations
				throw "Unexpected node kind " + Strconv.Quote(node.Kind.String());
			}
			final initializer = node.Initializer();
			if (initializer != null) {
				return c.grammarErrorOnNode(initializer, Diagnostics.A_type_literal_property_cannot_have_an_initializer);
			}
		}

		if ((node.Flags & NodeFlagsAmbient) != 0) {
			c.checkAmbientInitializer(node);
		}

		if (Ast.IsPropertyDeclaration(node)) {
			final propDecl = node.AsPropertyDeclaration();
			final postfixToken = propDecl.PostfixToken;
			if (postfixToken != null && postfixToken.Kind == KindExclamationToken) {
				if (propDecl.Initializer != null) {
					return c.grammarErrorOnNode(postfixToken, Diagnostics.Declarations_with_initializers_cannot_also_have_definite_assignment_assertions);
				} else if (propDecl.Type == null) {
					return c.grammarErrorOnNode(postfixToken, Diagnostics.Declarations_with_definite_assignment_assertions_must_also_have_type_annotations);
				} else if (!Ast.IsClassLike(node.Parent) || (node.Flags & NodeFlagsAmbient) != 0 || Ast.IsStatic(node) || Ast.HasAbstractModifier(node)) {
					return c.grammarErrorOnNode(postfixToken, Diagnostics.A_definite_assignment_assertion_is_not_permitted_in_this_context);
				}
			}
		}

		return false;
	}

	static function checkAmbientInitializer(c:Checker, node:Node):Bool {
		var initializer:Expression = null;
		var typeNode:TypeNode = null;
		switch (node.Kind) {
			case KindVariableDeclaration:
				final varDecl = node.AsVariableDeclaration();
				initializer = varDecl.Initializer;
				typeNode = varDecl.Type;
			case KindPropertyDeclaration:
				final propDecl = node.AsPropertyDeclaration();
				initializer = propDecl.Initializer;
				typeNode = propDecl.Type;
			case KindPropertySignature:
				final propSig = node.AsPropertySignatureDeclaration();
				initializer = propSig.Initializer;
				typeNode = propSig.Type;
			default:
				throw "Unexpected node kind " + Strconv.Quote(node.Kind.String());
		}

		if (initializer != null) {
			final isInvalidInitializer = !(Checker.isInitializerStringOrNumberLiteralExpression(initializer) || c.isInitializerSimpleLiteralEnumReference(initializer) || initializer.Kind == KindTrueKeyword || initializer.Kind == KindFalseKeyword || Checker.isInitializerBigIntLiteralExpression(initializer));
			final isConstOrReadonly = Checker.isDeclarationReadonly(node) || Ast.IsVariableDeclaration(node) && c.isVarConstLike(node);
			if (isConstOrReadonly && (typeNode == null)) {
				if (isInvalidInitializer) {
					return c.grammarErrorOnNode(initializer, Diagnostics.A_const_initializer_in_an_ambient_context_must_be_a_string_or_numeric_literal_or_literal_enum_reference);
				}
			} else {
				return c.grammarErrorOnNode(initializer, Diagnostics.Initializers_are_not_allowed_in_ambient_contexts);
			}
		}

		return false;
	}

	static function isInitializerSimpleLiteralEnumReference(c:Checker, expr:Expression):Bool {
		if (Ast.IsPropertyAccessExpression(expr)) {
			return (c.checkExpressionCached(expr).flags & TypeFlagsEnumLike) != 0;
		}

		if (Ast.IsElementAccessExpression(expr)) {
			final elementAccess = expr.AsElementAccessExpression();

			return Checker.isInitializerStringOrNumberLiteralExpression(elementAccess.ArgumentExpression)
				&& Ast.IsEntityNameExpression(elementAccess.Expression)
				&& (c.checkExpressionCached(expr).flags & TypeFlagsEnumLike) != 0;
		}

		return false;
	}

	static function checkGrammarTopLevelElementForRequiredDeclareModifier(c:Checker, node:Node):Bool {
		// A declare modifier is required for any top level .d.ts declaration except export=, export default, export as namespace
		// interfaces and imports categories:
		//
		//  DeclarationElement:
		//     ExportAssignment
		//     export_opt   InterfaceDeclaration
		//     export_opt   TypeAliasDeclaration
		//     export_opt   ImportDeclaration
		//     export_opt   ExternalImportDeclaration
		//     export_opt   AmbientDeclaration
		//
		// TODO: The spec needs to be amended to reflect this grammar.
		if (node.Kind == KindInterfaceDeclaration || node.Kind == KindTypeAliasDeclaration || node.Kind == KindImportDeclaration || node.Kind == KindJSImportDeclaration || node.Kind == KindImportEqualsDeclaration || node.Kind == KindExportDeclaration || node.Kind == KindExportAssignment || node.Kind == KindNamespaceExportDeclaration || Ast.HasSyntacticModifier(node, ModifierFlagsAmbient | ModifierFlagsExport | ModifierFlagsDefault)) {
			return false;
		}

		return c.grammarErrorOnFirstToken(node, Diagnostics.Top_level_declarations_in_d_ts_files_must_start_with_either_a_declare_or_export_modifier);
	}

	static function checkGrammarTopLevelElementsForRequiredDeclareModifier(c:Checker, file:SourceFile):Bool {
		for (decl in rangeOf(file.Statements.Nodes)) {
			if (Ast.IsDeclarationNode(decl) || decl.Kind == KindVariableStatement) {
				if (c.checkGrammarTopLevelElementForRequiredDeclareModifier(decl)) {
					return true;
				}
			}
		}
		return false;
	}

	static function checkGrammarSourceFile(c:Checker, node:SourceFile):Bool {
		return (node.Flags & NodeFlagsAmbient) != 0 && c.checkGrammarTopLevelElementsForRequiredDeclareModifier(node);
	}

	static function checkGrammarStatementInAmbientContext(c:Checker, node:Node):Bool {
		if ((node.Flags & NodeFlagsAmbient) != 0) {
			// Find containing block which is either Block, ModuleBlock, SourceFile
			final links = c.nodeLinks.Get(node);
			if (!links.hasReportedStatementInAmbientContext && (Ast.IsFunctionLike(node.Parent) || Ast.IsAccessor(node.Parent))) {
				links.hasReportedStatementInAmbientContext = c.grammarErrorOnFirstToken(node, Diagnostics.An_implementation_cannot_be_declared_in_ambient_contexts);
				return links.hasReportedStatementInAmbientContext;
			}

			// We are either parented by another statement, or some sort of block.
			// If we're in a block, we only want to really report an error once
			// to prevent noisiness.  So use a bit on the block to indicate if
			// this has already been reported, and don't report if it has.
			//
			if (node.Parent.Kind == KindBlock || node.Parent.Kind == KindModuleBlock || node.Parent.Kind == KindSourceFile) {
				final links = c.nodeLinks.Get(node.Parent);
				// Check if the containing block ever report this error
				if (!links.hasReportedStatementInAmbientContext) {
					links.hasReportedStatementInAmbientContext = c.grammarErrorOnFirstToken(node, Diagnostics.Statements_are_not_allowed_in_ambient_contexts);
					return links.hasReportedStatementInAmbientContext;
				}
			} else {
				// We must be parented by a statement.  If so, there's no need
				// to report the error as our parent will have already done it.
				// debug.Assert(ast.IsStatement(node.Parent)) // !!! commented out in strada - fails if uncommented
			}
		}
		return false;
	}

	static function checkGrammarNumericLiteral(c:Checker, node:NumericLiteral):Void {
		final nodeText = Scanner.GetTextOfNode(node.AsNode());

		// Realism (size) checking
		// We should test against `getTextOfNode(node)` rather than `node.text`, because `node.text` for large numeric literals can contain "."
		// e.g. `node.text` for numeric literal `1100000000000000000000` is `1.1e21`.
		final isFractional = nodeText.indexOf(".") >= 0;
		final isScientific = (node.TokenFlags & TokenFlagsScientific) != 0;

		// Scientific notation (e.g. 2e54 and 1e00000000010) can't be converted to bigint
		// Fractional numbers (e.g. 9000000000000000.001) are inherently imprecise anyway
		if (isFractional || isScientific) {
			return;
		}

		// Here `node` is guaranteed to be a numeric literal representing an integer.
		// We need to judge whether the integer `node` represents is <= 2 ** 53 - 1, which can be accomplished by comparing to `value` defined below because:
		// 1) when `node` represents an integer <= 2 ** 53 - 1, `node.text` is its exact string representation and thus `value` precisely represents the integer.
		// 2) otherwise, although `node.text` may be imprecise string representation, its mathematical value and consequently `value` cannot be less than 2 ** 53,
		//    thus the result of the predicate won't be affected.
		final value = Jsnum.FromString(node.Text);
		if (value <= Jsnum.MaxSafeInteger) {
			return;
		}

		c.addErrorOrSuggestion(false, Checker.createDiagnosticForNode(node.AsNode(), Diagnostics.Numeric_literals_with_absolute_values_equal_to_2_53_or_greater_are_too_large_to_be_represented_accurately_as_integers));
	}

	static function checkGrammarBigIntLiteral(c:Checker, node:BigIntLiteral):Bool {
		final literalType = Ast.IsLiteralTypeNode(node.Parent) || Ast.IsPrefixUnaryExpression(node.Parent) && Ast.IsLiteralTypeNode(node.Parent.Parent);
		if (!literalType) {
			// Don't error on BigInt literals in ambient contexts
			if ((node.Flags & NodeFlagsAmbient) == 0 && c.languageVersion < ScriptTargetES2020) {
				if (c.grammarErrorOnNode(node.AsNode(), Diagnostics.BigInt_literals_are_not_available_when_targeting_lower_than_ES2020)) {
					return true;
				}
			}
		}
		return false;
	}

	static function checkGrammarImportClause(c:Checker, node:ImportClause):Bool {
		switch (node.PhaseModifier) {
			case KindTypeKeyword:
				if ((node.Flags & NodeFlagsJSDoc) == 0 && node.Name() != null && node.NamedBindings != null) {
					return c.grammarErrorOnNode(node.AsNode(), Diagnostics.A_type_only_import_can_specify_a_default_import_or_named_bindings_but_not_both);
				}
				if (node.NamedBindings != null && node.NamedBindings.Kind == KindNamedImports) {
					return c.checkGrammarTypeOnlyNamedImportsOrExports(node.NamedBindings);
				}
			case KindDeferKeyword:
				if (node.Name() != null) {
					return c.grammarErrorOnNode(node.AsNode(), Diagnostics.Default_imports_are_not_allowed_in_a_deferred_import);
				}
				if (node.NamedBindings != null && node.NamedBindings.Kind == KindNamedImports) {
					return c.grammarErrorOnNode(node.AsNode(), Diagnostics.Named_imports_are_not_allowed_in_a_deferred_import);
				}
				if (c.moduleKind != ModuleKindESNext && c.moduleKind != ModuleKindPreserve) {
					return c.grammarErrorOnNode(node.AsNode(), Diagnostics.Deferred_imports_are_only_supported_when_the_module_flag_is_set_to_esnext_or_preserve);
				}
			default:
		}
		return false;
	}

	static function checkGrammarTypeOnlyNamedImportsOrExports(c:Checker, namedBindings:Node):Bool {
		final nodeList = namedBindings.ElementList();
		for (specifier in rangeOf(nodeList.Nodes)) {
			var specifierIsTypeOnly = false;
			var message:Message = null;
			if (specifier.Kind == KindImportSpecifier) {
				specifierIsTypeOnly = specifier.IsTypeOnly();
				message = Diagnostics.The_type_modifier_cannot_be_used_on_a_named_import_when_import_type_is_used_on_its_import_statement;
			} else {
				specifierIsTypeOnly = specifier.IsTypeOnly();
				message = Diagnostics.The_type_modifier_cannot_be_used_on_a_named_export_when_export_type_is_used_on_its_export_statement;
			}

			if (specifierIsTypeOnly) {
				return c.grammarErrorOnFirstToken(specifier, message);
			}
		}

		return false;
	}

	static function checkGrammarImportCallExpression(c:Checker, node:Node):Bool {
		if (c.compilerOptions.VerbatimModuleSyntax == TSTrue && c.moduleKind == ModuleKindCommonJS) {
			return c.grammarErrorOnNode(node, Checker.getVerbatimModuleSyntaxErrorMessage(node));
		}

		if (node.Expression().Kind == KindMetaProperty) {
			if (c.moduleKind != ModuleKindESNext && c.moduleKind != ModuleKindPreserve) {
				return c.grammarErrorOnNode(node, Diagnostics.Deferred_imports_are_only_supported_when_the_module_flag_is_set_to_esnext_or_preserve);
			}
		} else if (c.moduleKind == ModuleKindES2015) {
			return c.grammarErrorOnNode(node, Diagnostics.Dynamic_imports_are_only_supported_when_the_module_flag_is_set_to_es2020_es2022_esnext_commonjs_amd_system_umd_node16_node18_node20_or_nodenext);
		}

		final nodeAsCall = node.AsCallExpression();
		if (nodeAsCall.TypeArguments != null) {
			return c.grammarErrorOnNode(node, Diagnostics.This_use_of_import_is_invalid_import_calls_can_be_written_but_they_must_have_parentheses_and_cannot_have_type_arguments);
		}

		final nodeArguments = nodeAsCall.Arguments;
		final argumentNodes = nodeArguments.Nodes;
		if (!(ModuleKindNode16 <= c.moduleKind && c.moduleKind <= ModuleKindNodeNext) && c.moduleKind != ModuleKindESNext && c.moduleKind != ModuleKindPreserve) {
			// We are allowed trailing comma after proposal-import-assertions.
			c.checkGrammarForDisallowedTrailingComma(nodeArguments, Diagnostics.Trailing_comma_not_allowed);

			if (Core.len(argumentNodes) > 1) {
				final importAttributesArgument = argumentNodes[1];
				return c.grammarErrorOnNode(importAttributesArgument, Diagnostics.Dynamic_imports_only_support_a_second_argument_when_the_module_option_is_set_to_esnext_node16_node18_node20_nodenext_or_preserve);
			}
		}

		if (Core.len(argumentNodes) == 0 || argumentNodes.length > 2) {
			return c.grammarErrorOnNode(node, Diagnostics.Dynamic_imports_can_only_accept_a_module_specifier_and_an_optional_set_of_attributes_as_arguments);
		}

		// see: parseArgumentOrArrayLiteralElement...we use this function which parse arguments of callExpression to parse specifier for dynamic import.
		// parseArgumentOrArrayLiteralElement allows spread element to be in an argument list which is not allowed as specifier in dynamic import.
		final spreadElement = Core.Find(argumentNodes, fn_IsSpreadElement);
		if (spreadElement != null) {
			return c.grammarErrorOnNode(spreadElement, Diagnostics.Argument_of_dynamic_import_cannot_be_spread_element);
		}
		return false;
	}

	// --- private helpers (PORT) ---

	// PORT: Go `range` over a possibly-nil slice.
	static inline function rangeOf<T>(s:Array<T>):Array<T> {
		return s != null ? s : [];
	}

	// PORT: *ast.SourceFile passed where Go converts it to ast.HasFileName (structural interface);
	// Haxe uses the cached adapter of modulespecifiers (as in CheckerPart2).
	static inline function hasFileName(file:SourceFile):HasFileName {
		return ts.modulespecifiers.Types.SourceFileAdapter.Of(file);
	}

	// PORT: method values created once (PORTING.md §7a).
	static final fn_IsModifier:(Node) -> Bool = n -> Ast.IsModifier(n);
	static final fn_IsDecorator:(Node) -> Bool = n -> Ast.IsDecorator(n);
	static final fn_IsSpreadElement:(Node) -> Bool = n -> Ast.IsSpreadElement(n);
}
