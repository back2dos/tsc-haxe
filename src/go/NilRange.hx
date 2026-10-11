package go;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;

// Go `for _, x := range s` over a nil slice or map runs zero times; a Haxe `for (x in s)` over
// null crashes. Ported code has thousands of loops over values that Go may leave nil (e.g. every
// empty parser NodeList has nil `Nodes`). This build macro, applied to every type in packages `ts`
// and `go` by tools/haxe, rewrites `for (x in e)` and `for (k => v in e)` into
// `{ final tmp = e; if (tmp != null) for (x in tmp) ... }`. Integer ranges (`a...b`) are unchanged.
// It also makes a rest spread `f(...xs)` of a null array pass zero arguments, like Go `f(xs...)`,
// and a `.length` read of null give 0, like Go `len(nil)`. On cpp the loops go through go.ForIn
// (PORT: perf: map loops over arrays instead of hxcpp's by-name iterator calls); on JVM, C# and
// Python too (map loops over snapshots, see go.ForIn).
class NilRange {
	public static function apply():Void {
		for (pack in ["ts", "go"])
			Compiler.addGlobalMetadata(pack, "@:build(go.NilRange.build())", true, true, false);
		if (Context.defined("cs"))
			Context.onGenerate(go.CsTarget.names); // PORT: cs (see go.CsTarget)
	}

