package main

// External symbols: what the target package uses from other typescript-go packages, and stub
// skeletons (into a separate directory) for the parts that have no Haxe port yet.

import (
	"fmt"
	"go/types"
	"sort"
	"strings"
)

type extNeeds struct {
	g          *Gen
	target     *Pkg
	byPkg      map[*types.Package]*Filter
	fieldOwner map[*types.Var]*types.TypeName
}

func (g *Gen) fieldOwners() map[*types.Var]*types.TypeName {
	m := map[*types.Var]*types.TypeName{}
	for _, p := range g.L.Pkgs {
		scope := p.Types.Scope()
		for _, name := range scope.Names() {
			tn, ok := scope.Lookup(name).(*types.TypeName)
			if !ok || tn.IsAlias() {
				continue
			}
			if st, ok := tn.Type().Underlying().(*types.Struct); ok {
				for i := 0; i < st.NumFields(); i++ {
					m[st.Field(i)] = tn
				}
			}
		}
	}
	return m
}

func (e *extNeeds) filter(p *types.Package) *Filter {
	f := e.byPkg[p]
	if f == nil {
		f = &Filter{Types: map[*types.TypeName]bool{}, Objs: map[types.Object]bool{}}
		e.byPkg[p] = f
	}
	return f
}

func (e *extNeeds) external(p *types.Package) bool {
	if p == nil || p == e.target.Types {
		return false
	}
	_, ok := e.g.L.Pkgs[p.Path()]
	return ok
}

func (e *extNeeds) need(obj types.Object) {
	if !e.external(obj.Pkg()) {
		return
	}
	f := e.filter(obj.Pkg())
	switch o := obj.(type) {
	case *types.TypeName:
		e.needType(o)
	case *types.Func:
		if f.Objs[o] {
			return
		}
		f.Objs[o] = true
		sig := o.Type().(*types.Signature)
		if sig.Recv() != nil {
			if tn := baseTypeName(sig.Recv().Type()); tn != nil {
				e.needType(tn)
			}
		}
		e.needT(sig)
	case *types.Var:
		if f.Objs[o] {
			return
		}
		f.Objs[o] = true
		if o.IsField() {
			if tn := e.fieldOwner[o.Origin()]; tn != nil {
				e.needType(tn)
			}
		}
		e.needT(o.Type())
	case *types.Const:
		if n, ok := o.Type().(*types.Named); ok && n.Obj().Pkg() == o.Pkg() {
			if _, ok := n.Underlying().(*types.Basic); ok {
				e.needType(n.Obj())
				return
			}
		}
		f.Objs[o] = true
		e.needT(o.Type())
	}
}

func (e *extNeeds) needType(tn *types.TypeName) {
	if !e.external(tn.Pkg()) {
		return
	}
	f := e.filter(tn.Pkg())
	if f.Types[tn] {
		return
	}
	f.Types[tn] = true
	if tn.IsAlias() {
		e.needT(tn.Type().(*types.Alias).Rhs())
		return
	}
	n, ok := tn.Type().(*types.Named)
	if !ok {
		return
	}
	switch u := n.Underlying().(type) {
	case *types.Interface:
		for i := 0; i < u.NumMethods(); i++ {
			e.needT(u.Method(i).Type())
		}
	case *types.Struct:
		// embedded base: followed only for stubbed types (see Externals)
	default:
		e.needT(u)
	}
}

func (e *extNeeds) needT(t types.Type) {
	switch t := t.(type) {
	case *types.Alias:
		e.needType(t.Obj())
		e.needT(types.Unalias(t))
	case *types.Named:
		e.needType(t.Origin().Obj())
		for i := 0; i < t.TypeArgs().Len(); i++ {
			e.needT(t.TypeArgs().At(i))
		}
	case *types.Pointer:
		e.needT(t.Elem())
	case *types.Slice:
		e.needT(t.Elem())
	case *types.Array:
		e.needT(t.Elem())
	case *types.Map:
		e.needT(t.Key())
		e.needT(t.Elem())
	case *types.Chan:
		e.needT(t.Elem())
	case *types.Signature:
		for i := 0; i < t.Params().Len(); i++ {
			e.needT(t.Params().At(i).Type())
		}
		for i := 0; i < t.Results().Len(); i++ {
			e.needT(t.Results().At(i).Type())
		}
	case *types.Struct:
		for i := 0; i < t.NumFields(); i++ {
			e.needT(t.Field(i).Type())
		}
	case *types.Tuple:
		for i := 0; i < t.Len(); i++ {
			e.needT(t.At(i).Type())
		}
	}
}

type extReport struct {
	stubPkgs    []string // packages stubbed completely (no Haxe port yet)
	partialPkgs []string
	stubbed     []string // symbols stubbed
	missing     []string // symbols used but missing in an existing Haxe package (not stubbed)
}

