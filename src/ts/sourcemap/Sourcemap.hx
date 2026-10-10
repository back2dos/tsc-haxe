package ts.sourcemap;

import haxe.ds.IntMap;
import haxe.ds.StringMap;

// Port of internal/sourcemap.
// Package-level consts and funcs of all files (Go file order). Types: Decoder.hx, Generator.hx,
// Lineinfo.hx, Source.hx, SourceMapper.hx.
@:allow(ts.sourcemap)
class Sourcemap {
	// --- decoder.go ---

	public static inline final MissingSource:SourceIndex = -1;
	public static inline final MissingName:NameIndex = -1;
	public static inline final MissingLineOrColumn:Int = -1;
	public static inline final MissingUTF16Column:UTF16Offset = -1;

	public static function DecodeMappings(mappings:String):MappingsDecoder {
		final d = new MappingsDecoder();
		d.mappings = mappings;
		return d;
	}

	static function base64FormatDecode(ch:Int):Int {
		if (ch >= 'A'.code && ch <= 'Z'.code) {
			return ch - 'A'.code;
		} else if (ch >= 'a'.code && ch <= 'z'.code) {
			return ch - 'a'.code + 26;
		} else if (ch >= '0'.code && ch <= '9'.code) {
			return ch - '0'.code + 52;
		} else if (ch == '+'.code) {
			return 62;
		} else if (ch == '/'.code) {
			return 63;
		} else {
			return -1;
		}
	}

	// --- generator.go ---

	static inline final sourceIndexNotSet:SourceIndex = -1;
	static inline final nameIndexNotSet:NameIndex = -1;
	static inline final notSet:Int = -1;
	static inline final notSetUTF16:UTF16Offset = -1;

	public static function NewGenerator(file:String, sourceRoot:String, sourcesDirectoryPath:String, options:ComparePathsOptions):Generator {
		final gen = new Generator();
		gen.file = file;
		gen.sourceRoot = sourceRoot;
		gen.sourcesDirectoryPath = sourcesDirectoryPath;
		gen.pathOptions = options;
		return gen;
	}

	static function base64FormatEncode(value:Int):Int {
		if (value >= 0 && value < 26) {
			return 'A'.code + value;
		} else if (value >= 26 && value < 52) {
			return 'a'.code + value - 26;
		} else if (value >= 52 && value < 62) {
			return '0'.code + value - 52;
		} else if (value == 62) {
			return '+'.code;
		} else if (value == 63) {
			return '/'.code;
		} else {
			throw "not a base64 value";
		}
	}

	// --- lineinfo.go ---

	public static function CreateECMALineInfo(text:String, lineStarts:ECMALineStarts):ECMALineInfo {
		final li = new ECMALineInfo();
		li.text = text;
		li.lineStarts = lineStarts;
		return li;
	}

	// --- source_mapper.go ---

	static inline final missingPosition = -1;

