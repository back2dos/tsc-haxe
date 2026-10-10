// astref: prints the behaviour of the upstream (Go) AST for every NodeFactory.New* method.
// Reference for test/ts/ast/AstTest.hx (golden file test/ts/ast/factory.golden.txt).
// Built against the pinned upstream with `go build -overlay` (see tools/gen/ast/goref.sh);
// upstream files are not changed.
//
// For every factory method (and every variant of its Kind / bool arguments) it builds the node
// with distinct child nodes, then prints: the ForEachChild order, the base data accessors,
// Name()/Modifiers(), the *Node accessors, SubtreeFacts, VisitEachChild (identity and changing
// visitor), Clone, DeepCloneNode, and the factory hook calls. Children are labelled by
// parameter: "p3" (node), "p3.1" (list element). Both sides build the arguments the same way.
package main

import (
	"fmt"
	"reflect"
	"sort"
	"strings"

	"github.com/microsoft/typescript-go/internal/ast"
	"github.com/microsoft/typescript-go/internal/core"
)

var kindChoices = map[string][]ast.Kind{
	"NewToken":                       {ast.KindAsyncKeyword, ast.KindQuestionDotToken, ast.KindThisKeyword, ast.KindUsingKeyword, ast.KindPublicKeyword, ast.KindAsteriskAsteriskToken, ast.KindCommaToken},
	"NewModifier":                    {ast.KindExportKeyword},
	"NewForInOrOfStatement":          {ast.KindForInStatement, ast.KindForOfStatement},
	"NewCaseOrDefaultClause":         {ast.KindCaseClause, ast.KindDefaultClause},
	"NewBindingPattern":              {ast.KindObjectBindingPattern, ast.KindArrayBindingPattern},
	"NewHeritageClause":              {ast.KindExtendsKeyword, ast.KindImplementsKeyword},
	"NewKeywordExpression":           {ast.KindThisKeyword, ast.KindSuperKeyword, ast.KindNullKeyword},
	"NewPrefixUnaryExpression":       {ast.KindPlusPlusToken, ast.KindExclamationToken},
	"NewPostfixUnaryExpression":      {ast.KindMinusMinusToken},
	"NewMetaProperty":                {ast.KindImportKeyword, ast.KindNewKeyword},
	"NewKeywordTypeNode":             {ast.KindAnyKeyword},
	"NewTypeOperatorNode":            {ast.KindKeyOfKeyword},
	"NewImportAttributes":            {ast.KindWithKeyword},
	"NewModuleDeclaration":           {ast.KindNamespaceKeyword},
	"NewImportClause":                {ast.KindTypeKeyword, ast.KindUnknown},
	"NewJSDocParameterOrPropertyTag": {ast.KindJSDocParameterTag, ast.KindJSDocPropertyTag},
}

// Node accessors of *Node compared on both sides (all children are non-nil identifiers).
var accessors = []string{
	"Expression", "Type", "Initializer", "Name", "TagName", "PropertyName", "PropertyNameOrName", "PostfixToken",
	"QuestionToken", "QuestionDotToken", "TypeExpression", "ClassName", "Label", "Attributes", "Children", "ModuleSpecifier",
	"ImportClause", "Statement", "Body", "ArgumentList", "TypeArgumentList", "TypeParameterList", "MemberList", "StatementList",
	"CommentList", "PropertyList", "ElementList", "IsTypeOnly", "CanHaveStatements", "ModifierFlags", "Text", "RawText",
	"Decorators", "ModifierNodes", "Symbol", "LocalSymbol", "Locals", "IsJSDoc",
}

const (
	nodeFlagsArg  = ast.NodeFlagsOptionalChain | ast.NodeFlagsLet
	tokenFlagsArg = ast.TokenFlagsUnterminated | ast.TokenFlagsScientific | ast.TokenFlagsContainsInvalidEscape | ast.TokenFlagsSingleQuote | ast.TokenFlagsHexSpecifier
)

