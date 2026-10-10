package ts.printer;

import haxe.ds.IntMap;
import haxe.ds.ObjectMap;

// Port of emitcontext.go (types and methods; NewEmitContext, GetEmitContext, isHoistedVariable and
// nextAutoGenerateId are package statics in class Printer).

// Stores side-table information used during transformation that can be read by the printer to customize emit
//
// NOTE: EmitContext is not guaranteed to be thread-safe.
@:allow(ts.printer)
class EmitContext {
	public var Factory:NodeFactory = null; // Required. The NodeFactory to use to create new nodes
	var autoGenerate:ObjectMap<Node, AutoGenerateInfo> = null;
	var textSource:ObjectMap<Node, Node> = null;
	var original:ObjectMap<Node, Node> = null;
	var emitNodes:LinkStore<Node, EmitNode> = new LinkStore<Node, EmitNode>(fn_newEmitNode);
	var assignedName:ObjectMap<Node, Node> = null;
	var classThis:ObjectMap<Node, Node> = null;
	var varScopeStack:Stack<VarScope> = new Stack<VarScope>();
	var letScopeStack:Stack<VarScope> = new Stack<VarScope>();
	var emitHelpers:OrderedSet<EmitHelper> = new OrderedSet<EmitHelper>();

	static final fn_newEmitNode:() -> EmitNode = () -> new EmitNode();

	public function new() {}

	public function Reset():Void {
		// PORT: Go `*c = EmitContext{Factory: c.Factory}` → every field back to its zero value.
		autoGenerate = null;
		textSource = null;
		original = null;
		emitNodes = new LinkStore<Node, EmitNode>(fn_newEmitNode);
		assignedName = null;
		classThis = null;
		varScopeStack = new Stack<VarScope>();
		letScopeStack = new Stack<VarScope>();
		emitHelpers = new OrderedSet<EmitHelper>();
	}

	function onCreate(node:Node):Void {
		node.Flags |= NodeFlagsSynthesized;
	}

	function onUpdate(updated:Node, original:Node):Void {
		SetOriginal(updated, original);
	}

	function onClone(updated:Node, original:Node):Void {
		SetOriginal(updated, original);
		if (Ast.IsIdentifier(updated) || Ast.IsPrivateIdentifier(updated)) {
			final autoGenerate = this.autoGenerate == null ? null : this.autoGenerate.get(original);
			if (autoGenerate != null) {
				final autoGenerateCopy = autoGenerate.copy();
				this.autoGenerate.set(updated, autoGenerateCopy);
			}
		}
	}

	// Creates a new NodeVisitor attached to this EmitContext
	public function NewNodeVisitor(visit:(node:Node) -> Node):NodeVisitor {
		final hooks = new NodeVisitorHooks();
		hooks.VisitParameters = VisitParameters;
		hooks.VisitFunctionBody = VisitFunctionBody;
		hooks.VisitIterationBody = VisitIterationBody;
		hooks.VisitTopLevelStatements = VisitVariableEnvironment;
		hooks.VisitEmbeddedStatement = VisitEmbeddedStatement;
		return Ast.NewNodeVisitor(visit, Factory.AsNodeFactory(), hooks);
	}

	//
	// Environment tracking
	//

	// Starts a new VariableEnvironment used to track hoisted `var` statements and function declarations.
	//
	// see: https://tc39.es/ecma262/#table-additional-state-components-for-ecmascript-code-execution-contexts
	//
	// NOTE: This is the equivalent of `transformContext.startLexicalEnvironment` in Strada.
	public function StartVariableEnvironment():Void {
		varScopeStack.Push(new VarScope());
		StartLexicalEnvironment();
	}

	// Ends the current VariableEnvironment, returning a list of statements that should be emitted at the start of the current scope.
	//
	// NOTE: This is the equivalent of `transformContext.endLexicalEnvironment` in Strada.
	public function EndVariableEnvironment():Array<Statement> {
		final scope = varScopeStack.Pop();
		var statements:Array<Statement> = null;
		if (Core.len(scope.functions) > 0) {
			statements = scope.functions.copy();
		}
		if (Core.len(scope.variables) > 0) {
			final varDeclList = Factory.NewVariableDeclarationList(Factory.NewNodeList(scope.variables), NodeFlagsNone);
			final varStatement = Factory.NewVariableStatement(null /*modifiers*/, varDeclList);
			SetEmitFlags(varStatement, EFCustomPrologue);
			statements = append(statements, varStatement);
		}
		if (Core.len(scope.initializationStatements) > 0) {
			for (s in scope.initializationStatements) {
				statements = append(statements, s);
			}
		}
		final rest = EndLexicalEnvironment();
		if (rest != null) {
			for (s in rest) {
				statements = append(statements, s);
			}
		}
		return statements;
	}

	// PORT: Go `append` on a slice this function owns (nil → new array).
	static inline function append(s:Array<Statement>, x:Statement):Array<Statement> {
		if (s == null) {
			return [x];
		}
		s.push(x);
		return s;
	}

	// Invokes c.EndVariableEnvironment() and merges the results into `statements`
	public function EndAndMergeVariableEnvironmentList(statements:StatementList):StatementList {
		var nodes:Array<Statement> = null;
		if (statements != null) {
			nodes = statements.Nodes;
		}

		final r = endAndMergeVariableEnvironment(nodes);
		if (r.b) {
			final list = Factory.NewNodeList(r.a);
			list.Loc = statements.Loc;
			return list;
		}

		return statements;
	}

