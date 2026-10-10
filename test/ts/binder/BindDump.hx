package ts.binder;

import go.Utf8;
import haxe.ds.ObjectMap;
import ts.ast.Ast;
import ts.ast.Flow;
import ts.ast.KindGenerated.Kind;
import ts.ast.Nodeflags.NodeFlags;
import ts.ast.Parseoptions.SourceFileParseOptions;
import ts.ast.Symbol;
import ts.core.Core;
import ts.locale.Locale;
import ts.parser.Parser;

// Haxe counterpart of tools/dump/bind/main.go (Phase 4 gate): parses and binds each file and
// prints the binder's results in exactly the same format.
//
// Usage: BindDump FILE... | @LISTFILE (one path per line)
// Output per file: "## <file>", then
//   one line per node (ForEachChild pre-order, JSDoc nodes as in AstDump, marked "@jsdoc "):
//     <2*depth spaces><Kind> <pos> <end> <NodeFlags>[ sym=#S][ locals=#S,#S..][ flow=#F][ end=#F][ ret=#F][ fall=#F]
//   then the symbols, numbered in order of first reference (node order; locals, members and
//   exports in name order, Go byte order of the UTF-8 names):
//     S #S <name> <SymbolFlags> decls=<Kind@pos,..> value=<Kind@pos|-> parent=<#S|-> export=<#S|-> members=<#S,..> exports=<#S,..>
//   then the flow nodes, numbered in order of first reference (node order, then antecedents):
//     F #F <FlowFlags> node=<Kind@pos|-> ante=<#F|-> antes=<#F,..>
//   then the bind diagnostics:
//     D <code> <pos> <len> <message>
// Positions are UTF-16 code-unit offsets (the port's native positions).
class BindDump {
	static var out:StringBuf = new StringBuf();

	// Bind-only time in ms (sum over all files), printed to stderr with -t.
	static var bindMs:Float = 0;

	static function main() {
		final files:Array<String> = [];
		var timing = false;
		for (arg in Sys.args()) {
			if (arg == "-t") {
				timing = true;
			} else if (StringTools.startsWith(arg, "@")) {
				for (line in sys.io.File.getContent(arg.substring(1)).split("\n")) {
					final l = StringTools.trim(line);
					if (l != "")
						files.push(l);
				}
			} else {
				files.push(arg);
			}
		}
		for (file in files) {
			final data = sys.io.File.getBytes(file);
			dump(file, Utf8.BytesToString(data, 0, data.length));
		}
		flush();
		if (timing) {
			Sys.stderr().writeString('bind ms: ${Math.round(bindMs)}\n');
		}
	}

	// Writes the buffered output (like Go's bufio.Writer) about every 64 KiB.
	static var pending = 0;

	static function flush() {
		pending = 0;
		Sys.stdout().writeString(out.toString());
		out = new StringBuf();
	}

	static var sf:SourceFile = null;
	static var depth = 0;
	static var walkChild:(node:Node) -> Bool = null;
	static var symIds:ObjectMap<Symbol, Int> = null;
	static var syms:Array<Symbol> = null;
	static var flowIds:ObjectMap<FlowNode, Int> = null;
	static var flows:Array<FlowNode> = null;

