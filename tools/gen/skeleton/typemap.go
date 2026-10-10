package main

// Go type → Haxe type text (PORTING.md §3, §4a).
//
// External Haxe types are written as tokens «pkg|module|name»; after all modules of a unit are
// generated, finishImports decides per type whether it is imported (short name) or written fully
// qualified (name clash), and replaces the tokens.

import (
	"fmt"
	"go/types"
	"strconv"
	"strings"
)

const tokOpen, tokClose = "«", "»"

func capFirst(s string) string {
	if s == "" {
		return s
	}
	return strings.ToUpper(s[:1]) + s[1:]
}

var hxKeywords = map[string]bool{}

func init() {
	for _, k := range strings.Fields("abstract break case cast catch class continue default do dynamic else enum extends extern false final for function if implements import in inline interface macro new null operator overload override package private public return static switch this throw true try typedef untyped using var while is trace") {
		hxKeywords[k] = true
	}
}

// id applies the keyword rule (PORTING.md §1).
func id(s string) string {
	if hxKeywords[s] {
		return s + "_"
	}
	return s
}

// hxPkgOf maps a Go import path to the Haxe package.
func hxPkgOf(path string) string {
	if strings.HasPrefix(path, modulePath) {
		rel := strings.TrimPrefix(path, modulePath)
		rel = strings.TrimPrefix(rel, "internal/")
		return "ts." + strings.ReplaceAll(rel, "/", ".")
	}
	return "go"
}

func (u *Unit) tok(t *HxType) string {
	u.refs[t] = true
	return tokOpen + t.Pkg + "|" + t.Module + "|" + t.Name + tokClose
}

// builtin Haxe / shim types that are referenced through tokens
func (g *Gen) builtin(pkg, module, name string) *HxType {
	if t := g.X.Lookup(pkg, name); t != nil && t.Module == module {
		return t
	}
	t := &HxType{Pkg: pkg, Module: module, Name: name, Kind: "class", ZeroCtor: true, Members: map[string]bool{}}
	g.X.Add(t)
	return t
}

func (u *Unit) note(kind, detail string) {
	u.g.notes[kind+": "+detail]++
}

// T maps a Go type to Haxe.
func (u *Unit) T(t types.Type) string {
	switch t := t.(type) {
	case *types.Alias:
		obj := t.Obj()
		if obj.Pkg() == u.p.Types {
			if name, ok := u.tname[obj]; ok {
				return name + u.typeArgs(t.TypeArgs())
			}
		} else if obj.Pkg() != nil {
			if hx := u.g.lookupExt(obj); hx != nil {
				return u.tok(hx) + u.typeArgs(t.TypeArgs())
			}
		}
		return u.T(types.Unalias(t))
	case *types.Named:
		obj := t.Obj()
		if obj.Pkg() == nil {
			switch obj.Name() {
			case "error":
				return u.tok(u.g.builtin("go", "Errors", "Error"))
			}
			return "Any"
		}
		if obj.Pkg() == u.p.Types {
			if name, ok := u.tname[obj]; ok {
				return name + u.typeArgs(t.TypeArgs())
			}
		}
		return u.extNamed(t)
	case *types.Basic:
		return u.basic(t)
	case *types.Pointer:
		elem := t.Elem()
		if b, ok := types.Unalias(elem).(*types.Basic); ok {
			u.note("pointer to basic", b.String())
			return "Null<" + u.basic(b) + "> /* PORT: pointer */"
		}
		return u.T(elem)
	case *types.Slice:
		return "Array<" + u.T(t.Elem()) + ">"
	case *types.Array:
		return "Array<" + u.T(t.Elem()) + ">"
	case *types.Map:
		return u.mapType(t)
	case *types.Signature:
		return u.funcType(t)
	case *types.Interface:
		if t.Empty() {
			return "Any"
		}
		u.note("anonymous interface", t.String())
		return "Any /* " + t.String() + " */"
	case *types.Struct:
		if t.NumFields() == 0 {
			return "Any"
		}
		return u.anonStruct(t)
	case *types.Chan:
		u.note("channel", t.String())
		return "Any /* " + t.String() + " */"
	case *types.TypeParam:
		return t.Obj().Name()
	case *types.Tuple:
		return u.results(t, "")
	}
	u.note("unmapped type", fmt.Sprintf("%T", t))
	return "Any"
}

func (u *Unit) typeArgs(l *types.TypeList) string {
	if l == nil || l.Len() == 0 {
		return ""
	}
	var s []string
	for i := 0; i < l.Len(); i++ {
		s = append(s, u.T(l.At(i)))
	}
	return "<" + strings.Join(s, ", ") + ">"
}

