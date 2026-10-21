package ts.parser;

// Port of jsdoc.go: the Parser methods of jsdoc.go as a static extension (PORTING.md §2), used
// via `using ts.parser.Jsdoc`. The package-level funcs of jsdoc.go are in class Parser.
enum abstract JsdocState(Int) from Int to Int {
	var jsdocStateBeginningOfLine = 0;
	var jsdocStateSawAsterisk = 1;
	var jsdocStateSavingComments = 2;
	var jsdocStateSavingBackticks = 3;
}

enum abstract PropertyLikeParse(Int) from Int to Int {
	@:op(A | B) static function or(a:PropertyLikeParse, b:PropertyLikeParse):PropertyLikeParse;
	@:op(A & B) static function and(a:PropertyLikeParse, b:PropertyLikeParse):PropertyLikeParse;

	var propertyLikeParseProperty = 1 << 0;
	var propertyLikeParseParameter = 1 << 1;
	var propertyLikeParseCallbackParameter = 1 << 2;
}

@:allow(ts.parser)
class Jsdoc {

	static function withJSDoc(p:Parser, node:Node, info:JsdocScannerInfo):Array<Node> {
		if (info&jsdocScannerInfoHasJSDoc == 0) {
			return null;
		}

		// For TS/TSX files, defer JSDoc parsing to first access, unless the comment
		// contains @see/@link (needed for unused-identifier checks).
		// @deprecated is detected via cheap text scan to set PossiblyContainsDeprecatedTag;
		// callers must confirm via JSDoc lookup.
		if (!p.isJavaScript()) {
			node.Flags |= NodeFlagsHasJSDoc;
			if (info&jsdocScannerInfoHasDeprecated != 0) {
				node.Flags |= NodeFlagsPossiblyContainsDeprecatedTag;
			}
			if (info&jsdocScannerInfoHasSeeOrLink == 0) {
				return null;
			}
			// Fall through to eager parse for @see/@link
		}

		// PORT: Go passes p.jsdocCommentRangesSpace (len 0) to append into; here the reused array
		// is truncated when it is taken again.
		var ranges = Parser.GetJSDocCommentRanges(p.factory, Parser.truncate(p.jsdocCommentRangesSpace, 0), node, p.sourceText);
		p.jsdocCommentRangesSpace = ranges;

		// Should only be called once per node
		p.hasDeprecatedTag = false;
		var jsdoc:Array<Node> = [];
		var pos = node.Pos();
		for (i in 0...Core.len(ranges)) {
			final comment = ranges[i];
			final parsed = p.parseJSDocComment(node, comment.Pos(), comment.End(), pos);
			if (parsed != null) {
				parsed.Parent = node;
				jsdoc.push(parsed);
				pos = parsed.End();
			}
		}
		if (Core.len(jsdoc) != 0) {
			if (node.Flags&NodeFlagsHasJSDoc == 0) {
				node.Flags |= NodeFlagsHasJSDoc;
			}
			if (p.hasDeprecatedTag) {
				p.hasDeprecatedTag = false;
				node.Flags |= NodeFlagsPossiblyContainsDeprecatedTag;
			}
			if (p.isJavaScript()) {
				p.reparseTags(node, jsdoc);
			}
			p.jsdocInfos = Parser.append(p.jsdocInfos, new JSDocInfo(node, jsdoc));
			return jsdoc;
		}
		return null;
	}

	static function parseJSDocTypeExpression(p:Parser, mayOmitBraces:Bool):Node {
		var pos = p.nodePos();
		var hasBrace:Bool = false;
		if (mayOmitBraces) {
			hasBrace = p.parseOptional(KindOpenBraceToken);
		} else {
			hasBrace = p.parseExpected(KindOpenBraceToken);
		}
		var saveContextFlags = p.contextFlags;
		p.setContextFlags(NodeFlagsJSDoc, true);
		var t = p.parseJSDocType();
		p.contextFlags = saveContextFlags;
		if (hasBrace) {
			p.parseExpectedJSDoc(KindCloseBraceToken);
		}

		return p.finishNode(p.factory.NewJSDocTypeExpression(t), pos);
	}

	static function parseJSDocNameReference(p:Parser):Node {
		var pos = p.nodePos();
		var hasBrace = p.parseOptional(KindOpenBraceToken);
		var entityName = p.parseJSDocLinkName();
		if (hasBrace) {
			p.parseExpectedJSDoc(KindCloseBraceToken);
		}
		p.scanner.ResetPos(p.scanner.TokenFullStart());
		p.nextTokenJSDoc();
		return p.finishNode(p.factory.NewJSDocNameReference(entityName), pos);
	}

	// Pass end=-1 to parse the text to the end
	static function parseJSDocComment(p:Parser, parent:Node, start:Int, end:Int, fullStart:Int):Node {
		if (end == -1) {
			end = p.sourceText.length;
		}
		// Check for /** (JSDoc opening part)
		if (!Parser.isJSDocLikeTextAt(p.sourceText, start)) {
			// TODO: This should be a panic, unless parseSingleJSDocComment is calling this (not ported yet)
			return null;
		}

		// PORT: perf — the text and its length (p.sourceText may be a prefix: Parser.setSourceTextPrefix)
		var saveSourceText = p.sourceTextFull;
		var saveSourceTextLen = p.sourceTextLen;
		var saveToken = p.token;
		var saveContextFlags = p.contextFlags;
		var saveParsingContexts = p.parsingContexts;
		var saveScannerState = p.scanner.Mark();
		var saveDiagnosticsLength = Core.len(p.diagnostics);
		var saveHasParseError = p.hasParseError;
		var saveHasAwaitIdentifier = p.statementHasAwaitIdentifier;

		// initial indent is start+4 to account for leading `/** `
		// + 1 because \n is one character before the first character in the line and,
		// if there is no \n before start, -1 is one index before the first character in the string
		var initialIndent = start + 4 - (Parser.lastIndexOfNewLine(p.sourceText, start) + 1);
		// -2 for trailing `*/`
		// PORT: perf — p.sourceText[:end-2] without a copy (Go slices)
		p.setSourceTextPrefix(p.sourceTextFull, end - 2);
		p.scanner.SetTextPrefix(p.sourceTextFull, end - 2);
		// +3 for leading `/**`
		p.scanner.ResetPos(start + 3);
		p.setContextFlags(NodeFlagsJSDoc, true);
		p.parsingContexts |= 1 << PCJSDocComment;

		var comment = p.parseJSDocCommentWorker(start, end, fullStart, initialIndent);
		// move jsdoc diagnostics to jsdocDiagnostics -- for JS files only
		if (p.contextFlags&NodeFlagsJavaScriptFile != 0) {
			p.jsdocDiagnostics = Parser.appendAll(p.jsdocDiagnostics, p.diagnostics == null ? null : p.diagnostics.slice(saveDiagnosticsLength));
		}
		p.diagnostics = Parser.truncate(p.diagnostics, saveDiagnosticsLength);

		p.setSourceTextPrefix(saveSourceText, saveSourceTextLen);
		p.scanner.SetTextPrefix(saveSourceText, saveSourceTextLen);
		p.parsingContexts = saveParsingContexts;
		p.contextFlags = saveContextFlags;
		p.scanner.Rewind(saveScannerState);
		p.token = saveToken;
		p.hasParseError = saveHasParseError;
		p.statementHasAwaitIdentifier = saveHasAwaitIdentifier;

		return comment;
	}

