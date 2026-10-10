package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/checker.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Part of checker.go, Go lines 1-3970 (3970 lines): the Checker methods of this range as static extension
// (receiver first, PORTING.md §2; `using ts.checker.CheckerPart1` in import.hx). Inside class Checker call them as `this.m(...)`.
@:allow(ts.checker)
class CheckerPart1 {

	static function reportUnreliableWorker(c:Checker, t:Type):Type {
		if (t == c.markerSuperType || t == c.markerSubType || t == c.markerOtherType) {
			c.reliabilityFlags |= RelationComparisonResultReportsUnreliable;
		}
		return t;
	}

	static function reportUnmeasurableWorker(c:Checker, t:Type):Type {
		if (t == c.markerSuperType || t == c.markerSubType || t == c.markerOtherType) {
			c.reliabilityFlags |= RelationComparisonResultReportsUnmeasurable;
		}
		return t;
	}

	// Resolve to the global class or interface by the given name and arity, or emptyObjectType/emptyGenericType otherwise
	static function getGlobalTypeResolver(c:Checker, name:std.String, arity:Int, reportErrors:Bool):() -> Type {
		return Core.Memoize(() -> {
			return c.getGlobalType(name, arity, reportErrors);
		});
	}

	// Resolve to the global type alias symbol by the given name and arity, or nil otherwise
	static function getGlobalTypeAliasResolver(c:Checker, name:std.String, arity:Int, reportErrors:Bool):() -> Symbol {
		return Core.Memoize(() -> {
			return c.getGlobalTypeAliasSymbol(name, arity, reportErrors);
		});
	}

	// Resolve to the global value symbol by the given name, or nil otherwise
	static function getGlobalValueSymbolResolver(c:Checker, name:std.String, reportErrors:Bool):() -> Symbol {
		return Core.Memoize(() -> {
			return c.getGlobalSymbol(name, SymbolFlagsValue, Core.IfElse(reportErrors, Diagnostics.Cannot_find_global_value_0, null));
		});
	}

	static function getGlobalTypeSymbolResolver(c:Checker, name:std.String, reportErrors:Bool):() -> Symbol {
		return Core.Memoize(() -> {
			return c.getGlobalSymbol(name, SymbolFlagsType, Core.IfElse(reportErrors, Diagnostics.Cannot_find_global_type_0, null));
		});
	}

	static function getGlobalTypesResolver(c:Checker, names:Array<std.String>, arity:Int, reportErrors:Bool):() -> Array<Type> {
		return Core.Memoize(() -> {
			return Core.Map(names, (name:std.String) -> {
				return c.getGlobalType(name, arity, reportErrors);
			});
		});
	}

	static function getGlobalTypeAliasSymbol(c:Checker, name:std.String, arity:Int, reportErrors:Bool):Symbol {
		final symbol = c.getGlobalSymbol(name, SymbolFlagsTypeAlias, Core.IfElse(reportErrors, Diagnostics.Cannot_find_global_type_0, null));
		if (symbol == null) {
			return null;
		}
		// Resolve the declared type of the symbol. This resolves type parameters for the type alias so that we can check arity.
		c.getDeclaredTypeOfSymbol(symbol);
		if (Core.len(c.typeAliasLinks.Get(symbol).typeParameters) != arity) {
			if (reportErrors) {
				final decl = Core.Find(symbol.Declarations, Ast.IsTypeAliasDeclaration);
				c.error(decl, Diagnostics.Global_type_0_must_have_1_type_parameter_s, Ast.SymbolName(symbol), arity);
			}
			return null;
		}
		return symbol;
	}

	public static function GetTypeAliasTypeParameters(c:Checker, symbol:Symbol):Array<Type> {
		if (symbol.Flags & SymbolFlagsTypeAlias == 0) {
			throw "Attempted to fetch type alias parameters for non-type-alias symbol";
		}
		c.getDeclaredTypeOfSymbol(symbol);
		return c.typeAliasLinks.Get(symbol).typeParameters;
	}

	static function getGlobalType(c:Checker, name:std.String, arity:Int, reportErrors:Bool):Type {
		final symbol = c.getGlobalSymbol(name, SymbolFlagsType, Core.IfElse(reportErrors, Diagnostics.Cannot_find_global_type_0, null));
		if (symbol != null) {
			if (symbol.Flags & (SymbolFlagsClass | SymbolFlagsInterface) != 0) {
				final t = c.getDeclaredTypeOfSymbol(symbol);
				if (Core.len(t.AsInterfaceType().TypeParameters()) == arity) {
					return t;
				}
				if (reportErrors) {
					c.error(Checker.getGlobalTypeDeclaration(symbol), Diagnostics.Global_type_0_must_have_1_type_parameter_s, Ast.SymbolName(symbol), arity);
				}
			} else if (reportErrors) {
				c.error(Checker.getGlobalTypeDeclaration(symbol), Diagnostics.Global_type_0_must_be_a_class_or_interface_type, Ast.SymbolName(symbol));
			}
		}
		if (arity != 0) {
			return c.emptyGenericType;
		}
		return c.emptyObjectType;
	}

	static function getGlobalSymbol(c:Checker, name:std.String, meaning:SymbolFlags, diagnostic:Message):Symbol {
		// Don't track references for global symbols anyway, so value if `isReference` is arbitrary
		return c.resolveName(null, name, meaning, diagnostic, false /*isUse*/, false /*excludeGlobals*/);
	}

	static function initializeClosures(c:Checker):Void {
		c.isPrimitiveOrObjectOrEmptyType = (t:Type) -> {
			return t.flags & (TypeFlagsPrimitive | TypeFlagsNonPrimitive) != 0 || c.IsEmptyAnonymousObjectType(t);
		};
		c.containsMissingType = (t:Type) -> {
			return t == c.missingType || t.flags & TypeFlagsUnion != 0 && t.Types()[0] == c.missingType;
		};
		c.couldContainTypeVariables = c.couldContainTypeVariablesWorker;
		c.isStringIndexSignatureOnlyType = c.isStringIndexSignatureOnlyTypeWorker;
		c.markNodeAssignments = c.markNodeAssignmentsWorker;
		c.compareTypesAssignable = c.compareTypesAssignableWorker;
	}

	static function initializeIterationResolvers(c:Checker):Void {
		final sync = new IterationTypesResolver();
		sync.iteratorSymbolName = "iterator";
		sync.getGlobalIteratorType = c.getGlobalIteratorType;
		sync.getGlobalIterableType = c.getGlobalIterableType;
		sync.getGlobalIterableTypeChecked = c.getGlobalIterableTypeChecked;
		sync.getGlobalIterableIteratorType = c.getGlobalIterableIteratorType;
		sync.getGlobalIterableIteratorTypeChecked = c.getGlobalIterableIteratorTypeChecked;
		sync.getGlobalIteratorObjectType = c.getGlobalIteratorObjectType;
		sync.getGlobalGeneratorType = c.getGlobalGeneratorType;
		sync.getGlobalBuiltinIteratorTypes = c.getGlobalTypesResolver(["ArrayIterator", "MapIterator", "SetIterator", "StringIterator"], 1, false /*reportErrors*/);
		sync.resolveIterationType = (t:Type, errorNode:Node) -> {
			return t;
		};
		sync.mustHaveANextMethodDiagnostic = Diagnostics.An_iterator_must_have_a_next_method;
		sync.mustBeAMethodDiagnostic = Diagnostics.The_0_property_of_an_iterator_must_be_a_method;
		sync.mustHaveAValueDiagnostic = Diagnostics.The_type_returned_by_the_0_method_of_an_iterator_must_have_a_value_property;
		c.syncIterationTypesResolver = sync;
		final async = new IterationTypesResolver();
		async.iteratorSymbolName = "asyncIterator";
		async.getGlobalIteratorType = c.getGlobalAsyncIteratorType;
		async.getGlobalIterableType = c.getGlobalAsyncIterableType;
		async.getGlobalIterableTypeChecked = c.getGlobalAsyncIterableTypeChecked;
		async.getGlobalIterableIteratorType = c.getGlobalAsyncIterableIteratorType;
		async.getGlobalIterableIteratorTypeChecked = c.getGlobalAsyncIterableIteratorTypeChecked;
		async.getGlobalIteratorObjectType = c.getGlobalAsyncIteratorObjectType;
		async.getGlobalGeneratorType = c.getGlobalAsyncGeneratorType;
		async.getGlobalBuiltinIteratorTypes = c.getGlobalTypesResolver(["ReadableStreamAsyncIterator"], 1, false /*reportErrors*/);
		async.resolveIterationType = (t:Type, errorNode:Node) -> {
			return c.getAwaitedTypeEx(t, errorNode,
				Diagnostics.Type_of_await_operand_must_either_be_a_valid_promise_or_must_not_contain_a_callable_then_member);
		};
		async.mustHaveANextMethodDiagnostic = Diagnostics.An_async_iterator_must_have_a_next_method;
		async.mustBeAMethodDiagnostic = Diagnostics.The_0_property_of_an_async_iterator_must_be_a_method;
		async.mustHaveAValueDiagnostic = Diagnostics.The_type_returned_by_the_0_method_of_an_async_iterator_must_be_a_promise_for_a_type_with_a_value_property;
		c.asyncIterationTypesResolver = async;
	}

	static function initializeChecker(c:Checker):Void {
		// Initialize global symbol table
		var ambientModuleSymbols:Array<Symbol> = null;
		final augmentations:Array<Array<ModuleName>> = [];
		for (file in c.files) {
			if (!Ast.IsExternalOrCommonJSModule(file)) {
				// It is an error for a non-external-module (i.e. script) to declare its own `globalThis`.
				final fileGlobalThisSymbol = file.Locals != null ? file.Locals.get("globalThis") : null;
				if (fileGlobalThisSymbol != null) {
					if (fileGlobalThisSymbol.Declarations != null) {
						for (d in fileGlobalThisSymbol.Declarations) {
							c.addDiagnostic(Checker.NewDiagnosticForNode(d, Diagnostics.Declaration_name_conflicts_with_built_in_global_identifier_0, "globalThis"));
						}
					}
				}
				if (file.Locals != null) {
					for (symbol in file.Locals) {
						// We defer merging of global ambient module declarations since they may require other global symbols
						// and types to be resolved. See https://github.com/microsoft/typescript-go/issues/2953.
						if (symbol.Flags & SymbolFlagsModule != 0 && Ast.IsAmbientModuleSymbolName(symbol.Name)) {
							if (ambientModuleSymbols == null) {
								ambientModuleSymbols = [];
							}
							ambientModuleSymbols.push(symbol);
						} else {
							c.mergeGlobalSymbol(symbol);
						}
					}
				}
			}
			if (file.PatternAmbientModules != null) {
				for (m in file.PatternAmbientModules) {
					if (c.patternAmbientModules == null) {
						c.patternAmbientModules = [];
					}
					c.patternAmbientModules.push(m);
				}
			}
			augmentations.push(file.ModuleAugmentations);
			if (file.Symbol != null) {
				// Merge in UMD exports with first-in-wins semantics (see #9771)
				if (file.GlobalExports != null) {
					for (name => symbol in file.GlobalExports) {
						if (!c.globals.exists(name)) {
							c.globals.set(name, symbol);
						}
					}
				}
			}
		}
		// We do global augmentations separately from module augmentations (and before creating global types) because they
		//  1. Affect global types. We won't have the correct global types until global augmentations are merged. Also,
		//  2. Module augmentation instantiation requires creating the type of a module, which, in turn, can require
		//       checking for an export or property on the module (if export=) which, in turn, can fall back to the
		//       apparent type of the module - either globalObjectType or globalFunctionType - which wouldn't exist if we
		//       did module augmentations prior to finalizing the global types.
		for (list in augmentations) {
			if (list == null) {
				continue;
			}
			for (augmentation in list) {
				// Merge 'global' module augmentations. This needs to be done after global symbol table is initialized to
				// make sure that all ambient modules are indexed
				if (Ast.IsGlobalScopeAugmentation(augmentation.Parent)) {
					c.mergeModuleAugmentation(augmentation);
				}
			}
		}
		c.addUndefinedToGlobalsOrErrorOnRedeclaration();
		c.valueSymbolLinks.Get(c.undefinedSymbol).resolvedType = c.undefinedWideningType;
		c.valueSymbolLinks.Get(c.argumentsSymbol).resolvedType = c.getGlobalType("IArguments", 0 /*arity*/, true /*reportErrors*/);
		c.valueSymbolLinks.Get(c.unknownSymbol).resolvedType = c.errorType;
		c.valueSymbolLinks.Get(c.globalThisSymbol).resolvedType = c.newObjectType(ObjectFlagsAnonymous, c.globalThisSymbol);
		// Initialize special types
		c.globalArrayType = c.getGlobalType("Array", 1 /*arity*/, true /*reportErrors*/);
		c.globalObjectType = c.getGlobalType("Object", 0 /*arity*/, true /*reportErrors*/);
		c.globalFunctionType = c.getGlobalType("Function", 0 /*arity*/, true /*reportErrors*/);
		c.globalCallableFunctionType = c.getGlobalStrictFunctionType("CallableFunction");
		c.globalNewableFunctionType = c.getGlobalStrictFunctionType("NewableFunction");
		c.globalStringType = c.getGlobalType("String", 0 /*arity*/, true /*reportErrors*/);
		c.globalNumberType = c.getGlobalType("Number", 0 /*arity*/, true /*reportErrors*/);
		c.globalBooleanType = c.getGlobalType("Boolean", 0 /*arity*/, true /*reportErrors*/);
		c.globalRegExpType = c.getGlobalType("RegExp", 0 /*arity*/, true /*reportErrors*/);
		c.anyArrayType = c.createArrayType(c.anyType);
		c.autoArrayType = c.createArrayType(c.autoType);
		if (c.autoArrayType == c.emptyObjectType) {
			// autoArrayType is used as a marker, so even if global Array type is not defined, it needs to be a unique type
			c.autoArrayType = c.newAnonymousType(null, null, null, null, null);
		}
		c.globalReadonlyArrayType = c.getGlobalType("ReadonlyArray", 1 /*arity*/, false /*reportErrors*/);
		if (c.globalReadonlyArrayType == c.emptyGenericType) {
			c.globalReadonlyArrayType = c.globalArrayType;
		}
		c.anyReadonlyArrayType = c.createTypeFromGenericGlobalType(c.globalReadonlyArrayType, [c.anyType]);
		c.globalThisType = c.getGlobalType("ThisType", 1 /*arity*/, false /*reportErrors*/);
		// Now merge global ambient module declarations
		if (ambientModuleSymbols != null) {
			for (symbol in ambientModuleSymbols) {
				c.mergeGlobalSymbol(symbol);
			}
		}
		// merge _nonglobal_ module augmentations.
		// this needs to be done after global symbol table is initialized to make sure that all ambient modules are indexed
		for (list in augmentations) {
			if (list == null) {
				continue;
			}
			for (augmentation in list) {
				if (!Ast.IsGlobalScopeAugmentation(augmentation.Parent)) {
					c.mergeModuleAugmentation(augmentation);
				}
			}
		}
	}

	static function mergeGlobalSymbol(c:Checker, symbol:Symbol):Void {
		final globalSymbol = c.globals.get(symbol.Name);
		var merged:Symbol = null;
		if (globalSymbol != null) {
			merged = c.mergeSymbol(globalSymbol, symbol, false /*unidirectional*/);
		} else {
			merged = c.getMergedSymbol(symbol);
		}
		c.globals.set(symbol.Name, merged);
	}

	static function mergeModuleAugmentation(c:Checker, moduleName:Node):Void {
		final moduleNode = moduleName.Parent;
		final moduleAugmentation = moduleNode.AsModuleDeclaration();
		if (moduleAugmentation.Symbol.Declarations[0] != moduleNode) {
			// this is a combined symbol for multiple augmentations within the same file.
			// its symbol already has accumulated information for all declarations
			// so we need to add it just once - do the work only for first declaration
			return;
		}
		if (Ast.IsGlobalScopeAugmentation(moduleNode)) {
			c.mergeSymbolTable(c.globals, moduleAugmentation.Symbol.Exports, false /*unidirectional*/, null /*parent*/);
		} else {
			// find a module that about to be augmented
			// do not validate names of augmentations that are defined in ambient context
			var moduleNotFoundError:Message = null;
			if (moduleName.Parent.Parent.Flags & NodeFlagsAmbient == 0) {
				moduleNotFoundError = Diagnostics.Invalid_module_name_in_augmentation_module_0_cannot_be_found;
			}
			var mainModule = c.resolveExternalModuleNameWorker(moduleName, moduleName, moduleNotFoundError /*ignoreErrors*/, false /*isForAugmentation*/, true);
			if (mainModule == null) {
				return;
			}
			// obtain item referenced by 'export='
			mainModule = c.resolveExternalModuleSymbol(mainModule, false /*dontResolveAlias*/);
			if (mainModule.Flags & SymbolFlagsNamespace != 0) {
				// If we're merging an augmentation to a pattern ambient module, we want to
				// perform the merge unidirectionally from the augmentation ('a.foo') to
				// the pattern ('*.foo'), so that 'getMergedSymbol()' on a.foo gives you
				// all the exports both from the pattern and from the augmentation, but
				// 'getMergedSymbol()' on *.foo only gives you exports from *.foo.
				final mm = mainModule;
				if (Core.Some(c.patternAmbientModules, (module:PatternAmbientModule) -> {
					return mm == module.Symbol;
				})) {
					final merged = c.mergeSymbol(moduleAugmentation.Symbol, mainModule, true /*unidirectional*/);
					// moduleName will be a StringLiteral since this is not `declare global`.
					Ast.GetSymbolTable(() -> c.patternAmbientModuleAugmentations, t -> c.patternAmbientModuleAugmentations = t)
						.set(moduleName.Text(), merged);
				} else {
					if (mainModule.Exports != null && mainModule.Exports.get(Ast.InternalSymbolNameExportStar) != null
						&& moduleAugmentation.Symbol.Exports != null && moduleAugmentation.Symbol.Exports.keys().hasNext()) {
						// We may need to merge the module augmentation's exports into the target symbols of the resolved exports
						final resolvedExports = c.getResolvedMembersOrExportsOfSymbol(mainModule, MembersOrExportsResolutionKindResolvedExports);
						for (key => value in moduleAugmentation.Symbol.Exports) {
							if (resolvedExports != null && resolvedExports.get(key) != null && mainModule.Exports.get(key) == null) {
								c.mergeSymbol(resolvedExports.get(key), value, false /*unidirectional*/);
							}
						}
					}
					c.mergeSymbol(mainModule, moduleAugmentation.Symbol, false /*unidirectional*/);
				}
			} else {
				// moduleName will be a StringLiteral since this is not `declare global`.
				c.error(moduleName, Diagnostics.Cannot_augment_module_0_because_it_resolves_to_a_non_module_entity, moduleName.Text());
			}
		}
	}

