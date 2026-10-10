package ts.module;

// Port of internal/module: package-level funcs, vars and consts of all files.
@:allow(ts.module)
class Module {
	// --- cache.go ---

	static function newCaches(currentDirectory:String, useCaseSensitiveFileNames:Bool, options:CompilerOptions):Caches {
		return new Caches(Packagejson.NewInfoCache(currentDirectory, useCaseSensitiveFileNames));
	}

	static function getRedirectConfigName(redirect:Null<ResolvedProjectReference>):String {
		if (redirect == null) {
			return "";
		}
		return redirect.ConfigName();
	}

	// --- resolver.go ---

	static inline function continueSearching():Null<Resolved> {
		return null;
	}

	static inline function unresolved():Resolved {
		return new Resolved();
	}

	static function newResolutionState(name:String, containingDirectory:String, isTypeReferenceDirective:Bool, resolutionMode:ResolutionMode,
			compilerOptions:CompilerOptions, redirectedReference:Null<ResolvedProjectReference>, resolver:Resolver,
			traceBuilder:Null<Tracer>):ResolutionState {
		final state = new ResolutionState();
		state.name = name;
		state.containingDirectory = containingDirectory;
		state.compilerOptions = GetCompilerOptionsWithRedirect(compilerOptions, redirectedReference);
		state.resolver = resolver;
		state.tracer = traceBuilder;

		if (isTypeReferenceDirective) {
			state.extensions = extensionsDeclaration;
		} else if (compilerOptions.NoDtsResolution == TSTrue) {
			state.extensions = extensionsImplementationFiles;
		} else {
			state.extensions = extensionsTypeScript | extensionsJavaScript | extensionsDeclaration;
		}

		if (!isTypeReferenceDirective && compilerOptions.GetResolveJsonModule()) {
			state.extensions |= extensionsJson;
		}

		switch (compilerOptions.GetModuleResolutionKind()) {
			case ModuleResolutionKindNode16:
				state.features = NodeResolutionFeaturesNode16Default;
				state.esmMode = resolutionMode == ModuleKindESNext;
				state.conditions = GetConditions(compilerOptions, resolutionMode);
			case ModuleResolutionKindNodeNext:
				state.features = NodeResolutionFeaturesNodeNextDefault;
				state.esmMode = resolutionMode == ModuleKindESNext;
				state.conditions = GetConditions(compilerOptions, resolutionMode);
			case ModuleResolutionKindBundler:
				state.features = getNodeResolutionFeatures(compilerOptions);
				state.conditions = GetConditions(compilerOptions, resolutionMode);
			default:
		}
		return state;
	}

	public static function GetCompilerOptionsWithRedirect(compilerOptions:CompilerOptions,
			redirectedReference:Null<ResolvedProjectReference>):CompilerOptions {
		if (redirectedReference == null) {
			return compilerOptions;
		}
		final optionsFromRedirect = redirectedReference.CompilerOptions();
		if (optionsFromRedirect != null) {
			return optionsFromRedirect;
		}
		return compilerOptions;
	}

	public static function NewResolver(host:ResolutionHost, options:CompilerOptions, typingsLocation:String, projectName:String):Resolver {
		final r = new Resolver();
		r.host = host;
		r.caches = newCaches(host.GetCurrentDirectory(), host.FS().UseCaseSensitiveFileNames(), options);
		r.compilerOptions = options;
		r.typingsLocation = typingsLocation;
		r.projectName = projectName;
		return r;
	}

	public static function NewResolverWithOptions(host:ResolutionHost, compilerOptions:CompilerOptions, typingsLocation:String, projectName:String,
			opts:ResolverOptions):Resolver {
		final r = new Resolver();
		r.host = host;
		r.compilerOptions = compilerOptions;
		r.typingsLocation = typingsLocation;
		r.projectName = projectName;
		if (opts.PackageJsonCache != null) {
			r.caches.packageJsonInfoCache = opts.PackageJsonCache;
		} else {
			r.caches = newCaches(host.GetCurrentDirectory(), host.FS().UseCaseSensitiveFileNames(), compilerOptions);
		}
		return r;
	}

