package ts.ast;

// Port of precedence.go (types; the functions are in Ast.hx under `// --- precedence.go ---`).

enum abstract OperatorPrecedence(Int) from Int to Int {
	// Expression:
	//     AssignmentExpression
	//     Expression `,` AssignmentExpression
	var OperatorPrecedenceComma = 0;
	// NOTE: `Spread` is higher than `Comma` due to how it is parsed in |ElementList|
	// SpreadElement:
	//     `...` AssignmentExpression
	var OperatorPrecedenceSpread = 1;
	// AssignmentExpression:
	//     ConditionalExpression
	//     YieldExpression
	//     ArrowFunction
	//     AsyncArrowFunction
	//     LeftHandSideExpression `=` AssignmentExpression
	//     LeftHandSideExpression AssignmentOperator AssignmentExpression
	//
	// NOTE: AssignmentExpression is broken down into several precedences due to the requirements
	//       of the parenthesizer rules.
	// AssignmentExpression: YieldExpression
	// YieldExpression:
	//     `yield`
	//     `yield` AssignmentExpression
	//     `yield` `*` AssignmentExpression
	var OperatorPrecedenceYield = 2;
	// AssignmentExpression: LeftHandSideExpression `=` AssignmentExpression
	// AssignmentExpression: LeftHandSideExpression AssignmentOperator AssignmentExpression
	// AssignmentOperator: one of
	//     `*=` `/=` `%=` `+=` `-=` `<<=` `>>=` `>>>=` `&=` `^=` `|=` `**=`
	var OperatorPrecedenceAssignment = 3;
	// NOTE: `Conditional` is considered higher than `Assignment` here, but in reality they have
	//       the same precedence.
	// AssignmentExpression: ConditionalExpression
	// ConditionalExpression:
	//     ShortCircuitExpression
	//     ShortCircuitExpression `?` AssignmentExpression `:` AssignmentExpression
	var OperatorPrecedenceConditional = 4;
	// LogicalORExpression:
	//     LogicalANDExpression
	//     LogicalORExpression `||` LogicalANDExpression
	var OperatorPrecedenceLogicalOR = 5;
	// LogicalANDExpression:
	//     BitwiseORExpression
	//     LogicalANDExprerssion `&&` BitwiseORExpression
	var OperatorPrecedenceLogicalAND = 6;
	// BitwiseORExpression:
	//     BitwiseXORExpression
	//     BitwiseORExpression `|` BitwiseXORExpression
	var OperatorPrecedenceBitwiseOR = 7;
	// BitwiseXORExpression:
	//     BitwiseANDExpression
	//     BitwiseXORExpression `^` BitwiseANDExpression
	var OperatorPrecedenceBitwiseXOR = 8;
	// BitwiseANDExpression:
	//     EqualityExpression
	//     BitwiseANDExpression `&` EqualityExpression
	var OperatorPrecedenceBitwiseAND = 9;
	// EqualityExpression:
	//     RelationalExpression
	//     EqualityExpression `==` RelationalExpression
	//     EqualityExpression `!=` RelationalExpression
	//     EqualityExpression `===` RelationalExpression
	//     EqualityExpression `!==` RelationalExpression
	var OperatorPrecedenceEquality = 10;
	// RelationalExpression:
	//     ShiftExpression
	//     RelationalExpression `<` ShiftExpression
	//     RelationalExpression `>` ShiftExpression
	//     RelationalExpression `<=` ShiftExpression
	//     RelationalExpression `>=` ShiftExpression
	//     RelationalExpression `instanceof` ShiftExpression
	//     RelationalExpression `in` ShiftExpression
	//     [+TypeScript] RelationalExpression `as` Type
	var OperatorPrecedenceRelational = 11;
	// ShiftExpression:
	//     AdditiveExpression
	//     ShiftExpression `<<` AdditiveExpression
	//     ShiftExpression `>>` AdditiveExpression
	//     ShiftExpression `>>>` AdditiveExpression
	var OperatorPrecedenceShift = 12;
	// AdditiveExpression:
	//     MultiplicativeExpression
	//     AdditiveExpression `+` MultiplicativeExpression
	//     AdditiveExpression `-` MultiplicativeExpression
	var OperatorPrecedenceAdditive = 13;
	// MultiplicativeExpression:
	//     ExponentiationExpression
	//     MultiplicativeExpression MultiplicativeOperator ExponentiationExpression
	// MultiplicativeOperator: one of `*`, `/`, `%`
	var OperatorPrecedenceMultiplicative = 14;
	// ExponentiationExpression:
	//     UnaryExpression
	//     UpdateExpression `**` ExponentiationExpression
	var OperatorPrecedenceExponentiation = 15;
	// UnaryExpression:
	//     UpdateExpression
	//     `delete` UnaryExpression
	//     `void` UnaryExpression
	//     `typeof` UnaryExpression
	//     `+` UnaryExpression
	//     `-` UnaryExpression
	//     `~` UnaryExpression
	//     `!` UnaryExpression
	//     AwaitExpression
	// UpdateExpression:            // TODO: Do we need to investigate the precedence here?
	//     `++` UnaryExpression
	//     `--` UnaryExpression
	var OperatorPrecedenceUnary = 16;
	// UpdateExpression:
	//     LeftHandSideExpression
	//     LeftHandSideExpression `++`
	//     LeftHandSideExpression `--`
	var OperatorPrecedenceUpdate = 17;
	// LeftHandSideExpression:
	//     NewExpression
	// NewExpression:
	//     MemberExpression
	//     `new` NewExpression
	var OperatorPrecedenceLeftHandSide = 18;
	// LeftHandSideExpression:
	//     OptionalExpression
	// OptionalExpression:
	//     MemberExpression OptionalChain
	//     CallExpression OptionalChain
	//     OptionalExpression OptionalChain
	var OperatorPrecedenceOptionalChain = 19;
	// LeftHandSideExpression:
	//     CallExpression
	// CallExpression:
	//     CoverCallExpressionAndAsyncArrowHead
	//     SuperCall
	//     ImportCall
	//     CallExpression Arguments
	//     CallExpression `[` Expression `]`
	//     CallExpression `.` IdentifierName
	//     CallExpression TemplateLiteral
	// MemberExpression:
	//     PrimaryExpression
	//     MemberExpression `[` Expression `]`
	//     MemberExpression `.` IdentifierName
	//     MemberExpression TemplateLiteral
	//     SuperProperty
	//     MetaProperty
	//     `new` MemberExpression Arguments
	var OperatorPrecedenceMember = 20;
	// TODO: JSXElement?
	// PrimaryExpression:
	//     `this`
	//     IdentifierReference
	//     Literal
	//     ArrayLiteral
	//     ObjectLiteral
	//     FunctionExpression
	//     ClassExpression
	//     GeneratorExpression
	//     AsyncFunctionExpression
	//     AsyncGeneratorExpression
	//     RegularExpressionLiteral
	//     TemplateLiteral
	var OperatorPrecedencePrimary = 21;
	// PrimaryExpression:
	//     CoverParenthesizedExpressionAndArrowParameterList
	var OperatorPrecedenceParentheses = 22;
	var OperatorPrecedenceLowest = OperatorPrecedenceComma;
	var OperatorPrecedenceHighest = OperatorPrecedenceParentheses;
	var OperatorPrecedenceDisallowComma = OperatorPrecedenceYield;
	// ShortCircuitExpression:
	//     LogicalORExpression
	//     CoalesceExpression
	// CoalesceExpression:
	//     CoalesceExpressionHead `??` BitwiseORExpression
	// CoalesceExpressionHead:
	//     CoalesceExpression
	//     BitwiseORExpression
	var OperatorPrecedenceCoalesce = OperatorPrecedenceLogicalOR;
	// -1 is lower than all other precedences. Returning it will cause binary expression
	// parsing to stop.
	var OperatorPrecedenceInvalid = -1;
}

