package ts.sourcemap;

import haxe.ds.StringMap;
import ts.sourcemap.Sourcemap.*;

// --- generator.go --- (types and methods; package-level consts and funcs are in Sourcemap.hx)

@:allow(ts.sourcemap)
class Generator {
	var pathOptions:ComparePathsOptions = new ComparePathsOptions();
	var file:String = "";
	var sourceRoot:String = "";
	var sourcesDirectoryPath:String = "";
	var rawSources:Array<String> = null;
	var sources:Array<String> = null;
	var sourceToSourceIndexMap:StringMap<SourceIndex> = null;
	// PORT: pointer — Go `[]*string` → Array<Null<String>> (nil → null).
	var sourcesContent:Array<Null<String>> = null;
	var names:Array<String> = null;
	var nameToNameIndexMap:StringMap<NameIndex> = null;
	var mappings:StringBuf = new StringBuf();
	var lastGeneratedLine:Int = 0;
	var lastGeneratedCharacter:UTF16Offset = 0;
	var lastSourceIndex:SourceIndex = 0;
	var lastSourceLine:Int = 0;
	var lastSourceCharacter:UTF16Offset = 0;
	var lastNameIndex:NameIndex = 0;
	var hasLast:Bool = false;
	var pendingGeneratedLine:Int = 0;
	var pendingGeneratedCharacter:UTF16Offset = 0;
	var pendingSourceIndex:SourceIndex = 0;
	var pendingSourceLine:Int = 0;
	var pendingSourceCharacter:UTF16Offset = 0;
	var pendingNameIndex:NameIndex = 0;
	var hasPending:Bool = false;
	var hasPendingSource:Bool = false;
	var hasPendingName:Bool = false;

	public function new() {}

	public function Sources():Array<String> {
		return rawSources;
	}

	// Adds a source to the source map
	public function AddSource(fileName:String):SourceIndex {
		final source = Tspath.GetRelativePathToDirectoryOrUrl(sourcesDirectoryPath, fileName, true, /*isAbsolutePathAnUrl*/
			pathOptions);

		var sourceIndex:SourceIndex = 0;
		final found = sourceToSourceIndexMap != null && sourceToSourceIndexMap.exists(source);
		if (found) {
			sourceIndex = sourceToSourceIndexMap.get(source);
		} else {
			sourceIndex = Core.len(sources);
			if (sources == null)
				sources = [];
			sources.push(source);
			if (rawSources == null)
				rawSources = [];
			rawSources.push(fileName);
			if (sourceToSourceIndexMap == null) {
				sourceToSourceIndexMap = new StringMap<SourceIndex>();
			}
			sourceToSourceIndexMap.set(source, sourceIndex);
		}

		return sourceIndex;
	}

	// Sets the content for a source
	public function SetSourceContent(sourceIndex:SourceIndex, content:String):Null<Error> {
		if (sourceIndex < 0 || sourceIndex >= Core.len(sources)) {
			return Errors.New("sourceIndex is out of range");
		}
		while (Core.len(sourcesContent) <= sourceIndex) {
			if (sourcesContent == null)
				sourcesContent = [];
			sourcesContent.push(null);
		}
		sourcesContent[sourceIndex] = content;
		return null;
	}

	// Declares a name in the source map, returning the index of the name
	public function AddName(name:String):NameIndex {
		var nameIndex:NameIndex = 0;
		final found = nameToNameIndexMap != null && nameToNameIndexMap.exists(name);
		if (found) {
			nameIndex = nameToNameIndexMap.get(name);
		} else {
			nameIndex = Core.len(names);
			if (names == null)
				names = [];
			names.push(name);
			if (nameToNameIndexMap == null) {
				nameToNameIndexMap = new StringMap<NameIndex>();
			}
			nameToNameIndexMap.set(name, nameIndex);
		}
		return nameIndex;
	}

	function isNewGeneratedPosition(generatedLine:Int, generatedCharacter:UTF16Offset):Bool {
		return !hasPending || pendingGeneratedLine != generatedLine || pendingGeneratedCharacter != generatedCharacter;
	}

