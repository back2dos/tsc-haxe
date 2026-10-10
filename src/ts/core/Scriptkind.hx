package ts.core;

// Port of scriptkind.go and scriptkind_stringer_generated.go.
enum abstract ScriptKind(Int) from Int to Int {
	// PORT: Go integer ordering of the enum values.
	@:op(A < B) static function lt(a:ScriptKind, b:ScriptKind):Bool;
	@:op(A <= B) static function lte(a:ScriptKind, b:ScriptKind):Bool;
	@:op(A > B) static function gt(a:ScriptKind, b:ScriptKind):Bool;
	@:op(A >= B) static function gte(a:ScriptKind, b:ScriptKind):Bool;

	var ScriptKindUnknown = 0;
	var ScriptKindJS = 1;
	var ScriptKindJSX = 2;
	var ScriptKindTS = 3;
	var ScriptKindTSX = 4;
	var ScriptKindExternal = 5;
	var ScriptKindJSON = 6;
	/**
	 * Used on extensions that doesn't define the ScriptKind but the content defines it.
	 * Deferred extensions are going to be included in all project contexts.
	 */
	var ScriptKindDeferred = 7;

	// --- scriptkind_stringer_generated.go ---

	static final _ScriptKind_names = [
		"ScriptKindUnknown", "ScriptKindJS", "ScriptKindJSX", "ScriptKindTS", "ScriptKindTSX", "ScriptKindExternal", "ScriptKindJSON", "ScriptKindDeferred"
	];

	public function String():String {
		final i:Int = this;
		if (i < 0 || i >= _ScriptKind_names.length) {
			return "ScriptKind(" + Std.string(i) + ")";
		}
		return _ScriptKind_names[i];
	}
}
