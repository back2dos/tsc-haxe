package ts.sourcemap;

// --- source.go ---

interface Source {
	function Text():String;
	function FileName():RootedFilePath;
	function ECMALineMap():Slice<TextPos>;
}
