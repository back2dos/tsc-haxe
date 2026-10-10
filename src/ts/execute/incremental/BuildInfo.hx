package ts.execute.incremental;

// Port of buildInfo.go (types and methods). Package-level funcs are in Incremental.hx.
//
// PORT: JSON. Go marshals these types with json tags (`omitzero`) and custom MarshalJSON /
// UnmarshalJSON methods. Here every type implements ts.json.Json.OrderedMarshaler
// (MarshalJSONValue returns the ordered value tree that Json.MarshalOrdered writes exactly like
// Go), and UnmarshalJSON becomes a static `fromJSONValue(v)` over the tree returned by
// Json.UnmarshalOrdered (objects are OrderedMaps, numbers Floats); it throws a String where Go
// returns an error.

// Go `type BuildInfoFileId int`, `type BuildInfoFileIdListId int`.
typedef BuildInfoFileId = Int;
typedef BuildInfoFileIdListId = Int;

// PORT: helpers that decode Go struct fields from the Json.UnmarshalOrdered tree (json v2 rules:
// JSON null leaves the zero value, a type mismatch is an error, unknown members are ignored).
@:allow(ts.execute.incremental)
class JsonDecode {
	static function object(v:Dynamic, what:std.String):OrderedMap<std.String, Dynamic> {
		if (v == null)
			return null;
		if (!Std.isOfType(v, OrderedMap))
			throw "json: cannot unmarshal into " + what;
		return v;
	}

	static function field(o:OrderedMap<std.String, Dynamic>, name:std.String):Dynamic {
		if (o == null)
			return null;
		return o.GetOrZero(name);
	}

	static function isNumber(v:Dynamic):Bool {
		return !Std.isOfType(v, Bool) && (Std.isOfType(v, Float) || Std.isOfType(v, Int));
	}

	// Go int (also int32 and the int enums): a JSON number without fraction.
	static function int(v:Dynamic):Int {
		if (v == null)
			return 0;
		if (!isNumber(v))
			throw "json: cannot unmarshal into Go int";
		final f:Float = v;
		if (f != std.Math.ffloor(f) || f > 2147483647.0 || f < -2147483648.0)
			throw "json: cannot unmarshal number into Go int";
		return Std.int(f);
	}

	static function string(v:Dynamic):std.String {
		if (v == null)
			return "";
		if (!Std.isOfType(v, std.String))
			throw "json: cannot unmarshal into Go string";
		return v;
	}

	static function bool(v:Dynamic):Bool {
		if (v == null)
			return false;
		if (!Std.isOfType(v, Bool))
			throw "json: cannot unmarshal into Go bool";
		return v;
	}

	static function array(v:Dynamic):Array<Dynamic> {
		if (v == null)
			return null;
		if (!Std.isOfType(v, Array))
			throw "json: cannot unmarshal into Go slice";
		return v;
	}

	static function strings(v:Dynamic):Array<std.String> {
		final a = array(v);
		if (a == null)
			return null;
		return [for (x in a) string(x)];
	}

	static function ints(v:Dynamic):Array<Int> {
		final a = array(v);
		if (a == null)
			return null;
		return [for (x in a) int(x)];
	}

	static function slice<T>(v:Dynamic, f:(Dynamic) -> T):Array<T> {
		final a = array(v);
		if (a == null)
			return null;
		return [for (x in a) x == null ? null : f(x)];
	}
}

// buildInfoRoot is
// - for incremental program buildinfo
//   - start and end of FileId for consecutive fileIds to be included as root
//   - start - single fileId that is root
//
// - for non incremental program buildinfo
//   - string that is the root file name
@:allow(ts.execute.incremental)
class BuildInfoRoot implements OrderedMarshaler {
	public var Start:BuildInfoFileId = 0;
	public var End:BuildInfoFileId = 0;
	public var NonIncremental:std.String = ""; // Root of a non incremental program

	public function new(Start:BuildInfoFileId = 0, End:BuildInfoFileId = 0, NonIncremental:std.String = "") {
		this.Start = Start;
		this.End = End;
		this.NonIncremental = NonIncremental;
	}

	public function MarshalJSONValue():Dynamic {
		if (this.Start != 0) {
			if (this.End != 0) {
				return [this.Start, this.End];
			} else {
				return this.Start;
			}
		} else {
			return this.NonIncremental;
		}
	}

	public static function fromJSONValue(data:Dynamic):BuildInfoRoot {
		// [2]int, else int, else string
		if (Std.isOfType(data, Array)) {
			final a:Array<Dynamic> = data;
			if (a.length != 2)
				throw "invalid BuildInfoRoot";
			return new BuildInfoRoot(JsonDecode.int(a[0]), JsonDecode.int(a[1]));
		}
		if (JsonDecode.isNumber(data)) {
			return new BuildInfoRoot(JsonDecode.int(data));
		}
		if (Std.isOfType(data, std.String)) {
			return new BuildInfoRoot(0, 0, data);
		}
		throw "invalid BuildInfoRoot";
	}
}

