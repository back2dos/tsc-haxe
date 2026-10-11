package ts.ast;

import haxe.ds.StringMap;

// Port of symbol.go (types and methods; the InternalSymbolName* constants and the package
// functions are in Ast.hx).

// PORT: Go checker.TypeSystemEntity is `any` (a *Symbol, *Node, *Type or *Signature). Here it is an
// empty interface that these four classes implement, so a typed cast to it is valid on every target
// (the JVM checks every cast). ts.checker.Checker.TypeSystemEntity refers to it.
interface TypeSystemEntity {}

// Symbol
class Symbol implements TypeSystemEntity {
	public var Flags:SymbolFlags = 0;
	public var CheckFlags:CheckFlags = 0; // Non-zero only in transient symbols created by Checker
	public var Name:String = "";
	public var Declarations:Array<Node> = null;
	public var ValueDeclaration:Node = null;
	public var Members:SymbolTable = null;
	public var Exports:SymbolTable = null;
	public var id:Int = 0; // PORT: atomic.Uint64 → Int (single-threaded; ids fit in 32 bits)
	public var Parent:Symbol = null;
	public var ExportSymbol:Symbol = null;

	public function new() {}

	public function IsExternalModule():Bool {
		return Flags & SymbolFlagsModule != 0 && Name.length > 0 && StringTools.fastCodeAt(Name, 0) == '"'.code;
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

// SymbolTable
typedef SymbolTable = StringMap<Symbol>;