	static function addUndefinedToGlobalsOrErrorOnRedeclaration(c:Checker):Void {
		final name = c.undefinedSymbol.Name;
		final targetSymbol = c.globals.get(name);
		if (targetSymbol != null) {
			if (targetSymbol.Declarations != null) {
				for (declaration in targetSymbol.Declarations) {
					if (!Ast.IsTypeDeclaration(declaration)) {
						c.addDiagnostic(Checker.createDiagnosticForNode(declaration, Diagnostics.Declaration_name_conflicts_with_built_in_global_identifier_0, name));
					}
				}
			}
		} else {
			c.globals.set(name, c.undefinedSymbol);
		}
	}

	static function createNameResolver(c:Checker):NameResolver {
		final r = new NameResolver();
		r.CompilerOptions = c.compilerOptions;
		r.GetSymbolOfDeclaration = c.getSymbolOfDeclaration;
		// PORT: explicit closure; a bound `c.error` closure of a rest-args extension method passes the rest array as one
		// argument (measured, Haxe 4.3.7 JS output).
		r.Error = function(location:Node, message:Message, ...args:Any):Diagnostic {
			return c.error(location, message, ...args);
		};
		r.Globals = c.globals;
		r.ArgumentsSymbol = c.argumentsSymbol;
		r.RequireSymbol = c.requireSymbol;
		r.Lookup = c.getSymbol;
		r.SymbolReferenced = c.symbolReferenced;
		r.SetRequiresScopeChangeCache = c.setRequiresScopeChangeCache;
		r.GetRequiresScopeChangeCache = c.getRequiresScopeChangeCache;
		r.OnPropertyWithInvalidInitializer = c.checkAndReportErrorForInvalidInitializer;
		r.OnFailedToResolveSymbol = c.onFailedToResolveSymbol;
		r.OnSuccessfullyResolvedSymbol = c.onSuccessfullyResolvedSymbol;
		return r;
	}

	static function createNameResolverForSuggestion(c:Checker):NameResolver {
		final r = new NameResolver();
		r.CompilerOptions = c.compilerOptions;
		r.GetSymbolOfDeclaration = c.getSymbolOfDeclaration;
		// PORT: explicit closure; a bound `c.error` closure of a rest-args extension method passes the rest array as one
		// argument (measured, Haxe 4.3.7 JS output).
		r.Error = function(location:Node, message:Message, ...args:Any):Diagnostic {
			return c.error(location, message, ...args);
		};
		r.Globals = c.globals;
		r.ArgumentsSymbol = c.argumentsSymbol;
		r.RequireSymbol = c.requireSymbol;
		r.Lookup = c.getSuggestionForSymbolNameLookup;
		r.SymbolReferenced = c.symbolReferenced;
		r.SetRequiresScopeChangeCache = c.setRequiresScopeChangeCache;
		r.GetRequiresScopeChangeCache = c.getRequiresScopeChangeCache;
		return r;
	}

	static function symbolReferenced(c:Checker, symbol:Symbol, meaning:SymbolFlags):Void {
		c.symbolReferenceLinks.Get(symbol).referenceKinds |= meaning;
	}

	static function getRequiresScopeChangeCache(c:Checker, node:Node):Tristate {
		return c.nodeLinks.Get(node).declarationRequiresScopeChange;
	}

	static function setRequiresScopeChangeCache(c:Checker, node:Node, value:Tristate):Void {
		c.nodeLinks.Get(node).declarationRequiresScopeChange = value;
	}

	// The invalid initializer error is needed in two situation:
	// 1. When result is undefined, after checking for a missing "this."
	// 2. When result is defined
	static function checkAndReportErrorForInvalidInitializer(c:Checker, errorLocation:Node, name:std.String, propertyWithInvalidInitializer:Node, result:Symbol):Bool {
		if (!c.compilerOptions.GetEmitStandardClassFields()) {
			if (errorLocation != null && result == null && c.checkAndReportErrorForMissingPrefix(errorLocation, name)) {
				return true;
			}
			// We have a match, but the reference occurred within a property initializer and the identifier also binds
			// to a local variable in the constructor where the code will be emitted. Note that this is actually allowed
			// with emitStandardClassFields because the scope semantics are different.
			final prop = propertyWithInvalidInitializer.AsPropertyDeclaration();
			final message = Core.IfElse(errorLocation != null && prop.Type != null && prop.Type.Loc.ContainsInclusive(errorLocation.Pos()),
				Diagnostics.Type_of_instance_member_variable_0_cannot_reference_identifier_1_declared_in_the_constructor,
				Diagnostics.Initializer_of_instance_member_variable_0_cannot_reference_identifier_1_declared_in_the_constructor);
			c.error(errorLocation, message, Scanner.DeclarationNameToString(prop.Name()), name);
			return true;
		}
		return false;
	}

	static function checkAndReportErrorForMissingPrefix(c:Checker, errorLocation:Node, name:std.String):Bool {
		if (!Ast.IsIdentifier(errorLocation) || errorLocation.Text() != name || Checker.isTypeReferenceIdentifier(errorLocation)
			|| Checker.IsInTypeQuery(errorLocation)) {
			return false;
		}
		final container = c.getThisContainer(errorLocation, false /*includeArrowFunctions*/, false /*includeClassComputedPropertyName*/);
		var location = container;
		while (location.Parent != null) {
			if (Ast.IsClassLike(location.Parent)) {
				final classSymbol = c.getSymbolOfDeclaration(location.Parent);
				if (classSymbol == null) {
					break;
				}
				// Check to see if a static member exists.
				final constructorType = c.getTypeOfSymbol(classSymbol);
				if (c.getPropertyOfType(constructorType, name) != null) {
					c.error(errorLocation, Diagnostics.Cannot_find_name_0_Did_you_mean_the_static_member_1_0, name, c.symbolToString(classSymbol));
					return true;
				}
				// No static member is present.
				// Check if we're in an instance method and look for a relevant instance member.
				if (location == container && !Ast.IsStatic(location)) {
					final instanceType = c.getDeclaredTypeOfSymbol(classSymbol).AsInterfaceType().thisType;
					// TODO: GH#18217
					if (c.getPropertyOfType(instanceType, name) != null) {
						c.error(errorLocation, Diagnostics.Cannot_find_name_0_Did_you_mean_the_instance_member_this_0, name);
						return true;
					}
				}
			}
			location = location.Parent;
		}
		return false;
	}

	static function onFailedToResolveSymbol(c:Checker, errorLocation:Node, name:std.String, meaning:SymbolFlags, nameNotFoundMessage:Message):Void {
		if (errorLocation != null
			&& (errorLocation.Parent.Kind == KindJSDocLink
				|| c.checkAndReportErrorForMissingPrefix(errorLocation, name)
				|| c.checkAndReportErrorForExtendingInterface(errorLocation)
				|| c.checkAndReportErrorForUsingTypeAsNamespace(errorLocation, name, meaning)
				|| c.checkAndReportErrorForExportingPrimitiveType(errorLocation, name)
				|| c.checkAndReportErrorForUsingNamespaceAsTypeOrValue(errorLocation, name, meaning)
				|| c.checkAndReportErrorForUsingTypeAsValue(errorLocation, name, meaning)
				|| c.checkAndReportErrorForUsingValueAsType(errorLocation, name, meaning))) {
			return;
		}
		var declarationName = name;
		if (errorLocation != null && Ast.IsIdentifier(errorLocation) && errorLocation.Text() == name) {
			declarationName = Scanner.DeclarationNameToString(errorLocation); // use escape sequences from original file
		}
		// Report missing lib first
		final suggestedLib = c.getSuggestedLibForNonExistentName(name);
		if (suggestedLib != "") {
			c.error(errorLocation, nameNotFoundMessage, declarationName, suggestedLib);
			return;
		}
		// Then spelling suggestions
		final suggestion = c.getSuggestedSymbolForNonexistentSymbol(errorLocation, name, meaning);
		if (suggestion != null
			&& !(suggestion.ValueDeclaration != null && Ast.IsAmbientModule(suggestion.ValueDeclaration)
				&& Ast.IsGlobalScopeAugmentation(suggestion.ValueDeclaration))) {
			final suggestionName = c.symbolToString(suggestion);
			final isUncheckedJS = c.isUncheckedJSSuggestion(errorLocation, suggestion, false /*excludeClasses*/);
			final message = Core.IfElse(meaning == SymbolFlagsNamespace, Diagnostics.Cannot_find_namespace_0_Did_you_mean_1,
				Core.IfElse(isUncheckedJS, Diagnostics.Could_not_find_name_0_Did_you_mean_1, Diagnostics.Cannot_find_name_0_Did_you_mean_1));
			final diagnostic = Checker.NewDiagnosticForNode(errorLocation, message, declarationName, suggestionName);
			if (suggestion.ValueDeclaration != null) {
				diagnostic.AddRelatedInfo(Checker.NewDiagnosticForNode(suggestion.ValueDeclaration, Diagnostics.X_0_is_declared_here, suggestionName));
			}
			c.addErrorOrSuggestion(!isUncheckedJS, diagnostic);
			return;
		}
		// And then fall back to unspecified "not found"
		c.error(errorLocation, nameNotFoundMessage, declarationName);
	}

	static function checkAndReportErrorForUsingTypeAsNamespace(c:Checker, errorLocation:Node, name:std.String, meaning:SymbolFlags):Bool {
		if (meaning == SymbolFlagsNamespace) {
			final symbol = c.resolveSymbol(c.resolveName(errorLocation, name, SymbolFlagsType & ~SymbolFlagsNamespace, null /*nameNotFoundMessage*/,
				false /*isUse*/, false /*excludeGlobals*/));
			if (symbol != null) {
				final parent = errorLocation.Parent;
				if (Ast.IsQualifiedName(parent)) {
					Debug.Assert(parent.AsQualifiedName().Left == errorLocation, "Should only be resolving left side of qualified name as a namespace");
					final propName = parent.AsQualifiedName().Right.Text();
					final propType = c.getPropertyOfType(c.getDeclaredTypeOfSymbol(symbol), propName);
					if (propType != null) {
						c.error(parent,
							Diagnostics.Cannot_access_0_1_because_0_is_a_type_but_not_a_namespace_Did_you_mean_to_retrieve_the_type_of_the_property_1_in_0_with_0_1,
							name, propName);
						return true;
					}
				}
				c.error(errorLocation, Diagnostics.X_0_only_refers_to_a_type_but_is_being_used_as_a_namespace_here, name);
				return true;
			}
		}
		return false;
	}

	static function checkAndReportErrorForExportingPrimitiveType(c:Checker, errorLocation:Node, name:std.String):Bool {
		if (Checker.isPrimitiveTypeName(name) && errorLocation.Parent.Kind == KindExportSpecifier) {
			c.error(errorLocation, Diagnostics.Cannot_export_0_Only_local_declarations_can_be_exported_from_a_module, name);
			return true;
		}
		return false;
	}

	static function checkAndReportErrorForUsingNamespaceAsTypeOrValue(c:Checker, errorLocation:Node, name:std.String, meaning:SymbolFlags):Bool {
		if (meaning & (SymbolFlagsValue & ~SymbolFlagsType) != 0) {
			final symbol = c.resolveSymbol(c.resolveName(errorLocation, name, SymbolFlagsNamespaceModule, null /*nameNotFoundMessage*/, false /*isUse*/,
				false /*excludeGlobals*/));
			if (symbol != null) {
				c.error(errorLocation, Diagnostics.Cannot_use_namespace_0_as_a_value, name);
				return true;
			}
		} else if (meaning & (SymbolFlagsType & ~SymbolFlagsValue) != 0) {
			final symbol = c.resolveSymbol(c.resolveName(errorLocation, name, SymbolFlagsModule, null /*nameNotFoundMessage*/, false /*isUse*/,
				false /*excludeGlobals*/));
			if (symbol != null) {
				c.error(errorLocation, Diagnostics.Cannot_use_namespace_0_as_a_type, name);
				return true;
			}
		}
		return false;
	}

	static function checkAndReportErrorForUsingTypeAsValue(c:Checker, errorLocation:Node, name:std.String, meaning:SymbolFlags):Bool {
		if (meaning & SymbolFlagsValue != 0) {
			if (Checker.isPrimitiveTypeName(name)) {
				final grandparent = errorLocation.Parent.Parent;
				if (grandparent != null && grandparent.Parent != null && Ast.IsHeritageClause(grandparent)) {
					final heritageKind = grandparent.AsHeritageClause().Token;
					final containerKind = grandparent.Parent.Kind;
					if (containerKind == KindInterfaceDeclaration && heritageKind == KindExtendsKeyword) {
						c.error(errorLocation,
							Diagnostics.An_interface_cannot_extend_a_primitive_type_like_0_It_can_only_extend_other_named_object_types, name);
					} else if (Ast.IsClassLike(grandparent.Parent) && heritageKind == KindExtendsKeyword) {
						c.error(errorLocation, Diagnostics.A_class_cannot_extend_a_primitive_type_like_0_Classes_can_only_extend_constructable_values,
							name);
					} else if (Ast.IsClassLike(grandparent.Parent) && heritageKind == KindImplementsKeyword) {
						c.error(errorLocation,
							Diagnostics.A_class_cannot_implement_a_primitive_type_like_0_It_can_only_implement_other_named_object_types, name);
					}
				} else {
					c.error(errorLocation, Diagnostics.X_0_only_refers_to_a_type_but_is_being_used_as_a_value_here, name);
				}
				return true;
			}
			final symbol = c.resolveSymbol(c.resolveName(errorLocation, name, SymbolFlagsType & ~SymbolFlagsValue, null /*nameNotFoundMessage*/,
				false /*isUse*/, false /*excludeGlobals*/));
			if (symbol != null) {
				final allFlags = c.getSymbolFlags(symbol);
				if (allFlags & SymbolFlagsValue == 0) {
					if (Checker.isES2015OrLaterConstructorName(name)) {
						c.error(errorLocation,
							Diagnostics.X_0_only_refers_to_a_type_but_is_being_used_as_a_value_here_Do_you_need_to_change_your_target_library_Try_changing_the_lib_compiler_option_to_es2015_or_later,
							name);
					} else if (c.maybeMappedType(errorLocation, symbol)) {
						c.error(errorLocation, Diagnostics.X_0_only_refers_to_a_type_but_is_being_used_as_a_value_here_Did_you_mean_to_use_1_in_0, name,
							Core.IfElse(name == "K", "P", "K"));
					} else {
						c.error(errorLocation, Diagnostics.X_0_only_refers_to_a_type_but_is_being_used_as_a_value_here, name);
					}
					return true;
				}
			}
		}
		return false;
	}

	static function maybeMappedType(c:Checker, node:Node, symbol:Symbol):Bool {
		while (true) {
			node = node.Parent;
			if (!(Ast.IsComputedPropertyName(node) || Ast.IsPropertySignatureDeclaration(node))) {
				break;
			}
		}
		if (Ast.IsTypeLiteralNode(node) && Core.len(node.Members()) == 1) {
			final t = c.getDeclaredTypeOfSymbol(symbol);
			return t.flags & TypeFlagsUnion != 0 && c.allTypesAssignableToKindEx(t, TypeFlagsStringOrNumberLiteral, true /*strict*/);
		}
		return false;
	}

	static function checkAndReportErrorForUsingValueAsType(c:Checker, errorLocation:Node, name:std.String, meaning:SymbolFlags):Bool {
		if (meaning & (SymbolFlagsType & ~SymbolFlagsNamespace) != 0) {
			final symbol = c.resolveSymbol(c.resolveName(errorLocation, name, ~SymbolFlagsType & SymbolFlagsValue, null /*nameNotFoundMessage*/,
				false /*isUse*/, false /*excludeGlobals*/));
			if (symbol != null && symbol.Flags & SymbolFlagsNamespace == 0) {
				c.error(errorLocation, Diagnostics.X_0_refers_to_a_value_but_is_being_used_as_a_type_here_Did_you_mean_typeof_0, name);
				return true;
			}
		}
		return false;
	}

	static function getSuggestedLibForNonExistentName(c:Checker, name:std.String):std.String {
		final featureMap = Checker.getFeatureMap();
		if (featureMap.exists(name)) {
			final typeFeatures = featureMap.get(name);
			return typeFeatures[0].lib;
		}
		return "";
	}

	static function getSuggestedSymbolForNonexistentSymbol(c:Checker, location:Node, outerName:std.String, meaning:SymbolFlags):Symbol {
		return c.resolveNameForSymbolSuggestion(location, outerName, meaning, null /*nameNotFoundMessage*/, false /*isUse*/, false /*excludeGlobals*/);
	}

	static function getSuggestionForSymbolNameLookup(c:Checker, symbols:SymbolTable, name:std.String, meaning:SymbolFlags):Symbol {
		final symbol = c.getSymbol(symbols, name, meaning);
		if (symbol != null) {
			return symbol;
		}
		var extras:(yield:(Symbol) -> Bool) -> Void = null;
		if (meaning & SymbolFlagsGlobalLookup != 0) {
			extras = Checker.getPrimitiveTypeAliasSuggestions(symbols);
		}
		// PORT: core.ConcatenateSeq(maps.Values(symbols), extras) over iter.Seq (yield-func form).
		return c.getSpellingSuggestionForName(name, (yield:(Symbol) -> Bool) -> {
			if (symbols != null) {
				for (s in symbols) {
					if (!yield(s)) {
						return;
					}
				}
			}
			if (extras != null) {
				extras(yield);
			}
		}, meaning);
	}

