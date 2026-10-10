package go;

import go.Errors.Error;

// Shared result types for Go multiple return values (PORTING.md §3).
// Not @:generic: a @:generic class cannot be used with an unresolved type parameter
// (generic functions), and @:generic generic functions hang Haxe 5.0.0-preview.1.

// (T, bool)
final class ValueOk<T> {
	public final value:T;
	public final ok:Bool;

	public inline function new(value:T, ok:Bool) {
		this.value = value;
		this.ok = ok;
	}
}

// (T, error)
final class ValueError<T> {
	public final value:T;
	public final err:Null<Error>;

	public inline function new(value:T, err:Null<Error>) {
		this.value = value;
		this.err = err;
	}
}

// (A, B)
final class Pair<A, B> {
	public final a:A;
	public final b:B;

	public inline function new(a:A, b:B) {
		this.a = a;
		this.b = b;
	}
}

// (A, B, C)
final class Triple<A, B, C> {
	public final a:A;
	public final b:B;
	public final c:C;

	public inline function new(a:A, b:B, c:C) {
		this.a = a;
		this.b = b;
		this.c = c;
	}
}
