package ts.tsoptions;

// Port of commandlineparser.go (type commandLineParser and its methods; package-level funcs are
// in Tsoptions.hx).
@:allow(ts.tsoptions)
class CommandLineParser {
	public function AlternateMode():Null<AlternateModeDiagnostics> {
		return this.workerDiagnostics.didYouMean.alternateMode;
	}

	public function OptionsDeclarations():Null<Array<CommandLineOption>> {
		return this.workerDiagnostics.didYouMean.OptionDeclarations;
	}

	public function UnknownOptionDiagnostic():Null<Message> {
		return this.workerDiagnostics.didYouMean.UnknownOptionDiagnostic;
	}

	public function UnknownDidYouMeanDiagnostic():Null<Message> {
		return this.workerDiagnostics.didYouMean.UnknownDidYouMeanDiagnostic;
	}

	var workerDiagnostics:ParseCommandLineWorkerDiagnostics = null;
	var optionsMap:NameMap = null;
	var fs:Null<FS> = null;
	var currentDirectory:String = "";
	var options:OrderedMap<String, Dynamic> = null;
	var fileNames:Null<Array<String>> = null;
	var errors:Null<Array<Diagnostic>> = null;

	public function new() {}

	function parseStrings(args:Array<String>):Void {
		var i = 0;
		while (i < args.length) {
			final s = args[i];
			i++;
			if (s == "") {
				continue;
			}
			switch (StringTools.fastCodeAt(s, 0)) {
				case '@'.code:
					this.parseResponseFile(s.substring(1));
				case '-'.code:
					final inputOptionName = Tsoptions.getInputOptionName(s);
					final opt = this.optionsMap.GetOptionDeclarationFromName(inputOptionName, true /*allowShort*/);
					if (opt != null) {
						i = this.parseOptionValue(args, i, opt, this.workerDiagnostics.OptionTypeMismatchDiagnostic);
					} else {
						final watchOpt = Tsoptions.WatchNameMap.GetOptionDeclarationFromName(inputOptionName, true /*allowShort*/);
						if (watchOpt != null) {
							i = this.parseOptionValue(args, i, watchOpt, Tsoptions.watchOptionsDidYouMeanDiagnostics.OptionTypeMismatchDiagnostic);
						} else {
							this.errors.push(this.createUnknownOptionError(inputOptionName, s, null, null));
						}
					}
				default:
					this.fileNames.push(s);
			}
		}
	}

	function parseResponseFile(fileName:String):Void {
		fileName = Tspath.GetNormalizedAbsolutePath(fileName, this.currentDirectory);
		final r = Tsoptions.tryReadFile(fileName, function(fileName:String):ValueOk<String> {
			if (this.fs == null) {
				return new ValueOk<String>("", false);
			}
			final read = this.fs.ReadFile(fileName);
			return read;
		}, this.errors);
		final fileContents = r.a;
		this.errors = r.b;

		if (fileContents == "") {
			return;
		}

		var args:Array<String> = [];
		// PORT: Go converts the text to []rune; UTF-16 code units give the same splits here
		// (only ' ' and '"' are compared, both below the surrogate range).
		final text = fileContents;
		final textLength = text.length;
		var pos = 0;
		while (pos < textLength) {
			while (pos < textLength && StringTools.fastCodeAt(text, pos) <= ' '.code) {
				pos++;
			}
			if (pos >= textLength) {
				break;
			}
			final start = pos;
			if (StringTools.fastCodeAt(text, pos) == '"'.code) {
				pos++;
				while (pos < textLength && StringTools.fastCodeAt(text, pos) != '"'.code) {
					pos++;
				}
				if (pos < textLength) {
					args.push(text.substring(start + 1, pos));
					pos++;
				} else {
					this.errors.push(Ast.NewCompilerDiagnostic(Diagnostics.Unterminated_quoted_string_in_response_file_0, fileName));
				}
			} else {
				while (true) {
					// PORT: Go indexes text[pos] without a bounds check and panics at the end of the text.
					if (pos >= textLength) {
						throw "runtime error: index out of range [" + pos + "] with length " + textLength;
					}
					if (!(StringTools.fastCodeAt(text, pos) > ' '.code)) {
						break;
					}
					pos++;
				}
				args.push(text.substring(start, pos));
			}
		}
		this.parseStrings(args);
	}