	/**
	 * @param offset - the offset in the containing file
	 * @param indent - the number of spaces to consider as the margin (applies to non-first lines only)
	 */
	static function parseJSDocCommentWorker(p:Parser, start:Int, end:Int, fullStart:Int, indent:Int):Node {
		// Initially we can parse out a tag.  We also have seen a starting asterisk.
		// This is so that /** * @type */ doesn't parse.
		var tags:Array<Node> = []; // PORT: arena — Go p.nodeSliceArena.NewSlice(1)[:0]
		var tagsPos = -1;
		var tagsEnd = -1;
		var state = jsdocStateSawAsterisk;
		var backtickCount = 0;
		var inFencedCodeBlock = false;
		var commentParts:Array<Node> = []; // PORT: arena — Go p.nodeSliceArena.NewSlice(1)[:0]
		// PORT: reused slice; Go keeps it at len 0, here it is truncated when taken.
		var comments = p.jsdocCommentsSpace != null ? Parser.truncate(p.jsdocCommentsSpace, 0) : [];
		var commentsPos = -1;
		var linkEnd = start;
		var margin = -1;
		inline function pushComment(text:String):Void {
			if (margin == -1) {
				margin = indent;
			}
			comments.push(text);
			indent += text.length;
		}

		p.nextTokenJSDoc();
		while (p.parseOptionalJsdoc(KindWhitespaceTrivia)) {
		}
		if (p.parseOptionalJsdoc(KindNewLineTrivia)) {
			state = jsdocStateBeginningOfLine;
			indent = 0;
		}
	// PORT: label — `break loop` → `break` (a Haxe `break` in a switch leaves the loop).
	while (true) {
		// Detect fenced code blocks by counting consecutive backtick tokens.
		// Three or more consecutive backticks toggle the fenced code block state.
		if (p.token != KindBacktickToken && backtickCount > 0) {
				if (backtickCount >= 3) {
					inFencedCodeBlock = !inFencedCodeBlock;
				}
				backtickCount = 0;
			}
			switch (p.token) {
			case KindAtToken:
				if (inFencedCodeBlock || !p.scanner.CanFollowJSDocAt()) {
					if (inFencedCodeBlock) {
						state = jsdocStateSavingBackticks;
					} else {
						state = jsdocStateSavingComments;
					}
					pushComment(p.scanner.TokenText());
				} else { // PORT: Go `break` out of the case
					comments = Parser.removeTrailingWhitespace(comments);
					if (commentsPos == -1) {
						commentsPos = p.nodePos();
					}
					var tag = p.parseTag(tags, indent);
					if (tagsPos == -1) {
						tagsPos = tag.Pos();
					}
					tags.push(tag);
					tagsEnd = tag.End();
					// NOTE: According to usejsdoc.org, a tag goes to end of line, except the last tag.
					// Real-world comments may break this rule, so "BeginningOfLine" will not be a real line beginning
					// for malformed examples like `/** @param {string} x @returns {number} the length */`
					state = jsdocStateBeginningOfLine;
					margin = -1;
				}
			case KindNewLineTrivia:
				comments.push(p.scanner.TokenText());
				state = jsdocStateBeginningOfLine;
				indent = 0;
			case KindAsteriskToken:
				var asterisk = p.scanner.TokenText();
				if (state == jsdocStateSawAsterisk) {
					// If we've already seen an asterisk, then we can no longer parse a tag on this line
					state = jsdocStateSavingComments;
					pushComment(asterisk);
				} else {
					if (state != jsdocStateBeginningOfLine) {
						throw "state must be BeginningOfLine";
					}
					// Ignore the first asterisk on a line
					state = jsdocStateSawAsterisk;
					indent += asterisk.length;
				}
			case KindWhitespaceTrivia:
				if (state == jsdocStateSavingComments || state == jsdocStateSavingBackticks) {
					throw "whitespace shouldn't come from the scanner while saving top-level comment text";
				}
				// only collect whitespace if we're already saving comments or have just crossed the comment indent margin
				var whitespace = p.scanner.TokenText();
				if (margin > -1 && indent + whitespace.length > margin) {
					var existingIndent = margin - indent;
					if (existingIndent < 0) {
						existingIndent += whitespace.length;
					}
					if (existingIndent < 0) {
						existingIndent = 0;
					}
					comments.push(whitespace.substring(existingIndent));
				}
				indent += whitespace.length;
			case KindEndOfFile:
				break; // PORT: label — Go `break loop`
			case KindJSDocCommentTextToken:
				if (state != jsdocStateSavingBackticks) {
					if (inFencedCodeBlock) {
						state = jsdocStateSavingBackticks;
					} else {
						state = jsdocStateSavingComments;
					}
				}
				pushComment(p.scanner.TokenValue());
			case KindBacktickToken:
				backtickCount++;
				if (state == jsdocStateSavingBackticks) {
					state = jsdocStateSavingComments;
				} else {
					state = jsdocStateSavingBackticks;
				}
				pushComment(p.scanner.TokenText());
			case KindOpenBraceToken:
				if (inFencedCodeBlock) {
					state = jsdocStateSavingBackticks;
					pushComment(p.scanner.TokenText());
				} else { // PORT: Go `break` out of the case
					state = jsdocStateSavingComments;
					var commentEnd = p.scanner.TokenFullStart();
					var linkStart = p.scanner.TokenEnd() - 1;
					var link = p.parseJSDocLink(linkStart);
					if (link != null) {
						if (linkEnd == start) {
							comments = Parser.removeLeadingNewlines(comments);
						}
						var jsdocText = p.finishNodeWithEnd(p.factory.NewJSDocText(Parser.cloneStrings(comments)), linkEnd, commentEnd);
						commentParts.push(jsdocText);
						commentParts.push(link);
						comments.resize(0);
						linkEnd = p.scanner.TokenEnd();
					} else {
						// PORT: fallthrough into default
						if (state != jsdocStateSavingBackticks) {
							if (inFencedCodeBlock) {
								state = jsdocStateSavingBackticks;
							} else {
								state = jsdocStateSavingComments;
							}
						}
						pushComment(p.scanner.TokenText());
					}
				}
			default:
				// Anything else is doc comment text. We just save it. Because it
				// wasn't a tag, we can no longer parse a tag on this line until we hit the next
				// line break.
				if (state != jsdocStateSavingBackticks) {
					if (inFencedCodeBlock) {
						state = jsdocStateSavingBackticks;
					} else {
						state = jsdocStateSavingComments;
					}
				}
				pushComment(p.scanner.TokenText());
			}
			if (state == jsdocStateSavingComments || state == jsdocStateSavingBackticks) {
				p.nextJSDocCommentTextToken(state == jsdocStateSavingBackticks);
			} else {
				p.nextTokenJSDoc();
			}
		}

		p.jsdocCommentsSpace = comments; // Reuse this slice for further parses
		if (commentsPos == -1) {
			commentsPos = p.scanner.TokenFullStart();
		}

		if (comments.length > 0) {
			comments[comments.length - 1] = Strings.TrimRightFunc(comments[comments.length - 1], Parser.unicodeIsSpace);
			var jsdocText = p.finishNodeWithEnd(p.factory.NewJSDocText(Parser.cloneStrings(comments)), linkEnd, commentsPos);
			commentParts.push(jsdocText);
		}

		if (commentParts.length > 0 && tags.length > 0 && commentsPos == -1) {
			throw "having parsed tags implies that the end of the comment span should be set";
		}

		var tagsNodeList:NodeList = null;
		if (tagsPos != -1) {
			tagsNodeList = p.newNodeList(Core.NewTextRange(tagsPos, tagsEnd), tags);
		}

		var jsdocComment = p.factory.NewJSDoc(p.newNodeList(Core.NewTextRange(start, commentsPos), commentParts), tagsNodeList);
		return p.finishNodeWithEnd(jsdocComment, fullStart, end);
	}

