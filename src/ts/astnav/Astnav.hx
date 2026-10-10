package ts.astnav;

// Port of internal/astnav (tokens.go).
@:allow(ts.astnav)
class Astnav {
	// --- tokens.go ---

	static function shouldRescanLessThanLessThanToken(s:Scanner, containingNode:Node, token:Kind):Bool {
		return token == KindLessThanLessThanToken && Ast.IsJsxChild(containingNode);
	}

	static function scanNavigationToken(s:Scanner, containingNode:Node):Kind {
		final token = s.Token();
		if (shouldRescanLessThanLessThanToken(s, containingNode, token)) {
			return s.ReScanJsxToken(true /*allowMultilineJsxText*/);
		}
		return token;
	}

	public static function GetTouchingPropertyName(sourceFile:SourceFile, position:Int):Node {
		return getTokenAtPosition(sourceFile, position, false /*allowPositionInLeadingTrivia*/, function(node:Node):Bool {
			return Ast.IsPropertyNameLiteral(node) || Ast.IsKeywordKind(node.Kind) || Ast.IsPrivateIdentifier(node);
		});
	}

	public static function GetTouchingToken(sourceFile:SourceFile, position:Int):Node {
		return getTokenAtPosition(sourceFile, position, false /*allowPositionInLeadingTrivia*/, null);
	}

	public static function GetTokenAtPosition(sourceFile:SourceFile, position:Int):Node {
		return getTokenAtPosition(sourceFile, position, true /*allowPositionInLeadingTrivia*/, null);
	}

