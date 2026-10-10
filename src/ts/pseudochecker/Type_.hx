package ts.pseudochecker;

// --- type.go --- (types and methods; the package-level vars and funcs are in Pseudochecker.hx)
// PORT: module named Type_ because Type.hx would shadow the Haxe std class Type.
// PORT: Go embeds the base structs (PseudoTypeDefault → PseudoType, PseudoObjectMethod →
// PseudoObjectElement); here composition fields with the Go type name (PORTING.md §3). The promoted
// AsPseudoType()/AsPseudoObjectElement() methods are written out as forwarders.

// `PseudoType`s are skeletons of types - partially interpreted expressions and type nodes
// composed to represent how you *should* construct a type out of them. They can be trivially
// mapped into actual types by a real `Checker`, or into a tree of `Node`s directly, without
// needing to make any intermediate types, by a `NodeBuilder`. Unlike checker `Type`s, these are
// never normalized, and multiple pseudo-types may refer to the same underlying `Type`.

// In strada, these were implicit in the AST nodes constructed in `expressionToTypeNode.ts`, which
// repurposed AST nodes for this purpose, but in so doing, often confused weather or not it had validated
// nested nodes for use at a given use-site. By keeping the mapping deferred like this, we can know we haven't
// done any use-site checks until we're ready to map the `PseudoType` into a `Node`, and can cache
// `PseudoType`s across multiple target positions.

enum abstract PseudoTypeKind(Int) from Int to Int {
	var PseudoTypeKindDirect = 0;
	var PseudoTypeKindInferred = 1;
	var PseudoTypeKindNoResult = 2;
	var PseudoTypeKindMaybeConstLocation = 3;
	var PseudoTypeKindUnion = 4;
	var PseudoTypeKindUndefined = 5;
	var PseudoTypeKindNull = 6;
	var PseudoTypeKindAny = 7;
	var PseudoTypeKindString = 8;
	var PseudoTypeKindNumber = 9;
	var PseudoTypeKindBigInt = 10;
	var PseudoTypeKindBoolean = 11;
	var PseudoTypeKindFalse = 12;
	var PseudoTypeKindTrue = 13;
	var PseudoTypeKindSingleCallSignature = 14;
	var PseudoTypeKindTuple = 15;
	var PseudoTypeKindObjectLiteral = 16;
	var PseudoTypeKindStringLiteral = 17;
	var PseudoTypeKindNumericLiteral = 18;
	var PseudoTypeKindBigIntLiteral = 19;
}

@:allow(ts.pseudochecker)
class PseudoType {
	public var Kind:PseudoTypeKind = 0;
	var data:PseudoTypeData = null;

	public function new() {}

	public function AsPseudoTypeDirect():PseudoTypeDirect {
		return cast(data, PseudoTypeDirect);
	}

	public function AsPseudoTypeInferred():PseudoTypeInferred {
		return cast(data, PseudoTypeInferred);
	}

	public function AsPseudoTypeNoResult():PseudoTypeNoResult {
		return cast(data, PseudoTypeNoResult);
	}

	public function AsPseudoTypeMaybeConstLocation():PseudoTypeMaybeConstLocation {
		return cast(data, PseudoTypeMaybeConstLocation);
	}

	public function AsPseudoTypeUnion():PseudoTypeUnion {
		return cast(data, PseudoTypeUnion);
	}

	public function AsPseudoTypeSingleCallSignature():PseudoTypeSingleCallSignature {
		return cast(data, PseudoTypeSingleCallSignature);
	}

	public function AsPseudoTypeTuple():PseudoTypeTuple {
		return cast(data, PseudoTypeTuple);
	}

	public function AsPseudoTypeObjectLiteral():PseudoTypeObjectLiteral {
		return cast(data, PseudoTypeObjectLiteral);
	}

	public function AsPseudoTypeLiteral():PseudoTypeLiteral {
		return cast(data, PseudoTypeLiteral);
	}
}

interface PseudoTypeData {
	function AsPseudoType():PseudoType;
}

class PseudoTypeDefault implements PseudoTypeData {
	public var PseudoType:PseudoType = new PseudoType();

	public function new() {}

	public function AsPseudoType():PseudoType {
		return PseudoType;
	}
}

class PseudoTypeBase implements PseudoTypeData {
	public var PseudoTypeDefault:PseudoTypeDefault = new PseudoTypeDefault();

	public function new() {}

