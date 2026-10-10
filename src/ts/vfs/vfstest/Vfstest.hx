package ts.vfs.vfstest;

import go.Errors;
import go.Errors.Error;
import go.Fs.FileMode;
import go.Fs.PathError;
import go.Fs.FileInfo as FsFileInfo;
import go.Fs.File as FsFile;
import go.Fs.ReadDirFile as FsReadDirFile;
import go.Fs.DirEntry as FsDirEntry;
import go.Fstest.MapFile;
import go.Strconv;
import go.Time;
import go.Tuple;
import haxe.ds.StringMap;
import haxe.io.Bytes;
import ts.tspath.Tspath;
import ts.vfs.Vfs;
import ts.vfs.iovfs.Iofs;
import ts.vfs.iovfs.Iovfs;

// Port of vfstest.go: package-level funcs. The types follow below in this module.
// PORT: `canonicalPath` (a Go string type) → String.
// PORT: fstest.MapFS (a Go map) → go.Fstest.MapFS (see the shim header).
// PORT: sync.RWMutex locks are dropped (single-threaded port).
class Vfstest {
	// FromMap creates a new [vfs.FS] from a map of paths to file contents.
	// Those file contents may be strings, byte slices, or [fstest.MapFile]s.
	//
	// The paths must be normalized absolute paths according to the tspath package,
	// without trailing directory separators.
	// The paths must be all POSIX-style or all Windows-style, but not both.
	public static function FromMap<File>(m:Null<Map<String, File>>, useCaseSensitiveFileNames:Bool):FS {
		return FromMapWithClock(m, useCaseSensitiveFileNames, new ClockImpl(Time.Now()));
	}

	// FromMapWithClock creates a new [vfs.FS] from a map of paths to file contents.
	// Those file contents may be strings, byte slices, or [fstest.MapFile]s.
	//
	// The paths must be normalized absolute paths according to the tspath package,
	// without trailing directory separators.
	// The paths must be all POSIX-style or all Windows-style, but not both.
	public static function FromMapWithClock<File>(m:Null<Map<String, File>>, useCaseSensitiveFileNames:Bool, clock:Clock):FS {
		var posix = false;
		var windows = false;

		function checkPath(p:String) {
			if (!Tspath.IsRootedDiskPath(p)) {
				throw 'non-rooted path ${Strconv.Quote(p)}';
			}

			final normal = Tspath.RemoveTrailingDirectorySeparator(Tspath.NormalizePath(p));
			if (normal != p) {
				throw 'non-normalized path ${Strconv.Quote(p)}';
			}

			if (StringTools.startsWith(p, "/")) {
				posix = true;
			} else {
				windows = true;
			}
		}

		final mfs = new go.Fstest.MapFS();
		// Sorted creation to ensure times are always guaranteed to be in order.
		final keys:Array<String> = m == null ? [] : [for (k in m.keys()) k];
		keys.sort(comparePathsByParts);
		for (p in keys) {
			final f:Any = m.get(p);
			checkPath(p);

			var file:MapFile;
			if (Std.isOfType(f, String)) {
				file = new MapFile(go.Utf8.StringToBytes((f : String)), null, clock.Now());
			} else if (Std.isOfType(f, Bytes)) {
				file = new MapFile((f : Bytes), null, clock.Now());
			} else if (Std.isOfType(f, MapFile)) {
				final fCopy = (f : MapFile).copy();
				fCopy.ModTime = clock.Now();
				file = fCopy;
			} else {
				throw 'invalid file type ${goTypeName(f)}';
			}

			if (file.Mode & ModeSymlink != 0) {
				var target = go.Utf8.BytesToString(file.Data, 0, file.Data.length);
				checkPath(target);

				if (StringTools.startsWith(target, "/"))
					target = target.substring(1);
				final fileCopy = file.copy();
				fileCopy.Data = go.Utf8.StringToBytes(target);
				file = fileCopy;
			}

			final key = StringTools.startsWith(p, "/") ? p.substring(1) : p;
			mfs.set(key, file);
		}

		if (posix && windows) {
			throw "mixed posix and windows paths";
		}

		return Iovfs.From(convertMapFS(mfs, useCaseSensitiveFileNames, clock), useCaseSensitiveFileNames);
	}

