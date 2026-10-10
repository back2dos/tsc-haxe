package ts.core;

// Port of parsedoptions.go.
class ParsedOptions {
	public var CompilerOptions:Null<CompilerOptions> = null; // json:"compilerOptions"
	public var WatchOptions:Null<WatchOptions> = null; // json:"watchOptions"
	public var TypeAcquisition:Null<TypeAcquisition> = null; // json:"typeAcquisition"

	public var FileNames:Null<Array<String>> = null; // json:"fileNames"
	public var ProjectReferences:Null<Array<ProjectReference>> = null; // json:"projectReferences"

	public function new() {}
}
