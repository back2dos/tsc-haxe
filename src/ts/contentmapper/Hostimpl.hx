package ts.contentmapper;

import go.Errors;
import go.Errors.Error;
import go.Slices;
import go.Strings;
import go.Tuple;
import haxe.ds.StringMap;
import ts.ast.Ast;
import ts.ast.Ast.MappedDiagnosticDirective;
import ts.ast.Ast.MappedDiagnosticDirectivePolicy;
import ts.ast.Diagnostic;
import ts.collections.OrderedMap;
import ts.contentmapper.Contentmapper;
import ts.contentmapper.Host;
import ts.core.Compileroptions;
import ts.core.Core;
import ts.diagnostics.Diagnostics;
import ts.diagnostics.Diagnostics.Category.*;
import ts.json.Json;
import ts.locale.Locale;
import ts.spanmap.Spanmap;
import ts.tspath.Tspath;

// --- hostimpl.go ---
//
// PORT: Go drives each mapper as a child process over a JSON-RPC connection (internal/ipc). The port
// is single-threaded and has no process host: a Spawner returns an in-process Handler (the mapper's
// protocol implementation) and the connection calls it directly, passing the protocol structs below
// instead of their JSON encoding. json.Value fields stay raw JSON text. Running real external mapper
// packages (the CLI's exec spawner) is not supported (see Hostimpl.NewProcessSpawner).

// Content mapper protocol method names.
class Hostimpl {
	public static inline final MethodInitialize = "initialize";
	public static inline final MethodOpenProject = "openProject";
	public static inline final MethodCloseProject = "closeProject";
	public static inline final MethodTransform = "transform";

	public static inline final PositionEncodingUTF8 = "utf-8";
	public static inline final PositionEncodingUTF16 = "utf-16";

	public static inline final DiagnosticDirectivePolicyIgnore = 0;
	public static inline final DiagnosticDirectivePolicyExpect = 1;

	static inline final initializeTimeoutSeconds = 5;

	// NewHost creates a Host that spawns each mapper via the given spawner and drives it over a connection.
	public static function NewHost(ctx:go.Context, spawner:Spawner, diagnosticLocale:Locale):Host {
		return newWithDial(ctx, diagnosticLocale, function(ctx:go.Context, mapper:Mapper, diagnosticLocale:Locale):DialResult {
			if (mapper.Manifest.Exec == null || mapper.Manifest.Exec.length == 0) {
				return DialResult.failure(Errors.New('content mapper ${Json.Quote(mapper.Definition.Package)} declares no command to run'));
			}
			final diagnosticName = mapper.DiagnosticName();
			final spawned = spawner.Spawn(mapper.Manifest.Exec, mapper.PackageDirectory);
			if (spawned.err != null) {
				final e = new InitializeError(InitializeErrorKindProcessStart);
				e.MapperName = diagnosticName;
				e.Command = mapper.Manifest.Exec[0];
				e.Detail = spawned.err.Error();
				return DialResult.failure(e);
			}
			final conn = new InProcessConn(spawned.value);
			final hs = handshake(ctx, conn, diagnosticLocale);
			if (hs.c != null) {
				final initializeError = Std.downcast(hs.c, InitializeError);
				if (initializeError != null) {
					initializeError.MapperName = diagnosticName;
					return DialResult.failure(initializeError);
				}
				final e = new InitializeError(InitializeErrorKindRequest);
				e.MapperName = diagnosticName;
				e.Detail = hs.c.Error();
				return DialResult.failure(e);
			}
			return new DialResult(conn, hs.a, hs.b, null);
		});
	}

	static function newWithDial(ctx:go.Context, diagnosticLocale:Locale, dial:DialFunc):HostImpl {
		return new HostImpl(ctx, dial, diagnosticLocale);
	}

	public static function projectSpecKey(spec:ProjectSpec):String {
		// PORT: Go keys by the pointers of the options and mappers (%p); here by object identity ids.
		final key = new StringBuf();
		key.add(spec.ConfigFileName);
		key.add("\x01");
		key.add(identityId(spec.CompilerOptions));
		for (mapper in spec.Mappers) {
			key.add("\x01");
			key.add(identityId(mapper));
		}
		return key.toString();
	}

	static var identityIds:go.IdentityMap<Dynamic, Int> = null;
	static var nextIdentityId = 1;

	static function identityId(o:Dynamic):Int {
		if (o == null)
			return 0;
		if (identityIds == null)
			identityIds = new go.IdentityMap();
		final r = identityIds.get(o);
		if (r != null)
			return r;
		final id = nextIdentityId++;
		identityIds.set(o, id);
		return id;
	}

	public static function combinedIdentity(mapper:Mapper, configIdentity:String, compilerOptions:CompilerOptions):String {
		final transformIdentity = mapper.TransformIdentity(compilerOptions);
		final buf = new StringBuf();
		buf.add(mapper.Identity());
		buf.addChar(0);
		buf.add(mapper.Definition.Options);
		buf.addChar(0);
		buf.add(configIdentity);
		buf.addChar(0);
		buf.add(transformIdentity);
		return mapper.Identity() + ":" + Mapper.hexOf(go.Xxh3.HashString128(buf.toString()).Bytes());
	}

