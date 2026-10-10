package ts.core;

// Port of compileroptions.go (types and methods; package-level vars and funcs are in Core.hx),
// modulekind_stringer_generated.go and scripttarget_stringer_generated.go.

// Keep in sync with the API's compilerOptions.ts
// PORT: Go struct tags (`json:"name,omitzero"`) are kept as comments; no JSON (un)marshaling in core.
// PORT: `_ noCopy` is a `go vet` marker only; omitted (and so is type noCopy).
// PORT: Go `*int` option fields → Null<Int> (null = Go nil; the pointer is never written through).
class CompilerOptions {


	public var AllowJs:Tristate = TSUnknown; // json:"allowJs,omitzero"
	public var AllowArbitraryExtensions:Tristate = TSUnknown; // json:"allowArbitraryExtensions,omitzero"
	public var AllowImportingTsExtensions:Tristate = TSUnknown; // json:"allowImportingTsExtensions,omitzero"
	public var AllowNonTsExtensions:Tristate = TSUnknown; // json:"allowNonTsExtensions,omitzero"
	public var AllowUmdGlobalAccess:Tristate = TSUnknown; // json:"allowUmdGlobalAccess,omitzero"
	public var AllowUnreachableCode:Tristate = TSUnknown; // json:"allowUnreachableCode,omitzero"
	public var AllowUnusedLabels:Tristate = TSUnknown; // json:"allowUnusedLabels,omitzero"
	public var AssumeChangesOnlyAffectDirectDependencies:Tristate = TSUnknown; // json:"assumeChangesOnlyAffectDirectDependencies,omitzero"
	public var CheckJs:Tristate = TSUnknown; // json:"checkJs,omitzero"
	public var CustomConditions:Null<Array<String>> = null; // json:"customConditions,omitzero"
	public var Composite:Tristate = TSUnknown; // json:"composite,omitzero"
	public var EmitDeclarationOnly:Tristate = TSUnknown; // json:"emitDeclarationOnly,omitzero"
	public var EmitBOM:Tristate = TSUnknown; // json:"emitBOM,omitzero"
	public var EmitDecoratorMetadata:Tristate = TSUnknown; // json:"emitDecoratorMetadata,omitzero"
	public var Declaration:Tristate = TSUnknown; // json:"declaration,omitzero"
	public var DeclarationDir:String = ""; // json:"declarationDir,omitzero"
	public var DeclarationMap:Tristate = TSUnknown; // json:"declarationMap,omitzero"
	public var DeduplicatePackages:Tristate = TSUnknown; // json:"deduplicatePackages,omitzero"
	public var DisableSizeLimit:Tristate = TSUnknown; // json:"disableSizeLimit,omitzero"
	public var DisableSourceOfProjectReferenceRedirect:Tristate = TSUnknown; // json:"disableSourceOfProjectReferenceRedirect,omitzero"
	public var DisableSolutionSearching:Tristate = TSUnknown; // json:"disableSolutionSearching,omitzero"
	public var DisableReferencedProjectLoad:Tristate = TSUnknown; // json:"disableReferencedProjectLoad,omitzero"
	public var ErasableSyntaxOnly:Tristate = TSUnknown; // json:"erasableSyntaxOnly,omitzero"
	public var ExactOptionalPropertyTypes:Tristate = TSUnknown; // json:"exactOptionalPropertyTypes,omitzero"
	public var ExperimentalDecorators:Tristate = TSUnknown; // json:"experimentalDecorators,omitzero"
	public var ForceConsistentCasingInFileNames:Tristate = TSUnknown; // json:"forceConsistentCasingInFileNames,omitzero"
	public var IsolatedModules:Tristate = TSUnknown; // json:"isolatedModules,omitzero"
	public var IsolatedDeclarations:Tristate = TSUnknown; // json:"isolatedDeclarations,omitzero"
	public var IgnoreConfig:Tristate = TSUnknown; // json:"ignoreConfig,omitzero"
	public var IgnoreDeprecations:String = ""; // json:"ignoreDeprecations,omitzero"
	public var ImportHelpers:Tristate = TSUnknown; // json:"importHelpers,omitzero"
	public var InlineSourceMap:Tristate = TSUnknown; // json:"inlineSourceMap,omitzero"
	public var InlineSources:Tristate = TSUnknown; // json:"inlineSources,omitzero"
	public var Init:Tristate = TSUnknown; // json:"init,omitzero"
	public var Incremental:Tristate = TSUnknown; // json:"incremental,omitzero"
	public var Jsx:JsxEmit = JsxEmitNone; // json:"jsx,omitzero"
	public var JsxFactory:String = ""; // json:"jsxFactory,omitzero"
	public var JsxFragmentFactory:String = ""; // json:"jsxFragmentFactory,omitzero"
	public var JsxImportSource:String = ""; // json:"jsxImportSource,omitzero"
	public var Lib:Null<Array<String>> = null; // json:"lib,omitzero"
	public var LibReplacement:Tristate = TSUnknown; // json:"libReplacement,omitzero"
	public var Locale:String = ""; // json:"locale,omitzero"
	public var MapRoot:String = ""; // json:"mapRoot,omitzero"
	public var Module:ModuleKind = ModuleKindNone; // json:"module,omitzero"
	public var ModuleResolution:ModuleResolutionKind = ModuleResolutionKindUnknown; // json:"moduleResolution,omitzero"
	public var ModuleSuffixes:Null<Array<String>> = null; // json:"moduleSuffixes,omitzero"
	public var ModuleDetection:ModuleDetectionKind = ModuleDetectionKindNone; // json:"moduleDetection,omitzero"
	public var NewLine:NewLineKind = NewLineKindNone; // json:"newLine,omitzero"
	public var NoEmit:Tristate = TSUnknown; // json:"noEmit,omitzero"
	public var NoCheck:Tristate = TSUnknown; // json:"noCheck,omitzero"
	public var NoErrorTruncation:Tristate = TSUnknown; // json:"noErrorTruncation,omitzero"
	public var NoFallthroughCasesInSwitch:Tristate = TSUnknown; // json:"noFallthroughCasesInSwitch,omitzero"
	public var NoImplicitAny:Tristate = TSUnknown; // json:"noImplicitAny,omitzero"
	public var NoImplicitThis:Tristate = TSUnknown; // json:"noImplicitThis,omitzero"
	public var NoImplicitReturns:Tristate = TSUnknown; // json:"noImplicitReturns,omitzero"
	public var NoEmitHelpers:Tristate = TSUnknown; // json:"noEmitHelpers,omitzero"
	public var NoLib:Tristate = TSUnknown; // json:"noLib,omitzero"
	public var NoPropertyAccessFromIndexSignature:Tristate = TSUnknown; // json:"noPropertyAccessFromIndexSignature,omitzero"
	public var NoUncheckedIndexedAccess:Tristate = TSUnknown; // json:"noUncheckedIndexedAccess,omitzero"
	public var NoEmitOnError:Tristate = TSUnknown; // json:"noEmitOnError,omitzero"
	public var NoUnusedLocals:Tristate = TSUnknown; // json:"noUnusedLocals,omitzero"
	public var NoUnusedParameters:Tristate = TSUnknown; // json:"noUnusedParameters,omitzero"
	public var NoResolve:Tristate = TSUnknown; // json:"noResolve,omitzero"
	public var NoImplicitOverride:Tristate = TSUnknown; // json:"noImplicitOverride,omitzero"
	public var NoUncheckedSideEffectImports:Tristate = TSUnknown; // json:"noUncheckedSideEffectImports,omitzero"
	public var OutDir:String = ""; // json:"outDir,omitzero"
	public var Paths:Null<OrderedMap<String, Array<String>>> = null; // json:"paths,omitzero"
	public var PreserveConstEnums:Tristate = TSUnknown; // json:"preserveConstEnums,omitzero"
	public var PreserveSymlinks:Tristate = TSUnknown; // json:"preserveSymlinks,omitzero"
	public var Project:String = ""; // json:"project,omitzero"
	public var ResolveJsonModule:Tristate = TSUnknown; // json:"resolveJsonModule,omitzero"
	public var ResolvePackageJsonExports:Tristate = TSUnknown; // json:"resolvePackageJsonExports,omitzero"
	public var ResolvePackageJsonImports:Tristate = TSUnknown; // json:"resolvePackageJsonImports,omitzero"
	public var RemoveComments:Tristate = TSUnknown; // json:"removeComments,omitzero"
	public var RewriteRelativeImportExtensions:Tristate = TSUnknown; // json:"rewriteRelativeImportExtensions,omitzero"
	public var ReactNamespace:String = ""; // json:"reactNamespace,omitzero"
	public var RootDir:String = ""; // json:"rootDir,omitzero"
	public var RootDirs:Null<Array<String>> = null; // json:"rootDirs,omitzero"
	public var SkipLibCheck:Tristate = TSUnknown; // json:"skipLibCheck,omitzero"
	public var StableTypeOrdering:Tristate = TSUnknown; // json:"stableTypeOrdering,omitzero"
	public var Strict:Tristate = TSUnknown; // json:"strict,omitzero"
	public var StrictBindCallApply:Tristate = TSUnknown; // json:"strictBindCallApply,omitzero"
	public var StrictBuiltinIteratorReturn:Tristate = TSUnknown; // json:"strictBuiltinIteratorReturn,omitzero"
	public var StrictFunctionTypes:Tristate = TSUnknown; // json:"strictFunctionTypes,omitzero"
	public var StrictNullChecks:Tristate = TSUnknown; // json:"strictNullChecks,omitzero"
	public var StrictPropertyInitialization:Tristate = TSUnknown; // json:"strictPropertyInitialization,omitzero"
	public var StripInternal:Tristate = TSUnknown; // json:"stripInternal,omitzero"
	public var SkipDefaultLibCheck:Tristate = TSUnknown; // json:"skipDefaultLibCheck,omitzero"
	public var SourceMap:Tristate = TSUnknown; // json:"sourceMap,omitzero"
	public var SourceRoot:String = ""; // json:"sourceRoot,omitzero"
	public var SuppressOutputPathCheck:Tristate = TSUnknown; // json:"suppressOutputPathCheck,omitzero"
	public var Target:ScriptTarget = ScriptTargetNone; // json:"target,omitzero"
	public var TraceResolution:Tristate = TSUnknown; // json:"traceResolution,omitzero"
	public var TsBuildInfoFile:String = ""; // json:"tsBuildInfoFile,omitzero"
	public var TypeRoots:Null<Array<String>> = null; // json:"typeRoots,omitzero"
	public var Types:Null<Array<String>> = null; // json:"types,omitzero"
	public var UseDefineForClassFields:Tristate = TSUnknown; // json:"useDefineForClassFields,omitzero"
	public var UseUnknownInCatchVariables:Tristate = TSUnknown; // json:"useUnknownInCatchVariables,omitzero"
	public var VerbatimModuleSyntax:Tristate = TSUnknown; // json:"verbatimModuleSyntax,omitzero"
	public var MaxNodeModuleJsDepth:Null<Int> = null; // json:"maxNodeModuleJsDepth,omitzero"

