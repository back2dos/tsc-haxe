package ts.spanmap;

import go.Errors.Error;
import go.Slices;
import go.Tuple;
import ts.core.Core;
import ts.core.Text;
import ts.json.Json;

// Port of internal/spanmap (TypeScript main, content mappers, typescript-go #4712 / #63936).
//
// Package spanmap provides bidirectional span-aware mapping between a content mapper's virtual text
// and its original, untransformed source. Unlike a source map, which records
// point correspondences and leaves spans and "no origin" implicit, a SpanMap records explicit segments
// for the parts of the virtual text that correspond to the original; positions not covered by any
// segment are synthesized (virtual content with no original counterpart). All positions are absolute
// offsets (core.TextPos), matching the compiler's TextRange model.
// PORT: positions are UTF-16 offsets like everywhere in the port (Go: UTF-8 byte offsets); see
// contentmapper's positionNormalizer.

// Kind describes how positions inside a segment relate the virtual span to the original span.
enum abstract Kind(Int) to Int {
	// KindVerbatim segments are length-preserving: the virtual and original spans have the same
	// length and interior positions map 1:1.
	var KindVerbatim = 0;
	// KindAtom segments map a virtual span to an original span as a whole; interior positions are not
	// interpolatable, so positions within clamp to the segment's endpoints.
	var KindAtom = 1;
	// KindAlias has atom geometry, but additionally asserts that the virtual and original texts are
	// names for the same logical entity. Diagnostic presentation may substitute the original name.
	var KindAlias = 2;
}

// Feature selects which language-service operations may use a segment.
enum abstract Feature(Int) to Int {
	var FeatureHover = 1 << 0;
	var FeatureSignatureHelp = 1 << 1;
	var FeatureCompletion = 1 << 2;
	var FeatureDefinition = 1 << 3;
	var FeatureTypeDefinition = 1 << 4;
	var FeatureImplementation = 1 << 5;
	var FeatureReferences = 1 << 6;
	var FeatureDocumentHighlights = 1 << 7;
	var FeatureRename = 1 << 8;
	var FeatureCallHierarchy = 1 << 9;
	var FeatureCodeActions = 1 << 10;
	var FeatureFormatting = 1 << 11;
	var FeatureInlayHints = 1 << 12;
	var FeatureSemanticTokens = 1 << 13;
	var FeatureFoldingRanges = 1 << 14;
	var FeatureSelectionRanges = 1 << 15;
	var FeatureLinkedEditing = 1 << 16;
	var FeatureAutoInsert = 1 << 17;
	var FeatureDocumentSymbols = 1 << 18;
	var FeatureCodeLens = 1 << 19;
	var FeatureNone = 0;
	var FeatureAll = (1 << 20) - 1;

	@:op(A | B) static function or(a:Feature, b:Feature):Feature;

	@:op(A & B) static function and(a:Feature, b:Feature):Feature;
}

// Fidelity describes how faithfully a mapped span reflects the original.
enum abstract Fidelity(Int) to Int {
	var FidelityExact = 0;
	var FidelityAtom = 1;
	var FidelityApproximate = 2;
	var FidelityNone = 3;

	public inline function IsExact():Bool {
		return (cast this : Fidelity) == FidelityExact;
	}

	public inline function IsSingleSegment():Bool {
		return (cast this : Fidelity) == FidelityExact || (cast this : Fidelity) == FidelityAtom;
	}

	public inline function IsNone():Bool {
		return (cast this : Fidelity) == FidelityNone;
	}
}

// Segment maps the half-open virtual range [VirtualStart, VirtualEnd) to the half-open original range
// [OriginalStart, OriginalEnd).
class Segment {
	public var VirtualStart:Int = 0;
	public var VirtualEnd:Int = 0;
	public var OriginalStart:Int = 0;
	public var OriginalEnd:Int = 0;
	public var Kind:Kind = KindVerbatim;
	public var Features:Feature = FeatureNone;

