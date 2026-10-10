package ts.collections;

// Port of ordered_set.go.
// OrderedSet an insertion ordered set.
// Go `OrderedMap[T, struct{}]` → OrderedMap<T, Bool> (value always true, zero false).
// A Go zero-value `OrderedSet[T]` is `new OrderedSet<T>()`. Go methods dereference the
// receiver, so (like Go) none of them accept a null receiver.
class OrderedSet<T> {
	@:allow(ts.collections)
	var m:OrderedMap<T, Bool> = new OrderedMap<T, Bool>(false);

	public function new() {}

	// Add adds a value to the set.
	public function Add(value:T):Void {
		this.m.Set(value, true);
	}

	// Has returns true if the set contains the value.
	public function Has(value:T):Bool {
		return this.m.Has(value);
	}

	// Delete removes a value from the set.
	public function Delete(value:T):Bool {
		final r = this.m.Delete(value);
		return r.ok;
	}

	// Values returns an iterator over the values in the set.
	public inline function Values():OrderedMapKeys<T, Bool> {
		return this.m.Keys();
	}

	// Clear removes all elements from the set.
	// The space allocated for the set will be reused.
	public function Clear():Void {
		this.m.Clear();
	}

	// Size returns the number of elements in the set.
	public function Size():Int {
		return this.m.Size();
	}

	// Clone returns a shallow copy of the set.
	public function Clone():OrderedSet<T> {
		final s = new OrderedSet<T>();
		s.m = this.m.clone();
		return s;
	}
}
