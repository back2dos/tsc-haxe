package main

// Skeleton emitter: one Unit = one Go package → Haxe modules (PORTING.md §1, §2, §3).

import (
	"fmt"
	"go/ast"
	"go/constant"
	"go/token"
	"go/types"
	"math"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"unicode/utf8"
)

type Gen struct {
	L          *Loader
	X          *HxIndex
	inherit    bool
	split      map[string]int // Go file → number of part modules for its main-struct methods
	unresolved map[string]int
	notes      map[string]int
	renames    []string
}

// Filter restricts a stub unit to the objects another package uses.
type Filter struct {
	Types map[*types.TypeName]bool
	Objs  map[types.Object]bool // fields, methods, funcs, vars, consts
}

type TypeDecl struct {
	obj      *types.TypeName
	spec     *ast.TypeSpec
	doc      *ast.CommentGroup
	file     string
	hx       string
	kind     string // class, interface, enum, abstract, typedef, alias, constraint
	base     *TypeDecl
	methods  []*item // instance methods (declared in the type's file)
	nmethods int     // all methods, any file
	impl     []string
	public   map[string]bool // methods forced public (interface implementations)
	// prepared
	fields   []string          // rendered field lines
	inst     map[string]string // Go member name → final Haxe name (fields + methods)
	msig     map[string]string // method Go name → signature text (for override checks)
	mpublic  map[string]bool
	prepared bool
}

type item struct {
	kind string // func, method, var, const
	fn   *ast.FuncDecl
	obj  types.Object
	spec *ast.ValueSpec
	gd   *ast.GenDecl
	recv *TypeDecl
	file string
}

type Unit struct {
	g        *Gen
	p        *Pkg
	hxPkg    string
	pkgClass string
	partial  bool // stub for a package that exists in src: types only, in module ExtStubs
	filt     *Filter

	files      []string
	mainFile   string
	modOf      map[string]string
	tname      map[*types.TypeName]string
	tdecl      map[*types.TypeName]*TypeDecl
	tdecls     []*TypeDecl
	mainStruct *TypeDecl
	items      map[string][]*item // per file, source order: package-level items and methods
	enumVals   map[*types.TypeName][]*types.Const
	enumFlags  map[*types.TypeName]bool
	localNames map[string]bool

	anonCtx   string
	anonNames map[*types.Struct]string
	extra     map[string][]string // module → generated helper classes
	curModule string
	refs      map[*HxType]bool
	extModule map[string]bool // modules that hold extension statics (→ using)
	text      map[string]string
	modules   []string

	// stats
	nFuncs, nMethods, nTypes, nFields, nEnumVals, nLines int

	// -split: main-struct methods of one Go file → static-extension part modules
	part      map[*item]int
	parts     []*splitPart
	SplitInfo []string
}

type splitPart struct {
	module     string
	file       string
	from, to   int // Go line range (inclusive)
	items      []*item
	keptPublic []string
}

var haxeCore = map[string]bool{}

func init() {
	for _, n := range strings.Fields("String Array Map Math Std Type Date Reflect Lambda List Class Enum EReg Xml Sys StringBuf StringTools Int Float Bool Dynamic Any Void Null Iterator Iterable UInt IntIterator") {
		haxeCore[n] = true
	}
}

func (g *Gen) pos(p token.Pos) (string, int) {
	ps := g.L.Fset.Position(p)
	return filepath.Base(ps.Filename), ps.Line
}

func baseTypeName(t types.Type) *types.TypeName {
	if p, ok := t.(*types.Pointer); ok {
		t = p.Elem()
	}
	switch t := types.Unalias(t).(type) {
	case *types.Named:
		return t.Origin().Obj()
	}
	return nil
}