	public function new(virtualStart:Int = 0, virtualEnd:Int = 0, originalStart:Int = 0, originalEnd:Int = 0, kind:Kind = KindVerbatim,
			features:Feature = FeatureNone) {
		this.VirtualStart = virtualStart;
		this.VirtualEnd = virtualEnd;
		this.OriginalStart = originalStart;
		this.OriginalEnd = originalEnd;
		this.Kind = kind;
		this.Features = features;
	}

	public function copy():Segment {
		return new Segment(VirtualStart, VirtualEnd, OriginalStart, OriginalEnd, Kind, Features);
	}

	public function equals(o:Segment):Bool {
		return VirtualStart == o.VirtualStart && VirtualEnd == o.VirtualEnd && OriginalStart == o.OriginalStart && OriginalEnd == o.OriginalEnd
			&& Kind == o.Kind && Features == o.Features;
	}
}

// MappedPosition is one virtual projection of an original position and its mapping fidelity.
class MappedPosition {
	public var Position:Int = 0;
	public var Fidelity:Fidelity = FidelityExact;

	public function new(position:Int = 0, fidelity:Fidelity = FidelityExact) {
		this.Position = position;
		this.Fidelity = fidelity;
	}
}

// MappedSpan is one virtual projection of an original range and its mapping fidelity.
class MappedSpan {
	public var Span:TextRange;
	public var Fidelity:Fidelity = FidelityExact;

	public function new(span:TextRange, fidelity:Fidelity) {
		this.Span = span;
		this.Fidelity = fidelity;
	}
}

// Validation failures.
enum abstract MappingErrorKind(Int) to Int {
	var MappingErrorKindOverlap = 0;
	var MappingErrorKindOutOfBounds = 1;
	var MappingErrorKindVerbatimMismatch = 2;
	var MappingErrorKindKind = 3;
	var MappingErrorKindFeature = 4;
}

// MappingError describes a single span map validation failure.
class MappingError implements Error {
	public var Kind:MappingErrorKind = MappingErrorKindOverlap;
	public var VirtualPos:Int = 0;
	public var OriginalPos:Int = 0;

	public function new(kind:MappingErrorKind, virtualPos:Int = 0, originalPos:Int = 0) {
		this.Kind = kind;
		this.VirtualPos = virtualPos;
		this.OriginalPos = originalPos;
	}

	public function Error():String {
		switch (Kind) {
			case MappingErrorKindOverlap:
				return 'content mapper position mappings overlap or are out of order near virtual offset ${VirtualPos}';
			case MappingErrorKindOutOfBounds:
				return 'content mapper position mapping points outside the original content at original offset ${OriginalPos}';
			case MappingErrorKindVerbatimMismatch:
				return 'content mapper verbatim mapping does not match the original content at virtual offset ${VirtualPos}, original offset ${OriginalPos}';
			case MappingErrorKindKind:
				return 'content mapper position mapping has an invalid kind at virtual offset ${VirtualPos}';
			case MappingErrorKindFeature:
				return 'content mapper position mappings have invalid features near original offset ${OriginalPos}';
			default:
				return "content mapper produced an invalid position mapping";
		}
	}
}

private class SegmentGroupAtOriginalPosition {
	public final segments:Array<Segment>;
	public final atEnd:Bool;

	public function new(segments:Array<Segment>, atEnd:Bool) {
		this.segments = segments;
		this.atEnd = atEnd;
	}
}

// originalIndex stores segments in original-text order and a complete binary tree whose leaves correspond
// to those segments. Each internal node stores the maximum OriginalEnd below it.
private class OriginalIndex {
	public final segments:Array<Segment>;
	public final leafCount:Int;
	public final maxEnds:Array<Int>;

	public function new(segments:Array<Segment>, leafCount:Int, maxEnds:Array<Int>) {
		this.segments = segments;
		this.leafCount = leafCount;
		this.maxEnds = maxEnds;
	}

	// PORT: sort.Search
	function search(pred:Int->Bool):Int {
		var lo = 0;
		var hi = segments.length;
		while (lo < hi) {
			final h = (lo + hi) >>> 1;
			if (!pred(h))
				lo = h + 1;
			else
				hi = h;
		}
		return lo;
	}

