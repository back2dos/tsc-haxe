// gen: reads upstream ast/utilities.go + precedence.go with go/parser and writes the function
// tables of the utilities golden test on both sides:
//   - tools/gen/ast/goref/utilref/funcs.go         (Go, overlaid next to utilref/main.go)
//   - test/ts/ast/UtilitiesGoldenTable.hx          (Haxe replay table)
//
// Selected shapes (exported package functions, no type parameters):
//
//	kind functions: func(Kind) bool | int-like
//	node functions: func(*N, rest...) bool | int-like | string | *N | []*N, where N is Node or an
//	                alias of Node; rest params are bool (every combination is printed) or *N
//	                (passed node.Parent).
//
// Usage (from the project root): go run ./tools/gen/ast/goref/utilref/gen  (see ../../utilref.sh)
package main

import (
	"fmt"
	"go/ast"
	"go/format"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Functions with side effects / global state, or not ported in Haxe. Edit and re-run utilref.sh.
var exclude = map[string]string{
	"GetNodeId":   "global id counter",
	"GetSymbolId": "global id counter",
}

const astDir = "upstream/tsc/internal/ast"

var (
	nodeTypes = map[string]bool{"Node": true}
	intTypes  = map[string]bool{"int": true, "int32": true}
)

type param struct{ kind string } // "node", "bool"

type fn struct {
	name   string
	file   string
	params []param
	result string // "bool", "int", "string", "node", "nodes"
}

func typeName(e ast.Expr) string {
	switch t := e.(type) {
	case *ast.Ident:
		return t.Name
	case *ast.StarExpr:
		return "*" + typeName(t.X)
	case *ast.ArrayType:
		if t.Len == nil {
			return "[]" + typeName(t.Elt)
		}
	case *ast.SelectorExpr:
		return typeName(t.X) + "." + t.Sel.Name
	}
	return "?"
}

func isNodePtr(t string) bool {
	return strings.HasPrefix(t, "*") && nodeTypes[t[1:]]
}

func main() {
	fset := token.NewFileSet()
	files, _ := filepath.Glob(filepath.Join(astDir, "*.go"))
	parsed := map[string]*ast.File{}
	for _, f := range files {
		if strings.HasSuffix(f, "_test.go") {
			continue
		}
		pf, err := parser.ParseFile(fset, f, nil, parser.SkipObjectResolution)
		if err != nil {
			panic(err)
		}
		parsed[filepath.Base(f)] = pf
	}
	// Node aliases and int-like named types (fixed point over alias chains).
	for changed := true; changed; {
		changed = false
		for _, pf := range parsed {
			for _, d := range pf.Decls {
				gd, ok := d.(*ast.GenDecl)
				if !ok || gd.Tok != token.TYPE {
					continue
				}
				for _, s := range gd.Specs {
					ts := s.(*ast.TypeSpec)
					n := typeName(ts.Type)
					if ts.Assign != 0 && nodeTypes[n] && !nodeTypes[ts.Name.Name] {
						nodeTypes[ts.Name.Name] = true
						changed = true
					}
					switch n {
					case "int", "int8", "int16", "int32", "uint8", "uint16", "uint32":
						if !intTypes[ts.Name.Name] {
							intTypes[ts.Name.Name] = true
							changed = true
						}
					}
				}
			}
		}
	}

	var kindFns, nodeFns []fn
	var skipped []string
	for _, file := range []string{"utilities.go", "precedence.go"} {
		for _, d := range parsed[file].Decls {
			fd, ok := d.(*ast.FuncDecl)
			if !ok || fd.Recv != nil || !fd.Name.IsExported() || fd.Type.TypeParams != nil {
				continue
			}
			name := fd.Name.Name
			if why, ok := exclude[name]; ok {
				skipped = append(skipped, name+" ("+why+")")
				continue
			}
			var ptypes []string
			for _, p := range fd.Type.Params.List {
				t := typeName(p.Type)
				n := len(p.Names)
				if n == 0 {
					n = 1
				}
				for range n {
					ptypes = append(ptypes, t)
				}
			}
			if fd.Type.Results == nil || len(fd.Type.Results.List) != 1 || len(fd.Type.Results.List[0].Names) > 1 {
				continue
			}
			rt := typeName(fd.Type.Results.List[0].Type)
			var res string
			switch {
			case rt == "bool":
				res = "bool"
			case rt == "string":
				res = "string"
			case intTypes[rt]:
				res = "int"
			case isNodePtr(rt):
				res = "node"
			case strings.HasPrefix(rt, "[]") && isNodePtr(rt[2:]):
				res = "nodes"
			default:
				continue
			}
			if len(ptypes) == 1 && ptypes[0] == "Kind" && (res == "bool" || res == "int") {
				kindFns = append(kindFns, fn{name: name, file: file, result: res})
				continue
			}
			if len(ptypes) == 0 || !isNodePtr(ptypes[0]) {
				continue
			}
			f := fn{name: name, file: file, result: res, params: []param{{"node"}}}
			ok = true
			for _, t := range ptypes[1:] {
				switch {
				case t == "bool":
					f.params = append(f.params, param{"bool"})
				case isNodePtr(t):
					f.params = append(f.params, param{"parent"})
				default:
					ok = false
				}
			}
			if ok {
				nodeFns = append(nodeFns, f)
			}
		}
	}

	type variant struct {
		label  string
		goArgs string
		hxArgs string
	}
	variants := func(f fn) []variant {
		vs := []variant{{"", "n", "n"}}
		for _, p := range f.params[1:] {
			var next []variant
			for _, v := range vs {
				switch p.kind {
				case "bool":
					next = append(next, variant{v.label + ",1", v.goArgs + ", true", v.hxArgs + ", true"})
					next = append(next, variant{v.label + ",0", v.goArgs + ", false", v.hxArgs + ", false"})
				case "parent":
					next = append(next, variant{v.label + ",p", v.goArgs + ", n.Parent", v.hxArgs + ", n.Parent"})
				}
			}
			vs = next
		}
		return vs
	}
	goFmt := map[string]string{"bool": "fb(%s)", "int": "fi(int32(%s))", "string": "fs(%s)", "node": "lb.of(%s)", "nodes": "lb.list(%s)"}
	hxFmt := map[string]string{"bool": "fb(%s)", "int": "fi(%s)", "string": "fs(%s)", "node": "lb(%s)", "nodes": "lbs(%s)"}

	var g, h strings.Builder
	g.WriteString("// Code generated by tools/gen/ast/goref/utilref/gen. DO NOT EDIT.\n\npackage main\n\nimport \"github.com/microsoft/typescript-go/internal/ast\"\n\n")
	h.WriteString("// Code generated by tools/gen/ast/goref/utilref/gen. DO NOT EDIT.\npackage ts.ast;\n\n")
	h.WriteString("// Function tables of the utilities golden test (see UtilitiesGolden.hx), in the same order as\n// the Go reference tools/gen/ast/goref/utilref.\nclass UtilitiesGoldenTable {\n")

	g.WriteString("var kindFuncNames = []string{\n")
	h.WriteString("\tpublic static final kindFuncNames:Array<String> = [\n")
	for _, f := range kindFns {
		fmt.Fprintf(&g, "\t%q,\n", f.name)
		fmt.Fprintf(&h, "\t\t%q,\n", f.name)
	}
	g.WriteString("}\n\nvar kindFuncs = []func(k ast.Kind) string{\n")
	h.WriteString("\t];\n\n\tpublic static function kindFuncs(fb:(Bool) -> String, fi:(Int) -> String):Array<(Kind) -> String> {\n\t\treturn [\n")
	for _, f := range kindFns {
		fmt.Fprintf(&g, "\tfunc(k ast.Kind) string { return "+goFmt[f.result]+" },\n", "ast."+f.name+"(k)")
		fmt.Fprintf(&h, "\t\t\tk -> "+hxFmt[f.result]+",\n", "Ast."+f.name+"(k)")
	}
	g.WriteString("}\n\nvar nodeFuncNames = []string{\n")
	h.WriteString("\t\t];\n\t}\n\n\tpublic static final nodeFuncNames:Array<String> = [\n")
	var gBody, hBody strings.Builder
	count := 0
	for _, f := range nodeFns {
		for _, v := range variants(f) {
			count++
			label := f.name
			if v.label != "" {
				label += "(" + v.label[1:] + ")"
			}
			fmt.Fprintf(&g, "\t%q,\n", label)
			fmt.Fprintf(&h, "\t\t%q,\n", label)
			fmt.Fprintf(&gBody, "\tfunc(n *ast.Node, lb labels) string { return "+goFmt[f.result]+" },\n", "ast."+f.name+"("+v.goArgs+")")
			fmt.Fprintf(&hBody, "\t\t\tn -> "+hxFmt[f.result]+",\n", "Ast."+f.name+"("+v.hxArgs+")")
		}
	}
	g.WriteString("}\n\nvar nodeFuncs = []func(n *ast.Node, lb labels) string{\n")
	g.WriteString(gBody.String())
	g.WriteString("}\n")
	h.WriteString("\t];\n\n\tpublic static function nodeFuncs(fb:(Bool) -> String, fi:(Int) -> String, fs:(String) -> String, lb:(Node) -> String,\n\t\t\tlbs:(Array<Node>) -> String):Array<(Node) -> String> {\n\t\treturn [\n")
	h.WriteString(hBody.String())
	h.WriteString("\t\t];\n\t}\n}\n")

	src, err := format.Source([]byte(g.String()))
	if err != nil {
		panic(err)
	}
	if err := os.WriteFile("tools/gen/ast/goref/utilref/funcs.go", src, 0o644); err != nil {
		panic(err)
	}
	if err := os.WriteFile("test/ts/ast/UtilitiesGoldenTable.hx", []byte(h.String()), 0o644); err != nil {
		panic(err)
	}
	sort.Strings(skipped)
	fmt.Printf("kind functions: %d, node functions: %d (%d variants), excluded: %s\n", len(kindFns), len(nodeFns), count, strings.Join(skipped, ", "))
}