// Externals computes the external needs of target and creates the stub units.
func (g *Gen) Externals(target *Pkg) ([]*Unit, *extReport) {
	e := &extNeeds{g: g, target: target, byPkg: map[*types.Package]*Filter{}, fieldOwner: g.fieldOwners()}
	for _, obj := range target.Info.Uses {
		e.need(obj)
	}
	// a stubbed struct needs its embedded base (Haxe `extends` or composition field)
	for changed := true; changed; {
		changed = false
		for tp, f := range e.byPkg {
			full := !g.X.PkgDirs[hxPkgOf(tp.Path())]
			for tn := range f.Types {
				if !full && g.lookupExt(tn) != nil {
					continue
				}
				if st, ok := tn.Type().Underlying().(*types.Struct); ok && !tn.IsAlias() {
					for i := 0; i < st.NumFields(); i++ {
						if fld := st.Field(i); fld.Embedded() && !f.Objs[fld] {
							e.need(fld)
							changed = true
						}
					}
				}
			}
		}
	}
	rep := &extReport{}
	var pkgs []*types.Package
	for p := range e.byPkg {
		pkgs = append(pkgs, p)
	}
	sort.Slice(pkgs, func(i, j int) bool { return pkgs[i].Path() < pkgs[j].Path() })
	var units []*Unit
	for _, tp := range pkgs {
		f := e.byPkg[tp]
		p := g.L.Pkgs[tp.Path()]
		hp := hxPkgOf(tp.Path())
		rel := strings.TrimPrefix(tp.Path(), modulePath)
		if !g.X.PkgDirs[hp] {
			rep.stubPkgs = append(rep.stubPkgs, rel)
			for tn := range f.Types {
				rep.stubbed = append(rep.stubbed, rel+"."+tn.Name())
			}
			for o := range f.Objs {
				rep.stubbed = append(rep.stubbed, rel+"."+memberName(e, o))
			}
			units = append(units, NewUnit(g, p, f, false))
			continue
		}
		// package exists in src: stub only the missing types (module ExtStubs)
		pf := &Filter{Types: map[*types.TypeName]bool{}, Objs: map[types.Object]bool{}}
		pkgClass := g.X.Lookup(hp, capFirst(tp.Name()))
		for tn := range f.Types {
			if g.lookupExt(tn) == nil {
				pf.Types[tn] = true
				rep.stubbed = append(rep.stubbed, rel+"."+tn.Name())
			}
		}
		for o := range f.Objs {
			owner := ownerOf(e, o)
			switch {
			case owner == nil:
				if pkgClass == nil || !g.X.HasMember(pkgClass, o.Name()) {
					rep.missing = append(rep.missing, rel+"."+o.Name())
				}
			case pf.Types[owner]:
				pf.Objs[o] = true
				rep.stubbed = append(rep.stubbed, rel+"."+memberName(e, o))
			case isEmbedded(o):
			default:
				if hx := g.lookupExt(owner); hx != nil && !g.X.HasMember(hx, o.Name()) && !g.X.HasMember(hx, id(o.Name())) {
					rep.missing = append(rep.missing, rel+"."+memberName(e, o))
				}
			}
		}
		if len(pf.Types) > 0 {
			rep.partialPkgs = append(rep.partialPkgs, rel)
			units = append(units, NewUnit(g, p, pf, true))
		}
	}
	// register the stub types so that every unit resolves them
	for _, u := range units {
		for _, td := range u.tdecls {
			kind := td.kind
			switch kind {
			case "enum":
				kind = "enum abstract"
			case "typedef", "alias", "constraint":
				kind = "typedef"
			}
			mod := u.modOf[td.file]
			if td == u.mainStruct {
				mod = u.pkgClass
			}
			g.X.Add(&HxType{Pkg: u.hxPkg, Module: mod, Name: td.hx, Kind: kind, FromBase: true, ZeroCtor: kind == "class", Members: map[string]bool{}, Stub: true})
		}
		if !u.partial && g.X.Lookup(u.hxPkg, u.pkgClass) == nil {
			g.X.Add(&HxType{Pkg: u.hxPkg, Module: u.pkgClass, Name: u.pkgClass, Kind: "class", Members: map[string]bool{}, Stub: true})
		}
		g.X.PkgDirs[u.hxPkg] = true
	}
	sort.Strings(rep.stubbed)
	sort.Strings(rep.missing)
	return units, rep
}

func ownerOf(e *extNeeds, o types.Object) *types.TypeName {
	switch o := o.(type) {
	case *types.Func:
		if sig := o.Type().(*types.Signature); sig.Recv() != nil {
			return baseTypeName(sig.Recv().Type())
		}
	case *types.Var:
		if o.IsField() {
			return e.fieldOwner[o.Origin()]
		}
	}
	return nil
}

func memberName(e *extNeeds, o types.Object) string {
	if tn := ownerOf(e, o); tn != nil {
		k := "field"
		if _, ok := o.(*types.Func); ok {
			k = "method"
		}
		return fmt.Sprintf("%s.%s (%s)", tn.Name(), o.Name(), k)
	}
	switch o.(type) {
	case *types.Func:
		return o.Name() + " (func)"
	case *types.Var:
		return o.Name() + " (var)"
	case *types.Const:
		return o.Name() + " (const)"
	}
	return o.Name()
}

func isEmbedded(o types.Object) bool {
	v, ok := o.(*types.Var)
	return ok && v.Embedded()
}
