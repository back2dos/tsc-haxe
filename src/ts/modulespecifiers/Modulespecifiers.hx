package ts.modulespecifiers;

import ts.ast.Ast.HasFileName;
import ts.ast.Ast.SourceFile;
import ts.ast.Ast.Node;
import ts.ast.Ast.StringLiteralLike;
import ts.ast.Symbol;
import ts.packagejson.Cache.VersionPaths;
import ts.packagejson.Exportsorimports.ExportsOrImports;
import ts.module.Resolver.ResolvedEntrypoint;

// Port of internal/modulespecifiers: package-level funcs and vars of all files (Go file order).
@:allow(ts.modulespecifiers)
class Modulespecifiers {
	// --- compare.go ---

	public static function CountPathComponents(path:String):Int {
		var initial = 0;
		if (StringTools.startsWith(path, "./")) {
			initial = 2;
		}
		return Strings.Count(path.substring(initial), "/");
	}

	// --- preferences.go ---

	// Program errors validate that `noEmit` or `emitDeclarationOnly` is also set,
	// so this function doesn't check them to avoid propagating errors.
	static function shouldAllowImportingTsExtension(compilerOptions:CompilerOptions, fromFileName:RootedFilePath):Bool {
		return compilerOptions.GetAllowImportingTsExtensions() || fromFileName.IsDeclarationFile();
	}

	static function usesExtensionsOnImports(file:SourceFileForSpecifierGeneration):Bool {
		final imports = file.Imports();
		if (imports != null) {
			for (ref in imports) {
				final text = ref.Text();
				if (Tspath.PathIsRelative(text) && !Tspath.FileExtensionIsOneOf(text, Tspath.ExtensionsNotSupportingExtensionlessResolution)) {
					return Tspath.HasTSFileExtension(text) || Tspath.HasJSFileExtension(text);
				}
			}
		}
		return false;
	}

	static function inferPreference(resolutionMode:ResolutionMode, sourceFile:SourceFileForSpecifierGeneration,
			moduleResolutionIsNodeNext:Bool):ModuleSpecifierEnding {
		var usesJsExtensions = false;
		var specifiers:Slice<Node> = null;
		if (sourceFile != null && Core.len(sourceFile.Imports()) > 0) {
			specifiers = sourceFile.Imports();
		} else if (sourceFile != null && sourceFile.IsJS()) {
			// !!! TODO: JS support
			// specifiers = core.Map(getRequiresAtTopOfFile(sourceFile), func(d *ast.Node) *ast.Node { return d.arguments[0] })
		}

		if (specifiers != null) {
			for (specifier in specifiers) {
				final path = specifier.Text();
				if (Tspath.PathIsRelative(path)) {
					// !!! TODO: proper resolutionMode support
					if (moduleResolutionIsNodeNext
						&& resolutionMode == Core.ResolutionModeCommonJS /* && getModeForUsageLocation(sourceFile!, specifier, compilerOptions) === ModuleKind.ESNext */) {
						// We're trying to decide a preference for a CommonJS module specifier, but looking at an ESM import.
						continue;
					}
					if (Tspath.FileExtensionIsOneOf(path, Tspath.ExtensionsNotSupportingExtensionlessResolution)) {
						// These extensions are not optional, so do not indicate a preference.
						continue;
					}
					if (Tspath.HasTSFileExtension(path)) {
						return ModuleSpecifierEndingTsExtension;
					}
					if (Tspath.HasJSFileExtension(path)) {
						usesJsExtensions = true;
					}
				}
			}
		}

		if (usesJsExtensions) {
			return ModuleSpecifierEndingJsExtension;
		}
		return ModuleSpecifierEndingMinimal;
	}

	static function getModuleSpecifierEndingPreference(pref:ImportModuleSpecifierEndingPreference, resolutionMode:ResolutionMode,
			compilerOptions:CompilerOptions, sourceFile:SourceFileForSpecifierGeneration):ModuleSpecifierEnding {
		final moduleResolution = compilerOptions.GetModuleResolutionKind();
		final moduleResolutionIsNodeNext = ModuleResolutionKindNode16 <= moduleResolution && moduleResolution <= ModuleResolutionKindNodeNext;

		if (pref == ImportModuleSpecifierEndingPreferenceJs || resolutionMode == Core.ResolutionModeESM && moduleResolutionIsNodeNext) {
			// Extensions are explicitly requested or required. Now choose between .js and .ts.
			if (!shouldAllowImportingTsExtension(compilerOptions, cast "")) {
				return ModuleSpecifierEndingJsExtension;
			}
			// `allowImportingTsExtensions` is a strong signal, so use .ts unless the file
			// already uses .js extensions and no .ts extensions.
			if (inferPreference(resolutionMode, sourceFile, moduleResolutionIsNodeNext) != ModuleSpecifierEndingJsExtension) {
				return ModuleSpecifierEndingTsExtension;
			}
			return ModuleSpecifierEndingJsExtension;
		}

		if (pref == ImportModuleSpecifierEndingPreferenceMinimal) {
			return ModuleSpecifierEndingMinimal;
		}

		if (pref == ImportModuleSpecifierEndingPreferenceIndex) {
			return ModuleSpecifierEndingIndex;
		}

		// No preference was specified.
		// Look at imports and/or requires to guess whether .js, .ts, or extensionless imports are preferred.
		// N.B. that `Index` detection is not supported since it would require file system probing to do
		// accurately, and more importantly, literally nobody wants `Index` and its existence is a mystery.
		if (!shouldAllowImportingTsExtension(compilerOptions, cast "")) {
			// If .ts imports are not valid, we only need to see one .js import to go with that.
			if (sourceFile != null && usesExtensionsOnImports(sourceFile)) {
				return ModuleSpecifierEndingJsExtension;
			}
			return ModuleSpecifierEndingMinimal;
		}

		return inferPreference(resolutionMode, sourceFile, moduleResolutionIsNodeNext);
	}

	static function getPreferredEnding(prefs:UserPreferences, host:ModuleSpecifierGenerationHost, compilerOptions:CompilerOptions,
			importingSourceFile:SourceFileForSpecifierGeneration, oldImportSpecifier:String, resolutionMode:ResolutionMode):ModuleSpecifierEnding {
		if (oldImportSpecifier.length > 0) {
			if (Tspath.HasJSFileExtension(oldImportSpecifier)) {
				return ModuleSpecifierEndingJsExtension;
			}
			if (StringTools.endsWith(oldImportSpecifier, "/index")) {
				return ModuleSpecifierEndingIndex;
			}
		}
		if (resolutionMode == Core.ResolutionModeNone) {
			resolutionMode = host.GetDefaultResolutionModeForFile(importingSourceFile);
		}
		return getModuleSpecifierEndingPreference(prefs.ImportModuleSpecifierEnding, resolutionMode, compilerOptions, importingSourceFile);
	}

	public static function GetAllowedEndingsInPreferredOrder(prefs:UserPreferences, host:ModuleSpecifierGenerationHost, compilerOptions:CompilerOptions,
			importingSourceFile:SourceFileForSpecifierGeneration, oldImportSpecifier:String,
			syntaxImpliedNodeFormat:ResolutionMode):Array<ModuleSpecifierEnding> {
		var preferredEnding = getPreferredEnding(prefs, host, compilerOptions, importingSourceFile, oldImportSpecifier, Core.ResolutionModeNone);
		final resolutionMode = host.GetDefaultResolutionModeForFile(importingSourceFile);
		if (resolutionMode != syntaxImpliedNodeFormat) {
			preferredEnding = getPreferredEnding(prefs, host, compilerOptions, importingSourceFile, oldImportSpecifier, syntaxImpliedNodeFormat);
		}
		final moduleResolution = compilerOptions.GetModuleResolutionKind();
		final moduleResolutionIsNodeNext = ModuleResolutionKindNode16 <= moduleResolution && moduleResolution <= ModuleResolutionKindNodeNext;
		final allowImportingTsExtension = shouldAllowImportingTsExtension(compilerOptions, importingSourceFile.FileName());
		// TypeScript uses `(syntaxImpliedNodeFormat ?? impliedNodeFormat)` here - fall back to the
		// file's default resolution mode when no syntax-implied mode is given.
		var effectiveSyntaxMode = syntaxImpliedNodeFormat;
		if (effectiveSyntaxMode == Core.ResolutionModeNone) {
			effectiveSyntaxMode = resolutionMode;
		}
		if (effectiveSyntaxMode == Core.ResolutionModeESM && moduleResolutionIsNodeNext) {
			if (allowImportingTsExtension) {
				return [ModuleSpecifierEndingTsExtension, ModuleSpecifierEndingJsExtension];
			}
			return [ModuleSpecifierEndingJsExtension];
		}
		switch (preferredEnding) {
			case ModuleSpecifierEndingJsExtension:
				if (allowImportingTsExtension) {
					return [
						ModuleSpecifierEndingJsExtension,
						ModuleSpecifierEndingTsExtension,
						ModuleSpecifierEndingMinimal,
						ModuleSpecifierEndingIndex
					];
				}
				return [ModuleSpecifierEndingJsExtension, ModuleSpecifierEndingMinimal, ModuleSpecifierEndingIndex];
			case ModuleSpecifierEndingTsExtension:
				return [
					ModuleSpecifierEndingTsExtension,
					ModuleSpecifierEndingMinimal,
					ModuleSpecifierEndingJsExtension,
					ModuleSpecifierEndingIndex
				];
			case ModuleSpecifierEndingIndex:
				if (allowImportingTsExtension) {
					return [
						ModuleSpecifierEndingIndex,
						ModuleSpecifierEndingMinimal,
						ModuleSpecifierEndingTsExtension,
						ModuleSpecifierEndingJsExtension
					];
				}
				return [ModuleSpecifierEndingIndex, ModuleSpecifierEndingMinimal, ModuleSpecifierEndingJsExtension];
			case ModuleSpecifierEndingMinimal:
				if (allowImportingTsExtension) {
					return [
						ModuleSpecifierEndingMinimal,
						ModuleSpecifierEndingIndex,
						ModuleSpecifierEndingTsExtension,
						ModuleSpecifierEndingJsExtension
					];
				}
				return [ModuleSpecifierEndingMinimal, ModuleSpecifierEndingIndex, ModuleSpecifierEndingJsExtension];
			default:
				Debug.AssertNever(preferredEnding);
		}
		return [ModuleSpecifierEndingMinimal];
	}

	static function getModuleSpecifierPreferences(prefs:UserPreferences, host:ModuleSpecifierGenerationHost, compilerOptions:CompilerOptions,
			importingSourceFile:SourceFileForSpecifierGeneration, oldImportSpecifier:String):ModuleSpecifierPreferences {
		final excludes = prefs.AutoImportSpecifierExcludeRegexes;
		var relativePreference = RelativePreferenceShortest;
		if (oldImportSpecifier.length > 0) {
			if (Tspath.IsExternalModuleNameRelative(oldImportSpecifier)) {
				relativePreference = RelativePreferenceRelative;
			} else {
				relativePreference = RelativePreferenceNonRelative;
			}
		} else {
			switch (prefs.ImportModuleSpecifierPreference) {
				case ImportModuleSpecifierPreferenceRelative:
					relativePreference = RelativePreferenceRelative;
				case ImportModuleSpecifierPreferenceNonRelative:
					relativePreference = RelativePreferenceNonRelative;
				case ImportModuleSpecifierPreferenceProjectRelative:
					relativePreference = RelativePreferenceExternalNonRelative;
				// all others are shortest
				default:
			}
		}

		final getAllowedEndingsInPreferredOrder = function(syntaxImpliedNodeFormat:ResolutionMode):Array<ModuleSpecifierEnding> {
			return GetAllowedEndingsInPreferredOrder(prefs, host, compilerOptions, importingSourceFile, oldImportSpecifier, syntaxImpliedNodeFormat);
		};

		final result = new ModuleSpecifierPreferences();
		result.excludeRegexes = excludes;
		result.relativePreference = relativePreference;
		result.getAllowedEndingsInPreferredOrder = getAllowedEndingsInPreferredOrder;
		return result;
	}

	// --- specifiers.go ---