	// Given a name and a list of symbols whose names are *not* equal to the name, return a spelling suggestion if there is
	// one that is close enough. Names less than length 3 only check for case-insensitive equality, not levenshtein distance.
	//
	// If there is a candidate that's the same except for case, return that.
	// If there is a candidate that's within one edit of the name, return that.
	// Otherwise, return the candidate with the smallest Levenshtein distance,
	//
	// Except for candidates:
	//   - With no name
	//   - Whose meaning doesn't match the `meaning` parameter.
	//   - Whose length differs from the target name by more than 0.34 of the length of the name.
	//   - Whose levenshtein distance is more than 0.4 of the length of the name (0.4 allows 1 substitution/transposition
	//     for every 5 characters, and 1 insertion/deletion at 3 characters)
	static function getSpellingSuggestionForName(c:Checker, name:std.String, symbols:(yield:(Symbol) -> Bool) -> Void, meaning:SymbolFlags):Symbol {
		final getCandidateName = (candidate:Symbol) -> {
			final candidateName = Ast.SymbolName(candidate);
			// PORT: Go byte '\xFE' (internal symbol prefix) is U+FFFE here (PORTING.md §5).
			if (candidateName.length == 0 || StringTools.fastCodeAt(candidateName, 0) == '"'.code
				|| StringTools.fastCodeAt(candidateName, 0) == 0xFFFE) {
				return "";
			}
			if (candidate.Flags & meaning != 0) {
				return candidateName;
			}
			if (candidate.Flags & SymbolFlagsAlias != 0) {
				final alias = c.tryResolveAlias(candidate);
				if (alias != null && alias.Flags & meaning != 0) {
					return candidateName;
				}
			}
			return "";
		};
		// PORT: iter.Seq → collected into an array (core.GetSpellingSuggestion takes an Iterator).
		final list:Array<Symbol> = [];
		symbols(s -> {
			list.push(s);
			return true;
		});
		return Core.GetSpellingSuggestion(name, list.iterator(), getCandidateName, c.compareSymbols);
	}

	static function onSuccessfullyResolvedSymbol(c:Checker, errorLocation:Node, result:Symbol, meaning:SymbolFlags, lastLocation:Node, associatedDeclarationForContainingInitializerOrBindingName:Node, withinDeferredContext:Bool):Void {
		final name = result.Name;
		final isInExternalModule = lastLocation != null && Ast.IsSourceFile(lastLocation) && Ast.IsExternalOrCommonJSModule(lastLocation.AsSourceFile());
		// Only check for block-scoped variable if we have an error location and are looking for the
		// name with variable meaning
		//      For example,
		//          declare module foo {
		//              interface bar {}
		//          }
		//      const foo/*1*/: foo/*2*/.bar;
		// The foo at /*1*/ and /*2*/ will share same symbol with two meanings:
		// block-scoped variable and namespace module. However, only when we
		// try to resolve name in /*1*/ which is used in variable position,
		// we want to check for block-scoped
		if (errorLocation != null
			&& (meaning & SymbolFlagsBlockScopedVariable != 0
				|| meaning & (SymbolFlagsClass | SymbolFlagsEnum) != 0 && meaning & SymbolFlagsValue == SymbolFlagsValue)) {
			final exportOrLocalSymbol = c.getExportSymbolOfValueSymbolIfExported(result);
			if (exportOrLocalSymbol.Flags & (SymbolFlagsBlockScopedVariable | SymbolFlagsClass | SymbolFlagsEnum) != 0) {
				c.checkResolvedBlockScopedVariable(exportOrLocalSymbol, errorLocation);
			}
		}
		// If we're in an external module, we can't reference value symbols created from UMD export declarations
		if (isInExternalModule && (meaning & SymbolFlagsValue) == SymbolFlagsValue && errorLocation.Flags & NodeFlagsJSDoc == 0) {
			final merged = c.getMergedSymbol(result);
			if (Core.len(merged.Declarations) != 0 && Core.Every(merged.Declarations, (d:Node) -> {
				return Ast.IsNamespaceExportDeclaration(d) || Ast.IsSourceFile(d) && d.AsSourceFile().GlobalExports != null;
			})) {
				c.errorOrSuggestion(c.compilerOptions.AllowUmdGlobalAccess != TSTrue, errorLocation,
					Diagnostics.X_0_refers_to_a_UMD_global_but_the_current_file_is_a_module_Consider_adding_an_import_instead, name);
			}
		}
		// If we're in a parameter initializer or binding name, we can't reference the values of the parameter whose initializer we're within or parameters to the right
		if (associatedDeclarationForContainingInitializerOrBindingName != null && !withinDeferredContext
			&& (meaning & SymbolFlagsValue) == SymbolFlagsValue) {
			final candidate = c.getMergedSymbol(c.getLateBoundSymbol(result));
			final root = Ast.GetRootDeclaration(associatedDeclarationForContainingInitializerOrBindingName);
			// A parameter initializer or binding pattern initializer within a parameter cannot refer to itself
			if (candidate == c.getSymbolOfDeclaration(associatedDeclarationForContainingInitializerOrBindingName)) {
				c.error(errorLocation, Diagnostics.Parameter_0_cannot_reference_itself,
					Scanner.DeclarationNameToString(associatedDeclarationForContainingInitializerOrBindingName.Name()));
			} else if (candidate.ValueDeclaration != null
				&& candidate.ValueDeclaration.Pos() > associatedDeclarationForContainingInitializerOrBindingName.Pos()
				&& root.Parent.Locals() != null
				&& c.getSymbol(root.Parent.Locals(), candidate.Name, meaning) == candidate) {
				c.error(errorLocation, Diagnostics.Parameter_0_cannot_reference_identifier_1_declared_after_it,
					Scanner.DeclarationNameToString(associatedDeclarationForContainingInitializerOrBindingName.Name()),
					Scanner.DeclarationNameToString(errorLocation));
			}
		}
		if (errorLocation != null && meaning & SymbolFlagsValue != 0 && result.Flags & SymbolFlagsAlias != 0 && result.Flags & SymbolFlagsValue == 0
			&& !Ast.IsValidTypeOnlyAliasUseSite(errorLocation)) {
			final typeOnlyDeclaration = c.getTypeOnlyAliasDeclarationEx(result, SymbolFlagsValue);
			if (typeOnlyDeclaration != null) {
				final message = Core.IfElse(Ast.NodeKindIs(typeOnlyDeclaration, KindExportSpecifier, KindExportDeclaration, KindNamespaceExport),
					Diagnostics.X_0_cannot_be_used_as_a_value_because_it_was_exported_using_export_type,
					Diagnostics.X_0_cannot_be_used_as_a_value_because_it_was_imported_using_import_type);
				c.addTypeOnlyDeclarationRelatedInfo(c.error(errorLocation, message, name), typeOnlyDeclaration, name);
			}
		}
		// Look at 'compilerOptions.isolatedModules' and not 'getIsolatedModules(...)' (which considers 'verbatimModuleSyntax')
		// here because 'verbatimModuleSyntax' will already have an error for importing a type without 'import type'.
		if (c.compilerOptions.IsolatedModules == TSTrue && result != null && isInExternalModule && (meaning & SymbolFlagsValue) == SymbolFlagsValue) {
			final isGlobal = c.getSymbol(c.globals, name, meaning) == result;
			var nonValueSymbol:Symbol = null;
			if (isGlobal && Ast.IsSourceFile(lastLocation)) {
				nonValueSymbol = c.getSymbol(lastLocation.Locals(), name, ~SymbolFlagsValue);
			}
			if (nonValueSymbol != null) {
				final importDecl = Core.Find(nonValueSymbol.Declarations, (d:Node) -> {
					return Ast.NodeKindIs(d, KindImportSpecifier, KindImportClause, KindNamespaceImport, KindImportEqualsDeclaration);
				});
				if (importDecl != null && !Ast.IsTypeOnlyImportDeclaration(importDecl)) {
					c.error(importDecl,
						Diagnostics.Import_0_conflicts_with_global_value_used_in_this_file_so_must_be_declared_with_a_type_only_import_when_isolatedModules_is_enabled,
						name);
				}
			}
		}
	}

	static function checkResolvedBlockScopedVariable(c:Checker, result:Symbol, errorLocation:Node):Void {
		Debug.Assert(result.Flags & SymbolFlagsBlockScopedVariable != 0 || result.Flags & SymbolFlagsClass != 0 || result.Flags & SymbolFlagsEnum != 0);
		if (result.Flags & (SymbolFlagsFunction | SymbolFlagsFunctionScopedVariable | SymbolFlagsAssignment) != 0 && result.Flags & SymbolFlagsClass != 0) {
			// constructor functions aren't block scoped
			return;
		}
		// Block-scoped variables cannot be used before their definition
		final declaration = Core.Find(result.Declarations, (d:Node) -> {
			return Ast.IsBlockOrCatchScoped(d) || Ast.IsClassLike(d) || Ast.IsEnumDeclaration(d);
		});
		if (declaration == null) {
			throw "checkResolvedBlockScopedVariable could not find block-scoped declaration";
		}
		if (declaration.Flags & NodeFlagsAmbient == 0 && !c.isBlockScopedNameDeclaredBeforeUse(declaration, errorLocation)) {
			var diagnostic:Diagnostic = null;
			final declarationName = Scanner.DeclarationNameToString(Ast.GetNameOfDeclaration(declaration));
			if (result.Flags & SymbolFlagsBlockScopedVariable != 0) {
				diagnostic = c.error(errorLocation, Diagnostics.Block_scoped_variable_0_used_before_its_declaration, declarationName);
			} else if (result.Flags & SymbolFlagsClass != 0) {
				diagnostic = c.error(errorLocation, Diagnostics.Class_0_used_before_its_declaration, declarationName);
			} else if (result.Flags & SymbolFlagsRegularEnum != 0) {
				diagnostic = c.error(errorLocation, Diagnostics.Enum_0_used_before_its_declaration, declarationName);
			} else {
				Debug.Assert(result.Flags & SymbolFlagsConstEnum != 0);
				if (c.compilerOptions.GetIsolatedModules()) {
					diagnostic = c.error(errorLocation, Diagnostics.Enum_0_used_before_its_declaration, declarationName);
				}
			}
			if (diagnostic != null) {
				diagnostic.AddRelatedInfo(Checker.createDiagnosticForNode(declaration, Diagnostics.X_0_is_declared_here, declarationName));
			}
		}
	}

	static function isBlockScopedNameDeclaredBeforeUse(c:Checker, declaration:Node, usage:Node):Bool {
		final declarationFile = Ast.GetSourceFileOfNode(declaration);
		final useFile = Ast.GetSourceFileOfNode(usage);
		final declContainer = Ast.GetEnclosingBlockScopeContainer(declaration);
		if (declarationFile != useFile) {
			// nodes are in different files and order cannot be determined
			return true;
		}
		// deferred usage in a type context is always OK regardless of the usage position:
		if (usage.Flags & NodeFlagsJSDoc != 0 || Checker.IsInTypeQuery(usage) || c.isInAmbientOrTypeNode(usage)) {
			return true;
		}
		if (declaration.Pos() <= usage.Pos()
			&& !(Ast.IsPropertyDeclaration(declaration) && Checker.isThisProperty(usage.Parent) && declaration.Initializer() == null
				&& !Checker.isExclamationToken(declaration.PostfixToken()))) {
			// declaration is before usage
			if (declaration.Kind == KindBindingElement) {
				// still might be illegal if declaration and usage are both binding elements (eg var [a = b, b = b] = [1, 2])
				final errorBindingElement = Ast.FindAncestorKind(usage, KindBindingElement);
				if (errorBindingElement != null) {
					return Ast.FindAncestor(errorBindingElement, Ast.IsBindingElement) != Ast.FindAncestor(declaration, Ast.IsBindingElement)
						|| declaration.Pos() < errorBindingElement.Pos();
				}
				// or it might be illegal if usage happens before parent variable is declared (eg var [a] = a)
				return c.isBlockScopedNameDeclaredBeforeUse(Ast.FindAncestorKind(declaration, KindVariableDeclaration), usage);
			} else if (declaration.Kind == KindVariableDeclaration) {
				// still might be illegal if usage is in the initializer of the variable declaration (eg var a = a)
				return !Checker.isImmediatelyUsedInInitializerOfBlockScopedVariable(declaration, usage, declContainer);
			} else if (Ast.IsClassLike(declaration)) {
				// still might be illegal if the usage is within a computed property name in the class (eg class A { static p = "a"; [A.p]() {} })
				// or when used within a decorator in the class (e.g. `@dec(A.x) class A { static x = "x" }`),
				// except when used in a function that is not an IIFE (e.g., `@dec(() => A.x) class A { ... }`)
				var container = usage;
				while (container != null && container != declaration) {
					if (Ast.IsComputedPropertyName(container) && container.Parent.Parent == declaration
						|| !c.legacyDecorators && Ast.IsDecorator(container)
						&& (container.Parent == declaration
							|| Ast.IsMethodDeclaration(container.Parent) && container.Parent.Parent == declaration
							|| Ast.IsAccessor(container.Parent) && container.Parent.Parent == declaration
							|| Ast.IsPropertyDeclaration(container.Parent) && container.Parent.Parent == declaration
							|| Ast.IsParameterDeclaration(container.Parent) && container.Parent.Parent.Parent == declaration)) {
						break;
					}
					container = container.Parent;
				}
				if (container == null || container == declaration) {
					return true;
				}
				if (!c.legacyDecorators && Ast.IsDecorator(container)) {
					var n = usage;
					while (n != null && n != container) {
						if (Ast.IsFunctionLike(n) && Ast.GetImmediatelyInvokedFunctionExpression(n) == null) {
							break;
						}
						n = n.Parent;
					}
					return n != null && n != container;
				}
				return false;
			} else if (Ast.IsPropertyDeclaration(declaration)) {
				// still might be illegal if a self-referencing property initializer (eg private x = this.x)
				return !Checker.isPropertyImmediatelyReferencedWithinDeclaration(declaration, usage, false /*stopAtAnyPropertyDeclaration*/);
			} else if (Ast.IsParameterPropertyDeclaration(declaration, declaration.Parent)) {
				// foo = this.bar is illegal in emitStandardClassFields when bar is a parameter property
				return !(c.emitStandardClassFields && Ast.GetContainingClass(declaration) == Ast.GetContainingClass(usage)
					&& c.isUsedInFunctionOrInstanceProperty(usage, declaration, declContainer));
			}
			return true;
		}
		// declaration is after usage, but it can still be legal if usage is deferred:
		// 1. inside an export specifier
		// 2. inside a function
		// 3. inside an instance property initializer, a reference to a non-instance property
		//    (except when emitStandardClassFields: true and the reference is to a parameter property)
		// 4. inside a static property initializer, a reference to a static method in the same class
		// 5. inside a TS export= declaration (since we will move the export statement during emit to avoid TDZ)
		if (Ast.IsExportSpecifier(usage.Parent) || Ast.IsExportAssignment(usage.Parent) && usage.Parent.AsExportAssignment().IsExportEquals) {
			// export specifiers do not use the variable, they only make it available for use
			return true;
		}
		// When resolving symbols for exports, the `usage` location passed in can be the export site directly
		if (Ast.IsExportAssignment(usage) && usage.AsExportAssignment().IsExportEquals) {
			return true;
		}
		if (c.isUsedInFunctionOrInstanceProperty(usage, declaration, declContainer)) {
			if (c.emitStandardClassFields && Ast.GetContainingClass(declaration) != null
				&& (Ast.IsPropertyDeclaration(declaration) || Ast.IsParameterPropertyDeclaration(declaration, declaration.Parent))) {
				return !Checker.isPropertyImmediatelyReferencedWithinDeclaration(declaration, usage, true /*stopAtAnyPropertyDeclaration*/);
			}
			return true;
		}
		return false;
	}

	static function isUsedInFunctionOrInstanceProperty(c:Checker, usage:Node, declaration:Node, declContainer:Node):Bool {
		return Ast.FindAncestorOrQuit(usage, (current:Node) -> {
			if (current == declContainer) {
				return FindAncestorQuit;
			}
			if (Ast.IsFunctionLike(current)) {
				return Ast.ToFindAncestorResult(Ast.GetImmediatelyInvokedFunctionExpression(current) == null);
			}
			if (Ast.IsClassStaticBlockDeclaration(current)) {
				return Ast.ToFindAncestorResult(declaration.Pos() < usage.Pos());
			}

			if (current.Parent != null && Ast.IsPropertyDeclaration(current.Parent)) {
				final propertyDeclaration = current.Parent;
				final initializerOfProperty = propertyDeclaration.Initializer() == current;
				if (initializerOfProperty) {
					if (Ast.IsStatic(current.Parent)) {
						if (Ast.IsMethodDeclaration(declaration)) {
							return FindAncestorTrue;
						}
						if (Ast.IsPropertyDeclaration(declaration) && Ast.GetContainingClass(usage) == Ast.GetContainingClass(declaration)) {
							final propName = declaration.Name();
							if (Ast.IsIdentifier(propName) || Ast.IsPrivateIdentifier(propName)) {
								final t = c.getTypeOfSymbol(c.getSymbolOfDeclaration(declaration));
								final staticBlocks = Core.Filter(declaration.Parent.Members(), Ast.IsClassStaticBlockDeclaration);
								if (c.isPropertyInitializedInStaticBlocks(propName, t, staticBlocks, declaration.Parent.Pos(), current.Pos())) {
									return FindAncestorTrue;
								}
							}
						}
					} else {
						final isDeclarationInstanceProperty = Ast.IsPropertyDeclaration(declaration) && !Ast.IsStatic(declaration);
						if (!isDeclarationInstanceProperty || Ast.GetContainingClass(usage) != Ast.GetContainingClass(declaration)) {
							return FindAncestorTrue;
						}
					}
				}
			}

			if (current.Parent != null && Ast.IsDecorator(current.Parent)) {
				final decorator = current.Parent.AsDecorator();
				if (decorator.Expression == current) {
					if (Ast.IsParameterDeclaration(decorator.Parent)) {
						if (c.isUsedInFunctionOrInstanceProperty(decorator.Parent.Parent.Parent, declaration, declContainer)) {
							return FindAncestorTrue;
						}
						return FindAncestorQuit;
					}
					if (Ast.IsMethodDeclaration(decorator.Parent)) {
						if (c.isUsedInFunctionOrInstanceProperty(decorator.Parent.Parent, declaration, declContainer)) {
							return FindAncestorTrue;
						}
						return FindAncestorQuit;
					}
				}
			}

			return FindAncestorFalse;
		}) != null;
	}

	// Return the type-only declaration node (if any) for the given alias symbol (non-transitively)
	static function getTypeOnlyAliasDeclaration(c:Checker, symbol:Symbol):Node {
		if (symbol.Flags & SymbolFlagsAlias != 0) {
			c.resolveAlias(symbol);
			return c.aliasSymbolLinks.Get(symbol).typeOnlyDeclaration;
		}
		return null;
	}