// Go type buildInfoFileInfoNoSignature.
@:allow(ts.execute.incremental)
class BuildInfoFileInfoNoSignature implements OrderedMarshaler {
	public var Version:std.String = ""; // json:"version,omitzero"
	public var NoSignature:Bool = false; // json:"noSignature,omitzero"
	public var AffectsGlobalScope:Bool = false; // json:"affectsGlobalScope,omitzero"
	public var ImpliedNodeFormat:ResolutionMode = ModuleKindNone; // json:"impliedNodeFormat,omitzero"

	public function new() {}

	public function MarshalJSONValue():Dynamic {
		final m = new OrderedMap<std.String, Dynamic>();
		if (this.Version != "")
			m.Set("version", this.Version);
		if (this.NoSignature)
			m.Set("noSignature", true);
		if (this.AffectsGlobalScope)
			m.Set("affectsGlobalScope", true);
		if ((this.ImpliedNodeFormat : Int) != 0)
			m.Set("impliedNodeFormat", (this.ImpliedNodeFormat : Int));
		return m;
	}

	static function fromJSONValue(data:Dynamic):BuildInfoFileInfoNoSignature {
		final o = JsonDecode.object(data, "buildInfoFileInfoNoSignature");
		final r = new BuildInfoFileInfoNoSignature();
		r.Version = JsonDecode.string(JsonDecode.field(o, "version"));
		r.NoSignature = JsonDecode.bool(JsonDecode.field(o, "noSignature"));
		r.AffectsGlobalScope = JsonDecode.bool(JsonDecode.field(o, "affectsGlobalScope"));
		r.ImpliedNodeFormat = JsonDecode.int(JsonDecode.field(o, "impliedNodeFormat"));
		return r;
	}
}

//	 Signature is
//		 - undefined if FileInfo.version === FileInfo.signature
//		 - string actual signature
// Go type buildInfoFileInfoWithSignature.
@:allow(ts.execute.incremental)
class BuildInfoFileInfoWithSignature implements OrderedMarshaler {
	public var Version:std.String = ""; // json:"version,omitzero"
	public var Signature:std.String = ""; // json:"signature,omitzero"
	public var AffectsGlobalScope:Bool = false; // json:"affectsGlobalScope,omitzero"
	public var ImpliedNodeFormat:ResolutionMode = ModuleKindNone; // json:"impliedNodeFormat,omitzero"

	public function new() {}

	public function MarshalJSONValue():Dynamic {
		final m = new OrderedMap<std.String, Dynamic>();
		if (this.Version != "")
			m.Set("version", this.Version);
		if (this.Signature != "")
			m.Set("signature", this.Signature);
		if (this.AffectsGlobalScope)
			m.Set("affectsGlobalScope", true);
		if ((this.ImpliedNodeFormat : Int) != 0)
			m.Set("impliedNodeFormat", (this.ImpliedNodeFormat : Int));
		return m;
	}

	static function fromJSONValue(data:Dynamic):BuildInfoFileInfoWithSignature {
		final o = JsonDecode.object(data, "buildInfoFileInfoWithSignature");
		final r = new BuildInfoFileInfoWithSignature();
		r.Version = JsonDecode.string(JsonDecode.field(o, "version"));
		r.Signature = JsonDecode.string(JsonDecode.field(o, "signature"));
		r.AffectsGlobalScope = JsonDecode.bool(JsonDecode.field(o, "affectsGlobalScope"));
		r.ImpliedNodeFormat = JsonDecode.int(JsonDecode.field(o, "impliedNodeFormat"));
		return r;
	}
}

@:allow(ts.execute.incremental)
class BuildInfoFileInfo implements OrderedMarshaler {
	var signature:std.String = "";
	var noSignature:BuildInfoFileInfoNoSignature = null;
	var fileInfo:BuildInfoFileInfoWithSignature = null;

	public function new() {}

	public function GetFileInfo():FileInfo {
		if (this == null) {
			return null;
		}
		if (this.signature != "") {
			return new FileInfo(this.signature, this.signature, false, Core.ResolutionModeCommonJS);
		}
		if (this.noSignature != null) {
			return new FileInfo(this.noSignature.Version, "", this.noSignature.AffectsGlobalScope, this.noSignature.ImpliedNodeFormat);
		}
		return new FileInfo(this.fileInfo.Version, Core.IfElse(this.fileInfo.Signature == "", this.fileInfo.Version, this.fileInfo.Signature),
			this.fileInfo.AffectsGlobalScope, this.fileInfo.ImpliedNodeFormat);
	}

	public function HasSignature():Bool {
		return this.signature != "";
	}

	public function MarshalJSONValue():Dynamic {
		if (this.signature != "") {
			return this.signature;
		}
		if (this.noSignature != null) {
			return this.noSignature;
		}
		return this.fileInfo;
	}

