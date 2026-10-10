package ts.compiler;

import ts.diagnostics.Diagnostics.Message;

// Port of processingDiagnostic.go.

// Go unexported type processingDiagnosticKind.
enum abstract ProcessingDiagnosticKind(Int) from Int to Int {
	var processingDiagnosticKindUnknownReference = 0;
	var processingDiagnosticKindExplainingFileInclude = 1;
}

@:allow(ts.compiler)
class ProcessingDiagnostic {
	var kind:ProcessingDiagnosticKind = 0;
	var data:Any = null; // FileIncludeReason or IncludeExplainingDiagnostic

	public function new(kind:ProcessingDiagnosticKind = 0, data:Any = null) {
		this.kind = kind;
		this.data = data;
	}

	function asFileIncludeReason():FileIncludeReason {
		return (this.data : FileIncludeReason);
	}

	function asIncludeExplainingDiagnostic():IncludeExplainingDiagnostic {
		return (this.data : IncludeExplainingDiagnostic);
	}

	function toDiagnostic(program:Program):Diagnostic {
		switch (this.kind) {
			case processingDiagnosticKindUnknownReference:
				final ref = this.asFileIncludeReason();
				final loc = ref.getReferencedLocation(program);
				switch (ref.kind) {
					case fileIncludeKindTypeReferenceDirective:
						return loc.diagnosticAt(Diagnostics.Cannot_find_type_definition_file_for_0, loc.ref.FileName);
					case fileIncludeKindLibReferenceDirective:
						final libName = Tspath.ToFileNameLowerCase(loc.ref.FileName);
						final unqualifiedLibName = Strings.TrimSuffix(Strings.TrimPrefix(libName, "lib."), ".d.ts");
						final suggestion = Core.GetSpellingSuggestionForStrings(unqualifiedLibName, Tsoptions.Libs.iterator());
						return loc.diagnosticAt(Core.IfElse(suggestion != "", Diagnostics.Cannot_find_lib_definition_for_0_Did_you_mean_1,
							Diagnostics.Cannot_find_lib_definition_for_0), libName, suggestion);
					default:
						throw "unknown include kind";
				}
			case processingDiagnosticKindExplainingFileInclude:
				return this.createDiagnosticExplainingFile(program);
			default:
				throw "unknown processingDiagnosticKind";
		}
	}

	function createDiagnosticExplainingFile(program:Program):Diagnostic {
		final diag = this.asIncludeExplainingDiagnostic();
		var includeDetails:Array<Diagnostic> = null;
		var relatedInfo:Array<Diagnostic> = null;
		var redirectInfo:Array<Diagnostic> = null;
		var preferredLocation:FileIncludeReason = null;
		final seenReasons = new Set<FileIncludeReason>();
		if (diag.diagnosticReason.isReferencedFile() && !program.includeProcessor.getReferenceLocation(diag.diagnosticReason, program).isSynthetic) {
			preferredLocation = diag.diagnosticReason;
		}

		final processRelatedInfo = function(includeReason:FileIncludeReason) {
			if (preferredLocation == null
				&& includeReason.isReferencedFile()
				&& !program.includeProcessor.getReferenceLocation(includeReason, program).isSynthetic) {
				preferredLocation = includeReason;
			} else if (preferredLocation != includeReason) {
				final info = program.includeProcessor.getRelatedInfo(includeReason, program);
				if (info != null) {
					if (relatedInfo == null)
						relatedInfo = [];
					relatedInfo.push(info);
				}
			}
		};
		final processInclude = function(includeReason:FileIncludeReason) {
			if (!seenReasons.AddIfAbsent(includeReason)) {
				return;
			}
			if (includeDetails == null)
				includeDetails = [];
			includeDetails.push(includeReason.toDiagnostic(program, false));
			processRelatedInfo(includeReason);
		};

		// !!! todo sheetal caching

		if (diag.file != "") {
			final reasons = program.includeProcessor.fileIncludeReasons.get(diag.file);
			includeDetails = []; // make([]*ast.Diagnostic, 0, len(reasons)): non-nil
			if (reasons != null) {
				for (reason in reasons) {
					processInclude(reason);
				}
			}
			redirectInfo = program.includeProcessor.explainRedirectAndImpliedFormat(program, diag.file, function(fileName:std.String) return fileName);
		}
		if (diag.diagnosticReason != null) {
			processInclude(diag.diagnosticReason);
		}
		var chain:Array<Diagnostic> = null;
		if (includeDetails != null && (preferredLocation == null || seenReasons.Len() != 1)) {
			final fileReason = Ast.NewCompilerDiagnostic(Diagnostics.The_file_is_in_the_program_because_Colon);
			fileReason.SetMessageChain(includeDetails);
			chain = [fileReason];
		}
		if (redirectInfo != null && redirectInfo.length > 0) { // append to a nil slice stays nil when empty
			if (chain == null)
				chain = [];
			for (d in redirectInfo)
				chain.push(d);
		}

		var result:Diagnostic = null;
		if (preferredLocation != null) {
			result = program.includeProcessor.getReferenceLocation(preferredLocation, program).diagnosticAt(diag.message, ...(diag.args == null ? [] : diag.args));
		}
		if (result == null) {
			result = Ast.NewCompilerDiagnostic(diag.message, ...(diag.args == null ? [] : diag.args));
		}
		if (chain != null) {
			result.SetMessageChain(chain);
		}
		if (relatedInfo != null) {
			result.SetRelatedInfo(relatedInfo);
		}
		return result;
	}
}

@:allow(ts.compiler)
class IncludeExplainingDiagnostic {
	var file:Path = "";
	var diagnosticReason:FileIncludeReason = null;
	var message:Message = null;
	var args:Array<Any> = null;

	public function new(file:Path = "", diagnosticReason:FileIncludeReason = null, message:Message = null, args:Array<Any> = null) {
		this.file = file;
		this.diagnosticReason = diagnosticReason;
		this.message = message;
		this.args = args;
	}
}