	static function isNextNonwhitespaceTokenEndOfFile(p:Parser):Bool {
		// We must use infinite lookahead, as there could be any number of newlines :(
		while (true) {
			p.nextTokenJSDoc();
			if (p.token == KindEndOfFile) {
				return true;
			}
			if (!(p.token == KindWhitespaceTrivia || p.token == KindNewLineTrivia)) {
				return false;
			}
		}
	}

	static function skipWhitespace(p:Parser):Void {
		if (p.token == KindWhitespaceTrivia || p.token == KindNewLineTrivia) {
			if (p.lookAhead(Parser.fn_isNextNonwhitespaceTokenEndOfFile)) {
				return;
				// Don't skip whitespace prior to EoF (or end of comment) - that shouldn't be included in any node's range
			}
		}
		while (p.token == KindWhitespaceTrivia || p.token == KindNewLineTrivia) {
			p.nextTokenJSDoc();
		}
	}

	static function skipWhitespaceOrAsterisk(p:Parser):String {
		if (p.token == KindWhitespaceTrivia || p.token == KindNewLineTrivia) {
			if (p.lookAhead(Parser.fn_isNextNonwhitespaceTokenEndOfFile)) {
				return "";
				// Don't skip whitespace prior to EoF (or end of comment) - that shouldn't be included in any node's range
			}
		}

		var precedingLineBreak = p.scanner.HasPrecedingLineBreak();
		var seenLineBreak = false;
		var indents:Array<String> = [];
		while ((precedingLineBreak && p.token == KindAsteriskToken) || p.token == KindWhitespaceTrivia || p.token == KindNewLineTrivia) {
			indents.push(p.scanner.TokenText());
			if (p.token == KindNewLineTrivia) {
				precedingLineBreak = true;
				seenLineBreak = true;
				indents.resize(0);
			} else if (p.token == KindAsteriskToken) {
				precedingLineBreak = false;
			}
			p.nextTokenJSDoc();
		}
		if (seenLineBreak) {
			return indents.join("");
		} else {
			return "";
		}
	}

	static function parseTag(p:Parser, tags:Array<Node>, margin:Int):Node {
		if (p.token != KindAtToken) {
			throw "should be called only at the start of a tag";
		}
		var start = p.scanner.TokenStart();
		p.nextTokenJSDoc();

		var tagName = p.parseJSDocIdentifierName(Diagnostics.Identifier_expected);
		var indentText = p.skipWhitespaceOrAsterisk();

		var tag:Node = null;
		switch (tagName.Text()) {
		case "implements":
			tag = p.parseImplementsTag(start, tagName, margin, indentText);
		case "augments" | "extends":
			tag = p.parseAugmentsTag(start, tagName, margin, indentText);
		case "public":
			tag = p.parseSimpleTag(start, function(tagName:IdentifierNode, comments:NodeList):Node {
				return p.factory.NewJSDocPublicTag(tagName, comments);
			}, tagName, margin, indentText);
		case "private":
			tag = p.parseSimpleTag(start, function(tagName:IdentifierNode, comments:NodeList):Node {
				return p.factory.NewJSDocPrivateTag(tagName, comments);
			}, tagName, margin, indentText);
		case "protected":
			tag = p.parseSimpleTag(start, function(tagName:IdentifierNode, comments:NodeList):Node {
				return p.factory.NewJSDocProtectedTag(tagName, comments);
			}, tagName, margin, indentText);
		case "readonly":
			tag = p.parseSimpleTag(start, function(tagName:IdentifierNode, comments:NodeList):Node {
				return p.factory.NewJSDocReadonlyTag(tagName, comments);
			}, tagName, margin, indentText);
		case "override":
			tag = p.parseSimpleTag(start, function(tagName:IdentifierNode, comments:NodeList):Node {
				return p.factory.NewJSDocOverrideTag(tagName, comments);
			}, tagName, margin, indentText);
		case "deprecated":
			p.hasDeprecatedTag = true;
			tag = p.parseSimpleTag(start, function(tagName:IdentifierNode, comments:NodeList):Node {
				return p.factory.NewJSDocDeprecatedTag(tagName, comments);
			}, tagName, margin, indentText);
		case "this":
			tag = p.parseThisTag(start, tagName, margin, indentText);
		case "arg" | "argument" | "param":
			tag = p.parseParameterOrPropertyTag(start, tagName, propertyLikeParseParameter, margin);
		case "return" | "returns":
			tag = p.parseReturnTag(tags, start, tagName, margin, indentText);
		case "template":
			tag = p.parseTemplateTag(start, tagName, margin, indentText);
		case "type":
			tag = p.parseTypeTag(tags, start, tagName, margin, indentText);
		case "typedef":
			tag = p.parseTypedefTag(start, tagName, margin, indentText);
		case "callback":
			tag = p.parseCallbackTag(start, tagName, margin, indentText);
		case "overload":
			tag = p.parseOverloadTag(start, tagName, margin, indentText);
		case "satisfies":
			tag = p.parseSatisfiesTag(start, tagName, margin, indentText);
		case "see":
			tag = p.parseSeeTag(start, tagName, margin, indentText);
		case "exception" | "throws":
			tag = p.parseThrowsTag(start, tagName, margin, indentText);
		case "import":
			tag = p.parseImportTag(start, tagName, margin, indentText);
		default:
			tag = p.parseUnknownTag(start, tagName, margin, indentText);
		}
		if (tag == null) {
			throw "tag should not be null";
		}
		return tag;
	}

	static function parseTrailingTagComments(p:Parser, pos:Int, end:Int, margin:Int, indentText:String):NodeList {
		// some tags, like typedef and callback, have already parsed their comments earlier
		if (indentText.length == 0) {
			margin += end - pos;
		}
		var initialMargin:String = "";
		if (margin < indentText.length) {
			initialMargin = indentText.substring(margin);
		}
		return p.parseTagComments(margin, initialMargin);
	}

