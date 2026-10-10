package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/printer.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.checker)
class SemicolonRemoverWriter implements EmitTextWriter {
	var hasPendingSemicolon:Bool = false;
	var inner:EmitTextWriter = null;

	public function new() {}

	function commitSemicolon():Void {
		if (this.hasPendingSemicolon) {
			this.inner.WriteTrailingSemicolon(";");
			this.hasPendingSemicolon = false;
		}
	}

	public function Clear():Void {
		this.inner.Clear();
	}

	public function DecreaseIndent():Void {
		this.commitSemicolon();
		this.inner.DecreaseIndent();
	}

	public function GetColumn():UTF16Offset {
		return this.inner.GetColumn();
	}

	public function GetIndent():Int {
		return this.inner.GetIndent();
	}

	public function GetLine():Int {
		return this.inner.GetLine();
	}

	public function GetTextPos():Int {
		return this.inner.GetTextPos();
	}

	public function HasTrailingComment():Bool {
		return this.inner.HasTrailingComment();
	}

	public function HasTrailingWhitespace():Bool {
		return this.inner.HasTrailingWhitespace();
	}

	public function IncreaseIndent():Void {
		this.commitSemicolon();
		this.inner.IncreaseIndent();
	}

	public function IsAtStartOfLine():Bool {
		return this.inner.IsAtStartOfLine();
	}

	public function RawWrite(s1:std.String):Void {
		this.commitSemicolon();
		this.inner.RawWrite(s1);
	}

	public function String():std.String {
		this.commitSemicolon();
		return this.inner.String();
	}

	public function Write(s1:std.String):Void {
		this.commitSemicolon();
		this.inner.Write(s1);
	}

	public function WriteComment(text:std.String):Void {
		this.commitSemicolon();
		this.inner.WriteComment(text);
	}

	public function WriteKeyword(text:std.String):Void {
		this.commitSemicolon();
		this.inner.WriteKeyword(text);
	}

	public function WriteLine():Void {
		this.commitSemicolon();
		this.inner.WriteLine();
	}

	public function WriteLineForce(force:Bool):Void {
		this.commitSemicolon();
		this.inner.WriteLineForce(force);
	}

	public function WriteLiteral(s1:std.String):Void {
		this.commitSemicolon();
		this.inner.WriteLiteral(s1);
	}

	public function WriteOperator(text:std.String):Void {
		this.commitSemicolon();
		this.inner.WriteOperator(text);
	}

	public function WriteParameter(text:std.String):Void {
		this.commitSemicolon();
		this.inner.WriteParameter(text);
	}

	public function WriteProperty(text:std.String):Void {
		this.commitSemicolon();
		this.inner.WriteProperty(text);
	}

	public function WritePunctuation(text:std.String):Void {
		this.commitSemicolon();
		this.inner.WritePunctuation(text);
	}

	public function WriteSpace(text:std.String):Void {
		this.commitSemicolon();
		this.inner.WriteSpace(text);
	}

	public function WriteStringLiteral(text:std.String):Void {
		this.commitSemicolon();
		this.inner.WriteStringLiteral(text);
	}

	public function WriteSymbol(text:std.String, symbol:Symbol):Void {
		this.commitSemicolon();
		this.inner.WriteSymbol(text, symbol);
	}

	public function WriteTrailingSemicolon(text:std.String):Void {
		this.hasPendingSemicolon = true;
	}
}

