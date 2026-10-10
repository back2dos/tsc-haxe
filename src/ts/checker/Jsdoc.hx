package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/jsdoc.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Methods of jsdoc.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class Jsdoc {

	static function checkUnmatchedJSDocParameters(c:Checker, node:Node):Void {
		var jsdocParameters:Array<Node> = null;
		final tags = Checker.getAllJSDocTags(node);
		if (tags != null) {
			for (tag in tags) {
				if (tag.Kind == KindJSDocParameterTag) {
					final name = tag.AsJSDocParameterOrPropertyTag().Name();
					if (Ast.IsIdentifier(name) && name.Text().length == 0) {
						continue;
					}
					if (jsdocParameters == null) {
						jsdocParameters = [];
					}
					jsdocParameters.push(tag);
				}
			}
		}

		if (Core.len(jsdocParameters) == 0) {
			return;
		}

		final isJs = Ast.IsInJSFile(node);
		final parameters = new Set<std.String>();
		final excludedParameters = new Set<Int>();

		final params = node.Parameters();
		for (i in 0...Core.len(params)) {
			final name = params[i].AsParameterDeclaration().Name();
			if (Ast.IsIdentifier(name)) {
				parameters.Add(name.Text());
			}
			if (Ast.IsBindingPattern(name)) {
				excludedParameters.Add(i);
			}
		}
		if (c.containsArgumentsReference(node)) {
			if (isJs) {
				final lastJSDocParamIndex = jsdocParameters.length - 1;
				final lastJSDocParam = jsdocParameters[lastJSDocParamIndex].AsJSDocParameterOrPropertyTag();
				if (lastJSDocParam == null || !Ast.IsIdentifier(lastJSDocParam.Name())) {
					return;
				}
				if (excludedParameters.Has(lastJSDocParamIndex) || parameters.Has(lastJSDocParam.Name().Text())) {
					return;
				}
				if (lastJSDocParam.TypeExpression == null || lastJSDocParam.TypeExpression.Type() == null) {
					return;
				}
				if (c.isArrayType(c.getTypeFromTypeNode(lastJSDocParam.TypeExpression.Type()))) {
					return;
				}
				c.error(lastJSDocParam.Name(),
					Diagnostics.JSDoc_param_tag_has_name_0_but_there_is_no_parameter_with_that_name_It_would_match_arguments_if_it_had_an_array_type,
					lastJSDocParam.Name().Text());
			}
		} else {
			for (index in 0...jsdocParameters.length) {
				final tag = jsdocParameters[index];
				final name = tag.AsJSDocParameterOrPropertyTag().Name();
				final isNameFirst = tag.AsJSDocParameterOrPropertyTag().IsNameFirst;

				if (excludedParameters.Has(index) || (Ast.IsIdentifier(name) && parameters.Has(name.Text()))) {
					continue;
				}

				if (Ast.IsQualifiedName(name)) {
					if (isJs) {
						c.error(name, Diagnostics.Qualified_name_0_is_not_allowed_without_a_leading_param_object_1, Checker.entityNameToString(name),
							Checker.entityNameToString(name.AsQualifiedName().Left));
					}
				} else {
					if (!isNameFirst) {
						c.errorOrSuggestion(isJs, name, Diagnostics.JSDoc_param_tag_has_name_0_but_there_is_no_parameter_with_that_name, name.Text());
					}
				}
			}
		}
	}
}
