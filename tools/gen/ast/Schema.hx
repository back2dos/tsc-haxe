// Port of upstream tsc/_scripts/schema.ts (the parts the Go generator uses) for GenAst.
// Reads _scripts/ast.json with an order-preserving JSON parser: the generated code follows the
// key order of ast.json, exactly like the TypeScript generator.

// ── Order-preserving JSON ─────────────────────────────────────────────────

enum JValue {
	JNull;
	JBool(b:Bool);
	JNum(f:Float);
	JStr(s:String);
	JArr(a:Array<JValue>);
	JObj(o:JObject);
}

class JObject {
	public final keys:Array<String> = [];
	public final map:Map<String, JValue> = new Map();

	public function new() {}

	public inline function has(k:String):Bool
		return map.exists(k);

	public function get(k:String):Null<JValue>
		return map.get(k);

	public function str(k:String):Null<String> {
		return switch (map.get(k)) {
			case JStr(s): s;
			default: null;
		}
	}

	public function bool(k:String):Null<Bool> {
		return switch (map.get(k)) {
			case JBool(b): b;
			default: null;
		}
	}

	public function obj(k:String):Null<JObject> {
		return switch (map.get(k)) {
			case JObj(o): o;
			default: null;
		}
	}

	public function arr(k:String):Null<Array<JValue>> {
		return switch (map.get(k)) {
			case JArr(a): a;
			default: null;
		}
	}
}

class JsonParser {
	final s:String;
	var i = 0;

	function new(s:String) {
		this.s = s;
	}

	public static function parse(s:String):JValue {
		final p = new JsonParser(s);
		final v = p.value();
		p.ws();
		if (p.i != s.length)
			throw "trailing JSON data";
		return v;
	}

	function ws() {
		while (i < s.length) {
			final c = s.charCodeAt(i);
			if (c == 32 || c == 9 || c == 10 || c == 13)
				i++;
			else
				break;
		}
	}

	function value():JValue {
		ws();
		final c = s.charAt(i);
		switch (c) {
			case "{":
				i++;
				final o = new JObject();
				ws();
				if (s.charAt(i) == "}") {
					i++;
					return JObj(o);
				}
				while (true) {
					ws();
					final k = string();
					ws();
					expect(":");
					final v = value();
					if (!o.map.exists(k))
						o.keys.push(k);
					o.map.set(k, v);
					ws();
					if (s.charAt(i) == ",") {
						i++;
						continue;
					}
					expect("}");
					return JObj(o);
				}
			case "[":
				i++;
				final a = [];
				ws();
				if (s.charAt(i) == "]") {
					i++;
					return JArr(a);
				}
				while (true) {
					a.push(value());
					ws();
					if (s.charAt(i) == ",") {
						i++;
						continue;
					}
					expect("]");
					return JArr(a);
				}
			case '"':
				return JStr(string());
			case "t":
				i += 4;
				return JBool(true);
			case "f":
				i += 5;
				return JBool(false);
			case "n":
				i += 4;
				return JNull;
			default:
				final start = i;
				while (i < s.length && "+-0123456789.eE".indexOf(s.charAt(i)) >= 0)
					i++;
				return JNum(Std.parseFloat(s.substring(start, i)));
		}
	}

	function expect(c:String) {
		if (s.charAt(i) != c)
			throw 'expected $c at $i';
		i++;
	}

	function string():String {
		expect('"');
		final b = new StringBuf();
		while (true) {
			final c = s.charAt(i++);
			if (c == '"')
				break;
			if (c == "\\") {
				final e = s.charAt(i++);
				switch (e) {
					case "n":
						b.add("\n");
					case "t":
						b.add("\t");
					case "r":
						b.add("\r");
					case "u":
						b.addChar(Std.parseInt("0x" + s.substr(i, 4)));
						i += 4;
					default:
						b.add(e);
				}
			} else {
				b.add(c);
			}
		}
		return b.toString();
	}
}

// ── Types ────────────────────────────────────────────────────────────────

class SType {
	public final api:SchemaAPI;
	public final kind:String; // alias | list | primitive | kind | node | typeParameter | union

	function new(api:SchemaAPI, kind:String) {
		this.api = api;
		this.kind = kind;
	}

