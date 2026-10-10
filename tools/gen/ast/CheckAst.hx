// Structural cross-check of the generated Haxe AST against the upstream generated Go code.
// Parses upstream internal/ast/{ast_generated.go, ast.go, kind_generated.go} (independently of
// ast.json) and src/ts/ast/{AstGenerated.hx, Ast.hx, KindGenerated.hx}, then checks:
//   - every Go node data struct has a Haxe class with the same flattened field set (Go embedding
//     resolved here; the fields of Go `Node` itself live in NodeDefault and are not compared);
//   - ForEachChild visits the same fields in the same order;
//   - VisitEachChild passes the same visitor calls in the same order;
//   - every NodeFactory New*/Update* method exists with the same parameter names;
//   - every Is*() function and As*() cast exists;
//   - every Kind constant exists with the same value.
// Run from the project root: tools/haxe -cp tools/gen/ast --run CheckAst
import sys.io.File;

using StringTools;

class CheckAst {
	static inline final GO = "upstream/tsc/internal/ast/";
	static inline final HX = "src/ts/ast/";
	static var errors = 0;

	static function err(msg:String) {
		errors++;
		if (errors <= 50)
			Sys.println("MISMATCH " + msg);
	}

	static function main() {
		final goGen = File.getContent(GO + "ast_generated.go");
		final goAst = File.getContent(GO + "ast.go");
		final goKind = File.getContent(GO + "kind_generated.go");
		final hxGen = File.getContent(HX + "AstGenerated.hx");
		final hxAst = File.getContent(HX + "Ast.hx");
		final hxKind = File.getContent(HX + "KindGenerated.hx");

		// ── Go structs ──
		final structs = new Map<String, {embeds:Array<String>, fields:Array<String>}>();
		final structRe = ~/^type ([A-Za-z0-9_]+) struct ?\{(\}|\n([\s\S]*?)^\})/m;
		for (src in [goGen, goAst]) {
			var s = src;
			while (structRe.match(s)) {
				final name = structRe.matched(1);
				final body = structRe.matched(3);
				final embeds = [], fields = [];
				if (body != null)
					for (line in body.split("\n")) {
						final l = line.trim();
						if (l == "" || l.startsWith("//"))
							continue;
						final parts = l.split("//")[0].trim().split(" ").filter(x -> x != "");
						if (parts.length == 1)
							embeds.push(parts[0]);
						else
							fields.push(parts[0]);
					}
				structs.set(name, {embeds: embeds, fields: fields});
				s = structRe.matchedRight();
			}
		}
		// Node data structs = structs with a generated Clone method in ast_generated.go.
		final nodeStructs = [];
		final cloneRe = ~/^func \(node \*([A-Za-z0-9_]+)\) Clone\(f NodeFactoryCoercible\) \*Node \{/m;
		var s = goGen;
		while (cloneRe.match(s)) {
			nodeStructs.push(cloneRe.matched(1));
			s = cloneRe.matchedRight();
		}

		function goFields(name:String, out:Map<String, Bool>) {
			if (name == "NodeBase" || name == "NodeDefault" || name == "Node")
				return;
			final st = structs.get(name);
			if (st == null)
				throw 'unknown Go struct $name';
			for (e in st.embeds)
				goFields(e, out);
			for (f in st.fields)
				out.set(f, true);
		}

		// ── Haxe classes ──
		final hxClasses = new Map<String, {fields:Array<String>, body:String}>();
		final classRe = ~/^class ([A-Za-z0-9_]+) extends NodeDefault[^{]*\{\n([\s\S]*?)^\}/m;
		s = hxGen;
		while (classRe.match(s)) {
			final body = classRe.matched(2);
			final fields = [];
			final fre = ~/^\t(?:@:isVar )?public var ([A-Za-z0-9_]+)/;
			for (line in body.split("\n"))
				if (fre.match(line))
					fields.push(fre.matched(1));
			hxClasses.set(classRe.matched(1), {fields: fields, body: body});
			s = classRe.matchedRight();
		}

		var structCount = 0, fieldCount = 0, fecCount = 0, vecCount = 0;
		for (name in nodeStructs) {
			final cls = hxClasses.get(name);
			if (cls == null) {
				err('class $name missing');
				continue;
			}
			structCount++;
			final gf = new Map<String, Bool>();
			goFields(name, gf);
			final gl = [for (k in gf.keys()) k];
			gl.sort(Reflect.compare);
			final hl = cls.fields.copy();
			hl.sort(Reflect.compare);
			if (gl.join(",") != hl.join(","))
				err('$name fields: go [${gl.join(",")}] haxe [${hl.join(",")}]');
			else
				fieldCount += gl.length;

			// ForEachChild
			final goFec = methodBody(goGen, name, "ForEachChild");
			final hxFec = hxMethodBody(cls.body, "ForEachChild");
			if ((goFec == null) != (hxFec == null)) {
				err('$name ForEachChild presence: go ${goFec != null} haxe ${hxFec != null}');
			} else if (goFec != null) {
				final g = calls(goFec, ~/(visit[A-Za-z]*|forEachChild_[A-Za-z]+)\((?:v, node\.([A-Za-z]+)|node, v)\)/);
				final h = calls(hxFec, ~/Ast\.(visit[A-Za-z]*|forEachChild_[A-Za-z]+)\((?:v, this\.([A-Za-z]+)|this, v)\)/);
				if (g != h)
					err('$name ForEachChild: go [$g] haxe [$h]');
				else
					fecCount++;
			}

			// VisitEachChild
			final goVec = methodBody(goGen, name, "VisitEachChild");
			final hxVec = hxMethodBody(cls.body, "VisitEachChild");
			if ((goVec == null) != (hxVec == null)) {
				err('$name VisitEachChild presence');
			} else if (goVec != null) {
				final g = calls(goVec, ~/(v\.visit[A-Za-z]*|visitEachChild_[A-Za-z]+)\((?:node\.([A-Za-z]+)|node, v|n)\)/);
				final h = calls(hxVec, ~/(v\.visit[A-Za-z]*|Ast\.visitEachChild_[A-Za-z]+)\((?:this\.([A-Za-z]+)|this, v|n)\)/).replace("Ast.", "");
				if (g != h)
					err('$name VisitEachChild: go [$g] haxe [$h]');
				else
					vecCount++;
			}
		}
		for (name in hxClasses.keys())
			if (nodeStructs.indexOf(name) < 0)
				err('extra Haxe class $name');

		// ── Factory methods ──
		var factoryCount = 0;
		final goFactRe = ~/^func \(f \*NodeFactory\) ((?:New|Update)[A-Za-z0-9_]+)\(([^)]*)\) \*Node \{/m;
		final hxFactories = new Map<String, String>();
		final hxFactRe = ~/^\tpublic function ((?:New|Update)[A-Za-z0-9_]+)\(([^)]*)\):Node \{/m;
		s = hxAst;
		while (hxFactRe.match(s)) {
			hxFactories.set(hxFactRe.matched(1), paramNames(hxFactRe.matched(2), ":"));
			s = hxFactRe.matchedRight();
		}
		s = goGen;
		while (goFactRe.match(s)) {
			final n = goFactRe.matched(1);
			final g = paramNames(goFactRe.matched(2), " ");
			final h = hxFactories.get(n);
			if (h == null)
				err('factory $n missing');
			else if (g != h.replace("operator_", "operator"))
				err('factory $n params: go ($g) haxe ($h)');
			else
				factoryCount++;
			s = goFactRe.matchedRight();
		}

		// ── Is*() functions and As*() casts ──
		var isCount = 0, asCount = 0;
		final isRe = ~/^func (Is[A-Za-z0-9_]+)\((node \*Node|kind Kind)\) bool \{/m;
		s = goGen;
		while (isRe.match(s)) {
			if (hxAst.indexOf('\tpublic static function ${isRe.matched(1)}(') < 0)
				err('${isRe.matched(1)} missing');
			else
				isCount++;
			s = isRe.matchedRight();
		}
		final asRe = ~/^func \(n \*Node\) (As[A-Za-z0-9_]+)\(\) \*([A-Za-z0-9_]+) \{/m;
		s = goGen;
		while (asRe.match(s)) {
			if (hxAst.indexOf('\tpublic inline function ${asRe.matched(1)}():${asRe.matched(2)} {') < 0)
				err('${asRe.matched(1)} missing');
			else
				asCount++;
			s = asRe.matchedRight();
		}

		// ── Kind values ──
		final goKinds = new Map<String, Int>();
		var value = 0;
		final constBlock = goKind.substring(goKind.indexOf("const ("), goKind.indexOf("\n)", goKind.indexOf("const (")));
		for (line in constBlock.split("\n").slice(1)) {
			final l = line.split("//")[0].trim();
			if (l == "")
				continue;
			final parts = l.split("=").map(x -> x.trim());
			final name = parts[0].split(" ")[0];
			if (parts.length == 1 || parts[1] == "iota") {
				goKinds.set(name, value++);
			} else {
				goKinds.set(name, goKinds.get(parts[1]));
			}
		}
		final hxKinds = new Map<String, Int>();
		final kre = ~/^\tvar (Kind[A-Za-z0-9_]+) = ([A-Za-z0-9_]+);/;
		for (line in hxKind.split("\n"))
			if (kre.match(line)) {
				final v = kre.matched(2);
				hxKinds.set(kre.matched(1), v.startsWith("Kind") ? hxKinds.get(v) : Std.parseInt(v));
			}
		var kindCount = 0;
		for (k in goKinds.keys()) {
			if (hxKinds.get(k) != goKinds.get(k))
				err('$k: go ${goKinds.get(k)} haxe ${hxKinds.get(k)}');
			else
				kindCount++;
		}

		Sys.println('node structs/classes: $structCount/${nodeStructs.length} (fields compared: $fieldCount)');
		Sys.println('ForEachChild bodies: $fecCount, VisitEachChild bodies: $vecCount');
		Sys.println('factory New/Update methods: $factoryCount, Is* functions: $isCount, As* casts: $asCount, Kind constants: $kindCount');
		Sys.println('mismatches: $errors');
		Sys.exit(errors == 0 ? 0 : 1);
	}

	static function paramNames(params:String, sep:String):String {
		if (params.trim() == "")
			return "";
		return [for (p in params.split(",")) p.trim().split(sep)[0]].join(",");
	}

	static function methodBody(src:String, type:String, method:String):Null<String> {
		final head = 'func (node *$type) $method(';
		final i = src.indexOf(head);
		if (i < 0)
			return null;
		final e = src.indexOf("\n}\n", i);
		return src.substring(i, e);
	}

	static function hxMethodBody(body:String, method:String):Null<String> {
		final head = 'override public function $method(';
		final i = body.indexOf(head);
		if (i < 0)
			return null;
		final e = body.indexOf("\n\t}\n", i);
		return body.substring(i, e);
	}

	// "fn:field fn:field ..." for every match, in order.
	static function calls(body:String, re:EReg):String {
		final out = [];
		var s = body;
		while (re.match(s)) {
			var field = null;
			try
				field = re.matched(2)
			catch (_:Dynamic) {}
			out.push(re.matched(1) + ":" + (field == null ? "" : field));
			s = re.matchedRight();
		}
		return out.join(" ");
	}
}
