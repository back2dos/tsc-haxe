package ts.testutil.contentmappertest;

import go.Errors;
import go.Errors.Error;
import go.Tuple;
import haxe.ds.StringMap;
import ts.collections.OrderedMap;
import ts.contentmapper.Hostimpl;
import ts.json.Json;
import ts.spanmap.Spanmap;
import ts.spanmap.Spanmap.Feature.*;
import ts.spanmap.Spanmap.Kind.*;

// Port of internal/testutil/contentmappertest (TypeScript main): realistic content mapper implementations
// used by tests, served in-process.
// PORT: only the mappers used by the compiler test corpus are ported (compiler-test-mapper, failing-mapper,
// lisp-mapper and the supplemental mappers); the others serve LSP/unit tests. The in-process connection
// passes the protocol structs directly (see Hostimpl.hx), so handlers receive typed params.
class Contentmappertest {
	// --- registry.go ---
	public static inline final TransformingMapper = "compiler-test-mapper";
	public static inline final FailingMapper = "failing-mapper";
	public static inline final LispMapper = "lisp-mapper";
	public static inline final SupplementalMapper = "supplemental-mapper";
	public static inline final SupplementalDiagnosticsMapper = "supplemental-diagnostics-mapper";
	public static inline final SupplementalGlobalsMapper = "supplemental-globals-mapper";
	public static inline final SupplementalModuleMapper = "supplemental-module-mapper";

	static function handlerForMapper(command:Slice<String>):ValueError<Handler> {
		if (command == null || command.length == 0) {
			return new ValueError(null, Errors.New("contentmappertest: empty mapper command"));
		}
		final handler:Handler = switch (command[0]) {
			case TransformingMapper: new TransformingHandler();
			case FailingMapper: new FailingHandler();
			case LispMapper: new LispHandler();
			case SupplementalMapper: new SupplementalHandler();
			case SupplementalDiagnosticsMapper: new SupplementalDiagnosticsHandler();
			case SupplementalGlobalsMapper: new SupplementalGlobalsHandler();
			case SupplementalModuleMapper: new SupplementalModuleHandler();
			default: null;
		}
		if (handler == null) {
			return new ValueError(null, Errors.New('contentmappertest: unknown mapper command [${command.join(" ")}]'));
		}
		return new ValueError(handler, null);
	}

	// --- spawner.go ---

	// NewSpawner returns an in-process spawner for the test mapper implementations.
	public static function NewSpawner():Spawner {
		return new InProcessSpawner();
	}

	// --- protocol.go ---

	public static function initializeResult(source:String):InitializeResult {
		// PORT: the port's test mappers compute UTF-16 offsets (Haxe strings), so they select utf-16 (Go: utf-8 byte offsets).
		return new InitializeResult(Hostimpl.PositionEncodingUTF16, source);
	}

	public static function identityMappedOutput(content:String):MappedOutput {
		final mappings = Spanmap.New([new Segment(0, content.length, 0, content.length, KindVerbatim, FeatureAll)]).Marshal();
		return new MappedOutput(content, ".ts", mappings);
	}

	public static function unexpectedMethod(method:String):ValueError<Dynamic> {
		return new ValueError(null, Errors.New('contentmappertest: unexpected method ${Json.Quote(method)}'));
	}
}

private class InProcessSpawner implements Spawner {
	public function new() {}

	public function Spawn(command:Slice<String>, dir:String):ValueError<Handler> {
		final h = @:privateAccess Contentmappertest.handlerForMapper(command);
		if (h.err != null) {
			return h;
		}
		return new ValueError((new StaticProjectHandler(h.value) : Handler), null);
	}
}

interface ProjectLifecycleHandler {
	function OpenProject(params:OpenProjectParams):Null<Error>;
	function CloseProject(params:CloseProjectParams):Void;
}

// staticProjectHandler (protocol.go)
private class StaticProjectHandler implements Handler {
	final Handler:Handler;

	public function new(handler:Handler) {
		this.Handler = handler;
	}