	// PORT: pointer — Go `initialMargin *string`; null is Go's nil.
	static function parseTagComments(p:Parser, indent:Int, initialMargin:Null<String>):NodeList {
		var commentsPos = p.nodePos();
		// PORT: reused slices; Go keeps them at len 0, here they are truncated when taken.
		var comments = p.jsdocTagCommentsSpace != null ? Parser.truncate(p.jsdocTagCommentsSpace, 0) : [];
		p.jsdocTagCommentsSpace = null; // !!! can parseTagComments call itself?
		var parts = p.jsdocTagCommentsPartsSpace != null ? Parser.truncate(p.jsdocTagCommentsPartsSpace, 0) : [];
		p.jsdocTagCommentsPartsSpace = null;
		var linkEnd = -1;
		var state = jsdocStateBeginningOfLine;
		var backtickCount = 0;
		var inFencedCodeBlock = false;
		if (indent < 0) {
			throw "indent must be a natural number";
		}
		var margin = -1;
		inline function pushComment(text:String):Void {
			if (margin == -1) {
				margin = indent;
			}
			comments.push(text);
			indent += text.length;
		}

		if (initialMargin != null) {
			// jump straight to saving comments if there is some initial indentation
			if (initialMargin != "") {
				pushComment(initialMargin);
			}
			state = jsdocStateSawAsterisk;
		}
		var tok = p.token;
		// PORT: label — `break loop` → `break` (a Haxe `break` in a switch leaves the loop).
		while (true) {
			// Detect fenced code blocks by counting consecutive backtick tokens.
			// Three or more consecutive backticks toggle the fenced code block state.
			if (tok != KindBacktickToken && backtickCount > 0) {
				if (backtickCount >= 3) {
					inFencedCodeBlock = !inFencedCodeBlock;
				}
				backtickCount = 0;
			}
			switch (tok) {
			case KindNewLineTrivia:
				state = jsdocStateBeginningOfLine;
				// don't use pushComment here because we want to keep the margin unchanged
				comments.push(p.scanner.TokenText());
				indent = 0;
			case KindAtToken:
				if (!inFencedCodeBlock && p.scanner.CanFollowJSDocAt()) {
					p.scanner.ResetPos(p.scanner.TokenEnd() - 1);
					break; // PORT: label — Go `break loop`
				}
				if (inFencedCodeBlock) {
					state = jsdocStateSavingBackticks;
				} else {
					state = jsdocStateSavingComments;
				}
				pushComment(p.scanner.TokenText());
			case KindEndOfFile:
				// Done
				break; // PORT: label — Go `break loop`
			case KindWhitespaceTrivia:
				if (state == jsdocStateSavingComments || state == jsdocStateSavingBackticks) {
					throw "whitespace shouldn't come from the scanner while saving comment text";
				}
				var whitespace = p.scanner.TokenText();
				// if the whitespace crosses the margin, take only the whitespace that passes the margin
				if (margin > -1 && indent + whitespace.length > margin) {
					comments.push(whitespace.substring(margin - indent > 0 ? margin - indent : 0));
					if (inFencedCodeBlock) {
						state = jsdocStateSavingBackticks;
					} else {
						state = jsdocStateSavingComments;
					}
				}
				indent += whitespace.length;
			case KindOpenBraceToken:
				if (inFencedCodeBlock) {
					state = jsdocStateSavingBackticks;
					pushComment(p.scanner.TokenText());
				} else { // PORT: Go `break` out of the case
					state = jsdocStateSavingComments;
					var commentEnd = p.scanner.TokenFullStart();
					var linkStart = p.scanner.TokenEnd() - 1;
					var link = p.parseJSDocLink(linkStart);
					if (link != null) {
						var commentStart:Int = 0;
						if (linkEnd > -1) {
							commentStart = linkEnd;
						} else {
							commentStart = commentsPos;
						}
						var text = p.finishNodeWithEnd(p.factory.NewJSDocText(Parser.cloneStrings(comments)), commentStart, commentEnd);
						parts.push(text);
						parts.push(link);
						comments.resize(0);
						linkEnd = p.scanner.TokenEnd();
					} else {
						pushComment(p.scanner.TokenText());
					}
				}
			case KindBacktickToken:
				backtickCount++;
				if (state == jsdocStateSavingBackticks) {
					state = jsdocStateSavingComments;
				} else {
					state = jsdocStateSavingBackticks;
				}
				pushComment(p.scanner.TokenText());
			case KindJSDocCommentTextToken:
				if (state != jsdocStateSavingBackticks) {
					if (inFencedCodeBlock) {
						state = jsdocStateSavingBackticks;
					} else {
						state = jsdocStateSavingComments;
					}
					// leading identifiers start recording as well
				}
				pushComment(p.scanner.TokenValue());
			case KindAsteriskToken:
				if (state == jsdocStateBeginningOfLine) {
					// leading asterisks start recording on the *next* (non-whitespace) token
					state = jsdocStateSawAsterisk;
					indent += 1;
				} else { // PORT: Go `break` out of the case
					// record the * as a comment
					// PORT: fallthrough into default
					if (state != jsdocStateSavingBackticks) {
						if (inFencedCodeBlock) {
							state = jsdocStateSavingBackticks;
						} else {
							state = jsdocStateSavingComments;
						}
						// leading identifiers start recording as well
					}
					pushComment(p.scanner.TokenText());
				}
			default:
				if (state != jsdocStateSavingBackticks) {
					if (inFencedCodeBlock) {
						state = jsdocStateSavingBackticks;
					} else {
						state = jsdocStateSavingComments;
					}
					// leading identifiers start recording as well
				}
				pushComment(p.scanner.TokenText());
			}
			if (state == jsdocStateSavingComments || state == jsdocStateSavingBackticks) {
				tok = p.nextJSDocCommentTextToken(state == jsdocStateSavingBackticks);
			} else {
				tok = p.nextTokenJSDoc();
			}
		}

		p.jsdocTagCommentsSpace = comments;

		comments = Parser.removeLeadingNewlines(comments);
		comments = Parser.removeTrailingWhitespace(comments);
		if (comments.length > 0) {
			var commentStart:Int = 0;
			if (linkEnd > -1) {
				commentStart = linkEnd;
			} else {
				commentStart = commentsPos;
			}
			var text = p.finishNode(p.factory.NewJSDocText(Parser.cloneStrings(comments)), commentStart);
			parts.push(text);
		}

		p.jsdocTagCommentsPartsSpace = parts;

		if (parts.length > 0) {
			return p.newNodeList(Core.NewTextRange(commentsPos, p.scanner.TokenEnd()), parts.copy()); // PORT: arena — Clone of a reused slice
		}
		return null;
	}

