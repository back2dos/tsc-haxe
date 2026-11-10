package ts.execute.tsc;

// Port of extendedconfigcache.go.

// extendedConfigCache is a minimal implementation of tsoptions.ExtendedConfigCache.
// It is concurrency-safe, but stores cached entries permanently. This implementation
// should not be used for long-running processes where configuration changes over the
// course of multiple compilations.
// PORT: collections.SyncMap[tspath.Path, ...] → StringMap; the per-entry mutex is dropped
// (single-threaded port).
class ExtendedConfigCache implements ts.tsoptions.Tsconfigparsing.ExtendedConfigCache {
	var m:StringMap<ExtendedConfigCacheEntry_> = new StringMap();

	public function new() {}

	// GetExtendedConfig implements tsoptions.ExtendedConfigCache.
	public function GetExtendedConfig(fileName:RootedFilePath, path:PathKey, resolutionStack:Slice<PathKey>, fs:FS):ExtendedConfigCacheEntry {
		final r = this.loadOrStoreNewLockedEntry(path);
		final entry = r.value, loaded = r.ok;
		if (!loaded) {
			entry.ExtendedConfigCacheEntry = Tsoptions.ParseExtendedConfig(fileName, path, resolutionStack, fs, this);
		}
		return entry.ExtendedConfigCacheEntry;
	}

	// loadOrStoreNewLockedEntry loads an existing entry or creates a new one. The returned entry's mutex is locked.
	function loadOrStoreNewLockedEntry(path:PathKey):ValueOk<ExtendedConfigCacheEntry_> {
		final entry = new ExtendedConfigCacheEntry_();
		final existing = this.m.get(path);
		if (existing != null) {
			return new ValueOk(existing, true);
		}
		this.m.set(path, entry);
		return new ValueOk(entry, false);
	}
}

// Go type `extendedConfigCacheEntry` (unexported; `_` because tsoptions exports the same name).
// PORT: embedded *tsoptions.ExtendedConfigCacheEntry → composition field; `mu` dropped.
class ExtendedConfigCacheEntry_ {
	public var ExtendedConfigCacheEntry:ExtendedConfigCacheEntry = null;

	public function new() {}
}