	public function formatGoReference():String
		throw "abstract";

	public function baseKind():String
		throw "abstract";

	public function concreteNodeName():Null<String>
		return null;
}

class PrimitiveType extends SType {
	public final name:String;

	public function new(api, name:String) {
		super(api, "primitive");
		this.name = name;
	}

	override public function formatGoReference()
		return name;

	override public function baseKind()
		return "primitive";
}

class KindType extends SType {
	public final value:String;

	public function new(api, value:String) {
		super(api, "kind");
		this.value = value;
	}

	override public function formatGoReference()
		return "Kind";

	override public function baseKind()
		return "kind";

	public var name(get, never):String;

	function get_name()
		return StringTools.startsWith(value, "SyntaxKind.") ? value.substr("SyntaxKind.".length) : value;

	public function formatGoConstant():String
		return value == "Kind" ? "Kind" : 'Kind$name';
}

class TypeParameterType extends SType {
	public final name:String;
	public final constraint:SType;

	public function new(api, name:String, constraint:SType) {
		super(api, "typeParameter");
		this.name = name;
		this.constraint = constraint;
	}

	override public function formatGoReference()
		return constraint.formatGoReference();

	override public function baseKind()
		return constraint.baseKind();

	override public function concreteNodeName():Null<String> {
		return switch (constraint.kind) {
			case "node" | "alias" | "typeParameter": constraint.concreteNodeName();
			default: null;
		}
	}
}

class AliasType extends SType {
	public final name:String;
	public final resolved:SType;
	public final resolveAs:Null<String>;

	public function new(api, name:String, resolved:SType, ?resolveAs:String) {
		super(api, "alias");
		this.name = name;
		this.resolved = resolved;
		this.resolveAs = resolveAs;
	}

	override public function formatGoReference() {
		return baseKind() == "node" || (baseKind() == "list" && (cast resolved : ListType).listKind != "raw") ? '*$name' : name;
	}

	override public function baseKind()
		return resolved.baseKind();

	override public function concreteNodeName():Null<String>
		return api.instantiationAliasMap.get(name);

	public function isUnion():Bool {
		return switch (api.nodeAliasesObj.get(name)) {
			case JArr(_): true;
			default: false;
		}
	}

	public function isBaseAlias():Bool {
		return switch (api.nodeAliasesObj.get(name)) {
			case JObj(_): true;
			default: false;
		}
	}

	public function unionMemberNames():Array<String> {
		return switch (api.nodeAliasesObj.get(name)) {
			case JArr(a): [for (x in a) SchemaAPI.s(x)];
			default: [];
		}
	}

	public function baseKey():Null<String> {
		return switch (api.nodeAliasesObj.get(name)) {
			case JObj(o): o.str("base");
			default: null;
		}
	}

	public function elementTypeName():Null<String>
		return api.listAliasesObj == null ? null : api.listAliasesObj.str(name);
}

class UnionType extends SType {
	public final types:Array<SType>;

	public function new(api, types:Array<SType>) {
		super(api, "union");
		this.types = types;
	}

	override public function formatGoReference() {
		final concreteNodes:Array<String> = [];
		var allConcreteNodes = true;
		for (type in types) {
			final nodeName = switch (type.kind) {
				case "node" | "alias" | "typeParameter": type.concreteNodeName();
				default: null;
			}
			if (nodeName == null) {
				allConcreteNodes = false;
				break;
			}
			if (concreteNodes.indexOf(nodeName) < 0)
				concreteNodes.push(nodeName);
		}
		if (allConcreteNodes && concreteNodes.length == 1)
			return '*${concreteNodes[0]}Node';
		if (Lambda.exists(types, t -> t.baseKind() == "node" || t.baseKind() == "list"))
			return "*Node";
		if (Lambda.foreach(types, t -> t.baseKind() == "kind"))
			return "Kind";
		final refs:Array<String> = [];
		for (t in types) {
			final r = t.formatGoReference();
			if (refs.indexOf(r) < 0)
				refs.push(r);
		}
		if (refs.length == 1)
			return refs[0];
		throw 'Cannot resolve Go reference form for union ${refs.join(" | ")}';
	}

