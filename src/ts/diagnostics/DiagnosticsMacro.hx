package ts.diagnostics;

import haxe.macro.Expr;
#if macro
import haxe.macro.Context;
#end

// Replaces upstream internal/diagnostics/generate.go (diagnostics part).
// Adds one static field per message to class Diagnostics, plus allMessages for keyToMessage.
// embedLoc embeds a generated loc/<TgtCul>.json.gz (tools/gen/diagnostics/GenLoc.hx) as a
// haxe.Resource (Go: //go:embed in loc_generated.go).
class DiagnosticsMacro {
	public static macro function embedLoc(filename:String):Expr {
		final path = Context.resolvePath("ts/diagnostics/loc/" + filename);
		Context.registerModuleDependency(Context.getLocalModule(), path);
		// PORT: no "-" in the resource name: Haxe 5's JVM target writes it into the jar as is (genjvm, since 402d20167) but
		// haxe.Resource on the JVM looks it up escaped (Path.escape: "-x45")
		final name = "diagnostics/loc/" + StringTools.replace(filename, "-", "_");
		Context.addResource(name, sys.io.File.getBytes(path));
		return macro $v{name};
	}

#if macro
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
		// PORT: jvm — one static initializer with all ~3,000 messages exceeds the JVM's 64 KB
		// limit per method. On JVM the fields are plain statics assigned by chunk functions
		// (called from __init__, i.e. from the class initializer, in the same order).
		final chunked = Context.defined("jvm");
		final inits:Array<Expr> = [];
		for (code in codes) {
			final e = byCode.get(code);
			final names = convertPropertyName(e.key, code);
			final category = "Category" + e.m.category;
			final unnecessary = e.m.reportsUnnecessary == true;
			final elided = e.m.elidedInCompatabilityPyramid == true; // [sic] spelling as in Strada
			final deprecated = e.m.reportsDeprecated == true;
			final init = macro new ts.diagnostics.Diagnostics.Message($v{code}, ts.diagnostics.Diagnostics.Category.$category, $v{names.key}, $v{e.key},
				$v{unnecessary}, $v{elided}, $v{deprecated});
			if (chunked) {
				fields.push({
					name: names.varName,
					access: [APublic, AStatic],
					kind: FProp("default", "null", macro :ts.diagnostics.Diagnostics.Message, null),
					pos: pos,
				});
				final n = names.varName;
				inits.push(macro $i{n} = $init);
			} else {
				fields.push({
					name: names.varName,
					access: [APublic, AStatic, AFinal],
					kind: FVar(macro :ts.diagnostics.Diagnostics.Message, init),
					pos: pos,
				});
			}
			all.push(macro $i{names.varName});
		}
		if (!chunked) {
			fields.push({
				name: "allMessages",
				access: [AStatic, AFinal],
				kind: FVar(macro :Array<ts.diagnostics.Diagnostics.Message>, macro $a{all}),
				pos: pos,
			});
			return fields;
		}
		fields.push({
			name: "allMessages",
			access: [AStatic],
			kind: FVar(macro :Array<ts.diagnostics.Diagnostics.Message>, null),
			pos: pos,
		});
		final calls:Array<Expr> = [];
		var i = 0;
		while (i < inits.length) {
			final name = "initMessages" + calls.length;
			final body = inits.slice(i, i + 200);
			fields.push({
				name: name,
				access: [AStatic],
				kind: FFun({args: [], ret: macro :Void, expr: macro $b{body}}),
				pos: pos,
			});
			calls.push(macro $i{name}());
			i += 200;
		}
		final chunk = 1000;
		calls.push(macro allMessages = []);
		i = 0;
		while (i < all.length) {
			final name = "initAllMessages" + Std.int(i / chunk);
			final pushes = [for (e in all.slice(i, i + chunk)) macro allMessages.push($e)];
			fields.push({
				name: name,
				access: [AStatic],
				kind: FFun({args: [], ret: macro :Void, expr: macro $b{pushes}}),
				pos: pos,
			});
			calls.push(macro $i{name}());
			i += chunk;
		}
		fields.push({
			name: "__init__",
			access: [AStatic],
			kind: FFun({args: [], ret: macro :Void, expr: macro $b{calls}}),
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
#end
}
