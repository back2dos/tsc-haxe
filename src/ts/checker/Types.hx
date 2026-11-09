package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/types.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

enum abstract ParseFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:ParseFlags, b:ParseFlags):ParseFlags;
	@:op(A & B) static function and(a:ParseFlags, b:ParseFlags):ParseFlags;
	@:op(~A) static function not(a:ParseFlags):ParseFlags;

	var ParseFlagsNone = 0;
	var ParseFlagsYield = 1 << 0;
	var ParseFlagsAwait = 1 << 1;
	var ParseFlagsType = 1 << 2;
	var ParseFlagsIgnoreMissingOpenBrace = 1 << 4;
	var ParseFlagsJSDoc = 1 << 5;
}

enum abstract SignatureKind(Int) from Int to Int {
	var SignatureKindCall = 0;
	var SignatureKindConstruct = 1;
}

enum abstract ContextFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:ContextFlags, b:ContextFlags):ContextFlags;
	@:op(A & B) static function and(a:ContextFlags, b:ContextFlags):ContextFlags;
	@:op(~A) static function not(a:ContextFlags):ContextFlags;

	var ContextFlagsNone = 0;
	var ContextFlagsSignature = 1 << 0; // Obtaining contextual signature
	var ContextFlagsNoConstraints = 1 << 1; // Don't obtain type variable constraints
	var ContextFlagsIgnoreNodeInferences = 1 << 2; // Ignore inference to current node and parent nodes out to the containing call for, for example, completions
	var ContextFlagsSkipBindingPatterns = 1 << 3; // Ignore contextual types applied by binding patterns
}

enum abstract TypeFormatFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:TypeFormatFlags, b:TypeFormatFlags):TypeFormatFlags;
	@:op(A & B) static function and(a:TypeFormatFlags, b:TypeFormatFlags):TypeFormatFlags;
	@:op(~A) static function not(a:TypeFormatFlags):TypeFormatFlags;

	var TypeFormatFlagsNone = 0;
	var TypeFormatFlagsNoTruncation = 1 << 0; // Don't truncate typeToString result
	var TypeFormatFlagsWriteArrayAsGenericType = 1 << 1; // Write Array<T> instead T[]
	var TypeFormatFlagsGenerateNamesForShadowedTypeParams = 1 << 2; // When a type parameter T is shadowing another T, generate a name for it so it can still be referenced
	var TypeFormatFlagsUseStructuralFallback = 1 << 3; // When an alias cannot be named by its symbol, rather than report an error, fallback to a structural printout if possible
	// hole because there's a hole in node builder flags
	var TypeFormatFlagsWriteTypeArgumentsOfSignature = 1 << 5; // Write the type arguments instead of type parameters of the signature
	var TypeFormatFlagsUseFullyQualifiedType = 1 << 6; // Write out the fully qualified type name (eg. Module.Type, instead of Type)
	// hole because `UseOnlyExternalAliasing` is here in node builder flags, but functions which take old flags use `SymbolFormatFlags` instead
	var TypeFormatFlagsSuppressAnyReturnType = 1 << 8; // If the return type is any-like, don't offer a return type.
	// hole because `WriteTypeParametersInQualifiedName` is here in node builder flags, but functions which take old flags use `SymbolFormatFlags` for this instead
	var TypeFormatFlagsMultilineObjectLiterals = 1 << 10; // Always print object literals across multiple lines (only used to map into node builder flags)
	var TypeFormatFlagsWriteClassExpressionAsTypeLiteral = 1 << 11; // Write a type literal instead of (Anonymous class)
	var TypeFormatFlagsUseTypeOfFunction = 1 << 12; // Write typeof instead of function type literal
	var TypeFormatFlagsOmitParameterModifiers = 1 << 13; // Omit modifiers on parameters
	var TypeFormatFlagsUseAliasDefinedOutsideCurrentScope = 1 << 14; // For a `type T = ... ` defined in a different file, write `T` instead of its value, even though `T` can't be accessed in the current scope.
	var TypeFormatFlagsUseSingleQuotesForStringLiteralType = 1 << 28; // Use single quotes for string literal type
	var TypeFormatFlagsNoTypeReduction = 1 << 29; // Don't call getReducedType
	var TypeFormatFlagsUseInstantiationExpressions = 1 << 30; // Use instantiation expressions for qualified instantiated names like Foo<string>.Bar
	var TypeFormatFlagsOmitThisParameter = 1 << 25;
	var TypeFormatFlagsWriteCallStyleSignature = 1 << 27; // Write construct signatures as call style signatures
	// Error Handling
	var TypeFormatFlagsAllowUniqueESSymbolType = 1 << 20; // This is bit 20 to align with the same bit in `NodeBuilderFlags`
	// TypeFormatFlags exclusive
	var TypeFormatFlagsAddUndefined = 1 << 17; // Add undefined to types of initialized, non-optional parameters
	var TypeFormatFlagsWriteArrowStyleSignature = 1 << 18; // Write arrow style signature
	// State
	var TypeFormatFlagsInArrayType = 1 << 19; // Writing an array element type
	var TypeFormatFlagsInElementType = 1 << 21; // Writing an array or union element type
	var TypeFormatFlagsInFirstTypeArgument = 1 << 22; // Writing first type argument of the instantiated type
	var TypeFormatFlagsInTypeAlias = 1 << 23; // Writing type in type alias declaration
	var TypeFormatFlagsNodeBuilderFlagsMask = 1922071919;
}

enum abstract SymbolFormatFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:SymbolFormatFlags, b:SymbolFormatFlags):SymbolFormatFlags;
	@:op(A & B) static function and(a:SymbolFormatFlags, b:SymbolFormatFlags):SymbolFormatFlags;
	@:op(~A) static function not(a:SymbolFormatFlags):SymbolFormatFlags;

	var SymbolFormatFlagsNone = 0;
	// Write symbols's type argument if it is instantiated symbol
	// eg. class C<T> { p: T }   <-- Show p as C<T>.p here
	//     var a: C<number>;
	//     var p = a.p; <--- Here p is property of C<number> so show it as C<number>.p instead of just C.p
	var SymbolFormatFlagsWriteTypeParametersOrArguments = 1 << 0;
	// Use only external alias information to get the symbol name in the given context
	// eg.  module m { export class c { } } import x = m.c;
	// When this flag is specified m.c will be used to refer to the class instead of alias symbol x
	var SymbolFormatFlagsUseOnlyExternalAliasing = 1 << 1;
	// Build symbol name using any nodes needed, instead of just components of an entity name
	var SymbolFormatFlagsAllowAnyNodeKind = 1 << 2;
	// Prefer aliases which are not directly visible
	var SymbolFormatFlagsUseAliasDefinedOutsideCurrentScope = 1 << 3;
	// { [E.A]: 1 }
	/** @internal */
	var SymbolFormatFlagsWriteComputedProps = 1 << 4;
	// Skip building an accessible symbol chain
	/** @internal */
	var SymbolFormatFlagsDoNotIncludeSymbolChain = 1 << 5;
}

enum abstract ExternalEmitHelpers(Int) from Int to Int {
	@:op(A | B) static function or(a:ExternalEmitHelpers, b:ExternalEmitHelpers):ExternalEmitHelpers;
	@:op(A & B) static function and(a:ExternalEmitHelpers, b:ExternalEmitHelpers):ExternalEmitHelpers;
	@:op(~A) static function not(a:ExternalEmitHelpers):ExternalEmitHelpers;

	var ExternalEmitHelpersRest = 1 << 0; // __rest (used by ESNext object rest transformation)
	var ExternalEmitHelpersDecorate = 1 << 1; // __decorate (used by TypeScript decorators transformation)
	var ExternalEmitHelpersMetadata = 1 << 2; // __metadata (used by TypeScript decorators transformation)
	var ExternalEmitHelpersParam = 1 << 3; // __param (used by TypeScript decorators transformation)
	var ExternalEmitHelpersAwaiter = 1 << 4; // __awaiter (used by ES2017 async functions transformation)
	var ExternalEmitHelpersAwait = 1 << 5; // __await (used by ES2017 async generator transformation)
	var ExternalEmitHelpersAsyncGenerator = 1 << 6; // __asyncGenerator (used by ES2017 async generator transformation)
	var ExternalEmitHelpersAsyncDelegator = 1 << 7; // __asyncDelegator (used by ES2017 async generator yield* transformation)
	var ExternalEmitHelpersAsyncValues = 1 << 8; // __asyncValues (used by ES2017 for..await..of transformation)
	var ExternalEmitHelpersExportStar = 1 << 9; // __exportStar (used by CommonJS/AMD/UMD module transformation)
	var ExternalEmitHelpersImportStar = 1 << 10; // __importStar (used by CommonJS/AMD/UMD module transformation)
	var ExternalEmitHelpersImportDefault = 1 << 11; // __importDefault (used by CommonJS/AMD/UMD module transformation)
	var ExternalEmitHelpersMakeTemplateObject = 1 << 12; // __makeTemplateObject (used for constructing template string array objects)
	var ExternalEmitHelpersClassPrivateFieldGet = 1 << 13; // __classPrivateFieldGet (used by the class private field transformation)
	var ExternalEmitHelpersClassPrivateFieldSet = 1 << 14; // __classPrivateFieldSet (used by the class private field transformation)
	var ExternalEmitHelpersClassPrivateFieldIn = 1 << 15; // __classPrivateFieldIn (used by the class private field transformation)
	var ExternalEmitHelpersSetFunctionName = 1 << 16; // __setFunctionName (used by class fields and ECMAScript decorators)
	var ExternalEmitHelpersPropKey = 1 << 17; // __propKey (used by class fields and ECMAScript decorators)
	var ExternalEmitHelpersAddDisposableResourceAndDisposeResources = 1 << 18; // __addDisposableResource and __disposeResources (used by ESNext transformations)
	var ExternalEmitHelpersRewriteRelativeImportExtension = 1 << 19; // __rewriteRelativeImportExtension (used by --rewriteRelativeImportExtensions)
	var ExternalEmitHelpersESDecorateAndRunInitializers = 1 << 1; // __esDecorate and __runInitializers (used by ECMAScript decorators transformation)
	var ExternalEmitHelpersFirstEmitHelper = 1 << 0;
	var ExternalEmitHelpersLastEmitHelper = 1 << 19;
	// Helpers included by ES2017 for..await..of
	var ExternalEmitHelpersForAwaitOfIncludes = 1 << 8;
	// Helpers included by ES2017 async generators
	var ExternalEmitHelpersAsyncGeneratorIncludes = 96;
	// Helpers included by yield* in ES2017 async generators
	var ExternalEmitHelpersAsyncDelegatorIncludes = 416;
}

typedef TypeId = Int;

typedef SignatureId = Int;

@:allow(ts.checker)
class SymbolReferenceLinks extends ts.core.Linkstore.LinkEntry {
	var referenceKinds:SymbolFlags = 0; // Flags for the meanings of the symbol that were referenced

	public function new() {
		super();
	}
}