	// Return the first type-only alias declaration node (if any) in the resolution chain that affects
	// the symbol for the given meaning
	static function getTypeOnlyAliasDeclarationEx(c:Checker, symbol:Symbol, meaning:SymbolFlags):Node {
		while (symbol.Flags & SymbolFlagsAlias != 0 && symbol.Flags & meaning == 0) {
			final resolved = c.resolveAlias(symbol);
			final links = c.aliasSymbolLinks.Get(symbol);
			if (links.typeOnlyDeclaration != null) {
				return links.typeOnlyDeclaration;
			}
			symbol = resolved;
		}
		return null;
	}

	static function getImmediateAliasedSymbol(c:Checker, symbol:Symbol):Symbol {
		Debug.Assert(symbol.Flags & SymbolFlagsAlias != 0, "Should only get Alias here.");
		final links = c.aliasSymbolLinks.Get(symbol);
		if (links.immediateTarget == null) {
			final node = c.getDeclarationOfAliasSymbol(symbol);
			if (node == null) {
				throw "Unexpected nil in getImmediateAliasedSymbol";
			}
			links.immediateTarget = c.getTargetOfAliasDeclaration(node);
		}
		return links.immediateTarget;
	}

	static function addTypeOnlyDeclarationRelatedInfo(c:Checker, diagnostic:Diagnostic, typeOnlyDeclaration:Node, name:std.String):Diagnostic {
		if (typeOnlyDeclaration == null) {
			return diagnostic;
		}
		final isExport = Ast.IsExportSpecifier(typeOnlyDeclaration) || Ast.IsExportDeclaration(typeOnlyDeclaration)
			|| Ast.IsNamespaceExport(typeOnlyDeclaration);
		return diagnostic.AddRelatedInfo(Checker.NewDiagnosticForNode(typeOnlyDeclaration,
			Core.IfElse(isExport, Diagnostics.X_0_was_exported_here, Diagnostics.X_0_was_imported_here), name));
	}

	static function getSymbol(c:Checker, symbols:SymbolTable, name:std.String, meaning:SymbolFlags):Symbol {
		if (meaning & SymbolFlagsAll != 0) {
			final symbol = c.getMergedSymbol(symbols != null ? symbols.get(name) : null);
			if (symbol != null) {
				if (symbol.Flags & meaning != 0) {
					return symbol;
				}
				if (symbol.Flags & SymbolFlagsAlias != 0) {
					final targetFlags = c.getSymbolFlags(symbol);
					// `targetFlags` will be `SymbolFlags.All` if an error occurred in alias resolution; this avoids cascading errors
					if (targetFlags & meaning != 0) {
						return symbol;
					}
				}
			}
		}
		// return nil if we can't find a symbol
		return null;
	}

	static function checkSourceFile(c:Checker, ctx:Context, sourceFile:SourceFile, checkUnused:Bool):Void {
		c.ctx = ctx;
		final links = c.sourceFileLinks.Get(sourceFile);
		// PORT: defer — the tracer pop runs at the end of the function (success path).
		var popTrace:() -> Void = null;
		if (!links.typeChecked) {
			c.saveDeferredDiagnostics = true;
			final tr = c.tracer;
			if (tr != null) {
				final args = new StringMap<Any>();
				args.set("path", sourceFile.FileName());
				popTrace = tr.Push(PhaseCheck, "checkSourceFile", args, true);
			}
			// Grammar checking
			c.checkGrammarSourceFile(sourceFile);
			c.renamedBindingElementsInTypes = null;
			c.checkSourceElements(sourceFile.Statements.Nodes);
			c.checkDeferredNodes(sourceFile);
			if (Ast.IsExternalOrCommonJSModule(sourceFile)) {
				c.checkExternalModuleExports(sourceFile.AsNode());
				c.registerForUnusedIdentifiersCheck(sourceFile.AsNode());
			}
			if (!sourceFile.IsDeclarationFile && !c.isCanceled()) {
				c.checkUnusedRenamedBindingElements();
			}
			c.saveDeferredDiagnostics = false;
			c.produceDeferredDiagnostics();
			c.reportedUnreachableNodes.Clear();
			links.typeChecked = true;
		}
		if (checkUnused && !links.unusedChecked) {
			// The unused identifiers check relies on a full type check having first been performed
			if (!sourceFile.IsDeclarationFile && !c.isCanceled()) {
				c.checkUnusedIdentifiers(links.identifierCheckNodes);
			}
			links.unusedChecked = true;
		}
		if (c.isCanceled()) {
			c.wasCanceled = true;
		}
		c.ctx = null;
		if (popTrace != null) {
			popTrace();
		}
	}

	static function checkSourceElements(c:Checker, nodes:Array<Node>):Void {
		if (nodes == null) {
			return;
		}
		for (node in nodes) {
			if (c.isCanceled()) {
				break;
			}
			c.checkSourceElement(node);
		}
	}

	static function checkSourceElement(c:Checker, node:Node):Bool {
		if (node != null) {
			final saveCurrentNode = c.currentNode;
			final saveWithinUnreachableCode = c.withinUnreachableCode;
			c.currentNode = node;
			c.instantiationCount = 0;
			c.checkSourceElementWorker(node);
			c.currentNode = saveCurrentNode;
			c.withinUnreachableCode = saveWithinUnreachableCode;
		}
		return false;
	}

	static function checkSourceElementWorker(c:Checker, node:Node):Void {
		final jsdocs = node.EagerJSDoc(null);
		if (jsdocs != null) {
			for (jsdoc in jsdocs) {
				c.checkJSDocComments(jsdoc);
				final tags = jsdoc.AsJSDoc().Tags;
				if (tags != null) {
					for (tag in tags.Nodes) {
						c.checkJSDocComments(tag);
					}
				}
			}
		}

		if (!c.withinUnreachableCode && c.compilerOptions.AllowUnreachableCode != TSTrue) {
			if (c.checkSourceElementUnreachable(node)) {
				c.withinUnreachableCode = true;
			}
		}

		switch (node.Kind) {
			case KindTypeParameter:
				c.checkTypeParameter(node);
			case KindParameter:
				c.checkParameter(node);
			case KindPropertyDeclaration:
				c.checkPropertyDeclaration(node);
			case KindPropertySignature:
				c.checkPropertySignature(node);
			case KindConstructorType | KindFunctionType | KindCallSignature | KindConstructSignature | KindIndexSignature:
				c.checkSignatureDeclaration(node);
			case KindMethodDeclaration | KindMethodSignature:
				c.checkMethodDeclaration(node);
			case KindClassStaticBlockDeclaration:
				c.checkClassStaticBlockDeclaration(node);
			case KindConstructor:
				c.checkConstructorDeclaration(node);
			case KindGetAccessor | KindSetAccessor:
				c.checkAccessorDeclaration(node);
			case KindTypeReference:
				c.checkTypeReferenceNode(node);
			case KindTypePredicate:
				c.checkTypePredicate(node);
			case KindTypeQuery:
				c.checkTypeQuery(node);
			case KindTypeLiteral:
				c.checkTypeLiteral(node);
			case KindArrayType:
				c.checkArrayType(node);
			case KindTupleType:
				c.checkTupleType(node);
			case KindUnionType | KindIntersectionType:
				c.checkUnionOrIntersectionType(node);
			case KindParenthesizedType | KindOptionalType | KindRestType:
				node.ForEachChild(c.checkSourceElement);
			case KindThisType:
				c.checkThisType(node);
			case KindTypeOperator:
				c.checkTypeOperator(node);
			case KindConditionalType:
				c.checkConditionalType(node);
			case KindInferType:
				c.checkInferType(node);
			case KindTemplateLiteralType:
				c.checkTemplateLiteralType(node);
			case KindImportType:
				c.checkImportType(node);
			case KindNamedTupleMember:
				c.checkNamedTupleMember(node);
			case KindIndexedAccessType:
				c.checkIndexedAccessType(node);
			case KindMappedType:
				c.checkMappedType(node);
			case KindFunctionDeclaration:
				c.checkFunctionDeclaration(node);
			case KindBlock | KindModuleBlock:
				c.checkBlock(node);
			case KindVariableStatement:
				c.checkVariableStatement(node);
			case KindExpressionStatement:
				c.checkExpressionStatement(node);
			case KindIfStatement:
				c.checkIfStatement(node);
			case KindDoStatement:
				c.checkDoStatement(node);
			case KindWhileStatement:
				c.checkWhileStatement(node);
			case KindForStatement:
				c.checkForStatement(node);
			case KindForInStatement:
				c.checkForInStatement(node);
			case KindForOfStatement:
				c.checkForOfStatement(node);
			case KindContinueStatement | KindBreakStatement:
				c.checkBreakOrContinueStatement(node);
			case KindReturnStatement:
				c.checkReturnStatement(node);
			case KindWithStatement:
				c.checkWithStatement(node);
			case KindSwitchStatement:
				c.checkSwitchStatement(node);
			case KindLabeledStatement:
				c.checkLabeledStatement(node);
			case KindThrowStatement:
				c.checkThrowStatement(node);
			case KindTryStatement:
				c.checkTryStatement(node);
			case KindVariableDeclaration:
				c.checkVariableDeclaration(node);
			case KindBindingElement:
				c.checkBindingElement(node);
			case KindClassDeclaration:
				c.checkClassDeclaration(node);
			case KindInterfaceDeclaration:
				c.checkInterfaceDeclaration(node);
			case KindTypeAliasDeclaration | KindJSTypeAliasDeclaration:
				c.checkTypeAliasDeclaration(node);
			case KindEnumDeclaration:
				c.checkEnumDeclaration(node);
			case KindEnumMember:
				c.checkEnumMember(node);
			case KindModuleDeclaration:
				c.checkModuleDeclaration(node);
			case KindImportDeclaration | KindJSImportDeclaration:
				c.checkImportDeclaration(node);
			case KindImportEqualsDeclaration:
				c.checkImportEqualsDeclaration(node);
			case KindExportDeclaration:
				c.checkExportDeclaration(node);
			case KindExportAssignment:
				c.checkExportAssignment(node);
			case KindEmptyStatement:
				c.checkGrammarStatementInAmbientContext(node);
			case KindDebuggerStatement:
				c.checkGrammarStatementInAmbientContext(node);
			case KindMissingDeclaration:
				c.checkMissingDeclaration(node);
			case KindJSDocNonNullableType | KindJSDocNullableType | KindJSDocAllType | KindJSDocTypeLiteral:
				c.checkJSDocType(node);
			default:
		}
	}

	static function checkSourceElementUnreachable(c:Checker, node:Node):Bool {
		if (!Ast.IsPotentiallyExecutableNode(node)) {
			return false;
		}

		if (c.reportedUnreachableNodes.Has(node)) {
			return true;
		}

		if (!c.isSourceElementUnreachable(node)) {
			return false;
		}

		c.reportedUnreachableNodes.Add(node);

		final sourceFile = Ast.GetSourceFileOfNode(node);

		var startNode = node;
		var endNode = node;

		final parent = node.Parent;
		if (parent.CanHaveStatements()) {
			final statements = parent.Statements();
			final offset = statements != null ? statements.indexOf(node) : -1;
			if (offset >= 0) {
				// Scan backwards to find the first unreachable unreported node;
				// this may happen when producing region diagnostics where not all nodes
				// will have been visited.
				// TODO: enable this code once we support region diagnostics again.
				final first = offset;
				// for i := offset - 1; i >= 0; i-- {
				// 	prevNode := statements[i]
				// 	if !ast.IsPotentiallyExecutableNode(prevNode) || c.reportedUnreachableNodes.Has(prevNode) || !c.isSourceElementUnreachable(prevNode) {
				// 		break
				// 	}
				// 	firstUnreachableIndex = i
				// 	c.reportedUnreachableNodes.Add(prevNode)
				// }

				var last = offset;
				var i = offset + 1;
				while (i < statements.length) {
					final nextNode = statements[i];
					if (!Ast.IsPotentiallyExecutableNode(nextNode) || !c.isSourceElementUnreachable(nextNode)) {
						break;
					}
					last = i;
					c.reportedUnreachableNodes.Add(nextNode);
					i++;
				}

				startNode = statements[first];
				endNode = statements[last];
			}
		}

		final start = Scanner.GetTokenPosOfNode(startNode, sourceFile, false /*includeJSDoc*/);

		final diagnostic = Ast.NewDiagnostic(sourceFile, Core.NewTextRange(start, endNode.End()), Diagnostics.Unreachable_code_detected);
		c.addErrorOrSuggestion(c.compilerOptions.AllowUnreachableCode == TSFalse, diagnostic);

		return true;
	}

	static function isSourceElementUnreachable(c:Checker, node:Node):Bool {
		// Precondition: ast.IsPotentiallyExecutableNode is true
		if (node.Flags & NodeFlagsUnreachable != 0) {
			// The binder has determined that this code is unreachable.
			// Ignore const enums unless preserveConstEnums is set.
			switch (node.Kind) {
				case KindEnumDeclaration:
					return !Ast.IsEnumConst(node) || c.compilerOptions.ShouldPreserveConstEnums();
				case KindModuleDeclaration:
					return Ast.IsInstantiatedModule(node, c.compilerOptions.ShouldPreserveConstEnums());
				default:
					return true;
			}
		} else {
			final flowNode = node.FlowNodeData().FlowNode;
			if (flowNode != null) {
				// For code the binder doesn't know is unreachable, use control flow / types.
				return !c.isReachableFlowNode(flowNode);
			}
		}
		return false;
	}

	// Function and class expression bodies are checked after all statements in the enclosing body. This is
	// to ensure constructs like the following are permitted:
	//
	//	const foo = function () {
	//	   const s = foo();
	//	   return "hello";
	//	}
	//
	// Here, performing a full type check of the body of the function expression whilst in the process of
	// determining the type of foo would cause foo to be given type any because of the recursive reference.
	// Delaying the type check of the body ensures foo has been assigned a type.
	static function checkNodeDeferred(c:Checker, node:Node):Void {
		final enclosingFile = Ast.GetSourceFileOfNode(node);
		final links = c.sourceFileLinks.Get(enclosingFile);
		if (!links.typeChecked) {
			links.deferredNodes.Add(node);
		}
	}

	static function checkDeferredNodes(c:Checker, context:SourceFile):Void {
		final links = c.sourceFileLinks.Get(context);
		for (node in links.deferredNodes.Values()) {
			if (c.isCanceled()) {
				break;
			}
			c.checkDeferredNode(node);
		}
		links.deferredNodes.Clear();
	}

	static function checkDeferredNode(c:Checker, node:Node):Void {
		// PORT: defer — the tracer pop runs at the end of the function (success path).
		var popTrace:() -> Void = null;
		final tr = c.tracer;
		if (tr != null) {
			final args = new StringMap<Any>();
			args.set("kind", node.Kind);
			args.set("pos", node.Pos());
			args.set("end", node.End());
			args.set("path", Ast.GetSourceFileOfNode(node).FileName());
			popTrace = tr.Push(PhaseCheck, "checkDeferredNode", args, false);
		}
		final saveCurrentNode = c.currentNode;
		c.currentNode = node;
		c.instantiationCount = 0;
		switch (node.Kind) {
			case KindCallExpression | KindNewExpression | KindTaggedTemplateExpression | KindDecorator | KindJsxOpeningElement:
				// These node kinds are deferred checked when overload resolution fails. To save on work,
				// we ensure the arguments are checked just once in a deferred way.
				c.resolveUntypedCall(node);
			case KindFunctionExpression | KindArrowFunction | KindMethodDeclaration | KindMethodSignature:
				c.checkFunctionExpressionOrObjectLiteralMethodDeferred(node);
			case KindGetAccessor | KindSetAccessor:
				c.checkAccessorDeclaration(node);
			case KindClassExpression:
				c.checkClassExpressionDeferred(node);
			case KindTypeParameter:
				c.checkTypeParameterDeferred(node);
			case KindJsxSelfClosingElement:
				c.checkJsxSelfClosingElementDeferred(node);
			case KindJsxElement:
				c.checkJsxElementDeferred(node);
			case KindTypeAssertionExpression | KindAsExpression:
				c.checkAssertionDeferred(node);
			case KindVoidExpression:
				c.checkExpression(node.Expression());
			case KindBinaryExpression:
				if (Ast.IsInstanceOfExpression(node)) {
					c.resolveUntypedCall(node);
				}
			default:
		}
		c.currentNode = saveCurrentNode;
		if (popTrace != null) {
			popTrace();
		}
	}

	static function checkJSDocComments(c:Checker, node:Node):Void {
		final comments = node.Comments();
		if (comments != null) {
			for (comment in comments) {
				c.checkJSDocComment(comment);
			}
		}
	}

	static function checkJSDocComment(c:Checker, node:Node):Void {
		// This performs minimal checking of JSDoc nodes to ensure that @link references to entities are recorded
		// for purposes of checking unused identifiers.
		switch (node.Kind) {
			case KindJSDocLink | KindJSDocLinkCode | KindJSDocLinkPlain:
				c.resolveJSDocMemberName(node.Name());
			default:
		}
	}

	static function resolveJSDocMemberName(c:Checker, name:Node):Symbol {
		if (name != null && Ast.IsEntityName(name)) {
			final meaning = SymbolFlagsType | SymbolFlagsNamespace | SymbolFlagsValue;
			final symbol = c.resolveEntityName(name, meaning, true /*ignoreErrors*/, true /*dontResolveAlias*/, Ast.GetHostSignatureFromJSDoc(name));
			if (symbol != null) {
				return symbol;
			}
			if (Ast.IsQualifiedName(name)) {
				final symbol = c.resolveJSDocMemberName(name.AsQualifiedName().Left);
				if (symbol != null) {
					var t:Type = null;
					if (symbol.Flags & SymbolFlagsValue != 0) {
						final proto = c.getPropertyOfType(c.getTypeOfSymbol(symbol), "prototype");
						if (proto != null) {
							t = c.getTypeOfSymbol(proto);
						}
					}
					if (t == null) {
						t = c.getDeclaredTypeOfSymbol(symbol);
					}
					return c.getPropertyOfType(t, name.AsQualifiedName().Right.Text());
				}
			}
		}
		return null;
	}

	static function checkJSDocType(c:Checker, node:Node):Void {
		c.checkJSDocTypeIsInJsFile(node);
		node.ForEachChild(c.checkSourceElement);
	}