func NewUnit(g *Gen, p *Pkg, filt *Filter, partial bool) *Unit {
	u := &Unit{g: g, p: p, filt: filt, partial: partial,
		hxPkg: hxPkgOf(p.Path), pkgClass: capFirst(p.Name),
		modOf: map[string]string{}, tname: map[*types.TypeName]string{}, tdecl: map[*types.TypeName]*TypeDecl{},
		items: map[string][]*item{}, enumVals: map[*types.TypeName][]*types.Const{}, enumFlags: map[*types.TypeName]bool{},
		localNames: map[string]bool{}, anonNames: map[*types.Struct]string{}, extra: map[string][]string{},
		refs: map[*HxType]bool{}, extModule: map[string]bool{}, text: map[string]string{}}
	if haxeCore[u.pkgClass] {
		u.pkgClass += "_"
	}
	u.mainFile = p.Name + ".go"
	info := p.Info
	for fi, f := range p.Files {
		file := p.FileNames[fi]
		u.files = append(u.files, file)
		for _, d := range f.Decls {
			switch d := d.(type) {
			case *ast.GenDecl:
				for _, s := range d.Specs {
					switch s := s.(type) {
					case *ast.TypeSpec:
						obj, _ := info.Defs[s.Name].(*types.TypeName)
						if obj == nil || (filt != nil && !filt.Types[obj]) {
							continue
						}
						doc := s.Doc
						if doc == nil && len(d.Specs) == 1 {
							doc = d.Doc
						}
						td := &TypeDecl{obj: obj, spec: s, doc: doc, file: file, public: map[string]bool{}}
						u.tdecls = append(u.tdecls, td)
						u.tdecl[obj] = td
					case *ast.ValueSpec:
						for _, n := range s.Names {
							if n.Name == "_" {
								continue
							}
							obj := info.Defs[n]
							if c, ok := obj.(*types.Const); ok {
								if nt, ok := c.Type().(*types.Named); ok && nt.Obj().Pkg() == p.Types {
									if _, ok := nt.Underlying().(*types.Basic); ok {
										u.enumVals[nt.Obj()] = append(u.enumVals[nt.Obj()], c)
										if s.Values != nil {
											src := exprString(g.L.Fset, s.Values[0])
											if strings.Contains(src, "<<") || strings.Contains(src, "|") {
												u.enumFlags[nt.Obj()] = true
											}
										}
										continue
									}
								}
								if filt != nil && !filt.Objs[obj] {
									continue
								}
								u.items[file] = append(u.items[file], &item{kind: "const", obj: obj, spec: s, gd: d, file: file})
							} else if v, ok := obj.(*types.Var); ok {
								if filt != nil && !filt.Objs[obj] {
									continue
								}
								u.items[file] = append(u.items[file], &item{kind: "var", obj: v, spec: s, gd: d, file: file})
							}
						}
					}
				}
			case *ast.FuncDecl:
				if d.Name.Name == "_" {
					continue
				}
				obj, _ := info.Defs[d.Name].(*types.Func)
				if obj == nil {
					continue
				}
				if filt != nil && !filt.Objs[obj] {
					continue
				}
				it := &item{kind: "func", fn: d, obj: obj, file: file}
				if d.Recv != nil {
					it.kind = "method"
				}
				u.items[file] = append(u.items[file], it)
			}
		}
	}
	// enum flags: also a const group that uses iota with shifts (`1 << iota`) marks every value
	for _, f := range p.Files {
		ast.Inspect(f, func(n ast.Node) bool {
			gd, ok := n.(*ast.GenDecl)
			if !ok || gd.Tok != token.CONST {
				return true
			}
			var cur *types.TypeName
			for _, s := range gd.Specs {
				vs := s.(*ast.ValueSpec)
				for _, nm := range vs.Names {
					if c, ok := info.Defs[nm].(*types.Const); ok {
						if nt, ok := c.Type().(*types.Named); ok {
							cur = nt.Obj()
						}
					}
				}
				if vs.Values != nil && cur != nil {
					src := exprString(g.L.Fset, vs.Values[0])
					if strings.Contains(src, "<<") {
						u.enumFlags[cur] = true
					}
				}
			}
			return false
		})
	}
	// type names (PORTING.md §1: capitalize unexported, `_` on clash with an exported name)
	exported := map[string]bool{}
	for _, td := range u.tdecls {
		if td.obj.Exported() {
			exported[td.obj.Name()] = true
		}
	}
	for _, td := range u.tdecls {
		hx := capFirst(td.obj.Name())
		if hx != td.obj.Name() && exported[hx] {
			hx += "_"
		}
		if haxeCore[hx] && hx != "Type" {
			hx += "_"
		}
		td.hx = hx
		u.tname[td.obj] = hx
		u.localNames[hx] = true
	}
	// method receivers, kinds
	for _, file := range u.files {
		for _, it := range u.items[file] {
			if it.kind != "method" {
				continue
			}
			sig := it.obj.Type().(*types.Signature)
			tn := baseTypeName(sig.Recv().Type())
			it.recv = u.tdecl[tn]
			if it.recv != nil {
				it.recv.nmethods++
			}
		}
	}
	for _, td := range u.tdecls {
		td.kind = u.kindOf(td)
	}
	// modules (one per Go file, PORTING.md §1; `_` suffix on clashes, §7a)
	reserved := map[string]bool{}
	for n := range haxeCore {
		reserved[n] = true
	}
	for _, imp := range p.Imports {
		elems := strings.Split(imp, "/")
		reserved[capFirst(elems[len(elems)-1])] = true
	}
	typeFile := map[string]string{}
	for _, td := range u.tdecls {
		typeFile[td.hx] = td.file
	}
	for _, file := range u.files {
		var mod string
		switch {
		case partial:
			mod = "ExtStubs"
		case file == u.mainFile:
			mod = u.pkgClass
		default:
			parts := strings.Split(strings.TrimSuffix(file, ".go"), "_")
			for i := range parts {
				parts[i] = capFirst(parts[i])
			}
			mod = strings.Join(parts, "")
			for reserved[mod] || mod == u.pkgClass || (typeFile[mod] != "" && typeFile[mod] != file) {
				mod += "_"
			}
		}
		u.modOf[file] = mod
		u.localNames[mod] = true
	}
	for _, td := range u.tdecls {
		if td.hx == u.pkgClass && td.kind == "class" && (td.file == u.mainFile || partial) {
			u.mainStruct = td
			if !partial {
				u.modOf[td.file] = u.pkgClass
			}
		}
	}
	// instance methods vs extension statics (PORTING.md §2)
	for _, file := range u.files {
		for _, it := range u.items[file] {
			if it.kind == "method" && it.recv != nil && (it.recv.file == file || partial) && it.recv.kind != "typedef" {
				it.recv.methods = append(it.recv.methods, it)
			}
		}
	}
	// base classes: first field embeds a local struct by value (AST-like data hierarchy)
	if g.inherit {
		for _, td := range u.tdecls {
			if td.kind != "class" {
				continue
			}
			st := td.obj.Type().Underlying().(*types.Struct)
			if st.NumFields() > 0 && st.Field(0).Embedded() {
				if n, ok := types.Unalias(st.Field(0).Type()).(*types.Named); ok && n.Obj().Pkg() == p.Types {
					if b := u.tdecl[n.Obj()]; b != nil && b.kind == "class" && n.TypeArgs().Len() == 0 && td.obj.Type().(*types.Named).TypeParams().Len() == 0 {
						td.base = b
					}
				}
			}
		}
	}
	u.computeImplements()
	u.computeSplit()
	return u
}