// PORT: perf — an instantiated symbol (Checker.instantiateSymbol: most transient symbols, t3code-server 1.7M) has
// its value links as fields (InstantiatedSymbol, like Strada's TransientSymbol): no links entry (24 B less: its
// header, store and next entry). ValueSymbolLinks is the instantiated symbol itself or the links entry of another
// symbol (ValueSymbolLinksRecord); Checker.valueSymbolLinks (ValueSymbolLinkStore) returns one or the other.
@:allow(ts.checker)
abstract ValueSymbolLinks(Any) {
	var resolvedType(get, set):Type;
	var target(get, set):Symbol;
	var mapper(get, set):TypeMapper;
	var functionOrConstructorChecked(get, set):Bool;
	var writeType(get, set):Type;
	var nameType(get, set):Type;
	var containingType(get, set):Type;

	inline function isInst():Bool {
		return Std.isOfType(this, InstantiatedSymbol);
	}

	inline function inst():InstantiatedSymbol {
		return cast this;
	}

	inline function rec():ValueSymbolLinksRecord {
		return cast this;
	}

	// the links entry (null for an instantiated symbol)
	inline function record():ValueSymbolLinksRecord {
		return isInst() ? null : cast this;
	}

	inline function get_resolvedType():Type {
		return isInst() ? inst().vResolvedType : rec().resolvedType;
	}

	inline function set_resolvedType(v:Type):Type {
		return isInst() ? inst().vResolvedType = v : rec().resolvedType = v;
	}

	inline function get_target():Symbol {
		return isInst() ? inst().vTarget : rec().target;
	}

	inline function set_target(v:Symbol):Symbol {
		return isInst() ? inst().vTarget = v : rec().target = v;
	}

	inline function get_mapper():TypeMapper {
		return isInst() ? inst().vMapper : rec().mapper;
	}

	inline function set_mapper(v:TypeMapper):TypeMapper {
		return isInst() ? inst().vMapper = v : rec().mapper = v;
	}

	inline function get_functionOrConstructorChecked():Bool {
		return isInst() ? inst().extraFunctionOrConstructorChecked() : rec().functionOrConstructorChecked;
	}

	inline function set_functionOrConstructorChecked(v:Bool):Bool {
		return isInst() ? inst().setFunctionOrConstructorChecked(v) : rec().functionOrConstructorChecked = v;
	}

	inline function get_writeType():Type {
		return isInst() ? inst().extraWriteType() : rec().writeType;
	}

	inline function set_writeType(v:Type):Type {
		return isInst() ? inst().setWriteType(v) : rec().writeType = v;
	}

	inline function get_nameType():Type {
		return isInst() ? inst().extraNameType() : rec().nameType;
	}

	inline function set_nameType(v:Type):Type {
		return isInst() ? inst().setNameType(v) : rec().nameType = v;
	}

	inline function get_containingType():Type {
		return isInst() ? inst().extraContainingType() : rec().containingType;
	}

	inline function set_containingType(v:Type):Type {
		return isInst() ? inst().setContainingType(v) : rec().containingType = v;
	}
}

// Checker.valueSymbolLinks: an instantiated symbol's links are the symbol (see ValueSymbolLinks)
class ValueSymbolLinkStore {
	final store:LinkStore<Symbol, ValueSymbolLinksRecord>;

	public function new(factory:() -> ValueSymbolLinksRecord, forKey:Symbol->ValueSymbolLinksRecord) {
		store = new LinkStore<Symbol, ValueSymbolLinksRecord>(factory, forKey);
	}

	public inline function Get(s:Symbol):ValueSymbolLinks {
		return Std.isOfType(s, InstantiatedSymbol) ? cast s : cast store.Get(s);
	}

	public inline function TryGet(s:Symbol):Null<ValueSymbolLinks> {
		return Std.isOfType(s, InstantiatedSymbol) ? cast s : cast store.TryGet(s);
	}

	public inline function Has(s:Symbol):Bool {
		return Std.isOfType(s, InstantiatedSymbol) || store.Has(s);
	}

	// the links entry of a symbol that is not instantiated
	public inline function TryGetRecord(s:Symbol):Null<ValueSymbolLinksRecord> {
		return Std.isOfType(s, InstantiatedSymbol) ? null : store.TryGet(s);
	}
}

// a symbol made by Checker.instantiateSymbol (Go main's newSharedDataSymbol: its target's data), with its value links
@:allow(ts.checker)
@:access(ts.ast.Symbol)
class InstantiatedSymbol extends Symbol {
	var vResolvedType:Type = null;
	var vTarget:Symbol = null;
	var vMapper:TypeMapper = null;
	// Go's rarely set fields (see ValueSymbolLinksRecord.extra; t3code-server: 5% of the instantiated symbols) in
	// an entry of the symbol's links (no field: 64 -> 56 B; its links are most often empty: t3code-server 100%)
	var vExtra(get, never):InstantiatedSymbolExtra;

	public function new(other:Symbol) {
		super();
		data = other.data;
	}

	inline function get_vExtra():InstantiatedSymbolExtra {
		return links == null ? null : InstantiatedSymbolExtra.store.TryGetInline(this);
	}

	function newExtra():InstantiatedSymbolExtra {
		return InstantiatedSymbolExtra.store.Get(this);
	}

	function extraFunctionOrConstructorChecked():Bool {
		final x = vExtra;
		return x != null && x.functionOrConstructorChecked;
	}

	function extraWriteType():Type {
		final x = vExtra;
		return x == null ? null : x.writeType;
	}

	function extraNameType():Type {
		final x = vExtra;
		return x == null ? null : x.nameType;
	}

	function extraContainingType():Type {
		final x = vExtra;
		return x == null ? null : x.containingType;
	}

	function setFunctionOrConstructorChecked(b:Bool):Bool {
		final x = vExtra;
		if (x == null && !b) {
			return b;
		}
		return (x != null ? x : newExtra()).functionOrConstructorChecked = b;
	}

	function setWriteType(t:Type):Type {
		final x = vExtra;
		if (x == null && t == null) {
			return t;
		}
		return (x != null ? x : newExtra()).writeType = t;
	}

	function setNameType(t:Type):Type {
		final x = vExtra;
		if (x == null && t == null) {
			return t;
		}
		return (x != null ? x : newExtra()).nameType = t;
	}

	function setContainingType(t:Type):Type {
		final x = vExtra;
		if (x == null && t == null) {
			return t;
		}
		return (x != null ? x : newExtra()).containingType = t;
	}
}

// the rarely set value links of an instantiated symbol (InstantiatedSymbol.vExtra)
@:allow(ts.checker)
class InstantiatedSymbolExtra extends ts.core.Linkstore.LinkEntry {
	static final store = new LinkStore<Symbol, InstantiatedSymbolExtra>(() -> new InstantiatedSymbolExtra());

	var writeType:Type = null;
	var nameType:Type = null;
	var containingType:Type = null;
	var functionOrConstructorChecked:Bool = false;

	public function new() {
		super();
	}
}

// the value links entry of a symbol that is not instantiated (see ValueSymbolLinks)
@:allow(ts.checker)
class ValueSymbolLinksRecord extends ts.core.Linkstore.LinkEntry {
	var resolvedType:Type = null; // Type of value symbol
	// PORT: perf — target and mapper are fields of the links of a transient symbol (TransientValueSymbolLinks,
	// Checker.valueSymbolLinks), which has them (the checker makes them: instantiated symbols, synthetic
	// properties); the links of another symbol keep them in the side record (ValueSymbolTargetExtra; none on
	// t3code-server): those links are 16 B smaller
	var target(get, set):Symbol;
	var mapper(get, set):TypeMapper;

	inline function get_target():Symbol {
		final t = Std.downcast(this, TransientValueSymbolLinks);
		return t != null ? t.instTarget : extra == null ? null : targetExtraTarget();
	}

	inline function get_mapper():TypeMapper {
		final t = Std.downcast(this, TransientValueSymbolLinks);
		return t != null ? t.instMapper : extra == null ? null : targetExtraMapper();
	}

	function targetExtraTarget():Symbol {
		final x = Std.downcast(extra, ValueSymbolTargetExtra);
		return x == null ? null : x.target;
	}

	function targetExtraMapper():TypeMapper {
		final x = Std.downcast(extra, ValueSymbolTargetExtra);
		return x == null ? null : x.mapper;
	}

	// the side record with the target and mapper (null when v is nil and there is none: nothing to write)
	function targetExtra(v:Dynamic):ValueSymbolTargetExtra {
		var x = Std.downcast(extra, ValueSymbolTargetExtra);
		if (x == null) {
			if (v == null) {
				return null;
			}
			x = new ValueSymbolTargetExtra();
			final o = extra;
			if (o != null) {
				x.writeType = o.writeType;
				x.nameType = o.nameType;
				x.containingType = o.containingType;
				x.functionOrConstructorChecked = o.functionOrConstructorChecked;
			}
			extra = x;
		}
		return x;
	}

	function set_target(v:Symbol):Symbol {
		final t = Std.downcast(this, TransientValueSymbolLinks);
		if (t != null) {
			return t.instTarget = v;
		}
		final x = targetExtra(v);
		if (x != null) {
			x.target = v;
		}
		return v;
	}

	function set_mapper(v:TypeMapper):TypeMapper {
		final t = Std.downcast(this, TransientValueSymbolLinks);
		if (t != null) {
			return t.instMapper = v;
		}
		final x = targetExtra(v);
		if (x != null) {
			x.mapper = v;
		}
		return v;
	}
	// PORT: perf — from TypeScript main (microsoft/typescript-go#64797): the rarely set fields in a side record
	// (allocated when one is set to a non-nil value)
	var extra:ValueSymbolExtra = null;
	var functionOrConstructorChecked(get, set):Bool;
	var writeType(get, set):Type;
	var nameType(get, set):Type;
	var containingType(get, set):Type; // Mapped type for mapped type property, containing union or intersection type for synthetic property

	inline function get_writeType():Type {
		return extra == null ? null : extra.writeType;
	}

	inline function get_functionOrConstructorChecked():Bool {
		return extra != null && extra.functionOrConstructorChecked;
	}

	function set_functionOrConstructorChecked(b:Bool):Bool {
		if (extra == null) {
			if (!b) {
				return b;
			}
			extra = new ValueSymbolExtra();
		}
		return extra.functionOrConstructorChecked = b;
	}

	// PORT: perf — the name type and containing type of a synthetic or mapped property are fields of its links
	// (SyntheticValueSymbolLinks), not of the side record
	inline function get_nameType():Type {
		final s = Std.downcast(this, SyntheticValueSymbolLinks);
		return s != null ? s.synNameType : extra == null ? null : extra.nameType;
	}

	inline function get_containingType():Type {
		final s = Std.downcast(this, SyntheticValueSymbolLinks);
		return s != null ? s.synContainingType : extra == null ? null : extra.containingType;
	}

	function set_writeType(t:Type):Type {
		if (extra == null) {
			if (t == null) {
				return t;
			}
			extra = new ValueSymbolExtra();
		}
		return extra.writeType = t;
	}

