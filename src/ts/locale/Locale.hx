package ts.locale;

import go.text.language.Language;

// Port of internal/locale (locale.go).
// Go: type Locale language.Tag. The zero value (Default) is language.Und.
abstract Locale(go.text.language.Language.Tag) {
	inline function new(t:go.text.language.Language.Tag) {
		this = t;
	}

	public static var Default(get, never):Locale;

	static inline function get_Default():Locale {
		return new Locale(Language.Und);
	}

	// Go: locale.Locale(tag) / language.Tag(locale) conversions.
	@:from public static inline function fromTag(t:go.text.language.Language.Tag):Locale {
		return new Locale(t);
	}

	@:to public inline function toTag():go.text.language.Language.Tag {
		return this;
	}

	// Go: contextKey(0). PORT: a unique key object (go.Context compares keys by identity).
	static final contextKey:Any = new ContextKey();

	public static function WithLocale(ctx:go.Context, locale:Locale):go.Context {
		return go.Context.WithValue(ctx, contextKey, locale);
	}

	public static function FromContext(ctx:go.Context):Locale {
		final v:Any = ctx.Value(contextKey);
		if (v == null)
			return Default;
		return cast v;
	}

	public inline function String():String {
		return this.String();
	}

	// PORT: Go returns (locale, ok); a failed parse still yields the partial tag
	// (language.Parse keeps what it could parse). ParseOk is that port.
	public static function ParseOk(localeStr:String):go.Tuple.ValueOk<Locale> {
		// Parse gracefully fails.
		final r = Language.Parse(localeStr);
		return new go.Tuple.ValueOk((r.value : Locale), r.err == null);
	}

	// PORT: callers that only test ok (tsoptions validation) or that fall back to Default use this
	// form: null when the tag is not valid.
	public static function Parse(localeStr:String):Null<Locale> {
		final r = ParseOk(localeStr);
		return r.ok ? r.value : null;
	}
}

private class ContextKey {
	public function new() {}
}
