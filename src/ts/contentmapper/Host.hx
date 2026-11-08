package ts.contentmapper;

import go.Errors.Error;
import go.Tuple;
import ts.ast.Ast;
import ts.ast.Ast.MappedDiagnosticDirective;
import ts.ast.Diagnostic;
import ts.core.Compileroptions;
import ts.contentmapper.Contentmapper;
import ts.contentmapper.Hostimpl;
import ts.spanmap.Spanmap;

// --- host.go ---

// TransformErrorKind identifies the stage at which a content mapper transform failed.
enum abstract TransformErrorKind(Int) to Int {
	var TransformErrorKindUnknown = 0;
	var TransformErrorKindInitialize = 1;
	var TransformErrorKindProject = 2;
	var TransformErrorKindRequest = 3;
	var TransformErrorKindResponse = 4;
	var TransformErrorKindMappings = 5;
}

// TransformError reports a failure while preparing, requesting, or decoding a transform.
class TransformError implements Error implements go.Errors.Wrapper {
	public var Kind:TransformErrorKind;
	final err:Null<Error>;

	public function new(kind:TransformErrorKind, err:Null<Error>) {
		this.Kind = kind;
		this.err = err;
	}

	public function Error():String {
		return "content mapper transform failed: " + (err == null ? "<nil>" : err.Error());
	}

	public function Unwrap():Null<Error> {
		return err;
	}
}

// DiagnosticDirectiveErrorKind identifies why a diagnostic directive was rejected.
enum abstract DiagnosticDirectiveErrorKind(Int) to Int {
	var DiagnosticDirectiveErrorKindInvalidRange = 0;
	var DiagnosticDirectiveErrorKindInvalidPolicy = 1;
	var DiagnosticDirectiveErrorKindExpectMissingUnusedDiagnostic = 2;
	var DiagnosticDirectiveErrorKindInvalidUnusedDiagnosticIndex = 3;
	var DiagnosticDirectiveErrorKindOverlap = 4;
}

// DiagnosticDirectiveError reports an invalid diagnostic directive in a transform response.
class DiagnosticDirectiveError implements Error {
	public var Kind:DiagnosticDirectiveErrorKind;
	public var Index:Int = 0;
	public var SupplementalIndex:Int = 0;
	public var Policy:Int = 0; // DiagnosticDirectivePolicy

	public function new(kind:DiagnosticDirectiveErrorKind, index:Int, supplementalIndex:Int) {
		this.Kind = kind;
		this.Index = index;
		this.SupplementalIndex = supplementalIndex;
	}

	public function Error():String {
		return 'invalid content mapper diagnostic directive ${Index}';
	}
}

// InvalidVirtualExtensionError reports an unsupported or missing virtual extension on a mapped output.
class InvalidVirtualExtensionError implements Error {
	public var Extension:String;

	public function new(extension:String) {
		this.Extension = extension;
	}

	public function Error():String {
		return 'invalid virtual extension ${ts.json.Json.Quote(Extension)}';
	}
}

// ProjectErrorKind identifies why a mapper's openProject response was rejected.
enum abstract ProjectErrorKind(Int) to Int {
	var ProjectErrorKindMalformedResponse = 0;
	var ProjectErrorKindMissingConfigIdentity = 1;
	var ProjectErrorKindNonAbsoluteWatchedFile = 2;
	var ProjectErrorKindUnexpectedConfigIdentity = 3;
	var ProjectErrorKindUnexpectedWatchedFiles = 4;
}

// ProjectError reports an invalid mapper openProject response.
class ProjectError implements Error {
	public var Kind:ProjectErrorKind;

	public function new(kind:ProjectErrorKind) {
		this.Kind = kind;
	}

	public function Error():String {
		switch (Kind) {
			case ProjectErrorKindMalformedResponse:
				return "content mapper returned a malformed project response";
			case ProjectErrorKindMissingConfigIdentity:
				return "content mapper did not return configIdentity for dynamic configuration";
			case ProjectErrorKindNonAbsoluteWatchedFile:
				return "content mapper returned a non-absolute path in watchedFiles";
			case ProjectErrorKindUnexpectedConfigIdentity:
				return "content mapper returned configIdentity without declaring dynamicConfig";
			case ProjectErrorKindUnexpectedWatchedFiles:
				return "content mapper returned watchedFiles without declaring dynamicConfig";
			default:
				return "content mapper returned an invalid project response";
		}
	}
}

// InitializeErrorKind identifies why a mapper's initialize response was rejected.
enum abstract InitializeErrorKind(Int) to Int {
	var InitializeErrorKindProcessStart = 0;
	var InitializeErrorKindProcessExit = 1;
	var InitializeErrorKindNoResponse = 2;
	var InitializeErrorKindInvalidResponse = 3;
	var InitializeErrorKindRequest = 4;
	var InitializeErrorKindPositionEncoding = 5;
	var InitializeErrorKindEmptyDiagnosticSource = 6;
	var InitializeErrorKindReservedDiagnosticSource = 7;
}

// InitializeError reports an invalid or unsupported mapper initialize response.
class InitializeError implements Error {
	public var Kind:InitializeErrorKind;
	public var MapperName:String = "";
	public var Command:String = "";
	public var Detail:String = "";
	public var ExitCode:Int = 0;
	public var TimeoutSeconds:Int = 0;
	public var PositionEncoding:String = "";
	public var DiagnosticSource:String = "";

	public function new(kind:InitializeErrorKind) {
		this.Kind = kind;
	}