	public function HandleRequest(ctx:go.Context, method:String, params:Dynamic):ValueError<Dynamic> {
		switch (method) {
			case Hostimpl.MethodOpenProject:
				final p:OpenProjectParams = params;
				if (Std.isOfType(this.Handler, ProjectLifecycleHandler)) {
					final err = (cast this.Handler : ProjectLifecycleHandler).OpenProject(p);
					if (err != null) {
						return new ValueError(null, err);
					}
				}
				var diagnostics:Slice<OptionDiagnosticResult> = null;
				if (p.Options == '{"plugins":[{"name":1}]}') {
					final d = new OptionDiagnosticResult();
					d.Path = ['"plugins"', '0', '"name"'];
					d.MessageText = "Option 'name' requires a string.";
					d.Code = 123;
					diagnostics = [d];
				}
				final result = new OpenProjectResult();
				result.OptionDiagnostics = diagnostics;
				return new ValueError(result, null);
			case Hostimpl.MethodCloseProject:
				final p:CloseProjectParams = params;
				if (Std.isOfType(this.Handler, ProjectLifecycleHandler)) {
					(cast this.Handler : ProjectLifecycleHandler).CloseProject(p);
				}
				return new ValueError(null, null);
			default:
				return this.Handler.HandleRequest(ctx, method, params);
		}
	}
}

// --- transforming.go ---

// Handler implements the transforming content mapper protocol.
class TransformingHandler implements Handler implements ProjectLifecycleHandler {
	static inline final preamble = "const __VERSION = \"1.0.0\";\n";
	static inline final diagnosticSource = "box";
	static inline final unclosedInterpolationCode = 1000;

	// PORT: OrderedMap<String, json.Value> with the raw JSON texts of the options
	var compilerOptions:StringMap<OrderedMap<String, String>> = null;

	public function new() {}

	public function OpenProject(p:OpenProjectParams):Null<Error> {
		var options:OrderedMap<String, String> = null;
		final decoded:Dynamic = try Json.UnmarshalOrdered(p.CompilerOptions) catch (e:Dynamic) return Errors.New(Std.string(e));
		if (decoded != null) {
			options = new OrderedMap<String, String>("");
			final m:OrderedMap<String, Dynamic> = decoded;
			for (k => v in m.Entries()) {
				options.Set(k, Json.MarshalOrdered(v));
			}
		}
		if (compilerOptions == null) {
			compilerOptions = new StringMap();
		}
		compilerOptions.set(p.ProjectHandle, options);
		return null;
	}

	public function CloseProject(p:CloseProjectParams):Void {
		if (compilerOptions != null)
			compilerOptions.remove(p.ProjectHandle);
	}

	public function HandleRequest(ctx:go.Context, method:String, params:Dynamic):ValueError<Dynamic> {
		switch (method) {
			case Hostimpl.MethodInitialize:
				return new ValueError(Contentmappertest.initializeResult(diagnosticSource), null);
			case Hostimpl.MethodTransform:
				final p:TransformParams = params;
				final options = compilerOptions == null ? null : compilerOptions.get(p.ProjectHandle);
				if (options == null) {
					return new ValueError(null, Errors.New('contentmappertest: project ${Json.Quote(p.ProjectHandle)} is not open'));
				}
				final result = transform(p.Content, options);
				result.Extension = mappedExtension(p.Content);
				return new ValueError(result, null);
			default:
				return Contentmappertest.unexpectedMethod(method);
		}
	}

	static function mappedExtension(content:String):String {
		final prefix = "// @box-extension:";
		final nl = content.indexOf("\n");
		if (nl >= 0) {
			final firstLine = content.substring(0, nl);
			if (StringTools.startsWith(firstLine, prefix)) {
				return go.Strings.TrimSpace(firstLine.substring(prefix.length));
			}
		}
		return ".ts";
	}