	// Invokes c.EndVariableEnvironment() and merges the results into `statements`
	public function EndAndMergeVariableEnvironment(statements:Array<Statement>):Array<Statement> {
		return endAndMergeVariableEnvironment(statements).a;
	}

	function endAndMergeVariableEnvironment(statements:Array<Statement>):Pair<Array<Statement>, Bool> {
		return mergeEnvironment(statements, EndVariableEnvironment());
	}

	// Adds a `var` declaration to the current VariableEnvironment
	//
	// NOTE: This is the equivalent of `transformContext.hoistVariableDeclaration` in Strada.
	public function AddVariableDeclaration(name:IdentifierNode):Void {
		final varDecl = Factory.NewVariableDeclaration(name, null /*exclamationToken*/, null /*typeNode*/, null /*initializer*/);
		SetEmitFlags(varDecl, EFNoNestedSourceMaps);
		final scope = varScopeStack.Peek();
		scope.variables = Printer.appendNode(scope.variables, varDecl);
		if (scope.flags & environmentFlagsInParameters != 0) {
			scope.flags |= environmentFlagsVariablesHoistedInParameters;
		}
	}

	// Adds a hoisted function declaration to the current VariableEnvironment
	//
	// NOTE: This is the equivalent of `transformContext.hoistFunctionDeclaration` in Strada.
	public function AddHoistedFunctionDeclaration(node:FunctionDeclarationNode):Void {
		SetEmitFlags(node, EFCustomPrologue);
		final scope = varScopeStack.Peek();
		scope.functions = Printer.appendNode(scope.functions, node);
	}

	// Starts a new LexicalEnvironment used to track block-scoped `let`, `const`, and `using` declarations.
	//
	// see: https://tc39.es/ecma262/#table-additional-state-components-for-ecmascript-code-execution-contexts
	//
	// NOTE: This is the equivalent of `transformContext.startBlockScope` in Strada.
	// NOTE: This is *not* the same as `startLexicalEnvironment` in Strada as that method is incorrectly named.
	public function StartLexicalEnvironment():Void {
		letScopeStack.Push(new VarScope());
	}

	// Ends the current EndLexicalEnvironment, returning a list of statements that should be emitted at the start of the current scope.
	//
	// NOTE: This is the equivalent of `transformContext.endLexicalEnvironment` in Strada.
	// NOTE: This is *not* the same as `endLexicalEnvironment` in Strada as that method is incorrectly named.
	public function EndLexicalEnvironment():Array<Statement> {
		final scope = letScopeStack.Pop();
		var statements:Array<Statement> = null;
		if (Core.len(scope.variables) > 0) {
			final varDeclList = Factory.NewVariableDeclarationList(Factory.NewNodeList(scope.variables), NodeFlagsLet);
			final varStatement = Factory.NewVariableStatement(null /*modifiers*/, varDeclList);
			SetEmitFlags(varStatement, EFCustomPrologue);
			statements = append(statements, varStatement);
		}
		return statements;
	}

	// Invokes c.EndLexicalEnvironment() and merges the results into `statements`
	public function EndAndMergeLexicalEnvironmentList(statements:StatementList):StatementList {
		var nodes:Array<Statement> = null;
		if (statements != null) {
			nodes = statements.Nodes;
		}

		final r = endAndMergeLexicalEnvironment(nodes);
		if (r.b) {
			final list = Factory.NewNodeList(r.a);
			list.Loc = statements.Loc;
			return list;
		}

		return statements;
	}

	// Invokes c.EndLexicalEnvironment() and merges the results into `statements`
	public function EndAndMergeLexicalEnvironment(statements:Array<Statement>):Array<Statement> {
		return endAndMergeLexicalEnvironment(statements).a;
	}

	// Invokes c.EndLexicalEnvironment() and merges the results into `statements`
	function endAndMergeLexicalEnvironment(statements:Array<Statement>):Pair<Array<Statement>, Bool> {
		return mergeEnvironment(statements, EndLexicalEnvironment());
	}

	// Adds a `let` declaration to the current LexicalEnvironment.
	public function AddLexicalDeclaration(name:IdentifierNode):Void {
		final varDecl = Factory.NewVariableDeclaration(name, null /*exclamationToken*/, null /*typeNode*/, null /*initializer*/);
		SetEmitFlags(varDecl, EFNoNestedSourceMaps);
		final scope = letScopeStack.Peek();
		scope.variables = Printer.appendNode(scope.variables, varDecl);
	}

	// Merges declarations produced by c.EndVariableEnvironment() or c.EndLexicalEnvironment() into a statement list
	public function MergeEnvironmentList(statements:StatementList, declarations:Array<Statement>):StatementList {
		final r = mergeEnvironment(statements.Nodes, declarations);
		if (r.b) {
			final list = Factory.NewNodeList(r.a);
			list.Loc = statements.Loc;
			return list;
		}
		return statements;
	}

	// Merges declarations produced by c.EndVariableEnvironment() or c.EndLexicalEnvironment() into a slice of statements
	public function MergeEnvironment(statements:Array<Statement>, declarations:Array<Statement>):Array<Statement> {
		return mergeEnvironment(statements, declarations).a;
	}