	// Deprecated: Do not use outside of options parsing and validation.
	public var AllowSyntheticDefaultImports:Tristate = TSUnknown; // json:"allowSyntheticDefaultImports,omitzero"
	// Deprecated: Do not use outside of options parsing and validation.
	public var AlwaysStrict:Tristate = TSUnknown; // json:"alwaysStrict,omitzero"
	// Deprecated: Do not use outside of options parsing and validation.
	public var BaseUrl:String = ""; // json:"baseUrl,omitzero"
	// Deprecated: Do not use outside of options parsing and validation.
	public var DownlevelIteration:Tristate = TSUnknown; // json:"downlevelIteration,omitzero"
	// Deprecated: Do not use outside of options parsing and validation.
	public var ESModuleInterop:Tristate = TSUnknown; // json:"esModuleInterop,omitzero"
	// Deprecated: Do not use outside of options parsing and validation.
	public var OutFile:String = ""; // json:"outFile,omitzero"

	// Internal fields
	public var ConfigFilePath:String = ""; // json:"configFilePath,omitzero"
	public var NoDtsResolution:Tristate = TSUnknown; // json:"noDtsResolution,omitzero"
	public var PathsBasePath:String = ""; // json:"pathsBasePath,omitzero"
	public var Diagnostics:Tristate = TSUnknown; // json:"diagnostics,omitzero"
	public var ExtendedDiagnostics:Tristate = TSUnknown; // json:"extendedDiagnostics,omitzero"
	public var GenerateCpuProfile:String = ""; // json:"generateCpuProfile,omitzero"
	public var GenerateTrace:String = ""; // json:"generateTrace,omitzero"
	public var ListEmittedFiles:Tristate = TSUnknown; // json:"listEmittedFiles,omitzero"
	public var ListFiles:Tristate = TSUnknown; // json:"listFiles,omitzero"
	public var ExplainFiles:Tristate = TSUnknown; // json:"explainFiles,omitzero"
	public var ListFilesOnly:Tristate = TSUnknown; // json:"listFilesOnly,omitzero"
	public var NoEmitForJsFiles:Tristate = TSUnknown; // json:"noEmitForJsFiles,omitzero"
	public var PreserveWatchOutput:Tristate = TSUnknown; // json:"preserveWatchOutput,omitzero"
	public var Pretty:Tristate = TSUnknown; // json:"pretty,omitzero"
	public var Version:Tristate = TSUnknown; // json:"version,omitzero"
	public var Watch:Tristate = TSUnknown; // json:"watch,omitzero"
	public var ShowConfig:Tristate = TSUnknown; // json:"showConfig,omitzero"
	public var Build:Tristate = TSUnknown; // json:"build,omitzero"
	public var Help:Tristate = TSUnknown; // json:"help,omitzero"
	public var All:Tristate = TSUnknown; // json:"all,omitzero"