	public static function handshake(ctx:go.Context, conn:Conn, diagnosticLocale:Locale):Triple<String, String, Error> {
		final params = new InitializeParams();
		params.Locale = diagnosticLocale == Locale.Default ? "" : diagnosticLocale.String();
		params.PositionEncodings = [PositionEncodingUTF8, PositionEncodingUTF16];
		final raw = conn.Call(ctx, MethodInitialize, params);
		if (raw.err != null) {
			return new Triple("", "", raw.err);
		}
		final res = Std.downcast(raw.value, InitializeResult);
		if (res == null) {
			final e = new InitializeError(InitializeErrorKindInvalidResponse);
			e.Detail = "json: cannot unmarshal into contentmapper.InitializeResult";
			return new Triple("", "", (e : Error));
		}
		if (res.PositionEncoding != PositionEncodingUTF8 && res.PositionEncoding != PositionEncodingUTF16) {
			final e = new InitializeError(InitializeErrorKindPositionEncoding);
			e.PositionEncoding = res.PositionEncoding;
			return new Triple("", "", (e : Error));
		}
		if (Strings.TrimSpace(res.DiagnosticSource) == "") {
			return new Triple("", "", (new InitializeError(InitializeErrorKindEmptyDiagnosticSource) : Error));
		}
		if (Strings.EqualFold(res.DiagnosticSource, "typescript") || Strings.EqualFold(res.DiagnosticSource, "tsc")) {
			final e = new InitializeError(InitializeErrorKindReservedDiagnosticSource);
			e.DiagnosticSource = res.DiagnosticSource;
			return new Triple("", "", (e : Error));
		}
		for (extensions in Tspath.AllSupportedExtensionsWithJson) {
			for (extension in extensions) {
				if (Strings.EqualFold(res.DiagnosticSource, StringTools.startsWith(extension, ".") ? extension.substring(1) : extension)) {
					final e = new InitializeError(InitializeErrorKindReservedDiagnosticSource);
					e.DiagnosticSource = res.DiagnosticSource;
					return new Triple("", "", (e : Error));
				}
			}
		}
		return new Triple(res.PositionEncoding, res.DiagnosticSource, null);
	}

	public static function decodeTransformResult(raw:Dynamic, originalText:String, positionEncoding:String, diagnosticSource:String):ValueError<Result> {
		final res = Std.downcast(raw, TransformResult);
		if (res == null) {
			return new ValueError(null, Errors.New("json: cannot unmarshal into contentmapper.TransformResult"));
		}
		final mapped = decodeMappedOutput(res, originalText, positionEncoding, diagnosticSource);
		if (mapped.c != null) {
			return new ValueError(null, mapped.c);
		}
		final originalPositions = mapped.b;
		final result = new Result();
		result.Text = mapped.a.Text;
		result.VirtualExtension = mapped.a.VirtualExtension;
		result.Mappings = mapped.a.Mappings;
		result.DiagnosticDirectives = mapped.a.DiagnosticDirectives;
		if (res.Supplemental != null) {
			for (supplementalIndex in 0...res.Supplemental.length) {
				final supplemental = res.Supplemental[supplementalIndex];
				final m = decodeMappedOutput(supplemental, originalText, positionEncoding, diagnosticSource);
				if (m.c != null) {
					final directiveError = Std.downcast(m.c, DiagnosticDirectiveError);
					if (directiveError != null) {
						directiveError.SupplementalIndex = supplementalIndex;
					}
					return new ValueError(null, m.c);
				}
				if (result.Supplemental == null)
					result.Supplemental = [];
				result.Supplemental.push(m.a);
			}
		}
		if (res.Diagnostics != null) {
			for (d in res.Diagnostics) {
				if (d.Start < 0 || d.Length < 0 || d.Start > 0x7fffffff - d.Length) {
					return new ValueError(null, Errors.New('invalid content mapper diagnostic range [${d.Start}, ${d.Start + d.Length})'));
				}
				final start = originalPositions.normalize(d.Start);
				if (start.err != null) {
					return new ValueError(null, Errors.New("invalid content mapper diagnostic start: " + start.err.Error()));
				}
				final end = originalPositions.normalize(d.Start + d.Length);
				if (end.err != null) {
					return new ValueError(null, Errors.New("invalid content mapper diagnostic end: " + end.err.Error()));
				}
				if (result.Diagnostics == null)
					result.Diagnostics = [];
				result.Diagnostics.push(Ast.NewExternalDiagnostic(null, Core.NewTextRange(start.value, end.value), diagnosticSource, CategoryError, d.Code,
					d.MessageText));
			}
		}
		return new ValueError(result, null);
	}

	static function decodeMappedOutput(output:MappedOutput, originalText:String, positionEncoding:String,
			diagnosticSource:String):Triple<MappedResult, PositionNormalizer, Error> {
		if (!Contentmapper.IsSupportedVirtualExtension(output.Extension)) {
			return new Triple(null, null, (new InvalidVirtualExtensionError(output.Extension) : Error));
		}
		final result = new MappedResult();
		result.Text = output.Text;
		result.VirtualExtension = output.Extension;
		final virtualPositions = PositionNormalizer.create(output.Text, positionEncoding);
		if (virtualPositions.err != null) {
			return new Triple(null, null, virtualPositions.err);
		}
		final originalPositions = PositionNormalizer.create(originalText, positionEncoding);
		if (originalPositions.err != null) {
			return new Triple(null, null, originalPositions.err);
		}
		// A successful transform always carries a span map. Absent or empty mappings describe fully
		// synthesized output, so decode to an empty map rather than nil.
		if (output.Mappings != null && output.Mappings.length > 0) {
			final mappings = Spanmap.Unmarshal(output.Mappings);
			if (mappings.err != null) {
				return new Triple(null, null, mappings.err);
			}
			final normalized = normalizeMappings(mappings.value, virtualPositions.value, originalPositions.value);
			if (normalized.err != null) {
				return new Triple(null, null, normalized.err);
			}
			result.Mappings = normalized.value;
		} else {
			result.Mappings = Spanmap.New(null);
		}
		final directives = normalizeDiagnosticDirectives(output.DiagnosticDirectives, virtualPositions.value, originalPositions.value, diagnosticSource);
		if (directives.err != null) {
			return new Triple(null, null, directives.err);
		}
		result.DiagnosticDirectives = directives.value;
		return new Triple(result, originalPositions.value, null);
	}

