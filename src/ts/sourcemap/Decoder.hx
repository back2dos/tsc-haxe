package ts.sourcemap;

import ts.sourcemap.Sourcemap.*;

// --- decoder.go --- (types and methods; package-level consts and funcs are in Sourcemap.hx)

class Mapping {
	public var GeneratedLine:Int = 0;
	public var GeneratedCharacter:UTF16Offset = 0;
	public var SourceIndex:SourceIndex = 0;
	public var SourceLine:Int = 0;
	public var SourceCharacter:UTF16Offset = 0;
	public var NameIndex:NameIndex = 0;

	public function new() {}

	public function Equals(other:Mapping):Bool {
		return this == other
			|| GeneratedLine == other.GeneratedLine
			&& GeneratedCharacter == other.GeneratedCharacter
			&& SourceIndex == other.SourceIndex
			&& SourceLine == other.SourceLine
			&& SourceCharacter == other.SourceCharacter
			&& NameIndex == other.NameIndex;
	}

	public function IsSourceMapping():Bool {
		return SourceIndex != MissingSource && SourceLine != MissingLineOrColumn && SourceCharacter != MissingUTF16Column;
	}
}

@:allow(ts.sourcemap)
class MappingsDecoder {
	var mappings:String = "";
	var done:Bool = false;
	var pos:Int = 0;
	var generatedLine:Int = 0;
	var generatedCharacter:UTF16Offset = 0;
	var sourceIndex:SourceIndex = 0;
	var sourceLine:Int = 0;
	var sourceCharacter:UTF16Offset = 0;
	var nameIndex:NameIndex = 0;
	var error:Null<Error> = null;
	var mappingArena:Arena<Mapping> = new Arena<Mapping>(() -> new Mapping());

	public function new() {}

	public function MappingsString():String {
		return mappings;
	}

	public function Pos():Int {
		return pos;
	}

	public function Error():Null<Error> {
		return error;
	}

	public function State():Mapping {
		return captureMapping(true /*hasSource*/, true /*hasName*/);
	}

	// PORT: Go iter.Seq[*Mapping] → Iterator<Mapping>.
	public function Values():Iterator<Mapping> {
		return new MappingsDecoderValues(this);
	}

	// PORT: (value, done) → Pair (a = value, b = done).
	public function Next():Pair<Mapping, Bool> {
		while (!done && pos < mappings.length) {
			final ch = StringTools.fastCodeAt(mappings, pos);
			if (ch == ';'.code) {
				// new line
				generatedLine++;
				generatedCharacter = 0;
				pos++;
				continue;
			}

			if (ch == ','.code) {
				// Next entry is on same line - no action needed
				pos++;
				continue;
			}

			var hasSource = false;
			var hasName = false;
			generatedCharacter += base64VLQFormatDecode();
			if (hasReportedError()) {
				return stopIterating();
			}
			if (generatedCharacter < 0) {
				return setErrorAndStopIterating("Invalid generatedCharacter found");
			}

			if (!isSourceMappingSegmentEnd()) {
				hasSource = true;

				sourceIndex += base64VLQFormatDecode();
				if (hasReportedError()) {
					return stopIterating();
				}
				if (sourceIndex < 0) {
					return setErrorAndStopIterating("Invalid sourceIndex found");
				}
				if (isSourceMappingSegmentEnd()) {
					return setErrorAndStopIterating("Unsupported Format: No entries after sourceIndex");
				}

				sourceLine += base64VLQFormatDecode();
				if (hasReportedError()) {
					return stopIterating();
				}
				if (sourceLine < 0) {
					return setErrorAndStopIterating("Invalid sourceLine found");
				}
				if (isSourceMappingSegmentEnd()) {
					return setErrorAndStopIterating("Unsupported Format: No entries after sourceLine");
				}

				sourceCharacter += base64VLQFormatDecode();
				if (hasReportedError()) {
					return stopIterating();
				}
				if (sourceCharacter < 0) {
					return setErrorAndStopIterating("Invalid sourceCharacter found");
				}

				if (!isSourceMappingSegmentEnd()) {
					hasName = true;
					nameIndex += base64VLQFormatDecode();
					if (hasReportedError()) {
						return stopIterating();
					}
					if (nameIndex < 0) {
						return setErrorAndStopIterating("Invalid nameIndex found");
					}

					if (!isSourceMappingSegmentEnd()) {
						return setErrorAndStopIterating("Unsupported Error Format: Entries after nameIndex");
					}
				}
			}

			return new Pair(captureMapping(hasSource, hasName), false);
		}

		return stopIterating();
	}

	function captureMapping(hasSource:Bool, hasName:Bool):Mapping {
		final mapping = mappingArena.New();
		mapping.GeneratedLine = generatedLine;
		mapping.GeneratedCharacter = generatedCharacter;
		mapping.SourceIndex = Core.IfElse(hasSource, sourceIndex, MissingSource);
		mapping.SourceLine = Core.IfElse(hasSource, sourceLine, MissingLineOrColumn);
		mapping.SourceCharacter = Core.IfElse(hasSource, sourceCharacter, MissingUTF16Column);
		mapping.NameIndex = Core.IfElse(hasName, nameIndex, MissingName);
		return mapping;
	}

	function stopIterating():Pair<Mapping, Bool> {
		done = true;
		return new Pair<Mapping, Bool>(null, true);
	}

	function setError(err:String):Void {
		error = Errors.New(err);
	}

	function setErrorAndStopIterating(err:String):Pair<Mapping, Bool> {
		setError(err);
		return stopIterating();
	}

	function hasReportedError():Bool {
		return error != null;
	}

	function isSourceMappingSegmentEnd():Bool {
		return pos == mappings.length || StringTools.fastCodeAt(mappings, pos) == ','.code || StringTools.fastCodeAt(mappings, pos) == ';'.code;
	}

	function base64VLQFormatDecode():Int {
		var moreDigits = true;
		var shiftCount = 0;
		var value = 0;
		while (moreDigits) {
			if (pos >= mappings.length) {
				setError("Error in decoding base64VLQFormatDecode, past the mapping string");
				return -1;
			}

			// 6 digit number
			final currentByte = base64FormatDecode(StringTools.fastCodeAt(mappings, pos));
			if (currentByte == -1) {
				setError("Invalid character in VLQ");
				return -1;
			}

			// If msb is set, we still have more bits to continue
			moreDigits = (currentByte & 32) != 0;

			// least significant 5 bits are the next msbs in the final value.
			// PORT: Go int is 64-bit; Int is 32-bit (values fit: positions are 32-bit, PORTING.md §3).
			value = value | ((currentByte & 31) << shiftCount);
			shiftCount += 5;
			pos++;
		}

		// Least significant bit if 1 represents negative and rest of the msb is actual absolute value
		if ((value & 1) == 0) {
			// + number
			value = value >> 1;
		} else {
			// - number
			value = value >> 1;
			value = -value;
		}

		return value;
	}
}

// PORT: the iterator behind MappingsDecoder.Values() (Go: a range-over-func closure).
private class MappingsDecoderValues {
	final d:MappingsDecoder;
	var nextValue:Pair<Mapping, Bool> = null;

	public function new(d:MappingsDecoder) {
		this.d = d;
	}

	public function hasNext():Bool {
		if (nextValue == null) {
			nextValue = d.Next();
		}
		return !nextValue.b;
	}

	public function next():Mapping {
		hasNext();
		final value = nextValue.a;
		nextValue = null;
		return value;
	}
}
