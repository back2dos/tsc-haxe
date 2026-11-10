package go;

// Go `[]T`: an Array that may be nil. Go's `len(s)`, `range s` and `f(s...)` treat a nil slice as
// empty; a Haxe Array that is null throws on all three. A declaration that Go may leave nil (the
// zero value of a field, `return nil`, a struct literal without the field) is a Slice<T>; its
// `length`, `for (x in s)`, `for (i => x in s)` and `toArray()` read nil as empty, with no wrapper
// object (an abstract over the array itself) and no allocation in loops.
//
// Every other array operation is the Array's own (@:forward): indexing, push, slice, ... of nil fail
// as Go's do (index out of range, a nil append must assign: `s = s.append(x)`). An Array converts to
// a Slice implicitly; the other way is explicit: `toArray()` (nil: a new empty array) or `nilable()`
// (the array or null, for the APIs that take Null<Array<T>> and check for null themselves).
// `s == null` / `s.isNil()` is Go's `s == nil`.
@:forward
@:forward.new
abstract Slice<T>(Null<Array<T>>) from Array<T> {
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

	public inline function iterator():SliceIterator<T> {
		return new SliceIterator(nonNil());
	}

	public inline function keyValueIterator():SliceKeyValueIterator<T> {
		return new SliceKeyValueIterator(nonNil());
	}

	// The array, nil as a shared empty one that nobody writes to (the iterators only read its length).
	// hxmc: the loop then has no null test in its condition, so it gets the same fast form as a
	// loop over an Array (measured: a null test in the condition doubles a short loop's time).
	// Other targets keep the null test (their arrays of Int/Float are not interchangeable with Array<Dynamic>).
	inline function nonNil():SliceArray<T> {
		#if (target.name == "hxmc" || js)
		return this != null ? this : cast @:privateAccess SliceIterator.EMPTY;
		#else
		return this;
		#end
	}

	// Go `s = append(s, x)`: nil becomes a new array.
	public inline function append(x:T):Slice<T> {
		if (this == null)
			return [x];
		this.push(x);
		return this;
	}

	// The elements as an Array: nil gives a new empty array (never a shared one: the caller may push).
	public inline function toArray():Array<T> {
		return this == null ? [] : this;
	}

	// The array or null (for Null<Array<T>> APIs that treat null themselves).
	public inline function nilable():Null<Array<T>> {
		return this;
	}
}

private typedef SliceArray<T> = #if (target.name == "hxmc" || js) Array<T> #else Null<Array<T>> #end;

// Like haxe.iterators.ArrayIterator, the length read on every step (an append in the body is seen).
class SliceIterator<T> {
	static final EMPTY:Array<Dynamic> = [];

	final a:SliceArray<T>;
	var i:Int;

	public inline function new(a:SliceArray<T>) {
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

class SliceKeyValueIterator<T> {
	final a:SliceArray<T>;
	var i:Int;

	public inline function new(a:SliceArray<T>) {
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
