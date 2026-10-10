package ts.ast;

// Port of functionflags.go (GetFunctionFlags is in Ast.hx).

enum abstract FunctionFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:FunctionFlags, b:FunctionFlags):FunctionFlags;
	@:op(A & B) static function and(a:FunctionFlags, b:FunctionFlags):FunctionFlags;
	@:op(A ^ B) static function xor(a:FunctionFlags, b:FunctionFlags):FunctionFlags;
	@:op(~A) static function not(a:FunctionFlags):FunctionFlags;

	var FunctionFlagsNormal = 0;
	var FunctionFlagsGenerator = 1 << 0;
	var FunctionFlagsAsync = 1 << 1;
	var FunctionFlagsInvalid = 1 << 2;
	var FunctionFlagsAsyncGenerator = FunctionFlagsAsync | FunctionFlagsGenerator;
}