	public function Error():String {
		switch (Kind) {
			case InitializeErrorKindProcessStart:
				return 'could not start content mapper command ${ts.json.Json.Quote(Command)}: ${Detail}';
			case InitializeErrorKindProcessExit:
				return 'content mapper process exited before initialization with code ${ExitCode}';
			case InitializeErrorKindNoResponse:
				return "content mapper did not respond to the initialize request";
			case InitializeErrorKindInvalidResponse:
				return "content mapper returned an invalid initialize response: " + Detail;
			case InitializeErrorKindRequest:
				return "content mapper initialize request failed: " + Detail;
			case InitializeErrorKindPositionEncoding:
				return 'unsupported position encoding ${ts.json.Json.Quote(PositionEncoding)}';
			case InitializeErrorKindEmptyDiagnosticSource:
				return "diagnostic source must not be empty";
			case InitializeErrorKindReservedDiagnosticSource:
				return 'diagnostic source ${ts.json.Json.Quote(DiagnosticSource)} is reserved by TypeScript';
			default:
				return "content mapper initialization failed";
		}
	}
}

// SupplementalFileCollisionError reports a compiler-assigned supplemental filename that already exists.
class SupplementalFileCollisionError implements Error {
	public var FileName:String;

	public function new(fileName:String) {
		this.FileName = fileName;
	}

	public function Error():String {
		return 'content mapper supplemental output file ${ts.json.Json.Quote(FileName)} already exists';
	}
}

// Result is the outcome of transforming a content-mapped source file into virtual TypeScript.
class Result {
	// Text is the virtual TypeScript source text that is parsed into the program.
	public var Text:String = "";
	// VirtualExtension determines how Text is parsed.
	public var VirtualExtension:String = "";
	// Diagnostics are syntax errors in the original content.
	public var Diagnostics:Array<Diagnostic> = null;
	// Mappings maps positions in Text back to the original content. A successful transform must return
	// a non-nil map; an empty map describes fully synthesized output.
	public var Mappings:Spanmap = null;
	// DiagnosticDirectives control TypeScript diagnostics produced in virtual ranges.
	public var DiagnosticDirectives:Array<MappedDiagnosticDirective> = null;
	// Supplemental contains additional unnamed outputs associated with the canonical result.
	public var Supplemental:Array<MappedResult> = null;

	public function new() {}
}

// MappedResult is one virtual source file and its mapping to the original input.
class MappedResult {
	public var Text:String = "";
	public var VirtualExtension:String = "";
	public var Mappings:Spanmap = null;
	public var DiagnosticDirectives:Array<MappedDiagnosticDirective> = null;

	public function new() {}
}

// Request carries the inputs for transforming one content-mapped source file.
class Request {
	// FileName is the content-mapped source file being transformed.
	public var FileName:String;
	// Content is the content-mapped source file's text.
	public var Content:String;

	public function new(fileName:String, content:String) {
		this.FileName = fileName;
		this.Content = content;
	}
}

// ProjectSpec describes the project configuration visible to its content mappers.
class ProjectSpec {
	// ConfigFileName is the absolute project configuration file name, or empty for a project without one.
	public var ConfigFileName:String = "";
	// Mappers are the resolved content mapper entries configured for the project.
	public var Mappers:Array<Mapper> = null;
	// CompilerOptions are the project's effective compiler options.
	public var CompilerOptions:CompilerOptions = null;

	public function new(configFileName:String, mappers:Array<Mapper>, compilerOptions:CompilerOptions) {
		this.ConfigFileName = configFileName;
		this.Mappers = mappers;
		this.CompilerOptions = compilerOptions;
	}
}

class OptionPathSegment {
	public var Property:String = "";
	public var Index:Int = 0;
	public var IsIndex:Bool = false;

	public function new() {}
}

class OptionDiagnostic {
	public var Mapper:Mapper = null;
	public var Path:Array<OptionPathSegment> = null;
	public var Source:String = "";
	public var Code:Int = 0;
	public var MessageText:String = "";

	public function new() {}
}

// PORT: Timings / MapperTimings / OperationTiming (protocol activity statistics for --extendedDiagnostics)
// are not ported: the port's in-process mappers are not timed.

// Project is the project-scoped view of a Host.
interface Project {
	// Refresh closes opened mapper projects so they are reopened on the next transform or configuration identity query.
	function Refresh():Null<Error>;
	// Identities returns sorted transform identities for all configured mappers.
	function Identities():ValueError<Array<String>>;
	// Identity returns the transform identity for mapper, or an empty string if mapper is not in this project.
	function Identity(mapper:Mapper):ValueError<String>;
	// WatchedFiles returns the absolute files reported by mappers whose package.json declares dynamicConfig.
	function WatchedFiles():ValueError<Array<String>>;
	// Diagnostics returns option diagnostics cached by mapper projects that have already been opened.
	function Diagnostics():Array<OptionDiagnostic>;
	// Transform transforms one content-mapped source file using mapper in this project's configuration.
	function Transform(mapper:Mapper, request:Request):ValueError<Result>;
	// Close releases this project reference and closes mapper project handles when no references remain.
	function Close():Null<Error>;
}

// Host transforms otherwise unsupported file content into virtual TypeScript during program construction, by driving the
// configured content mappers. Create one with NewHost; Close tears down every mapper it spawned.
interface Host {
	// Project returns a retained project-scoped view for spec.
	function Project(spec:ProjectSpec):Project;
	// Acquire retains the processes for the given mapper identities until the returned lease is released.
	function Acquire(mappers:Array<Mapper>):() -> Void;
	// SetLocale updates the locale used to initialize mapper processes.
	function SetLocale(locale:ts.locale.Locale):Void;
	// Transform maps a content-mapped source file to virtual TypeScript using the given content mapper
	// in a short-lived project with default compiler options.
	function Transform(mapper:Mapper, request:Request):ValueError<Result>;
	// Close shuts down every mapper process the host spawned.
	function Close():Null<Error>;
}
