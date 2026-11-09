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
// PORT: perf — Go's map[string]*Symbol → one reference to one of six forms, told apart by type tests (a closed
// set of classes: hxmc tests a class by one comparison of the object's type index, no virtual call):
//   null                      Go's nil table
//   EmptySymbolTable.instance a non-nil empty table (Go make(SymbolTable)), shared
//   a Symbol                  one entry, the symbol under its Name
//   SymbolTable2/SymbolTable3 two or three entries under their Names, in insertion order (immutable)
//   StringMap<Symbol>         four or more entries, or a table with an entry whose key is not its symbol's Name
//                             (module augmentation merges through aliases, the node builder's renamed type
//                             parameters, ...; measured with -D symtab_check, see commit 40f0d2b) (mutable)
// Reads keep StringMap's API. A write returns the table to store: `owner.table = owner.table.with(symbol)`. The small
// forms make a new object, the map changes in place and returns itself, so every write stores its result where
// the table lives (Go writes a map that every holder shares). A replaced entry keeps its position; iteration is in
// insertion order (TypeScript main #64979); a loop over a table sees the entries it had when the loop started.
abstract SymbolTable(Dynamic) {
	// a non-nil empty table (Go make(ast.SymbolTable))
	public inline function new() {
		this = EmptySymbolTable.instance;
	}

	// PORT: pointer — a non-nil empty table that changes in place (a map), for a table that more than one holder must
	// see change (Go: every holder of a map shares it); its writes still store their result
	public static inline function newShared():SymbolTable {
		return cast new StringMap<Symbol>();
	}

	inline function isMap():Bool {
		return Std.isOfType(this, StringMap);
	}

	inline function map():StringMap<Symbol> {
		return cast this;
	}

	public inline function get(k:String):Symbol {
		return this == null ? null : SymbolTableImpl.get(this, k);
	}

	public inline function exists(k:String):Bool {
		return this != null && SymbolTableImpl.exists(this, k);
	}

	public inline function size():Int {
		return this == null ? 0 : SymbolTableImpl.size(this);
	}

	// the table with s under its Name (the same map, or a new small table)
	public inline function with(s:Symbol):SymbolTable {
		return SymbolTableImpl.with(this, s);
	}

	// the table with s under the key k (k is s.Name but where Go keys a symbol by another name)
	public inline function withKey(k:String, s:Symbol):SymbolTable {
		return SymbolTableImpl.withKey(this, k, s);
	}

	// the table without the entry k (the same map, or a new small table)
	public inline function without(k:String):SymbolTable {
		return this == null ? null : SymbolTableImpl.without(this, k);
	}

	// Go maps.Clone: a map is copied, the immutable small forms are shared
	public inline function copy():SymbolTable {
		return isMap() ? (map().copy() : Dynamic) : this;
	}

	public inline function iterator():SymbolTableIterator {
		return new SymbolTableIterator(this, 0);
	}

	public inline function keys():SymbolTableKeyIterator {
		return new SymbolTableKeyIterator(this);
	}

	public inline function keyValueIterator():KeyValueIterator<String, Symbol> {
		return new SymbolTableKeyValueIterator(this);
	}

	// (go.ForIn's `for (k => v in table)`: the iterator of the values, whose `key` is the last value's key)
	public inline function entries():SymbolTableIterator {
		return new SymbolTableIterator(this, 2);
	}
}

// PORT: pointer — where a symbol table lives, for code that Go hands the table itself (a map that every holder shares;
// a SymbolTable is a value that an insertion may replace): Ast.GetSlotTable / Ast.SetSlotTable.
enum abstract SymbolTableSlot(Int) {
	var SlotMembers; // of a Symbol
	var SlotExports; // of a Symbol
	var SlotLocals; // of a locals container Node
	var SlotGlobalExports; // of a SourceFile
}

// a non-nil empty table
class EmptySymbolTable {
	public static final instance = new EmptySymbolTable();

	function new() {}
}

// two entries (s0 inserted first)
class SymbolTable2 {
	public final s0:Symbol;
	public final s1:Symbol;

	public function new(s0:Symbol, s1:Symbol) {
		this.s0 = s0;
		this.s1 = s1;
	}
}

// three entries
class SymbolTable3 extends SymbolTable2 {
	public final s2:Symbol;

	public function new(s0:Symbol, s1:Symbol, s2:Symbol) {
		super(s0, s1);
		this.s2 = s2;
	}
}

// the operations on a non-null table
class SymbolTableImpl {
	public static function get(t:Dynamic, k:String):Symbol {
		if (Std.isOfType(t, Symbol)) {
			final s:Symbol = cast t;
			return s.Name == k ? s : null;
		}
		if (Std.isOfType(t, SymbolTable2)) {
			final t2:SymbolTable2 = cast t;
			var s = t2.s0;
			if (s.Name == k) {
				return s;
			}
			s = t2.s1;
			if (s.Name == k) {
				return s;
			}
			if (Std.isOfType(t, SymbolTable3)) {
				s = (cast t : SymbolTable3).s2;
				if (s.Name == k) {
					return s;
				}
			}
			return null;
		}
		if (Std.isOfType(t, StringMap)) {
			return (cast t : StringMap<Symbol>).get(k);
		}
		return null;
	}

	public static function exists(t:Dynamic, k:String):Bool {
		if (Std.isOfType(t, StringMap)) {
			return (cast t : StringMap<Symbol>).exists(k);
		}
		return get(t, k) != null;
	}

