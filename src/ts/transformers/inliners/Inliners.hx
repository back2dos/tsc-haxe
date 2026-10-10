package ts.transformers.inliners;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/inliners/Inliners.hx (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Package class: package-level funcs, vars and consts of internal/transformers/inliners (all files).
@:allow(ts.transformers.inliners)
class Inliners {

	// --- constenum.go ---

	public static function NewConstEnumInliningTransformer(opt:TransformOptions):Transformer {
		final compilerOptions = opt.CompilerOptions;
		final emitContext = opt.Context;
		if (compilerOptions.GetIsolatedModules()) {
			Debug.Fail("const enums are not inlined under isolated modules");
		}
		final tx = new ConstEnumInliningTransformer();
		tx.compilerOptions = compilerOptions;
		tx.emitResolver = opt.EmitResolver;
		return tx.Transformer.NewTransformer(tx.visit, emitContext);
	}

	static function safeMultiLineComment(text:std.String):std.String {
		final b = new StringBuf();
		b.add(" ");
		while (true) {
			final i = text.indexOf("*/");
			if (i < 0) {
				break;
			}
			b.add(text.substring(0, i));
			b.add("*_/");
			text = text.substring(i + 2);
		}
		b.add(text);
		b.add(" ");
		return b.toString();
	}
}