	override public function baseKind() {
		final kinds:Array<String> = [];
		for (t in types)
			if (kinds.indexOf(t.baseKind()) < 0)
				kinds.push(t.baseKind());
		if (kinds.length == 1)
			return types[0].baseKind();
		if (Lambda.exists(types, t -> t.baseKind() == "list" || t.baseKind() == "node"))
			return "node";
		if (Lambda.exists(types, t -> t.baseKind() == "kind"))
			return "kind";
		return "primitive";
	}
}

class ListType extends SType {
	public final elementType:SType;
	public final listKind:String; // NodeList | ModifierList | raw

	public function new(api, elementType:SType, listKind:String) {
		super(api, "list");
		this.elementType = elementType;
		this.listKind = listKind;
	}

	override public function formatGoReference() {
		if (listKind == "raw")
			return elementType.baseKind() == "node" ? "[]*Node" : '[]${elementType.formatGoReference()}';
		if (listKind == "ModifierList")
			return "*ModifierList";
		final alias = api.listAliasName(elementType);
		return '*${alias != null ? alias : "NodeList"}';
	}

	override public function baseKind()
		return elementType.baseKind() == "node" ? "list" : elementType.baseKind();
}

class NodeType extends SType {
	public final name:String;

	var membersCache:Null<Array<MemberInfo>>;
	var fieldsCache:Null<Array<MemberInfo>>;

	public function new(api, name:String) {
		super(api, "node");
		this.name = name;
	}

	override public function formatGoReference()
		return api.hasNode(name) ? '*${name}Node' : '*$name';

	override public function baseKind()
		return "node";

	override public function concreteNodeName():Null<String> {
		if (def == null)
			throw '$name is not a concrete node';
		return name;
	}

	public var def(get, never):Null<JObject>;

	function get_def()
		return api.definitions.obj(name);

	public var entry(get, never):Null<JObject>;

	function get_entry()
		return api.basesObj.obj(name);

	public var syntaxKindName(get, never):String;

	function get_syntaxKindName():String {
		if (def == null)
			return name;
		return switch (def.get("kind")) {
			case JArr(a): SchemaAPI.s(a[0]);
			case JStr(s): s;
			default: name;
		}
	}

	public var extendsKeys(get, never):Array<String>;

	function get_extendsKeys():Array<String> {
		final a = def != null ? def.arr("extends") : (entry != null ? entry.arr("extends") : null);
		return a == null ? [] : [for (x in a) SchemaAPI.s(x)];
	}

	public var extendsTypes(get, never):Array<NodeType>;

	function get_extendsTypes()
		return [for (k in extendsKeys) if (api.getBase(k) != null) api.getBase(k)];

	public var members(get, never):Array<MemberInfo>;

	function get_members() {
		if (membersCache == null) {
			membersCache = [];
			final a = def != null ? def.arr("members") : null;
			if (a != null)
				for (m in a) {
					final o = SchemaAPI.o(m);
					membersCache.push(new MemberInfo(api, o.str("name"), o, null, this));
				}
		}
		return membersCache;
	}

	public var kindAliases(get, never):Array<String>;

	function get_kindAliases():Array<String> {
		if (def == null)
			return [];
		return switch (def.get("kind")) {
			case JArr(a): [for (i in 1...a.length) SchemaAPI.s(a[i])];
			default: [];
		}
	}

	public var fields(get, never):Array<MemberInfo>;

	function get_fields() {
		if (fieldsCache == null) {
			fieldsCache = [];
			final f = entry != null ? entry.obj("fields") : null;
			if (f != null)
				for (k in f.keys)
					fieldsCache.push(new MemberInfo(api, k, null, f.obj(k), null));
		}
		return fieldsCache;
	}

	function defFlag(k:String):Bool
		return def != null && def.bool(k) == true;

	public var arena(get, never):Bool;

	function get_arena()
		return defFlag("arena");

	public var handWritten(get, never):Bool;

	function get_handWritten()
		return defFlag("handWritten");

	public var handWrittenVisitor(get, never):Bool;

	function get_handWrittenVisitor()
		return defFlag("handWrittenVisitor");

	public var generateSubtreeFacts(get, never):Bool;

	function get_generateSubtreeFacts()
		return defFlag("generateSubtreeFacts");

