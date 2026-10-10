package go;

import go.Errors.Error;
import go.Fs;
import go.Time;
import go.Tuple.ValueError;
import haxe.ds.StringMap;
import haxe.io.Bytes;

// Shim for Go package testing/fstest: MapFS and MapFile (mapfs.go).
// PORT: Go `type MapFS map[string]*MapFile` → class MapFS around a StringMap (field `m`), with
// get/set/remove/exists/keys for the Go map operations. Go map order is random; Open sorts.
// PORT: Glob, ReadLink, Lstat and fstest.TestFS are not ported (not used in scope).

// fstest.MapFile (struct used as a value: copy()).
class MapFile {
	public var Data:Null<Bytes> = null; // file content or symlink destination
	public var Mode:FileMode = ModeNone; // fs.FileInfo.Mode
	public var ModTime:Time = Time.Zero(); // fs.FileInfo.ModTime
	public var Sys:Any = null; // fs.FileInfo.Sys

	public function new(?data:Bytes, ?mode:FileMode, ?modTime:Time, ?sys:Any) {
		this.Data = data;
		if (mode != null)
			this.Mode = mode;
		if (modTime != null)
			this.ModTime = modTime;
		this.Sys = sys;
	}

	public function copy():MapFile {
		final f = new MapFile();
		f.Data = Data;
		f.Mode = Mode;
		f.ModTime = ModTime;
		f.Sys = Sys;
		return f;
	}
}

// fstest.MapFS
class MapFS implements ReadFileFS implements StatFS implements ReadDirFS implements SubFS {
	public final m:StringMap<MapFile> = new StringMap<MapFile>();

	public function new() {}

	// fsys[name] (nil when absent)
	public inline function get(name:String):Null<MapFile> {
		return m.get(name);
	}

	// fsys[name] = f
	public inline function set(name:String, f:MapFile):Void {
		m.set(name, f);
	}

	// delete(fsys, name)
	public inline function remove(name:String):Void {
		m.remove(name);
	}

	public inline function exists(name:String):Bool {
		return m.exists(name);
	}

	// for name := range fsys
	public inline function keys():Iterator<String> {
		return m.keys();
	}

	// len(fsys)
	public function length():Int {
		var n = 0;
		for (_ in m.keys())
			n++;
		return n;
	}

	// Open opens the named file after following any symbolic links.
	public function Open(name:String):ValueError<File> {
		if (!Fs.ValidPath(name)) {
			return new ValueError<File>(null, new PathError("open", name, Fs.ErrNotExist));
		}
		final realName = resolveSymlinks(name);
		if (realName == null) {
			return new ValueError<File>(null, new PathError("open", name, Fs.ErrNotExist));
		}
		var file = get(realName);
		if (file != null && file.Mode & ModeDir == 0) {
			// Ordinary file
			return new ValueError<File>(new OpenMapFile(name, new MapFileInfo(Path.Base(name), file), 0), null);
		}

		// Directory, possibly synthesized.
		// Note that file can be nil here: the map need not contain explicit parent directories
		// for all its files. But file can also be non-nil, in case the user wants to set metadata
		// for the directory explicitly. Either way, we need to construct the list of children
		// of this directory.
		var list:Null<Array<MapFileInfo>> = null;
		final need = new StringMap<Bool>();
		if (realName == ".") {
			for (fname in keys()) {
				final f = get(fname);
				final i = fname.indexOf("/");
				if (i < 0) {
					if (fname != ".") {
						if (list == null)
							list = [];
						list.push(new MapFileInfo(fname, f));
					}
				} else {
					need.set(fname.substring(0, i), true);
				}
			}
		} else {
			final prefix = realName + "/";
			for (fname in keys()) {
				final f = get(fname);
				if (StringTools.startsWith(fname, prefix)) {
					final felem = fname.substring(prefix.length);
					final i = felem.indexOf("/");
					if (i < 0) {
						if (list == null)
							list = [];
						list.push(new MapFileInfo(felem, f));
					} else {
						need.set(fname.substring(prefix.length, prefix.length + i), true);
					}
				}
			}
			// If the directory name is not in the map,
			// and there are no children of the name in the map,
			// then the directory is treated as not existing.
			if (file == null && list == null && !need.keys().hasNext()) {
				return new ValueError<File>(null, new PathError("open", name, Fs.ErrNotExist));
			}
		}
		if (list != null) {
			for (fi in list) {
				need.remove(fi.name);
			}
		}
		for (name in need.keys()) {
			if (list == null)
				list = [];
			list.push(new MapFileInfo(name, new MapFile(null, ModeDir | 365)));
		}
		if (list == null)
			list = [];
		list.sort((a, b) -> Strings.Compare(a.name, b.name));

		if (file == null) {
			file = new MapFile(null, ModeDir | 365);
		}
		var elem:String;
		if (name == ".") {
			elem = ".";
		} else {
			elem = name.substring(name.lastIndexOf("/") + 1);
		}
		return new ValueError<File>(new MapDir(name, new MapFileInfo(elem, file), list, 0), null);
	}

