import ts.core.Core;
import ts.jsnum.Jsnum;
import ts.jsnum.PseudoBigInt;
import ts.ast.Ast;
import ts.ast.AstGenerated;
// PORT: no `import ts.ast.KindGenerated;`: with it, `Std.isOfType(v, String)` hangs Haxe 4.3.7 (measured).
// With `Kind.*`, `String` in an expression is Kind.String (stringer method); Evaluator.hx writes `std.String`.
import ts.ast.KindGenerated.Kind.*;
import ts.ast.Utilities;
import ts.ast.Utilities.OuterExpressionKinds.*;

using ts.jsnum.String_;
