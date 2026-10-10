package ts.binder;

// Port of nameresolver.go (type NameResolver and its methods; the package functions are in
// Binder.hx).

@:allow(ts.binder)
class NameResolver {
	public var CompilerOptions:CompilerOptions = null;
	public var GetSymbolOfDeclaration:(node:Node) -> Symbol = null;
	public var Error:(location:Node, message:Message, ...args:Any) -> Diagnostic = null;
	public var Globals:SymbolTable = null;
	public var ArgumentsSymbol:Symbol = null;
	public var RequireSymbol:Symbol = null;
	public var Lookup:(symbols:SymbolTable, name:std.String, meaning:SymbolFlags) -> Symbol = null;
	public var SymbolReferenced:(symbol:Symbol, meaning:SymbolFlags) -> Void = null;
	public var SetRequiresScopeChangeCache:(node:Node, value:Tristate) -> Void = null;
	public var GetRequiresScopeChangeCache:(node:Node) -> Tristate = null;
	public var OnPropertyWithInvalidInitializer:(location:Node, name:std.String, declaration:Node, result:Symbol) -> Bool = null;
	public var OnFailedToResolveSymbol:(location:Node, name:std.String, meaning:SymbolFlags, nameNotFoundMessage:Message) -> Void = null;
	public var OnSuccessfullyResolvedSymbol:(location:Node, result:Symbol, meaning:SymbolFlags, lastLocation:Node,
		associatedDeclarationForContainingInitializerOrBindingName:Node, withinDeferredContext:Bool) -> Void = null;

	public function new() {}