	static function normalizeDiagnosticDirectives(diagnosticDirectives:Null<DiagnosticDirectives>, virtualPositions:PositionNormalizer,
			originalPositions:PositionNormalizer, diagnosticSource:String):ValueError<Slice<MappedDiagnosticDirective>> {
		if (diagnosticDirectives == null) {
			return new ValueError(null, null);
		}
		final directives = diagnosticDirectives.Directives == null ? [] : diagnosticDirectives.Directives;
		final unusedDiagnostics = diagnosticDirectives.UnusedExpectDirectiveDiagnostics == null ? [] : diagnosticDirectives.UnusedExpectDirectiveDiagnostics;
		final result:Array<MappedDiagnosticDirective> = [];
		for (i in 0...directives.length) {
			final directive = directives[i];
			function directiveError(kind:DiagnosticDirectiveErrorKind):DiagnosticDirectiveError {
				return new DiagnosticDirectiveError(kind, i, -1);
			}
			final normalized = new MappedDiagnosticDirective();
			normalized.Source = diagnosticSource;
			switch (directive.Policy) {
				case DiagnosticDirectivePolicyIgnore:
					normalized.Policy = MappedDiagnosticDirectivePolicyIgnore;
				case DiagnosticDirectivePolicyExpect:
					var unusedDiagnosticIndex = 0;
					if (directive.UnusedExpectDirectiveIndex != null) {
						unusedDiagnosticIndex = directive.UnusedExpectDirectiveIndex;
					} else if (unusedDiagnostics.length != 1) {
						return new ValueError(null, directiveError(DiagnosticDirectiveErrorKindExpectMissingUnusedDiagnostic));
					}
					if (unusedDiagnosticIndex < 0 || unusedDiagnosticIndex >= unusedDiagnostics.length) {
						return new ValueError(null, directiveError(DiagnosticDirectiveErrorKindInvalidUnusedDiagnosticIndex));
					}
					final unusedDiagnostic = unusedDiagnostics[unusedDiagnosticIndex];
					normalized.Policy = MappedDiagnosticDirectivePolicyExpect;
					normalized.UnusedCode = unusedDiagnostic.Code;
					normalized.UnusedMessageText = unusedDiagnostic.MessageText;
				default:
					final validationError = directiveError(DiagnosticDirectiveErrorKindInvalidPolicy);
					validationError.Policy = directive.Policy;
					return new ValueError(null, validationError);
			}
			if (directive.VirtualStart < 0 || directive.VirtualEnd < directive.VirtualStart) {
				return new ValueError(null, directiveError(DiagnosticDirectiveErrorKindInvalidRange));
			}
			final virtualStart = virtualPositions.normalize(directive.VirtualStart);
			if (virtualStart.err != null) {
				return new ValueError(null, directiveError(DiagnosticDirectiveErrorKindInvalidRange));
			}
			final virtualEnd = virtualPositions.normalize(directive.VirtualEnd);
			if (virtualEnd.err != null) {
				return new ValueError(null, directiveError(DiagnosticDirectiveErrorKindInvalidRange));
			}
			normalized.VirtualRange = Core.NewTextRange(virtualStart.value, virtualEnd.value);
			var validOriginalRange = directive.OriginalStart >= 0 && directive.OriginalLength >= 0
				&& directive.OriginalStart <= 0x7fffffff - directive.OriginalLength;
			if (validOriginalRange) {
				final originalStart = originalPositions.normalize(directive.OriginalStart);
				final originalEnd = originalPositions.normalize(directive.OriginalStart + directive.OriginalLength);
				if (originalStart.err == null && originalEnd.err == null) {
					normalized.OriginalRange = Core.NewTextRange(originalStart.value, originalEnd.value);
				} else {
					validOriginalRange = false;
				}
			}
			if (normalized.Policy == MappedDiagnosticDirectivePolicyExpect && !validOriginalRange) {
				return new ValueError(null, directiveError(DiagnosticDirectiveErrorKindInvalidRange));
			}
			result.push(normalized);
		}
		final sorted = [for (i in 0...result.length) new Pair(result[i], i)];
		Slices.SortFunc(sorted, (a, b) -> a.a.VirtualRange.Pos() - b.a.VirtualRange.Pos());
		for (i in 1...sorted.length) {
			if (sorted[i].a.VirtualRange.Pos() < sorted[i - 1].a.VirtualRange.End()) {
				return new ValueError(null, new DiagnosticDirectiveError(DiagnosticDirectiveErrorKindOverlap, sorted[i].b, -1));
			}
		}
		return new ValueError(result, null);
	}

