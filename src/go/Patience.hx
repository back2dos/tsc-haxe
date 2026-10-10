package go;

import go.Tuple.Pair;

// Shim for github.com/peter-evans/patience v0.3.0 (Diff, UnifiedDiffTextWithOptions), used by the
// test baseline diffs (testutil/baseline.DiffText).
// PORT: Go sub-slices share their backing array; here every slice is a copy (`slice`), which is
// equivalent because no slice is written through after an append that could alias.

enum abstract DiffType(Int) to Int {
	var Delete = -1;
	var Insert = 1;
	var Equal = 0;
}

class DiffLine {
	public var Text:String = "";
	public var Type:DiffType = Equal;

	public function new(Text:String, Type:DiffType) {
		this.Text = Text;
		this.Type = Type;
	}
}

class Hunk {
	public var Diffs:Null<Array<DiffLine>> = null;
	public var SrcStart:Int = 0;
	public var SrcLines:Int = 0;
	public var DstStart:Int = 0;
	public var DstLines:Int = 0;

	public function new() {}
}

class UnifiedDiffOptions {
	public var Precontext:Int = 0;
	public var Postcontext:Int = 0;
	public var SrcHeader:String = "";
	public var DstHeader:String = "";

	public function new(Precontext:Int = 0, Postcontext:Int = 0, SrcHeader:String = "", DstHeader:String = "") {
		this.Precontext = Precontext;
		this.Postcontext = Postcontext;
		this.SrcHeader = SrcHeader;
		this.DstHeader = DstHeader;
	}
}

class Patience {
	// --- lcs.go ---

	// PORT: [][2]int → Array<Array<Int>>.
	public static function LCS(a:Array<String>, b:Array<String>):Array<Array<Int>> {
		final lcs:Array<Array<Int>> = [for (i in 0...a.length + 1) [for (j in 0...b.length + 1) 0]];

		for (i in 1...lcs.length) {
			for (j in 1...lcs[i].length) {
				if (a[i - 1] == b[j - 1]) {
					lcs[i][j] = lcs[i - 1][j - 1] + 1;
				} else {
					lcs[i][j] = lcs[i - 1][j] > lcs[i][j - 1] ? lcs[i - 1][j] : lcs[i][j - 1];
				}
			}
		}

		var i = a.length, j = b.length;
		final s:Array<Array<Int>> = [];
		while (i > 0 && j > 0) {
			if (a[i - 1] == b[j - 1]) {
				s.push([i - 1, j - 1]);
				i--;
				j--;
			} else if (lcs[i - 1][j] > lcs[i][j - 1]) {
				i--;
			} else {
				j--;
			}
		}

		s.reverse();
		return s;
	}

	// --- patience.go ---

	static function toDiffLines(a:Array<String>, t:DiffType):Array<DiffLine> {
		return [for (l in a) new DiffLine(l, t)];
	}

	static function uniqueElements(a:Array<String>):Pair<Array<String>, Array<Int>> {
		final m = new haxe.ds.StringMap<Int>();
		for (e in a) {
			m.set(e, (m.exists(e) ? m.get(e) : 0) + 1);
		}
		final elements:Array<String> = [];
		final indices:Array<Int> = [];
		for (i in 0...a.length) {
			final e = a[i];
			if (m.get(e) == 1) {
				elements.push(e);
				indices.push(i);
			}
		}
		return new Pair(elements, indices);
	}

	public static function Diff(a:Array<String>, b:Array<String>):Null<Array<DiffLine>> {
		if (a.length == 0 && b.length == 0) {
			return null;
		} else if (a.length == 0) {
			return toDiffLines(b, Insert);
		} else if (b.length == 0) {
			return toDiffLines(a, Delete);
		}

		var i = 0;
		while (i < a.length && i < b.length && a[i] == b[i]) {
			i++;
		}
		if (i > 0) {
			return concat(toDiffLines(a.slice(0, i), Equal), Diff(a.slice(i), b.slice(i)));
		}

		var j = 0;
		while (j < a.length && j < b.length && a[a.length - 1 - j] == b[b.length - 1 - j]) {
			j++;
		}
		if (j > 0) {
			return concat(Diff(a.slice(0, a.length - j), b.slice(0, b.length - j)), toDiffLines(a.slice(a.length - j), Equal));
		}

		final ua = uniqueElements(a);
		final ub = uniqueElements(b);
		final lcs = LCS(ua.a, ub.a);

		if (lcs.length == 0) {
			return concat(toDiffLines(a, Delete), toDiffLines(b, Insert));
		}

		for (x in lcs) {
			x[0] = ua.b[x[0]];
			x[1] = ub.b[x[1]];
		}

		var diffs:Array<DiffLine> = [];
		var ga = 0, gb = 0;
		for (ip in lcs) {
			diffs = concat(diffs, Diff(a.slice(ga, ip[0]), b.slice(gb, ip[1])));
			diffs.push(new DiffLine(a[ip[0]], Equal));
			ga = ip[0] + 1;
			gb = ip[1] + 1;
		}
		diffs = concat(diffs, Diff(a.slice(ga), b.slice(gb)));

		return diffs;
	}

	static function concat(a:Null<Array<DiffLine>>, b:Null<Array<DiffLine>>):Array<DiffLine> {
		final r = a == null ? [] : a.copy();
		if (b != null)
			for (x in b)
				r.push(x);
		return r;
	}