	public static function GetConditions(options:CompilerOptions, resolutionMode:ResolutionMode):Array<String> {
		final moduleResolution = options.GetModuleResolutionKind();
		if (resolutionMode == ModuleKindNone && moduleResolution == ModuleResolutionKindBundler) {
			resolutionMode = ModuleKindESNext;
		}
		var conditions:Array<String> = [];
		if (resolutionMode == ModuleKindESNext) {
			conditions.push("import");
		} else {
			conditions.push("require");
		}

		if (options.NoDtsResolution != TSTrue) {
			conditions.push("types");
		}
		if (moduleResolution != ModuleResolutionKindBundler) {
			conditions.push("node");
		}
		conditions = Core.Concatenate(conditions, options.CustomConditions);
		return conditions;
	}

	static function getNodeResolutionFeatures(options:CompilerOptions):NodeResolutionFeatures {
		var features = NodeResolutionFeaturesNone;

		switch (options.GetModuleResolutionKind()) {
			case ModuleResolutionKindNode16:
				features = NodeResolutionFeaturesNode16Default;
			case ModuleResolutionKindNodeNext:
				features = NodeResolutionFeaturesNodeNextDefault;
			case ModuleResolutionKindBundler:
				features = NodeResolutionFeaturesBundlerDefault;
			default:
		}
		if (options.ResolvePackageJsonExports == TSTrue) {
			features |= NodeResolutionFeaturesExports;
		} else if (options.ResolvePackageJsonExports == TSFalse) {
			features = features & ~NodeResolutionFeaturesExports;
		}
		if (options.ResolvePackageJsonImports == TSTrue) {
			features |= NodeResolutionFeaturesImports;
		} else if (options.ResolvePackageJsonImports == TSFalse) {
			features = features & ~NodeResolutionFeaturesImports;
		}
		return features;
	}

	static function moveToNextDirectorySeparatorIfAvailable(path:String, prevSeparatorIndex:Int, isFolder:Bool):Int {
		final offset = prevSeparatorIndex + 1;
		var nextSeparatorIndex = -1;
		if (offset <= path.length) {
			nextSeparatorIndex = path.substring(offset).indexOf("/");
		}
		if (nextSeparatorIndex == -1) {
			if (isFolder) {
				return path.length;
			}
			return prevSeparatorIndex;
		}
		return nextSeparatorIndex + offset;
	}

	public static function TryParsePatterns(pathMappings:Null<OrderedMap<String, Array<String>>>):ParsedPatterns {
		var numPatterns = 0;
		for (path in pathMappings.Keys()) {
			final pattern = Core.TryParsePattern(path);
			if (pattern.IsValid() && pattern.StarIndex == -1) {
				numPatterns++;
			}
		}
		final numMatchables = pathMappings.Size() - numPatterns;

		var patterns:Null<Array<Pattern>> = null;
		var matchableStringSet = new Set<String>();
		if (numPatterns != 0) {
			patterns = [];
		}
		if (numMatchables != 0) {
			matchableStringSet = Collections.NewSetWithSizeHint(numMatchables);
		}

		for (path in pathMappings.Keys()) {
			final pattern = Core.TryParsePattern(path);
			if (pattern.IsValid()) {
				if (pattern.StarIndex == -1) {
					matchableStringSet.Add(path);
				} else {
					// PORT: Go appends to a nil slice when numPatterns counted only exact keys.
					if (patterns == null)
						patterns = [];
					patterns.push(pattern);
				}
			}
		}
		return new ParsedPatterns(matchableStringSet, patterns);
	}

	public static function MatchPatternOrExact(patterns:ParsedPatterns, candidate:String):Pattern {
		if (patterns.matchableStringSet.Has(candidate)) {
			return new Pattern(candidate, -1);
		}
		if (patterns.patterns == null || patterns.patterns.length == 0) {
			return new Pattern();
		}
		return Core.FindBestPatternMatch(patterns.patterns, Core.Identity, candidate, new Pattern());
	}

