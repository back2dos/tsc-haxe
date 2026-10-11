package go;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
#end

// PORT: cs — fixes for C# rules that hxcs does not handle. go.NilRange applies them on C# only.
class CsTarget {
	#if cs
	// With -D erase-generics, hxcs passes a spread array `f(...a)` as its backing native array
	// (haxe.Rest.of: `array.__a`), which is longer than `a` (capacity): the callee sees extra null
	// elements (measured: a null EmitHelper in Printer.emitHelpers). go.NilRange passes every spread
	// array through this function on C#: the same array when its backing array has its length,
	// else a copy of the right length.
	public static function exactRest<T>(a:Array<T>):Array<T> {
		return (@:privateAccess a.__a).Length == a.length ? a : a.copy();
	}
	#end

	#if macro
	// A C# member must not have the name of its enclosing type. hxcs renames such a member to
	// `<Type>_<name>` in that type only, so an implementation in a class with another name no longer
	// implements the interface member (Go `error.Error()`: interface go.Errors.Error has `Error()`,
	// class ErrorString implements it; `ProgramLike.Program()` and class Program). Every field named
	// like a type that has a field of its own name gets the same native name `<name>_` in all types,
	// so declarations, overrides and calls agree. (Context.onGenerate callback.)
	public static function names(types:Array<Type>):Void {
		final classes = [];
		for (t in types) {
			switch t {
				case TInst(c, _):
					classes.push(c.get());
				case _:
			}
		}
		final clash = new Map<String, Bool>();
		for (c in classes) {
			for (f in c.fields.get().concat(c.statics.get())) {
				if (f.name == c.name)
					clash.set(f.name, true);
			}
		}
		for (c in classes) {
			for (f in c.fields.get().concat(c.statics.get())) {
				if (clash.exists(f.name) && !f.meta.has(":native"))
					f.meta.add(":native", [macro $v{f.name + "_"}], f.pos);
			}
		}
	}

	// hxcs gives every class a second constructor `C(haxe.lang.EmptyObject empty)`, and EmptyObject
	// is a C# enum. C# converts a constant 0 to any enum type, and prefers that conversion to boxing:
	// `new SyncMap<Path, FileEmitKind>(FileEmitKindNone)` (one parameter of type V = object) silently
	// called the empty constructor, and the fields stayed null. A constructor with exactly one
	// parameter gets a second, optional parameter, so no call has one argument. (Build macro step.)
	public static function constructorArity(fields:Array<Field>):Void {
		for (f in fields) {
			if (f.name != "new")
				continue;
			switch f.kind {
				case FFun(fn) if (fn.args.length == 1):
					fn.args.push({name: "__csArity", opt: true, type: macro :Null<Bool>});
				case _:
			}
		}
	}
	#end
}