	// segmentsAtOriginalPosition returns every mapping segment containing the original-text position pos.
	public function segmentsAtOriginalPosition(pos:Int):ValueOk<Array<Segment>> {
		final start = search(index -> segments[index].OriginalStart >= pos);
		final results = segmentsEndingAfterPosition(start, pos);
		final end = search(index -> segments[index].OriginalStart > pos);
		for (i in start...end)
			results.push(segments[i]);
		return new ValueOk(results, results.length > 0);
	}

	function segmentsEndingAfterPosition(limit:Int, pos:Int):Array<Segment> {
		final results:Array<Segment> = [];
		collectSegmentsEndingAtOrAfter(1, 0, leafCount, limit, pos, false, results);
		return results;
	}

	function collectSegmentsEndingAtOrAfter(node:Int, start:Int, end:Int, limit:Int, pos:Int, includeEnd:Bool, results:Array<Segment>):Void {
		if (start >= limit || maxEnds[node] < pos || !includeEnd && maxEnds[node] == pos) {
			return;
		}
		if (end - start == 1) {
			results.push(segments[start]);
			return;
		}
		final middle = start + Std.int((end - start) / 2);
		collectSegmentsEndingAtOrAfter(2 * node, start, middle, limit, pos, includeEnd, results);
		collectSegmentsEndingAtOrAfter(2 * node + 1, middle, end, limit, pos, includeEnd, results);
	}

	public function segmentGroupsAtOriginalPosition(pos:Int):Array<SegmentGroupAtOriginalPosition> {
		final limit = search(index -> segments[index].OriginalStart > pos);
		final segs:Array<Segment> = [];
		collectSegmentsEndingAtOrAfter(1, 0, leafCount, limit, pos, true, segs);
		final groups:Array<SegmentGroupAtOriginalPosition> = [];
		var start = 0;
		while (start < segs.length) {
			var end = start + 1;
			while (end < segs.length && Spanmap.sameOriginalRange(segs[start], segs[end])) {
				end++;
			}
			final segment = segs[start];
			if (pos <= segment.OriginalEnd) {
				groups.push(new SegmentGroupAtOriginalPosition(segs.slice(start, end), pos == segment.OriginalEnd && pos != segment.OriginalStart));
			}
			start = end;
		}
		return groups;
	}
}

// SpanMap is a sparse, ordered set of segments over a content mapper's virtual text.
// PORT: Go methods on a nil *SpanMap are statics taking the map first where callers pass nil
// (VirtualToOriginalSpan etc. on a file's SpanMap()); they are instance methods guarded by
// the static entry points below.
class Spanmap {
	var segments:Array<Segment>;
	var originalIndex:OriginalIndex = null;

	function new(segments:Array<Segment>) {
		this.segments = segments;
	}

	// Validate enforces the content-mapper span map contract against the virtual and original text.
	public static function Validate(m:Null<Spanmap>, virtual:String, original:String):Null<MappingError> {
		if (m == null) {
			return null;
		}
		final virtualLen = virtual.length;
		final origLen = original.length;
		var previousVirtualEnd = 0;
		for (s in m.segments) {
			if (s.VirtualStart < previousVirtualEnd || s.VirtualEnd < s.VirtualStart || s.VirtualEnd > virtualLen) {
				return new MappingError(MappingErrorKindOverlap, s.VirtualStart);
			}
			previousVirtualEnd = s.VirtualEnd;
			if (s.OriginalStart < 0 || s.OriginalEnd < s.OriginalStart || s.OriginalEnd > origLen) {
				return new MappingError(MappingErrorKindOutOfBounds, s.VirtualStart, s.OriginalEnd);
			}
			if (s.Kind != KindVerbatim && s.Kind != KindAtom && s.Kind != KindAlias) {
				return new MappingError(MappingErrorKindKind, s.VirtualStart, s.OriginalStart);
			}
			if (s.Kind == KindVerbatim) {
				if (s.VirtualEnd - s.VirtualStart != s.OriginalEnd - s.OriginalStart
					|| virtual.substring(s.VirtualStart, s.VirtualEnd) != original.substring(s.OriginalStart, s.OriginalEnd)) {
					return new MappingError(MappingErrorKindVerbatimMismatch, s.VirtualStart, s.OriginalStart);
				}
			}
			if (((s.Features : Int) & ~(FeatureAll : Int)) != 0) {
				return new MappingError(MappingErrorKindFeature, s.VirtualStart, s.OriginalStart);
			}
		}
		return null;
	}