	function set_nameType(t:Type):Type {
		final s = Std.downcast(this, SyntheticValueSymbolLinks);
		if (s != null) {
			return s.synNameType = t;
		}
		if (extra == null) {
			if (t == null) {
				return t;
			}
			extra = new ValueSymbolExtra();
		}
		return extra.nameType = t;
	}

	function set_containingType(t:Type):Type {
		final s = Std.downcast(this, SyntheticValueSymbolLinks);
		if (s != null) {
			return s.synContainingType = t;
		}
		if (extra == null) {
			if (t == null) {
				return t;
			}
			extra = new ValueSymbolExtra();
		}
		return extra.containingType = t;
	}

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class ValueSymbolExtra {
	var writeType:Type = null;
	var nameType:Type = null;
	var containingType:Type = null;
	var functionOrConstructorChecked:Bool = false;

	public function new() {}
}

// the value links of a transient symbol (see ValueSymbolLinks.target)
@:allow(ts.checker)
class TransientValueSymbolLinks extends ValueSymbolLinksRecord {
	var instTarget:Symbol = null;
	var instMapper:TypeMapper = null;

	public function new() {
		super();
	}
}

// the value links of a synthetic (union or intersection) or mapped property, which have a containing type and
// most often a name type (see ValueSymbolLinks.get_nameType), and no target or mapper (one set would go to
// the side record: none on t3code-server)
@:allow(ts.checker)
class SyntheticValueSymbolLinks extends ValueSymbolLinksRecord {
	var synNameType:Type = null;
	var synContainingType:Type = null;

	public function new() {
		super();
	}
}

// the value links of a mapped type's property, with Go's MappedSymbolLinks (Checker.getMappedKeyType, ...)
@:allow(ts.checker)
class MappedValueSymbolLinks extends SyntheticValueSymbolLinks {
	var mappedKeyType:Type = null;
	var mappedSyntheticOrigin:Symbol = null;