	static function parseJSDocLink(p:Parser, start:Int):Node {
		var state = p.mark();
		var linkType = p.parseJSDocLinkPrefix();
		if (linkType == null) { // PORT: Go `!ok`
			p.rewind(state);
			return null;
		}
		p.nextTokenJSDoc();
		// start at token after link, then skip any whitespace
		p.skipWhitespace();
		var name = p.parseJSDocLinkName();
		var text:Array<String> = null;
		while (p.token != KindCloseBraceToken && p.token != KindNewLineTrivia && p.token != KindEndOfFile) {
			text = Parser.append(text, p.scanner.TokenText());
			p.nextTokenJSDoc(); // Couldn't this be nextTokenCommentJSDoc?
		}
		var create:Node = null;
		switch (linkType) {
		case "link":
			create = p.factory.NewJSDocLink(name, text);
		case "linkcode":
			create = p.factory.NewJSDocLinkCode(name, text);
		default:
			create = p.factory.NewJSDocLinkPlain(name, text);
		}
		return p.finishNodeWithEnd(create, start, p.scanner.TokenEnd());
	}

	static function parseJSDocLinkName(p:Parser):Node {
		if (Parser.tokenIsIdentifierOrKeyword(p.token)) {
			var pos = p.nodePos();
			var name = p.parseIdentifierName();
			while (p.parseOptional(KindDotToken)) {
				var right:IdentifierNode = null;
				if (p.token == KindPrivateIdentifier) {
					right = p.createMissingIdentifier();
				} else {
					right = p.parseIdentifierName();
				}
				name = p.finishNode(p.factory.NewQualifiedName(name, right), pos);
			}
			while (p.token == KindPrivateIdentifier) {
				p.scanner.ReScanHashToken();
				p.nextTokenJSDoc();
				name = p.finishNode(p.factory.NewQualifiedName(name, p.parseIdentifier()), pos);
			}
			return name;
		}
		return null;
	}

	// PORT: Go returns (string, bool); here null stands for ("NONE", false).
	static function parseJSDocLinkPrefix(p:Parser):Null<String> {
		p.skipWhitespaceOrAsterisk();
		if (p.token == KindOpenBraceToken && p.nextTokenJSDoc() == KindAtToken && Parser.tokenIsIdentifierOrKeyword(p.nextTokenJSDoc())) {
			var kind = p.scanner.TokenValue();
			if (Parser.isJSDocLinkTag(kind)) {
				return kind;
			}
		}
		return null;
	}

	static function parseUnknownTag(p:Parser, start:Int, tagName:IdentifierNode, indent:Int, indentText:String):Node {
		return p.finishNode(p.factory.NewJSDocUnknownTag(tagName, p.parseTrailingTagComments(start, p.nodePos(), indent, indentText)), start);
	}

	static function tryParseTypeExpression(p:Parser):Node {
		p.skipWhitespaceOrAsterisk();
		if (p.token == KindOpenBraceToken) {
			return p.parseJSDocTypeExpression(false /*mayOmitBraces*/);
		} else {
			return null;
		}
	}

	// PORT: Go returns (name, isBracketed); isBracketed is the out field p.bracketNameIsBracketed.
	static function parseBracketNameInPropertyAndParamTag(p:Parser, target:PropertyLikeParse):EntityName {
		var name:EntityName = null;
		// Looking for something like '[foo]', 'foo', '[foo.bar]' or 'foo.bar'
		var isBracketed = p.parseOptionalJsdoc(KindOpenBracketToken);
		if (isBracketed) {
			p.skipWhitespace();
		}
		// a markdown-quoted name: `arg` is not legal jsdoc, but occurs in the wild
		var isBackquoted = p.parseOptionalJsdoc(KindBacktickToken);
		name = p.parseJSDocEntityName((target == propertyLikeParseParameter ? null : Diagnostics.Identifier_expected));
		if (isBackquoted) {
			p.parseExpectedTokenJSDoc(KindBacktickToken);
		}
		if (isBracketed) {
			p.skipWhitespace();
			// May have an optional default, e.g. '[foo = 42]'
			if (p.parseOptionalToken(KindEqualsToken) != null) {
				p.parseExpression();
			}

			p.parseExpected(KindCloseBracketToken);
		}

		p.bracketNameIsBracketed = isBracketed;
		return name;
	}

	static function parseParameterOrPropertyTag(p:Parser, start:Int, tagName:IdentifierNode, target:PropertyLikeParse, indent:Int):Node {
		var typeExpression = p.tryParseTypeExpression();
		var isNameFirst = typeExpression == null;
		p.skipWhitespaceOrAsterisk();

		var name = p.parseBracketNameInPropertyAndParamTag(target);
		var isBracketed = p.bracketNameIsBracketed;
		var indentText = p.skipWhitespaceOrAsterisk();

		if (isNameFirst && p.lookAhead(fl_notJSDocLinkPrefix)) {
			typeExpression = p.tryParseTypeExpression();
		}

		var comment = p.parseTrailingTagComments(start, p.nodePos(), indent, indentText);

		var nestedTypeLiteral = p.parseNestedTypeLiteral(typeExpression, name, target, indent);
		if (nestedTypeLiteral != null) {
			typeExpression = nestedTypeLiteral;
			isNameFirst = true;
		}
		var result:Node /* JSDocPropertyTag | JSDocParameterTag */ = null;
		var kind = (target == propertyLikeParseProperty ? KindJSDocPropertyTag : KindJSDocParameterTag);
		result = p.factory.NewJSDocParameterOrPropertyTag(kind, tagName, name, isBracketed, typeExpression, isNameFirst, comment);
		return p.finishNode(result, start);
	}

	static function parseNestedTypeLiteral(p:Parser, typeExpression:Node, name:EntityName, target:PropertyLikeParse, indent:Int):Node {
		if (typeExpression != null && Parser.isObjectOrObjectArrayTypeReference(typeExpression.Type())) {
			var pos = p.nodePos();
			var children:Array<Node> = null;
			while (true) {
				var state = p.mark();
				var child = p.parseChildParameterOrPropertyTag(target, indent, name);
				if (child == null) {
					p.rewind(state);
					break;
				}
				switch (child.Kind) {
				case KindJSDocParameterTag | KindJSDocPropertyTag:
					children = Parser.append(children, child);
				case KindJSDocTemplateTag:
					p.parseErrorAtRange(child.TagName().Loc, Diagnostics.A_JSDoc_template_tag_may_not_follow_a_typedef_callback_or_overload_tag);
				default:
				}
			}
			if (children != null) {
				var literal = p.finishNode(p.factory.NewJSDocTypeLiteral(children, typeExpression.Type().Kind == KindArrayType), pos);
				return p.finishNode(p.factory.NewJSDocTypeExpression(literal), pos);
			}
		}
		return null;
	}

	static function parseReturnTag(p:Parser, previousTags:Array<Node>, start:Int, tagName:IdentifierNode, indent:Int, indentText:String):Node {
		if (Core.Some(previousTags, Parser.isJSDocReturnTagFn)) {
			p.parseErrorAt(tagName.Pos(), p.scanner.TokenStart(), Diagnostics.X_0_tag_already_specified, tagName.Text());
		}

		var typeExpression = p.tryParseTypeExpression();
		return p.finishNode(p.factory.NewJSDocReturnTag(tagName, typeExpression, p.parseTrailingTagComments(start, p.nodePos(), indent, indentText)), start);
	}

