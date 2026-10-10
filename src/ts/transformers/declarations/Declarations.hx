package ts.transformers.declarations;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/declarations/Declarations.hx (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Package class: package-level funcs, vars and consts of internal/transformers/declarations (all files).
@:allow(ts.transformers.declarations)
class Declarations {

	// --- diagnostics.go ---

	static function wrapSimpleDiagnosticSelector(node:Node, selector:(node:Node, symbolAccessibilityResult:SymbolAccessibilityResult) -> Message):GetSymbolAccessibilityDiagnostic {
		return function(symbolAccessibilityResult:SymbolAccessibilityResult):SymbolAccessibilityDiagnostic {
			final diagnosticMessage = selector(node, symbolAccessibilityResult);
			if (diagnosticMessage == null) {
				return null;
			}
			final d = new SymbolAccessibilityDiagnostic();
			d.errorNode = node;
			d.diagnosticMessage = diagnosticMessage;
			d.typeName = Ast.GetNameOfDeclaration(node);
			return d;
		};
	}

	static function wrapNamedDiagnosticSelector(node:Node, selector:(node:Node, symbolAccessibilityResult:SymbolAccessibilityResult) -> Message):GetSymbolAccessibilityDiagnostic {
		return function(symbolAccessibilityResult:SymbolAccessibilityResult):SymbolAccessibilityDiagnostic {
			final diagnosticMessage = selector(node, symbolAccessibilityResult);
			if (diagnosticMessage == null) {
				return null;
			}
			final name = Ast.GetNameOfDeclaration(node);
			final d = new SymbolAccessibilityDiagnostic();
			d.errorNode = name;
			d.diagnosticMessage = diagnosticMessage;
			d.typeName = name;
			return d;
		};
	}

	static function wrapFallbackErrorDiagnosticSelector(node:Node, selector:(node:Node, symbolAccessibilityResult:SymbolAccessibilityResult) -> Message):GetSymbolAccessibilityDiagnostic {
		return function(symbolAccessibilityResult:SymbolAccessibilityResult):SymbolAccessibilityDiagnostic {
			final diagnosticMessage = selector(node, symbolAccessibilityResult);
			if (diagnosticMessage == null) {
				return null;
			}
			var errorNode = Ast.GetNameOfDeclaration(node);
			if (errorNode == null) {
				errorNode = node;
			}
			final d = new SymbolAccessibilityDiagnostic();
			d.errorNode = errorNode;
			d.diagnosticMessage = diagnosticMessage;
			return d;
		};
	}

	static function selectDiagnosticBasedOnModuleName(symbolAccessibilityResult:SymbolAccessibilityResult, moduleNotNameable:Message, privateModule:Message, nonModule:Message):Message {
		if (symbolAccessibilityResult.ErrorModuleName.length > 0) {
			if (symbolAccessibilityResult.Accessibility == SymbolAccessibilityCannotBeNamed) {
				return moduleNotNameable;
			}
			return privateModule;
		}
		return nonModule;
	}

	static function selectDiagnosticBasedOnModuleNameNoNameCheck(symbolAccessibilityResult:SymbolAccessibilityResult, privateModule:Message, nonModule:Message):Message {
		if (symbolAccessibilityResult.ErrorModuleName.length > 0) {
			return privateModule;
		}
		return nonModule;
	}

	static function createGetSymbolAccessibilityDiagnosticForNodeName(node:Node):GetSymbolAccessibilityDiagnostic {
		if (Ast.IsSetAccessorDeclaration(node) || Ast.IsGetAccessorDeclaration(node)) {
			return wrapSimpleDiagnosticSelector(node, getAccessorNameVisibilityDiagnosticMessage);
		} else if (Ast.IsMethodDeclaration(node) || Ast.IsMethodSignatureDeclaration(node)) {
			return wrapSimpleDiagnosticSelector(node, getMethodNameVisibilityDiagnosticMessage);
		} else {
			return createGetSymbolAccessibilityDiagnosticForNode(node);
		}
	}

	static function getAccessorNameVisibilityDiagnosticMessage(node:Node, symbolAccessibilityResult:SymbolAccessibilityResult):Message {
		if (Ast.IsStatic(node)) {
			return selectDiagnosticBasedOnModuleName(
				symbolAccessibilityResult,
				Diagnostics.Public_static_property_0_of_exported_class_has_or_is_using_name_1_from_external_module_2_but_cannot_be_named,
				Diagnostics.Public_static_property_0_of_exported_class_has_or_is_using_name_1_from_private_module_2,
				Diagnostics.Public_static_property_0_of_exported_class_has_or_is_using_private_name_1
			);
		} else if (node.Parent.Kind == KindClassDeclaration) {
			return selectDiagnosticBasedOnModuleName(
				symbolAccessibilityResult,
				Diagnostics.Public_property_0_of_exported_class_has_or_is_using_name_1_from_external_module_2_but_cannot_be_named,
				Diagnostics.Public_property_0_of_exported_class_has_or_is_using_name_1_from_private_module_2,
				Diagnostics.Public_property_0_of_exported_class_has_or_is_using_private_name_1
			);
		} else {
			return selectDiagnosticBasedOnModuleNameNoNameCheck(
				symbolAccessibilityResult,
				Diagnostics.Property_0_of_exported_interface_has_or_is_using_name_1_from_private_module_2,
				Diagnostics.Property_0_of_exported_interface_has_or_is_using_private_name_1
			);
		}
	}

	static function getMethodNameVisibilityDiagnosticMessage(node:Node, symbolAccessibilityResult:SymbolAccessibilityResult):Message {
		if (Ast.IsStatic(node)) {
			return selectDiagnosticBasedOnModuleName(
				symbolAccessibilityResult,
				Diagnostics.Public_static_method_0_of_exported_class_has_or_is_using_name_1_from_external_module_2_but_cannot_be_named,
				Diagnostics.Public_static_method_0_of_exported_class_has_or_is_using_name_1_from_private_module_2,
				Diagnostics.Public_static_method_0_of_exported_class_has_or_is_using_private_name_1
			);
		} else if (node.Parent.Kind == KindClassDeclaration) {
			return selectDiagnosticBasedOnModuleName(
				symbolAccessibilityResult,
				Diagnostics.Public_method_0_of_exported_class_has_or_is_using_name_1_from_external_module_2_but_cannot_be_named,
				Diagnostics.Public_method_0_of_exported_class_has_or_is_using_name_1_from_private_module_2,
				Diagnostics.Public_method_0_of_exported_class_has_or_is_using_private_name_1
			);
		} else {
			return selectDiagnosticBasedOnModuleNameNoNameCheck(
				symbolAccessibilityResult,
				Diagnostics.Method_0_of_exported_interface_has_or_is_using_name_1_from_private_module_2,
				Diagnostics.Method_0_of_exported_interface_has_or_is_using_private_name_1
			);
		}
	}

	static function createGetSymbolAccessibilityDiagnosticForNode(node:Node):GetSymbolAccessibilityDiagnostic {
		if (Ast.IsVariableDeclaration(node) || Ast.IsPropertyDeclaration(node) || Ast.IsPropertySignatureDeclaration(node) || Ast.IsPropertyAccessExpression(node) || Ast.IsElementAccessExpression(node) || Ast.IsBinaryExpression(node) || Ast.IsBindingElement(node) || Ast.IsConstructorDeclaration(node)) {
			return wrapSimpleDiagnosticSelector(node, getVariableDeclarationTypeVisibilityDiagnosticMessage);
		} else if (Ast.IsSetAccessorDeclaration(node) || Ast.IsGetAccessorDeclaration(node)) {
			return wrapNamedDiagnosticSelector(node, getAccessorDeclarationTypeVisibilityDiagnosticMessage);
		} else if (Ast.IsConstructSignatureDeclaration(node) || Ast.IsCallSignatureDeclaration(node) || Ast.IsMethodDeclaration(node) || Ast.IsMethodSignatureDeclaration(node) || Ast.IsFunctionDeclaration(node) || Ast.IsIndexSignatureDeclaration(node)) {
			return wrapFallbackErrorDiagnosticSelector(node, getReturnTypeVisibilityDiagnosticMessage);
		} else if (Ast.IsParameterDeclaration(node)) {
			if (Ast.IsParameterPropertyDeclaration(node, node.Parent) && Ast.HasSyntacticModifier(node.Parent, ModifierFlagsPrivate)) {
				return wrapSimpleDiagnosticSelector(node, getVariableDeclarationTypeVisibilityDiagnosticMessage);
			}
			return wrapSimpleDiagnosticSelector(node, getParameterDeclarationTypeVisibilityDiagnosticMessage);
		} else if (Ast.IsTypeParameterDeclaration(node)) {
			return wrapSimpleDiagnosticSelector(node, getTypeParameterConstraintVisibilityDiagnosticMessage);
		} else if (Ast.IsExpressionWithTypeArguments(node)) {
			// unique node selection behavior, inline closure
			return function(symbolAccessibilityResult:SymbolAccessibilityResult):SymbolAccessibilityDiagnostic {
				var diagnosticMessage:Message = null;
				// Heritage clause is written by user so it can always be named
				if (Ast.IsClassDeclaration(node.Parent.Parent)) {
					// Class or Interface implemented/extended is inaccessible
					if (Ast.IsHeritageClause(node.Parent) && node.Parent.AsHeritageClause().Token == KindImplementsKeyword) {
						diagnosticMessage = Diagnostics.Implements_clause_of_exported_class_0_has_or_is_using_private_name_1;
					} else {
						if (node.Parent.Parent.Name() != null) {
							diagnosticMessage = Diagnostics.X_extends_clause_of_exported_class_0_has_or_is_using_private_name_1;
						} else {
							diagnosticMessage = Diagnostics.X_extends_clause_of_exported_class_has_or_is_using_private_name_0;
						}
					}
				} else {
					// interface is inaccessible
					diagnosticMessage = Diagnostics.X_extends_clause_of_exported_interface_0_has_or_is_using_private_name_1;
				}

				final d = new SymbolAccessibilityDiagnostic();
				d.diagnosticMessage = diagnosticMessage;
				d.errorNode = node;
				d.typeName = Ast.GetNameOfDeclaration(node.Parent.Parent);
				return d;
			};
		} else if (Ast.IsImportEqualsDeclaration(node)) {
			return wrapSimpleDiagnosticSelector(node, function(_:Node, _:SymbolAccessibilityResult):Message {
				return Diagnostics.Import_declaration_0_is_using_private_name_1;
			});
		} else if (Ast.IsTypeAliasDeclaration(node) || Ast.IsJSTypeAliasDeclaration(node)) {
			// unique node selection behavior, inline closure
			return function(symbolAccessibilityResult:SymbolAccessibilityResult):SymbolAccessibilityDiagnostic {
				final diagnosticMessage = selectDiagnosticBasedOnModuleNameNoNameCheck(
					symbolAccessibilityResult,
					Diagnostics.Exported_type_alias_0_has_or_is_using_private_name_1_from_module_2,
					Diagnostics.Exported_type_alias_0_has_or_is_using_private_name_1
				);
				final errorNode = node.Type();
				final typeName = node.Name();
				final d = new SymbolAccessibilityDiagnostic();
				d.errorNode = errorNode;
				d.diagnosticMessage = diagnosticMessage;
				d.typeName = typeName;
				return d;
			};
		} else if (Ast.IsCallExpression(node)) {
			// JS object.defineProperty call
			// unique node selection behavior, inline closure
			return function(symbolAccessibilityResult:SymbolAccessibilityResult):SymbolAccessibilityDiagnostic {
				final diagnosticMessage = selectDiagnosticBasedOnModuleName(
					symbolAccessibilityResult,
					Diagnostics.Exported_variable_0_has_or_is_using_name_1_from_external_module_2_but_cannot_be_named,
					Diagnostics.Exported_variable_0_has_or_is_using_name_1_from_private_module_2,
					Diagnostics.Exported_variable_0_has_or_is_using_private_name_1
				);
				final errorNode = node.Arguments()[1];
				final typeName = node.Arguments()[1];
				final d = new SymbolAccessibilityDiagnostic();
				d.errorNode = errorNode;
				d.diagnosticMessage = diagnosticMessage;
				d.typeName = typeName;
				return d;
			};
		} else {
			throw "Attempted to set a declaration diagnostic context for unhandled node kind: " + node.Kind.String();
		}
	}

	static function getVariableDeclarationTypeVisibilityDiagnosticMessage(node:Node, symbolAccessibilityResult:SymbolAccessibilityResult):Message {
		if (node.Kind == KindVariableDeclaration || node.Kind == KindBindingElement) {
			return selectDiagnosticBasedOnModuleName(
				symbolAccessibilityResult,
				Diagnostics.Exported_variable_0_has_or_is_using_name_1_from_external_module_2_but_cannot_be_named,
				Diagnostics.Exported_variable_0_has_or_is_using_name_1_from_private_module_2,
				Diagnostics.Exported_variable_0_has_or_is_using_private_name_1
			);

			// This check is to ensure we don't report error on constructor parameter property as that error would be reported during parameter emit
			// The only exception here is if the constructor was marked as private. we are not emitting the constructor parameters at all.
		} else if (node.Kind == KindPropertyDeclaration || node.Kind == KindPropertyAccessExpression || node.Kind == KindElementAccessExpression || node.Kind == KindBinaryExpression || node.Kind == KindPropertySignature ||
			(node.Kind == KindParameter && Ast.HasSyntacticModifier(node.Parent, ModifierFlagsPrivate))) {
			// TODO(jfreeman): Deal with computed properties in error reporting.
			if (Ast.IsStatic(node)) {
				return selectDiagnosticBasedOnModuleName(
					symbolAccessibilityResult,
					Diagnostics.Public_static_property_0_of_exported_class_has_or_is_using_name_1_from_external_module_2_but_cannot_be_named,
					Diagnostics.Public_static_property_0_of_exported_class_has_or_is_using_name_1_from_private_module_2,
					Diagnostics.Public_static_property_0_of_exported_class_has_or_is_using_private_name_1
				);
			} else if (node.Parent.Kind == KindClassDeclaration || node.Kind == KindParameter) {
				return selectDiagnosticBasedOnModuleName(
					symbolAccessibilityResult,
					Diagnostics.Public_property_0_of_exported_class_has_or_is_using_name_1_from_external_module_2_but_cannot_be_named,
					Diagnostics.Public_property_0_of_exported_class_has_or_is_using_name_1_from_private_module_2,
					Diagnostics.Public_property_0_of_exported_class_has_or_is_using_private_name_1
				);
			} else {
				// Interfaces cannot have types that cannot be named
				return selectDiagnosticBasedOnModuleNameNoNameCheck(
					symbolAccessibilityResult,
					Diagnostics.Property_0_of_exported_interface_has_or_is_using_name_1_from_private_module_2,
					Diagnostics.Property_0_of_exported_interface_has_or_is_using_private_name_1
				);
			}
		}
		return null; // TODO: Audit behavior - should this panic? potentially silent error state in strada
	}

	static function getAccessorDeclarationTypeVisibilityDiagnosticMessage(node:Node, symbolAccessibilityResult:SymbolAccessibilityResult):Message {
		if (node.Kind == KindSetAccessor) {
			// Getters can infer the return type from the returned expression, but setters cannot, so the
			// "_from_external_module_1_but_cannot_be_named" case cannot occur.
			if (Ast.IsStatic(node)) {
				return selectDiagnosticBasedOnModuleNameNoNameCheck(
					symbolAccessibilityResult,
					Diagnostics.Parameter_type_of_public_static_setter_0_from_exported_class_has_or_is_using_name_1_from_private_module_2,
					Diagnostics.Parameter_type_of_public_static_setter_0_from_exported_class_has_or_is_using_private_name_1
				);
			} else {
				return selectDiagnosticBasedOnModuleNameNoNameCheck(
					symbolAccessibilityResult,
					Diagnostics.Parameter_type_of_public_setter_0_from_exported_class_has_or_is_using_name_1_from_private_module_2,
					Diagnostics.Parameter_type_of_public_setter_0_from_exported_class_has_or_is_using_private_name_1
				);
			}
		} else {
			if (Ast.IsStatic(node)) {
				return selectDiagnosticBasedOnModuleName(
					symbolAccessibilityResult,
					Diagnostics.Return_type_of_public_static_getter_0_from_exported_class_has_or_is_using_name_1_from_external_module_2_but_cannot_be_named,
					Diagnostics.Return_type_of_public_static_getter_0_from_exported_class_has_or_is_using_name_1_from_private_module_2,
					Diagnostics.Return_type_of_public_static_getter_0_from_exported_class_has_or_is_using_private_name_1
				);
			} else {
				return selectDiagnosticBasedOnModuleName(
					symbolAccessibilityResult,
					Diagnostics.Return_type_of_public_getter_0_from_exported_class_has_or_is_using_name_1_from_external_module_2_but_cannot_be_named,
					Diagnostics.Return_type_of_public_getter_0_from_exported_class_has_or_is_using_name_1_from_private_module_2,
					Diagnostics.Return_type_of_public_getter_0_from_exported_class_has_or_is_using_private_name_1
				);
			}
		}
	}

	static function getReturnTypeVisibilityDiagnosticMessage(node:Node, symbolAccessibilityResult:SymbolAccessibilityResult):Message {
		switch (node.Kind) {
			case KindConstructSignature:
				// Interfaces cannot have return types that cannot be named
				return selectDiagnosticBasedOnModuleNameNoNameCheck(
					symbolAccessibilityResult,
					Diagnostics.Return_type_of_constructor_signature_from_exported_interface_has_or_is_using_name_0_from_private_module_1,
					Diagnostics.Return_type_of_constructor_signature_from_exported_interface_has_or_is_using_private_name_0
				);
			case KindCallSignature:
				// Interfaces cannot have return types that cannot be named
				return selectDiagnosticBasedOnModuleNameNoNameCheck(
					symbolAccessibilityResult,
					Diagnostics.Return_type_of_call_signature_from_exported_interface_has_or_is_using_name_0_from_private_module_1,
					Diagnostics.Return_type_of_call_signature_from_exported_interface_has_or_is_using_private_name_0
				);
			case KindIndexSignature:
				// Interfaces cannot have return types that cannot be named
				return selectDiagnosticBasedOnModuleNameNoNameCheck(
					symbolAccessibilityResult,
					Diagnostics.Return_type_of_index_signature_from_exported_interface_has_or_is_using_name_0_from_private_module_1,
					Diagnostics.Return_type_of_index_signature_from_exported_interface_has_or_is_using_private_name_0
				);

			case KindMethodDeclaration, KindMethodSignature:
				if (Ast.IsStatic(node)) {
					return selectDiagnosticBasedOnModuleName(
						symbolAccessibilityResult,
						Diagnostics.Return_type_of_public_static_method_from_exported_class_has_or_is_using_name_0_from_external_module_1_but_cannot_be_named,
						Diagnostics.Return_type_of_public_static_method_from_exported_class_has_or_is_using_name_0_from_private_module_1,
						Diagnostics.Return_type_of_public_static_method_from_exported_class_has_or_is_using_private_name_0
					);
				} else if (node.Parent.Kind == KindClassDeclaration) {
					return selectDiagnosticBasedOnModuleName(
						symbolAccessibilityResult,
						Diagnostics.Return_type_of_public_method_from_exported_class_has_or_is_using_name_0_from_external_module_1_but_cannot_be_named,
						Diagnostics.Return_type_of_public_method_from_exported_class_has_or_is_using_name_0_from_private_module_1,
						Diagnostics.Return_type_of_public_method_from_exported_class_has_or_is_using_private_name_0
					);
				} else {
					// Interfaces cannot have return types that cannot be named
					return selectDiagnosticBasedOnModuleNameNoNameCheck(
						symbolAccessibilityResult,
						Diagnostics.Return_type_of_method_from_exported_interface_has_or_is_using_name_0_from_private_module_1,
						Diagnostics.Return_type_of_method_from_exported_interface_has_or_is_using_private_name_0
					);
				}
			case KindFunctionDeclaration:
				return selectDiagnosticBasedOnModuleName(
					symbolAccessibilityResult,
					Diagnostics.Return_type_of_exported_function_has_or_is_using_name_0_from_external_module_1_but_cannot_be_named,
					Diagnostics.Return_type_of_exported_function_has_or_is_using_name_0_from_private_module_1,
					Diagnostics.Return_type_of_exported_function_has_or_is_using_private_name_0
				);
			default:
				throw "This is unknown kind for signature: " + node.Kind.String();
		}
	}

	static function getParameterDeclarationTypeVisibilityDiagnosticMessage(node:Node, symbolAccessibilityResult:SymbolAccessibilityResult):Message {
		switch (node.Parent.Kind) {
			case KindConstructor:
				return selectDiagnosticBasedOnModuleName(
					symbolAccessibilityResult,
					Diagnostics.Parameter_0_of_constructor_from_exported_class_has_or_is_using_name_1_from_external_module_2_but_cannot_be_named,
					Diagnostics.Parameter_0_of_constructor_from_exported_class_has_or_is_using_name_1_from_private_module_2,
					Diagnostics.Parameter_0_of_constructor_from_exported_class_has_or_is_using_private_name_1
				);

			case KindConstructSignature, KindConstructorType:
				// Interfaces cannot have parameter types that cannot be named
				return selectDiagnosticBasedOnModuleNameNoNameCheck(
					symbolAccessibilityResult,
					Diagnostics.Parameter_0_of_constructor_signature_from_exported_interface_has_or_is_using_name_1_from_private_module_2,
					Diagnostics.Parameter_0_of_constructor_signature_from_exported_interface_has_or_is_using_private_name_1
				);

			case KindCallSignature:
				// Interfaces cannot have parameter types that cannot be named
				return selectDiagnosticBasedOnModuleNameNoNameCheck(
					symbolAccessibilityResult,
					Diagnostics.Parameter_0_of_call_signature_from_exported_interface_has_or_is_using_name_1_from_private_module_2,
					Diagnostics.Parameter_0_of_call_signature_from_exported_interface_has_or_is_using_private_name_1
				);

			case KindIndexSignature:
				// Interfaces cannot have parameter types that cannot be named
				return selectDiagnosticBasedOnModuleNameNoNameCheck(
					symbolAccessibilityResult,
					Diagnostics.Parameter_0_of_index_signature_from_exported_interface_has_or_is_using_name_1_from_private_module_2,
					Diagnostics.Parameter_0_of_index_signature_from_exported_interface_has_or_is_using_private_name_1
				);

			case KindMethodDeclaration, KindMethodSignature:
				if (Ast.IsStatic(node.Parent)) {
					return selectDiagnosticBasedOnModuleName(
						symbolAccessibilityResult,
						Diagnostics.Parameter_0_of_public_static_method_from_exported_class_has_or_is_using_name_1_from_external_module_2_but_cannot_be_named,
						Diagnostics.Parameter_0_of_public_static_method_from_exported_class_has_or_is_using_name_1_from_private_module_2,
						Diagnostics.Parameter_0_of_public_static_method_from_exported_class_has_or_is_using_private_name_1
					);
				} else if (node.Parent.Parent.Kind == KindClassDeclaration) {
					return selectDiagnosticBasedOnModuleName(
						symbolAccessibilityResult,
						Diagnostics.Parameter_0_of_public_method_from_exported_class_has_or_is_using_name_1_from_external_module_2_but_cannot_be_named,
						Diagnostics.Parameter_0_of_public_method_from_exported_class_has_or_is_using_name_1_from_private_module_2,
						Diagnostics.Parameter_0_of_public_method_from_exported_class_has_or_is_using_private_name_1
					);
				} else {
					// Interfaces cannot have parameter types that cannot be named
					return selectDiagnosticBasedOnModuleNameNoNameCheck(
						symbolAccessibilityResult,
						Diagnostics.Parameter_0_of_method_from_exported_interface_has_or_is_using_name_1_from_private_module_2,
						Diagnostics.Parameter_0_of_method_from_exported_interface_has_or_is_using_private_name_1
					);
				}

			case KindFunctionDeclaration, KindFunctionType:
				return selectDiagnosticBasedOnModuleName(
					symbolAccessibilityResult,
					Diagnostics.Parameter_0_of_exported_function_has_or_is_using_name_1_from_external_module_2_but_cannot_be_named,
					Diagnostics.Parameter_0_of_exported_function_has_or_is_using_name_1_from_private_module_2,
					Diagnostics.Parameter_0_of_exported_function_has_or_is_using_private_name_1
				);
			case KindSetAccessor, KindGetAccessor:
				return selectDiagnosticBasedOnModuleName(
					symbolAccessibilityResult,
					Diagnostics.Parameter_0_of_accessor_has_or_is_using_name_1_from_external_module_2_but_cannot_be_named,
					Diagnostics.Parameter_0_of_accessor_has_or_is_using_name_1_from_private_module_2,
					Diagnostics.Parameter_0_of_accessor_has_or_is_using_private_name_1
				);
			default:
				throw "Unknown parent for parameter: " + node.Parent.Kind.String();
		}
	}

	static function getTypeParameterConstraintVisibilityDiagnosticMessage(node:Node, symbolAccessibilityResult:SymbolAccessibilityResult):Message {
		// Type parameter constraints are named by user so we should always be able to name it
		switch (node.Parent.Kind) {
			case KindClassDeclaration:
				return Diagnostics.Type_parameter_0_of_exported_class_has_or_is_using_private_name_1;
			case KindInterfaceDeclaration:
				return Diagnostics.Type_parameter_0_of_exported_interface_has_or_is_using_private_name_1;
			case KindMappedType:
				return Diagnostics.Type_parameter_0_of_exported_mapped_object_type_is_using_private_name_1;
			case KindConstructorType, KindConstructSignature:
				return Diagnostics.Type_parameter_0_of_constructor_signature_from_exported_interface_has_or_is_using_private_name_1;
			case KindCallSignature:
				return Diagnostics.Type_parameter_0_of_call_signature_from_exported_interface_has_or_is_using_private_name_1;
			case KindMethodDeclaration, KindMethodSignature:
				if (Ast.IsStatic(node.Parent)) {
					return Diagnostics.Type_parameter_0_of_public_static_method_from_exported_class_has_or_is_using_private_name_1;
				} else if (node.Parent.Parent.Kind == KindClassDeclaration) {
					return Diagnostics.Type_parameter_0_of_public_method_from_exported_class_has_or_is_using_private_name_1;
				} else {
					return Diagnostics.Type_parameter_0_of_method_from_exported_interface_has_or_is_using_private_name_1;
				}
			case KindFunctionType, KindFunctionDeclaration:
				return Diagnostics.Type_parameter_0_of_exported_function_has_or_is_using_private_name_1;

			case KindInferType:
				return Diagnostics.Extends_clause_for_inferred_type_0_has_or_is_using_private_name_1;

			case KindTypeAliasDeclaration, KindJSTypeAliasDeclaration:
				return Diagnostics.Type_parameter_0_of_exported_type_alias_has_or_is_using_private_name_1;

			default:
				throw "This is unknown parent for type parameter: " + node.Parent.Kind.String();
		}
	}

	static function getRelatedSuggestionByDeclarationKind(kind:Kind):Message {
		switch (kind) {
			case KindArrowFunction:
				return Diagnostics.Add_a_return_type_to_the_function_expression;
			case KindFunctionExpression:
				return Diagnostics.Add_a_return_type_to_the_function_expression;
			case KindMethodDeclaration:
				return Diagnostics.Add_a_return_type_to_the_method;
			case KindGetAccessor:
				return Diagnostics.Add_a_return_type_to_the_get_accessor_declaration;
			case KindSetAccessor:
				return Diagnostics.Add_a_type_to_parameter_of_the_set_accessor_declaration;
			case KindFunctionDeclaration:
				return Diagnostics.Add_a_return_type_to_the_function_declaration;
			case KindConstructSignature:
				return Diagnostics.Add_a_return_type_to_the_function_declaration;
			case KindParameter:
				return Diagnostics.Add_a_type_annotation_to_the_parameter_0;
			case KindVariableDeclaration:
				return Diagnostics.Add_a_type_annotation_to_the_variable_0;
			case KindPropertyDeclaration:
				return Diagnostics.Add_a_type_annotation_to_the_property_0;
			case KindPropertySignature:
				return Diagnostics.Add_a_type_annotation_to_the_property_0;
			case KindExportAssignment:
				return Diagnostics.Move_the_expression_in_default_export_to_a_variable_and_add_a_type_annotation_to_it;
			default:
				return null;
		}
	}

	static function getErrorByDeclarationKind(kind:Kind):Message {
		switch (kind) {
			case KindFunctionExpression:
				return Diagnostics.Function_must_have_an_explicit_return_type_annotation_with_isolatedDeclarations;
			case KindFunctionDeclaration:
				return Diagnostics.Function_must_have_an_explicit_return_type_annotation_with_isolatedDeclarations;
			case KindArrowFunction:
				return Diagnostics.Function_must_have_an_explicit_return_type_annotation_with_isolatedDeclarations;
			case KindMethodDeclaration:
				return Diagnostics.Method_must_have_an_explicit_return_type_annotation_with_isolatedDeclarations;
			case KindConstructSignature:
				return Diagnostics.Method_must_have_an_explicit_return_type_annotation_with_isolatedDeclarations;
			case KindGetAccessor:
				return Diagnostics.At_least_one_accessor_must_have_an_explicit_type_annotation_with_isolatedDeclarations;
			case KindSetAccessor:
				return Diagnostics.At_least_one_accessor_must_have_an_explicit_type_annotation_with_isolatedDeclarations;
			case KindParameter:
				return Diagnostics.Parameter_must_have_an_explicit_type_annotation_with_isolatedDeclarations;
			case KindVariableDeclaration:
				return Diagnostics.Variable_must_have_an_explicit_type_annotation_with_isolatedDeclarations;
			case KindPropertyDeclaration:
				return Diagnostics.Property_must_have_an_explicit_type_annotation_with_isolatedDeclarations;
			case KindPropertySignature:
				return Diagnostics.Property_must_have_an_explicit_type_annotation_with_isolatedDeclarations;
			case KindComputedPropertyName:
				return Diagnostics.Computed_property_names_on_class_or_object_literals_cannot_be_inferred_with_isolatedDeclarations;
			case KindSpreadAssignment:
				return Diagnostics.Objects_that_contain_spread_assignments_can_t_be_inferred_with_isolatedDeclarations;
			case KindShorthandPropertyAssignment:
				return Diagnostics.Objects_that_contain_shorthand_properties_can_t_be_inferred_with_isolatedDeclarations;
			case KindArrayLiteralExpression:
				return Diagnostics.Only_const_arrays_can_be_inferred_with_isolatedDeclarations;
			case KindExportAssignment:
				return Diagnostics.Default_exports_can_t_be_inferred_with_isolatedDeclarations;
			case KindSpreadElement:
				return Diagnostics.Arrays_with_spread_elements_can_t_inferred_with_isolatedDeclarations;
			default:
				return null;
		}
	}

	static function isDeclarationEnoughForErrors(node:Node):Bool {
		return Ast.IsExportAssignment(node) || Ast.IsStatement(node) || Ast.IsVariableDeclaration(node) || Ast.IsPropertyDeclaration(node) || Ast.IsParameterDeclaration(node);
	}

	static function isFunctionLikeAndNotConstructor(node:Node):Bool {
		return Ast.IsFunctionLikeDeclaration(node) && !Ast.IsConstructorDeclaration(node);
	}

	static function findNearestDeclaration(node:Node):Node {
		final result = Ast.FindAncestor(node, isDeclarationEnoughForErrors);
		if (result == null) {
			return null;
		}
		if (Ast.IsExportAssignment(result)) {
			return result;
		}
		if (Ast.IsReturnStatement(result)) {
			return Ast.FindAncestor(result, isFunctionLikeAndNotConstructor);
		}
		if (Ast.IsStatement(result)) {
			return null;
		}
		return result;
	}

	static function createEntityInTypeNodeError(node:Node):Diagnostic {
		final diag = createDiagnosticForNode(node, Diagnostics.Type_containing_private_name_0_can_t_be_used_with_isolatedDeclarations, Scanner.GetTextOfNode(node));
		addParentDeclarationRelatedInfo(node, diag);
		return diag;
	}

	static function addParentDeclarationRelatedInfo(node:Node, diag:Diagnostic):Void {
		final parentDeclaration = findNearestDeclaration(node);
		if (parentDeclaration == null) {
			return;
		}
		var targetStr = "";
		if (!Ast.IsExportAssignment(parentDeclaration) && parentDeclaration.Name() != null) {
			targetStr = Scanner.GetTextOfNode(parentDeclaration.Name());
		}
		diag.AddRelatedInfo(createDiagnosticForNode(parentDeclaration, getRelatedSuggestionByDeclarationKind(parentDeclaration.Kind), targetStr));
	}

	static function createAccessorTypeError(node:Node):Diagnostic {
		final allDeclarations = Ast.GetAllAccessorDeclarationsForDeclaration(node, node.Symbol().Declarations);
		final getAccessor = allDeclarations.GetAccessor;
		final setAccessor = allDeclarations.SetAccessor;
		var targetNode = node;
		if (Ast.IsSetAccessorDeclaration(node) && Core.len(node.Parameters()) > 0) {
			targetNode = node.Parameters()[0];
		}
		final diag = createDiagnosticForNode(targetNode, getErrorByDeclarationKind(node.Kind));
		if (setAccessor != null) {
			diag.AddRelatedInfo(createDiagnosticForNode(setAccessor.AsNode(), getRelatedSuggestionByDeclarationKind(setAccessor.Kind)));
		}
		if (getAccessor != null) {
			diag.AddRelatedInfo(createDiagnosticForNode(getAccessor.AsNode(), getRelatedSuggestionByDeclarationKind(getAccessor.Kind)));
		}
		return diag;
	}

	static function createObjectLiteralError(node:Node):Diagnostic {
		final diag = createDiagnosticForNode(node, getErrorByDeclarationKind(node.Kind));
		addParentDeclarationRelatedInfo(node, diag);
		return diag;
	}

	static function createArrayLiteralError(node:Node):Diagnostic {
		final diag = createDiagnosticForNode(node, getErrorByDeclarationKind(node.Kind));
		addParentDeclarationRelatedInfo(node, diag);
		return diag;
	}

	static function createReturnTypeError(node:Node):Diagnostic {
		final diag = createDiagnosticForNode(node, getErrorByDeclarationKind(node.Kind));
		addParentDeclarationRelatedInfo(node, diag);
		diag.AddRelatedInfo(createDiagnosticForNode(node, getRelatedSuggestionByDeclarationKind(node.Kind)));
		return diag;
	}

	static function createBindingElementError(node:Node):Diagnostic {
		return createDiagnosticForNode(node, Diagnostics.Binding_elements_can_t_be_exported_directly_with_isolatedDeclarations);
	}

	static function createVariableOrPropertyError(node:Node):Diagnostic {
		final diag = createDiagnosticForNode(node, getErrorByDeclarationKind(node.Kind));
		diag.AddRelatedInfo(createDiagnosticForNode(node, getRelatedSuggestionByDeclarationKind(node.Kind), Scanner.GetTextOfNode(node.Name())));
		return diag;
	}

	static function createExpressionError(node:Node):Diagnostic {
		return createExpressionErrorEx(node, null);
	}

	static function createClassExpressionError(node:Node):Diagnostic {
		return createExpressionErrorEx(node, Diagnostics.Inference_from_class_expressions_is_not_supported_with_isolatedDeclarations);
	}

	static function isParentForIDDIagnostic(node:Node):FindAncestorResult {
		if (Ast.IsExportAssignment(node)) {
			return FindAncestorTrue;
		}
		if (Ast.IsStatement(node)) {
			return FindAncestorQuit;
		}
		return Ast.ToFindAncestorResult(!Ast.IsParenthesizedExpression(node) && !Ast.IsAssertionExpression(node));
	}

	static function createExpressionErrorEx(node:Node, diagnosticMessage:Message):Diagnostic {
		final parentDeclaration = findNearestDeclaration(node);
		if (parentDeclaration == null) {
			if (diagnosticMessage == null) {
				diagnosticMessage = Diagnostics.Expression_type_can_t_be_inferred_with_isolatedDeclarations;
			}
			return createDiagnosticForNode(node, diagnosticMessage);
		}

		var targetStr = "";
		if (!Ast.IsExportAssignment(parentDeclaration) && parentDeclaration.Name() != null) {
			targetStr = Scanner.GetTextOfNode(parentDeclaration.Name());
		}
		final parent = Ast.FindAncestorOrQuit(node.Parent, isParentForIDDIagnostic);

		if (parentDeclaration == parent) {
			if (diagnosticMessage == null) {
				diagnosticMessage = getErrorByDeclarationKind(parentDeclaration.Kind);
			}
			final diag = createDiagnosticForNode(node, diagnosticMessage);
			diag.AddRelatedInfo(createDiagnosticForNode(parentDeclaration, getRelatedSuggestionByDeclarationKind(parentDeclaration.Kind), targetStr));
			return diag;
		}
		if (diagnosticMessage == null) {
			diagnosticMessage = Diagnostics.Expression_type_can_t_be_inferred_with_isolatedDeclarations;
		}
		final diag = createDiagnosticForNode(node, diagnosticMessage);
		diag.AddRelatedInfo(createDiagnosticForNode(parentDeclaration, getRelatedSuggestionByDeclarationKind(parentDeclaration.Kind), targetStr));
		diag.AddRelatedInfo(createDiagnosticForNode(node, Diagnostics.Add_satisfies_and_a_type_assertion_to_this_expression_satisfies_T_as_T_to_make_the_type_explicit));
		return diag;
	}

	static function createGetIsolatedDeclarationErrors(resolver:EmitResolver):(node:Node) -> Diagnostic {
		final createParameterError = function(node:Node):Diagnostic {
			if (Ast.IsSetAccessorDeclaration(node.Parent)) {
				return createAccessorTypeError(node.Parent);
			}
			final addUndefined = resolver.RequiresAddingImplicitUndefinedUnsafe(node, null, null); // skip checker lock - node builder will already have one
			if (!addUndefined && node.Initializer() != null) {
				return createExpressionError(node.Initializer());
			}
			var message = getErrorByDeclarationKind(node.Kind);
			if (addUndefined) {
				message = Diagnostics.Declaration_emit_for_this_parameter_requires_implicitly_adding_undefined_to_its_type_This_is_not_supported_with_isolatedDeclarations;
			}
			final diag = createDiagnosticForNode(node, message);
			final targetStr = Scanner.GetTextOfNode(node.Name());
			diag.AddRelatedInfo(createDiagnosticForNode(node, getRelatedSuggestionByDeclarationKind(node.Kind), targetStr));
			return diag;
		};

		return function(node:Node):Diagnostic {
			final heritageClause = Ast.FindAncestor(node, Ast.IsHeritageClause);
			if (heritageClause != null) {
				return createDiagnosticForNode(node, Diagnostics.Extends_clause_can_t_contain_an_expression_with_isolatedDeclarations);
			}
			if (Ast.IsPartOfTypeNode(node) || Ast.IsTypeQueryNode(node)) {
				return createEntityInTypeNodeError(node);
			}
			if (Ast.IsEntityName(node) || Ast.IsEntityNameExpression(node)) {
				return createEntityInTypeNodeError(node);
			}
			switch (node.Kind) {
				case KindGetAccessor, KindSetAccessor:
					return createAccessorTypeError(node);
				case KindComputedPropertyName, KindShorthandPropertyAssignment, KindSpreadAssignment:
					return createObjectLiteralError(node);
				case KindArrayLiteralExpression, KindSpreadElement:
					return createArrayLiteralError(node);
				case KindMethodDeclaration, KindConstructSignature, KindFunctionExpression, KindArrowFunction, KindFunctionDeclaration:
					return createReturnTypeError(node);
				case KindBindingElement:
					return createBindingElementError(node);
				case KindPropertyDeclaration, KindVariableDeclaration:
					return createVariableOrPropertyError(node);
				case KindParameter:
					return createParameterError(node);
				case KindPropertyAssignment:
					return createExpressionError(node.Initializer());
				case KindClassExpression:
					return createClassExpressionError(node);
				default:
					return createExpressionError(node);
			}
		};
	}

	// --- tracker.go ---

	static function createDiagnosticForNode(node:Node, message:Message, ...args:Any):Diagnostic {
		return Checker.NewDiagnosticForNode(node, message, ...args);
	}

	public static function NewSymbolTracker(host:DeclarationEmitHost, resolver:EmitResolver, state:SymbolTrackerSharedState):SymbolTrackerImpl {
		final tracker = new SymbolTrackerImpl();
		tracker.host = host;
		tracker.resolver = resolver;
		tracker.state = state;
		tracker.getIsolatedDeclarationError = createGetIsolatedDeclarationErrors(resolver);
		return tracker;
	}

	// --- transform.go ---

	static function getThisPropertyAssignmentKey(name:Node, node:Node, isStatic:Bool):ThisPropertyAssignmentKey {
		final isPrivate = Ast.IsPrivateIdentifier(name);
		if (name != null && !Ast.IsDynamicName(name)) {
			final r = Ast.TryGetTextOfPropertyName(name);
			if (r.ok) {
				final k = new ThisPropertyAssignmentKey();
				k.name = r.value;
				k.isStatic = isStatic;
				k.isPrivate = isPrivate;
				return k;
			}
		}
		final k = new ThisPropertyAssignmentKey();
		k.node = node;
		k.isStatic = isStatic;
		k.isPrivate = isPrivate;
		return k;
	}

	// TODO: Convert to transformers.TransformerFactory signature to allow more automatic composition with other transforms
	public static function NewDeclarationTransformer(host:DeclarationEmitHost, context:EmitContext, compilerOptions:CompilerOptions, declarationFilePath:std.String, declarationMapPath:std.String):DeclarationTransformer {
		final resolver = host.GetEmitResolver();
		final state = new SymbolTrackerSharedState();
		state.isolatedDeclarations = compilerOptions.IsolatedDeclarations.IsTrue();
		state.stripInternal = compilerOptions.StripInternal.IsTrue();
		state.resolver = resolver;
		final tracker = NewSymbolTracker(host, resolver, state);
		// TODO: Use new host GetOutputPathsFor method instead of passing in entrypoint paths (which will also better support bundled emit)
		final tx = new DeclarationTransformer();
		tx.host = host;
		tx.compilerOptions = compilerOptions;
		tx.tracker = tracker;
		tx.state = state;
		tx.resolver = resolver;
		tx.declarationFilePath = declarationFilePath;
		tx.declarationMapPath = declarationMapPath;
		tx.state.reportExpandoFunctionErrors = function(node:Node):Void {
			if (!tx.state.isolatedDeclarations) {
				return;
			}
			final props = resolver.GetPropertiesOfContainerFunction(node);
			if (props != null) {
				for (p in props) {
					if (Ast.IsExpandoPropertyDeclaration(p.ValueDeclaration)) {
						var errorTarget = p.ValueDeclaration;
						if (Ast.IsBinaryExpression(errorTarget)) {
							errorTarget = errorTarget.AsBinaryExpression().Left;
						}
						tx.state.addDiagnostic(createDiagnosticForNode(errorTarget,
							Diagnostics.Assigning_properties_to_functions_without_declaring_them_is_not_supported_with_isolatedDeclarations_Add_an_explicit_declaration_for_the_properties_assigned_to_this_function));
					}
				}
			}
		};
		tx.Transformer.NewTransformer(tx.visit, context);
		tx.bindingNameVisitor = tx.EmitContext().NewNodeVisitor(tx.visitBindingName);
		tx.expressionVisitor = tx.EmitContext().NewNodeVisitor(tx.visitNestedExpression);
		tx.exportStrippingVisitor = tx.EmitContext().NewNodeVisitor(tx.stripExportModifiers);
		tx.thisPropertyVisitor = tx.EmitContext().NewNodeVisitor(tx.visitThisPropertyAssignments);
		tx.cjsExportAssignmentVisitor = tx.EmitContext().NewNodeVisitor(tx.visitCJSExportAssignments);
		tx.declareStrippingVisitor = tx.EmitContext().NewNodeVisitor(tx.stripDeclareModifiers);
		return tx;
	}

	static function hasInternalAnnotation(commentRange:CommentRange, sourceFile:SourceFile):Bool {
		final comment = sourceFile.Text().substring(commentRange.Pos(), commentRange.End());
		return comment.indexOf("@internal") >= 0;
	}

	static final declarationEmitNodeBuilderFlags:Flags = cast 531469;

	static final declarationEmitInternalNodeBuilderFlags:InternalFlags = cast 8;

	static function throwDiagnostic(result:SymbolAccessibilityResult):SymbolAccessibilityDiagnostic {
		throw "Diagnostic emitted without context";
	}

	static function nodeOrSyntaxListChildren(node:Node):Array<Node> {
		if (Ast.IsSyntaxList(node)) {
			return node.AsSyntaxList().Children;
		}
		return [node];
	}

	static function flattenSyntaxLists(nodes:Array<Node>):Array<Node> {
		return Core.FlatMap(nodes, nodeOrSyntaxListChildren);
	}

	static function createEmptyExports(factory:NodeFactory):Node {
		return factory.NewExportDeclaration(null /*isTypeOnly*/, false, factory.NewNamedExports(factory.NewNodeList([])), null, null);
	}

	static function isCommonJSAliasExport(node:Node):Bool {
		if (Ast.IsBinaryExpression(node) && Ast.IsIdentifier(node.AsBinaryExpression().Right)) {
			final symbol = node.Symbol();
			if (symbol != null && Core.len(symbol.Declarations) == 1) {
				return true;
			}
		}
		return false;
	}

	static function isClassExtendingNull(node:Node):Bool {
		if (node == null) {
			return false;
		}
		final heritage = node.ClassLikeData().HeritageClauses;
		if (heritage == null) {
			return false;
		}
		if (Core.len(heritage.Nodes) > 1 || Core.len(heritage.Nodes) == 0) {
			return false;
		}
		for (expA in heritage.Nodes[0].AsHeritageClause().Types.Nodes) {
			final expr = expA.AsExpressionWithTypeArguments().Expression;
			if (expr != null && expr.Kind == KindNullKeyword) {
				return true;
			}
		}
		return false;
	}

	static function isNotDeclareModifier(mod:Modifier):Bool {
		return mod.Kind != KindDeclareKeyword;
	}

	static function extractExpandoHostParams(node:Node):Triple<TypeParameterList, ParameterList, TokenNode> {
		switch (node.Kind) {
			case KindFunctionExpression:
				final fn = node.AsFunctionExpression();
				return new Triple(fn.TypeParameters, fn.Parameters, fn.AsteriskToken);
			case KindArrowFunction:
				final fn = node.AsArrowFunction();
				return new Triple(fn.TypeParameters, fn.Parameters, fn.AsteriskToken);
			default:
				final fn = node.AsFunctionDeclaration();
				return new Triple(fn.TypeParameters, fn.Parameters, fn.AsteriskToken);
		}
	}

	// --- util.go ---

	static function needsScopeMarker(result:Node):Bool {
		return !Ast.IsAnyImportOrReExport(result) && !Ast.IsExportAssignment(result) && !Ast.HasSyntacticModifier(result, ModifierFlagsExport) && !Ast.IsAmbientModule(result);
	}

	static function canHaveLiteralInitializer(host:DeclarationEmitHost, node:Node):Bool {
		switch (node.Kind) {
			case KindPropertyDeclaration, KindPropertySignature:
				return (host.GetEffectiveDeclarationFlags(node, ModifierFlagsPrivate) : Int) == 0;
			case KindParameter, KindVariableDeclaration:
				return true;
			default:
		}
		return false;
	}

	static function canProduceDiagnostics(node:Node):Bool {
		return Ast.IsVariableDeclaration(node) ||
			Ast.IsPropertyDeclaration(node) ||
			Ast.IsPropertySignatureDeclaration(node) ||
			Ast.IsBindingElement(node) ||
			Ast.IsSetAccessorDeclaration(node) ||
			Ast.IsGetAccessorDeclaration(node) ||
			Ast.IsConstructSignatureDeclaration(node) ||
			Ast.IsCallSignatureDeclaration(node) ||
			Ast.IsMethodDeclaration(node) ||
			Ast.IsMethodSignatureDeclaration(node) ||
			Ast.IsFunctionDeclaration(node) ||
			Ast.IsParameterDeclaration(node) ||
			Ast.IsTypeParameterDeclaration(node) ||
			Ast.IsExpressionWithTypeArguments(node) ||
			Ast.IsImportEqualsDeclaration(node) ||
			Ast.IsTypeAliasDeclaration(node) ||
			Ast.IsJSTypeAliasDeclaration(node) ||
			Ast.IsConstructorDeclaration(node) ||
			Ast.IsIndexSignatureDeclaration(node) ||
			Ast.IsPropertyAccessExpression(node) ||
			Ast.IsElementAccessExpression(node) ||
			Ast.IsBinaryExpression(node) ||
			Ast.IsCallExpression(node); // || // !!! TODO: JSDoc support
		/* ast.IsJSDocTypeAlias(node); */
	}

	static function canReuseModifierNodes(nodes:Array<Node>):Bool {
		if (nodes != null) { // PORT: Go range over a nil slice
			for (node in nodes) {
				if (Ast.IsModifier(node) && (node.Flags & NodeFlagsReparsed) != 0) {
					return false;
				}
			}
		}
		return true;
	}

	static function isDeclarationAndNotVisible(emitContext:EmitContext, resolver:EmitResolver, node:Node):Bool {
		node = emitContext.ParseNode(node);
		switch (node.Kind) {
			case KindFunctionDeclaration,
				KindModuleDeclaration,
				KindInterfaceDeclaration,
				KindClassDeclaration,
				KindTypeAliasDeclaration,
				KindJSTypeAliasDeclaration,
				KindEnumDeclaration:
				return !resolver.IsDeclarationVisible(node);
			// The following should be doing their own visibility checks based on filtering their members
			case KindVariableDeclaration:
				return !getBindingNameVisible(resolver, node);
			case KindImportEqualsDeclaration,
				KindImportDeclaration,
				KindJSImportDeclaration,
				KindExportDeclaration,
				KindExportAssignment:
				return false;
			case KindClassStaticBlockDeclaration:
				return true;
			default:
		}
		return false;
	}

	static function getBindingNameVisible(resolver:EmitResolver, elem:Node):Bool {
		if (Ast.IsOmittedExpression(elem)) {
			return false;
		}
		// TODO: parseArrayBindingElement _never_ parses out an OmittedExpression anymore, instead producing a nameless binding element
		// Audit if OmittedExpression should be removed
		if (elem.Name() == null) {
			return false;
		}
		if (Ast.IsBindingPattern(elem.Name())) {
			// If any child binding pattern element has been marked visible (usually by collect linked aliases), then this is visible
			final elements = elem.Name().Elements();
			if (elements != null) { // PORT: Go range over a nil slice
				for (elem in elements) {
					if (getBindingNameVisible(resolver, elem)) {
						return true;
					}
				}
			}
			return false;
		} else {
			return resolver.IsDeclarationVisible(elem);
		}
	}

	static function isEnclosingDeclaration(node:Node):Bool {
		return Ast.IsSourceFile(node) ||
			Ast.IsTypeAliasDeclaration(node) ||
			Ast.IsJSTypeAliasDeclaration(node) ||
			Ast.IsModuleDeclaration(node) ||
			Ast.IsClassDeclaration(node) ||
			Ast.IsInterfaceDeclaration(node) ||
			Ast.IsFunctionLike(node) ||
			Ast.IsIndexSignatureDeclaration(node) ||
			Ast.IsMappedTypeNode(node) ||
			Ast.IsVariableDeclaration(node);
	}

	static function isAlwaysType(node:Node):Bool {
		if (node.Kind == KindInterfaceDeclaration) {
			return true;
		}
		return false;
	}

	static function maskModifierFlags(node:Node, modifierMask:ModifierFlags, modifierAdditions:ModifierFlags):ModifierFlags {
		var flags = (Ast.GetCombinedModifierFlags(node) & modifierMask) | modifierAdditions;
		if ((flags & ModifierFlagsDefault) != 0 && ((flags & ModifierFlagsExport) == 0)) {
			// A non-exported default is a nonsequitor - we usually try to remove all export modifiers
			// from statements in ambient declarations; but a default export must retain its export modifier to be syntactically valid
			flags = flags ^ ModifierFlagsExport;
		}
		if ((flags & ModifierFlagsDefault) != 0 && (flags & ModifierFlagsAmbient) != 0) {
			flags = flags ^ ModifierFlagsAmbient; // `declare` is never required alongside `default` (and would be an error if printed)
		}
		return flags;
	}

	static function unwrapParenthesizedExpression(o:Node):Node {
		while (o.Kind == KindParenthesizedExpression) {
			o = o.Expression();
		}
		return o;
	}

	static function isPrivateMethodTypeParameter(host:DeclarationEmitHost, node:TypeParameterDeclaration):Bool {
		return node.AsNode().Parent.Kind == KindMethodDeclaration && (host.GetEffectiveDeclarationFlags(node.AsNode().Parent, ModifierFlagsPrivate) : Int) != 0;
	}

	// Returns true if expando properties should be emitted for this function.
	// Properties are emitted if any overload in the symbol has a body (implementation).
	static function shouldEmitFunctionProperties(input:FunctionDeclaration):Bool {
		if (input.Body != null) {
			return true;
		}
		return !Core.Every(input.Symbol.Declarations, function(decl:Node):Bool {
			return !Ast.IsFunctionDeclaration(decl) || decl.AsFunctionDeclaration().Body == null;
		});
	}

	static function getEffectiveBaseTypeNode(node:Node):Node {
		final baseType = Ast.GetClassExtendsHeritageElement(node);
		// !!! TODO: JSDoc support
		// if (baseType && isInJSFile(node)) {
		//     // Prefer an @augments tag because it may have type parameters.
		//     const tag = getJSDocAugmentsTag(node);
		//     if (tag) {
		//         return tag.class;
		//     }
		// }
		return baseType;
	}

	static function isScopeMarker(node:Node):Bool {
		return Ast.IsExportAssignment(node) || Ast.IsExportDeclaration(node);
	}

	static function hasScopeMarker(statements:StatementList):Bool {
		if (statements == null) {
			return false;
		}
		return Core.Some(statements.Nodes, isScopeMarker);
	}
}