	public function Resolve(location:Node, name:std.String, meaning:SymbolFlags, nameNotFoundMessage:Message, isUse:Bool, excludeGlobals:Bool):Symbol {
		var result:Symbol = null;
		var lastLocation:Node = null;
		var lastSelfReferenceLocation:Node = null;
		var propertyWithInvalidInitializer:Node = null;
		var associatedDeclarationForContainingInitializerOrBindingName:Node = null;
		var withinDeferredContext = false;
		var grandparent:Node = null;
		final originalLocation = location; // needed for did-you-mean error reporting, which gathers candidates starting from the original location
		final nameIsConst = name == "const";
		// PORT: label — `break loop` is a Haxe `break` (it leaves the loop, also from inside a
		// switch); a Go `break` that only leaves the switch is restructured with if/else.
		while (location != null) {
			if (nameIsConst && Ast.IsConstAssertion(location)) {
				// `const` in an `as const` has no symbol, but issues no error because there is no *actual* lookup of the type
				// (it refers to the constant type of the expression instead)
				return null;
			}
			if (Ast.IsModuleOrEnumDeclaration(location) && lastLocation != null && location.Name() == lastLocation) {
				// If lastLocation is the name of a namespace or enum, skip the parent since it will have is own locals that could
				// conflict.
				lastLocation = location;
				location = location.Parent;
			}
			final locals = location.Locals();
			// Locals of a source file are not in scope (because they get merged into the global symbol table)
			if (locals != null && !Ast.IsGlobalSourceFile(location)) {
				result = lookup(locals, name, meaning);
				if (result != null) {
					var useResult = true;
					if (Ast.IsFunctionLike(location) && lastLocation != null && lastLocation != location.Body()) {
						// symbol lookup restrictions for function-like declarations
						// - Type parameters of a function are in scope in the entire function declaration, including the parameter
						//   list and return type. However, local types are only in scope in the function body.
						// - parameters are only in the scope of function body
						// This restriction does not apply to JSDoc comment types because they are parented
						// at a higher level than type parameters would normally be
						if (meaning & result.Flags & SymbolFlagsType != 0 && lastLocation.Kind != KindJSDoc) {
							// type parameters are visible in parameter list, return type and type parameter list.
							// Synthetic fake scopes are added for signatures so type parameters are accessible from them.
							useResult = result.Flags & SymbolFlagsTypeParameter != 0
								&& (lastLocation.Flags & NodeFlagsSynthesized != 0
									|| lastLocation == location.Type()
									|| lastLocation.Kind == KindParameter
									|| lastLocation.Kind == KindJSDocParameterTag
									|| lastLocation.Kind == KindJSDocReturnTag
									|| lastLocation.Kind == KindTypeParameter);
						}
						if (meaning & result.Flags & SymbolFlagsVariable != 0) {
							// expression inside parameter will lookup as normal variable scope when targeting es2015+
							if (useOuterVariableScopeInParameter(result, location, lastLocation)) {
								useResult = false;
							} else if (result.Flags & SymbolFlagsFunctionScopedVariable != 0) {
								// parameters are visible only inside function body, parameter list and return type
								// technically for parameter list case here we might mix parameters and variables declared in function,
								// however it is detected separately when checking initializers of parameters
								// to make sure that they reference no variables declared after them.
								useResult = lastLocation.Kind == KindParameter
									|| lastLocation.Flags & NodeFlagsSynthesized != 0
									|| lastLocation == location.Type() && Ast.FindAncestor(result.ValueDeclaration, Ast.IsParameterDeclaration) != null;
							}
						}
					} else if (location.Kind == KindConditionalType) {
						// A type parameter declared using 'infer T' in a conditional type is visible only in
						// the true branch of the conditional type.
						useResult = lastLocation == location.AsConditionalTypeNode().TrueType;
					}
					if (useResult) {
						break; // break loop
					}
					result = null;
				}
			}
			withinDeferredContext = withinDeferredContext || Binder.getIsDeferredContext(location, lastLocation);
			switch (location.Kind) {
				case KindSourceFile | KindModuleDeclaration:
					// PORT: `case KindSourceFile: if !... { break }; fallthrough` → one case with a condition.
					if (location.Kind == KindModuleDeclaration || Ast.IsExternalOrCommonJSModule(location.AsSourceFile())) {
						final moduleSymbol = getSymbolOfDeclaration(location);
						if (moduleSymbol != null) {
							final moduleExports = moduleSymbol.Exports;
							var leaveSwitch = false;
							if (Ast.IsSourceFile(location)
								|| (Ast.IsModuleDeclaration(location) && location.Flags & NodeFlagsAmbient != 0 && !Ast.IsGlobalScopeAugmentation(location))) {
								// It's an external module. First see if the module has an export default and if the local
								// name of that export default matches.
								result = moduleExports == null ? null : moduleExports.get(Ast.InternalSymbolNameDefault);
								if (result != null) {
									final localSymbol = Binder.GetLocalSymbolForExportDefault(result);
									if (localSymbol != null && result.Flags & meaning != 0 && localSymbol.Name == name) {
										break; // break loop
									}
									result = null;
								}
								// Because of module/namespace merging, a module's exports are in scope,
								// yet we never want to treat an export specifier as putting a member in scope.
								// Therefore, if the name we find is purely an export specifier, it is not actually considered in scope.
								// Two things to note about this:
								//     1. We have to check this without calling getSymbol. The problem with calling getSymbol
								//        on an export specifier is that it might find the export specifier itself, and try to
								//        resolve it as an alias. This will cause the checker to consider the export specifier
								//        a circular alias reference when it might not be.
								//     2. We check === SymbolFlags.Alias in order to check that the symbol is *purely*
								//        an alias. If we used &, we'd be throwing out symbols that have non alias aspects,
								//        which is not the desired behavior.
								final moduleExport = moduleExports == null ? null : moduleExports.get(name);
								if (moduleExport != null
									&& moduleExport.Flags == SymbolFlagsAlias
									&& (Ast.GetDeclarationOfKind(moduleExport, KindExportSpecifier) != null
										|| Ast.GetDeclarationOfKind(moduleExport, KindNamespaceExport) != null)) {
									leaveSwitch = true;
								}
							}
							if (!leaveSwitch && name != Ast.InternalSymbolNameDefault) {
								if ((result = lookup(moduleExports, name, meaning & SymbolFlagsModuleMember)) != null) {
									if (Ast.IsSourceFile(location) && location.AsSourceFile().CommonJSModuleIndicator != null && result.Flags & SymbolFlagsType == 0) {
										result = null;
									} else {
										break; // break loop
									}
								}
							}
						}
					}
				case KindEnumDeclaration:
					final enumSymbol = getSymbolOfDeclaration(location);
					if (enumSymbol != null) {
						result = lookup(enumSymbol.Exports, name, meaning & SymbolFlagsEnumMember);
						if (result != null) {
							if (nameNotFoundMessage != null
								&& CompilerOptions.GetIsolatedModules()
								&& location.Flags & NodeFlagsAmbient == 0
								&& Ast.GetSourceFileOfNode(location) != Ast.GetSourceFileOfNode(result.ValueDeclaration)) {
								final isolatedModulesLikeFlagName = Core.IfElse(CompilerOptions.VerbatimModuleSyntax == TSTrue, "verbatimModuleSyntax", "isolatedModules");
								error(originalLocation, Diagnostics.Cannot_access_0_from_another_file_without_qualification_when_1_is_enabled_Use_2_instead, name,
									isolatedModulesLikeFlagName, enumSymbol.Name + "." + name);
							}
							break; // break loop
						}
					}
				case KindPropertyDeclaration:
					if (!Ast.IsStatic(location)) {
						final ctor = Ast.FindConstructorDeclaration(location.Parent);
						if (ctor != null && ctor.Locals() != null) {
							if (lookup(ctor.Locals(), name, meaning & SymbolFlagsValue) != null) {
								// Remember the property node, it will be used later to report appropriate error
								propertyWithInvalidInitializer = location;
							}
						}
					}
				case KindClassDeclaration | KindClassExpression | KindInterfaceDeclaration:
					result = lookup(getSymbolOfDeclaration(location).Members, name, meaning & SymbolFlagsType);
					if (result != null) {
						if (!Binder.isTypeParameterSymbolDeclaredInContainer(result, location)) {
							// ignore type parameters not declared in this container
							result = null;
							// PORT: Go `break` (leaves the switch) → the else branches below.
						} else if (lastLocation != null && Ast.IsStatic(lastLocation)) {
							// TypeScript 1.0 spec (April 2014): 3.4.1
							// The scope of a type parameter extends over the entire declaration with which the type
							// parameter list is associated, with the exception of static member declarations in classes.
							if (nameNotFoundMessage != null) {
								error(originalLocation, Diagnostics.Static_members_cannot_reference_class_type_parameters);
							}
							return null;
						} else {
							break; // break loop
						}
					} else if (Ast.IsClassExpression(location) && meaning & SymbolFlagsClass != 0) {
						final className = location.Name();
						if (className != null && name == className.Text()) {
							result = location.Symbol();
							break; // break loop
						}
					}
				case KindExpressionWithTypeArguments:
					if (lastLocation == location.Expression() && Ast.IsHeritageClause(location.Parent) && location.Parent.AsHeritageClause().Token == KindExtendsKeyword) {
						final container = location.Parent.Parent;
						if (Ast.IsClassLike(container)) {
							result = lookup(getSymbolOfDeclaration(container).Members, name, meaning & SymbolFlagsType);
							if (result != null) {
								if (nameNotFoundMessage != null) {
									error(originalLocation, Diagnostics.Base_class_expressions_cannot_reference_class_type_parameters);
								}
								return null;
							}
						}
					}
				// It is not legal to reference a class's own type parameters from a computed property name that
				// belongs to the class. For example:
				//
				//   function foo<T>() { return '' }
				//   class C<T> { // <-- Class's own type parameter T
				//       [foo<T>()]() { } // <-- Reference to T from class's own computed property
				//   }
				case KindComputedPropertyName:
					grandparent = location.Parent.Parent;
					if (Ast.IsClassLike(grandparent) || Ast.IsInterfaceDeclaration(grandparent)) {
						// A reference to this grandparent's type parameters would be an error
						result = lookup(getSymbolOfDeclaration(grandparent).Members, name, meaning & SymbolFlagsType);
						if (result != null) {
							if (nameNotFoundMessage != null) {
								error(originalLocation, Diagnostics.A_computed_property_name_cannot_reference_a_type_parameter_from_its_containing_type);
							}
							return null;
						}
					}
				case KindMethodDeclaration | KindConstructor | KindGetAccessor | KindSetAccessor | KindFunctionDeclaration:
					if (meaning & SymbolFlagsVariable != 0 && name == "arguments") {
						result = argumentsSymbol();
						break; // break loop
					}
				case KindFunctionExpression:
					if (meaning & SymbolFlagsVariable != 0 && name == "arguments") {
						result = argumentsSymbol();
						break; // break loop
					}
					if (meaning & SymbolFlagsFunction != 0) {
						final functionName = location.AsFunctionExpression().Name();
						if (functionName != null && name == functionName.Text()) {
							result = location.Symbol();
							break; // break loop
						}
					}
				case KindDecorator:
					// Decorators are resolved at the class declaration. Resolving at the parameter
					// or member would result in looking up locals in the method.
					//
					//   function y() {}
					//   class C {
					//       method(@y x, y) {} // <-- decorator y should be resolved at the class declaration, not the parameter.
					//   }
					//
					if (location.Parent != null && location.Parent.Kind == KindParameter) {
						location = location.Parent;
					}
					//   function y() {}
					//   class C {
					//       @y method(x, y) {} // <-- decorator y should be resolved at the class declaration, not the method.
					//   }
					//
					// class Decorators are resolved outside of the class to avoid referencing type parameters of that class.
					//
					//   type T = number;
					//   declare function y(x: T): any;
					//   @param(1 as T) // <-- T should resolve to the type alias outside of class C
					//   class C<T> {}
					if (location.Parent != null && (Ast.IsClassElement(location.Parent) || location.Parent.Kind == KindClassDeclaration)) {
						location = location.Parent;
					}
				case KindParameter:
					final parameterDeclaration = location.AsParameterDeclaration();
					if (lastLocation != null
						&& (lastLocation == parameterDeclaration.Initializer || lastLocation == parameterDeclaration.Name() && Ast.IsBindingPattern(lastLocation))) {
						if (associatedDeclarationForContainingInitializerOrBindingName == null) {
							associatedDeclarationForContainingInitializerOrBindingName = location;
						}
					}
				case KindBindingElement:
					final bindingElement = location.AsBindingElement();
					if (lastLocation != null
						&& (lastLocation == bindingElement.Initializer || lastLocation == bindingElement.Name() && Ast.IsBindingPattern(lastLocation))) {
						if (Ast.IsPartOfParameterDeclaration(location) && associatedDeclarationForContainingInitializerOrBindingName == null) {
							associatedDeclarationForContainingInitializerOrBindingName = location;
						}
					}
				case KindInferType:
					if (meaning & SymbolFlagsTypeParameter != 0) {
						final parameterName = location.AsInferTypeNode().TypeParameter.AsTypeParameterDeclaration().Name();
						if (parameterName != null && name == parameterName.Text()) {
							result = location.AsInferTypeNode().TypeParameter.Symbol();
							break; // break loop
						}
					}
				case KindExportSpecifier:
					final exportSpecifier = location.AsExportSpecifier();
					if (lastLocation != null && lastLocation == exportSpecifier.PropertyName && location.Parent.Parent.ModuleSpecifier() != null) {
						location = location.Parent.Parent.Parent;
					}
				default:
			}
			if (Binder.isSelfReferenceLocation(location, lastLocation)) {
				lastSelfReferenceLocation = location;
			}
			lastLocation = location;
			// !!! In Strada, JSDocTemplateTag/JSDocParameterTag/JSDocReturnTag locations skip to
			// getEffectiveContainerForJSDocTemplateTag/getHostSignatureFromJSDoc instead of location.parent.
			// This is a no-op currently because JSDoc nodes have no locals and getEffectiveJSDocHost is not
			// fully ported for JS assignment patterns.
			location = location.Parent;
		}
		// We just climbed up parents looking for the name, meaning that we started in a descendant node of `lastLocation`.
		// If `result === lastSelfReferenceLocation.symbol`, that means that we are somewhere inside `lastSelfReferenceLocation` looking up a name, and resolving to `lastLocation` itself.
		// That means that this is a self-reference of `lastLocation`, and shouldn't count this when considering whether `lastLocation` is used.
		if (isUse && result != null && (lastSelfReferenceLocation == null || result != lastSelfReferenceLocation.Symbol())) {
			if (SymbolReferenced != null) {
				SymbolReferenced(result, meaning);
			}
		}
		if (result == null && !excludeGlobals) {
			result = lookup(Globals, name, meaning | SymbolFlagsGlobalLookup);
		}
		if (result == null) {
			if (originalLocation != null && Ast.IsInJSFile(originalLocation) && originalLocation.Parent != null) {
				if (Ast.IsRequireCall(originalLocation.Parent, false /*requireStringLiteralLikeArgument*/)) {
					return RequireSymbol;
				}
			}
		}
		if (nameNotFoundMessage != null) {
			if (propertyWithInvalidInitializer != null
				&& OnPropertyWithInvalidInitializer != null
				&& OnPropertyWithInvalidInitializer(originalLocation, name, propertyWithInvalidInitializer, result)) {
				return null;
			}
			if (result == null) {
				if (OnFailedToResolveSymbol != null) {
					OnFailedToResolveSymbol(originalLocation, name, meaning, nameNotFoundMessage);
				}
			} else {
				if (OnSuccessfullyResolvedSymbol != null) {
					OnSuccessfullyResolvedSymbol(originalLocation, result, meaning, lastLocation, associatedDeclarationForContainingInitializerOrBindingName,
						withinDeferredContext);
				}
			}
		}
		return result;
	}