	// New builds a SpanMap from segments, sorted by virtual start.
	public static function New(segments:Null<Array<Segment>>):Spanmap {
		final sorted = segments == null ? [] : segments.copy();
		Slices.SortFunc(sorted, (a, b) -> a.VirtualStart - b.VirtualStart);
		return new Spanmap(sorted);
	}

	// Segments returns the map's segments ordered by virtual start.
	public static function Segments(m:Null<Spanmap>):Array<Segment> {
		if (m == null) {
			return null;
		}
		return [for (s in m.segments) s.copy()];
	}

	// VirtualToOriginalSpan maps a virtual range to an original range, along with the fidelity of the result.
	// A nil SpanMap maps identically.
	public static function VirtualToOriginalSpan(m:Null<Spanmap>, r:TextRange):Pair<TextRange, Fidelity> {
		if (m == null) {
			return new Pair(r, FidelityExact);
		}
		final virtualStart = r.Pos();
		final virtualEnd = Std.int(Math.max(r.End(), virtualStart));
		if (virtualStart == virtualEnd) {
			final p = VirtualToOriginalPosition(m, virtualStart);
			return new Pair(Core.NewTextRange(p.a, p.a), p.b);
		}

		final s = m.segmentIndexAt(virtualStart);
		final startIdx = s.value, startIn = s.ok;
		final endProbe = virtualEnd - 1;
		final e = m.segmentIndexAt(endProbe);
		final endIdx = e.value, endIn = e.ok;

		if (startIdx == endIdx && startIn == endIn) {
			if (startIn) {
				final seg = m.segments[startIdx];
				if (seg.Kind == KindVerbatim) {
					final origStart = clamp(seg.OriginalStart + (virtualStart - seg.VirtualStart), seg.OriginalStart, seg.OriginalEnd);
					final origEnd = clamp(seg.OriginalStart + (virtualEnd - seg.VirtualStart), origStart, seg.OriginalEnd);
					return new Pair(Core.NewTextRange(origStart, origEnd), FidelityExact);
				}
				return new Pair(Core.NewTextRange(seg.OriginalStart, seg.OriginalEnd), FidelityAtom);
			}
			// Entirely within a single synthesized gap.
			final pos = m.insertionPoint(startIdx);
			return new Pair(Core.NewTextRange(pos, pos), FidelityNone);
		}

		final origStart = m.mapLow(virtualStart, startIdx, startIn);
		final origEnd = imax(m.mapHigh(virtualEnd, endIdx, endIn), origStart);
		return new Pair(Core.NewTextRange(origStart, origEnd), FidelityApproximate);
	}

	// VirtualToOriginalPosition maps a single virtual position to the corresponding original position.
	public static function VirtualToOriginalPosition(m:Null<Spanmap>, pos:Int):Pair<Int, Fidelity> {
		if (m == null) {
			return new Pair(pos, FidelityExact);
		}
		final r = m.segmentIndexAt(pos);
		if (!r.ok) {
			return new Pair(m.insertionPoint(r.value), FidelityNone);
		}
		final seg = m.segments[r.value];
		if (seg.Kind == KindVerbatim) {
			return new Pair(clamp(seg.OriginalStart + (pos - seg.VirtualStart), seg.OriginalStart, seg.OriginalEnd), FidelityExact);
		}
		return new Pair(seg.OriginalStart, FidelityAtom);
	}

