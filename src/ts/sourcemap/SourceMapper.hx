package ts.sourcemap;

import haxe.ds.IntMap;
import haxe.ds.StringMap;
import ts.sourcemap.Sourcemap.*;

// --- source_mapper.go --- (types and methods; package-level funcs are in Sourcemap.hx)

interface Host {
	function UseCaseSensitiveFileNames():Bool;
	function GetECMALineInfo(fileName:String):ECMALineInfo;
	// PORT: (string, bool) → ValueOk<String>.
	function ReadFile(fileName:String):ValueOk<String>;
}

// Similar to `Mapping`, but position-based.
@:allow(ts.sourcemap)
class MappedPosition {
	var generatedPosition:Int = 0;
	var sourcePosition:Int = 0;
	var sourceIndex:SourceIndex = 0;
	var nameIndex:NameIndex = 0;

	public function new() {}

	function isSourceMappedPosition():Bool {
		return sourceIndex != MissingSource && sourcePosition != missingPosition;
	}
}

typedef SourceMappedPosition = MappedPosition;

// Maps source positions to generated positions and vice versa.
@:allow(ts.sourcemap)
class DocumentPositionMapper {
	var useCaseSensitiveFileNames:Bool = false;

	var sourceFileAbsolutePaths:Array<String> = null;
	var sourceToSourceIndexMap:StringMap<SourceIndex> = null;
	var generatedAbsoluteFilePath:String = "";

	var generatedMappings:Array<MappedPosition> = null;
	var sourceMappings:IntMap<Array<SourceMappedPosition>> = null;

	public function new() {}

	// PORT: nil receiver — inline with a `this == null` check like Go's `d == nil`; the body is in
	// getSourcePosition. Only call it directly (not as a closure).
	public inline function GetSourcePosition(loc:DocumentPosition):DocumentPosition {
		return this == null ? null : getSourcePosition(loc);
	}

	function getSourcePosition(loc:DocumentPosition):DocumentPosition {
		if (Core.len(generatedMappings) == 0) {
			return null;
		}

		final targetIndex = Slices.BinarySearchFunc(generatedMappings, loc.Pos, function(m:MappedPosition, pos:Int):Int {
			return m.generatedPosition - pos;
		}).value;

		if (targetIndex < 0 || targetIndex >= generatedMappings.length) {
			return null;
		}

		final mapping = generatedMappings[targetIndex];
		if (!mapping.isSourceMappedPosition()) {
			return null;
		}

		// Closest position
		return new DocumentPosition(sourceFileAbsolutePaths[mapping.sourceIndex], mapping.sourcePosition);
	}

	// PORT: nil receiver — like GetSourcePosition.
	public inline function GetGeneratedPosition(loc:DocumentPosition):DocumentPosition {
		return this == null ? null : getGeneratedPosition(loc);
	}

	function getGeneratedPosition(loc:DocumentPosition):DocumentPosition {
		final key = Tspath.GetCanonicalFileName(loc.FileName, useCaseSensitiveFileNames);
		if (!sourceToSourceIndexMap.exists(key)) {
			return null;
		}
		final sourceIndex = sourceToSourceIndexMap.get(key);
		if (sourceIndex < 0 || sourceIndex >= mapLen(sourceMappings)) {
			return null;
		}
		final sourceMappings = this.sourceMappings.get(sourceIndex);
		final targetIndex = Slices.BinarySearchFunc(sourceMappings, loc.Pos, function(m:SourceMappedPosition, pos:Int):Int {
			return m.sourcePosition - pos;
		}).value;

		if (targetIndex < 0 || targetIndex >= Core.len(sourceMappings)) {
			return null;
		}

		final mapping = sourceMappings[targetIndex];
		if (mapping.sourceIndex != sourceIndex) {
			return null;
		}

		// Closest position
		return new DocumentPosition(generatedAbsoluteFilePath, mapping.generatedPosition);
	}

	// PORT: Go len(map).
	static function mapLen<V>(m:IntMap<V>):Int {
		var n = 0;
		if (m != null) {
			for (_ in m.keys())
				n++;
		}
		return n;
	}
}

class DocumentPosition {
	public var FileName:String = "";
	public var Pos:Int = 0;

	public function new(FileName:String = "", Pos:Int = 0) {
		this.FileName = FileName;
		this.Pos = Pos;
	}
}
