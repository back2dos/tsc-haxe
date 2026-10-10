package ts.locale;

// Port of internal/locale.
// PORT: Go wraps golang.org/x/text/language.Tag. We keep the tag as its string form;
// "" is language.Und. Tag matching for localized messages is not ported yet.
abstract Locale(String) from String to String {
	public static final Default:Locale = "";

	// PORT: Go returns (locale, ok). We return null when the tag is not valid.
	public static function Parse(localeStr:String):Null<Locale> {
		return ~/^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$/.match(localeStr) ? (localeStr : Locale) : null;
	}
}