	public var PprofDir:String = ""; // json:"pprofDir,omitzero"
	public var SingleThreaded:Tristate = TSUnknown; // json:"singleThreaded,omitzero"
	public var Quiet:Tristate = TSUnknown; // json:"quiet,omitzero"
	public var Checkers:Null<Int> = null; // json:"checkers,omitzero"

	public function new() {}

	// Clone creates a shallow copy of the CompilerOptions.
	// PORT: Go copies every exported field with reflection; here every field is copied explicitly.
	public function Clone():CompilerOptions {
		// TODO: this could be generated code instead of reflection.
		final target = new CompilerOptions();

		target.AllowJs = this.AllowJs;
		target.AllowArbitraryExtensions = this.AllowArbitraryExtensions;
		target.AllowImportingTsExtensions = this.AllowImportingTsExtensions;
		target.AllowNonTsExtensions = this.AllowNonTsExtensions;
		target.AllowUmdGlobalAccess = this.AllowUmdGlobalAccess;
		target.AllowUnreachableCode = this.AllowUnreachableCode;
		target.AllowUnusedLabels = this.AllowUnusedLabels;
		target.AssumeChangesOnlyAffectDirectDependencies = this.AssumeChangesOnlyAffectDirectDependencies;
		target.CheckJs = this.CheckJs;
		target.CustomConditions = this.CustomConditions;
		target.Composite = this.Composite;
		target.EmitDeclarationOnly = this.EmitDeclarationOnly;
		target.EmitBOM = this.EmitBOM;
		target.EmitDecoratorMetadata = this.EmitDecoratorMetadata;
		target.Declaration = this.Declaration;
		target.DeclarationDir = this.DeclarationDir;
		target.DeclarationMap = this.DeclarationMap;
		target.DeduplicatePackages = this.DeduplicatePackages;
		target.DisableSizeLimit = this.DisableSizeLimit;
		target.DisableSourceOfProjectReferenceRedirect = this.DisableSourceOfProjectReferenceRedirect;
		target.DisableSolutionSearching = this.DisableSolutionSearching;
		target.DisableReferencedProjectLoad = this.DisableReferencedProjectLoad;
		target.ErasableSyntaxOnly = this.ErasableSyntaxOnly;
		target.ExactOptionalPropertyTypes = this.ExactOptionalPropertyTypes;
		target.ExperimentalDecorators = this.ExperimentalDecorators;
		target.ForceConsistentCasingInFileNames = this.ForceConsistentCasingInFileNames;
		target.IsolatedModules = this.IsolatedModules;
		target.IsolatedDeclarations = this.IsolatedDeclarations;
		target.IgnoreConfig = this.IgnoreConfig;
		target.IgnoreDeprecations = this.IgnoreDeprecations;
		target.ImportHelpers = this.ImportHelpers;
		target.InlineSourceMap = this.InlineSourceMap;
		target.InlineSources = this.InlineSources;
		target.Init = this.Init;
		target.Incremental = this.Incremental;
		target.Jsx = this.Jsx;
		target.JsxFactory = this.JsxFactory;
		target.JsxFragmentFactory = this.JsxFragmentFactory;
		target.JsxImportSource = this.JsxImportSource;
		target.Lib = this.Lib;
		target.LibReplacement = this.LibReplacement;
		target.Locale = this.Locale;
		target.MapRoot = this.MapRoot;
		target.Module = this.Module;
		target.ModuleResolution = this.ModuleResolution;
		target.ModuleSuffixes = this.ModuleSuffixes;
		target.ModuleDetection = this.ModuleDetection;
		target.NewLine = this.NewLine;
		target.NoEmit = this.NoEmit;
		target.NoCheck = this.NoCheck;
		target.NoErrorTruncation = this.NoErrorTruncation;
		target.NoFallthroughCasesInSwitch = this.NoFallthroughCasesInSwitch;
		target.NoImplicitAny = this.NoImplicitAny;
		target.NoImplicitThis = this.NoImplicitThis;
		target.NoImplicitReturns = this.NoImplicitReturns;
		target.NoEmitHelpers = this.NoEmitHelpers;
		target.NoLib = this.NoLib;
		target.NoPropertyAccessFromIndexSignature = this.NoPropertyAccessFromIndexSignature;
		target.NoUncheckedIndexedAccess = this.NoUncheckedIndexedAccess;
		target.NoEmitOnError = this.NoEmitOnError;
		target.NoUnusedLocals = this.NoUnusedLocals;
		target.NoUnusedParameters = this.NoUnusedParameters;
		target.NoResolve = this.NoResolve;
		target.NoImplicitOverride = this.NoImplicitOverride;
		target.NoUncheckedSideEffectImports = this.NoUncheckedSideEffectImports;
		target.OutDir = this.OutDir;
		target.Paths = this.Paths;
		target.PreserveConstEnums = this.PreserveConstEnums;
		target.PreserveSymlinks = this.PreserveSymlinks;
		target.Project = this.Project;
		target.ResolveJsonModule = this.ResolveJsonModule;
		target.ResolvePackageJsonExports = this.ResolvePackageJsonExports;
		target.ResolvePackageJsonImports = this.ResolvePackageJsonImports;
		target.RemoveComments = this.RemoveComments;
		target.RewriteRelativeImportExtensions = this.RewriteRelativeImportExtensions;
		target.ReactNamespace = this.ReactNamespace;
		target.RootDir = this.RootDir;
		target.RootDirs = this.RootDirs;
		target.SkipLibCheck = this.SkipLibCheck;
		target.StableTypeOrdering = this.StableTypeOrdering;
		target.Strict = this.Strict;
		target.StrictBindCallApply = this.StrictBindCallApply;
		target.StrictBuiltinIteratorReturn = this.StrictBuiltinIteratorReturn;
		target.StrictFunctionTypes = this.StrictFunctionTypes;
		target.StrictNullChecks = this.StrictNullChecks;
		target.StrictPropertyInitialization = this.StrictPropertyInitialization;
		target.StripInternal = this.StripInternal;
		target.SkipDefaultLibCheck = this.SkipDefaultLibCheck;
		target.SourceMap = this.SourceMap;
		target.SourceRoot = this.SourceRoot;
		target.SuppressOutputPathCheck = this.SuppressOutputPathCheck;
		target.Target = this.Target;
		target.TraceResolution = this.TraceResolution;
		target.TsBuildInfoFile = this.TsBuildInfoFile;
		target.TypeRoots = this.TypeRoots;
		target.Types = this.Types;
		target.UseDefineForClassFields = this.UseDefineForClassFields;
		target.UseUnknownInCatchVariables = this.UseUnknownInCatchVariables;
		target.VerbatimModuleSyntax = this.VerbatimModuleSyntax;
		target.MaxNodeModuleJsDepth = this.MaxNodeModuleJsDepth;
		target.AllowSyntheticDefaultImports = this.AllowSyntheticDefaultImports;
		target.AlwaysStrict = this.AlwaysStrict;
		target.BaseUrl = this.BaseUrl;
		target.DownlevelIteration = this.DownlevelIteration;
		target.ESModuleInterop = this.ESModuleInterop;
		target.OutFile = this.OutFile;
		target.ConfigFilePath = this.ConfigFilePath;
		target.NoDtsResolution = this.NoDtsResolution;
		target.PathsBasePath = this.PathsBasePath;
		target.Diagnostics = this.Diagnostics;
		target.ExtendedDiagnostics = this.ExtendedDiagnostics;
		target.GenerateCpuProfile = this.GenerateCpuProfile;
		target.GenerateTrace = this.GenerateTrace;
		target.ListEmittedFiles = this.ListEmittedFiles;
		target.ListFiles = this.ListFiles;
		target.ExplainFiles = this.ExplainFiles;
		target.ListFilesOnly = this.ListFilesOnly;
		target.NoEmitForJsFiles = this.NoEmitForJsFiles;
		target.PreserveWatchOutput = this.PreserveWatchOutput;
		target.Pretty = this.Pretty;
		target.Version = this.Version;
		target.Watch = this.Watch;
		target.ShowConfig = this.ShowConfig;
		target.Build = this.Build;
		target.Help = this.Help;
		target.All = this.All;
		target.PprofDir = this.PprofDir;
		target.SingleThreaded = this.SingleThreaded;
		target.Quiet = this.Quiet;
		target.Checkers = this.Checkers;

		return target;
	}