	// PORT: Go returns ([]*ast.Statement, bool) → Pair (a = statements, b = changed).
	function mergeEnvironment(statements:Array<Statement>, declarations:Array<Statement>):Pair<Array<Statement>, Bool> {
		if (Core.len(declarations) == 0) {
			return new Pair(statements, false);
		}

		// When we merge new lexical statements into an existing statement list, we merge them in the following manner:
		//
		// Given:
		//
		// | Left                               | Right                               |
		// |------------------------------------|-------------------------------------|
		// | [standard prologues (left)]        | [standard prologues (right)]        |
		// | [hoisted functions (left)]         | [hoisted functions (right)]         |
		// | [hoisted variables (left)]         | [hoisted variables (right)]         |
		// | [lexical init statements (left)]   | [lexical init statements (right)]   |
		// | [other statements (left)]          |                                     |
		//
		// The resulting statement list will be:
		//
		// | Result                              |
		// |-------------------------------------|
		// | [standard prologues (right)]        |
		// | [standard prologues (left)]         |
		// | [hoisted functions (right)]         |
		// | [hoisted functions (left)]          |
		// | [hoisted variables (right)]         |
		// | [hoisted variables (left)]          |
		// | [lexical init statements (right)]   |
		// | [lexical init statements (left)]    |
		// | [other statements (left)]           |
		//
		// NOTE: It is expected that new lexical init statements must be evaluated before existing lexical init statements,
		// as the prior transformation may depend on the evaluation of the lexical init statements to be in the correct state.

		var changed = false;

		// find standard prologues on left in the following order: standard directives, hoisted functions, hoisted variables, other custom
		final leftStandardPrologueEnd = Printer.findSpanEnd(statements, fn_IsPrologueDirective, 0);
		final leftHoistedFunctionsEnd = Printer.findSpanEndWithEmitContext(this, statements, fn_isHoistedFunction, leftStandardPrologueEnd);
		final leftHoistedVariablesEnd = Printer.findSpanEndWithEmitContext(this, statements, fn_isHoistedVariableStatement, leftHoistedFunctionsEnd);

		// find standard prologues on right in the following order: standard directives, hoisted functions, hoisted variables, other custom
		final rightStandardPrologueEnd = Printer.findSpanEnd(declarations, fn_IsPrologueDirective, 0);
		final rightHoistedFunctionsEnd = Printer.findSpanEndWithEmitContext(this, declarations, fn_isHoistedFunction, rightStandardPrologueEnd);
		final rightHoistedVariablesEnd = Printer.findSpanEndWithEmitContext(this, declarations, fn_isHoistedVariableStatement, rightHoistedFunctionsEnd);
		final rightCustomPrologueEnd = Printer.findSpanEndWithEmitContext(this, declarations, fn_isCustomPrologue, rightHoistedVariablesEnd);
		if (rightCustomPrologueEnd != declarations.length) {
			throw "Expected declarations to be valid standard or custom prologues";
		}

		var left = statements;

		// splice other custom prologues from right into left
		if (rightCustomPrologueEnd > rightHoistedVariablesEnd) {
			left = Core.Splice(left, leftHoistedVariablesEnd, 0, ...declarations.slice(rightHoistedVariablesEnd, rightCustomPrologueEnd));
			changed = true;
		}

		// splice hoisted variables from right into left
		if (rightHoistedVariablesEnd > rightHoistedFunctionsEnd) {
			left = Core.Splice(left, leftHoistedFunctionsEnd, 0, ...declarations.slice(rightHoistedFunctionsEnd, rightHoistedVariablesEnd));
			changed = true;
		}

		// splice hoisted functions from right into left
		if (rightHoistedFunctionsEnd > rightStandardPrologueEnd) {
			left = Core.Splice(left, leftStandardPrologueEnd, 0, ...declarations.slice(rightStandardPrologueEnd, rightHoistedFunctionsEnd));
			changed = true;
		}

		// splice standard prologues from right into left (that are not already in left)
		if (rightStandardPrologueEnd > 0) {
			if (leftStandardPrologueEnd == 0) {
				left = Core.Splice(left, 0, 0, ...declarations.slice(0, rightStandardPrologueEnd));
				changed = true;
			} else {
				final leftPrologues = new Set<std.String>();
				for (i in 0...leftStandardPrologueEnd) {
					final leftPrologue = statements[i];
					leftPrologues.Add(leftPrologue.Expression().Text());
				}
				var i = rightStandardPrologueEnd - 1;
				while (i >= 0) {
					final rightPrologue = declarations[i];
					if (!leftPrologues.Has(rightPrologue.Expression().Text())) {
						left = Core.Concatenate([rightPrologue], left);
						changed = true;
					}
					i--;
				}
			}
		}

		return new Pair(left, changed);
	}

	// PORT: Go method expressions `(*EmitContext).isX` / `ast.IsPrologueDirective` → function values created once.
	static final fn_IsPrologueDirective:(node:Node) -> Bool = node -> Ast.IsPrologueDirective(node);
	static final fn_isCustomPrologue:(c:EmitContext, node:Node) -> Bool = (c, node) -> c.isCustomPrologue(node);
	static final fn_isHoistedFunction:(c:EmitContext, node:Node) -> Bool = (c, node) -> c.isHoistedFunction(node);
	static final fn_isHoistedVariableStatement:(c:EmitContext, node:Node) -> Bool = (c, node) -> c.isHoistedVariableStatement(node);
	static final fn_isHoistedVariable:(node:Node) -> Bool = node -> Printer.isHoistedVariable(node);

	function isCustomPrologue(node:Statement):Bool {
		return EmitFlags(node) & EFCustomPrologue != 0;
	}

	function isHoistedFunction(node:Statement):Bool {
		return isCustomPrologue(node) && Ast.IsFunctionDeclaration(node);
	}

