package ts.pseudochecker;

// Upstream has no pseudochecker tests. Smoke checks of the port only (not upstream tests).
class PseudocheckerTest {
	public static function run() {
		T.run("SmokePseudochecker", () -> {
			final f = Ast.NewNodeFactory(new NodeFactoryHooks());
			final ch = Pseudochecker.NewPseudoChecker(true, false);
			T.isTrue(Pseudochecker.CouldAlreadyReferToUndefinedType(Pseudochecker.PseudoTypeUndefined));
			T.isTrue(!Pseudochecker.CouldAlreadyReferToUndefinedType(Pseudochecker.PseudoTypeString));
			final num = ch.GetTypeOfExpression(f.NewNumericLiteral("1", TokenFlagsNone));
			T.eq(PseudoTypeKindMaybeConstLocation, num.Kind);
			T.eq(PseudoTypeKindNumericLiteral, num.AsPseudoTypeMaybeConstLocation().ConstType.Kind);
			T.isTrue(num.AsPseudoTypeMaybeConstLocation().RegularType == Pseudochecker.PseudoTypeNumber);
			final direct = Pseudochecker.NewPseudoTypeDirect(f.NewKeywordTypeNode(KindStringKeyword));
			T.isTrue(!Pseudochecker.CouldAlreadyReferToUndefinedType(direct));
			T.isTrue(Pseudochecker.CouldAlreadyReferToUndefinedType(Pseudochecker.NewPseudoTypeUnion([direct, Pseudochecker.PseudoTypeUndefined])));
			final sig = f.NewIdentifier("s");
			final m = Pseudochecker.NewPseudoObjectMethod(sig, f.NewIdentifier("m"), true, null, null, direct);
			T.eq(PseudoObjectElementKindMethod, m.Kind);
			T.isTrue(m.Signature() == sig);
			T.isTrue(m.AsPseudoObjectMethod().ReturnType == direct);
			final pa = Pseudochecker.NewPseudoPropertyAssignment(true, null, false, direct);
			T.isTrue(pa.Signature() == null);
			T.isTrue(pa.AsPseudoPropertyAssignment().Readonly);
		});
	}
}
