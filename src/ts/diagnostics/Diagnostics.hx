package ts.diagnostics;

import ts.locale.Locale;

// Port of internal/diagnostics/diagnostics.go.
// Message statics (diagnostics_generated.go) are added by DiagnosticsMacro.
@:build(ts.diagnostics.DiagnosticsMacro.build())
class Diagnostics {
	// --- diagnostics.go ---

	public static function Localize(locale:Locale, message:Null<Message>, key:Key, args:Array<String>):String {
		if (message == null)
			message = keyToMessage(key);
		if (message == null)
			throw "Unknown diagnostic message: " + key;

		var text = message.text;
		final localized = getLocalizedMessages(locale);
		if (localized != null && localized.exists(message.key))
			text = localized.get(message.key);

		return Format(text, args);
	}

	// PORT: localization (loc_generated.go, locale matcher) is not ported yet. English only.
	static function getLocalizedMessages(loc:Locale):Null<Map<String, String>> {
		return null;
	}

	static final placeholderRegexp = ~/{(\d+)}/g;

	public static function Format(text:String, args:Array<String>):String {
		if (args == null || args.length == 0)
			return text;

		// PORT: Go replaces invalid UTF-8 in args. Haxe strings are UTF-16; nothing to replace.
		return placeholderRegexp.map(text, r -> {
			final index = Std.parseInt(r.matched(1));
			if (index == null || index >= args.length)
				throw "Invalid formatting placeholder";
			return args[index];
		});
	}

	public static function StringifyArgs(args:Array<Any>):Array<String> {
		if (args == null || args.length == 0)
			return null;
		return [for (arg in args) arg is String ? (arg : String) : Std.string(arg)];
	}

	public static function NewAdHocMessage(message:String):Message {
		return new Message(-1, CategoryError, "-1", message, false, false, false);
	}

	// --- diagnostics_generated.go ---

	static var keyToMessageMap:Map<String, Message> = null;

	// PORT: Go generates a switch; we build a map once.
	static function keyToMessage(key:Key):Null<Message> {
		if (keyToMessageMap == null) {
			keyToMessageMap = new Map();
			for (m in allMessages)
				keyToMessageMap.set(m.key, m);
		}
		return keyToMessageMap.get(key);
	}
}

enum abstract Category(Int) {
	var CategoryWarning = 0;
	var CategoryError = 1;
	var CategorySuggestion = 2;
	var CategoryMessage = 3;

	public function Name():String {
		return switch (cast this : Category) {
			case CategoryWarning: "warning";
			case CategoryError: "error";
			case CategorySuggestion: "suggestion";
			case CategoryMessage: "message";
			case _: throw "Unhandled diagnostic category";
		}
	}
}

typedef Key = String;

class Message {
	public final code:Int;
	public final category:Category;
	public final key:Key;
	public final text:String;
	public final reportsUnnecessary:Bool;
	public final elidedInCompatibilityPyramid:Bool;
	public final reportsDeprecated:Bool;

	public function new(code:Int, category:Category, key:Key, text:String, reportsUnnecessary:Bool, elidedInCompatibilityPyramid:Bool,
			reportsDeprecated:Bool) {
		this.code = code;
		this.category = category;
		this.key = key;
		this.text = text;
		this.reportsUnnecessary = reportsUnnecessary;
		this.elidedInCompatibilityPyramid = elidedInCompatibilityPyramid;
		this.reportsDeprecated = reportsDeprecated;
	}

	public inline function Code():Int return code;
	public inline function Category():Category return category;
	public inline function Key():Key return key;
	public inline function ReportsUnnecessary():Bool return reportsUnnecessary;
	public inline function ElidedInCompatibilityPyramid():Bool return elidedInCompatibilityPyramid;
	public inline function ReportsDeprecated():Bool return reportsDeprecated;

	// For debugging only.
	public function toString():String return text;

	public function Localize(locale:Locale, args:Array<Any>):String {
		return Diagnostics.Localize(locale, this, "", Diagnostics.StringifyArgs(args));
	}
}