	public static function fromJSONValue(data:Dynamic):BuildInfoFileInfo {
		final b = new BuildInfoFileInfo();
		if (!Std.isOfType(data, std.String)) {
			var noSignature:BuildInfoFileInfoNoSignature = null;
			try {
				noSignature = BuildInfoFileInfoNoSignature.fromJSONValue(data);
			} catch (e:Dynamic) {
				noSignature = null;
			}
			if (noSignature == null || !noSignature.NoSignature) {
				var fileInfo:BuildInfoFileInfoWithSignature;
				try {
					fileInfo = BuildInfoFileInfoWithSignature.fromJSONValue(data);
				} catch (e:Dynamic) {
					throw "invalid BuildInfoFileInfo";
				}
				b.fileInfo = fileInfo;
				return b;
			}
			b.noSignature = noSignature;
			return b;
		}
		b.signature = data;
		return b;
	}
}

@:allow(ts.execute.incremental)
class BuildInfoReferenceMapEntry implements OrderedMarshaler {
	public var FileId:BuildInfoFileId = 0;
	public var FileIdListId:BuildInfoFileIdListId = 0;

	public function new(FileId:BuildInfoFileId = 0, FileIdListId:BuildInfoFileIdListId = 0) {
		this.FileId = FileId;
		this.FileIdListId = FileIdListId;
	}

	public function MarshalJSONValue():Dynamic {
		return [this.FileId, this.FileIdListId];
	}

	public static function fromJSONValue(data:Dynamic):BuildInfoReferenceMapEntry {
		final v = JsonDecode.ints(data);
		if (v == null || v.length != 2)
			throw "invalid BuildInfoReferenceMapEntry";
		return new BuildInfoReferenceMapEntry(v[0], v[1]);
	}
}

@:allow(ts.execute.incremental)
class BuildInfoDiagnostic implements OrderedMarshaler {
	// BuildInfoFileId if it is for a File thats other than its stored for
	public var File:BuildInfoFileId = 0; // json:"file,omitzero"
	public var NoFile:Bool = false; // json:"noFile,omitzero"
	public var Pos:Int = 0; // json:"pos,omitzero"
	public var End:Int = 0; // json:"end,omitzero"
	public var Code:Int = 0; // json:"code,omitzero"
	public var Category:Category = cast 0; // json:"category,omitzero"
	public var MessageKey:Key = ""; // json:"messageKey,omitzero"
	public var MessageArgs:Array<std.String> = null; // json:"messageArgs,omitzero"
	public var MessageChain:Array<BuildInfoDiagnostic> = null; // json:"messageChain,omitzero"
	public var RelatedInformation:Array<BuildInfoDiagnostic> = null; // json:"relatedInformation,omitzero"
	public var ReportsUnnecessary:Bool = false; // json:"reportsUnnecessary,omitzero"
	public var ReportsDeprecated:Bool = false; // json:"reportsDeprecated,omitzero"
	public var SkippedOnNoEmit:Bool = false; // json:"skippedOnNoEmit,omitzero"
	public var RepopulateInfo:BuildInfoRepopulateInfo = null; // json:"repopulateInfo,omitzero"

	public function new() {}

	public function MarshalJSONValue():Dynamic {
		final m = new OrderedMap<std.String, Dynamic>();
		if (this.File != 0)
			m.Set("file", this.File);
		if (this.NoFile)
			m.Set("noFile", true);
		if (this.Pos != 0)
			m.Set("pos", this.Pos);
		if (this.End != 0)
			m.Set("end", this.End);
		if (this.Code != 0)
			m.Set("code", this.Code);
		if ((cast this.Category : Int) != 0)
			m.Set("category", (cast this.Category : Int));
		if (this.MessageKey != "")
			m.Set("messageKey", this.MessageKey);
		if (this.MessageArgs != null)
			m.Set("messageArgs", this.MessageArgs);
		if (this.MessageChain != null)
			m.Set("messageChain", this.MessageChain);
		if (this.RelatedInformation != null)
			m.Set("relatedInformation", this.RelatedInformation);
		if (this.ReportsUnnecessary)
			m.Set("reportsUnnecessary", true);
		if (this.ReportsDeprecated)
			m.Set("reportsDeprecated", true);
		if (this.SkippedOnNoEmit)
			m.Set("skippedOnNoEmit", true);
		if (this.RepopulateInfo != null)
			m.Set("repopulateInfo", this.RepopulateInfo);
		return m;
	}

	public static function fromJSONValue(data:Dynamic):BuildInfoDiagnostic {
		final o = JsonDecode.object(data, "BuildInfoDiagnostic");
		final d = new BuildInfoDiagnostic();
		d.File = JsonDecode.int(JsonDecode.field(o, "file"));
		d.NoFile = JsonDecode.bool(JsonDecode.field(o, "noFile"));
		d.Pos = JsonDecode.int(JsonDecode.field(o, "pos"));
		d.End = JsonDecode.int(JsonDecode.field(o, "end"));
		d.Code = JsonDecode.int(JsonDecode.field(o, "code"));
		d.Category = cast JsonDecode.int(JsonDecode.field(o, "category"));
		d.MessageKey = JsonDecode.string(JsonDecode.field(o, "messageKey"));
		d.MessageArgs = JsonDecode.strings(JsonDecode.field(o, "messageArgs"));
		d.MessageChain = JsonDecode.slice(JsonDecode.field(o, "messageChain"), BuildInfoDiagnostic.fromJSONValue);
		d.RelatedInformation = JsonDecode.slice(JsonDecode.field(o, "relatedInformation"), BuildInfoDiagnostic.fromJSONValue);
		d.ReportsUnnecessary = JsonDecode.bool(JsonDecode.field(o, "reportsUnnecessary"));
		d.ReportsDeprecated = JsonDecode.bool(JsonDecode.field(o, "reportsDeprecated"));
		d.SkippedOnNoEmit = JsonDecode.bool(JsonDecode.field(o, "skippedOnNoEmit"));
		final ri = JsonDecode.field(o, "repopulateInfo");
		d.RepopulateInfo = ri == null ? null : BuildInfoRepopulateInfo.fromJSONValue(ri);
		return d;
	}
}

