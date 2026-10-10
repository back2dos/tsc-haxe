package ts.execute.incremental;

// Port of referencemap.go.
@:allow(ts.execute.incremental)
class ReferenceMap {
	var references:SyncMap<Path, Set<Path>> = new SyncMap<Path, Set<Path>>();
	var referencedBy:StringMap<Set<Path>> = null;
	var referenceByDone:Bool = false; // PORT: sync.Once → flag

	public function new() {}

	function storeReferences(path:Path, refs:Set<Path>):Void {
		this.references.Store(path, refs);
	}

	// PORT: (*Set, bool) → ValueOk
	function getReferences(path:Path):ValueOk<Set<Path>> {
		return this.references.Load(path);
	}

	function getPathsWithReferences():Array<Path> {
		return Slices.Collect(this.references.Keys());
	}

	// PORT: iter.Seq[tspath.Path] → Iterator
	function getReferencedBy(path:Path):Iterator<Path> {
		if (!this.referenceByDone) {
			this.referenceByDone = true;
			this.referencedBy = new StringMap();
			this.references.Range(function(key:Path, value:Set<Path>):Bool {
				for (ref in value.Keys().keys()) {
					var set = this.referencedBy.get(ref);
					if (set == null) {
						set = new Set<Path>();
						this.referencedBy.set(ref, set);
					}
					set.Add(key);
				}
				return true;
			});
		}
		final refs = this.referencedBy.get(path);
		if (refs != null) {
			return refs.Keys().keys();
		}
		return [].iterator();
	}
}