	// PORT: Go's %T of the value, for the scalar types a caller can pass.
	static function goTypeName(v:Any):String {
		if (Std.isOfType(v, Int))
			return "int";
		if (Std.isOfType(v, Float))
			return "float64";
		if (Std.isOfType(v, Bool))
			return "bool";
		if (v == null)
			return "<nil>";
		final c = Type.getClass(v);
		return c == null ? Std.string(Type.typeof(v)) : Type.getClassName(c);
	}

	@:allow(ts.vfs.vfstest)
	static function convertMapFS(input:go.Fstest.MapFS, useCaseSensitiveFileNames:Bool, clock:Null<Clock>):MapFS {
		if (clock == null) {
			clock = new ClockImpl(Time.Now());
		}
		final m = new MapFS(new go.Fstest.MapFS(), useCaseSensitiveFileNames, clock);

		// Verify that the input is well-formed.
		final canonicalPaths = new StringMap<String>();
		for (path in input.keys()) {
			final canonical = m.getCanonicalPath(path);
			if (canonicalPaths.exists(canonical)) {
				var other = canonicalPaths.get(canonical);
				// Ensure consistent panic messages
				var p = path;
				if (go.Strings.Compare(other, p) < 0) {
					final t = p;
					p = other;
					other = t;
				}
				throw 'duplicate path: ${Strconv.Quote(p)} and ${Strconv.Quote(other)} have the same canonical path';
			}
			canonicalPaths.set(canonical, path);
		}

		// Sort the input by depth and path so we ensure parent dirs are created
		// before their children, if explicitly specified by the input.
		final inputKeys = [for (k in input.keys()) k];
		inputKeys.sort(comparePathsByParts);

		for (p in inputKeys) {
			final file = input.get(p);

			// Create all missing intermediate directories so we can attach the realpath to each of them.
			// fstest.MapFS doesn't require this as it synthesizes directories on the fly, but it's a lot
			// harder to reapply a realpath onto those when we're deep in some FileInfo method.
			final dir = dirName(p);
			if (dir != "") {
				final err = m.mkdirAll(dir, 511 /* 0o777 */);
				if (err != null) {
					throw 'failed to create intermediate directories for ${Strconv.Quote(p)}: ${err.Error()}';
				}
			}
			m.setEntry(p, m.getCanonicalPath(p), file.copy());
		}

		return m;
	}

	static function comparePathsByParts(a:String, b:String):Int {
		while (true) {
			final ai = a.indexOf("/");
			final bi = b.indexOf("/");

			if (ai < 0 || bi < 0) {
				return go.Strings.Compare(a, b);
			}

			final r = go.Strings.Compare(a.substring(0, ai), b.substring(0, bi));
			if (r != 0) {
				return r;
			}

			a = a.substring(ai + 1);
			b = b.substring(bi + 1);
		}
	}

	public static function Symlink(target:String):MapFile {
		return new MapFile(go.Utf8.StringToBytes(target), ModeSymlink);
	}

	@:allow(ts.vfs.vfstest)
	static function isBrokenSymlinkError(err:Null<Error>):Bool {
		// PORT: errors.AsType[*brokenSymlinkError]; these errors are never wrapped.
		return Std.isOfType(err, BrokenSymlinkError);
	}

	// (before, after)
	@:allow(ts.vfs.vfstest)
	static function splitPath(s:String, offset:Int):Pair<String, String> {
		final idx = s.substring(offset).indexOf("/");
		if (idx < 0) {
			return new Pair(s, "");
		}
		return new Pair(s.substring(0, idx + offset), s.substring(idx + 1 + offset));
	}

	@:allow(ts.vfs.vfstest)
	static function dirName(p:String):String {
		final dir = go.Path.Split(p).a;
		return StringTools.endsWith(dir, "/") ? dir.substring(0, dir.length - 1) : dir;
	}

	@:allow(ts.vfs.vfstest)
	static function baseName(p:String):String {
		return go.Path.Split(p).b;
	}

	@:allow(ts.vfs.vfstest)
	static function convertInfo(info:FsFileInfo):Null<FileInfo> {
		final s = info.Sys();
		if (!Std.isOfType(s, Sys_)) {
			return null;
		}
		final sys:Sys_ = cast s;
		return new FileInfo(info, sys.original, sys.realpath);
	}

	@:allow(ts.vfs.vfstest)
	static inline final umask = 18; // 0o022