	public function GetEmitScriptTarget():ScriptTarget {
		if (this.Target != ScriptTargetNone) {
			return this.Target;
		}
		return ScriptTargetLatestStandard;
	}

	public function GetEmitModuleKind():ModuleKind {
		if (this.Module != ModuleKindNone) {
			return this.Module;
		}

		final target = this.GetEmitScriptTarget();
		if (target == ScriptTargetESNext) {
			return ModuleKindESNext;
		}
		if (target >= ScriptTargetES2022) {
			return ModuleKindES2022;
		}
		if (target >= ScriptTargetES2020) {
			return ModuleKindES2020;
		}
		if (target >= ScriptTargetES2015) {
			return ModuleKindES2015;
		}
		return ModuleKindCommonJS;
	}

	public function GetModuleResolutionKind():ModuleResolutionKind {
		switch (this.ModuleResolution) {
			case ModuleResolutionKindUnknown, ModuleResolutionKindClassic, ModuleResolutionKindNode10:
				switch (this.GetEmitModuleKind()) {
					case ModuleKindNode16, ModuleKindNode18, ModuleKindNode20:
						return ModuleResolutionKindNode16;
					case ModuleKindNodeNext:
						return ModuleResolutionKindNodeNext;
					default:
						return ModuleResolutionKindBundler;
				}
			default:
				return this.ModuleResolution;
		}
	}

