// tsdump-bind: parses and binds each file with the upstream (Go) parser and binder and prints
// the binder's results. Reference for the Haxe binder (Phase 4 gate). Built by
// tools/dump/build.sh (go build -overlay); upstream files are not changed.
//
// Usage: tsdump-bind FILE...   (an argument "@LIST" reads one path per line from LIST)
// Output per file: "## <file>", then
//   one line per node (ForEachChild pre-order, JSDoc nodes as in tsdump-ast, marked "@jsdoc "):
//     <2*depth spaces><Kind> <pos> <end> <NodeFlags>[ sym=#S][ locals=#S,#S..][ flow=#F][ end=#F][ ret=#F][ fall=#F]
//   then the symbols, numbered in order of first reference (node order; locals, members and
//   exports in name order, Go byte order of the UTF-8 names):
//     S #S <name> <SymbolFlags> decls=<Kind@pos,..> value=<Kind@pos|-> parent=<#S|-> export=<#S|-> members=<#S,..> exports=<#S,..>
//   then the flow nodes, numbered in order of first reference (node order, then antecedents):
//     F #F <FlowFlags> node=<Kind@pos|-> ante=<#F|-> antes=<#F,..>
//   then the bind diagnostics:
//     D <code> <pos> <len> <message>
// Positions are UTF-16 code-unit offsets; <name> is escaped as in tsdump-tokens, and the internal
// symbol name prefix byte 0xFE prints as \uFFFE (the Haxe port stores it as U+FFFE).
package main

