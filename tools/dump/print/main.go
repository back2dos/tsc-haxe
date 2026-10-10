// tsdump-print: prints every file with the upstream (Go) printer. Reference for the Haxe printer
// (printer gate, tools/gate/printer.sh). Built by tools/dump/build.sh (go build -overlay);
// upstream files are not changed.
//
// Usage: tsdump-print FILE...   (an argument "@LIST" reads one path per line from LIST)
//
// Each file is parsed like tools/dump/ast (parser.ParseSourceFile, FileName and Path = the
// argument, script kind from the extension) and printed the way upstream
// testutil/emittestutil.CheckEmit creates a printer:
//
//	printer.NewPrinter(printer.PrinterOptions{NewLine: core.NewLineKindLF}, printer.PrintHandlers{}, printer.NewEmitContext())
//	text := p.EmitSourceFile(sf)
//
// One fresh EmitContext and Printer per file. No binder, no transforms, no checker.
//
// Output per file: "## <file>", then the printed text split on "\n" (a trailing newline yields
// a final empty piece); each piece is written as "| " + escape(piece). escape works per UTF-16
// code unit (as tools/dump/ast, without quotes and without escaping '"'): `\` -> `\\`, CR -> `\r`,
// TAB -> `\t`, other units < 0x20 or > 0x7E -> `\uXXXX` (upper-case hex), else the character.
// If EmitSourceFile panics, a "!panic" line replaces the text lines: for an explicit
// panic(value) "!panic " + escape(fmt.Sprint(value)); for a Go runtime error (e.g. a nil pointer
// dereference, whose message is a Go runtime artifact) just "!panic". The Haxe dumper writes
// "!panic " + message for a thrown String and "!panic" for any other exception (null access).
// At the pin, 3 corpus files panic with a nil dereference (mapped types without a type).
// At exit "print-ms <ms>" (time spent in EmitSourceFile only) is written to stderr.
package main

import (
	"bufio"
	"fmt"
	"os"
	"runtime"
	"strings"
	"time"
	"unicode/utf16"

	"github.com/microsoft/typescript-go/internal/ast"
	"github.com/microsoft/typescript-go/internal/core"
	"github.com/microsoft/typescript-go/internal/parser"
	"github.com/microsoft/typescript-go/internal/printer"
	"github.com/microsoft/typescript-go/internal/stringutil"
	"github.com/microsoft/typescript-go/internal/tspath"
)

var printTime time.Duration

func main() {
	out := bufio.NewWriter(os.Stdout)
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
	out.Flush()
	fmt.Fprintf(os.Stderr, "print-ms %d\n", printTime.Milliseconds())
}

func emit(sf *ast.SourceFile) (text string, panicked any) {
	defer func() {
		if r := recover(); r != nil {
			panicked = r
		}
	}()
	p := printer.NewPrinter(printer.PrinterOptions{NewLine: core.NewLineKindLF}, printer.PrintHandlers{}, printer.NewEmitContext())
	t0 := time.Now()
	defer func() { printTime += time.Since(t0) }()
	return p.EmitSourceFile(sf), nil
}

func dump(out *bufio.Writer, file string, text string) {
	fmt.Fprintf(out, "## %s\n", file)
	sf := parser.ParseSourceFile(ast.SourceFileParseOptions{FileName: file, Path: tspath.Path(file)}, text, core.GetScriptKindFromFileName(file))
	printed, r := emit(sf)
	if r != nil {
		if _, ok := r.(runtime.Error); ok {
			out.WriteString("!panic\n")
		} else {
			fmt.Fprintf(out, "!panic %s\n", escape(fmt.Sprint(r)))
		}
		return
	}
	for _, piece := range strings.Split(printed, "\n") {
		out.WriteString("| ")
		out.WriteString(escape(piece))
		out.WriteByte('\n')
	}
}

func escape(v string) string {
	var b strings.Builder
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
		case c == '\r':
			b.WriteString(`\r`)
		case c == '\t':
			b.WriteString(`\t`)
		case c == '\\':
			b.WriteString(`\\`)
		case c < 0x20 || c > 0x7E:
			fmt.Fprintf(&b, `\u%04X`, c)
		default:
			b.WriteByte(byte(c))
		}
	}
	return b.String()
}