	@:allow(ts.vfs.vfstest)
	static function must<T>(v:ValueError<T>):T {
		if (v.err != null) {
			throw v.err;
		}
		return v.value;
	}
}

// fmt.Errorf("...: %w", err)
// PORT: the only Errorf with %w in this file; the message is formatted by the caller.
private class WrapError implements Error implements go.Errors.Wrapper {
	final msg:String;
	final err:Error;

	public function new(msg:String, err:Error) {
		this.msg = msg;
		this.err = err;
	}

	public function Error():String {
		return msg;
	}

	public function Unwrap():Null<Error> {
		return err;
	}

	public function toString():String {
		return msg;
	}
}

class MapFS implements RealpathFS implements WritableFS {
	// keys in m are canonicalPaths
	@:allow(ts.vfs.vfstest)
	final m:go.Fstest.MapFS;

	final useCaseSensitiveFileNames:Bool;

	var symlinks:Null<StringMap<String>> = null;

	final clock:Clock;

	@:allow(ts.vfs.vfstest)
	function new(m:go.Fstest.MapFS, useCaseSensitiveFileNames:Bool, clock:Clock) {
		this.m = m;
		this.useCaseSensitiveFileNames = useCaseSensitiveFileNames;
		this.clock = clock;
	}

	@:allow(ts.vfs.vfstest)
	function getCanonicalPath(p:String):String {
		return Tspath.GetCanonicalFileName(p, this.useCaseSensitiveFileNames);
	}

	function open(p:String):ValueError<FsFile> {
		return this.m.Open(p);
	}

	function remove(path:String):Null<Error> {
		final canonical = this.getCanonicalPath(path);
		var canonicalString = canonical;
		final fileInfo = this.m.get(canonicalString);
		if (fileInfo == null) {
			// file does not exist
			return null;
		}
		this.m.remove(canonicalString);
		if (this.symlinks != null)
			this.symlinks.remove(canonical);

		if (fileInfo.Mode.IsDir()) {
			canonicalString += "/";
			// PORT: Go deletes while ranging over the map; collect the keys first.
			final keys = [for (k in this.m.keys()) k];
			for (path in keys) {
				if (StringTools.startsWith(path, canonicalString)) {
					this.m.remove(path);
					if (this.symlinks != null)
						this.symlinks.remove(path);
				}
			}
		}
		return null;
	}

	function getFollowingSymlinks(p:String):Triple<Null<MapFile>, String, Null<Error>> {
		return this.getFollowingSymlinksWorker(p, "", "");
	}

	function getFollowingSymlinksWorker(p:String, symlinkFrom:String, symlinkTo:String):Triple<Null<MapFile>, String, Null<Error>> {
		final file = this.m.get(p);
		if (file != null && file.Mode & ModeSymlink == 0) {
			return new Triple(file, p, null);
		}

		if (this.symlinks != null && this.symlinks.exists(p)) {
			final target = this.symlinks.get(p);
			return this.getFollowingSymlinksWorker(target, p, target);
		}

		// This could be a path underneath a symlinked directory.
		if (this.symlinks != null) {
			for (other in this.symlinks.keys()) {
				final target = this.symlinks.get(other);
				if (other.length < p.length && other == p.substring(0, other.length) && StringTools.fastCodeAt(p, other.length) == '/'.code) {
					return this.getFollowingSymlinksWorker(target + p.substring(other.length), other, target);
				}
			}
		}

		var err:Error = go.Fs.Fs.ErrNotExist;
		if (symlinkFrom != "") {
			err = new BrokenSymlinkError(symlinkFrom, symlinkTo);
		}
		return new Triple(null, p, err);
	}

	function set(p:String, file:MapFile):Void {
		this.m.set(p, file);
	}

	// PORT: `file fstest.MapFile` is passed by value; callers pass a fresh or copied MapFile.
	@:allow(ts.vfs.vfstest)
	function setEntry(realpath:String, canonical:String, file:MapFile):Void {
		if (realpath == "" || canonical == "") {
			throw "empty path";
		}

		file.Sys = new Sys_(file.Sys, realpath);
		this.set(canonical, file);

		if (file.Mode & ModeSymlink != 0) {
			if (this.symlinks == null) {
				this.symlinks = new StringMap<String>();
			}
			this.symlinks.set(canonical, this.getCanonicalPath(go.Utf8.BytesToString(file.Data, 0, file.Data.length)));
		}
	}