enum abstract OperatorPrecedenceFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:OperatorPrecedenceFlags, b:OperatorPrecedenceFlags):OperatorPrecedenceFlags;
	@:op(A & B) static function and(a:OperatorPrecedenceFlags, b:OperatorPrecedenceFlags):OperatorPrecedenceFlags;
	@:op(~A) static function not(a:OperatorPrecedenceFlags):OperatorPrecedenceFlags;

	var OperatorPrecedenceFlagsNone = 0;
	var OperatorPrecedenceFlagsNewWithoutArguments = 1 << 0;
	var OperatorPrecedenceFlagsOptionalChain = 1 << 1;
}

enum abstract TypePrecedence(Int) from Int to Int {
	// Conditional precedence (lowest)
	//
	//   Type[Extends]:
	//       ConditionalTypeNode[?Extends]
	//
	//   ConditionalTypeNode[Extends]:
	//       [~Extends] UnionTypeNode `extends` Type[+Extends] `?` Type[~Extends] `:` Type[~Extends]
	//
	var TypePrecedenceConditional = 0;

	// JSDoc precedence (optional and variadic types)
	//
	//    JSDocType:
	//      `...`? Type `=`?
	var TypePrecedenceJSDoc = 1;

	// Function precedence
	//
	//   Type[Extends]:
	//       ConditionalTypeNode[?Extends]
	//       FunctionTypeNode[?Extends]
	//       ConstructorTypeNode[?Extends]
	//
	//   ConditionalTypeNode[Extends]:
	//       UnionTypeNode
	//
	//   FunctionTypeNode[Extends]:
	//       TypeParameters? ArrowParameters `=>` Type[?Extends]
	//
	//   ConstructorTypeNode[Extends]:
	//       `abstract`? TypeParameters? ArrowParameters `=>` Type[?Extends]
	//
	var TypePrecedenceFunction = 2;