	public function GetEmitModuleDetectionKind():ModuleDetectionKind {
		if (this.ModuleDetection != ModuleDetectionKindNone) {
			return this.ModuleDetection;
		}
		final moduleKind = this.GetEmitModuleKind();
		if (ModuleKindNode16 <= moduleKind && moduleKind <= ModuleKindNodeNext) {
			return ModuleDetectionKindForce;
		}
		return ModuleDetectionKindAuto;
	}

	public function GetResolvePackageJsonExports():Bool {
		return this.ResolvePackageJsonExports.IsTrueOrUnknown();
	}

	public function GetResolvePackageJsonImports():Bool {
		return this.ResolvePackageJsonImports.IsTrueOrUnknown();
	}

	public function GetAllowImportingTsExtensions():Bool {
		return this.AllowImportingTsExtensions.IsTrue() || this.RewriteRelativeImportExtensions.IsTrue();
	}

	public function AllowImportingTsExtensionsFrom(fileName:String):Bool {
		return this.GetAllowImportingTsExtensions() || Tspath.IsDeclarationFileName(fileName);
	}

	public function GetResolveJsonModule():Bool {
		if (this.ResolveJsonModule != TSUnknown) {
			return this.ResolveJsonModule == TSTrue;
		}
		switch (this.GetEmitModuleKind()) {
			// TODO in 6.0: add Node16/Node18
			case ModuleKindNode20, ModuleKindNodeNext:
				return true;
			default:
		}
		return this.GetModuleResolutionKind() == ModuleResolutionKindBundler;
	}