	static function getTokenAtPosition(sourceFile:SourceFile, position:Int, allowPositionInLeadingTrivia:Bool,
			includePrecedingTokenAtEndPosition:(node:Node) -> Bool):Node {
		// getTokenAtPosition returns a token at the given position in the source file.
		// The token can be a real node in the AST, or a synthesized token constructed
		// with information from the scanner. Synthesized tokens are only created when
		// needed, and they are stored in the source file's token cache such that multiple
		// calls to getTokenAtPosition with the same position will return the same object
		// in memory. If there is no token at the given position (possible when
		// `allowPositionInLeadingTrivia` is false), the lowest node that encloses the
		// position is returned.

		// `next` tracks the node whose children will be visited on the next iteration.
		// `prevSubtree` is a node whose end position is equal to the target position,
		// only if `includePrecedingTokenAtEndPosition` is provided. Once set, the next
		// iteration of the loop will test the rightmost token of `prevSubtree` to see
		// if it should be returned.
		var next:Node = null, prevSubtree:Node = null;
		var current = sourceFile.AsNode();
		// `left` tracks the lower boundary of the node/token that could be returned,
		// and is eventually the scanner's start position, if the scanner is used.
		var left = 0;
		// `nodeAfterLeft` tracks the first node we visit after visiting the node that advances `left`.
		// When scanning in between nodes for token, we should only scan up to the start of `nodeAfterLeft`.
		var nodeAfterLeft:Node = null;

		final testNode = function(node:Node):Int {
			if (node.Kind != KindEndOfFile && node.End() == position && includePrecedingTokenAtEndPosition != null
				&& (node.Flags & NodeFlagsReparsed) == 0) {
				prevSubtree = node;
			}

			// A node "contains" the position if position < end, except nodes at the file end
			// treat end as inclusive (there's nowhere else to look). This applies to the EOF
			// token itself, and to JSDoc nodes reaching EOF (e.g. unterminated JSDoc comments).
			if (node.End() < position
				|| node.End() == position
				&& node.Kind != KindEndOfFile
				&& (!Ast.IsJSDocKind(node.Kind) || node.End() != sourceFile.EndOfFileToken.End())) {
				return -1;
			}
			final nodePos = getPosition(node, sourceFile, allowPositionInLeadingTrivia);
			if (nodePos > position) {
				return 1;
			}
			return 0;
		};

		// We zero in on the node that contains the target position by visiting each
		// child and JSDoc comment of the current node. Node children are walked in
		// order, while node lists are binary searched.
		final visitNode = function(node:Node, _:NodeVisitor):Node {
			// We can't abort visiting children, so once a match is found, we set `next`
			// and do nothing on subsequent visits.
			if (node == null || (node.Flags & NodeFlagsReparsed) != 0) {
				return null;
			}
			if (nodeAfterLeft == null) {
				nodeAfterLeft = node;
			}
			if (next == null) {
				final result = testNode(node);
				if (result == -1) {
					if (!Ast.IsJSDocKind(node.Kind)) {
						// We can't move the left boundary into or beyond JSDoc,
						// because we may end up returning the token after this JSDoc,
						// constructing it with the scanner, and we need to include
						// all its leading trivia in its position.
						left = node.End();
					}
					nodeAfterLeft = null;
				} else if (result == 0) {
					next = node;
				}
			}
			return node;
		};

		final visitNodeList = function(nodeList:NodeList, _:NodeVisitor):NodeList {
			if (nodeList == null || Core.len(nodeList.Nodes) == 0) {
				return nodeList;
			}
			if (nodeAfterLeft == null) {
				for (node in nodeList.Nodes) {
					if ((node.Flags & NodeFlagsReparsed) == 0) {
						nodeAfterLeft = node;
						break;
					}
				}
			}
			if (next == null) {
				if (nodeList.End() == position && includePrecedingTokenAtEndPosition != null) {
					left = nodeList.End();
					nodeAfterLeft = null;
					var i = nodeList.Nodes.length - 1;
					while (i >= 0) {
						if ((nodeList.Nodes[i].Flags & NodeFlagsReparsed) == 0) {
							prevSubtree = nodeList.Nodes[i];
							break;
						}
						i--;
					}
				} else if (nodeList.End() <= position) {
					left = nodeList.End();
					nodeAfterLeft = null;
				} else if (nodeList.Pos() <= position) {
					var nodes = nodeList.Nodes;
					var r = Core.BinarySearchUniqueFunc(nodes, function(middle:Int, node:Node):Int {
						if ((node.Flags & NodeFlagsReparsed) != 0) {
							return 0;
						}
						final cmp = testNode(node);
						if (cmp < 0) {
							left = node.End();
							nodeAfterLeft = null;
							for (i in middle + 1...nodes.length) {
								if ((nodes[i].Flags & NodeFlagsReparsed) == 0) {
									nodeAfterLeft = nodes[i];
									break;
								}
							}
						}
						return cmp;
					});
					var index = r.value, match = r.ok;
					if (match && (nodes[index].Flags & NodeFlagsReparsed) != 0) {
						// filter and search again
						nodes = Core.Filter(nodes, function(node:Node):Bool {
							return (node.Flags & NodeFlagsReparsed) == 0;
						});
						r = Core.BinarySearchUniqueFunc(nodes, function(middle:Int, node:Node):Int {
							final cmp = testNode(node);
							if (cmp < 0) {
								left = node.End();
								if (middle + 1 < nodes.length) {
									nodeAfterLeft = nodes[middle + 1];
								} else {
									nodeAfterLeft = null;
								}
							}
							return cmp;
						});
						index = r.value;
						match = r.ok;
					}
					if (match) {
						next = nodes[index];
					}
				}
			}
			return nodeList;
		};

		while (true) {
			VisitEachChildAndJSDoc(current, sourceFile, visitNode, visitNodeList);
			// If prevSubtree was set on the last iteration, it ends at the target position.
			// Check if the rightmost token of prevSubtree should be returned based on the
			// `includePrecedingTokenAtEndPosition` callback.
			if (prevSubtree != null) {
				final child = FindPrecedingTokenEx(sourceFile, position, prevSubtree, false /*excludeJSDoc*/);
				if (child != null && child.End() == position && includePrecedingTokenAtEndPosition(child)) {
					// Optimization: includePrecedingTokenAtEndPosition only ever returns true
					// for real AST nodes, so we don't run the scanner here.
					return child;
				}
				prevSubtree = null;
			}

			// No node was found that contains the target position, so we've gone as deep as
			// we can in the AST. We've either found a token, or we need to run the scanner
			// to construct one that isn't stored in the AST.
			if (next == null) {
				if (Ast.IsTokenKind(current.Kind) || shouldSkipChild(current)) {
					return current;
				}
				final scanner = Scanner.GetScannerForSourceFile(sourceFile, left);
				var end = current.End();
				// We should only scan up to the start of the next node in the AST after the node ending at position `left`.
				// It is necessary to enforce this invariant in cases where `position` occurs in between two node/tokens,
				// such that we would not find a token in the loop below before we reach the next node.
				// We can fall into this case when `allowPositionInLeadingTrivia` is false and `position` is in a leading trivia,
				// or when `position` would be in the leading trivia of a node but this node is inside JSDoc:
				// ```
				// /**
				//  * @type {{
				//  */*$*/ identifier: boolean;
				//  * }}
				//  */
				// ```
				// The position of marker '$' falls in between the asterisk token and the identifier token, but is not
				// part of the leading trivia for `identifier`.
				if (nodeAfterLeft != null) {
					end = nodeAfterLeft.Pos();
				}
				while (left < end) {
					final token = scanNavigationToken(scanner, current);
					final tokenFullStart = scanner.TokenFullStart();
					final tokenStart = Core.IfElse(allowPositionInLeadingTrivia, tokenFullStart, scanner.TokenStart());
					final tokenEnd = scanner.TokenEnd();
					final flags = scanner.TokenFlags();
					if (tokenEnd > end) {
						break;
					}
					if (tokenStart <= position && (position < tokenEnd)) {
						if (token == KindIdentifier || !Ast.IsTokenKind(token)) {
							if (Ast.IsJSDocKind(current.Kind)) {
								return current;
							}
							throw 'did not expect ${current.Kind.String()} to have ${token.String()} in its trivia';
						}
						return sourceFile.GetOrCreateToken(token, tokenFullStart, tokenEnd, current, flags);
					}
					if (includePrecedingTokenAtEndPosition != null && tokenEnd == position) {
						final prevToken = sourceFile.GetOrCreateToken(token, tokenFullStart, tokenEnd, current, flags);
						if (includePrecedingTokenAtEndPosition(prevToken)) {
							return prevToken;
						}
					}
					left = tokenEnd;
					scanner.Scan();
				}
				return current;
			}
			current = next;
			left = current.Pos();
			nodeAfterLeft = null;
			next = null;
		}
	}

