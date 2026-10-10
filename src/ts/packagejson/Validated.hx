package ts.packagejson;

// Port of validated.go.
interface TypeValidatedField {
	function IsPresent():Bool;
	function IsValid():Bool;
	function ExpectedJSONType():String;
	function ActualJSONType():String;
}