@:allow(ts.execute.incremental)
class BuildInfoRepopulateInfo implements OrderedMarshaler {
	public var Kind:RepopulateDiagnosticKind = 0; // json:"kind"
	public var ModuleReference:std.String = ""; // json:"moduleReference,omitzero"
	public var Mode:ResolutionMode = ModuleKindNone; // json:"mode,omitzero"
	public var PackageName:std.String = ""; // json:"packageName,omitzero"

	public function new() {}

	public function MarshalJSONValue():Dynamic {
		final m = new OrderedMap<std.String, Dynamic>();
		m.Set("kind", (this.Kind : Int));
		if (this.ModuleReference != "")
			m.Set("moduleReference", this.ModuleReference);
		if ((this.Mode : Int) != 0)
			m.Set("mode", (this.Mode : Int));
		if (this.PackageName != "")
			m.Set("packageName", this.PackageName);
		return m;
	}

	public static function fromJSONValue(data:Dynamic):BuildInfoRepopulateInfo {
		final o = JsonDecode.object(data, "BuildInfoRepopulateInfo");
		final r = new BuildInfoRepopulateInfo();
		r.Kind = JsonDecode.int(JsonDecode.field(o, "kind"));
		r.ModuleReference = JsonDecode.string(JsonDecode.field(o, "moduleReference"));
		r.Mode = JsonDecode.int(JsonDecode.field(o, "mode"));
		r.PackageName = JsonDecode.string(JsonDecode.field(o, "packageName"));
		return r;
	}
}

@:allow(ts.execute.incremental)
class BuildInfoDiagnosticsOfFile implements OrderedMarshaler {
	public var FileId:BuildInfoFileId = 0;
	public var Diagnostics:Array<BuildInfoDiagnostic> = null;

	public function new(FileId:BuildInfoFileId = 0, ?Diagnostics:Array<BuildInfoDiagnostic>) {
		this.FileId = FileId;
		this.Diagnostics = Diagnostics;
	}

	public function MarshalJSONValue():Dynamic {
		final fileIdAndDiagnostics:Array<Dynamic> = [];
		fileIdAndDiagnostics.push(this.FileId);
		// PORT: Go json v2 marshals a nil slice as [].
		fileIdAndDiagnostics.push(this.Diagnostics == null ? [] : this.Diagnostics);
		return fileIdAndDiagnostics;
	}

	public static function fromJSONValue(data:Dynamic):BuildInfoDiagnosticsOfFile {
		if (!Std.isOfType(data, Array))
			throw "invalid BuildInfoDiagnosticsOfFile";
		final fileIdAndDiagnostics:Array<Dynamic> = data;
		if (fileIdAndDiagnostics.length != 2) {
			throw "invalid BuildInfoDiagnosticsOfFile: expected 2 elements, got " + fileIdAndDiagnostics.length;
		}
		final fileId = JsonDecode.int(fileIdAndDiagnostics[0]);
		final diagnostics = JsonDecode.slice(fileIdAndDiagnostics[1], BuildInfoDiagnostic.fromJSONValue);
		return new BuildInfoDiagnosticsOfFile(fileId, diagnostics);
	}
}

@:allow(ts.execute.incremental)
class BuildInfoSemanticDiagnostic implements OrderedMarshaler {
	public var FileId:BuildInfoFileId = 0; // File is not in changedSet and still doesnt have cached diagnostics
	public var Diagnostics:BuildInfoDiagnosticsOfFile = null; // Diagnostics for file

	public function new(FileId:BuildInfoFileId = 0, ?Diagnostics:BuildInfoDiagnosticsOfFile) {
		this.FileId = FileId;
		this.Diagnostics = Diagnostics;
	}

	public function MarshalJSONValue():Dynamic {
		if (this.FileId != 0) {
			return this.FileId;
		}
		return this.Diagnostics;
	}

	public static function fromJSONValue(data:Dynamic):BuildInfoSemanticDiagnostic {
		if (!JsonDecode.isNumber(data)) {
			var diagnostics:BuildInfoDiagnosticsOfFile;
			try {
				diagnostics = BuildInfoDiagnosticsOfFile.fromJSONValue(data);
			} catch (e:Dynamic) {
				throw "invalid BuildInfoSemanticDiagnostic";
			}
			return new BuildInfoSemanticDiagnostic(0, diagnostics);
		}
		return new BuildInfoSemanticDiagnostic(JsonDecode.int(data));
	}
}