	function useOuterVariableScopeInParameter(result:Symbol, location:Node, lastLocation:Node):Bool {
		if (Ast.IsParameterDeclaration(lastLocation)) {
			final body = location.Body();
			if (body != null && result.ValueDeclaration != null && result.ValueDeclaration.Pos() >= body.Pos() && result.ValueDeclaration.End() <= body.End()) {
				// check for several cases where we introduce temporaries that require moving the name/initializer of the parameter to the body
				// - static field in a class expression
				// - optional chaining pre-es2020
				// - nullish coalesce pre-es2020
				// - spread assignment in binding pattern pre-es2017
				final functionLocation = location;
				var declarationRequiresScopeChange = TSUnknown;
				if (GetRequiresScopeChangeCache != null) {
					declarationRequiresScopeChange = GetRequiresScopeChangeCache(functionLocation);
				}
				if (declarationRequiresScopeChange == TSUnknown) {
					declarationRequiresScopeChange = Core.IfElse(Core.Some(functionLocation.Parameters(), requiresScopeChange), TSTrue, TSFalse);
					if (SetRequiresScopeChangeCache != null) {
						SetRequiresScopeChangeCache(functionLocation, declarationRequiresScopeChange);
					}
				}
				return declarationRequiresScopeChange != TSTrue;
			}
		}
		return false;
	}

