package ts.execute.tsctests;

import go.Fs.FileMode;
import go.Time;
import ts.collections.Syncset;
import ts.vfs.iovfs.Iofs.FsWithSys;
import ts.vfs.vfstest.Vfstest.MapFS;

// Port of internal/testutil/fsbaselineutil/differ.go.
// PORT: lives next to its only user (tsctests) instead of test/ts/testutil/fsbaselineutil.
class DiffEntry {
	public var Content:String = "";
	public var MTime:Time = Time.Zero();
	public var IsWritten:Bool = false;
	public var SymlinkTarget:String = "";

	public function new() {}
}

class Snapshot {
	public var Snap:StringMap<DiffEntry> = null;
	public var DefaultLibs:Null<SyncSet<String>> = null;

	public function new() {}
}

class FSDiffer {
	public var FS:FsWithSys = null;
	public var DefaultLibs:Null<() -> Null<SyncSet<String>>> = null;
	// PORT: Go `*collections.SyncSet[string]` pointing at testFs.writtenFiles; Go resets the pointee
	// (`*d.WrittenFiles = SyncSet{}`), so this is a getter/setter pair. // PORT: pointer
	public var getWrittenFiles:() -> SyncSet<String> = null;
	public var setWrittenFiles:(SyncSet<String>) -> Void = null;

	var serializedDiff:Null<Snapshot> = null;

	public function new() {}

	public function MapFs():MapFS {
		return cast this.FS.FSys();
	}

	public function SerializedDiff():Null<Snapshot> {
		return this.serializedDiff;
	}

	public function BaselineFSwithDiff(baseline:Builder):Void {
		// todo: baselines the entire fs, possibly doesn't correctly diff all cases of emitted files, since emit isn't fully implemented and doesn't always emit the same way as strada
		final snap = new StringMap<DiffEntry>();

		final diffs = new StringMap<String>();

		for (path => file in this.MapFs().Entries()) {
			if ((file.Mode & ModeSymlink) != 0) {
				final r = this.MapFs().GetTargetOfSymlink(path);
				if (!r.ok) {
					throw "Failed to resolve symlink target: " + path;
				}
				final newEntry = new DiffEntry();
				newEntry.SymlinkTarget = r.value;
				snap.set(path, newEntry);
				this.addFsEntryDiff(diffs, newEntry, path);
				continue;
			} else if (file.Mode.IsRegular()) {
				final content = Fsbaselineutil.SanitizeInternalSymbolName(go.Utf8.BytesToString(file.Data, 0, file.Data.length));
				final newEntry = new DiffEntry();
				newEntry.Content = content;
				newEntry.MTime = file.ModTime;
				newEntry.IsWritten = this.getWrittenFiles().Has(path);
				snap.set(path, newEntry);
				this.addFsEntryDiff(diffs, newEntry, path);
			}
		}
		if (this.serializedDiff != null) {
			for (path in this.serializedDiff.Snap.keys()) {
				if (this.MapFs().GetFileInfo(path) == null) {
					// report deleted
					this.addFsEntryDiff(diffs, null, path);
				}
			}
		}
		final defaultLibs = new SyncSet<String>();
		if (this.DefaultLibs != null && this.DefaultLibs() != null) {
			this.DefaultLibs().Range(function(libPath:String):Bool {
				defaultLibs.Add(libPath);
				return true;
			});
		}
		final s = new Snapshot();
		s.Snap = snap;
		s.DefaultLibs = defaultLibs;
		this.serializedDiff = s;
		final diffKeys = [for (k in diffs.keys()) k];
		diffKeys.sort(go.Strings.Compare);
		for (path in diffKeys) {
			baseline.WriteString("//// [" + path + "] " + diffs.get(path) + "\n");
		}
		baseline.WriteString("\n");
		this.setWrittenFiles(new SyncSet<String>()); // Reset written files after baseline
	}

	function addFsEntryDiff(diffs:StringMap<String>, newDirContent:Null<DiffEntry>, path:String):Void {
		var oldDirContent:Null<DiffEntry> = null;
		var defaultLibs:Null<SyncSet<String>> = null;
		if (this.serializedDiff != null) {
			oldDirContent = this.serializedDiff.Snap.get(path);
			defaultLibs = this.serializedDiff.DefaultLibs;
		}
		// todo handle more cases of fs changes
		if (oldDirContent == null) {
			if (this.DefaultLibs == null || this.DefaultLibs() == null || !this.DefaultLibs().Has(path)) {
				if (newDirContent.SymlinkTarget != "") {
					diffs.set(path, "-> " + newDirContent.SymlinkTarget + " *new*");
				} else {
					diffs.set(path, "*new* \n" + newDirContent.Content);
				}
			}
		} else if (newDirContent == null) {
			diffs.set(path, "*deleted*");
		} else if (newDirContent.Content != oldDirContent.Content) {
			diffs.set(path, "*modified* \n" + newDirContent.Content);
		} else if (newDirContent.IsWritten) {
			diffs.set(path, "*rewrite with same content*");
		} else if (!newDirContent.MTime.Equal(oldDirContent.MTime)) {
			diffs.set(path, "*mTime changed*");
		} else if (defaultLibs != null
			&& defaultLibs.Has(path)
			&& this.DefaultLibs != null
			&& this.DefaultLibs() != null
			&& !this.DefaultLibs().Has(path)) {
			// Lib file that was read
			diffs.set(path, "*Lib*\n" + newDirContent.Content);
		}
	}

	// PORT: ChangedPaths (FileChange) is only used by watch mode; not ported.
}

class Fsbaselineutil {
	// Replaces internal symbol names of shape �@symbolName@123 with �@symbolName@<symbolId>
	// // to avoid baselining differences in symbol ids, which can change between runs.
	// PORT: regexp `\x{FFFD}@[^@]+@[0-9]+` → hand loop. Go's regexp also matches an invalid UTF-8
	// byte as \x{FFFD}: the internal symbol prefix is the byte 0xFE in Go and U+FFFE in the Haxe port
	// (ast.InternalSymbolNamePrefix), so both start a match. In Go that byte already reaches the
	// baseline text as U+FFFD (the reference files contain U+FFFD), so a U+FFFE prefix is written as U+FFFD.
	public static function SanitizeInternalSymbolName(s:String):String {
		if (s.indexOf("\u{FFFD}@") < 0 && s.indexOf("\u{FFFE}@") < 0) {
			return s;
		}
		final b = new StringBuf();
		var i = 0;
		final n = s.length;
		while (i < n) {
			final a1 = s.indexOf("\u{FFFD}@", i);
			final a2 = s.indexOf("\u{FFFE}@", i);
			final start = a1 < 0 ? a2 : (a2 < 0 ? a1 : (a1 < a2 ? a1 : a2));
			if (start < 0)
				break;
			// [^@]+ then @ then [0-9]+
			var j = start + 2;
			while (j < n && StringTools.fastCodeAt(s, j) != "@".code)
				j++;
			var matched = false;
			var end = -1;
			if (j > start + 2 && j < n) {
				var k = j + 1;
				while (k < n && StringTools.fastCodeAt(s, k) >= "0".code && StringTools.fastCodeAt(s, k) <= "9".code)
					k++;
				if (k > j + 1) {
					matched = true;
					end = k;
				}
			}
			if (!matched) {
				b.add(s.substring(i, start + 1));
				i = start + 1;
				continue;
			}
			b.add(s.substring(i, start));
			b.add("\u{FFFD}");
			b.add(s.substring(start + 1, j));
			b.add("@<symbolId>");
			i = end;
		}
		b.add(s.substring(i));
		return b.toString();
	}
}