	static function normalizeMappings(mappings:Spanmap, virtualPositions:PositionNormalizer, originalPositions:PositionNormalizer):ValueError<Spanmap> {
		final segments = Spanmap.Segments(mappings);
		for (i in 0...segments.length) {
			final segment = segments[i];
			var r = virtualPositions.normalize(segment.VirtualStart);
			if (r.err != null)
				return new ValueError(null, Errors.New('invalid content mapper mapping ${i} virtual start: ${r.err.Error()}'));
			segment.VirtualStart = r.value;
			r = virtualPositions.normalize(segment.VirtualEnd);
			if (r.err != null)
				return new ValueError(null, Errors.New('invalid content mapper mapping ${i} virtual end: ${r.err.Error()}'));
			segment.VirtualEnd = r.value;
			r = originalPositions.normalize(segment.OriginalStart);
			if (r.err != null)
				return new ValueError(null, Errors.New('invalid content mapper mapping ${i} original start: ${r.err.Error()}'));
			segment.OriginalStart = r.value;
			r = originalPositions.normalize(segment.OriginalEnd);
			if (r.err != null)
				return new ValueError(null, Errors.New('invalid content mapper mapping ${i} original end: ${r.err.Error()}'));
			segment.OriginalEnd = r.value;
		}
		return new ValueError(Spanmap.New(segments), null);
	}
}

// PORT: ipc.Handler (the mapper side of a connection); notifications are not modelled.
interface Handler {
	function HandleRequest(ctx:go.Context, method:String, params:Dynamic):ValueError<Dynamic>;
}

// PORT: ipc.Conn (the host side): Call returns the result object or the handler's error.
interface Conn {
	function Call(ctx:go.Context, method:String, params:Dynamic):ValueError<Dynamic>;
}

// Spawner starts a mapper. PORT: returns the in-process Handler instead of the process's stdio.
interface Spawner {
	function Spawn(command:Slice<String>, dir:String):ValueError<Handler>;
}

private class InProcessConn implements Conn {
	final handler:Handler;

	public function new(handler:Handler) {
		this.handler = handler;
	}

	public function Call(ctx:go.Context, method:String, params:Dynamic):ValueError<Dynamic> {
		try {
			return handler.HandleRequest(ctx, method, params);
		} catch (e:Dynamic) {
			return new ValueError(null, Errors.New(Std.string(e)));
		}
	}
}

typedef DialFunc = (ctx:go.Context, mapper:Mapper, diagnosticLocale:Locale) -> DialResult;

class DialResult {
	public final conn:Null<Conn>;
	public final positionEncoding:String;
	public final diagnosticSource:String;
	public final err:Null<Error>;

	public function new(conn, positionEncoding, diagnosticSource, err) {
		this.conn = conn;
		this.positionEncoding = positionEncoding;
		this.diagnosticSource = diagnosticSource;
		this.err = err;
	}

	public static function failure(err:Error):DialResult {
		return new DialResult(null, "", "", err);
	}
}

// --- protocol types ---

// InitializeParams is the parameter object for the initialize request.
class InitializeParams {
	public var Locale:String = "";
	public var PositionEncodings:Slice<String> = null;

	public function new() {}
}

// InitializeResult is the mapper's response to the initialize request.
class InitializeResult {
	public var PositionEncoding:String = "";
	public var DiagnosticSource:String = "";

	public function new(positionEncoding:String = "", diagnosticSource:String = "") {
		this.PositionEncoding = positionEncoding;
		this.DiagnosticSource = diagnosticSource;
	}
}

// OpenProjectParams is the parameter object for the openProject request.
class OpenProjectParams {
	public var ConfigFileName:String = "";
	public var ProjectHandle:String = "";
	// json.Value: the mapper entry's options ("" when absent)
	public var Options:String = "";
	// json.Value: the project's effective compiler options
	public var CompilerOptions:String = "";

	public function new() {}
}

// OpenProjectResult is the mapper's response to an openProject request.
class OpenProjectResult {
	public var ConfigIdentity:String = "";
	public var WatchedFiles:Slice<String> = null;
	public var OptionDiagnostics:Slice<OptionDiagnosticResult> = null;

	public function new() {}
}

class OptionDiagnosticResult {
	// json.Value segments: a JSON string (property) or number (index)
	public var Path:Slice<String> = null;
	public var MessageText:String = "";
	public var Code:Int = 0;

	public function new() {}
}

// CloseProjectParams is the parameter object for the closeProject request.
class CloseProjectParams {
	public var ProjectHandle:String = "";

	public function new(projectHandle:String = "") {
		this.ProjectHandle = projectHandle;
	}
}

// TransformParams is the parameter object for the transform request.
class TransformParams {
	public var FileName:String = "";
	public var Content:String = "";
	public var ProjectHandle:String = "";

	public function new() {}
}

// MappedOutput is virtual source text and its mapping to an original input.
class MappedOutput {
	public var Text:String = "";
	public var Extension:String = "";
	// json.Value: the span map's tuple-array JSON; "" or null means fully synthesized.
	public var Mappings:String = null;
	public var DiagnosticDirectives:DiagnosticDirectives = null;

	public function new(text:String = "", extension:String = "", mappings:String = null) {
		this.Text = text;
		this.Extension = extension;
		this.Mappings = mappings;
	}
}

