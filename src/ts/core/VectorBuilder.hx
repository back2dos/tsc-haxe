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

	// The list so far as an exact-size Vector (the builder can be used on).
	public inline function build():haxe.ds.Vector<T> {
		return haxe.ds.Vector.fromArrayCopy(this);
	}

	// A finished Array (from a function that builds one) as a Vector: the same copy as build(). Null (Go nil) and
	// empty give the empty vector.
	public static inline function freeze<T>(a:Null<Array<T>>):haxe.ds.Vector<T> {
		return a == null ? new haxe.ds.Vector<T>(0) : haxe.ds.Vector.fromArrayCopy(a);
	}

	// As freeze, but null stays null (where Go tells a nil slice from an empty one).
	public static inline function freezeOrNull<T>(a:Null<Array<T>>):haxe.ds.Vector<T> {
		return a == null ? null : haxe.ds.Vector.fromArrayCopy(a);
	}
}