	static function createDocumentPositionMapper(host:Host, sourceMap:RawSourceMap, mapPath:String):DocumentPositionMapper {
		final mapDirectory = Tspath.GetDirectoryPath(mapPath);
		var sourceRoot:String;
		if (sourceMap.SourceRoot != "") {
			sourceRoot = Tspath.GetNormalizedAbsolutePath(sourceMap.SourceRoot, mapDirectory);
		} else {
			sourceRoot = mapDirectory;
		}
		final generatedAbsoluteFilePath = Tspath.GetNormalizedAbsolutePath(sourceMap.File, mapDirectory);
		final sourceFileAbsolutePaths = Core.Map(sourceMap.Sources, function(source:String):String {
			return Tspath.GetNormalizedAbsolutePath(source, sourceRoot);
		});
		final useCaseSensitiveFileNames = host.UseCaseSensitiveFileNames();
		final sourceToSourceIndexMap = new StringMap<SourceIndex>();
		for (i in 0...Core.len(sourceFileAbsolutePaths)) {
			final source = sourceFileAbsolutePaths[i];
			sourceToSourceIndexMap.set(Tspath.GetCanonicalFileName(source, useCaseSensitiveFileNames), i);
		}

		var decodedMappings:Array<MappedPosition> = null;
		var generatedMappings:Array<MappedPosition> = null;
		final sourceMappings = new IntMap<Array<SourceMappedPosition>>();

		// getDecodedMappings()
		final decoder = DecodeMappings(sourceMap.Mappings);
		for (mapping in decoder.Values()) {
			// processMapping()
			var generatedPosition = -1;
			final lineInfo = host.GetECMALineInfo(generatedAbsoluteFilePath);
			if (lineInfo != null) {
				generatedPosition = Scanner.ComputePositionOfLineAndUTF16Character(lineInfo.lineStarts, mapping.GeneratedLine, mapping.GeneratedCharacter,
					lineInfo.text, true /*allowEdits*/);
			}

			var sourcePosition = -1;
			if (mapping.IsSourceMapping()) {
				final lineInfo = host.GetECMALineInfo(sourceFileAbsolutePaths[mapping.SourceIndex]);
				if (lineInfo != null) {
					final pos = Scanner.ComputePositionOfLineAndUTF16Character(lineInfo.lineStarts, mapping.SourceLine, mapping.SourceCharacter,
						lineInfo.text, true /*allowEdits*/);
					sourcePosition = pos;
				}
			}

			final m = new MappedPosition();
			m.generatedPosition = generatedPosition;
			m.sourceIndex = mapping.SourceIndex;
			m.sourcePosition = sourcePosition;
			m.nameIndex = mapping.NameIndex;
			if (decodedMappings == null)
				decodedMappings = [];
			decodedMappings.push(m);
		}
		if (decoder.Error() != null) {
			decodedMappings = null;
		}

		// getSourceMappings()
		if (decodedMappings != null) {
			for (mapping in decodedMappings) {
				if (!mapping.isSourceMappedPosition()) {
					continue;
				}
				final sourceIndex = mapping.sourceIndex;
				var list = sourceMappings.get(sourceIndex);
				if (list == null)
					list = [];
				final p = new SourceMappedPosition();
				p.generatedPosition = mapping.generatedPosition;
				p.sourceIndex = sourceIndex;
				p.sourcePosition = mapping.sourcePosition;
				p.nameIndex = mapping.nameIndex;
				list.push(p);
				sourceMappings.set(sourceIndex, list);
			}
		}
		// PORT: Go assigns map entries while ranging over the map; here over a snapshot of the keys.
		for (i in [for (k in sourceMappings.keys()) k]) {
			final list = sourceMappings.get(i);
			Slices.SortFunc(list, function(a:SourceMappedPosition, b:SourceMappedPosition):Int {
				Debug.Assert(a.sourceIndex == b.sourceIndex, "All source mappings should have the same source index");
				return a.sourcePosition - b.sourcePosition;
			});
			sourceMappings.set(i, Core.DeduplicateSorted(list, function(a:SourceMappedPosition, b:SourceMappedPosition):Bool {
				return a.generatedPosition == b.generatedPosition && a.sourceIndex == b.sourceIndex && a.sourcePosition == b.sourcePosition;
			}));
		}

		// getGeneratedMappings()
		generatedMappings = decodedMappings;
		Slices.SortFunc(generatedMappings, function(a:MappedPosition, b:MappedPosition):Int {
			return a.generatedPosition - b.generatedPosition;
		});
		generatedMappings = Core.DeduplicateSorted(generatedMappings, function(a:MappedPosition, b:MappedPosition):Bool {
			return a.generatedPosition == b.generatedPosition && a.sourceIndex == b.sourceIndex && a.sourcePosition == b.sourcePosition;
		});

		final d = new DocumentPositionMapper();
		d.useCaseSensitiveFileNames = useCaseSensitiveFileNames;
		d.sourceFileAbsolutePaths = sourceFileAbsolutePaths;
		d.sourceToSourceIndexMap = sourceToSourceIndexMap;
		d.generatedAbsoluteFilePath = generatedAbsoluteFilePath;
		d.generatedMappings = generatedMappings;
		d.sourceMappings = sourceMappings;
		return d;
	}