class UnusedExpectDirectiveDiagnostic {
	public var Code:Int = 0;
	public var MessageText:String = "";

	public function new(code:Int = 0, messageText:String = "") {
		this.Code = code;
		this.MessageText = messageText;
	}
}

// DiagnosticDirectives shares unused-expect diagnostics across compact directive tuples.
class DiagnosticDirectives {
	public var UnusedExpectDirectiveDiagnostics:Slice<UnusedExpectDirectiveDiagnostic> = null;
	public var Directives:Slice<ProtocolDiagnosticDirective> = null;

	public function new(directives:Array<ProtocolDiagnosticDirective>, unused:Slice<UnusedExpectDirectiveDiagnostic>) {
		this.Directives = directives;
		this.UnusedExpectDirectiveDiagnostics = unused;
	}
}

// MappedDiagnosticDirective of the protocol (Go contentmapper.MappedDiagnosticDirective), encoded as
// [originalStart, originalLength, virtualStart, virtualEnd, policy, unusedExpectDirectiveIndex?].
// PORT: renamed to avoid the clash with ast.MappedDiagnosticDirective.
class ProtocolDiagnosticDirective {
	public var OriginalStart:Int = 0;
	public var OriginalLength:Int = 0;
	public var VirtualStart:Int = 0;
	public var VirtualEnd:Int = 0;
	public var Policy:Int = 0;
	public var UnusedExpectDirectiveIndex:Null<Int> = null;

	public function new() {}
}

// TransformResult is the canonical output for one input file.
class TransformResult extends MappedOutput {
	public var Diagnostics:Slice<ProtocolDiagnostic> = null;
	public var Supplemental:Slice<MappedOutput> = null;

	public function new(text:String = "", extension:String = "", mappings:String = null) {
		super(text, extension, mappings);
	}
}

// Diagnostic is an error reported by a mapper in original-source coordinates.
// PORT: renamed (Go contentmapper.Diagnostic) to avoid the clash with ast.Diagnostic.
class ProtocolDiagnostic {
	public var MessageText:String = "";
	public var Start:Int = 0;
	public var Length:Int = 0;
	public var Code:Int = 0;

	public function new(messageText:String = "", start:Int = 0, length:Int = 0, code:Int = 0) {
		this.MessageText = messageText;
		this.Start = start;
		this.Length = length;
		this.Code = code;
	}
}

private class ProjectEntry {
	public var mapper:Mapper;
	public var spec:ProjectSpec;
	public var projectHandle:String;
	public var opened:Bool = false;
	public var configIdentity:String = "";
	public var watchedFiles:Slice<String> = null;
	public var optionDiagnostics:Slice<OptionDiagnostic> = null;

	public function new(mapper, spec, projectHandle) {
		this.mapper = mapper;
		this.spec = spec;
		this.projectHandle = projectHandle;
	}
}

private class MapperConn {
	public var conn:Null<Conn> = null;
	// err, when non-nil, records that this mapper failed to start.
	public var err:Null<Error> = null;
	public var positionEncoding:String = "";
	public var diagnosticSource:String = "";
	public var refs:Int = 0;

	public function new() {}
}

// host manages one connection per mapper identity. PORT: single-threaded (no locks, no contexts).
class HostImpl implements Host {
	final ctx:go.Context;
	final dial:DialFunc;
	var diagnosticLocale:Locale;
	var conns:StringMap<MapperConn> = new StringMap();
	var projects:StringMap<ProjectEntry> = new StringMap();
	var projectLeases:StringMap<ProjectLease> = new StringMap();
	var nextProjectID:Int = 0;

	public function new(ctx:go.Context, dial:DialFunc, diagnosticLocale:Locale) {
		this.ctx = ctx;
		this.dial = dial;
		this.diagnosticLocale = diagnosticLocale;
	}

	public function SetLocale(diagnosticLocale:Locale):Void {
		if (this.diagnosticLocale.String() == diagnosticLocale.String()) {
			return;
		}
		this.diagnosticLocale = diagnosticLocale;
		for (entry in conns) {
			entry.conn = null;
			entry.err = null;
			entry.positionEncoding = "";
			entry.diagnosticSource = "";
		}
		for (project in projects) {
			project.opened = false;
		}
	}

	public function Project(spec:ProjectSpec):Project {
		final key = Hostimpl.projectSpecKey(spec);
		if (projects == null) {
			return null;
		}
		final existing = projectLeases.get(key);
		if (existing != null) {
			return existing.retain();
		}
		final lease = new ProjectLease(this, key, spec.Mappers == null ? [] : spec.Mappers.copy());
		lease.refs = 1;
		for (mapper in lease.mappers) {
			final entryKey = mapper.Identity() + ":" + nextProjectID;
			nextProjectID++;
			final entry = new ProjectEntry(mapper, spec, entryKey);
			projects.set(entryKey, entry);
			var connEntry = conns.get(mapper.Identity());
			if (connEntry == null) {
				connEntry = new MapperConn();
				conns.set(mapper.Identity(), connEntry);
			}
			connEntry.refs++;
			lease.entries.set(mapper, entryKey);
		}
		projectLeases.set(key, lease);
		return lease;
	}