	public function ShouldPreserveConstEnums():Bool {
		return this.PreserveConstEnums == TSTrue || this.GetIsolatedModules();
	}

	public function GetAllowJS():Bool {
		if (this.AllowJs != TSUnknown) {
			return this.AllowJs == TSTrue;
		}
		return this.CheckJs == TSTrue;
	}

	public function GetJSXTransformEnabled():Bool {
		final jsx = this.Jsx;
		return jsx == JsxEmitReact || jsx == JsxEmitReactJSX || jsx == JsxEmitReactJSXDev;
	}

	public function GetStrictOptionValue(value:Tristate):Bool {
		if (value != TSUnknown) {
			return value == TSTrue;
		}
		return this.Strict != TSFalse;
	}

	// PORT: (result []string, fromConfig bool) → ValueOk (value = result, ok = fromConfig).
	public function GetEffectiveTypeRoots(currentDirectory:String):ValueOk<Null<Array<String>>> {
		if (this.TypeRoots != null) {
			return new ValueOk<Null<Array<String>>>(this.TypeRoots, true);
		}
		var baseDir:String;
		if (this.ConfigFilePath != "") {
			baseDir = Tspath.GetDirectoryPath(this.ConfigFilePath);
		} else {
			baseDir = currentDirectory;
			if (baseDir == "") {
				// This was accounted for in the TS codebase, but only for third-party API usage
				// where the module resolution host does not provide a getCurrentDirectory().
				throw "cannot get effective type roots without a config file path or current directory";
			}
		}

		final typeRoots:Array<String> = [];
		Tspath.ForEachAncestorDirectory(baseDir, function(dir:String):ValueOk<Any> {
			typeRoots.push(Tspath.CombinePaths(dir, "node_modules", "@types"));
			return new ValueOk<Any>(null, false);
		});
		return new ValueOk<Null<Array<String>>>(typeRoots, false);
	}

	// UsesWildcardTypes returns true if this option's types array includes "*"
	public function UsesWildcardTypes():Bool {
		return Slices.Contains(this.Types, "*");
	}

	public function GetIsolatedModules():Bool {
		return this.IsolatedModules == TSTrue || this.VerbatimModuleSyntax == TSTrue;
	}

	public function IsIncremental():Bool {
		return this.Incremental.IsTrue() || this.Composite.IsTrue();
	}

	public function GetEmitStandardClassFields():Bool {
		return this.UseDefineForClassFields != TSFalse && this.GetEmitScriptTarget() >= ScriptTargetES2022;
	}

	public function GetUseDefineForClassFields():Bool {
		if (this.UseDefineForClassFields == TSUnknown) {
			return this.GetEmitScriptTarget() >= ScriptTargetES2022;
		}
		return this.UseDefineForClassFields == TSTrue;
	}

	public function GetEmitDeclarations():Bool {
		return this.Declaration.IsTrue() || this.Composite.IsTrue();
	}

	public function GetAreDeclarationMapsEnabled():Bool {
		return this.DeclarationMap == TSTrue && this.GetEmitDeclarations();
	}

	public function HasJsonModuleEmitEnabled():Bool {
		switch (this.GetEmitModuleKind()) {
			case ModuleKindSystem, ModuleKindUMD:
				return false;
			default:
		}
		return true;
	}

	public function GetPathsBasePath(currentDirectory:String):String {
		if (this.Paths.Size() == 0) {
			return "";
		}
		if (this.PathsBasePath != "") {
			return this.PathsBasePath;
		}
		return currentDirectory;
	}
}

enum abstract ModuleDetectionKind(Int) from Int to Int {
	// PORT: Go integer ordering of the enum values.
	@:op(A < B) static function lt(a:ModuleDetectionKind, b:ModuleDetectionKind):Bool;
	@:op(A <= B) static function lte(a:ModuleDetectionKind, b:ModuleDetectionKind):Bool;
	@:op(A > B) static function gt(a:ModuleDetectionKind, b:ModuleDetectionKind):Bool;
	@:op(A >= B) static function gte(a:ModuleDetectionKind, b:ModuleDetectionKind):Bool;

	var ModuleDetectionKindNone = 0;
	var ModuleDetectionKindAuto = 1;
	var ModuleDetectionKindLegacy = 2;
	var ModuleDetectionKindForce = 3;
}

