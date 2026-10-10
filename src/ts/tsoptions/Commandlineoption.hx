package ts.tsoptions;

// Port of commandlineoption.go (types and methods; package-level vars are in Tsoptions.hx).

enum abstract CommandLineOptionKind(String) to String {
	var CommandLineOptionTypeString = "string";
	var CommandLineOptionTypeNumber = "number";
	var CommandLineOptionTypeBoolean = "boolean";
	var CommandLineOptionTypeObject = "object";
	var CommandLineOptionTypeList = "list";
	var CommandLineOptionTypeListOrElement = "listOrElement";
	var CommandLineOptionTypeEnum = "enum"; // map
}

@:allow(ts.tsoptions)
class CommandLineOption {
	public var Name:String = "";
	public var ShortName:String = "";
	public var Kind:CommandLineOptionKind = cast "";

	// used in parsing
	public var IsFilePath:Bool = false;
	public var IsTSConfigOnly:Bool = false;
	public var IsCommandLineOnly:Bool = false;

	// used in output
	public var Description:Null<Message> = null;
	public var DefaultValueDescription:Dynamic = null;
	public var ShowInSimplifiedHelpView:Bool = false;

	// used in output in serializing and generate tsconfig
	public var Category:Null<Message> = null;

	// What kind of extra validation `validateJsonOptionValue` should do
	var extraValidation:ExtraValidation = extraValidationNone;

	// checks that option with number type has value >= minValue
	var minValue:Int = 0;

	// true or undefined
	// used for configDirTemplateSubstitutionOptions
	var allowConfigDirTemplateSubstitution:Bool = false;

	// used for filter in compilerrunner
	public var AffectsDeclarationPath:Bool = false;
	public var AffectsProgramStructure:Bool = false;
	public var AffectsSemanticDiagnostics:Bool = false;
	public var AffectsBuildInfo:Bool = false;
	public var AffectsBindDiagnostics:Bool = false;
	public var AffectsSourceFile:Bool = false;
	public var AffectsModuleResolution:Bool = false;
	public var AffectsEmit:Bool = false;

	var allowJsFlag:Bool = false;
	var strictFlag:Bool = false;

	// used in transpileoptions worker
	// todo: revisit to see if this can be reduced to boolean
	var transpileOptionValue:Tristate = TSUnknown;

	// used for CommandLineOptionTypeList
	var listPreserveFalsyValues:Bool = false;
	// used for compilerOptionsDeclaration
	public var ElementOptions:CommandLineOptionNameMap = null;

	public function new() {}

	public function DeprecatedKeys():Null<Set<String>> {
		if (this.Kind != CommandLineOptionTypeEnum) {
			return null;
		}
		return Tsoptions.commandLineOptionDeprecated.get(this.Name);
	}

	public function EnumMap():Null<OrderedMap<String, Dynamic>> {
		if (this.Kind != CommandLineOptionTypeEnum) {
			return null;
		}
		return Tsoptions.commandLineOptionEnumMap.get(this.Name);
	}

	public function Elements():Null<CommandLineOption> {
		if (this.Kind != CommandLineOptionTypeList && this.Kind != CommandLineOptionTypeListOrElement) {
			return null;
		}
		return Tsoptions.commandLineOptionElements.get(this.Name);
	}

	public function DisallowNullOrUndefined():Bool {
		return this.Name == "extends";
	}
}

enum abstract ExtraValidation(String) to String {
	var extraValidationNone = "";
	var extraValidationSpec = "spec";
	var extraValidationLocale = "locale";
}

// todo: revisit to see if this can be improved
typedef CompilerOptionsValue = Dynamic;
