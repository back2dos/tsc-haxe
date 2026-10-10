package ts.testutil.harnessutil;

import ts.core.Text.TextPos;
import ts.sourcemap.Sourcemap;
import ts.sourcemap.Decoder.Mapping;
import ts.sourcemap.Decoder.MappingsDecoder;
import ts.sourcemap.Generator.RawSourceMap;
import ts.scanner.Scanner;
import ts.stringutil.Stringutil;

// Port of sourcemap_recorder.go (types and methods; CompilationResult.GetSourceMapRecord is in Harnessutil.hx).
// PORT: Go embeds strings.Builder; fmt verbs used: %s, %d only.
class WriterAggregator {
	final b = new StringBuf();

	public function new() {}

	public function WriteString(s:String):Void {
		b.add(s);
	}

	public function WriteLine(s:String):Void {
		b.add(s);
		b.add("\r\n");
	}

	public function String():String {
		return b.toString();
	}
}

class SourceMapSpanWithDecodeErrors {
	public var sourceMapSpan:Mapping = null;
	public var decodeErrors:Array<String> = null;

	public function new(sourceMapSpan:Mapping, decodeErrors:Array<String>) {
		this.sourceMapSpan = sourceMapSpan;
		this.decodeErrors = decodeErrors;
	}
}

class DecodedMapping {
	public var sourceMapSpan:Mapping = null;
	public var error:Null<Error> = null;

	public function new() {}
}

class SourceMapDecoder {
	var sourceMapMappings:String = "";
	var mappings:MappingsDecoder = null;

	public function new(sourceMap:RawSourceMap) {
		this.sourceMapMappings = sourceMap.Mappings;
		this.mappings = Sourcemap.DecodeMappings(sourceMap.Mappings);
	}

	public function decodeNextEncodedSourceMapSpan():DecodedMapping {
		final r = this.mappings.Next();
		final value = r.a;
		final done = r.b;
		if (done) {
			final mapping = new DecodedMapping();
			mapping.error = this.mappings.Error();
			mapping.sourceMapSpan = this.mappings.State();
			if (mapping.error == null) {
				mapping.error = Errors.New("No encoded entry found");
			}
			return mapping;
		}
		final m = new DecodedMapping();
		m.sourceMapSpan = value;
		return m;
	}

	public function hasCompletedDecoding():Bool {
		return this.mappings.Pos() == this.sourceMapMappings.length;
	}

	public function getRemainingDecodeString():String {
		return this.sourceMapMappings.substring(this.mappings.Pos());
	}
}

@:allow(ts.testutil.harnessutil)
class SourceMapSpanWriter {
	var sourceMapRecorder:WriterAggregator = null;
	var sourceMapSources:Array<String> = null;
	var sourceMapNames:Array<String> = null;
	var jsFile:TestFile = null;
	var jsLineMap:Array<TextPos> = null;
	var tsCode:String = "";
	var tsLineMap:Array<TextPos> = null;
	var spansOnSingleLine:Array<SourceMapSpanWithDecodeErrors> = null;
	var prevWrittenSourcePos:Int = 0;
	var nextJsLineToWrite:Int = 0;
	var spanMarkerContinues:Bool = false;
	var sourceMapDecoder:SourceMapDecoder = null;

	public function new() {}

	public static function newSourceMapSpanWriter(sourceMapRecorder:WriterAggregator, sourceMap:RawSourceMap, jsFile:TestFile):SourceMapSpanWriter {
		final writer = new SourceMapSpanWriter();
		writer.sourceMapRecorder = sourceMapRecorder;
		writer.sourceMapSources = sourceMap.Sources;
		writer.sourceMapNames = sourceMap.Names;
		writer.jsFile = jsFile;
		writer.jsLineMap = Core.ComputeECMALineStarts(jsFile.Content);
		writer.spansOnSingleLine = [];
		writer.prevWrittenSourcePos = 0;
		writer.nextJsLineToWrite = 0;
		writer.spanMarkerContinues = false;
		writer.sourceMapDecoder = new SourceMapDecoder(sourceMap);

		sourceMapRecorder.WriteLine("===================================================================");
		sourceMapRecorder.WriteLine("JsFile: " + sourceMap.File);
		sourceMapRecorder.WriteLine("mapUrl: " + Sourcemap.TryGetSourceMappingURL(Sourcemap.CreateECMALineInfo(jsFile.Content, writer.jsLineMap)));
		sourceMapRecorder.WriteLine("sourceRoot: " + sourceMap.SourceRoot);
		sourceMapRecorder.WriteLine("sources: " + (sourceMap.Sources == null ? "" : sourceMap.Sources.join(",")));
		if (Core.len(sourceMap.SourcesContent) > 0) {
			// PORT: json.Marshal([]*string)
			final content = new StringBuf();
			@:privateAccess RawSourceMap.appendJSONStrings(content, sourceMap.SourcesContent);
			sourceMapRecorder.WriteLine("sourcesContent: " + content.toString());
		}
		sourceMapRecorder.WriteLine("===================================================================");
		return writer;
	}