	function parseOptionValue(args:Array<String>, i:Int, opt:CommandLineOption, diag:Message):Int {
		if (opt.IsTSConfigOnly && i <= args.length) {
			var optValue = "";
			if (i < args.length) {
				optValue = args[i];
			}
			if (optValue == "null") {
				this.options.Set(opt.Name, null);
				i++;
			} else if (opt.Kind == CommandLineOptionTypeBoolean) {
				if (optValue == "false") {
					this.options.Set(opt.Name, false);
					i++;
				} else {
					if (optValue == "true") {
						i++;
					}
					this.errors.push(Ast.NewCompilerDiagnostic(Diagnostics.Option_0_can_only_be_specified_in_tsconfig_json_file_or_set_to_false_or_null_on_command_line,
						opt.Name));
				}
			} else {
				this.errors.push(Ast.NewCompilerDiagnostic(Diagnostics.Option_0_can_only_be_specified_in_tsconfig_json_file_or_set_to_null_on_command_line, opt.Name));
				if (optValue.length != 0 && !StringTools.startsWith(optValue, "-")) {
					i++;
				}
			}
		} else {
			// Check to see if no argument was provided (e.g. "--locale" is the last command-line argument).
			if (i >= args.length) {
				if (opt.Kind != CommandLineOptionTypeBoolean) {
					this.errors.push(Ast.NewCompilerDiagnostic(diag, opt.Name, Tsoptions.getCompilerOptionValueTypeString(opt)));
					if (opt.Kind == CommandLineOptionTypeList) {
						// PORT: Go `[]string{}` (not `[]any`): see Tsoptions.emptyStringSlice.
						this.options.Set(opt.Name, Tsoptions.emptyStringSlice);
					} else if (opt.Kind == CommandLineOptionTypeEnum) {
						this.errors.push(Tsoptions.createDiagnosticForInvalidEnumType(opt, null, null));
					}
				} else {
					this.options.Set(opt.Name, true);
				}
				return i;
			}
			if (args[i] != "null") {
				switch (opt.Kind) {
					case CommandLineOptionTypeNumber:
						// !!! Make sure this parseInt matches JS parseInt
						final r = Strconv.Atoi(args[i]);
						final num = r.value;
						final e = r.err;
						if (e == null) {
							if (num >= opt.minValue) {
								this.options.Set(opt.Name, num);
							} else {
								this.errors.push(Ast.NewCompilerDiagnostic(Diagnostics.Option_0_requires_value_to_be_greater_than_1, opt.Name,
									Std.string(opt.minValue)));
							}
						} else {
							this.errors.push(Ast.NewCompilerDiagnostic(diag, opt.Name, "number"));
						}
						i++;
					case CommandLineOptionTypeBoolean:
						// boolean flag has optional value true, false, others
						final optValue = args[i];

						// check next argument as boolean flag value
						if (optValue == "false") {
							this.options.Set(opt.Name, false);
						} else {
							this.options.Set(opt.Name, true);
						}
						// try to consume next argument as value for boolean flag; do not consume argument if it is not "true" or "false"
						if (optValue == "false" || optValue == "true") {
							i++;
						}
					case CommandLineOptionTypeString:
						final r = Tsoptions.validateJsonOptionValue(opt, args[i], null, null);
						final val = r.a;
						final err = r.b;
						if (err == null) {
							this.options.Set(opt.Name, val);
						} else {
							for (d in err)
								this.errors.push(d);
						}
						i++;
					case CommandLineOptionTypeList:
						final r = this.parseListTypeOption(opt, args[i]);
						final result = r.a;
						final err = r.b;
						this.options.Set(opt.Name, Tsoptions.anySliceToAny(result));
						if (err != null)
							for (d in err)
								this.errors.push(d);
						if (Core.len(result) > 0 || Core.len(err) > 0) {
							i++;
						}
					case CommandLineOptionTypeListOrElement:
						// If not a primitive, the possible types are specified in what is effectively a map of options.
						throw "listOrElement not supported here";
					default:
						final r = Tsoptions.convertJsonOptionOfEnumType(opt, Strings.TrimFunc(args[i], Stringutil.IsWhiteSpaceLike), null, null);
						this.options.Set(opt.Name, r.a);
						if (r.b != null)
							for (d in r.b)
								this.errors.push(d);
						i++;
				}
			} else {
				this.options.Set(opt.Name, null);
				i++;
			}
		}
		return i;
	}

	function parseListTypeOption(opt:CommandLineOption, value:String):Pair<Array<Dynamic>, Null<Array<Diagnostic>>> {
		return Tsoptions.ParseListTypeOption(opt, value);
	}
}
