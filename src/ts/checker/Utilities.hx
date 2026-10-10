package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/utilities.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

enum abstract AssignmentKind(Int) from Int to Int {
	var AssignmentKindNone = 0;
	var AssignmentKindDefinite = 1;
	var AssignmentKindCompound = 2;
}

typedef AssignmentTarget = Node;

@:allow(ts.checker)
class OrderedSet<T> {
	var valuesByKey:GoMap<T, Bool> = null;
	var values:Array<T> = null;

	public function new() {}

	function contains(value:T):Bool {
		if (this.valuesByKey == null) {
			return Slices.Contains(this.values, value);
		}
		return this.valuesByKey.exists(value);
	}

	function add(value:T):Void {
		if (this.values == null) {
			this.values = [];
		}
		this.values.push(value);
		// Small sets are served by a linear scan over values; only materialize the map once the set
		// grows large enough for hashing to win.
		if (this.valuesByKey == null) {
			if (this.values.length <= Checker.orderedSetMapThreshold) {
				return;
			}
			this.valuesByKey = new GoMap<T, Bool>();
			for (i in 0...this.values.length - 1) {
				this.valuesByKey.set(this.values[i], true);
			}
		}
		this.valuesByKey.set(value, true);
	}
}

@:allow(ts.checker)
class FeatureMapEntry {
	var lib:std.String = "";
	var props:Array<std.String> = null;

	public function new() {}
}

// DiagnosticDetails holds a resolved diagnostic message and its arguments,
// used for sharing diagnostic chain computation between the checker and incremental builder.
class DiagnosticDetails {
	public var Message:Message = null;
	public var Args:Array<Any> = null;

	public function new() {}
}

