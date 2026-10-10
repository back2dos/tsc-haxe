// tsdump-ast: prints the AST and parse diagnostics of the upstream (Go) parser.
// Reference for the Haxe parser (Phase 3 gate). Built by tools/dump/build.sh (go build -overlay);
// upstream files are not changed.
//
// Usage: tsdump-ast FILE...   (an argument "@LIST" reads one path per line from LIST)
// Output per file: "## <file>", then one line per node in ForEachChild pre-order:
//   <2*depth spaces><Kind> <pos> <end> <NodeFlags> [<text>]
// JSDoc nodes attached to a node follow its line, marked "@jsdoc", before its children.
// <text> only for Identifier, PrivateIdentifier, StringLiteral, NumericLiteral, BigIntLiteral,
// NoSubstitutionTemplateLiteral, TemplateHead/Middle/Tail, RegularExpressionLiteral, JsxText;
// escaped per UTF-16 code unit as in tsdump-tokens.
// Then the parse diagnostics (file.Diagnostics(), then file.JSDiagnostics()):
//   D <code> <pos> <len> <message text, escaped>
// Positions are UTF-16 code-unit offsets. The script kind comes from the file extension.
package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"unicode/utf16"

	"github.com/microsoft/typescript-go/internal/ast"
	"github.com/microsoft/typescript-go/internal/core"
	"github.com/microsoft/typescript-go/internal/locale"
	"github.com/microsoft/typescript-go/internal/parser"
	"github.com/microsoft/typescript-go/internal/stringutil"
	"github.com/microsoft/typescript-go/internal/tspath"
)

func main() {
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	for _, arg := range os.Args[1:] {
		files := []string{arg}
		if strings.HasPrefix(arg, "@") {
			data, err := os.ReadFile(arg[1:])
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			files = strings.Fields(string(data))
		}
		for _, file := range files {
			data, err := os.ReadFile(file)
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			dump(out, file, string(data))
		}
	}
}

func dump(out *bufio.Writer, file string, text string) {
	pm := ast.ComputePositionMap(text)
	u := func(p int) int {
		if p < 0 {
			return p
		}
		return pm.UTF8ToUTF16(p)
	}
	fmt.Fprintf(out, "## %s\n", file)
	sf := parser.ParseSourceFile(ast.SourceFileParseOptions{FileName: file, Path: tspath.Path(file)}, text, core.GetScriptKindFromFileName(file))
	var walk func(node *ast.Node, depth int, mark string)
	walk = func(node *ast.Node, depth int, mark string) {
		fmt.Fprintf(out, "%s%s%s %d %d %d%s\n", strings.Repeat("  ", depth), mark, node.Kind.String(), u(node.Pos()), u(node.End()), node.Flags, nodeText(node))
		if node.Flags&ast.NodeFlagsHasJSDoc != 0 {
			for _, jsdoc := range node.JSDoc(sf) {
				walk(jsdoc, depth+1, "@jsdoc ")
			}
		}
		node.ForEachChild(func(child *ast.Node) bool {
			walk(child, depth+1, "")
			return false
		})
	}
	walk(sf.AsNode(), 0, "")
	for _, d := range append(append([]*ast.Diagnostic{}, sf.Diagnostics()...), sf.JSDiagnostics()...) {
		fmt.Fprintf(out, "D %d %d %d %s\n", d.Code(), u(d.Pos()), u(d.End())-u(d.Pos()), escape(d.Localize(locale.Default)))
	}
}

func nodeText(node *ast.Node) string {
	switch node.Kind {
	case ast.KindIdentifier, ast.KindPrivateIdentifier, ast.KindStringLiteral, ast.KindNumericLiteral,
		ast.KindBigIntLiteral, ast.KindNoSubstitutionTemplateLiteral, ast.KindTemplateHead,
		ast.KindTemplateMiddle, ast.KindTemplateTail, ast.KindRegularExpressionLiteral:
		return " " + escape(node.Text())
	case ast.KindJsxText:
		return " " + escape(node.AsJsxText().Text)
	}
	return ""
}

func escape(v string) string {
	var b strings.Builder
	// Decode as a JS string value: a lone surrogate is stored by the scanner as its
	// CESU-8 sentinel (stringutil.EncodeJSStringRune) and must print as that code unit,
	// not as three U+FFFD (which []rune(v) would give). Same as tools/dump/tokens.
	units := make([]uint16, 0, len(v))
	for i := 0; i < len(v); {
		r, size := stringutil.DecodeJSStringRune(v[i:])
		i += size
		if r >= 0x10000 {
			r1, r2 := utf16.EncodeRune(r)
			units = append(units, uint16(r1), uint16(r2))
		} else {
			units = append(units, uint16(r))
		}
	}
	for _, c := range units {
		switch {
		case c == '\n':
			b.WriteString(`\n`)
		case c == '\r':
			b.WriteString(`\r`)
		case c == '\t':
			b.WriteString(`\t`)
		case c == '\\':
			b.WriteString(`\\`)
		case c == '"':
			b.WriteString(`\"`)
		case c < 0x20 || c > 0x7E:
			fmt.Fprintf(&b, `\u%04X`, c)
		default:
			b.WriteByte(byte(c))
		}
	}
	return `"` + b.String() + `"`
}