	public static function GetDocumentPositionMapper(host:Host, generatedFileName:String):DocumentPositionMapper {
		var mapFileName = tryGetSourceMappingURL(host, generatedFileName);
		if (mapFileName != "") {
			final r = tryParseBase64Url(mapFileName);
			final base64Object = r.a;
			if (r.b) {
				if (base64Object != "") {
					final decoded = Base64.StdEncoding.DecodeString(base64Object);
					if (decoded.err == null) {
						// PORT: Go string(decoded) → the bytes decoded as UTF-8.
						return convertDocumentToSourceMapper(host, decoded.value.toString(), generatedFileName);
					}
				}
				// Not a data URL we can parse, skip it
				mapFileName = "";
			}
		}

		var possibleMapLocations:Array<String> = [];
		if (mapFileName != "") {
			possibleMapLocations.push(mapFileName);
		}
		possibleMapLocations.push(generatedFileName + ".map");
		for (location in possibleMapLocations) {
			final mapFileName = Tspath.GetNormalizedAbsolutePath(location, Tspath.GetDirectoryPath(generatedFileName));
			final r = host.ReadFile(mapFileName);
			if (r.ok) {
				return convertDocumentToSourceMapper(host, r.value, mapFileName);
			}
		}
		return null;
	}

	static function convertDocumentToSourceMapper(host:Host, contents:String, mapFileName:String):DocumentPositionMapper {
		final sourceMap = tryParseRawSourceMap(contents);
		if (sourceMap == null || Core.len(sourceMap.Sources) == 0 || sourceMap.File == "" || sourceMap.Mappings == "") {
			// invalid map
			return null;
		}

		// Don't support source maps that contain inlined sources
		if (Core.Some(sourceMap.SourcesContent, function(s:Null<String>):Bool {
			return s != null;
		})) {
			return null;
		}

		return createDocumentPositionMapper(host, sourceMap, mapFileName);
	}

	static function tryParseRawSourceMap(contents:String):RawSourceMap {
		final sourceMap = unmarshalRawSourceMap(contents);
		if (sourceMap == null) {
			return null;
		}
		if (sourceMap.Version != 3) {
			return null;
		}
		return sourceMap;
	}

	// PORT: Go json.Unmarshal into *RawSourceMap (go-json-experiment, reflection) → haxe.Json plus
	// explicit type checks with the same results: unknown members are ignored, member names match
	// case-sensitively, JSON null leaves the Go zero value, a value of the wrong type is an error (nil).
	// Not reproduced: v2 rejects duplicate member names (haxe.Json keeps the last one).
	static function unmarshalRawSourceMap(contents:String):RawSourceMap {
		var v:Dynamic;
		try {
			v = Json.Unmarshal(contents);
		} catch (e:Dynamic) {
			return null;
		}
		final sourceMap = new RawSourceMap();
		if (v == null) {
			return sourceMap;
		}
		if (!isJSONObject(v)) {
			return null;
		}
		var ok = true;
		for (name in Reflect.fields(v)) {
			final value:Dynamic = Reflect.field(v, name);
			switch (name) {
				case "version":
					if (value == null) {
						sourceMap.Version = 0;
					} else if (Std.isOfType(value, Float) && isJSONInt(value)) {
						sourceMap.Version = Std.int(value);
					} else {
						ok = false;
					}
				case "file":
					final s = jsonString(value);
					if (s == null)
						ok = false;
					else
						sourceMap.File = s;
				case "sourceRoot":
					final s = jsonString(value);
					if (s == null)
						ok = false;
					else
						sourceMap.SourceRoot = s;
				case "mappings":
					final s = jsonString(value);
					if (s == null)
						ok = false;
					else
						sourceMap.Mappings = s;
				case "sources", "names", "sourcesContent":
					var list:Array<Null<String>> = null;
					if (value != null) {
						if (!Std.isOfType(value, Array)) {
							ok = false;
						} else {
							list = [];
							for (e in (value : Array<Dynamic>)) {
								if (name == "sourcesContent" && e == null) {
									list.push(null);
									continue;
								}
								final s = jsonString(e);
								if (s == null) {
									ok = false;
									break;
								}
								list.push(s);
							}
						}
					}
					switch (name) {
						case "sources":
							sourceMap.Sources = list;
						case "names":
							sourceMap.Names = list;
						default:
							sourceMap.SourcesContent = list;
					}
				default:
			}
			if (!ok) {
				return null;
			}
		}
		return sourceMap;
	}

