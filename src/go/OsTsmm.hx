package go;

// PORT: ts-- (haxe-in-haxe's tsmm generator, portable mode: target.name == "tsmm") — OsNative's system
// calls with OsHxmc's API, as a native class: on tsmm it is extern, and OsTsmm.ts (beside this file)
// implements it on node; compiled for another target (haxe-in-haxe's ts-- frontend), this class is the
// implementation.
#if (target.name == "tsmm")
@:tsmm.native("OsTsmm.ts")
extern class OsTsmm {
	static function errname(e:Int):String;
	static function stat(path:String, follow:Bool):Array<Float>;
	static function mkdir(path:String, perm:Int):Int;
	static function unlink(path:String):Int;
	static function rmdir(path:String):Int;
	static function symlink(target:String, path:String):Int;
	static function utimes(path:String, atime:Float, mtime:Float):Int;
	static var realpathErrno:Int;
	static function realpath(path:String):Null<String>;
}
#elseif (target.name == "hxmc")
typedef OsTsmm = OsHxmc;
#elseif js
class OsTsmm {
	static final names = ["ENOENT" => 2, "EEXIST" => 17, "ENOTDIR" => 20, "EISDIR" => 21, "EACCES" => 13, "EPERM" => 1,
		"ENOTEMPTY" => 39, "ELOOP" => 40, "EINVAL" => 22, "EIO" => 5, "ENAMETOOLONG" => 36, "EBUSY" => 16, "EROFS" => 30, "EXDEV" => 18];
	static final codes = [for (k => v in names) v => k];

	static function code(e:Dynamic):Int {
		final c:Null<String> = e == null ? null : e.code;
		final n = c == null ? null : names[c];
		return n == null ? 5 : n;
	}

	public static function errname(e:Int):String {
		final n = codes[e];
		return n == null ? Std.string(e) : n;
	}

	public static function stat(path:String, follow:Bool):Array<Float> {
		try {
			final s:Dynamic = follow ? js.Syntax.code("require('fs').statSync({0})", path) : js.Syntax.code("require('fs').lstatSync({0})", path);
			final ms:Float = s.mtimeMs;
			final sec = std.Math.ffloor(ms / 1000);
			return [0, s.mode, s.size, sec, std.Math.ffloor((ms - sec * 1000) * 1000000)];
		} catch (e:Dynamic) {
			return [code(e)];
		}
	}

	public static function mkdir(path:String, perm:Int):Int {
		try {
			js.Syntax.code("require('fs').mkdirSync({0}, {1})", path, perm);
			return 0;
		} catch (e:Dynamic) {
			return code(e);
		}
	}

	public static function unlink(path:String):Int {
		try {
			js.Syntax.code("require('fs').unlinkSync({0})", path);
			return 0;
		} catch (e:Dynamic) {
			return code(e);
		}
	}

	public static function rmdir(path:String):Int {
		try {
			js.Syntax.code("require('fs').rmdirSync({0})", path);
			return 0;
		} catch (e:Dynamic) {
			return code(e);
		}
	}

	public static function symlink(target:String, path:String):Int {
		try {
			js.Syntax.code("require('fs').symlinkSync({0}, {1})", target, path);
			return 0;
		} catch (e:Dynamic) {
			return code(e);
		}
	}

	public static function utimes(path:String, atime:Float, mtime:Float):Int {
		try {
			js.Syntax.code("require('fs').utimesSync({0}, {1}, {2})", path, atime, mtime);
			return 0;
		} catch (e:Dynamic) {
			return code(e);
		}
	}

	public static var realpathErrno = 0;

	public static function realpath(path:String):Null<String> {
		try {
			final r:String = js.Syntax.code("require('fs').realpathSync.native({0})", path);
			realpathErrno = 0;
			return r;
		} catch (e:Dynamic) {
			realpathErrno = code(e);
			return null;
		}
	}
}
#end