	@:allow(ts.vfs.vfstest)
	function mkdirAll(p:String, perm:FileMode):Null<Error> {
		if (p == "") {
			throw "empty path";
		}

		// Fast path; already exists.
		{
			final r = this.getFollowingSymlinks(this.getCanonicalPath(p));
			if (r.c == null) {
				if (!r.a.Mode.IsDir()) {
					return Errors.New('mkdir ${Strconv.Quote(p)}: path exists but is not a directory');
				}
				return null;
			}
		}

		var toCreate:Array<String> = [];
		var offset = 0;
		while (true) {
			final split = Vfstest.splitPath(p, offset);
			final dir = split.a;
			final rest = split.b;
			final canonical = this.getCanonicalPath(dir);
			final r = this.getFollowingSymlinks(canonical);
			final other = r.a;
			final otherPath = r.b;
			final err = r.c;
			if (err != null) {
				if (!Errors.Is(err, go.Fs.Fs.ErrNotExist)) {
					return err;
				}
				toCreate.push(dir);
			} else {
				if (!other.Mode.IsDir()) {
					return Errors.New('mkdir ${Strconv.Quote(otherPath)}: path exists but is not a directory');
				}
				if (canonical != otherPath) {
					// We have a symlinked parent, reset and start again.
					p = (cast other.Sys : Sys_).realpath + "/" + rest;
					toCreate = [];
					offset = 0;
					continue;
				}
			}
			if (rest == "") {
				break;
			}
			offset = dir.length + 1;
		}

		for (dir in toCreate) {
			this.setEntry(dir, this.getCanonicalPath(dir), new MapFile(null, ModeDir | (perm & ~Vfstest.umask), this.clock.Now()));
		}

		return null;
	}

	public function Open(name:String):ValueError<FsFile> {
		final cp = this.getFollowingSymlinks(this.getCanonicalPath(name)).b;
		final r = this.open(cp);
		if (r.err != null) {
			return new ValueError<FsFile>(null, r.err);
		}
		final f = r.value;

		final info = Vfstest.must(f.Stat());

		final newInfo = Vfstest.convertInfo(info);
		if (newInfo == null) {
			// This is a synthesized dir.
			if (name != ".") {
				throw 'unexpected synthesized dir: ${Strconv.Quote(name)}';
			}

			return new ValueError<FsFile>(new ReadDirFile(cast f, new FileInfo(info, info.Sys(), ".")), null);
		}

		if (Std.isOfType(f, FsReadDirFile)) {
			return new ValueError<FsFile>(new ReadDirFile(cast f, newInfo), null);
		}

		return new ValueError<FsFile>(new File(f, newInfo), null);
	}

	public function Realpath(name:String):ValueError<String> {
		final r = this.getFollowingSymlinks(this.getCanonicalPath(name));
		if (r.c != null) {
			return new ValueError<String>("", r.c);
		}
		return new ValueError<String>((cast r.a.Sys : Sys_).realpath, null);
	}

	public function MkdirAll(path:String, perm:FileMode):Null<Error> {
		return this.mkdirAll(path, perm);
	}

	public function AddSymlink(path:String, target:String):Void {
		final canonical = this.getCanonicalPath(path);
		this.setEntry(path, canonical, new MapFile(go.Utf8.StringToBytes(target), ModeSymlink));
	}

	public function WriteFile(path:String, data:String, perm:FileMode):Null<Error> {
		final parent = Vfstest.dirName(path);
		if (parent != "") {
			final canonical = this.getCanonicalPath(parent);
			final r = this.getFollowingSymlinks(canonical);
			if (r.c != null) {
				return new WrapError('write ${Strconv.Quote(path)}: ${r.c.Error()}', r.c);
			}
			if (!r.a.Mode.IsDir()) {
				return Errors.New('write ${Strconv.Quote(path)}: parent path exists but is not a directory');
			}
		}

		final r = this.getFollowingSymlinks(this.getCanonicalPath(path));
		final file = r.a;
		final cp = r.b;
		final err = r.c;
		if (err != null) {
			if (!Errors.Is(err, go.Fs.Fs.ErrNotExist) && !Vfstest.isBrokenSymlinkError(err)) {
				// No other errors are possible.
				throw err;
			}
		} else {
			if (!file.Mode.IsRegular()) {
				return Errors.New('write ${Strconv.Quote(path)}: path exists but is not a regular file');
			}
		}

		this.setEntry(path, cp, new MapFile(go.Utf8.StringToBytes(data), perm & ~Vfstest.umask, this.clock.Now()));

		return null;
	}

