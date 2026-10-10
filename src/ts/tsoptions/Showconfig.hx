package ts.tsoptions;

// Port of showconfig.go (types; package-level vars and funcs are in Tsoptions.hx).

// impliedOption describes a compiler option whose effective value can be derived from
// other options. This mirrors TypeScript's computedOptions concept used in convertToTSConfig.
@:allow(ts.tsoptions)
class ImpliedOption {
	// name is the Go struct field name of the CompilerOptions field (e.g., "Module").
	var name:std.String = "";
	// dependencies lists the Go struct field names that this option depends on.
	var dependencies:Null<Array<std.String>> = null;
	// compute returns the effective value of this option given compiler options.
	var compute:(opts:CompilerOptions) -> Dynamic = null;

	public function new(name:std.String, dependencies:Array<std.String>, compute:(opts:CompilerOptions) -> Dynamic) {
		this.name = name;
		this.dependencies = dependencies;
		this.compute = compute;
	}
}

// TSConfig represents the output structure for --showConfig
// PORT: Go marshals the struct by its json tags; MarshalJSONValue gives the same ordered tree
// for ts.json.Json.MarshalOrdered / MarshalIndentOrdered.
class TSConfig implements ts.json.Json.OrderedMarshaler {
	public var CompilerOptions:Null<OrderedMap<std.String, Dynamic>> = null; // json:"compilerOptions"
	public var References:Null<Array<Dynamic>> = null; // json:"references,omitzero"
	public var Files:Null<Array<std.String>> = null; // json:"files,omitzero"
	public var Include:Null<Array<std.String>> = null; // json:"include,omitzero"
	public var Exclude:Null<Array<std.String>> = null; // json:"exclude,omitzero"
	public var CompileOnSave:Null<Bool> = null; // json:"compileOnSave,omitzero"

	public function new() {}

	public function MarshalJSONValue():Dynamic {
		final m = new OrderedMap<std.String, Dynamic>();
		m.Set("compilerOptions", this.CompilerOptions);
		if (this.References != null)
			m.Set("references", this.References);
		if (this.Files != null)
			m.Set("files", this.Files);
		if (this.Include != null)
			m.Set("include", this.Include);
		if (this.Exclude != null)
			m.Set("exclude", this.Exclude);
		if (this.CompileOnSave != null)
			m.Set("compileOnSave", (this.CompileOnSave : Bool));
		return m;
	}
}