	static function getPosition(node:Node, sourceFile:SourceFile, allowPositionInLeadingTrivia:Bool):Int {
		if (allowPositionInLeadingTrivia) {
			return node.Pos();
		}
		return Scanner.GetTokenPosOfNode(node, sourceFile, true /*includeJSDoc*/);
	}

	static function findRightmostNode(node:Node):Node {
		var next:Node = null;
		var current = node;
		final visitNode = function(node:Node, _:NodeVisitor):Node {
			if (node != null) {
				next = node;
			}
			return node;
		};
		final visitNodes = function(nodeList:NodeList, visitor:NodeVisitor):NodeList {
			if (nodeList != null) {
				final rightmost = Ast.FindLastVisibleNode(nodeList.Nodes);
				if (rightmost != null) {
					next = rightmost;
				}
			}
			return nodeList;
		};
		final visitor = getNodeVisitor(visitNode, visitNodes);

		while (true) {
			current.VisitEachChild(visitor);
			if (next == null) {
				return current;
			}
			current = next;
			next = null;
		}
	}

	public static function VisitEachChildAndJSDoc(node:Node, sourceFile:SourceFile, visitNode:(Node, NodeVisitor) -> Node,
			visitNodes:(NodeList, NodeVisitor) -> NodeList):Void {
		final visitor = getNodeVisitor(visitNode, visitNodes);
		final jsdocs = node.JSDoc(sourceFile);
		if (jsdocs != null) {
			for (jsdoc in jsdocs) {
				if (visitor.Hooks.VisitNode != null) {
					visitor.Hooks.VisitNode(jsdoc, visitor);
				} else {
					visitor.VisitNode(jsdoc);
				}
			}
		}
		node.VisitEachChild(visitor);
	}

	// Go builtin min.
	static inline function min(a:Int, b:Int):Int {
		return a < b ? a : b;
	}

	static inline final comparisonLessThan = -1;
	static inline final comparisonEqualTo = 0;
	static inline final comparisonGreaterThan = 1;

	// Finds the leftmost token satisfying `position < token.End()`.
	// If the leftmost token satisfying `position < token.End()` is invalid, or if position
	// is in the trivia of that leftmost token,
	// we will find the rightmost valid token with `token.End() <= position`.
	public static function FindPrecedingToken(sourceFile:SourceFile, position:Int):Node {
		return FindPrecedingTokenEx(sourceFile, position, null, false);
	}

