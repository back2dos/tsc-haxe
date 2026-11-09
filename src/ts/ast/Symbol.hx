package ts.ast;

import haxe.ds.StringMap;

// Port of symbol.go (types and methods; the InternalSymbolName* constants and the package
// functions are in Ast.hx).

// PORT: Go checker.TypeSystemEntity is `any` (a *Symbol, *Node, *Type or *Signature). Here it is an
// empty interface that these four classes implement, so a typed cast to it is valid on every target
// (the JVM checks every cast). ts.checker.Checker.TypeSystemEntity refers to it.
interface TypeSystemEntity {}

// Symbol
// PORT: perf — extends core.LinkHolder (the links of the checker's LinkStores, see there).
// PORT: perf — from TypeScript main (microsoft/typescript-go#64691, shared data symbols): a symbol's name,
// declarations, value declaration, parent and optional tables (Go's symbolData) are reached through `data`. A
// SymbolWithData (every symbol made with `new SymbolWithData()`) is its own data; an instantiated symbol
// (Symbol.NewSharedData, the checker's instantiateSymbol) shares its target's and is 40 B instead of 80. Go 7.0's
// instantiated symbol copied the four fields and had no tables: here the tables of a symbol whose data is shared
// read as nil, and a write to any of its data fields first gives it data of its own (a copy of the four fields).
class Symbol extends ts.core.Linkstore.LinkHolder implements TypeSystemEntity {
	public var Flags:SymbolFlags = 0;
	public var CheckFlags:CheckFlags = 0; // Non-zero only in transient symbols created by Checker
	// PORT: perf — no id field: Go's `id` is an entry of the links (Ast.GetSymbolId)
	var data:SymbolWithData = null;
	public var Name(get, set):String;
	public var Declarations(get, set):haxe.ds.Vector<Node>; // PORT: perf — a Vector (one exact-size object; an append makes a new one)
	public var ValueDeclaration(get, set):Node;
	public var Parent(get, set):Symbol;
	public var Members(get, set):SymbolTable;
	public var Exports(get, set):SymbolTable;
	public var ExportSymbol(get, set):Symbol;

	function new() {
		super();
	}

	// Go main's newSharedDataSymbol (without the flags): a symbol with other's data
	public static function NewSharedData(other:Symbol):Symbol {
		final s = new Symbol();
		s.data = other.data;
		return s;
	}

	// PORT: perf — no dataShared field (one Int fewer: Symbol 40 -> 32 B, SymbolWithData 80 -> 72): the data is
	// this symbol's when it is the symbol itself (a SymbolWithData) or the copy made for it (detach: a
	// DetachedSymbolData, which knows its owner; another symbol may share it)
	inline function dataShared():Bool {
		final d = data;
		return d != this && !isOwnCopy(d);
	}

	function isOwnCopy(d:SymbolWithData):Bool {
		final c = Std.downcast(d, DetachedSymbolData);
		return c != null && c.owner == this;
	}

	// the data to write to: a copy of the shared data's four fields first, for a symbol whose data is shared
	inline function own():SymbolWithData {
		if (dataShared()) {
			detach();
		}
		return data;
	}

	function detach():Void {
		final o = data;
		final d = new DetachedSymbolData(this);
		d.name = o.name;
		d.declarations = o.declarations;
		d.valueDeclaration = o.valueDeclaration;
		d.parent = o.parent;
		data = d;
	}

	inline function get_Name():String {
		return data.name;
	}

	function set_Name(v:String):String {
		return own().name = v;
	}

	inline function get_Declarations():haxe.ds.Vector<Node> {
		return data.declarations;
	}

	function set_Declarations(v:haxe.ds.Vector<Node>):haxe.ds.Vector<Node> {
		return own().declarations = v;
	}

	inline function get_ValueDeclaration():Node {
		return data.valueDeclaration;
	}

	function set_ValueDeclaration(v:Node):Node {
		return own().valueDeclaration = v;
	}

	inline function get_Parent():Symbol {
		return data.parent;
	}

	function set_Parent(v:Symbol):Symbol {
		return own().parent = v;
	}

	inline function get_Members():SymbolTable {
		final x = data.extra;
		return x == null || dataShared() ? null : x.members;
	}