	function isHoistedVariableStatement(node:Statement):Bool {
		return isCustomPrologue(node)
			&& Ast.IsVariableStatement(node)
			&& Core.Every(node.AsVariableStatement().DeclarationList.AsVariableDeclarationList().Declarations.Nodes, fn_isHoistedVariable);
	}

	//
	// Name Generation
	//

	// Gets whether a given name has an associated AutoGenerateInfo entry.
	public function HasAutoGenerateInfo(node:MemberName):Bool {
		if (node != null) {
			return autoGenerate != null && autoGenerate.exists(node);
		}
		return false;
	}

	// Gets the associated AutoGenerateInfo entry for a given name.
	public function GetAutoGenerateInfo(name:MemberName):AutoGenerateInfo {
		if (name == null) {
			return null;
		}
		return autoGenerate == null ? null : autoGenerate.get(name);
	}

	// Walks the associated AutoGenerateInfo entries of a name to find the root Nopde from which the name should be generated.
	public function GetNodeForGeneratedName(name:MemberName):Node {
		final autoGenerate = this.autoGenerate == null ? null : this.autoGenerate.get(name);
		if (autoGenerate != null && autoGenerate.Flags.IsNode()) {
			return getNodeForGeneratedNameWorker(autoGenerate.Node, autoGenerate.Id);
		}
		return name;
	}

	function getNodeForGeneratedNameWorker(node:Node, autoGenerateId:AutoGenerateId):Node {
		var original = Original(node);
		while (original != null) {
			node = original;
			if (Ast.IsMemberName(node)) {
				// if "node" is a different generated name (having a different "autoGenerateId"), use it and stop traversing.
				final autoGenerate = this.autoGenerate == null ? null : this.autoGenerate.get(node);
				if (autoGenerate == null || autoGenerate.Flags.IsNode() && autoGenerate.Id != autoGenerateId) {
					break;
				}
				if (autoGenerate.Flags.IsNode()) {
					original = autoGenerate.Node;
					continue;
				}
			}
			original = Original(node);
		}
		return node;
	}

	//
	// Original Node Tracking
	//

	// Sets the original node for a given node.
	//
	// NOTE: This is the equivalent to `setOriginalNode` in Strada.
	public function SetOriginal(node:Node, original:Node):Void {
		SetOriginalEx(node, original, false);
	}

	public function UnsetOriginal(node:Node):Void {
		if (original != null) {
			original.remove(node);
		}
	}

	public function SetOriginalEx(node:Node, original:Node, allowOverwrite:Bool):Void {
		if (original == null) {
			throw "Original cannot be nil.";
		}

		if (this.original == null) {
			this.original = new ObjectMap<Node, Node>();
		}

		final existing = this.original.get(node);
		final ok = existing != null || this.original.exists(node);
		if (!ok) {
			this.original.set(node, original);
			final emitNode = emitNodes.TryGet(original);
			if (emitNode != null) {
				emitNodes.Get(node).copyFrom(emitNode);
			}
		} else if (!allowOverwrite && existing != original) {
			throw "Original node already set.";
		} else if (allowOverwrite) {
			this.original.set(node, original);
		}
	}

	// Gets the original node for a given node.
	//
	// NOTE: This is the equivalent to reading `node.original` in Strada.
	public function Original(node:Node):Node {
		return original == null ? null : original.get(node);
	}

	// Gets the most original node associated with this node by walking Original pointers.
	//
	// NOTE: This method is analogous to `getOriginalNode` in the old compiler, but the name has changed to avoid accidental
	// conflation with `SetOriginal`/`Original`
	public function MostOriginal(node:Node):Node {
		if (node != null) {
			var original = Original(node);
			while (original != null) {
				node = original;
				original = Original(node);
			}
		}
		return node;
	}

	// Gets the original parse tree node for a given node.
	//
	// NOTE: This is the equivalent to `getParseTreeNode` in Strada.
	public function ParseNode(node:Node):Node {
		node = MostOriginal(node);
		if (node != null && Ast.IsParseTreeNode(node)) {
			return node;
		}
		return null;
	}

	public function EmitFlags(node:Node):EmitFlags {
		final emitNode = emitNodes.TryGet(node);
		if (emitNode != null) {
			return emitNode.emitFlags;
		}
		return EFNone;
	}

	public function SetEmitFlags(node:Node, flags:EmitFlags):Void {
		emitNodes.Get(node).emitFlags = flags;
	}

	public function AddEmitFlags(node:Node, flags:EmitFlags):Void {
		emitNodes.Get(node).emitFlags |= flags;
	}

	// Gets the range to use for a node when emitting comments.
	public function CommentRange(node:Node):TextRange {
		final emitNode = emitNodes.TryGet(node);
		if (emitNode != null && emitNode.flags & hasCommentRange != 0) {
			return emitNode.commentRange;
		}
		return node.Loc;
	}

	// Sets the range to use for a node when emitting comments.
	public function SetCommentRange(node:Node, loc:TextRange):Void {
		final emitNode = emitNodes.Get(node);
		emitNode.commentRange = loc;
		emitNode.flags |= hasCommentRange;
	}

	// Sets the range to use for a node when emitting comments.
	public function AssignCommentRange(to:Node, from:Node):Void {
		SetCommentRange(to, CommentRange(from));
	}

	// Gets the range to use for a node when emitting source maps.
	public function SourceMapRange(node:Node):TextRange {
		final emitNode = emitNodes.TryGet(node);
		if (emitNode != null && emitNode.flags & hasSourceMapRange != 0) {
			return emitNode.sourceMapRange;
		}
		return node.Loc;
	}