// fileId if pending emit is same as what compilerOptions suggest
// [fileId] if pending emit is only dts file emit
// [fileId, emitKind] if any other type emit is pending
@:allow(ts.execute.incremental)
class BuildInfoFilePendingEmit implements OrderedMarshaler {
	public var FileId:BuildInfoFileId = 0;
	public var EmitKind:FileEmitKind = FileEmitKindNone;

	public function new(FileId:BuildInfoFileId = 0, EmitKind:FileEmitKind = FileEmitKindNone) {
		this.FileId = FileId;
		this.EmitKind = EmitKind;
	}

	public function MarshalJSONValue():Dynamic {
		if (this.EmitKind == 0) {
			return this.FileId;
		}
		if (this.EmitKind == FileEmitKindDts) {
			final fileListIds:Array<BuildInfoFileId> = [this.FileId];
			return fileListIds;
		}
		final fileAndEmitKind:Array<Int> = [this.FileId, (this.EmitKind : Int)];
		return fileAndEmitKind;
	}

	public static function fromJSONValue(data:Dynamic):BuildInfoFilePendingEmit {
		if (!JsonDecode.isNumber(data)) {
			var intTuple:Array<Int> = null;
			try {
				intTuple = JsonDecode.ints(data);
			} catch (e:Dynamic) {
				intTuple = null;
			}
			if (intTuple == null || intTuple.length == 0) {
				throw "invalid BuildInfoFilePendingEmit";
			}
			switch (intTuple.length) {
				case 1:
					return new BuildInfoFilePendingEmit(intTuple[0], FileEmitKindDts);
				case 2:
					return new BuildInfoFilePendingEmit(intTuple[0], intTuple[1]);
				default:
					throw "invalid BuildInfoFilePendingEmit: expected 1 or 2 integers, got " + intTuple.length;
			}
		}
		return new BuildInfoFilePendingEmit(JsonDecode.int(data));
	}
}

// [fileId, signature] if different from file's signature
// fileId if file wasnt emitted
@:allow(ts.execute.incremental)
class BuildInfoEmitSignature implements OrderedMarshaler {
	public var FileId:BuildInfoFileId = 0;
	public var Signature:std.String = ""; // Signature if it is different from file's Signature
	public var DiffersOnlyInDtsMap:Bool = false; // true if signature is different only in dtsMap value
	public var DiffersInOptions:Bool = false; // true if signature is different in options used to emit file

	public function new(FileId:BuildInfoFileId = 0, Signature:std.String = "", DiffersOnlyInDtsMap:Bool = false, DiffersInOptions:Bool = false) {
		this.FileId = FileId;
		this.Signature = Signature;
		this.DiffersOnlyInDtsMap = DiffersOnlyInDtsMap;
		this.DiffersInOptions = DiffersInOptions;
	}

	function noEmitSignature():Bool {
		return this.Signature == "" && !this.DiffersOnlyInDtsMap && !this.DiffersInOptions;
	}

	function toEmitSignature(path:Path, emitSignatures:SyncMap<Path, EmitSignature>):EmitSignature {
		var signature = "";
		var signatureWithDifferentOptions:Array<std.String> = null;
		if (this.DiffersOnlyInDtsMap) {
			signatureWithDifferentOptions = [];
			final info = emitSignatures.Load(path).value;
			signatureWithDifferentOptions.push(info.signature);
		} else if (this.DiffersInOptions) {
			signatureWithDifferentOptions = [];
			signatureWithDifferentOptions.push(this.Signature);
		} else {
			signature = this.Signature;
		}
		return new EmitSignature(signature, signatureWithDifferentOptions);
	}

	public function MarshalJSONValue():Dynamic {
		if (this.noEmitSignature()) {
			return this.FileId;
		}
		final fileIdAndSignature:Array<Dynamic> = [null, null];
		fileIdAndSignature[0] = this.FileId;
		var signature:Dynamic;
		if (this.DiffersOnlyInDtsMap) {
			signature = ([] : Array<std.String>);
		} else if (this.DiffersInOptions) {
			signature = [this.Signature];
		} else {
			signature = this.Signature;
		}
		fileIdAndSignature[1] = signature;
		return fileIdAndSignature;
	}

