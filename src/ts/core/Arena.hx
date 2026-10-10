package ts.core;

// Port of arena.go (nextArenaSize is in Core.hx).

// Arena allocator
// PORT: PORTING.md §4a — Haxe has no pointers into a backing array, so the arena only knows
// how to make the Go zero value of T: `new Arena<X>(() -> new X())`; for a pointer-typed
// T (`Arena[*X]`) the factory returns null. New() returns factory(); NewSlice(n) returns an
// array of n new elements. The Go capacity bookkeeping has no observable effect and is omitted.
class Arena<T> {
	// PORT: factory for the Go zero value of T.
	final factory:() -> T;

	public function new(factory:() -> T) {
		this.factory = factory;
	}

	// Allocate a single element in the arena and return a pointer to the element. If the arena is at capacity,
	// a new arena of the next size up is allocated.
	public inline function New():T {
		return factory();
	}

	// Allocate a slice of the given size in the arena. If the requested size is beyond the capacity of the arena
	// and an arena of the next size up still wouldn't fit the slice, make a separate memory allocation for the slice.
	// Otherwise, grow the arena if necessary and allocate a slice out of it. The length and capacity of the resulting
	// slice are equal to the given size.
	public function NewSlice(size:Int):Null<Array<T>> {
		if (size == 0) {
			return null;
		}
		final slice = new Array<T>();
		for (i in 0...size) {
			slice.push(factory());
		}
		return slice;
	}

	public function NewSlice1(t:T):Array<T> {
		// PORT: NewSlice(1) followed by slice[0] = t; the zero element would be overwritten at once.
		return [t];
	}

	public function Clone(t:Null<Array<T>>):Null<Array<T>> {
		if (t == null || t.length == 0) {
			return null;
		}
		return t.copy();
	}
}