	function getSourceMapSpanString(mapEntry:Mapping, getAbsentNameIndex:Bool):String {
		final mapString = new StringBuf();
		mapString.add("Emitted(" + (mapEntry.GeneratedLine + 1) + ", " + (mapEntry.GeneratedCharacter + 1) + ")");
		if (mapEntry.IsSourceMapping()) {
			mapString.add(" Source(" + (mapEntry.SourceLine + 1) + ", " + (mapEntry.SourceCharacter + 1) + ") + SourceIndex(" + mapEntry.SourceIndex + ")");
			if (mapEntry.NameIndex >= 0 && mapEntry.NameIndex < Core.len(this.sourceMapNames)) {
				mapString.add(" name (" + this.sourceMapNames[mapEntry.NameIndex] + ")");
			} else {
				if (mapEntry.NameIndex != Sourcemap.MissingName || getAbsentNameIndex) {
					mapString.add(" nameIndex (" + mapEntry.NameIndex + ")");
				}
			}
		}
		return mapString.toString();
	}

	public function recordSourceMapSpan(sourceMapSpan:Mapping):Void {
		// verify the decoded span is same as the new span
		final decodeResult = this.sourceMapDecoder.decodeNextEncodedSourceMapSpan();
		var decodeErrors:Array<String> = null;
		if (decodeResult.error != null || !decodeResult.sourceMapSpan.Equals(sourceMapSpan)) {
			if (decodeResult.error != null) {
				decodeErrors = ["!!^^ !!^^ There was decoding error in the sourcemap at this location: " + decodeResult.error.Error()];
			} else {
				decodeErrors = ["!!^^ !!^^ The decoded span from sourcemap's mapping entry does not match what was encoded for this span:"];
			}
			decodeErrors.push("!!^^ !!^^ Decoded span from sourcemap's mappings entry: "
				+ this.getSourceMapSpanString(decodeResult.sourceMapSpan, true /*getAbsentNameIndex*/)
				+ " Span encoded by the emitter:"
				+ this.getSourceMapSpanString(sourceMapSpan, true /*getAbsentNameIndex*/));
		}

		if (this.spansOnSingleLine.length > 0 && this.spansOnSingleLine[0].sourceMapSpan.GeneratedLine != sourceMapSpan.GeneratedLine) {
			// On different line from the one that we have been recording till now,
			this.writeRecordedSpans();
			this.spansOnSingleLine = [];
		}
		this.spansOnSingleLine.push(new SourceMapSpanWithDecodeErrors(sourceMapSpan, decodeErrors));
	}

	public function recordNewSourceFileSpan(sourceMapSpan:Mapping, newSourceFileCode:String):Void {
		var continuesLine = false;
		if (this.spansOnSingleLine.length > 0 && this.spansOnSingleLine[0].sourceMapSpan.GeneratedCharacter == sourceMapSpan.GeneratedLine) { // !!! char == line seems like a bug in Strada?
			this.writeRecordedSpans();
			this.spansOnSingleLine = [];
			this.nextJsLineToWrite--; // walk back one line to reprint the line
			continuesLine = true;
		}

		this.recordSourceMapSpan(sourceMapSpan);

		if (this.spansOnSingleLine.length != 1) {
			throw "expected a single span";
		}

		this.sourceMapRecorder.WriteLine("-------------------------------------------------------------------");
		if (continuesLine) {
			this.sourceMapRecorder.WriteLine("emittedFile:" + this.jsFile.UnitName + " (" + (sourceMapSpan.GeneratedLine + 1) + ", "
				+ (sourceMapSpan.GeneratedCharacter + 1) + ")");
		} else {
			this.sourceMapRecorder.WriteLine("emittedFile:" + this.jsFile.UnitName);
		}
		this.sourceMapRecorder.WriteLine("sourceFile:" + this.sourceMapSources[this.spansOnSingleLine[0].sourceMapSpan.SourceIndex]);
		this.sourceMapRecorder.WriteLine("-------------------------------------------------------------------");

		this.tsLineMap = Core.ComputeECMALineStarts(newSourceFileCode);
		this.tsCode = newSourceFileCode;
		this.prevWrittenSourcePos = 0;
	}

