package ts.printer;

import go.Errors.Error;

// Port of emithost.go.

// NOTE: EmitHost operations must be thread-safe
interface EmitHost {
	function Options():CompilerOptions;
	function SourceFiles():Array<SourceFile>;
	function UseCaseSensitiveFileNames():Bool;
	function GetCurrentDirectory():std.String;
	function CommonSourceDirectory():std.String;
	function IsEmitBlocked(file:std.String):Bool;
	function WriteFile(fileName:std.String, text:std.String):Null<Error>;
	function GetEmitModuleFormatOfFile(file:HasFileName):ModuleKind;
	function GetEmitResolver():EmitResolver;
	function GetProjectReferenceFromSource(path:Path):SourceOutputAndProjectReference;
	function IsSourceFileFromExternalLibrary(file:SourceFile):Bool;
}