	// Sets the range to use for a node when emitting source maps.
	public function SetSourceMapRange(node:Node, loc:TextRange):Void {
		final emitNode = emitNodes.Get(node);
		emitNode.sourceMapRange = loc;
		emitNode.flags |= hasSourceMapRange;
	}

	// Sets the range to use for a node when emitting source maps.
	public function AssignSourceMapRange(to:Node, from:Node):Void {
		SetSourceMapRange(to, SourceMapRange(from));
	}

	// Sets the range to use for a node when emitting comments and source maps.
	public function AssignCommentAndSourceMapRanges(to:Node, from:Node):Void {
		final emitNode = emitNodes.Get(to);
		final commentRange = CommentRange(from);
		final sourceMapRange = SourceMapRange(from);
		emitNode.commentRange = commentRange;
		emitNode.sourceMapRange = sourceMapRange;
		emitNode.flags |= hasCommentRange | hasSourceMapRange;
	}

	// Gets the range for a token of a node when emitting source maps.
	// PORT: Go returns (core.TextRange, bool) → ValueOk.
	public function TokenSourceMapRange(node:Node, kind:Kind):ValueOk<TextRange> {
		final emitNode = emitNodes.TryGet(node);
		if (emitNode != null && emitNode.tokenSourceMapRanges != null) {
			if (emitNode.tokenSourceMapRanges.exists(kind)) {
				return new ValueOk(emitNode.tokenSourceMapRanges.get(kind), true);
			}
		}
		return new ValueOk(new TextRange(0, 0), false);
	}

	// Sets the range for a token of a node when emitting source maps.
	public function SetTokenSourceMapRange(node:Node, kind:Kind, loc:TextRange):Void {
		final emitNode = emitNodes.Get(node);
		if (emitNode.tokenSourceMapRanges == null) {
			emitNode.tokenSourceMapRanges = new IntMap<TextRange>();
		}
		emitNode.tokenSourceMapRanges.set(kind, loc);
	}

	public function AssignedName(node:Node):Expression {
		return assignedName == null ? null : assignedName.get(node);
	}

	public function TextSource(node:StringLiteralNode):Node {
		return textSource == null ? null : textSource.get(node);
	}

	public function SetAssignedName(node:Node, name:Expression):Void {
		if (assignedName == null) {
			assignedName = new ObjectMap<Node, Node>();
		}
		assignedName.set(node, name);
	}

	public function ClassThis(node:Node):Expression {
		return classThis == null ? null : classThis.get(node);
	}

	public function SetClassThis(node:Node, classThis:IdentifierNode):Void {
		if (this.classThis == null) {
			this.classThis = new ObjectMap<Node, Node>();
		}
		this.classThis.set(node, classThis);
	}

	public function RequestEmitHelper(helper:EmitHelper):Void {
		if (helper.Scoped) {
			throw "Cannot request a scoped emit helper";
		}
		if (helper.Dependencies != null) {
			for (h in helper.Dependencies) {
				RequestEmitHelper(h);
			}
		}
		emitHelpers.Add(helper);
	}

	public function ReadEmitHelpers():Array<EmitHelper> {
		// PORT: slices.Collect of an empty sequence is nil.
		var helpers:Array<EmitHelper> = null;
		for (h in emitHelpers.Values()) {
			if (helpers == null) {
				helpers = [];
			}
			helpers.push(h);
		}
		emitHelpers.Clear();
		return helpers;
	}

	public function AddEmitHelper(node:Node, ...helper:EmitHelper):Void {
		final emitNode = emitNodes.Get(node);
		for (h in helper) {
			emitNode.helpers = Core.AppendIfUnique(emitNode.helpers, h);
		}
	}

	public function MoveEmitHelpers(source:Node, target:Node, predicate:(helper:EmitHelper) -> Bool):Void {
		final sourceEmitNode = emitNodes.TryGet(source);
		if (sourceEmitNode == null) {
			return;
		}
		var sourceEmitHelpers = sourceEmitNode.helpers;
		if (Core.len(sourceEmitHelpers) == 0) {
			return;
		}

		final targetEmitNode = emitNodes.Get(target);
		var helpersRemoved = 0;
		for (i in 0...sourceEmitHelpers.length) {
			final helper = sourceEmitHelpers[i];
			if (predicate(helper)) {
				helpersRemoved++;
				targetEmitNode.helpers = Core.AppendIfUnique(targetEmitNode.helpers, helper);
			} else if (helpersRemoved > 0) {
				sourceEmitHelpers[i - helpersRemoved] = helper;
			}
		}

		if (helpersRemoved > 0) {
			// PORT: Go reslices `sourceEmitHelpers[:len-helpersRemoved]` (other slice headers keep their
			// length); here a truncated copy is stored, so other references keep the full array.
			sourceEmitHelpers = sourceEmitHelpers.slice(0, sourceEmitHelpers.length - helpersRemoved);
			sourceEmitNode.helpers = sourceEmitHelpers;
		}
	}

	public function GetEmitHelpers(node:Node):Array<EmitHelper> {
		final emitNode = emitNodes.TryGet(node);
		if (emitNode != null) {
			return emitNode.helpers;
		}
		return null;
	}

	public function GetExternalHelpersModuleName(node:SourceFile):IdentifierNode {
		final parseNode = ParseNode(node.AsNode());
		if (parseNode != null) {
			final emitNode = emitNodes.TryGet(parseNode);
			if (emitNode != null) {
				return emitNode.externalHelpersModuleName;
			}
		}
		return null;
	}