	static function checkJSDocTypeIsInJsFile(c:Checker, node:Node):Void {
		if (!Ast.IsInJSFile(node)) {
			if (Ast.IsJSDocNonNullableType(node) || Ast.IsJSDocNullableType(node)) {
				final token = Core.IfElse(Ast.IsJSDocNonNullableType(node), "!", "?");
				final postfix = node.Pos() == node.Type().Pos();
				final message = Core.IfElse(postfix, Diagnostics.X_0_at_the_end_of_a_type_is_not_valid_TypeScript_syntax_Did_you_mean_to_write_1,
					Diagnostics.X_0_at_the_start_of_a_type_is_not_valid_TypeScript_syntax_Did_you_mean_to_write_1);
				var t = c.getTypeFromTypeNode(node.Type());
				if (Ast.IsJSDocNullableType(node) && t != c.neverType && t != c.voidType) {
					t = c.getNullableType(t, Core.IfElse(postfix, TypeFlagsUndefined, TypeFlagsNullable));
				}
				c.grammarErrorOnNode(node, message, token, c.TypeToString(t));
			} else {
				c.grammarErrorOnNode(node, Diagnostics.JSDoc_types_can_only_be_used_inside_documentation_comments);
			}
		}
	}

	static function checkTypeParameter(c:Checker, node:Node):Void {
		// Grammar Checking
		c.checkGrammarModifiers(node);
		final expr = node.AsTypeParameterDeclaration().Expression;
		if (expr != null) {
			c.grammarErrorOnFirstToken(expr, Diagnostics.Type_expected);
		}
		final tpNode = node.AsTypeParameterDeclaration();
		c.checkSourceElement(tpNode.Constraint);
		c.checkSourceElement(tpNode.DefaultType);
		final typeParameter = c.getDeclaredTypeOfTypeParameter(c.getSymbolOfDeclaration(node));
		// Resolve base constraint to reveal circularity errors
		c.getBaseConstraintOfType(typeParameter);
		if (c.getResolvedTypeParameterDefault(typeParameter) == c.circularConstraintType) {
			c.error(tpNode.DefaultType, Diagnostics.Type_parameter_0_has_a_circular_default, c.TypeToString(typeParameter));
		}
		final constraintType = c.getConstraintOfTypeParameter(typeParameter);
		final defaultType = c.getDefaultFromTypeParameter(typeParameter);
		if (constraintType != null && defaultType != null) {
			c.checkTypeAssignableTo(defaultType,
				c.getTypeWithThisArgument(c.instantiateType(constraintType, Checker.newSimpleTypeMapper(typeParameter, defaultType)), defaultType, false),
				tpNode.DefaultType, Diagnostics.Type_0_does_not_satisfy_the_constraint_1);
		}
		c.checkTypeNameIsReserved(node.Name(), Diagnostics.Type_parameter_name_cannot_be_0);
		c.checkNodeDeferred(node);
	}

	static function checkTypeParameterDeferred(c:Checker, node:Node):Void {
		if (Ast.IsInterfaceDeclaration(node.Parent) || Ast.IsClassLike(node.Parent) || Ast.IsTypeOrJSTypeAliasDeclaration(node.Parent)) {
			final typeParameter = c.getDeclaredTypeOfTypeParameter(c.getSymbolOfDeclaration(node));
			final modifiers = c.getTypeParameterModifiers(typeParameter) & (ModifierFlagsIn | ModifierFlagsOut);
			if (modifiers != 0) {
				final symbol = c.getSymbolOfDeclaration(node.Parent);
				if (Ast.IsTypeOrJSTypeAliasDeclaration(node.Parent)
					&& c.getDeclaredTypeOfSymbol(symbol).objectFlags & (ObjectFlagsAnonymous | ObjectFlagsMapped) == 0) {
					c.error(node,
						Diagnostics.Variance_annotations_are_only_supported_in_type_aliases_for_object_function_constructor_and_mapped_types);
				} else if (modifiers == ModifierFlagsIn || modifiers == ModifierFlagsOut) {
					// PORT: defer — the tracer pop runs at the end of this block (the end of the function).
					var popTrace:() -> Void = null;
					final tr = c.tracer;
					if (tr != null) {
						final args = new StringMap<Any>();
						args.set("parent", c.getDeclaredTypeOfSymbol(symbol).id);
						args.set("id", typeParameter.id);
						popTrace = tr.Push(PhaseCheckTypes, "checkTypeParameterDeferred", args, false);
					}
					final source = c.createMarkerType(symbol, typeParameter,
						Core.IfElse(modifiers == ModifierFlagsOut, c.markerSubTypeForCheck, c.markerSuperTypeForCheck));
					final target = c.createMarkerType(symbol, typeParameter,
						Core.IfElse(modifiers == ModifierFlagsOut, c.markerSuperTypeForCheck, c.markerSubTypeForCheck));
					final saveVarianceTypeParameter = typeParameter;
					c.varianceTypeParameter = typeParameter;
					c.checkTypeAssignableTo(source, target, node, Diagnostics.Type_0_is_not_assignable_to_type_1_as_implied_by_variance_annotation);
					c.varianceTypeParameter = saveVarianceTypeParameter;
					if (popTrace != null) {
						popTrace();
					}
				}
			}
		}
	}

	static function shouldCheckErasableSyntax(c:Checker, node:Node):Bool {
		return c.compilerOptions.ErasableSyntaxOnly.IsTrue() && !Ast.IsInJSFile(node);
	}

	static function checkParameter(c:Checker, node:Node):Void {
		// Grammar checking
		// It is a SyntaxError if the Identifier "eval" or the Identifier "arguments" occurs as the
		// Identifier in a PropertySetParameterList of a PropertyAssignment that is contained in strict code
		// or if its FunctionBody is strict code(11.1.5).
		c.checkGrammarModifiers(node);
		c.checkVariableLikeDeclaration(node);
		final fn = Ast.GetContainingFunction(node);
		var paramName = "";
		if (node.Name() != null && Ast.IsIdentifier(node.Name())) {
			paramName = node.Name().Text();
		}
		if (Ast.HasSyntacticModifier(node, ModifierFlagsParameterPropertyModifier)) {
			if (c.shouldCheckErasableSyntax(node)) {
				c.error(node, Diagnostics.This_syntax_is_not_allowed_when_erasableSyntaxOnly_is_enabled);
			}
			if (!(Ast.IsConstructorDeclaration(fn) && Ast.NodeIsPresent(fn.Body()))) {
				c.error(node, Diagnostics.A_parameter_property_is_only_allowed_in_a_constructor_implementation);
			}
			if (Ast.IsConstructorDeclaration(fn) && paramName == "constructor") {
				c.error(node.Name(), Diagnostics.X_constructor_cannot_be_used_as_a_parameter_property_name);
			}
		}
		if (node.Initializer() == null && Checker.isOptionalDeclaration(node) && Ast.IsBindingPattern(node.Name()) && fn.Body() != null) {
			c.error(node, Diagnostics.A_binding_pattern_parameter_cannot_be_optional_in_an_implementation_signature);
		}
		if (paramName == "this" || paramName == "new") {
			final params = fn.Parameters();
			if ((params != null ? params.indexOf(node) : -1) != 0) {
				c.error(node, Diagnostics.A_0_parameter_must_be_the_first_parameter, paramName);
			}
			if (Ast.IsConstructorDeclaration(fn) || Ast.IsConstructSignatureDeclaration(fn) || Ast.IsConstructorTypeNode(fn)) {
				c.error(node, Diagnostics.A_constructor_cannot_have_a_this_parameter);
			}
			if (Ast.IsArrowFunction(fn)) {
				c.error(node, Diagnostics.An_arrow_function_cannot_have_a_this_parameter);
			}
			if (Ast.IsAccessor(fn)) {
				c.error(node, Diagnostics.X_get_and_set_accessors_cannot_declare_this_parameters);
			}
		}
		// Only check rest parameter type if it's not a binding pattern. Since binding patterns are
		// not allowed in a rest parameter, we already have an error from checkGrammarParameterList.
		if (Checker.hasDotDotDotToken(node) && !Ast.IsBindingPattern(node.Name())
			&& !c.isTypeAssignableTo(c.getReducedType(c.getTypeOfSymbol(node.Symbol())), c.anyReadonlyArrayType)) {
			c.error(node, Diagnostics.A_rest_parameter_must_be_of_an_array_type);
		}
	}

	static function checkPropertyDeclaration(c:Checker, node:Node):Void {
		// Grammar checking
		if (!c.checkGrammarModifiers(node) && !c.checkGrammarProperty(node)) {
			c.checkGrammarComputedPropertyName(node.Name());
		}
		c.checkVariableLikeDeclaration(node);
		c.setNodeLinksForPrivateIdentifierScope(node);
		// property signatures already report "initializer not allowed in ambient context" elsewhere
		if (Ast.HasSyntacticModifier(node, ModifierFlagsAbstract) && Ast.IsPropertyDeclaration(node)) {
			if (node.Initializer() != null) {
				c.error(node, Diagnostics.Property_0_cannot_have_an_initializer_because_it_is_marked_abstract, Scanner.DeclarationNameToString(node.Name()));
			}
		}
	}

	static function checkPropertySignature(c:Checker, node:Node):Void {
		if (Ast.IsPrivateIdentifier(node.AsPropertySignatureDeclaration().Name())) {
			c.error(node, Diagnostics.Private_identifiers_are_not_allowed_outside_class_bodies);
		}
		c.checkPropertyDeclaration(node);
	}

	static function checkSignatureDeclaration(c:Checker, node:Node):Void {
		// Grammar checking
		switch (node.Kind) {
			case KindIndexSignature:
				c.checkGrammarIndexSignature(node.AsIndexSignatureDeclaration());
			case KindFunctionType | KindFunctionDeclaration | KindConstructorType | KindCallSignature | KindConstructor | KindConstructSignature:
				c.checkGrammarFunctionLikeDeclaration(node);
			default:
		}
		final functionFlags = Ast.GetFunctionFlags(node);
		if (functionFlags & FunctionFlagsInvalid == 0) {
			// Async generators prior to ES2018 require the __await and __asyncGenerator helpers
			if (functionFlags & FunctionFlagsAsyncGenerator == FunctionFlagsAsyncGenerator
				&& (c.languageVersion : Int) < (Checker.LanguageFeatureMinimumTarget.AsyncGenerators : Int)) {
				c.checkExternalEmitHelpers(node, ExternalEmitHelpersAsyncGeneratorIncludes);
			}
			if (functionFlags & FunctionFlagsAsyncGenerator == FunctionFlagsAsync
				&& (c.languageVersion : Int) < (Checker.LanguageFeatureMinimumTarget.AsyncFunctions : Int)) {
				c.checkExternalEmitHelpers(node, ExternalEmitHelpersAwaiter);
			}
		}
		c.checkTypeParameters(node.TypeParameters());
		c.checkUnmatchedJSDocParameters(node);
		c.checkSourceElements(node.Parameters());
		final returnTypeNode = node.Type();
		if (returnTypeNode != null) {
			c.checkSourceElement(returnTypeNode);
		}
		if (c.noImplicitAny && returnTypeNode == null) {
			switch (node.Kind) {
				case KindConstructSignature:
					c.error(node, Diagnostics.Construct_signature_which_lacks_return_type_annotation_implicitly_has_an_any_return_type);
				case KindCallSignature:
					c.error(node, Diagnostics.Call_signature_which_lacks_return_type_annotation_implicitly_has_an_any_return_type);
				default:
			}
		}
		if (returnTypeNode != null) {
			if ((functionFlags & (FunctionFlagsInvalid | FunctionFlagsGenerator)) == FunctionFlagsGenerator) {
				final returnType = c.getTypeFromTypeNode(returnTypeNode);
				if (returnType == c.voidType) {
					c.error(returnTypeNode, Diagnostics.A_generator_cannot_have_a_void_type_annotation);
				} else {
					c.checkGeneratorInstantiationAssignabilityToReturnType(returnType, functionFlags, returnTypeNode);
				}
			} else if ((functionFlags & FunctionFlagsAsyncGenerator) == FunctionFlagsAsync) {
				c.checkAsyncFunctionReturnType(node, returnTypeNode);
			}
		}
		if (!Ast.IsIndexSignatureDeclaration(node)) {
			c.registerForUnusedIdentifiersCheck(node);
		}
	}

	// Checks the return type of an async function to ensure it is a compatible
	// Promise implementation.
	//
	// This checks that an async function has a valid Promise-compatible return type.
	// An async function has a valid Promise-compatible return type if the resolved value
	// of the return type has a construct signature that takes in an `initializer` function
	// that in turn supplies a `resolve` function as one of its arguments and results in an
	// object with a callable `then` signature.
	static function checkAsyncFunctionReturnType(c:Checker, node:Node, returnTypeNode:Node):Void {
		final returnType = c.getTypeFromTypeNode(returnTypeNode);
		if (c.isErrorType(returnType)) {
			return;
		}
		final globalPromiseType = c.getGlobalPromiseTypeChecked();
		if (globalPromiseType != c.emptyGenericType && !c.isReferenceToType(returnType, globalPromiseType)) {
			// The promise type was not a valid type reference to the global promise type, so we
			// report an error and return the unknown type.
			c.error(returnTypeNode,
				Diagnostics.The_return_type_of_an_async_function_or_method_must_be_the_global_Promise_T_type_Did_you_mean_to_write_Promise_0,
				c.TypeToString(Core.OrElse(c.getAwaitedTypeNoAlias(returnType), c.voidType)));
			return;
		}
		c.checkAwaitedType(returnType, false /*withAlias*/, node,
			Diagnostics.The_return_type_of_an_async_function_must_either_be_a_valid_promise_or_must_not_contain_a_callable_then_member);
	}

	static function checkMethodDeclaration(c:Checker, node:Node):Void {
		// Grammar checking
		if (!c.checkGrammarMethod(node)) {
			c.checkGrammarComputedPropertyName(node.Name());
			if (Ast.IsMethodDeclaration(node) && node.AsMethodDeclaration().AsteriskToken != null && Ast.IsIdentifier(node.Name())
				&& node.Name().Text() == "constructor") {
				c.error(node.Name(), Diagnostics.Class_constructor_may_not_be_a_generator);
			}
		}
		// Grammar checking for modifiers is done inside the function checkGrammarFunctionLikeDeclaration
		c.checkFunctionOrMethodDeclaration(node);
		// method signatures already report "implementation not allowed in ambient context" elsewhere
		if (Ast.HasSyntacticModifier(node, ModifierFlagsAbstract) && Ast.IsMethodDeclaration(node) && node.Body() != null) {
			c.error(node, Diagnostics.Method_0_cannot_have_an_implementation_because_it_is_marked_abstract, Scanner.DeclarationNameToString(node.Name()));
		}
		// Private named methods are only allowed in class declarations
		if (Ast.IsPrivateIdentifier(node.Name()) && Ast.GetContainingClass(node) == null) {
			c.error(node, Diagnostics.Private_identifiers_are_not_allowed_outside_class_bodies);
		}
		c.setNodeLinksForPrivateIdentifierScope(node);
	}

	static function checkClassStaticBlockDeclaration(c:Checker, node:Node):Void {
		// Grammar checking
		c.checkGrammarModifiers(node);
		node.ForEachChild(c.checkSourceElement);
	}

	static function checkConstructorDeclaration(c:Checker, node:Node):Void {
		// Grammar check on signature of constructor and modifier of the constructor is done in checkSignatureDeclaration function.
		c.checkSignatureDeclaration(node);
		// Grammar check for checking only related to constructorDeclaration
		final ctor = node.AsConstructorDeclaration();
		if (!c.checkGrammarConstructorTypeParameters(ctor)) {
			c.checkGrammarConstructorTypeAnnotation(ctor);
		}
		c.checkSourceElement(node.Body());
		final symbol = c.getSymbolOfDeclaration(node);
		c.checkFunctionOrConstructorSymbol(symbol);
		// exit early in the case of signature - super checks are not relevant to them
		if (Ast.NodeIsMissing(node.Body())) {
			return;
		}
		// TS 1.0 spec (April 2014): 8.3.2
		// Constructors of classes with no extends clause may not contain super calls, whereas
		// constructors of derived classes must contain at least one super call somewhere in their function body.
		final containingClassDecl = node.Parent;
		if (Ast.GetExtendsHeritageClauseElement(containingClassDecl) == null) {
			return;
		}
		final classExtendsNull = c.classDeclarationExtendsNull(containingClassDecl);
		final superCall = c.findFirstSuperCall(node.Body());
		if (superCall != null) {
			if (classExtendsNull) {
				c.error(superCall, Diagnostics.A_constructor_cannot_contain_a_super_call_when_its_class_extends_null);
			}
			// A super call must be root-level in a constructor if both of the following are true:
			// - The containing class is a derived class.
			// - The constructor declares parameter properties
			//   or the containing class declares instance member variables with initializers.
			final superCallShouldBeRootLevel = !c.emitStandardClassFields
				&& (Core.Some(node.Parent.Members(), Checker.isInstancePropertyWithInitializerOrPrivateIdentifierProperty)
					|| Core.Some(node.Parameters(), (p:Node) -> {
						return Ast.HasSyntacticModifier(p, ModifierFlagsParameterPropertyModifier);
					}));
			if (superCallShouldBeRootLevel) {
				// Until we have better flow analysis, it is an error to place the super call within any kind of block or conditional
				// See GH #8277
				if (!Checker.superCallIsRootLevelInConstructor(superCall, node.Body())) {
					c.error(superCall,
						Diagnostics.A_super_call_must_be_a_root_level_statement_within_a_constructor_of_a_derived_class_that_contains_initialized_properties_parameter_properties_or_private_identifiers);
				} else {
					var superCallStatement:Node = null;
					final statements = node.Body().Statements();
					if (statements != null) {
						for (statement in statements) {
							if (Ast.IsExpressionStatement(statement) && Checker.isSuperCall(Ast.SkipOuterExpressions(statement.Expression(), OEKAll))) {
								superCallStatement = statement;
								break;
							}
							if (Checker.nodeImmediatelyReferencesSuperOrThis(statement)) {
								break;
							}
						}
					}
					// Until we have better flow analysis, it is an error to place the super call within any kind of block or conditional
					// See GH #8277
					if (superCallStatement == null) {
						c.error(node,
							Diagnostics.A_super_call_must_be_the_first_statement_in_the_constructor_to_refer_to_super_or_this_when_a_derived_class_contains_initialized_properties_parameter_properties_or_private_identifiers);
					}
				}
			}
		} else if (!classExtendsNull) {
			c.error(node, Diagnostics.Constructors_for_derived_classes_must_contain_a_super_call);
		}
	}