func (u *Unit) basic(b *types.Basic) string {
	switch b.Kind() {
	case types.Bool, types.UntypedBool:
		return "Bool"
	case types.Int64, types.Uint64:
		u.note("64-bit int mapped to Int", b.Name())
		return "Int"
	case types.Int, types.Int8, types.Int16, types.Int32, types.Uint, types.Uint8, types.Uint16, types.Uint32, types.Uintptr, types.UntypedInt, types.UntypedRune:
		return "Int"
	case types.Float32, types.Float64, types.UntypedFloat:
		return "Float"
	case types.String, types.UntypedString:
		return "std.String"
	}
	return "Any"
}

// lookupExt finds the Haxe type for a named Go type of another package (index + stubs).
func (g *Gen) lookupExt(obj *types.TypeName) *HxType {
	path := obj.Pkg().Path()
	if strings.HasPrefix(path, modulePath) {
		pkg := hxPkgOf(path)
		if t := g.X.Lookup(pkg, obj.Name()); t != nil {
			return t
		}
		if t := g.X.Lookup(pkg, capFirst(obj.Name())); t != nil {
			return t
		}
		return nil
	}
	// Go std / third party: shims in src/go, module = package name with upper-case first letter.
	switch path + "." + obj.Name() {
	case "strings.Builder":
		return g.builtin("", "StringBuf", "StringBuf")
	case "context.Context":
		return g.builtin("go", "Context", "Context")
	}
	elems := strings.Split(path, "/")
	module := capFirst(elems[len(elems)-1])
	if t := g.X.Lookup("go", obj.Name()); t != nil && t.Module == module {
		return t
	}
	return nil
}

func (u *Unit) extNamed(t *types.Named) string {
	obj := t.Obj()
	if hx := u.g.lookupExt(obj); hx != nil {
		return u.tok(hx) + u.typeArgs(t.TypeArgs())
	}
	path := obj.Pkg().Path()
	full := strings.TrimPrefix(path, modulePath) + "." + obj.Name()
	switch {
	case path == "iter":
		return u.T(t.Underlying())
	case path == "sync" || path == "sync/atomic":
		u.note("sync type mapped to Any", full)
		return "Any /* " + full + " */"
	}
	u.g.unresolved[full]++
	if b, ok := t.Underlying().(*types.Basic); ok {
		return u.basic(b) + " /* ?" + full + " */"
	}
	return "Any /* ?" + full + " */"
}

func (u *Unit) mapType(m *types.Map) string {
	v := u.T(m.Elem())
	if s, ok := m.Elem().Underlying().(*types.Struct); ok && s.NumFields() == 0 {
		v = "Bool"
	}
	k := types.Unalias(m.Key())
	if _, ok := k.(*types.TypeParam); ok {
		return u.tok(u.g.builtin("go", "GoMap", "GoMap")) + "<" + u.T(k) + ", " + v + ">"
	}
	switch ku := k.Underlying().(type) {
	case *types.Basic:
		switch {
		case ku.Info()&types.IsString != 0:
			return u.tok(u.g.builtin("haxe.ds", "StringMap", "StringMap")) + "<" + v + ">"
		case ku.Info()&types.IsInteger != 0:
			if ku.Kind() == types.Int64 || ku.Kind() == types.Uint64 {
				u.note("64-bit map key", m.String())
			}
			return u.tok(u.g.builtin("haxe.ds", "IntMap", "IntMap")) + "<" + v + ">"
		}
		return u.tok(u.g.builtin("go", "GoMap", "GoMap")) + "<" + u.T(k) + ", " + v + ">"
	case *types.Pointer, *types.Chan:
		return u.tok(u.g.builtin("haxe.ds", "ObjectMap", "ObjectMap")) + "<" + u.T(k) + ", " + v + ">"
	case *types.Interface:
		if ku.Empty() {
			return u.tok(u.g.builtin("go", "GoMap", "GoMap")) + "<Any, " + v + ">"
		}
		return u.tok(u.g.builtin("haxe.ds", "ObjectMap", "ObjectMap")) + "<" + u.T(k) + ", " + v + ">"
	case *types.Struct, *types.Array:
		u.note("struct map key encoded as String (PORTING §4a)", types.TypeString(k, nil))
		return u.tok(u.g.builtin("haxe.ds", "StringMap", "StringMap")) + "<" + v + "> /* key: " + types.TypeString(k, func(p *types.Package) string { return p.Name() }) + " */"
	}
	return u.tok(u.g.builtin("go", "GoMap", "GoMap")) + "<" + u.T(k) + ", " + v + ">"
}

// paramList renders a parameter tuple: names when given (keyword rule, blanks numbered).
func (u *Unit) paramList(params *types.Tuple, variadic bool) []string {
	var out []string
	seen := map[string]bool{}
	for i := 0; i < params.Len(); i++ {
		p := params.At(i)
		name := p.Name()
		if name == "" {
			name = "arg" + strconv.Itoa(i)
		} else if name == "_" && seen["_"] {
			name = "_" + strconv.Itoa(i)
		}
		name = id(name)
		seen[name] = true
		typ := p.Type()
		if variadic && i == params.Len()-1 {
			out = append(out, "..."+name+":"+u.T(typ.(*types.Slice).Elem()))
		} else {
			out = append(out, name+":"+u.T(typ))
		}
	}
	return out
}