	public static function GetModuleSpecifiers(moduleSymbol:Symbol, checker:CheckerShape, compilerOptions:CompilerOptions,
			importingSourceFile:SourceFileForSpecifierGeneration, host:ModuleSpecifierGenerationHost, userPreferences:UserPreferences,
			options:ModuleSpecifierOptions, forAutoImports:Bool):ModuleSpecifiersResult {
		return GetModuleSpecifiersWithInfo(moduleSymbol, checker, compilerOptions, importingSourceFile, host, userPreferences, options, forAutoImports);
	}

	public static function GetModuleSpecifiersWithInfo(moduleSymbol:Symbol, checker:CheckerShape, compilerOptions:CompilerOptions,
			importingSourceFile:SourceFileForSpecifierGeneration, host:ModuleSpecifierGenerationHost, userPreferences:UserPreferences,
			options:ModuleSpecifierOptions, forAutoImports:Bool):ModuleSpecifiersResult {
		final ambient = tryGetModuleNameFromAmbientModule(moduleSymbol, checker);
		if (ambient.name.length > 0) {
			if (forAutoImports && IsExcludedByRegex(ambient.name.AsString(), userPreferences.AutoImportSpecifierExcludeRegexes)) {
				return new ModuleSpecifiersResult(null, ResultKindAmbient, ambient.symbol);
			}
			return new ModuleSpecifiersResult([ambient.name], ResultKindAmbient, ambient.symbol);
		}

		final moduleSourceFile = Ast.GetSourceFileOfModule(moduleSymbol);
		if (moduleSourceFile == null) {
			return new ModuleSpecifiersResult();
		}

		// Use original source file name when file is from project reference output
		final moduleFileName = host.GetSourceOfProjectReferenceIfOutputIncluded(SourceFileAdapter.Of(moduleSourceFile));

		final r = GetModuleSpecifiersForFileWithInfo(importingSourceFile, moduleFileName, compilerOptions, host, userPreferences, options, forAutoImports);
		return new ModuleSpecifiersResult(r.a, r.b);
	}

	public static function GetModuleSpecifiersForFileWithInfo(importingSourceFile:SourceFileForSpecifierGeneration, moduleFileName:RootedFilePath,
			compilerOptions:CompilerOptions, host:ModuleSpecifierGenerationHost, userPreferences:UserPreferences, options:ModuleSpecifierOptions,
			forAutoImports:Bool):Pair<Slice<ModuleSpecifier>, ResultKind> {
		final modulePaths = getAllModulePathsWorker(getInfo(host.GetSourceOfProjectReferenceIfOutputIncluded(importingSourceFile), host), moduleFileName,
			host, compilerOptions, options);

		return computeModuleSpecifiers(modulePaths, compilerOptions, importingSourceFile, host, userPreferences, options, forAutoImports);
	}

	static function tryGetModuleNameFromAmbientModule(moduleSymbol:Symbol, checker:CheckerShape):AmbientModuleInfo {
		if (Core.len(moduleSymbol.Declarations) != 0) {
			for (decl in moduleSymbol.Declarations) {
				if (Ast.IsModuleWithStringLiteralName(decl)
					&& (!Ast.IsModuleAugmentationExternal(decl) || !Tspath.IsExternalModuleNameRelative(decl.Name().Text()))) {
					return new AmbientModuleInfo(Tspath.ToModuleSpecifier(decl.Name().Text()), moduleSymbol);
				}
			}
		}

		// the module could be a namespace, which is export through "export=" from an ambient module.
		/**
		 * declare module "m" {
		 *     namespace ns {
		 *         class c {}
		 *     }
		 *     export = ns;
		 * }
		 */
		// `import {c} from "m";` is valid, in which case, `moduleSymbol` is "ns", but the module name should be "m"
		if (Core.len(moduleSymbol.Declarations) != 0) {
			for (d in moduleSymbol.Declarations) {
				if (!Ast.IsModuleDeclaration(d)) {
					continue;
				}

				final possibleContainer = Ast.FindAncestor(d, Ast.IsModuleWithStringLiteralName);
				if (possibleContainer == null || possibleContainer.Parent == null || !Ast.IsSourceFile(possibleContainer.Parent)) {
					continue;
				}

				final exports = possibleContainer.Symbol().Exports;
				final sym = exports == null ? null : exports.get(Ast.InternalSymbolNameExportEquals);
				if (sym == null) {
					continue;
				}
				final exportAssignmentDecl = sym.ValueDeclaration;
				if (exportAssignmentDecl == null || exportAssignmentDecl.Kind != Kind.KindExportAssignment) {
					continue;
				}
				var exportSymbol = checker.GetSymbolAtLocation(exportAssignmentDecl.Expression());
				if (exportSymbol == null) {
					continue;
				}
				if ((exportSymbol.Flags & SymbolFlagsAlias) != 0) {
					exportSymbol = checker.GetAliasedSymbol(exportSymbol);
				}
				// TODO: Possible strada bug - isn't this insufficient in the presence of merge symbols?
				if (exportSymbol == d.Symbol()) {
					return new AmbientModuleInfo(Tspath.ToModuleSpecifier(possibleContainer.Name().Text()), possibleContainer.Symbol());
				}
			}
		}
		return new AmbientModuleInfo(cast "", null);
	}

	static function getInfo(importingSourceFileName:RootedFilePath, host:ModuleSpecifierGenerationHost):Info {
		return new Info(host.CaseSensitivity(), importingSourceFileName, importingSourceFileName.Directory());
	}

	static function getAllModulePaths(info:Info, importedFileName:RootedFilePath, host:ModuleSpecifierGenerationHost, compilerOptions:CompilerOptions,
			preferences:UserPreferences, options:ModuleSpecifierOptions):Array<ModulePath> {
		// !!! use new cache model
		// importingFilePath := info.CaseSensitivity.PathKey(info.ImportingSourceFileName.AsPath())
		// importedFilePath := info.CaseSensitivity.PathKey(importedFileName.AsPath())
		// cache := host.getModuleSpecifierCache();
		// if (cache != nil) {
		//     cached := cache.get(importingFilePath, importedFilePath, preferences, options);
		//     if (cached.modulePaths) {return cached.modulePaths;}
		// }
		final modulePaths = getAllModulePathsWorker(info, importedFileName, host, compilerOptions, options);
		// if (cache != nil) {
		//     cache.setModulePaths(importingFilePath, importedFilePath, preferences, options, modulePaths);
		// }
		return modulePaths;
	}

	static function getAllModulePathsWorker(info:Info, importedFileName:RootedFilePath, host:ModuleSpecifierGenerationHost,
			compilerOptions:CompilerOptions, options:ModuleSpecifierOptions):Array<ModulePath> {
		// PORT: Go map (random iteration order) → StringMap + key list; each group is sorted below,
		// so the result does not depend on the iteration order (as in Go).
		final allFileNames = new StringMap<ModulePath>();
		final allFileNameKeys:Array<RootedFilePath> = [];
		final paths = GetEachFileNameOfModule(info.ImportingSourceFileName, importedFileName, host, true);
		for (p in paths) {
			if (!allFileNames.exists(p.FileName))
				allFileNameKeys.push(p.FileName);
			allFileNames.set(p.FileName, p);
		}

		final caseSensitivity = info.CaseSensitivity;
		final comparePaths = function(a:ModulePath, b:ModulePath):Int {
			return comparePathsByRedirect(a, b, caseSensitivity);
		};

		// Sort by paths closest to importing file Name directory
		final sortedPaths:Array<ModulePath> = [];
		var directory = info.SourceDirectory;
		while (allFileNameKeys.length != 0) {
			var pathsInDirectory:Slice<ModulePath> = null;
			var i = 0;
			while (i < allFileNameKeys.length) {
				final fileName = allFileNameKeys[i];
				if (caseSensitivity.StartsWithDirectory(fileName, directory)) {
					if (pathsInDirectory == null)
						pathsInDirectory = [];
					pathsInDirectory.push(allFileNames.get(fileName));
					allFileNames.remove(fileName);
					allFileNameKeys.splice(i, 1);
				} else {
					i++;
				}
			}
			if (Core.len(pathsInDirectory) > 0) {
				Slices.SortFunc(pathsInDirectory, comparePaths);
				for (p in pathsInDirectory)
					sortedPaths.push(p);
			}
			final newDirectory = directory.AsPath().Directory();
			if (newDirectory == directory) {
				break;
			}
			directory = newDirectory;
		}
		if (allFileNameKeys.length > 0) {
			final remainingPaths = [for (k in allFileNameKeys) allFileNames.get(k)];
			Slices.SortFunc(remainingPaths, comparePaths);
			for (p in remainingPaths)
				sortedPaths.push(p);
		}
		return sortedPaths;
	}

	// containsIgnoredPath checks if a path contains patterns that should be ignored.
	// This is a local helper that duplicates tspath.ContainsIgnoredPath for performance.
	static function containsIgnoredPath(fileName:RootedFilePath):Bool {
		return fileName.AsString().indexOf("/node_modules/.") >= 0 || fileName.AsString().indexOf("/.git") >= 0 || fileName.AsString().indexOf(".#") >= 0;
	}

	static function moduleSpecifierContainsNodeModules(specifier:ModuleSpecifier):Bool {
		return specifier.Contains("/node_modules/");
	}

	// GetEachFileNameOfModule returns all possible file paths for a module, including symlink alternatives.
	// This function handles symlink resolution and provides multiple path options for module resolution.
	public static function GetEachFileNameOfModule(importingFileName:RootedFilePath, importedFileName:RootedFilePath,
			host:ModuleSpecifierGenerationHost, preferSymlinks:Bool):Array<ModulePath> {
		final caseSensitivity = host.CaseSensitivity();
		final importedPath = caseSensitivity.PathKey(importedFileName.AsPath());
		var referenceRedirect:RootedFilePath = cast "";
		final outputAndReference = host.GetProjectReferenceFromSource(importedPath);
		if (outputAndReference != null && outputAndReference.OutputDts != "") {
			referenceRedirect = outputAndReference.OutputDts;
		}

		final redirects = host.GetRedirectTargets(importedPath);
		final importedFileNames:Array<RootedFilePath> = [];
		if (referenceRedirect != "") {
			importedFileNames.push(referenceRedirect);
		}
		importedFileNames.push(importedFileName);
		if (redirects != null) {
			for (r in redirects)
				importedFileNames.push(r);
		}
		final targets = importedFileNames;
		var shouldFilterIgnoredPaths = !Core.Every(targets, containsIgnoredPath);

		final results:Array<ModulePath> = [];
		if (!preferSymlinks) {
			for (p in targets) {
				if (!(shouldFilterIgnoredPaths && containsIgnoredPath(p))) {
					results.push(new ModulePath(p, p.ContainsLowercaseDirectorySequence("/node_modules/"), referenceRedirect == p));
				}
			}
		}

		final symlinkCache = host.GetSymlinkCache();
		if (symlinkCache != null) {
			Tspath.ForEachAncestorDirectoryPathStoppingAtGlobalCache(host.GetGlobalTypingsCacheLocation(), importedFileName.Directory(),
				function(realPathDirectory:RootedDirectoryPath):ValueOk<Bool> {
					final loaded = symlinkCache.DirectoriesByRealpath().Load(caseSensitivity.PathKey(realPathDirectory.AsPath()));
					if (!loaded.ok) {
						return new ValueOk<Bool>(false, false);
					} // Continue to ancestor directory
					final symlinkSet = loaded.value;

					// Don't want to a package to globally import from itself (importNameCodeFix_symlink_own_package.ts)
					if (caseSensitivity.ContainsFilePath(realPathDirectory, importingFileName)) {
						return new ValueOk<Bool>(false, true); // Stop search, each ancestor directory will also hit this condition
					}

					for (target in targets) {
						final relative = caseSensitivity.RelativeFilePathFromDirectory(realPathDirectory, target);
						if (relative == null) {
							continue;
						}
						symlinkSet.Range(function(symlinkDirectory:RootedDirectoryPath):Bool {
							final option = symlinkDirectory.ResolveRelativeFile(relative);
							results.push(new ModulePath(option, option.ContainsLowercaseDirectorySequence("/node_modules/"), target == referenceRedirect));
							shouldFilterIgnoredPaths = true; // We found a non-ignored path in symlinks, so we can reject ignored-path realpaths
							return true;
						});
					}

					return new ValueOk<Bool>(false, false);
				});
		}

		if (preferSymlinks) {
			for (p in targets) {
				if (!(shouldFilterIgnoredPaths && containsIgnoredPath(p))) {
					results.push(new ModulePath(p, p.ContainsLowercaseDirectorySequence("/node_modules/"), referenceRedirect == p));
				}
			}
		}

		return results;
	}