	static function findFirstSuperCall(c:Checker, node:Node):Node {
		var superCall:Node = null;
		var visit:(node:Node) -> Bool = null;
		visit = (node:Node) -> {
			if (Checker.isSuperCall(node)) {
				superCall = node;
				return true;
			} else if (Ast.IsFunctionLike(node)) {
				return false;
			}
			return node.ForEachChild(visit);
		};
		visit(node);
		return superCall;
	}

	static function checkAccessorDeclaration(c:Checker, node:Node):Void {
		// Grammar checking accessors
		if (!c.checkGrammarFunctionLikeDeclaration(node) && !c.checkGrammarAccessor(node)) {
			c.checkGrammarComputedPropertyName(node.Name());
		}
		final name = node.Name();
		if (Ast.IsIdentifier(name) && name.Text() == "constructor" && Ast.IsClassLike(node.Parent)) {
			c.error(node.Name(), Diagnostics.Class_constructor_may_not_be_an_accessor);
		}
		c.checkDecorators(node);
		c.checkSignatureDeclaration(node);
		if (Ast.IsGetAccessorDeclaration(node)) {
			if (node.Flags & NodeFlagsAmbient == 0 && Ast.NodeIsPresent(node.Body()) && node.Flags & NodeFlagsHasImplicitReturn != 0) {
				if (node.Flags & NodeFlagsHasExplicitReturn == 0) {
					c.error(name, Diagnostics.A_get_accessor_must_return_a_value);
				}
			}
		}
		// Do not use hasDynamicName here, because that returns false for well known symbols.
		// We want to perform checkComputedPropertyName for all computed properties, including
		// well known symbols.
		if (Ast.IsComputedPropertyName(name)) {
			c.checkComputedPropertyName(name);
		}
		if (c.hasBindableName(node)) {
			// TypeScript 1.0 spec (April 2014): 8.4.3
			// Accessors for the same member name must specify the same accessibility.
			final symbol = c.getSymbolOfDeclaration(node);
			final getter = Ast.GetDeclarationOfKind(symbol, KindGetAccessor);
			final setter = Ast.GetDeclarationOfKind(symbol, KindSetAccessor);
			if (getter != null && setter != null && c.nodeLinks.Get(getter).flags & NodeCheckFlagsTypeChecked == 0) {
				c.nodeLinks.Get(getter).flags |= NodeCheckFlagsTypeChecked;
				final getterFlags = getter.ModifierFlags();
				final setterFlags = setter.ModifierFlags();
				if ((getterFlags & ModifierFlagsAbstract) != (setterFlags & ModifierFlagsAbstract)) {
					c.error(getter.Name(), Diagnostics.Accessors_must_both_be_abstract_or_non_abstract);
					c.error(setter.Name(), Diagnostics.Accessors_must_both_be_abstract_or_non_abstract);
				}
				if (((getterFlags & ModifierFlagsProtected != 0) && setterFlags & (ModifierFlagsProtected | ModifierFlagsPrivate) == 0)
					|| ((getterFlags & ModifierFlagsPrivate != 0) && setterFlags & ModifierFlagsPrivate == 0)) {
					c.error(getter.Name(), Diagnostics.A_get_accessor_must_be_at_least_as_accessible_as_the_setter);
					c.error(setter.Name(), Diagnostics.A_get_accessor_must_be_at_least_as_accessible_as_the_setter);
				}
			}
		}
		final returnType = c.getTypeOfAccessors(c.getSymbolOfDeclaration(node));
		if (node.Kind == KindGetAccessor) {
			c.checkAllCodePathsInNonVoidFunctionReturnOrThrow(node, returnType);
		}
		c.checkSourceElement(node.Body());
		c.setNodeLinksForPrivateIdentifierScope(node);
	}

	static function checkTypeReferenceNode(c:Checker, node:Node):Void {
		c.checkGrammarTypeArguments(node, node.TypeArgumentList());
		if (Ast.IsTypeReferenceNode(node) && node.Flags & NodeFlagsJSDoc == 0) {
			final data = node.AsTypeReferenceNode();
			if (data.TypeArguments != null && data.TypeName.End() != data.TypeArguments.Pos()) {
				// If there was a token between the type name and the type arguments, check if it was a DotToken
				final sourceFile = Ast.GetSourceFileOfNode(node);
				if (Scanner.ScanTokenAtPosition(sourceFile, data.TypeName.End()) == KindDotToken) {
					c.grammarErrorAtPos(node, Scanner.SkipTrivia(sourceFile.Text(), data.TypeName.End()), 1,
						Diagnostics.JSDoc_types_can_only_be_used_inside_documentation_comments);
				}
			}
		}
		c.checkSourceElements(node.TypeArguments());
		c.checkTypeReferenceOrImport(node);
	}

	static function checkTypeReferenceOrImport(c:Checker, node:Node):Void {
		final t = c.getTypeFromTypeNode(node);
		if (!c.isErrorType(t)) {
			if (Core.len(node.TypeArguments()) != 0) {
				final typeParameters = c.getTypeParametersForTypeReferenceOrImport(node);
				if (Core.len(typeParameters) != 0) {
					c.checkTypeArgumentConstraints(node, typeParameters);
				}
			}
			final symbol = c.getResolvedSymbolOrNil(node);
			if (symbol != null) {
				if (Core.Some(symbol.Declarations, (d:Node) -> Ast.IsTypeDeclaration(d) && c.IsDeprecatedDeclaration(d))) {
					c.addDeprecatedSuggestion(c.getDeprecatedSuggestionNode(node), symbol.Declarations, symbol.Name);
				}
			}
		}
	}

	static function checkTypeArgumentConstraints(c:Checker, node:Node, typeParameters:Array<Type>):Bool {
		var typeArguments:Array<Type> = null;
		var mapper:TypeMapper = null;
		var result = true;
		for (i in 0...Core.len(typeParameters)) {
			final typeParameter = typeParameters[i];
			final constraint = c.getConstraintOfTypeParameter(typeParameter);
			if (constraint != null) {
				if (typeArguments == null) {
					typeArguments = c.getEffectiveTypeArguments(node, typeParameters);
					mapper = Checker.newTypeMapper(typeParameters, typeArguments);
				}
				result = result
					&& c.checkTypeAssignableTo(typeArguments[i], c.instantiateType(constraint, mapper), Core.ElementOrNil(node.TypeArguments(), i),
						Diagnostics.Type_0_does_not_satisfy_the_constraint_1);
			}
		}
		return result;
	}

	static function getDeprecatedSuggestionNode(c:Checker, node:Node):Node {
		node = Ast.SkipParentheses(node);
		switch (node.Kind) {
			case KindCallExpression | KindDecorator | KindNewExpression:
				return c.getDeprecatedSuggestionNode(node.Expression());
			case KindTaggedTemplateExpression:
				return c.getDeprecatedSuggestionNode(node.AsTaggedTemplateExpression().Tag);
			case KindJsxOpeningElement | KindJsxSelfClosingElement:
				return c.getDeprecatedSuggestionNode(node.TagName());
			case KindElementAccessExpression:
				return node.AsElementAccessExpression().ArgumentExpression;
			case KindPropertyAccessExpression:
				return node.Name();
			case KindTypeReference:
				final typeName = node.AsTypeReferenceNode().TypeName;
				if (Ast.IsQualifiedName(typeName)) {
					return typeName.AsQualifiedName().Right;
				}
			default:
		}
		return node;
	}

	static function checkTypePredicate(c:Checker, node:Node):Void {
		final parent = c.getTypePredicateParent(node);
		if (parent == null) {
			// The parent must not be valid.
			c.error(node, Diagnostics.A_type_predicate_is_only_allowed_in_return_type_position_for_functions_and_methods);
			return;
		}
		final signature = c.getSignatureFromDeclaration(parent);
		final typePredicate = c.getTypePredicateOfSignature(signature);
		if (typePredicate == null) {
			return;
		}
		c.checkSourceElement(node.Type());
		final parameterName = node.AsTypePredicateNode().ParameterName;
		if (typePredicate.kind != TypePredicateKindThis && typePredicate.kind != TypePredicateKindAssertsThis) {
			if (typePredicate.parameterIndex >= 0) {
				if (Checker.signatureHasRestParameter(signature) && typePredicate.parameterIndex == Core.len(signature.parameters) - 1) {
					c.error(parameterName, Diagnostics.A_type_predicate_cannot_reference_a_rest_parameter);
				} else {
					if (typePredicate.t != null) {
						final diags:Array<Diagnostic> = [];
						if (!c.checkTypeAssignableToEx(typePredicate.t, c.getTypeOfSymbol(signature.parameters[typePredicate.parameterIndex]), node.Type(),
							null /*headMessage*/, diags)) {
							c.addDiagnostic(Ast.NewDiagnosticChain(diags[0], Diagnostics.A_type_predicate_s_type_must_be_assignable_to_its_parameter_s_type));
						}
					}
				}
			} else if (parameterName != null) {
				var hasReportedError = false;
				final params = parent.Parameters();
				if (params != null) {
					for (param in params) {
						final name = param.Name();
						if (Ast.IsBindingPattern(name)
							&& c.checkIfTypePredicateVariableIsDeclaredInBindingPattern(name, parameterName, typePredicate.parameterName)) {
							hasReportedError = true;
							break;
						}
					}
				}
				if (!hasReportedError) {
					c.error(parameterName, Diagnostics.Cannot_find_parameter_0, typePredicate.parameterName);
				}
			}
		}
	}

	static function getTypePredicateParent(c:Checker, node:Node):SignatureDeclaration {
		final parent = node.Parent;
		switch (parent.Kind) {
			case KindArrowFunction | KindCallSignature | KindFunctionDeclaration | KindFunctionExpression | KindFunctionType | KindMethodDeclaration
				| KindMethodSignature:
				if (node == parent.Type()) {
					return parent;
				}
			default:
		}
		return null;
	}

	static function checkIfTypePredicateVariableIsDeclaredInBindingPattern(c:Checker, pattern:Node, predicateVariableNode:Node, predicateVariableName:std.String):Bool {
		final elements = pattern.Elements();
		if (elements != null) {
			for (element in elements) {
				final name = element.Name();
				if (name == null) {
					continue;
				}
				if (Ast.IsIdentifier(name) && name.Text() == predicateVariableName) {
					c.error(predicateVariableNode, Diagnostics.A_type_predicate_cannot_reference_element_0_in_a_binding_pattern, predicateVariableName);
					return true;
				}
				if (Ast.IsArrayBindingPattern(name) || Ast.IsObjectBindingPattern(name)) {
					if (c.checkIfTypePredicateVariableIsDeclaredInBindingPattern(name, predicateVariableNode, predicateVariableName)) {
						return true;
					}
				}
			}
		}
		return false;
	}

	static function checkTypeQuery(c:Checker, node:Node):Void {
		c.getTypeFromTypeQueryNode(node);
	}

	static function checkTypeLiteral(c:Checker, node:Node):Void {
		c.checkSourceElements(node.Members());
		final t = c.getTypeFromTypeLiteralOrFunctionOrConstructorTypeNode(node);
		c.checkIndexConstraints(t, t.symbol, false /*isStaticIndex*/);
		c.checkTypeForDuplicateIndexSignatures(node);
		c.checkObjectTypeForDuplicateDeclarations(node, false /*checkPrivateNames*/);
	}

	static function checkObjectTypeForDuplicateDeclarations(c:Checker, node:Node, checkPrivateNames:Bool):Void {
		var instanceNames:StringMap<Int> = null;
		var staticNames:StringMap<Int> = null;
		var privateNames:StringMap<Int> = null;
		final nodeInAmbientContext = node.Flags & NodeFlagsAmbient != 0;
		final checkPropertyOrAccessor = (symbol:Symbol, kind:Int, isStatic:Bool) -> {
			if (Core.len(symbol.Declarations) > 1) {
				var names:StringMap<Int> = null;
				if (isStatic) {
					if (staticNames == null) {
						staticNames = new StringMap<Int>();
					}
					names = staticNames;
				} else {
					if (instanceNames == null) {
						instanceNames = new StringMap<Int>();
					}
					names = instanceNames;
				}
				final state:Int = names.exists(symbol.Name) ? names.get(symbol.Name) : 0;
				if (state == 0) {
					// On first occurrence just record the kind
					names.set(symbol.Name, kind);
				} else if (state == 1 || state == 2 && kind != 2) {
					// Error on second property or combination of property and accessor
					c.reportDuplicateMemberErrors(node, symbol.Name, true, isStatic, Diagnostics.Duplicate_identifier_0);
					// Record that errors have been reported
					names.set(symbol.Name, 3);
				}
			}
		};
		final members = node.Members();
		if (members != null) {
			for (member in members) {
				if (Ast.IsConstructorDeclaration(member)) {
					final params = member.Parameters();
					if (params != null) {
						for (param in params) {
							if (Ast.IsParameterPropertyDeclaration(param, member) && !Ast.IsBindingPattern(param.Name())) {
								checkPropertyOrAccessor(c.getSymbolOfDeclaration(param), 1, false /*isStatic*/);
							}
						}
					}
				} else {
					final symbol = c.getSymbolOfDeclaration(member);
					final isStatic = Ast.HasStaticModifier(member);
					// In non-ambient contexts, check that static members are not named 'prototype'.
					if (!nodeInAmbientContext && isStatic && symbol != null && symbol.Name == "prototype") {
						c.error(member.Name(), Diagnostics.Static_property_0_conflicts_with_built_in_property_Function_0_of_constructor_function_1, symbol.Name,
							c.symbolToString(c.getSymbolOfDeclaration(node)));
					}
					// Check that this object type declaration doesn't contain multiple declarations of the same property,
					// or accessor and property declarations with the same name.
					if (Ast.IsPropertyDeclaration(member) && !Ast.HasAccessorModifier(member) || Ast.IsPropertySignatureDeclaration(member)) {
						checkPropertyOrAccessor(symbol, 1, isStatic);
					} else if (Ast.IsAccessor(member) || Ast.IsPropertyDeclaration(member) && Ast.HasAccessorModifier(member)) {
						checkPropertyOrAccessor(symbol, 2, isStatic);
					}
					// Check that each private identifier is used only for instance members or only for static members. It is an
					// error for an instance and a static member to have the same private identifier.
					if (checkPrivateNames && member.Name() != null && Ast.IsPrivateIdentifier(member.Name())) {
						var flags:Int = privateNames != null && privateNames.exists(symbol.Name) ? privateNames.get(symbol.Name) : 0;
						if (flags != 3) {
							flags |= Core.IfElse(Ast.IsStatic(member), 2, 1);
							if (privateNames == null) {
								privateNames = new StringMap<Int>();
							}
							privateNames.set(symbol.Name, flags);
							if (flags == 3) {
								c.reportDuplicateMemberErrors(node, symbol.Name, false, false,
									Diagnostics.Duplicate_identifier_0_Static_and_instance_elements_cannot_share_the_same_private_name);
							}
						}
					}
				}
			}
		}
	}

	static function reportDuplicateMemberErrors(c:Checker, node:Node, name:std.String, checkStatic:Bool, isStatic:Bool, message:Message):Void {
		final members = node.Members();
		if (members == null) {
			return;
		}
		for (member in members) {
			if (Ast.IsConstructorDeclaration(member)) {
				final params = member.Parameters();
				if (params != null) {
					for (param in params) {
						if (Ast.IsParameterPropertyDeclaration(param, member) && !Ast.IsBindingPattern(param.Name())) {
							final symbol = c.getSymbolOfDeclaration(param);
							if (symbol.Name == name) {
								c.error(param.Name(), message, c.symbolToString(symbol));
							}
						}
					}
				}
			} else {
				final symbol = c.getSymbolOfDeclaration(member);
				if (symbol != null && symbol.Name == name && (!checkStatic || isStatic == Ast.IsStatic(member))) {
					c.error(member.Name(), message, c.symbolToString(symbol));
				}
			}
		}
	}

	static function checkArrayType(c:Checker, node:Node):Void {
		c.checkSourceElement(node.AsArrayTypeNode().ElementType);
	}

	static function checkTupleType(c:Checker, node:Node):Void {
		var seenOptionalElement = false;
		var seenRestElement = false;
		final elements = node.Elements();
		if (elements != null) {
			for (e in elements) {
				var flags = c.getTupleElementFlags(e);
				if (flags & ElementFlagsVariadic != 0) {
					final t = c.getTypeFromTypeNode(e.Type());
					if (!c.isArrayLikeType(t)) {
						c.error(e, Diagnostics.A_rest_element_type_must_be_an_array_type);
						break;
					}
					if (c.isArrayType(t) || Checker.isTupleType(t) && t.TargetTupleType().combinedFlags & ElementFlagsRest != 0) {
						flags |= ElementFlagsRest;
					}
				}
				if (flags & ElementFlagsRest != 0) {
					if (seenRestElement) {
						c.grammarErrorOnNode(e, Diagnostics.A_rest_element_cannot_follow_another_rest_element);
						break;
					}
					seenRestElement = true;
				} else if (flags & ElementFlagsOptional != 0) {
					if (seenRestElement) {
						c.grammarErrorOnNode(e, Diagnostics.An_optional_element_cannot_follow_a_rest_element);
						break;
					}
					seenOptionalElement = true;
				} else if (flags & ElementFlagsRequired != 0 && seenOptionalElement) {
					c.grammarErrorOnNode(e, Diagnostics.A_required_element_cannot_follow_an_optional_element);
					break;
				}
			}
		}
		c.checkSourceElements(elements);
		c.getTypeFromTypeNode(node);
	}

	static function checkUnionOrIntersectionType(c:Checker, node:Node):Void {
		node.ForEachChild(c.checkSourceElement);
		c.getTypeFromTypeNode(node);
	}

	static function checkThisType(c:Checker, node:Node):Void {
		c.getTypeFromThisTypeNode(node);
	}

	static function checkTypeOperator(c:Checker, node:Node):Void {
		c.checkGrammarTypeOperatorNode(node.AsTypeOperatorNode());
		c.checkSourceElement(node.Type());
	}

	static function checkConditionalType(c:Checker, node:Node):Void {
		node.ForEachChild(c.checkSourceElement);
	}