	// Returns null for Go's ok == false.
	function resolveSymlinks(name:String):Null<String> {
		// Fast path: if a symlink is in the map, resolve it.
		final file = get(name);
		if (file != null && file.Mode.Type() == ModeSymlink) {
			final target = Utf8.BytesToString(file.Data, 0, file.Data.length);
			if (Path.IsAbs(target)) {
				return null;
			}
			return resolveSymlinks(Path.Join([Path.Dir(name), target]));
		}

		// Check if each parent directory (starting at root) is a symlink.
		var i = 0;
		while (i < name.length) {
			final j = name.substring(i).indexOf("/");
			var dir:String;
			if (j < 0) {
				dir = name;
				i = name.length;
			} else {
				dir = name.substring(0, i + j);
				i += j;
			}
			final f = get(dir);
			if (f != null && f.Mode.Type() == ModeSymlink) {
				final target = Utf8.BytesToString(f.Data, 0, f.Data.length);
				if (Path.IsAbs(target)) {
					return null;
				}
				return resolveSymlinks(Path.Join([Path.Dir(dir), target]) + name.substring(i));
			}
			i += 1;
		}
		return Fs.ValidPath(name) ? name : null;
	}

	public function ReadFile(name:String):ValueError<Bytes> {
		return Fs.ReadFile(new FsOnly(this), name);
	}

	public function Stat(name:String):ValueError<FileInfo> {
		return Fs.Stat(new FsOnly(this), name);
	}

	public function ReadDir(name:String):ValueError<Array<DirEntry>> {
		return Fs.ReadDir(new FsOnly(this), name);
	}

	public function Sub(dir:String):ValueError<FS> {
		return Fs.Sub(new FsOnly(this), dir);
	}
}

// fsOnly is a wrapper that hides all but the fs.FS methods,
// to avoid an infinite recursion when implementing special
// methods in terms of helpers that would use them.
// (In general, implementing these methods using the package fs helpers
// is redundant and unnecessary, but having the methods may make
// MapFS exercise more code paths when used in tests.)
private class FsOnly implements FS {
	final fs:FS;

	public function new(fs:FS) {
		this.fs = fs;
	}

	public function Open(name:String):ValueError<File> {
		return fs.Open(name);
	}
}

// A mapFileInfo implements fs.FileInfo and fs.DirEntry for a given map file.
class MapFileInfo implements FileInfo implements DirEntry {
	public final name:String;
	public final f:MapFile;

	public function new(name:String, f:MapFile) {
		this.name = name;
		this.f = f;
	}

	public function Name():String {
		return Path.Base(name);
	}

	public function Size():Int {
		return f.Data == null ? 0 : f.Data.length;
	}

	public function Mode():FileMode {
		return f.Mode;
	}

	public function Type():FileMode {
		return f.Mode.Type();
	}

	public function ModTime():Time {
		return f.ModTime;
	}

	public function IsDir():Bool {
		return f.Mode & ModeDir != 0;
	}

	public function Sys():Any {
		return f.Sys;
	}

	public function Info():ValueError<FileInfo> {
		return new ValueError<FileInfo>(this, null);
	}
}

// An openMapFile is a regular (non-directory) fs.File open for reading.
class OpenMapFile implements File {
	final path:String;
	final mapFileInfo:MapFileInfo;
	var offset:Int;

	public function new(path:String, mapFileInfo:MapFileInfo, offset:Int) {
		this.path = path;
		this.mapFileInfo = mapFileInfo;
		this.offset = offset;
	}

	public function Stat():ValueError<FileInfo> {
		return new ValueError<FileInfo>(mapFileInfo, null);
	}

	public function Close():Null<Error> {
		return null;
	}

	public function Read(b:Bytes, pos:Int, len:Int):ValueError<Int> {
		final data = mapFileInfo.f.Data;
		final dataLen = data == null ? 0 : data.length;
		if (offset >= dataLen) {
			return new ValueError<Int>(0, Io.EOF);
		}
		if (offset < 0) {
			return new ValueError<Int>(0, new PathError("read", path, Fs.ErrInvalid));
		}
		var n = dataLen - offset;
		if (n > len)
			n = len;
		b.blit(pos, data, offset, n);
		offset += n;
		return new ValueError<Int>(n, null);
	}
}

// A mapDir is a directory fs.File (so also an fs.ReadDirFile) open for reading.
class MapDir implements ReadDirFile {
	final path:String;
	final mapFileInfo:MapFileInfo;
	final entry:Array<MapFileInfo>;
	var offset:Int;

	public function new(path:String, mapFileInfo:MapFileInfo, entry:Array<MapFileInfo>, offset:Int) {
		this.path = path;
		this.mapFileInfo = mapFileInfo;
		this.entry = entry;
		this.offset = offset;
	}

	public function Stat():ValueError<FileInfo> {
		return new ValueError<FileInfo>(mapFileInfo, null);
	}

	public function Close():Null<Error> {
		return null;
	}

	public function Read(b:Bytes, pos:Int, len:Int):ValueError<Int> {
		return new ValueError<Int>(0, new PathError("read", path, Fs.ErrInvalid));
	}

	public function ReadDir(count:Int):ValueError<Array<DirEntry>> {
		var n = entry.length - offset;
		if (n == 0 && count > 0) {
			return new ValueError<Array<DirEntry>>(null, Io.EOF);
		}
		if (count > 0 && n > count) {
			n = count;
		}
		final list:Array<DirEntry> = [];
		for (i in 0...n) {
			list.push(entry[offset + i]);
		}
		offset += n;
		return new ValueError<Array<DirEntry>>(list, null);
	}
}
