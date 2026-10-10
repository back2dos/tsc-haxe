package ts.collections;

// Port of syncset.go.
// PORT: single-threaded port (PORTING.md §4). Go `struct{}` values → Bool (always true).
// A Go zero-value `SyncSet[T]` is `new SyncSet<T>()`.
class SyncSet<T> {
	var m:SyncMap<T, Bool> = new SyncMap<T, Bool>(false);

	public function new() {}

	public function Has(key:T):Bool {
		final r = m.Load(key);
		return r.ok;
	}

	public function Add(key:T):Void {
		this.AddIfAbsent(key);
	}

	// AddIfAbsent adds the key to the set if it is not already present
	// using LoadOrStore. It returns true if the key was not already present
	// (opposite of the return value of LoadOrStore).
	public function AddIfAbsent(key:T):Bool {
		final r = m.LoadOrStore(key, true);
		return !r.ok;
	}

	public function Delete(key:T):Void {
		m.Delete(key);
	}

	public function Range(fn:(key:T) -> Bool):Void {
		m.Range((key:T, value:Bool) -> {
			return fn(key);
		});
	}

	// Size returns the approximate number of items in the map.
	// Note that this is not a precise count, as the map may be modified
	// concurrently while this method is running.
	public function Size():Int {
		var count = 0;
		m.Range((_, _) -> {
			count++;
			return true;
		});
		return count;
	}

	public function IsEmpty():Bool {
		var empty = true;
		m.Range((_, _) -> {
			empty = false;
			return false;
		});

		return empty;
	}

	public function ToSlice():Array<T> {
		final arr:Array<T> = [];
		m.Range((key:T, value:Bool) -> {
			arr.push(key);
			return true;
		});
		return arr;
	}

	public function Keys():Iterator<T> {
		return m.Keys();
	}
}