	public function instantiationAliases():Array<{name:String, typeArg:String}> {
		final o = def != null ? def.obj("instantiationAliases") : null;
		return o == null ? [] : [for (k in o.keys) {name: k, typeArg: o.str(k)}];
	}

	public function kindMember():Null<MemberInfo> {
		for (m in members)
			if (m.name == "Kind" || m.name == "kind")
				return m;
		return null;
	}

	public var kindType(get, never):SType;

	function get_kindType():SType {
		final km = kindMember();
		return km != null ? km.declaredType : api.kindType('SyntaxKind.$syntaxKindName');
	}

	public function field(n:String):Null<MemberInfo> {
		for (f in fields)
			if (f.name == n)
				return f;
		return null;
	}

	public function inheritedField(n:String):Null<MemberInfo> {
		for (base in extendsTypes) {
			final direct = base.field(n);
			if (direct != null)
				return direct;
			final inh = base.inheritedField(n);
			if (inh != null)
				return inh;
		}
		return null;
	}

	public function kindTypes():Array<KindType> {
		function collect(type:SType):Array<KindType> {
			return switch (type.kind) {
				case "kind":
					final k:KindType = cast type;
					k.value == "Kind" ? [] : [k];
				case "union":
					var r = [];
					for (t in (cast type : UnionType).types)
						r = r.concat(collect(t));
					r;
				case "alias": collect((cast type : AliasType).resolved);
				case "typeParameter": collect((cast type : TypeParameterType).constraint);
				default: [];
			}
		}
		final kts = collect(kindType);
		if (kts.length == 0)
			return [api.kindType('SyntaxKind.$syntaxKindName')];
		// Deduplicate by value, keeping first occurrence order (JS Map semantics).
		final seen = new Map<String, Bool>();
		final r = [];
		for (k in kts)
			if (!seen.exists(k.value)) {
				seen.set(k.value, true);
				r.push(k);
			}
		return r;
	}

	public function isMultiKind():Bool
		return kindTypes().length > 1;

	public function allKinds():Array<KindType> {
		return kindTypes().concat([for (a in kindAliases) api.kindType('SyntaxKind.$a')]);
	}
}

class MemberInfo {
	final api:SchemaAPI;

	public final name:String;
	public final member:Null<JObject>;
	public final fieldDef:Null<JObject>;
	public final node:Null<NodeType>;

	public function new(api:SchemaAPI, name:String, member:Null<JObject>, field:Null<JObject>, node:Null<NodeType>) {
		this.api = api;
		this.name = name;
		this.member = member;
		this.fieldDef = field;
		this.node = node;
	}

	public var declaredType(get, never):SType;

	function get_declaredType()
		return api.resolveType(rawType, node != null ? node.def : null);

	public var type(get, never):SType;

	function get_type()
		return listKind != null ? api.listType(declaredType, listKind) : declaredType;

	public var rawType(get, never):JValue;

	function get_rawType():JValue {
		if (fieldDef != null)
			return fieldDef.get("type");
		if (member != null && !inherited)
			return member.get("type");
		if (member != null && inherited && member.has("type"))
			return member.get("type");
		if (inheritedField != null)
			return inheritedField.rawType;
		if (member != null)
			return member.get("type");
		throw 'Member $name has no raw type source';
	}

	public var listKind(get, never):Null<String>;

	function get_listKind():Null<String> {
		if (fieldDef != null)
			return fieldDef.str("list");
		if (member != null && !inherited)
			return member.str("list");
		return inheritedField != null ? inheritedField.listKind : null;
	}

	public var optional(get, never):Bool;

	function get_optional():Bool {
		if (fieldDef != null && fieldDef.has("optional"))
			return fieldDef.bool("optional");
		if (member != null && member.has("optional"))
			return member.bool("optional");
		if (inheritedField != null)
			return inheritedField.optional;
		return false;
	}

	public var inherited(get, never):Bool;

	function get_inherited()
		return member != null && member.bool("inherited") == true;

	public var isPrivate(get, never):Bool;

	function get_isPrivate():Bool {
		if (fieldDef != null && fieldDef.bool("private") == true)
			return true;
		if (member != null && member.bool("private") == true)
			return true;
		return inheritedField != null ? inheritedField.isPrivate : false;
	}

