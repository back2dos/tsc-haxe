package ts.transformers.jsxtransforms;

// Port of internal/transformers/jsxtransforms/jsx.go (package-level funcs; upstream v7.0.2).

// Package class: package-level funcs, vars and consts of internal/transformers/jsxtransforms (all files).
@:allow(ts.transformers.jsxtransforms)
class Jsxtransforms {
	// PORT: Go `range` over a possibly-nil slice (parser lists of zero elements have nil Nodes).
	static inline function rangeOf<T>(a:Null<Array<T>>):Array<T> {
		return a == null ? [] : a;
	}


	// --- jsx.go ---

	public static function NewJSXTransformer(opts:TransformOptions):Transformer {
		final compilerOptions = opts.CompilerOptions;
		final emitContext = opts.Context;
		final tx = new JSXTransformer();
		tx.compilerOptions = compilerOptions;
		tx.emitResolver = opts.EmitResolver;
		return tx.NewTransformer(tx.visit, emitContext);
	}

	/**
	 * The react jsx/jsxs transform falls back to `createElement` when an explicit `key` argument comes after a spread
	 */
	static function hasKeyAfterPropsSpread(node:Node):Bool {
		var spread = false;
		var opener = node;
		if (node.Kind == KindJsxElement) {
			opener = node.AsJsxElement().OpeningElement;
		} // otherwise self-closing
		final props = opener.Attributes().Properties();
		if (props != null) {
			for (elem in props) {
				if (Ast.IsJsxSpreadAttribute(elem) && (!Ast.IsObjectLiteralExpression(elem.Expression()) || Core.Some(elem.Expression().Properties(), Ast.IsSpreadAssignment))) {
					spread = true;
				} else if (spread && Ast.IsJsxAttribute(elem) && Ast.IsIdentifier(elem.Name()) && elem.Name().Text() == "key") {
					return true;
				}
			}
		}
		return false;
	}

	static function insertStatementAfterPrologue<T>(to:Array<Node>, statement:Node, isPrologueDirective:(callee:T, node:Node) -> Bool, callee:T):Array<Node> {
		if (statement == null) {
			return to;
		}
		var statementIdx = 0;
		// skip all prologue directives to insert at the correct position
		final n = Core.len(to);
		while (statementIdx < n) {
			if (!isPrologueDirective(callee, to[statementIdx])) {
				break;
			}
			statementIdx++;
		}
		// PORT: Go slices.Insert; copy first so the caller's (node-owned) slice is never mutated.
		final result = to == null ? [] : to.copy();
		result.insert(statementIdx, statement);
		return result;
	}

	static function sortImportSpecifiers(a:Node, b:Node):Int {
		final res = Stringutil.CompareStringsCaseSensitive(a.PropertyName().Text(), b.PropertyName().Text());
		if (res != 0) {
			return res;
		}
		return Stringutil.CompareStringsCaseSensitive(a.AsImportSpecifier().Name().Text(), b.AsImportSpecifier().Name().Text());
	}

	static function getSortedSpecifiers(m:StringMap<Node>):Array<Node> {
		// PORT: slices.Collect(maps.Values(m)) — map order is irrelevant after the sort.
		var res:Array<Node> = null;
		if (m != null) {
			for (v in m) {
				if (res == null) {
					res = [];
				}
				res.push(v);
			}
		}
		Slices.SortFunc(res, sortImportSpecifiers);
		return res;
	}

	static function hasProto(obj:ObjectLiteralExpression):Bool {
		for (p in rangeOf(obj.Properties.Nodes)) {
			if (Ast.IsPropertyAssignment(p) && (Ast.IsStringLiteral(p.Name()) || Ast.IsIdentifier(p.Name())) && p.Name().Text() == "__proto__") {
				return true;
			}
		}
		return false;
	}

	static function addLineOfJsxText(b:StringBuf, trimmedLine:std.String, isInitial:Bool):Void {
		// We do not escape the string here as that is handled by the printer
		// when it emits the literal. We do, however, need to decode JSX entities.
		final decoded = decodeEntities(trimmedLine);
		if (!isInitial) {
			b.add(" ");
		}
		b.add(decoded);
	}

