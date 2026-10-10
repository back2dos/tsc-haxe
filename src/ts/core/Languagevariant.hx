package ts.core;

// Port of languagevariant.go and languagevariant_stringer_generated.go.
enum abstract LanguageVariant(Int) from Int to Int {
	// PORT: Go integer ordering of the enum values.
	@:op(A < B) static function lt(a:LanguageVariant, b:LanguageVariant):Bool;
	@:op(A <= B) static function lte(a:LanguageVariant, b:LanguageVariant):Bool;
	@:op(A > B) static function gt(a:LanguageVariant, b:LanguageVariant):Bool;
	@:op(A >= B) static function gte(a:LanguageVariant, b:LanguageVariant):Bool;

	var LanguageVariantStandard = 0;
	var LanguageVariantJSX = 1;

	// --- languagevariant_stringer_generated.go ---

	public function String():String {
		final i:Int = this;
		switch (i) {
			case 0:
				return "LanguageVariantStandard";
			case 1:
				return "LanguageVariantJSX";
			default:
				return "LanguageVariant(" + Std.string(i) + ")";
		}
	}
}
