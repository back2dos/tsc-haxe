package go;

import go.Errors.Error;
import go.Errors.Wrapper;
import go.Time;
import go.Tuple.ValueError;
import haxe.io.Bytes;

// Shim for Go package io/fs (fs.go, readdir.go, readfile.go, stat.go, sub.go, walk.go).
// PORT: `[]byte` → haxe.io.Bytes; File.Read takes the slice as (b, pos, len).
// PORT: FileInfo.Size() is Int (Go int64); all file sizes in scope fit in 31 bits.
// PORT: ValidPath does not check UTF-8 validity (Haxe strings are always decoded).

// fs.FileMode (uint32 bits; bit 31 is ModeDir: test with != 0, never with < or >).
enum abstract FileMode(Int) from Int to Int {
	var ModeNone = 0;
	var ModeDir = 1 << 31; // d: is a directory
	var ModeAppend = 1 << 30; // a: append-only
	var ModeExclusive = 1 << 29; // l: exclusive use
	var ModeTemporary = 1 << 28; // T: temporary file; Plan 9 only
	var ModeSymlink = 1 << 27; // L: symbolic link
	var ModeDevice = 1 << 26; // D: device file
	var ModeNamedPipe = 1 << 25; // p: named pipe (FIFO)
	var ModeSocket = 1 << 24; // S: Unix domain socket
	var ModeSetuid = 1 << 23; // u: setuid
	var ModeSetgid = 1 << 22; // g: setgid
	var ModeCharDevice = 1 << 21; // c: Unix character device, when ModeDevice is set
	var ModeSticky = 1 << 20; // t: sticky
	var ModeIrregular = 1 << 19; // ?: non-regular file; nothing else is known about this file
	// Mask for the type bits. For regular files, none will be set.
	var ModeType = (1 << 31) | (1 << 27) | (1 << 25) | (1 << 24) | (1 << 26) | (1 << 21) | (1 << 19);
	var ModePerm = 511; // 0777, Unix permission bits

	@:op(A | B) static function or(a:FileMode, b:FileMode):FileMode;

	@:op(A & B) static function and(a:FileMode, b:FileMode):FileMode;

	@:op(~A) static function not(a:FileMode):FileMode;

	public inline function IsDir():Bool {
		return this & ModeDir != 0;
	}

	public inline function IsRegular():Bool {
		return this & ModeType == 0;
	}

	public inline function Perm():FileMode {
		return this & ModePerm;
	}

	public inline function Type():FileMode {
		return this & ModeType;
	}
}

// fs.FS
interface FS {
	function Open(name:String):ValueError<File>;
}

// fs.File
interface File {
	function Stat():ValueError<FileInfo>;
	function Read(b:Bytes, pos:Int, len:Int):ValueError<Int>;
	function Close():Null<Error>;
}

// fs.ReadDirFile
interface ReadDirFile extends File {
	function ReadDir(n:Int):ValueError<Array<DirEntry>>;
}

// fs.FileInfo
interface FileInfo {
	function Name():String;
	function Size():Int;
	function Mode():FileMode;
	function ModTime():Time;
	function IsDir():Bool;
	function Sys():Any;
}

// fs.DirEntry
interface DirEntry {
	function Name():String;
	function IsDir():Bool;
	function Type():FileMode;
	function Info():ValueError<FileInfo>;
}

// fs.StatFS
interface StatFS extends FS {
	function Stat(name:String):ValueError<FileInfo>;
}

// fs.ReadFileFS
interface ReadFileFS extends FS {
	function ReadFile(name:String):ValueError<Bytes>;
}

// fs.ReadDirFS
interface ReadDirFS extends FS {
	function ReadDir(name:String):ValueError<Array<DirEntry>>;
}

// fs.SubFS
interface SubFS extends FS {
	function Sub(dir:String):ValueError<FS>;
}

// fs.WalkDirFunc
typedef WalkDirFunc = (path:String, d:Null<DirEntry>, err:Null<Error>) -> Null<Error>;

// fs.PathError
class PathError implements Error implements Wrapper {
	public var Op:String = "";
	public var Path:String = "";
	public var Err:Null<Error> = null;

	public function new(op:String, path:String, err:Null<Error>) {
		this.Op = op;
		this.Path = path;
		this.Err = err;
	}

	public function Error():String {
		return Op + " " + Path + ": " + Err.Error();
	}