	public function close():Void {
		// Write the lines pending on the single line
		this.writeRecordedSpans();

		if (!this.sourceMapDecoder.hasCompletedDecoding()) {
			this.sourceMapRecorder.WriteLine("!!!! **** There are more source map entries in the sourceMap's mapping than what was encoded");
			this.sourceMapRecorder.WriteLine("!!!! **** Remaining decoded string: " + this.sourceMapDecoder.getRemainingDecodeString());
		}

		// write remaining js lines
		this.writeJsFileLines(this.jsLineMap.length);
	}

	function getTextOfLine(line:Int, lineMap:Array<TextPos>, code:String):String {
		// PORT: Go indexing panics out of range (e.g. the line+1 lookup in writeRecordedSpans).
		if (line >= lineMap.length) {
			throw "runtime error: index out of range [" + line + "] with length " + lineMap.length;
		}
		final startPos = lineMap[line];
		var endPos:TextPos;
		if (line + 1 < lineMap.length) {
			endPos = lineMap[line + 1];
		} else {
			endPos = code.length;
		}
		final text = code.substring(startPos, endPos);
		if (line == 0) {
			return Stringutil.RemoveByteOrderMark(text);
		}
		// return line == 0 ? Utils.removeByteOrderMark(text) : text;
		return text;
	}

	function writeJsFileLines(endJsLine:Int):Void {
		while (this.nextJsLineToWrite < endJsLine) {
			this.sourceMapRecorder.WriteString(">>>" + this.getTextOfLine(this.nextJsLineToWrite, this.jsLineMap, this.jsFile.Content));
			this.nextJsLineToWrite++;
		}
	}

	function writeRecordedSpans():Void {
		final recordedSpanWriter = new RecordedSpanWriter(this);
		recordedSpanWriter.writeRecordedSpans();
	}
}

class RecordedSpanWriter {
	var markerIds:Array<String> = [];
	var prevEmittedCol:Int = 0;
	var w:SourceMapSpanWriter = null;

	public function new(w:SourceMapSpanWriter) {
		this.w = w;
	}

	function getMarkerId(markerIndex:Int):String {
		var markerId = "";
		if (@:privateAccess this.w.spanMarkerContinues) {
			if (markerIndex != 0) {
				throw "expected markerIndex to be 0";
			}
			markerId = "1->";
		} else {
			markerId = Std.string(markerIndex + 1);
			if (markerId.length < 2) {
				markerId += " ";
			}
			markerId += ">";
		}
		return markerId;
	}

	@:privateAccess
	function iterateSpans(fn:(currentSpan:SourceMapSpanWithDecodeErrors, index:Int) -> Void):Void {
		this.prevEmittedCol = 0;
		for (i in 0...this.w.spansOnSingleLine.length) {
			fn(this.w.spansOnSingleLine[i], i);
			this.prevEmittedCol = this.w.spansOnSingleLine[i].sourceMapSpan.GeneratedCharacter;
		}
	}

	@:privateAccess
	function writeSourceMapIndent(indentLength:Int, indentPrefix:String):Void {
		this.w.sourceMapRecorder.WriteString(indentPrefix);
		for (_ in 0...indentLength) {
			this.w.sourceMapRecorder.WriteString(" ");
		}
	}

	function writeSourceMapMarker(currentSpan:SourceMapSpanWithDecodeErrors, index:Int):Void {
		this.writeSourceMapMarkerEx(currentSpan, index, currentSpan.sourceMapSpan.GeneratedCharacter, false /*endContinues*/);
	}

