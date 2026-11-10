package ts.core;

// PORT: perf — builds a list that ends as a haxe.ds.Vector (an exact-size, immutable list: one object; the
// empty one shared on hxmc). Every "push-build a list, then freeze it" goes through here, so the scratch
// storage can later be pooled in one place. Now: an Array underneath, build() copies it exactly.
abstract VectorBuilder<T>(Array<T>) {
	public inline function new() {
		this = [];
	}

	public var length(get, never):Int;

	inline function get_length():Int {
		return this.length;
	}

	public inline function push(x:T):Void {
		this.push(x);
	}

	@:op([]) public inline function get(i:Int):T {
		return this[i];
	}

	@:op([]) public inline function set(i:Int, x:T):T {
		return this[i] = x;
	}

	// go.Slices.SortFunc of the elements so far
	public inline function sortFunc(cmp:(T, T) -> Int):Void {
		go.Slices.SortFunc(this, cmp);
	}

	// head's elements, then this builder's, as one exact-size Vector
	public inline function buildAfter(head:VectorBuilder<T>):Vec<T> {
		final n1 = head.length, n2 = this.length;
		final v = new haxe.ds.Vector<T>(n1 + n2);
		for (i in 0...n1)
			v[i] = head[i];
		for (i in 0...n2)
			v[n1 + i] = this[i];
		return v;
	}

	// The list so far as an exact-size Vector (the builder can be used on).
	public inline function build():Vec<T> {
		return haxe.ds.Vector.fromArrayCopy(this);
	}

	// A finished Array (from a function that builds one) as a Vector: the same copy as build(). Null (Go nil) and
	// empty give the empty vector.
	public static inline function freeze<T>(a:Slice<T>):Vec<T> {
		return a == null ? new haxe.ds.Vector<T>(0) : haxe.ds.Vector.fromArrayCopy(a.nilable());
	}

	// As freeze, but null stays null (where Go tells a nil slice from an empty one).
	public static inline function freezeOrNull<T>(a:Slice<T>):Vec<T> {
		return a == null ? null : haxe.ds.Vector.fromArrayCopy(a.nilable());
	}
}