	static function checkInferType(c:Checker, node:Node):Void {
		if (Ast.FindAncestor(node, (n:Node) -> {
			return n.Parent != null && n.Parent.Kind == KindConditionalType && n.Parent.AsConditionalTypeNode().ExtendsType == n;
		}) == null) {
			c.grammarErrorOnNode(node, Diagnostics.X_infer_declarations_are_only_permitted_in_the_extends_clause_of_a_conditional_type);
		}
		final typeParameterDeclarationNode = node.AsInferTypeNode().TypeParameter;
		c.checkSourceElement(typeParameterDeclarationNode);
		final symbol = c.getSymbolOfDeclaration(typeParameterDeclarationNode);
		if (Core.len(symbol.Declarations) > 1) {
			final links = c.declaredTypeLinks.Get(symbol);
			if (!links.typeParametersChecked) {
				links.typeParametersChecked = true;
				final typeParameter = c.getDeclaredTypeOfTypeParameter(symbol);
				final declarations = Checker.getDeclarationsOfKind(symbol, KindTypeParameter);
				if (!c.areTypeParametersIdentical(declarations, [typeParameter], (decl:Node) -> [decl])) {
					// Report an error on every conflicting declaration.
					final name = c.symbolToString(symbol);
					if (declarations != null) {
						for (declaration in declarations) {
							c.error(declaration.Name(), Diagnostics.All_declarations_of_0_must_have_identical_constraints, name);
						}
					}
				}
			}
		}
		c.registerForUnusedIdentifiersCheck(node);
	}

	static function checkTemplateLiteralType(c:Checker, node:Node):Void {
		for (span in node.AsTemplateLiteralTypeNode().TemplateSpans.Nodes) {
			c.checkSourceElement(span.Type());
			final t = c.getTypeFromTypeNode(span.Type());
			c.checkTypeAssignableTo(t, c.templateConstraintType, span.Type(), null);
		}
		c.getTypeFromTypeNode(node);
	}

	static function checkImportType(c:Checker, node:Node):Void {
		c.checkSourceElement(node.AsImportTypeNode().Argument);
		final attributes = node.AsImportTypeNode().Attributes;
		if (attributes != null) {
			c.getResolutionModeOverride(attributes.AsImportAttributes(), true /*reportErrors*/);
		}
		c.checkTypeReferenceOrImport(node);
	}

	static function getResolutionModeOverride(c:Checker, node:ImportAttributes, reportErrors:Bool):ResolutionMode {
		if (node.Attributes.Nodes.length != 1) {
			if (reportErrors) {
				c.grammarErrorOnNode(node.AsNode(),
					Diagnostics.Type_import_attributes_should_have_exactly_one_key_resolution_mode_with_value_import_or_require);
			}
			return Core.ResolutionModeNone;
		}
		final elem = node.Attributes.Nodes[0];
		if (!Ast.IsStringLiteralLike(elem.Name())) {
			return Core.ResolutionModeNone;
		}
		if (elem.Name().Text() != "resolution-mode") {
			if (reportErrors) {
				c.grammarErrorOnNode(elem.Name(), Diagnostics.X_resolution_mode_is_the_only_valid_key_for_type_import_attributes);
			}
			return Core.ResolutionModeNone;
		}
		final value = elem.AsImportAttribute().Value;
		if (!Ast.IsStringLiteralLike(value)) {
			return Core.ResolutionModeNone;
		}
		if (value.Text() != "import" && value.Text() != "require") {
			if (reportErrors) {
				c.grammarErrorOnNode(value, Diagnostics.X_resolution_mode_should_be_either_require_or_import);
			}
			return Core.ResolutionModeNone;
		}
		if (value.Text() == "import") {
			return Core.ResolutionModeESM;
		}
		return Core.ResolutionModeCommonJS;
	}

	static function checkNamedTupleMember(c:Checker, node:Node):Void {
		final tupleMember = node.AsNamedTupleMember();
		if (tupleMember.DotDotDotToken != null && tupleMember.QuestionToken != null) {
			c.grammarErrorOnNode(node, Diagnostics.A_tuple_member_cannot_be_both_optional_and_rest);
		}
		if (tupleMember.Type.Kind == KindOptionalType) {
			c.grammarErrorOnNode(tupleMember.Type,
				Diagnostics.A_labeled_tuple_element_is_declared_as_optional_with_a_question_mark_after_the_name_and_before_the_colon_rather_than_after_the_type);
		}
		if (tupleMember.Type.Kind == KindRestType) {
			c.grammarErrorOnNode(tupleMember.Type,
				Diagnostics.A_labeled_tuple_element_is_declared_as_rest_with_a_before_the_name_rather_than_before_the_type);
		}
		c.checkSourceElement(node.Type());
		c.getTypeFromTypeNode(node);
	}

	static function checkIndexedAccessType(c:Checker, node:Node):Void {
		node.ForEachChild(c.checkSourceElement);
		c.checkIndexedAccessIndexType(c.getTypeFromIndexedAccessTypeNode(node), node);
	}

	static function checkMappedType(c:Checker, node:Node):Void {
		final mappedTypeNode = node.AsMappedTypeNode();
		c.checkGrammarMappedType(mappedTypeNode);
		c.checkSourceElement(mappedTypeNode.TypeParameter);
		c.checkSourceElement(mappedTypeNode.NameType);
		c.checkSourceElement(mappedTypeNode.Type);
		if (mappedTypeNode.Type == null) {
			c.reportImplicitAny(node, c.anyType, WideningKindNormal);
		}
		final t = c.getTypeFromMappedTypeNode(node);
		final nameType = c.getNameTypeFromMappedType(t);
		if (nameType != null) {
			c.checkTypeAssignableTo(nameType, c.stringNumberSymbolType, mappedTypeNode.NameType, null);
		} else {
			final constraintType = c.getConstraintTypeFromMappedType(t);
			c.checkTypeAssignableTo(constraintType, c.stringNumberSymbolType, mappedTypeNode.TypeParameter.AsTypeParameterDeclaration().Constraint, null);
		}
	}

	static function checkFunctionDeclaration(c:Checker, node:Node):Void {
		c.checkFunctionOrMethodDeclaration(node);
		c.checkGrammarForGenerator(node);
		c.checkCollisionsForDeclarationName(node, node.Name());
	}

	static function checkFunctionOrMethodDeclaration(c:Checker, node:Node):Void {
		c.checkDecorators(node);
		c.checkSignatureDeclaration(node);
		final functionFlags = Ast.GetFunctionFlags(node);
		// Do not use hasDynamicName here, because that returns false for well known symbols.
		// We want to perform checkComputedPropertyName for all computed properties, including
		// well known symbols.
		if (node.Name() != null && Ast.IsComputedPropertyName(node.Name())) {
			// This check will account for methods in class/interface declarations,
			// as well as accessors in classes/object literals
			c.checkComputedPropertyName(node.Name());
		}
		if (c.hasBindableName(node)) {
			// first we want to check the local symbol that contain this declaration
			// - if node.localSymbol !== undefined - this is current declaration is exported and localSymbol points to the local symbol
			// - if node.localSymbol === undefined - this node is non-exported so we can just pick the result of getSymbolOfNode
			final symbol = c.getSymbolOfDeclaration(node);
			final localSymbol = Core.OrElse(node.LocalSymbol(), symbol);
			// Since the javascript won't do semantic analysis like typescript, ignore javascript function
			// declarations so that redeclaring a function in a JS file is not reported as a duplicate.
			if (node.Flags & NodeFlagsJavaScriptFile == 0) {
				c.checkFunctionOrConstructorSymbol(localSymbol);
			}
			if (symbol.Parent != null) {
				// run check on export symbol to check that modifiers agree across all exported declarations
				c.checkFunctionOrConstructorSymbol(symbol);
			}
		}
		final body = node.Body();
		c.checkSourceElement(body);
		c.checkAllCodePathsInNonVoidFunctionReturnOrThrow(node, c.getReturnTypeFromAnnotation(node));
		if (node.FunctionLikeData().FullSignature != null) {
			if (c.getContextualCallSignature(c.getTypeFromTypeNode(node.FunctionLikeData().FullSignature), node) == null) {
				c.error(node.FunctionLikeData().FullSignature,
					Diagnostics.A_JSDoc_type_tag_on_a_function_must_have_a_signature_with_the_correct_number_of_arguments);
			}
		}
		if (node.Type() == null) {
			// Report an implicit any error if there is no body, no explicit return type, and node is not a private method
			// in an ambient context
			if (Ast.NodeIsMissing(body) && !Checker.isPrivateWithinAmbient(node)) {
				c.reportImplicitAny(node, c.anyType, WideningKindNormal);
			}
			if (functionFlags & FunctionFlagsGenerator != 0 && Ast.NodeIsPresent(body)) {
				// A generator with a body and no type annotation can still cause errors. It can error if the
				// yielded values have no common supertype, or it can give an implicit any error if it has no
				// yielded values. The only way to trigger these errors is to try checking its return type.
				c.getReturnTypeOfSignature(c.getSignatureFromDeclaration(node));
			}
		}
	}

	static function checkFunctionOrConstructorSymbol(c:Checker, symbol:Symbol):Void {
		// Only check the symbol once
		final links = c.valueSymbolLinks.Get(symbol);
		if (!links.functionOrConstructorChecked) {
			links.functionOrConstructorChecked = true;
			c.checkFunctionOrConstructorSymbolWorker(symbol);
		}
	}

	static function checkFunctionOrConstructorSymbolWorker(c:Checker, symbol:Symbol):Void {
		final flagsToCheck = ModifierFlagsExport | ModifierFlagsAmbient | ModifierFlagsPrivate | ModifierFlagsProtected | ModifierFlagsAbstract;
		var someNodeFlags = ModifierFlagsNone;
		var allNodeFlags = flagsToCheck;
		var someHaveQuestionToken = false;
		var allHaveQuestionToken = true;
		var hasOverloads = false;
		var bodyDeclaration:Node = null;
		var lastSeenNonAmbientDeclaration:Node = null;
		var previousDeclaration:Node = null;
		final declarations = symbol.Declarations;
		final isConstructor = symbol.Flags & SymbolFlagsConstructor != 0;
		var duplicateFunctionDeclaration = false;
		var multipleConstructorImplementation = false;
		var hasNonAmbientClass = false;
		var functionDeclarations:Array<Node> = null;
		final getCanonicalOverload = (overloads:Array<Node>, implementation:Node) -> {
			// Consider the canonical set of flags to be the flags of the bodyDeclaration or the first declaration
			// Error on all deviations from this canonical set of flags
			// The caveat is that if some overloads are defined in lib.d.ts, we don't want to
			// report the errors on those. To achieve this, we will say that the implementation is
			// the canonical signature only if it is in the same container as the first overload_
			final implementationSharesContainerWithFirstOverload = implementation != null && implementation.Parent == overloads[0].Parent;
			if (implementationSharesContainerWithFirstOverload) {
				return implementation;
			}
			return overloads[0];
		};
		final checkFlagAgreementBetweenOverloads = (overloads:Array<Node>, implementation:Node, flagsToCheck:ModifierFlags,
				someOverloadFlags:ModifierFlags, allOverloadFlags:ModifierFlags) -> {
			// Error if some overloads have a flag that is not shared by all overloads. To find the
			// deviations, we XOR someOverloadFlags with allOverloadFlags
			final someButNotAllOverloadFlags:Int = (someOverloadFlags : Int) ^ (allOverloadFlags : Int);
			if (someButNotAllOverloadFlags != 0) {
				final canonicalFlags = c.getEffectiveDeclarationFlags(getCanonicalOverload(overloads, implementation), flagsToCheck);
				// PORT: Go map[*ast.SourceFile][]*ast.Node; iteration order does not matter (diagnostics are sorted).
				final groups = new IdentityMap<SourceFile, Array<Node>>();
				for (overload_ in overloads) {
					final sourceFile = Ast.GetSourceFileOfNode(overload_);
					var group = groups.get(sourceFile);
					if (group == null) {
						group = [];
						groups.set(sourceFile, group);
					}
					group.push(overload_);
				}
				for (overloadsInFile in groups) {
					final canonicalFlagsForFile = c.getEffectiveDeclarationFlags(getCanonicalOverload(overloadsInFile, implementation), flagsToCheck);
					for (overload_ in overloadsInFile) {
						final deviation:ModifierFlags = (c.getEffectiveDeclarationFlags(overload_, flagsToCheck) : Int) ^ (canonicalFlags : Int);
						final deviationInFile:ModifierFlags = (c.getEffectiveDeclarationFlags(overload_, flagsToCheck) : Int) ^ (canonicalFlagsForFile : Int);
						if (deviationInFile & ModifierFlagsExport != 0) {
							// Overloads in different files need not all have export modifiers. This is ok:
							//   // lib.d.ts
							//   declare function foo(s: number): string;
							//   declare function foo(s: string): number;
							//   export { foo };
							//
							//   // app.ts
							//   declare module "lib" {
							//     export function foo(s: boolean): boolean;
							//   }
							c.error(Ast.GetNameOfDeclaration(overload_), Diagnostics.Overload_signatures_must_all_be_exported_or_non_exported);
						} else if (deviationInFile & ModifierFlagsAmbient != 0) {
							// Though rare, a module augmentation (necessarily ambient) is allowed to add overloads
							// to a non-ambient function in an implementation file.
							c.error(Ast.GetNameOfDeclaration(overload_), Diagnostics.Overload_signatures_must_all_be_ambient_or_non_ambient);
						} else if (deviation & (ModifierFlagsPrivate | ModifierFlagsProtected) != 0) {
							c.error(Core.OrElse(Ast.GetNameOfDeclaration(overload_), overload_), Diagnostics.Overload_signatures_must_all_be_public_private_or_protected);
						} else if (deviation & ModifierFlagsAbstract != 0) {
							c.error(Ast.GetNameOfDeclaration(overload_), Diagnostics.Overload_signatures_must_all_be_abstract_or_non_abstract);
						}
					}
				}
			}
		};
		final checkQuestionTokenAgreementBetweenOverloads = (overloads:Array<Node>, implementation:Node, someHaveQuestionToken:Bool,
				allHaveQuestionToken:Bool) -> {
			if (someHaveQuestionToken != allHaveQuestionToken) {
				final canonicalHasQuestionToken = Checker.isOptionalDeclaration(getCanonicalOverload(overloads, implementation));
				for (o in overloads) {
					if (Checker.isOptionalDeclaration(o) != canonicalHasQuestionToken) {
						c.error(Ast.GetNameOfDeclaration(o), Diagnostics.Overload_signatures_must_all_be_optional_or_required);
					}
				}
			}
		};
		final reportImplementationExpectedError = (node:Node) -> {
			final name = node.Name();
			if (name != null && Ast.NodeIsMissing(name)) {
				return;
			}
			var seen = false;
			var subsequentNode:Node = null;
			node.Parent.ForEachChild((child:Node) -> {
				if (seen) {
					subsequentNode = child;
					return true;
				}
				seen = child == node;
				return false;
			});
			// We may be here because of some extra nodes between overloads that could not be parsed into a valid node.
			// In this case the subsequent node is not really consecutive (.pos !== node.end), and we must ignore it here.
			if (subsequentNode != null && subsequentNode.Pos() == node.End()) {
				if (subsequentNode.Kind == node.Kind) {
					final subsequentName = subsequentNode.Name();
					final errorNode = Core.OrElse(subsequentName, subsequentNode);
					if (name != null && subsequentName != null
						&& (Ast.IsPrivateIdentifier(name) && Ast.IsPrivateIdentifier(subsequentName) && name.Text() == subsequentName.Text()
							|| Ast.IsComputedPropertyName(name) && Ast.IsComputedPropertyName(subsequentName)
							&& c.isTypeIdenticalTo(c.checkComputedPropertyName(name), c.checkComputedPropertyName(subsequentName))
							|| Ast.IsPropertyNameLiteral(name) && Ast.IsPropertyNameLiteral(subsequentName) && name.Text() == subsequentName.Text())) {
						final reportError = (Ast.IsMethodDeclaration(node) || Ast.IsMethodSignatureDeclaration(node))
							&& Ast.IsStatic(node) != Ast.IsStatic(subsequentNode);
						// we can get here in two cases
						// 1. mixed static and instance class members
						// 2. something with the same name was defined before the set of overloads that prevents them from merging
						// here we'll report error only for the first case since for second we should already report error in binder
						if (reportError) {
							final diagnostic = Core.IfElse(Ast.IsStatic(node), Diagnostics.Function_overload_must_be_static,
								Diagnostics.Function_overload_must_not_be_static);
							c.error(errorNode, diagnostic);
						}
						return;
					}
					if (Ast.NodeIsPresent(subsequentNode.Body())) {
						c.error(errorNode, Diagnostics.Function_implementation_name_must_be_0, Scanner.DeclarationNameToString(name));
						return;
					}
				}
			}
			final errorNode = Core.OrElse(name, node);
			if (isConstructor) {
				c.error(errorNode, Diagnostics.Constructor_implementation_is_missing);
			} else {
				// Report different errors regarding non-consecutive blocks of declarations depending on whether
				// the node in question is abstract.
				if (Ast.HasSyntacticModifier(node, ModifierFlagsAbstract)) {
					c.error(errorNode, Diagnostics.All_declarations_of_an_abstract_method_must_be_consecutive);
				} else {
					c.error(errorNode, Diagnostics.Function_implementation_is_missing_or_not_immediately_following_the_declaration);
				}
			}
		};
		if (declarations != null) {
			for (node in declarations) {
				final inAmbientContext = node.Flags & NodeFlagsAmbient != 0;
				final inAmbientContextOrInterface = inAmbientContext
					|| node.Parent != null && (Ast.IsInterfaceDeclaration(node.Parent) || Ast.IsTypeLiteralNode(node.Parent));
				if (inAmbientContextOrInterface) {
					// check if declarations are consecutive only if they are non-ambient
					// 1. ambient declarations can be interleaved
					// i.e. this is legal
					//     declare function foo();
					//     declare function bar();
					//     declare function foo();
					// 2. mixing ambient and non-ambient declarations is a separate error that will be reported - do not want to report an extra one
					previousDeclaration = null;
				}
				if (Ast.IsClassLike(node) && !inAmbientContext) {
					hasNonAmbientClass = true;
				}
				if (Ast.IsFunctionDeclaration(node) || Ast.IsMethodDeclaration(node) || Ast.IsMethodSignatureDeclaration(node)
					|| Ast.IsConstructorDeclaration(node)) {
					if (functionDeclarations == null) {
						functionDeclarations = [];
					}
					functionDeclarations.push(node);
					final currentNodeFlags = c.getEffectiveDeclarationFlags(node, flagsToCheck);
					someNodeFlags |= currentNodeFlags;
					allNodeFlags &= currentNodeFlags;
					someHaveQuestionToken = someHaveQuestionToken || Checker.isOptionalDeclaration(node);
					allHaveQuestionToken = allHaveQuestionToken && Checker.isOptionalDeclaration(node);
					final bodyIsPresent = Ast.NodeIsPresent(node.Body());
					if (bodyIsPresent && bodyDeclaration != null) {
						if (isConstructor) {
							multipleConstructorImplementation = true;
						} else {
							duplicateFunctionDeclaration = true;
						}
					} else if (previousDeclaration != null && previousDeclaration.Parent == node.Parent && previousDeclaration.End() != node.Pos()
						&& previousDeclaration.Flags & NodeFlagsReparsed == 0) {
						reportImplementationExpectedError(previousDeclaration);
					}
					if (bodyIsPresent) {
						if (bodyDeclaration == null) {
							bodyDeclaration = node;
						}
					} else {
						hasOverloads = true;
					}
					previousDeclaration = node;
					if (!inAmbientContextOrInterface) {
						lastSeenNonAmbientDeclaration = node;
					}
				}
			}
		}
		if (multipleConstructorImplementation) {
			for (declaration in functionDeclarations) {
				c.error(declaration, Diagnostics.Multiple_constructor_implementations_are_not_allowed);
			}
		}
		if (duplicateFunctionDeclaration) {
			for (declaration in functionDeclarations) {
				c.error(Core.OrElse(Ast.GetNameOfDeclaration(declaration), declaration), Diagnostics.Duplicate_function_implementation);
			}
		}
		if (hasNonAmbientClass && !isConstructor && symbol.Flags & SymbolFlagsFunction != 0 && Core.len(declarations) != 0) {
			var relatedDiagnostics:Array<Diagnostic> = null;
			for (declaration in declarations) {
				if (Ast.IsClassDeclaration(declaration)) {
					if (relatedDiagnostics == null) {
						relatedDiagnostics = [];
					}
					relatedDiagnostics.push(Checker.createDiagnosticForNode(declaration, Diagnostics.Consider_adding_a_declare_modifier_to_this_class));
				}
			}
			for (declaration in declarations) {
				var diagnostic:Message = null;
				switch (declaration.Kind) {
					case KindClassDeclaration:
						diagnostic = Diagnostics.Class_declaration_cannot_implement_overload_list_for_0;
					case KindFunctionDeclaration:
						diagnostic = Diagnostics.Function_with_bodies_can_only_merge_with_classes_that_are_ambient;
					default:
				}
				if (diagnostic != null) {
					c.error(Core.OrElse(Ast.GetNameOfDeclaration(declaration), declaration), diagnostic, symbol.Name).SetRelatedInfo(relatedDiagnostics);
				}
			}
		}
		// Abstract methods can't have an implementation -- in particular, they don't need one.
		if (lastSeenNonAmbientDeclaration != null && lastSeenNonAmbientDeclaration.Body() == null
			&& !Ast.HasSyntacticModifier(lastSeenNonAmbientDeclaration, ModifierFlagsAbstract)
			&& !Checker.isOptionalDeclaration(lastSeenNonAmbientDeclaration)) {
			reportImplementationExpectedError(lastSeenNonAmbientDeclaration);
		}
		if (hasOverloads) {
			checkFlagAgreementBetweenOverloads(declarations, bodyDeclaration, flagsToCheck, someNodeFlags, allNodeFlags);
			checkQuestionTokenAgreementBetweenOverloads(declarations, bodyDeclaration, someHaveQuestionToken, allHaveQuestionToken);
			if (bodyDeclaration != null) {
				final signatures = c.getSignaturesOfSymbol(symbol);
				final bodySignature = c.getSignatureFromDeclaration(bodyDeclaration);
				if (signatures != null) {
					for (signature in signatures) {
						if (!c.isImplementationCompatibleWithOverload(bodySignature, signature)) {
							final errorNode = signature.declaration;
							c.error(errorNode, Diagnostics.This_overload_signature_is_not_compatible_with_its_implementation_signature)
								.AddRelatedInfo(Checker.createDiagnosticForNode(bodyDeclaration, Diagnostics.The_implementation_signature_is_declared_here));
							break;
						}
					}
				}
			}
		}
	}

