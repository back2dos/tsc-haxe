// Command skeleton writes Haxe skeleton modules (types, fields, signatures; bodies throw
// "unported") for one upstream Go package, following docs/PORTING.md.
//
//	tools/gen/skeleton/run.sh internal/checker            # → bin/skeleton/checker/ + bin/skeleton/_ext/
//	tools/gen/skeleton/run.sh internal/binder -ext=       # no external stubs
//
// Flags: -pkg, -out (default bin/skeleton/<pkg>), -ext (default bin/skeleton/_ext, "" = off),
// -inherit (embedded first-field struct → `extends`, default true), -root (project root).
package main

import (
	"flag"
	"fmt"
	"go/printer"
	"go/token"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

func printNode(w io.Writer, fset *token.FileSet, n any) error {
	return printer.Fprint(w, fset, n)
}

func findRoot() string {
	dir, _ := os.Getwd()
	for d := dir; d != "/"; d = filepath.Dir(d) {
		if _, err := os.Stat(filepath.Join(d, "UPSTREAM.md")); err == nil {
			return d
		}
	}
	return dir
}

func main() {
	root := flag.String("root", findRoot(), "project root")
	pkgRel := flag.String("pkg", "", "upstream package, e.g. internal/checker")
	out := flag.String("out", "", "output classpath root (default bin/skeleton/<pkg>)")
	ext := flag.String("ext", "bin/skeleton/_ext", "output classpath root for stubs of unported external symbols (empty: off)")
	var splits splitFlag
	flag.Var(&splits, "split", "<gofile>:<N>: main-struct methods of that file → N static-extension modules <Module>Part1..N (repeatable)")
	unported := flag.String("unported", "", "comma-separated packages to treat as not ported even if src/ts/<pkg> exists (e.g. a lane in progress): full stubs")
	inherit := flag.Bool("inherit", true, "struct whose first field embeds a local struct → Haxe `extends`")
	flag.Parse()
	if *pkgRel == "" && flag.NArg() > 0 {
		*pkgRel = flag.Arg(0)
	}
	if *pkgRel == "" {
		fmt.Fprintln(os.Stderr, "usage: skeleton -pkg internal/<pkg> [-out dir] [-ext dir]")
		os.Exit(2)
	}
	if !strings.HasPrefix(*pkgRel, "internal/") {
		*pkgRel = "internal/" + *pkgRel
	}
	if *out == "" {
		*out = filepath.Join("bin/skeleton", strings.TrimPrefix(*pkgRel, "internal/"))
	}
	abs := func(p string) string {
		if p == "" || filepath.IsAbs(p) {
			return p
		}
		return filepath.Join(*root, p)
	}
	*out, *ext = abs(*out), abs(*ext)
	if strings.HasPrefix(*out, filepath.Join(*root, "src")) || (*ext != "" && strings.HasPrefix(*ext, filepath.Join(*root, "src"))) {
		fmt.Fprintln(os.Stderr, "refusing to write into src/")
		os.Exit(2)
	}
	upstream := filepath.Join(*root, "upstream", "tsc")
	L, err := Load(upstream, *pkgRel)
	check(err)
	X := NewHxIndex()
	check(X.ScanDir(filepath.Join(*root, "src", "ts")))
	check(X.ScanDir(filepath.Join(*root, "src", "go")))
	for _, p := range strings.Split(*unported, ",") {
		if p = strings.TrimSpace(strings.TrimPrefix(p, "internal/")); p != "" {
			hp := "ts." + strings.ReplaceAll(p, "/", ".")
			delete(X.ByPkg, hp)
			delete(X.Modules, hp)
			delete(X.PkgDirs, hp)
		}
	}
	g := &Gen{L: L, X: X, inherit: *inherit, split: map[string]int(splits), unresolved: map[string]int{}, notes: map[string]int{}}
	target := L.Pkgs[modulePath+*pkgRel]
	if target == nil {
		check(fmt.Errorf("package %s not loaded", *pkgRel))
	}
	var stubs []*Unit
	var rep *extReport
	if *ext != "" {
		stubs, rep = g.Externals(target)
	}
	tu := NewUnit(g, target, nil, false)
	check(os.RemoveAll(*out))
	if *ext != "" {
		check(os.RemoveAll(*ext)) // the stub directory belongs to the last run
	}
	for _, s := range stubs {
		s.Generate()
	}
	tu.Generate()
	for _, s := range stubs {
		check(s.Finish(*ext))
	}
	check(tu.Finish(*out))

	var r strings.Builder
	fmt.Fprintf(&r, "skeleton %s → %s\n", *pkgRel, *out)
	fmt.Fprintf(&r, "  modules %d, lines %d, types %d, fields %d, enum values %d, funcs %d, methods %d\n",
		len(tu.modules), tu.nLines, tu.nTypes, tu.nFields, tu.nEnumVals, tu.nFuncs, tu.nMethods)
	if len(tu.SplitInfo) > 0 {
		fmt.Fprintf(&r, "split modules:\n")
		for _, s := range tu.SplitInfo {
			fmt.Fprintf(&r, "  %s\n", s)
		}
	}
	if rep != nil {
		fmt.Fprintf(&r, "external stubs → %s\n", *ext)
		fmt.Fprintf(&r, "  packages without Haxe port (stubbed): %s\n", strings.Join(rep.stubPkgs, ", "))
		fmt.Fprintf(&r, "  packages with missing types (ExtStubs.hx): %s\n", strings.Join(rep.partialPkgs, ", "))
		n := 0
		for _, s := range stubs {
			n += s.nLines
		}
		fmt.Fprintf(&r, "  stub lines %d, stubbed symbols %d\n", n, len(rep.stubbed))
		for _, s := range rep.stubbed {
			fmt.Fprintf(&r, "    stub %s\n", s)
		}
		fmt.Fprintf(&r, "  used but missing in an existing Haxe package (not stubbed): %d\n", len(rep.missing))
		for _, s := range rep.missing {
			fmt.Fprintf(&r, "    missing %s\n", s)
		}
	}
	fmt.Fprintf(&r, "unresolved Go types (mapped to Any): %d\n", len(g.unresolved))
	for _, k := range sortedKeys(g.unresolved) {
		fmt.Fprintf(&r, "  %s ×%d\n", k, g.unresolved[k])
	}
	fmt.Fprintf(&r, "renames (Haxe name clashes): %d\n", len(g.renames))
	for _, s := range g.renames {
		fmt.Fprintf(&r, "  %s\n", s)
	}
	fmt.Fprintf(&r, "notes:\n")
	for _, k := range sortedKeys(g.notes) {
		fmt.Fprintf(&r, "  %s ×%d\n", k, g.notes[k])
	}
	check(os.WriteFile(filepath.Join(*out, "REPORT.txt"), []byte(r.String()), 0o644))
	fmt.Print(r.String())
}

func sortedKeys(m map[string]int) []string {
	var k []string
	for s := range m {
		k = append(k, s)
	}
	sort.Strings(k)
	return k
}

func check(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, "skeleton:", err)
		os.Exit(1)
	}
}

type splitFlag map[string]int

func (s *splitFlag) String() string { return fmt.Sprint(map[string]int(*s)) }

func (s *splitFlag) Set(v string) error {
	i := strings.LastIndex(v, ":")
	if i < 0 {
		return fmt.Errorf("want <gofile>:<N>")
	}
	n, err := strconv.Atoi(v[i+1:])
	if err != nil || n < 1 {
		return fmt.Errorf("bad part count in %q", v)
	}
	if *s == nil {
		*s = splitFlag{}
	}
	(*s)[v[:i]] = n
	return nil
}
