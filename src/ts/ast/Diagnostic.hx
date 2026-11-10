package ts.ast;

import haxe.ds.StringMap;

// Port of diagnostic.go (types and methods; the package functions are in Ast.hx).

// RepopulateDiagnosticKind indicates the kind of repopulation for a diagnostic chain entry.
enum abstract RepopulateDiagnosticKind(Int) from Int to Int {
	var RepopulateModeMismatch = 1;
	var RepopulateModuleNotFound = 2;
}

// RepopulateDiagnosticInfo stores information needed to recompute a diagnostic chain entry
// during incremental builds when the program state may have changed.
class RepopulateDiagnosticInfo {
	public var Kind:RepopulateDiagnosticKind = 0;
	public var ModuleReference:String = "";
	public var Mode:ResolutionMode = ModuleKindNone;
	public var PackageName:String = "";

	public function new() {}
}

// Diagnostic
@:allow(ts.ast)
class Diagnostic {
	var file:SourceFile = null;
	var loc:TextRange = new TextRange(0, 0);
	var code:Int = 0;
	var category:Category = cast 0;
	// source, when non-empty, is a custom prefix (e.g. a content mapper's name) shown instead of "TS"
	// before the code. It marks the diagnostic as coming from an external source whose ranges point
	// into the file's original, untransformed text.
	var source:String = "";
	// Original message; may be nil.
	var message:Message = null;
	// messageText is an already-localized message used when message is nil, e.g. a diagnostic
	// deserialized from an external process that owns its own localization.
	var messageText:String = "";
	var messageKey:Key = "";
	var messageArgs:Slice<String> = null;
	var messageChain:Slice<Diagnostic> = null;
	var relatedInformation:Slice<Diagnostic> = null;
	var reportsUnnecessary:Bool = false;
	var reportsDeprecated:Bool = false;
	var skippedOnNoEmit:Bool = false;
	var repopulateInfo:RepopulateDiagnosticInfo = null;

	public function new() {}

	public function File():SourceFile {
		return file;
	}

	public function Pos():Int {
		return loc.Pos();
	}

	public function End():Int {
		return loc.End();
	}

	public function Len():Int {
		return loc.Len();
	}

	public function Loc():TextRange {
		return loc;
	}

	public function Code():Int {
		return code;
	}

	public function Category():Category {
		return category;
	}

	public function Source():String {
		return source;
	}

	public function MessageText():String {
		return messageText;
	}

	public function MessageKey():Key {
		return messageKey;
	}

	public function MessageArgs():Slice<String> {
		return messageArgs;
	}

	public function MessageChain():Slice<Diagnostic> {
		return messageChain;
	}

	public function RelatedInformation():Slice<Diagnostic> {
		return relatedInformation;
	}

	public function ReportsUnnecessary():Bool {
		return reportsUnnecessary;
	}

	public function ReportsDeprecated():Bool {
		return reportsDeprecated;
	}

	public function SkippedOnNoEmit():Bool {
		return skippedOnNoEmit;
	}

	public function RepopulateInfo():RepopulateDiagnosticInfo {
		return repopulateInfo;
	}

	public function SetFile(file:SourceFile):Void {
		this.file = file;
	}

	public function SetLocation(loc:TextRange):Void {
		this.loc = loc;
	}

	public function SetCategory(category:Category):Void {
		this.category = category;
	}

	public function SetSkippedOnNoEmit():Void {
		this.skippedOnNoEmit = true;
	}

	public function SetRepopulateInfo(info:RepopulateDiagnosticInfo):Void {
		this.repopulateInfo = info;
	}

	public function SetExternalData(source:String, messageText:String):Diagnostic {
		this.source = source;
		this.messageText = messageText;
		return this;
	}

	public function SetMessageChain(messageChain:Slice<Diagnostic>):Diagnostic {
		this.messageChain = messageChain;
		return this;
	}

	public function AddMessageChain(messageChain:Diagnostic):Diagnostic {
		if (messageChain != null) {
			// PORT: Go append: a nil slice grows into a new one.
			if (this.messageChain == null)
				this.messageChain = [];
			this.messageChain.push(messageChain);
		}
		return this;
	}

	public function SetRelatedInfo(relatedInformation:Slice<Diagnostic>):Diagnostic {
		this.relatedInformation = relatedInformation;
		return this;
	}