	public static function size(t:Dynamic):Int {
		if (Std.isOfType(t, Symbol)) {
			return 1;
		}
		if (Std.isOfType(t, SymbolTable2)) {
			return Std.isOfType(t, SymbolTable3) ? 3 : 2;
		}
		if (Std.isOfType(t, StringMap)) {
			return (cast t : StringMap<Symbol>).size();
		}
		return 0;
	}

	// the i-th symbol of a table that is not a map (i < size)
	public static inline function smallAt(t:Dynamic, i:Int):Symbol {
		return if (Std.isOfType(t, Symbol)) {
			cast t;
		} else {
			final t2:SymbolTable2 = cast t;
			i == 0 ? t2.s0 : i == 1 ? t2.s1 : (cast t : SymbolTable3).s2;
		}
	}

	public static function with(t:Dynamic, s:Symbol):Dynamic {
		if (t == null || Std.isOfType(t, EmptySymbolTable)) {
			return s;
		}
		final k = s.Name;
		if (Std.isOfType(t, Symbol)) {
			final a:Symbol = cast t;
			return a.Name == k ? s : new SymbolTable2(a, s);
		}
		if (Std.isOfType(t, SymbolTable3)) {
			final t3:SymbolTable3 = cast t;
			final a = t3.s0, b = t3.s1, c = t3.s2;
			if (a.Name == k) {
				return new SymbolTable3(s, b, c);
			}
			if (b.Name == k) {
				return new SymbolTable3(a, s, c);
			}
			if (c.Name == k) {
				return new SymbolTable3(a, b, s);
			}
			final m = new StringMap<Symbol>();
			m.set(a.Name, a);
			m.set(b.Name, b);
			m.set(c.Name, c);
			m.set(k, s);
			return m;
		}
		if (Std.isOfType(t, SymbolTable2)) {
			final t2:SymbolTable2 = cast t;
			final a = t2.s0, b = t2.s1;
			if (a.Name == k) {
				return new SymbolTable2(s, b);
			}
			if (b.Name == k) {
				return new SymbolTable2(a, s);
			}
			return new SymbolTable3(a, b, s);
		}
		final m:StringMap<Symbol> = cast t;
		m.set(k, s);
		return m;
	}

	public static function withKey(t:Dynamic, k:String, s:Symbol):Dynamic {
		if (s != null && s.Name == k && (t == null || !Std.isOfType(t, StringMap))) {
			return with(t, s);
		}
		final m = toMap(t);
		m.set(k, s);
		return m;
	}

	// the entries as a map (the map itself if t is one)
	static function toMap(t:Dynamic):StringMap<Symbol> {
		if (t != null && Std.isOfType(t, StringMap)) {
			return cast t;
		}
		final m = new StringMap<Symbol>();
		final n = t == null ? 0 : size(t);
		for (i in 0...n) {
			final s = smallAt(t, i);
			m.set(s.Name, s);
		}
		return m;
	}

	public static function without(t:Dynamic, k:String):Dynamic {
		if (Std.isOfType(t, StringMap)) {
			(cast t : StringMap<Symbol>).remove(k);
			return t;
		}
		final n = size(t);
		var r:Dynamic = new SymbolTable();
		for (i in 0...n) {
			final s = smallAt(t, i);
			if (s.Name != k) {
				r = with(r, s);
			}
		}
		return r;
	}
}

// for (symbol in table): the symbols in insertion order (of a map: a snapshot of its values). `mode` (a constant):
// 0 the values, 1 the keys, 2 both (`key` is the key of the last value)
class SymbolTableIterator {
	final t:Dynamic;
	final big:Array<Symbol>;
	final bigKeys:Array<String>;
	final n:Int;
	final mode:Int;
	var i:Int;

	public var key(default, null):String;

	public inline function new(t:Dynamic, mode:Int) {
		this.t = t;
		this.mode = mode;
		i = 0;
		key = null;
		if (t != null && Std.isOfType(t, StringMap)) {
			final m:StringMap<Symbol> = cast t;
			bigKeys = mode != 0 ? go.ForIn.StringKeys(m) : null;
			big = mode != 1 ? go.ForIn.StringValues(m) : null;
			n = m.size();
		} else {
			bigKeys = null;
			big = null;
			n = t == null ? 0 : SymbolTableImpl.size(t);
		}
	}

	public inline function hasNext():Bool {
		return i < n;
	}

	public inline function next():Symbol {
		final j = i++;
		if (bigKeys != null || big != null) {
			if (mode != 0) {
				key = bigKeys[j];
			}
			return mode != 1 ? big[j] : null;
		}
		final s = SymbolTableImpl.smallAt(t, j);
		if (mode != 0) {
			key = s.Name;
		}
		return s;
	}
}

class SymbolTableKeyIterator {
	final it:SymbolTableIterator;

	public inline function new(t:Dynamic) {
		it = new SymbolTableIterator(t, 1);
	}

	public inline function hasNext():Bool {
		return it.hasNext();
	}

	public inline function next():String {
		it.next();
		return it.key;
	}
}

class SymbolTableKeyValueIterator {
	final it:SymbolTableIterator;

	public inline function new(t:Dynamic) {
		it = new SymbolTableIterator(t, 2);
	}

	public inline function hasNext():Bool {
		return it.hasNext();
	}

	public inline function next():{key:String, value:Symbol} {
		final v = it.next();
		return {key: it.key, value: v};
	}
}