	// If you import from "." inside a containing directory "/foo", the result of `tspath.NormalizePath`
	// would be "/foo", but this loses the information that `foo` is a directory and we intended
	// to look inside of it. The Node CommonJS resolution algorithm doesn't call this out
	// (https://nodejs.org/api/modules.html#all-together), but it seems that module paths ending
	// in `.` are actually normalized to `./` before proceeding with the resolution algorithm.
	static function normalizePathForCJSResolution(containingDirectory:String, moduleName:String):String {
		final combined = Tspath.CombinePaths(containingDirectory, moduleName);
		final parts = Tspath.GetPathComponents(combined, "");
		final lastPart = parts[parts.length - 1];
		if (lastPart == "." || lastPart == "..") {
			return Tspath.EnsureTrailingDirectorySeparator(Tspath.NormalizePath(combined));
		}
		return Tspath.NormalizePath(combined);
	}

	static function matchesPatternWithTrailer(target:String, name:String):Bool {
		if (StringTools.endsWith(target, "*")) {
			return false;
		}
		final i = target.indexOf("*");
		if (i < 0) {
			return false;
		}
		final before = target.substring(0, i);
		final after = target.substring(i + 1);
		return StringTools.startsWith(name, before) && StringTools.endsWith(name, after);
	}

	/** True if `extension` is one of the supported `extensions`. */
	static function extensionIsOk(extensions:Extensions, extension:String):Bool {
		return ((extensions & extensionsJavaScript) != 0
			&& (extension == Tspath.ExtensionJs || extension == Tspath.ExtensionJsx || extension == Tspath.ExtensionMjs
				|| extension == Tspath.ExtensionCjs))
			|| ((extensions & extensionsTypeScript) != 0
				&& (extension == Tspath.ExtensionTs || extension == Tspath.ExtensionTsx || extension == Tspath.ExtensionMts
					|| extension == Tspath.ExtensionCts))
			|| ((extensions & extensionsDeclaration) != 0
				&& (extension == Tspath.ExtensionDts || extension == Tspath.ExtensionDmts || extension == Tspath.ExtensionDcts))
			|| ((extensions & extensionsJson) != 0 && extension == Tspath.ExtensionJson);
	}

	public static function ResolveConfig(moduleName:String, containingFile:String, host:ResolutionHost):ResolvedModule {
		final options = new CompilerOptions();
		options.ModuleResolution = ModuleResolutionKindNodeNext;
		final resolver = NewResolver(host, options, "", "");
		return resolver.resolveConfig(moduleName, containingFile);
	}

	public static function GetAutomaticTypeDirectiveNames(options:CompilerOptions, host:ResolutionHost):Array<String> {
		if (!options.UsesWildcardTypes()) {
			if (options.Types != null) {
				return options.Types;
			}
			return [];
		}

		// Walk the primary type lookup locations
		var wildcardMatches:Null<Array<String>> = null;
		final typeRoots = options.GetEffectiveTypeRoots(host.GetCurrentDirectory()).value;
		if (typeRoots != null) {
			for (root in typeRoots) {
				if (host.FS().DirectoryExists(root)) {
					final directories = host.FS().GetAccessibleEntries(root).Directories;
					if (directories != null) {
						for (typeDirectivePath in directories) {
							final normalized = Tspath.NormalizePath(typeDirectivePath);
							final packageJsonPath = Tspath.CombinePaths(root, normalized, "package.json");
							var isNotNeededPackage = false;
							if (host.FS().FileExists(packageJsonPath)) {
								final contents = host.FS().ReadFile(packageJsonPath).value;
								final packageJsonContent = Packagejson.Parse(contents).value;
								// `types-publisher` sometimes creates packages with `"typings": null` for packages that don't provide their own types.
								// See `createNotNeededPackageJSON` in the types-publisher` repo.
								isNotNeededPackage = packageJsonContent.Typings.Null;
							}
							if (!isNotNeededPackage) {
								final baseFileName = Tspath.GetBaseFileName(normalized);
								if (!StringTools.startsWith(baseFileName, ".")) {
									if (wildcardMatches == null)
										wildcardMatches = [];
									wildcardMatches.push(baseFileName);
								}
							}
						}
					}
				}
			}
		}

		// Order potentially matters in program construction, so substitute
		// in the wildcard in the position it was specified in the types array
		var result:Null<Array<String>> = null;
		for (t in options.Types) {
			if (t == "*") {
				if (wildcardMatches != null) {
					if (result == null)
						result = [];
					for (m in wildcardMatches)
						result.push(m);
				}
			} else {
				if (result == null)
					result = [];
				result.push(t);
			}
		}
		return Core.Deduplicate(result);
	}