	/**
	* JSX trims whitespace at the end and beginning of lines, except that the
	* start/end of a tag is considered a start/end of a line only if that line is
	* on the same line as the closing tag. See examples in
	* tests/cases/conformance/jsx/tsxReactEmitWhitespace.tsx
	* See also https://www.w3.org/TR/html4/struct/text.html#h-9.1 and https://www.w3.org/TR/CSS2/text.html#white-space-model
	*
	* An equivalent algorithm would be:
	* - If there is only one line, return it.
	* - If there is only whitespace (but multiple lines), return `undefined`.
	* - Split the text into lines.
	* - 'trimRight' the first line, 'trimLeft' the last line, 'trim' middle lines.
	* - Decode entities on each line (individually).
	* - Remove empty lines and join the rest with " ".
	 */
	static function fixupWhitespaceAndDecodeEntities(text:std.String):std.String {
		final acc = new StringBuf();
		var initial = true;
		// First non-whitespace character on this line.
		var firstNonWhitespace = 0;
		// End byte position of the last non-whitespace character on this line.
		var lastNonWhitespaceEnd = -1;
		// These initial values are special because the first line is:
		// firstNonWhitespace = 0 to indicate that we want leading whitespace,
		// but lastNonWhitespaceEnd = -1 as a special flag to indicate that we *don't* include the line if it's all whitespace.
		// PORT: utf16 — positions are UTF-16 code units; the rune size is Utf16.RuneLen.
		var i = 0;
		while (i < text.length) {
			final c = Utf16.CodePointAt(text, i);
			final size = Utf16.RuneLen(c);
			if (Stringutil.IsLineBreak(c)) {
				// If we've seen any non-whitespace characters on this line, add the 'trim' of the line.
				// (lastNonWhitespaceEnd === -1 is a special flag to detect whether the first line is all whitespace.)
				if (firstNonWhitespace != -1 && lastNonWhitespaceEnd != -1) {
					addLineOfJsxText(acc, text.substring(firstNonWhitespace, lastNonWhitespaceEnd + 1), initial);
					initial = false;
				}

				// Reset firstNonWhitespace for the next line.
				// Don't bother to reset lastNonWhitespaceEnd because we ignore it if firstNonWhitespace = -1.
				firstNonWhitespace = -1;
			} else if (!Stringutil.IsWhiteSpaceSingleLine(c)) {
				lastNonWhitespaceEnd = i + size - 1; // Store the end byte position of the character
				if (firstNonWhitespace == -1) {
					firstNonWhitespace = i;
				}
			}

			if (size > 1) {
				i += (size - 1);
			}
			i++;
		}

		if (firstNonWhitespace != -1) {
			// Last line had a non-whitespace character. Emit the 'trimLeft', meaning keep trailing whitespace.
			addLineOfJsxText(acc, text.substring(firstNonWhitespace), initial);
		}
		return acc.toString();
	}

	/**
	* Replace entities like "&nbsp;", "&#123;", and "&#xDEADBEEF;" with the characters they encode.
	* See https://en.wikipedia.org/wiki/List_of_XML_and_HTML_character_entity_references
	 */
	static function decodeEntities(text:std.String):std.String {
		// PORT: utf16 — '&' and ';' are ASCII, so code-unit offsets match Go's byte offsets logically.
		var i = text.indexOf("&");
		if (i < 0) {
			return text;
		}

		final result = new StringBuf();
		while (true) {
			result.add(text.substring(0, i));
			text = text.substring(i);

			var semi = text.indexOf(";");
			if (semi < 0) {
				break;
			}

			// Skip past any intervening '&' characters between the current '&'
			// and the ';'. Each such '&' is not part of a valid entity, so emit
			// it (and any text before the next '&') as literals.
			while (true) {
				final nextAmp = text.substring(1, semi).indexOf("&");
				if (nextAmp < 0) {
					break;
				}
				result.add(text.substring(0, nextAmp + 1));
				text = text.substring(nextAmp + 1);
				semi -= nextAmp + 1;
			}

			final entity = text.substring(1, semi);
			final decoded = decodeEntity(entity);
			if (decoded.ok) {
				// Use the JS-string encoder so lone surrogates (e.g. "&#xD800;")
				// are preserved rather than being lost to U+FFFD by WriteRune.
				result.add(Stringutil.EncodeJSStringRune(decoded.value));
			} else {
				result.add(text.substring(0, semi + 1));
			}
			text = text.substring(semi + 1);

			i = text.indexOf("&");
			if (i < 0) {
				break;
			}
		}
		result.add(text);
		return result.toString();
	}

