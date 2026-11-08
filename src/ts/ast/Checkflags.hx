package ts.ast;

// Port of checkflags.go.

enum abstract CheckFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:CheckFlags, b:CheckFlags):CheckFlags;
	@:op(A & B) static function and(a:CheckFlags, b:CheckFlags):CheckFlags;
	@:op(A ^ B) static function xor(a:CheckFlags, b:CheckFlags):CheckFlags;
	@:op(~A) static function not(a:CheckFlags):CheckFlags;

	var CheckFlagsNone = 0;
	var CheckFlagsInstantiated = 1 << 0; // Instantiated symbol
	var CheckFlagsSyntheticProperty = 1 << 1; // Property in union or intersection type
	var CheckFlagsSyntheticMethod = 1 << 2; // Method in union or intersection type
	var CheckFlagsReadonly = 1 << 3; // Readonly transient symbol
	var CheckFlagsReadPartial = 1 << 4; // Synthetic property present in some but not all constituents
	var CheckFlagsWritePartial = 1 << 5; // Synthetic property present in some but only satisfied by an index signature in others
	var CheckFlagsHasNonUniformType = 1 << 6; // Synthetic property with non-uniform type in constituents
	var CheckFlagsHasLiteralType = 1 << 7; // Synthetic property with at least one literal type in constituents
	var CheckFlagsContainsPublic = 1 << 8; // Synthetic property with public constituent(s)
	var CheckFlagsContainsProtected = 1 << 9; // Synthetic property with protected constituent(s)
	var CheckFlagsContainsPrivate = 1 << 10; // Synthetic property with private constituent(s)
	var CheckFlagsContainsWritePublic = 1 << 11; // Synthetic property with public set accessors(s)
	var CheckFlagsContainsWriteProtected = 1 << 12; // Synthetic property with protected set accessors(s)
	var CheckFlagsContainsWritePrivate = 1 << 13; // Synthetic property with private set accessors(s)
	var CheckFlagsContainsStatic = 1 << 14; // Synthetic property with static constituent(s)
	var CheckFlagsLate = 1 << 15; // Late-bound symbol for a computed property with a dynamic name
	var CheckFlagsReverseMapped = 1 << 16; // Property of reverse-inferred homomorphic mapped type
	var CheckFlagsOptionalParameter = 1 << 17; // Optional parameter
	var CheckFlagsRestParameter = 1 << 18; // Rest parameter
	var CheckFlagsDeferredType = 1 << 19; // Calculation of the type of this symbol is deferred due to processing costs, should be fetched with `getTypeOfSymbolWithDeferredType`
	var CheckFlagsHasNeverType = 1 << 20; // Synthetic property with at least one never type in constituents
	var CheckFlagsMapped = 1 << 21; // Property of mapped type
	var CheckFlagsStripOptional = 1 << 22; // Strip optionality in mapped property
	var CheckFlagsUnresolved = 1 << 23; // Unresolved type alias symbol
	var CheckFlagsIsDiscriminantComputed = 1 << 24; // IsDiscriminant flags has been computed
	var CheckFlagsIsDiscriminant = 1 << 25; // Discriminant property
	var CheckFlagsIndexSymbol = 1 << 26; // Synthetic property created from index signature
	var CheckFlagsSynthetic = CheckFlagsSyntheticProperty | CheckFlagsSyntheticMethod;
	var CheckFlagsNonUniformAndLiteral = CheckFlagsHasNonUniformType | CheckFlagsHasLiteralType;
	var CheckFlagsPartial = CheckFlagsReadPartial | CheckFlagsWritePartial;
}