	public static function FindPrecedingTokenEx(sourceFile:SourceFile, position:Int, startNode:Node, excludeJSDoc:Bool):Node {
		function find(n:Node):Node {
			if (Ast.IsNonWhitespaceToken(n) && n.Kind != KindEndOfFile) {
				return n;
			}

			// `foundChild` is the leftmost node that contains the target position.
			// `prevChild` is the last visited child of the current node.
			var foundChild:Node = null, prevChild:Node = null;
			final visitNode = function(node:Node, _:NodeVisitor):Node {
				// skip synthesized nodes (that will exist now because of jsdoc handling)
				if (node == null || (node.Flags & NodeFlagsReparsed) != 0) {
					return node;
				}
				if (foundChild != null) { // We cannot abort visiting children, so once the desired child is found, we do nothing.
					return node;
				}
				if (position < node.End() && (prevChild == null || prevChild.End() <= position)) {
					foundChild = node;
				} else {
					prevChild = node;
				}
				return node;
			};
			final visitNodes = function(nodeList:NodeList, _:NodeVisitor):NodeList {
				if (foundChild != null) {
					return nodeList;
				}
				if (nodeList != null && Core.len(nodeList.Nodes) > 0) {
					final nodes = nodeList.Nodes;
					final r = Core.BinarySearchUniqueFunc(nodes, function(middle:Int, _:Node):Int {
						// synthetic jsdoc nodes should have jsdocNode.End() <= n.Pos()
						if ((nodes[middle].Flags & NodeFlagsReparsed) != 0) {
							return comparisonLessThan;
						}
						if (position < nodes[middle].End()) {
							if (middle == 0 || position >= nodes[middle - 1].End()) {
								return comparisonEqualTo;
							}
							return comparisonGreaterThan;
						}
						return comparisonLessThan;
					});
					final index = r.value, match = r.ok;

					if (match) {
						foundChild = nodes[index];
					}

					final validLookupIndex = Core.IfElse(match, index - 1, nodes.length - 1);
					var i = validLookupIndex;
					while (i >= 0) {
						if ((nodes[i].Flags & NodeFlagsReparsed) != 0) {
							i--;
							continue;
						}
						if (prevChild == null) {
							prevChild = nodes[i];
						}
						i--;
					}
				}
				return nodeList;
			};
			VisitEachChildAndJSDoc(n, sourceFile, visitNode, visitNodes);

			if (foundChild != null) {
				// Note that the span of a node's tokens is [getStartOfNode(node, ...), node.end).
				// Given that `position < child.end` and child has constituent tokens, we distinguish these cases:
				// 1) `position` precedes `child`'s tokens or `child` has no tokens (ie: in a comment or whitespace preceding `child`):
				// we need to find the last token in a previous child node or child tokens.
				// 2) `position` is within the same span: we recurse on `child`.
				final start = GetStartOfNode(foundChild, sourceFile, !excludeJSDoc /*includeJSDoc*/);
				final lookInPreviousChild = start >= position || // cursor in the leading trivia or preceding tokens
					!isValidPrecedingNode(foundChild, sourceFile);
				if (lookInPreviousChild) {
					if (position >= foundChild.Pos()) {
						// Find jsdoc preceding the foundChild.
						var jsDoc:Node = null;
						final nodeJSDoc = n.JSDoc(sourceFile);
						var i = Core.len(nodeJSDoc) - 1;
						while (i >= 0) {
							if (nodeJSDoc[i].Pos() >= foundChild.Pos()) {
								jsDoc = nodeJSDoc[i];
								break;
							}
							i--;
						}
						if (jsDoc != null) {
							if (!excludeJSDoc && position < jsDoc.End()) {
								return find(jsDoc);
							} else {
								return findRightmostValidToken(jsDoc.End(), sourceFile, n, position, excludeJSDoc);
							}
						}
						return findRightmostValidToken(foundChild.Pos(), sourceFile, n, -1 /*position*/, excludeJSDoc);
					} else { // Answer is in tokens between two visited children.
						return findRightmostValidToken(foundChild.Pos(), sourceFile, n, position, excludeJSDoc);
					}
				} else {
					// position is in [foundChild.getStart(), foundChild.End): recur.
					return find(foundChild);
				}
			}

			// We have two cases here: either the position is at the end of the file,
			// or the desired token is in the unvisited trailing tokens of the current node.
			if (position >= n.End()) {
				return findRightmostValidToken(n.End(), sourceFile, n, -1 /*position*/, excludeJSDoc);
			} else {
				return findRightmostValidToken(n.End(), sourceFile, n, position, excludeJSDoc);
			}
		}

		var node:Node = null;
		if (startNode != null) {
			node = startNode;
		} else {
			node = sourceFile.AsNode();
		}
		final result = find(node);
		if (result != null && Ast.IsWhitespaceOnlyJsxText(result)) {
			throw "Expected result to be a non-whitespace token.";
		}
		return result;
	}