	// Union precedence
	//
	//   UnionTypeNode:
	//       `|`? UnionTypeNoBar
	//
	//   UnionTypeNoBar:
	//       IntersectionTypeNode
	//       UnionTypeNoBar `|` IntersectionTypeNode
	//
	var TypePrecedenceUnion = 3;

	// Intersection precedence
	//
	//   IntersectionTypeNode:
	//       `&`? IntersectionTypeNoAmpersand
	//
	//   IntersectionTypeNoAmpersand:
	//       TypeOperatorNode
	//       IntersectionTypeNoAmpersand `&` TypeOperatorNode
	//
	var TypePrecedenceIntersection = 4;

	// TypeOperatorNode precedence
	//
	//   TypeOperatorNode:
	//     PostfixType
	//     InferTypeNode
	//     `keyof` TypeOperatorNode
	//     `unique` TypeOperatorNode
	//     `readonly` PostfixType
	//
	//   InferTypeNode:
	//     `infer` BindingIdentifier
	//     `infer` BindingIdentifier `extends` Type[+Extends]
	//
	var TypePrecedenceTypeOperator = 5;

	// Postfix precedence
	//
	//   PostfixType:
	//       NonArrayType
	//       OptionalTypeNode
	//       ArrayTypeNode
	//       IndexedAccessTypeNode
	//
	//   OptionalTypeNode:
	//       PostfixType `?`
	//
	//   ArrayTypeNode:
	//       PostfixType `[` `]`
	//
	//   IndexedAccessTypeNode:
	//       PostfixType `[` Type[~Extends] `]`
	//
	var TypePrecedencePostfix = 6;

