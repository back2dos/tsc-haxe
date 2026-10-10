package main

// Index of the Haxe types that already exist (src/ts/**, src/go/*), built by scanning the .hx
// files. Top-level declarations start at column 0 in this code base; members are indented by one
// tab. This is a line scanner, not a Haxe parser: good enough to map Go names to Haxe names.

import (
	"bufio"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

type HxType struct {
	Pkg      string // Haxe package, e.g. ts.ast
	Module   string // module (file) name, e.g. AstGenerated
	Name     string // type name
	Kind     string // class, interface, typedef, abstract, enum abstract, enum
	FromBase bool   // abstract with `from Int` / `from String`
	ZeroCtor bool   // class with `new()` callable without arguments
	Under    string // abstract: underlying type name; class: super class name
	Members  map[string]bool
	Stub     bool // generated stub (bin/skeleton/_ext)
	Build    bool // @:build macro: members unknown, assume present
}

// Path is the fully qualified Haxe type path.
func (t *HxType) Path() string {
	if t.Module == t.Name {
		return t.Pkg + "." + t.Name
	}
	return t.Pkg + "." + t.Module + "." + t.Name
}

func (t *HxType) ModulePath() string { return t.Pkg + "." + t.Module }

type HxIndex struct {
	ByPkg   map[string]map[string]*HxType   // pkg → name → type
	Modules map[string]map[string][]*HxType // pkg → module → types
	PkgDirs map[string]bool                 // Haxe packages that exist in src
	ExtFns  map[string]bool                 // "pkg|Recv|name": static function whose first parameter is Recv (static extension)
}

var (
	reDecl    = regexp.MustCompile(`^(?:@:[\w.]+(?:\([^)]*\))?\s+)*((?:private|final|extern)\s+)*(class|interface|typedef|enum abstract|abstract|enum)\s+(\w+)(.*)$`)
	reMember  = regexp.MustCompile(`^\t(?:@:[\w.]+(?:\([^)]*\))?\s+)*(?:(?:public|private|static|inline|override|final|dynamic|extern|overload|macro)\s+)*(?:function|var|final)\s+(\w+)`)
	reNew     = regexp.MustCompile(`^\t.*function new\s*\(\s*(\)|\?)`)
	reExtFn   = regexp.MustCompile(`^\t.*\bstatic\s+(?:inline\s+)?function\s+(\w+)\s*(?:<[^(]*>)?\(\s*\w+\s*:\s*(?:Null<)?(\w+)`)
	reEnumVal = regexp.MustCompile(`^\t(?:final|var)\s+(\w+)\s*=`)
)

func NewHxIndex() *HxIndex {
	return &HxIndex{ByPkg: map[string]map[string]*HxType{}, Modules: map[string]map[string][]*HxType{}, PkgDirs: map[string]bool{}, ExtFns: map[string]bool{}}
}

func (x *HxIndex) Add(t *HxType) {
	if x.ByPkg[t.Pkg] == nil {
		x.ByPkg[t.Pkg] = map[string]*HxType{}
		x.Modules[t.Pkg] = map[string][]*HxType{}
	}
	x.ByPkg[t.Pkg][t.Name] = t
	x.Modules[t.Pkg][t.Module] = append(x.Modules[t.Pkg][t.Module], t)
}

func (x *HxIndex) Lookup(pkg, name string) *HxType {
	if m := x.ByPkg[pkg]; m != nil {
		return m[name]
	}
	return nil
}

// HasMember looks for a member in a type, its super classes and (for abstracts) the underlying type.
func (x *HxIndex) HasMember(t *HxType, name string) bool {
	for i := 0; t != nil && i < 10; i++ {
		if t.Members[name] || t.Build || x.ExtFns[t.Pkg+"|"+t.Name+"|"+name] {
			return true
		}
		if t.Under == "" {
			return false
		}
		t = x.Lookup(t.Pkg, t.Under)
	}
	return false
}

func (x *HxIndex) ScanDir(root string) error {
	return filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() || !strings.HasSuffix(path, ".hx") || info.Name() == "import.hx" {
			return nil
		}
		return x.scanFile(path)
	})
}

func (x *HxIndex) scanFile(path string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	module := strings.TrimSuffix(filepath.Base(path), ".hx")
	pkg := ""
	var cur *HxType
	build := false
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 1<<20), 1<<24)
	for sc.Scan() {
		line := sc.Text()
		if strings.HasPrefix(line, "package ") {
			pkg = strings.TrimSuffix(strings.TrimSpace(strings.TrimPrefix(line, "package ")), ";")
			x.PkgDirs[pkg] = true
			continue
		}
		if strings.HasPrefix(line, "@:build") || strings.HasPrefix(line, "@:autoBuild") {
			build = true
		}
		if len(line) > 0 && line[0] != '\t' && line[0] != ' ' && line[0] != '/' && line[0] != '}' {
			if m := reDecl.FindStringSubmatch(line); m != nil {
				isBuild := build || strings.Contains(line, "@:build")
				build = false
				cur = nil
				if strings.Contains(m[1], "private") {
					continue
				}
				t := &HxType{Pkg: pkg, Module: module, Name: m[3], Kind: m[2], Members: map[string]bool{}, Build: isBuild}
				rest := m[4]
				if strings.Contains(rest, "from Int") || strings.Contains(rest, "from String") {
					t.FromBase = true
				}
				if t.Kind == "abstract" || t.Kind == "enum abstract" {
					if i := strings.Index(rest, "("); i >= 0 {
						if j := strings.Index(rest[i:], ")"); j > 0 {
							t.Under = strings.TrimSpace(rest[i+1 : i+j])
						}
					}
				}
				if i := strings.Index(rest, "extends "); i >= 0 && t.Kind == "class" {
					f := strings.Fields(rest[i+8:])
					if len(f) > 0 {
						t.Under = strings.TrimRight(strings.Split(f[0], "<")[0], "{")
					}
				}
				if t.Kind == "typedef" || t.Kind == "interface" {
					t.ZeroCtor = false
				}
				x.Add(t)
				cur = t
			}
			continue
		}
		if m := reExtFn.FindStringSubmatch(line); m != nil {
			x.ExtFns[pkg+"|"+m[2]+"|"+m[1]] = true
		}
		if cur == nil {
			continue
		}
		if m := reMember.FindStringSubmatch(line); m != nil {
			cur.Members[m[1]] = true
		} else if m := reEnumVal.FindStringSubmatch(line); m != nil {
			cur.Members[m[1]] = true
		}
		if reNew.MatchString(line) {
			cur.ZeroCtor = true
		}
	}
	return sc.Err()
}