func (u *Unit) funcType(s *types.Signature) string {
	ps := u.paramList(s.Params(), s.Variadic())
	named := s.Variadic()
	for i := 0; i < s.Params().Len(); i++ {
		if s.Params().At(i).Name() != "" {
			named = true
		}
	}
	if !named {
		ps = nil
		for i := 0; i < s.Params().Len(); i++ {
			ps = append(ps, u.T(s.Params().At(i).Type()))
		}
	}
	r := u.results(s.Results(), "")
	if strings.Contains(r, "->") {
		r = "(" + r + ")"
	}
	return "(" + strings.Join(ps, ", ") + ") -> " + r
}

// results maps Go results to one Haxe type (PORTING.md §3: go.Tuple).
// ctx names a generated result class for 4+ results ("" = not allowed here).
func (u *Unit) results(r *types.Tuple, ctx string) string {
	switch r.Len() {
	case 0:
		return "Void"
	case 1:
		return u.T(r.At(0).Type())
	case 2:
		second := r.At(1).Type()
		if b, ok := second.(*types.Basic); ok && b.Kind() == types.Bool {
			return u.tok(u.g.builtin("go", "Tuple", "ValueOk")) + "<" + u.T(r.At(0).Type()) + ">"
		}
		if n, ok := second.(*types.Named); ok && n.Obj().Pkg() == nil && n.Obj().Name() == "error" {
			return u.tok(u.g.builtin("go", "Tuple", "ValueError")) + "<" + u.T(r.At(0).Type()) + ">"
		}
		return u.tok(u.g.builtin("go", "Tuple", "Pair")) + "<" + u.T(r.At(0).Type()) + ", " + u.T(second) + ">"
	case 3:
		return u.tok(u.g.builtin("go", "Tuple", "Triple")) + "<" + u.T(r.At(0).Type()) + ", " + u.T(r.At(1).Type()) + ", " + u.T(r.At(2).Type()) + ">"
	}
	if ctx == "" {
		u.note("4+ results in a func type", r.String())
		return "Any /* " + r.String() + " */"
	}
	return u.resultClass(r, ctx)
}

// Zero returns Go's zero value as a Haxe initializer (PORTING.md §3).
func (u *Unit) Zero(t types.Type) string {
	t = types.Unalias(t)
	switch x := t.Underlying().(type) {
	case *types.Basic:
		lit := "null"
		switch {
		case x.Info()&types.IsBoolean != 0:
			lit = "false"
		case x.Info()&types.IsInteger != 0:
			lit = "0"
		case x.Info()&types.IsFloat != 0:
			lit = "0.0"
		case x.Info()&types.IsString != 0:
			lit = `""`
		}
		if n, ok := t.(*types.Named); ok && n.Obj().Pkg() != u.p.Types && n.Obj().Pkg() != nil {
			if hx := u.g.lookupExt(n.Obj()); hx != nil && strings.Contains(hx.Kind, "abstract") && !hx.FromBase {
				return "cast " + lit
			}
		}
		return lit
	case *types.Struct:
		n, ok := t.(*types.Named)
		if !ok {
			if x.NumFields() == 0 {
				return "null"
			}
			return "new " + u.T(t) + "()"
		}
		if n.Obj().Pkg() == u.p.Types {
			if td := u.tdecl[n.Obj()]; td != nil && td.kind == "class" {
				return "new " + u.T(t) + "()"
			}
			return "null"
		}
		hx := u.g.lookupExt(n.Obj())
		if hx != nil && hx.Pkg == "ts.core" && (hx.Name == "Arena" || hx.Name == "LinkStore") && n.TypeArgs().Len() > 0 {
			// PORTING.md §4a: built with a factory for the zero element
			el := n.TypeArgs().At(n.TypeArgs().Len() - 1)
			return "new " + u.T(t) + "(() -> " + u.Zero(el) + ")"
		}
		if hx == nil || !hx.ZeroCtor || hx.Kind != "class" {
			u.note("zero struct value without new()", n.Obj().Pkg().Name()+"."+n.Obj().Name())
			return "null /* PORT: Go zero struct */"
		}
		if hx.Name == "OrderedMap" && n.TypeArgs().Len() == 2 {
			return "new " + u.T(t) + "(" + u.Zero(n.TypeArgs().At(1)) + ")"
		}
		return "new " + u.T(t) + "()"
	case *types.Array:
		return fmt.Sprintf("[for (_ in 0...%d) %s]", x.Len(), u.Zero(x.Elem()))
	}
	return "null"
}