	function isBacktrackingSourcePosition(sourceIndex:SourceIndex, sourceLine:Int, sourceCharacter:UTF16Offset):Bool {
		return sourceIndex != sourceIndexNotSet
			&& sourceLine != notSet
			&& sourceCharacter != notSetUTF16
			&& pendingSourceIndex == sourceIndex
			&& (pendingSourceLine > sourceLine || pendingSourceLine == sourceLine && pendingSourceCharacter > sourceCharacter);
	}

	function shouldCommitMapping():Bool {
		return hasPending
			&& (!hasLast
				|| lastGeneratedLine != pendingGeneratedLine
				|| lastGeneratedCharacter != pendingGeneratedCharacter
				|| lastSourceIndex != pendingSourceIndex
				|| lastSourceLine != pendingSourceLine
				|| lastSourceCharacter != pendingSourceCharacter
				|| lastNameIndex != pendingNameIndex);
	}

	function appendMappingCharCode(charCode:Int):Void {
		Utf16.WriteRune(mappings, charCode);
	}

	function appendBase64VLQ(inValue:Int):Void {
		// Add a new least significant bit that has the sign of the value.
		// if negative number the least significant bit that gets added to the number has value 1
		// else least significant bit value that gets added is 0
		// eg. -1 changes to binary : 01 [1] => 3
		//     +1 changes to binary : 01 [0] => 2
		if (inValue < 0) {
			inValue = ((-inValue) << 1) + 1;
		} else {
			inValue = inValue << 1;
		}

		// Encode 5 bits at a time starting from least significant bits
		while (true) {
			var currentDigit = inValue & 31; // 11111
			inValue = inValue >> 5;
			if (inValue > 0) {
				// There are still more digits to decode, set the msb (6th bit)
				currentDigit = currentDigit | 32;
			}
			appendMappingCharCode(base64FormatEncode(currentDigit));
			if (inValue <= 0) {
				break;
			}
		}
	}

	function commitPendingMapping():Void {
		if (!shouldCommitMapping()) {
			return;
		}

		// Line/Comma delimiters
		if (lastGeneratedLine < pendingGeneratedLine) {
			// Emit line delimiters
			while (true) {
				appendMappingCharCode(';'.code);
				lastGeneratedLine++;
				if (lastGeneratedLine >= pendingGeneratedLine) {
					break;
				}
			}
			// Only need to set this once
			lastGeneratedCharacter = 0;
		} else {
			if (lastGeneratedLine != pendingGeneratedLine) {
				// panic rather than error as an invariant has been violated
				throw "generatedLine cannot backtrack";
			}
			// Emit comma to separate the entry
			if (hasLast) {
				appendMappingCharCode(','.code);
			}
		}

		// 1. Relative generated character
		appendBase64VLQ(pendingGeneratedCharacter - lastGeneratedCharacter);
		lastGeneratedCharacter = pendingGeneratedCharacter;

		if (hasPendingSource) {
			// 2. Relative sourceIndex
			appendBase64VLQ(pendingSourceIndex - lastSourceIndex);
			lastSourceIndex = pendingSourceIndex;

			// 3. Relative source line
			appendBase64VLQ(pendingSourceLine - lastSourceLine);
			lastSourceLine = pendingSourceLine;

			// 4. Relative source character
			appendBase64VLQ(pendingSourceCharacter - lastSourceCharacter);
			lastSourceCharacter = pendingSourceCharacter;

			if (hasPendingName) {
				// 5. Relative nameIndex
				appendBase64VLQ(pendingNameIndex - lastNameIndex);
				lastNameIndex = pendingNameIndex;
			}
		}

		hasLast = true;
	}

