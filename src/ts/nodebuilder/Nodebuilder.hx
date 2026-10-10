package ts.nodebuilder;

// Port of internal/nodebuilder.
// Exports interfaces and types defining the node builder - concrete implementations are on top of the
// checker, but these types and interfaces are used by the emit resolver in the printer.
// PORT: the package has no package-level functions; the types are in Types.hx (types.go).
class Nodebuilder {}