enum abstract ModuleKind(Int) from Int to Int {
	// PORT: Go integer ordering of the enum values.
	@:op(A < B) static function lt(a:ModuleKind, b:ModuleKind):Bool;
	@:op(A <= B) static function lte(a:ModuleKind, b:ModuleKind):Bool;
	@:op(A > B) static function gt(a:ModuleKind, b:ModuleKind):Bool;
	@:op(A >= B) static function gte(a:ModuleKind, b:ModuleKind):Bool;

	var ModuleKindNone = 0;
	var ModuleKindCommonJS = 1;
	// Deprecated: Do not use outside of options parsing and validation.
	var ModuleKindAMD = 2;
	// Deprecated: Do not use outside of options parsing and validation.
	var ModuleKindUMD = 3;
	// Deprecated: Do not use outside of options parsing and validation.
	var ModuleKindSystem = 4;
	// NOTE: ES module kinds should be contiguous to more easily check whether a module kind is *any* ES module kind.
	//       Non-ES module kinds should not come between ES2015 (the earliest ES module kind) and ESNext (the last ES
	//       module kind).
	var ModuleKindES2015 = 5;
	var ModuleKindES2020 = 6;
	var ModuleKindES2022 = 7;
	var ModuleKindESNext = 99;
	// Node16+ is an amalgam of commonjs (albeit updated) and es2022+, and represents a distinct module system from es2020/esnext
	var ModuleKindNode16 = 100;
	var ModuleKindNode18 = 101;
	var ModuleKindNode20 = 102;
	var ModuleKindNodeNext = 199;
	// Emit as written
	var ModuleKindPreserve = 200;

	public function IsNonNodeESM():Bool {
		final moduleKind:ModuleKind = cast this;
		return moduleKind >= ModuleKindES2015 && moduleKind <= ModuleKindESNext;
	}

	public function SupportsImportAttributes():Bool {
		final moduleKind:ModuleKind = cast this;
		return ModuleKindNode18 <= moduleKind && moduleKind <= ModuleKindNodeNext || moduleKind == ModuleKindPreserve || moduleKind == ModuleKindESNext;
	}

	// --- modulekind_stringer_generated.go ---

	static final _ModuleKind_name_0 = ["None", "CommonJS", "AMD", "UMD", "System", "ES2015", "ES2020", "ES2022"];
	static final _ModuleKind_name_1 = ["ESNext", "Node16", "Node18", "Node20"];
	static final _ModuleKind_name_2 = ["NodeNext", "Preserve"];

	public function String():String {
		var i:Int = this;
		if (0 <= i && i <= 7) {
			return _ModuleKind_name_0[i];
		} else if (99 <= i && i <= 102) {
			i -= 99;
			return _ModuleKind_name_1[i];
		} else if (199 <= i && i <= 200) {
			i -= 199;
			return _ModuleKind_name_2[i];
		} else {
			return "ModuleKind(" + Std.string(i) + ")";
		}
	}
}

// ResolutionMode = ModuleKind // ModuleKindNone | ModuleKindCommonJS | ModuleKindESNext
// (constants ResolutionModeNone / ResolutionModeCommonJS / ResolutionModeESM are in Core.hx)
typedef ResolutionMode = ModuleKind;

enum abstract ModuleResolutionKind(Int) from Int to Int {
	// PORT: Go integer ordering of the enum values.
	@:op(A < B) static function lt(a:ModuleResolutionKind, b:ModuleResolutionKind):Bool;
	@:op(A <= B) static function lte(a:ModuleResolutionKind, b:ModuleResolutionKind):Bool;
	@:op(A > B) static function gt(a:ModuleResolutionKind, b:ModuleResolutionKind):Bool;
	@:op(A >= B) static function gte(a:ModuleResolutionKind, b:ModuleResolutionKind):Bool;

	var ModuleResolutionKindUnknown = 0;
	// Deprecated: Do not use outside of options parsing and validation.
	var ModuleResolutionKindClassic = 1;
	// Deprecated: Do not use outside of options parsing and validation.
	var ModuleResolutionKindNode10 = 2;
	// Starting with node16, node's module resolver has significant departures from traditional cjs resolution
	// to better support ECMAScript modules and their use within node - however more features are still being added.
	// TypeScript's Node ESM support was introduced after Node 12 went end-of-life, and Node 14 is the earliest stable
	// version that supports both pattern trailers - *but*, Node 16 is the first version that also supports ECMAScript 2022.
	// In turn, we offer both a `NodeNext` moving resolution target, and a `Node16` version-anchored resolution target
	var ModuleResolutionKindNode16 = 3;
	var ModuleResolutionKindNodeNext = 99; // Not simply `Node16` so that compiled code linked against TS can use the `Next` value reliably (same as with `ModuleKind`)
	var ModuleResolutionKindBundler = 100;