	public function Unwrap():Null<Error> {
		return Err;
	}

	public function toString():String {
		return Error();
	}
}

class Fs {
	public static final ErrInvalid:Error = Errors.New("invalid argument");
	public static final ErrPermission:Error = Errors.New("permission denied");
	public static final ErrExist:Error = Errors.New("file already exists");
	public static final ErrNotExist:Error = Errors.New("file does not exist");
	public static final ErrClosed:Error = Errors.New("file already closed");

	public static final SkipDir:Error = Errors.New("skip this directory");
	public static final SkipAll:Error = Errors.New("skip everything and stop the walk");

	// fs.ValidPath
	public static function ValidPath(name:String):Bool {
		if (name == ".") {
			return true;
		}
		while (true) {
			var i = 0;
			while (i < name.length && StringTools.fastCodeAt(name, i) != '/'.code) {
				i++;
			}
			final elem = name.substring(0, i);
			if (elem == "" || elem == "." || elem == "..") {
				return false;
			}
			if (i == name.length) {
				return true;
			}
			name = name.substring(i + 1);
		}
	}

	// --- stat.go ---

	public static function Stat(fsys:FS, name:String):ValueError<FileInfo> {
		if (Std.isOfType(fsys, StatFS)) {
			return (cast fsys : StatFS).Stat(name);
		}
		final r = fsys.Open(name);
		if (r.err != null) {
			return new ValueError<FileInfo>(null, r.err);
		}
		final file = r.value;
		final s = file.Stat();
		file.Close();
		return s;
	}

	// --- readfile.go ---

	public static function ReadFile(fsys:FS, name:String):ValueError<Bytes> {
		if (Std.isOfType(fsys, ReadFileFS)) {
			return (cast fsys : ReadFileFS).ReadFile(name);
		}
		final r = fsys.Open(name);
		if (r.err != null) {
			return new ValueError<Bytes>(null, r.err);
		}
		final file = r.value;
		final result = readAll(file);
		file.Close();
		return result;
	}

	static function readAll(file:File):ValueError<Bytes> {
		var size = 0;
		final info = file.Stat();
		if (info.err == null) {
			size = info.value.Size();
		}
		var data = Bytes.alloc(size + 1);
		var n = 0;
		while (true) {
			if (n >= data.length) {
				final d = Bytes.alloc(data.length * 2 + 1);
				d.blit(0, data, 0, n);
				data = d;
			}
			final r = file.Read(data, n, data.length - n);
			n += r.value;
			if (r.err != null) {
				var err = r.err;
				if (err == Io.EOF) {
					err = null;
				}
				return new ValueError<Bytes>(data.sub(0, n), err);
			}
		}
	}

	// --- readdir.go ---

	public static function ReadDir(fsys:FS, name:String):ValueError<Array<DirEntry>> {
		if (Std.isOfType(fsys, ReadDirFS)) {
			return (cast fsys : ReadDirFS).ReadDir(name);
		}
		final r = fsys.Open(name);
		if (r.err != null) {
			return new ValueError<Array<DirEntry>>(null, r.err);
		}
		final file = r.value;
		if (!Std.isOfType(file, ReadDirFile)) {
			file.Close();
			return new ValueError<Array<DirEntry>>(null, new PathError("readdir", name, Errors.New("not implemented")));
		}
		final res = (cast file : ReadDirFile).ReadDir(-1);
		file.Close();
		final list = res.value;
		if (list != null) {
			list.sort((a, b) -> Strings.Compare(a.Name(), b.Name()));
		}
		return new ValueError<Array<DirEntry>>(list, res.err);
	}

	// fs.FileInfoToDirEntry
	public static function FileInfoToDirEntry(info:Null<FileInfo>):Null<DirEntry> {
		if (info == null) {
			return null;
		}
		return new DirInfo(info);
	}

	// --- sub.go ---

	public static function Sub(fsys:FS, dir:String):ValueError<FS> {
		if (!ValidPath(dir)) {
			return new ValueError<FS>(null, new PathError("sub", dir, ErrInvalid));
		}
		if (dir == ".") {
			return new ValueError<FS>(fsys, null);
		}
		if (Std.isOfType(fsys, SubFS)) {
			return (cast fsys : SubFS).Sub(dir);
		}
		return new ValueError<FS>(new SubFS_(fsys, dir), null);
	}

	// --- walk.go ---

