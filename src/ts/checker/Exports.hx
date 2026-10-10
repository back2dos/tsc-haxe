package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/exports.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Methods of exports.go on receivers declared in other files: static extension (PORTING.md §2).
class Exports {

	public static function GetStringType(c:Checker):Type {
		return c.stringType;
	}

	public static function GetNumberType(c:Checker):Type {
		return c.numberType;
	}

	public static function GetBooleanType(c:Checker):Type {
		return c.booleanType;
	}

	public static function GetVoidType(c:Checker):Type {
		return c.voidType;
	}

	public static function GetUndefinedType(c:Checker):Type {
		return c.undefinedType;
	}

	public static function GetNullType(c:Checker):Type {
		return c.nullType;
	}

	public static function GetAnyType(c:Checker):Type {
		return c.anyType;
	}

	public static function GetErrorType(c:Checker):Type {
		return c.errorType;
	}

	public static function GetNeverType(c:Checker):Type {
		return c.neverType;
	}

	public static function GetUnknownType(c:Checker):Type {
		return c.unknownType;
	}

	public static function GetBigIntType(c:Checker):Type {
		return c.bigintType;
	}

	public static function GetESSymbolType(c:Checker):Type {
		return c.esSymbolType;
	}

	public static function GetBaseTypeOfLiteralType(c:Checker, t:Type):Type {
		return c.getBaseTypeOfLiteralType(t);
	}

	public static function GetUnknownSymbol(c:Checker):Symbol {
		return c.unknownSymbol;
	}

	public static function GetUndefinedSymbol(c:Checker):Symbol {
		return c.undefinedSymbol;
	}

	public static function GetArgumentsSymbol(c:Checker):Symbol {
		return c.argumentsSymbol;
	}

	public static function GetUnionType(c:Checker, types:Array<Type>):Type {
		return c.getUnionType(types);
	}

	public static function GetNameTypeOfSymbol(c:Checker, symbol:Symbol):Type {
		if (!c.valueSymbolLinks.Has(symbol)) {
			return null;
		}
		return c.valueSymbolLinks.TryGet(symbol).nameType;
	}

	public static function GetGlobalSymbol(c:Checker, name:std.String, meaning:SymbolFlags, diagnostic:Message):Symbol {
		return c.getGlobalSymbol(name, meaning, diagnostic);
	}

	public static function GetMergedSymbol(c:Checker, symbol:Symbol):Symbol {
		return c.getMergedSymbol(symbol);
	}

	public static function TryFindAmbientModule(c:Checker, moduleName:std.String):Symbol {
		return c.tryFindAmbientModule(moduleName, true);
	}

	public static function GetImmediateAliasedSymbol(c:Checker, symbol:Symbol):Symbol {
		return c.getImmediateAliasedSymbol(symbol);
	}

	public static function GetTypeOnlyAliasDeclaration(c:Checker, symbol:Symbol):Node {
		return c.getTypeOnlyAliasDeclaration(symbol);
	}

	public static function ResolveExternalModuleName(c:Checker, moduleSpecifier:Node):Symbol {
		return c.resolveExternalModuleName(moduleSpecifier, moduleSpecifier, true);
	}

	public static function ResolveExternalModuleSymbol(c:Checker, moduleSymbol:Symbol):Symbol {
		return c.resolveExternalModuleSymbol(moduleSymbol, false);
	}

	public static function GetTypeFromTypeNode(c:Checker, node:Node):Type {
		return c.getTypeFromTypeNode(node);
	}

	public static function IsArrayLikeType(c:Checker, t:Type):Bool {
		return c.isArrayLikeType(t);
	}

	public static function GetPropertiesOfType(c:Checker, t:Type):Array<Symbol> {
		return c.getPropertiesOfType(t);
	}

	public static function GetPropertyOfType(c:Checker, t:Type, name:std.String):Symbol {
		return c.getPropertyOfType(t, name);
	}

	public static function TypeHasCallOrConstructSignatures(c:Checker, t:Type):Bool {
		return c.typeHasCallOrConstructSignatures(t);
	}