	static function transform(content:String, options:OrderedMap<String, String>):TransformResult {
		final virtual = new StringBuf();
		var virtualLen = 0;
		final segments:Array<Segment> = [];
		var diagnostics:Slice<ProtocolDiagnostic> = null;

		function write(s:String) {
			virtual.add(s);
			virtualLen += s.length;
		}

		write(preamble);

		function writeVerbatim(from:Int, to:Int) {
			if (to <= from) {
				return;
			}
			final virtualStart = virtualLen;
			write(content.substring(from, to));
			segments.push(new Segment(virtualStart, virtualLen, from, to, KindVerbatim, FeatureAll));
		}

		function writeAtom(value:String, from:Int, to:Int) {
			final virtualStart = virtualLen;
			write(value);
			segments.push(new Segment(virtualStart, virtualLen, from, to, KindAtom, FeatureAll));
		}

		var pos = 0;
		while (pos < content.length) {
			final tokenStart = content.indexOf("#{", pos);
			if (tokenStart < 0) {
				writeVerbatim(pos, content.length);
				break;
			}
			var lineEnd = content.indexOf("\n", tokenStart);
			if (lineEnd < 0) {
				lineEnd = content.length;
			}
			final close = content.substring(tokenStart, lineEnd).indexOf("}");
			if (close < 0) {
				writeVerbatim(pos, tokenStart);
				writeAtom("undefined", tokenStart, lineEnd);
				if (diagnostics == null)
					diagnostics = [];
				diagnostics.push(new ProtocolDiagnostic("Unclosed interpolation.", tokenStart, lineEnd - tokenStart, unclosedInterpolationCode));
				pos = lineEnd;
				continue;
			}
			final tokenEnd = tokenStart + close + 1;
			final name = content.substring(tokenStart + "#{".length, tokenEnd - "}".length);

			writeVerbatim(pos, tokenStart);
			writeAtom(renderOption(options, name), tokenStart, tokenEnd);
			pos = tokenEnd;
		}

		final spanMap = Spanmap.New(segments);
		final result = new TransformResult(virtual.toString(), "", spanMap.Marshal());
		result.Diagnostics = diagnostics;
		result.DiagnosticDirectives = diagnosticDirectives(content, spanMap);
		return result;
	}

	static function directive(originalStart:Int = 0, originalLength:Int = 0, virtualStart:Int = 0, virtualEnd:Int = 0, policy:Int = 0,
			?unusedIndex:Int):ProtocolDiagnosticDirective {
		final d = new ProtocolDiagnosticDirective();
		d.OriginalStart = originalStart;
		d.OriginalLength = originalLength;
		d.VirtualStart = virtualStart;
		d.VirtualEnd = virtualEnd;
		d.Policy = policy;
		d.UnusedExpectDirectiveIndex = unusedIndex;
		return d;
	}