	public function SetExternalHelpersModuleName(node:SourceFile, name:IdentifierNode):Void {
		final parseNode = ParseNode(node.AsNode());
		if (parseNode == null) {
			throw "Node must be a parse tree node or have an Original pointer to a parse tree node.";
		}

		final emitNode = emitNodes.Get(parseNode);
		emitNode.externalHelpersModuleName = name;
	}

	public function HasRecordedExternalHelpers(node:SourceFile):Bool {
		final parseNode = ParseNode(node.AsNode());
		if (parseNode != null) {
			final emitNode = emitNodes.TryGet(parseNode);
			return emitNode != null && (emitNode.externalHelpersModuleName != null || emitNode.emitFlags & EFExternalHelpers != 0);
		}
		return false;
	}

	public function IsCallToHelper(firstSegment:Expression, helperName:std.String):Bool {
		return Ast.IsCallExpression(firstSegment)
			&& Ast.IsIdentifier(firstSegment.Expression())
			&& (EmitFlags(firstSegment.Expression()) & EFHelperName) != 0
			&& firstSegment.Expression().Text() == helperName;
	}

	//
	// Visitor Hooks
	//

	public function VisitVariableEnvironment(nodes:StatementList, visitor:NodeVisitor):StatementList {
		StartVariableEnvironment();
		return EndAndMergeVariableEnvironmentList(visitor.VisitNodes(nodes));
	}

	public function VisitParameters(nodes:ParameterList, visitor:NodeVisitor):ParameterList {
		StartVariableEnvironment();
		final scope = varScopeStack.Peek();
		final oldFlags = scope.flags;
		scope.flags |= environmentFlagsInParameters;
		nodes = visitor.VisitNodes(nodes);

		// As of ES2015, any runtime execution of that occurs in for a parameter (such as evaluating an
		// initializer or a binding pattern), occurs in its own lexical scope. As a result, any expression
		// that we might transform that introduces a temporary variable would fail as the temporary variable
		// exists in a different lexical scope. To address this, we move any binding patterns and initializers
		// in a parameter list to the body if we detect a variable being hoisted while visiting a parameter list
		// when the emit target is greater than ES2015. (Which is now all targets.)
		if (scope.flags & environmentFlagsVariablesHoistedInParameters != 0) {
			nodes = addDefaultValueAssignmentsIfNeeded(nodes);
		}
		scope.flags = oldFlags;
		// !!! c.suspendVariableEnvironment()
		return nodes;
	}

	function addDefaultValueAssignmentsIfNeeded(nodeList:ParameterList):ParameterList {
		if (nodeList == null) {
			return nodeList;
		}
		var result:Array<Node> = null;
		final nodes = nodeList.Nodes;
		if (nodes != null) {
			for (i in 0...nodes.length) {
				final parameter = nodes[i];
				final updated = addDefaultValueAssignmentIfNeeded(parameter.AsParameterDeclaration());
				if (updated != parameter) {
					if (result == null) {
						result = nodes.copy();
					}
					result[i] = updated;
				}
			}
		}
		if (result != null) {
			final res = Factory.NewNodeList(result);
			res.Loc = nodeList.Loc;
			return res;
		}
		return nodeList;
	}

	function addDefaultValueAssignmentIfNeeded(parameter:ParameterDeclaration):Node {
		// A rest parameter cannot have a binding pattern or an initializer,
		// so let's just ignore it.
		if (parameter.DotDotDotToken != null) {
			return parameter.AsNode();
		} else if (Ast.IsBindingPattern(parameter.AsNode().Name())) {
			return addDefaultValueAssignmentForBindingPattern(parameter);
		} else if (parameter.Initializer != null) {
			return addDefaultValueAssignmentForInitializer(parameter, parameter.AsNode().Name(), parameter.Initializer);
		}
		return parameter.AsNode();
	}

	function addDefaultValueAssignmentForBindingPattern(parameter:ParameterDeclaration):Node {
		var initNode:Node;
		if (parameter.Initializer != null) {
			initNode = Factory.NewConditionalExpression(Factory.NewStrictEqualityExpression(Factory.NewGeneratedNameForNode(parameter.AsNode()),
				Factory.NewVoidZeroExpression()),
				Factory.NewToken(KindQuestionToken), parameter.Initializer, Factory.NewToken(KindColonToken),
				Factory.NewGeneratedNameForNode(parameter.AsNode()));
		} else {
			initNode = Factory.NewGeneratedNameForNode(parameter.AsNode());
		}
		AddInitializationStatement(Factory.NewVariableStatement(null,
			Factory.NewVariableDeclarationList(Factory.NewNodeList([
				Factory.NewVariableDeclaration(parameter.AsNode().Name(), null, parameter.Type, initNode)
			]), NodeFlagsNone)));
		return Factory.UpdateParameterDeclaration(parameter, parameter.AsNode().Modifiers(), parameter.DotDotDotToken,
			Factory.NewGeneratedNameForNode(parameter.AsNode()), parameter.QuestionToken, parameter.Type, null);
	}

