package ts.transformers.inliners;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/inliners/constenum.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers.inliners)
class ConstEnumInliningTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var compilerOptions:CompilerOptions = null;
	var currentSourceFile:SourceFile = null;
	var emitResolver:EmitResolver = null;

	public function new() {}

	function visit(node:Node):Node {
		switch (node.Kind) {
			case KindPropertyAccessExpression, KindElementAccessExpression:
				{
					final parse = Transformer.EmitContext().ParseNode(node);
					if (parse == null) {
						return Transformer.Visitor().VisitEachChild(node);
					}
					final value:Any = emitResolver.GetConstantValue(parse);
					if (value != null) {
						var replacement:Node = null;
						// PORT: Go type switch on the constant value (jsnum.Number | string | jsnum.PseudoBigInt).
						if (Std.isOfType(value, Float)) {
							final v:ts.jsnum.Jsnum.Number = (value : Float);
							if (v.IsInf()) {
								if (v.Abs() == v) {
									replacement = Transformer.Factory().NewIdentifier("Infinity");
								} else {
									replacement = Transformer.Factory().NewPrefixUnaryExpression(KindMinusToken, Transformer.Factory().NewIdentifier("Infinity"));
								}
							} else if (v.IsNaN()) {
								replacement = Transformer.Factory().NewIdentifier("NaN");
							} else if (v.Abs() == v) {
								replacement = Transformer.Factory().NewNumericLiteral(ts.jsnum.String_.String(v), TokenFlagsNone);
							} else {
								replacement = Transformer.Factory().NewPrefixUnaryExpression(KindMinusToken,
									Transformer.Factory().NewNumericLiteral(ts.jsnum.String_.String(v.Abs()), TokenFlagsNone));
							}
						} else if (Std.isOfType(value, std.String)) {
							replacement = Transformer.Factory().NewStringLiteral((value : std.String), TokenFlagsNone);
						} else if (Std.isOfType(value, ts.jsnum.PseudoBigInt)) { // technically not supported by strada, and issues a checker error, handled here for completeness
							final v:ts.jsnum.PseudoBigInt = (value : ts.jsnum.PseudoBigInt);
							if (!v.Negative && v.Base10Value == "") {
								replacement = Transformer.Factory().NewBigIntLiteral("0", TokenFlagsNone);
							} else if (!v.Negative) {
								replacement = Transformer.Factory().NewBigIntLiteral(v.Base10Value, TokenFlagsNone);
							} else {
								replacement = Transformer.Factory().NewPrefixUnaryExpression(KindMinusToken,
									Transformer.Factory().NewBigIntLiteral(v.Base10Value, TokenFlagsNone));
							}
						}

						if (compilerOptions.RemoveComments.IsFalseOrUnknown()) {
							final original = Transformer.EmitContext().MostOriginal(node);
							if (original != null && !Ast.NodeIsSynthesized(original)) {
								final originalText = Scanner.GetTextOfNode(original);
								final escapedText = Inliners.safeMultiLineComment(originalText);
								Transformer.EmitContext().AddSyntheticTrailingComment(replacement, KindMultiLineCommentTrivia, escapedText, false);
							}
						}
						return replacement;
					}
					return Transformer.Visitor().VisitEachChild(node);
				}
			default:
		}
		return Transformer.Visitor().VisitEachChild(node);
	}
}