	public function AddRelatedInfo(relatedInformation:Diagnostic):Diagnostic {
		if (relatedInformation != null) {
			if (this.relatedInformation == null)
				this.relatedInformation = [];
			this.relatedInformation.push(relatedInformation);
		}
		return this;
	}

	// PORT: Go `result := *d` copies the struct (slices are shared, like Go).
	public function Clone():Diagnostic {
		final result = new Diagnostic();
		result.file = file;
		result.loc = loc;
		result.code = code;
		result.category = category;
		result.source = source;
		result.message = message;
		result.messageText = messageText;
		result.messageKey = messageKey;
		result.messageArgs = messageArgs;
		result.messageChain = messageChain;
		result.relatedInformation = relatedInformation;
		result.reportsUnnecessary = reportsUnnecessary;
		result.reportsDeprecated = reportsDeprecated;
		result.skippedOnNoEmit = skippedOnNoEmit;
		result.repopulateInfo = repopulateInfo;
		return result;
	}

	public function Localize(locale:Locale):String {
		if (message == null && messageText != "") {
			return messageText;
		}
		return Diagnostics.Localize(locale, message, messageKey, displayMessageArgs());
	}

	// For debugging only.
	public function String():String {
		if (message == null && messageText != "") {
			return messageText;
		}
		return Diagnostics.Localize(Locale.Default, message, messageKey, displayMessageArgs());
	}

	// displayMessageArgs substitutes the original text for a complete alias span when a diagnostic argument
	// exactly matches the virtual alias. Stored arguments remain unchanged for code fixes and serialization.
	function displayMessageArgs():Slice<String> {
		if (file == null || source != "") {
			return messageArgs;
		}
		final alias = ts.spanmap.Spanmap.AliasForVirtualSpan(file.SpanMap(), loc);
		if (!alias.ok) {
			return messageArgs;
		}
		final segment = alias.value;
		final virtualText = file.Text();
		final originalText = file.OriginalText();
		if (segment.VirtualStart < 0 || segment.VirtualEnd > virtualText.length || segment.OriginalStart < 0
			|| segment.OriginalEnd > originalText.length) {
			return messageArgs;
		}
		final virtualName = virtualText.substring(segment.VirtualStart, segment.VirtualEnd);
		final originalName = originalText.substring(segment.OriginalStart, segment.OriginalEnd);
		var result:Slice<String> = null;
		if (messageArgs != null) {
			for (i in 0...messageArgs.length) {
				if (messageArgs[i] != virtualName) {
					continue;
				}
				if (result == null) {
					result = messageArgs.copy();
				}
				result[i] = originalName;
			}
		}
		if (result != null) {
			return result;
		}
		return messageArgs;
	}
}

class DiagnosticsCollection {
	#if tshx_parallel
	// PORT: hxmc (-D tshx-parallel) — Go's sync.Mutex: a collection can be read by several checker threads at
	// once (the include processor's, via Program.GetIncludeProcessorDiagnostics), and its reads write (the lazy
	// sort marks fileDiagnosticsSorted / nonFileDiagnosticsSorted)
	final mu = new sys.thread.Mutex();
	#end
	var count:Int = 0;
	var fileDiagnostics:StringMap<Slice<Diagnostic>> = null;
	var fileDiagnosticsSorted:Set<String> = new Set<String>();
	var nonFileDiagnostics:Slice<Diagnostic> = null;
	var nonFileDiagnosticsSorted:Bool = false;
	// PORT: TypeScript main's dedup index (#4825); diagnosticLocationKey {path, loc, code} encoded as a string
	var diagnosticIndex:StringMap<Diagnostic> = null;
	var diagnosticCollisions:StringMap<Slice<Diagnostic>> = null;

	public function new() {}

	static function getDiagnosticLocationKey(diagnostic:Diagnostic):String {
		final path = diagnostic.File() != null ? diagnostic.File().FileName() : "";
		return diagnostic.Loc().Pos() + ":" + diagnostic.Loc().End() + ":" + diagnostic.Code() + ":" + path;
	}

	public function Add(diagnostic:Diagnostic):Diagnostic {
		#if tshx_parallel
		mu.acquire();
		final r = addLocked(diagnostic);
		mu.release();
		return r;
		#else
		return addLocked(diagnostic);
		#end
	}