	function flag(k:String):Bool {
		if (fieldDef != null && fieldDef.has(k))
			return fieldDef.bool(k);
		if (member != null && member.has(k))
			return member.bool(k);
		return false;
	}

	public var goOnly(get, never):Bool;

	function get_goOnly()
		return flag("goOnly");

	public var noGo(get, never):Bool;

	function get_noGo()
		return flag("noGo");

	public var noFactory(get, never):Bool;

	function get_noFactory()
		return goOnly || (fieldDef != null && fieldDef.bool("noFactory") == true) || (member != null && member.bool("noFactory") == true);

	public var visit(get, never):Null<String>;

	function get_visit():Null<String> {
		if (member != null && member.str("visit") != null)
			return member.str("visit");
		if (fieldDef != null && fieldDef.str("visit") != null)
			return fieldDef.str("visit");
		return inheritedField != null ? inheritedField.visit : null;
	}

	public var bitmask(get, never):Null<String>;

	function get_bitmask()
		return member != null ? member.str("bitmask") : null;

	public var inheritedField(get, never):Null<MemberInfo>;

	function get_inheritedField():Null<MemberInfo> {
		if (!inherited || node == null)
			return null;
		return node.inheritedField(name);
	}

	public function isKindParam():Bool {
		if (member == null || node == null)
			return false;
		if (name != "Kind" && name != "kind")
			return false;
		return declaredType.baseKind() == "kind";
	}

	public function isChild():Bool {
		if (member == null || node == null)
			return false;
		return type.baseKind() == "list" || type.baseKind() == "node";
	}

	/** Go parameter name: uncapitalized, with Go keyword avoidance. */
	public function goParamName():String {
		final n = api.uncapitalize(name);
		if (n == "type")
			return "typeNode";
		if (n == "default")
			return "defaultNode";
		if (n == "case")
			return "caseNode";
		return n;
	}
}

// ── SchemaAPI ────────────────────────────────────────────────────────────

class SchemaAPI {
	public final root:JObject;
	public final basesObj:JObject;
	public final definitions:JObject;
	public final nodeAliasesObj:JObject;
	public final listAliasesObj:Null<JObject>;
	public final kindsObj:JObject;

	final listAliasNameMap = new Map<String, String>();

	public final instantiationAliasMap = new Map<String, String>();

	final syntaxKindToNodeInfo = new Map<String, {aliasName:Null<String>, nodeName:String}>();
	final nodeTypeMap = new Map<String, NodeType>();
	final primitiveTypes = ["any", "bool", "boolean", "int", "ModifierFlags", "NodeFlags", "string", "TokenFlags"];

	public static function s(v:JValue):String {
		return switch (v) {
			case JStr(x): x;
			default: throw "expected string";
		}
	}

	public static function o(v:JValue):JObject {
		return switch (v) {
			case JObj(x): x;
			default: throw "expected object";
		}
	}

	public function new(root:JObject) {
		this.root = root;
		basesObj = root.obj("bases");
		final nodes = root.obj("nodes");
		definitions = nodes.obj("definitions");
		nodeAliasesObj = nodes.obj("aliases");
		listAliasesObj = nodes.obj("listAliases");
		kindsObj = root.obj("kinds");
		if (listAliasesObj != null)
			for (aliasName in listAliasesObj.keys)
				listAliasNameMap.set(typeCacheKey(resolveType(listAliasesObj.get(aliasName))), aliasName);
		for (nodeName in definitions.keys) {
			final nodeDef = definitions.obj(nodeName);
			final ia = nodeDef.obj("instantiationAliases");
			if (ia != null) {
				for (aliasName in ia.keys)
					instantiationAliasMap.set(aliasName, nodeName);
				for (aliasName in ia.keys) {
					final typeArg = ia.str(aliasName);
					if (hasKindAlias(typeArg)) {
						for (kt in expandKindAliasMembers(typeArg))
							if (!syntaxKindToNodeInfo.exists(kt.name))
								syntaxKindToNodeInfo.set(kt.name, {aliasName: aliasName, nodeName: nodeName});
					} else if (!syntaxKindToNodeInfo.exists(typeArg)) {
						syntaxKindToNodeInfo.set(typeArg, {aliasName: aliasName, nodeName: nodeName});
					}
				}
			}
			final kindV = nodeDef.get("kind");
			final primaryKind = switch (kindV) {
				case JArr(a): s(a[0]);
				case JStr(x): x;
				default: nodeName;
			}
			if (!syntaxKindToNodeInfo.exists(primaryKind))
				syntaxKindToNodeInfo.set(primaryKind, {aliasName: null, nodeName: nodeName});
			switch (kindV) {
				case JArr(a):
					for (i in 1...a.length)
						if (!syntaxKindToNodeInfo.exists(s(a[i])))
							syntaxKindToNodeInfo.set(s(a[i]), {aliasName: null, nodeName: nodeName});
				default:
			}
		}
	}

