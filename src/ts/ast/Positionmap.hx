package ts.ast;

// Port of positionmap.go (types and methods; ComputePositionMap is in Ast.hx).
//
// PORT: Haxe strings are UTF-16 and the port's positions are UTF-16 offsets (PORTING.md §5). The
// map still converts between the UTF-8 byte offsets of the text (as Go sees them) and UTF-16
// code unit offsets, so it behaves like upstream (e.g. for offsets that come from Go tools).

// PositionMap provides bidirectional mapping between UTF-8 byte offsets (used by Go)
// and UTF-16 code unit offsets (used by JavaScript/TypeScript).
//
// For ASCII-only text, the two are identical. For text containing non-ASCII characters,
// the offsets diverge because multi-byte UTF-8 sequences map to different numbers of
// UTF-16 code units:
//   - U+0000..U+007F:   1 byte  in UTF-8, 1 code unit  in UTF-16
//   - U+0080..U+07FF:   2 bytes in UTF-8, 1 code unit  in UTF-16
//   - U+0800..U+FFFF:   3 bytes in UTF-8, 1 code unit  in UTF-16
//   - U+10000..U+10FFFF: 4 bytes in UTF-8, 2 code units in UTF-16 (surrogate pair)
@:allow(ts.ast)
class PositionMap {
	// asciiOnly is true if the text contains only ASCII characters,
	// meaning UTF-8 byte offsets and UTF-16 code unit offsets are identical.
	var asciiOnly:Bool = false;
	// For each multi-byte character, we store:
	//   - the UTF-8 byte offset of the character
	//   - the cumulative delta (utf8Offset - utf16Offset) at that character
	// This allows O(log n) conversion in either direction.
	//
	// entries[i].utf8Pos is the byte offset of the i-th multi-byte character.
	// entries[i].delta is the total (utf8 - utf16) difference accumulated
	// through and including the i-th multi-byte character.
	var entries:Array<PositionMapEntry> = null;

	public function new() {}

	// IsAsciiOnly returns true if the text is ASCII-only,
	// meaning UTF-8 and UTF-16 offsets are identical.
	public function IsAsciiOnly():Bool {
		return asciiOnly;
	}

	// UTF8ToUTF16 converts a UTF-8 byte offset to a UTF-16 code unit offset.
	public function UTF8ToUTF16(utf8Offset:Int):Int {
		if (asciiOnly) {
			return utf8Offset;
		}
		// Binary search: find the last entry where utf8Pos <= utf8Offset
		var lo = 0, hi = Core.len(entries);
		while (lo < hi) {
			final mid = lo + ((hi - lo) >> 1);
			if (entries[mid].utf8Pos <= utf8Offset) {
				lo = mid + 1;
			} else {
				hi = mid;
			}
		}
		if (lo == 0) {
			// Before any multi-byte character
			return utf8Offset;
		}
		return utf8Offset - entries[lo - 1].delta;
	}

	// UTF16ToUTF8 converts a UTF-16 code unit offset to a UTF-8 byte offset.
	public function UTF16ToUTF8(utf16Offset:Int):Int {
		if (asciiOnly) {
			return utf16Offset;
		}
		// We need the last entry where (utf8Pos - delta) <= utf16Offset.
		// (utf8Pos - delta) is the UTF-16 offset of that entry's character.
		var lo = 0, hi = Core.len(entries);
		while (lo < hi) {
			final mid = lo + ((hi - lo) >> 1);
			final utf16Pos = entries[mid].utf8Pos - entries[mid].delta;
			if (utf16Pos <= utf16Offset) {
				lo = mid + 1;
			} else {
				hi = mid;
			}
		}
		if (lo == 0) {
			return utf16Offset;
		}
		return utf16Offset + entries[lo - 1].delta;
	}
}

class PositionMapEntry {
	public final utf8Pos:Int; // UTF-8 byte offset AFTER this multi-byte character
	public final delta:Int; // cumulative (utf8 - utf16) offset difference after this character

	public inline function new(utf8Pos:Int, delta:Int) {
		this.utf8Pos = utf8Pos;
		this.delta = delta;
	}
}