	static function walkDir(fsys:FS, name:String, d:DirEntry, walkDirFn:WalkDirFunc):Null<Error> {
		{
			var err = walkDirFn(name, d, null);
			if (err != null || !d.IsDir()) {
				if (err == SkipDir && d.IsDir()) {
					err = null;
				}
				return err;
			}
		}

		final r = ReadDir(fsys, name);
		final dirs = r.value;
		if (r.err != null) {
			// Second call, to report ReadDir error.
			var err = walkDirFn(name, d, r.err);
			if (err != null) {
				if (err == SkipDir && d.IsDir()) {
					err = null;
				}
				return err;
			}
		}

		if (dirs != null) {
			for (d1 in dirs) {
				final name1 = Path.Join([name, d1.Name()]);
				final err = walkDir(fsys, name1, d1, walkDirFn);
				if (err != null) {
					if (err == SkipDir) {
						break;
					}
					return err;
				}
			}
		}
		return null;
	}

	public static function WalkDir(fsys:FS, root:String, fn:WalkDirFunc):Null<Error> {
		final info = Stat(fsys, root);
		var err:Null<Error>;
		if (info.err != null) {
			err = fn(root, null, info.err);
		} else {
			err = walkDir(fsys, root, FileInfoToDirEntry(info.value), fn);
		}
		if (err == SkipDir || err == SkipAll) {
			return null;
		}
		return err;
	}
}

// fs.dirInfo
private class DirInfo implements DirEntry {
	final fileInfo:FileInfo;

	public function new(fileInfo:FileInfo) {
		this.fileInfo = fileInfo;
	}

	public function IsDir():Bool {
		return fileInfo.IsDir();
	}

	public function Type():FileMode {
		return fileInfo.Mode().Type();
	}

	public function Info():ValueError<FileInfo> {
		return new ValueError<FileInfo>(fileInfo, null);
	}

	public function Name():String {
		return fileInfo.Name();
	}
}

// fs.subFS
private class SubFS_ implements ReadDirFS implements ReadFileFS implements SubFS {
	final fsys:FS;
	final dir:String;

	public function new(fsys:FS, dir:String) {
		this.fsys = fsys;
		this.dir = dir;
	}

	function fullName(op:String, name:String):ValueError<String> {
		if (!Fs.ValidPath(name)) {
			return new ValueError<String>("", new PathError(op, name, Fs.ErrInvalid));
		}
		return new ValueError<String>(Path.Join([dir, name]), null);
	}

	function shorten(name:String):Null<String> {
		if (name == dir) {
			return ".";
		}
		if (name.length >= dir.length + 2 && StringTools.fastCodeAt(name, dir.length) == '/'.code && name.substring(0, dir.length) == dir) {
			return name.substring(dir.length + 1);
		}
		return null;
	}

	function fixErr(err:Null<Error>):Null<Error> {
		if (Std.isOfType(err, PathError)) {
			final e:PathError = cast err;
			final short = shorten(e.Path);
			if (short != null) {
				e.Path = short;
			}
		}
		return err;
	}

	public function Open(name:String):ValueError<File> {
		final full = fullName("open", name);
		if (full.err != null) {
			return new ValueError<File>(null, full.err);
		}
		final r = fsys.Open(full.value);
		return new ValueError<File>(r.value, fixErr(r.err));
	}

	public function ReadDir(name:String):ValueError<Array<DirEntry>> {
		final full = fullName("read", name);
		if (full.err != null) {
			return new ValueError<Array<DirEntry>>(null, full.err);
		}
		final r = Fs.ReadDir(fsys, full.value);
		return new ValueError<Array<DirEntry>>(r.value, fixErr(r.err));
	}

	public function ReadFile(name:String):ValueError<Bytes> {
		final full = fullName("read", name);
		if (full.err != null) {
			return new ValueError<Bytes>(null, full.err);
		}
		final r = Fs.ReadFile(fsys, full.value);
		return new ValueError<Bytes>(r.value, fixErr(r.err));
	}

	// PORT: ReadLink, Lstat, Glob of subFS are not ported (not used in scope).

	public function Sub(dir:String):ValueError<FS> {
		if (dir == ".") {
			return new ValueError<FS>(this, null);
		}
		final full = fullName("sub", dir);
		if (full.err != null) {
			return new ValueError<FS>(null, full.err);
		}
		return new ValueError<FS>(new SubFS_(fsys, full.value), null);
	}
}
