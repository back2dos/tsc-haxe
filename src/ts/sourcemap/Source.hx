package ts.sourcemap;

// --- source.go ---

interface Source {
	function Text():String;
	function FileName():String;
	function ECMALineMap():Array<TextPos>;
}