type labels map[*ast.Node]string

func (l labels) of(n *ast.Node) string {
	if n == nil {
		return "nil"
	}
	if s, ok := l[n]; ok {
		return s
	}
	return "?" + n.Kind.String()
}

func main() {
	for k := -1; k <= int(ast.KindCount)+1; k++ {
		fmt.Printf("kind %d %s\n", k, ast.Kind(k).String())
	}

	ft := reflect.TypeOf(&ast.NodeFactory{})
	var names []string
	for i := range ft.NumMethod() {
		name := ft.Method(i).Name
		if strings.HasPrefix(name, "New") && name != "NewNodeList" && name != "NewModifierList" && name != "NewSourceFile" && name != "NewCommentRange" {
			names = append(names, name)
		}
	}
	sort.Strings(names)
	for _, name := range names {
		m, _ := ft.MethodByName(name)
		var types []string
		hasBool := false
		for i := 1; i < m.Type.NumIn(); i++ {
			t := m.Type.In(i).String()
			if t == "interface {}" {
				t = "any"
			}
			types = append(types, t)
			if t == "bool" {
				hasBool = true
			}
		}
		kinds := kindChoices[name]
		if len(kinds) == 0 {
			kinds = []ast.Kind{ast.KindUnknown}
		}
		bools := []bool{true}
		if hasBool {
			bools = []bool{true, false}
		}
		for _, kind := range kinds {
			for _, b := range bools {
				runCase(name, types, kind, b)
			}
		}
	}
}