	static function isValidPrecedingNode(node:Node, sourceFile:SourceFile):Bool {
		if (node.Kind == KindEndOfFile) {
			return Core.len(node.JSDoc(sourceFile)) > 0;
		}
		final start = GetStartOfNode(node, sourceFile, false /*includeJSDoc*/);
		final width = node.End() - start;
		return !(Ast.IsWhitespaceOnlyJsxText(node) || width == 0);
	}

	public static function GetStartOfNode(node:Node, file:SourceFile, includeJSDoc:Bool):Int {
		return Scanner.GetTokenPosOfNode(node, file, includeJSDoc);
	}

	// Looks for rightmost valid token in the range [startPos, endPos).
	// If position is >= 0, looks for rightmost valid token that precedes or touches that position.
	static function findRightmostValidToken(endPos:Int, sourceFile:SourceFile, containingNode:Node, position:Int, excludeJSDoc:Bool):Node {
		if (position == -1) {
			position = containingNode.End();
		}
		function find(n:Node, endPos:Int):Node {
			if (n == null) {
				return null;
			}
			if (Ast.IsNonWhitespaceToken(n)) {
				return n;
			}

			var rightmostValidNode:Node = null;
			final rightmostVisitedNodes:Array<Node> = []; // Nodes after the last valid node.
			var hasChildren = false;
			final shouldVisitNode = function(node:Node):Bool {
				// Node is synthetic or out of the desired range: don't visit it.
				return !((node.Flags & NodeFlagsReparsed) != 0
					|| node.End() > endPos
					|| GetStartOfNode(node, sourceFile, !excludeJSDoc /*includeJSDoc*/) >= position);
			};
			final visitNode = function(node:Node, _:NodeVisitor):Node {
				if (node == null || (node.Flags & NodeFlagsReparsed) != 0) {
					return node;
				}
				hasChildren = true;
				if (!shouldVisitNode(node)) {
					return node;
				}
				rightmostVisitedNodes.push(node);
				if (isValidPrecedingNode(node, sourceFile)) {
					rightmostValidNode = node;
					rightmostVisitedNodes.resize(0);
				}
				return node;
			};
			final visitNodes = function(nodeList:NodeList, _:NodeVisitor):NodeList {
				if (nodeList != null && Core.len(nodeList.Nodes) > 0) {
					hasChildren = true;
					final index = Core.BinarySearchUniqueFunc(nodeList.Nodes, function(middle:Int, node:Node):Int {
						if (node.End() > endPos) {
							return comparisonGreaterThan;
						}
						return comparisonLessThan;
					}).value;
					var validIndex = -1;
					var i = index - 1;
					while (i >= 0) {
						if (!shouldVisitNode(nodeList.Nodes[i])) {
							i--;
							continue;
						}
						if (isValidPrecedingNode(nodeList.Nodes[i], sourceFile)) {
							validIndex = i;
							rightmostValidNode = nodeList.Nodes[i];
							break;
						}
						i--;
					}
					for (i in validIndex + 1...index) {
						if (!shouldVisitNode(nodeList.Nodes[i])) {
							continue;
						}
						rightmostVisitedNodes.push(nodeList.Nodes[i]);
					}
				}
				return nodeList;
			};
			VisitEachChildAndJSDoc(n, sourceFile, visitNode, visitNodes);

			// Three cases:
			// 1. The answer is a token of `rightmostValidNode`.
			// 2. The answer is one of the unvisited tokens that occur after the rightmost valid node.
			// 3. The current node is a childless, token-less node. The answer is the current node.

			// Case 2: Look at unvisited trailing tokens that occur in between the rightmost visited nodes.
			if (!shouldSkipChild(n)) { // JSDoc nodes don't include trivia tokens as children.
				var startPos:Int;
				if (rightmostValidNode != null) {
					startPos = rightmostValidNode.End();
				} else {
					startPos = n.Pos();
				}
				final scanner = Scanner.GetScannerForSourceFile(sourceFile, startPos);
				final tokens:Array<Node> = [];
				for (visitedNode in rightmostVisitedNodes) {
					// Trailing tokens that occur before this node.
					while (startPos < min(visitedNode.Pos(), position)) {
						final token = scanNavigationToken(scanner, n);
						final tokenStart = scanner.TokenStart();
						if (tokenStart >= position) {
							break;
						}
						final tokenFullStart = scanner.TokenFullStart();
						final tokenEnd = scanner.TokenEnd();
						startPos = tokenEnd;
						final flags = scanner.TokenFlags();
						tokens.push(sourceFile.GetOrCreateToken(token, tokenFullStart, tokenEnd, n, flags));
						scanner.Scan();
					}
					startPos = visitedNode.End();
					scanner.ResetPos(startPos);
					scanner.Scan();
				}
				// Trailing tokens after last visited node.
				while (startPos < min(endPos, position)) {
					final token = scanNavigationToken(scanner, n);
					final tokenStart = scanner.TokenStart();
					if (tokenStart >= position) {
						break;
					}
					final tokenFullStart = scanner.TokenFullStart();
					final tokenEnd = scanner.TokenEnd();
					startPos = tokenEnd;
					final flags = scanner.TokenFlags();
					tokens.push(sourceFile.GetOrCreateToken(token, tokenFullStart, tokenEnd, n, flags));
					scanner.Scan();
				}

				final lastToken = tokens.length - 1;
				// Find preceding valid token.
				var i = lastToken;
				while (i >= 0) {
					if (!Ast.IsWhitespaceOnlyJsxText(tokens[i])) {
						return tokens[i];
					}
					i--;
				}
			}

			// Case 3: childless node.
			if (!hasChildren) {
				if (n != containingNode) {
					return n;
				}
				return null;
			}
			// Case 1: recur on rightmostValidNode.
			if (rightmostValidNode != null) {
				endPos = rightmostValidNode.End();
			}
			return find(rightmostValidNode, endPos);
		}

		return find(containingNode, endPos);
	}