	function addDefaultValueAssignmentForInitializer(parameter:ParameterDeclaration, name:Node, initializer:Node):Node {
		AddEmitFlags(initializer, EFNoSourceMap | EFNoComments);
		final nameClone = name.Clone(Factory);
		AddEmitFlags(nameClone, EFNoSourceMap);
		final initAssignment = Factory.NewAssignmentExpression(nameClone, initializer);
		initAssignment.Loc = parameter.Loc;
		AddEmitFlags(initAssignment, EFNoComments);
		final initBlock = Factory.NewBlock(Factory.NewNodeList([Factory.NewExpressionStatement(initAssignment)]), false);
		initBlock.Loc = parameter.Loc;
		AddEmitFlags(initBlock, EFSingleLine | EFNoTrailingSourceMap | EFNoTokenSourceMaps | EFNoComments);
		AddInitializationStatement(Factory.NewIfStatement(Factory.NewTypeCheck(name.Clone(Factory), "undefined"), initBlock, null));
		return Factory.UpdateParameterDeclaration(parameter, parameter.AsNode().Modifiers(), parameter.DotDotDotToken, parameter.AsNode().Name(),
			parameter.QuestionToken, parameter.Type, null);
	}

	public function AddInitializationStatement(node:Node):Void {
		final scope = varScopeStack.Peek();
		if (scope == null) {
			throw "Tried to add an initialization statement without a surrounding variable scope";
		}
		AddEmitFlags(node, EFCustomPrologue);
		scope.initializationStatements = Printer.appendNode(scope.initializationStatements, node);
	}

	public function VisitFunctionBody(node:BlockOrExpression, visitor:NodeVisitor):BlockOrExpression {
		// !!! c.resumeVariableEnvironment()
		final updated = visitor.VisitNode(node);
		final declarations = EndVariableEnvironment();
		if (Core.len(declarations) == 0) {
			return updated;
		}

		if (updated == null) {
			return Factory.NewBlock(Factory.NewNodeList(declarations), true /*multiLine*/);
		}

		if (!Ast.IsBlock(updated)) {
			final statements = MergeEnvironment([Factory.NewReturnStatement(updated)], declarations);
			return Factory.NewBlock(Factory.NewNodeList(statements), false /*multiLine*/);
		}

		return Factory.UpdateBlock(updated.AsBlock(), MergeEnvironmentList(updated.StatementList(), declarations), updated.AsBlock().MultiLine);
	}

	public function VisitIterationBody(body:Statement, visitor:NodeVisitor):Statement {
		if (body == null) {
			return null;
		}

		StartLexicalEnvironment();
		final updated = VisitEmbeddedStatement(body, visitor);
		if (updated == null) {
			throw "Expected visitor to return a statement.";
		}

		var statements = EndLexicalEnvironment();
		if (Core.len(statements) > 0) {
			if (Ast.IsBlock(updated)) {
				final us = updated.Statements();
				if (us != null) {
					for (s in us) {
						statements.push(s);
					}
				}
				final statementsList = Factory.NewNodeList(statements);
				statementsList.Loc = updated.StatementList().Loc;
				return Factory.UpdateBlock(updated.AsBlock(), statementsList, updated.AsBlock().MultiLine);
			}
			statements.push(updated);
			return Factory.NewBlock(Factory.NewNodeList(statements), true /*multiLine*/);
		}

		return updated;
	}

	public function VisitEmbeddedStatement(node:Statement, visitor:NodeVisitor):Statement {
		if (node == null) {
			return null;
		}
		final embeddedStatement = visitor.VisitEmbeddedStatement(node);
		if (embeddedStatement == null || Ast.IsNotEmittedStatement(embeddedStatement)) {
			final emptyStatement = visitor.Factory.NewEmptyStatement();
			emptyStatement.Loc = node.Loc;
			SetOriginal(emptyStatement, node);
			AssignCommentRange(emptyStatement, node);
			return emptyStatement;
		}
		return embeddedStatement;
	}

	public function SetSyntheticLeadingComments(node:Node, comments:Array<SynthesizedComment>):Node {
		emitNodes.Get(node).leadingComments = comments;
		return node;
	}

	public function AddSyntheticLeadingComment(node:Node, kind:Kind, text:std.String, hasTrailingNewLine:Bool):Node {
		final c = new SynthesizedComment();
		c.Kind = kind;
		c.Loc = Core.NewTextRange(-1, -1);
		c.HasTrailingNewLine = hasTrailingNewLine;
		c.Text = text;
		final emitNode = emitNodes.Get(node);
		emitNode.leadingComments = appendComment(emitNode.leadingComments, c);
		return node;
	}

	// PORT: Go `append` (may share the backing array with the caller's slice) → a new array.
	static function appendComment(s:Array<SynthesizedComment>, c:SynthesizedComment):Array<SynthesizedComment> {
		final r = s == null ? [] : s.copy();
		r.push(c);
		return r;
	}

	public function GetSyntheticLeadingComments(node:Node):Array<SynthesizedComment> {
		if (emitNodes.Has(node)) {
			return emitNodes.Get(node).leadingComments;
		}
		return null;
	}

	public function SetSyntheticTrailingComments(node:Node, comments:Array<SynthesizedComment>):Node {
		emitNodes.Get(node).trailingComments = comments;
		return node;
	}

	public function AddSyntheticTrailingComment(node:Node, kind:Kind, text:std.String, hasTrailingNewLine:Bool):Node {
		final c = new SynthesizedComment();
		c.Kind = kind;
		c.Loc = Core.NewTextRange(-1, -1);
		c.HasTrailingNewLine = hasTrailingNewLine;
		c.Text = text;
		final emitNode = emitNodes.Get(node);
		emitNode.trailingComments = appendComment(emitNode.trailingComments, c);
		return node;
	}

