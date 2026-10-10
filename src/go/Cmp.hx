package go;

// Shims for Go package cmp.
class Cmp {
	// cmp.Compare for signed integers.
	public static inline function Compare(x:Int, y:Int):Int {
		return x < y ? -1 : (x > y ? 1 : 0);
	}
}