	public function AsPseudoType():PseudoType {
		return PseudoTypeDefault.AsPseudoType();
	}
}

// PseudoTypeDirect directly encodes the type referred to by a given TypeNode
class PseudoTypeDirect implements PseudoTypeData {
	public var PseudoTypeBase:PseudoTypeBase = new PseudoTypeBase();
	public var TypeNode:Node = null;

	public function new() {}

	public function AsPseudoType():PseudoType {
		return PseudoTypeBase.AsPseudoType();
	}
}

// PseudoTypeInferred directly encodes the type referred to by a given Expression
// These represent cases where the expression was too complex for the pseudochecker.
// Most of the time, these locations will produce an error under ID.
// Specific error nodes (shorthand properties, spread assignments, etc.) are stored on the
// ErrorNodes field, collected during pseudochecker construction.
class PseudoTypeInferred implements PseudoTypeData {
	public var PseudoTypeBase:PseudoTypeBase = new PseudoTypeBase();
	public var Expression:Node = null;
	public var ErrorNodes:Array<Node> = null;
	public var IsSignatureReturn:Bool = false;

	public function new() {}

	public function AsPseudoType():PseudoType {
		return PseudoTypeBase.AsPseudoType();
	}
}

// PseudoTypeNoResult is analogous to PseudoTypeInferred in that it references a case
// where the type was too complex for the pseudochecker. Rather than an expression, however,
// it is referring to the return type of a signature or declaration.
class PseudoTypeNoResult implements PseudoTypeData {
	public var PseudoTypeBase:PseudoTypeBase = new PseudoTypeBase();
	public var Declaration:Node = null;

	public function new() {}

	public function AsPseudoType():PseudoType {
		return PseudoTypeBase.AsPseudoType();
	}
}

// PseudoTypeMaybeConstLocation encodes the const/regular types of a location so the builder
// can later select the appropriate pseudotype based on the location's context. This is used
// to ensure accuracy in nested expressions without exposing type-based functionality to the pseudochecker.
// A nodebuilder that doesn't do contextual typing would need to, as policy, reject these types if they
// are in a contextually typed position! (Otherwise they could pick one, but either type could be wrong, depending on context!)
// At the top-level, which is generally what ID is concerned with, nothing is contextually typed, so these cases don't generally
// cause problems. Once you get into reused nodes in nested expressions, however, this becomes important.
// In strada, checker `isConstContext` functionality exposed to the pseudochecker + type comparison sanity checking
// on nested results masks the need for this abstraction, but with it present it clearly highlights a shortcoming
// of the ID infernce model and how "standalone" it can(n't) truly be without substantial restrictions on expression inference.
class PseudoTypeMaybeConstLocation implements PseudoTypeData {
	public var PseudoTypeBase:PseudoTypeBase = new PseudoTypeBase();
	public var Node:Node = null;
	public var ConstType:PseudoType = null;
	public var RegularType:PseudoType = null;

	public function new() {}

	public function AsPseudoType():PseudoType {
		return PseudoTypeBase.AsPseudoType();
	}
}

// PseudoTypeUnion is a collection of psudotypes joined into a union
class PseudoTypeUnion implements PseudoTypeData {
	public var PseudoTypeBase:PseudoTypeBase = new PseudoTypeBase();
	public var Types:Array<PseudoType> = null;

	public function new() {}

	public function AsPseudoType():PseudoType {
		return PseudoTypeBase.AsPseudoType();
	}
}

class PseudoParameter {
	public var Rest:Bool = false;
	public var Name:Node = null;
	public var Optional:Bool = false;
	public var Type:PseudoType = null;

	public function new() {}
}

// PseudoTypeSingleCallSignature represents an object type with a single call signature, like an arrow or function expression
class PseudoTypeSingleCallSignature implements PseudoTypeData {
	public var PseudoTypeBase:PseudoTypeBase = new PseudoTypeBase();
	public var Signature:Node = null;
	public var Parameters:Array<PseudoParameter> = null;
	public var TypeParameters:Array<TypeParameterDeclaration> = null;
	public var ReturnType:PseudoType = null;

	public function new() {}

	public function AsPseudoType():PseudoType {
		return PseudoTypeBase.AsPseudoType();
	}
}

// PseudoTypeTuple represents a tuple originaing from an `as const` array literal
class PseudoTypeTuple implements PseudoTypeData {
	public var PseudoTypeBase:PseudoTypeBase = new PseudoTypeBase();
	public var Elements:Array<PseudoType> = null;

