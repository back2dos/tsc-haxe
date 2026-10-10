package main

// Finish: decide imports vs fully qualified names, write the modules and the package import.hx.

import (
	"fmt"
	"go/types"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

func (u *Unit) Finish(outRoot string) error {
	X := u.g.X
	modNames := func(pkg, mod string) []string {
		var r []string
		for _, t := range X.Modules[pkg][mod] {
			r = append(r, t.Name)
		}
		return r
	}
	// modules we would like to import: the modules of all referenced types, plus the package
	// classes of the imported packages (PORTING.md §1: `Ast.IsIdentifier(n)` style calls).
	want := map[string][2]string{} // module path → pkg, module
	for r := range u.refs {
		if r.Pkg != "" {
			want[r.ModulePath()] = [2]string{r.Pkg, r.Module}
		}
	}
	for _, imp := range u.p.Imports {
		elems := strings.Split(imp, "/")
		hp := hxPkgOf(imp)
		name := capFirst(elems[len(elems)-1])
		if t := X.Lookup(hp, name); t != nil && t.Module == name && (strings.HasPrefix(imp, modulePath) || hp == "go") {
			want[t.ModulePath()] = [2]string{t.Pkg, t.Module}
		}
	}
	safe := map[string]bool{}
	for mp, pm := range want {
		safe[mp] = !u.localNames[pm[1]]
		for _, n := range modNames(pm[0], pm[1]) {
			if u.localNames[n] {
				safe[mp] = false
			}
		}
	}
	short := map[*HxType]bool{}
	subImports := map[string]bool{}
	for r := range u.refs {
		switch {
		case r.Pkg == "":
			short[r] = true
		case u.localNames[r.Name]:
		case safe[r.ModulePath()]:
			short[r] = true
		case r.Name != r.Module:
			subImports[r.Path()] = true
			short[r] = true
		}
	}
	// ambiguity between imported modules
	visible := map[string]map[*HxType]bool{}
	addVis := func(t *HxType) {
		if visible[t.Name] == nil {
			visible[t.Name] = map[*HxType]bool{}
		}
		visible[t.Name][t] = true
	}
	for mp, pm := range want {
		if safe[mp] {
			for _, t := range X.Modules[pm[0]][pm[1]] {
				addVis(t)
			}
		}
	}
	for r := range u.refs {
		if subImports[r.Path()] {
			addVis(r)
		}
	}
	for r := range short {
		if r.Pkg != "" && len(visible[r.Name]) > 1 {
			delete(short, r)
			u.g.notes["type written fully qualified (ambiguous import): "+r.Path()]++
		}
	}
	for r := range u.refs {
		if !short[r] && r.Pkg != "" && u.localNames[r.Name] {
			u.g.notes["type written fully qualified (clashes with a local name): "+r.Path()]++
		}
	}
	repl := map[string]string{}
	for r := range u.refs {
		key := tokOpen + r.Pkg + "|" + r.Module + "|" + r.Name + tokClose
		if short[r] {
			repl[key] = r.Name
		} else {
			repl[key] = r.Path()
		}
	}
	var pairs []string
	for k, v := range repl {
		pairs = append(pairs, k, v)
	}
	rep := strings.NewReplacer(pairs...)
	dir := filepath.Join(outRoot, filepath.FromSlash(strings.ReplaceAll(u.hxPkg, ".", "/")))
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	for _, mod := range u.modules {
		text := rep.Replace(u.text[mod])
		if strings.Contains(text, tokOpen) {
			return fmt.Errorf("unreplaced token in %s", mod)
		}
		u.nLines += strings.Count(text, "\n")
		if err := os.WriteFile(filepath.Join(dir, mod+".hx"), []byte(text), 0o644); err != nil {
			return err
		}
	}
	// import.hx
	var lines []string
	var mods []string
	for mp := range want {
		if safe[mp] {
			mods = append(mods, mp)
		}
	}
	sortImports(mods)
	for _, m := range mods {
		lines = append(lines, "import "+m+";")
	}
	var subs []string
	for s := range subImports {
		subs = append(subs, s)
	}
	sortImports(subs)
	for _, s := range subs {
		lines = append(lines, "import "+s+";")
	}
	for _, mod := range u.modules {
		lines = append(lines, "import "+u.hxPkg+"."+mod+";")
	}
	// enum values: own enums, and external enums whose values the Go package uses
	for _, td := range u.tdecls {
		if td.kind == "enum" && contains(u.modules, u.modOf[td.file]) {
			lines = append(lines, "import "+u.hxPkg+"."+u.modOf[td.file]+"."+td.hx+".*;")
		}
	}
	extEnums := map[string]bool{}
	for _, obj := range u.p.Info.Uses {
		c, ok := obj.(*types.Const)
		if !ok || c.Pkg() == nil || c.Pkg() == u.p.Types {
			continue
		}
		n, ok := c.Type().(*types.Named)
		if !ok || n.Obj().Pkg() == nil {
			continue
		}
		if t := u.g.lookupExt(n.Obj()); t != nil && strings.Contains(t.Kind, "abstract") {
			extEnums["import "+t.Pkg+"."+t.Module+"."+t.Name+".*;"] = true
		}
	}
	var ee []string
	for k := range extEnums {
		ee = append(ee, k)
	}
	sort.Strings(ee)
	lines = append(lines, ee...)
	for _, mod := range u.modules {
		if u.extModule[mod] {
			lines = append(lines, "using "+u.hxPkg+"."+mod+";")
		}
	}
	hdr := "// GENERATED SKELETON by tools/gen/skeleton for " + u.p.Rel + ".\n"
	return os.WriteFile(filepath.Join(dir, "import.hx"), []byte(hdr+strings.Join(lines, "\n")+"\n"), 0o644)
}

func contains(l []string, s string) bool {
	for _, x := range l {
		if x == s {
			return true
		}
	}
	return false
}

func sortImports(l []string) {
	rank := func(s string) int {
		switch {
		case strings.HasPrefix(s, "haxe."):
			return 0
		case strings.HasPrefix(s, "go."):
			return 1
		}
		return 2
	}
	sort.Slice(l, func(i, j int) bool {
		if rank(l[i]) != rank(l[j]) {
			return rank(l[i]) < rank(l[j])
		}
		return l[i] < l[j]
	})
}
