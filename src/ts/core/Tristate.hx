package ts.core;

// Port of tristate.go and tristate_stringer_generated.go (BoolToTristate is in Core.hx).

// Tristate
enum abstract Tristate(Int) from Int to Int {
	// PORT: Go integer ordering of the enum values.
	@:op(A < B) static function lt(a:Tristate, b:Tristate):Bool;
	@:op(A <= B) static function lte(a:Tristate, b:Tristate):Bool;
	@:op(A > B) static function gt(a:Tristate, b:Tristate):Bool;
	@:op(A >= B) static function gte(a:Tristate, b:Tristate):Bool;

	var TSUnknown = 0;
	var TSFalse = 1;
	var TSTrue = 2;

	public inline function IsTrue():Bool {
		return (cast this : Tristate) == TSTrue;
	}

	public inline function IsTrueOrUnknown():Bool {
		return (cast this : Tristate) == TSTrue || (cast this : Tristate) == TSUnknown;
	}

	public inline function IsFalse():Bool {
		return (cast this : Tristate) == TSFalse;
	}

	public inline function IsFalseOrUnknown():Bool {
		return (cast this : Tristate) == TSFalse || (cast this : Tristate) == TSUnknown;
	}

	public inline function IsUnknown():Bool {
		return (cast this : Tristate) == TSUnknown;
	}

	public inline function DefaultIfUnknown(value:Tristate):Tristate {
		if ((cast this : Tristate) == TSUnknown) {
			return value;
		}
		return (cast this : Tristate);
	}

	// PORT: Go `(t *Tristate) UnmarshalJSON(data []byte) error` sets *t and always returns nil.
	// An abstract value cannot be assigned through `this`: returns the new value instead
	// (`t = Tristate.UnmarshalJSON(data)`). `[]byte` → String.
	public static function UnmarshalJSON(data:String):Tristate {
		switch (data) {
			case "true":
				return TSTrue;
			case "false":
				return TSFalse;
			default:
				return TSUnknown;
		}
	}

	// PORT: ([]byte, error) → String; the Go error is always nil.
	public function MarshalJSON():String {
		switch ((cast this : Tristate)) {
			case TSTrue:
				return "true";
			case TSFalse:
				return "false";
			default:
				return "null";
		}
	}

	// --- tristate_stringer_generated.go ---

	public function String():String {
		final i:Int = this;
		switch (i) {
			case 0:
				return "TSUnknown";
			case 1:
				return "TSFalse";
			case 2:
				return "TSTrue";
			default:
				return "Tristate(" + Std.string(i) + ")";
		}
	}
}