	public function new() {}

	public function AsPseudoType():PseudoType {
		return PseudoTypeBase.AsPseudoType();
	}
}

@:allow(ts.pseudochecker)
class PseudoObjectElement implements PseudoObjectElementData {
	public var Name:Node = null;
	public var Optional:Bool = false;
	public var Kind:PseudoObjectElementKind = 0;
	var data:PseudoObjectElementData = null;

	public function new() {}

	public function AsPseudoObjectElement():PseudoObjectElement {
		return this;
	}

	public function Signature():Node {
		switch (Kind) {
			case PseudoObjectElementKindMethod:
				return AsPseudoObjectMethod().Signature;
			case PseudoObjectElementKindSetAccessor:
				return AsPseudoSetAccessor().Signature;
			case PseudoObjectElementKindGetAccessor:
				return AsPseudoGetAccessor().Signature;
			default:
				return null;
		}
	}

	public function AsPseudoObjectMethod():PseudoObjectMethod {
		return cast(data, PseudoObjectMethod);
	}

	public function AsPseudoPropertyAssignment():PseudoPropertyAssignment {
		return cast(data, PseudoPropertyAssignment);
	}

	public function AsPseudoSetAccessor():PseudoSetAccessor {
		return cast(data, PseudoSetAccessor);
	}

	public function AsPseudoGetAccessor():PseudoGetAccessor {
		return cast(data, PseudoGetAccessor);
	}
}

enum abstract PseudoObjectElementKind(Int) from Int to Int {
	var PseudoObjectElementKindMethod = 0;
	var PseudoObjectElementKindPropertyAssignment = 1;
	var PseudoObjectElementKindSetAccessor = 2;
	var PseudoObjectElementKindGetAccessor = 3;
}

interface PseudoObjectElementData {
	function AsPseudoObjectElement():PseudoObjectElement;
}

class PseudoObjectMethod implements PseudoObjectElementData {
	public var PseudoObjectElement:PseudoObjectElement = new PseudoObjectElement();
	public var Signature:Node = null;
	public var TypeParameters:Array<TypeParameterDeclaration> = null;
	public var Parameters:Array<PseudoParameter> = null;
	public var ReturnType:PseudoType = null;

	public function new() {}

	public function AsPseudoObjectElement():PseudoObjectElement {
		return PseudoObjectElement.AsPseudoObjectElement();
	}
}

class PseudoPropertyAssignment implements PseudoObjectElementData {
	public var PseudoObjectElement:PseudoObjectElement = new PseudoObjectElement();
	public var Readonly:Bool = false;
	public var Type:PseudoType = null;

	public function new() {}

	public function AsPseudoObjectElement():PseudoObjectElement {
		return PseudoObjectElement.AsPseudoObjectElement();
	}
}

class PseudoSetAccessor implements PseudoObjectElementData {
	public var PseudoObjectElement:PseudoObjectElement = new PseudoObjectElement();
	public var Signature:Node = null;
	public var Parameter:PseudoParameter = null;

	public function new() {}

	public function AsPseudoObjectElement():PseudoObjectElement {
		return PseudoObjectElement.AsPseudoObjectElement();
	}
}

class PseudoGetAccessor implements PseudoObjectElementData {
	public var PseudoObjectElement:PseudoObjectElement = new PseudoObjectElement();
	public var Signature:Node = null;
	public var Type:PseudoType = null;

	public function new() {}

	public function AsPseudoObjectElement():PseudoObjectElement {
		return PseudoObjectElement.AsPseudoObjectElement();
	}
}

// PseudoTypeObjectLiteral represents an object type originaing from an object literal
class PseudoTypeObjectLiteral implements PseudoTypeData {
	public var PseudoTypeBase:PseudoTypeBase = new PseudoTypeBase();
	public var Elements:Array<PseudoObjectElement> = null;

	public function new() {}

	public function AsPseudoType():PseudoType {
		return PseudoTypeBase.AsPseudoType();
	}
}

// PseudoTypeLiteral represents a literal type
class PseudoTypeLiteral implements PseudoTypeData {
	public var PseudoTypeBase:PseudoTypeBase = new PseudoTypeBase();
	public var Node:Node = null;

	public function new() {}

	public function AsPseudoType():PseudoType {
		return PseudoTypeBase.AsPseudoType();
	}
}