	// Checks if a property can be accessed in a location.
	// The location is given by the `node` parameter.
	// The node does not need to be a property access.
	// @param node location where to check property accessibility
	// @param isSuper whether to consider this a `super` property access, e.g. `super.foo`.
	// @param isWrite whether this is a write access, e.g. `++foo.x`.
	// @param containingType type where the property comes from.
	// @param property property symbol.
	public static function IsPropertyAccessible(c:Checker, node:Node, isSuper:Bool, isWrite:Bool, containingType:Type, property:Symbol):Bool {
		return c.isPropertyAccessible(node, isSuper, isWrite, containingType, property);
	}

	public static function GetTypeOfPropertyOfContextualType(c:Checker, t:Type, name:std.String):Type {
		return c.getTypeOfPropertyOfContextualType(t, name);
	}

	public static function WasCanceled(c:Checker):Bool {
		return c.wasCanceled;
	}

	public static function GetSignaturesOfType(c:Checker, t:Type, kind:SignatureKind):Array<Signature> {
		return c.getSignaturesOfType(t, kind);
	}

	public static function GetDeclaredTypeOfSymbol(c:Checker, symbol:Symbol):Type {
		return c.getDeclaredTypeOfSymbol(symbol);
	}

	public static function GetTypeOfSymbol(c:Checker, symbol:Symbol):Type {
		return c.getTypeOfSymbol(symbol);
	}

	public static function GetConstraintOfTypeParameter(c:Checker, typeParameter:Type):Type {
		return c.getConstraintOfTypeParameter(typeParameter);
	}

	public static function GetTrueTypeOfConditionalType(c:Checker, t:Type):Type {
		return c.getTrueTypeFromConditionalType(t);
	}

	public static function GetFalseTypeOfConditionalType(c:Checker, t:Type):Type {
		return c.getFalseTypeFromConditionalType(t);
	}

	public static function GetDefaultFromTypeParameter(c:Checker, typeParameter:Type):Type {
		return c.getDefaultFromTypeParameter(typeParameter);
	}

	public static function GetResolutionModeOverride(c:Checker, node:ImportAttributes, reportErrors:Bool):ResolutionMode {
		return c.getResolutionModeOverride(node, reportErrors);
	}

	public static function GetEffectiveDeclarationFlags(c:Checker, n:Node, flagsToCheck:ModifierFlags):ModifierFlags {
		return c.getEffectiveDeclarationFlags(n, flagsToCheck);
	}

	public static function GetBaseConstraintOfType(c:Checker, t:Type):Type {
		return c.getBaseConstraintOfType(t);
	}

	public static function GetTypePredicateOfSignature(c:Checker, sig:Signature):TypePredicate {
		return c.getTypePredicateOfSignature(sig);
	}

	public static function IsArrayType(c:Checker, t:Type):Bool {
		return c.isArrayType(t);
	}

	public static function GetReturnTypeOfSignature(c:Checker, sig:Signature):Type {
		return c.getReturnTypeOfSignature(sig);
	}

	public static function HasEffectiveRestParameter(c:Checker, signature:Signature):Bool {
		return c.hasEffectiveRestParameter(signature);
	}

	public static function GetLocalTypeParametersOfClassOrInterfaceOrTypeAlias(c:Checker, symbol:Symbol):Array<Type> {
		return c.getLocalTypeParametersOfClassOrInterfaceOrTypeAlias(symbol);
	}

	public static function GetContextualTypeForObjectLiteralElement(c:Checker, element:Node, contextFlags:ContextFlags):Type {
		return c.getContextualTypeForObjectLiteralElement(element, contextFlags);
	}

	public static function TypePredicateToString(c:Checker, t:TypePredicate):std.String {
		return c.typePredicateToString(t);
	}

	public static function GetExpandedParameters(c:Checker, signature:Signature, skipUnionExpanding:Bool):Array<Array<Symbol>> {
		return c.getExpandedParameters(signature, skipUnionExpanding);
	}

	public static function GetResolvedSignature(c:Checker, node:Node):Signature {
		return c.getResolvedSignature(node, null, CheckModeNormal);
	}

	// Return the type of the given property in the given type, or nil if no such property exists
	public static function GetTypeOfPropertyOfType(c:Checker, t:Type, name:std.String):Type {
		return c.getTypeOfPropertyOfType(t, name);
	}

