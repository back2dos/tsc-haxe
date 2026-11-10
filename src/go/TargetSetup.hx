package go;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;

// Per-target fixes for the JVM, C# and Python targets (tools/haxe: `--macro go.TargetSetup.apply()`); on
// every other target (js, cpp, hxmc) nothing. Go's nil-slice semantics are in the types (go.Slice, go.Vec),
// not in a macro.
class TargetSetup {
	public static function apply():Void {
		final jvm = Context.defined("jvm"), cs = Context.defined("cs");
		if (jvm || cs)
			for (pack in ["ts", "go"])
				Compiler.addGlobalMetadata(pack, "@:build(go.TargetSetup.build())", true, true, false);
		if (cs)
			Context.onGenerate(go.CsTarget.names); // PORT: cs (see go.CsTarget)
		if (Context.defined("python"))
			go.PyTarget.apply(); // PORT: python — std-py/ class path, output rewrite
	}

	public static function build():Array<Field> {
		final fields = Context.getBuildFields();
		final jvm = Context.defined("jvm"), cs = Context.defined("cs");
		if (cs)
			go.CsTarget.constructorArity(fields); // PORT: cs (see go.CsTarget)
		for (f in fields) {
			// PORT: jvm — large literal tables in static initializers (see go.JvmStatics).
			if (jvm && f.access != null && f.access.contains(AStatic)) {
				switch f.kind {
					case FVar(t, e) if (e != null):
						f.kind = FVar(t, go.JvmStatics.rewriteStatic(e));
					case FProp(g, s, t, e) if (e != null):
						f.kind = FProp(g, s, t, go.JvmStatics.rewriteStatic(e));
					case _:
				}
			}
			// PORT: cs — every rest spread `f(...xs)` passes an array of the exact length (see go.CsTarget.exactRest)
			if (cs)
				switch f.kind {
					case FFun(fn) if (fn.expr != null):
						fn.expr = csSpreads(fn.expr);
					case FVar(t, e) if (e != null):
						f.kind = FVar(t, csSpreads(e));
					case FProp(g, s, t, e) if (e != null):
						f.kind = FProp(g, s, t, csSpreads(e));
					case _:
				}
		}
		return fields;
	}

	static function csSpreads(e:Expr):Expr {
		return switch e.expr {
			case EConst(CString(str, SingleQuotes)) if (str.indexOf("$") >= 0):
				csSpreads(haxe.macro.MacroStringTools.formatString(str, e.pos));
			case EUnop(OpSpread, false, inner):
				final inner2 = csSpreads(inner);
				macro @:pos(e.pos) ...go.CsTarget.exactRest($inner2);
			case _:
				haxe.macro.ExprTools.map(e, csSpreads);
		}
	}
}
#end