	static function computeModuleSpecifiers(modulePaths:Array<ModulePath>, compilerOptions:CompilerOptions,
			importingSourceFile:SourceFileForSpecifierGeneration, host:ModuleSpecifierGenerationHost, userPreferences:UserPreferences,
			options:ModuleSpecifierOptions, forAutoImport:Bool):Pair<Slice<ModuleSpecifier>, ResultKind> {
		final info = getInfo(importingSourceFile.FileName(), host);
		final preferences = getModuleSpecifierPreferences(userPreferences, host, compilerOptions, importingSourceFile, "");
		final caseSensitivity = info.CaseSensitivity;

		var existingSpecifier:ModuleSpecifier = cast "";
		for (modulePath in modulePaths) {
			final targetPath = caseSensitivity.PathKey(modulePath.FileName.AsPath());
			var existingImport:StringLiteralLike = null;
			final imports = importingSourceFile.Imports();
			if (imports != null) {
				for (importSpecifier in imports) {
					final resolvedModule = host.GetResolvedModuleFromModuleSpecifier(importingSourceFile, importSpecifier);
					if (resolvedModule.IsResolved() && resolvedModule.ResolvedPath == targetPath) {
						existingImport = importSpecifier;
						break;
					}
				}
			}
			if (existingImport != null) {
				if (preferences.relativePreference == RelativePreferenceNonRelative && Tspath.PathIsRelative(existingImport.Text())) {
					// If the preference is for non-relative and the module specifier is relative, ignore it
					continue;
				}
				final existingMode = host.GetModeForUsageLocation(importingSourceFile, existingImport);
				var targetMode = options.OverrideImportMode;
				if (targetMode == Core.ResolutionModeNone) {
					targetMode = host.GetDefaultResolutionModeForFile(importingSourceFile);
				}
				if (existingMode != targetMode && existingMode != Core.ResolutionModeNone && targetMode != Core.ResolutionModeNone) {
					// If the candidate import mode doesn't match the mode we're generating for, don't consider it
					continue;
				}
				existingSpecifier = Tspath.ToModuleSpecifier(existingImport.Text());
				break;
			}
		}

		if (existingSpecifier != "") {
			return new Pair<Slice<ModuleSpecifier>, ResultKind>([existingSpecifier], ResultKindNone);
		}

		final importedFileIsInNodeModules = Core.Some(modulePaths, function(p:ModulePath):Bool return p.IsInNodeModules);

		// Module specifier priority:
		//   1. "Bare package specifiers" (e.g. "@foo/bar") resulting from a path through node_modules to a package.json's "types" entry
		//   2. Specifiers generated using "paths" from tsconfig
		//   3. Non-relative specfiers resulting from a path through node_modules (e.g. "@foo/bar/path/to/file")
		//   4. Relative paths
		var pathsSpecifiers:Slice<ModuleSpecifier> = null;
		var redirectPathsSpecifiers:Slice<ModuleSpecifier> = null;
		var nodeModulesSpecifiers:Slice<ModuleSpecifier> = null;
		var relativeSpecifiers:Slice<ModuleSpecifier> = null;

		for (modulePath in modulePaths) {
			var specifier:ModuleSpecifier = cast "";
			if (modulePath.IsInNodeModules) {
				specifier = tryGetModuleNameAsNodeModule(modulePath, info, importingSourceFile, host, compilerOptions, userPreferences /*packageNameOnly*/,
					false, options.OverrideImportMode);
			}
			if (specifier.length > 0 && !(forAutoImport && IsExcludedByRegex(specifier.AsString(), preferences.excludeRegexes))) {
				if (nodeModulesSpecifiers == null)
					nodeModulesSpecifiers = [];
				nodeModulesSpecifiers.push(specifier);
				if (modulePath.IsRedirect) {
					// If we got a specifier for a redirect, it was a bare package specifier (e.g. "@foo/bar",
					// not "@foo/bar/path/to/file"). No other specifier will be this good, so stop looking.
					return new Pair<Slice<ModuleSpecifier>, ResultKind>(nodeModulesSpecifiers, ResultKindNodeModules);
				}
			}

			var importMode = options.OverrideImportMode;
			if (importMode == Core.ResolutionModeNone) {
				importMode = host.GetDefaultResolutionModeForFile(importingSourceFile);
			}
			final local = getLocalModuleSpecifier(modulePath.FileName, info, compilerOptions, host, importMode, preferences,
				/*pathsOnly*/ modulePath.IsRedirect || specifier.length > 0);
			if (local.length == 0 || forAutoImport && IsExcludedByRegex(local.AsString(), preferences.excludeRegexes)) {
				continue;
			}
			if (modulePath.IsRedirect) {
				if (redirectPathsSpecifiers == null)
					redirectPathsSpecifiers = [];
				redirectPathsSpecifiers.push(local);
			} else if (PathIsBareSpecifier(local)) {
				if (moduleSpecifierContainsNodeModules(local)) {
					// We could be in this branch due to inappropriate use of `baseUrl`, not intentional `paths`
					// usage. It's impossible to reason about where to prioritize baseUrl-generated module
					// specifiers, but if they contain `/node_modules/`, they're going to trigger a portability
					// error, so *at least* don't prioritize those.
					if (relativeSpecifiers == null)
						relativeSpecifiers = [];
					relativeSpecifiers.push(local);
				} else {
					if (pathsSpecifiers == null)
						pathsSpecifiers = [];
					pathsSpecifiers.push(local);
				}
			} else if (forAutoImport || !importedFileIsInNodeModules || modulePath.IsInNodeModules) {
				// Why this extra conditional, not just an `else`? If some path to the file contained
				// 'node_modules', but we can't create a non-relative specifier (e.g. "@foo/bar/path/to/file"),
				// that means we had to go through a *sibling's* node_modules, not one we can access directly.
				// If some path to the file was in node_modules but another was not, this likely indicates that
				// we have a monorepo structure with symlinks. In this case, the non-nodeModules path is
				// probably the realpath, e.g. "../bar/path/to/file", but a relative path to another package
				// in a monorepo is probably not portable. So, the module specifier we actually go with will be
				// the relative path through node_modules, so that the declaration emitter can produce a
				// portability error. (See declarationEmitReexportedSymlinkReference3)
				if (relativeSpecifiers == null)
					relativeSpecifiers = [];
				relativeSpecifiers.push(local);
			}
		}

		if (Core.len(pathsSpecifiers) > 0) {
			return new Pair<Slice<ModuleSpecifier>, ResultKind>(pathsSpecifiers, ResultKindPaths);
		}
		if (Core.len(redirectPathsSpecifiers) > 0) {
			return new Pair<Slice<ModuleSpecifier>, ResultKind>(redirectPathsSpecifiers, ResultKindRedirect);
		}
		if (Core.len(nodeModulesSpecifiers) > 0) {
			return new Pair<Slice<ModuleSpecifier>, ResultKind>(nodeModulesSpecifiers, ResultKindNodeModules);
		}
		return new Pair<Slice<ModuleSpecifier>, ResultKind>(relativeSpecifiers, ResultKindRelative);
	}

	static function getLocalModuleSpecifier(moduleFileName:RootedFilePath, info:Info, compilerOptions:CompilerOptions,
			host:ModuleSpecifierGenerationHost, importMode:ResolutionMode, preferences:ModuleSpecifierPreferences, pathsOnly:Bool):ModuleSpecifier {
		final paths = compilerOptions.Paths;
		final rootDirs = compilerOptions.GetEffectiveRootDirs();

		if (pathsOnly && paths == null) {
			return cast "";
		}

		final sourceDirectory = info.SourceDirectory;

		final allowedEndings = preferences.getAllowedEndingsInPreferredOrder(importMode);
		var relativePath:ModuleSpecifier = cast "";
		if (Core.len(rootDirs) > 0) {
			relativePath = tryGetModuleNameFromRootDirs(rootDirs, moduleFileName, sourceDirectory, allowedEndings, compilerOptions, host);
		}
		if (relativePath.length == 0) {
			final relativePathFromSource = host.CaseSensitivity().RelativePathFromDirectory(sourceDirectory, moduleFileName);
			var path = moduleFileName.AsString();
			if (relativePathFromSource != null) {
				path = relativePathFromSource.AsModuleSpecifier().AsString();
			}
			relativePath = processEnding(Tspath.ToModuleSpecifier(path), moduleFileName, allowedEndings, compilerOptions, host);
		}

		if ((paths == null && !compilerOptions.GetResolvePackageJsonImports()) || preferences.relativePreference == RelativePreferenceRelative) {
			if (pathsOnly) {
				return cast "";
			}
			return relativePath;
		}

		var baseDirectory = host.BaseDirectory();
		final pathsBasePath = compilerOptions.GetPathsBasePath(baseDirectory);
		if (pathsBasePath != "") {
			baseDirectory = pathsBasePath;
		}
		final relativeToBaseUrl = getRelativePathIfInSameVolume(moduleFileName, baseDirectory, host.CaseSensitivity());
		if (relativeToBaseUrl.length == 0) {
			if (pathsOnly) {
				return cast "";
			}
			return relativePath;
		}

		var fromPackageJsonImports:ModuleSpecifier = cast "";
		if (!pathsOnly) {
			fromPackageJsonImports = tryGetModuleNameFromPackageJsonImports(moduleFileName, sourceDirectory, compilerOptions, host, importMode,
				prefersTsExtension(allowedEndings));
		}

		var fromPaths = "";
		if ((pathsOnly || fromPackageJsonImports.length == 0) && paths != null) {
			fromPaths = tryGetModuleNameFromPaths(relativeToBaseUrl.AsString(), moduleFileName, paths, allowedEndings, baseDirectory, host,
				compilerOptions);
		}

		if (pathsOnly) {
			return Tspath.ToModuleSpecifier(fromPaths);
		}

		var maybeNonRelative:String;
		if (fromPackageJsonImports.length > 0) {
			maybeNonRelative = fromPackageJsonImports.AsString();
		} else {
			maybeNonRelative = fromPaths;
		}
		if (maybeNonRelative.length == 0) {
			return relativePath;
		}

		final relativeIsExcluded = IsExcludedByRegex(relativePath.AsString(), preferences.excludeRegexes);
		final nonRelativeIsExcluded = IsExcludedByRegex(maybeNonRelative, preferences.excludeRegexes);
		if (!relativeIsExcluded && nonRelativeIsExcluded) {
			return relativePath;
		}
		if (relativeIsExcluded && !nonRelativeIsExcluded) {
			return Tspath.ToModuleSpecifier(maybeNonRelative);
		}

		if (preferences.relativePreference == RelativePreferenceNonRelative && !Tspath.PathIsRelative(maybeNonRelative)) {
			return Tspath.ToModuleSpecifier(maybeNonRelative);
		}

		if (preferences.relativePreference == RelativePreferenceExternalNonRelative && !Tspath.PathIsRelative(maybeNonRelative)) {
			var projectDirectory:PathKey;
			final configFileName = compilerOptions.ConfigFilePath;
			if (configFileName != "") {
				projectDirectory = host.CaseSensitivity().PathKey(configFileName.Directory().AsPath());
			} else {
				projectDirectory = host.CaseSensitivity().PathKey(host.BaseDirectory().AsPath());
			}
			final caseSensitivity = host.CaseSensitivity();
			final canonicalSourceDirectory = caseSensitivity.PathKey(sourceDirectory.AsPath());
			final modulePath = caseSensitivity.PathKey(moduleFileName.AsPath());

			final sourceIsInternal = projectDirectory.ContainsPath(canonicalSourceDirectory);
			final targetIsInternal = projectDirectory.ContainsPath(modulePath);
			if (sourceIsInternal && !targetIsInternal || !sourceIsInternal && targetIsInternal) {
				// 1. The import path crosses the boundary of the tsconfig.json-containing directory.
				//
				//      src/
				//        tsconfig.json
				//        index.ts -------
				//      lib/              | (path crosses tsconfig.json)
				//        imported.ts <---
				//
				return Tspath.ToModuleSpecifier(maybeNonRelative);
			}

			final nearestTargetPackageJson = host.GetNearestAncestorDirectoryWithPackageJson(moduleFileName.Directory());
			final nearestSourcePackageJson = host.GetNearestAncestorDirectoryWithPackageJson(sourceDirectory);

			if (!packageJsonPathsAreEqual(nearestTargetPackageJson, nearestSourcePackageJson, host.CaseSensitivity())) {
				// 2. The importing and imported files are part of different packages.
				//
				//      packages/a/
				//        package.json
				//        index.ts --------
				//      packages/b/        | (path crosses package.json)
				//        package.json     |
				//        component.ts <---
				//
				return Tspath.ToModuleSpecifier(maybeNonRelative);
			}

			return relativePath;
		}

		// Prefer a relative import over a baseUrl import if it has fewer components.
		if (StringTools.startsWith(maybeNonRelative, "..") || CountPathComponents(relativePath.AsString()) < CountPathComponents(maybeNonRelative)) {
			return relativePath;
		}
		return Tspath.ToModuleSpecifier(maybeNonRelative);
	}