	// --- unified.go ---

	static function makeHunks(diffs:Null<Array<DiffLine>>, precontext:Int, postcontext:Int):Null<Array<Hunk>> {
		if (diffs == null || diffs.length == 0) {
			return null;
		}

		final hunks:Array<Hunk> = [];

		final updateHunks = function(block:Hunk, lastBlock:Bool) {
			final curHunk = hunks.length - 1;
			if (block.Diffs[0].Type == Equal) {
				if (hunks.length == 0) {
					final ctxLen = precontext < block.Diffs.length ? precontext : block.Diffs.length;
					final h = new Hunk();
					h.Diffs = block.Diffs.slice(block.Diffs.length - ctxLen);
					h.SrcStart = block.Diffs.length - ctxLen + block.SrcStart;
					h.SrcLines = ctxLen;
					h.DstStart = block.Diffs.length - ctxLen + block.DstStart;
					h.DstLines = ctxLen;
					hunks.push(h);
				} else {
					var maxNonContext = precontext + postcontext;
					if (lastBlock) {
						maxNonContext = postcontext;
					}
					if (block.Diffs.length <= maxNonContext) {
						hunks[curHunk].Diffs = concat(hunks[curHunk].Diffs, block.Diffs);
						hunks[curHunk].SrcLines += block.Diffs.length;
						hunks[curHunk].DstLines += block.Diffs.length;
					} else {
						hunks[curHunk].Diffs = concat(hunks[curHunk].Diffs, block.Diffs.slice(0, postcontext));
						hunks[curHunk].SrcLines += postcontext;
						hunks[curHunk].DstLines += postcontext;
						if (!lastBlock) {
							final h = new Hunk();
							h.Diffs = block.Diffs.slice(block.Diffs.length - precontext);
							h.SrcStart = block.Diffs.length - precontext + block.SrcStart;
							h.SrcLines = precontext;
							h.DstStart = block.Diffs.length - precontext + block.DstStart;
							h.DstLines = precontext;
							hunks.push(h);
						}
					}
					if (hunks[curHunk].SrcStart == 0) {
						hunks[curHunk].SrcStart = block.SrcStart;
					}
					if (hunks[curHunk].DstStart == 0) {
						hunks[curHunk].DstStart = block.DstStart;
					}
				}
			} else {
				if (hunks.length > 0) {
					hunks[curHunk].Diffs = concat(hunks[curHunk].Diffs, block.Diffs);
					hunks[curHunk].SrcLines += block.SrcLines;
					hunks[curHunk].DstLines += block.DstLines;
				} else {
					final h = new Hunk();
					h.Diffs = block.Diffs;
					h.SrcStart = block.SrcStart;
					h.SrcLines = block.SrcLines;
					h.DstStart = block.DstStart;
					h.DstLines = block.DstLines;
					hunks.push(h);
				}
			}
		};

		var block = new Hunk();
		var modifiedLines = 0;
		var srcLineNum = 0, dstLineNum = 0;
		for (l in diffs) {
			if (block.Diffs == null
				|| block.Diffs.length == 0
				|| block.Diffs[0].Type == l.Type
				|| (block.Diffs[0].Type != l.Type && block.Diffs[0].Type != Equal && l.Type != Equal)) {
				if (block.Diffs == null)
					block.Diffs = [];
				block.Diffs.push(l);
			} else {
				updateHunks(block, false);
				block = new Hunk();
				block.Diffs = [l];
			}

			switch (l.Type) {
				case Delete:
					srcLineNum++;
					block.SrcLines++;
					modifiedLines++;
				case Insert:
					dstLineNum++;
					block.DstLines++;
					modifiedLines++;
				case Equal:
					srcLineNum++;
					dstLineNum++;
					block.SrcLines++;
					block.DstLines++;
			}

			if (block.SrcStart == 0 && (l.Type == Equal || l.Type == Delete)) {
				block.SrcStart = srcLineNum;
			}
			if (block.DstStart == 0 && (l.Type == Equal || l.Type == Insert)) {
				block.DstStart = dstLineNum;
			}
		}
		updateHunks(block, true);

		if (modifiedLines == 0) {
			return null;
		}

		return hunks;
	}

	// --- format.go ---

	static function typeSymbol(t:DiffType):String {
		return switch (t) {
			case Equal: " ";
			case Insert: "+";
			case Delete: "-";
		}
	}

	public static function UnifiedDiffTextWithOptions(diffs:Null<Array<DiffLine>>, opts:UnifiedDiffOptions):String {
		final hunks = makeHunks(diffs, opts.Precontext, opts.Postcontext);
		final s:Array<String> = [];
		if (opts.SrcHeader.length > 0) {
			s.push("--- " + opts.SrcHeader);
		}
		if (opts.DstHeader.length > 0) {
			s.push("+++ " + opts.DstHeader);
		}
		if (hunks != null) {
			for (h in hunks) {
				s.push("@@ -" + h.SrcStart + "," + h.SrcLines + " +" + h.DstStart + "," + h.DstLines + " @@");
				for (l in h.Diffs) {
					if (l.Type == Equal && l.Text.length == 0) {
						s.push("");
					} else {
						s.push(typeSymbol(l.Type) + l.Text);
					}
				}
			}
		}
		return s.join("\n");
	}
}
