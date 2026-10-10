package ts.core;

// Port of buildoptions.go.
// PORT: `_ noCopy` omitted (go vet marker); json tags kept as comments; `*int` → Null<Int>.
class BuildOptions {
	public var Dry:Tristate = TSUnknown; // json:"dry,omitzero"
	public var Force:Tristate = TSUnknown; // json:"force,omitzero"
	public var Verbose:Tristate = TSUnknown; // json:"verbose,omitzero"
	public var Builders:Null<Int> = null; // json:"builders,omitzero"
	public var StopBuildOnErrors:Tristate = TSUnknown; // json:"stopBuildOnErrors,omitzero"

	// CompilerOptions are not parsed here and will be available on ParsedBuildCommandLine

	// Internal fields
	public var Clean:Tristate = TSUnknown; // json:"clean,omitzero"

	public function new() {}
}