	function addMapping(generatedLine:Int, generatedCharacter:UTF16Offset, sourceIndex:SourceIndex, sourceLine:Int, sourceCharacter:UTF16Offset,
			nameIndex:NameIndex):Void {
		if (isNewGeneratedPosition(generatedLine, generatedCharacter) || isBacktrackingSourcePosition(sourceIndex, sourceLine, sourceCharacter)) {
			commitPendingMapping();
			pendingGeneratedLine = generatedLine;
			pendingGeneratedCharacter = generatedCharacter;
			hasPendingSource = false;
			hasPendingName = false;
			hasPending = true;
		}

		if (sourceIndex != sourceIndexNotSet && sourceLine != notSet && sourceCharacter != notSetUTF16) {
			pendingSourceIndex = sourceIndex;
			pendingSourceLine = sourceLine;
			pendingSourceCharacter = sourceCharacter;
			hasPendingSource = true;
			if (nameIndex != nameIndexNotSet) {
				pendingNameIndex = nameIndex;
				hasPendingName = true;
			}
		}
	}

	// Adds a mapping without source information
	public function AddGeneratedMapping(generatedLine:Int, generatedCharacter:UTF16Offset):Null<Error> {
		if (generatedLine < pendingGeneratedLine) {
			return Errors.New("generatedLine cannot backtrack");
		}
		if (generatedCharacter < 0) {
			return Errors.New("generatedCharacter cannot be negative");
		}
		addMapping(generatedLine, generatedCharacter, sourceIndexNotSet, notSet /*sourceLine*/, notSetUTF16 /*sourceCharacter*/, nameIndexNotSet);
		return null;
	}

	// Adds a mapping with source information
	public function AddSourceMapping(generatedLine:Int, generatedCharacter:UTF16Offset, sourceIndex:SourceIndex, sourceLine:Int,
			sourceCharacter:UTF16Offset):Null<Error> {
		if (generatedLine < pendingGeneratedLine) {
			return Errors.New("generatedLine cannot backtrack");
		}
		if (generatedCharacter < 0) {
			return Errors.New("generatedCharacter cannot be negative");
		}
		if (sourceIndex < 0 || sourceIndex >= Core.len(sources)) {
			return Errors.New("sourceIndex is out of range");
		}
		if (sourceLine < 0) {
			return Errors.New("sourceLine cannot be negative");
		}
		if (sourceCharacter < 0) {
			return Errors.New("sourceCharacter cannot be negative");
		}
		addMapping(generatedLine, generatedCharacter, sourceIndex, sourceLine, sourceCharacter, nameIndexNotSet);
		return null;
	}

	// Adds a mapping with source and name information
	public function AddNamedSourceMapping(generatedLine:Int, generatedCharacter:UTF16Offset, sourceIndex:SourceIndex, sourceLine:Int,
			sourceCharacter:UTF16Offset, nameIndex:NameIndex):Null<Error> {
		if (generatedLine < pendingGeneratedLine) {
			return Errors.New("generatedLine cannot backtrack");
		}
		if (generatedCharacter < 0) {
			return Errors.New("generatedCharacter cannot be negative");
		}
		if (sourceIndex < 0 || sourceIndex >= Core.len(sources)) {
			return Errors.New("sourceIndex is out of range");
		}
		if (sourceLine < 0) {
			return Errors.New("sourceLine cannot be negative");
		}
		if (sourceCharacter < 0) {
			return Errors.New("sourceCharacter cannot be negative");
		}
		if (nameIndex < 0 || nameIndex >= Core.len(names)) {
			return Errors.New("nameIndex is out of range");
		}
		addMapping(generatedLine, generatedCharacter, sourceIndex, sourceLine, sourceCharacter, nameIndex);
		return null;
	}

	// Gets the source map as a `RawSourceMap` object
	public function RawSourceMap():RawSourceMap {
		commitPendingMapping();
		var sources = Slices.Clone(this.sources);
		if (sources == null) {
			sources = [];
		}
		var names = Slices.Clone(this.names);
		if (names == null) {
			names = [];
		}
		final m = new RawSourceMap();
		m.Version = 3;
		m.File = file;
		m.SourceRoot = sourceRoot;
		m.Sources = sources;
		m.Names = names;
		m.Mappings = mappings.toString();
		m.SourcesContent = Slices.Clone(sourcesContent);
		return m;
	}

