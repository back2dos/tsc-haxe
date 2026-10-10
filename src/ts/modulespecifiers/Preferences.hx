package ts.modulespecifiers;

// Port of preferences.go (types; the funcs are in Modulespecifiers.hx).

class ModuleSpecifierPreferences {
	public var relativePreference:RelativePreferenceKind = RelativePreferenceRelative;
	public var getAllowedEndingsInPreferredOrder:(syntaxImpliedNodeFormat:ResolutionMode) -> Array<ModuleSpecifierEnding> = null;
	public var excludeRegexes:Null<Array<String>> = null;

	public function new() {}
}
