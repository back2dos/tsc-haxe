package ts.ast;

// Port of modifierflags.go.

enum abstract ModifierFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:ModifierFlags, b:ModifierFlags):ModifierFlags;
	@:op(A & B) static function and(a:ModifierFlags, b:ModifierFlags):ModifierFlags;
	@:op(A ^ B) static function xor(a:ModifierFlags, b:ModifierFlags):ModifierFlags;
	@:op(~A) static function not(a:ModifierFlags):ModifierFlags;

	var ModifierFlagsNone = 0;
	// Syntactic/JSDoc modifiers
	var ModifierFlagsPublic = 1 << 0; // Property/Method
	var ModifierFlagsPrivate = 1 << 1; // Property/Method
	var ModifierFlagsProtected = 1 << 2; // Property/Method
	var ModifierFlagsReadonly = 1 << 3; // Property/Method
	var ModifierFlagsOverride = 1 << 4; // Override method
	// Syntactic-only modifiers
	var ModifierFlagsExport = 1 << 5; // Declarations
	var ModifierFlagsAbstract = 1 << 6; // Class/Method/ConstructSignature
	var ModifierFlagsAmbient = 1 << 7; // Declarations (declare keyword)
	var ModifierFlagsStatic = 1 << 8; // Property/Method
	var ModifierFlagsAccessor = 1 << 9; // Property
	var ModifierFlagsAsync = 1 << 10; // Property/Method/Function
	var ModifierFlagsDefault = 1 << 11; // Function/Class (export default declaration)
	var ModifierFlagsConst = 1 << 12; // Const enum
	var ModifierFlagsIn = 1 << 13; // Contravariance modifier
	var ModifierFlagsOut = 1 << 14; // Covariance modifier
	var ModifierFlagsDecorator = 1 << 15; // Contains a decorator
	// JSDoc-only modifiers
	var ModifierFlagsDeprecated = 1 << 16; // Deprecated tag
	// Cache-only JSDoc-modifiers. Should match order of Syntactic/JSDoc modifiers, above.
	var ModifierFlagsJSDocPublic = 1 << 23; // if this value changes, `selectEffectiveModifierFlags` must change accordingly
	var ModifierFlagsJSDocPrivate = 1 << 24;
	var ModifierFlagsJSDocProtected = 1 << 25;
	var ModifierFlagsJSDocReadonly = 1 << 26;
	var ModifierFlagsJSDocOverride = 1 << 27;
	var ModifierFlagsHasComputedJSDocModifiers = 1 << 28; // Indicates the computed modifier flags include modifiers from JSDoc.
	var ModifierFlagsHasComputedFlags = 1 << 29; // Modifier flags have been computed

	var ModifierFlagsSyntacticOrJSDocModifiers = ModifierFlagsPublic | ModifierFlagsPrivate | ModifierFlagsProtected | ModifierFlagsReadonly | ModifierFlagsOverride;
	var ModifierFlagsSyntacticOnlyModifiers = ModifierFlagsExport | ModifierFlagsAmbient | ModifierFlagsAbstract | ModifierFlagsStatic | ModifierFlagsAccessor | ModifierFlagsAsync | ModifierFlagsDefault | ModifierFlagsConst | ModifierFlagsIn | ModifierFlagsOut | ModifierFlagsDecorator;
	var ModifierFlagsSyntacticModifiers = ModifierFlagsSyntacticOrJSDocModifiers | ModifierFlagsSyntacticOnlyModifiers;
	var ModifierFlagsJSDocCacheOnlyModifiers = ModifierFlagsJSDocPublic | ModifierFlagsJSDocPrivate | ModifierFlagsJSDocProtected | ModifierFlagsJSDocReadonly | ModifierFlagsJSDocOverride;
	var ModifierFlagsJSDocOnlyModifiers = ModifierFlagsDeprecated;
	var ModifierFlagsNonCacheOnlyModifiers = ModifierFlagsSyntacticOrJSDocModifiers | ModifierFlagsSyntacticOnlyModifiers | ModifierFlagsJSDocOnlyModifiers;

	var ModifierFlagsAccessibilityModifier = ModifierFlagsPublic | ModifierFlagsPrivate | ModifierFlagsProtected;
	// Accessibility modifiers and 'readonly' can be attached to a parameter in a constructor to make it a property.
	var ModifierFlagsParameterPropertyModifier = ModifierFlagsAccessibilityModifier | ModifierFlagsReadonly | ModifierFlagsOverride;
	var ModifierFlagsNonPublicAccessibilityModifier = ModifierFlagsPrivate | ModifierFlagsProtected;

	var ModifierFlagsTypeScriptModifier = ModifierFlagsAmbient | ModifierFlagsPublic | ModifierFlagsPrivate | ModifierFlagsProtected | ModifierFlagsReadonly | ModifierFlagsAbstract | ModifierFlagsConst | ModifierFlagsOverride | ModifierFlagsIn | ModifierFlagsOut;
	var ModifierFlagsExportDefault = ModifierFlagsExport | ModifierFlagsDefault;
	var ModifierFlagsAll = ModifierFlagsExport | ModifierFlagsAmbient | ModifierFlagsPublic | ModifierFlagsPrivate | ModifierFlagsProtected | ModifierFlagsStatic | ModifierFlagsReadonly | ModifierFlagsAbstract | ModifierFlagsAccessor | ModifierFlagsAsync | ModifierFlagsDefault | ModifierFlagsConst | ModifierFlagsDeprecated | ModifierFlagsOverride | ModifierFlagsIn | ModifierFlagsOut | ModifierFlagsDecorator;
	var ModifierFlagsModifier = ModifierFlagsAll & ~ModifierFlagsDecorator;
	var ModifierFlagsJavaScript = ModifierFlagsExport | ModifierFlagsStatic | ModifierFlagsAccessor | ModifierFlagsAsync | ModifierFlagsDefault;
}
