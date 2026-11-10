package go;

// Go `[]T` held as a haxe.ds.Vector (the port's fixed-size lists: one object, no header, a shared empty
// vector): like go.Slice, a nil Vec reads as empty for `length`, `for (x in v)` and `for (i => x in v)`,
// with no wrapper object and no allocation. Unlike Slice it converts to and from haxe.ds.Vector
// implicitly (the Vector APIs of the port and of the standard library check for null themselves or are
// given the vectors they build).
@:forward
@:forward.new
abstract Vec<T>(Null<haxe.ds.Vector<T>>) from haxe.ds.Vector<T> to haxe.ds.Vector<T> {
	public var length(get, never):Int;

	inline function get_length():Int {
		return this == null ? 0 : this.length;
	}

	public inline function isNil():Bool {
		return this == null;
	}

	@:arrayAccess inline function get(i:Int):T {
		return this[i];
	}

	@:arrayAccess inline function set(i:Int, v:T):T {
		return this[i] = v;
	}

	public inline function iterator():VecIterator<T> {
		return new VecIterator(nonNil());
	}

	public inline function keyValueIterator():VecKeyValueIterator<T> {
		return new VecKeyValueIterator(nonNil());
	}

	// (as Slice.nonNil: hxmc/js loop over a shared empty vector when nil, no null test in the loop)
	inline function nonNil():VecData<T> {
		#if (target.name == "hxmc" || js)
		return this != null ? this : cast @:privateAccess VecIterator.EMPTY;
		#else
		return this;
		#end
	}
}

private typedef VecData<T> = #if (target.name == "hxmc" || js) haxe.ds.Vector<T> #else Null<haxe.ds.Vector<T>> #end;

class VecIterator<T> {
	static final EMPTY:haxe.ds.Vector<Dynamic> = new haxe.ds.Vector<Dynamic>(0);

	final a:VecData<T>;
	var i:Int;

	public inline function new(a:VecData<T>) {
		this.a = a;
		i = 0;
	}

	public inline function hasNext():Bool {
		#if (target.name == "hxmc" || js)
		return i < a.length;
		#else
		return a != null && i < a.length;
		#end
	}

	public inline function next():T {
		return a[i++];
	}
}

class VecKeyValueIterator<T> {
	final a:VecData<T>;
	var i:Int;

	public inline function new(a:VecData<T>) {
		this.a = a;
		i = 0;
	}

	public inline function hasNext():Bool {
		#if (target.name == "hxmc" || js)
		return i < a.length;
		#else
		return a != null && i < a.length;
		#end
	}

	public inline function next():{key:Int, value:T} {
		return {value: a[i], key: i++};
	}
}
