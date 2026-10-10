package ts.core;

// Port of context.go (types; the funcs are in Core.hx).
// PORT: module named Context_ because `Context` is the go.Context shim imported in import.hx.

// PORT: Go `type key int` context keys are compared by type and value; go.Context compares
// keys with ==, so each key is a distinct object (an Int 0 from another package must not match).
class Key {
	final id:Int;

	public function new(id:Int) {
		this.id = id;
	}
}

enum abstract CheckerLifetime(Int) from Int to Int {
	// PORT: Go integer ordering of the enum values.
	@:op(A < B) static function lt(a:CheckerLifetime, b:CheckerLifetime):Bool;
	@:op(A <= B) static function lte(a:CheckerLifetime, b:CheckerLifetime):Bool;
	@:op(A > B) static function gt(a:CheckerLifetime, b:CheckerLifetime):Bool;
	@:op(A >= B) static function gte(a:CheckerLifetime, b:CheckerLifetime):Bool;

	var CheckerLifetimeTemporary = 0;
	var CheckerLifetimeDiagnostics = 1;
	var CheckerLifetimeAPI = 2;
}