	static function processEnding(specifier:ModuleSpecifier, sourceFileName:RootedFilePath, allowedEndings:Array<ModuleSpecifierEnding>,
			options:CompilerOptions, host:ModuleSpecifierGenerationHost):ModuleSpecifier {
		final fileName = specifier.AsString();
		if (Tspath.FileExtensionIsOneOf(fileName, [Tspath.ExtensionJson, Tspath.ExtensionMjs, Tspath.ExtensionCjs])) {
			return specifier;
		}

		final noExtension = Tspath.RemoveFileExtension(fileName);
		if (fileName == noExtension) {
			return specifier;
		}

		final jsPriority = Slices.Index(allowedEndings, ModuleSpecifierEndingJsExtension);
		final tsPriority = Slices.Index(allowedEndings, ModuleSpecifierEndingTsExtension);
		if (Tspath.FileExtensionIsOneOf(fileName, [Tspath.ExtensionMts, Tspath.ExtensionCts]) && tsPriority != -1 && tsPriority < jsPriority) {
			return specifier;
		}
		if (Tspath.FileExtensionIsOneOf(fileName, [Tspath.ExtensionDmts, Tspath.ExtensionDcts])) {
			final inputExt = Tspath.GetDeclarationFileExtension(fileName);
			final ext = GetJSExtensionForDeclarationFileExtension(inputExt);
			return Tspath.ToModuleSpecifier(Tspath.RemoveExtension(fileName, inputExt) + ext);
		}
		if (Tspath.FileExtensionIsOneOf(fileName, [Tspath.ExtensionMts, Tspath.ExtensionCts])) {
			return Tspath.ToModuleSpecifier(noExtension + getJSExtensionForFile(fileName, options));
		}
		if (!Tspath.FileExtensionIsOneOf(fileName, [Tspath.ExtensionDts])
			&& Tspath.FileExtensionIsOneOf(fileName, [Tspath.ExtensionTs])
			&& fileName.indexOf(".d.") >= 0) {
			// `foo.d.json.ts` and the like - remap back to `foo.json`
			final result = TryGetRealFileNameForNonJSDeclarationFileName(fileName);
			if (result != "") {
				return Tspath.ToModuleSpecifier(result);
			}
		}

		switch (allowedEndings[0]) {
			case ModuleSpecifierEndingMinimal:
				final withoutIndex = trimSuffix(noExtension, "/index");
				if (host != null && withoutIndex != noExtension && tryGetAnyFileFromPath(host, Tspath.RootedFilePathFromPath(sourceFileName.Directory().AsPath()))) {
					// Can't remove index if there's a file by the same name as the directory.
					// Probably more callers should pass `host` so we can determine this?
					return Tspath.ToModuleSpecifier(noExtension);
				}
				return Tspath.ToModuleSpecifier(withoutIndex);
			case ModuleSpecifierEndingIndex:
				return Tspath.ToModuleSpecifier(noExtension);
			case ModuleSpecifierEndingJsExtension:
				return Tspath.ToModuleSpecifier(noExtension + getJSExtensionForFile(fileName, options));
			case ModuleSpecifierEndingTsExtension:
				// For now, we don't know if this import is going to be type-only, which means we don't
				// know if a .d.ts extension is valid, so use no extension or a .js extension
				if (Tspath.IsDeclarationFileName(fileName)) {
					var extensionlessPriority = -1;
					for (i in 0...allowedEndings.length) {
						final e = allowedEndings[i];
						if (e == ModuleSpecifierEndingMinimal || e == ModuleSpecifierEndingIndex) {
							extensionlessPriority = i;
							break;
						}
					}
					if (extensionlessPriority != -1 && extensionlessPriority < jsPriority) {
						return Tspath.ToModuleSpecifier(noExtension);
					}
					return Tspath.ToModuleSpecifier(noExtension + getJSExtensionForFile(fileName, options));
				}
				return specifier;
			default:
				Debug.AssertNever(allowedEndings[0]);
				return cast "";
		}
	}

	static function tryGetModuleNameFromRootDirs(rootDirs:Slice<RootedDirectoryPath>, moduleFileName:RootedFilePath,
			sourceDirectory:RootedDirectoryPath, allowedEndings:Array<ModuleSpecifierEnding>, compilerOptions:CompilerOptions,
			host:ModuleSpecifierGenerationHost):ModuleSpecifier {
		final normalizedTargetPaths = getPathsRelativeToRootDirs(moduleFileName, rootDirs, host.CaseSensitivity());
		if (Core.len(normalizedTargetPaths) == 0) {
			return cast "";
		}

		final normalizedSourcePaths = getPathsRelativeToRootDirs(Tspath.RootedFilePathFromPath(sourceDirectory.AsPath()), rootDirs, host.CaseSensitivity());
		var shortest:ModuleSpecifier = cast "";
		var shortestSepCount = 0;
		if (normalizedSourcePaths != null) {
			for (sourcePath in normalizedSourcePaths) {
				for (targetPath in normalizedTargetPaths) {
					final candidate = host.CaseSensitivity().RelativePathFromRelativeDirectory(sourcePath, targetPath).AsModuleSpecifier();
					final candidateSepCount = Strings.Count(candidate.AsString(), "/");
					if (shortest.length == 0 || candidateSepCount < shortestSepCount) {
						shortest = candidate;
						shortestSepCount = candidateSepCount;
					}
				}
			}
		}

		if (shortest.length == 0) {
			return cast "";
		}
		return processEnding(shortest, moduleFileName, allowedEndings, compilerOptions, host);
	}

	static function tryGetModuleNameAsNodeModule(pathObj:ModulePath, info:Info, importingSourceFile:SourceFileForSpecifierGeneration,
			host:ModuleSpecifierGenerationHost, options:CompilerOptions, userPreferences:UserPreferences, packageNameOnly:Bool,
			overrideMode:ResolutionMode):ModuleSpecifier {
		final parts = GetNodeModulePathParts(pathObj.FileName);
		if (parts == null) {
			return cast "";
		}

		final caseSensitivity = host.CaseSensitivity();
		final globalTypingsCacheLocation = host.GetGlobalTypingsCacheLocation();
		// Check reachability before consulting package.json exports, which can return
		// a bare specifier directly. An exported path is only usable if the importing
		// file can reach the package through node_modules, and packages under the
		// global typings cache are excluded.
		if (!caseSensitivity.ContainsPath(parts.TopLevelNodeModulesSearchRoot, info.SourceDirectory.AsPath())
			|| globalTypingsCacheLocation != ""
			&& caseSensitivity.ContainsPath(parts.TopLevelNodeModulesSearchRoot, globalTypingsCacheLocation.AsPath())) {
			return cast "";
		}

		// Simplify the full file path to something that can be resolved by Node.
		final preferences = getModuleSpecifierPreferences(userPreferences, host, options, importingSourceFile, "");
		final allowedEndings = preferences.getAllowedEndingsInPreferredOrder(Core.ResolutionModeNone);

		var moduleSpecifier = pathObj.FileName.AsString();
		var isPackageRootPath = false;
		if (!packageNameOnly) {
			if (parts.IsDirectNodeModulesFile) {
				moduleSpecifier = processEnding(pathObj.FileName.AsModuleSpecifier(), pathObj.FileName, allowedEndings, options, host).AsString();
			} else {
				var moduleFileName:RootedFilePath = cast "";
				var packageRootDirectory = parts.PackageRootDirectory;
				final relativeComponents = parts.PackageRelativePath.AsString().split("/");
				var i = 0;
				while (true) {
					final packagePath = packageRootDirectory.AsPath().RelativeTo(parts.TopLevelNodeModulesDirectory);
					if (packagePath == null) {
						return cast "";
					}
					// If the module could be imported by a directory name, use that directory's name
					final pkgJsonResults = tryDirectoryWithPackageJson(packageRootDirectory, parts.PackageRootDirectory, packagePath.AsString(), pathObj,
						importingSourceFile, host, overrideMode, options, allowedEndings);
					final moduleFileToTry = pkgJsonResults.moduleFileToTry;
					final resolvedPackageRoot = pkgJsonResults.packageRootDirectory;
					final blockedByExports = pkgJsonResults.blockedByExports;
					if (blockedByExports) {
						return cast ""; // File is under this package.json, but is not publicly exported - there's no way to name it via `node_modules` resolution
					}
					if (pkgJsonResults.verbatimFromExports != "") {
						return pkgJsonResults.verbatimFromExports;
					}
					//}
					if (resolvedPackageRoot != "") {
						moduleSpecifier = resolvedPackageRoot.AsString();
						isPackageRootPath = true;
						break;
					}
					if (moduleFileName.length == 0) {
						moduleFileName = moduleFileToTry;
					}
					if (i >= relativeComponents.length - 1) {
						moduleSpecifier = processEnding(moduleFileName.AsModuleSpecifier(), moduleFileName, allowedEndings, options, host).AsString();
						break;
					}
					packageRootDirectory = packageRootDirectory.ResolveDirectory(relativeComponents[i]);
					i++;
				}
			}
		}

		if (pathObj.IsRedirect && !isPackageRootPath) {
			return cast "";
		}

		// If the module was found in @types, get the actual Node package name
		final nodeModulesPrefix = Tspath.EnsureTrailingDirectorySeparator(parts.TopLevelNodeModulesDirectory.AsString());
		if (!StringTools.startsWith(moduleSpecifier, nodeModulesPrefix)) {
			return cast "";
		}
		final nodeModulesDirectoryName = moduleSpecifier.substring(nodeModulesPrefix.length);
		return Tspath.ToModuleSpecifier(Module.GetPackageNameFromTypesPackageName(nodeModulesDirectoryName));
	}