	static function diagnosticDirectives(content:String, mappings:Spanmap):Null<DiagnosticDirectives> {
		function wrap(directives:Array<ProtocolDiagnosticDirective>, ?unused:Slice<UnusedExpectDirectiveDiagnostic>):DiagnosticDirectives {
			return new DiagnosticDirectives(directives, unused);
		}
		final invalidPrefix = "// @box-invalid-directive:";
		if (StringTools.startsWith(content, invalidPrefix)) {
			final nl = content.indexOf("\n");
			final firstLine = nl < 0 ? content : content.substring(0, nl);
			switch (go.Strings.TrimSpace(firstLine.substring(invalidPrefix.length))) {
				case "invalid-range":
					return wrap([directive(0, 0, -1, 0, Hostimpl.DiagnosticDirectivePolicyIgnore)]);
				case "original-range-out-of-bounds":
					return wrap([directive(content.length + 1, 0, 0, 0, Hostimpl.DiagnosticDirectivePolicyIgnore)]);
				case "virtual-range-out-of-bounds":
					return wrap([directive(0, 0, 1 << 20, 1 << 20, Hostimpl.DiagnosticDirectivePolicyIgnore)]);
				case "invalid-policy":
					return wrap([directive(0, 0, 0, 0, 2)]);
				case "ignore-with-unused-diagnostic":
					return wrap([directive(0, 0, 0, 0, Hostimpl.DiagnosticDirectivePolicyIgnore)], [new UnusedExpectDirectiveDiagnostic()]);
				case "expect-without-unused-diagnostic":
					return wrap([directive(0, 0, 0, 0, Hostimpl.DiagnosticDirectivePolicyExpect)]);
				case "invalid-unused-diagnostic-index":
					return wrap([directive(0, 0, 0, 0, Hostimpl.DiagnosticDirectivePolicyExpect, 1)], [new UnusedExpectDirectiveDiagnostic()]);
				case "overlap":
					return wrap([
						directive(0, 0, 0, 2, Hostimpl.DiagnosticDirectivePolicyIgnore),
						directive(0, 0, 1, 3, Hostimpl.DiagnosticDirectivePolicyIgnore)
					]);
				default:
			}
		}
		final ignorePrefix = "// @box-ignore";
		final expectPrefix = "// @box-expect-error";
		final result:Array<ProtocolDiagnosticDirective> = [];
		final unusedDiagnostics:Array<UnusedExpectDirectiveDiagnostic> = [];
		var lineStart = 0;
		while (lineStart < content.length) {
			var lineEnd = content.indexOf("\n", lineStart);
			if (lineEnd < 0) {
				lineEnd = content.length;
			}
			final line = content.substring(lineStart, lineEnd);
			final trimmed = go.Strings.TrimSpace(line);
			var policy = 0;
			var hasPolicy = false;
			var unusedDiagnosticIndex = -1;
			if (trimmed == ignorePrefix) {
				policy = Hostimpl.DiagnosticDirectivePolicyIgnore;
				hasPolicy = true;
			} else if (StringTools.startsWith(trimmed, expectPrefix + ":")) {
				policy = Hostimpl.DiagnosticDirectivePolicyExpect;
				hasPolicy = true;
				unusedDiagnosticIndex = unusedDiagnostics.length;
				unusedDiagnostics.push(new UnusedExpectDirectiveDiagnostic(2578, go.Strings.TrimSpace(trimmed.substring((expectPrefix + ":").length))));
			}
			if (hasPolicy && lineEnd < content.length) {
				final affectedStart = lineEnd + 1;
				var affectedLength = content.indexOf("\n", affectedStart);
				if (affectedLength < 0) {
					affectedLength = content.length - affectedStart;
				} else {
					affectedLength -= affectedStart;
				}
				final virtualSpans = Spanmap.OriginalToVirtualSpans(mappings, ts.core.Core.NewTextRange(affectedStart, affectedStart + affectedLength), FeatureAll);
				if (virtualSpans != null && virtualSpans.length == 1) {
					final d = directive(lineStart, lineEnd - lineStart, virtualSpans[0].Span.Pos(), virtualSpans[0].Span.End(), policy);
					if (unusedDiagnosticIndex >= 0) {
						d.UnusedExpectDirectiveIndex = unusedDiagnosticIndex;
					}
					result.push(d);
				}
			}
			if (lineEnd == content.length) {
				break;
			}
			lineStart = lineEnd + 1;
		}
		if (unusedDiagnostics.length == 1) {
			for (d in result) {
				d.UnusedExpectDirectiveIndex = null;
			}
		}
		if (result.length == 0 && unusedDiagnostics.length == 0) {
			return null;
		}
		return wrap(result, unusedDiagnostics);
	}

	static function renderOption(options:Null<OrderedMap<String, String>>, name:String):String {
		if (options != null) {
			final r = options.Get(name);
			if (r.ok && r.value.length > 0) {
				return r.value;
			}
		}
		return "undefined";
	}
}

// --- failing.go ---
private class FailingHandler implements Handler {
	public function new() {}

	public function HandleRequest(ctx:go.Context, method:String, params:Dynamic):ValueError<Dynamic> {
		switch (method) {
			case Hostimpl.MethodInitialize:
				return new ValueError(Contentmappertest.initializeResult("mapper"), null);
			case Hostimpl.MethodTransform:
				return new ValueError(null, Errors.New("content mapper failed to transform the file"));
			default:
				return Contentmappertest.unexpectedMethod(method);
		}
	}
}

// --- lisp.go ---
private class LispHandler implements Handler {
	public function new() {}