	static function decodeEntity(entity:std.String):ValueOk<Int> {
		if (entity.length == 0) {
			return new ValueOk<Int>(0, false);
		}

		if (StringTools.fastCodeAt(entity, 0) == "#".code) {
			entity = entity.substring(1);
			if (entity.length == 0) {
				return new ValueOk<Int>(0, false);
			}

			var base = 10;
			if (StringTools.fastCodeAt(entity, 0) == "x".code) {
				base = 16;
				entity = entity.substring(1);
			}

			if (entity.length == 0) {
				return new ValueOk<Int>(0, false);
			}

			// PORT: utf16 — Go ranges over runes; non-ASCII code units are never (hex) digits either.
			for (k in 0...entity.length) {
				final c = StringTools.fastCodeAt(entity, k);
				if (base == 16 && !Stringutil.IsHexDigit(c)) {
					return new ValueOk<Int>(0, false);
				}
				if (base == 10 && !Stringutil.IsDigit(c)) {
					return new ValueOk<Int>(0, false);
				}
			}

			// PORT: strconv.ParseInt(entity, base, 32) as a hand loop (no Int64, §7a): the text is only
			// digits of `base` here, so the only possible error is a value above math.MaxInt32.
			var parsed = 0.0;
			for (k in 0...entity.length) {
				final c = StringTools.fastCodeAt(entity, k);
				final d = c >= "0".code && c <= "9".code ? c - "0".code : (c >= "a".code ? c - "a".code + 10 : c - "A".code + 10);
				parsed = parsed * base + d;
				if (parsed > 2147483647.0) {
					return new ValueOk<Int>(0, false);
				}
			}
			return new ValueOk<Int>(Std.int(parsed), true);
		}

		final ents = getEntities();
		if (ents.exists(entity)) {
			return new ValueOk<Int>(ents.get(entity), true);
		}
		return new ValueOk<Int>(0, false);
	}

	static var entities:StringMap<Int> = null;

