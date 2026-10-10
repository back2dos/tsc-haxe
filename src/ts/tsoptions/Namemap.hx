package ts.tsoptions;

// Port of namemap.go (type NameMap; package-level vars and funcs are in Tsoptions.hx).
@:allow(ts.tsoptions)
class NameMap {
	var optionsNames:OrderedMap<String, CommandLineOption> = null;
	var shortOptionNames:StringMap<String> = null;

	public function new(optionsNames:OrderedMap<String, CommandLineOption>, shortOptionNames:StringMap<String>) {
		this.optionsNames = optionsNames;
		this.shortOptionNames = shortOptionNames;
	}

	public function Get(name:String):Null<CommandLineOption> {
		return this.optionsNames.GetOrZero(Strings.ToLower(name));
	}

	public function GetFromShort(shortName:String):Null<CommandLineOption> {
		// returns option only if shortName is a valid short option
		if (!this.shortOptionNames.exists(shortName)) {
			return null;
		}
		final name = this.shortOptionNames.get(shortName);
		return this.Get(name);
	}

	public function GetOptionDeclarationFromName(optionName:String, allowShort:Bool):Null<CommandLineOption> {
		optionName = Strings.ToLower(optionName);
		// Try to translate short option names to their full equivalents.
		if (allowShort) {
			final short = this.shortOptionNames.get(optionName);
			if (short != null && short != "") {
				optionName = short;
			}
		}
		return this.Get(optionName);
	}
}
