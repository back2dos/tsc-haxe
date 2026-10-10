package ts.diagnosticwriter;

// Generated from a Go reference run of the pinned upstream (overlay program in the lane's scratchpad).
// Expected output of the scenarios in DiagnosticwriterTest.hx.
class DiagnosticwriterGolden {
	public static final PRETTY = "\x1b[96msrc/a.ts\x1b[0m:\x1b[93m2\x1b[0m:\x1b[93m8\x1b[0m - \x1b[91merror\x1b[0m\x1b[90m TS2322: \x1b[0mType 'string' is not assignable to type 'number'.\n  chain level 1\n    chain level 2\n\n\x1b[7m2\x1b[0m  const x: number = \"s\";\n\x1b[7m \x1b[0m \x1b[91m       ~\x1b[0m\n\n  \x1b[96msrc/a.ts\x1b[0m:\x1b[93m1\x1b[0m:\x1b[93m5\x1b[0m - The expected type comes from here.\n    \x1b[7m1\x1b[0m let \u{1F600} = 1;\n    \x1b[7m \x1b[0m \x1b[96m    ~~\x1b[0m\n\n\n\x1b[96msrc/b.ts\x1b[0m:\x1b[93m2\x1b[0m:\x1b[93m4\x1b[0m - \x1b[93mwarning\x1b[0m\x1b[90m TS1005: \x1b[0mLong span.\n\n\x1b[7m  2\x1b[0m line1 \u{1F600} x\n\x1b[7m   \x1b[0m \x1b[93m   ~~~~~~~\x1b[0m\n\x1b[7m  3\x1b[0m line2 \u{1F600} x\n\x1b[7m   \x1b[0m \x1b[93m~~~~~~~~~~\x1b[0m\n\x1b[7m...\x1b[0m \n\x1b[7m  9\x1b[0m line8 \u{1F600} x\n\x1b[7m   \x1b[0m \x1b[93m~~~~~~~~~~\x1b[0m\n\x1b[7m 10\x1b[0m line9 \u{1F600} x\n\x1b[7m   \x1b[0m \x1b[93m~~~~\x1b[0m\n\n\x1b[96msrc/a.ts\x1b[0m:\x1b[93m3\x1b[0m:\x1b[93m1\x1b[0m - \x1b[90msuggestion\x1b[0m\x1b[90m TS1109: \x1b[0mZero length.\n\n\x1b[7m3\x1b[0m foo();\n\x1b[7m \x1b[0m \x1b[90m~\x1b[0m\n\n\x1b[91merror\x1b[0m\x1b[90m TS5023: \x1b[0mGlobal error.\n\x1b[96m../other/c.ts\x1b[0m:\x1b[93m1\x1b[0m:\x1b[93m1\x1b[0m - \x1b[91merror\x1b[0m\x1b[90m TS2304: \x1b[0mCannot find name 'x'.\n\n\x1b[7m1\x1b[0m x\n\x1b[7m \x1b[0m \x1b[91m~\x1b[0m\n\n\x1b[96msrc/b.ts\x1b[0m:\x1b[93m1\x1b[0m:\x1b[93m1\x1b[0m - \x1b[91merror\x1b[0m\x1b[90m TS1: \x1b[0mFour lines.\n\n\x1b[7m1\x1b[0m line0 \u{1F600} x\n\x1b[7m \x1b[0m \x1b[91m~~~~~~~~~~\x1b[0m\n\x1b[7m2\x1b[0m line1 \u{1F600} x\n\x1b[7m \x1b[0m \x1b[91m~~~~~~~~~~\x1b[0m\n\x1b[7m3\x1b[0m line2 \u{1F600} x\n\x1b[7m \x1b[0m \x1b[91m~~~~~~~~~~\x1b[0m\n\x1b[7m4\x1b[0m line3 \u{1F600} x\n\x1b[7m \x1b[0m \x1b[91m~~\x1b[0m\n\n\x1b[96msrc/b.ts\x1b[0m:\x1b[93m3\x1b[0m:\x1b[93m10\x1b[0m - \x1b[91merror\x1b[0m\x1b[90m TS1: \x1b[0mEmoji col.\n\n\x1b[7m3\x1b[0m line2 \u{1F600} x\n\x1b[7m \x1b[0m \x1b[91m         ~\x1b[0m\n\n\x1b[96msrc/a.ts\x1b[0m:\x1b[93m1\x1b[0m:\x1b[93m1\x1b[0m - \x1b[91merror\x1b[0m\x1b[90m TS1490: \x1b[0mbinary";
	public static final PLAIN = "src/a.ts(2,8): error TS2322: Type 'string' is not assignable to type 'number'.\n  chain level 1\n    chain level 2\nsrc/b.ts(2,4): warning TS1005: Long span.\nsrc/a.ts(3,1): suggestion TS1109: Zero length.\nerror TS5023: Global error.\n../other/c.ts(1,1): error TS2304: Cannot find name 'x'.\nsrc/b.ts(1,1): error TS1: Four lines.\nsrc/b.ts(3,10): error TS1: Emoji col.\nsrc/a.ts(1,1): error TS1490: binary\n";
	public static final SUMMARY = [
		"\nFound 6 errors in 3 files.\n\nErrors  Files\n     1  ../other/c.ts\x1b[90m:1\x1b[0m\n     2  src/a.ts\x1b[90m:2\x1b[0m\n     2  src/b.ts\x1b[90m:1\x1b[0m\n\n",
		"\nFound 1 error in src/a.ts\x1b[90m:2\x1b[0m\n\n",
		"\nFound 1 error.\n\n",
		"\nFound 2 errors in 2 files.\n\nErrors  Files\n     1  src/a.ts\x1b[90m:2\x1b[0m\n     1  src/b.ts\x1b[90m:1\x1b[0m\n\n",
		"\nFound 1 error in src/a.ts\x1b[90m:2\x1b[0m\n\n",
		"",
		"\nFound 13 errors in 2 files.\n\nErrors  Files\n    12  ../other/c.ts\x1b[90m:1\x1b[0m\n     1  src/a.ts\x1b[90m:2\x1b[0m\n\n"
	];
	public static final FLAT = "Type 'string' is not assignable to type 'number'.\r\n  chain level 1\r\n    chain level 2";
	public static final STATUS = "[\x1b[90m12:00:00 AM\x1b[0m] Global error.12:00:00 AM - Global error.";
	public static final CLEAR_RESULTS = [true, false, false];
	public static final CLEAR = "\x1b[2J\x1b[3J\x1b[H";
}