	public function HandleRequest(ctx:go.Context, method:String, params:Dynamic):ValueError<Dynamic> {
		switch (method) {
			case Hostimpl.MethodInitialize:
				return new ValueError(Contentmappertest.initializeResult("lisp"), null);
			case Hostimpl.MethodTransform:
				final p:TransformParams = params;
				final content = StringTools.endsWith(p.Content, "\n") ? p.Content.substring(0, p.Content.length - 1) : p.Content;
				if (content != '(+ 1 2 "oops")') {
					return new ValueError(null, Errors.New('contentmappertest: unsupported Lisp expression ${Json.Quote(p.Content)}'));
				}
				final mappings = Spanmap.New([
					new Segment(0, 3, 1, 2, KindAlias, FeatureAll),
					new Segment(4, 5, 3, 4, KindVerbatim, FeatureAll),
					new Segment(7, 8, 5, 6, KindVerbatim, FeatureAll),
					new Segment(10, 16, 7, 13, KindVerbatim, FeatureAll),
				]).Marshal();
				return new ValueError(new TransformResult('add(1, 2, "oops");', ".ts", mappings), null);
			default:
				return Contentmappertest.unexpectedMethod(method);
		}
	}
}

// --- supplemental.go ---
private class SupplementalHandler implements Handler {
	public function new() {}

	public function HandleRequest(ctx:go.Context, method:String, params:Dynamic):ValueError<Dynamic> {
		switch (method) {
			case Hostimpl.MethodInitialize:
				return new ValueError(Contentmappertest.initializeResult("mapper"), null);
			case Hostimpl.MethodTransform:
				final p:TransformParams = params;
				final result = new TransformResult("export {};", ".ts");
				result.Supplemental = [Contentmappertest.identityMappedOutput(p.Content)];
				return new ValueError(result, null);
			default:
				return Contentmappertest.unexpectedMethod(method);
		}
	}
}

// --- supplemental_diagnostics.go ---
private class SupplementalDiagnosticsHandler implements Handler {
	public function new() {}

	public function HandleRequest(ctx:go.Context, method:String, params:Dynamic):ValueError<Dynamic> {
		switch (method) {
			case Hostimpl.MethodInitialize:
				return new ValueError(Contentmappertest.initializeResult("mapper"), null);
			case Hostimpl.MethodTransform:
				final p:TransformParams = params;
				final prefix = "missingSupplementalGlobal;\n";
				final mappings = Spanmap.New([new Segment(prefix.length, prefix.length + p.Content.length, 0, p.Content.length, KindVerbatim, FeatureAll)])
					.Marshal();
				final result = new TransformResult("export {};", ".ts");
				result.Supplemental = [new MappedOutput(prefix + p.Content, ".ts", mappings)];
				return new ValueError(result, null);
			default:
				return Contentmappertest.unexpectedMethod(method);
		}
	}
}

// --- supplemental_globals.go ---
private class SupplementalGlobalsHandler implements Handler {
	public function new() {}

	public function HandleRequest(ctx:go.Context, method:String, params:Dynamic):ValueError<Dynamic> {
		switch (method) {
			case Hostimpl.MethodInitialize:
				return new ValueError(Contentmappertest.initializeResult("mapper"), null);
			case Hostimpl.MethodTransform:
				final p:TransformParams = params;
				var supplemental:String;
				if (StringTools.endsWith(p.FileName, "/a.vue")) {
					supplemental = "/// <reference path=\"./extra.d.ts\" />\ninterface Shared extends Extra { value: string }";
				} else if (StringTools.endsWith(p.FileName, "/b.vue")) {
					supplemental = "declare const shared: Shared;";
				} else {
					return new ValueError(null, Errors.New('contentmappertest: unexpected supplemental global input ${Json.Quote(p.FileName)}'));
				}
				final result = new TransformResult("export default shared.value;", ".ts");
				result.Supplemental = [new MappedOutput(supplemental, ".ts")];
				return new ValueError(result, null);
			default:
				return Contentmappertest.unexpectedMethod(method);
		}
	}
}

// --- supplemental_module.go ---
private class SupplementalModuleHandler implements Handler {
	public function new() {}

	public function HandleRequest(ctx:go.Context, method:String, params:Dynamic):ValueError<Dynamic> {
		switch (method) {
			case Hostimpl.MethodInitialize:
				return new ValueError(Contentmappertest.initializeResult("mapper"), null);
			case Hostimpl.MethodTransform:
				final result = new TransformResult("export default 1;", ".ts");
				result.Supplemental = [new MappedOutput('export const privateValue: number = "wrong";', ".ts")];
				return new ValueError(result, null);
			default:
				return Contentmappertest.unexpectedMethod(method);
		}
	}
}
