// tsdump-tokens: prints the raw token stream of the upstream (Go) scanner.
// Reference for the Haxe scanner (Phase 2 gate). Built against the pinned upstream
// with `go build -overlay` (see tools/dump/build.sh); upstream files are not changed.
//
// Usage: tsdump-tokens [-trivia] FILE...
// Output per file: "## <file>", then one line per token:
//   <Kind> <pos> <end> <flags> <value>
// and one line per scanner error:
//   E <code> <pos> <len>
// Positions are UTF-16 code-unit offsets. <value> is escaped per UTF-16 code unit:
// \n \r \t \\ \" stay, any unit outside 0x20..0x7E is \uXXXX.
package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"strings"
	"unicode/utf16"

	"github.com/microsoft/typescript-go/internal/ast"
	"github.com/microsoft/typescript-go/internal/core"
	"github.com/microsoft/typescript-go/internal/diagnostics"
	"github.com/microsoft/typescript-go/internal/scanner"
	"github.com/microsoft/typescript-go/internal/stringutil"
)

func main() {
	trivia := flag.Bool("trivia", false, "do not skip trivia")
	flag.Parse()
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	for _, file := range flag.Args() {
		data, err := os.ReadFile(file)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		dump(out, file, string(data), *trivia)
	}
}

func dump(out *bufio.Writer, file string, text string, trivia bool) {
	pm := ast.ComputePositionMap(text)
	u := func(p int) int { return pm.UTF8ToUTF16(p) }
	fmt.Fprintf(out, "## %s\n", file)
	s := scanner.NewScanner()
	s.SetSkipTrivia(!trivia)
	if strings.HasSuffix(file, ".tsx") || strings.HasSuffix(file, ".jsx") {
		s.SetLanguageVariant(core.LanguageVariantJSX)
	}
	s.SetScriptTarget(core.ScriptTargetLatest)
	s.SetOnError(func(message *diagnostics.Message, start int, length int, args ...any) {
		fmt.Fprintf(out, "E %d %d %d\n", message.Code(), u(start), u(start+length)-u(start))
	})
	s.SetText(text)
	for {
		kind := s.Scan()
		fmt.Fprintf(out, "%s %d %d %d %s\n", kind.String(), u(s.TokenFullStart()), u(s.TokenEnd()), s.TokenFlags(), escape(s.TokenValue()))
		if kind == ast.KindEndOfFile {
			break
		}
	}
}

func escape(v string) string {
	var b strings.Builder
	// Decode as a JS string value: a lone surrogate is stored by the scanner as its
	// CESU-8 sentinel (stringutil.EncodeJSStringRune) and must print as that code unit,
	// not as three U+FFFD (which []rune(v) would give).
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
	return `"` + b.String() + `"`
}
