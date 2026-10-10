package ts.packagejson;

// Port of jsonvalue.go (types and methods; unmarshalJSONValue* are in Packagejson.hx).

enum abstract JSONValueType(Int) from Int to Int {
	var JSONValueTypeNotPresent = 0;
	var JSONValueTypeNull = 1;
	var JSONValueTypeString = 2;
	var JSONValueTypeNumber = 3;
	var JSONValueTypeBoolean = 4;
	var JSONValueTypeArray = 5;
	var JSONValueTypeObject = 6;

	public function String():String {
		switch ((cast this : JSONValueType)) {
			case JSONValueTypeNull:
				return "null";
			case JSONValueTypeString:
				return "string";
			case JSONValueTypeNumber:
				return "number";
			case JSONValueTypeBoolean:
				return "boolean";
			case JSONValueTypeArray:
				return "array";
			case JSONValueTypeObject:
				return "object";
			default:
				return "unknown(" + (this : Int) + ")";
		}
	}
}

// PORT: Go `any` Value holds: String (string), Float (number), Bool (boolean),
// Array<JSONValue> (array), OrderedMap<String, JSONValue> (object), null (null / not present).
// Go copies the struct by value; it is never mutated after unmarshaling, so copies share it.
class JSONValue implements UnmarshalerFrom {
	public var Type:JSONValueType = JSONValueTypeNotPresent;
	public var Value:Any = null;

	public function new() {}

	public function IsPresent():Bool {
		return this.Type != JSONValueTypeNotPresent;
	}

	public function IsFalsy():Bool {
		switch (this.Type) {
			case JSONValueTypeNotPresent, JSONValueTypeNull:
				return true;
			case JSONValueTypeString:
				return (this.Value : String) == "";
			case JSONValueTypeNumber:
				// PORT: Go `v.Value == 0` compares any(float64) with any(int(0)); never equal.
				return false;
			case JSONValueTypeBoolean:
				return !(this.Value : Bool);
			default:
				return false;
		}
	}

	public function AsObject():OrderedMap<String, JSONValue> {
		if (this.Type != JSONValueTypeObject) {
			throw "expected object, got " + this.Type.String();
		}
		return cast this.Value;
	}

	public function AsArray():Array<JSONValue> {
		if (this.Type != JSONValueTypeArray) {
			throw "expected array, got " + this.Type.String();
		}
		return cast this.Value;
	}

	public function AsString():String {
		if (this.Type != JSONValueTypeString) {
			throw "expected string, got " + this.Type.String();
		}
		return cast this.Value;
	}

	public function UnmarshalJSONFrom(dec:Value):Null<Error> {
		return Packagejson.unmarshalJSONValueV2(this, dec, () -> new JSONValue());
	}
}

// PORT: json.UnmarshalerFrom; the decoder is the decoded Jsontext.Value of this JSON value.
interface UnmarshalerFrom {
	function UnmarshalJSONFrom(dec:Value):Null<Error>;
}
