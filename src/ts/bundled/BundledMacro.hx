package ts.bundled;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

// Replaces upstream internal/bundled/generate.go (generateLibList and generateEmbedded).
// The lib files themselves are copied from upstream bundled/libs into src/ts/bundled/libs/
// (generateLibs output, data). This macro embeds every libs/*.d.ts as a haxe.Resource named
// "bundled/libs/<name>" (Go: //go:embed) and adds to class Bundled:
//   LibNames      (libs_generated.go)  sorted by name, as Go strings.Compare (the names are ASCII)
//   libsEntries   (embed_generated.go) one fileInfo per lib, size = UTF-8 byte length
//   bundledSourceDirValue: the directory of Bundled.hx (Go: runtime.Caller(0) of bundled.go)
class BundledMacro {
	public static function build():Array<Field> {
		final fields = Context.getBuildFields();
		final pos = Context.currentPos();

		final self = Context.resolvePath("ts/bundled/Bundled.hx");
		final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(self));
		final libsDir = dir + "/libs";
		final names = [for (f in sys.FileSystem.readDirectory(libsDir)) if (StringTools.endsWith(f, ".d.ts")) f];
		names.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));

		final nameExprs:Array<Expr> = [];
		final entryExprs:Array<Expr> = [];
		for (name in names) {
			final path = libsDir + "/" + name;
			Context.registerModuleDependency(Context.getLocalModule(), path);
			final bytes = sys.io.File.getBytes(path);
			Context.addResource("bundled/libs/" + name, bytes);
			nameExprs.push(macro $v{name});
			entryExprs.push(macro new ts.bundled.Embed.FileInfo(go.Fs.FileMode.ModeNone, $v{name}, $v{bytes.length}));
		}

		fields.push({
			name: "LibNames",
			doc: null,
			access: [APublic, AStatic, AFinal],
			kind: FVar(macro :Array<String>, macro $a{nameExprs}),
			pos: pos,
		});
		fields.push({
			name: "libsEntries",
			access: [AStatic, AFinal],
			meta: [{name: ":allow", params: [macro ts.bundled], pos: pos}],
			kind: FVar(macro :Array<go.Fs.DirEntry>, macro $a{entryExprs}),
			pos: pos,
		});
		fields.push({
			name: "bundledSourceDirValue",
			access: [AStatic, AInline, AFinal],
			kind: FVar(macro :String, macro $v{dir}),
			pos: pos,
		});
		return fields;
	}
}
#end
