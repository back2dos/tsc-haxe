package ts.evaluator;

import ts.evaluator.Evaluator.Result;

// Upstream has no evaluator_test.go. These are smoke checks of the port only (not upstream tests).
class EvaluatorTest {
	public static function run() {
		T.run("SmokeEvaluator", () -> {
			final f = Ast.NewNodeFactory(new NodeFactoryHooks());
			final ev = Evaluator.NewEvaluator((expr, location) -> new Result(null, false, false, false), OEKAll);
			final num = (s:String) -> f.NewNumericLiteral(s, TokenFlagsNone);
			// Direct jsnum.Number arithmetic keeps the sign of -0 on both targets (PORTING.md §7a).
			final zero:Number = Std.parseFloat("0"); // PORT: python — not a constant: the analyzer folds -0.0 to 0. there
			final negZeroNum:Number = -zero;
			T.eq(Math.NEGATIVE_INFINITY, go.Math.Div(1, (negZeroNum : Float))); // PORT: python — 1 / 0 raises
			// A jsnum.Number in `any` is a raw Float (PORTING.md §3).
			final negZero = ev(f.NewPrefixUnaryExpression(KindMinusToken, num("0")), null);
			T.isTrue(Std.isOfType(negZero.Value, Float));
			T.eq("0", Evaluator.AnyToString(negZero.Value));
			// -0 through `any`: kept on JS; lost on hxcpp (documented deviation, PORTING.md §3/§7a).
			#if cpp
			T.eq(Math.POSITIVE_INFINITY, go.Math.Div(1, (negZero.Value : Float)));
			#else
			T.eq(Math.NEGATIVE_INFINITY, go.Math.Div(1, (negZero.Value : Float)));
			#end
			final sum = ev(f.NewBinaryExpression(null, num("1"), null, f.NewToken(KindPlusToken), f.NewStringLiteral("a", TokenFlagsNone)), null);
			T.eq("1a", (sum.Value : String));
			T.eq(true, sum.IsSyntacticallyString);
			final shl = ev(f.NewBinaryExpression(null, num("1"), null, f.NewToken(KindLessThanLessThanToken), num("31")), null);
			T.eq("-2147483648", Evaluator.AnyToString(shl.Value));
			final tmpl = ev(f.NewTemplateExpression(f.NewTemplateHead("x", "x", TokenFlagsNone),
				f.NewNodeList([f.NewTemplateSpan(num("2"), f.NewTemplateTail("y", "y", TokenFlagsNone))])), null);
			T.eq("x2y", (tmpl.Value : String));
			T.eq(false, Evaluator.IsTruthy(Math.NaN));
			T.eq(false, Evaluator.IsTruthy(Jsnum.NewPseudoBigInt("0", true)));
			T.eq(true, Evaluator.IsTruthy(Jsnum.NewPseudoBigInt("1", false)));
			T.eq("false", Evaluator.AnyToString(false));
		});
	}
}
