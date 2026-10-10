package go;

// Shim for Go package context. Single-threaded port: no cancellation, Err() is always null.
class Context {
	static final background = new Context(null, null, null);

	final parent:Null<Context>;
	final key:Any;
	final value:Any;

	function new(parent, key, value) {
		this.parent = parent;
		this.key = key;
		this.value = value;
	}

	public static function Background():Context return background;

	public static function TODO():Context return background;

	public static function WithValue(parent:Context, key:Any, value:Any):Context {
		return new Context(parent, key, value);
	}

	// Go compares keys with ==; keys are small ints or strings in upstream.
	public function Value(key:Any):Any {
		var c = this;
		while (c != null && c != background) {
			if (c.key == key)
				return c.value;
			c = c.parent;
		}
		return null;
	}

	public function Err():Null<go.Errors.Error> return null;
}