	// JSON string value; JSON null is the Go zero value ""; any other type → null (error).
	static function jsonString(value:Dynamic):Null<String> {
		if (value == null) {
			return "";
		}
		if (Std.isOfType(value, std.String)) {
			return (value : String);
		}
		return null;
	}

	static function isJSONObject(v:Dynamic):Bool {
		return Reflect.isObject(v) && !Std.isOfType(v, std.String) && !Std.isOfType(v, Array);
	}

	static function isJSONInt(f:Float):Bool {
		return f == std.Math.ffloor(f) && f >= -2147483648.0 && f <= 2147483647.0;
	}

	static function tryGetSourceMappingURL(host:Host, fileName:String):String {
		final lineInfo = host.GetECMALineInfo(fileName);
		return TryGetSourceMappingURL(lineInfo);
	}

	// Equivalent to /^data:(?:application\/json;(?:charset=[uU][tT][fF]-8;)?base64,([A-Za-z0-9+/=]+)$)?/
	// PORT: (parseableUrl, isBase64Url) → Pair (a = parseableUrl, b = isBase64Url).
	static function tryParseBase64Url(url:String):Pair<String, Bool> {
		if (!StringTools.startsWith(url, "data:")) {
			return new Pair("", false);
		}
		url = url.substring("data:".length);
		if (!StringTools.startsWith(url, "application/json;")) {
			return new Pair("", true);
		}
		url = url.substring("application/json;".length);
		if (StringTools.startsWith(url, "charset=")) {
			url = url.substring("charset=".length);
			if (url.length < "utf-8;".length) {
				// PORT: Go url[:len(`utf-8;`)] panics on a shorter string.
				throw "runtime error: slice bounds out of range";
			}
			if (!Strings.EqualFold(url.substring(0, "utf-8;".length), "utf-8;")) {
				return new Pair("", true);
			}
			url = url.substring("utf-8;".length);
		}
		if (!StringTools.startsWith(url, "base64,")) {
			return new Pair("", true);
		}
		url = url.substring("base64,".length);
		for (i in 0...url.length) {
			// PORT: Go ranges over runes; all accepted characters are ASCII, so code units give the same result.
			final r = StringTools.fastCodeAt(url, i);
			if (!(Stringutil.IsASCIILetter(r) || Stringutil.IsDigit(r) || r == '+'.code || r == '/'.code || r == '='.code)) {
				return new Pair("", true);
			}
		}
		return new Pair(url, true);
	}

	// --- util.go ---

	// Tries to find the sourceMappingURL comment at the end of a file.
	public static function TryGetSourceMappingURL(lineInfo:ECMALineInfo):String {
		if (lineInfo != null) {
			var index = lineInfo.LineCount() - 1;
			while (index >= 0) {
				var line = lineInfo.LineText(index);
				line = Strings.TrimLeftFunc(line, Unicode.IsSpace);
				line = Strings.TrimRightFunc(line, Stringutil.IsLineBreak);
				if (line.length == 0) {
					index--;
					continue;
				}
				if (line.length < 4
					|| !StringTools.startsWith(line, "//")
					|| StringTools.fastCodeAt(line, 2) != '#'.code && StringTools.fastCodeAt(line, 2) != '@'.code
					|| StringTools.fastCodeAt(line, 3) != ' '.code) {
					break;
				}
				final rest = line.substring(4);
				if (StringTools.startsWith(rest, "sourceMappingURL=")) {
					final url = rest.substring("sourceMappingURL=".length);
					return Strings.TrimRightFunc(url, Unicode.IsSpace);
				}
				index--;
			}
		}
		return "";
	}
}

// --- generator.go ---
// PORT: Go `type SourceIndex int` / `type NameIndex int` → typedefs of Int (like core.UTF16Offset).
typedef SourceIndex = Int;
typedef NameIndex = Int;