	// pass indent=-1 to skip parsing trailing comments (as when a type tag is nested in a typedef)
	static function parseTypeTag(p:Parser, previousTags:Array<Node>, start:Int, tagName:IdentifierNode, indent:Int, indentText:String):Node {
		if (Core.Some(previousTags, Parser.isJSDocTypeTagFn)) {
			p.parseErrorAt(tagName.Pos(), p.scanner.TokenStart(), Diagnostics.X_0_tag_already_specified, tagName.Text());
		}

		var typeExpression = p.parseJSDocTypeExpression(true);
		var comments:NodeList = null;
		if (indent != -1) {
			comments = p.parseTrailingTagComments(start, p.nodePos(), indent, indentText);
		}
		return p.finishNode(p.factory.NewJSDocTypeTag(tagName, typeExpression, comments), start);
	}

	static function parseSeeTag(p:Parser, start:Int, tagName:IdentifierNode, indent:Int, indentText:String):Node {
		var hasNameReference = p.isIdentifier() && !Parser.match(p.sourceText, p.scanner.TokenEnd(), "://") ||
			p.token == KindOpenBraceToken && p.lookAhead(Parser.fn_nextTokenIsIdentifierOrKeyword);
		var nameExpression:Node = null;
		if (hasNameReference) {
			nameExpression = p.parseJSDocNameReference();
		}
		var comments = p.parseTrailingTagComments(start, p.nodePos(), indent, indentText);
		return p.finishNode(p.factory.NewJSDocSeeTag(tagName, nameExpression, comments), start);
	}

	static function parseImplementsTag(p:Parser, start:Int, tagName:IdentifierNode, margin:Int, indentText:String):Node {
		var className = p.parseExpressionWithTypeArgumentsForAugments();
		return p.finishNode(p.factory.NewJSDocImplementsTag(tagName, className, p.parseTrailingTagComments(start, p.nodePos(), margin, indentText)), start);
	}

	static function parseAugmentsTag(p:Parser, start:Int, tagName:IdentifierNode, margin:Int, indentText:String):Node {
		var className = p.parseExpressionWithTypeArgumentsForAugments();
		return p.finishNode(p.factory.NewJSDocAugmentsTag(tagName, className, p.parseTrailingTagComments(start, p.nodePos(), margin, indentText)), start);
	}

	static function parseSatisfiesTag(p:Parser, start:Int, tagName:IdentifierNode, margin:Int, indentText:String):Node {
		var typeExpression = p.parseJSDocTypeExpression(false);
		var comments = p.parseTrailingTagComments(start, p.nodePos(), margin, indentText);
		return p.finishNode(p.factory.NewJSDocSatisfiesTag(tagName, typeExpression, comments), start);
	}

	static function parseThrowsTag(p:Parser, start:Int, tagName:IdentifierNode, margin:Int, indentText:String):Node {
		var typeExpression = p.tryParseTypeExpression();
		var comment = p.parseTrailingTagComments(start, p.nodePos(), margin, indentText);
		return p.finishNode(p.factory.NewJSDocThrowsTag(tagName, typeExpression, comment), start);
	}

	static function parseImportTag(p:Parser, start:Int, tagName:IdentifierNode, margin:Int, indentText:String):Node {
		var afterImportTagPos = p.scanner.TokenFullStart();

		var identifier:IdentifierNode = null;
		if (p.isIdentifier()) {
			identifier = p.parseIdentifier();
		}

		var importClause = p.tryParseImportClause(identifier, afterImportTagPos, KindTypeKeyword, true /*skipJSDocLeadingAsterisks*/);
		var moduleSpecifier = p.parseModuleSpecifier();
		var attributes = p.tryParseImportAttributes();

		var comments = p.parseTrailingTagComments(start, p.nodePos(), margin, indentText);
		return p.finishNode(p.factory.NewJSDocImportTag(tagName, importClause, moduleSpecifier, attributes, comments), start);
	}

	static function parseExpressionWithTypeArgumentsForAugments(p:Parser):Node {
		var usedBrace = p.parseOptional(KindOpenBraceToken);
		var pos = p.nodePos();
		var expression = p.parsePropertyAccessEntityNameExpression();
		p.scanner.SetSkipJSDocLeadingAsterisks(true);
		var typeArguments = p.parseTypeArguments();
		p.scanner.SetSkipJSDocLeadingAsterisks(false);
		var node = p.finishNode(p.factory.NewExpressionWithTypeArguments(expression, typeArguments), pos);
		if (usedBrace) {
			p.skipWhitespace();
			p.parseExpected(KindCloseBraceToken);
		}
		return node;
	}

	static function parsePropertyAccessEntityNameExpression(p:Parser):Node {
		var pos = p.nodePos();
		var node = p.parseJSDocIdentifierName(Diagnostics.Identifier_expected);
		while (p.parseOptional(KindDotToken)) {
			var name = p.parseJSDocIdentifierName(Diagnostics.Identifier_expected);
			node = p.finishNode(p.factory.NewPropertyAccessExpression(node, null, name, NodeFlagsNone), pos);
		}
		return node;
	}

	static function parseSimpleTag(p:Parser, start:Int, createTag:(tagName:IdentifierNode, comment:NodeList) -> Node, tagName:IdentifierNode, margin:Int, indentText:String):Node {
		return p.finishNode(createTag(tagName, p.parseTrailingTagComments(start, p.nodePos(), margin, indentText)), start);
	}

	static function parseThisTag(p:Parser, start:Int, tagName:IdentifierNode, margin:Int, indentText:String):Node {
		var typeExpression = p.parseJSDocTypeExpression(true);
		p.skipWhitespace();
		var result = p.factory.NewJSDocThisTag(tagName, typeExpression, p.parseTrailingTagComments(start, p.nodePos(), margin, indentText));
		return p.finishNode(result, start);
	}

	static function parseJSDocTypeNameWithNamespace(p:Parser, nested:Bool):Node {
		var start = p.scanner.TokenStart();
		if (!Parser.tokenIsIdentifierOrKeyword(p.token)) {
			return null;
		}
		var typeNameOrNamespaceName = p.parseJSDocIdentifierName(null);
		if (p.parseOptionalJsdoc(KindDotToken)) {
			var body = p.parseJSDocTypeNameWithNamespace(true /*nested*/);
			var jsDocNamespaceNode = p.factory.NewModuleDeclaration(null /*modifiers*/, KindNamespaceKeyword /*keyword*/, typeNameOrNamespaceName, body);
			if (nested) {
				jsDocNamespaceNode.Flags |= NodeFlagsNestedNamespace;
			}
			return p.finishNode(jsDocNamespaceNode, start);
		}
		if (nested) {
			typeNameOrNamespaceName.Flags |= NodeFlagsIdentifierIsInJSDocNamespace;
		}
		return typeNameOrNamespaceName;
	}

