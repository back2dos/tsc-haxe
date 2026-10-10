package ts.ast;

// Port of utilities.go (types; the functions are in Ast.hx under `// --- utilities.go ---`).

enum abstract OuterExpressionKinds(Int) from Int to Int {
	@:op(A | B) static function or(a:OuterExpressionKinds, b:OuterExpressionKinds):OuterExpressionKinds;
	@:op(A & B) static function and(a:OuterExpressionKinds, b:OuterExpressionKinds):OuterExpressionKinds;
	@:op(~A) static function not(a:OuterExpressionKinds):OuterExpressionKinds;

	var OEKParentheses = 1 << 0;
	var OEKTypeAssertions = 1 << 1;
	var OEKNonNullAssertions = 1 << 2;
	var OEKPartiallyEmittedExpressions = 1 << 3;
	var OEKExpressionsWithTypeArguments = 1 << 4;
	var OEKSatisfies = 1 << 5;
	var OEKExcludeJSDocTypeAssertion = 1 << 6;
	var OEKAssignments = 1 << 7;
	var OEKComma = 1 << 8;
	var OEKAssertions = OEKTypeAssertions | OEKNonNullAssertions | OEKSatisfies;
	var OEKAll = OEKParentheses | OEKAssertions | OEKPartiallyEmittedExpressions | OEKExpressionsWithTypeArguments;
	var OEKAllExceptAssertionsOrExpressionsWithTypeArguments = OEKAll & ~OEKAssertions & ~OEKExpressionsWithTypeArguments;
	var OEKExpressionTypePassthrough = OEKParentheses | OEKAssignments | OEKComma;
}

enum abstract FindAncestorResult(Int) from Int to Int {
	var FindAncestorFalse = 0;
	var FindAncestorTrue = 1;
	var FindAncestorQuit = 2;
}

enum abstract JSDeclarationKind(Int) from Int to Int {
	var JSDeclarationKindNone = 0;
	// module.exports = expr, except for module.exports = exports
	var JSDeclarationKindModuleExports = 1;
	// exports.name = expr
	// module.exports.name = expr
	var JSDeclarationKindExportsProperty = 2;
	// this.name = expr
	var JSDeclarationKindThisProperty = 3;
	// F.name = expr, F[name] = expr, in JS or TS file
	var JSDeclarationKindProperty = 4;
	// Object.defineProperty(x, 'name', { value: any, writable?: boolean (false by default) });
	// Object.defineProperty(x, 'name', { get: Function, set: Function });
	// Object.defineProperty(x, 'name', { get: Function });
	// Object.defineProperty(x, 'name', { set: Function });
	var JSDeclarationKindObjectDefinePropertyValue = 5;
	// Object.defineProperty(exports || module.exports, 'name', ...);
	var JSDeclarationKindObjectDefinePropertyExports = 6;
}

enum abstract SemanticMeaning(Int) from Int to Int {
	@:op(A | B) static function or(a:SemanticMeaning, b:SemanticMeaning):SemanticMeaning;
	@:op(A & B) static function and(a:SemanticMeaning, b:SemanticMeaning):SemanticMeaning;
	@:op(~A) static function not(a:SemanticMeaning):SemanticMeaning;

	var SemanticMeaningNone = 0;
	var SemanticMeaningValue = 1 << 0;
	var SemanticMeaningType = 1 << 1;
	var SemanticMeaningNamespace = 1 << 2;
	var SemanticMeaningAll = SemanticMeaningValue | SemanticMeaningType | SemanticMeaningNamespace;
}

enum abstract ModuleInstanceState(Int) from Int to Int {
	var ModuleInstanceStateUnknown = 0;
	var ModuleInstanceStateNonInstantiated = 1;
	var ModuleInstanceStateInstantiated = 2;
	var ModuleInstanceStateConstEnumOnly = 3;
}

class HasFileNameImpl implements HasFileName {
	public var fileName:String = "";
	public var path:Path = "";

	public function new() {}

	public function FileName():String {
		return fileName;
	}

	public function Path():Path {
		return path;
	}
}

class AllAccessorDeclarations {
	public var FirstAccessor:AccessorDeclaration = null;
	public var SecondAccessor:AccessorDeclaration = null;
	public var SetAccessor:SetAccessorDeclaration = null;
	public var GetAccessor:GetAccessorDeclaration = null;

	public function new() {}
}
