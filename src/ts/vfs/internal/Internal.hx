package ts.vfs.internal;

import go.Errors.Error;
import go.Fs;
import go.Tuple;
import haxe.ds.StringMap;
import haxe.io.Bytes;
import ts.tspath.Tspath;
import ts.vfs.Vfs;

// Port of internal.go (package-level funcs). Common is below.
class Internal {
	public static function RootLength(p:String):Int {
		final l = Tspath.GetEncodedRootLength(p);
		if (l == 0) {
			throw 'vfs: path ${go.Strconv.Quote(p)} is not absolute';
		} else if (l < 0) {
			return ~l;
		}
		return l;
	}

	// (rootName, rest)
	public static function SplitPath(p:String):Pair<String, String> {
		p = Tspath.NormalizePath(p);
		final l = RootLength(p);
		final rootName = p.substring(0, l);
		var rest = p.substring(l);
		rest = Tspath.RemoveTrailingDirectorySeparator(rest);
		return new Pair(rootName, rest);
	}

	// PORT: takes the bytes Go converts with unsafe.String.
	@:allow(ts.vfs)
	static function decodeBytes(b:Bytes):ValueOk<String> {
		if (b.length >= 2) {
			final b0 = b.get(0);
			final b1 = b.get(1);
			if (b0 == 0xFF && b1 == 0xFE) {
				return new ValueOk(decodeUtf16(b, 2, false), true);
			} else if (b0 == 0xFE && b1 == 0xFF) {
				return new ValueOk(decodeUtf16(b, 2, true), true);
			}
		}
		var start = 0;
		if (b.length >= 3 && b.get(0) == 0xEF && b.get(1) == 0xBB && b.get(2) == 0xBF) {
			start = 3;
		}

		return new ValueOk(go.Utf8.BytesToString(b, start, b.length - start), true);
	}

	// PORT: binary.Read into []uint16 + utf16.Decode + string(runes), done in one loop:
	// the decoded runes are appended as code points (lone surrogates → U+FFFD, as utf16.Decode).
	static function decodeUtf16(b:Bytes, offset:Int, bigEndian:Bool):String {
		final n = Std.int((b.length - offset) / 2);
		final buf = new StringBuf();
		inline function unit(i:Int):Int {
			final p = offset + 2 * i;
			return bigEndian ? (b.get(p) << 8) | b.get(p + 1) : b.get(p) | (b.get(p + 1) << 8);
		}
		var i = 0;
		while (i < n) {
			final r = unit(i);
			if (r < 0xD800 || r >= 0xE000) {
				buf.addChar(r);
			} else if (r < 0xDC00 && i + 1 < n && unit(i + 1) >= 0xDC00 && unit(i + 1) < 0xE000) {
				buf.addChar(((r - 0xD800) << 10) + (unit(i + 1) - 0xDC00) + 0x10000);
				i++;
			} else {
				buf.addChar(0xFFFD);
			}
			i++;
		}
		return buf.toString();
	}
}

class Common {
	public var RootFor:(root:String) -> Null<go.Fs.FS> = null;
	public var IsReparsePoint:Null<(path:String) -> Bool> = null;

	public function new(rootFor:(root:String) -> Null<go.Fs.FS>, ?isReparsePoint:(path:String) -> Bool) {
		this.RootFor = rootFor;
		this.IsReparsePoint = isReparsePoint;
	}

	// (fsys, rootName, rest)
	public function RootAndPath(path:String):Triple<Null<go.Fs.FS>, String, String> {
		final split = Internal.SplitPath(path);
		final rootName = split.a;
		var rest = split.b;
		if (rest == "") {
			rest = ".";
		}
		return new Triple(this.RootFor(rootName), rootName, rest);
	}

	public function Stat(path:String):Null<FileInfo> {
		final r = this.RootAndPath(path);
		final fsys = r.a;
		if (fsys == null) {
			return null;
		}
		final stat = go.Fs.Fs.Stat(fsys, r.c);
		if (stat.err != null) {
			return null;
		}
		return stat.value;
	}

	public function FileExists(path:String):Bool {
		final stat = this.Stat(path);
		return stat != null && !stat.IsDir();
	}

	public function DirectoryExists(path:String):Bool {
		final stat = this.Stat(path);
		return stat != null && stat.IsDir();
	}

	public function GetAccessibleEntries(path:String):Entries {
		final result = new Entries();
		result.Symlinks = new StringMap<Bool>();

		function addToResult(name:String, mode:FileMode, isLink:Bool):Bool {
			if (mode.IsDir()) {
				if (result.Directories == null)
					result.Directories = [];
				result.Directories.push(name);
			} else if (mode.IsRegular()) {
				if (result.Files == null)
					result.Files = [];
				result.Files.push(name);
			} else {
				return false;
			}

			if (isLink) {
				result.Symlinks.set(name, true);
			}
			return true;
		}

		final entries = this.getEntries(path);
		if (entries != null) {
			for (entry in entries) {
				final entryType = entry.Type();

				if (addToResult(entry.Name(), entryType, false)) {
					continue;
				}

				if (entryType & ModeSymlink != 0) {
					// Easy case; UNIX-like system will clearly mark symlinks.
					final stat = this.Stat(path + "/" + entry.Name());
					if (stat != null) {
						addToResult(entry.Name(), stat.Mode(), true);
					}
					continue;
				}

				if (entryType & ModeIrregular != 0 && this.IsReparsePoint != null) {
					// Could be a Windows junction or other reparse point.
					// Check using the OS-specific helper.
					final fullPath = path + "/" + entry.Name();
					if (this.IsReparsePoint(fullPath)) {
						final stat = this.Stat(fullPath);
						if (stat != null) {
							addToResult(entry.Name(), stat.Mode(), true);
						}
					}
					continue;
				}
			}
		}

		return result;
	}

	function getEntries(path:String):Null<Array<DirEntry>> {
		final r = this.RootAndPath(path);
		final fsys = r.a;
		if (fsys == null) {
			return null;
		}

		final entries = go.Fs.Fs.ReadDir(fsys, r.c);
		if (entries.err != null) {
			return null;
		}

		return entries.value;
	}

	public function WalkDir(root:String, walkFn:WalkDirFunc):Null<Error> {
		final r = this.RootAndPath(root);
		final fsys = r.a;
		final rootName = r.b;
		if (fsys == null) {
			return null;
		}
		return go.Fs.Fs.WalkDir(fsys, r.c, (path:String, d:Null<DirEntry>, err:Null<Error>) -> {
			if (path == ".") {
				path = "";
			}
			return walkFn(rootName + path, d, err);
		});
	}

	public function ReadFile(path:String):ValueOk<String> {
		final r = this.RootAndPath(path);
		final fsys = r.a;
		if (fsys == null) {
			return new ValueOk("", false);
		}

		final b = go.Fs.Fs.ReadFile(fsys, r.c);
		if (b.err != null) {
			return new ValueOk("", false);
		}

		// An invariant of any underlying filesystem is that the bytes returned
		// are immutable, otherwise anyone using the filesystem would end up
		// with data races.
		//
		// This means that we can safely convert the bytes to a string directly,
		// saving a copy.
		if (b.value.length == 0) {
			return new ValueOk("", true);
		}

		return Internal.decodeBytes(b.value);
	}
}
