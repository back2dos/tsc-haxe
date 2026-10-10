package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/nodebuilderscopes.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.checker)
class LocalsRecord {
	var name:std.String = "";
	var oldSymbol:Symbol = null;

	public function new() {}
}

// Methods of nodebuilderscopes.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class Nodebuilderscopes {

	static function addSymbolTypeToContext(b:NodeBuilderImpl, symbol:Symbol, t:Type):() -> Void {
		final id = Ast.GetSymbolId(symbol);
		final oldTypeExists = b.ctx.enclosingSymbolTypes.exists(id);
		final oldType = b.ctx.enclosingSymbolTypes.get(id);
		b.ctx.enclosingSymbolTypes.set(id, t);
		return () -> {
			if (oldTypeExists) {
				b.ctx.enclosingSymbolTypes.set(id, oldType);
			} else {
				b.ctx.enclosingSymbolTypes.remove(id);
			}
		};
	}

	static function enterSignatureScope(b:NodeBuilderImpl, signature:Signature):Pair<Array<Symbol>, () -> Void> {
		final expandedParams = b.ch.getExpandedParameters(signature, true /*skipUnionExpanding*/)[0];
		final cleanup = b.enterNewScope(signature.declaration, expandedParams, signature.typeParameters, signature.parameters, signature.mapper);
		return new Pair<Array<Symbol>, () -> Void>(expandedParams, cleanup);
	}

	static function enterNewScope(b:NodeBuilderImpl, declaration:Node, expandedParams:Array<Symbol>, typeParameters:Array<Type>, originalParameters:Array<Symbol>, mapper:TypeMapper):() -> Void {
		final cleanupContext = Checker.cloneNodeBuilderContext(b.ctx);
		// For regular function/method declarations, the enclosing declaration will already be signature.declaration,
		// so this is a no-op, but for arrow functions and function expressions, the enclosing declaration will be
		// the declaration that the arrow function / function expression is assigned to.
		//
		// If the parameters or return type include "typeof globalThis.paramName", using the wrong scope will lead
		// us to believe that we can emit "typeof paramName" instead, even though that would refer to the parameter,
		// not the global. Make sure we are in the right scope by changing the enclosingDeclaration to the function.
		//
		// We can't use the declaration directly; it may be in another file and so we may lose access to symbols
		// accessible to the current enclosing declaration, or gain access to symbols not accessible to the current
		// enclosing declaration. To keep this chain accurate, insert a fake scope into the chain which makes the
		// function's parameters visible.
		var cleanupParams:() -> Void = null;
		var cleanupTypeParams:() -> Void = null;
		final oldEnclosingDecl = b.ctx.enclosingDeclaration;
		final oldMapper = b.ctx.mapper;
		if (mapper != null) {
			b.ctx.mapper = mapper;
		}
		if (b.ctx.enclosingDeclaration != null && declaration != null) {
			// As a performance optimization, reuse the same fake scope within this chain.
			// This is especially needed when we are working on an excessively deep type;
			// if we don't do this, then we spend all of our time adding more and more
			// scopes that need to be searched in isSymbolAccessible later. Since all we
			// really want to do is to mark certain names as unavailable, we can just keep
			// all of the names we're introducing in one large table and push/pop from it as
			// needed; isSymbolAccessible will walk upward and find the closest "fake" scope,
			// which will conveniently report on any and all faked scopes in the chain.
			//
			// It'd likely be better to store this somewhere else for isSymbolAccessible, but
			// since that API _only_ uses the enclosing declaration (and its parents), this is
			// seems like the best way to inject names into that search process.
			//
			// Note that we only check the most immediate enclosingDeclaration; the only place we
			// could potentially add another fake scope into the chain is right here, so we don't
			// traverse all ancestors.
			final pushFakeScope = (kind:std.String, addAll:(addSymbol:(name:std.String, symbol:Symbol) -> Void) -> Void) -> {
				// We only ever need to look two declarations upward.
				Debug.Assert(b.ctx.enclosingDeclaration != null);
				var existingFakeScope:Node = null;
				if (b.links.Has(b.ctx.enclosingDeclaration)) {
					final links = b.links.Get(b.ctx.enclosingDeclaration);
					if (links.fakeScopeForSignatureDeclaration != null && links.fakeScopeForSignatureDeclaration == kind) {
						existingFakeScope = b.ctx.enclosingDeclaration;
					}
				}
				if (existingFakeScope == null && b.ctx.enclosingDeclaration.Parent != null) {
					if (b.links.Has(b.ctx.enclosingDeclaration.Parent)) {
						final links = b.links.Get(b.ctx.enclosingDeclaration.Parent);
						if (links.fakeScopeForSignatureDeclaration != null && links.fakeScopeForSignatureDeclaration == kind) {
							existingFakeScope = b.ctx.enclosingDeclaration.Parent;
						}
					}
				}
				Debug.Assert(existingFakeScope == null || Ast.IsBlock(existingFakeScope));

				var locals:SymbolTable = null;
				if (existingFakeScope != null) {
					locals = existingFakeScope.Locals();
				}
				if (locals == null) {
					locals = new SymbolTable();
				}
				final newLocals:Array<std.String> = [];
				final oldLocals:Array<LocalsRecord> = [];
				addAll((name:std.String, symbol:Symbol) -> {
					// Add cleanup information only if we don't own the fake scope
					if (existingFakeScope != null) {
						final oldSymbol = locals.get(name);
						if (!locals.exists(name) || oldSymbol == null) {
							newLocals.push(name);
						} else {
							final rec = new LocalsRecord();
							rec.name = name;
							rec.oldSymbol = oldSymbol;
							oldLocals.push(rec);
						}
					}
					locals.set(name, symbol);
				});

				if (existingFakeScope == null) {
					// Use a Block for this; the type of the node doesn't matter so long as it
					// has locals, and this is cheaper/easier than using a function-ish Node.
					final fakeScope = b.f.NewBlock(b.f.NewNodeList([]), false);
					b.links.Get(fakeScope).fakeScopeForSignatureDeclaration = kind;
					final data = fakeScope.LocalsContainerData();
					data.Locals = locals;
					fakeScope.Parent = b.ctx.enclosingDeclaration;
					b.ctx.enclosingDeclaration = fakeScope;
					return null;
				} else {
					// We did not create the current scope, so we have to clean it up
					final undo = () -> {
						for (s in newLocals) {
							locals.remove(s);
						}
						for (s in oldLocals) {
							locals.set(s.name, s.oldSymbol);
						}
					};
					return undo;
				}
			};

			if (expandedParams == null || !Core.Some(expandedParams, (p:Symbol) -> p != null)) {
				cleanupParams = null;
			} else {
				cleanupParams = pushFakeScope("params", (add:(name:std.String, symbol:Symbol) -> Void) -> {
					if (expandedParams == null) {
						return;
					}
					for (pIndex in 0...expandedParams.length) {
						final param = expandedParams[pIndex];
						var originalParam:Symbol = null;
						if (pIndex < Core.len(originalParameters)) {
							originalParam = originalParameters[pIndex];
						}
						if (originalParameters != null && originalParam != param) {
							// Can't reference the expanded parameter name, just the original, unless we've expanded the param list for some reason
							if (originalParam != null) {
								add(originalParam.Name, originalParam);
							}
						} else if (!Core.Some(param.Declarations, (d:Node) -> {
							var bindElement:(e:BindingElement) -> Void = null;
							var bindPattern:(e:BindingPattern) -> Void = null;

							final bindPatternWorker = (p:BindingPattern) -> {
								for (e in p.Elements.Nodes) {
									switch (e.Kind) {
										case KindOmittedExpression:
											return;
										case KindBindingElement:
											bindElement(e.AsBindingElement());
											return;
										default:
											throw "Unhandled binding element kind";
									}
								}
							};

							final bindElementWorker = (e:BindingElement) -> {
								if (e.Name() != null && Ast.IsBindingPattern(e.Name())) {
									bindPattern(e.Name().AsBindingPattern());
									return;
								}
								final symbol = b.ch.getSymbolOfDeclaration(e.AsNode());
								if (symbol != null) { // omitted expressions are now parsed as nameless binding patterns and also have no symbol
									add(symbol.Name, symbol);
								}
							};
							bindElement = bindElementWorker;
							bindPattern = bindPatternWorker;

							if (Ast.IsParameterDeclaration(d) && d.Name() != null && Ast.IsBindingPattern(d.Name())) {
								bindPattern(d.Name().AsBindingPattern());
								return true;
							}
							return false;
						})) {
							add(param.Name, param);
						}
					}
				});
			}

			if (b.ctx.flags & FlagsGenerateNamesForShadowedTypeParams != 0 && typeParameters != null
				&& Core.Some(typeParameters, (p:Type) -> p != null)) {
				cleanupTypeParams = pushFakeScope("typeParams", (add:(name:std.String, symbol:Symbol) -> Void) -> {
					if (typeParameters == null) {
						return;
					}
					for (typeParam in typeParameters) {
						if (typeParam == null) {
							continue;
						}
						final typeParamName = b.typeParameterToName(typeParam).Text;
						add(typeParamName, typeParam.symbol);
					}
				});
			}
		}

		return () -> {
			if (cleanupParams != null) {
				cleanupParams();
			}
			if (cleanupTypeParams != null) {
				cleanupTypeParams();
			}
			cleanupContext();
			b.ctx.enclosingDeclaration = oldEnclosingDecl;
			b.ctx.mapper = oldMapper;
		};
	}
}