	function bytes():String {
		// PORT: Go json.Marshal (reflection, struct tags) → RawSourceMap.marshalJSON, same output.
		return RawSourceMap().marshalJSON();
	}

	// Gets the string representation of the source map
	public function String():String {
		return bytes();
	}

	public function Base64DataURL():String {
		final prefix = "data:application/json;base64,";
		final data = bytes();
		final sb = new StringBuf();
		sb.add(prefix);
		// PORT: Go streams the UTF-8 bytes through a base64 encoder; here the UTF-8 bytes of the string.
		sb.add(Base64.StdEncoding.EncodeToString(haxe.io.Bytes.ofString(data, UTF8)));
		return sb.toString();
	}
}

@:allow(ts.sourcemap)
class RawSourceMap {
	public var Version:Int = 0; // json:"version"
	public var File:String = ""; // json:"file"
	public var SourceRoot:String = ""; // json:"sourceRoot"
	public var Sources:Array<String> = null; // json:"sources"
	public var Names:Array<String> = null; // json:"names"
	public var Mappings:String = ""; // json:"mappings"
	public var SourcesContent:Array<Null<String>> = null; // json:"sourcesContent,omitzero"

	public function new() {}

	// PORT: Go json.Marshal of the struct (go-json-experiment, AllowInvalidUTF8): fields in declaration
	// order, `omitzero` drops a nil SourcesContent, a nil slice is `[]`, a nil *string is `null`.
	function marshalJSON():String {
		final b = new StringBuf();
		b.add('{"version":');
		b.add(Version);
		b.add(',"file":');
		appendJSONString(b, File);
		b.add(',"sourceRoot":');
		appendJSONString(b, SourceRoot);
		b.add(',"sources":');
		appendJSONStrings(b, Sources);
		b.add(',"names":');
		appendJSONStrings(b, Names);
		b.add(',"mappings":');
		appendJSONString(b, Mappings);
		if (SourcesContent != null) {
			b.add(',"sourcesContent":');
			appendJSONStrings(b, SourcesContent);
		}
		b.add("}");
		return b.toString();
	}

	static function appendJSONStrings(b:StringBuf, values:Array<Null<String>>):Void {
		b.add("[");
		if (values != null) {
			for (i in 0...values.length) {
				if (i > 0)
					b.add(",");
				final v = values[i];
				if (v == null)
					b.add("null");
				else
					appendJSONString(b, v);
			}
		}
		b.add("]");
	}

	// PORT: jsonwire.AppendQuote with the default flags: escapes '"', '\\' and control characters
	// (\b \f \n \r \t, others \u00xx); '<', '>', '&', U+2028 and U+2029 stay as they are. Invalid UTF-8
	// becomes U+FFFD; the UTF-16 analogue is a lone surrogate.
	static function appendJSONString(b:StringBuf, s:String):Void {
		b.add('"');
		var i = 0;
		var start = 0;
		final n = s.length;
		while (i < n) {
			final c = StringTools.fastCodeAt(s, i);
			if (c >= 0x20 && c != '"'.code && c != '\\'.code && !Utf16.IsSurrogate(c)) {
				i++;
				continue;
			}
			if (Utf16.IsSurrogate(c)) {
				final r = Utf16.DecodeRuneInString(s, i);
				if (r != Utf16.RuneError) {
					i += 2; // valid pair
					continue;
				}
			}
			b.add(s.substring(start, i));
			switch (c) {
				case '"'.code, '\\'.code:
					b.addChar('\\'.code);
					b.addChar(c);
				case 0x08:
					b.add("\\b");
				case 0x0C:
					b.add("\\f");
				case '\n'.code:
					b.add("\\n");
				case '\r'.code:
					b.add("\\r");
				case '\t'.code:
					b.add("\\t");
				default:
					if (Utf16.IsSurrogate(c)) {
						b.addChar(Utf16.RuneError);
					} else {
						b.add("\\u00");
						b.add(StringTools.hex(c, 2).toLowerCase());
					}
			}
			i++;
			start = i;
		}
		b.add(s.substring(start, n));
		b.add('"');
	}
}