	inline function get_Exports():SymbolTable {
		final x = data.extra;
		return x == null || dataShared() ? null : x.exports;
	}

	inline function get_ExportSymbol():Symbol {
		final x = data.extra;
		return x == null || dataShared() ? null : x.exportSymbol;
	}

	// the extra record to write to (null when v is nil and there is none: nothing to write)
	function extraFor(v:Dynamic):SymbolExtra {
		if (dataShared()) {
			if (v == null) {
				return null;
			}
			detach();
		}
		final d = data;
		if (d.extra == null && v != null) {
			d.extra = new SymbolExtra();
		}
		return d.extra;
	}

	function set_Members(v:SymbolTable):SymbolTable {
		final x = extraFor(v);
		if (x != null) {
			x.members = v;
		}
		return v;
	}

	function set_Exports(v:SymbolTable):SymbolTable {
		final x = extraFor(v);
		if (x != null) {
			x.exports = v;
		}
		return v;
	}

	function set_ExportSymbol(v:Symbol):Symbol {
		final x = extraFor(v);
		if (x != null) {
			x.exportSymbol = v;
		}
		return v;
	}

	public function IsExternalModule():Bool {
		return Flags & SymbolFlagsModule != 0 && Ast.IsAmbientModuleSymbolName(Name);
	}

	public function IsStatic():Bool {
		if (ValueDeclaration == null) {
			return false;
		}
		final modifierFlags = ValueDeclaration.ModifierFlags();
		return modifierFlags & ModifierFlagsStatic != 0;
	}

	// See comment on `declareModuleMember` in `binder.go`.
	public function CombinedLocalAndExportSymbolFlags():SymbolFlags {
		if (ExportSymbol != null) {
			return Flags | ExportSymbol.Flags;
		}
		return Flags;
	}
}

// A symbol with its own data (Go main's SymbolWithData): every symbol but the instantiated ones.
@:allow(ts.ast.Symbol)
class SymbolWithData extends Symbol {
	var name:String = "";
	var declarations:haxe.ds.Vector<Node> = null;
	var valueDeclaration:Node = null;
	var parent:Symbol = null;
	// PORT: perf — from TypeScript main (microsoft/typescript-go#64799, symbolExtra): the optional symbol tables
	// and the export symbol in a side record, allocated when one is set to a non-nil value
	var extra:SymbolExtra = null;

	public function new() {
		super();
		data = this;
	}
}

// The data a symbol whose data was shared made for itself (Symbol.detach) and its owner (Symbol.dataShared).
@:allow(ts.ast.Symbol)
class DetachedSymbolData extends SymbolWithData {
	final owner:Symbol;

	public function new(owner:Symbol) {
		super();
		this.owner = owner;
	}
}

class SymbolExtra {
	public var members:SymbolTable = null;
	public var exports:SymbolTable = null;
	public var exportSymbol:Symbol = null;

	public function new() {}
}

// SymbolTable
// PORT: perf — an abstract over the map (step 1 of the symbol-table representation change). With
// -D symtab_check every insertion and lookup checks that the key is the symbol's name.
@:forward(get, exists, remove, keys, size, reserve, clear, toString)
abstract SymbolTable(StringMap<Symbol>) from StringMap<Symbol> to StringMap<Symbol> {
	public inline function new(#if symtab_stats ?pos:haxe.PosInfos #end) {
		this = new StringMap<Symbol>();
		#if symtab_stats
		SymbolTableStats.register(this, pos.className.split(".").pop() + "." + pos.methodName);
		#end
	}

	public inline function set(k:String, v:Symbol):Void {
		#if symtab_check
		SymbolTableCheck.check(k, v, "set");
		#end
		this.set(k, v);
	}

	#if symtab_check
	public inline function get(k:String):Symbol {
		final v = this.get(k);
		if (v != null) {
			SymbolTableCheck.check(k, v, "get");
		}
		return v;
	}
	#end

	public inline function iterator():Iterator<Symbol> {
		return this.iterator();
	}

	public inline function keyValueIterator():KeyValueIterator<String, Symbol> {
		return this.keyValueIterator();
	}

	public inline function copy(#if symtab_stats ?pos:haxe.PosInfos #end):SymbolTable {
		#if symtab_stats
		final t = this.copy();
		SymbolTableStats.register(t, "copy@" + pos.className.split(".").pop() + "." + pos.methodName);
		return t;
		#else
		return this.copy();
		#end
	}
}

