package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/nodebuilder_hover.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Methods of nodebuilder_hover.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class NodebuilderHover {

	// expandSymbolForHover produces declaration nodes (class, interface, enum, module) for a symbol
	// for expandable hover. This is a focused alternative to the full symbolTableToDeclarationStatements
	// machinery used by declaration emit — it directly builds the declaration nodes hover needs
	// without the declaration-emit scaffolding (deferred privates, symbol name remapping, export
	// modifier computation, alias resolution, visited symbols tracking).
	static function expandSymbolForHover(b:NodeBuilderImpl, symbol:Symbol):Array<Node> {
		var results:Array<Node> = null;
		if (symbol.Flags & SymbolFlagsEnum != 0) {
			final node = b.expandEnumDecl(symbol);
			if (node != null) {
				if (results == null) results = [];
				results.push(node);
			}
		}
		if (symbol.Flags & SymbolFlagsClass != 0) {
			final node = b.expandClassDecl(symbol);
			if (node != null) {
				if (results == null) results = [];
				results.push(node);
			}
		}
		// Module/namespace before interface (matching Strada ordering for merged declarations)
		if (symbol.Flags & (SymbolFlagsValueModule | SymbolFlagsNamespaceModule) != 0) {
			final node = b.expandModuleDecl(symbol);
			if (node != null) {
				if (results == null) results = [];
				results.push(node);
			}
		}
		if (symbol.Flags & SymbolFlagsInterface != 0 && symbol.Flags & SymbolFlagsClass == 0) {
			final node = b.expandInterfaceDecl(symbol);
			if (node != null) {
				if (results == null) results = [];
				results.push(node);
			}
		}
		return results;
	}

	// expandEnumDecl produces an EnumDeclaration node with all members.
	static function expandEnumDecl(b:NodeBuilderImpl, symbol:Symbol):Node {
		final name = Ast.SymbolName(symbol);
		b.ctx.approximateLength += 9 + Utf8.ByteLen(name); // PORT: byte (Go len of a UTF-8 string)
		final memberProps = Core.Filter(b.ch.getPropertiesOfType(b.ch.getTypeOfSymbol(symbol)), (p:Symbol) -> {
			return p.Flags & SymbolFlagsEnumMember != 0;
		});
		var members:Array<Node> = null;
		if (memberProps != null) {
			for (i in 0...memberProps.length) {
				final p = memberProps[i];
				if (b.checkTruncationLengthIfExpanding() && i + 3 < memberProps.length - 1) {
					b.ctx.expansionTruncated = true;
					if (members == null) members = [];
					members.push(b.f.NewEnumMember(b.f.NewStringLiteral(Fmt.Sprintf(" ... %d more ... ", [memberProps.length - i - 1]), TokenFlagsNone), null));
					final last = memberProps[memberProps.length - 1];
					members.push(b.f.NewEnumMember(b.f.NewIdentifier(last.Name), b.enumMemberInitializer(last)));
					break;
				}
				final memberDecl = Core.Find(p.Declarations, Ast.IsEnumMember);
				var initializer:Node = null;
				if (memberDecl != null && memberDecl.AsEnumMember().Initializer != null) {
					initializer = b.f.DeepCloneNode(memberDecl.AsEnumMember().Initializer);
				} else {
					initializer = b.enumMemberInitializer(p);
				}
				b.ctx.approximateLength += 4 + Utf8.ByteLen(p.Name); // PORT: byte (Go len of a UTF-8 string)
				if (initializer != null) {
					b.ctx.approximateLength += 5; // " = " + value estimate
				}
				if (members == null) members = [];
				members.push(b.f.NewEnumMember(b.f.NewIdentifier(p.Name), initializer));
			}
		}

		var constModifier = ModifierFlagsNone;
		if (Checker.isConstEnumSymbol(symbol)) {
			constModifier = ModifierFlagsConst;
		}
		var mods:ModifierList = null;
		if (constModifier != 0) {
			mods = b.f.NewModifierList(Ast.CreateModifiersFromModifierFlags(constModifier, kind -> b.f.NewModifier(kind)));
		}
		return b.f.NewEnumDeclaration(mods, b.f.NewIdentifier(name), b.f.NewNodeList(members));
	}

	static function enumMemberInitializer(b:NodeBuilderImpl, p:Symbol):Node {
		final memberDecl = Core.Find(p.Declarations, Ast.IsEnumMember);
		if (memberDecl == null) {
			return null;
		}
		final val:Any = b.ch.GetConstantValue(memberDecl);
		if (val == null) {
			return null;
		}
		// PORT: Go type switch on string / jsnum.Number.
		if (Std.isOfType(val, std.String)) {
			return b.f.NewStringLiteral((val : std.String), TokenFlagsNone);
		} else if (Std.isOfType(val, Float)) {
			return b.f.NewNumericLiteral(ts.jsnum.String_.String((val : Float)), TokenFlagsNone);
		}
		return null;
	}

	// expandClassDecl produces a ClassDeclaration node with heritage clauses and members.
	static function expandClassDecl(b:NodeBuilderImpl, symbol:Symbol):Node {
		final name = Ast.SymbolName(symbol);
		b.ctx.approximateLength += 9 + Utf8.ByteLen(name); // PORT: byte (Go len of a UTF-8 string)

		final classLikeDeclarations = Core.Filter(symbol.Declarations, Ast.IsClassLike);
		final originalDecl = Core.FirstOrNil(classLikeDeclarations);
		final oldEnclosing = b.ctx.enclosingDeclaration;
		if (originalDecl != null) {
			b.ctx.enclosingDeclaration = originalDecl;
		}
		// PORT: defer restoring enclosingDeclaration → restored before the single return below.

		final localParams = b.ch.getLocalTypeParametersOfClassOrInterfaceOrTypeAlias(symbol);
		final typeParamDecls = Core.Map(localParams, (p:Type) -> b.typeParameterToDeclaration(p));

		final declaredType = b.ch.getDeclaredTypeOfClassOrInterface(symbol);
		final classType = b.ch.getTypeWithThisArgument(declaredType, null, false);
		final baseTypes = b.ch.getBaseTypes(b.ch.getTargetType(classType));
		final staticType = b.ch.getTypeOfSymbol(symbol);
		final isClass = staticType.symbol != null && staticType.symbol.ValueDeclaration != null && Ast.IsClassLike(staticType.symbol.ValueDeclaration);
		var staticBaseType:Type = null;
		if (isClass) {
			staticBaseType = b.ch.getBaseConstructorTypeOfClass(declaredType);
		} else {
			staticBaseType = b.ch.anyType;
		}

		// Heritage clauses
		final heritageClauses = b.hoverHeritageClauses(classLikeDeclarations);

		// Instance members via addPropertyToElementList (reusing existing serialization),
		// then convert TypeElements to ClassElements and add class-specific modifiers
		final allProps = b.ch.getPropertiesOfType(classType);
		final symbolProps = b.filterInheritedProperties(classType, baseTypes, allProps);
		final publicProps = Core.Filter(symbolProps, (s:Symbol) -> !Checker.isHashPrivate(s));
		final hasPrivate = Core.Some(symbolProps, Checker.isHashPrivate);

		var instanceMembers:Array<Node> = null;
		instanceMembers = b.serializePropertiesWithTruncation(publicProps, instanceMembers);
		instanceMembers = Checker.typeElementsToClassElements(b.f, instanceMembers);
		instanceMembers = b.addClassModifiers(instanceMembers, false);

		// Static members
		final staticProps = Core.Filter(b.ch.getPropertiesOfType(staticType), (p:Symbol) -> {
			return p.Flags & SymbolFlagsPrototype == 0 && p.Name != "prototype" && !b.isNamespaceMember(p);
		});
		var staticMembers:Array<Node> = null;
		staticMembers = b.serializePropertiesWithTruncation(staticProps, staticMembers);
		staticMembers = Checker.typeElementsToClassElements(b.f, staticMembers);
		staticMembers = b.addClassModifiers(staticMembers, true);

		// Hash-private members
		var privateMembers:Array<Node> = null;
		if (hasPrivate) {
			privateMembers = b.serializePropertiesWithTruncation(Core.Filter(symbolProps, Checker.isHashPrivate), privateMembers);
			privateMembers = Checker.typeElementsToClassElements(b.f, privateMembers);
		}

		// Constructors
		final constructors = b.serializeConstructors(staticType, staticBaseType, isClass, symbol);

		// Index signatures
		final indexSigs = b.serializeIndexSignaturesOfType(classType, Core.FirstOrNil(baseTypes));

		final allMembers:Array<Node> = [];
		for (list in [indexSigs, staticMembers, constructors, instanceMembers, privateMembers]) {
			if (list != null) {
				for (m in list) {
					allMembers.push(m);
				}
			}
		}

		final result = b.f.NewClassDeclaration(null, b.f.NewIdentifier(name), b.f.NewNodeList(typeParamDecls), b.f.NewNodeList(heritageClauses),
			b.f.NewNodeList(allMembers));
		b.ctx.enclosingDeclaration = oldEnclosing;
		return result;
	}

	// addClassModifiers post-processes class member nodes to add class-specific modifiers
	// (private, protected, public, abstract, static) based on the original symbol declarations.
	static function addClassModifiers(b:NodeBuilderImpl, members:Array<Node>, isStatic:Bool):Array<Node> {
		if (members == null) {
			return members;
		}
		for (i in 0...members.length) {
			final m = members[i];
			// Find the symbol for this member by matching the property name
			var memberSymbol:Symbol = null;
			final memberName = m.Name();
			if (memberName != null) {
				if (b.idToSymbol.exists(memberName)) {
					memberSymbol = b.idToSymbol.get(memberName);
				}
			}
			if (memberSymbol == null) {
				continue;
			}
			var modFlags = Checker.getDeclarationModifierFlagsFromSymbol(memberSymbol) & ~ModifierFlagsAsync;
			if (isStatic) {
				modFlags |= ModifierFlagsStatic;
			}
			if (modFlags != 0 && Ast.CanHaveModifiers(m)) {
				final existing = m.ModifierFlags();
				if (modFlags != existing) {
					members[i] = Ast.ReplaceModifiers(b.f, m, b.f.NewModifierList(Ast.CreateModifiersFromModifierFlags(modFlags | existing, kind -> b.f.NewModifier(kind))));
				}
			}
		}
		return members;
	}

	// expandInterfaceDecl produces an InterfaceDeclaration with members.
	// Reuses addPropertyToElementList for property serialization and
	// signatureToSignatureDeclarationHelper for signatures.
	static function expandInterfaceDecl(b:NodeBuilderImpl, symbol:Symbol):Node {
		final name = Ast.SymbolName(symbol);
		b.ctx.approximateLength += 14 + Utf8.ByteLen(name); // PORT: byte (Go len of a UTF-8 string)

		final interfaceType = b.ch.getDeclaredTypeOfClassOrInterface(symbol);
		final interfaceDeclarations = Core.Filter(symbol.Declarations, Ast.IsInterfaceDeclaration);
		final localParams = b.ch.getLocalTypeParametersOfClassOrInterfaceOrTypeAlias(symbol);
		final typeParamDecls = Core.Map(localParams, (p:Type) -> b.typeParameterToDeclaration(p));
		final baseTypes = b.ch.getBaseTypes(interfaceType);
		var baseType:Type = null;
		if (Core.len(baseTypes) > 0) {
			baseType = b.ch.getIntersectionType(baseTypes);
		}

		// Members: reuse existing serialization functions
		final resolved = b.ch.resolveStructuredTypeMembers(interfaceType);
		var members:Array<Node> = null;

		// Index signatures, filtering those identical to base
		final indexSigs = b.serializeIndexSignaturesOfType(interfaceType, baseType);
		if (indexSigs != null) {
			for (n in indexSigs) {
				if (members == null) members = [];
				members.push(n);
			}
		}
		// Construct signatures (skip abstract)
		final constructSigs = resolved.ConstructSignatures();
		if (constructSigs != null) {
			for (sig in constructSigs) {
				if (sig.flags & SignatureFlagsAbstract != 0) {
					continue;
				}
				if (members == null) members = [];
				members.push(b.signatureToSignatureDeclarationHelper(sig, KindConstructSignature, null));
			}
		}
		// Call signatures
		final callSigs = resolved.CallSignatures();
		if (callSigs != null) {
			for (sig in callSigs) {
				if (members == null) members = [];
				members.push(b.signatureToSignatureDeclarationHelper(sig, KindCallSignature, null));
			}
		}
		// Properties, filtering inherited
		final filteredProps = b.filterInheritedProperties(interfaceType, baseTypes, resolved.properties);
		members = b.serializePropertiesWithTruncation(filteredProps, members);

		// Heritage clauses
		final heritageClauses = b.hoverHeritageClauses(interfaceDeclarations);

		return b.f.NewInterfaceDeclaration(null, b.f.NewIdentifier(name), b.f.NewNodeList(typeParamDecls), b.f.NewNodeList(heritageClauses),
			b.f.NewNodeList(members));
	}

	static function hoverHeritageClauses(b:NodeBuilderImpl, declarations:Array<Node>):Array<Node> {
		var extendsTypes:Array<Node> = null;
		var implementsTypes:Array<Node> = null;
		if (declarations != null) {
			for (declaration in declarations) {
				final ext = Ast.GetExtendsHeritageClauseElements(declaration);
				if (ext != null) {
					for (heritageElement in ext) {
						if (extendsTypes == null) extendsTypes = [];
						extendsTypes.push(b.f.DeepCloneNode(heritageElement.AsNode()));
					}
				}
				final impl = Ast.GetImplementsHeritageClauseElements(declaration);
				if (impl != null) {
					for (heritageElement in impl) {
						if (implementsTypes == null) implementsTypes = [];
						implementsTypes.push(b.f.DeepCloneNode(heritageElement.AsNode()));
					}
				}
			}
		}

		var heritageClauses:Array<Node> = null;
		if (Core.len(extendsTypes) > 0) {
			if (heritageClauses == null) heritageClauses = [];
			heritageClauses.push(b.f.NewHeritageClause(KindExtendsKeyword, b.f.NewNodeList(extendsTypes)));
		}
		if (Core.len(implementsTypes) > 0) {
			if (heritageClauses == null) heritageClauses = [];
			heritageClauses.push(b.f.NewHeritageClause(KindImplementsKeyword, b.f.NewNodeList(implementsTypes)));
		}
		return heritageClauses;
	}

	// serializePropertiesWithTruncation iterates properties using addPropertyToElementList,
	// with truncation checks matching Strada's createTypeNodesFromResolvedType behavior.
	static function serializePropertiesWithTruncation(b:NodeBuilderImpl, properties:Array<Symbol>, elements:Array<Node>):Array<Node> {
		properties = Core.Filter(properties, (p:Symbol) -> {
			return p.Flags & SymbolFlagsPrototype == 0;
		});
		if (properties != null) {
			for (i in 0...properties.length) {
				final p = properties[i];
				if (b.checkTruncationLengthIfExpanding() && (i + 3 < properties.length - 1)) {
					b.ctx.expansionTruncated = true;
					final text = Fmt.Sprintf("... %d more ...", [properties.length - i - 1]);
					if (elements == null) elements = [];
					elements.push(b.f.NewPropertySignatureDeclaration(null, b.f.NewIdentifier(text), null, null, null));
					elements = b.addPropertyToElementList(properties[properties.length - 1], elements);
					break;
				}
				elements = b.addPropertyToElementList(p, elements);
			}
		}
		return elements;
	}

	// serializeConstructors builds constructor signature(s) for a class, with base type filtering.
	static function serializeConstructors(b:NodeBuilderImpl, staticType:Type, staticBaseType:Type, isClass:Bool, symbol:Symbol):Array<Node> {
		final isNonConstructable = !isClass
			&& symbol.ValueDeclaration != null
			&& Ast.IsInJSFile(symbol.ValueDeclaration)
			&& Core.len(b.ch.getSignaturesOfType(staticType, SignatureKindConstruct)) == 0;
		if (isNonConstructable) {
			b.ctx.approximateLength += 21;
			final modifiers = Ast.CreateModifiersFromModifierFlags(ModifierFlagsPrivate, kind -> b.f.NewModifier(kind));
			return [b.f.NewConstructorDeclaration(b.f.NewModifierList(modifiers), null, b.f.NewNodeList(null), null, null, null)];
		}
		final signatures = b.ch.getSignaturesOfType(staticType, SignatureKindConstruct);
		if (staticBaseType != null) {
			final baseSigs = b.ch.getSignaturesOfType(staticBaseType, SignatureKindConstruct);
			if (Core.len(baseSigs) == 0 && Core.Every(signatures, (sig:Signature) -> Core.len(sig.parameters) == 0)) {
				return null;
			}
			if (Core.len(baseSigs) == Core.len(signatures)) {
				var allMatch = true;
				for (i in 0...Core.len(baseSigs)) {
					if (b.ch.compareSignaturesIdentical(signatures[i], baseSigs[i], false, false, true,
						(s, t) -> b.ch.compareTypesIdentical(s, t)) != TernaryTrue) {
						allMatch = false;
						break;
					}
				}
				if (allMatch) {
					return null;
				}
			}
			var privateProtected:ModifierFlags = 0;
			if (signatures != null) {
				for (sig in signatures) {
					if (sig.declaration != null) {
						privateProtected |= sig.declaration.ModifierFlags() & (ModifierFlagsPrivate | ModifierFlagsProtected);
					}
				}
			}
			if (privateProtected != 0) {
				return [
					b.f.NewConstructorDeclaration(b.f.NewModifierList(Ast.CreateModifiersFromModifierFlags(privateProtected, kind -> b.f.NewModifier(kind))), null,
						b.f.NewNodeList(null), null, null, null)
				];
			}
		} else if (Core.Every(signatures, (sig:Signature) -> Core.len(sig.parameters) == 0)) {
			return null;
		}
		var result:Array<Node> = null;
		if (signatures != null) {
			for (sig in signatures) {
				b.ctx.approximateLength++;
				if (result == null) result = [];
				result.push(b.signatureToSignatureDeclarationHelper(sig, KindConstructor, null));
			}
		}
		return result;
	}

	// serializeIndexSignaturesOfType builds index signature declarations, filtering those identical to baseType.
	static function serializeIndexSignaturesOfType(b:NodeBuilderImpl, input:Type, baseType:Type):Array<Node> {
		var result:Array<Node> = null;
		final infos = b.ch.getIndexInfosOfType(input);
		if (infos != null) {
			for (info in infos) {
				if (baseType != null) {
					final baseInfo = b.ch.getIndexInfoOfType(baseType, info.keyType);
					if (baseInfo != null && b.ch.isTypeIdenticalTo(info.valueType, baseInfo.valueType)) {
						continue;
					}
				}
				if (result == null) result = [];
				result.push(b.indexInfoToIndexSignatureDeclarationHelper(info, null));
			}
		}
		return result;
	}

	// serializeNamespaceMember produces the appropriate declaration node for a namespace member
	// based on its symbol flags (type alias, enum, class, interface, nested namespace, or variable).
	static function serializeNamespaceMember(b:NodeBuilderImpl, resolved:Symbol, name:std.String):Node {
		if (resolved.Flags & SymbolFlagsTypeAlias != 0) {
			return b.serializeTypeAliasForNamespace(resolved, name);
		} else if (resolved.Flags & SymbolFlagsEnum != 0) {
			return b.expandEnumDecl(resolved);
		} else if (resolved.Flags & SymbolFlagsClass != 0) {
			return b.expandClassDecl(resolved);
		} else if (resolved.Flags & SymbolFlagsInterface != 0) {
			return b.expandInterfaceDecl(resolved);
		} else if (resolved.Flags & (SymbolFlagsValueModule | SymbolFlagsNamespaceModule) != 0) {
			return b.expandModuleDecl(resolved);
		} else {
			final t = b.ch.getWidenedType(b.ch.getTypeOfSymbol(resolved));
			b.ctx.approximateLength += Utf8.ByteLen(name) + 5; // PORT: byte (Go len of a UTF-8 string)
			return b.f.NewVariableStatement(null,
				b.f.NewVariableDeclarationList(b.f.NewNodeList([
					b.f.NewVariableDeclaration(b.f.NewIdentifier(name), null, b.serializeTypeForDeclaration(null, t, resolved, true), null),
				]), NodeFlagsLet));
		}
	}

	// expandModuleDecl produces a ModuleDeclaration with exported members.
	static function expandModuleDecl(b:NodeBuilderImpl, symbol:Symbol):Node {
		final exports = b.ch.getExportsOfSymbol(symbol);
		var members:Array<Symbol> = null;
		// Go map iteration order is random; members are sorted by sortSymbols below.
		if (exports != null) {
			for (sym in exports) {
				// Filter to namespace-relevant members
				if (!b.isNamespaceMember(sym)) {
					continue;
				}
				if (!Scanner.IsIdentifierText(sym.Name, LanguageVariantStandard)) {
					continue;
				}
				if (members == null) members = [];
				members.push(sym);
			}
		}
		b.ch.sortSymbols(members);
		b.ctx.approximateLength += 14;

		// Use the same name as symbol display.
		final oldFlags = b.ctx.flags;
		// PORT: defer restoring flags → restored before the single return below.
		b.ctx.flags = b.ctx.flags | FlagsWriteTypeParametersInQualifiedName | ((SymbolFormatFlagsUseOnlyExternalAliasing : Int) : Flags);
		final localName = b.symbolToNode(symbol, SymbolFlagsAll);
		b.ctx.flags = oldFlags;

		// PORT: Go []hoverStatement{node, isLocal} → two parallel arrays.
		final bodyNodes:Array<Node> = [];
		final bodyIsLocal:Array<Bool> = []; // local declarations (e.g. alias targets) should not get export modifier
		final emittedLocals = new Set<Symbol>();
		final membersLen = Core.len(members);
		var i = 0;
		while (i < membersLen) {
			final m = members[i];
			if (b.checkTruncationLengthIfExpanding() && i + 3 < membersLen - 1) {
				b.ctx.expansionTruncated = true;
				bodyNodes.push(b.f.NewExpressionStatement(b.f.NewIdentifier(Fmt.Sprintf("... (%d more) ...", [membersLen - i - 1]))));
				bodyIsLocal.push(false);
				i = membersLen - 2; // skip to last member after i++ at end of iteration
				i++;
				continue;
			}

			// Handle alias/re-export symbols
			if (m.Flags & SymbolFlagsAlias != 0) {
				final aliasDecl = b.ch.getDeclarationOfAliasSymbol(m);
				final target = b.ch.getMergedSymbol(b.ch.getTargetOfAliasDeclaration(aliasDecl));
				if (target != null) {
					// If the alias target is a local symbol (not itself an export), emit its declaration first
					if (target.Flags & (SymbolFlagsBlockScopedVariable | SymbolFlagsFunctionScopedVariable | SymbolFlagsProperty) != 0) {
						if (emittedLocals.AddIfAbsent(target)) {
							final localType = b.ch.getWidenedType(b.ch.getTypeOfSymbol(target));
							b.ctx.approximateLength += Utf8.ByteLen(target.Name) + 5; // PORT: byte (Go len of a UTF-8 string)
							final localStmt = b.f.NewVariableStatement(null,
								b.f.NewVariableDeclarationList(b.f.NewNodeList([
									b.f.NewVariableDeclaration(b.f.NewIdentifier(target.Name), null, b.serializeTypeForDeclaration(null, localType, target, true), null),
								]), NodeFlagsLet));
							bodyNodes.push(localStmt);
							bodyIsLocal.push(true);
						}
					}
					final targetName = target.Name;
					b.ctx.approximateLength += 16 + Utf8.ByteLen(m.Name); // PORT: byte (Go len of a UTF-8 string)
					var propertyName:Node = null;
					if (m.Name != targetName) {
						propertyName = b.f.NewIdentifier(targetName);
					}
					final stmt = b.f.NewExportDeclaration(null, false,
						b.f.NewNamedExports(b.f.NewNodeList([b.f.NewExportSpecifier(false, propertyName, b.f.NewIdentifier(m.Name)),])), null, null);
					bodyNodes.push(stmt);
					bodyIsLocal.push(false);
					i++;
					continue;
				}
			}

			final resolved = b.ch.resolveSymbol(m);

			// Handle functions as function declarations
			if (resolved.Flags & (SymbolFlagsFunction | SymbolFlagsMethod) != 0) {
				final t = b.ch.getTypeOfSymbol(resolved);
				final sigs = b.ch.getSignaturesOfType(t, SignatureKindCall);
				if (sigs != null) {
					for (sig in sigs) {
						b.ctx.approximateLength++;
						final opts = new SignatureToSignatureDeclarationOptions();
						opts.name = b.f.NewIdentifier(m.Name);
						final decl = b.signatureToSignatureDeclarationHelper(sig, KindFunctionDeclaration, opts);
						bodyNodes.push(decl);
						bodyIsLocal.push(false);
					}
				}
				// If the function also has namespace characteristics, emit an empty namespace.
				final merged = b.ch.getMergedSymbol(resolved);
				final hasModuleExports = merged.Flags & (SymbolFlagsValueModule | SymbolFlagsNamespaceModule) != 0 && merged.Exports != null
					&& merged.Exports.keys().hasNext();
				if (!hasModuleExports) {
					bodyNodes.push(b.f.NewModuleDeclaration(null, KindNamespaceKeyword, b.f.NewIdentifier(m.Name), b.f.NewModuleBlock(b.f.NewNodeList(null))));
					bodyIsLocal.push(false);
				}
				i++;
				continue;
			}

			// Handle remaining member kinds (type alias, enum, class, interface, namespace, variable)
			final node = b.serializeNamespaceMember(resolved, m.Name);
			if (node != null) {
				bodyNodes.push(node);
				bodyIsLocal.push(false);
			}
			i++;
		}

		// Add export modifier to exported statements (skip local declarations and ExportDeclarations).
		for (i in 0...bodyNodes.length) {
			if (bodyIsLocal[i] || Ast.IsExportDeclaration(bodyNodes[i])) {
				continue;
			}
			if (Ast.CanHaveModifiers(bodyNodes[i])) {
				final mf = bodyNodes[i].ModifierFlags() | ModifierFlagsExport;
				bodyNodes[i] = Ast.ReplaceModifiers(b.f, bodyNodes[i], b.f.NewModifierList(Ast.CreateModifiersFromModifierFlags(mf, kind -> b.f.NewModifier(kind))));
			}
		}

		// Collect nodes, stripping export if all statements are exported.
		final bodyStatements:Array<Node> = bodyNodes.copy();
		final allExported = bodyStatements.length > 0 && Core.Every(bodyStatements, (d:Node) -> {
			return Ast.HasSyntacticModifier(d, ModifierFlagsExport);
		});
		if (allExported) {
			for (i in 0...bodyStatements.length) {
				final stmt = bodyStatements[i];
				if (Ast.CanHaveModifiers(stmt)) {
					final mf = stmt.ModifierFlags() & ~ModifierFlagsExport;
					bodyStatements[i] = Ast.ReplaceModifiers(b.f, stmt, b.f.NewModifierList(Ast.CreateModifiersFromModifierFlags(mf, kind -> b.f.NewModifier(kind))));
				}
			}
		}

		var keyword = KindNamespaceKeyword;
		if (!Ast.IsIdentifier(localName)) {
			keyword = KindModuleKeyword;
		}
		final result = b.f.NewModuleDeclaration(null, keyword, localName, b.f.NewModuleBlock(b.f.NewNodeList(bodyStatements)));
		b.ctx.flags = oldFlags;
		return result;
	}

	// serializeTypeAliasForNamespace produces a TypeAliasDeclaration for a type alias inside a namespace body.
	static function serializeTypeAliasForNamespace(b:NodeBuilderImpl, symbol:Symbol, name:std.String):Node {
		final aliasType = b.ch.getDeclaredTypeOfTypeAlias(symbol);
		final typeParams = b.ch.getLocalTypeParametersOfClassOrInterfaceOrTypeAlias(symbol);
		final typeParamDecls = Core.Map(typeParams, (p:Type) -> b.typeParameterToDeclaration(p));
		final restoreFlags = b.saveRestoreFlags();
		b.ctx.flags |= FlagsInTypeAlias;
		final typeNode = b.typeToTypeNode(aliasType);
		restoreFlags();
		b.ctx.approximateLength += 8 + Utf8.ByteLen(name); // PORT: byte (Go len of a UTF-8 string)
		return b.f.NewTypeAliasDeclaration(null, b.f.NewIdentifier(name), b.f.NewNodeList(typeParamDecls), typeNode);
	}

	// filterInheritedProperties removes properties already present in base types.
	static function filterInheritedProperties(b:NodeBuilderImpl, t:Type, baseTypes:Array<Type>, properties:Array<Symbol>):Array<Symbol> {
		if (Core.len(baseTypes) == 0) {
			return properties;
		}
		// Build a lookup from property name to symbol for parent-identity comparison.
		final propsByName = new StringMap<Symbol>();
		if (properties != null) {
			for (p in properties) {
				propsByName.set(p.Name, p);
			}
		}
		// Collect names of properties inherited unchanged from base types.
		final inherited = new Set<std.String>();
		for (base in baseTypes) {
			final baseWithThis = b.ch.getTypeWithThisArgument(base, b.ch.getTargetType(t).AsInterfaceType().thisType, false);
			final props = b.ch.getPropertiesOfType(baseWithThis);
			if (props != null) {
				for (prop in props) {
					if (propsByName.exists(prop.Name) && prop.Parent == propsByName.get(prop.Name).Parent) {
						inherited.Add(prop.Name);
					}
				}
			}
		}
		if (inherited.Len() == 0) {
			return properties;
		}
		return Core.Filter(properties, (p:Symbol) -> {
			return !inherited.Has(p.Name);
		});
	}

	static function isNamespaceMember(b:NodeBuilderImpl, p:Symbol):Bool {
		return p.Flags & (SymbolFlagsType | SymbolFlagsNamespace | SymbolFlagsAlias) != 0
			|| !(p.Flags & SymbolFlagsPrototype != 0
				|| p.Name == "prototype"
				|| (p.ValueDeclaration != null && Ast.HasStaticModifier(p.ValueDeclaration) && Ast.IsClassLike(p.ValueDeclaration.Parent)));
	}
}