	// PORT: lazy initializer of the Go package var `entities` (jsx.go:955).
	static function getEntities():StringMap<Int> {
		if (entities != null) {
			return entities;
		}
		final m = new StringMap<Int>();
		m.set("quot", 0x0022);
		m.set("amp", 0x0026);
		m.set("apos", 0x0027);
		m.set("lt", 0x003C);
		m.set("gt", 0x003E);
		m.set("nbsp", 0x00A0);
		m.set("iexcl", 0x00A1);
		m.set("cent", 0x00A2);
		m.set("pound", 0x00A3);
		m.set("curren", 0x00A4);
		m.set("yen", 0x00A5);
		m.set("brvbar", 0x00A6);
		m.set("sect", 0x00A7);
		m.set("uml", 0x00A8);
		m.set("copy", 0x00A9);
		m.set("ordf", 0x00AA);
		m.set("laquo", 0x00AB);
		m.set("not", 0x00AC);
		m.set("shy", 0x00AD);
		m.set("reg", 0x00AE);
		m.set("macr", 0x00AF);
		m.set("deg", 0x00B0);
		m.set("plusmn", 0x00B1);
		m.set("sup2", 0x00B2);
		m.set("sup3", 0x00B3);
		m.set("acute", 0x00B4);
		m.set("micro", 0x00B5);
		m.set("para", 0x00B6);
		m.set("middot", 0x00B7);
		m.set("cedil", 0x00B8);
		m.set("sup1", 0x00B9);
		m.set("ordm", 0x00BA);
		m.set("raquo", 0x00BB);
		m.set("frac14", 0x00BC);
		m.set("frac12", 0x00BD);
		m.set("frac34", 0x00BE);
		m.set("iquest", 0x00BF);
		m.set("Agrave", 0x00C0);
		m.set("Aacute", 0x00C1);
		m.set("Acirc", 0x00C2);
		m.set("Atilde", 0x00C3);
		m.set("Auml", 0x00C4);
		m.set("Aring", 0x00C5);
		m.set("AElig", 0x00C6);
		m.set("Ccedil", 0x00C7);
		m.set("Egrave", 0x00C8);
		m.set("Eacute", 0x00C9);
		m.set("Ecirc", 0x00CA);
		m.set("Euml", 0x00CB);
		m.set("Igrave", 0x00CC);
		m.set("Iacute", 0x00CD);
		m.set("Icirc", 0x00CE);
		m.set("Iuml", 0x00CF);
		m.set("ETH", 0x00D0);
		m.set("Ntilde", 0x00D1);
		m.set("Ograve", 0x00D2);
		m.set("Oacute", 0x00D3);
		m.set("Ocirc", 0x00D4);
		m.set("Otilde", 0x00D5);
		m.set("Ouml", 0x00D6);
		m.set("times", 0x00D7);
		m.set("Oslash", 0x00D8);
		m.set("Ugrave", 0x00D9);
		m.set("Uacute", 0x00DA);
		m.set("Ucirc", 0x00DB);
		m.set("Uuml", 0x00DC);
		m.set("Yacute", 0x00DD);
		m.set("THORN", 0x00DE);
		m.set("szlig", 0x00DF);
		m.set("agrave", 0x00E0);
		m.set("aacute", 0x00E1);
		m.set("acirc", 0x00E2);
		m.set("atilde", 0x00E3);
		m.set("auml", 0x00E4);
		m.set("aring", 0x00E5);
		m.set("aelig", 0x00E6);
		m.set("ccedil", 0x00E7);
		m.set("egrave", 0x00E8);
		m.set("eacute", 0x00E9);
		m.set("ecirc", 0x00EA);
		m.set("euml", 0x00EB);
		m.set("igrave", 0x00EC);
		m.set("iacute", 0x00ED);
		m.set("icirc", 0x00EE);
		m.set("iuml", 0x00EF);
		m.set("eth", 0x00F0);
		m.set("ntilde", 0x00F1);
		m.set("ograve", 0x00F2);
		m.set("oacute", 0x00F3);
		m.set("ocirc", 0x00F4);
		m.set("otilde", 0x00F5);
		m.set("ouml", 0x00F6);
		m.set("divide", 0x00F7);
		m.set("oslash", 0x00F8);
		m.set("ugrave", 0x00F9);
		m.set("uacute", 0x00FA);
		m.set("ucirc", 0x00FB);
		m.set("uuml", 0x00FC);
		m.set("yacute", 0x00FD);
		m.set("thorn", 0x00FE);
		m.set("yuml", 0x00FF);
		m.set("OElig", 0x0152);
		m.set("oelig", 0x0153);
		m.set("Scaron", 0x0160);
		m.set("scaron", 0x0161);
		m.set("Yuml", 0x0178);
		m.set("fnof", 0x0192);
		m.set("circ", 0x02C6);
		m.set("tilde", 0x02DC);
		m.set("Alpha", 0x0391);
		m.set("Beta", 0x0392);
		m.set("Gamma", 0x0393);
		m.set("Delta", 0x0394);
		m.set("Epsilon", 0x0395);
		m.set("Zeta", 0x0396);
		m.set("Eta", 0x0397);
		m.set("Theta", 0x0398);
		m.set("Iota", 0x0399);
		m.set("Kappa", 0x039A);
		m.set("Lambda", 0x039B);
		m.set("Mu", 0x039C);
		m.set("Nu", 0x039D);
		m.set("Xi", 0x039E);
		m.set("Omicron", 0x039F);
		m.set("Pi", 0x03A0);
		m.set("Rho", 0x03A1);
		m.set("Sigma", 0x03A3);
		m.set("Tau", 0x03A4);
		m.set("Upsilon", 0x03A5);
		m.set("Phi", 0x03A6);
		m.set("Chi", 0x03A7);
		m.set("Psi", 0x03A8);
		m.set("Omega", 0x03A9);
		m.set("alpha", 0x03B1);
		m.set("beta", 0x03B2);
		m.set("gamma", 0x03B3);
		m.set("delta", 0x03B4);
		m.set("epsilon", 0x03B5);
		m.set("zeta", 0x03B6);
		m.set("eta", 0x03B7);
		m.set("theta", 0x03B8);
		m.set("iota", 0x03B9);
		m.set("kappa", 0x03BA);
		m.set("lambda", 0x03BB);
		m.set("mu", 0x03BC);
		m.set("nu", 0x03BD);
		m.set("xi", 0x03BE);
		m.set("omicron", 0x03BF);
		m.set("pi", 0x03C0);
		m.set("rho", 0x03C1);
		m.set("sigmaf", 0x03C2);
		m.set("sigma", 0x03C3);
		m.set("tau", 0x03C4);
		m.set("upsilon", 0x03C5);
		m.set("phi", 0x03C6);
		m.set("chi", 0x03C7);
		m.set("psi", 0x03C8);
		m.set("omega", 0x03C9);
		m.set("thetasym", 0x03D1);
		m.set("upsih", 0x03D2);
		m.set("piv", 0x03D6);
		m.set("ensp", 0x2002);
		m.set("emsp", 0x2003);
		m.set("thinsp", 0x2009);
		m.set("zwnj", 0x200C);
		m.set("zwj", 0x200D);
		m.set("lrm", 0x200E);
		m.set("rlm", 0x200F);
		m.set("ndash", 0x2013);
		m.set("mdash", 0x2014);
		m.set("lsquo", 0x2018);
		m.set("rsquo", 0x2019);
		m.set("sbquo", 0x201A);
		m.set("ldquo", 0x201C);
		m.set("rdquo", 0x201D);
		m.set("bdquo", 0x201E);
		m.set("dagger", 0x2020);
		m.set("Dagger", 0x2021);
		m.set("bull", 0x2022);
		m.set("hellip", 0x2026);
		m.set("permil", 0x2030);
		m.set("prime", 0x2032);
		m.set("Prime", 0x2033);
		m.set("lsaquo", 0x2039);
		m.set("rsaquo", 0x203A);
		m.set("oline", 0x203E);
		m.set("frasl", 0x2044);
		m.set("euro", 0x20AC);
		m.set("image", 0x2111);
		m.set("weierp", 0x2118);
		m.set("real", 0x211C);
		m.set("trade", 0x2122);
		m.set("alefsym", 0x2135);
		m.set("larr", 0x2190);
		m.set("uarr", 0x2191);
		m.set("rarr", 0x2192);
		m.set("darr", 0x2193);
		m.set("harr", 0x2194);
		m.set("crarr", 0x21B5);
		m.set("lArr", 0x21D0);
		m.set("uArr", 0x21D1);
		m.set("rArr", 0x21D2);
		m.set("dArr", 0x21D3);
		m.set("hArr", 0x21D4);
		m.set("forall", 0x2200);
		m.set("part", 0x2202);
		m.set("exist", 0x2203);
		m.set("empty", 0x2205);
		m.set("nabla", 0x2207);
		m.set("isin", 0x2208);
		m.set("notin", 0x2209);
		m.set("ni", 0x220B);
		m.set("prod", 0x220F);
		m.set("sum", 0x2211);
		m.set("minus", 0x2212);
		m.set("lowast", 0x2217);
		m.set("radic", 0x221A);
		m.set("prop", 0x221D);
		m.set("infin", 0x221E);
		m.set("ang", 0x2220);
		m.set("and", 0x2227);
		m.set("or", 0x2228);
		m.set("cap", 0x2229);
		m.set("cup", 0x222A);
		m.set("int", 0x222B);
		m.set("there4", 0x2234);
		m.set("sim", 0x223C);
		m.set("cong", 0x2245);
		m.set("asymp", 0x2248);
		m.set("ne", 0x2260);
		m.set("equiv", 0x2261);
		m.set("le", 0x2264);
		m.set("ge", 0x2265);
		m.set("sub", 0x2282);
		m.set("sup", 0x2283);
		m.set("nsub", 0x2284);
		m.set("sube", 0x2286);
		m.set("supe", 0x2287);
		m.set("oplus", 0x2295);
		m.set("otimes", 0x2297);
		m.set("perp", 0x22A5);
		m.set("sdot", 0x22C5);
		m.set("lceil", 0x2308);
		m.set("rceil", 0x2309);
		m.set("lfloor", 0x230A);
		m.set("rfloor", 0x230B);
		m.set("lang", 0x2329);
		m.set("rang", 0x232A);
		m.set("loz", 0x25CA);
		m.set("spades", 0x2660);
		m.set("clubs", 0x2663);
		m.set("hearts", 0x2665);
		m.set("diams", 0x2666);
		entities = m;
		return m;
	}
}