func runCase(name string, types []string, kind ast.Kind, boolValue bool) {
	bi := 0
	if boolValue {
		bi = 1
	}
	fmt.Printf("case %s %s %d %d\n", name, strings.Join(types, ","), int(kind), bi)

	childFactory := ast.NewNodeFactory(ast.NodeFactoryHooks{})
	creates, updates, clones := 0, 0, 0
	f := ast.NewNodeFactory(ast.NodeFactoryHooks{
		OnCreate: func(node *ast.Node) { creates++ },
		OnUpdate: func(node *ast.Node, original *ast.Node) { updates++ },
		OnClone:  func(node *ast.Node, original *ast.Node) { clones++ },
	})

	lb := labels{}
	counter := 0
	newChild := func(label string) *ast.Node {
		counter++
		c := childFactory.NewIdentifier(fmt.Sprintf("c%d", counter))
		lb[c] = label
		return c
	}
	var args []reflect.Value
	for i, t := range types {
		p := fmt.Sprintf("p%d", i)
		switch t {
		case "*ast.Node":
			args = append(args, reflect.ValueOf(newChild(p)))
		case "*ast.NodeList":
			args = append(args, reflect.ValueOf(childFactory.NewNodeList([]*ast.Node{newChild(p + ".0"), newChild(p + ".1")})))
		case "*ast.ModifierList":
			m0 := childFactory.NewToken(ast.KindExportKeyword)
			m1 := childFactory.NewToken(ast.KindAsyncKeyword)
			lb[m0] = p + ".0"
			lb[m1] = p + ".1"
			args = append(args, reflect.ValueOf(childFactory.NewModifierList([]*ast.Node{m0, m1})))
		case "[]*ast.Node":
			args = append(args, reflect.ValueOf([]*ast.Node{newChild(p + ".0"), newChild(p + ".1")}))
		case "[]string":
			args = append(args, reflect.ValueOf([]string{p + "a", p + "b"}))
		case "string":
			args = append(args, reflect.ValueOf("s"+p))
		case "bool":
			args = append(args, reflect.ValueOf(boolValue))
		case "int":
			args = append(args, reflect.ValueOf(7))
		case "ast.Kind":
			args = append(args, reflect.ValueOf(kind))
		case "ast.NodeFlags":
			args = append(args, reflect.ValueOf(nodeFlagsArg))
		case "ast.TokenFlags":
			args = append(args, reflect.ValueOf(tokenFlagsArg))
		case "any":
			args = append(args, reflect.Zero(reflect.TypeOf((*any)(nil)).Elem()))
		default:
			panic("unhandled param type " + t)
		}
	}
	node := reflect.ValueOf(f).MethodByName(name).Call(args)[0].Interface().(*ast.Node)
	listLabel := func(l *ast.NodeList) string {
		if l == nil {
			return "nil"
		}
		for i, a := range args {
			if nl, ok := a.Interface().(*ast.NodeList); ok && nl == l {
				return fmt.Sprintf("p%d", i)
			}
			if ml, ok := a.Interface().(*ast.ModifierList); ok && &ml.NodeList == l {
				return fmt.Sprintf("p%d", i)
			}
		}
		return "?list"
	}

	fmt.Printf("kind %s flags %d\n", node.Kind.String(), int(node.Flags))
	fmt.Printf("fec %s\n", forEachChild(node, lb))
	fmt.Printf("data %s\n", dataAccessors(node))
	mods := "nil"
	if node.Modifiers() != nil {
		mods = listLabel(&node.Modifiers().NodeList)
	}
	fmt.Printf("modifiers %s\n", mods)

	for _, acc := range accessors {
		fmt.Printf("acc %s %s\n", acc, callAccessor(node, acc, lb, listLabel))
	}
	if node.FunctionLikeData() != nil {
		fmt.Printf("params %s\n", listLabel(node.ParameterList()))
	}

	fmt.Printf("facts %d\n", int(node.SubtreeFacts()))
	wrapper := childFactory.NewExpressionStatement(node)
	fmt.Printf("pfacts %d\n", int(wrapper.SubtreeFacts()))

	// VisitEachChild with the identity visitor: no update.
	same := ast.NewNodeVisitor(func(n *ast.Node) *ast.Node { return n }, f, ast.NodeVisitorHooks{}).VisitEachChild(node)
	fmt.Printf("vec-same %t\n", same == node)

	// VisitEachChild with a changing visitor: every child is replaced by a new identifier.
	rl := labels{}
	for n, l := range lb {
		rl[n] = l
	}
	changed := ast.NewNodeVisitor(func(n *ast.Node) *ast.Node {
		r := childFactory.NewIdentifier("r")
		rl[r] = "r" + lb.of(n)
		return r
	}, f, ast.NodeVisitorHooks{}).VisitEachChild(node)
	fmt.Printf("vec-changed %t %s fec %s\n", changed == node, changed.Kind.String(), forEachChild(changed, rl))

	// Clone
	node.Loc = core.NewTextRange(3, 9)
	node.Flags |= ast.NodeFlagsAmbient
	clone := node.Clone(f)
	if clone == nil {
		fmt.Printf("clone nil\n")
	} else {
		fmt.Printf("clone %t %s %d %d %d fec %s\n", clone == node, clone.Kind.String(), clone.Pos(), clone.End(), int(clone.Flags), forEachChild(clone, lb))
	}

	// DeepCloneNode: preorder kinds and locations of the copy.
	fmt.Printf("deep%s\n", deepClone(f, node, lb))

	fmt.Printf("hooks %d %d %d\n", creates, updates, clones)
}

func deepClone(f *ast.NodeFactory, node *ast.Node, lb labels) (result string) {
	defer func() {
		if r := recover(); r != nil {
			result = " panic"
		}
	}()
	deep := f.DeepCloneNode(node)
	var b strings.Builder
	var walk func(n *ast.Node) bool
	walk = func(n *ast.Node) bool {
		fmt.Fprintf(&b, " %s@%d,%d", n.Kind.String(), n.Pos(), n.End())
		if lb[n] != "" {
			b.WriteString("!shared")
		}
		n.ForEachChild(walk)
		return false
	}
	walk(deep)
	return b.String()
}

