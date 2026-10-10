package ts.nodebuilder;

import ts.nodebuilder.Types;

// Upstream has no nodebuilder tests. Smoke checks of the port only (not upstream tests).
class NodebuilderTest {
	public static function run() {
		T.run("SmokeNodebuilderFlags", () -> {
			T.eq(0x0D, (InternalFlagsWriteComputedProps | InternalFlagsDoNotIncludeSymbolChain | InternalFlagsAllowUnresolvedNames : Int));
			T.eq((1 << 15) | (1 << 16) | (1 << 17) | (1 << 18) | (1 << 19) | (1 << 21) | (1 << 26), (FlagsIgnoreErrors : Int));
			T.isTrue(FlagsIgnoreErrors & FlagsAllowUniqueESSymbolType == 0);
			T.eq(1 << 30, (FlagsUseInstantiationExpressions : Int));
			final tracker:SymbolTracker = null;
			T.isTrue(tracker == null);
			T.eq("ts.nodebuilder.Nodebuilder", Type.getClassName(Nodebuilder));
		});
	}
}