#if symtab_check
class SymbolTableCheck {
	static var seen:StringMap<Bool> = new StringMap();
	static var mutex = new sys.thread.Mutex();

	public static function check(k:String, v:Symbol, op:String):Void {
		if (v == null || v.Name == k) {
			return;
		}
		final key = op + " " + k + " " + v.Name + " " + (v.Flags : Int) + " " + (v.CheckFlags : Int);
		mutex.acquire();
		final first = !seen.exists(key);
		if (first) {
			seen.set(key, true);
		}
		mutex.release();
		if (first) {
			Sys.stderr().writeString("SYMTAB-MISMATCH " + op + " key=" + haxe.Json.stringify(k) + " name=" + haxe.Json.stringify(v.Name) + " flags="
				+ StringTools.hex(v.Flags, 8) + " checkFlags=" + StringTools.hex(v.CheckFlags, 8) + "\n" + haxe.CallStack.toString(haxe.CallStack.callStack()) + "\n");
		}
	}
}
#end


#if symtab_stats
// -D symtab_stats: every table made through `new SymbolTable()` / copy() with a tag (its creation site or a kind
// given by retag), and at exit (Tsgo) the histogram of the final sizes per tag on stderr
class SymbolTableStats {
	static var tables:Array<StringMap<Symbol>> = [];
	static var tags:Array<String> = [];
	static var mutex = new sys.thread.Mutex();

	public static function register(t:StringMap<Symbol>, tag:String):Void {
		mutex.acquire();
		tables.push(t);
		tags.push(tag);
		mutex.release();
	}

	public static function retag(t:StringMap<Symbol>, tag:String):Void {
		mutex.acquire();
		var i = tables.length - 1;
		while (i >= 0 && i >= tables.length - 64) {
			if (tables[i] == t) {
				tags[i] = tag;
				break;
			}
			i--;
		}
		mutex.release();
	}

	static final bounds = [0, 1, 2, 3, 4, 5, 6, 8, 12, 16, 32, 64, 256, 1024, 0x7fffffff];

	static function bucket(n:Int):Int {
		var b = 0;
		while (n > bounds[b])
			b++;
		return b;
	}

	public static function dump():Void {
		final byTag = new StringMap<Array<Int>>();
		final order = [];
		final total = [for (_ in bounds) 0];
		var entries = 0.0;
		for (i in 0...tables.length) {
			final n = tables[i].size();
			entries += n;
			final b = bucket(n);
			var h = byTag.get(tags[i]);
			if (h == null) {
				h = [for (_ in 0...bounds.length + 1) 0];
				byTag.set(tags[i], h);
				order.push(tags[i]);
			}
			h[b]++;
			h[bounds.length] += n;
			total[b]++;
		}
		final head = [for (i in 0...bounds.length) i == 0 ? "0" : bounds[i] == bounds[i - 1] + 1 ? "" + bounds[i] : bounds[i] == 0x7fffffff ? ">" + bounds[i - 1] : "<=" + bounds[i]];
		final out = new StringBuf();
		out.add("SYMTAB-STATS tables " + tables.length + " entries " + entries + "\n");
		out.add("tag\ttables\tentries\t" + head.join("\t") + "\n");
		order.sort((a, b) -> {
			final x = byTag.get(a), y = byTag.get(b);
			var nx = 0, ny = 0;
			for (i in 0...bounds.length) {
				nx += x[i];
				ny += y[i];
			}
			return ny - nx;
		});
		for (t in order) {
			final h = byTag.get(t);
			var n = 0;
			for (i in 0...bounds.length)
				n += h[i];
			out.add(t + "\t" + n + "\t" + h[bounds.length] + "\t" + h.slice(0, bounds.length).join("\t") + "\n");
		}
		out.add("ALL\t" + tables.length + "\t" + entries + "\t" + total.join("\t") + "\n");
		Sys.stderr().writeString(out.toString());
	}
}
#end