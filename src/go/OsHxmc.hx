package go;

#if (target.name == "hxmc" && hxmc.wasm_gc)
typedef OsHxmc = OsGc;
#elseif (target.name == "hxmc" && hxmc.target == "wasm32-wasi")
typedef OsHxmc = OsWasi;
#elseif (target.name == "hxmc")
import hxmc.unsafe.LibC;
import hxmc.unsafe.Mem;
import hxmc.unsafe.Ptr;

// PORT: hxmc — the C library calls of OsNative (as the cpp branch's go_os_* helpers), Linux x86-64
// layouts (struct stat: st_mode at 24, st_size at 48, st_mtim at 88; struct timespec: 16 bytes, utimensat for utimes).
@:hxmc.c @:hxmc.fast private extern class C {
	static function stat(path:Ptr, st:Ptr):Int;
	static function lstat(path:Ptr, st:Ptr):Int;
	static function mkdir(path:Ptr, mode:Int):Int;
	static function unlink(path:Ptr):Int;
	static function rmdir(path:Ptr):Int;
	static function symlink(target:Ptr, path:Ptr):Int;
	static function utimensat(dirfd:Int, path:Ptr, ts:Ptr, flags:Int):Int;
	static function realpath(path:Ptr, buf:Ptr):Ptr;
	static function __errno_location():Ptr;
}

class OsHxmc {
	static inline function cstr(s:String):Ptr
		return @:privateAccess hxmc.rt.Str.toUtf8(s);

	static function errno():Int
		return Mem.getI32(C.__errno_location(), 0);

	public static function errname(e:Int):String {
		return switch e {
			case 2: "ENOENT";
			case 17: "EEXIST";
			case 20: "ENOTDIR";
			case 21: "EISDIR";
			case 13: "EACCES";
			case 1: "EPERM";
			case 39: "ENOTEMPTY";
			case 40: "ELOOP";
			case 22: "EINVAL";
			case 5: "EIO";
			case 36: "ENAMETOOLONG";
			case 16: "EBUSY";
			case 30: "EROFS";
			case 18: "EXDEV";
			case _: Std.string(e);
		}
	}

	// [errno] or [0, mode, size, mtime sec, mtime nsec]
	public static function stat(path:String, follow:Bool):Array<Float> {
		final p = cstr(path);
		final st = Mem.stack(256);
		final r = follow ? C.stat(p, st) : C.lstat(p, st);
		final e = r != 0 ? errno() : 0;
		LibC.free(p);
		if (r != 0)
			return [e];
		final size:Float = cast Mem.getI64(st, 48);
		final sec:Float = cast Mem.getI64(st, 88);
		final nsec:Float = cast Mem.getI64(st, 96);
		return [0, Mem.getI32(st, 24), size, sec, nsec];
	}

	public static function mkdir(path:String, perm:Int):Int {
		final p = cstr(path);
		final e = C.mkdir(p, perm) == 0 ? 0 : errno();
		LibC.free(p);
		return e;
	}

	public static function unlink(path:String):Int {
		final p = cstr(path);
		final e = C.unlink(p) == 0 ? 0 : errno();
		LibC.free(p);
		return e;
	}

	public static function rmdir(path:String):Int {
		final p = cstr(path);
		final e = C.rmdir(p) == 0 ? 0 : errno();
		LibC.free(p);
		return e;
	}

	public static function symlink(target:String, path:String):Int {
		final t = cstr(target), p = cstr(path);
		final e = C.symlink(t, p) == 0 ? 0 : errno();
		LibC.free(t);
		LibC.free(p);
		return e;
	}

	public static function utimes(path:String, atime:Float, mtime:Float):Int {
		final p = cstr(path);
		final tv = Mem.stack(32);
		final as = Std.int(std.Math.ffloor(atime)), ms = Std.int(std.Math.ffloor(mtime));
		Mem.setI64(tv, 0, as);
		Mem.setI64(tv, 8, Std.int((atime - as) * 1e6) * 1000); // microseconds, as the cpp branch's utimes
		Mem.setI64(tv, 16, ms);
		Mem.setI64(tv, 24, Std.int((mtime - ms) * 1e6) * 1000);
		final e = C.utimensat(-100, p, tv, 0) == 0 ? 0 : errno();
		LibC.free(p);
		return e;
	}

	#if tshx_parallel
	@:hxmc.threadLocal public static var realpathErrno:Int; // PORT: hxmc (-D tshx-parallel) — per thread
	#else
	public static var realpathErrno = 0;
	#end