	static function dump(file:String, text:String) {
		out.add("## ");
		out.add(file);
		out.addChar("\n".code);
		symIds = new ObjectMap();
		syms = [];
		flowIds = new ObjectMap();
		flows = [];
		final opts = new SourceFileParseOptions();
		opts.FileName = file;
		opts.Path = file;
		sf = Parser.ParseSourceFile(opts, text, Core.GetScriptKindFromFileName(file));
		final t0 = haxe.Timer.stamp();
		Binder.BindSourceFile(sf);
		bindMs += (haxe.Timer.stamp() - t0) * 1000;
		if (walkChild == null) {
			walkChild = function(child:Node):Bool {
				depth++;
				walk(child, "");
				depth--;
				return false;
			};
		}
		depth = 0;
		walk(sf.AsNode(), "");
		var i = 0;
		while (i < syms.length) { // syms grows while printing
			final b = out;
			final s = syms[i];
			b.add("S #");
			b.add(i);
			b.addChar(" ".code);
			escape(b, s.Name);
			b.addChar(" ".code);
			b.add((s.Flags : Int));
			b.add(" decls=");
			if (s.Declarations != null) {
				for (j in 0...s.Declarations.length) {
					if (j > 0)
						b.addChar(",".code);
					at(b, s.Declarations[j]);
				}
			}
			b.add(" value=");
			at(b, s.ValueDeclaration);
			b.add(" parent=");
			symRef(b, s.Parent);
			b.add(" export=");
			symRef(b, s.ExportSymbol);
			b.add(" members=");
			table(b, s.Members);
			b.add(" exports=");
			table(b, s.Exports);
			b.addChar("\n".code);
			i++;
			pending += 128;
			if (pending > (1 << 16))
				flush();
		}
		i = 0;
		while (i < flows.length) { // flows grows while printing
			final b = out;
			final f = flows[i];
			b.add("F #");
			b.add(i);
			b.addChar(" ".code);
			b.add((f.Flags : Int));
			b.add(" node=");
			at(b, f.Node);
			b.add(" ante=");
			flowRef(b, f.Antecedent);
			b.add(" antes=");
			var l = f.Antecedents;
			var first = true;
			while (l != null) {
				if (!first)
					b.addChar(",".code);
				first = false;
				flowRef(b, l.Flow);
				l = l.Next;
			}
			b.addChar("\n".code);
			i++;
			pending += 64;
			if (pending > (1 << 16))
				flush();
		}
		final diags = sf.BindDiagnostics();
		if (diags != null) {
			final b = out;
			for (d in diags) {
				b.add("D ");
				b.add(d.Code());
				b.addChar(" ".code);
				b.add(d.Pos());
				b.addChar(" ".code);
				b.add(d.End() - d.Pos());
				b.addChar(" ".code);
				escape(b, d.Localize(Locale.Default));
				b.addChar("\n".code);
			}
		}
		sf = null;
		symIds = null;
		syms = null;
		flowIds = null;
		flows = null;
	}

	// Appends 2*depth spaces (Go strings.Repeat("  ", depth)) from one shared string of spaces.
	static var spaces = "  ";

	static function indent(b:StringBuf, depth:Int):Void {
		while (spaces.length < 2 * depth) {
			spaces += spaces;
		}
		b.addSub(spaces, 0, 2 * depth);
	}

	static function walk(node:Node, mark:String):Void {
		final b = out;
		indent(b, depth);
		b.add(mark);
		b.add(node.Kind.String());
		b.addChar(" ".code);
		b.add(node.Pos());
		b.addChar(" ".code);
		b.add(node.End());
		b.addChar(" ".code);
		b.add((node.Flags : Int));
		final s = symbolOf(node);
		if (s != null) {
			b.add(" sym=");
			symRef(b, s);
		}
		final locals = localsOf(node);
		if (locals != null && locals.keys().hasNext()) {
			b.add(" locals=");
			table(b, locals);
		}
		final fd = node.FlowNodeData();
		if (fd != null && fd.FlowNode != null) {
			b.add(" flow=");
			flowRef(b, fd.FlowNode);
		}
		final bd = node.BodyData();
		if (bd != null && bd.EndFlowNode != null) {
			b.add(" end=");
			flowRef(b, bd.EndFlowNode);
		}
		if (node.Kind == KindSourceFile && sf.EndFlowNode != null) {
			b.add(" end=");
			flowRef(b, sf.EndFlowNode);
		}
		var ret:FlowNode = null;
		switch (node.Kind) {
			case KindFunctionDeclaration:
				ret = node.AsFunctionDeclaration().ReturnFlowNode;
			case KindConstructor:
				ret = node.AsConstructorDeclaration().ReturnFlowNode;
			case KindClassStaticBlockDeclaration:
				ret = node.AsClassStaticBlockDeclaration().ReturnFlowNode;
			case KindFunctionExpression:
				ret = node.AsFunctionExpression().ReturnFlowNode;
			case KindCaseClause | KindDefaultClause:
				final f = node.AsCaseOrDefaultClause().FallthroughFlowNode;
				if (f != null) {
					b.add(" fall=");
					flowRef(b, f);
				}
			default:
		}
		if (ret != null) {
			b.add(" ret=");
			flowRef(b, ret);
		}
		b.addChar("\n".code);
		pending += 2 * depth + 64;
		if (pending > (1 << 16)) {
			flush();
		}
		if (node.Flags & NodeFlagsHasJSDoc != 0) {
			final jsdocs = node.AsNode().JSDoc(sf);
			if (jsdocs != null) {
				for (jsdoc in jsdocs) {
					depth++;
					walk(jsdoc, "@jsdoc ");
					depth--;
				}
			}
		}
		node.ForEachChild(walkChild);
	}

