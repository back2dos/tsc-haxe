package ts.diagnostics;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

// Replaces upstream internal/diagnostics/generate.go (diagnostics part).
// Adds one static field per message to class Diagnostics, plus allMessages for keyToMessage.
class DiagnosticsMacro {
	public static function build():Array<Field> {
		final fields = Context.getBuildFields();
		final pos = Context.currentPos();

		// Same merge as generate.go: by code, extra messages override.
		final byCode = new Map<Int, {key:String, m:Dynamic}>();
		for (file in ["ts/diagnostics/diagnosticMessages.json", "ts/diagnostics/extraDiagnosticMessages.json"]) {
			final path = Context.resolvePath(file);
			Context.registerModuleDependency(Context.getLocalModule(), path);
			final raw:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
			for (key in Reflect.fields(raw)) {
				final m:Dynamic = Reflect.field(raw, key);
				byCode.set(m.code, {key: key, m: m});
			}
		}
		final codes = [for (c in byCode.keys()) c];
		codes.sort((a, b) -> a - b);

		final all:Array<Expr> = [];
		for (code in codes) {
			final e = byCode.get(code);
			final names = convertPropertyName(e.key, code);
			final category = "Category" + e.m.category;
			final unnecessary = e.m.reportsUnnecessary == true;
			final elided = e.m.elidedInCompatabilityPyramid == true; // [sic] spelling as in Strada
			final deprecated = e.m.reportsDeprecated == true;
			fields.push({
				name: names.varName,
				access: [APublic, AStatic, AFinal],
				kind: FVar(macro :ts.diagnostics.Diagnostics.Message,
					macro new ts.diagnostics.Diagnostics.Message($v{code}, ts.diagnostics.Diagnostics.Category.$category, $v{names.key}, $v{e.key},
						$v{unnecessary}, $v{elided}, $v{deprecated})),
				pos: pos,
			});
			all.push(macro $i{names.varName});
		}
		fields.push({
			name: "allMessages",
			access: [AStatic, AFinal],
			kind: FVar(macro :Array<ts.diagnostics.Diagnostics.Message>, macro $a{all}),
			pos: pos,
		});
		return fields;
	}

	static function convertPropertyName(origName:String, code:Int):{varName:String, key:String} {
		final b = new StringBuf();
		for (i in 0...origName.length) {
			final c = origName.charAt(i);
			switch c {
				case "*": b.add("_Asterisk");
				case "/": b.add("_Slash");
				case ":": b.add("_Colon");
				case _: b.add(~/^[A-Za-z0-9]$/.match(c) ? c : "_"); // keys are ASCII (checked)
			}
		}
		var varName = b.toString();
		varName = ~/_+/g.replace(varName, "_");
		varName = ~/^_+([^0-9])/.replace(varName, "$1");
		varName = ~/_$/.replace(varName, "");

		var key = varName;
		if (key.length > 100)
			key = key.substr(0, 100);
		key = key + "_" + code;

		final first = varName.charCodeAt(0);
		if (!(first >= "A".code && first <= "Z".code))
			varName = (varName.charAt(0) == "_" ? "X" : "X_") + varName;
		return {varName: varName, key: key};
	}
}
#end