	// --- util.go ---

	// PORT: lazy getter (static init order, PORTING.md §7a).
	static var typeScriptVersion(get, never):Version;
	static var typeScriptVersion_:Null<Version> = null;

	static function get_typeScriptVersion():Version {
		if (typeScriptVersion_ == null)
			typeScriptVersion_ = Semver.MustParse(Core.Version());
		return typeScriptVersion_;
	}

	public static inline final InferredTypesContainingFile = "__inferred type names__.ts";

	public static function IsApplicableVersionedTypesKey(key:String):Bool {
		if (!StringTools.startsWith(key, "types@")) {
			return false;
		}
		final r = Semver.TryParseVersionRange(key.substring("types@".length));
		final range_ = r.value;
		if (!r.ok) {
			return false;
		}
		return range_.Test(typeScriptVersion);
	}

	public static function ParseNodeModuleFromPath(resolved:String, isFolder:Bool):String {
		final path = Tspath.NormalizePath(resolved);
		final idx = path.lastIndexOf("/node_modules/");
		if (idx == -1) {
			return "";
		}

		final indexAfterNodeModules = idx + "/node_modules/".length;
		var indexAfterPackageName = moveToNextDirectorySeparatorIfAvailable(path, indexAfterNodeModules, isFolder);
		if (StringTools.fastCodeAt(path, indexAfterNodeModules) == "@".code) {
			indexAfterPackageName = moveToNextDirectorySeparatorIfAvailable(path, indexAfterPackageName, isFolder);
		}
		return path.substring(0, indexAfterPackageName);
	}

	// PORT: (packageName, rest string) → Pair(a = packageName, b = rest).
	public static function ParsePackageName(moduleName:String):Pair<String, String> {
		var idx = moduleName.indexOf("/");
		if (moduleName.length > 0 && StringTools.fastCodeAt(moduleName, 0) == "@".code) {
			final offset = idx + 1;
			idx = moduleName.substring(offset).indexOf("/");
			if (idx != -1) {
				idx += offset;
			}
		}
		if (idx == -1) {
			return new Pair(moduleName, "");
		}
		return new Pair(moduleName.substring(0, idx), moduleName.substring(idx + 1));
	}

	public static function MangleScopedPackageName(packageName:String):String {
		if (packageName.length > 0 && StringTools.fastCodeAt(packageName, 0) == "@".code) {
			final idx = packageName.indexOf("/");
			if (idx == -1) {
				return packageName;
			}
			return packageName.substring(1, idx) + "__" + packageName.substring(idx + 1);
		}
		return packageName;
	}

	public static function UnmangleScopedPackageName(packageName:String):String {
		final i = packageName.indexOf("__");
		if (i >= 0) {
			return "@" + packageName.substring(0, i) + "/" + packageName.substring(i + 2);
		}
		return packageName;
	}

	public static function GetTypesPackageName(packageName:String):String {
		return "@types/" + MangleScopedPackageName(packageName);
	}

	public static function GetPackageNameFromTypesPackageName(mangledName:String):String {
		final withoutAtTypePrefix = Strings.TrimPrefix(mangledName, "@types/");
		if (withoutAtTypePrefix != mangledName) {
			return UnmangleScopedPackageName(withoutAtTypePrefix);
		}
		return mangledName;
	}

