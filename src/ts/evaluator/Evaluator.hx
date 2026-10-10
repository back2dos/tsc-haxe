package ts.evaluator;

// Port of internal/evaluator (evaluator.go).
@:allow(ts.evaluator)
class Evaluator {
	// --- evaluator.go ---

	public static function NewResult(value:Any, isSyntacticallyString:Bool, resolvedOtherFiles:Bool, hasExternalReferences:Bool):Result {
		return new Result(value, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
	}

	public static function NewEvaluator(evaluateEntity:Evaluator_, outerExpressionsToSkip:OuterExpressionKinds):Evaluator_ {
		var evaluate:Evaluator_ = null;
		evaluate = function(expr:Node, location:Node):Result {
			var isSyntacticallyString = false;
			var resolvedOtherFiles = false;
			var hasExternalReferences = false;
			// It's unclear when/whether we should consider skipping other kinds of outer expressions.
			// Type assertions intentionally break evaluation when evaluating literal types, such as:
			//     type T = `one ${"two" as any} three`; // string
			// But it's less clear whether such an assertion should break enum member evaluation:
			//     enum E {
			//       A = "one" as any
			//     }
			// SatisfiesExpressions and non-null assertions seem to have even less reason to break
			// emitting enum members as literals. However, these expressions also break Babel's
			// evaluation (but not esbuild's), and the isolatedModules errors we give depend on
			// our evaluation results, so we're currently being conservative so as to issue errors
			// on code that might break Babel.
			expr = Ast.SkipOuterExpressions(expr, outerExpressionsToSkip | OEKParentheses);
			switch (expr.Kind) {
				case KindPrefixUnaryExpression:
					final result = evaluate(expr.AsPrefixUnaryExpression().Operand, location);
					resolvedOtherFiles = result.ResolvedOtherFiles;
					hasExternalReferences = result.HasExternalReferences;
					if (Std.isOfType(result.Value, Float)) {
						final value = ((result.Value : Float) : Number);
						switch (expr.AsPrefixUnaryExpression().Operator) {
							case KindPlusToken:
								return new Result((value), isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
							case KindMinusToken:
								return new Result((-value), isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
							case KindTildeToken:
								return new Result((value.BitwiseNOT()), isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
							default:
						}
					}
				case KindBinaryExpression:
					final left = evaluate(expr.AsBinaryExpression().Left, location);
					final right = evaluate(expr.AsBinaryExpression().Right, location);
					final operator_ = expr.AsBinaryExpression().OperatorToken.Kind;
					isSyntacticallyString = (left.IsSyntacticallyString || right.IsSyntacticallyString)
						&& expr.AsBinaryExpression().OperatorToken.Kind == KindPlusToken;
					resolvedOtherFiles = left.ResolvedOtherFiles || right.ResolvedOtherFiles;
					hasExternalReferences = left.HasExternalReferences || right.HasExternalReferences;
					final leftIsNum = Std.isOfType(left.Value, Float);
					final leftNum:Number = leftIsNum ? ((left.Value : Float) : Number) : 0;
					final rightIsNum = Std.isOfType(right.Value, Float);
					final rightNum:Number = rightIsNum ? ((right.Value : Float) : Number) : 0;
					if (leftIsNum && rightIsNum) {
						switch (operator_) {
							case KindBarToken:
								return new Result((leftNum.BitwiseOR(rightNum)), isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
							case KindAmpersandToken:
								return new Result((leftNum.BitwiseAND(rightNum)), isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
							case KindGreaterThanGreaterThanToken:
								return new Result((leftNum.SignedRightShift(rightNum)), isSyntacticallyString, resolvedOtherFiles,
									hasExternalReferences);
							case KindGreaterThanGreaterThanGreaterThanToken:
								return new Result((leftNum.UnsignedRightShift(rightNum)), isSyntacticallyString, resolvedOtherFiles,
									hasExternalReferences);
							case KindLessThanLessThanToken:
								return new Result((leftNum.LeftShift(rightNum)), isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
							case KindCaretToken:
								return new Result((leftNum.BitwiseXOR(rightNum)), isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
							case KindAsteriskToken:
								return new Result((leftNum * rightNum), isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
							case KindSlashToken:
								return new Result((leftNum / rightNum), isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
							case KindPlusToken:
								return new Result((leftNum + rightNum), isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
							case KindMinusToken:
								return new Result((leftNum - rightNum), isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
							case KindPercentToken:
								return new Result((leftNum.Remainder(rightNum)), isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
							case KindAsteriskAsteriskToken:
								return new Result((leftNum.Exponentiate(rightNum)), isSyntacticallyString, resolvedOtherFiles,
									hasExternalReferences);
							default:
						}
					}
					// PORT: `std.String`, see import.hx.
					final leftIsStr = Std.isOfType(left.Value, std.String);
					var leftStr:String = leftIsStr ? (left.Value : String) : "";
					final rightIsStr = Std.isOfType(right.Value, std.String);
					var rightStr:String = rightIsStr ? (right.Value : String) : "";
					if ((leftIsStr || leftIsNum) && (rightIsStr || rightIsNum) && operator_ == KindPlusToken) {
						if (leftIsNum) {
							leftStr = leftNum.String();
						}
						if (rightIsNum) {
							rightStr = rightNum.String();
						}
						return new Result(leftStr + rightStr, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
					}
				case KindStringLiteral, KindNoSubstitutionTemplateLiteral:
					return new Result(expr.Text(), true /*isSyntacticallyString*/, false, false);
				case KindTemplateExpression:
					return evaluateTemplateExpression(expr, location, evaluate);
				case KindNumericLiteral:
					return new Result((Jsnum.FromString(expr.Text())), false, false, false);
				case KindIdentifier:
					return evaluateEntity(expr, location);
				case KindElementAccessExpression, KindPropertyAccessExpression:
					if (Ast.IsEntityNameExpression(expr.Expression())) {
						return evaluateEntity(expr, location);
					}
				default:
			}
			return new Result(null, isSyntacticallyString, resolvedOtherFiles, hasExternalReferences);
		};
		return evaluate;
	}

	static function evaluateTemplateExpression(expr:Node, location:Node, evaluate:Evaluator_):Result {
		final sb = new StringBuf();
		sb.add(expr.AsTemplateExpression().Head.Text());
		var resolvedOtherFiles = false;
		var hasExternalReferences = false;
		for (span in expr.AsTemplateExpression().TemplateSpans.Nodes) {
			final spanResult = evaluate(span.Expression(), location);
			if (spanResult.Value == null) {
				return new Result(null, true /*isSyntacticallyString*/, false, false);
			}
			sb.add(AnyToString(spanResult.Value));
			sb.add(span.AsTemplateSpan().Literal.Text());
			resolvedOtherFiles = resolvedOtherFiles || spanResult.ResolvedOtherFiles;
			hasExternalReferences = hasExternalReferences || spanResult.HasExternalReferences;
		}
		return new Result(sb.toString(), true, resolvedOtherFiles, hasExternalReferences);
	}

	public static function AnyToString(v:Any):String {
		if (Std.isOfType(v, std.String)) {
			return (v : String);
		}
		if (Std.isOfType(v, Float)) {
			return ((v : Float) : Number).String();
		}
		if (Std.isOfType(v, Bool)) {
			return Core.IfElse((v : Bool), "true", "false");
		}
		if (Std.isOfType(v, PseudoBigInt)) {
			return (v : PseudoBigInt).String();
		}
		throw "Unhandled case in AnyToString";
	}

	public static function IsTruthy(v:Any):Bool {
		if (Std.isOfType(v, std.String)) {
			return (v : String).length != 0;
		}
		if (Std.isOfType(v, Float)) {
			final n = ((v : Float) : Number);
			return n != 0 && !n.IsNaN();
		}
		if (Std.isOfType(v, Bool)) {
			return (v : Bool);
		}
		if (Std.isOfType(v, PseudoBigInt)) {
			// PORT: Go struct compare `v != jsnum.PseudoBigInt{}` → field compare.
			final b = (v : PseudoBigInt);
			return b.Negative != false || b.Base10Value != "";
		}
		throw "Unhandled case in IsTruthy";
	}
}

class Result {
	public var Value:Any = null;
	public var IsSyntacticallyString:Bool = false;
	public var ResolvedOtherFiles:Bool = false;
	public var HasExternalReferences:Bool = false;

	public function new(Value:Any = null, IsSyntacticallyString:Bool = false, ResolvedOtherFiles:Bool = false, HasExternalReferences:Bool = false) {
		this.Value = Value;
		this.IsSyntacticallyString = IsSyntacticallyString;
		this.ResolvedOtherFiles = ResolvedOtherFiles;
		this.HasExternalReferences = HasExternalReferences;
	}
}

// PORT: Go `type Evaluator func(...)`; the name Evaluator is the package class, so the function type
// gets a `_` suffix.
typedef Evaluator_ = (expr:Node, location:Node) -> Result;

// PORT: a jsnum.Number stored in an `any` value (Result.Value, and the values AnyToString/IsTruthy
// take) is a raw `Float` (PORTING.md §3): Go `v.(jsnum.Number)` → `Std.isOfType(v, Float)` +
// `((v : Float) : Number)`. No Go `any` read here holds an `int`. hxcpp loses the sign of -0 when the
// Float passes through `Any` (documented deviation, PORTING.md §7a); upstream never inspects it there.
