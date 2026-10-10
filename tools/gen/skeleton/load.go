package main

// Package loading without golang.org/x/tools (not in the module cache of upstream/tsc):
// `go list -deps -export -json` gives the dependency order, the file lists and the export data.
// typescript-go packages are type-checked from source (we need their syntax: doc comments, file
// of each declaration); everything else (std, third party) is imported from export data.

import (
	"bytes"
	"encoding/json"
	"fmt"
	"go/ast"
	"go/importer"
	"go/parser"
	"go/token"
	"go/types"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const modulePath = "github.com/microsoft/typescript-go/"

type listPkg struct {
	ImportPath string
	Dir        string
	Name       string
	GoFiles    []string
	Standard   bool
	Export     string
	Imports    []string
}

// Pkg is one type-checked typescript-go package.
type Pkg struct {
	Path      string // full import path
	Rel       string // path below the module, e.g. internal/checker
	Name      string
	Types     *types.Package
	Info      *types.Info
	Files     []*ast.File
	FileNames []string // base names, same order as Files
	Imports   []string
}

type Loader struct {
	Fset     *token.FileSet
	Upstream string
	Pkgs     map[string]*Pkg // by import path
	exports  map[string]string
	gc       types.Importer
}

func (l *Loader) Import(path string) (*types.Package, error) {
	if p, ok := l.Pkgs[path]; ok {
		return p.Types, nil
	}
	return l.gc.Import(path)
}

func goList(dir string, args ...string) ([]*listPkg, error) {
	cmd := exec.Command("go", append([]string{"list", "-deps", "-export", "-json"}, args...)...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GOTOOLCHAIN=go1.26.9", "GOFLAGS=-mod=mod")
	var out, errb bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &errb
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("go list: %v\n%s", err, errb.String())
	}
	var res []*listPkg
	dec := json.NewDecoder(&out)
	for {
		var p listPkg
		if err := dec.Decode(&p); err == io.EOF {
			break
		} else if err != nil {
			return nil, err
		}
		res = append(res, &p)
	}
	return res, nil
}

// Load type-checks the given packages (paths relative to the module, e.g. internal/checker) and
// all their typescript-go dependencies.
func Load(upstream string, rels ...string) (*Loader, error) {
	var args []string
	for _, r := range rels {
		args = append(args, "./"+r)
	}
	list, err := goList(upstream, args...)
	if err != nil {
		return nil, err
	}
	l := &Loader{Fset: token.NewFileSet(), Upstream: upstream, Pkgs: map[string]*Pkg{}, exports: map[string]string{}}
	for _, p := range list {
		if p.Export != "" {
			l.exports[p.ImportPath] = p.Export
		}
	}
	l.gc = importer.ForCompiler(l.Fset, "gc", func(path string) (io.ReadCloser, error) {
		f, ok := l.exports[path]
		if !ok {
			return nil, fmt.Errorf("no export data for %s", path)
		}
		return os.Open(f)
	})
	for _, p := range list { // -deps lists dependencies first
		if p.Standard || !strings.HasPrefix(p.ImportPath, modulePath) {
			continue
		}
		pkg := &Pkg{Path: p.ImportPath, Rel: strings.TrimPrefix(p.ImportPath, modulePath), Name: p.Name, Imports: p.Imports}
		for _, f := range p.GoFiles {
			af, err := parser.ParseFile(l.Fset, filepath.Join(p.Dir, f), nil, parser.ParseComments)
			if err != nil {
				return nil, err
			}
			pkg.Files = append(pkg.Files, af)
			pkg.FileNames = append(pkg.FileNames, f)
		}
		pkg.Info = &types.Info{
			Types:      map[ast.Expr]types.TypeAndValue{},
			Defs:       map[*ast.Ident]types.Object{},
			Uses:       map[*ast.Ident]types.Object{},
			Selections: map[*ast.SelectorExpr]*types.Selection{},
		}
		var firstErr error
		conf := types.Config{Importer: l, Error: func(err error) {
			if firstErr == nil {
				firstErr = err
			}
		}}
		tp, _ := conf.Check(p.ImportPath, l.Fset, pkg.Files, pkg.Info)
		if firstErr != nil {
			return nil, fmt.Errorf("type-check %s: %v", p.ImportPath, firstErr)
		}
		pkg.Types = tp
		l.Pkgs[p.ImportPath] = pkg
	}
	return l, nil
}