	public static function GetContextualTypeForArgumentAtIndex(c:Checker, node:Node, argIndex:Int):Type {
		return c.getContextualTypeForArgumentAtIndex(node, argIndex);
	}

	public static function GetIndexSignaturesAtLocation(c:Checker, node:Node):Array<Node> {
		return c.getIndexSignaturesAtLocation(node);
	}

	public static function GetResolvedSymbol(c:Checker, node:Node):Symbol {
		return c.getResolvedSymbol(node);
	}

	public static function GetJsxNamespace(c:Checker, location:Node):std.String {
		return c.getJsxNamespace(location);
	}

	public static function GetJsxFragmentFactory(c:Checker, location:Node):std.String {
		final entity = c.getJsxFragmentFactoryEntity(location);
		if (entity != null) {
			return Ast.GetFirstIdentifier(entity).Text();
		}
		return "";
	}

	public static function ResolveName(c:Checker, name:std.String, location:Node, meaning:SymbolFlags, excludeGlobals:Bool):Symbol {
		return c.resolveName(location, name, meaning, null, true, excludeGlobals);
	}

	public static function GetSymbolFlags(c:Checker, symbol:Symbol):SymbolFlags {
		return c.getSymbolFlags(symbol);
	}

	public static function GetBaseTypes(c:Checker, t:Type):Array<Type> {
		return c.getBaseTypes(t);
	}

	public static function GetApparentType(c:Checker, t:Type):Type {
		return c.getApparentType(t);
	}

	public static function GetBaseConstructorTypeOfClass(c:Checker, t:Type):Type {
		return c.getBaseConstructorTypeOfClass(t);
	}

	public static function GetRestTypeOfSignature(c:Checker, sig:Signature):Type {
		return c.getRestTypeOfSignature(sig);
	}

	public static function GetTypeArguments(c:Checker, t:Type):Array<Type> {
		return c.getTypeArguments(t);
	}

	public static function GetIndexInfoOfType(c:Checker, t:Type, keyType:Type):IndexInfo {
		return c.getIndexInfoOfType(t, keyType);
	}

	public static function GetIndexInfosOfType(c:Checker, t:Type):Array<IndexInfo> {
		return c.getIndexInfosOfType(t);
	}

	public static function IsContextSensitive(c:Checker, node:Node):Bool {
		return c.isContextSensitive(node);
	}

	public static function FillMissingTypeArguments(c:Checker, typeArguments:Array<Type>, typeParameters:Array<Type>, minTypeArgumentCount:Int, isJavaScriptImplicitAny:Bool):Array<Type> {
		return c.fillMissingTypeArguments(typeArguments, typeParameters, minTypeArgumentCount, isJavaScriptImplicitAny);
	}

	public static function GetMinTypeArgumentCount(c:Checker, typeParameters:Array<Type>):Int {
		return c.getMinTypeArgumentCount(typeParameters);
	}

	public static function GetWidenedLiteralType(c:Checker, t:Type):Type {
		return c.getWidenedLiteralType(t);
	}

	public static function IsTypeAssignableTo(c:Checker, source:Type, target:Type):Bool {
		return c.isTypeAssignableTo(source, target);
	}

	public static function GetUnionTypeEx(c:Checker, types:Array<Type>, unionReduction:UnionReduction):Type {
		return c.getUnionTypeEx(types, unionReduction, null, null);
	}

	public static function RequiresAddingImplicitUndefined(c:Checker, node:Node):Bool {
		var enclosingDeclaration = Ast.FindAncestor(node, Ast.IsDeclaration);
		if (enclosingDeclaration == null) {
			enclosingDeclaration = Ast.GetSourceFileOfNode(node).AsNode();
		}
		final symbol = node.Symbol();
		if (symbol == null) {
			return false;
		}
		return c.GetEmitResolver().RequiresAddingImplicitUndefined(node, symbol, enclosingDeclaration);
	}

	public static function RemoveMissingOrUndefinedType(c:Checker, t:Type):Type {
		return c.removeMissingOrUndefinedType(t);
	}

	public static function GetWidenedType(c:Checker, t:Type):Type {
		return c.getWidenedType(t);
	}

	public static function CompareSymbols(c:Checker, s1:Symbol, s2:Symbol):Int {
		return c.compareSymbols(s1, s2);
	}
}
