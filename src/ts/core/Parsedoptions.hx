package ts.core;

// Port of parsedoptions.go.
class ParsedOptions {
	public var CompilerOptions:Null<CompilerOptions> = null; // json:"compilerOptions"
	public var WatchOptions:Null<WatchOptions> = null; // json:"watchOptions"
	public var TypeAcquisition:Null<TypeAcquisition> = null; // json:"typeAcquisition"

	public var FileNames:Slice<RootedFilePath> = null; // json:"fileNames"
	public var ProjectReferences:Slice<ProjectReference> = null; // json:"projectReferences"
	// TypeScript main (content mappers); main moved ParsedOptions to tsoptions.
	#if !macro // PORT: Core.hx (with its imports) is also typed in the macro context (Core.OrElse)
	public var ContentMappers:Slice<ts.contentmapper.Contentmapper.Mapper> = null; // json:"contentMappers"
	#end

	public function new() {}

	// PORT: Go struct value copy (`*p.ParsedConfig`).
	public function copy():ParsedOptions {
		final o = new ParsedOptions();
		o.CompilerOptions = this.CompilerOptions;
		o.WatchOptions = this.WatchOptions;
		o.TypeAcquisition = this.TypeAcquisition;
		o.FileNames = this.FileNames;
		o.ProjectReferences = this.ProjectReferences;
		#if !macro
		o.ContentMappers = this.ContentMappers;
		#end
		return o;
	}
}