	public function capitalize(x:String):String
		return x.charAt(0).toUpperCase() + x.substr(1);

	public function uncapitalize(x:String):String {
		if (StringTools.startsWith(x, "JSDoc"))
			return "jsdoc" + x.substr(5);
		return x.charAt(0).toLowerCase() + x.substr(1);
	}

	public function bases():Array<NodeType>
		return [for (k in basesObj.keys) nodeType(k)];

	public function getBase(key:String):Null<NodeType>
		return basesObj.has(key) ? nodeType(key) : null;

	public function nodes():Array<NodeType>
		return [for (k in definitions.keys) nodeType(k)];

	public function getNode(key:String):Null<NodeType>
		return definitions.has(key) ? nodeType(key) : null;

	public function hasNode(key:String):Bool
		return definitions.has(key);

	public function nodeAliases():Array<AliasType> {
		final r = [];
		for (n in nodeAliasesObj.keys) {
			final t = resolveType(JStr(n));
			if (t.kind == "alias")
				r.push((cast t : AliasType));
		}
		return r;
	}

	public function listAliases():Array<AliasType> {
		final r = [];
		if (listAliasesObj != null)
			for (n in listAliasesObj.keys) {
				final t = resolveType(JStr(n));
				if (t.kind == "alias")
					r.push((cast t : AliasType));
			}
		return r;
	}

	public function kindElements():Array<{name:Null<String>, comment:Null<String>}> {
		return [
			for (e in kindsObj.arr("elements")) switch (e) {
				case JStr(x): {name: x, comment: null};
				case JObj(ob): {name: ob.str("name"), comment: ob.str("comment")};
				default: throw "bad kind element";
			}
		];
	}

	public function kindMarkers():Array<{name:String, value:String}> {
		return [for (m in kindsObj.arr("markers")) {name: o(m).str("name"), value: o(m).str("value")}];
	}

	public function resolveKindMarkerValue(n:String):String {
		for (m in kindMarkers())
			if (m.name == n)
				return resolveKindMarkerValue(m.value);
		return n;
	}

	public function kindAliases():Array<{name:String, members:Array<String>, range:Null<Array<String>>}> {
		final al = kindsObj.obj("aliases");
		final r = [];
		if (al == null)
			return r;
		for (n in al.keys) {
			switch (al.get(n)) {
				case JArr(a):
					r.push({name: n, members: [for (x in a) s(x)], range: null});
				case JObj(ob):
					final range = [for (x in ob.arr("range")) s(x)];
					final elements = [for (e in kindElements()) if (e.name != null) e.name];
					final firstIdx = elements.indexOf(resolveKindMarkerValue(range[0]));
					final lastIdx = elements.indexOf(resolveKindMarkerValue(range[1]));
					if (firstIdx == -1 || lastIdx == -1)
						throw 'Range alias $n: could not resolve range';
					r.push({name: n, members: elements.slice(firstIdx, lastIdx + 1), range: range});
				default:
					throw "bad kind alias";
			}
		}
		return r;
	}

	public function hasKindAlias(n:String):Bool {
		final al = kindsObj.obj("aliases");
		return al != null && al.has(n);
	}

	public function getKindAlias(n:String) {
		for (a in kindAliases())
			if (a.name == n)
				return a;
		return null;
	}

	public function expandKindAliasMembers(n:String):Array<KindType> {
		final alias = getKindAlias(n);
		if (alias == null)
			return [kindType('SyntaxKind.$n')];
		var r:Array<KindType> = [];
		for (m in alias.members) {
			if (hasKindAlias(m))
				r = r.concat(expandKindAliasMembers(m));
			else
				r.push(kindType('SyntaxKind.$m'));
		}
		return r;
	}

