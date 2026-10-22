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
#elseif jvm
// PORT: ts-- on the JVM: go.Os's jvm branches (java.nio.file) with OsHxmc's API
class OsTsmm {
	static final names = ["ENOENT" => 2, "EEXIST" => 17, "ENOTDIR" => 20, "EISDIR" => 21, "EACCES" => 13, "EPERM" => 1,
		"ENOTEMPTY" => 39, "ELOOP" => 40, "EINVAL" => 22, "EIO" => 5, "ENAMETOOLONG" => 36, "EBUSY" => 16, "EROFS" => 30, "EXDEV" => 18];
	static final codes = [for (k => v in names) v => k];

	public static function errname(e:Int):String {
		final n = codes[e];
		return n == null ? Std.string(e) : n;
	}

	static function jpath(path:String):java.nio.file.Path {
		return java.nio.file.Paths.get(path);
	}

	static function code(e:Dynamic):Int {
		return names[jvmName(e)];
	}

	static function jvmName(e:Dynamic):String {
		if (Std.isOfType(e, java.nio.file.NoSuchFileException))
			return "ENOENT";
		if (Std.isOfType(e, java.nio.file.FileAlreadyExistsException))
			return "EEXIST";
		if (Std.isOfType(e, java.nio.file.DirectoryNotEmptyException))
			return "ENOTEMPTY";
		if (Std.isOfType(e, java.nio.file.NotDirectoryException))
			return "ENOTDIR";
		if (Std.isOfType(e, java.nio.file.AccessDeniedException))
			return "EACCES";
		if (Std.isOfType(e, java.nio.file.FileSystemLoopException))
			return "ELOOP";
		if (Std.isOfType(e, java.nio.file.FileSystemException)) {
			final reason:Null<String> = (cast e : java.nio.file.FileSystemException).getReason();
			switch reason {
				case "Not a directory": return "ENOTDIR";
				case "Is a directory": return "EISDIR";
				case "Too many levels of symbolic links": return "ELOOP";
				case "File name too long": return "ENAMETOOLONG";
				case "Permission denied": return "EACCES";
				case "Operation not permitted": return "EPERM";
				case "Read-only file system": return "EROFS";
				case "Invalid argument": return "EINVAL";
				case _:
			}
		}
		return "EIO";
	}

	static function isDir(path:String):Bool {
		return java.nio.file.Files.isDirectory(jpath(path), java.nio.file.LinkOption.NOFOLLOW_LINKS);
	}

	public static function stat(path:String, follow:Bool):Array<Float> {
		try {
			final m = if (follow) java.nio.file.Files.readAttributes(jpath(path),
				"unix:mode,size,lastModifiedTime") else java.nio.file.Files.readAttributes(jpath(path), "unix:mode,size,lastModifiedTime",
					java.nio.file.LinkOption.NOFOLLOW_LINKS);
			final t:java.nio.file.attribute.FileTime = cast m.get("lastModifiedTime");
			final i = t.toInstant();
			return [0, (cast m.get("mode") : Int), haxe.Int64.toInt((cast m.get("size") : haxe.Int64)), haxe.Int64.toInt(i.getEpochSecond()), i.getNano()];
		} catch (e:Dynamic) {
			return [code(e)];
		}
	}

	public static function mkdir(path:String, perm:Int):Int {
		try {
			final b = new StringBuf();
			for (i in 0...9)
				b.add((perm & (1 << (8 - i))) != 0 ? "rwx".charAt(i % 3) : "-");
			java.nio.file.Files.createDirectory(jpath(path),
				java.nio.file.attribute.PosixFilePermissions.asFileAttribute(java.nio.file.attribute.PosixFilePermissions.fromString(b.toString())));
			return 0;
		} catch (e:Dynamic) {
			return code(e);
		}
	}

	public static function unlink(path:String):Int {
		try {
			if (isDir(path))
				return names["EISDIR"]; // Files.delete would remove an empty directory
			java.nio.file.Files.delete(jpath(path));
			return 0;
		} catch (e:Dynamic) {
			return code(e);
		}
	}

	public static function rmdir(path:String):Int {
		try {
			if (!isDir(path)) {
				final st = stat(path, false);
				return st[0] != 0 ? Std.int(st[0]) : names["ENOTDIR"];
			}
			java.nio.file.Files.delete(jpath(path));
			return 0;
		} catch (e:Dynamic) {
			return code(e);
		}
	}

	public static function symlink(target:String, path:String):Int {
		try {
			java.nio.file.Files.createSymbolicLink(jpath(path), jpath(target));
			return 0;
		} catch (e:Dynamic) {
			return code(e);
		}
	}

	public static function utimes(path:String, atime:Float, mtime:Float):Int {
		try {
			final view:java.nio.file.attribute.BasicFileAttributeView = cast java.nio.file.Files.getFileAttributeView(jpath(path),
				java.lang.Class.forName("java.nio.file.attribute.BasicFileAttributeView"));
			final us = (t:Float) -> java.nio.file.attribute.FileTime.from(haxe.Int64.fromFloat(std.Math.ffloor(t * 1e6)),
				java.util.concurrent.TimeUnit.MICROSECONDS);
			view.setTimes(us(mtime), us(atime), null);
			return 0;
		} catch (e:Dynamic) {
			return code(e);
		}
	}

	public static var realpathErrno = 0;

	public static function realpath(path:String):Null<String> {
		try {
			final r = jpath(path).toRealPath().toString();
			realpathErrno = 0;
			return r;
		} catch (e:Dynamic) {
			realpathErrno = code(e);
			return null;
		}
	}
}
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