	@:allow(ts.contentmapper)
	function openProject(entry:ProjectEntry):Null<Error> {
		if (entry.opened) {
			return null;
		}
		final c = connFor(entry.mapper);
		if (c.err != null) {
			return c.err;
		}
		final params = new OpenProjectParams();
		params.ConfigFileName = entry.spec.ConfigFileName;
		params.ProjectHandle = entry.projectHandle;
		params.Options = entry.mapper.Definition.Options;
		params.CompilerOptions = Contentmapper.MarshalCompilerOptions(entry.spec.CompilerOptions);
		final raw = c.conn.Call(ctx, Hostimpl.MethodOpenProject, params);
		if (raw.err != null) {
			return raw.err;
		}
		final result = Std.downcast(raw.value, OpenProjectResult);
		if (result == null) {
			return new ProjectError(ProjectErrorKindMalformedResponse);
		}
		if (entry.mapper.Manifest.DynamicConfig && result.ConfigIdentity == "") {
			return new ProjectError(ProjectErrorKindMissingConfigIdentity);
		}
		if (!entry.mapper.Manifest.DynamicConfig && result.ConfigIdentity != "") {
			return new ProjectError(ProjectErrorKindUnexpectedConfigIdentity);
		}
		if (!entry.mapper.Manifest.DynamicConfig && result.WatchedFiles != null && result.WatchedFiles.length != 0) {
			return new ProjectError(ProjectErrorKindUnexpectedWatchedFiles);
		}
		entry.configIdentity = result.ConfigIdentity;
		entry.watchedFiles = [];
		if (result.WatchedFiles != null) {
			for (fileName in result.WatchedFiles) {
				if (!Tspath.IsRootedDiskPath(fileName)) {
					return new ProjectError(ProjectErrorKindNonAbsoluteWatchedFile);
				}
				entry.watchedFiles.push(Tspath.NormalizePath(fileName));
			}
		}
		entry.optionDiagnostics = [];
		if (result.OptionDiagnostics != null) {
			for (diagnostic in result.OptionDiagnostics) {
				final path:Array<OptionPathSegment> = [];
				if (diagnostic.Path != null) {
					for (rawSegment in diagnostic.Path) {
						final segment = new OptionPathSegment();
						final v:Dynamic = try Json.UnmarshalOrdered(rawSegment) catch (e:Dynamic) null;
						if (Std.isOfType(v, String)) {
							segment.Property = v;
						} else if (Std.isOfType(v, Float) && (v : Float) >= 0 && Math.ffloor(v) == v) {
							segment.Index = Std.int(v);
							segment.IsIndex = true;
						} else {
							return new ProjectError(ProjectErrorKindMalformedResponse);
						}
						path.push(segment);
					}
				}
				final d = new OptionDiagnostic();
				d.Mapper = entry.mapper;
				d.Path = path;
				d.Source = c.diagnosticSource;
				d.Code = diagnostic.Code;
				d.MessageText = diagnostic.MessageText;
				entry.optionDiagnostics.push(d);
			}
		}
		entry.opened = true;
		return null;
	}

	@:allow(ts.contentmapper)
	function closeProject(mapper:Mapper, conn:Conn, projectHandle:String):Null<Error> {
		return conn.Call(ctx, Hostimpl.MethodCloseProject, new CloseProjectParams(projectHandle)).err;
	}

	public function Acquire(mappers:Array<Mapper>):() -> Void {
		final seen = new StringMap<Bool>();
		final identities:Array<String> = [];
		if (conns != null) {
			for (mapper in mappers) {
				final identity = mapper.Identity();
				if (seen.exists(identity)) {
					continue;
				}
				seen.set(identity, true);
				identities.push(identity);
				var entry = conns.get(identity);
				if (entry == null) {
					entry = new MapperConn();
					conns.set(identity, entry);
				}
				entry.refs++;
			}
		}
		var released = false;
		return function() {
			if (!released) {
				released = true;
				release(identities);
			}
		};
	}

	// Transform sends the file's content to the mapper and decodes the transformed result.
	public function Transform(mapper:Mapper, request:Request):ValueError<Result> {
		final project = Project(new ProjectSpec("", [mapper], new CompilerOptions()));
		final r = project.Transform(mapper, request);
		project.Close();
		return r;
	}

	@:allow(ts.contentmapper)
	function transform(mapper:Mapper, request:Request, projectHandle:String):ValueError<Result> {
		if (projectHandle == "") {
			return new ValueError(null, Errors.New("content mapper project handle is required"));
		}
		final c = connFor(mapper);
		if (c.err != null) {
			return new ValueError(null, Contentmapper.NewTransformError(TransformErrorKindInitialize, c.err));
		}
		final params = new TransformParams();
		params.FileName = request.FileName;
		params.Content = request.Content;
		params.ProjectHandle = projectHandle;
		final raw = c.conn.Call(ctx, Hostimpl.MethodTransform, params);
		if (raw.err != null) {
			return new ValueError(null, Contentmapper.NewTransformError(TransformErrorKindRequest, raw.err));
		}
		final decoded = Hostimpl.decodeTransformResult(raw.value, request.Content, c.positionEncoding, c.diagnosticSource);
		if (decoded.err != null) {
			return new ValueError(null, Contentmapper.NewTransformError(TransformErrorKindResponse, decoded.err));
		}
		return decoded;
	}

	// Close shuts down every mapper. It is safe to call more than once.
	public function Close():Null<Error> {
		conns = null;
		projects = null;
		projectLeases = null;
		return null;
	}