	static function tryDirectoryWithPackageJson(packageRootDirectory:RootedDirectoryPath, packageBaseDirectory:RootedDirectoryPath,
			packageName:String, pathObj:ModulePath, importingSourceFile:SourceFileForSpecifierGeneration, host:ModuleSpecifierGenerationHost,
			overrideMode:ResolutionMode, options:CompilerOptions, allowedEndings:Array<ModuleSpecifierEnding>):PkgJsonDirAttemptResult {
		final packageJsonPath = packageRootDirectory.ResolveFile("package.json");
		var moduleFileToTry = pathObj.FileName;
		var maybeBlockedByTypesVersions = false;
		final packageJson = host.GetPackageJsonInfo(packageJsonPath);
		if (packageJson == null) {
			// No package.json exists; an index.js will still resolve as the package name
			final relative = moduleFileToTry.RelativeTo(packageBaseDirectory);
			if (relative == null) {
				throw "module file was not contained by package root";
			}
			final fileName = relative.AsString();
			if (fileName == "index.d.ts" || fileName == "index.js" || fileName == "index.ts" || fileName == "index.tsx") {
				return new PkgJsonDirAttemptResult(moduleFileToTry, packageRootDirectory);
			} else {
				return new PkgJsonDirAttemptResult(moduleFileToTry);
			}
		}

		var importMode = overrideMode;
		if (importMode == Core.ResolutionModeNone) {
			importMode = host.GetDefaultResolutionModeForFile(importingSourceFile);
		}

		final packageJsonContent = packageJson.GetContents();
		if (options.GetResolvePackageJsonExports()) {
			// The package name that we found in node_modules could be different from the package
			// name in the package.json content via url/filepath dependency specifiers. We need to
			// use the actual directory name, so don't look at `packageJsonContent.name` here.
			final packageName = Module.GetPackageNameFromTypesPackageName(packageName);

			// Determine resolution mode for package.json exports condition matching.
			// TypeScript's tryDirectoryWithPackageJson uses the importing file's mode (moduleSpecifiers.ts:1257),
			// but this causes incorrect exports resolution. We fix this by checking the target file's extension
			// using the logic from getImpliedNodeFormatForEmitWorker (program.ts:4827-4838).
			// .cjs/.cts/.d.cts → CommonJS → "require" condition
			// .mjs/.mts/.d.mts → ESM → "import" condition
			if (pathObj.FileName.ExtensionIsOneOf([Tspath.ExtensionCjs, Tspath.ExtensionCts, Tspath.ExtensionDcts])) {
				importMode = Core.ResolutionModeCommonJS;
			} else if (pathObj.FileName.ExtensionIsOneOf([Tspath.ExtensionMjs, Tspath.ExtensionMts, Tspath.ExtensionDmts])) {
				importMode = Core.ResolutionModeESM;
			}

			final conditions = Module.GetConditions(options, importMode);

			var fromExports:ModuleSpecifier = cast "";
			if (packageJsonContent != null && packageJsonContent.Fields.Exports.Type != JSONValueTypeNotPresent) {
				fromExports = tryGetModuleNameFromExports(options, host, pathObj.FileName, packageRootDirectory, packageName,
					packageJsonContent.Fields.Exports, conditions);
			}
			if (fromExports.length > 0) {
				return new PkgJsonDirAttemptResult(cast "", null, false, fromExports);
			}
			if (packageJsonContent != null && packageJsonContent.Fields.Exports.Type != JSONValueTypeNotPresent) {
				return new PkgJsonDirAttemptResult(moduleFileToTry, null, true);
			}
		}

		var versionPaths = new VersionPaths();
		if (packageJsonContent != null && packageJsonContent.TypesVersions.Type == JSONValueTypeObject) {
			versionPaths = packageJsonContent.GetVersionPaths(null);
		}
		if (versionPaths.GetPaths() != null) {
			final subModuleName = moduleFileToTry.RelativeTo(packageRootDirectory);
			if (subModuleName == null) {
				throw "module file was not contained by package root";
			}
			final fromPaths = tryGetModuleNameFromPaths(subModuleName.AsString(), moduleFileToTry, versionPaths.GetPaths(), allowedEndings,
				packageRootDirectory, host, options);
			if (fromPaths.length == 0) {
				maybeBlockedByTypesVersions = true;
			} else {
				moduleFileToTry = packageRootDirectory.ResolveFile(fromPaths);
			}
		}
		// If the file is the main module, it can be imported by the package name
		var mainFileRelative = "index.js";
		if (packageJsonContent != null) {
			if (packageJsonContent.Typings.Valid) {
				mainFileRelative = packageJsonContent.Typings.Value;
			} else if (packageJsonContent.Types.Valid) {
				mainFileRelative = packageJsonContent.Types.Value;
			} else if (packageJsonContent.Main.Valid) {
				mainFileRelative = packageJsonContent.Main.Value;
			}
		}

		if (mainFileRelative.length > 0
			&& !(maybeBlockedByTypesVersions
				&& !Module.MatchPatternOrExact(Module.TryParsePatterns(versionPaths.GetPaths()), mainFileRelative).Equals(new Pattern()))) {
			// The 'main' file is also subject to mapping through typesVersions, and we couldn't come up with a path
			// explicitly through typesVersions, so if it matches a key in typesVersions now, it's not reachable.
			// (The only way this can happen is if some file in a package that's not resolvable from outside the
			// package got pulled into the program anyway, e.g. transitively through a file that *is* reachable. It
			// happens very easily in fourslash tests though, since every test file listed gets included. See
			// importNameCodeFix_typesVersions.ts for an example.)
			final caseSensitivity = host.CaseSensitivity();
			var packageType = "";
			if (packageJsonContent != null) {
				packageType = packageJsonContent.Type.Value;
			}
			if (isPackageMainFile(moduleFileToTry, packageRootDirectory, mainFileRelative, packageType, caseSensitivity)) {
				return new PkgJsonDirAttemptResult(moduleFileToTry, packageRootDirectory);
			}
		}

		return new PkgJsonDirAttemptResult(moduleFileToTry);
	}

	static function isPackageMainFile(moduleFileName:RootedFilePath, packageRootDirectory:RootedDirectoryPath, mainFileRelative:String,
			packageType:String, caseSensitivity:CaseSensitivity):Bool {
		final mainIsDirectory = Tspath.HasTrailingDirectorySeparator(mainFileRelative);
		final mainExportFile = packageRootDirectory.ResolveFile(mainFileRelative);

		if (!mainIsDirectory && caseSensitivity.CompareFileNameStems(mainExportFile.RemoveFileExtension(), moduleFileName.RemoveFileExtension()) == 0) {
			// An arbitrary removal of file extension for this comparison is almost certainly wrong.
			return true;
		}
		final mainExportDirectory = Tspath.RootedDirectoryPathFromPath(mainExportFile.AsPath());
		return packageType != "module"
			&& !moduleFileName.ExtensionIsOneOf(Tspath.ExtensionsNotSupportingExtensionlessResolution)
			&& caseSensitivity.ComparePaths(moduleFileName.Directory().AsPath(), mainExportDirectory.AsPath()) == 0
			&& Tspath.RemoveFileExtension(moduleFileName.BaseName()) == "index";
	}

	static function tryGetModuleNameFromExports(options:CompilerOptions, host:ModuleSpecifierGenerationHost, targetFileName:RootedFilePath,
			packageDirectory:RootedDirectoryPath, packageName:String, exports:ExportsOrImports, conditions:Slice<String>):ModuleSpecifier {
		if (exports.IsSubpaths()) {
			// sub-mappings
			// 3 cases:
			// * directory mappings (legacyish, key ends with / (technically allows index/extension resolution under cjs mode))
			// * pattern mappings (contains a *)
			// * exact mappings (no *, does not end with /)
			for (k => subk in exports.AsObject().Entries()) {
				final subPackageName = Tspath.ResolvePathWithoutTrailingDirectorySeparator(packageName, k);
				var mode = MatchingModeExact;
				if (StringTools.endsWith(k, "/")) {
					mode = MatchingModeDirectory;
				} else if (k.indexOf("*") >= 0) {
					mode = MatchingModePattern;
				}
				final result = tryGetModuleNameFromExportsOrImports(options, host, targetFileName, packageDirectory, subPackageName, subk, conditions,
					mode /*isImports*/, false /*preferTsExtension*/, false);
				if (result.length > 0) {
					return Tspath.ToModuleSpecifier(result);
				}
			}
		}
		return Tspath.ToModuleSpecifier(tryGetModuleNameFromExportsOrImports(options, host, targetFileName, packageDirectory, packageName, exports,
			conditions, MatchingModeExact,
			/*isImports*/ false,
			/*preferTsExtension*/ false));
	}

	static function tryGetModuleNameFromPackageJsonImports(moduleFileName:RootedFilePath, sourceDirectory:RootedDirectoryPath,
			options:CompilerOptions, host:ModuleSpecifierGenerationHost, importMode:ResolutionMode, preferTsExtension:Bool):ModuleSpecifier {
		if (!options.GetResolvePackageJsonImports()) {
			return cast "";
		}

		final ancestorDirectoryWithPackageJson = host.GetNearestAncestorDirectoryWithPackageJson(sourceDirectory);
		if (ancestorDirectoryWithPackageJson.length == 0) {
			return cast "";
		}
		final packageJsonPath = ancestorDirectoryWithPackageJson.ResolveFile("package.json");

		final info = host.GetPackageJsonInfo(packageJsonPath);
		if (info == null) {
			return cast "";
		}

		final imports = info.GetContents().Fields.Imports;
		switch (imports.Type) {
			case JSONValueTypeNotPresent, JSONValueTypeArray, JSONValueTypeString:
				return cast ""; // not present or invalid for imports
			case JSONValueTypeObject:
				final conditions = Module.GetConditions(options, importMode);
				final top = imports.AsObject();
				for (k => value in top.Entries()) {
					if (k == "#" || k == "#/" || !StringTools.startsWith(k, "#")) {
						continue; // invalid imports entry
					}
					if (StringTools.startsWith(k, "#/")
						&& options.GetModuleResolutionKind() != ModuleResolutionKindNodeNext
						&& options.GetModuleResolutionKind() != ModuleResolutionKindBundler) {
						continue; // "#/" imports keys are only valid in nodenext/bundler
					}
					var mode = MatchingModeExact;
					if (StringTools.endsWith(k, "/")) {
						mode = MatchingModeDirectory;
					} else if (k.indexOf("*") >= 0) {
						mode = MatchingModePattern;
					}
					final result = tryGetModuleNameFromExportsOrImports(options, host, moduleFileName, ancestorDirectoryWithPackageJson, k, value,
						conditions, mode, true, preferTsExtension);
					if (result.length > 0) {
						return Tspath.ToModuleSpecifier(result);
					}
				}
			default:
		}

		return cast "";
	}