	// VirtualToOriginalPositionExact maps a position only when it is unambiguously in verbatim content.
	// A boundary touching an atom is rejected because the same virtual position can describe either side.
	public static function VirtualToOriginalPositionExact(m:Null<Spanmap>, pos:Int):ValueOk<Int> {
		final r = VirtualToOriginalPosition(m, pos);
		final mapped = r.a, fidelity = r.b;
		if (fidelity != FidelityExact || m == null) {
			return new ValueOk(mapped, fidelity == FidelityExact);
		}
		final idx = m.segmentIndexAt(pos);
		final index = idx.value;
		if (!idx.ok || m.segments[index].Kind != KindVerbatim) {
			return new ValueOk(mapped, false);
		}
		if (index > 0) {
			final previous = m.segments[index - 1];
			if (previous.VirtualEnd == pos && (previous.Kind != KindVerbatim || previous.OriginalEnd != m.segments[index].OriginalStart)) {
				return new ValueOk(mapped, false);
			}
		}
		return new ValueOk(mapped, true);
	}

	// AliasForVirtualSpan returns the alias segment exactly covering r.
	public static function AliasForVirtualSpan(m:Null<Spanmap>, r:TextRange):ValueOk<Segment> {
		if (m == null) {
			return new ValueOk(new Segment(), false);
		}
		final idx = m.segmentIndexAt(r.Pos());
		if (!idx.ok) {
			return new ValueOk(new Segment(), false);
		}
		final segment = m.segments[idx.value];
		return new ValueOk(segment, segment.Kind == KindAlias && r.Pos() == segment.VirtualStart && r.End() == segment.VirtualEnd);
	}

	// segmentIndexAt returns the index of the segment containing pos and true, or, when pos lies in a gap,
	// the index of the segment immediately before pos (-1 if none) and false.
	function segmentIndexAt(pos:Int):ValueOk<Int> {
		final r = Slices.BinarySearchFunc(segments, pos, (s:Segment, p:Int) -> s.VirtualStart - p);
		if (r.ok) {
			return new ValueOk(r.value, true);
		}
		final prev = r.value - 1;
		if (prev >= 0 && (pos < segments[prev].VirtualEnd || prev == segments.length - 1 && pos == segments[prev].VirtualEnd)) {
			return new ValueOk(prev, true);
		}
		return new ValueOk(prev, false);
	}

	function insertionPoint(prev:Int):Int {
		if (prev < 0) {
			return 0;
		}
		return segments[prev].OriginalEnd;
	}

	function mapLow(pos:Int, idx:Int, inside:Bool):Int {
		if (!inside) {
			return insertionPoint(idx);
		}
		final seg = segments[idx];
		if (seg.Kind == KindVerbatim) {
			return clamp(seg.OriginalStart + (pos - seg.VirtualStart), seg.OriginalStart, seg.OriginalEnd);
		}
		return seg.OriginalStart;
	}

	function mapHigh(pos:Int, idx:Int, inside:Bool):Int {
		if (!inside) {
			return insertionPoint(idx);
		}
		final seg = segments[idx];
		if (seg.Kind == KindVerbatim) {
			return clamp(seg.OriginalStart + (pos - seg.VirtualStart), seg.OriginalStart, seg.OriginalEnd);
		}
		return seg.OriginalEnd;
	}

	// OriginalToVirtualPositions returns every virtual projection of an original position whose segment
	// participates in feature.
	public static function OriginalToVirtualPositions(m:Null<Spanmap>, pos:Int, feature:Feature):Array<MappedPosition> {
		if (m == null) {
			return [new MappedPosition(pos, FidelityExact)];
		}
		final groups = m.origIndex().segmentGroupsAtOriginalPosition(pos);
		if (groups.length == 0) {
			return null;
		}
		var results:Array<MappedPosition> = null;
		for (group in groups) {
			for (segment in group.segments) {
				if (!supportsFeature(segment, feature)) {
					continue;
				}
				final mapped = new MappedPosition(0, FidelityAtom);
				if (segment.Kind == KindVerbatim) {
					mapped.Position = clamp(segment.VirtualStart + (pos - segment.OriginalStart), segment.VirtualStart, segment.VirtualEnd);
					mapped.Fidelity = FidelityExact;
				} else if (group.atEnd) {
					mapped.Position = segment.VirtualEnd;
				} else {
					mapped.Position = segment.VirtualStart;
				}
				if (results == null)
					results = [];
				if (!Lambda.exists(results, r -> r.Position == mapped.Position && r.Fidelity == mapped.Fidelity)) {
					results.push(mapped);
				}
			}
		}
		Slices.SortFunc(results, (a, b) -> a.Position - b.Position);
		return results;
	}

