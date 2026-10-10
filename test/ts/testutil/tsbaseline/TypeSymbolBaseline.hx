package ts.testutil.tsbaseline;

// Port of type_symbol_baseline.go: types typeWriterWalker and typeWriterResult (the package-level
// funcs are in Tsbaseline.hx).

@:allow(ts.testutil.tsbaseline)
class TypeWriterWalker {
	var program:ProgramLike = null;
	var hadErrorBaseline:Bool = false;
	var currentSourceFile:SourceFile = null;
	var declarationTextCache:ObjectMap<Node, String> = null;

	public function new() {}

	// PORT: (*checker.Checker, func()) → Pair
	function getTypeCheckerForCurrentFile():Pair<Checker, () -> Void> {
		// If we don't use the right checker for the file, its contents won't be up to date
		// since the types/symbols baselines appear to depend on files having been checked.
		return this.program.Program().GetTypeCheckerForFile(Context.Background(), this.currentSourceFile);
	}

	function getTypes(filename:String):Array<TypeWriterResult> {
		final sourceFile = this.program.GetSourceFile(filename);
		this.currentSourceFile = sourceFile;
		return this.visitNode(sourceFile.AsNode(), false /*isSymbolWalk*/);
	}

	function getSymbols(filename:String):Array<TypeWriterResult> {
		final sourceFile = this.program.GetSourceFile(filename);
		this.currentSourceFile = sourceFile;
		return this.visitNode(sourceFile.AsNode(), true /*isSymbolWalk*/);
	}

	function visitNode(node:Node, isSymbolWalk:Bool):Array<TypeWriterResult> {
		final nodes = Tsbaseline.forEachASTNode(node);
		final results:Array<TypeWriterResult> = [];
		for (n in nodes) {
			if (Ast.IsExpressionNode(n) || n.Kind == KindIdentifier || Ast.IsDeclarationName(n)) {
				final result = this.writeTypeOrSymbol(n, isSymbolWalk);
				if (result != null) {
					results.push(result);
				}
			}
		}
		return results;
	}

	function writeTypeOrSymbol(node:Node, isSymbolWalk:Bool):TypeWriterResult {
		final actualPos = Scanner.SkipTrivia(this.currentSourceFile.Text(), node.Pos());
		final line = Scanner.GetECMALineOfPosition(this.currentSourceFile, actualPos);
		final sourceText = Scanner.GetSourceTextOfNodeFromSourceFile(this.currentSourceFile, node, false /*includeTrivia*/);
		final fc = this.getTypeCheckerForCurrentFile();
		final fileChecker = fc.a, done = fc.b;

		final ec = Printer.GetEmitContext();
		final ctx = ec.a, putCtx = ec.b;

		final r = try this.writeTypeOrSymbolWorker(node, isSymbolWalk, line, sourceText, fileChecker, ctx) catch (e:haxe.Exception) {
			putCtx();
			done();
			throw e;
		}
		putCtx();
		done();
		return r;
	}

