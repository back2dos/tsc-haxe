package ts.ast;

// Port of symbolflags.go.

enum abstract SymbolFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:SymbolFlags, b:SymbolFlags):SymbolFlags;
	@:op(A & B) static function and(a:SymbolFlags, b:SymbolFlags):SymbolFlags;
	@:op(A ^ B) static function xor(a:SymbolFlags, b:SymbolFlags):SymbolFlags;
	@:op(~A) static function not(a:SymbolFlags):SymbolFlags;

	var SymbolFlagsNone = 0;
	var SymbolFlagsFunctionScopedVariable = 1 << 0; // Variable (var) or parameter
	var SymbolFlagsBlockScopedVariable = 1 << 1; // A block-scoped variable (let or const)
	var SymbolFlagsProperty = 1 << 2; // Property or enum member
	var SymbolFlagsEnumMember = 1 << 3; // Enum member
	var SymbolFlagsFunction = 1 << 4; // Function
	var SymbolFlagsClass = 1 << 5; // Class
	var SymbolFlagsInterface = 1 << 6; // Interface
	var SymbolFlagsConstEnum = 1 << 7; // Const enum
	var SymbolFlagsRegularEnum = 1 << 8; // Enum
	var SymbolFlagsValueModule = 1 << 9; // Instantiated module
	var SymbolFlagsNamespaceModule = 1 << 10; // Uninstantiated module
	var SymbolFlagsTypeLiteral = 1 << 11; // Type Literal or mapped type
	var SymbolFlagsObjectLiteral = 1 << 12; // Object Literal
	var SymbolFlagsMethod = 1 << 13; // Method
	var SymbolFlagsConstructor = 1 << 14; // Constructor
	var SymbolFlagsGetAccessor = 1 << 15; // Get accessor
	var SymbolFlagsSetAccessor = 1 << 16; // Set accessor
	var SymbolFlagsSignature = 1 << 17; // Call, construct, or index signature
	var SymbolFlagsTypeParameter = 1 << 18; // Type parameter
	var SymbolFlagsTypeAlias = 1 << 19; // Type alias
	var SymbolFlagsExportValue = 1 << 20; // Exported value marker (see comment in declareModuleMember in binder)
	var SymbolFlagsAlias = 1 << 21; // An alias for another symbol (see comment in isAliasSymbolDeclaration in checker)
	var SymbolFlagsPrototype = 1 << 22; // Prototype property (no source representation)
	var SymbolFlagsExportStar = 1 << 23; // Export * declaration
	var SymbolFlagsOptional = 1 << 24; // Optional property
	var SymbolFlagsTransient = 1 << 25; // Transient symbol (created during type check)
	var SymbolFlagsAssignment = 1 << 26; // Assignment to property on function acting as declaration (eg `func.prop = 1`)
	var SymbolFlagsModuleExports = 1 << 27; // Symbol for CommonJS `module` of `module.exports`
	var SymbolFlagsConstEnumOnlyModule = 1 << 28; // Module contains only const enums or other modules with only const enums
	var SymbolFlagsReplaceableByMethod = 1 << 29;
	var SymbolFlagsGlobalLookup = 1 << 30; // Flag to signal this is a global lookup
	var SymbolFlagsAll = (1 << 30) - 1; // All flags except SymbolFlagsGlobalLookup

	var SymbolFlagsEnum = SymbolFlagsRegularEnum | SymbolFlagsConstEnum;
	var SymbolFlagsVariable = SymbolFlagsFunctionScopedVariable | SymbolFlagsBlockScopedVariable;
	var SymbolFlagsValue = SymbolFlagsVariable | SymbolFlagsProperty | SymbolFlagsEnumMember | SymbolFlagsObjectLiteral | SymbolFlagsFunction | SymbolFlagsClass | SymbolFlagsEnum | SymbolFlagsValueModule | SymbolFlagsMethod | SymbolFlagsGetAccessor | SymbolFlagsSetAccessor;
	var SymbolFlagsType = SymbolFlagsClass | SymbolFlagsInterface | SymbolFlagsEnum | SymbolFlagsEnumMember | SymbolFlagsTypeLiteral | SymbolFlagsTypeParameter | SymbolFlagsTypeAlias;
	var SymbolFlagsNamespace = SymbolFlagsValueModule | SymbolFlagsNamespaceModule | SymbolFlagsEnum;
	var SymbolFlagsModule = SymbolFlagsValueModule | SymbolFlagsNamespaceModule;
	var SymbolFlagsAccessor = SymbolFlagsGetAccessor | SymbolFlagsSetAccessor;

	// Variables can be redeclared, but can not redeclare a block-scoped declaration with the
	// same name, or any other value that is not a variable, e.g. ValueModule or Class
	var SymbolFlagsFunctionScopedVariableExcludes = SymbolFlagsValue & ~SymbolFlagsFunctionScopedVariable;

	// Block-scoped declarations are not allowed to be re-declared
	// they can not merge with anything in the value space
	var SymbolFlagsBlockScopedVariableExcludes = SymbolFlagsValue;

	var SymbolFlagsParameterExcludes = SymbolFlagsValue;
	var SymbolFlagsPropertyExcludes = SymbolFlagsValue & ~(SymbolFlagsProperty | SymbolFlagsAccessor);
	var SymbolFlagsEnumMemberExcludes = SymbolFlagsValue | SymbolFlagsType;
	var SymbolFlagsFunctionExcludes = SymbolFlagsValue & ~(SymbolFlagsFunction | SymbolFlagsValueModule | SymbolFlagsClass);
	var SymbolFlagsClassExcludes = (SymbolFlagsValue | SymbolFlagsType) & ~(SymbolFlagsValueModule | SymbolFlagsInterface | SymbolFlagsFunction); // class-interface mergability done in checker.ts
	var SymbolFlagsInterfaceExcludes = SymbolFlagsType & ~(SymbolFlagsInterface | SymbolFlagsClass);
	var SymbolFlagsRegularEnumExcludes = (SymbolFlagsValue | SymbolFlagsType) & ~(SymbolFlagsRegularEnum | SymbolFlagsValueModule); // regular enums merge only with regular enums and modules
	var SymbolFlagsConstEnumExcludes = (SymbolFlagsValue | SymbolFlagsType) & ~SymbolFlagsConstEnum; // const enums merge only with const enums
	var SymbolFlagsValueModuleExcludes = SymbolFlagsValue & ~(SymbolFlagsFunction | SymbolFlagsClass | SymbolFlagsRegularEnum | SymbolFlagsValueModule);
	var SymbolFlagsNamespaceModuleExcludes = SymbolFlagsNone;
	var SymbolFlagsMethodExcludes = SymbolFlagsValue & ~SymbolFlagsMethod;
	var SymbolFlagsGetAccessorExcludes = SymbolFlagsValue & ~(SymbolFlagsSetAccessor | SymbolFlagsProperty);
	var SymbolFlagsSetAccessorExcludes = SymbolFlagsValue & ~(SymbolFlagsGetAccessor | SymbolFlagsProperty);
	var SymbolFlagsAccessorExcludes = SymbolFlagsValue & ~SymbolFlagsProperty;
	var SymbolFlagsTypeParameterExcludes = SymbolFlagsType & ~SymbolFlagsTypeParameter;
	var SymbolFlagsTypeAliasExcludes = SymbolFlagsType;
	var SymbolFlagsAliasExcludes = SymbolFlagsAlias;
	var SymbolFlagsModuleMember = SymbolFlagsVariable | SymbolFlagsFunction | SymbolFlagsClass | SymbolFlagsInterface | SymbolFlagsEnum | SymbolFlagsModule | SymbolFlagsTypeAlias | SymbolFlagsAlias;
	var SymbolFlagsExportHasLocal = SymbolFlagsFunction | SymbolFlagsClass | SymbolFlagsEnum | SymbolFlagsValueModule;
	var SymbolFlagsBlockScoped = SymbolFlagsBlockScopedVariable | SymbolFlagsClass | SymbolFlagsEnum;
	var SymbolFlagsPropertyOrAccessor = SymbolFlagsProperty | SymbolFlagsAccessor;
	var SymbolFlagsClassMember = SymbolFlagsMethod | SymbolFlagsAccessor | SymbolFlagsProperty;
	var SymbolFlagsExportSupportsDefaultModifier = SymbolFlagsClass | SymbolFlagsFunction | SymbolFlagsInterface;
	var SymbolFlagsExportDoesNotSupportDefaultModifier = ~SymbolFlagsExportSupportsDefaultModifier;
	// The set of things we consider semantically classifiable.  Used to speed up the LS during
	// classification.
	var SymbolFlagsClassifiable = SymbolFlagsClass | SymbolFlagsEnum | SymbolFlagsTypeAlias | SymbolFlagsInterface | SymbolFlagsTypeParameter | SymbolFlagsModule | SymbolFlagsAlias;
	var SymbolFlagsLateBindingContainer = SymbolFlagsClass | SymbolFlagsInterface | SymbolFlagsTypeLiteral | SymbolFlagsObjectLiteral | SymbolFlagsFunction;
}