	public static function fromJSONValue(data:Dynamic):BuildInfoEmitSignature {
		if (!JsonDecode.isNumber(data)) {
			if (!Std.isOfType(data, Array)) {
				throw "invalid BuildInfoEmitSignature";
			}
			final fileIdAndSignature:Array<Dynamic> = data;
			if (fileIdAndSignature.length != 2) {
				throw "invalid BuildInfoEmitSignature: expected 2 elements, got " + fileIdAndSignature.length;
			}
			var fileId:BuildInfoFileId;
			if (!JsonDecode.isNumber(fileIdAndSignature[0])) {
				throw "invalid fileId in BuildInfoEmitSignature: expected float64";
			} else {
				fileId = Std.int((fileIdAndSignature[0] : Float));
			}
			var signature = "";
			var differsOnlyInDtsMap = false, differsInOptions = false;
			if (!Std.isOfType(fileIdAndSignature[1], std.String)) {
				if (!Std.isOfType(fileIdAndSignature[1], Array)) {
					throw "invalid signature in BuildInfoEmitSignature: expected string or []string";
				} else {
					final signatureList:Array<Dynamic> = fileIdAndSignature[1];
					switch (signatureList.length) {
						case 0:
							differsOnlyInDtsMap = true;
						case 1:
							if (!Std.isOfType(signatureList[0], std.String)) {
								throw "invalid signature in BuildInfoEmitSignature: expected string";
							} else {
								signature = signatureList[0];
								differsInOptions = true;
							}
						default:
							throw "invalid signature in BuildInfoEmitSignature: expected string or []string with 0 or 1 element, got "
								+ signatureList.length + " elements";
					}
				}
			} else {
				signature = fileIdAndSignature[1];
			}
			return new BuildInfoEmitSignature(fileId, signature, differsOnlyInDtsMap, differsInOptions);
		}
		return new BuildInfoEmitSignature(JsonDecode.int(data));
	}
}

@:allow(ts.execute.incremental)
class BuildInfoResolvedRoot implements OrderedMarshaler {
	public var Resolved:BuildInfoFileId = 0;
	public var Root:BuildInfoFileId = 0;

	public function new(Resolved:BuildInfoFileId = 0, Root:BuildInfoFileId = 0) {
		this.Resolved = Resolved;
		this.Root = Root;
	}

	public function MarshalJSONValue():Dynamic {
		return [this.Resolved, this.Root];
	}

	public static function fromJSONValue(data:Dynamic):BuildInfoResolvedRoot {
		var resolvedAndRoot:Array<Int>;
		try {
			resolvedAndRoot = JsonDecode.ints(data);
		} catch (e:Dynamic) {
			throw "invalid BuildInfoResolvedRoot";
		}
		if (resolvedAndRoot == null || resolvedAndRoot.length != 2)
			throw "invalid BuildInfoResolvedRoot";
		return new BuildInfoResolvedRoot(resolvedAndRoot[0], resolvedAndRoot[1]);
	}
}

@:allow(ts.execute.incremental)
class BuildInfo implements OrderedMarshaler {
	public var Version:std.String = ""; // json:"version,omitzero"

	// Common between incremental and tsc -b buildinfo for non incremental programs
	public var Errors:Bool = false; // json:"errors,omitzero"
	public var CheckPending:Bool = false; // json:"checkPending,omitzero"
	public var Root:Array<BuildInfoRoot> = null; // json:"root,omitzero"
	public var PackageJsons:Array<std.String> = null; // json:"packageJsons,omitzero"
	public var MissingPackageJsons:Array<std.String> = null; // json:"missingPackageJsons,omitzero"

	// IncrementalProgram info
	public var FileNames:Array<std.String> = null; // json:"fileNames,omitzero"
	public var FileInfos:Array<BuildInfoFileInfo> = null; // json:"fileInfos,omitzero"
	public var FileIdsList:Array<Array<BuildInfoFileId>> = null; // json:"fileIdsList,omitzero"
	public var Options:OrderedMap<std.String, Dynamic> = null; // json:"options,omitzero"
	public var ReferencedMap:Array<BuildInfoReferenceMapEntry> = null; // json:"referencedMap,omitzero"
	public var SemanticDiagnosticsPerFile:Array<BuildInfoSemanticDiagnostic> = null; // json:"semanticDiagnosticsPerFile,omitzero"
	public var EmitDiagnosticsPerFile:Array<BuildInfoDiagnosticsOfFile> = null; // json:"emitDiagnosticsPerFile,omitzero"
	public var ChangeFileSet:Array<BuildInfoFileId> = null; // json:"changeFileSet,omitzero"
	public var AffectedFilesPendingEmit:Array<BuildInfoFilePendingEmit> = null; // json:"affectedFilesPendingEmit,omitzero"
	public var LatestChangedDtsFile:std.String = ""; // json:"latestChangedDtsFile,omitzero" // Because this is only output file in the program, we dont need fileId to deduplicate name
	public var EmitSignatures:Array<BuildInfoEmitSignature> = null; // json:"emitSignatures,omitzero"
	public var ResolvedRoot:Array<BuildInfoResolvedRoot> = null; // json:"resolvedRoot,omitzero"

	// NonIncrementalProgram info
	public var SemanticErrors:Bool = false; // json:"semanticErrors,omitzero"

	public function new() {}