	// NonArray precedence (highest)
	//
	//   NonArrayType:
	//       KeywordType
	//       LiteralTypeNode
	//       ThisTypeNode
	//       ImportType
	//       TypeQueryNode
	//       MappedTypeNode
	//       TypeLiteralNode
	//       TupleTypeNode
	//       ParenthesizedTypeNode
	//       TypePredicateNode
	//       TypeReferenceNode
	//       TemplateType
	//
	//   KeywordType: one of
	//       `any`       `unknown` `string`    `number` `bigint`
	//       `symbol`    `boolean` `undefined` `never`  `object`
	//       `intrinsic` `void`
	//
	//   LiteralTypeNode:
	//       StringLiteral
	//       NoSubstitutionTemplateLiteral
	//       NumericLiteral
	//       BigIntLiteral
	//       `-` NumericLiteral
	//       `-` BigIntLiteral
	//       `true`
	//       `false`
	//       `null`
	//
	//   ThisTypeNode:
	//       `this`
	//
	//   ImportType:
	//       `typeof`? `import` `(` Type[~Extends] `,`? `)` ImportTypeQualifier? TypeArguments?
	//       `typeof`? `import` `(` Type[~Extends] `,` ImportTypeAttributes `,`? `)` ImportTypeQualifier? TypeArguments?
	//
	//   ImportTypeQualifier:
	//       `.` EntityName
	//
	//   ImportTypeAttributes:
	//       `{` `with` `:` ImportAttributes `,`? `}`
	//
	//   TypeQueryNode:
	//
	//   MappedTypeNode:
	//       `{` MappedTypePrefix? MappedTypePropertyName MappedTypeSuffix? `:` Type[~Extends] `;` `}`
	//
	//   MappedTypePrefix:
	//       `readonly`
	//       `+` `readonly`
	//       `-` `readonly`
	//
	//   MappedTypePropertyName:
	//       `[` BindingIdentifier `in` Type[~Extends] `]`
	//       `[` BindingIdentifier `in` Type[~Extends] `as` Type[~Extends] `]`
	//
	//   MappedTypeSuffix:
	//       `?`
	//       `+` `?`
	//       `-` `?`
	//
	//   TypeLiteralNode:
	//       `{` TypeElementList `}`
	//
	//   TypeElementList:
	//       [empty]
	//       TypeElementList TypeElement
	//
	//   TypeElement:
	//       PropertySignatureDeclaration
	//       MethodSignatureDeclaration
	//       IndexSignatureDeclaration
	//       CallSignatureDeclaration
	//       ConstructSignatureDeclaration
	//
	//   PropertySignatureDeclaration:
	//       PropertyName `?`? TypeAnnotation? `;`
	//
	//   MethodSignatureDeclaration:
	//       PropertyName `?`? TypeParameters? `(` FormalParameterList `)` TypeAnnotation? `;`
	//       `get` PropertyName TypeParameters? `(` FormalParameterList `)` TypeAnnotation? `;` // GetAccessorDeclaration
	//       `set` PropertyName TypeParameters? `(` FormalParameterList `)` TypeAnnotation? `;` // SetAccessorDeclaration
	//
	//   IndexSignatureDeclaration:
	//       `[` IdentifierName`]` TypeAnnotation `;`
	//
	//   CallSignatureDeclaration:
	//       TypeParameters? `(` FormalParameterList `)` TypeAnnotation? `;`
	//
	//   ConstructSignatureDeclaration:
	//       `new` TypeParameters? `(` FormalParameterList `)` TypeAnnotation? `;`
	//
	//   TupleTypeNode:
	//       `[` `]`
	//       `[` NamedTupleElementTypes `,`? `]`
	//       `[` TupleElementTypes `,`? `]`
	//
	//   NamedTupleElementTypes:
	//       NamedTupleMember
	//       NamedTupleElementTypes `,` NamedTupleMember
	//
	//   NamedTupleMember:
	//       IdentifierName `?`? `:` Type[~Extends]
	//       `...` IdentifierName `:` Type[~Extends]
	//
	//   TupleElementTypes:
	//       TupleElementType
	//       TupleElementTypes `,` TupleElementType
	//
	//   TupleElementType:
	//       Type[~Extends]
	//       OptionalTypeNode
	//       RestTypeNode
	//
	//   RestTypeNode:
	//       `...` Type[~Extends]
	//
	//   ParenthesizedTypeNode:
	//       `(` Type[~Extends] `)`
	//
	//   TypePredicateNode:
	//       `asserts`? TypePredicateParameterName
	//       `asserts`? TypePredicateParameterName `is` Type[~Extends]
	//
	//   TypePredicateParameterName:
	//       `this`
	//       IdentifierReference
	//
	//   TypeReferenceNode:
	//       EntityName TypeArguments?
	//
	//   TemplateType:
	//       TemplateHead Type[~Extends] TemplateTypeSpans
	//
	//   TemplateTypeSpans:
	//       TemplateTail
	//       TemplateTypeMiddleList TemplateTail
	//
	//   TemplateTypeMiddleList:
	//       TemplateMiddle Type[~Extends]
	//       TemplateTypeMiddleList TemplateMiddle Type[~Extends]
	//
	//   TypeArguments:
	//       `<` TypeArgumentList `,`? `>`
	//
	//   TypeArgumentList:
	//       Type[~Extends]
	//       TypeArgumentList `,` Type[~Extends]
	//
	var TypePrecedenceNonArray = 7;

	var TypePrecedenceLowest = TypePrecedenceConditional;
	var TypePrecedenceHighest = TypePrecedenceNonArray;
}