	static function parseTypedefTag(p:Parser, start:Int, tagName:IdentifierNode, indent:Int, indentText:String):Node {
		var typeExpression = p.tryParseTypeExpression();
		p.skipWhitespaceOrAsterisk();
		var fullName = p.parseJSDocTypeNameWithNamespace(false /*nested*/);
		if (fullName == null) {
			fullName = p.parseJSDocIdentifierName(Diagnostics.Identifier_expected);
		}
		p.skipWhitespace();
		var comment = p.parseTagComments(indent, null);

		var end = -1;
		var hasChildren = false;
		if (typeExpression == null || Parser.isObjectOrObjectArrayTypeReference(typeExpression.Type())) {
			var child:Node = null;
			var childTypeTag:JSDocTypeTag = null;
			var jsdocPropertyTags:Array<Node> = null;
			while (true) {
				var state = p.mark();
				child = p.parseChildPropertyTag(indent);
				if (child == null) {
					p.rewind(state);
					break;
				}
				hasChildren = true;
				switch (child.Kind) {
				case KindJSDocTemplateTag:
					p.parseErrorAtRange(child.TagName().Loc, Diagnostics.A_JSDoc_template_tag_may_not_follow_a_typedef_callback_or_overload_tag);
				case KindJSDocTypeTag:
					if (childTypeTag == null) {
						childTypeTag = child.AsJSDocTypeTag();
					} else {
						var lastError = p.parseErrorAtCurrentToken(Diagnostics.A_JSDoc_typedef_comment_may_not_contain_multiple_type_tags);
						if (lastError != null) {
							var related = Ast.NewDiagnostic(null, Core.NewTextRange(0, 0), Diagnostics.The_tag_was_first_specified_here);
							lastError.AddRelatedInfo(related);
						}
					}
				default:
					jsdocPropertyTags = Parser.append(jsdocPropertyTags, child);
				}
			}
			if (hasChildren) {
				var isArrayType = typeExpression != null && typeExpression.Type().Kind == KindArrayType;
				var jsdocTypeLiteral = p.factory.NewJSDocTypeLiteral(jsdocPropertyTags, isArrayType);
				if (childTypeTag != null && childTypeTag.TypeExpression != null && !Parser.isObjectOrObjectArrayTypeReference(childTypeTag.TypeExpression.Type())) {
					typeExpression = childTypeTag.TypeExpression;
				} else {
					// !!! This differs from Strada but prevents a crash
					var pos = start;
					if (Core.len(jsdocPropertyTags) > 0) {
						pos = jsdocPropertyTags[0].Pos();
					}
					typeExpression = p.finishNode(jsdocTypeLiteral, pos);
				}
				end = typeExpression.End();
			}
		}

		// Only include the characters between the name end and the next token if a comment was actually parsed out - otherwise it's just whitespace
		if (end == -1) {
			if (hasChildren && typeExpression != null) {
				end = typeExpression.End();
			} else if (comment != null) {
				end = p.nodePos();
			} else if (fullName != null) {
				end = fullName.End();
			} else if (typeExpression != null) {
				end = typeExpression.End();
			} else {
				end = tagName.End();
			}
		}

		if (comment == null) {
			comment = p.parseTrailingTagComments(start, end, indent, indentText);
		}

		var typedefTag = p.finishNodeWithEnd(p.factory.NewJSDocTypedefTag(tagName, typeExpression, fullName, comment), start, end);
		if (typeExpression != null) {
			typeExpression.Parent = typedefTag; // forcibly overwrite parent potentially set by inner type expression parse
		}
		return typedefTag;
	}

	static function parseCallbackTagParameters(p:Parser, indent:Int):NodeList {
		var child:Node = null;
		var parameters:Array<Node> = null;
		var pos = p.nodePos();
		while (true) {
			var state = p.mark();
			child = p.parseChildParameterOrPropertyTag(propertyLikeParseCallbackParameter, indent, null);
			if (child == null) {
				p.rewind(state);
				break;
			}
			if (child.Kind == KindJSDocTemplateTag) {
				p.parseErrorAtRange(child.TagName().Loc, Diagnostics.A_JSDoc_template_tag_may_not_follow_a_typedef_callback_or_overload_tag);
			} else {
				parameters = Parser.append(parameters, child);
			}
		}
		return p.newNodeList(Core.NewTextRange(pos, p.nodePos()), parameters);
	}

	static function parseJSDocSignature(p:Parser, start:Int, indent:Int):Node {
		var parameters = p.parseCallbackTagParameters(indent);
		var returnTag:Node = null;
		var state = p.mark();
		if (p.parseOptionalJsdoc(KindAtToken)) {
			var tag = p.parseTag(null, indent);
			if (tag.Kind == KindJSDocReturnTag) {
				returnTag = tag;
			}
		}
		if (returnTag == null) {
			p.rewind(state);
		}
		return p.finishNode(p.factory.NewJSDocSignature(null, parameters, returnTag), start);
	}

	static function parseCallbackTag(p:Parser, start:Int, tagName:IdentifierNode, indent:Int, indentText:String):Node {
		var fullName = p.parseJSDocTypeNameWithNamespace(false /*nested*/);
		if (fullName == null) {
			fullName = p.parseJSDocIdentifierName(Diagnostics.Identifier_expected);
		}
		p.skipWhitespace();
		var comment = p.parseTagComments(indent, null);
		var typeExpression = p.parseJSDocSignature(p.nodePos(), indent);
		if (comment == null) {
			comment = p.parseTrailingTagComments(start, p.nodePos(), indent, indentText);
		}
		var end:Int = 0;
		if (comment != null) {
			end = p.nodePos();
		} else {
			end = typeExpression.End();
		}
		return p.finishNodeWithEnd(p.factory.NewJSDocCallbackTag(tagName, typeExpression, fullName, comment), start, end);
	}

	static function parseOverloadTag(p:Parser, start:Int, tagName:IdentifierNode, indent:Int, indentText:String):Node {
		p.skipWhitespace();
		var comment = p.parseTagComments(indent, null);
		var typeExpression = p.parseJSDocSignature(start, indent);
		if (comment == null) {
			comment = p.parseTrailingTagComments(start, p.nodePos(), indent, indentText);
		}
		var end:Int = 0;
		if (comment != null) {
			end = p.nodePos();
		} else {
			end = typeExpression.End();
		}
		return p.finishNodeWithEnd(p.factory.NewJSDocOverloadTag(tagName, typeExpression, comment), start, end);
	}

	static function parseChildPropertyTag(p:Parser, indent:Int):Node {
		return p.parseChildParameterOrPropertyTag(propertyLikeParseProperty, indent, null);
	}