	static function tryGetModuleNameFromPaths(relativeToBaseUrl:String, fileName:RootedFilePath, paths:OrderedMap<String, Slice<String>>,
			allowedEndings:Array<ModuleSpecifierEnding>, baseDirectory:RootedDirectoryPath, host:ModuleSpecifierGenerationHost,
			compilerOptions:CompilerOptions):String {
		final caseSensitivity = host.CaseSensitivity();
		for (key => values in paths.Entries()) {
			if (values == null)
				continue;
			for (patternText in values) {
				final normalized = Tspath.NormalizePath(patternText);
				var pattern = resolvePathPatternIfInSameVolume(normalized, baseDirectory, caseSensitivity);
				if (pattern.length == 0) {
					pattern = normalized;
				}
				// PORT: strings.Cut(pattern, "*").
				final starIndex = pattern.indexOf("*");
				final ok = starIndex >= 0;
				final prefix = ok ? pattern.substring(0, starIndex) : pattern;
				final suffix = ok ? pattern.substring(starIndex + 1) : "";

				// In module resolution, if `pattern` itself has an extension, a file with that extension is looked up directly,
				// meaning a '.ts' or '.d.ts' extension is allowed to resolve. This is distinct from the case where a '*' substitution
				// causes a module specifier to have an extension, i.e. the extension comes from the module specifier in a JS/TS file
				// and matches the '*'. For example:
				//
				// Module Specifier      | Path Mapping (key: [pattern]) | Interpolation       | Resolution Action
				// ---------------------->------------------------------->--------------------->---------------------------------------------------------------
				// import "@app/foo"    -> "@app/*": ["./src/app/*.ts"] -> "./src/app/foo.ts" -> tryFile("./src/app/foo.ts") || [continue resolution algorithm]
				// import "@app/foo.ts" -> "@app/*": ["./src/app/*"]    -> "./src/app/foo.ts" -> [continue resolution algorithm]
				//
				// (https://github.com/microsoft/TypeScript/blob/ad4ded80e1d58f0bf36ac16bea71bc10d9f09895/src/compiler/moduleNameResolver.ts#L2509-L2516)
				//
				// The interpolation produced by both scenarios is identical, but only in the former, where the extension is encoded in
				// the path mapping rather than in the module specifier, will we prioritize a file lookup on the interpolation result.
				// (In fact, currently, the latter scenario will necessarily fail since no resolution mode recognizes '.ts' as a valid
				// extension for a module specifier.)
				//
				// Here, this means we need to be careful about whether we generate a match from the target filename (typically with a
				// .ts extension) or the possible relative module specifiers representing that file:
				//
				// Filename            | Relative Module Specifier Candidates         | Path Mapping                 | Filename Result    | Module Specifier Results
				// --------------------<----------------------------------------------<------------------------------<-------------------||----------------------------
				// dist/haha.d.ts      <- dist/haha, dist/haha.js                     <- "@app/*": ["./dist/*.d.ts"] <- @app/haha        || (none)
				// dist/haha.d.ts      <- dist/haha, dist/haha.js                     <- "@app/*": ["./dist/*"]      <- (none)           || @app/haha, @app/haha.js
				// dist/foo/index.d.ts <- dist/foo, dist/foo/index, dist/foo/index.js <- "@app/*": ["./dist/*.d.ts"] <- @app/foo/index   || (none)
				// dist/foo/index.d.ts <- dist/foo, dist/foo/index, dist/foo/index.js <- "@app/*": ["./dist/*"]      <- (none)           || @app/foo, @app/foo/index, @app/foo/index.js
				// dist/wow.js.js      <- dist/wow.js, dist/wow.js.js                 <- "@app/*": ["./dist/*.js"]   <- @app/wow.js      || @app/wow, @app/wow.js
				//
				// The "Filename Result" can be generated only if `pattern` has an extension. Care must be taken that the list of
				// relative module specifiers to run the interpolation (a) is actually valid for the module resolution mode, (b) takes
				// into account the existence of other files (e.g. 'dist/wow.js' cannot refer to 'dist/wow.js.js' if 'dist/wow.js'
				// exists) and (c) that they are ordered by preference. The last row shows that the filename result and module
				// specifier results are not mutually exclusive. Note that the filename result is a higher priority in module
				// resolution, but as long criteria (b) above is met, I don't think its result needs to be the highest priority result
				// in module specifier generation. I have included it last, as it's difficult to tell exactly where it should be
				// sorted among the others for a particular value of `importModuleSpecifierEnding`.

				final candidates:Array<SpecPair> = [];
				if (allowedEndings != null) {
					for (ending in allowedEndings) {
						final result = processEnding(Tspath.ToModuleSpecifier(relativeToBaseUrl), fileName, [ending], compilerOptions, host);
						candidates.push(new SpecPair(ending, result));
					}
				}
				if (Tspath.TryGetExtensionFromPath(pattern).length > 0) {
					candidates.push(new SpecPair(ModuleSpecifierEndingJsExtension, Tspath.ToModuleSpecifier(relativeToBaseUrl)));
				}

				if (ok) {
					for (c in candidates) {
						final value = c.value.AsString();
						if (value.length >= prefix.length + suffix.length
							&& Stringutil.HasPrefix(value, prefix, caseSensitivity.IsCaseSensitive()) // TODO: possible strada bug: these are not case-switched in strada
							&& Stringutil.HasSuffix(value, suffix, caseSensitivity.IsCaseSensitive())
							&& validateEnding(c, relativeToBaseUrl, fileName, compilerOptions, host)) {
							final matchedStar = value.substring(prefix.length, value.length - suffix.length);
							if (!Tspath.PathIsRelative(matchedStar)) {
								return replaceFirstStar(key, matchedStar);
							}
						}
					}
				} else if (Core.Some(candidates, function(c:SpecPair):Bool {
					return c.ending != ModuleSpecifierEndingMinimal && pattern == c.value.AsString();
				})
					|| Core.Some(candidates, function(c:SpecPair):Bool {
						return c.ending == ModuleSpecifierEndingMinimal
							&& pattern == c.value.AsString()
							&& validateEnding(c, relativeToBaseUrl, fileName, compilerOptions, host);
					})) {
					return key;
				}
			}
		}
		return "";
	}

	static function validateEnding(c:SpecPair, relativeToBaseUrl:String, fileName:RootedFilePath, compilerOptions:CompilerOptions,
			host:ModuleSpecifierGenerationHost):Bool {
		// Optimization: `removeExtensionAndIndexPostFix` can query the file system (a good bit) if `ending` is `Minimal`, the basename
		// is 'index', and a `host` is provided. To avoid that until it's unavoidable, we ran the function with no `host` above. Only
		// here, after we've checked that the minimal ending is indeed a match (via the length and prefix/suffix checks / `some` calls),
		// do we check that the host-validated result is consistent with the answer we got before. If it's not, it falls back to the
		// `ModuleSpecifierEnding.Index` result, which should already be in the list of candidates if `Minimal` was. (Note: the assumption here is
		// that every module resolution mode that supports dropping extensions also supports dropping `/index`. Like literally
		// everything else in this file, this logic needs to be updated if that's not true in some future module resolution mode.)
		return c.ending != ModuleSpecifierEndingMinimal
			|| c.value == processEnding(Tspath.ToModuleSpecifier(relativeToBaseUrl), fileName, [c.ending], compilerOptions, host);
	}

	static function tryGetModuleNameFromExportsOrImports(options:CompilerOptions, host:ModuleSpecifierGenerationHost, targetFileName:RootedFilePath,
			packageDirectory:RootedDirectoryPath, packageName:String, exports:ExportsOrImports, conditions:Slice<String>, mode:MatchingMode,
			isImports:Bool, preferTsExtension:Bool):String {
		final packageSpecifier = Tspath.ToModuleSpecifier(packageName);
		switch (exports.Type) {
			case JSONValueTypeNotPresent:
				return "";
			case JSONValueTypeString:
				final strValue:String = exports.Value;

				// possible strada bug? Always uses compilerOptions of the host project, not those applicable to the targeted package.json!
				var outputFile:RootedFilePath = cast "";
				var declarationFile:RootedFilePath = cast "";
				if (isImports) {
					outputFile = Outputpaths.GetOutputJSFileNameWorker(targetFileName, options, host);
					declarationFile = Outputpaths.GetOutputDeclarationFileNameWorker(targetFileName, options, host);
				}

				var extensionSwappedTarget:RootedFilePath = cast "";
				if (targetFileName.HasTSFileExtension()) {
					extensionSwappedTarget = targetFileName.RemoveFileExtension().AppendSuffix(Module.TryGetJSExtensionForFileName(targetFileName, options));
				}
				final canTryTsExtension = preferTsExtension && targetFileName.HasImplementationTSFileExtension();

				final caseSensitivity = host.CaseSensitivity();

				switch (mode) {
					case MatchingModeExact:
						if (Tspath.HasTrailingDirectorySeparator(strValue)) {
							return "";
						}
						final resolvedTarget = packageDirectory.ResolveFile(strValue);
						if (extensionSwappedTarget.length > 0 && caseSensitivity.CompareFilePaths(extensionSwappedTarget, resolvedTarget) == 0
							|| caseSensitivity.CompareFilePaths(targetFileName, resolvedTarget) == 0
							|| outputFile.length > 0 && caseSensitivity.CompareFilePaths(outputFile, resolvedTarget) == 0
							|| declarationFile.length > 0 && caseSensitivity.CompareFilePaths(declarationFile, resolvedTarget) == 0) {
							return packageName;
						}
					case MatchingModeDirectory:
						final resolvedTarget = packageDirectory.ResolveDirectory(Tspath.RemoveTrailingDirectorySeparator(strValue));
						if (canTryTsExtension
							&& caseSensitivity.ContainsPath(Tspath.RootedDirectoryPathFromPath(targetFileName.AsPath()), resolvedTarget.AsPath())) {
							final fragment = caseSensitivity.RelativePathFromDirectory(resolvedTarget, targetFileName);
							return packageSpecifier.Resolve(strValue, fragment.AsString()).AsString();
						}
						if (extensionSwappedTarget.length > 0 && caseSensitivity.ContainsFilePath(resolvedTarget, extensionSwappedTarget)) {
							final fragment = caseSensitivity.RelativePathFromDirectory(resolvedTarget, extensionSwappedTarget);
							return packageSpecifier.Resolve(strValue, fragment.AsString()).AsString();
						}
						if (!canTryTsExtension && caseSensitivity.ContainsFilePath(resolvedTarget, targetFileName)) {
							final fragment = caseSensitivity.RelativePathFromDirectory(resolvedTarget, targetFileName);
							return packageSpecifier.Resolve(strValue, fragment.AsString()).AsString();
						}
						if (outputFile.length > 0 && caseSensitivity.ContainsFilePath(resolvedTarget, outputFile)) {
							final fragment = caseSensitivity.RelativePathFromDirectory(resolvedTarget, outputFile);
							return packageSpecifier.CombineRelative(fragment).AsString();
						}
						if (declarationFile.length > 0 && caseSensitivity.ContainsFilePath(resolvedTarget, declarationFile)) {
							final fragment = caseSensitivity.RelativePathFromDirectory(resolvedTarget, declarationFile);
							final jsExtension = getJSExtensionForFileName(declarationFile, options);
							final fragmentWithJsExtension = fragment.ChangeExtension(jsExtension);
							return packageSpecifier.CombineRelative(fragmentWithJsExtension).AsString();
						}
					case MatchingModePattern:
						final pathOrPattern = Tspath.ResolvePath(packageDirectory.AsString(), strValue);
						// PORT: strings.Cut(pathOrPattern, "*").
						final starIndex = pathOrPattern.indexOf("*");
						final leadingSlice = starIndex >= 0 ? pathOrPattern.substring(0, starIndex) : pathOrPattern;
						final trailingSlice = starIndex >= 0 ? pathOrPattern.substring(starIndex + 1) : "";
						final caseSensitivity = host.CaseSensitivity();
						final targetFilePath = targetFileName.AsString();
						if (canTryTsExtension
							&& Stringutil.HasPrefixAndSuffixWithoutOverlap(targetFilePath, leadingSlice, trailingSlice, caseSensitivity.IsCaseSensitive())) {
							final starReplacement = targetFilePath.substring(leadingSlice.length, targetFilePath.length - trailingSlice.length);
							return replaceFirstStar(packageName, starReplacement);
						}
						final extensionSwappedTargetString = extensionSwappedTarget.AsString();
						if (extensionSwappedTargetString.length > 0
							&& Stringutil.HasPrefixAndSuffixWithoutOverlap(extensionSwappedTargetString, leadingSlice, trailingSlice,
								caseSensitivity.IsCaseSensitive())) {
							final starReplacement = extensionSwappedTargetString.substring(leadingSlice.length,
								extensionSwappedTargetString.length - trailingSlice.length);
							return replaceFirstStar(packageName, starReplacement);
						}
						if (!canTryTsExtension
							&& Stringutil.HasPrefixAndSuffixWithoutOverlap(targetFilePath, leadingSlice, trailingSlice, caseSensitivity.IsCaseSensitive())) {
							final starReplacement = targetFilePath.substring(leadingSlice.length, targetFilePath.length - trailingSlice.length);
							return replaceFirstStar(packageName, starReplacement);
						}
						final outputFileString = outputFile.AsString();
						if (outputFileString.length > 0
							&& Stringutil.HasPrefixAndSuffixWithoutOverlap(outputFileString, leadingSlice, trailingSlice, caseSensitivity.IsCaseSensitive())) {
							final starReplacement = outputFileString.substring(leadingSlice.length, outputFileString.length - trailingSlice.length);
							return replaceFirstStar(packageName, starReplacement);
						}
						final declarationFileString = declarationFile.AsString();
						if (declarationFileString.length > 0
							&& Stringutil.HasPrefixAndSuffixWithoutOverlap(declarationFileString, leadingSlice, trailingSlice,
								caseSensitivity.IsCaseSensitive())) {
							final starReplacement = declarationFileString.substring(leadingSlice.length, declarationFileString.length - trailingSlice.length);
							final substituted = replaceFirstStar(packageName, starReplacement);
							final jsExtension = Module.TryGetJSExtensionForFileName(declarationFile, options);
							if (jsExtension.length > 0) {
								return Tspath.ChangeFullExtension(substituted, jsExtension);
							}
						}
					default:
				}
				return "";
			case JSONValueTypeArray:
				final arr = exports.AsArray();
				for (e in arr) {
					final result = tryGetModuleNameFromExportsOrImports(options, host, targetFileName, packageDirectory, packageName, e, conditions, mode,
						isImports, preferTsExtension);
					if (result.length > 0) {
						return result;
					}
				}
			case JSONValueTypeObject:
				// conditional mapping
				final obj = exports.AsObject();
				for (key => value in obj.Entries()) {
					if (key == "default"
						|| Slices.Contains(conditions, key)
						|| Slices.Contains(conditions, "types") && Module.IsApplicableVersionedTypesKey(key)) {
						final result = tryGetModuleNameFromExportsOrImports(options, host, targetFileName, packageDirectory, packageName, value, conditions,
							mode, isImports, preferTsExtension);
						if (result.length > 0) {
							return result;
						}
					}
				}
			case JSONValueTypeNull:
				return "";
			default:
		}
		return "";
	}