	public function MarshalJSONValue():Dynamic {
		final m = new OrderedMap<std.String, Dynamic>();
		if (this.Version != "")
			m.Set("version", this.Version);
		if (this.Errors)
			m.Set("errors", true);
		if (this.CheckPending)
			m.Set("checkPending", true);
		if (this.Root != null)
			m.Set("root", this.Root);
		if (this.PackageJsons != null)
			m.Set("packageJsons", this.PackageJsons);
		if (this.MissingPackageJsons != null)
			m.Set("missingPackageJsons", this.MissingPackageJsons);
		if (this.FileNames != null)
			m.Set("fileNames", this.FileNames);
		if (this.FileInfos != null)
			m.Set("fileInfos", this.FileInfos);
		if (this.FileIdsList != null)
			m.Set("fileIdsList", [for (ids in this.FileIdsList) ids == null ? [] : ids]); // PORT: nil inner slice → []
		if (this.Options != null)
			m.Set("options", this.Options);
		if (this.ReferencedMap != null)
			m.Set("referencedMap", this.ReferencedMap);
		if (this.SemanticDiagnosticsPerFile != null)
			m.Set("semanticDiagnosticsPerFile", this.SemanticDiagnosticsPerFile);
		if (this.EmitDiagnosticsPerFile != null)
			m.Set("emitDiagnosticsPerFile", this.EmitDiagnosticsPerFile);
		if (this.ChangeFileSet != null)
			m.Set("changeFileSet", this.ChangeFileSet);
		if (this.AffectedFilesPendingEmit != null)
			m.Set("affectedFilesPendingEmit", this.AffectedFilesPendingEmit);
		if (this.LatestChangedDtsFile != "")
			m.Set("latestChangedDtsFile", this.LatestChangedDtsFile);
		if (this.EmitSignatures != null)
			m.Set("emitSignatures", this.EmitSignatures);
		if (this.ResolvedRoot != null)
			m.Set("resolvedRoot", this.ResolvedRoot);
		if (this.SemanticErrors)
			m.Set("semanticErrors", true);
		return m;
	}

	public static function fromJSONValue(data:Dynamic):BuildInfo {
		if (!Std.isOfType(data, OrderedMap))
			throw "json: cannot unmarshal into BuildInfo";
		final o:OrderedMap<std.String, Dynamic> = data;
		final b = new BuildInfo();
		b.Version = JsonDecode.string(JsonDecode.field(o, "version"));
		b.Errors = JsonDecode.bool(JsonDecode.field(o, "errors"));
		b.CheckPending = JsonDecode.bool(JsonDecode.field(o, "checkPending"));
		b.Root = JsonDecode.slice(JsonDecode.field(o, "root"), BuildInfoRoot.fromJSONValue);
		b.PackageJsons = JsonDecode.strings(JsonDecode.field(o, "packageJsons"));
		b.MissingPackageJsons = JsonDecode.strings(JsonDecode.field(o, "missingPackageJsons"));
		b.FileNames = JsonDecode.strings(JsonDecode.field(o, "fileNames"));
		b.FileInfos = JsonDecode.slice(JsonDecode.field(o, "fileInfos"), BuildInfoFileInfo.fromJSONValue);
		final fileIdsList = JsonDecode.array(JsonDecode.field(o, "fileIdsList"));
		b.FileIdsList = fileIdsList == null ? null : [for (ids in fileIdsList) JsonDecode.ints(ids)];
		b.Options = JsonDecode.object(JsonDecode.field(o, "options"), "OrderedMap");
		b.ReferencedMap = JsonDecode.slice(JsonDecode.field(o, "referencedMap"), BuildInfoReferenceMapEntry.fromJSONValue);
		b.SemanticDiagnosticsPerFile = JsonDecode.slice(JsonDecode.field(o, "semanticDiagnosticsPerFile"), BuildInfoSemanticDiagnostic.fromJSONValue);
		b.EmitDiagnosticsPerFile = JsonDecode.slice(JsonDecode.field(o, "emitDiagnosticsPerFile"), BuildInfoDiagnosticsOfFile.fromJSONValue);
		b.ChangeFileSet = JsonDecode.ints(JsonDecode.field(o, "changeFileSet"));
		b.AffectedFilesPendingEmit = JsonDecode.slice(JsonDecode.field(o, "affectedFilesPendingEmit"), BuildInfoFilePendingEmit.fromJSONValue);
		b.LatestChangedDtsFile = JsonDecode.string(JsonDecode.field(o, "latestChangedDtsFile"));
		b.EmitSignatures = JsonDecode.slice(JsonDecode.field(o, "emitSignatures"), BuildInfoEmitSignature.fromJSONValue);
		b.ResolvedRoot = JsonDecode.slice(JsonDecode.field(o, "resolvedRoot"), BuildInfoResolvedRoot.fromJSONValue);
		b.SemanticErrors = JsonDecode.bool(JsonDecode.field(o, "semanticErrors"));
		return b;
	}

	public function IsValidVersion():Bool {
		return this.Version == Core.Version();
	}

	public function IsIncremental():Bool {
		return this != null && Core.len(this.FileNames) != 0;
	}

	function fileName(fileId:BuildInfoFileId):std.String {
		if (fileId < 1 || fileId > Core.len(this.FileNames)) {
			return "";
		}
		return this.FileNames[fileId - 1];
	}

	function fileInfo(fileId:BuildInfoFileId):BuildInfoFileInfo {
		if (fileId < 1 || fileId > Core.len(this.FileInfos)) {
			return null;
		}
		return this.FileInfos[fileId - 1];
	}

