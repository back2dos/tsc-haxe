package ts.module;

// Port of cache.go (types and methods; newCaches and getRedirectConfigName are in Module.hx).

// PORT: Go `map[ModeAwareCacheKey]T`; struct keys are encoded as Strings with
// ModeAwareCacheKey.Key() (decode with ModeAwareCacheKey.ModeAwareCacheKeyFromKey).
typedef ModeAwareCache<T> = haxe.ds.StringMap<T>;

// PORT: struct map key → String (PORTING.md §4a); see key().
class ModuleResolutionCacheKey {
	public final containingDirectory:String;
	public final moduleName:String;
	public final resolutionMode:ResolutionMode;
	public final redirectConfigName:String;

	public function new(containingDirectory:String, moduleName:String, resolutionMode:ResolutionMode, redirectConfigName:String) {
		this.containingDirectory = containingDirectory;
		this.moduleName = moduleName;
		this.resolutionMode = resolutionMode;
		this.redirectConfigName = redirectConfigName;
	}

	public function key():String {
		return containingDirectory + "\x00" + moduleName + "\x00" + (resolutionMode : Int) + "\x00" + redirectConfigName;
	}

	// the key in the map of the containing directory (ModuleResolutionCache): the module name when there is no mode or
	// redirect (such a name never starts with U+0000), else all three after a U+0000
	public function keyInDirectory():String {
		return (resolutionMode : Int) == 0 && redirectConfigName == "" && !StringTools.startsWith(moduleName, "\x00") ? moduleName : "\x00" + moduleName
			+ "\x00" + (resolutionMode : Int) + "\x00" + redirectConfigName;
	}
}

// PORT: perf — a map per containing directory: no key string with the directory per lookup (key(): t3code-server
// made 38 MB of these strings while loading the program, one or two per import)
class ModuleResolutionCache {
	final cache:SyncMap<String, SyncMap<String, ResolvedModule>> = new SyncMap<String, SyncMap<String, ResolvedModule>>();

	public function new() {}

	// PORT: (*ResolvedModule, bool) → ValueOk.
	public function Get(key:ModuleResolutionCacheKey):ValueOk<ResolvedModule> {
		final d = this.cache.Load(key.containingDirectory);
		return d.ok ? d.value.Load(key.keyInDirectory()) : new ValueOk<ResolvedModule>(null, false);
	}

	public function Set(key:ModuleResolutionCacheKey, value:ResolvedModule):Void {
		var d = this.cache.Load(key.containingDirectory);
		if (!d.ok) {
			d = this.cache.LoadOrStore(key.containingDirectory, new SyncMap<String, ResolvedModule>());
		}
		d.value.LoadOrStore(key.keyInDirectory(), value);
	}
}

// PORT: struct map key → String (PORTING.md §4a); see key().
class TypeRefDirectiveResolutionCacheKey {
	public final containingDirectory:String;
	public final typeReferenceName:String;
	public final resolutionMode:ResolutionMode;
	public final redirectConfigName:String;
	public final fromInferredTypesContainingFile:Bool;

	public function new(containingDirectory:String, typeReferenceName:String, resolutionMode:ResolutionMode, redirectConfigName:String,
			fromInferredTypesContainingFile:Bool) {
		this.containingDirectory = containingDirectory;
		this.typeReferenceName = typeReferenceName;
		this.resolutionMode = resolutionMode;
		this.redirectConfigName = redirectConfigName;
		this.fromInferredTypesContainingFile = fromInferredTypesContainingFile;
	}

	public function key():String {
		return containingDirectory + "\x00" + typeReferenceName + "\x00" + (resolutionMode : Int) + "\x00" + redirectConfigName + "\x00"
			+ (fromInferredTypesContainingFile ? "1" : "0");
	}
}

class TypeRefDirectiveResolutionCache {
	final cache:SyncMap<String, ResolvedTypeReferenceDirective> = new SyncMap<String, ResolvedTypeReferenceDirective>();

	public function new() {}

	// PORT: (*ResolvedTypeReferenceDirective, bool) → ValueOk.
	public function Get(key:TypeRefDirectiveResolutionCacheKey):ValueOk<ResolvedTypeReferenceDirective> {
		return this.cache.Load(key.key());
	}

	public function Set(key:TypeRefDirectiveResolutionCacheKey, value:ResolvedTypeReferenceDirective):Void {
		this.cache.Store(key.key(), value);
	}
}

// Go unexported type `caches`, embedded in Resolver.
class Caches {
	public var packageJsonInfoCache:Null<InfoCache> = null;

	public var moduleResolutionCache:ModuleResolutionCache = new ModuleResolutionCache();
	public var typeRefDirectiveResolutionCache:TypeRefDirectiveResolutionCache = new TypeRefDirectiveResolutionCache();

	// Cached representation for `core.CompilerOptions.paths`.
	// Doesn't handle other path patterns like in `typesVersions`.
	// PORT: sync.Once → flag.
	public var parsedPatternsForPathsOnce:Bool = false;
	public var parsedPatternsForPaths:Null<ParsedPatterns> = null;

	public function new(?packageJsonInfoCache:InfoCache) {
		this.packageJsonInfoCache = packageJsonInfoCache;
	}
}