	// `importingSourceFile` and `importingSourceFileName`? Why not just use `importingSourceFile.path`?
	// Because when this is called by the declaration emitter, `importingSourceFile` is the implementation
	// file, but `importingSourceFileName` and `toFileName` refer to declaration files (the former to the
	// one currently being produced; the latter to the one being imported). We need an implementation file
	// just to get its `impliedNodeFormat` and to detect certain preferences from existing import module
	// specifiers.
	public static function GetModuleSpecifier(compilerOptions:CompilerOptions, host:ModuleSpecifierGenerationHost,
			importingSourceFile:SourceFile, // !!! | FutureSourceFile
			importingSourceFileName:RootedFilePath, oldImportSpecifier:ModuleSpecifier, // used only in updatingModuleSpecifier
			toFileName:RootedFilePath, options:ModuleSpecifierOptions):ModuleSpecifier {
		return getModuleSpecifierWithPreferences(compilerOptions, host, importingSourceFile, importingSourceFileName, oldImportSpecifier, toFileName,
			new UserPreferences(), options);
	}

	public static function UpdateModuleSpecifier(compilerOptions:CompilerOptions, host:ModuleSpecifierGenerationHost, importingSourceFile:SourceFile,
			importingSourceFileName:RootedFilePath, oldImportSpecifier:ModuleSpecifier, toFileName:RootedFilePath, userPreferences:UserPreferences,
			options:ModuleSpecifierOptions):ModuleSpecifier {
		return getModuleSpecifierWithPreferences(compilerOptions, host, importingSourceFile, importingSourceFileName, oldImportSpecifier, toFileName,
			userPreferences, options);
	}

	static function getModuleSpecifierWithPreferences(compilerOptions:CompilerOptions, host:ModuleSpecifierGenerationHost,
			importingSourceFile:SourceFile, // !!! | FutureSourceFile
			importingSourceFileName:RootedFilePath, oldImportSpecifier:ModuleSpecifier, // used only in updatingModuleSpecifier
			toFileName:RootedFilePath, userPreferences:UserPreferences, options:ModuleSpecifierOptions):ModuleSpecifier {
		// PORT: *ast.SourceFile as SourceFileForSpecifierGeneration / ast.HasFileName → adapter.
		final importingFile = SourceFileAdapter.Of(importingSourceFile);
		final info = getInfo(importingSourceFileName, host);
		final modulePaths = getAllModulePaths(info, toFileName, host, compilerOptions, userPreferences, options);
		final preferences = getModuleSpecifierPreferences(userPreferences, host, compilerOptions, importingFile, oldImportSpecifier.AsString());

		var resolutionMode = options.OverrideImportMode;
		if (resolutionMode == Core.ResolutionModeNone) {
			resolutionMode = host.GetDefaultResolutionModeForFile(importingFile);
		}

		for (modulePath in modulePaths) {
			final firstDefined = tryGetModuleNameAsNodeModule(modulePath, info, importingFile, host, compilerOptions, userPreferences,
				false /*packageNameOnly*/, options.OverrideImportMode);
			if (firstDefined.length > 0) {
				return firstDefined;
			}
		}

		return getLocalModuleSpecifier(toFileName, info, compilerOptions, host, resolutionMode, preferences, false);
	}

	// --- util.go ---

	// PORT: map[regexPatternCacheKey]*regexp.Regexp → StringMap keyed by "<0|1>" + pattern (struct key
	// encoded as a String). The RWMutex is dropped (single-threaded port).
	#if tshx_parallel
	// PORT: hxmc (-D tshx-parallel) — a cache per thread (go.Par.slot): an EReg keeps its last match
	static final regexPatternCaches:Array<StringMap<Null<EReg>>> = [for (_ in 0...go.Par.SLOTS) new StringMap()];
	static final regexPatternCacheSizes:Array<Int> = [for (_ in 0...go.Par.SLOTS) 0];
	static var regexPatternCache(get, never):StringMap<Null<EReg>>;
	static var regexPatternCacheSize(get, set):Int;

	static inline function get_regexPatternCache()
		return regexPatternCaches[go.Par.slot];

	static inline function get_regexPatternCacheSize()
		return regexPatternCacheSizes[go.Par.slot];

	static inline function set_regexPatternCacheSize(v:Int)
		return regexPatternCacheSizes[go.Par.slot] = v;
	#else
	static final regexPatternCache = new StringMap<Null<EReg>>();
	static var regexPatternCacheSize = 0;
	#end

	static function comparePathsByRedirect(a:ModulePath, b:ModulePath, caseSensitivity:CaseSensitivity):Int {
		// Redirects sort first, matching Strada's compareBooleans(b.isRedirect, a.isRedirect).
		final c1 = Core.CompareBooleans(b.IsRedirect, a.IsRedirect);
		if (c1 != 0) {
			return c1;
		}
		final c2 = Reflect.compare(a.FileName.DirectorySeparatorCount(), b.FileName.DirectorySeparatorCount());
		if (c2 != 0) {
			return c2;
		}
		// Strada relies on Map insertion order to break remaining ties deterministically;
		// Go maps are unordered, so compare paths to keep the ordering stable.
		return caseSensitivity.CompareFilePaths(a.FileName, b.FileName);
	}

	public static function PathIsBareSpecifier(path:ModuleSpecifier):Bool {
		return !path.IsAbsolute() && !path.IsRelative();
	}

	public static function IsExcludedByRegex(moduleSpecifier:String, excludes:Slice<String>):Bool {
		if (excludes == null)
			return false;
		for (pattern in excludes) {
			final re = stringToRegex(pattern);
			if (re == null) {
				continue;
			}
			if (re.match(moduleSpecifier)) {
				return true;
			}
		}
		return false;
	}

	// PORT: Go compiles the pattern with RE2 (regexp.Compile) and wraps it in `(?i:...)` when
	// case-insensitive. User patterns cannot be rewritten for the EReg backends (PORTING.md §7),
	// so the pattern is passed to EReg as is (JS RegExp / PCRE2 syntax) and the `i` flag is used.
	// A pattern that does not compile is cached as null, like Go.
	static function stringToRegex(pattern:String):Null<EReg> {
		var caseInsensitive = false;

		if (pattern.length > 2 && StringTools.fastCodeAt(pattern, 0) == "/".code) {
			final lastSlash = pattern.lastIndexOf("/");
			if (lastSlash > 0) {
				var hasUnescapedMiddleSlash = false;
				for (i in 1...lastSlash) {
					if (StringTools.fastCodeAt(pattern, i) == "/".code && (i == 0 || StringTools.fastCodeAt(pattern, i - 1) != "\\".code)) {
						hasUnescapedMiddleSlash = true;
						break;
					}
				}

				if (!hasUnescapedMiddleSlash) {
					final flags = pattern.substring(lastSlash + 1);
					pattern = pattern.substring(1, lastSlash);

					for (i in 0...flags.length) {
						switch (StringTools.fastCodeAt(flags, i)) {
							case "i".code:
								caseInsensitive = true;
							default:
						}
					}
				}
			}
		}
		final key = (caseInsensitive ? "1" : "0") + pattern;

		if (regexPatternCache.exists(key)) {
			return regexPatternCache.get(key);
		}

		if (regexPatternCacheSize > 1000) {
			regexPatternCache.clear();
			regexPatternCacheSize = 0;
		}

		var compiled:Null<EReg> = null;
		try {
			compiled = new EReg(pattern, caseInsensitive ? "i" : "");
		} catch (e:Dynamic) {
			compiled = null;
		}
		regexPatternCache.set(key, compiled);
		regexPatternCacheSize++;
		return compiled;
	}

	public static function GetJSExtensionForDeclarationFileExtension(ext:String):String {
		switch (ext) {
			case Tspath.ExtensionDts:
				return Tspath.ExtensionJs;
			case Tspath.ExtensionDmts:
				return Tspath.ExtensionMjs;
			case Tspath.ExtensionDcts:
				return Tspath.ExtensionCjs;
			default:
				// .d.json.ts and the like
				return ext.substring(".d".length, ext.length - Tspath.ExtensionTs.length);
		}
	}

	// TryGetRealFileNameForNonJSDeclarationFileName remaps files like `foo.d.json.ts` or
	// `foo.module.d.css.ts` back to their real non-JS names.
	public static function TryGetRealFileNameForNonJSDeclarationFileName(fileName:String):String {
		final baseName = Tspath.GetBaseFileName(fileName);
		// Ends with .ts, contains ".d.", and is NOT a standard .d.ts file
		if (!StringTools.endsWith(fileName, Tspath.ExtensionTs) || baseName.indexOf(".d.") < 0 || StringTools.endsWith(baseName, Tspath.ExtensionDts)) {
			return "";
		}
		final noExtension = Tspath.RemoveExtension(fileName, Tspath.ExtensionTs);
		final lastDotIndex = noExtension.lastIndexOf(".");
		final ext = noExtension.substring(lastDotIndex);
		// PORT: strings.Cut(noExtension, ".d.") — `before` is the text before the first ".d." (or all of it).
		final cut = noExtension.indexOf(".d.");
		final before = cut >= 0 ? noExtension.substring(0, cut) : noExtension;
		return before + ext;
	}

	static function getJSExtensionForFile(fileName:String, options:CompilerOptions):String {
		final result = Module.TryGetJSExtensionForFile(fileName, options);
		if (result.length == 0) {
			throw 'Extension ${extensionFromPath(fileName)} is unsupported:: FileName:: $fileName';
		}
		return result;
	}

	static function getJSExtensionForFileName(fileName:RootedFilePath, options:CompilerOptions):String {
		final result = Module.TryGetJSExtensionForFileName(fileName, options);
		if (result.length == 0) {
			throw 'Extension ${fileName.Extension()} is unsupported:: FileName:: $fileName';
		}
		return result;
	}

	/**
	 * Gets the extension from a path.
	 * Path must have a valid extension.
	 */
	static function extensionFromPath(path:String):String {
		final ext = Tspath.TryGetExtensionFromPath(path);
		if (ext.length == 0) {
			throw 'File $path has unknown extension.';
		}
		return ext;
	}

	static function tryGetAnyFileFromPath(host:ModuleSpecifierGenerationHost, path:RootedFilePath):Bool {
		// !!! TODO: shouldn't this use readdir instead of fileexists for perf?
		// We check all js, `node` and `json` extensions in addition to TS, since node module resolution would also choose those over the directory
		final allowJsOptions = new CompilerOptions();
		allowJsOptions.AllowJs = TSTrue;
		final extGroups = Tsoptions.GetSupportedExtensions(allowJsOptions, [".node", ".json"]);
		for (exts in extGroups) {
			for (e in exts) {
				if (host.FileExists(path.AppendSuffix(e))) {
					return true;
				}
			}
		}
		return false;
	}

	static function getPathsRelativeToRootDirs(path:RootedFilePath, rootDirs:Slice<RootedDirectoryPath>,
			caseSensitivity:CaseSensitivity):Slice<RelativePath> {
		var results:Slice<RelativePath> = null;
		for (rootDir in rootDirs) {
			final relativePath = getRelativePathIfInSameVolume(path, rootDir, caseSensitivity);
			if (!isPathRelativeToParent(relativePath)) {
				if (results == null)
					results = [];
				results.push(relativePath);
			}
		}
		return results;
	}

	static function isPathRelativeToParent(path:RelativePath):Bool {
		return path.IsParentRelative();
	}

	static function getRelativePathIfInSameVolume(path:RootedFilePath, directoryPath:RootedDirectoryPath,
			caseSensitivity:CaseSensitivity):RelativePath {
		final relativePath = caseSensitivity.RelativePathFromDirectory(directoryPath, path);
		if (relativePath == null) {
			return Tspath.RelativePathFromNormalized("");
		}
		return relativePath;
	}

	static function resolvePathPatternIfInSameVolume(path:String, directoryPath:RootedDirectoryPath, caseSensitivity:CaseSensitivity):String {
		final relativePath = Tspath.ResolveRelativePathToDirectoryOrUrl(directoryPath.AsString(), path, false, directoryPath, caseSensitivity);

		if (Tspath.IsRootedDiskPath(relativePath)) {
			return "";
		}
		return relativePath;
	}