	// PORT: body of writeTypeOrSymbol after its defers.
	function writeTypeOrSymbolWorker(node:Node, isSymbolWalk:Bool, line:Int, sourceText:String, fileChecker:Checker,
			ctx:ts.printer.Emitcontext.EmitContext):TypeWriterResult {
		if (!isSymbolWalk) {
			// Don't try to get the type of something that's already a type.
			// Exception for `T` in `type T = something` because that may evaluate to some interesting type.
			if (Ast.IsPartOfTypeNode(node)
				|| (node.Kind == KindAsExpression || node.Kind == KindSatisfiesExpression) && (node.Type().Flags & NodeFlagsReparsed) != 0
				|| Ast.IsIdentifier(node)
				&& (Ast.GetMeaningFromDeclaration(node.Parent) & SemanticMeaningValue) == 0
				&& !(Ast.IsTypeOrJSTypeAliasDeclaration(node.Parent) && node == node.Parent.Name())) {
				return null;
			}

			if (Ast.IsOmittedExpression(node)) {
				return null;
			}

			var t:Type = null;
			// Workaround to ensure we output 'C' instead of 'typeof C' for base class expressions
			if (Ast.IsExpressionWithTypeArgumentsInClassExtendsClause(node.Parent)) {
				t = fileChecker.GetTypeAtLocation(node.Parent);
			}
			if (t == null || Checker.IsTypeAny(t)) {
				t = fileChecker.GetTypeAtLocation(node);
			}
			var typeString:String;
			// var underline string
			if (!this.hadErrorBaseline
				&& Checker.IsTypeAny(t)
				&& !Ast.IsBindingElement(node.Parent)
				&& !Ast.IsPropertyAccessOrQualifiedName(node.Parent)
				&& !Ast.IsLabelName(node)
				&& !Ast.IsGlobalScopeAugmentation(node.Parent)
				&& !Ast.IsMetaProperty(node.Parent)
				&& !Tsbaseline.isImportStatementName(node)
				&& !Tsbaseline.isExportStatementName(node)
				&& !Tsbaseline.isIntrinsicJsxTag(node, this.currentSourceFile)) {
				typeString = t.AsIntrinsicType().IntrinsicName();
			} else {
				ctx.Reset();
				final builder = Checker.NewNodeBuilder(fileChecker, ctx);
				final typeFormatFlags:TypeFormatFlags = TypeFormatFlagsNoTruncation | TypeFormatFlagsAllowUniqueESSymbolType | TypeFormatFlagsGenerateNamesForShadowedTypeParams;
				var typeNode = builder.TypeToTypeNode(t, node.Parent, ((typeFormatFlags & TypeFormatFlagsNodeBuilderFlagsMask : Int) : Flags) | FlagsIgnoreErrors,
					InternalFlagsAllowUnresolvedNames, null);
				if (Ast.IsIdentifier(node) && Ast.IsTypeAliasDeclaration(node.Parent) && node.Parent.Name() == node && Ast.IsIdentifier(typeNode)
					&& typeNode.Text() == node.Text()) {
					// for a complex type alias `type T = ...`, showing "T : T" isn't very helpful for type tests. When the type produced is the same as
					// the name of the type alias, recreate the type string without reusing the alias name
					typeNode = builder.TypeToTypeNode(t, node.Parent,
						(((typeFormatFlags | TypeFormatFlagsInTypeAlias) & TypeFormatFlagsNodeBuilderFlagsMask : Int) : Flags) | FlagsIgnoreErrors,
						InternalFlagsAllowUnresolvedNames, null);
				}

				// !!! TODO: port underline printer, memoize
				final writer = Printer.NewTextWriter("", 0);
				final popts = new PrinterOptions();
				popts.RemoveComments = true;
				final printer = Printer.NewPrinter(popts, new PrintHandlers(), ctx);
				printer.Write(typeNode, this.currentSourceFile, writer, null);
				typeString = writer.String();
			}
			final r = new TypeWriterResult();
			r.line = line;
			r.sourceText = sourceText;
			r.typ = typeString;
			// underline: underline, // !!! TODO: underline
			return r;
		}

		final symbol = fileChecker.GetSymbolAtLocation(node);
		if (symbol == null) {
			return null;
		}

		final symbolString = new StringBuf();
		symbolString.add("Symbol(");
		symbolString.add(Ast.EscapeAllInternalSymbolNames(fileChecker.SymbolToStringEx(symbol, node.Parent, SymbolFlagsNone, SymbolFormatFlagsAllowAnyNodeKind)));
		var count = 0;
		if (symbol.Declarations != null) {
			for (declaration in symbol.Declarations) {
				if (count >= 5) {
					symbolString.add(Fmt.Sprintf(" ... and %d more", [symbol.Declarations.length - count]));
					break;
				}
				count++;
				symbolString.add(", ");
				if (this.declarationTextCache.exists(declaration)) {
					symbolString.add(this.declarationTextCache.get(declaration));
					continue;
				}

				final declSourceFile = Ast.GetSourceFileOfNode(declaration);
				final lc = Scanner.GetECMALineAndUTF16CharacterOfPosition(declSourceFile, declaration.Pos());
				final declLine = lc.a, declChar:Int = lc.b;
				final fileName = Tspath.GetBaseFileName(declSourceFile.FileName());
				symbolString.add("Decl(");
				symbolString.add(fileName);
				symbolString.add(", ");
				if (Tsbaseline.isDefaultLibraryFile(fileName)) {
					symbolString.add("--, --)");
				} else {
					symbolString.add(declLine + ", " + declChar + ")");
				}
			}
		}
		symbolString.add(")");
		final r = new TypeWriterResult();
		r.line = line;
		r.sourceText = sourceText;
		r.symbol = symbolString.toString();
		return r;
	}
}

@:allow(ts.testutil.tsbaseline)
class TypeWriterResult {
	var line:Int = 0;
	var sourceText:String = "";
	var symbol:String = "";
	var typ:String = "";
	var underline:String = ""; // !!!

	public function new() {}
}
