package go;

// Shim for Go's builtin `error` interface and package errors.
interface Error {
	function Error():String;
}

// An error with Go's `Unwrap() error` method.
interface Wrapper {
	function Unwrap():Null<Error>;
}

class Errors {
	// errors.New: every call returns a distinct error value.
	public static function New(text:String):Error {
		return new ErrorString(text);
	}

	// errors.Is: err == target, or one of the errors in its Unwrap chain is.
	// PORT: only single-error Unwrap() (interface Wrapper); Go's Is(error) bool hook and
	// Unwrap() []error are not implemented.
	public static function Is(err:Null<Error>, target:Null<Error>):Bool {
		if (err == null || target == null) {
			return err == target;
		}
		while (true) {
			if (err == target) {
				return true;
			}
			if (!Std.isOfType(err, Wrapper)) {
				return false;
			}
			err = (cast err : Wrapper).Unwrap();
			if (err == null) {
				return false;
			}
		}
	}
}

private class ErrorString implements Error {
	final s:String;

	public function new(s:String) {
		this.s = s;
	}

	public function Error():String {
		return s;
	}

	public function toString():String {
		return s;
	}
}