	static function packageJsonPathsAreEqual(a:RootedDirectoryPath, b:RootedDirectoryPath, caseSensitivity:CaseSensitivity):Bool {
		if (a == b) {
			return true;
		}
		if (a == "" || b == "") {
			return false;
		}
		return caseSensitivity.ComparePaths(a.AsPath(), b.AsPath()) == 0;
	}

	static function prefersTsExtension(allowedEndings:Array<ModuleSpecifierEnding>):Bool {
		final jsPriority = Slices.Index(allowedEndings, ModuleSpecifierEndingJsExtension);
		final tsPriority = Slices.Index(allowedEndings, ModuleSpecifierEndingTsExtension);
		if (tsPriority > -1) {
			return tsPriority < jsPriority;
		}
		return false;
	}

	static function replaceFirstStar(s:String, replacement:String):String {
		// PORT: strings.Replace(s, "*", replacement, 1).
		final i = s.indexOf("*");
		if (i < 0)
			return s;
		return s.substring(0, i) + replacement + s.substring(i + 1);
	}

	// PORT: strings.TrimSuffix.
	static inline function trimSuffix(s:String, suffix:String):String {
		return StringTools.endsWith(s, suffix) ? s.substring(0, s.length - suffix.length) : s;
	}

	public static function GetNodeModulePathParts(fileName:RootedFilePath):Null<NodeModulePathParts> {
		final fullPath = fileName.AsString();
		var topLevelNodeModulesIndex = -1;
		var packageNameStart = -1;
		var packageRootIndex = -1;
		var hasNestedNodeModules = false;
		var partEnd = 0;
		var state = nodeModulesPathParseStateBeforeNodeModules;

		while (partEnd >= 0) {
			final partStart = partEnd;
			partEnd = Core.IndexAfter(fullPath, "/", partStart + 1);
			switch (state) {
				case nodeModulesPathParseStateBeforeNodeModules:
					if (StringTools.startsWith(fullPath.substring(partStart), "/node_modules/")) {
						topLevelNodeModulesIndex = partStart;
						state = nodeModulesPathParseStateNodeModules;
					}
				case nodeModulesPathParseStateNodeModules:
					packageNameStart = partStart + 1;
					if (packageNameStart >= fullPath.length) {
						return null;
					}
					if (StringTools.fastCodeAt(fullPath, packageNameStart) == "@".code) {
						state = nodeModulesPathParseStateScope;
					} else {
						packageRootIndex = partEnd;
						state = nodeModulesPathParseStatePackageContent;
					}
				case nodeModulesPathParseStateScope:
					packageRootIndex = partEnd;
					state = nodeModulesPathParseStatePackageContent;
				case nodeModulesPathParseStatePackageContent:
					if (StringTools.startsWith(fullPath.substring(partStart), "/node_modules/")) {
						hasNestedNodeModules = true;
						state = nodeModulesPathParseStateNodeModules;
					}
				default:
			}
		}

		if (topLevelNodeModulesIndex == -1 || packageNameStart == -1) {
			return null;
		}

		final rootLength = fileName.RootLength();
		final searchRootEnd = Std.int(Math.max(topLevelNodeModulesIndex, rootLength));
		final topLevelNodeModulesSearchRoot = Tspath.RootedDirectoryPathFromNormalized(fullPath.substring(0, searchRootEnd));
		final topLevelNodeModulesDirectory = Tspath.RootedDirectoryPathFromNormalized(fullPath.substring(0,
			topLevelNodeModulesIndex + "/node_modules".length));
		if (packageRootIndex == -1) {
			return new NodeModulePathParts(topLevelNodeModulesSearchRoot, topLevelNodeModulesDirectory, cast "", fullPath.substring(packageNameStart),
				Tspath.RelativePathFromNormalized(""), hasNestedNodeModules, true);
		}
		final packageRootDirectory = Tspath.RootedDirectoryPathFromNormalized(fullPath.substring(0, packageRootIndex));
		return new NodeModulePathParts(topLevelNodeModulesSearchRoot, topLevelNodeModulesDirectory, packageRootDirectory,
			fullPath.substring(packageNameStart, packageRootIndex), Tspath.RelativePathFromNormalized(fullPath.substring(packageRootIndex + 1)),
			hasNestedNodeModules, false);
	}

	public static function GetNodeModulesPackageName(compilerOptions:CompilerOptions, importingSourceFile:SourceFile, // !!! | FutureSourceFile
			nodeModulesFileName:RootedFilePath, host:ModuleSpecifierGenerationHost, preferences:UserPreferences,
			options:ModuleSpecifierOptions):ModuleSpecifier {
		final info = getInfo(importingSourceFile.FileName(), host);
		final modulePaths = getAllModulePaths(info, nodeModulesFileName, host, compilerOptions, preferences, options);
		for (modulePath in modulePaths) {
			final result = tryGetModuleNameAsNodeModule(modulePath, info, SourceFileAdapter.Of(importingSourceFile), host, compilerOptions, preferences,
				true /*packageNameOnly*/, options.OverrideImportMode);
			if (result.length > 0) {
				return result;
			}
		}
		return cast "";
	}

	static function allKeysStartWithDot(obj:OrderedMap<String, ExportsOrImports>):Bool {
		for (k in obj.Keys()) {
			if (!StringTools.startsWith(k, ".")) {
				return false;
			}
		}
		return true;
	}

	public static function GetPackageNameFromDirectory(path:RootedPath):String {
		final fileOrDirectoryPath = path.AsString();
		final idx = fileOrDirectoryPath.lastIndexOf("/node_modules/");
		if (idx == -1) {
			return "";
		}

		final basename = fileOrDirectoryPath.substring(idx + "/node_modules/".length);
		if (StringTools.fastCodeAt(basename, 0) == ".".code) {
			return "";
		}

		final nextSlash = basename.indexOf("/");
		if (nextSlash == -1) {
			return basename;
		}

		if (StringTools.fastCodeAt(basename, 0) != "@".code || nextSlash == basename.length - 1) {
			return basename.substring(0, nextSlash);
		}

		final secondSlash = basename.substring(nextSlash + 1).indexOf("/");
		if (secondSlash == -1) {
			return basename;
		}

		return basename.substring(0, nextSlash + 1 + secondSlash);
	}

	// ProcessEntrypointEnding processes a pre-computed module specifier from a package.json exports
	// entrypoint according to the entrypoint's Ending type and the user's preferred endings.
	public static function ProcessEntrypointEnding(entrypoint:ResolvedEntrypoint, prefs:UserPreferences, host:ModuleSpecifierGenerationHost,
			options:CompilerOptions, importingSourceFile:SourceFileForSpecifierGeneration,
			allowedEndings:Slice<ModuleSpecifierEnding>):ModuleSpecifier {
		// PORT: ResolvedEntrypoint.ModuleSpecifier is still a String in the resolver.
		var specifier = entrypoint.ModuleSpecifier;
		if (entrypoint.Ending == EndingFixed) {
			return Tspath.ToModuleSpecifier(entrypoint.ModuleSpecifier);
		}

		if (Core.len(allowedEndings) == 0) {
			allowedEndings = GetAllowedEndingsInPreferredOrder(prefs, host, options, importingSourceFile, "",
				host.GetDefaultResolutionModeForFile(importingSourceFile));
		}

		final preferredEnding = allowedEndings[0];

		// Handle declaration file extensions
		final dtsExtension = Tspath.GetDeclarationFileExtension(specifier);
		if (dtsExtension != "") {
			switch (preferredEnding) {
				case ModuleSpecifierEndingTsExtension, ModuleSpecifierEndingJsExtension:
					// Map .d.ts -> .js, .d.mts -> .mjs, .d.cts -> .cjs
					final jsExtension = GetJSExtensionForDeclarationFileExtension(dtsExtension);
					return Tspath.ToModuleSpecifier(Tspath.ChangeAnyExtension(specifier, jsExtension, [dtsExtension], Tspath.CaseSensitive));
				case ModuleSpecifierEndingMinimal, ModuleSpecifierEndingIndex:
					if (entrypoint.Ending == EndingChangeable) {
						// .d.mts/.d.cts must keep an extension; rewrite to .mjs/.cjs instead of dropping
						if (dtsExtension == Tspath.ExtensionDts) {
							specifier = Tspath.RemoveExtension(specifier, dtsExtension);
							if (preferredEnding == ModuleSpecifierEndingMinimal) {
								specifier = trimSuffix(specifier, "/index");
							}
							return Tspath.ToModuleSpecifier(specifier);
						}
						final jsExtension = GetJSExtensionForDeclarationFileExtension(dtsExtension);
						return Tspath.ToModuleSpecifier(Tspath.ChangeAnyExtension(specifier, jsExtension, [dtsExtension], Tspath.CaseSensitive));
					}
					// EndingExtensionChangeable - can only change extension, not remove it
					final jsExtension = GetJSExtensionForDeclarationFileExtension(dtsExtension);
					return Tspath.ToModuleSpecifier(Tspath.ChangeAnyExtension(specifier, jsExtension, [dtsExtension], Tspath.CaseSensitive));
				default:
			}
			return Tspath.ToModuleSpecifier(specifier);
		}

		// Handle .ts/.tsx/.mts/.cts extensions
		if (Tspath.FileExtensionIsOneOf(specifier, [Tspath.ExtensionTs, Tspath.ExtensionTsx, Tspath.ExtensionMts, Tspath.ExtensionCts])) {
			switch (preferredEnding) {
				case ModuleSpecifierEndingTsExtension:
					return Tspath.ToModuleSpecifier(specifier);
				case ModuleSpecifierEndingJsExtension:
					final jsExtension = Module.TryGetJSExtensionForFile(specifier, options);
					if (jsExtension != "") {
						return Tspath.ToModuleSpecifier(Tspath.RemoveFileExtension(specifier) + jsExtension);
					}
					return Tspath.ToModuleSpecifier(specifier);
				case ModuleSpecifierEndingMinimal, ModuleSpecifierEndingIndex:
					if (entrypoint.Ending == EndingChangeable) {
						specifier = Tspath.RemoveFileExtension(specifier);
						if (preferredEnding == ModuleSpecifierEndingMinimal) {
							specifier = trimSuffix(specifier, "/index");
						}
						return Tspath.ToModuleSpecifier(specifier);
					}
					// EndingExtensionChangeable - can only change extension, not remove it
					final jsExtension = Module.TryGetJSExtensionForFile(specifier, options);
					if (jsExtension != "") {
						return Tspath.ToModuleSpecifier(Tspath.RemoveFileExtension(specifier) + jsExtension);
					}
					return Tspath.ToModuleSpecifier(specifier);
				default:
			}
			return Tspath.ToModuleSpecifier(specifier);
		}

		// Handle .js/.jsx/.mjs/.cjs extensions
		if (Tspath.FileExtensionIsOneOf(specifier, [Tspath.ExtensionJs, Tspath.ExtensionJsx, Tspath.ExtensionMjs, Tspath.ExtensionCjs])) {
			switch (preferredEnding) {
				case ModuleSpecifierEndingTsExtension, ModuleSpecifierEndingJsExtension:
					return Tspath.ToModuleSpecifier(specifier);
				case ModuleSpecifierEndingMinimal, ModuleSpecifierEndingIndex:
					if (entrypoint.Ending == EndingChangeable) {
						specifier = Tspath.RemoveFileExtension(specifier);
						if (preferredEnding == ModuleSpecifierEndingMinimal) {
							specifier = trimSuffix(specifier, "/index");
						}
						return Tspath.ToModuleSpecifier(specifier);
					}
					// EndingExtensionChangeable - keep the extension
					return Tspath.ToModuleSpecifier(specifier);
				default:
			}
			return Tspath.ToModuleSpecifier(specifier);
		}

		// For other extensions (like .json), return as-is
		return Tspath.ToModuleSpecifier(specifier);
	}
}

private class AmbientModuleInfo {
	public final name:ModuleSpecifier;
	public final symbol:Symbol;

	public function new(name:ModuleSpecifier, symbol:Symbol) {
		this.name = name;
		this.symbol = symbol;
	}
}