// Methods of printer.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class Printer_ {

	public static function TypeToString(c:Checker, t:Type):std.String {
		return c.typeToString(t, null);
	}

	static function typeToString(c:Checker, t:Type, enclosingDeclaration:Node):std.String {
		return c.typeToStringEx(t, enclosingDeclaration, TypeFormatFlagsAllowUniqueESSymbolType | TypeFormatFlagsUseAliasDefinedOutsideCurrentScope, null);
	}

	public static function TypeToStringEx(c:Checker, t:Type, enclosingDeclaration:Node, flags:TypeFormatFlags, vc:VerbosityContext):std.String {
		return c.typeToStringEx(t, enclosingDeclaration, flags, vc);
	}

	static function typeToStringEx(c:Checker, t:Type, enclosingDeclaration:Node, flags:TypeFormatFlags, vc:VerbosityContext):std.String {
		// Serialization of types can lead to (lazy) resolution of members, which can cause diagnostics that again require
		// serialization of types. This can potentially result in infinite recursion and stack overflows. To prevent that,
		// after a certain number of recursive invocations the function simply returns "?".
		if (c.serializationLevel >= Checker.maxSerializationLevel) {
			return "?";
		}
		var newLine = "";
		if (flags & TypeFormatFlagsMultilineObjectLiterals != 0) {
			newLine = "\n";
		}
		final writer = Printer.NewTextWriter(newLine, 0);
		final noTruncation = ((vc == null || vc.MaxTruncationLength == 0) && c.compilerOptions.NoErrorTruncation == TSTrue)
			|| (flags & TypeFormatFlagsNoTruncation != 0);
		var combinedFlags = Checker.toNodeBuilderFlags(flags) | FlagsIgnoreErrors;
		if (noTruncation) {
			combinedFlags = combinedFlags | FlagsNoTruncation;
		}
		final nb = c.getNodeBuilder();
		final nodeBuilder = nb.a;
		final release = nb.b;
		final oldVerbosity = nodeBuilder.verbosity;
		nodeBuilder.verbosity = vc;
		// PORT: defer (restore verbosity, release) — Go runs them on return and on panic.
		final r = try {
			c.serializationLevel++;
			final typeNode = nodeBuilder.TypeToTypeNode(t, enclosingDeclaration, combinedFlags, InternalFlagsNone, null);
			c.serializationLevel--;
			if (typeNode == null) {
				throw "should always get typenode";
			}
			// The unresolved type gets a synthesized comment on `any` to hint to users that it's not a plain `any`.
			// Otherwise, we always strip comments out.
			var p:Printer = null;
			if (t == c.unresolvedType) {
				p = Checker.createPrinterWithDefaults(nodeBuilder.EmitContext());
			} else {
				p = Checker.createPrinterWithRemoveComments(nodeBuilder.EmitContext());
			}
			var sourceFile:SourceFile = null;
			if (enclosingDeclaration != null) {
				sourceFile = Ast.GetSourceFileOfNode(enclosingDeclaration);
			}
			p.Write(typeNode, sourceFile, writer, null);
			final result = writer.String();

			var maxLength = Checker.defaultMaximumTruncationLength * 2;
			if (vc != null && vc.MaxTruncationLength > 0) {
				maxLength = vc.MaxTruncationLength * 10; // hard cutoff matching Strada's absoluteMaximumLength
			}
			if (noTruncation) {
				maxLength = Checker.noTruncationMaximumTruncationLength * 2;
			}
			// PORT: byte — Go len()/slicing count UTF-8 bytes; measured and cut in UTF-8 bytes here too. A cut inside
			// a multi-byte character (invalid UTF-8 in Go) keeps only the complete characters before it.
			if (maxLength > 0 && result != "" && go.Utf8.ByteLen(result) >= maxLength) {
				if (vc != null) {
					vc.Truncated = true;
				}
				final limit = maxLength - "...".length;
				var bytes = 0;
				var i = 0;
				while (i < result.length) {
					final r = go.Utf16.CodePointAt(result, i);
					final n = r < 0x80 ? 1 : (r < 0x800 ? 2 : (r < 0x10000 ? 3 : 4));
					if (bytes + n > limit) {
						break;
					}
					bytes += n;
					i += go.Utf16.RuneLen(r);
				}
				result.substring(0, i) + "...";
			} else {
				result;
			}
		} catch (e:Dynamic) {
			nodeBuilder.verbosity = oldVerbosity;
			release();
			throw e;
		}
		nodeBuilder.verbosity = oldVerbosity;
		release();
		return r;
	}

	public static function SymbolToString(c:Checker, s:Symbol):std.String {
		return c.symbolToString(s);
	}

	static function symbolToString(c:Checker, symbol:Symbol):std.String {
		return c.symbolToStringEx(symbol, null, SymbolFlagsAll, SymbolFormatFlagsAllowAnyNodeKind);
	}

	public static function SymbolToStringEx(c:Checker, symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags, flags:SymbolFormatFlags):std.String {
		return c.symbolToStringEx(symbol, enclosingDeclaration, meaning, flags);
	}

	static function symbolToStringEx(c:Checker, symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags, flags:SymbolFormatFlags):std.String {
		final wp = Printer.GetSingleLineStringWriter();
		final writer = wp.a;
		final putWriter = wp.b;

		var nodeFlags = FlagsIgnoreErrors;
		var internalNodeFlags = InternalFlagsNone;
		if (flags & SymbolFormatFlagsUseOnlyExternalAliasing != 0) {
			nodeFlags |= FlagsUseOnlyExternalAliasing;
		}
		if (flags & SymbolFormatFlagsWriteTypeParametersOrArguments != 0) {
			nodeFlags |= FlagsWriteTypeParametersInQualifiedName;
		}
		if (flags & SymbolFormatFlagsUseAliasDefinedOutsideCurrentScope != 0) {
			nodeFlags |= FlagsUseAliasDefinedOutsideCurrentScope;
		}
		if (flags & SymbolFormatFlagsDoNotIncludeSymbolChain != 0) {
			internalNodeFlags |= InternalFlagsDoNotIncludeSymbolChain;
		}
		if (flags & SymbolFormatFlagsWriteComputedProps != 0) {
			internalNodeFlags |= InternalFlagsWriteComputedProps;
		}

		final nb = c.getNodeBuilder();
		final nodeBuilder = nb.a;
		final release = nb.b;
		// PORT: defer putWriter()/release() — run on return and on panic.
		final r = try {
			var sourceFile:SourceFile = null;
			if (enclosingDeclaration != null) {
				sourceFile = Ast.GetSourceFileOfNode(enclosingDeclaration);
			}
			var printer_:Printer = null;
			// add neverAsciiEscape for GH#39027
			if (enclosingDeclaration != null && enclosingDeclaration.Kind == KindSourceFile) {
				printer_ = Checker.createPrinterWithRemoveCommentsNeverAsciiEscape(nodeBuilder.EmitContext());
			} else {
				printer_ = Checker.createPrinterWithRemoveComments(nodeBuilder.EmitContext());
			}

			var builder:(symbol:Symbol, meaning:SymbolFlags, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags,
				tracker:SymbolTracker) -> Node = null;
			if (flags & SymbolFormatFlagsAllowAnyNodeKind != 0) {
				builder = nodeBuilder.SymbolToNode;
			} else {
				builder = nodeBuilder.SymbolToEntityName;
			}
			final entity = builder(symbol, meaning, enclosingDeclaration, nodeFlags, internalNodeFlags, null); // TODO: GH#18217
			printer_.Write(entity /*sourceFile*/, sourceFile, Checker.getTrailingSemicolonDeferringWriter(writer), null); // TODO: GH#18217
			writer.String();
		} catch (e:Dynamic) {
			release();
			putWriter();
			throw e;
		}
		release();
		putWriter();
		return r;
	}

	static function signatureToString(c:Checker, signature:Signature):std.String {
		return c.signatureToStringEx(signature, null, TypeFormatFlagsNone, null);
	}

	public static function SignatureToStringEx(c:Checker, signature:Signature, enclosingDeclaration:Node, flags:TypeFormatFlags, vc:VerbosityContext):std.String {
		return c.signatureToStringEx(signature, enclosingDeclaration, flags, vc);
	}

	static function signatureToStringEx(c:Checker, signature:Signature, enclosingDeclaration:Node, flags:TypeFormatFlags, vc:VerbosityContext):std.String {
		final isConstructor = signature.flags & SignatureFlagsConstruct != 0 && flags & TypeFormatFlagsWriteCallStyleSignature == 0;
		var sigOutput:Kind = KindUnknown;
		if (flags & TypeFormatFlagsWriteArrowStyleSignature != 0) {
			if (isConstructor) {
				sigOutput = KindConstructorType;
			} else {
				sigOutput = KindFunctionType;
			}
		} else {
			if (isConstructor) {
				sigOutput = KindConstructSignature;
			} else {
				sigOutput = KindCallSignature;
			}
		}

		final nb = c.getNodeBuilder();
		final nodeBuilder = nb.a;
		final release = nb.b;
		final oldVerbosity = nodeBuilder.verbosity;
		nodeBuilder.verbosity = vc;
		// PORT: defer (restore verbosity, release, putWriter) — run on return and on panic.
		var putWriter:() -> Void = null;
		final r = try {
			final combinedFlags = Checker.toNodeBuilderFlags(flags) | FlagsIgnoreErrors | FlagsWriteTypeParametersInQualifiedName;
			final sig = nodeBuilder.SignatureToSignatureDeclaration(signature, sigOutput, enclosingDeclaration, combinedFlags, InternalFlagsNone, null);
			final p = Checker.createPrinterWithRemoveCommentsOmitTrailingSemicolonNeverAsciiEscape(nodeBuilder.EmitContext());
			var sourceFile:SourceFile = null;
			if (enclosingDeclaration != null) {
				sourceFile = Ast.GetSourceFileOfNode(enclosingDeclaration);
			}
			if (flags & TypeFormatFlagsMultilineObjectLiterals != 0) {
				final writer = Printer.NewTextWriter("\n", 0);
				p.Write(sig, sourceFile, Checker.getTrailingSemicolonDeferringWriter(writer), null);
				writer.String();
			} else {
				final wp = Printer.GetSingleLineStringWriter();
				final writer = wp.a;
				putWriter = wp.b;
				p.Write(sig, sourceFile, Checker.getTrailingSemicolonDeferringWriter(writer), null);
				writer.String();
			}
		} catch (e:Dynamic) {
			if (putWriter != null) {
				putWriter();
			}
			nodeBuilder.verbosity = oldVerbosity;
			release();
			throw e;
		}
		if (putWriter != null) {
			putWriter();
		}
		nodeBuilder.verbosity = oldVerbosity;
		release();
		return r;
	}

	static function typePredicateToString(c:Checker, typePredicate:TypePredicate):std.String {
		return c.typePredicateToStringEx(typePredicate, null, TypeFormatFlagsUseAliasDefinedOutsideCurrentScope);
	}

	static function typePredicateToStringEx(c:Checker, typePredicate:TypePredicate, enclosingDeclaration:Node, flags:TypeFormatFlags):std.String {
		final wp = Printer.GetSingleLineStringWriter();
		final writer = wp.a;
		final putWriter = wp.b;
		final nb = c.getNodeBuilder();
		final nodeBuilder = nb.a;
		final release = nb.b;
		// PORT: defer release()/putWriter() — run on return and on panic.
		final r = try {
			final combinedFlags = Checker.toNodeBuilderFlags(flags) | FlagsIgnoreErrors | FlagsWriteTypeParametersInQualifiedName;
			final predicate = nodeBuilder.TypePredicateToTypePredicateNode(typePredicate, enclosingDeclaration, combinedFlags, InternalFlagsNone,
				null); // TODO: GH#18217
			final printer_ = Checker.createPrinterWithRemoveComments(nodeBuilder.EmitContext());
			var sourceFile:SourceFile = null;
			if (enclosingDeclaration != null) {
				sourceFile = Ast.GetSourceFileOfNode(enclosingDeclaration);
			}
			printer_.Write(predicate /*sourceFile*/, sourceFile, writer, null);
			writer.String();
		} catch (e:Dynamic) {
			release();
			putWriter();
			throw e;
		}
		release();
		putWriter();
		return r;
	}

	static function valueToString(c:Checker, value:Any):std.String {
		return Checker.ValueToString(value);
	}

	static function formatUnionTypes(c:Checker, types:Array<Type>, expandingEnum:Bool):Array<Type> {
		var result:Array<Type> = null;
		var flags:TypeFlags = 0;
		var i = 0;
		while (i < Core.len(types)) {
			final t = types[i];
			flags |= t.flags;
			if (t.flags & TypeFlagsNullable == 0) {
				if (t.flags & TypeFlagsBooleanLiteral != 0 || (!expandingEnum && t.flags & TypeFlagsEnumLike != 0)) {
					var baseType:Type = null;
					if (t.flags & TypeFlagsBooleanLiteral != 0) {
						baseType = c.booleanType;
					} else {
						baseType = c.getBaseTypeOfEnumLikeType(t);
					}
					if (baseType.flags & TypeFlagsUnion != 0) {
						final count = Core.len(baseType.AsUnionType().types);
						if (i + count <= Core.len(types)
							&& c.getRegularTypeOfLiteralType(types[i + count - 1]) == c.getRegularTypeOfLiteralType(baseType.AsUnionType().types[count - 1])) {
							if (result == null) {
								result = [];
							}
							result.push(baseType);
							i += count - 1;
							i++;
							continue;
						}
					}
				}
				if (result == null) {
					result = [];
				}
				result.push(t);
			}
			i++;
		}
		if (flags & TypeFlagsNull != 0) {
			if (result == null) {
				result = [];
			}
			result.push(c.nullType);
		}
		if (flags & TypeFlagsUndefined != 0) {
			if (result == null) {
				result = [];
			}
			result.push(c.undefinedType);
		}
		return result;
	}

	public static function TypeToTypeNode(c:Checker, t:Type, enclosingDeclaration:Node, flags:Flags, idToSymbol:IdentityMap<IdentifierNode, Symbol>):TypeNode {
		final nodeBuilder = c.getNodeBuilderEx(idToSymbol);
		return nodeBuilder.TypeToTypeNode(t, enclosingDeclaration, flags, InternalFlagsNone, null);
	}

	public static function SignatureToSignatureDeclaration(c:Checker, signature:Signature, kind:Kind, enclosingDeclaration:Node, flags:Flags):Node {
		final nb = c.getNodeBuilder();
		final nodeBuilder = nb.a;
		final release = nb.b;
		// PORT: defer release() — run on return and on panic.
		final r = try nodeBuilder.SignatureToSignatureDeclaration(signature, kind, enclosingDeclaration, flags, InternalFlagsNone, null) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}

	// ExpandSymbolForHover produces declaration strings for a symbol with verbosity support for expandable hover.
	public static function ExpandSymbolForHover(c:Checker, symbol:Symbol, meaning:SymbolFlags, vc:VerbosityContext):std.String {
		final nb = c.getNodeBuilder();
		final nodeBuilder = nb.a;
		final release = nb.b;
		final oldVerbosity = nodeBuilder.verbosity;
		nodeBuilder.verbosity = vc;
		// PORT: defer (restore verbosity, release) — run on return and on panic.
		final r = try {
			final nodes = nodeBuilder.ExpandSymbolForHover(symbol, meaning);
			if (Core.len(nodes) == 0) {
				"";
			} else {
				final p = Checker.createPrinterWithRemoveComments(nodeBuilder.EmitContext());
				var sourceFile:SourceFile = null;
				if (symbol.ValueDeclaration != null) {
					sourceFile = Ast.GetSourceFileOfNode(symbol.ValueDeclaration);
				}
				final b = new StringBuf();
				for (i in 0...nodes.length) {
					final node = nodes[i];
					if (i > 0) {
						b.add("\n");
					}
					b.add(p.Emit(node, sourceFile));
				}
				b.toString();
			}
		} catch (e:Dynamic) {
			nodeBuilder.verbosity = oldVerbosity;
			release();
			throw e;
		}
		nodeBuilder.verbosity = oldVerbosity;
		release();
		return r;
	}

	// TypeParameterToStringEx renders a type parameter declaration (e.g. "T extends Foo") with optional verbosity support.
	public static function TypeParameterToStringEx(c:Checker, t:Type, enclosingDeclaration:Node, vc:VerbosityContext):std.String {
		final nb = c.getNodeBuilder();
		final nodeBuilder = nb.a;
		final release = nb.b;
		final oldVerbosity = nodeBuilder.verbosity;
		nodeBuilder.verbosity = vc;
		// PORT: defer (restore verbosity, release) — run on return and on panic.
		final r = try {
			final typeParamNode = nodeBuilder.TypeParameterToDeclaration(t, enclosingDeclaration, FlagsIgnoreErrors, InternalFlagsNone, null);
			if (typeParamNode == null) {
				c.TypeToString(t);
			} else {
				final p = Checker.createPrinterWithRemoveComments(nodeBuilder.EmitContext());
				var sourceFile:SourceFile = null;
				if (enclosingDeclaration != null) {
					sourceFile = Ast.GetSourceFileOfNode(enclosingDeclaration);
				}
				p.Emit(typeParamNode, sourceFile);
			}
		} catch (e:Dynamic) {
			nodeBuilder.verbosity = oldVerbosity;
			release();
			throw e;
		}
		nodeBuilder.verbosity = oldVerbosity;
		release();
		return r;
	}

	public static function TypeToTypeNodeEx(c:Checker, t:Type, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, idToSymbol:IdentityMap<IdentifierNode, Symbol>):TypeNode {
		final nodeBuilder = c.getNodeBuilderEx(idToSymbol);
		return nodeBuilder.TypeToTypeNode(t, enclosingDeclaration, flags, internalFlags, null);
	}

	public static function TypePredicateToTypePredicateNode(c:Checker, t:TypePredicate, enclosingDeclaration:Node, flags:Flags, idToSymbol:IdentityMap<IdentifierNode, Symbol>):TypePredicateNodeNode {
		final nodeBuilder = c.getNodeBuilderEx(idToSymbol);
		return nodeBuilder.TypePredicateToTypePredicateNode(t, enclosingDeclaration, flags, InternalFlagsNone, null);
	}
}