	public static function FindNextToken(previousToken:Node, parent:Node, file:SourceFile):Node {
		function find(n:Node):Node {
			if (Ast.IsTokenKind(n.Kind) && n.Pos() == previousToken.End()) {
				// this is token that starts at the end of previous token - return it
				return n;
			}
			// Node that contains `previousToken` or occurs immediately after it.
			var foundNode:Node = null;
			final visitNode = function(node:Node, _:NodeVisitor):Node {
				if (node != null && (node.Flags & NodeFlagsReparsed) == 0 && node.Pos() <= previousToken.End()
					&& node.End() > previousToken.End()) {
					foundNode = node;
				}
				return node;
			};
			final visitNodes = function(nodeList:NodeList, _:NodeVisitor):NodeList {
				if (nodeList != null && Core.len(nodeList.Nodes) > 0 && foundNode == null) {
					final nodes = nodeList.Nodes;
					final r = Core.BinarySearchUniqueFunc(nodes, function(_:Int, node:Node):Int {
						if ((node.Flags & NodeFlagsReparsed) != 0) {
							return comparisonLessThan;
						}
						if (node.Pos() > previousToken.End()) {
							return comparisonGreaterThan;
						}
						if (node.End() <= previousToken.Pos()) {
							return comparisonLessThan;
						}
						return comparisonEqualTo;
					});
					if (r.ok) {
						foundNode = nodes[r.value];
					}
				}
				return nodeList;
			};
			VisitEachChildAndJSDoc(n, file, visitNode, visitNodes);
			// Cases:
			// 1. no answer exists
			// 2. answer is an unvisited token
			// 3. answer is in the visited found node

			// Case 3: look for the next token inside the found node.
			if (foundNode != null) {
				return find(foundNode);
			}
			final startPos = previousToken.End();
			// Case 2: look for the next token directly.
			if (startPos >= n.Pos() && startPos < n.End()) {
				final scanner = Scanner.GetScannerForSourceFile(file, startPos);
				final token = scanner.Token();
				final tokenFullStart = scanner.TokenFullStart();
				final tokenEnd = scanner.TokenEnd();
				final flags = scanner.TokenFlags();
				// Use tokenFullStart (which includes leading trivia) to match TS's
				// findNextToken behavior where `n.pos === previousToken.end` is checked
				// (TS's pos includes trivia, same as Go's Pos()/tokenFullStart).
				if (tokenFullStart == previousToken.End()) {
					return file.GetOrCreateToken(token, tokenFullStart, tokenEnd, n, flags);
				}
				throw 'Expected to find next token at ${previousToken.End()}, got token ${token.String()} at ${tokenFullStart}';
			}
			// Case 3: no answer.
			return null;
		}
		return find(parent);
	}