	public function AppendFile(path:String, data:String, perm:FileMode):Null<Error> {
		final parent = Vfstest.dirName(path);
		if (parent != "") {
			final canonical = this.getCanonicalPath(parent);
			final r = this.getFollowingSymlinks(canonical);
			if (r.c != null) {
				return new WrapError('append ${Strconv.Quote(path)}: ${r.c.Error()}', r.c);
			}
			if (!r.a.Mode.IsDir()) {
				return Errors.New('append ${Strconv.Quote(path)}: parent path exists but is not a directory');
			}
		}

		var existing:Null<Bytes> = null;
		var existingMode:FileMode = ModeNone;
		final r = this.getFollowingSymlinks(this.getCanonicalPath(path));
		final file = r.a;
		final cp = r.b;
		final err = r.c;
		if (err != null) {
			if (!Errors.Is(err, go.Fs.Fs.ErrNotExist) && !Vfstest.isBrokenSymlinkError(err)) {
				// No other errors are possible.
				throw err;
			}
		} else {
			if (!file.Mode.IsRegular()) {
				return Errors.New('append ${Strconv.Quote(path)}: path exists but is not a regular file');
			}
			existing = file.Data;
			existingMode = file.Mode;
		}

		final dataBytes = go.Utf8.StringToBytes(data);
		final existingLen = existing == null ? 0 : existing.length;
		final combined = Bytes.alloc(existingLen + dataBytes.length);
		if (existing != null)
			combined.blit(0, existing, 0, existingLen);
		combined.blit(existingLen, dataBytes, 0, dataBytes.length);

		var mode = existingMode;
		if (mode == 0) {
			mode = perm & ~Vfstest.umask;
		}

		this.setEntry(path, cp, new MapFile(combined, mode, this.clock.Now()));

		return null;
	}

	public function Remove(path:String):Null<Error> {
		return this.remove(path);
	}

	public function Chtimes(path:String, aTime:Time, mTime:Time):Null<Error> {
		final canonical = this.getCanonicalPath(path);
		final canonicalString = canonical;
		final fileInfo = this.m.get(canonicalString);
		if (fileInfo == null) {
			// file does not exist
			return go.Fs.Fs.ErrNotExist;
		}
		fileInfo.ModTime = mTime;
		return null;
	}

	// (target, ok)
	public function GetTargetOfSymlink(path:String):ValueOk<String> {
		if (StringTools.startsWith(path, "/"))
			path = path.substring(1);
		final canonical = this.getCanonicalPath(path);
		final canonicalString = canonical;
		final fileInfo = this.m.get(canonicalString);
		if (fileInfo != null) {
			if (fileInfo.Mode & ModeSymlink != 0) {
				return new ValueOk("/" + go.Utf8.BytesToString(fileInfo.Data, 0, fileInfo.Data.length), true);
			}
		}
		return new ValueOk("", false);
	}

	public function GetModTime(path:String):Time {
		if (StringTools.startsWith(path, "/"))
			path = path.substring(1);
		final canonical = this.getCanonicalPath(path);
		final canonicalString = canonical;
		final fileInfo = this.m.get(canonicalString);
		if (fileInfo != null) {
			return fileInfo.ModTime;
		}
		return Time.Zero();
	}

	// PORT: iter.Seq2[string, *fstest.MapFile] → a key-value iterator over a sorted snapshot.
	public function Entries():KeyValueIterator<String, MapFile> {
		final inputKeys = [for (k in this.m.keys()) k];
		inputKeys.sort(@:privateAccess Vfstest.comparePathsByParts);

		final paths:Array<String> = [];
		final files:Array<MapFile> = [];
		for (p in inputKeys) {
			final file = this.m.get(p);
			var path = (cast file.Sys : Sys_).realpath;
			if (!Tspath.PathIsAbsolute(path)) {
				path = "/" + path;
			}
			paths.push(path);
			files.push(file);
		}
		return new EntriesIterator(paths, files);
	}

	public function GetFileInfo(path:String):Null<MapFile> {
		if (StringTools.startsWith(path, "/"))
			path = path.substring(1);
		final canonical = this.getCanonicalPath(path);
		final canonicalString = canonical;
		return this.m.get(canonicalString);
	}
}