	public function GetCompilerOptions(buildInfoDirectory:std.String):CompilerOptions {
		final options = new CompilerOptions();
		if (this.Options != null) {
			for (option => value in this.Options.Entries()) {
				if (buildInfoDirectory != "") {
					final r = Tsoptions.ConvertOptionToAbsolutePath(option, value, Tsoptions.CommandLineCompilerOptionsMap, buildInfoDirectory);
					if (r.ok) {
						Tsoptions.ParseCompilerOptions(option, r.value, options);
						continue;
					}
				}
				Tsoptions.ParseCompilerOptions(option, value, options);
			}
		}
		return options;
	}

	public function IsEmitPending(resolved:ParsedCommandLine, buildInfoDirectory:std.String):Bool {
		// Some of the emit files like source map or dts etc are not yet done
		if (!resolved.CompilerOptions().NoEmit.IsTrue() || resolved.CompilerOptions().GetEmitDeclarations()) {
			var pendingEmit = Incremental.getPendingEmitKindWithOptions(resolved.CompilerOptions(), this.GetCompilerOptions(buildInfoDirectory));
			if (resolved.CompilerOptions().NoEmit.IsTrue()) {
				pendingEmit = pendingEmit & FileEmitKindDtsErrors;
			}
			return pendingEmit != 0;
		}
		return false;
	}

	// PORT: iter.Seq[string] → Iterator
	public function GetPackageJsons(buildInfoDirectory:std.String):Iterator<std.String> {
		return Incremental.getNormalizedPaths(this.PackageJsons, buildInfoDirectory);
	}

	public function GetMissingPackageJsons(buildInfoDirectory:std.String):Iterator<std.String> {
		return Incremental.getNormalizedPaths(this.MissingPackageJsons, buildInfoDirectory);
	}

	public function GetBuildInfoRootInfoReader(buildInfoDirectory:std.String, comparePathOptions:ComparePathsOptions):BuildInfoRootInfoReader {
		final resolvedRootFileInfos = new StringMap<BuildInfoFileInfo>();
		// Roots of the File
		final rootToResolved = Collections.NewOrderedMapWithSizeHint(Core.len(this.FileNames), ("" : Path));
		final resolvedToRoot = new StringMap<Path>();
		final toPath = function(fileName:std.String):Path {
			return Tspath.ToPath(fileName, buildInfoDirectory, comparePathOptions.UseCaseSensitiveFileNames);
		};

		// Create map from resolvedRoot to Root
		for (resolved in this.ResolvedRoot) {
			final resolvedRoot = this.fileName(resolved.Resolved);
			final root = this.fileName(resolved.Root);
			if (resolvedRoot != "" && root != "") {
				resolvedToRoot.set(toPath(resolvedRoot), toPath(root));
			}
		}

		final addRoot = function(resolvedRoot:std.String, fileInfo:BuildInfoFileInfo) {
			if (resolvedRoot == "") {
				return;
			}
			final resolvedRootPath = toPath(resolvedRoot);
			final rootPath = resolvedToRoot.get(resolvedRootPath);
			if (rootPath != null) {
				rootToResolved.Set(rootPath, resolvedRootPath);
			} else {
				rootToResolved.Set(resolvedRootPath, resolvedRootPath);
			}
			if (fileInfo != null) {
				resolvedRootFileInfos.set(resolvedRootPath, fileInfo);
			}
		};

		for (root in this.Root) {
			if (root.NonIncremental != "") {
				addRoot(root.NonIncremental, null);
			} else if (root.End == 0) {
				addRoot(this.fileName(root.Start), this.fileInfo(root.Start));
			} else {
				var i = root.Start;
				while (i <= root.End) {
					addRoot(this.fileName(i), this.fileInfo(i));
					i++;
				}
			}
		}

		return new BuildInfoRootInfoReader(resolvedRootFileInfos, rootToResolved);
	}
}

@:allow(ts.execute.incremental)
class BuildInfoRootInfoReader {
	var resolvedRootFileInfos:StringMap<BuildInfoFileInfo> = null;
	var rootToResolved:OrderedMap<Path, Path> = null;

	public function new(resolvedRootFileInfos:StringMap<BuildInfoFileInfo>, rootToResolved:OrderedMap<Path, Path>) {
		this.resolvedRootFileInfos = resolvedRootFileInfos;
		this.rootToResolved = rootToResolved;
	}

	// PORT: (*BuildInfoFileInfo, tspath.Path) → Pair
	public function GetBuildInfoFileInfo(inputFilePath:Path):Pair<BuildInfoFileInfo, Path> {
		if (this.resolvedRootFileInfos.exists(inputFilePath)) {
			return new Pair(this.resolvedRootFileInfos.get(inputFilePath), inputFilePath);
		}
		final r = this.rootToResolved.Get(inputFilePath);
		if (r.ok) {
			return new Pair(this.resolvedRootFileInfos.get(r.value), r.value);
		}
		return new Pair<BuildInfoFileInfo, Path>(null, "");
	}

	// PORT: iter.Seq → Iterator
	public function Roots():Iterator<Path> {
		return this.rootToResolved.Keys();
	}
}