	static function getEffectiveDeclarationFlags(c:Checker, n:Node, flagsToCheck:ModifierFlags):ModifierFlags {
		var flags = c.getCombinedModifierFlagsCached(n);
		// children of classes (even ambient classes) should not be marked as ambient or export
		// because those flags have no useful semantics there.
		if (!Ast.IsInterfaceDeclaration(n.Parent) && !Ast.IsClassDeclaration(n.Parent) && !Ast.IsClassExpression(n.Parent) && n.Flags & NodeFlagsAmbient != 0) {
			final container = Checker.getEnclosingContainer(n);
			if (container != null && container.Flags & NodeFlagsExportContext != 0 && flags & ModifierFlagsAmbient == 0
				&& !(Ast.IsModuleBlock(n.Parent) && Ast.IsGlobalScopeAugmentation(n.Parent.Parent))) {
				// It is nested in an ambient export context, which means it is automatically exported
				flags |= ModifierFlagsExport;
			}
			flags |= ModifierFlagsAmbient;
		}
		return flags & flagsToCheck;
	}

	static function isImplementationCompatibleWithOverload(c:Checker, implementation:Signature, overload_:Signature):Bool {
		final erasedSource = c.getErasedSignature(implementation);
		final erasedTarget = c.getErasedSignature(overload_);
		// First see if the return types are compatible in either direction.
		final sourceReturnType = c.getReturnTypeOfSignature(erasedSource);
		final targetReturnType = c.getReturnTypeOfSignature(erasedTarget);
		if (targetReturnType == c.voidType || c.isTypeRelatedTo(targetReturnType, sourceReturnType, c.assignableRelation)
			|| c.isTypeRelatedTo(sourceReturnType, targetReturnType, c.assignableRelation)) {
			return c.isSignatureAssignableTo(erasedSource, erasedTarget, true /*ignoreReturnTypes*/);
		}
		return false;
	}

	static function checkAllCodePathsInNonVoidFunctionReturnOrThrow(c:Checker, fn:Node, returnType:Type):Void {
		final functionFlags = Ast.GetFunctionFlags(fn);
		var t:Type = null;
		if (returnType != null) {
			t = c.unwrapReturnType(returnType, functionFlags);
		}
		// Functions with an explicitly specified return type that includes `void` or is exactly `any` or `undefined` don't
		// need any return statements.
		if (t != null && (c.maybeTypeOfKind(t, TypeFlagsVoid) || t.flags & (TypeFlagsAny | TypeFlagsUndefined) != 0)) {
			return;
		}
		// If all we have is a function signature, or an arrow function with an expression body, then there is nothing to check.
		// also if HasImplicitReturn flag is not set this means that all codepaths in function body end with return or throw
		if (Ast.IsMethodSignatureDeclaration(fn) || Ast.NodeIsMissing(fn.Body()) || !Ast.IsBlock(fn.Body()) || !c.functionHasImplicitReturn(fn)) {
			return;
		}
		final hasExplicitReturn = fn.Flags & NodeFlagsHasExplicitReturn != 0;
		var errorNode = fn.Type();
		if (errorNode == null) {
			final data = fn.FunctionLikeData();
			if (data != null && data.FullSignature != null) {
				errorNode = data.FullSignature;
			}
		}
		if (errorNode == null) {
			errorNode = fn;
		}
		if (t != null && t.flags & TypeFlagsNever != 0) {
			c.error(errorNode, Diagnostics.A_function_returning_never_cannot_have_a_reachable_end_point);
		} else if (t != null && !hasExplicitReturn) {
			// minimal check: function has syntactic return type annotation and no explicit return statements in the body
			// this function does not conform to the specification.
			c.error(errorNode, Diagnostics.A_function_whose_declared_type_is_neither_undefined_void_nor_any_must_return_a_value);
		} else if (t != null && c.strictNullChecks && !c.isTypeAssignableTo(c.undefinedType, t)) {
			c.error(errorNode, Diagnostics.Function_lacks_ending_return_statement_and_return_type_does_not_include_undefined);
		} else if (c.compilerOptions.NoImplicitReturns == TSTrue) {
			if (t == null) {
				// If return type annotation is omitted check if function has any explicit return statements.
				// If it does not have any - its inferred return type is void - don't do any checks.
				// Otherwise get inferred return type from function body and report error only if it is not void / anytype
				if (!hasExplicitReturn) {
					return;
				}
				final inferredReturnType = c.getReturnTypeOfSignature(c.getSignatureFromDeclaration(fn));
				if (c.isUnwrappedReturnTypeUndefinedVoidOrAny(fn, inferredReturnType)) {
					return;
				}
			}
			c.error(errorNode, Diagnostics.Not_all_code_paths_return_a_value);
		}
	}

	static function isUnwrappedReturnTypeUndefinedVoidOrAny(c:Checker, fn:Node, returnType:Type):Bool {
		final t = c.unwrapReturnType(returnType, Ast.GetFunctionFlags(fn));
		return t != null && (c.maybeTypeOfKind(t, TypeFlagsVoid) || t.flags & (TypeFlagsAny | TypeFlagsUndefined) != 0);
	}

	static function checkBlock(c:Checker, node:Node):Void {
		// Grammar checking for SyntaxKind.Block
		if (node.Kind == KindBlock) {
			c.checkGrammarStatementInAmbientContext(node);
		}
		if (Ast.IsFunctionOrModuleBlock(node)) {
			final saveFlowAnalysisDisabled = c.flowAnalysisDisabled;
			c.checkSourceElements(node.Statements());
			c.flowAnalysisDisabled = saveFlowAnalysisDisabled;
		} else {
			c.checkSourceElements(node.Statements());
		}
		final locals = node.Locals();
		if (locals != null && locals.keys().hasNext()) {
			c.registerForUnusedIdentifiersCheck(node);
		}
	}

	static function checkIfStatement(c:Checker, node:Node):Void {
		c.checkGrammarStatementInAmbientContext(node);
		final t = c.checkTruthinessExpression(node.Expression(), CheckModeNormal);
		final data = node.AsIfStatement();
		c.checkTestingKnownTruthyCallableOrAwaitableOrEnumMemberType(node.Expression(), t, data.ThenStatement);
		c.checkSourceElement(data.ThenStatement);
		if (Ast.IsEmptyStatement(data.ThenStatement)) {
			c.error(data.ThenStatement, Diagnostics.The_body_of_an_if_statement_cannot_be_the_empty_statement);
		}
		c.checkSourceElement(data.ElseStatement);
	}

	static function checkTestingKnownTruthyCallableOrAwaitableOrEnumMemberType(c:Checker, condExpr:Node, condType:Type, body:Node):Void {
		if (!c.strictNullChecks) {
			return;
		}
		c.checkTestingKnownTruthyTypes(condExpr, condType, body);
	}

	static function checkTestingKnownTruthyTypes(c:Checker, condExpr:Node, condType:Type, body:Node):Void {
		condExpr = Ast.SkipParentheses(condExpr);
		c.checkTestingKnownTruthyType(condExpr, condType, body);
		while (Ast.IsBinaryExpression(condExpr)
			&& (condExpr.AsBinaryExpression().OperatorToken.Kind == KindBarBarToken
				|| condExpr.AsBinaryExpression().OperatorToken.Kind == KindQuestionQuestionToken)) {
			condExpr = Ast.SkipParentheses(condExpr.AsBinaryExpression().Left);
			c.checkTestingKnownTruthyType(condExpr, condType, body);
		}
	}

	static function checkTestingKnownTruthyType(c:Checker, condExpr:Node, condType:Type, body:Node):Void {
		var location = condExpr;
		if (Ast.IsLogicalOrCoalescingBinaryExpression(condExpr)) {
			location = Ast.SkipParentheses(condExpr.AsBinaryExpression().Right);
		}
		if (Ast.IsModuleExportsAccessExpression(location)) {
			return;
		}
		if (Ast.IsLogicalOrCoalescingBinaryExpression(location)) {
			c.checkTestingKnownTruthyTypes(location, condType, body);
			return;
		}
		var t = condType;
		if (location != condExpr) {
			t = c.checkExpression(location);
		}
		if (t.flags & TypeFlagsEnumLiteral != 0 && Ast.IsPropertyAccessExpression(location)
			&& Core.OrElse(c.getResolvedSymbolOrNil(location.Expression()), c.unknownSymbol).Flags & SymbolFlagsEnum != 0) {
			// EnumLiteral type at condition with known value is always truthy or always falsy, likely an error
			c.error(location, Diagnostics.This_condition_will_always_return_0, Core.IfElse(Evaluator.IsTruthy(t.AsLiteralType().value), "true", "false"));
			return;
		}
		final isPropertyExpressionCast = Ast.IsPropertyAccessExpression(location) && Checker.isTypeAssertion(location.Expression());
		if (!c.hasTypeFacts(t, TypeFactsTruthy) || isPropertyExpressionCast) {
			return;
		}
		// While it technically should be invalid for any known-truthy value
		// to be tested, we de-scope to functions and Promises unreferenced in
		// the block as a heuristic to identify the most common bugs. There
		// are too many false positives for values sourced from type
		// definitions without strictNullChecks otherwise.
		final callSignatures = c.getSignaturesOfType(t, SignatureKindCall);
		final isPromise = c.getAwaitedTypeOfPromise(t) != null;
		if (Core.len(callSignatures) == 0 && !isPromise) {
			return;
		}
		var testedNode:Node = null;
		if (Ast.IsIdentifier(location)) {
			testedNode = location;
		} else if (Ast.IsPropertyAccessExpression(location)) {
			testedNode = location.Name();
		}
		var testedSymbol:Symbol = null;
		if (testedNode != null) {
			testedSymbol = c.getSymbolAtLocation(testedNode, false);
		}
		if (testedSymbol == null && !isPromise) {
			return;
		}
		final isUsed = testedSymbol != null && Ast.IsBinaryExpression(condExpr.Parent) && c.isSymbolUsedInBinaryExpressionChain(condExpr.Parent, testedSymbol)
			|| testedSymbol != null && body != null && c.isSymbolUsedInConditionBody(condExpr, body, testedNode, testedSymbol);
		if (!isUsed) {
			if (isPromise) {
				c.errorAndMaybeSuggestAwait(location, true, Diagnostics.This_condition_will_always_return_true_since_this_0_is_always_defined,
					c.getTypeNameForErrorDisplay(t));
			} else {
				c.error(location, Diagnostics.This_condition_will_always_return_true_since_this_function_is_always_defined_Did_you_mean_to_call_it_instead);
			}
		}
	}

	static function isSymbolUsedInBinaryExpressionChain(c:Checker, node:Node, testedSymbol:Symbol):Bool {
		var visit:(Node) -> Bool = null;
		visit = (child:Node) -> {
			if (Ast.IsIdentifier(child)) {
				final symbol = c.getSymbolAtLocation(child, false);
				if (symbol != null && symbol == testedSymbol) {
					return true;
				}
			}
			return child.ForEachChild(visit);
		};
		while (Ast.IsBinaryExpression(node) && node.AsBinaryExpression().OperatorToken.Kind == KindAmpersandAmpersandToken) {
			final isUsed = node.AsBinaryExpression().Right.ForEachChild(visit);
			if (isUsed) {
				return true;
			}
			node = node.Parent;
		}
		return false;
	}

	static function isSymbolUsedInConditionBody(c:Checker, expr:Node, body:Node, testedNode:Node, testedSymbol:Symbol):Bool {
		var visit:(Node) -> Bool = null;
		visit = (childNode:Node) -> {
			if (Ast.IsIdentifier(childNode)) {
				final childSymbol = c.getSymbolAtLocation(childNode, false);
				if (childSymbol != null && childSymbol == testedSymbol) {
					// If the test was a simple identifier, the above check is sufficient
					if (Ast.IsIdentifier(expr) || Ast.IsIdentifier(testedNode) && Ast.IsBinaryExpression(testedNode.Parent)) {
						return true;
					}
					// Otherwise we need to ensure the symbol is called on the same target
					var testedExpression = testedNode.Parent;
					var childExpression = childNode.Parent;
					while (testedExpression != null && childExpression != null) {
						if (Ast.IsIdentifier(testedExpression) && Ast.IsIdentifier(childExpression)
							|| testedExpression.Kind == KindThisKeyword && childExpression.Kind == KindThisKeyword) {
							return c.getSymbolAtLocation(testedExpression, false) == c.getSymbolAtLocation(childExpression, false);
						} else if (Ast.IsPropertyAccessExpression(testedExpression) && Ast.IsPropertyAccessExpression(childExpression)) {
							if (c.getSymbolAtLocation(testedExpression.Name(), false) != c.getSymbolAtLocation(childExpression.Name(), false)) {
								return false;
							}
							childExpression = childExpression.Expression();
							testedExpression = testedExpression.Expression();
						} else if (Ast.IsCallExpression(testedExpression) && Ast.IsCallExpression(childExpression)) {
							childExpression = childExpression.Expression();
							testedExpression = testedExpression.Expression();
						} else {
							return false;
						}
					}
				}
			}
			return childNode.ForEachChild(visit);
		};
		return body.ForEachChild(visit);
	}

	static function checkDoStatement(c:Checker, node:Node):Void {
		c.checkGrammarStatementInAmbientContext(node);
		c.checkSourceElement(node.Statement());
		c.checkTruthinessExpression(node.Expression(), CheckModeNormal);
	}

	static function checkWhileStatement(c:Checker, node:Node):Void {
		c.checkGrammarStatementInAmbientContext(node);
		c.checkTruthinessExpression(node.Expression(), CheckModeNormal);
		c.checkSourceElement(node.Statement());
	}

	static function checkForStatement(c:Checker, node:Node):Void {
		if (!c.checkGrammarStatementInAmbientContext(node)) {
			final init = node.Initializer();
			if (init != null && init.Kind == KindVariableDeclarationList) {
				c.checkGrammarVariableDeclarationList(init.AsVariableDeclarationList());
			}
		}
		final data = node.AsForStatement();
		if (data.Initializer != null) {
			if (Ast.IsVariableDeclarationList(data.Initializer)) {
				c.checkVariableDeclarationList(data.Initializer);
			} else {
				c.checkExpression(data.Initializer);
			}
		}
		if (data.Condition != null) {
			c.checkTruthinessExpression(data.Condition, CheckModeNormal);
		}
		if (data.Incrementor != null) {
			c.checkExpression(data.Incrementor);
		}
		c.checkSourceElement(data.Statement);
		if (node.Locals() != null) {
			c.registerForUnusedIdentifiersCheck(node);
		}
	}
}
