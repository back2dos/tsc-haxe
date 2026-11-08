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
class Symbol extends ts.core.Linkstore.LinkHolder implements TypeSystemEntity {
	public var Flags:SymbolFlags = 0;
	public var CheckFlags:CheckFlags = 0; // Non-zero only in transient symbols created by Checker
	public var Name:String = "";
	public var Declarations:Array<Node> = null;
	public var ValueDeclaration:Node = null;
	public var id:Int = 0; // PORT: atomic.Uint64 → Int (single-threaded; ids fit in 32 bits)
	public var Parent:Symbol = null;
	// PORT: perf — from TypeScript main (microsoft/typescript-go#64799, symbolExtra): the optional symbol tables
	// and the export symbol in a side record, allocated when one is set to a non-nil value (most symbols,
	// the checker's transient ones, have none); the properties keep Go 7.0's field syntax.
	var extra:SymbolExtra = null;
	public var Members(get, set):SymbolTable;
	public var Exports(get, set):SymbolTable;
	public var ExportSymbol(get, set):Symbol;

	public function new() {
		super();
	}

	inline function get_Members():SymbolTable {
		return extra == null ? null : extra.members;
	}

	inline function get_Exports():SymbolTable {
		return extra == null ? null : extra.exports;
	}

	inline function get_ExportSymbol():Symbol {
		return extra == null ? null : extra.exportSymbol;
	}

	function set_Members(v:SymbolTable):SymbolTable {
		if (extra == null) {
			if (v == null) {
				return v;
			}
			extra = new SymbolExtra();
		}
		return extra.members = v;
	}

	function set_Exports(v:SymbolTable):SymbolTable {
		if (extra == null) {
			if (v == null) {
				return v;
			}
			extra = new SymbolExtra();
		}
		return extra.exports = v;
	}

	function set_ExportSymbol(v:Symbol):Symbol {
		if (extra == null) {
			if (v == null) {
				return v;
			}
			extra = new SymbolExtra();
		}
		return extra.exportSymbol = v;
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

class SymbolExtra {
	public var members:SymbolTable = null;
	public var exports:SymbolTable = null;
	public var exportSymbol:Symbol = null;

	public function new() {}
}

// SymbolTable
typedef SymbolTable = StringMap<Symbol>;