	public static function build():Array<Field> {
		final fields = Context.getBuildFields();
		final jvm = Context.defined("jvm");
		if (Context.defined("cs"))
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
			switch f.kind {
				case FFun(fn) if (fn.expr != null):
					fn.expr = rewrite(fn.expr);
				case FVar(t, e) if (e != null):
					f.kind = FVar(t, rewrite(e));
				case FProp(g, s, t, e) if (e != null):
					f.kind = FProp(g, s, t, rewrite(e));
				case _:
			}
		}
		return fields;
	}

	static var counter = 0;

	static function rewrite(e:Expr):Expr {
		return switch e.expr {
			// Array comprehension `[for (x in e) body]`: an expression, so it becomes
			// `{ final tmp = e; tmp == null ? [] : [for (x in tmp) body]; }`. Loops inside the body
			// produce values and keep comprehension form. Map comprehensions are left unwrapped.
			case EArrayDecl([{expr: EFor(it, body), pos: fpos}]):
				final body2 = rewriteComprehensionBody(body);
				switch it.expr {
					case EBinop(OpIn, v, coll) if (!isInterval(coll) && !yieldsMapEntry(body)):
						final name = "__nilRange" + (counter++);
						final tmp = macro @:pos(fpos) $i{name};
						final loop:Expr = {expr: EFor(macro $v in $tmp, body2), pos: fpos};
						final arr:Expr = {expr: EArrayDecl([loop]), pos: e.pos};
						final coll2 = rewrite(coll);
						macro @:pos(e.pos) {
							final $name = $coll2;
							$tmp == null ? [] : $arr;
						};
					case _:
						{expr: EArrayDecl([{expr: EFor(rewrite(it), body2), pos: fpos}]), pos: e.pos};
				}
			case EFor(it, body):
				final body2 = rewrite(body);
				switch it.expr {
					case EBinop(OpIn, v, coll) if (!isInterval(coll)):
						if (!Context.defined("js"))
							makeLoopWith(e.pos, rewrite(coll), tmp -> macro @:pos(e.pos) go.ForIn.values($tmp, $v, $body2));
						else
							makeLoop(e.pos, v, rewrite(coll), body2, (v, tmp) -> macro $v in $tmp);
					// `for (k => v in m)` parses as `k => (v in m)`
					case EBinop(OpArrow, k, {expr: EBinop(OpIn, v, coll)}):
						if (!Context.defined("js"))
							makeLoopWith(e.pos, rewrite(coll), tmp -> macro @:pos(e.pos) go.ForIn.keyValues($tmp, $k, $v, $body2));
						else
							makeLoop(e.pos, v, rewrite(coll), body2, (v, tmp) -> macro $k => $v in $tmp);
					case _:
						{expr: EFor(rewrite(it), body2), pos: e.pos};
				}
			// Interpolated strings `'..${e}..'` are still constants here: expand them, then rewrite the parts.
			case EConst(CString(str, SingleQuotes)) if (str.indexOf("$") >= 0):
				rewrite(haxe.macro.MacroStringTools.formatString(str, e.pos));
			// Go `len(s)` of a nil slice/map is 0; a Haxe `.length` read on null throws.
			// Reads become `(tmp == null ? 0 : tmp.length)`. Calls `x.length()` and assignments are unchanged.
			case ECall({expr: EField(obj, "length"), pos: fpos}, args):
				{expr: ECall({expr: EField(rewrite(obj), "length"), pos: fpos}, [for (a in args) rewrite(a)]), pos: e.pos};
			case EBinop(op = OpAssign | OpAssignOp(_), lhs = {expr: EField(obj, "length")}, rhs):
				{expr: EBinop(op, {expr: EField(rewrite(obj), "length"), pos: lhs.pos}, rewrite(rhs)), pos: e.pos};
			case EUnop(op, postFix, {expr: EField(obj, "length"), pos: fpos}) if (op == OpIncrement || op == OpDecrement):
				{expr: EUnop(op, postFix, {expr: EField(rewrite(obj), "length"), pos: fpos}), pos: e.pos};
			case EField(obj, "length"):
				final obj2 = rewrite(obj);
				switch obj2.expr {
					case EConst(CIdent(_)):
						macro @:pos(e.pos) ($obj2 == null ? 0 : $obj2.length);
					case _:
						final name = "__nilLen" + (counter++);
						final tmp = macro @:pos(e.pos) $i{name};
						macro @:pos(e.pos) {
							final $name = $obj2;
							$tmp == null ? 0 : $tmp.length;
						};
				}
			// Go `f(xs...)` with a nil slice passes zero arguments; Haxe `f(...xs)` throws on null.
			case EUnop(OpSpread, false, inner):
				final inner2 = rewrite(inner);
				if (Context.defined("cs")) // PORT: cs — spread of the exact length (see go.CsTarget.exactRest)
					macro @:pos(e.pos) ...{
						final __nilSpread = $inner2;
						__nilSpread != null ? go.CsTarget.exactRest(__nilSpread) : [];
					};
				else
					macro @:pos(e.pos) ...{
						final __nilSpread = $inner2;
						__nilSpread != null ? __nilSpread : [];
					};
			case _:
				haxe.macro.ExprTools.map(e, rewrite);
		}
	}

	// Inside a comprehension body, `for`, `if` and the last expression of a block yield values.
	static function rewriteComprehensionBody(e:Expr):Expr {
		return switch e.expr {
			case EFor(it, body): {expr: EFor(rewrite(it), rewriteComprehensionBody(body)), pos: e.pos};
			case EIf(cond, a, b): {expr: EIf(rewrite(cond), rewriteComprehensionBody(a), b == null ? null : rewriteComprehensionBody(b)), pos: e.pos};
			case EBlock(es) if (es.length > 0):
				final out = [for (i in 0...es.length) i == es.length - 1 ? rewriteComprehensionBody(es[i]) : rewrite(es[i])];
				{expr: EBlock(out), pos: e.pos};
			case _: rewrite(e);
		}
	}

	static function yieldsMapEntry(e:Expr):Bool {
		return switch e.expr {
			case EBinop(OpArrow, _, _): true;
			case EFor(_, body): yieldsMapEntry(body);
			case EIf(_, a, _): yieldsMapEntry(a);
			case EBlock(es) if (es.length > 0): yieldsMapEntry(es[es.length - 1]);
			case EParenthesis(inner): yieldsMapEntry(inner);
			case _: false;
		}
	}

	static function makeLoop(pos:Position, v:Expr, coll:Expr, body:Expr, mk:(Expr, Expr) -> Expr):Expr {
		final name = "__nilRange" + (counter++);
		final tmp = macro @:pos(pos) $i{name};
		final loop:Expr = {expr: EFor(mk(v, tmp), body), pos: pos};
		return macro @:pos(pos) {
			final $name = $coll;
			if ($tmp != null) $loop;
		};
	}

	// Like makeLoop, with the loop built by `mk` (go.ForIn on cpp).
	static function makeLoopWith(pos:Position, coll:Expr, mk:Expr->Expr):Expr {
		final name = "__nilRange" + (counter++);
		final tmp = macro @:pos(pos) $i{name};
		final loop = mk(tmp);
		return macro @:pos(pos) {
			final $name = $coll;
			if ($tmp != null) $loop;
		};
	}

	static function isInterval(e:Expr):Bool {
		return switch e.expr {
			case EBinop(OpInterval, _, _): true;
			case EParenthesis(inner): isInterval(inner);
			case _: false;
		}
	}
}
#end