func forEachChild(n *ast.Node, lb labels) string {
	var parts []string
	n.ForEachChild(func(c *ast.Node) bool {
		parts = append(parts, lb.of(c))
		return false
	})
	if len(parts) == 0 {
		return "-"
	}
	return strings.Join(parts, " ")
}

func b2s(b bool) string {
	if b {
		return "1"
	}
	return "0"
}

func dataAccessors(n *ast.Node) string {
	return b2s(n.FlowNodeData() != nil) + b2s(n.DeclarationData() != nil) + b2s(n.ExportableData() != nil) +
		b2s(n.LocalsContainerData() != nil) + b2s(n.FunctionLikeData() != nil) + b2s(n.ClassLikeData() != nil) +
		b2s(n.BodyData() != nil) + b2s(n.LiteralLikeData() != nil) + b2s(n.TemplateLiteralLikeData() != nil)
}

func callAccessor(n *ast.Node, name string, lb labels, listLabel func(*ast.NodeList) string) (result string) {
	defer func() {
		if r := recover(); r != nil {
			result = "panic"
		}
	}()
	switch name {
	case "Expression":
		return lb.of(n.Expression())
	case "Type":
		return lb.of(n.Type())
	case "Initializer":
		return lb.of(n.Initializer())
	case "Name":
		return lb.of(n.Name())
	case "TagName":
		return lb.of(n.TagName())
	case "PropertyName":
		return lb.of(n.PropertyName())
	case "PropertyNameOrName":
		return lb.of(n.PropertyNameOrName())
	case "PostfixToken":
		return lb.of(n.PostfixToken())
	case "QuestionToken":
		return lb.of(n.QuestionToken())
	case "QuestionDotToken":
		return lb.of(n.QuestionDotToken())
	case "TypeExpression":
		return lb.of(n.TypeExpression())
	case "ClassName":
		return lb.of(n.ClassName())
	case "Label":
		return lb.of(n.Label())
	case "Attributes":
		return lb.of(n.Attributes())
	case "Children":
		return listLabel(n.Children())
	case "ModuleSpecifier":
		return lb.of(n.ModuleSpecifier())
	case "ImportClause":
		return lb.of(n.ImportClause())
	case "Statement":
		return lb.of(n.Statement())
	case "Body":
		return lb.of(n.Body())
	case "ArgumentList":
		return listLabel(n.ArgumentList())
	case "TypeArgumentList":
		return listLabel(n.TypeArgumentList())
	case "TypeParameterList":
		return listLabel(n.TypeParameterList())
	case "MemberList":
		return listLabel(n.MemberList())
	case "StatementList":
		return listLabel(n.StatementList())
	case "CommentList":
		return listLabel(n.CommentList())
	case "PropertyList":
		return listLabel(n.PropertyList())
	case "ElementList":
		return listLabel(n.ElementList())
	case "IsTypeOnly":
		return fmt.Sprint(n.IsTypeOnly())
	case "CanHaveStatements":
		return fmt.Sprint(n.CanHaveStatements())
	case "ModifierFlags":
		return fmt.Sprint(int(n.ModifierFlags()))
	case "Text":
		return "\"" + n.Text() + "\""
	case "RawText":
		return "\"" + n.RawText() + "\""
	case "Decorators":
		d := n.Decorators()
		if d == nil {
			return "nil"
		}
		return fmt.Sprint(len(d))
	case "ModifierNodes":
		m := n.ModifierNodes()
		if m == nil {
			return "nil"
		}
		var parts []string
		for _, x := range m {
			parts = append(parts, lb.of(x))
		}
		return strings.Join(parts, ",")
	case "Symbol":
		return fmt.Sprint(n.Symbol() == nil)
	case "LocalSymbol":
		return fmt.Sprint(n.LocalSymbol() == nil)
	case "Locals":
		return fmt.Sprint(n.Locals() == nil)
	case "IsJSDoc":
		return fmt.Sprint(n.IsJSDoc())
	}
	panic("unknown accessor " + name)
}