	static function parseChildParameterOrPropertyTag(p:Parser, target:PropertyLikeParse, indent:Int, name:EntityName):Node {
		var canParseTag = true;
		var seenAsterisk = false;
		while (true) {
			switch (p.nextTokenJSDoc()) {
			case KindAtToken:
				if (canParseTag && p.scanner.CanFollowJSDocAt()) {
					var child = p.tryParseChildTag(target, indent);
					if (child != null && name != null &&
						(child.Kind == KindJSDocParameterTag || child.Kind == KindJSDocPropertyTag) &&
						(Ast.IsIdentifier(child.Name()) || !Parser.textsEqual(name, child.Name().AsQualifiedName().Left))) {
						return null;
					}
					return child;
				}
				seenAsterisk = false;
			case KindNewLineTrivia:
				canParseTag = true;
				seenAsterisk = false;
			case KindAsteriskToken:
				if (seenAsterisk) {
					canParseTag = false;
				}
				seenAsterisk = true;
			case KindIdentifier:
				canParseTag = false;
			case KindEndOfFile:
				return null;
			default:
			}
		}
	}

	static function tryParseChildTag(p:Parser, target:PropertyLikeParse, indent:Int):Node {
		if (p.token != KindAtToken) {
			throw "should only be called when at @";
		}
		var start = p.scanner.TokenFullStart();
		p.nextTokenJSDoc();

		var tagName = p.parseJSDocIdentifierName(Diagnostics.Identifier_expected);
		var indentText = p.skipWhitespaceOrAsterisk();
		var t:PropertyLikeParse = 0;
		switch (tagName.Text()) {
		case "type":
			if (target == propertyLikeParseProperty) {
				return p.parseTypeTag(null, start, tagName, -1, "");
			}
		case "prop" | "property":
			t = propertyLikeParseProperty;
		case "arg" | "argument" | "param":
			t = propertyLikeParseParameter | propertyLikeParseCallbackParameter;
		case "template":
			return p.parseTemplateTag(start, tagName, indent, indentText);
		case "this":
			return p.parseThisTag(start, tagName, indent, indentText);
		default:
			return null;
		}
		if ((target & t) == 0) {
			return null;
		}
		return p.parseParameterOrPropertyTag(start, tagName, target, indent);
	}

	static function parseTemplateTagTypeParameter(p:Parser):Node {
		var typeParameterPos = p.nodePos();
		var isBracketed = p.parseOptionalJsdoc(KindOpenBracketToken);
		if (isBracketed) {
			p.skipWhitespace();
		}

		var modifiers = p.parseModifiersEx(false, true /*permitConstAsModifier*/, false);
		var name = p.parseJSDocIdentifierName(Diagnostics.Unexpected_token_A_type_parameter_name_was_expected_without_curly_braces);
		var defaultType:Node = null;
		if (isBracketed) {
			p.skipWhitespace();
			p.parseExpected(KindEqualsToken);
			var saveContextFlags = p.contextFlags;
			p.setContextFlags(NodeFlagsJSDoc, true);
			defaultType = p.parseJSDocType();
			p.contextFlags = saveContextFlags;
			p.parseExpected(KindCloseBracketToken);
		}

		if (Ast.NodeIsMissing(name)) {
			return null;
		}
		return p.finishNode(p.factory.NewTypeParameterDeclaration(modifiers, name, null /*constraint*/, null /*expression*/, defaultType), typeParameterPos);
	}

	static function parseTemplateTagTypeParameters(p:Parser):TypeParameterList {
		var typeParameters = new NodeList(); // Go zero value ast.TypeParameterList{}
		do { // do-while loop
			p.skipWhitespace();
			var node = p.parseTemplateTagTypeParameter();
			if (node != null) {
				typeParameters.Nodes = Parser.append(typeParameters.Nodes, node);
			}
			p.skipWhitespaceOrAsterisk();
		} while (p.parseOptionalJsdoc(KindCommaToken));
		return typeParameters;
	}

	static function parseTemplateTag(p:Parser, start:Int, tagName:IdentifierNode, indent:Int, indentText:String):Node {
		// The template tag looks like one of the following:
		//   @template T,U,V
		//   @template {Constraint} T
		//
		// According to the [closure docs](https://github.com/google/closure-compiler/wiki/Generic-Types#multiple-bounded-template-types):
		//   > Multiple bounded generics cannot be declared on the same line. For the sake of clarity, if multiple templates share the same
		//   > type bound they must be declared on separate lines.
		//
		// TODO: Determine whether we should enforce this in the checker.
		// TODO: Consider moving the `constraint` to the first type parameter as we could then remove `getEffectiveConstraintOfTypeParameter`.
		// TODO: Consider only parsing a single type parameter if there is a constraint.
		var constraint:Node = null;
		if (p.token == KindOpenBraceToken) {
			constraint = p.parseJSDocTypeExpression(false);
		}
		var typeParameters = p.parseTemplateTagTypeParameters();
		var result = p.factory.NewJSDocTemplateTag(tagName, constraint, typeParameters, p.parseTrailingTagComments(start, p.nodePos(), indent, indentText));
		return p.finishNode(result, start);
	}

	static function parseOptionalJsdoc(p:Parser, t:Kind):Bool {
		if (p.token == t) {
			p.nextTokenJSDoc();
			return true;
		}
		return false;
	}

	static function parseJSDocEntityName(p:Parser, diagnosticMessage:Message):EntityName {
		var entity:EntityName = p.parseJSDocIdentifierName(diagnosticMessage);
		if (p.parseOptional(KindOpenBracketToken)) {
			p.parseExpected(KindCloseBracketToken);
			// Note that y[] is accepted as an entity name, but the postfix brackets are not saved for checking.
			// Technically usejsdoc.org requires them for specifying a property of a type equivalent to Array<{ x: ...}>
			// but it's not worth it to enforce that restriction.
		}
		while (p.parseOptional(KindDotToken)) {
			var name = p.parseJSDocIdentifierName(Diagnostics.Identifier_expected);
			if (p.parseOptional(KindOpenBracketToken)) {
				p.parseExpected(KindCloseBracketToken);
			}
			var pos = entity.Pos();
			entity = p.finishNode(p.factory.NewQualifiedName(entity, name), pos);
		}
		return entity;
	}

	static function parseJSDocIdentifierName(p:Parser, diagnosticMessage:Message):IdentifierNode {
		if (!Parser.tokenIsIdentifierOrKeyword(p.token)) {
			if (diagnosticMessage != null) {
				p.parseErrorAtCurrentToken(diagnosticMessage);
			} else if (Parser.isReservedWord(p.token)) {
				p.parseErrorAtCurrentToken(Diagnostics.Identifier_expected_0_is_a_reserved_word_that_cannot_be_used_here, p.scanner.TokenText());
			}
			return p.finishNode(p.newIdentifier(""), p.nodePos());
		}
		var pos = p.scanner.TokenStart();
		var end = p.scanner.TokenEnd();
		var text = p.scanner.TokenValue();
		p.internIdentifier(text);
		p.nextTokenJSDoc();
		return p.finishNodeWithEnd(p.newIdentifier(text), pos, end);
	}

	// PORT: Go func literal `func(p *Parser) bool { _, ok := p.parseJSDocLinkPrefix(); return !ok }`
	// (no captures) → created once.
	static final fl_notJSDocLinkPrefix:(p:Parser) -> Bool = function(p:Parser):Bool {
		return p.parseJSDocLinkPrefix() == null;
	};
}