	public static function ComparePatternKeys(a:String, b:String):Int {
		final aPatternIndex = a.indexOf("*");
		final bPatternIndex = b.indexOf("*");
		var baseLenA = a.length;
		if (aPatternIndex != -1) {
			baseLenA = aPatternIndex + 1;
		}
		var baseLenB = b.length;
		if (bPatternIndex != -1) {
			baseLenB = bPatternIndex + 1;
		}

		if (baseLenA > baseLenB) {
			return -1;
		}
		if (baseLenB > baseLenA) {
			return 1;
		}
		if (aPatternIndex == -1) {
			return 1;
		}
		if (bPatternIndex == -1) {
			return -1;
		}
		if (a.length > b.length) {
			return -1;
		}
		if (b.length > a.length) {
			return 1;
		}
		return 0;
	}

	// Returns a DiagnosticMessage if we won't include a resolved module due to its extension.
	// The DiagnosticMessage's parameters are the imported module name, and the filename it resolved to.
	// This returns a diagnostic even if the module will be an untyped module.
	public static function GetResolutionDiagnostic(options:CompilerOptions, resolvedModule:ResolvedModule, file:SourceFile):Null<Message> {
		final needJsx = function():Null<Message> {
			if (options.Jsx != JsxEmitNone) {
				return null;
			}
			return Diagnostics.Module_0_was_resolved_to_1_but_jsx_is_not_set;
		};

		final needAllowJs = function():Null<Message> {
			if (options.GetAllowJS() || !options.NoImplicitAny.DefaultIfUnknown(options.Strict).IsTrue()) {
				return null;
			}
			return Diagnostics.Could_not_find_a_declaration_file_for_module_0_1_implicitly_has_an_any_type;
		};

		final needResolveJsonModule = function():Null<Message> {
			if (options.GetResolveJsonModule()) {
				return null;
			}
			return Diagnostics.Module_0_was_resolved_to_1_but_resolveJsonModule_is_not_used;
		};

		final needAllowArbitraryExtensions = function():Null<Message> {
			if (file.IsDeclarationFile || options.AllowArbitraryExtensions.IsTrue()) {
				return null;
			}
			return Diagnostics.Module_0_was_resolved_to_1_but_allowArbitraryExtensions_is_not_set;
		};

		switch (resolvedModule.Extension) {
			case Tspath.ExtensionTs | Tspath.ExtensionDts | Tspath.ExtensionMts | Tspath.ExtensionDmts | Tspath.ExtensionCts | Tspath.ExtensionDcts:
				// These are always allowed.
				return null;
			case Tspath.ExtensionTsx:
				return needJsx();
			case Tspath.ExtensionJsx:
				final message = needJsx();
				if (message != null) {
					return message;
				}
				return needAllowJs();
			case Tspath.ExtensionJs | Tspath.ExtensionMjs | Tspath.ExtensionCjs:
				return needAllowJs();
			case Tspath.ExtensionJson:
				return needResolveJsonModule();
			default:
				return needAllowArbitraryExtensions();
		}
	}

	// TryGetJSExtensionForFile maps TS/JS/DTS extensions to the output JS-side extension.
	// Returns an empty string if the extension is unsupported.
	public static function TryGetJSExtensionForFile(fileName:String, options:CompilerOptions):String {
		final ext = Tspath.TryGetExtensionFromPath(fileName);
		switch (ext) {
			case Tspath.ExtensionTs | Tspath.ExtensionDts:
				return Tspath.ExtensionJs;
			case Tspath.ExtensionTsx:
				if (options.Jsx == JsxEmitPreserve) {
					return Tspath.ExtensionJsx;
				}
				return Tspath.ExtensionJs;
			case Tspath.ExtensionJs | Tspath.ExtensionJsx | Tspath.ExtensionJson:
				return ext;
			case Tspath.ExtensionDmts | Tspath.ExtensionMts | Tspath.ExtensionMjs:
				return Tspath.ExtensionMjs;
			case Tspath.ExtensionDcts | Tspath.ExtensionCts | Tspath.ExtensionCjs:
				return Tspath.ExtensionCjs;
			default:
				return "";
		}
	}
}