	static function getNodeVisitor(visitNode:(Node, NodeVisitor) -> Node, visitNodes:(NodeList, NodeVisitor) -> NodeList):NodeVisitor {
		var wrappedVisitNode:(Node, NodeVisitor) -> Node = null;
		var wrappedVisitNodes:(NodeList, NodeVisitor) -> NodeList = null;
		if (visitNode != null) {
			wrappedVisitNode = function(n:Node, v:NodeVisitor):Node {
				if (Ast.IsJSDocSingleCommentNodeComment(n)) {
					return n;
				}
				return visitNode(n, v);
			};
		}

		if (visitNodes != null) {
			wrappedVisitNodes = function(n:NodeList, v:NodeVisitor):NodeList {
				if (Ast.IsJSDocSingleCommentNodeList(n)) {
					return n;
				}
				return visitNodes(n, v);
			};
		}

		final hooks = new NodeVisitorHooks();
		hooks.VisitNode = wrappedVisitNode;
		hooks.VisitToken = wrappedVisitNode;
		hooks.VisitNodes = wrappedVisitNodes;
		hooks.VisitModifiers = function(modifiers:ModifierList, visitor:NodeVisitor):ModifierList {
			if (modifiers != null) {
				// PORT: `&modifiers.NodeList` is the ModifierList itself (ModifierList extends NodeList).
				wrappedVisitNodes(modifiers, visitor);
			}
			return modifiers;
		};
		return Ast.NewNodeVisitor(Core.Identity, null, hooks);
	}

	static function shouldSkipChild(node:Node):Bool {
		return node.Kind == KindJSDoc
			|| node.Kind == KindJSDocText
			|| node.Kind == KindJSDocTypeLiteral
			|| node.Kind == KindJSDocSignature
			|| Ast.IsJSDocLinkLike(node)
			|| Ast.IsJSDocTag(node);
	}

	// FindChildOfKind searches for a child node or token of the specified kind within a containing node.
	// This function scans through both AST nodes and intervening tokens to find the first match.
	public static function FindChildOfKind(containingNode:Node, kind:Kind, sourceFile:SourceFile):Node {
		var lastNodePos = containingNode.Pos();
		final scan = Scanner.GetScannerForSourceFile(sourceFile, lastNodePos);

		var foundChild:Node = null;
		final visitNode = function(node:Node):Bool {
			if (node == null || (node.Flags & NodeFlagsReparsed) != 0) {
				return false;
			}
			// Look for child in preceding tokens.
			var startPos = lastNodePos;
			while (startPos < node.Pos()) {
				final tokenKind = scan.Token();
				final tokenEnd = scan.TokenEnd();
				if (tokenKind == kind) {
					final tokenFullStart = scan.TokenFullStart();
					final flags = scan.TokenFlags();
					foundChild = sourceFile.GetOrCreateToken(tokenKind, tokenFullStart, tokenEnd, containingNode, flags);
					return true;
				}
				startPos = tokenEnd;
				scan.Scan();
			}

			if (node.Kind == kind) {
				foundChild = node;
				return true;
			}

			lastNodePos = node.End();
			scan.ResetPos(lastNodePos);
			return false;
		};

		Ast.ForEachChildAndJSDoc(containingNode, sourceFile, visitNode);

		if (foundChild != null) {
			return foundChild;
		}

		// Look for child in trailing tokens.
		var startPos = lastNodePos;
		while (startPos < containingNode.End()) {
			final tokenKind = scan.Token();
			final tokenEnd = scan.TokenEnd();
			if (tokenKind == kind) {
				final tokenFullStart = scan.TokenFullStart();
				final flags = scan.TokenFlags();
				final token = sourceFile.GetOrCreateToken(tokenKind, tokenFullStart, tokenEnd, containingNode, flags);
				return token;
			}
			startPos = tokenEnd;
			scan.Scan();
		}
		return null;
	}
}