	public function resolveNodeTypeForSyntaxKind(syntaxKindName:String):Null<SType> {
		final info = syntaxKindToNodeInfo.get(syntaxKindName);
		if (info == null)
			return null;
		if (info.aliasName != null)
			return new AliasType(this, info.aliasName, nodeType(info.nodeName));
		return nodeType(info.nodeName);
	}

	public function resolveType(typeName:JValue, ?node:JObject, ?resolveAs:String):SType {
		switch (typeName) {
			case JArr(a):
				return new UnionType(this, [for (t in a) resolveType(t, node, resolveAs)]);
			default:
		}
		final tn = s(typeName);
		if (node != null && node.arr("typeParameters") != null) {
			for (tpv in node.arr("typeParameters")) {
				final tp = o(tpv);
				if (tp.str("name") == tn) {
					final constraint = tp.str("constraint") == tn ? (new PrimitiveType(this, tn) : SType) : resolveType(JStr(tp.str("constraint")), node);
					return new TypeParameterType(this, tn, constraint);
				}
			}
		}
		final kal = kindsObj.obj("aliases");
		if (kal != null && kal.has(tn)) {
			if (resolveAs == "node") {
				return new UnionType(this, [
					for (kt in expandKindAliasMembers(tn)) {
						final r = resolveNodeTypeForSyntaxKind(kt.name);
						if (r == null)
							throw 'Kind alias member ${kt.name} does not resolve to a node type';
						r;
					}
				]);
			}
			return new AliasType(this, tn, new UnionType(this, cast expandKindAliasMembers(tn)));
		}
		if (tn == "Kind" || StringTools.startsWith(tn, "SyntaxKind."))
			return kindType(tn);
		if (tn == "Node")
			return nodeType(tn);
		if (primitiveTypes.indexOf(tn) >= 0)
			return new PrimitiveType(this, tn);
		if (listAliasesObj != null && listAliasesObj.has(tn))
			return new AliasType(this, tn, listType(resolveType(listAliasesObj.get(tn), node), "NodeList"));
		final inst = instantiationAliasMap.get(tn);
		if (inst != null)
			return new AliasType(this, tn, nodeType(inst));
		if (nodeAliasesObj.has(tn)) {
			switch (nodeAliasesObj.get(tn)) {
				case JArr(a):
					return new AliasType(this, tn, new UnionType(this, [for (t in a) resolveType(t, node, "node")]), "node");
				case JObj(ob):
					return new AliasType(this, tn, nodeType(ob.str("base")));
				default:
			}
		}
		if (definitions.has(tn))
			return nodeType(tn);
		if (basesObj.has(tn))
			return nodeType(tn);
		return new PrimitiveType(this, tn);
	}

	public function kindType(value:String):KindType
		return new KindType(this, value);

	public function nodeType(n:String):NodeType {
		var t = nodeTypeMap.get(n);
		if (t == null) {
			t = new NodeType(this, n);
			nodeTypeMap.set(n, t);
		}
		return t;
	}

	public function listType(elementType:SType, listKind:String):ListType
		return new ListType(this, elementType, listKind);

	public function listAliasName(elementType:SType):Null<String>
		return listAliasNameMap.get(typeCacheKey(elementType));

	public function typeCacheKey(type:SType):String {
		return switch (type.kind) {
			case "primitive": 'primitive:${(cast type : PrimitiveType).name}';
			case "kind": 'kind:${(cast type : KindType).value}';
			case "node": 'node:${(cast type : NodeType).name}';
			case "alias":
				final a:AliasType = cast type;
				'alias:${a.name}:${typeCacheKey(a.resolved)}';
			case "list":
				final l:ListType = cast type;
				'list:${l.listKind}:${typeCacheKey(l.elementType)}';
			case "typeParameter":
				final p:TypeParameterType = cast type;
				'typeParameter:${p.name}:${typeCacheKey(p.constraint)}';
			case "union": 'union:${[for (t in (cast type : UnionType).types) typeCacheKey(t)].join("|")}';
			default: throw "bad type";
		}
	}
}