// Methods of utilities.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class Utilities {

	static function isOptionalParameter(c:Checker, node:Node):Bool {
		// !!! TODO: JSDoc support
		if (Ast.IsParameterDeclaration(node) && node.QuestionToken() != null) {
			return true;
		}
		if (!Ast.IsParameterDeclaration(node)) {
			return false;
		}
		if (node.Initializer() != null) {
			final signature = c.getSignatureFromDeclaration(node.Parent);
			final parameterIndex = Core.FindIndex(node.Parent.Parameters(), (p:Node) -> p == node);
			Debug.Assert(parameterIndex >= 0);
			// Only consider syntactic or instantiated parameters as optional, not `void` parameters as this function is used
			// in grammar checks and checking for `void` too early results in parameter types widening too early
			// and causes some noImplicitAny errors to be lost.
			return parameterIndex >= c.getMinArgumentCountEx(signature, MinArgumentCountFlagsStrongArityForUntypedJS | MinArgumentCountFlagsVoidIsNonOptional);
		}
		final iife = Ast.GetImmediatelyInvokedFunctionExpression(node.Parent);
		if (iife != null) {
			final parameterIndex = Core.FindIndex(node.Parent.Parameters(), (p:Node) -> p == node);
			return node.Type() == null && node.AsParameterDeclaration().DotDotDotToken == null
				&& parameterIndex >= Core.len(c.getEffectiveCallArguments(iife));
		}
		return false;
	}

	static function sortSymbols(c:Checker, symbols:Array<Symbol>):Void {
		Slices.SortFunc(symbols, c.compareSymbols);
	}

	static function compareSymbolsWorker(c:Checker, s1:Symbol, s2:Symbol):Int {
		if (s1 == s2) {
			return 0;
		}
		if (s1 == null) {
			return 1;
		}
		if (s2 == null) {
			return -1;
		}
		if (Core.len(s1.Declarations) != 0 && Core.len(s2.Declarations) != 0) {
			final r = c.compareNodes(s1.Declarations[0], s2.Declarations[0]);
			if (r != 0) {
				return r;
			}
		} else if (Core.len(s1.Declarations) != 0) {
			return -1;
		} else if (Core.len(s2.Declarations) != 0) {
			return 1;
		}
		final r = Strings.Compare(s1.Name, s2.Name);
		if (r != 0) {
			return r;
		}
		// Fall back to symbol IDs. This is a last resort that should happen only when symbols have
		// no declaration and duplicate names.
		return Ast.GetSymbolId(s1) - Ast.GetSymbolId(s2);
	}

	static function compareNodes(c:Checker, n1:Node, n2:Node):Int {
		if (n1 == n2) {
			return 0;
		}
		if (n1 == null) {
			return 1;
		}
		if (n2 == null) {
			return -1;
		}
		final s1 = Ast.GetSourceFileOfNode(n1);
		final s2 = Ast.GetSourceFileOfNode(n2);
		if (s1 != s2) {
			final i1 = c.fileIndexMap.get(s1);
			final i2 = c.fileIndexMap.get(s2);
			final f1:Int = i1 == null ? 0 : i1;
			final f2:Int = i2 == null ? 0 : i2;
			// Order by index of file in the containing program
			return f1 - f2;
		}
		// In the same file, order by source position
		return n1.Pos() - n2.Pos();
	}

	static function isConstantVariable(c:Checker, symbol:Symbol):Bool {
		return symbol.Flags & SymbolFlagsVariable != 0 && (c.getDeclarationNodeFlagsFromSymbol(symbol) & NodeFlagsConstant) != 0;
	}

	static function isParameterOrMutableLocalVariable(c:Checker, symbol:Symbol):Bool {
		// Return true if symbol is a parameter, a catch clause variable, or a mutable local variable
		if (symbol.ValueDeclaration != null) {
			final declaration = Ast.GetRootDeclaration(symbol.ValueDeclaration);
			return declaration != null
				&& (Ast.IsParameterDeclaration(declaration)
					|| Ast.IsVariableDeclaration(declaration) && (Ast.IsCatchClause(declaration.Parent) || c.isMutableLocalVariableDeclaration(declaration)));
		}
		return false;
	}

	static function isMutableLocalVariableDeclaration(c:Checker, declaration:Node):Bool {
		// Return true if symbol is a non-exported and non-global `let` variable
		return declaration.Parent.Flags & NodeFlagsLet != 0
			&& !(Ast.GetCombinedModifierFlags(declaration) & ModifierFlagsExport != 0
				|| declaration.Parent.Parent.Kind == KindVariableStatement && Ast.IsGlobalSourceFile(declaration.Parent.Parent.Parent));
	}

	static function callLikeExpressionMayHaveTypeArguments(c:Checker, node:Node):Bool {
		return Ast.IsCallOrNewExpression(node) || Ast.IsTaggedTemplateExpression(node) || Ast.IsJsxOpeningLikeElement(node);
	}

	static function isCanceled(c:Checker):Bool {
		return c.ctx != null && c.ctx.Err() != null;
	}

	static function checkNotCanceled(c:Checker):Void {
		if (c.wasCanceled) {
			throw "Checker was previously cancelled";
		}
	}

	static function getPackagesMap(c:Checker):StringMap<Bool> {
		if (c.packagesMap == null) {
			c.packagesMap = new StringMap<Bool>();
			final resolvedModules = c.program.GetResolvedModules();
			if (resolvedModules != null) {
				for (resolvedModulesInFile in resolvedModules) {
					if (resolvedModulesInFile == null) {
						continue;
					}
					for (module in resolvedModulesInFile) {
						if (module.PackageId.Name != "") {
							c.packagesMap.set(module.PackageId.Name, c.packagesMap.get(module.PackageId.Name) == true || module.Extension == Tspath.ExtensionDts);
						}
					}
				}
			}
		}
		return c.packagesMap;
	}

	static function typesPackageExists(c:Checker, packageName:std.String):Bool {
		final packagesMap = c.getPackagesMap();
		return packagesMap.exists(Module.GetTypesPackageName(packageName));
	}

	static function packageBundlesTypes(c:Checker, packageName:std.String):Bool {
		final packagesMap = c.getPackagesMap();
		return packagesMap.get(packageName) == true;
	}

	// Determines whether a did-you-mean error should be a suggestion in an unchecked JS file.
	// Only applies to unchecked JS files without checkJS, // @ts-check or // @ts-nocheck
	// It does not suggest when the suggestion:
	// - Is from a global file that is different from the reference file, or
	// - (optionally) Is a class, or is a this.x property access expression
	static function isUncheckedJSSuggestion(c:Checker, node:Node, suggestion:Symbol, excludeClasses:Bool):Bool {
		final file = Ast.GetSourceFileOfNode(node);
		if (file != null) {
			if (c.compilerOptions.CheckJs.IsUnknown() && file.CheckJsDirective == null && (file.ScriptKind == ScriptKindJS || file.ScriptKind == ScriptKindJSX)) {
				var declarationFile:SourceFile = null;
				if (suggestion != null) {
					final firstDeclaration = Core.FirstOrNil(suggestion.Declarations);
					if (firstDeclaration != null) {
						declarationFile = Ast.GetSourceFileOfNode(firstDeclaration);
					}
				}
				final suggestionHasNoExtendsOrDecorators = suggestion == null
					|| suggestion.ValueDeclaration == null
					|| !Ast.IsClassLike(suggestion.ValueDeclaration)
					|| Core.len(Ast.GetExtendsHeritageClauseElements(suggestion.ValueDeclaration)) != 0
					|| Ast.ClassOrConstructorParameterIsDecorated(false, suggestion.ValueDeclaration);
				return !(file != declarationFile && declarationFile != null && Ast.IsGlobalSourceFile(declarationFile.AsNode()))
					&& !(excludeClasses && suggestion != null && suggestion.Flags & SymbolFlagsClass != 0 && suggestionHasNoExtendsOrDecorators)
					&& !(node != null && excludeClasses && Ast.IsPropertyAccessExpression(node) && node.Expression().Kind == KindThisKeyword
						&& suggestionHasNoExtendsOrDecorators);
			}
		}
		return false;
	}

	// Returns if a type is or consists of a JSLiteral object type
	// In addition to objects which are directly literals,
	// * unions where every element is a jsliteral
	// * intersections where at least one element is a jsliteral
	// * and instantiable types constrained to a jsliteral
	// Should all count as literals and not print errors on access or assignment of possibly existing properties.
	// This mirrors the behavior of the index signature propagation, to which this behaves similarly (but doesn't affect assignability or inference).
	static function isJSLiteralType(c:Checker, t:Type):Bool {
		if (c.noImplicitAny) {
			return false;
			// Flag is meaningless under `noImplicitAny` mode
		}
		if (t.objectFlags & ObjectFlagsJSLiteral != 0) {
			return true;
		}
		if (t.flags & TypeFlagsUnion != 0) {
			return Core.Every(t.AsUnionType().types, (u:Type) -> c.isJSLiteralType(u));
		}
		if (t.flags & TypeFlagsIntersection != 0) {
			return Core.Some(t.AsIntersectionType().types, (u:Type) -> c.isJSLiteralType(u));
		}
		if (t.flags & TypeFlagsInstantiable != 0) {
			final constraint = c.getResolvedBaseConstraint(t, null);
			return constraint != t && c.isJSLiteralType(constraint);
		}
		return false;
	}
}