	// We don't use stringer on this for now, because these values
	// are user-facing in --traceResolution, and stringer currently
	// lacks the ability to remove the "ModuleResolutionKind" prefix
	// when generating code for multiple types into the same output
	// file. Additionally, since there's no TS equivalent of
	// `ModuleResolutionKindUnknown`, we want to panic on that case,
	// as it probably represents a mistake when porting TS to Go.
	public function String():String {
		switch ((cast this : ModuleResolutionKind)) {
			case ModuleResolutionKindUnknown:
				throw "should not use zero value of ModuleResolutionKind";
			case ModuleResolutionKindClassic:
				return "Classic";
			case ModuleResolutionKindNode10:
				return "Node10";
			case ModuleResolutionKindNode16:
				return "Node16";
			case ModuleResolutionKindNodeNext:
				return "NodeNext";
			case ModuleResolutionKindBundler:
				return "Bundler";
			default:
				throw "unhandled case in ModuleResolutionKind.String";
		}
	}
}

enum abstract NewLineKind(Int) from Int to Int {
	// PORT: Go integer ordering of the enum values.
	@:op(A < B) static function lt(a:NewLineKind, b:NewLineKind):Bool;
	@:op(A <= B) static function lte(a:NewLineKind, b:NewLineKind):Bool;
	@:op(A > B) static function gt(a:NewLineKind, b:NewLineKind):Bool;
	@:op(A >= B) static function gte(a:NewLineKind, b:NewLineKind):Bool;

	var NewLineKindNone = 0;
	var NewLineKindCRLF = 1;
	var NewLineKindLF = 2;

	public function GetNewLineCharacter():String {
		switch ((cast this : NewLineKind)) {
			case NewLineKindCRLF:
				return "\r\n";
			default:
				return "\n";
		}
	}
}

enum abstract ScriptTarget(Int) from Int to Int {
	// PORT: Go integer ordering of the enum values.
	@:op(A < B) static function lt(a:ScriptTarget, b:ScriptTarget):Bool;
	@:op(A <= B) static function lte(a:ScriptTarget, b:ScriptTarget):Bool;
	@:op(A > B) static function gt(a:ScriptTarget, b:ScriptTarget):Bool;
	@:op(A >= B) static function gte(a:ScriptTarget, b:ScriptTarget):Bool;

	var ScriptTargetNone = 0;
	// Deprecated: Do not use outside of options parsing and validation.
	var ScriptTargetES5 = 1;
	var ScriptTargetES2015 = 2;
	var ScriptTargetES2016 = 3;
	var ScriptTargetES2017 = 4;
	var ScriptTargetES2018 = 5;
	var ScriptTargetES2019 = 6;
	var ScriptTargetES2020 = 7;
	var ScriptTargetES2021 = 8;
	var ScriptTargetES2022 = 9;
	var ScriptTargetES2023 = 10;
	var ScriptTargetES2024 = 11;
	var ScriptTargetES2025 = 12;
	var ScriptTargetESNext = 99;
	var ScriptTargetJSON = 100;
	var ScriptTargetLatest = 99; // ScriptTargetESNext
	var ScriptTargetLatestStandard = 12; // ScriptTargetES2025

	// --- scripttarget_stringer_generated.go ---

	static final _ScriptTarget_name_0 = [
		"None", "ES5", "ES2015", "ES2016", "ES2017", "ES2018", "ES2019", "ES2020", "ES2021", "ES2022", "ES2023", "ES2024", "ES2025"
	];
	static final _ScriptTarget_name_1 = ["ESNext", "JSON"];

	public function String():String {
		var i:Int = this;
		if (0 <= i && i <= 12) {
			return _ScriptTarget_name_0[i];
		} else if (99 <= i && i <= 100) {
			i -= 99;
			return _ScriptTarget_name_1[i];
		} else {
			return "ScriptTarget(" + Std.string(i) + ")";
		}
	}
}

enum abstract JsxEmit(Int) from Int to Int {
	// PORT: Go integer ordering of the enum values.
	@:op(A < B) static function lt(a:JsxEmit, b:JsxEmit):Bool;
	@:op(A <= B) static function lte(a:JsxEmit, b:JsxEmit):Bool;
	@:op(A > B) static function gt(a:JsxEmit, b:JsxEmit):Bool;
	@:op(A >= B) static function gte(a:JsxEmit, b:JsxEmit):Bool;

	var JsxEmitNone = 0;
	var JsxEmitPreserve = 1;
	var JsxEmitReactNative = 2;
	var JsxEmitReact = 3;
	var JsxEmitReactJSX = 4;
	var JsxEmitReactJSXDev = 5;

	public function String():String {
		switch ((cast this : JsxEmit)) {
			case JsxEmitNone:
				throw "should not use zero value of JsxEmit";
			case JsxEmitPreserve:
				return "preserve";
			case JsxEmitReactNative:
				return "react-native";
			case JsxEmitReact:
				return "react";
			case JsxEmitReactJSX:
				return "react-jsx";
			case JsxEmitReactJSXDev:
				return "react-jsxdev";
			default:
				throw "unhandled case in JsxEmit.String";
		}
	}
}