	function requiresScopeChange(node:Node):Bool {
		final d = node.AsParameterDeclaration();
		return requiresScopeChangeWorker(d.Name()) || d.Initializer != null && requiresScopeChangeWorker(d.Initializer);
	}

	function requiresScopeChangeWorker(node:Node):Bool {
		switch (node.Kind) {
			case KindArrowFunction | KindFunctionExpression | KindFunctionDeclaration | KindConstructor:
				return false;
			case KindMethodDeclaration | KindGetAccessor | KindSetAccessor | KindPropertyAssignment:
				return requiresScopeChangeWorker(node.Name());
			case KindPropertyDeclaration:
				if (Ast.HasStaticModifier(node)) {
					return !CompilerOptions.GetEmitStandardClassFields();
				}
				return requiresScopeChangeWorker(node.AsPropertyDeclaration().Name());
			default:
				if (Ast.IsNullishCoalesce(node) || Ast.IsOptionalChain(node)) {
					return (CompilerOptions.GetEmitScriptTarget() : Int) < (ScriptTargetES2020 : Int);
				}
				if (Ast.IsBindingElement(node) && node.AsBindingElement().DotDotDotToken != null && Ast.IsObjectBindingPattern(node.Parent)) {
					return (CompilerOptions.GetEmitScriptTarget() : Int) < (ScriptTargetES2017 : Int);
				}
				if (Ast.IsTypeNode(node)) {
					return false;
				}
				return node.ForEachChild(requiresScopeChangeWorker);
		}
	}

	function error(location:Node, message:Message, ...args:Any):Void {
		if (Error != null) {
			Error(location, message, ...args);
		}
		// Default implementation does not report errors
	}

	function getSymbolOfDeclaration(node:Node):Symbol {
		if (GetSymbolOfDeclaration != null) {
			return GetSymbolOfDeclaration(node);
		}

		// Default implementation does not support merged symbols
		return node.Symbol();
	}

	function lookup(symbols:SymbolTable, name:std.String, meaning:SymbolFlags):Symbol {
		if (Lookup != null) {
			return Lookup(symbols, name, meaning);
		}
		// Default implementation does not support following aliases or merged symbols
		if (meaning != 0) {
			final symbol = symbols == null ? null : symbols.get(name);
			if (symbol != null) {
				if (symbol.Flags & meaning != 0) {
					return symbol;
				}
			}
		}
		return null;
	}

	function argumentsSymbol():Symbol {
		if (ArgumentsSymbol == null) {
			// Default implementation synthesizes a transient symbol for `arguments`
			final s = new Symbol();
			s.Name = "arguments";
			s.Flags = SymbolFlagsProperty | SymbolFlagsTransient;
			ArgumentsSymbol = s;
		}
		return ArgumentsSymbol;
	}
}
