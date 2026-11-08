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
	// errors.AsType[T]: the first error in err's Unwrap chain that is a T, or null.
	// PORT: only single-error Unwrap() (interface Wrapper).
	public static function AsType<T>(err:Null<Error>, cls:Class<T>):Null<T> {
		while (err != null) {
			if (Std.isOfType(err, cls))
				return cast err;
			if (!Std.isOfType(err, Wrapper))
				return null;
			err = (cast err : Wrapper).Unwrap();
		}
		return null;
	}

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
