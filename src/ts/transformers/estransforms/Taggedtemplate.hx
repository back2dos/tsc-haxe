package ts.transformers.estransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/estransforms/taggedtemplate.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers.estransforms)
class TaggedTemplateTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var currentSourceFile:SourceFile = null;
	var taggedTemplateStringDeclarations:Array<Node> = null;

	public function new() {}

	// PORT: promoted methods of the embedded transformers.Transformer.
	inline function Visitor():NodeVisitor return Transformer.Visitor();
	inline function Factory():ts.printer.Factory.NodeFactory return Transformer.Factory();
	inline function EmitContext():EmitContext return Transformer.EmitContext();

	function visit(node:Node):Node {
		if ((node.SubtreeFacts() & SubtreeContainsInvalidTemplateEscape) == 0) {
			return node;
		}
		switch (node.Kind) {
			case KindSourceFile:
				return visitSourceFile(node.AsSourceFile());
			case KindTaggedTemplateExpression:
				return visitTaggedTemplateExpression(node.AsTaggedTemplateExpression());
			default:
				return Visitor().VisitEachChild(node);
		}
	}

	function visitSourceFile(node:SourceFile):Node {
		currentSourceFile = node;
		taggedTemplateStringDeclarations = null;
		var visited = Visitor().VisitEachChild(node.AsNode());

		if (taggedTemplateStringDeclarations != null && taggedTemplateStringDeclarations.length > 0) {
			final visitedSourceFile = visited.AsSourceFile();
			// PORT: Go `append(s[:len:len], x)` always copies.
			final statements = visitedSourceFile.Statements.Nodes.copy();
			statements.push(Factory().NewVariableStatement(null, /*modifiers*/
				Factory().NewVariableDeclarationList(Factory().NewNodeList(taggedTemplateStringDeclarations), NodeFlagsNone)));
			final stmtList = Factory().NewNodeList(statements);
			stmtList.Loc = node.Statements.Loc;
			visited = Factory().UpdateSourceFile(visitedSourceFile, stmtList, visitedSourceFile.EndOfFileToken);
		}

		// PORT: Go spreads a possibly-nil slice; a Haxe spread of null throws. With no helpers Go still calls
		// AddEmitHelper (which creates the emit node), so call it without arguments then.
		final helpers = EmitContext().ReadEmitHelpers();
		if (helpers != null) {
			EmitContext().AddEmitHelper(visited, ...helpers);
		} else {
			EmitContext().AddEmitHelper(visited);
		}
		return visited;
	}

	function visitTaggedTemplateExpression(node:TaggedTemplateExpression):Node {
		return processTaggedTemplateExpression(node);
	}

	function processTaggedTemplateExpression(node:TaggedTemplateExpression):Node {
		final tag = Visitor().VisitNode(node.Tag);
		final template = node.Template;

		if (!Estransforms.hasInvalidEscape(template)) {
			return Visitor().VisitEachChild(node.AsNode());
		}

		final f = Factory();

		// Build up the template arguments and the raw and cooked strings for the template.
		final templateArguments:Array<Node> = [null]; // placeholder for the template object
		final cookedStrings:Array<Node> = [];
		final rawStrings:Array<Node> = [];

		if (Ast.IsNoSubstitutionTemplateLiteral(template)) {
			cookedStrings.push(Estransforms.createTemplateCooked(f, template.TemplateLiteralLikeData()));
			rawStrings.push(Estransforms.getRawLiteral(f, template));
		} else {
			final te = template.AsTemplateExpression();
			cookedStrings.push(Estransforms.createTemplateCooked(f, te.Head.TemplateLiteralLikeData()));
			rawStrings.push(Estransforms.getRawLiteral(f, te.Head));
			for (span in te.TemplateSpans.Nodes) {
				final ts = span.AsTemplateSpan();
				cookedStrings.push(Estransforms.createTemplateCooked(f, ts.Literal.TemplateLiteralLikeData()));
				rawStrings.push(Estransforms.getRawLiteral(f, ts.Literal));
				templateArguments.push(Visitor().VisitNode(ts.Expression));
			}
		}

		final helperCall = f.NewTemplateObjectHelper(f.NewArrayLiteralExpression(f.NewNodeList(cookedStrings), false),
			f.NewArrayLiteralExpression(f.NewNodeList(rawStrings), false));

		// Create a variable to cache the template object if we're in a module.
		// Do not do this in the global scope, as any variable we currently generate could conflict with
		// variables from outside of the current compilation. In the future, we can revisit this behavior.
		if (Ast.IsExternalModule(currentSourceFile)) {
			final tempVar = f.NewUniqueName("templateObject");
			if (taggedTemplateStringDeclarations == null) {
				taggedTemplateStringDeclarations = [];
			}
			taggedTemplateStringDeclarations.push(f.NewVariableDeclaration(tempVar, null, null, null));
			templateArguments[0] = f.NewLogicalORExpression(tempVar, f.NewAssignmentExpression(tempVar, helperCall));
		} else {
			templateArguments[0] = helperCall;
		}

		final call = f.NewCallExpression(tag, null /*questionDotToken*/, null /*typeArguments*/, f.NewNodeList(templateArguments), NodeFlagsNone);
		call.Loc = node.Loc;
		return call;
	}
}

// PORT: Go `strings.Replacer` (generic algorithm: leftmost match, ties broken by argument order), used by
// `newlineNormalizer`. Kept here because the lane may not edit src/go; it belongs in go.Strings.
class Replacer {
	final oldnew:Array<std.String>;

	function new(oldnew:Array<std.String>) {
		this.oldnew = oldnew;
	}

	public static function NewReplacer(...oldnew:std.String):Replacer {
		if (oldnew.length % 2 == 1) {
			throw "strings.NewReplacer: odd argument count";
		}
		return new Replacer(oldnew.toArray());
	}

	public function Replace(s:std.String):std.String {
		var buf:StringBuf = null;
		var last = 0;
		var i = 0;
		while (i < s.length) {
			var matched = false;
			var k = 0;
			while (k < oldnew.length) {
				final o = oldnew[k];
				if (o.length > 0 && i + o.length <= s.length && s.substr(i, o.length) == o) {
					if (buf == null) {
						buf = new StringBuf();
					}
					buf.add(s.substring(last, i));
					buf.add(oldnew[k + 1]);
					i += o.length;
					last = i;
					matched = true;
					break;
				}
				k += 2;
			}
			if (!matched) {
				i++;
			}
		}
		if (buf == null) {
			return s;
		}
		buf.add(s.substring(last));
		return buf.toString();
	}
}