private class EntriesIterator {
	final paths:Array<String>;
	final files:Array<MapFile>;
	var i = 0;

	public function new(paths:Array<String>, files:Array<MapFile>) {
		this.paths = paths;
		this.files = files;
	}

	public function hasNext():Bool {
		return i < paths.length;
	}

	public function next():{key:String, value:MapFile} {
		final r = {key: paths[i], value: files[i]};
		i++;
		return r;
	}
}

interface Clock {
	function Now():Time;
	function SinceStart():Duration;
}

class ClockImpl implements Clock {
	final start:Time;

	public function new(start:Time) {
		this.start = start;
	}

	public function Now():Time {
		return Time.Now();
	}

	public function SinceStart():Duration {
		return Time.Since(this.start);
	}
}

// Go `sys` (renamed: Haxe has a core type Sys).
class Sys_ {
	public final original:Any;
	public final realpath:String;

	public function new(original:Any, realpath:String) {
		this.original = original;
		this.realpath = realpath;
	}
}

class BrokenSymlinkError implements Error {
	final from:String;
	final to:String;

	public function new(from:String, to:String) {
		this.from = from;
		this.to = to;
	}

	public function Error():String {
		return 'broken symlink ${Strconv.Quote(from)} -> ${Strconv.Quote(to)}';
	}

	public function toString():String {
		return Error();
	}
}

// PORT: embeds fs.FileInfo → field `FileInfo` with forwarding methods.
class FileInfo implements FsFileInfo {
	final FileInfo:FsFileInfo;
	final sys:Any;
	final realpath:String;

	public function new(fileInfo:FsFileInfo, sys:Any, realpath:String) {
		this.FileInfo = fileInfo;
		this.sys = sys;
		this.realpath = realpath;
	}

	public function Name():String {
		return Vfstest.baseName(this.realpath);
	}

	public function Sys():Any {
		return this.sys;
	}

	public function Size():Int {
		return this.FileInfo.Size();
	}

	public function Mode():FileMode {
		return this.FileInfo.Mode();
	}

	public function ModTime():Time {
		return this.FileInfo.ModTime();
	}

	public function IsDir():Bool {
		return this.FileInfo.IsDir();
	}
}

// PORT: embeds fs.File → field `File` with forwarding methods.
class File implements FsFile {
	final File:FsFile;
	final fileInfo:FileInfo;

	public function new(file:FsFile, fileInfo:FileInfo) {
		this.File = file;
		this.fileInfo = fileInfo;
	}

	public function Stat():ValueError<FsFileInfo> {
		return new ValueError<FsFileInfo>(this.fileInfo, null);
	}

	public function Read(b:Bytes, pos:Int, len:Int):ValueError<Int> {
		return this.File.Read(b, pos, len);
	}

	public function Close():Null<Error> {
		return this.File.Close();
	}
}

// PORT: embeds fs.ReadDirFile → field `ReadDirFile` with forwarding methods.
class ReadDirFile implements FsReadDirFile {
	final ReadDirFile:FsReadDirFile;
	final fileInfo:FileInfo;

	public function new(f:FsReadDirFile, fileInfo:FileInfo) {
		this.ReadDirFile = f;
		this.fileInfo = fileInfo;
	}

	public function Stat():ValueError<FsFileInfo> {
		return new ValueError<FsFileInfo>(this.fileInfo, null);
	}

	public function Read(b:Bytes, pos:Int, len:Int):ValueError<Int> {
		return this.ReadDirFile.Read(b, pos, len);
	}

	public function Close():Null<Error> {
		return this.ReadDirFile.Close();
	}

	public function ReadDir(n:Int):ValueError<Array<FsDirEntry>> {
		final r = this.ReadDirFile.ReadDir(n);
		if (r.err != null) {
			return new ValueError<Array<FsDirEntry>>(null, r.err);
		}
		final list = r.value;

		final entries:Array<FsDirEntry> = [];
		for (entry in list) {
			final info = Vfstest.must(entry.Info());
			final newInfo = Vfstest.convertInfo(info);
			if (newInfo == null) {
				throw 'unexpected synthesized dir: ${Strconv.Quote(info.Name())}';
			}
			entries.push(go.Fs.Fs.FileInfoToDirEntry(newInfo));
		}

		return new ValueError<Array<FsDirEntry>>(entries, null);
	}
}