import (
	"bufio"
	"fmt"
	"os"
	"slices"
	"strings"
	"unicode/utf16"

	"github.com/microsoft/typescript-go/internal/ast"
	"github.com/microsoft/typescript-go/internal/binder"
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

type dumper struct {
	out     *bufio.Writer
	sf      *ast.SourceFile
	u       func(int) int
	symIds  map[*ast.Symbol]int
	syms    []*ast.Symbol
	flowIds map[*ast.FlowNode]int
	flows   []*ast.FlowNode
}

func dump(out *bufio.Writer, file string, text string) {
	pm := ast.ComputePositionMap(text)
	d := &dumper{
		out:     out,
		u:       func(p int) int { if p < 0 { return p }; return pm.UTF8ToUTF16(p) },
		symIds:  map[*ast.Symbol]int{},
		flowIds: map[*ast.FlowNode]int{},
	}
	fmt.Fprintf(out, "## %s\n", file)
	d.sf = parser.ParseSourceFile(ast.SourceFileParseOptions{FileName: file, Path: tspath.Path(file)}, text, core.GetScriptKindFromFileName(file))
	binder.BindSourceFile(d.sf)
	d.walk(d.sf.AsNode(), 0, "")
	for i := 0; i < len(d.syms); i++ { // d.syms grows while printing
		s := d.syms[i]
		decls := make([]string, len(s.Declarations))
		for j, decl := range s.Declarations {
			decls[j] = d.at(decl)
		}
		fmt.Fprintf(out, "S #%d %s %d decls=%s value=%s parent=%s export=%s members=%s exports=%s\n",
			i, escape(s.Name), s.Flags, strings.Join(decls, ","), d.at(s.ValueDeclaration),
			d.symRef(s.Parent), d.symRef(s.ExportSymbol), d.table(s.Members), d.table(s.Exports))
	}
	for i := 0; i < len(d.flows); i++ { // d.flows grows while printing
		f := d.flows[i]
		var antes []string
		for l := f.Antecedents; l != nil; l = l.Next {
			antes = append(antes, d.flowRef(l.Flow))
		}
		fmt.Fprintf(out, "F #%d %d node=%s ante=%s antes=%s\n", i, f.Flags, d.at(f.Node), d.flowRef(f.Antecedent), strings.Join(antes, ","))
	}
	for _, diag := range d.sf.BindDiagnostics() {
		fmt.Fprintf(out, "D %d %d %d %s\n", diag.Code(), d.u(diag.Pos()), d.u(diag.End())-d.u(diag.Pos()), escape(diag.Localize(locale.Default)))
	}
}

func (d *dumper) walk(node *ast.Node, depth int, mark string) {
	var b strings.Builder
	fmt.Fprintf(&b, "%s%s%s %d %d %d", strings.Repeat("  ", depth), mark, node.Kind.String(), d.u(node.Pos()), d.u(node.End()), node.Flags)
	if s := symbolOf(node); s != nil {
		b.WriteString(" sym=" + d.symRef(s))
	}
	if locals := localsOf(node); len(locals) > 0 {
		b.WriteString(" locals=" + d.table(locals))
	}
	if fd := node.FlowNodeData(); fd != nil && fd.FlowNode != nil {
		b.WriteString(" flow=" + d.flowRef(fd.FlowNode))
	}
	if bd := node.BodyData(); bd != nil && bd.EndFlowNode != nil {
		b.WriteString(" end=" + d.flowRef(bd.EndFlowNode))
	}
	if node.Kind == ast.KindSourceFile && d.sf.EndFlowNode != nil {
		b.WriteString(" end=" + d.flowRef(d.sf.EndFlowNode))
	}
	var ret *ast.FlowNode
	switch node.Kind {
	case ast.KindFunctionDeclaration:
		ret = node.AsFunctionDeclaration().ReturnFlowNode
	case ast.KindConstructor:
		ret = node.AsConstructorDeclaration().ReturnFlowNode
	case ast.KindClassStaticBlockDeclaration:
		ret = node.AsClassStaticBlockDeclaration().ReturnFlowNode
	case ast.KindFunctionExpression:
		ret = node.AsFunctionExpression().ReturnFlowNode
	case ast.KindCaseClause, ast.KindDefaultClause:
		if f := node.AsCaseOrDefaultClause().FallthroughFlowNode; f != nil {
			b.WriteString(" fall=" + d.flowRef(f))
		}
	}
	if ret != nil {
		b.WriteString(" ret=" + d.flowRef(ret))
	}
	fmt.Fprintln(d.out, b.String())
	if node.Flags&ast.NodeFlagsHasJSDoc != 0 {
		for _, jsdoc := range node.JSDoc(d.sf) {
			d.walk(jsdoc, depth+1, "@jsdoc ")
		}
	}
	node.ForEachChild(func(child *ast.Node) bool {
		d.walk(child, depth+1, "")
		return false
	})
}

// symbolOf returns the symbol the binder stored on the node, without the checker's fallbacks.
func symbolOf(node *ast.Node) *ast.Symbol {
	if data := node.DeclarationData(); data != nil {
		return data.Symbol
	}
	if node.Kind == ast.KindSourceFile {
		return node.AsSourceFile().Symbol
	}
	return nil
}

func localsOf(node *ast.Node) ast.SymbolTable {
	if data := node.LocalsContainerData(); data != nil {
		return data.Locals
	}
	return nil
}

func (d *dumper) symRef(s *ast.Symbol) string {
	if s == nil {
		return "-"
	}
	id, ok := d.symIds[s]
	if !ok {
		id = len(d.syms)
		d.symIds[s] = id
		d.syms = append(d.syms, s)
	}
	return fmt.Sprintf("#%d", id)
}

func (d *dumper) table(t ast.SymbolTable) string {
	names := make([]string, 0, len(t))
	for name := range t {
		names = append(names, name)
	}
	slices.Sort(names)
	refs := make([]string, len(names))
	for i, name := range names {
		refs[i] = d.symRef(t[name])
	}
	return strings.Join(refs, ",")
}

func (d *dumper) flowRef(f *ast.FlowNode) string {
	if f == nil {
		return "-"
	}
	id, ok := d.flowIds[f]
	if !ok {
		id = len(d.flows)
		d.flowIds[f] = id
		d.flows = append(d.flows, f)
	}
	return fmt.Sprintf("#%d", id)
}

func (d *dumper) at(node *ast.Node) string {
	if node == nil {
		return "-"
	}
	return fmt.Sprintf("%s@%d", node.Kind.String(), d.u(node.Pos()))
}

func escape(v string) string {
	var b strings.Builder
	for i := 0; i < len(v); {
		if v[i] == 0xFE { // ast.InternalSymbolNamePrefix; the Haxe port uses U+FFFE for it
			b.WriteString(`\uFFFE`)
			i++
			continue
		}
		r, size := stringutil.DecodeJSStringRune(v[i:])
		i += size
		var units []uint16
		if r >= 0xD800 && r <= 0xDFFF {
			units = []uint16{uint16(r)}
		} else {
			units = utf16.Encode([]rune{r})
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
	}
	return `"` + b.String() + `"`
}
