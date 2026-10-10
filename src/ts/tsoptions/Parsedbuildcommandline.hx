package ts.tsoptions;

import ts.locale.Locale;

// Port of parsedbuildcommandline.go.
// PORT: sync.Once fields → Bool flags (single-threaded).
@:allow(ts.tsoptions)
class ParsedBuildCommandLine {
	public var BuildOptions:Null<BuildOptions> = null; // json:"buildOptions"
	public var CompilerOptions:Null<CompilerOptions> = null; // json:"compilerOptions"
	public var WatchOptions:Null<WatchOptions> = null; // json:"watchOptions"
	public var Projects:Null<Array<std.String>> = null; // json:"projects"
	public var Errors:Null<Array<Diagnostic>> = null; // json:"errors"
	public var Raw:Dynamic = null; // json:"raw"

	var comparePathsOptions:ComparePathsOptions = new ComparePathsOptions();

	var resolvedProjectPaths:Null<Array<std.String>> = null;
	var resolvedProjectPathsOnce:Bool = false;

	var locale:Locale = ts.locale.Locale.Default;
	var localeOnce:Bool = false;

	public function new() {}

	public function ResolvedProjectPaths():Null<Array<std.String>> {
		if (!this.resolvedProjectPathsOnce) {
			this.resolvedProjectPathsOnce = true;
			this.resolvedProjectPaths = Core.Map(this.Projects, function(project:std.String):std.String {
				return Core.ResolveConfigFileNameOfProjectReference(Tspath.ResolvePath(this.comparePathsOptions.CurrentDirectory, project));
			});
		}
		return this.resolvedProjectPaths;
	}

	public function Locale():Locale {
		if (!this.localeOnce) {
			this.localeOnce = true;
			// Go: `p.locale, _ = locale.Parse(...)` keeps the (partly) parsed tag even when parsing fails.
			this.locale = ts.locale.Locale.ParseOk(this.CompilerOptions.Locale).value;
		}
		return this.locale;
	}
}
