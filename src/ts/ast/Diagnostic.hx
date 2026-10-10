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
	// Original message; may be nil.
	var message:Message = null;
	var messageKey:Key = "";
	var messageArgs:Array<String> = null;
	var messageChain:Array<Diagnostic> = null;
	var relatedInformation:Array<Diagnostic> = null;
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

	public function MessageKey():Key {
		return messageKey;
	}

	public function MessageArgs():Array<String> {
		return messageArgs;
	}

	public function MessageChain():Array<Diagnostic> {
		return messageChain;
	}

	public function RelatedInformation():Array<Diagnostic> {
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

	public function SetMessageChain(messageChain:Array<Diagnostic>):Diagnostic {
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

	public function SetRelatedInfo(relatedInformation:Array<Diagnostic>):Diagnostic {
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
		result.message = message;
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
		return Diagnostics.Localize(locale, message, messageKey, messageArgs);
	}

	// For debugging only.
	public function String():String {
		return Diagnostics.Localize(Locale.Default, message, messageKey, messageArgs);
	}
}

class DiagnosticsCollection {
	// PORT: sync.Mutex dropped (single-threaded).
	var count:Int = 0;
	var fileDiagnostics:StringMap<Array<Diagnostic>> = null;
	var fileDiagnosticsSorted:Set<String> = new Set<String>();
	var nonFileDiagnostics:Array<Diagnostic> = null;
	var nonFileDiagnosticsSorted:Bool = false;

	public function new() {}

	public function Add(diagnostic:Diagnostic):Void {
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
	}

	public function Lookup(diagnostic:Diagnostic):Diagnostic {
		var diagnostics:Array<Diagnostic>;
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

	public function GetGlobalDiagnostics():Array<Diagnostic> {
		return getGlobalDiagnosticsLocked();
	}

	function getGlobalDiagnosticsLocked():Array<Diagnostic> {
		if (!nonFileDiagnosticsSorted) {
			Slices.SortStableFunc(nonFileDiagnostics, Ast.CompareDiagnostics);
			nonFileDiagnosticsSorted = true;
		}
		return Slices.Clone(nonFileDiagnostics);
	}

	public function GetDiagnosticsForFile(fileName:String):Array<Diagnostic> {
		return getDiagnosticsForFileLocked(fileName);
	}

	function getDiagnosticsForFileLocked(fileName:String):Array<Diagnostic> {
		final list = fileDiagnostics == null ? null : fileDiagnostics.get(fileName);
		if (!fileDiagnosticsSorted.Has(fileName)) {
			Slices.SortStableFunc(list, Ast.CompareDiagnostics);
			fileDiagnosticsSorted.Add(fileName);
		}
		return Slices.Clone(list);
	}

	public function GetDiagnostics():Array<Diagnostic> {
		final diagnostics = new Array<Diagnostic>(); // make([]*Diagnostic, 0, c.count)
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
