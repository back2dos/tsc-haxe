package ts.ast;

// Port of ids.go.
// PORT: Go uint64 → Int (PORTING.md §3: ids fit in 32 bits).
typedef NodeId = Int;
typedef SymbolId = Int;