	// connFor returns the connection for a mapper's identity, starting it on first use.
	@:allow(ts.contentmapper)
	function connFor(mapper:Mapper):DialResult {
		if (conns == null) {
			return DialResult.failure(Errors.New("content mapper host is closed"));
		}
		final identity = mapper.Identity();
		var entry = conns.get(identity);
		if (entry == null) {
			entry = new MapperConn();
			conns.set(identity, entry);
		}
		if (entry.conn != null || entry.err != null) {
			return new DialResult(entry.conn, entry.positionEncoding, entry.diagnosticSource, entry.err);
		}
		final d = dial(ctx, mapper, diagnosticLocale);
		entry.conn = d.conn;
		entry.err = d.err;
		entry.positionEncoding = d.positionEncoding;
		entry.diagnosticSource = d.diagnosticSource;
		return d;
	}

	@:allow(ts.contentmapper)
	function release(identities:Array<String>):Void {
		if (conns != null) {
			for (identity in identities) {
				final entry = conns.get(identity);
				if (entry == null) {
					continue;
				}
				entry.refs--;
				if (entry.refs == 0) {
					conns.remove(identity);
				}
			}
		}
	}
}

private class ProjectLease implements Project {
	public final host:HostImpl;
	public final key:String;
	public final mappers:Slice<Mapper>;
	public final entries:go.IdentityMap<Mapper, String> = new go.IdentityMap();
	public var refs:Int = 0;
	var closed:Bool = false;

	public function new(host:HostImpl, key:String, mappers:Slice<Mapper>) {
		this.host = host;
		this.key = key;
		this.mappers = mappers;
	}

	public function retain():Project {
		refs++;
		return new RetainedProject(this);
	}

	function projects():StringMap<ProjectEntry> {
		return @:privateAccess host.projects;
	}

	public function Refresh():Null<Error> {
		if (projects() == null) {
			return null;
		}
		var result:Null<Error> = null;
		for (mapper in mappers) {
			final entry = projects().get(entries.get(mapper));
			if (entry == null || !entry.opened) {
				continue;
			}
			final connEntry = @:privateAccess host.conns.get(entry.mapper.Identity());
			if (connEntry != null && connEntry.conn != null) {
				final err = host.closeProject(entry.mapper, connEntry.conn, entry.projectHandle);
				if (err != null)
					result = err;
			}
			entry.opened = false;
		}
		return result;
	}

	public function Identities():ValueError<Slice<String>> {
		if (projects() == null) {
			return new ValueError(null, null);
		}
		final identities:Array<String> = [];
		for (mapper in mappers) {
			final entry = projects().get(entries.get(mapper));
			if (entry == null) {
				continue;
			}
			if (mapper.Manifest.DynamicConfig) {
				final err = host.openProject(entry);
				if (err != null) {
					return new ValueError(null, err);
				}
				identities.push(Hostimpl.combinedIdentity(mapper, entry.configIdentity, entry.spec.CompilerOptions));
			} else {
				identities.push(mapper.Identity() + ":" + mapper.TransformIdentity(entry.spec.CompilerOptions));
			}
		}
		return new ValueError(identities, null);
	}

	public function Identity(mapper:Mapper):ValueError<String> {
		if (projects() == null) {
			return new ValueError("", null);
		}
		final key = entries.get(mapper);
		if (key == null) {
			return new ValueError("", null);
		}
		final entry = projects().get(key);
		if (entry == null) {
			return new ValueError("", null);
		}
		if (mapper.Manifest.DynamicConfig) {
			final err = host.openProject(entry);
			if (err != null) {
				return new ValueError("", err);
			}
			return new ValueError(Hostimpl.combinedIdentity(mapper, entry.configIdentity, entry.spec.CompilerOptions), null);
		}
		return new ValueError(mapper.Identity() + ":" + mapper.TransformIdentity(entry.spec.CompilerOptions), null);
	}

	public function WatchedFiles():ValueError<Slice<String>> {
		if (projects() == null) {
			return new ValueError(null, null);
		}
		var files:Array<String> = [];
		for (mapper in mappers) {
			final entry = projects().get(entries.get(mapper));
			if (entry == null) {
				continue;
			}
			if (entry.mapper.Manifest.DynamicConfig) {
				final err = host.openProject(entry);
				if (err != null) {
					return new ValueError(null, err);
				}
			}
			if (entry.watchedFiles != null)
				files = files.concat(entry.watchedFiles.toArray());
		}
		Slices.SortStrings(files);
		return new ValueError(Slices.CompactFunc(files, (a, b) -> a == b), null);
	}

	public function Diagnostics():Slice<OptionDiagnostic> {
		if (projects() == null) {
			return null;
		}
		var diagnostics:Slice<OptionDiagnostic> = null;
		for (mapper in mappers) {
			final entry = projects().get(entries.get(mapper));
			if (entry == null) {
				continue;
			}
			if (!entry.opened) {
				continue;
			}
			if (entry.optionDiagnostics != null && entry.optionDiagnostics.length > 0) {
				if (diagnostics == null)
					diagnostics = [];
				for (d in entry.optionDiagnostics)
					diagnostics.push(d);
			}
		}
		return diagnostics;
	}

