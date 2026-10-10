package ts.packagejson;

// Port of exportsorimports.go.

enum abstract ObjectKind(Int) from Int to Int {
	var objectKindUnknown = 0;
	var objectKindSubpaths = 1;
	var objectKindConditions = 2;
	var objectKindImports = 3;
	var objectKindInvalid = 4;
}

// PORT: embedded JSONValue → composition field `JSONValue`; its fields and methods are
// promoted through forwarding properties/methods (Type, Value, IsPresent, IsFalsy, AsString)
// so call sites read like Go. Go value receivers: AsObject/AsArray/Is* run on a copy, so
// Go never keeps the computed objectKind; caching it here gives the same results.
class ExportsOrImports implements UnmarshalerFrom {
	public var JSONValue:JSONValue = new JSONValue();

	var objectKind:ObjectKind = objectKindUnknown;

	public function new() {}

	// PORT: promoted fields of the embedded JSONValue.
	public var Type(get, set):JSONValueType;
	public var Value(get, set):Any;

	inline function get_Type():JSONValueType
		return JSONValue.Type;

	inline function set_Type(v:JSONValueType):JSONValueType
		return JSONValue.Type = v;

	inline function get_Value():Any
		return JSONValue.Value;

	inline function set_Value(v:Any):Any
		return JSONValue.Value = v;

	// PORT: promoted methods of the embedded JSONValue.
	public inline function IsPresent():Bool
		return JSONValue.IsPresent();

	public inline function IsFalsy():Bool
		return JSONValue.IsFalsy();

	public inline function AsString():String
		return JSONValue.AsString();

	public function UnmarshalJSONFrom(dec:Value):Null<Error> {
		return Packagejson.unmarshalJSONValueV2(this.JSONValue, dec, () -> new ExportsOrImports());
	}

	public function AsObject():OrderedMap<String, ExportsOrImports> {
		if (this.Type != JSONValueTypeObject) {
			throw "expected object";
		}
		return cast this.Value;
	}

	public function AsArray():Array<ExportsOrImports> {
		if (this.Type != JSONValueTypeArray) {
			throw "expected array";
		}
		return cast this.Value;
	}

	public function IsSubpaths():Bool {
		this.initObjectKind();
		return this.objectKind == objectKindSubpaths;
	}

	public function IsImports():Bool {
		this.initObjectKind();
		return this.objectKind == objectKindImports;
	}

	public function IsConditions():Bool {
		this.initObjectKind();
		return this.objectKind == objectKindConditions;
	}

	function initObjectKind():Void {
		if (this.objectKind == objectKindUnknown && this.Type == JSONValueTypeObject) {
			final obj = this.AsObject();
			if (obj.Size() > 0) {
				var seenDot = false, seenHash = false, seenOther = false;
				for (k in obj.Keys()) {
					if (k.length > 0) {
						final k0 = StringTools.fastCodeAt(k, 0);
						seenDot = seenDot || k0 == ".".code;
						seenHash = seenHash || k0 == "#".code;
						seenOther = seenOther || (k0 != ".".code && k0 != "#".code);
						if (seenOther && (seenDot || seenHash)) {
							this.objectKind = objectKindInvalid;
							return;
						}
					}
				}
				if (seenDot) {
					this.objectKind = objectKindSubpaths;
					return;
				}
				if (seenHash) {
					this.objectKind = objectKindImports;
					return;
				}
			}
			this.objectKind = objectKindConditions;
		}
	}
}