	// OriginalToVirtualSpans returns every feature-compatible virtual projection of an original range.
	public static function OriginalToVirtualSpans(m:Null<Spanmap>, r:TextRange, feature:Feature):Array<MappedSpan> {
		if (m == null) {
			return [new MappedSpan(r, FidelityExact)];
		}
		final start = r.Pos();
		final end = imax(r.End(), start);
		if (start == end) {
			return Core.Map(OriginalToVirtualPositions(m, start, feature), function(position:MappedPosition):MappedSpan {
				return new MappedSpan(Core.NewTextRange(position.Position, position.Position), position.Fidelity);
			});
		}
		final lastCharacter = end - 1;
		final originalIndex = m.origIndex();
		final s = originalIndex.segmentsAtOriginalPosition(start);
		final e = originalIndex.segmentsAtOriginalPosition(lastCharacter);
		final startSegments = s.value, endSegments = e.value;
		if (!s.ok || !e.ok) {
			return null;
		}
		final containing:Array<Segment> = [];
		for (segment in startSegments) {
			if (end <= segment.OriginalEnd) {
				containing.push(segment);
			}
		}
		if (containing.length > 0) {
			final results = originalToVirtualSpansInSegments(containing, start, end, feature);
			if (results.length > 0) {
				Slices.SortFunc(results, (a, b) -> a.Span.Pos() - b.Span.Pos());
				return results;
			}
		}
		final starts = originalStartProjections(startSegments, start, feature);
		final ends = originalEndProjections(endSegments, end, feature);
		if (starts.length == 0 || ends.length == 0) {
			return null;
		}
		Slices.SortFunc(starts, (a, b) -> a - b);
		Slices.SortFunc(ends, (a, b) -> a - b);
		final results:Array<MappedSpan> = [];
		for (i in 0...starts.length) {
			final virtualStart = starts[i];
			final endIndex = Slices.BinarySearchFunc(ends, virtualStart, (a:Int, b:Int) -> a - b).value;
			if (endIndex == ends.length || i + 1 < starts.length && starts[i + 1] <= ends[endIndex]) {
				continue;
			}
			results.push(new MappedSpan(Core.NewTextRange(virtualStart, ends[endIndex]), FidelityApproximate));
		}
		return results;
	}

	static function originalStartProjections(segments:Array<Segment>, start:Int, feature:Feature):Array<Int> {
		final results:Array<Int> = [];
		for (segment in segments) {
			if (!supportsFeature(segment, feature)) {
				continue;
			}
			if (segment.Kind == KindVerbatim) {
				results.push(clamp(segment.VirtualStart + (start - segment.OriginalStart), segment.VirtualStart, segment.VirtualEnd));
			} else {
				results.push(segment.VirtualStart);
			}
		}
		return results;
	}

	static function originalEndProjections(segments:Array<Segment>, end:Int, feature:Feature):Array<Int> {
		final results:Array<Int> = [];
		for (segment in segments) {
			if (!supportsFeature(segment, feature)) {
				continue;
			}
			if (segment.Kind == KindVerbatim) {
				results.push(clamp(segment.VirtualStart + (end - segment.OriginalStart), segment.VirtualStart, segment.VirtualEnd));
			} else {
				results.push(segment.VirtualEnd);
			}
		}
		return results;
	}

	static function originalToVirtualSpansInSegments(segments:Array<Segment>, start:Int, end:Int, feature:Feature):Array<MappedSpan> {
		final results:Array<MappedSpan> = [];
		for (segment in segments) {
			if (!supportsFeature(segment, feature)) {
				continue;
			}
			if (segment.Kind == KindVerbatim) {
				final virtualStart = clamp(segment.VirtualStart + (start - segment.OriginalStart), segment.VirtualStart, segment.VirtualEnd);
				final virtualEnd = clamp(segment.VirtualStart + (end - segment.OriginalStart), virtualStart, segment.VirtualEnd);
				results.push(new MappedSpan(Core.NewTextRange(virtualStart, virtualEnd), FidelityExact));
			} else {
				results.push(new MappedSpan(Core.NewTextRange(segment.VirtualStart, segment.VirtualEnd), FidelityAtom));
			}
		}
		return results;
	}

