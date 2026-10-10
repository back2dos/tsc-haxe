package ts.debug;

import go.Fmt;

// Port of internal/debug.
// PORT: Go `interface{ KindString() string }` / fmt.Stringer → structural checks via Reflect.
class Debug {
	public static function Fail(reason:String):Void {
		if (reason.length == 0)
			reason = "Debug failure.";
		else
			reason = "Debug failure. " + reason;
		throw reason;
	}

	public static function FailBadSyntaxKind(node:{function KindString():String;}, ...message:Any):Void {
		var msg:String;
		if (message.length == 0)
			msg = "Unexpected node.";
		else
			msg = Fmt.Sprint(message.toArray());
		Fail('$msg\nNode ${node.KindString()} was unexpected.');
	}

	public static function AssertNever(member:Any, ...message:Any):Void {
		var msg:String;
		if (message.length == 0)
			msg = "Illegal value:";
		else
			msg = Fmt.Sprint(message.toArray());
		var detail:String;
		final kindString = member == null ? null : Reflect.field(member, "KindString");
		final stringer = member == null ? null : Reflect.field(member, "String");
		if (Reflect.isFunction(kindString))
			detail = Reflect.callMethod(member, kindString, []);
		else if (Reflect.isFunction(stringer))
			detail = Reflect.callMethod(member, stringer, []);
		else
			detail = Fmt.Sprintv(member);
		Fail('$msg $detail');
	}

	public static inline function Assert(value:Bool, ...message:Any):Void {
		if (!value)
			assertSlow(message.toArray());
	}

	static function assertSlow(message:Array<Any>):Void {
		var msg:String;
		if (message.length > 0)
			msg = "False expression: " + Fmt.Sprint(message);
		else
			msg = "False expression.";
		Fail(msg);
	}
}
