package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/stringer_generated.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Methods of stringer_generated.go on receivers declared in other files: static extension (PORTING.md §2).
class StringerGenerated {

	public static function String(i:SignatureKind):std.String {
		final idx = (i : Int) - 0;
		if ((i : Int) < 0 || idx >= Checker._SignatureKind_index.length - 1) {
			return "SignatureKind(" + Std.string((i : Int)) + ")";
		}
		return Checker._SignatureKind_name.substring(Checker._SignatureKind_index[idx], Checker._SignatureKind_index[idx + 1]);
	}
}