	public function Transform(mapper:Mapper, request:Request):ValueError<Result> {
		final key = entries.get(mapper);
		final entry = projects() == null || key == null ? null : projects().get(key);
		if (entry == null) {
			return new ValueError(null, Errors.New("content mapper project is closed"));
		}
		final err = host.openProject(entry);
		if (err != null) {
			if (Std.isOfType(err, InitializeError)) {
				return new ValueError(null, Contentmapper.NewTransformError(TransformErrorKindInitialize, err));
			}
			return new ValueError(null, Contentmapper.NewTransformError(TransformErrorKindProject, err));
		}
		return host.transform(mapper, request, entry.projectHandle);
	}

	public function Close():Null<Error> {
		if (closed)
			return null;
		closed = true;
		return release();
	}

	public function release():Null<Error> {
		var result:Null<Error> = null;
		final releasedIdentities:Array<String> = [];
		refs--;
		if (refs < 0) {
			throw "content mapper project reference count below zero";
		}
		if (refs != 0) {
			return null;
		}
		final leases = @:privateAccess host.projectLeases;
		if (leases != null && leases.get(key) == this) {
			leases.remove(key);
		}
		if (projects() == null) {
			return null;
		}
		for (mapper in mappers) {
			final entryKey = entries.get(mapper);
			final entry = projects().get(entryKey);
			if (entry == null) {
				continue;
			}
			if (entry.opened) {
				final connEntry = @:privateAccess host.conns.get(entry.mapper.Identity());
				if (connEntry != null && connEntry.conn != null) {
					final err = host.closeProject(entry.mapper, connEntry.conn, entry.projectHandle);
					if (err != null)
						result = err;
				}
			}
			projects().remove(entryKey);
			releasedIdentities.push(entry.mapper.Identity());
		}
		host.release(releasedIdentities);
		return result;
	}
}

private class RetainedProject implements Project {
	final lease:ProjectLease;
	var closed:Bool = false;

	public function new(lease:ProjectLease) {
		this.lease = lease;
	}

	public function Refresh():Null<Error>
		return lease.Refresh();

	public function Identities():ValueError<Slice<String>>
		return lease.Identities();

	public function Identity(mapper:Mapper):ValueError<String>
		return lease.Identity(mapper);

	public function WatchedFiles():ValueError<Slice<String>>
		return lease.WatchedFiles();

	public function Diagnostics():Slice<OptionDiagnostic>
		return lease.Diagnostics();

	public function Transform(mapper:Mapper, request:Request):ValueError<Result>
		return lease.Transform(mapper, request);

	public function Close():Null<Error> {
		if (closed)
			return null;
		closed = true;
		return lease.release();
	}
}

// positionNormalizer converts mapper positions to the port's UTF-16 offsets.
// PORT: Go normalizes to UTF-8 byte offsets; the port's positions are UTF-16 code units, so UTF-16 is the
// identity and UTF-8 offsets are converted.
class PositionNormalizer {
	final text:String;
	final encoding:String;
	final length:Int;
	// UTF-8 byte offset of each UTF-16 offset (only for utf-8; null when the text is ASCII)
	var byteToUtf16:Null<haxe.ds.IntMap<Int>> = null;

	function new(text:String, encoding:String, length:Int) {
		this.text = text;
		this.encoding = encoding;
		this.length = length;
	}

	public static function create(text:String, encoding:String):ValueError<PositionNormalizer> {
		switch (encoding) {
			case Hostimpl.PositionEncodingUTF8:
				final n = new PositionNormalizer(text, encoding, go.Utf8.ByteLen(text));
				if (n.length != text.length) {
					// build the byte offset → UTF-16 offset table at code point boundaries
					final m = new haxe.ds.IntMap<Int>();
					var bytePos = 0;
					var i = 0;
					while (i < text.length) {
						m.set(bytePos, i);
						final c = StringTools.fastCodeAt(text, i);
						if (c >= 0xD800 && c <= 0xDBFF && i + 1 < text.length) {
							bytePos += 4;
							i += 2;
						} else {
							bytePos += c < 0x80 ? 1 : c < 0x800 ? 2 : 3;
							i++;
						}
					}
					m.set(bytePos, text.length);
					n.byteToUtf16 = m;
				}
				return new ValueError(n, null);
			case Hostimpl.PositionEncodingUTF16:
				return new ValueError(new PositionNormalizer(text, encoding, text.length), null);
			default:
				return new ValueError(null, Errors.New('unsupported position encoding ${Json.Quote(encoding)}'));
		}
	}

	public function normalize(position:Int):ValueError<Int> {
		if (position < 0) {
			return new ValueError(0, Errors.New('position ${position} is negative'));
		}
		if (position > length) {
			return new ValueError(0, Errors.New('position ${position} exceeds ${encoding} length ${length}'));
		}
		var utf16Position = position;
		if (byteToUtf16 != null) {
			final p = byteToUtf16.get(position);
			if (p == null) {
				return new ValueError(0, Errors.New('position ${position} splits a Unicode code point'));
			}
			utf16Position = p;
		} else if (encoding == Hostimpl.PositionEncodingUTF16 && position > 0 && position < text.length) {
			final c = StringTools.fastCodeAt(text, position);
			if (c >= 0xDC00 && c <= 0xDFFF) {
				final prev = StringTools.fastCodeAt(text, position - 1);
				if (prev >= 0xD800 && prev <= 0xDBFF)
					return new ValueError(0, Errors.New('position ${position} splits a Unicode code point'));
			}
		}
		return new ValueError(utf16Position, null);
	}
}