	public static function realpath(path:String):Null<String> {
		final p = cstr(path);
		final buf = Mem.stack(4104);
		final r = C.realpath(p, buf);
		realpathErrno = r.isNull() ? errno() : 0;
		LibC.free(p);
		if (r.isNull())
			return null;
		return hxmc.rt.Str.ofUtf8(buf, LibC.strlen(buf).toInt());
	}

	// PORT: memory — os.ReadFile and vfs's decodeBytes in one: the file read into malloc'ed memory (as the
	// runtime's fileContent does) and decoded from there, so no Bytes object holds the file on the heap (a copy
	// of every source file: garbage of the nursery and, when a minor collection catches it, of the old space).
	// ("", false) when it cannot be read; null when the caller's path is needed: a UTF-16 byte order mark or
	// UTF-8 that is not valid (U+FFFD replacement, go.Utf8.BytesToString).
	public static function readFileText(path:String):Null<go.Tuple.ValueOk<String>> {
		final p = cstr(path);
		final fd = hxmc.unsafe.Posix.open(p, 0x80000 /* O_RDONLY | O_CLOEXEC */, 0);
		LibC.free(p);
		if (fd < 0)
			return new go.Tuple.ValueOk("", false);
		var cap = 65536, n = 0;
		final st = Mem.stack(256);
		if (hxmc.unsafe.Posix.fstat(fd, st) == 0 && (Mem.getI32(st, 24) & 0xF000) == 0x8000)
			cap = Mem.getI64(st, 48).toInt() + 1;
		var buf = LibC.malloc(cap);
		while (true) {
			if (n == cap) {
				cap *= 2;
				buf = LibC.realloc(buf, cap);
			}
			final r = hxmc.unsafe.Posix.read(fd, buf.add(n), cap - n).toInt();
			if (r < 0 && errno() == 4 /* EINTR */)
				continue;
			if (r < 0) {
				LibC.free(buf);
				hxmc.unsafe.Posix.close(fd);
				return new go.Tuple.ValueOk("", false);
			}
			if (r == 0)
				break;
			n += r;
		}
		hxmc.unsafe.Posix.close(fd);
		final s = decodeText(buf, n);
		LibC.free(buf);
		return s == null ? null : new go.Tuple.ValueOk(s, true);
	}

	// Internal.decodeBytes of the n bytes at b (outside the heap); null for the cases it leaves to its caller
	static function decodeText(b:Ptr, n:Int):Null<String> {
		if (n >= 2) {
			final b0 = Mem.getU8(b, 0), b1 = Mem.getU8(b, 1);
			if ((b0 == 0xFF && b1 == 0xFE) || (b0 == 0xFE && b1 == 0xFF))
				return null;
		}
		var start = 0;
		if (n >= 3 && Mem.getU8(b, 0) == 0xEF && Mem.getU8(b, 1) == 0xBB && Mem.getU8(b, 2) == 0xBF)
			start = 3;
		var i = start;
		while (i + 8 <= n && (Mem.getI32(b, i) | Mem.getI32(b, i + 4)) & 0x80808080 == 0)
			i += 8;
		while (i < n && Mem.getU8(b, i) < 0x80)
			i++;
		final len = n - start;
		if (i == n) {
			final s = hxmc.rt.Str.make1(len);
			if (len > 0)
				LibC.memcpy(hxmc.rt.Str.unitsAddr(s), b.add(start), len);
			return s;
		}
		// valid UTF-8 (go.Utf8.validAt) is what Bytes.getString(UTF8) decodes the same way
		while (i < n) {
			final c = Mem.getU8(b, i);
			if (c < 0x80) {
				i++;
				continue;
			}
			final k = c < 0xC2 ? 0 : (c < 0xE0 ? 2 : (c < 0xF0 ? 3 : (c < 0xF5 ? 4 : 0)));
			if (k == 0 || i + k > n)
				return null;
			final b1 = Mem.getU8(b, i + 1);
			if (b1 < (c == 0xE0 ? 0xA0 : (c == 0xF0 ? 0x90 : 0x80)) || b1 > (c == 0xED ? 0x9F : (c == 0xF4 ? 0x8F : 0xBF)))
				return null;
			for (j in 2...k) {
				final bj = Mem.getU8(b, i + j);
				if (bj < 0x80 || bj > 0xBF)
					return null;
			}
			i += k;
		}
		return hxmc.rt.Str.ofUtf8(b.add(start), len);
	}
}
#end
