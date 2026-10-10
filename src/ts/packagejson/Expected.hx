package ts.packagejson;

import haxe.ds.StringMap;

// Port of expected.go.

// PORT: reflect — Go reads the kind of T with reflect.TypeFor[T]().Kind(). Type parameters are
// erased in Haxe, so each Expected<T> is built with the kind of T. Only the kinds used in scope
// are supported for unmarshaling: string (T = String), map[string]string
// (T = StringMap<String>) and any (T = Dynamic).
enum abstract ExpectedKind(Int) {
	var KindString = 0;
	var KindBool = 1;
	var KindSlice = 2;
	var KindMap = 3;
	var KindInt = 4;
	var KindInterface = 5;
}

// PORT: Go value type; the struct is only written while unmarshaling (or copied in
// readPackageJsonPeerDependencies, which does not mutate the copy), so copies share it.
// `new Expected<T>(kind, zero)` is the Go zero value; `zero` is the zero value of T.
class Expected<T> implements TypeValidatedField {
	var actualJSONType:String = "";

	public var Null:Bool = false;
	public var Valid:Bool = false;
	public var Value:T;

	// PORT: reflect (see ExpectedKind) and Go zero value of T.
	final kind:ExpectedKind;
	final zero:T;

	public function new(kind:ExpectedKind, ?zero:T) {
		this.kind = kind;
		this.zero = zero;
		this.Value = zero;
	}

	// PORT: Go json.Unmarshaler gets the raw bytes of the value; here the decoded Jsontext.Value.
	public function UnmarshalJSON(data:Value):Null<Error> {
		if (data.Kind == "n".code) {
			// *e = Expected[T]{Null: true, actualJSONType: "null"}
			this.Null = true;
			this.actualJSONType = "null";
			this.Valid = false;
			this.Value = this.zero;
			return null;
		}
		if (unmarshalValue(data)) {
			this.Valid = true;
		}
		switch (data.Kind) {
			case '"'.code:
				this.actualJSONType = "string";
			case "t".code, "f".code:
				this.actualJSONType = "boolean";
			case "[".code:
				this.actualJSONType = "array";
			case "{".code:
				this.actualJSONType = "object";
			default:
				this.actualJSONType = "number";
		}
		return null;
	}

	// PORT: `json.Unmarshal(data, &e.Value) == nil` for the kinds in scope. Like Go, a failed
	// unmarshal leaves Value unchanged, except a map, which keeps the entries stored before the
	// error, plus the failing entry. Unmarshaling into a non-nil map adds to it (Go keeps the
	// existing entries).
	function unmarshalValue(data:Value):Bool {
		switch (kind) {
			case KindString:
				if (data.Kind != '"'.code)
					return false;
				this.Value = cast data.Str;
				return true;
			case KindMap:
				if (data.Kind != "{".code)
					return false;
				var m:StringMap<String> = cast this.Value;
				if (m == null) {
					m = new StringMap<String>();
					this.Value = cast m;
				}
				final seen = new StringMap<Bool>();
				for (i in 0...data.Names.length) {
					final name = data.Names[i];
					// Go json.Unmarshal (default options) rejects duplicate names.
					if (seen.exists(name))
						return false;
					seen.set(name, true);
					final member = data.Members[i];
					if (member.Kind == "n".code) {
						m.set(name, "");
					} else if (member.Kind == '"'.code) {
						m.set(name, member.Str);
					} else {
						// Go stores the entry (zero or previous value) before it reports the error.
						if (!m.exists(name))
							m.set(name, "");
						return false;
					}
				}
				return true;
			case KindInterface:
				final r = toAny(data);
				if (r.err != null)
					return false;
				this.Value = r.value;
				return true;
			default:
				throw "packagejson.Expected: unsupported kind"; // PORT: not used in scope
		}
	}

	// PORT: Go json.Unmarshal into `any`: object → map[string]any (StringMap here),
	// array → []any, number → float64. Duplicate names are an error.
	static function toAny(data:Value):ValueError<Dynamic> {
		switch (data.Kind) {
			case "n".code:
				return new ValueError<Dynamic>(null, null);
			case "t".code:
				return new ValueError<Dynamic>(true, null);
			case "f".code:
				return new ValueError<Dynamic>(false, null);
			case '"'.code:
				return new ValueError<Dynamic>(data.Str, null);
			case "0".code:
				return new ValueError<Dynamic>(data.Num, null);
			case "[".code:
				final a:Array<Dynamic> = [];
				for (item in data.Items) {
					final r = toAny(item);
					if (r.err != null)
						return r;
					a.push(r.value);
				}
				return new ValueError<Dynamic>(a, null);
			default:
				final m = new StringMap<Dynamic>();
				for (i in 0...data.Names.length) {
					if (m.exists(data.Names[i]))
						return new ValueError<Dynamic>(null, Errors.New("duplicate object member name " + data.Names[i]));
					final r = toAny(data.Members[i]);
					if (r.err != null)
						return r;
					m.set(data.Names[i], r.value);
				}
				return new ValueError<Dynamic>(m, null);
		}
	}

	public function IsPresent():Bool {
		return this.actualJSONType != "";
	}

	// PORT: (value T, ok bool) → ValueOk.
	public function GetValue():ValueOk<T> {
		return new ValueOk<T>(this.Value, this.Valid);
	}

	public function IsValid():Bool {
		return this.Valid;
	}

	public function ExpectedJSONType():String {
		switch (kind) {
			case KindString:
				return "string";
			case KindBool:
				return "boolean";
			case KindSlice:
				return "array";
			case KindMap:
				return "object";
			case KindInt:
				return "number";
			default:
				return "unknown";
		}
	}

	public function ActualJSONType():String {
		return this.actualJSONType;
	}

	// PORT: ExpectedOf needs to set the unexported actualJSONType.
	@:allow(ts.packagejson)
	function setActualJSONType(t:String):Void {
		this.actualJSONType = t;
	}
}