	public function GetSyntheticTrailingComments(node:Node):Array<SynthesizedComment> {
		if (emitNodes.Has(node)) {
			return emitNodes.Get(node).trailingComments;
		}
		return null;
	}

	// SetTypeNode stores the original type node on a name node when the type is erased,
	// so the emitter can use the type's position for comment preservation.
	public function SetTypeNode(node:Node, typeNode:TypeNode):Void {
		emitNodes.Get(node).typeNode = typeNode;
	}

	// GetTypeNode gets the type node stored on a name node by the type eraser.
	public function GetTypeNode(node:Node):TypeNode {
		final emitNode = emitNodes.TryGet(node);
		if (emitNode != null) {
			return emitNode.typeNode;
		}
		return null;
	}

	public function NewNotEmittedStatement(node:Node):Statement {
		final statement = Factory.NewNotEmittedStatement();
		statement.Loc = node.Loc;
		SetOriginal(statement, node);
		AssignCommentRange(statement, node);
		return statement;
	}
}

// PORT: unexported Go type `environmentFlags` → EnvironmentFlags (PORTING.md §1).
enum abstract EnvironmentFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:EnvironmentFlags, b:EnvironmentFlags):EnvironmentFlags;
	@:op(A & B) static function and(a:EnvironmentFlags, b:EnvironmentFlags):EnvironmentFlags;

	var environmentFlagsNone = 0;
	var environmentFlagsInParameters = 1 << 0; // currently visiting a parameter list
	var environmentFlagsVariablesHoistedInParameters = 1 << 1; // a temp variable was hoisted while visiting a parameter list
}

// PORT: unexported Go type `varScope` → VarScope (PORTING.md §1).
class VarScope {
	public var variables:Array<VariableDeclarationNode> = null;
	public var functions:Array<FunctionDeclarationNode> = null;
	public var flags:EnvironmentFlags = environmentFlagsNone;
	public var initializationStatements:Array<Node> = null;

	public function new() {}
}

class AutoGenerateOptions {
	public var Flags:GeneratedIdentifierFlags = GeneratedIdentifierFlagsNone;
	public var Prefix:std.String = "";
	public var Suffix:std.String = "";

	public function new(Flags:GeneratedIdentifierFlags = GeneratedIdentifierFlagsNone, Prefix:std.String = "", Suffix:std.String = "") {
		this.Flags = Flags;
		this.Prefix = Prefix;
		this.Suffix = Suffix;
	}

	public function copy():AutoGenerateOptions {
		return new AutoGenerateOptions(Flags, Prefix, Suffix);
	}
}

typedef AutoGenerateId = Int;

class AutoGenerateInfo {
	public var Flags:GeneratedIdentifierFlags = GeneratedIdentifierFlagsNone; // Specifies whether to auto-generate the text for an identifier.
	public var Id:AutoGenerateId = 0; // Ensures unique generated identifiers get unique names, but clones get the same name.
	public var Prefix:std.String = ""; // Optional prefix to apply to the start of the generated name
	public var Suffix:std.String = ""; // Optional suffix to apply to the end of the generated name
	public var Node:Node = null; // For a GeneratedIdentifierFlagsNode, the node from which to generate an identifier

	public function new() {}

	public function copy():AutoGenerateInfo {
		final r = new AutoGenerateInfo();
		r.Flags = Flags;
		r.Id = Id;
		r.Prefix = Prefix;
		r.Suffix = Suffix;
		r.Node = Node;
		return r;
	}
}

//
// Emit-related Data
//

// PORT: unexported Go type `emitNodeFlags` → EmitNodeFlags (PORTING.md §1).
enum abstract EmitNodeFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:EmitNodeFlags, b:EmitNodeFlags):EmitNodeFlags;
	@:op(A & B) static function and(a:EmitNodeFlags, b:EmitNodeFlags):EmitNodeFlags;

	var hasCommentRange = 1 << 0;
	var hasSourceMapRange = 1 << 1;
}

class SynthesizedComment {
	public var Kind:Kind = KindUnknown;
	public var Loc:TextRange = new TextRange(0, 0);
	public var HasLeadingNewLine:Bool = false;
	public var HasTrailingNewLine:Bool = false;
	public var Text:std.String = "";

	public function new() {}
}

// PORT: unexported Go type `emitNode` → EmitNode (PORTING.md §1).
class EmitNode {
	public var flags:EmitNodeFlags = 0;
	public var emitFlags:EmitFlags = EFNone;
	public var commentRange:TextRange = new TextRange(0, 0);
	public var sourceMapRange:TextRange = new TextRange(0, 0);
	public var tokenSourceMapRanges:IntMap<TextRange> = null;
	public var helpers:Array<EmitHelper> = null;
	public var externalHelpersModuleName:IdentifierNode = null;
	public var leadingComments:Array<SynthesizedComment> = null;
	public var trailingComments:Array<SynthesizedComment> = null;
	public var typeNode:TypeNode = null;

	public function new() {}

	// NOTE: This method is not guaranteed to be thread-safe
	public function copyFrom(source:EmitNode):Void {
		flags = source.flags;
		emitFlags = source.emitFlags;
		commentRange = source.commentRange;
		sourceMapRange = source.sourceMapRange;
		tokenSourceMapRanges = source.tokenSourceMapRanges == null ? null : source.tokenSourceMapRanges.copy();
		helpers = source.helpers == null ? null : source.helpers.copy();
		externalHelpersModuleName = source.externalHelpersModuleName;
	}
}