// computeSplit moves the main-struct methods of a -split file into N static-extension modules
// <Module>Part1..N, cut at function boundaries into contiguous Go line ranges of about equal size.
// Methods that implement an interface stay instance methods (Haxe `implements` needs them).
func (u *Unit) computeSplit() {
	u.part = map[*item]int{}
	if u.mainStruct == nil || u.partial {
		return
	}
	for fi, file := range u.files {
		n := u.g.split[file]
		if n < 2 {
			continue
		}
		f := u.p.Files[fi]
		total := u.g.L.Fset.File(f.Pos()).LineCount()
		var starts []int
		for _, d := range f.Decls {
			if fd, ok := d.(*ast.FuncDecl); ok {
				p := fd.Pos()
				if fd.Doc != nil {
					p = fd.Doc.Pos()
				}
				starts = append(starts, u.g.L.Fset.Position(p).Line)
			}
		}
		bounds := []int{1}
		for k := 1; k < n; k++ {
			target := 1 + k*total/n
			best := -1
			for _, s := range starts {
				if s > bounds[len(bounds)-1] && (best < 0 || abs(s-target) < abs(best-target)) {
					best = s
				}
			}
			if best < 0 {
				break
			}
			bounds = append(bounds, best)
		}
		bounds = append(bounds, total+1)
		var ps []*splitPart
		for k := 0; k+1 < len(bounds); k++ {
			ps = append(ps, &splitPart{module: u.modOf[file] + "Part" + strconv.Itoa(k+1), file: file, from: bounds[k], to: bounds[k+1] - 1})
		}
		var keep []*item
		for _, m := range u.mainStruct.methods {
			if m.file != file {
				keep = append(keep, m)
				continue
			}
			line := u.g.L.Fset.Position(m.fn.Pos()).Line
			k := 0
			for k+1 < len(ps) && line > ps[k].to {
				k++
			}
			if u.mainStruct.public[m.obj.Name()] {
				ps[k].keptPublic = append(ps[k].keptPublic, m.obj.Name())
				keep = append(keep, m)
				continue
			}
			u.part[m] = k + 1
			ps[k].items = append(ps[k].items, m)
		}
		u.mainStruct.methods = keep
		for _, p := range ps {
			u.localNames[p.module] = true
		}
		u.parts = append(u.parts, ps...)
	}
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

func exprString(fset *token.FileSet, e ast.Expr) string {
	var sb strings.Builder
	_ = printNode(&sb, fset, e)
	return sb.String()
}

func (u *Unit) kindOf(td *TypeDecl) string {
	if td.obj.IsAlias() {
		return "alias"
	}
	switch x := td.obj.Type().Underlying().(type) {
	case *types.Struct:
		return "class"
	case *types.Interface:
		if !x.IsMethodSet() {
			return "constraint"
		}
		return "interface"
	case *types.Basic:
		if len(u.enumVals[td.obj]) > 0 {
			return "enum"
		}
	}
	if td.nmethods > 0 {
		return "abstract"
	}
	return "typedef"
}

// computeImplements adds `implements I` for local interfaces whose methods the class declares
// itself (or inherits); those methods become public (Haxe interface methods are public).
func (u *Unit) computeImplements() {
	type cand struct {
		name  string // Haxe name (local) or token (external)
		iface *types.Interface
	}
	var ifaces []cand
	for _, td := range u.tdecls {
		if td.kind == "interface" && td.obj.Type().(*types.Named).TypeParams().Len() == 0 {
			if it := td.obj.Type().Underlying().(*types.Interface); it.NumMethods() > 0 {
				ifaces = append(ifaces, cand{td.hx, it})
			}
		}
	}
	// external interfaces the package refers to and that exist in Haxe (port or stub)
	seen := map[*types.TypeName]bool{}
	var ext []*types.TypeName
	for _, obj := range u.p.Info.Uses {
		tn, ok := obj.(*types.TypeName)
		if !ok || tn.Pkg() == nil || tn.Pkg() == u.p.Types || seen[tn] || !strings.HasPrefix(tn.Pkg().Path(), modulePath) {
			continue
		}
		seen[tn] = true
		if n, ok := tn.Type().(*types.Named); ok && n.TypeParams().Len() == 0 {
			if it, ok := n.Underlying().(*types.Interface); ok && it.NumMethods() > 0 {
				if hx := u.g.lookupExt(tn); hx != nil && hx.Kind == "interface" {
					ext = append(ext, tn)
				}
			}
		}
	}
	sort.Slice(ext, func(i, j int) bool { return ext[i].Pkg().Path()+ext[i].Name() < ext[j].Pkg().Path()+ext[j].Name() })
	for _, tn := range ext {
		ifaces = append(ifaces, cand{u.tok(u.g.lookupExt(tn)), tn.Type().Underlying().(*types.Interface)})
	}
	for _, td := range u.tdecls {
		if td.kind != "class" || td.obj.Type().(*types.Named).TypeParams().Len() > 0 {
			continue
		}
		for _, it := range ifaces {
			iface := it.iface
			if !types.Implements(types.NewPointer(td.obj.Type()), iface) {
				continue
			}
			owners := map[string]*TypeDecl{}
			ok := true
			for i := 0; i < iface.NumMethods() && ok; i++ {
				name := iface.Method(i).Name()
				owner := (*TypeDecl)(nil)
				for c := td; c != nil && owner == nil; c = c.base {
					for _, m := range c.methods {
						if m.obj.Name() == name {
							owner = c
						}
					}
				}
				if owner == nil {
					ok = false
				}
				owners[name] = owner
			}
			if !ok {
				u.note("implements not declared (methods in other files or promoted)", td.obj.Name()+" → "+strings.Trim(strings.Split(it.name, "|")[len(strings.Split(it.name, "|"))-1], tokClose))
				continue
			}
			inherited := false
			for c := td.base; c != nil; c = c.base {
				for _, n := range c.impl {
					if n == it.name {
						inherited = true
					}
				}
			}
			for name, o := range owners {
				o.public[name] = true
			}
			if !inherited {
				td.impl = append(td.impl, it.name)
			}
		}
	}
}

// ---------------------------------------------------------------- rendering helpers

func docText(cg *ast.CommentGroup, indent string) string {
	if cg == nil {
		return ""
	}
	var sb strings.Builder
	for _, c := range cg.List {
		for _, line := range strings.Split(c.Text, "\n") {
			sb.WriteString(indent + strings.TrimRight(line, " \t") + "\n")
		}
	}
	return sb.String()
}

func lineComment(cg *ast.CommentGroup) string {
	if cg == nil || len(cg.List) == 0 {
		return ""
	}
	return " " + strings.ReplaceAll(cg.List[0].Text, "\n", " ")
}

func vis(name string, public bool) string {
	if public || ast.IsExported(name) {
		return "public "
	}
	return ""
}

func hxString(s string) string {
	var sb strings.Builder
	sb.WriteByte('"')
	for i := 0; i < len(s); {
		r, size := utf8.DecodeRuneInString(s[i:])
		if r == utf8.RuneError && size <= 1 {
			if s[i] == 0xFE {
				sb.WriteString(`\u{FFFE}`) // PORTING.md §5: internal symbol prefix
			} else {
				fmt.Fprintf(&sb, `\u{%X}`, 0xFFFD)
			}
			i++
			continue
		}
		switch r {
		case '"':
			sb.WriteString(`\"`)
		case '\\':
			sb.WriteString(`\\`)
		case '\n':
			sb.WriteString(`\n`)
		case '\r':
			sb.WriteString(`\r`)
		case '\t':
			sb.WriteString(`\t`)
		default:
			if r < 0x20 || r == 0x7f {
				fmt.Fprintf(&sb, `\u{%X}`, r)
			} else {
				sb.WriteRune(r)
			}
		}
		i += size
	}
	sb.WriteByte('"')
	return sb.String()
}

func constLit(v constant.Value, flags bool) string {
	switch v.Kind() {
	case constant.Bool:
		return strconv.FormatBool(constant.BoolVal(v))
	case constant.String:
		return hxString(constant.StringVal(v))
	case constant.Float:
		f, _ := constant.Float64Val(v)
		s := strconv.FormatFloat(f, 'g', -1, 64)
		if !strings.ContainsAny(s, ".eEn") {
			s += ".0"
		}
		if math.IsInf(f, 0) {
			return "Math.POSITIVE_INFINITY"
		}
		return s
	case constant.Int:
		if i, ok := constant.Int64Val(v); ok {
			if i >= math.MinInt32 && i <= math.MaxInt32 {
				if flags && i > 0 && i&(i-1) == 0 {
					return fmt.Sprintf("1 << %d", bitLen(uint64(i)))
				}
				return strconv.FormatInt(i, 10)
			}
			if i > 0 && i <= math.MaxUint32 {
				if i&(i-1) == 0 {
					return fmt.Sprintf("1 << %d", bitLen(uint64(i)))
				}
				return fmt.Sprintf("0x%X", i)
			}
			return fmt.Sprintf("0x%X /* PORT: 64-bit value %d */", uint32(i), i)
		}
		if x, ok := constant.Uint64Val(v); ok {
			return fmt.Sprintf("0x%X /* PORT: 64-bit value %d */", uint32(x), x)
		}
		return "0 /* PORT: big value " + v.ExactString() + " */"
	}
	return "null"
}

func bitLen(x uint64) int {
	n := 0
	for x > 1 {
		x >>= 1
		n++
	}
	return n
}

func typeParams(l *types.TypeParamList) string {
	if l == nil || l.Len() == 0 {
		return ""
	}
	var s []string
	for i := 0; i < l.Len(); i++ {
		s = append(s, l.At(i).Obj().Name())
	}
	return "<" + strings.Join(s, ", ") + ">"
}

// names gives unique member names per Haxe class (Haxe has one namespace for statics and
// instance members; Go has separate ones for package funcs and methods).
type names struct {
	used map[string]bool
	cls  string
	g    *Gen
}

func (n *names) take(goName string, kind string) string {
	name := id(goName)
	orig := name
	for n.used[name] {
		name += "_"
	}
	if name != orig {
		n.g.renames = append(n.g.renames, fmt.Sprintf("%s.%s → %s (%s; name clash in the Haxe class)", n.cls, goName, name, kind))
	}
	n.used[name] = true
	return name
}

// ---------------------------------------------------------------- prepare (instance members)

func (u *Unit) prepare(td *TypeDecl) {
	if td.prepared {
		return
	}
	td.prepared = true
	if td.base != nil {
		u.prepare(td.base)
	}
	td.inst = map[string]string{}
	td.msig = map[string]string{}
	td.mpublic = map[string]bool{}
	used := map[string]bool{}
	for c := td.base; c != nil; c = c.base {
		for _, n := range c.inst {
			used[n] = true
		}
	}
	nm := &names{used: used, cls: td.hx, g: u.g}
	if td.kind == "class" {
		st := td.obj.Type().Underlying().(*types.Struct)
		var astFields []*ast.Field
		if s, ok := td.spec.Type.(*ast.StructType); ok {
			astFields = s.Fields.List
		} else {
			// defined type over another struct type (`type K xxh3.Uint128`): fields from go/types
			for i := 0; i < st.NumFields(); i++ {
				astFields = append(astFields, &ast.Field{Names: []*ast.Ident{ast.NewIdent(st.Field(i).Name())}})
			}
		}
		fi := 0
		for _, af := range astFields {
			n := len(af.Names)
			if n == 0 {
				n = 1
			}
			for k := 0; k < n; k++ {
				f := st.Field(fi)
				fi++
				if fi == 1 && td.base != nil {
					continue
				}
				if u.filt != nil && !u.filt.Objs[f] {
					continue
				}
				name := nm.take(f.Name(), "field")
				td.inst[f.Name()] = name
				u.anonCtx = td.hx + capFirst(f.Name())
				line := ""
				if k == 0 {
					line += docText(af.Doc, "\t")
				}
				line += "\t" + vis(f.Name(), false) + "var " + name + ":" + u.T(f.Type()) + " = " + u.Zero(f.Type()) + ";"
				if f.Embedded() {
					line += " // Go: embedded"
				}
				line += lineComment(af.Comment) + "\n"
				td.fields = append(td.fields, line)
				u.nFields++
			}
		}
	}
	for _, m := range td.methods {
		goName := m.obj.Name()
		sig := u.sigText(m.obj.(*types.Func), false, nil)
		public := td.public[goName]
		var anc *TypeDecl
		for c := td.base; c != nil; c = c.base {
			if _, ok := c.msig[goName]; ok {
				anc = c
				break
			}
		}
		if anc != nil && anc.msig[goName] == sig {
			td.inst[goName] = anc.inst[goName]
			td.msig[goName] = sig
			td.mpublic[goName] = public || anc.mpublic[goName]
			continue
		}
		name := nm.take(goName, "method")
		td.inst[goName] = name
		td.msig[goName] = sig
		td.mpublic[goName] = public
	}
}

// sigText renders `<TP>(params):Ret` for a func; recv adds the receiver as first parameter.
func (u *Unit) sigText(f *types.Func, asStatic bool, recv *ast.FieldList) string {
	sig := f.Type().(*types.Signature)
	tp := typeParams(sig.TypeParams())
	ps := u.paramList(sig.Params(), sig.Variadic())
	if asStatic && sig.Recv() != nil {
		tp = typeParams(sig.RecvTypeParams())
		rn := sig.Recv().Name()
		if rn == "" || rn == "_" {
			rn = "recv"
		}
		ps = append([]string{id(rn) + ":" + u.T(sig.Recv().Type())}, ps...)
	}
	return tp + "(" + strings.Join(ps, ", ") + "):" + u.results(sig.Results(), capFirst(f.Name()))
}

func (u *Unit) unported(it *item) string {
	file, line := u.g.pos(it.fn.Pos())
	name := u.p.Name + "."
	if it.recv != nil {
		name += it.recv.obj.Name() + "."
	} else if it.kind == "method" {
		name += baseTypeName(it.obj.Type().(*types.Signature).Recv().Type()).Name() + "."
	}
	name += it.obj.Name()
	return fmt.Sprintf("\t\tthrow \"unported: %s (%s:%d)\";\n", name, file, line)
}

func (u *Unit) renderFunc(it *item, name string, static bool, public bool, override bool) string {
	var sb strings.Builder
	sb.WriteString(docText(it.fn.Doc, "\t"))
	sb.WriteString("\t" + vis(it.obj.Name(), public))
	if override {
		sb.WriteString("override ")
	}
	if static {
		sb.WriteString("static ")
	}
	asStatic := static && it.kind == "method"
	sb.WriteString("function " + name + u.sigText(it.obj.(*types.Func), asStatic, nil) + " {\n")
	sb.WriteString(u.unported(it))
	sb.WriteString("\t}\n")
	if it.kind == "method" {
		u.nMethods++
	} else {
		u.nFuncs++
	}
	return sb.String()
}

func (u *Unit) renderValue(it *item, name string) string {
	var sb strings.Builder
	doc := it.spec.Doc
	if doc == nil && len(it.gd.Specs) == 1 {
		doc = it.gd.Doc
	}
	sb.WriteString(docText(doc, "\t"))
	u.anonCtx = capFirst(it.obj.Name())
	typ := it.obj.Type()
	file, line := u.g.pos(it.obj.Pos())
	if it.kind == "const" {
		c := it.obj.(*types.Const)
		lit := constLit(c.Val(), false)
		if b, ok := typ.(*types.Basic); ok {
			if b.Info()&types.IsUntyped != 0 {
				typ = types.Default(typ)
			}
			sb.WriteString("\t" + vis(it.obj.Name(), false) + "static inline final " + name + ":" + u.T(typ) + " = " + lit + ";")
		} else {
			sb.WriteString("\t" + vis(it.obj.Name(), false) + "static final " + name + ":" + u.T(typ) + " = cast " + lit + ";")
		}
	} else {
		init := ""
		for i, n := range it.spec.Names {
			if n.Name == it.obj.Name() && i < len(it.spec.Values) {
				init = exprString(u.g.L.Fset, it.spec.Values[i])
			}
		}
		sb.WriteString("\t" + vis(it.obj.Name(), false) + "static var " + name + ":" + u.T(typ) + " = " + u.Zero(typ) + ";")
		if init != "" {
			first := strings.SplitN(init, "\n", 2)[0]
			if len(first) > 100 {
				first = first[:100] + "…"
			} else if strings.Contains(init, "\n") {
				first += " …"
			}
			sb.WriteString(fmt.Sprintf(" // PORT: initializer (%s:%d): %s", file, line, first))
		}
	}
	sb.WriteString(lineComment(it.spec.Comment) + "\n")
	return sb.String()
}

// ---------------------------------------------------------------- types

func (u *Unit) renderType(td *TypeDecl) string {
	var sb strings.Builder
	u.nTypes++
	sb.WriteString(docText(td.doc, ""))
	n := td.obj.Type()
	var tps string
	if nt, ok := n.(*types.Named); ok {
		tps = typeParams(nt.TypeParams())
	} else if at, ok := n.(*types.Alias); ok {
		tps = typeParams(at.TypeParams())
	}
	switch td.kind {
	case "alias":
		sb.WriteString("typedef " + td.hx + tps + " = " + u.T(n.(*types.Alias).Rhs()) + ";\n")
	case "constraint":
		sb.WriteString("typedef " + td.hx + tps + " = Any; // Go type constraint: " + n.Underlying().String() + "\n")
	case "typedef":
		sb.WriteString("typedef " + td.hx + tps + " = " + u.T(n.Underlying()) + ";\n")
	case "interface":
		sb.WriteString(u.renderInterface(td, tps))
	case "enum", "abstract":
		sb.WriteString(u.renderAbstract(td, tps))
	case "class":
		sb.WriteString(u.renderClass(td, tps, nil, nil))
	}
	return sb.String()
}

func (u *Unit) renderInterface(td *TypeDecl, tps string) string {
	var sb strings.Builder
	iface := td.obj.Type().Underlying().(*types.Interface)
	var ext []string
	flat := false
	for i := 0; i < iface.NumEmbeddeds(); i++ {
		e := types.Unalias(iface.EmbeddedType(i))
		if nt, ok := e.(*types.Named); ok && nt.Obj().Pkg() == u.p.Types && u.tdecl[nt.Obj()] != nil {
			ext = append(ext, " extends "+u.T(nt))
		} else {
			flat = true
		}
	}
	if flat {
		ext = nil
	}
	sb.WriteString("interface " + td.hx + tps + strings.Join(ext, "") + " {\n")
	docs := map[string]*ast.CommentGroup{}
	if it, ok := td.spec.Type.(*ast.InterfaceType); ok {
		for _, m := range it.Methods.List {
			for _, nm := range m.Names {
				docs[nm.Name] = m.Doc
			}
		}
	}
	count := iface.NumExplicitMethods()
	get := iface.ExplicitMethod
	if flat {
		count, get = iface.NumMethods(), iface.Method
	}
	for i := 0; i < count; i++ {
		m := get(i)
		sb.WriteString(docText(docs[m.Name()], "\t"))
		sb.WriteString("\tfunction " + id(m.Name()) + u.sigText(m, false, nil) + ";\n")
	}
	sb.WriteString("}\n")
	return sb.String()
}

func (u *Unit) renderAbstract(td *TypeDecl, tps string) string {
	var sb strings.Builder
	under := u.T(td.obj.Type().Underlying())
	if td.kind == "enum" {
		sb.WriteString("enum ")
	}
	nm := &names{used: map[string]bool{}, cls: td.hx, g: u.g}
	allow := false
	for _, m := range td.methods {
		if !ast.IsExported(m.obj.Name()) {
			allow = true
		}
	}
	if allow {
		sb.WriteString("@:allow(" + u.hxPkg + ")\n")
	}
	sb.WriteString("abstract " + td.hx + tps + "(" + under + ") from " + under + " to " + under + " {\n")
	if td.kind == "enum" {
		flags := u.enumFlags[td.obj]
		if flags {
			t := td.hx
			sb.WriteString(fmt.Sprintf("\t@:op(A | B) static function or(a:%s, b:%s):%s;\n\t@:op(A & B) static function and(a:%s, b:%s):%s;\n\t@:op(~A) static function not(a:%s):%s;\n\n", t, t, t, t, t, t, t, t))
			nm.used["or"], nm.used["and"], nm.used["not"] = true, true, true
		}
		for _, c := range u.enumVals[td.obj] {
			if p := u.findSpec(c); p != nil && p.Doc != nil {
				sb.WriteString(docText(p.Doc, "\t"))
			}
			name := nm.take(c.Name(), "enum value")
			sb.WriteString("\tvar " + name + " = " + constLit(c.Val(), flags) + ";")
			if p := u.findSpec(c); p != nil {
				sb.WriteString(lineComment(p.Comment))
			}
			sb.WriteString("\n")
			u.nEnumVals++
		}
	}
	for _, m := range td.methods {
		sb.WriteString("\n" + u.renderFunc(m, nm.take(m.obj.Name(), "method"), false, false, false))
	}
	sb.WriteString("}\n")
	return sb.String()
}

func (u *Unit) findSpec(c *types.Const) *ast.ValueSpec {
	for _, f := range u.p.Files {
		if f.Pos() <= c.Pos() && c.Pos() < f.End() {
			var res *ast.ValueSpec
			ast.Inspect(f, func(n ast.Node) bool {
				if res != nil {
					return false
				}
				if vs, ok := n.(*ast.ValueSpec); ok {
					for _, nm := range vs.Names {
						if nm.Pos() == c.Pos() {
							res = vs
						}
					}
					return false
				}
				return true
			})
			return res
		}
	}
	return nil
}

// renderClass renders a struct class. statics: package-level items (package class) or extension
// methods hosted by this class; seps marks `// --- file.go ---` separators.
func (u *Unit) renderClass(td *TypeDecl, tps string, statics []*item, seps map[*item]string) string {
	u.prepare(td)
	var body strings.Builder
	used := map[string]bool{}
	for c := td; c != nil; c = c.base {
		for _, n := range c.inst {
			used[n] = true
		}
	}
	nm := &names{used: used, cls: td.hx, g: u.g}
	allow := false
	if seps != nil && seps[nil] != "" {
		body.WriteString("\t" + seps[nil] + "\n\n")
	}
	for _, f := range td.fields {
		body.WriteString(f)
		if strings.Contains(f, "\tvar ") {
			allow = true
		}
	}
	if len(td.fields) > 0 {
		body.WriteString("\n")
	}
	if td.base != nil {
		body.WriteString("\tpublic function new() {\n\t\tsuper();\n\t}\n")
	} else {
		body.WriteString("\tpublic function new() {}\n")
	}
	// instance methods and statics of the same file interleaved in source order
	type entry struct {
		it     *item
		static bool
	}
	var entries []entry
	for _, m := range td.methods {
		entries = append(entries, entry{m, false})
	}
	for _, s := range statics {
		entries = append(entries, entry{s, true})
	}
	fileIdx := map[string]int{}
	for i, f := range u.files {
		fileIdx[f] = i
	}
	sort.SliceStable(entries, func(i, j int) bool {
		a, b := entries[i].it, entries[j].it
		if a.file != b.file {
			return fileIdx[a.file] < fileIdx[b.file]
		}
		return a.obj.Pos() < b.obj.Pos()
	})
	// static names after all instance names are known
	staticName := map[*item]string{}
	for _, e := range entries {
		if e.static {
			staticName[e.it] = nm.take(e.it.obj.Name(), e.it.kind)
		}
	}
	for _, e := range entries {
		it := e.it
		if s := seps[it]; s != "" {
			body.WriteString("\n\t" + s + "\n")
		}
		body.WriteString("\n")
		if !ast.IsExported(it.obj.Name()) {
			allow = true
		}
		if !e.static {
			goName := it.obj.Name()
			override := false
			for c := td.base; c != nil; c = c.base {
				if _, ok := c.msig[goName]; ok && c.inst[goName] == td.inst[goName] {
					override = true
					break
				}
			}
			body.WriteString(u.renderFunc(it, td.inst[goName], false, td.mpublic[goName], override))
			continue
		}
		if it.kind == "var" || it.kind == "const" {
			body.WriteString(u.renderValue(it, staticName[it]))
		} else {
			body.WriteString(u.renderFunc(it, staticName[it], true, false, false))
		}
	}
	var sb strings.Builder
	if allow {
		sb.WriteString("@:allow(" + u.hxPkg + ")\n")
	}
	sb.WriteString("class " + td.hx + tps)
	if td.base != nil {
		sb.WriteString(" extends " + td.base.hx)
	}
	for _, i := range td.impl {
		sb.WriteString(" implements " + i)
	}
	sb.WriteString(" {\n")
	sb.WriteString(body.String())
	sb.WriteString("}\n")
	return sb.String()
}

// renderStaticClass renders a class without instance members: the package class of a package
// without a main struct, or an extension class (PORTING.md §2).
func (u *Unit) renderStaticClass(name string, statics []*item, seps map[*item]string, doc string) string {
	var body strings.Builder
	nm := &names{used: map[string]bool{}, cls: name, g: u.g}
	if seps[nil] != "" {
		body.WriteString("\t" + seps[nil] + "\n")
	}
	allow := false
	for _, it := range statics {
		if s := seps[it]; s != "" {
			body.WriteString("\n\t" + s + "\n")
		}
		body.WriteString("\n")
		if !ast.IsExported(it.obj.Name()) {
			allow = true
		}
		n := nm.take(it.obj.Name(), it.kind)
		if it.kind == "var" || it.kind == "const" {
			body.WriteString(u.renderValue(it, n))
		} else {
			body.WriteString(u.renderFunc(it, n, true, false, false))
		}
	}
	var sb strings.Builder
	sb.WriteString(doc)
	if allow {
		sb.WriteString("@:allow(" + u.hxPkg + ")\n")
	}
	sb.WriteString("class " + name + " {\n" + body.String() + "}\n")
	return sb.String()
}

// ---------------------------------------------------------------- generated helper classes

func (u *Unit) uniqueType(name string) string {
	for u.localNames[name] {
		name += "_"
	}
	u.localNames[name] = true
	return name
}

func (u *Unit) anonStruct(t *types.Struct) string {
	if n, ok := u.anonNames[t]; ok {
		return n
	}
	ctx := u.anonCtx
	if ctx == "" {
		ctx = "Anon"
	}
	name := u.uniqueType(ctx + "Struct")
	u.anonNames[t] = name
	u.note("anonymous struct → generated class", name)
	var sb strings.Builder
	sb.WriteString("// Go: anonymous struct type\nclass " + name + " {\n")
	for i := 0; i < t.NumFields(); i++ {
		f := t.Field(i)
		u.anonCtx = name + capFirst(f.Name())
		sb.WriteString("\tpublic var " + id(f.Name()) + ":" + u.T(f.Type()) + " = " + u.Zero(f.Type()) + ";\n")
	}
	sb.WriteString("\n\tpublic function new() {}\n}\n")
	u.extra[u.curModule] = append(u.extra[u.curModule], sb.String())
	return name
}

func (u *Unit) resultClass(r *types.Tuple, ctx string) string {
	name := u.uniqueType(ctx + "Result")
	u.note("4+ results → generated result class", name)
	var sb strings.Builder
	var fields, params, assigns []string
	for i := 0; i < r.Len(); i++ {
		v := r.At(i)
		fname := v.Name()
		if fname == "" || fname == "_" {
			fname = "r" + strconv.Itoa(i)
		}
		fname = id(fname)
		t := u.T(v.Type())
		fields = append(fields, "\tpublic final "+fname+":"+t+";\n")
		params = append(params, fname+":"+t)
		assigns = append(assigns, "\t\tthis."+fname+" = "+fname+";\n")
	}
	sb.WriteString("// Go: multiple results (" + strconv.Itoa(r.Len()) + ") of " + ctx + "\nfinal class " + name + " {\n")
	sb.WriteString(strings.Join(fields, ""))
	sb.WriteString("\n\tpublic inline function new(" + strings.Join(params, ", ") + ") {\n" + strings.Join(assigns, "") + "\t}\n}\n")
	u.extra[u.curModule] = append(u.extra[u.curModule], sb.String())
	return name
}

// ---------------------------------------------------------------- modules

func (u *Unit) Generate() {
	header := func(file string) string {
		src := u.p.Rel + "/" + file
		return "package " + u.hxPkg + ";\n\n// GENERATED SKELETON by tools/gen/skeleton from " + src + " (upstream " + "v7.0.2" + ").\n" +
			"// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).\n\n"
	}
	pkgModule := u.pkgClass
	// package-level items: all go to the package class
	var pkgStatics []*item
	pkgSeps := map[*item]string{}
	for _, file := range u.files {
		first := true
		for _, it := range u.items[file] {
			if it.kind == "method" {
				continue
			}
			if first {
				if file == u.mainFile && u.mainStruct != nil {
					pkgSeps[nil] = "// --- " + file + " ---"
				} else {
					pkgSeps[it] = "// --- " + file + " ---"
				}
				first = false
			}
			pkgStatics = append(pkgStatics, it)
		}
	}
	if u.mainStruct != nil && pkgSeps[nil] == "" {
		pkgSeps[nil] = "// --- " + u.mainStruct.file + " ---"
	}
	// extension methods per file
	extOf := map[string][]*item{}
	for _, file := range u.files {
		for _, it := range u.items[file] {
			if it.kind != "method" {
				continue
			}
			if u.part[it] > 0 {
				continue
			}
			if it.recv == nil || !(it.recv.file == file || u.partial) || it.recv.kind == "typedef" {
				extOf[file] = append(extOf[file], it)
			}
		}
	}
	modFiles := map[string][]string{}
	var order []string
	for _, f := range u.files {
		m := u.modOf[f]
		if _, ok := modFiles[m]; !ok {
			order = append(order, m)
		}
		modFiles[m] = append(modFiles[m], f)
	}
	if !u.partial {
		if _, ok := modFiles[pkgModule]; !ok && len(pkgStatics) > 0 {
			order = append([]string{pkgModule}, order...)
			modFiles[pkgModule] = nil
		}
	}
	for _, mod := range order {
		u.curModule = mod
		var sb strings.Builder
		files := modFiles[mod]
		hdr := mod + ".hx"
		if len(files) > 0 {
			hdr = files[0]
		}
		if u.partial {
			hdr = "(stubs of the symbols used by the skeleton)"
		}
		sb.WriteString(header(hdr))
		hasContent := false
		var hostTD *TypeDecl
		for _, td := range u.tdecls {
			if u.modOf[td.file] != mod || td == u.mainStruct {
				continue
			}
			if td.hx == mod && td.kind == "class" {
				hostTD = td // module main type hosts the extension statics
				continue
			}
			sb.WriteString(u.renderType(td) + "\n")
			hasContent = true
		}
		var ext []*item
		extSeps := map[*item]string{}
		for _, f := range files {
			ext = append(ext, extOf[f]...)
		}
		if mod == pkgModule && !u.partial {
			if u.mainStruct != nil {
				statics := append(append([]*item{}, pkgStatics...), ext...)
				sb.WriteString(docText(u.mainStruct.doc, ""))
				sb.WriteString(u.renderClass(u.mainStruct, typeParams(u.mainStruct.obj.Type().(*types.Named).TypeParams()), statics, pkgSeps))
				u.nTypes++
			} else {
				sb.WriteString(u.renderStaticClass(u.pkgClass, append(append([]*item{}, pkgStatics...), ext...), pkgSeps, "// Package class: package-level funcs, vars and consts of "+u.p.Rel+" (all files).\n"))
			}
			if len(ext) > 0 {
				u.extModule[mod] = true
			}
			hasContent = true
		} else if hostTD != nil {
			sb.WriteString(docText(hostTD.doc, ""))
			if len(ext) > 0 {
				sb.WriteString("// Also holds the methods of " + hdr + " on other receivers as statics (static extension, PORTING.md §2).\n")
				u.extModule[mod] = true
			}
			sb.WriteString(u.renderClass(hostTD, typeParams(hostTD.obj.Type().(*types.Named).TypeParams()), ext, extSeps))
			u.nTypes++
			hasContent = true
		} else if len(ext) > 0 {
			name := mod
			if u.localNames[name] && u.typeIn(name, mod) {
				name += "Methods"
			}
			sb.WriteString(u.renderStaticClass(name, ext, extSeps, "// Methods of "+hdr+" on receivers declared in other files: static extension (PORTING.md §2).\n"))
			u.extModule[mod] = true
			hasContent = true
		}
		for len(u.extra[mod]) > 0 {
			x := u.extra[mod]
			u.extra[mod] = nil
			for _, e := range x {
				sb.WriteString("\n" + e)
			}
			hasContent = true
		}
		if hasContent {
			u.text[mod] = sb.String()
			u.modules = append(u.modules, mod)
		}
	}
	for _, p := range u.parts {
		mod := p.module
		u.curModule = mod
		var sb strings.Builder
		sb.WriteString(header(p.file))
		goLines := p.to - p.from + 1
		doc := fmt.Sprintf("// Part of %s, Go lines %d-%d (%d lines): the %s methods of this range as static extension\n"+
			"// (receiver first, PORTING.md §2; `using %s.%s` in import.hx). Inside class %s call them as `this.m(...)`.\n",
			p.file, p.from, p.to, goLines, u.mainStruct.hx, u.hxPkg, mod, u.mainStruct.hx)
		if len(p.keptPublic) > 0 {
			doc += "// Kept as instance methods in " + u.mainStruct.hx + ".hx (they implement an interface): " + strings.Join(p.keptPublic, ", ") + "\n"
		}
		sb.WriteString(u.renderStaticClass(mod, p.items, map[*item]string{}, doc))
		for len(u.extra[mod]) > 0 {
			x := u.extra[mod]
			u.extra[mod] = nil
			for _, e := range x {
				sb.WriteString("\n" + e)
			}
		}
		u.text[mod] = sb.String()
		u.modules = append(u.modules, mod)
		u.extModule[mod] = true
		u.SplitInfo = append(u.SplitInfo, fmt.Sprintf("%s.hx  %s:%d-%d  Go lines %d, methods %d, kept instance (interface) %d %v",
			mod, p.file, p.from, p.to, goLines, len(p.items), len(p.keptPublic), p.keptPublic))
	}
}

func (u *Unit) typeIn(name, mod string) bool {
	for _, td := range u.tdecls {
		if td.hx == name && u.modOf[td.file] == mod {
			return true
		}
	}
	return false
}
