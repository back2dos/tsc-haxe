package ts.printer;

import go.Errors.Error;

// Port of emithost.go.

// NOTE: EmitHost operations must be thread-safe
interface EmitHost {
	function Options():CompilerOptions;
	function SourceFiles():Array<SourceFile>;
	function ContentMapperExtensionRewrites():Null<Array<ts.tspath.Tspath.ExtensionRewrite>>;
	function CaseSensitivity():CaseSensitivity;
	function CommonSourceDirectory():RootedDirectoryPath;
	function IsEmitBlocked(file:RootedFilePath):Bool;
	function WriteFile(fileName:RootedFilePath, text:std.String):Null<Error>;
	function GetEmitModuleFormatOfFile(file:HasFileName):ModuleKind;
	function GetEmitResolver():EmitResolver;
	function GetProjectReferenceFromSource(path:PathKey):SourceOutputAndProjectReference;
	function IsSourceFileFromExternalLibrary(file:SourceFile):Bool;
}