	// symbolOf returns the symbol the binder stored on the node, without the checker's fallbacks.
	static function symbolOf(node:Node):Symbol {
		final data = node.DeclarationData();
		if (data != null) {
			return data.Symbol;
		}
		if (node.Kind == KindSourceFile) {
			return node.AsSourceFile().Symbol;
		}
		return null;
	}

	static function localsOf(node:Node):SymbolTable {
		final data = node.LocalsContainerData();
		if (data != null) {
			return data.Locals;
		}
		return null;
	}

	static function symRef(b:StringBuf, s:Symbol):Void {
		if (s == null) {
			b.addChar("-".code);
			return;
		}
		var id = symIds.get(s);
		if (id == null) {
			id = syms.length;
			symIds.set(s, id);
			syms.push(s);
		}
		b.addChar("#".code);
		b.add(id);
	}

	static function table(b:StringBuf, t:SymbolTable):Void {
		if (t == null) {
			return;
		}
		final names = [for (name in t.keys()) name];
		names.sort(goCompare);
		for (i in 0...names.length) {
			if (i > 0)
				b.addChar(",".code);
			symRef(b, t.get(names[i]));
		}
	}

	// Go byte order of the UTF-8 names: code-point order, except that Go's internal symbol name
	// prefix is the byte 0xFE, which sorts after every UTF-8 lead byte. The port stores the prefix
	// as U+FFFE, so U+FFFE sorts after every code point here.
	static function goCompare(a:String, b:String):Int {
		var i = 0;
		var j = 0;
		while (i < a.length && j < b.length) {
			final ca = codePointAt(a, i);
			final cb = codePointAt(b, j);
			if (ca != cb) {
				final ka = ca == 0xFFFE ? 0x110000 : ca;
				final kb = cb == 0xFFFE ? 0x110000 : cb;
				return ka < kb ? -1 : 1;
			}
			i += ca >= 0x10000 ? 2 : 1;
			j += cb >= 0x10000 ? 2 : 1;
		}
		final ra = a.length - i;
		final rb = b.length - j;
		return ra == rb ? 0 : (ra < rb ? -1 : 1);
	}

	static function codePointAt(s:String, i:Int):Int {
		final c = StringTools.fastCodeAt(s, i);
		if (c >= 0xD800 && c < 0xDC00 && i + 1 < s.length) {
			final d = StringTools.fastCodeAt(s, i + 1);
			if (d >= 0xDC00 && d < 0xE000) {
				return 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00);
			}
		}
		return c;
	}

	static function flowRef(b:StringBuf, f:FlowNode):Void {
		if (f == null) {
			b.addChar("-".code);
			return;
		}
		var id = flowIds.get(f);
		if (id == null) {
			id = flows.length;
			flowIds.set(f, id);
			flows.push(f);
		}
		b.addChar("#".code);
		b.add(id);
	}

	static function at(b:StringBuf, node:Node):Void {
		if (node == null) {
			b.addChar("-".code);
			return;
		}
		b.add(node.Kind.String());
		b.addChar("@".code);
		b.add(node.Pos());
	}

	static inline final hexDigits = "0123456789ABCDEF";

	static function escape(b:StringBuf, v:String) {
		b.addChar('"'.code);
		for (i in 0...v.length) {
			final c = StringTools.fastCodeAt(v, i);
			if (c == "\n".code) {
				b.add("\\n");
			} else if (c == "\r".code) {
				b.add("\\r");
			} else if (c == "\t".code) {
				b.add("\\t");
			} else if (c == "\\".code) {
				b.add("\\\\");
			} else if (c == '"'.code) {
				b.add('\\"');
			} else if (c < 0x20 || c > 0x7E) {
				b.add("\\u");
				b.addChar(StringTools.fastCodeAt(hexDigits, (c >> 12) & 15));
				b.addChar(StringTools.fastCodeAt(hexDigits, (c >> 8) & 15));
				b.addChar(StringTools.fastCodeAt(hexDigits, (c >> 4) & 15));
				b.addChar(StringTools.fastCodeAt(hexDigits, c & 15));
			} else {
				b.addChar(c);
			}
		}
		b.addChar('"'.code);
	}
}