	function addLocked(diagnostic:Diagnostic):Diagnostic {
		final key = getDiagnosticLocationKey(diagnostic);
		final existing = diagnosticIndex == null ? null : diagnosticIndex.get(key);
		if (existing != null) {
			if (Ast.EqualDiagnostics(existing, diagnostic)) {
				return existing;
			}
			final collisions = diagnosticCollisions == null ? null : diagnosticCollisions.get(key);
			if (collisions != null) {
				for (collision in collisions) {
					if (Ast.EqualDiagnostics(collision, diagnostic)) {
						return collision;
					}
				}
			}
		}
		if (diagnosticIndex == null) {
			diagnosticIndex = new StringMap();
		}
		if (existing == null) {
			diagnosticIndex.set(key, diagnostic);
		} else {
			if (diagnosticCollisions == null) {
				diagnosticCollisions = new StringMap();
			}
			var list = diagnosticCollisions.get(key);
			if (list == null) {
				list = [];
				diagnosticCollisions.set(key, list);
			}
			list.push(diagnostic);
		}

		count++;

		if (diagnostic.File() != null) {
			final fileName = diagnostic.File().FileName();
			if (fileDiagnostics == null) {
				fileDiagnostics = new StringMap();
			}
			var list = fileDiagnostics.get(fileName);
			if (list == null) {
				list = [];
				fileDiagnostics.set(fileName, list);
			}
			list.push(diagnostic);
			fileDiagnosticsSorted.Delete(fileName);
		} else {
			if (nonFileDiagnostics == null)
				nonFileDiagnostics = [];
			nonFileDiagnostics.push(diagnostic);
			nonFileDiagnosticsSorted = false;
		}
		return diagnostic;
	}

	public function Lookup(diagnostic:Diagnostic):Diagnostic {
		#if tshx_parallel
		mu.acquire();
		final r = lookupLocked(diagnostic);
		mu.release();
		return r;
		#else
		return lookupLocked(diagnostic);
		#end
	}

	function lookupLocked(diagnostic:Diagnostic):Diagnostic {
		var diagnostics:Slice<Diagnostic>;
		if (diagnostic.File() != null) {
			diagnostics = getDiagnosticsForFileLocked(diagnostic.File().FileName());
		} else {
			diagnostics = getGlobalDiagnosticsLocked();
		}
		final r = Slices.BinarySearchFunc(diagnostics, diagnostic, Ast.CompareDiagnostics);
		if (r.ok) {
			return diagnostics[r.value];
		}
		return null;
	}

	public function GetGlobalDiagnostics():Slice<Diagnostic> {
		#if tshx_parallel
		mu.acquire();
		final r = getGlobalDiagnosticsLocked();
		mu.release();
		return r;
		#else
		return getGlobalDiagnosticsLocked();
		#end
	}

	function getGlobalDiagnosticsLocked():Slice<Diagnostic> {
		if (!nonFileDiagnosticsSorted) {
			Slices.SortStableFunc(nonFileDiagnostics, Ast.CompareDiagnostics);
			nonFileDiagnosticsSorted = true;
		}
		return Slices.Clone(nonFileDiagnostics);
	}

	public function GetDiagnosticsForFile(fileName:String):Slice<Diagnostic> {
		#if tshx_parallel
		mu.acquire();
		final r = getDiagnosticsForFileLocked(fileName);
		mu.release();
		return r;
		#else
		return getDiagnosticsForFileLocked(fileName);
		#end
	}

	function getDiagnosticsForFileLocked(fileName:String):Slice<Diagnostic> {
		final list = fileDiagnostics == null ? null : fileDiagnostics.get(fileName);
		if (!fileDiagnosticsSorted.Has(fileName)) {
			Slices.SortStableFunc(list, Ast.CompareDiagnostics);
			fileDiagnosticsSorted.Add(fileName);
		}
		return Slices.Clone(list);
	}

	public function GetDiagnostics():Slice<Diagnostic> {
		#if tshx_parallel
		mu.acquire();
		final r = getDiagnosticsLocked();
		mu.release();
		return r;
		#else
		return getDiagnosticsLocked();
		#end
	}

	function getDiagnosticsLocked():Slice<Diagnostic> {
		final diagnostics = new Slice<Diagnostic>(); // make([]*Diagnostic, 0, c.count)
		if (nonFileDiagnostics != null)
			for (d in nonFileDiagnostics)
				diagnostics.push(d);
		if (fileDiagnostics != null)
			for (diags in fileDiagnostics)
				for (d in diags)
					diagnostics.push(d);
		Slices.SortFunc(diagnostics, Ast.CompareDiagnostics);
		return diagnostics;
	}
}
