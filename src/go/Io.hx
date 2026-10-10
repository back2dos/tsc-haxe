package go;

import go.Errors.Error;
import go.Tuple.ValueError;

// Shim for Go package io (only what the fs shims need).
class Io {
	// io.EOF
	public static final EOF:Error = Errors.New("EOF");
}

// io.Writer. PORT: Go `Write(p []byte) (n int, err error)` → Write(p:String) returning (n, err);
// Haxe strings are UTF-16, so p is text and n counts what the writer counts (implementations decide).
interface Writer {
	function Write(p:String):ValueError<Int>;
}