	public static function sameOriginalRange(left:Segment, right:Segment):Bool {
		return left.OriginalStart == right.OriginalStart && left.OriginalEnd == right.OriginalEnd;
	}

	// PORT: sync.Once → lazy field.
	function origIndex():OriginalIndex {
		if (originalIndex == null) {
			final segs = segments.copy();
			Slices.SortFunc(segs, function(a:Segment, b:Segment):Int {
				var c = a.OriginalStart - b.OriginalStart;
				if (c != 0)
					return c;
				c = a.OriginalEnd - b.OriginalEnd;
				if (c != 0)
					return c;
				return a.VirtualStart - b.VirtualStart;
			});
			var leafCount = 1;
			while (leafCount < segs.length) {
				leafCount *= 2;
			}
			final maxEnds = [for (_ in 0...2 * leafCount) 0];
			for (i in 0...segs.length) {
				maxEnds[leafCount + i] = segs[i].OriginalEnd;
			}
			var i = leafCount - 1;
			while (i > 0) {
				maxEnds[i] = imax(maxEnds[2 * i], maxEnds[2 * i + 1]);
				i--;
			}
			originalIndex = new OriginalIndex(segs, leafCount, maxEnds);
		}
		return originalIndex;
	}

	static inline function supportsFeature(segment:Segment, feature:Feature):Bool {
		return ((segment.Features : Int) & (feature : Int)) != 0;
	}

	static inline function imax(a:Int, b:Int):Int {
		return a > b ? a : b;
	}

	static inline function imin(a:Int, b:Int):Int {
		return a < b ? a : b;
	}

	// clamp confines v to the inclusive interval [lo, hi].
	static inline function clamp(v:Int, lo:Int, hi:Int):Int {
		return imax(lo, imin(v, hi));
	}

	// Unmarshal decodes a SpanMap from the JSON tuple form produced by an out-of-process content mapper.
	// PORT: Go returns (map, error); errors are thrown as a String.
	public static function Unmarshal(data:String):ValueError<Spanmap> {
		final tuples:Dynamic = try Json.UnmarshalOrdered(data) catch (e:Dynamic) return new ValueError(null, go.Errors.New(Std.string(e)));
		if (tuples != null && !Std.isOfType(tuples, Array)) {
			return new ValueError(null, go.Errors.New("json: cannot unmarshal into [][]int32"));
		}
		final arr:Array<Dynamic> = tuples == null ? [] : tuples;
		final segs:Array<Segment> = [];
		for (i in 0...arr.length) {
			final t:Array<Dynamic> = arr[i];
			if (t == null || (t.length != 5 && t.length != 6)) {
				return new ValueError(null, go.Errors.New('span map segment ${i}: expected 5 or 6 values, got ${t == null ? 0 : t.length}'));
			}
			final v = [for (x in t) Std.int((x : Float))];
			final seg = new Segment(v[0], v[0] + v[1], v[2], v[2] + v[3], cast v[4], FeatureAll);
			if (t.length == 6) {
				seg.Features = cast v[5];
			}
			segs.push(seg);
		}
		return new ValueError(New(segs), null);
	}

	// Marshal encodes a SpanMap into the JSON tuple form.
	public function Marshal():String {
		final b = new StringBuf();
		b.add("[");
		for (i in 0...segments.length) {
			final s = segments[i];
			if (i > 0)
				b.add(",");
			b.add('[${s.VirtualStart},${s.VirtualEnd - s.VirtualStart},${s.OriginalStart},${s.OriginalEnd - s.OriginalStart},${(s.Kind : Int)}');
			if (s.Features != FeatureAll) {
				b.add(',${(s.Features : Int)}');
			}
			b.add("]");
		}
		b.add("]");
		return b.toString();
	}
}