	public function new() {
		super();
	}
}

// the side record of the value links of a symbol that is not transient, with a target or mapper
@:allow(ts.checker)
class ValueSymbolTargetExtra extends ValueSymbolExtra {
	var target:Symbol = null;
	var mapper:TypeMapper = null;

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class MappedSymbolLinks extends ts.core.Linkstore.LinkEntry {
	var keyType:Type = null; // Key type for mapped type member
	var syntheticOrigin:Symbol = null; // For a property on a mapped or spread type, points back to the original property

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class DeferredSymbolLinks extends ts.core.Linkstore.LinkEntry {
	var parent:Type = null; // Source union/intersection of a deferred type
	var constituents:Array<Type> = null; // Calculated list of constituents for a deferred type
	var writeConstituents:Array<Type> = null; // Constituents of a deferred `writeType`

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class AliasSymbolLinks extends ts.core.Linkstore.LinkEntry {
	var immediateTarget:Symbol = null; // Immediate target of an alias. May be another alias. Do not access directly, use `checker.getImmediateAliasedSymbol` instead.
	var aliasTarget:Symbol = null; // Resolved (non-alias) target of an alias
	var referenced:Bool = false; // True if alias symbol has been referenced as a value that can be emitted
	var typeOnlyDeclaration:Node = null; // First resolved alias declaration that makes the symbol only usable in type constructs

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class ModuleSymbolLinks extends ts.core.Linkstore.LinkEntry {
	var resolvedExports:SymbolTable = null; // Resolved exports of module or combined early- and late-bound static members of a class.
	var typeOnlyExportStarMap:StringMap<Node> = null; // Set on a module symbol when some of its exports were resolved through a 'export type * from "mod"' declaration
	var exportsChecked:Bool = false;

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class ReverseMappedSymbolLinks extends ts.core.Linkstore.LinkEntry {
	var propertyType:Type = null;
	var mappedType:Type = null; // References a mapped type
	var constraintType:Type = null; // References an index type

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class LateBoundLinks extends ts.core.Linkstore.LinkEntry {
	var lateSymbol:Symbol = null;

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class ExportTypeLinks extends ts.core.Linkstore.LinkEntry {
	var target:Symbol = null; // Target symbol
	var originatingImport:Node = null; // Import declaration which produced the symbol, present if the symbol is marked as uncallable but had call signatures in `resolveESModuleSymbol`

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class TypeAliasLinks extends ts.core.Linkstore.LinkEntry {
	var declaredType:Type = null;
	var typeParameters:haxe.ds.Vector<Type> = null; // Type parameters of type alias (undefined if non-generic) // PORT: perf — a Vector
	var instantiations:ts.core.HashKeyMap<Type> /* key: checker.CacheHashKey */ = null; // Instantiations of generic type alias (undefined if non-generic)
	var isConstructorDeclaredProperty:Bool = false;

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class DeclaredTypeLinks extends ts.core.Linkstore.LinkEntry {
	var declaredType:Type = null;
	var interfaceChecked:Bool = false;
	var indexSignaturesChecked:Bool = false;
	var typeParametersChecked:Bool = false;
	var enumChecked:Bool = false;

	public function new() {
		super();
	}
}

enum abstract ExhaustiveState(Int) from Int to Int {
	var ExhaustiveStateUnknown = 0; // Exhaustive state not computed
	var ExhaustiveStateComputing = 1; // Exhaustive state computation in progress
	var ExhaustiveStateFalse = 2; // Switch statement is not exhaustive
	var ExhaustiveStateTrue = 3; // Switch statement is exhaustive
}

@:allow(ts.checker)
class SwitchStatementLinks extends ts.core.Linkstore.LinkEntry {
	var exhaustiveState:ExhaustiveState = 0; // Switch statement exhaustiveness
	var switchTypesComputed:Bool = false;
	var witnessesComputed:Bool = false;
	var switchTypes:Array<Type> = null;
	var witnesses:Array<std.String> = null;

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class ArrayLiteralLinks extends ts.core.Linkstore.LinkEntry {
	var indicesComputed:Bool = false;
	var firstSpreadIndex:Int = 0; // Index of first spread expression (or -1 if none)
	var lastSpreadIndex:Int = 0; // Index of last spread expression (or -1 if none)

	public function new() {
		super();
	}
}

enum abstract MembersOrExportsResolutionKind(Int) from Int to Int {
	var MembersOrExportsResolutionKindResolvedExports = 0;
	var MembersOrExportsResolutionKindResolvedMembers = 1;
}

// PORT: perf — Go `[2]SymbolTable` (by MembersOrExportsResolutionKind) as two fields of a link object (see LinkStore)
@:allow(ts.checker)
class MembersAndExportsLinks extends ts.core.Linkstore.LinkEntry {
	var resolvedExports:SymbolTable = null; // [MembersOrExportsResolutionKindResolvedExports]
	var resolvedMembers:SymbolTable = null; // [MembersOrExportsResolutionKindResolvedMembers]

	public function new() {
		super();
	}

	inline function get(kind:Int):SymbolTable {
		return kind == 0 ? resolvedExports : resolvedMembers;
	}

	inline function set(kind:Int, table:SymbolTable):Void {
		if (kind == 0) {
			resolvedExports = table;
		} else {
			resolvedMembers = table;
		}
	}
}

// PORT: perf — TypeScript 7.1's merged symbols in a symbol link store (microsoft/TypeScript#64869)
@:allow(ts.checker)
class MergedSymbolLinks extends ts.core.Linkstore.LinkEntry {
	var target:Symbol = null;

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class SpreadLinks extends ts.core.Linkstore.LinkEntry {
	var leftSpread:Symbol = null; // Left source for synthetic spread property
	var rightSpread:Symbol = null; // Right source for synthetic spread property

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class VarianceLinks extends ts.core.Linkstore.LinkEntry {
	var variances:Array<VarianceFlags> = null;

	public function new() {
		super();
	}
}

enum abstract VarianceFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:VarianceFlags, b:VarianceFlags):VarianceFlags;
	@:op(A & B) static function and(a:VarianceFlags, b:VarianceFlags):VarianceFlags;
	@:op(~A) static function not(a:VarianceFlags):VarianceFlags;

	var VarianceFlagsInvariant = 0; // Neither covariant nor contravariant
	var VarianceFlagsCovariant = 1 << 0; // Covariant
	var VarianceFlagsContravariant = 1 << 1; // Contravariant
	var VarianceFlagsBivariant = 3; // Both covariant and contravariant
	var VarianceFlagsIndependent = 1 << 2; // Unwitnessed type parameter
	var VarianceFlagsVarianceMask = 7; // Mask containing all measured variances without the unmeasurable flag
	var VarianceFlagsUnmeasurable = 1 << 3; // Variance result is unusable - relationship relies on structural comparisons which are not reflected in generic relationships
	var VarianceFlagsUnreliable = 1 << 4; // Variance result is unreliable - checking may produce false negatives, but not false positives
	var VarianceFlagsAllowsStructuralFallback = 24;

	public function String():std.String {
		final variance:VarianceFlags = (this : VarianceFlags) & VarianceFlagsVarianceMask;
		var result:std.String;
		switch (variance) {
			case VarianceFlagsInvariant:
				result = "in out";
			case VarianceFlagsBivariant:
				result = "[bivariant]";
			case VarianceFlagsContravariant:
				result = "in";
			case VarianceFlagsCovariant:
				result = "out";
			case VarianceFlagsIndependent:
				result = "[independent]";
			default:
				result = "";
		}
		if (((this : VarianceFlags) & VarianceFlagsUnmeasurable) != 0) {
			result += " (unmeasurable)";
		} else if (((this : VarianceFlags) & VarianceFlagsUnreliable) != 0) {
			result += " (unreliable)";
		}
		return result;
	}
}

@:allow(ts.checker)
class MarkedAssignmentSymbolLinks extends ts.core.Linkstore.LinkEntry {
	var lastAssignmentPos:Int = 0;
	var hasDefiniteAssignment:Bool = false; // Symbol is definitely assigned somewhere

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class AccessibleChainCacheKey {
	var useOnlyExternalAliasing:Bool = false;
	var location:Node = null;
	var meaning:SymbolFlags = 0;

	public function new() {}
}

@:allow(ts.checker)
class ContainingSymbolLinks extends ts.core.Linkstore.LinkEntry {
	var extendedContainersByFile:IntMap<Array<Symbol>> = null; // Symbols of nodes which which logically contain this one, cached by file the request is made within
	var extendedContainers:Array<Symbol> = null; // Containers (other than the parent) which this symbol is aliased in
	var accessibleChainCache:StringMap<Array<Symbol>> /* key: checker.accessibleChainCacheKey */ = null;

	public function new() {
		super();
	}
}

enum abstract AccessFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:AccessFlags, b:AccessFlags):AccessFlags;
	@:op(A & B) static function and(a:AccessFlags, b:AccessFlags):AccessFlags;
	@:op(~A) static function not(a:AccessFlags):AccessFlags;

	var AccessFlagsNone = 0;
	var AccessFlagsIncludeUndefined = 1 << 0;
	var AccessFlagsNoIndexSignatures = 1 << 1;
	var AccessFlagsWriting = 1 << 2;
	var AccessFlagsCacheSymbol = 1 << 3;
	var AccessFlagsAllowMissing = 1 << 4;
	var AccessFlagsExpressionPosition = 1 << 5;
	var AccessFlagsReportDeprecated = 1 << 6;
	var AccessFlagsSuppressNoImplicitAnyError = 1 << 7;
	var AccessFlagsContextual = 1 << 8;
	var AccessFlagsPersistent = 1 << 0;
}

enum abstract NodeCheckFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:NodeCheckFlags, b:NodeCheckFlags):NodeCheckFlags;
	@:op(A & B) static function and(a:NodeCheckFlags, b:NodeCheckFlags):NodeCheckFlags;
	@:op(~A) static function not(a:NodeCheckFlags):NodeCheckFlags;

	var NodeCheckFlagsNone = 0;
	var NodeCheckFlagsTypeChecked = 1 << 0; // Node has been type checked
	var NodeCheckFlagsContextChecked = 1 << 6; // Contextual types have been assigned
	var NodeCheckFlagsEnumValuesComputed = 1 << 10; // Values for enum members have been computed, and any errors have been reported for them.
	var NodeCheckFlagsAssignmentsMarked = 1 << 17; // Parameter assignments have been marked
	var NodeCheckFlagsContainsClassWithPrivateIdentifiers = 1 << 20; // Marked on all block-scoped containers containing a class with private identifiers.
	var NodeCheckFlagsContainsSuperPropertyInStaticInitializer = 1 << 21; // Marked on all block-scoped containers containing a static initializer with 'super.x' or 'super[x]'.
	var NodeCheckFlagsInCheckIdentifier = 1 << 22;
	var NodeCheckFlagsInitializerIsUndefined = 1 << 24;
	var NodeCheckFlagsInitializerIsUndefinedComputed = 1 << 25;
}

@:allow(ts.checker)
class NodeLinks extends ts.core.Linkstore.LinkEntry {
	var flags:NodeCheckFlags = 0; // Set of flags specific to Node
	var declarationRequiresScopeChange:Tristate = 0; // Set by `useOuterVariableScopeInParameter` in checker when downlevel emit would change the name resolution scope inside of a parameter.
	var hasReportedStatementInAmbientContext:Bool = false; // Cache boolean if we report statements in ambient context

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class SymbolNodeLinks extends ts.core.Linkstore.LinkEntry {
	var resolvedSymbol:Symbol = null; // Resolved symbol associated with node

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class TypeNodeLinks extends ts.core.Linkstore.LinkEntry {
	var resolvedType:Type = null; // Resolved type associated with node
	var outerTypeParameters:Array<Type> = null; // Outer type parameters of anonymous object type

	public function new() {
		super();
	}
}


enum abstract MemberOverrideStatus(Int) from Int to Int {
	var MemberOverrideStatusNone = 0;
	var MemberOverrideStatusNeedsOverride = 1;
	var MemberOverrideStatusHasInvalidOverride = 2;
}

@:allow(ts.checker)
class ComputedNameNodeLinks extends ts.core.Linkstore.LinkEntry {
	var hasName:Tristate = 0; // If the node has a computable name
	var name:std.String = ""; // Resolved name associated with the type of the node

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class EnumMemberLinks extends ts.core.Linkstore.LinkEntry {
	var value:Result = new Result() /* PORT: Go zero struct */; // Constant value of enum member

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class AssertionLinks extends ts.core.Linkstore.LinkEntry {
	var exprType:Type = null; // Assertion expression type

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class SourceFileLinks extends ts.core.Linkstore.LinkEntry {
	var typeChecked:Bool = false;
	var unusedChecked:Bool = false;
	var externalHelpersModule:Symbol = null;
	var requestedExternalEmitHelpers:ExternalEmitHelpers = 0;
	var deferredNodes:ts.collections.OrderedSet<Node> = new ts.collections.OrderedSet<Node>();
	var identifierCheckNodes:Array<Node> = null;
	var localJsxNamespace:std.String = "";
	var localJsxFragmentNamespace:std.String = "";
	var localJsxFactory:EntityName = null;
	var localJsxFragmentFactory:EntityName = null;
	var jsxFragmentType:Type = null;

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class SignatureLinks extends ts.core.Linkstore.LinkEntry {
	var resolvedSignature:Signature = null; // Cached signature of signature node or call expression
	// PORT: perf — effectsSignature and decoratorSignature in stores of their own (EffectsSignatureLinks,
	// DecoratorSignatureLinks: t3code-server, 7% and none of the signature links had them)

	public function new() {
		super();
	}
}

// PORT: perf — Go's SignatureLinks.effectsSignature (Checker.effectsSignatureLinks)
@:allow(ts.checker)
class EffectsSignatureLinks extends ts.core.Linkstore.LinkEntry {
	var effectsSignature:Signature = null; // Signature with possible control flow effects

	public function new() {
		super();
	}
}

// PORT: perf — Go's SignatureLinks.decoratorSignature (Checker.decoratorSignatureLinks)
@:allow(ts.checker)
class DecoratorSignatureLinks extends ts.core.Linkstore.LinkEntry {
	var decoratorSignature:Signature = null; // Signature for decorator as if invoked by the runtime

	public function new() {
		super();
	}
}

enum abstract TypeFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:TypeFlags, b:TypeFlags):TypeFlags;
	@:op(A & B) static function and(a:TypeFlags, b:TypeFlags):TypeFlags;
	@:op(~A) static function not(a:TypeFlags):TypeFlags;

	var TypeFlagsNone = 0;
	var TypeFlagsAny = 1 << 0;
	var TypeFlagsUnknown = 1 << 1;
	var TypeFlagsUndefined = 1 << 2;
	var TypeFlagsNull = 1 << 3;
	var TypeFlagsVoid = 1 << 4;
	var TypeFlagsString = 1 << 5;
	var TypeFlagsNumber = 1 << 6;
	var TypeFlagsBigInt = 1 << 7;
	var TypeFlagsBoolean = 1 << 8;
	var TypeFlagsESSymbol = 1 << 9; // Type of symbol primitive introduced in ES6
	var TypeFlagsStringLiteral = 1 << 10;
	var TypeFlagsNumberLiteral = 1 << 11;
	var TypeFlagsBigIntLiteral = 1 << 12;
	var TypeFlagsBooleanLiteral = 1 << 13;
	var TypeFlagsUniqueESSymbol = 1 << 14; // unique symbol
	var TypeFlagsEnumLiteral = 1 << 15; // Always combined with StringLiteral, NumberLiteral, or Union
	var TypeFlagsEnum = 1 << 16; // Numeric computed enum member value (must be right after EnumLiteral, see getSortOrderFlags)
	var TypeFlagsNonPrimitive = 1 << 17; // intrinsic object type
	var TypeFlagsNever = 1 << 18; // Never type
	var TypeFlagsTypeParameter = 1 << 19; // Type parameter
	var TypeFlagsObject = 1 << 20; // Object type
	var TypeFlagsIndex = 1 << 21; // keyof T
	var TypeFlagsTemplateLiteral = 1 << 22; // Template literal type
	var TypeFlagsStringMapping = 1 << 23; // Uppercase/Lowercase type
	var TypeFlagsSubstitution = 1 << 24; // Type parameter substitution
	var TypeFlagsIndexedAccess = 1 << 25; // T[K]
	var TypeFlagsConditional = 1 << 26; // T extends U ? X : Y
	var TypeFlagsUnion = 1 << 27; // Union (T | U)
	var TypeFlagsIntersection = 1 << 28; // Intersection (T & U)
	var TypeFlagsReserved1 = 1 << 29; // Used by union/intersection type construction
	var TypeFlagsReserved2 = 1 << 30; // Used by union/intersection type construction
	var TypeFlagsReserved3 = 1 << 31;
	var TypeFlagsAnyOrUnknown = 3;
	var TypeFlagsNullable = 12;
	var TypeFlagsLiteral = 15360;
	var TypeFlagsUnit = 97292;
	var TypeFlagsFreshable = 80896;
	var TypeFlagsStringOrNumberLiteral = 3072;
	var TypeFlagsStringOrNumberLiteralOrUnique = 19456;
	var TypeFlagsDefinitelyFalsy = 15388;
	var TypeFlagsPossiblyFalsy = 15868;
	var TypeFlagsIntrinsic = 393983;
	var TypeFlagsStringLike = 12583968;
	var TypeFlagsNumberLike = 67648;
	var TypeFlagsBigIntLike = 4224;
	var TypeFlagsBooleanLike = 8448;
	var TypeFlagsEnumLike = 98304;
	var TypeFlagsESSymbolLike = 16896;
	var TypeFlagsVoidLike = 20;
	var TypeFlagsPrimitive = 12713980;
	var TypeFlagsDefinitelyNonNullable = 13893600;
	var TypeFlagsDisjointDomains = 12812284;
	var TypeFlagsUnionOrIntersection = 402653184;
	var TypeFlagsStructuredType = 403701760;
	var TypeFlagsTypeVariable = 34078720;
	var TypeFlagsInstantiableNonPrimitive = 117964800;
	var TypeFlagsInstantiablePrimitive = 14680064;
	var TypeFlagsInstantiable = 132644864;
	var TypeFlagsStructuredOrInstantiable = 536346624;
	var TypeFlagsObjectFlagsType = 403963917;
	var TypeFlagsSimplifiable = 102760448;
	var TypeFlagsSingleton = 394239;
	// 'TypeFlagsNarrowable' types are types where narrowing actually narrows.
	// This *should* be every type other than null, undefined, void, and never
	var TypeFlagsNarrowable = 536575971;
	// The following flags are aggregated during union and intersection type construction
	var TypeFlagsIncludesMask = 416808959;
	// The following flags are used for different purposes during union and intersection type construction
	var TypeFlagsIncludesMissingType = 1 << 19;
	var TypeFlagsIncludesNonWideningType = 1 << 21;
	var TypeFlagsIncludesWildcard = 1 << 25;
	var TypeFlagsIncludesEmptyObject = 1 << 26;
	var TypeFlagsIncludesInstantiable = 1 << 24;
	var TypeFlagsIncludesConstrainedTypeVariable = 1 << 29;
	var TypeFlagsIncludesError = 1 << 30;
	var TypeFlagsNotPrimitiveUnion = 286523411;

	// String returns a pipe-separated string of flag names.
	public function String():std.String {
		return Checker.FormatTypeFlags(this).join("|");
	}
}

enum abstract ObjectFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:ObjectFlags, b:ObjectFlags):ObjectFlags;
	@:op(A & B) static function and(a:ObjectFlags, b:ObjectFlags):ObjectFlags;
	@:op(~A) static function not(a:ObjectFlags):ObjectFlags;

	var ObjectFlagsNone = 0;
	var ObjectFlagsClass = 1 << 0; // Class
	var ObjectFlagsInterface = 1 << 1; // Interface
	var ObjectFlagsReference = 1 << 2; // Generic type reference
	var ObjectFlagsTuple = 1 << 3; // Synthesized generic tuple type
	var ObjectFlagsAnonymous = 1 << 4; // Anonymous
	var ObjectFlagsMapped = 1 << 5; // Mapped
	var ObjectFlagsInstantiated = 1 << 6; // Instantiated anonymous or mapped type
	var ObjectFlagsObjectLiteral = 1 << 7; // Originates in an object literal
	var ObjectFlagsEvolvingArray = 1 << 8; // Evolving array type
	var ObjectFlagsObjectLiteralPatternWithComputedProperties = 1 << 9; // Object literal pattern with computed properties
	var ObjectFlagsReverseMapped = 1 << 10; // Object contains a property from a reverse-mapped type
	var ObjectFlagsJsxAttributes = 1 << 11; // Jsx attributes type
	var ObjectFlagsJSLiteral = 1 << 12; // Object type declared in JS - disables errors on read/write of nonexisting members
	var ObjectFlagsFreshLiteral = 1 << 13; // Fresh object literal
	var ObjectFlagsArrayLiteral = 1 << 14; // Originates in an array literal
	var ObjectFlagsPrimitiveUnion = 1 << 15; // Union of only primitive types
	var ObjectFlagsContainsWideningType = 1 << 16; // Type is or contains undefined or null widening type
	var ObjectFlagsContainsObjectOrArrayLiteral = 1 << 17; // Type is or contains object literal type
	var ObjectFlagsNonInferrableType = 1 << 18; // Type is or contains anyFunctionType or silentNeverType
	var ObjectFlagsCouldContainTypeVariablesComputed = 1 << 19; // CouldContainTypeVariables flag has been computed
	var ObjectFlagsCouldContainTypeVariables = 1 << 20; // Type could contain a type variable
	var ObjectFlagsMembersResolved = 1 << 21; // Members have been resolved
	var ObjectFlagsClassOrInterface = 3;
	var ObjectFlagsRequiresWidening = 196608;
	var ObjectFlagsPropagatingFlags = 458752;
	var ObjectFlagsInstantiatedMapped = 96;
	// Object flags that uniquely identify the kind of ObjectType
	var ObjectFlagsObjectTypeKindMask = 50332991;
	// PORT: the rest of this const block is untyped in Go (package-level statics on Checker, e.g.
	// `Checker.ObjectFlagsObjectRestType`); repeated here as typed values (same names, same values) for convenience.
	// Flags that require TypeFlags.Object
	var ObjectFlagsContainsSpread = 1 << 22; // Object literal contains spread operation
	var ObjectFlagsObjectRestType = 1 << 23; // Originates in object rest declaration
	var ObjectFlagsInstantiationExpressionType = 1 << 24; // Originates in instantiation expression
	var ObjectFlagsSingleSignatureType = 1 << 25; // A single signature type extracted from a potentially broader type
	var ObjectFlagsIsClassInstanceClone = 1 << 26; // Type is a clone of a class instance type
	// Flags that require TypeFlags.Object and ObjectFlags.Reference
	var ObjectFlagsIdenticalBaseTypeCalculated = 1 << 27; // has had `getSingleBaseForNonAugmentingSubtype` invoked on it already
	var ObjectFlagsIdenticalBaseTypeExists = 1 << 28; // has a defined cachedEquivalentBaseType member
	var ObjectFlagsUnresolvedMembers = 1 << 29; // Member resolution in process
	var ObjectFlagsFromTypeNode = 1 << 30; // Originates in resolution of AST type node
	// Flags that require TypeFlags.UnionOrIntersection or TypeFlags.Substitution
	var ObjectFlagsIsGenericTypeComputed = 1 << 22; // IsGenericObjectType flag has been computed
	var ObjectFlagsIsGenericObjectType = 1 << 23; // Union or intersection contains generic object type
	var ObjectFlagsIsGenericIndexType = 1 << 24; // Union or intersection contains generic index type
	var ObjectFlagsIsGenericType = 25165824;
	// Flags that require TypeFlags.Union
	var ObjectFlagsContainsIntersections = 1 << 25; // Union contains intersections
	var ObjectFlagsIsUnknownLikeUnionComputed = 1 << 26; // IsUnknownLikeUnion flag has been computed
	var ObjectFlagsIsUnknownLikeUnion = 1 << 27; // Union of null, undefined, and empty object type
	// PORT: perf — from TypeScript 7.1 (microsoft/typescript-go#4781)
	var ObjectFlagsIsUniformEnumComputed = 1 << 28; // IsUniformEnum flag has been computed
	var ObjectFlagsIsUniformEnum = 1 << 29; // Union contains uniform literal types
	// Flags that require TypeFlags.Intersection
	var ObjectFlagsIsNeverIntersectionComputed = 1 << 25; // IsNeverLike flag has been computed
	var ObjectFlagsIsNeverIntersection = 1 << 26; // Intersection reduces to never
	var ObjectFlagsIsConstrainedTypeVariable = 1 << 27; // T & C, where T's constraint and C are primitives, object, or {}
}

@:allow(ts.checker)
class TypeAlias {
	var symbol:Symbol = null;
	var typeArguments:haxe.ds.Vector<Type> = null; // PORT: perf — a Vector (one exact-size object)

	public function new() {}

	// PORT: nil receiver — inline with a `this == null` check like Go.
	public inline function Symbol():Symbol {
		if (this == null) {
			return null;
		}
		return this.symbol;
	}

	// PORT: nil receiver — inline with a `this == null` check like Go.
	public inline function TypeArguments():haxe.ds.Vector<Type> {
		if (this == null) {
			return null;
		}
		return this.typeArguments;
	}
}

@:allow(ts.checker)
class TypeExtra {
	var alias:TypeAlias = null;
	var resolvedBaseConstraint:Type = null; // (StructuredType)
	var node:Node = null; // (TypeReference)
	var flowType:FlowType = null;
	var objectTypeWithoutAbstractConstructSignatures:Type = null;
	var instantiations:ts.core.HashKeyMap<Type> /* key: checker.CacheHashKey */ = null;

	public function new() {}
}

// PORT: perf — the TypeExtra of a type reference, union or intersection, with the fields of Go's StructuredType and
// ObjectType that these types rarely set (an anonymous type has them as fields: AnonymousType)
@:allow(ts.checker)
class StructuredTypeExtra extends TypeExtra {
	var members:SymbolTable = null; // (t3code-server: 0.1% of the type references, no union or intersection)
	var mapper:TypeMapper = null; // (a type reference's: 0.8%)

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class Type implements TypeSystemEntity {
	var flags:TypeFlags = 0;
	var objectFlags:ObjectFlags = 0;
	var id:TypeId = 0;
	var symbol:Symbol = null;
	var checker:Checker = null;
	// PORT: perf — no `data` field: Go's `data` (Type specific data) is always the type itself here (every
	// TypeData is a TypeBase, a subclass of Type), so the As*() casts are of `this`.
	// PORT: perf — the rarely set fields of a type (its alias, FlowType; an object type's instantiations and type
	// without abstract construct signatures; a deferred type reference's node) in a side record, allocated when one
	// is set to a non-nil value
	var extra:TypeExtra = null;
	var alias(get, set):TypeAlias; // (in TypeExtra: t3code-server, 4% of the types have one)

	// the side record, made when a field of it is set: a StructuredTypeExtra for a type reference, union or
	// intersection (StructuredType.members)
	function newExtra():TypeExtra {
		return extra = Std.isOfType(this, TypeReference) || Std.isOfType(this, UnionOrIntersectionType) ? new StructuredTypeExtra() : new TypeExtra();
	}

	inline function get_alias():TypeAlias {
		return extra == null ? null : extra.alias;
	}

	function set_alias(v:TypeAlias):TypeAlias {
		if (extra == null) {
			if (v == null) {
				return v;
			}
			newExtra();
		}
		return extra.alias = v;
	}
	// PORT: perf — FlowType{t: this, incomplete: false}, made once (Go returns FlowType by value); the incomplete
	// one hangs off it (FlowType.twin).
	var flowType(get, set):FlowType;

	inline function get_flowType():FlowType {
		return extra == null ? null : extra.flowType;
	}

	function set_flowType(v:FlowType):FlowType {
		if (extra == null) {
			if (v == null) {
				return v;
			}
			newExtra();
		}
		return extra.flowType = v;
	}

	public function new() {}

	public function Id():TypeId {
		return id;
	}

	public function Flags():TypeFlags {
		return flags;
	}

	public function ObjectFlags():ObjectFlags {
		return objectFlags;
	}

	public inline function AsIntrinsicType():IntrinsicType {
		return cast this;
	}

	public inline function AsLiteralType():LiteralType {
		return cast this;
	}

	public inline function AsUniqueESSymbolType():UniqueESSymbolType {
		return cast this;
	}

	public inline function AsTupleType():TupleType {
		return cast this;
	}

	public inline function AsInstantiationExpressionType():InstantiationExpressionType {
		return cast this;
	}

	public inline function AsMappedType():MappedType {
		return cast this;
	}

	public inline function AsReverseMappedType():ReverseMappedType {
		return cast this;
	}

	public inline function AsEvolvingArrayType():EvolvingArrayType {
		return cast this;
	}

	public inline function AsTypeParameter():TypeParameter {
		return cast this;
	}

	public inline function AsUnionType():UnionType {
		return cast this;
	}

	public inline function AsIntersectionType():IntersectionType {
		return cast this;
	}

	public inline function AsIndexType():IndexType {
		return cast this;
	}

	public inline function AsIndexedAccessType():IndexedAccessType {
		return cast this;
	}

	public inline function AsTemplateLiteralType():TemplateLiteralType {
		return cast this;
	}

	public inline function AsStringMappingType():StringMappingType {
		return cast this;
	}

	public inline function AsSubstitutionType():SubstitutionType {
		return cast this;
	}

	public inline function AsConditionalType():ConditionalType {
		return cast this;
	}

	// PORT: perf — inline: what every TypeData's AsConstrainedType returns (the data when it is a ConstrainedType, else null),
	// a type test in place of an interface call
	public inline function AsConstrainedType():ConstrainedType {
		return Std.downcast(this, ConstrainedType);
	}

	// PORT: perf — inline: what every TypeData's AsStructuredType returns (the data when it is a StructuredType, else null),
	// a type test in place of an interface call
	public inline function AsStructuredType():StructuredType {
		return Std.downcast(this, StructuredType);
	}

	// PORT: perf — inline: what every TypeData's AsObjectType returns (the data when it is a ObjectType, else null),
	// a type test in place of an interface call
	public inline function AsObjectType():ObjectType {
		return Std.downcast(this, ObjectType);
	}

	// PORT: perf — inline: what every TypeData's AsTypeReference returns (the data when it is a TypeReference, else null),
	// a type test in place of an interface call
	public inline function AsTypeReference():TypeReference {
		return Std.downcast(this, TypeReference);
	}

	// PORT: perf — inline: what every TypeData's AsInterfaceType returns (the data when it is a InterfaceType, else null),
	// a type test in place of an interface call
	public inline function AsInterfaceType():InterfaceType {
		return Std.downcast(this, InterfaceType);
	}

	// PORT: perf — inline: what every TypeData's AsUnionOrIntersectionType returns (the data when it is a UnionOrIntersectionType, else null),
	// a type test in place of an interface call
	public inline function AsUnionOrIntersectionType():UnionOrIntersectionType {
		return Std.downcast(this, UnionOrIntersectionType);
	}

	public function Distributed():haxe.ds.Vector<Type> {
		if ((flags & TypeFlagsUnion) != 0) {
			return AsUnionType().types;
		} else if ((flags & TypeFlagsNever) != 0) {
			return new haxe.ds.Vector<Type>(0);
		}
		final v = new haxe.ds.Vector<Type>(1);
		v[0] = this;
		return v;
	}

	public function Target():Type {
		if ((flags & TypeFlagsObject) != 0) {
			return AsObjectType().target;
		} else if ((flags & TypeFlagsTypeParameter) != 0) {
			return AsTypeParameter().target;
		} else if ((flags & TypeFlagsIndex) != 0) {
			return AsIndexType().target;
		} else if ((flags & TypeFlagsStringMapping) != 0) {
			return AsStringMappingType().target;
		} else if ((flags & TypeFlagsObject) != 0 && (objectFlags & ObjectFlagsMapped) != 0) {
			return AsMappedType().target;
		}
		throw "Unhandled case in Type.Target";
	}

	public function Mapper():TypeMapper {
		if ((flags & TypeFlagsObject) != 0) {
			return AsObjectType().mapper;
		} else if ((flags & TypeFlagsTypeParameter) != 0) {
			return AsTypeParameter().mapper;
		} else if ((flags & TypeFlagsConditional) != 0) {
			return AsConditionalType().mapper;
		}
		throw "Unhandled case in Type.Mapper";
	}

	// PORT: perf — inline (no virtual call): a union's or intersection's types (its flags say its class)
	public inline function Types():haxe.ds.Vector<Type> {
		return (flags & TypeFlagsUnionOrIntersection) != 0 ? (cast this : UnionOrIntersectionType).types : TypesSlow();
	}

	function TypesSlow():haxe.ds.Vector<Type> {
		if ((flags & TypeFlagsUnionOrIntersection) != 0) {
			return AsUnionOrIntersectionType().types;
		} else if ((flags & TypeFlagsTemplateLiteral) != 0) {
			return VectorBuilder.freeze(AsTemplateLiteralType().types); // PORT: perf (a copy: template literal types are rare here)
		}
		throw "Unhandled case in Type.Types";
	}

	public function TargetInterfaceType():InterfaceType {
		return AsTypeReference().target.AsInterfaceType();
	}

	public function TargetTupleType():TupleType {
		return AsTypeReference().target.AsTupleType();
	}

	public function Symbol():Symbol {
		return symbol;
	}

	public function Alias():TypeAlias {
		return alias;
	}

	public function IsUnion():Bool {
		return (flags & TypeFlagsUnion) != 0;
	}

	public function IsString():Bool {
		return (flags & TypeFlagsString) != 0;
	}

	public function IsIntersection():Bool {
		return (flags & TypeFlagsIntersection) != 0;
	}

	public function IsStringLiteral():Bool {
		return (flags & TypeFlagsStringLiteral) != 0;
	}

	public function IsNumberLiteral():Bool {
		return (flags & TypeFlagsNumberLiteral) != 0;
	}

	public function IsBigIntLiteral():Bool {
		return (flags & TypeFlagsBigIntLiteral) != 0;
	}

	public function IsEnumLiteral():Bool {
		return (flags & TypeFlagsEnumLiteral) != 0;
	}

	public function IsBooleanLike():Bool {
		return (flags & TypeFlagsBooleanLike) != 0;
	}

	public function IsStringLike():Bool {
		return (flags & TypeFlagsStringLike) != 0;
	}

	public function IsClass():Bool {
		return (objectFlags & ObjectFlagsClass) != 0;
	}

	public function IsTypeParameter():Bool {
		return (flags & TypeFlagsTypeParameter) != 0;
	}

	public function IsIndex():Bool {
		return (flags & TypeFlagsIndex) != 0;
	}

	public function IsTupleType():Bool {
		return Checker.isTupleType(this);
	}
}

interface TypeData {
	function AsType():Type;
}

class TypeBase extends Type implements TypeData {
	public function new() {
		super();
	}

	public function AsType():Type {
		return this;
	}






}

@:allow(ts.checker)
class IntrinsicType extends TypeBase {
	var intrinsicName:std.String = "";

	public function new() {
		super();
	}

	public function IntrinsicName():std.String {
		return intrinsicName;
	}
}

@:allow(ts.checker)
class LiteralType extends TypeBase {
	var value:Any = null; // string | jsnum.Number | bool | PseudoBigInt | nil (computed enum)
	var freshType:Type = null; // Fresh version of type
	var regularType:Type = null; // Regular version of type

	public function new() {
		super();
	}

	public function Value():Any {
		return value;
	}

	public function FreshType():Type {
		return freshType;
	}

	public function RegularType():Type {
		return regularType;
	}

	public function String():std.String {
		return Checker.ValueToString(value);
	}
}

@:allow(ts.checker)
class UniqueESSymbolType extends TypeBase {
	var name:std.String = "";

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class ConstrainedType extends TypeBase {
	// PORT: perf — a structured type's resolved base constraint is in TypeExtra (t3code-server: 1% of the object
	// types have one), an instantiable type's in a field (InstantiableType); the type's flags say which it is
	var resolvedBaseConstraint(get, set):Type;

	inline function get_resolvedBaseConstraint():Type {
		final t:Type = this;
		if ((t.flags & TypeFlagsStructuredType) != 0) {
			final x = t.extra;
			return x == null ? null : x.resolvedBaseConstraint;
		}
		return (cast this : InstantiableType).baseConstraint;
	}

	function set_resolvedBaseConstraint(v:Type):Type {
		final t:Type = this;
		if ((t.flags & TypeFlagsStructuredType) != 0) {
			if (t.extra == null) {
				if (v == null) {
					return v;
				}
				t.newExtra();
			}
			return t.extra.resolvedBaseConstraint = v;
		}
		return (cast this : InstantiableType).baseConstraint = v;
	}

	public function new() {
		super();
	}

}

// PORT: perf — the constrained types that are not structured (see ConstrainedType.resolvedBaseConstraint)
@:allow(ts.checker)
class InstantiableType extends ConstrainedType {
	var baseConstraint:Type = null;

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class StructuredType extends ConstrainedType {
	// PORT: perf — an anonymous type's field (AnonymousType); a type reference's, union's or intersection's (which
	// get their members from a MemberLayout or not at all) in the side record (StructuredTypeExtra)
	var members(get, set):SymbolTable;

	inline function get_members():SymbolTable {
		return Std.isOfType(this, AnonymousType) ? (cast this : AnonymousType).anonMembers : structuredExtraMembers();
	}

	inline function structuredExtraMembers():SymbolTable {
		final x = (cast this : Type).extra;
		return x == null ? null : (cast x : StructuredTypeExtra).members;
	}

	function set_members(v:SymbolTable):SymbolTable {
		if (Std.isOfType(this, AnonymousType)) {
			return (cast this : AnonymousType).anonMembers = v;
		}
		final t:Type = cast this;
		if (t.extra == null) {
			if (v == null) {
				return v;
			}
			t.newExtra();
		}
		return (cast t.extra : StructuredTypeExtra).members = v;
	}

	var properties:haxe.ds.Vector<Symbol> = null; // PORT: perf — a Vector (one exact-size object; null: Go nil, which a lazy type tests)
	var signatures:haxe.ds.Vector<Signature> = null; // Signatures (call + construct) // PORT: perf — Vectors (one exact-size object each)
	var callSignatureCount:Int = 0; // Count of call signatures
	var indexInfos:haxe.ds.Vector<IndexInfo> = null;
	var objectTypeWithoutAbstractConstructSignatures(get, set):Type; // (in TypeExtra)

	inline function get_objectTypeWithoutAbstractConstructSignatures():Type {
		final x = (cast this : Type).extra;
		return x == null ? null : x.objectTypeWithoutAbstractConstructSignatures;
	}

	function set_objectTypeWithoutAbstractConstructSignatures(v:Type):Type {
		final t:Type = cast this;
		if (t.extra == null) {
			if (v == null) {
				return v;
			}
			t.newExtra();
		}
		return t.extra.objectTypeWithoutAbstractConstructSignatures = v;
	}

	public function new() {
		super();
	}


	// PORT: slices.Clip of a subslice → a copy (the same Vector when it is all of it); nil[:0] stays nil.
	public function CallSignatures():haxe.ds.Vector<Signature> {
		if (signatures == null) {
			return null;
		}
		return Core.subVector(signatures, 0, callSignatureCount);
	}

	public function ConstructSignatures():haxe.ds.Vector<Signature> {
		if (signatures == null) {
			return null;
		}
		return Core.subVector(signatures, callSignatureCount, signatures.length);
	}

	// PORT: from TypeScript main (microsoft/typescript-go#64915, lazy member resolution): the members of a class or
	// interface type and of its references are a shared MemberLayout (the uninstantiated symbols, by name) plus
	// the type's LazyState; each member is instantiated when first read (getPropertyAt)
	// PORT: perf — inline, one expression (it was inlined by hxmc before `members` became a property)
	inline function getMember(name:std.String):Symbol {
		final m = members;
		final lazy = m != null ? null : getLazyState();
		final index:Null<Int> = lazy == null ? null : lazy.layout.index.get(name);
		return m != null ? m.get(name) : index == null ? null : getPropertyAt(index);
	}

	function getMembers():SymbolTable {
		if (members == null) {
			final properties = getProperties();
			if (Core.len(properties) != 0) {
				members = new SymbolTable();
				for (member in properties) {
					members.set(member.Name, member);
				}
			}
		}
		return members;
	}

	function getPropertyAt(index:Int):Symbol {
		final lazy = getLazyState();
		if (lazy == null) {
			return properties[index];
		}
		if (properties == null) {
			properties = new haxe.ds.Vector<Symbol>(lazy.layout.symbols.length);
		}
		var member = properties[index];
		if (member == null) {
			final symbol = lazy.layout.symbols[index];
			final baseIndex = lazy.layout.baseIndices[index];
			if (baseIndex < 0) {
				member = (cast this : Type).checker.instantiateSymbol(symbol, lazy.mapper);
			} else {
				member = (cast this : Type).checker.getPropertyOfType(lazy.baseTypes[baseIndex], symbol.Name);
			}
			properties[index] = member;
		}
		return member;
	}

	function getProperties():haxe.ds.Vector<Symbol> {
		final lazy = getLazyState();
		if (lazy != null && !lazy.propertiesResolved) {
			for (i in 0...lazy.layout.symbols.length) {
				getPropertyAt(i);
			}
			lazy.propertiesResolved = true;
		}
		return properties;
	}

	function hasProperties():Bool {
		if (Core.len(properties) != 0) {
			return true;
		}
		final lazy = getLazyState();
		if (lazy == null) {
			return false;
		}
		return lazy.layout.symbols.length != 0;
	}

	inline function getLazyState():Null<LazyState> {
		return (cast this : Type).objectFlags & (ObjectFlagsClassOrInterface | ObjectFlagsReference) != 0 ? (cast this : TypeReference).lazy : null;
	}

	public function Properties():haxe.ds.Vector<Symbol> {
		return getProperties();
	}
}

@:allow(ts.checker)
class ObjectType extends StructuredType {
	var target:Type = null; // Target of instantiated type
	// PORT: perf — an anonymous type's field (AnonymousType); a type reference's in the side record
	// (StructuredTypeExtra: t3code-server, 0.8% of the type references have one)
	var mapper(get, set):TypeMapper; // Type mapper for instantiated type

	inline function get_mapper():TypeMapper {
		return Std.isOfType(this, AnonymousType) ? (cast this : AnonymousType).anonMapper : structuredExtraMapper();
	}

	inline function structuredExtraMapper():TypeMapper {
		final x = (cast this : Type).extra;
		return x == null ? null : (cast x : StructuredTypeExtra).mapper;
	}

	function set_mapper(v:TypeMapper):TypeMapper {
		if (Std.isOfType(this, AnonymousType)) {
			return (cast this : AnonymousType).anonMapper = v;
		}
		final t:Type = cast this;
		if (t.extra == null) {
			if (v == null) {
				return v;
			}
			t.newExtra();
		}
		return (cast t.extra : StructuredTypeExtra).mapper = v;
	}
	var instantiations(get, set):ts.core.HashKeyMap<Type> /* key: checker.CacheHashKey */; // Map of type instantiations (in TypeExtra)

	inline function get_instantiations():ts.core.HashKeyMap<Type> {
		final x = (cast this : Type).extra;
		return x == null ? null : x.instantiations;
	}

	function set_instantiations(v:ts.core.HashKeyMap<Type>):ts.core.HashKeyMap<Type> {
		final t:Type = cast this;
		if (t.extra == null) {
			if (v == null) {
				return v;
			}
			t.newExtra();
		}
		return t.extra.instantiations = v;
	}

	public function new() {
		super();
	}

}

// PORT: perf — an object type that is not a type reference (Go's ObjectType with ObjectFlagsAnonymous, mapped, reverse
// mapped, evolving array and instantiation expression types), with the members and mapper as fields (see
// StructuredType.members)
@:allow(ts.checker)
class AnonymousType extends ObjectType {
	var anonMembers:SymbolTable = null;
	var anonMapper:TypeMapper = null;

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class TypeReference extends ObjectType {
	var node(get, set):Node; // TypeReferenceNode | ArrayTypeNode | TupleTypeNode when deferred, else nil (in TypeExtra)
	var resolvedTypeArguments:haxe.ds.Vector<Type> = null; // PORT: perf — a Vector (one exact-size object; null: not resolved yet)
	var lazy:LazyState = null; // Resolved member layout and instantiation state

	inline function get_node():Node {
		final x = (cast this : Type).extra;
		return x == null ? null : x.node;
	}

	function set_node(v:Node):Node {
		final t:Type = cast this;
		if (t.extra == null) {
			if (v == null) {
				return v;
			}
			t.newExtra();
		}
		return t.extra.node = v;
	}

	public function new() {
		super();
	}

}

@:allow(ts.checker)
class LazyState {
	var layout:MemberLayout = null;
	var mapper:TypeMapper = null;
	var baseTypes:haxe.ds.Vector<Type> = null; // PORT: perf — a Vector (one object, exact size: 0.6M on t3code-server)
	var propertiesResolved:Bool = false;

	public function new() {}
}

// PORT: Go's MemberLayout.members (an insertion-ordered SymbolTable with Find and SymbolAt) → the symbols in order
// and their indices by name
@:allow(ts.checker)
class MemberLayout {
	var id:Int = 0; // Unique identifier for the member layout
	var symbols:haxe.ds.Vector<Symbol> = null; // the members (uninstantiated symbols) in order: the layout properties
	var index:StringMap<Int> = null; // their indices by name
	var baseIndices:haxe.ds.Vector<Int> = null; // Indices of base types for each member (-1 if locally declared)

	public function new() {}
}

@:allow(ts.checker)
class InterfaceType extends TypeReference {
	var allTypeParameters:haxe.ds.Vector<Type> = null; // Type parameters (outer + local + thisType)
	var typeParameters:haxe.ds.Vector<Type> = null; // PORT: perf — TypeParameters() made once (Go's subslice of allTypeParameters is no copy either)
	var outerTypeParameterCount:Int = 0; // Count of outer type parameters
	var thisType:Type = null; // The "this" type (nil if none)
	var baseTypesResolved:Bool = false;
	var declaredMembersResolved:Bool = false;
	var resolvedBaseConstructorType:Type = null;
	var resolvedBaseTypes:Array<Type> = null;
	var declaredMembers:SymbolTable = null; // Declared members
	var declaredCallSignatures:haxe.ds.Vector<Signature> = null; // Declared call signatures
	var declaredConstructSignatures:haxe.ds.Vector<Signature> = null; // Declared construct signatures
	var declaredIndexInfos:haxe.ds.Vector<IndexInfo> = null; // Declared index signatures

	public function new() {
		super();
	}


	// PORT: perf — a Vector (a copy of Go's clipped subslice; the same Vector when it is all of TypeParameters())
	public function OuterTypeParameters():haxe.ds.Vector<Type> {
		if (Core.len(allTypeParameters) == 0) {
			return null;
		}
		return outerTypeParameterCount == allTypeParameters.length - 1 ? TypeParameters() : Core.subVector(allTypeParameters, 0, outerTypeParameterCount);
	}

	public function LocalTypeParameters():haxe.ds.Vector<Type> {
		if (Core.len(allTypeParameters) == 0) {
			return null;
		}
		return outerTypeParameterCount == 0 ? TypeParameters() : Core.subVector(allTypeParameters, outerTypeParameterCount, allTypeParameters.length - 1);
	}

	// PORT: perf — one Vector per type (the same one on every call, as Go's subslice shares the storage)
	public function TypeParameters():haxe.ds.Vector<Type> {
		if (typeParameters == null) {
			final n = Core.len(allTypeParameters) - 1;
			if (n < 0) {
				return null;
			}
			final v = new haxe.ds.Vector<Type>(n);
			haxe.ds.Vector.blit(allTypeParameters, 0, v, 0, n);
			typeParameters = v;
		}
		return typeParameters;
	}
}

enum abstract ElementFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:ElementFlags, b:ElementFlags):ElementFlags;
	@:op(A & B) static function and(a:ElementFlags, b:ElementFlags):ElementFlags;
	@:op(~A) static function not(a:ElementFlags):ElementFlags;

	var ElementFlagsNone = 0;
	var ElementFlagsRequired = 1 << 0; // T
	var ElementFlagsOptional = 1 << 1; // T?
	var ElementFlagsRest = 1 << 2; // ...T[]
	var ElementFlagsVariadic = 1 << 3; // ...T
	var ElementFlagsFixed = 3;
	var ElementFlagsVariable = 12;
	var ElementFlagsNonRequired = 14;
	var ElementFlagsNonRest = 11;
}

@:allow(ts.checker)
class TupleElementInfo {
	var flags:ElementFlags = 0;
	var labeledDeclaration:Node = null; // NamedTupleMember | ParameterDeclaration | nil

	public function new() {}

	public function TupleElementFlags():ElementFlags {
		return flags;
	}

	public function LabeledDeclaration():Node {
		return labeledDeclaration;
	}
}

@:allow(ts.checker)
class TupleType extends InterfaceType {
	var elementInfos:Array<TupleElementInfo> = null;
	var minLength:Int = 0; // Number of required or variadic elements
	var fixedLength:Int = 0; // Number of initial required or optional elements
	var combinedFlags:ElementFlags = 0;
	var readonly:Bool = false;

	public function new() {
		super();
	}

	public function FixedLength():Int {
		return fixedLength;
	}

	public function IsReadonly():Bool {
		return readonly;
	}

	public function ElementFlags():Array<ElementFlags> {
		final elementFlags:Array<ElementFlags> = [for (_ in 0...Core.len(elementInfos)) ElementFlagsNone];
		if (elementInfos != null) {
			for (i in 0...elementInfos.length) {
				elementFlags[i] = elementInfos[i].flags;
			}
		}
		return elementFlags;
	}

	public function ElementInfos():Array<TupleElementInfo> {
		return elementInfos;
	}
}

@:allow(ts.checker)
class InstantiationExpressionType extends AnonymousType {
	var node:Node = null;

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class MappedType extends AnonymousType {
	var declaration:MappedTypeNode = null;
	var typeParameter:Type = null;
	var constraintType:Type = null;
	var nameType:Type = null;
	var templateType:Type = null;
	var modifiersType:Type = null;
	var resolvedApparentType:Type = null;
	var containsError:Bool = false;

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class ReverseMappedType extends AnonymousType {
	var source:Type = null;
	var mappedType:Type = null;
	var constraintType:Type = null;

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class EvolvingArrayType extends AnonymousType {
	var elementType:Type = null;
	var finalArrayType:Type = null;

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class UnionOrIntersectionType extends StructuredType {
	var types:haxe.ds.Vector<Type> = null;
	var propertyCache:SymbolTable = null;
	var propertyCacheWithoutFunctionPropertyAugment:SymbolTable = null;
	var resolvedProperties:haxe.ds.Vector<Symbol> = null; // PORT: perf — a Vector (null: not resolved)

	public function new() {
		super();
	}


}

@:allow(ts.checker)
class UnionType extends UnionOrIntersectionType {
	var resolvedReducedType:Type = null;
	var regularType:Type = null;
	var origin:Type = null; // Denormalized union, intersection, or index type in which union originates
	var keyPropertyName:std.String = ""; // Property with unique unit type that exists in every object/intersection in union type
	var constituentMap:IdentityMap<Type, Type> = null; // Constituents keyed by unit type discriminants

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class IntersectionType extends UnionOrIntersectionType {
	var resolvedApparentType:Type = null;
	var uniqueLiteralFilledInstantiation:Type = null; // Instantiation with type parameters mapped to never type

	public function new() {
		super();
	}
}

@:allow(ts.checker)
class TypeParameter extends InstantiableType {
	var constraint:Type = null;
	var target:Type = null;
	var mapper:TypeMapper = null;
	var isThisType:Bool = false;
	var isDistributed:Bool = false;
	var resolvedDefaultType:Type = null;
	var distributedType:Type = null;

	public function new() {
		super();
	}

	public function IsThisType():Bool {
		return isThisType;
	}
}

enum abstract IndexFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:IndexFlags, b:IndexFlags):IndexFlags;
	@:op(A & B) static function and(a:IndexFlags, b:IndexFlags):IndexFlags;
	@:op(~A) static function not(a:IndexFlags):IndexFlags;

	var IndexFlagsNone = 0;
	var IndexFlagsStringsOnly = 1 << 0;
	var IndexFlagsNoIndexSignatures = 1 << 1;
	var IndexFlagsNoReducibleCheck = 1 << 2;
}

@:allow(ts.checker)
class IndexType extends InstantiableType {
	var target:Type = null;
	var indexFlags:IndexFlags = 0;

	public function new() {
		super();
	}

	public override function Target():Type {
		return target;
	}
}

@:allow(ts.checker)
class IndexedAccessType extends InstantiableType {
	var objectType:Type = null;
	var indexType:Type = null;
	var accessFlags:AccessFlags = 0; // Only includes AccessFlags.Persistent

	public function new() {
		super();
	}

	public function ObjectType():Type {
		return objectType;
	}

	public function IndexType():Type {
		return indexType;
	}
}

@:allow(ts.checker)
class TemplateLiteralType extends InstantiableType {
	var texts:Array<std.String> = null; // Always one element longer than types
	var types:Array<Type> = null; // Always at least one element

	public function new() {
		super();
	}

	public function Texts():Array<std.String> {
		return texts;
	}

}

@:allow(ts.checker)
class StringMappingType extends InstantiableType {
	var target:Type = null;

	public function new() {
		super();
	}

	public override function Target():Type {
		return target;
	}
}

@:allow(ts.checker)
class SubstitutionType extends InstantiableType {
	var baseType:Type = null; // Target type
	var constraint:Type = null; // Constraint that target type is known to satisfy

	public function new() {
		super();
	}

	public function BaseType():Type {
		return baseType;
	}

	public function SubstConstraint():Type {
		return constraint;
	}
}

@:allow(ts.checker)
class ConditionalRoot {
	var node:ConditionalTypeNode = null;
	var checkType:Type = null;
	var extendsType:Type = null;
	var isDistributive:Bool = false;
	var inferTypeParameters:Array<Type> = null;
	var outerTypeParameters:Array<Type> = null;
	var instantiations:ts.core.HashKeyMap<Type> /* key: checker.CacheHashKey */ = null;
	var alias:TypeAlias = null;

	public function new() {}
}

@:allow(ts.checker)
class ConditionalType extends InstantiableType {
	var root:ConditionalRoot = null;
	var checkType:Type = null;
	var extendsType:Type = null;
	var resolvedTrueType:Type = null;
	var resolvedFalseType:Type = null;
	var resolvedInferredTrueType:Type = null; // The `trueType` instantiated with the `combinedMapper`, if present
	var resolvedDefaultConstraint:Type = null;
	var resolvedConstraintOfDistributive:Type = null;
	var mapper:TypeMapper = null;
	var combinedMapper:TypeMapper = null;

	public function new() {
		super();
	}

	public function CheckType():Type {
		return checkType;
	}

	public function ExtendsType():Type {
		return extendsType;
	}
}

enum abstract SignatureFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:SignatureFlags, b:SignatureFlags):SignatureFlags;
	@:op(A & B) static function and(a:SignatureFlags, b:SignatureFlags):SignatureFlags;
	@:op(~A) static function not(a:SignatureFlags):SignatureFlags;

	var SignatureFlagsNone = 0;
	// Propagating flags
	var SignatureFlagsHasRestParameter = 1 << 0; // Indicates last parameter is rest parameter
	var SignatureFlagsHasLiteralTypes = 1 << 1; // Indicates signature is specialized
	var SignatureFlagsConstruct = 1 << 2; // Indicates signature is a construct signature
	var SignatureFlagsAbstract = 1 << 3; // Indicates signature comes from an abstract class, abstract construct signature, or abstract constructor type
	// Non-propagating flags
	var SignatureFlagsIsInnerCallChain = 1 << 4; // Indicates signature comes from a CallChain nested in an outer OptionalChain
	var SignatureFlagsIsOuterCallChain = 1 << 5; // Indicates signature comes from a CallChain that is the outermost chain of an optional expression
	var SignatureFlagsIsUntypedSignatureInJSFile = 1 << 6; // Indicates signature is from a js file and has no types
	var SignatureFlagsIsNonInferrable = 1 << 7; // Indicates signature comes from a non-inferrable type
	var SignatureFlagsIsSignatureCandidateForOverloadFailure = 1 << 8;
	// We do not propagate `IsInnerCallChain` or `IsOuterCallChain` to instantiated signatures, as that would result in us
	// attempting to add `| undefined` on each recursive call to `getReturnTypeOfSignature` when
	// instantiating the return type.
	var SignatureFlagsPropagatingFlags = 335;
	var SignatureFlagsCallChainFlags = 48;
}

@:allow(ts.checker)
class SignatureExtra {
	var typeParameters:haxe.ds.Vector<Type> = null;
	var thisParameter:Symbol = null;
	var isolatedSignatureType:Type = null;
	var composite:CompositeSignature = null;

	public function new() {}
}

@:allow(ts.checker)
class Signature implements TypeSystemEntity {
	var id:SignatureId = 0;
	var flags:SignatureFlags = 0;
	var minArgumentCount:Int = 0;
	var resolvedMinArgumentCount:Int = 0;
	var declaration:Node = null;
	var parameters:haxe.ds.Vector<Symbol> = null; // PORT: perf — a Vector (one exact-size object)
	var resolvedReturnType:Type = null;
	var resolvedTypePredicate:TypePredicate = null;
	var target:Signature = null;
	var mapper:TypeMapper = null;
	// PORT: perf — the rarely set fields in a side record (allocated when one is set to a non-nil value): the type
	// parameters and this parameter too (t3code-server: 5% and 4% of the signatures have them)
	var extra:SignatureExtra = null;
	var typeParameters(get, set):haxe.ds.Vector<Type>; // PORT: perf — a Vector (one exact-size object; a mapper holds it as it is)
	var thisParameter(get, set):Symbol;
	var isolatedSignatureType(get, set):Type;
	var composite(get, set):CompositeSignature;

	public function new() {}

	inline function get_typeParameters():haxe.ds.Vector<Type> {
		return extra == null ? null : extra.typeParameters;
	}

	function set_typeParameters(v:haxe.ds.Vector<Type>):haxe.ds.Vector<Type> {
		if (extra == null) {
			if (v == null) {
				return v;
			}
			extra = new SignatureExtra();
		}
		return extra.typeParameters = v;
	}

	inline function get_thisParameter():Symbol {
		return extra == null ? null : extra.thisParameter;
	}

	function set_thisParameter(v:Symbol):Symbol {
		if (extra == null) {
			if (v == null) {
				return v;
			}
			extra = new SignatureExtra();
		}
		return extra.thisParameter = v;
	}

	inline function get_isolatedSignatureType():Type {
		return extra == null ? null : extra.isolatedSignatureType;
	}

	function set_isolatedSignatureType(v:Type):Type {
		if (extra == null) {
			if (v == null) {
				return v;
			}
			extra = new SignatureExtra();
		}
		return extra.isolatedSignatureType = v;
	}

	inline function get_composite():CompositeSignature {
		return extra == null ? null : extra.composite;
	}

	function set_composite(v:CompositeSignature):CompositeSignature {
		if (extra == null) {
			if (v == null) {
				return v;
			}
			extra = new SignatureExtra();
		}
		return extra.composite = v;
	}

	public function Id():SignatureId {
		return id;
	}

	public function Flags():SignatureFlags {
		return flags;
	}

	public function TypeParameters():haxe.ds.Vector<Type> {
		return typeParameters;
	}

	public function Declaration():Node {
		return declaration;
	}

	public function Target():Signature {
		return target;
	}

	public function ThisParameter():Symbol {
		return thisParameter;
	}

	public function Parameters():haxe.ds.Vector<Symbol> {
		return parameters;
	}

	public function HasRestParameter():Bool {
		return (flags & SignatureFlagsHasRestParameter) != 0;
	}

	public function MinArgumentCount():Int {
		return minArgumentCount;
	}
}

@:allow(ts.checker)
class CompositeSignature {
	var isUnion:Bool = false; // True for union, false for intersection
	var signatures:Array<Signature> = null; // Individual signatures

	public function new() {}
}

enum abstract TypePredicateKind(Int) from Int to Int {
	var TypePredicateKindThis = 0;
	var TypePredicateKindIdentifier = 1;
	var TypePredicateKindAssertsThis = 2;
	var TypePredicateKindAssertsIdentifier = 3;
}

@:allow(ts.checker)
class TypePredicate {
	var kind:TypePredicateKind = 0;
	var parameterIndex:Int = 0;
	var parameterName:std.String = "";
	var t:Type = null;

	public function new() {}

	public function Type():Type {
		return t;
	}

	public function Kind():TypePredicateKind {
		return kind;
	}

	public function ParameterIndex():Int {
		return parameterIndex;
	}

	public function ParameterName():std.String {
		return parameterName;
	}
}

@:allow(ts.checker)
class IndexInfo {
	var keyType:Type = null;
	var valueType:Type = null;
	var isReadonly:Bool = false;
	var declaration:Node = null; // IndexSignatureDeclaration
	var indexSymbol:Symbol = null; // Synthetic property symbol for this index signature
	var components:Array<Node> = null; // ElementWithComputedPropertyName

	public function new() {}

	public function KeyType():Type {
		return keyType;
	}

	public function ValueType():Type {
		return valueType;
	}

	public function IsReadonly():Bool {
		return isReadonly;
	}

	public function Declaration():Node {
		return declaration;
	}
}

/**
 * Ternary values are defined such that
 * x & y picks the lesser in the order False < Unknown < Maybe < True, and
 * x | y picks the greater in the order False < Unknown < Maybe < True.
 * Generally, Ternary.Maybe is used as the result of a relation that depends on itself, and
 * Ternary.Unknown is used as the result of a variance check that depends on itself. We make
 * a distinction because we don't want to cache circular variance check results.
 */
enum abstract Ternary(Int) from Int to Int {
	var TernaryFalse = 0;
	var TernaryUnknown = 1;
	var TernaryMaybe = 3;
	var TernaryTrue = -1;
}

typedef TypeComparer = (s:Type, t:Type, reportErrors:Bool) -> Ternary;

class LanguageFeatureMinimumTargetMap {
	public var Exponentiation:ScriptTarget = 0;
	public var AsyncFunctions:ScriptTarget = 0;
	public var ForAwaitOf:ScriptTarget = 0;
	public var AsyncGenerators:ScriptTarget = 0;
	public var AsyncIteration:ScriptTarget = 0;
	public var ObjectSpreadRest:ScriptTarget = 0;
	public var RegularExpressionFlagsDotAll:ScriptTarget = 0;
	public var BindinglessCatch:ScriptTarget = 0;
	public var BigInt:ScriptTarget = 0;
	public var NullishCoalesce:ScriptTarget = 0;
	public var OptionalChaining:ScriptTarget = 0;
	public var LogicalAssignment:ScriptTarget = 0;
	public var TopLevelAwait:ScriptTarget = 0;
	public var ClassFields:ScriptTarget = 0;
	public var PrivateNamesAndClassStaticBlocks:ScriptTarget = 0;
	public var RegularExpressionFlagsHasIndices:ScriptTarget = 0;
	public var ShebangComments:ScriptTarget = 0;
	public var UsingAndAwaitUsing:ScriptTarget = 0;
	public var ClassAndClassElementDecorators:ScriptTarget = 0;
	public var RegularExpressionFlagsUnicodeSets:ScriptTarget = 0;

	public function new() {}
}

// Aliases for types
typedef StringLiteralType = Type;