	@:privateAccess
	function writeSourceMapMarkerEx(currentSpan:SourceMapSpanWithDecodeErrors, index:Int, endColumn:Int, endContinues:Bool):Void {
		final markerId = this.getMarkerId(index);
		this.markerIds.push(markerId);
		this.writeSourceMapIndent(this.prevEmittedCol, markerId);
		for (i in this.prevEmittedCol...endColumn) {
			this.w.sourceMapRecorder.WriteString("^");
		}
		if (endContinues) {
			this.w.sourceMapRecorder.WriteString("->");
		}
		this.w.sourceMapRecorder.WriteLine("");
		this.w.spanMarkerContinues = endContinues;
	}

	@:privateAccess
	function writeSourceMapSourceText(currentSpan:SourceMapSpanWithDecodeErrors, index:Int):Void {
		// Convert UTF-16 character offset from the source map to a byte position.
		final sourcePos = Scanner.ComputePositionOfLineAndUTF16Character(this.w.tsLineMap, currentSpan.sourceMapSpan.SourceLine,
			currentSpan.sourceMapSpan.SourceCharacter, this.w.tsCode, true /*allowEdits*/);
		var sourceText = "";
		if (this.w.prevWrittenSourcePos < sourcePos) {
			// Position that goes forward, get text
			sourceText = this.w.tsCode.substring(this.w.prevWrittenSourcePos, sourcePos);
		}

		// If there are decode errors, write
		if (currentSpan.decodeErrors != null)
			for (decodeError in currentSpan.decodeErrors) {
				this.writeSourceMapIndent(this.prevEmittedCol, this.markerIds[index]);
				this.w.sourceMapRecorder.WriteLine(decodeError);
			}

		final tsCodeLineMap = Core.ComputeECMALineStarts(sourceText);
		for (i in 0...tsCodeLineMap.length) {
			if (i == 0) {
				this.writeSourceMapIndent(this.prevEmittedCol, this.markerIds[index]);
			} else {
				this.writeSourceMapIndent(this.prevEmittedCol, "  >");
			}
			this.w.sourceMapRecorder.WriteString(this.w.getTextOfLine(i, tsCodeLineMap, sourceText));
			if (i == tsCodeLineMap.length - 1) {
				this.w.sourceMapRecorder.WriteLine("");
			}
		}

		this.w.prevWrittenSourcePos = sourcePos;
	}

	@:privateAccess
	function writeSpanDetails(currentSpan:SourceMapSpanWithDecodeErrors, index:Int):Void {
		this.w.sourceMapRecorder.WriteLine(this.markerIds[index] + this.w.getSourceMapSpanString(currentSpan.sourceMapSpan, false /*getAbsentNameIndex*/));
	}

	@:privateAccess
	public function writeRecordedSpans():Void {
		final w = this.w;
		final writeSourceMapMarker = this.writeSourceMapMarker;
		final writeSourceMapSourceText = this.writeSourceMapSourceText;
		final writeSpanDetails = this.writeSpanDetails;

		if (w.spansOnSingleLine.length > 0) {
			final currentJsLine = w.spansOnSingleLine[0].sourceMapSpan.GeneratedLine;

			// Write js line
			w.writeJsFileLines(currentJsLine + 1);

			// Emit markers
			this.iterateSpans(writeSourceMapMarker);

			final jsFileText = w.getTextOfLine(currentJsLine + 1, w.jsLineMap, w.jsFile.Content); // TODO: Strada is wrong here, we should be looking at `currentJsLine`, not `currentJsLine+1`
			// PORT: byte: Go len(jsFileText) counts UTF-8 bytes.
			final jsFileTextLen = go.Utf8.ByteLen(jsFileText);
			if (this.prevEmittedCol < jsFileTextLen - 1) {
				// There is remaining text on this line that will be part of next source span so write marker that continues
				this.writeSourceMapMarkerEx(null /*currentSpan*/, w.spansOnSingleLine.length, jsFileTextLen - 1 /*endColumn*/, true /*endContinues*/);
			}

			// Emit Source text
			this.iterateSpans(writeSourceMapSourceText);

			// Emit column number etc
			this.iterateSpans(writeSpanDetails);

			w.sourceMapRecorder.WriteLine("---");
		}
	}
}
