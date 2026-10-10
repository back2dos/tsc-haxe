package ts.jsnum;

import go.Math;
import haxe.Int64;
import ts.jsnum.Jsnum;
import ts.jsnum.Jsnum.*;

using ts.jsnum.String_;

// Port of jsnum_test.go, pseudobigint_test.go, ryu_test.go and string_test.go.
// Not ported: BenchmarkToInt32, BenchmarkExponentiate (benchmarks); FuzzStringJS and
// FuzzFromStringJS (fuzz targets: outside fuzzing mode Go adds no seeds and upstream has no
// testdata corpus, so they run no cases).
// The "Node" subtests and TestStringJS run node like upstream jstest.EvalNodeScript (on both
// targets, via sys.io.Process); they are skipped when node is not found.
@:access(ts.jsnum.Jsnum)
@:access(ts.jsnum.Number)
class JsnumTest {
	// ryu_test.go
	static final maxMantissa:Int64 = Int64.make(0x001FFFFF, 0xFFFFFFFF); // (1 << 53) - 1

	// --- jsnum_test.go ---

	static function assertEqualNumber(got:Number, want:Number, ?pos:haxe.PosInfos) {
		if (got.IsNaN() || want.IsNaN()) {
			T.isTrue(got.IsNaN() == want.IsNaN(), 'got: ${got.String()}, want: ${want.String()}', pos);
		} else {
			T.isTrue(got == want, 'got: ${got.String()}, want: ${want.String()}', pos);
		}
	}

	// assertWithinOneULP checks that got and want are either equal or differ by
	// at most 1 ULP (unit in the last place).
	static function assertWithinOneULP(got:Number, want:Number, ?pos:haxe.PosInfos) {
		if (got.IsNaN() || want.IsNaN()) {
			T.isTrue(got.IsNaN() == want.IsNaN(), 'got: ${got.String()}, want: ${want.String()}', pos);
			return;
		}

		T.checks++;
		if (got == want) {
			return;
		}

		final gotBits = Math.Float64bits(got);
		final wantBits = Math.Float64bits(want);
		if (gotBits == wantBits) {
			return;
		}

		var ulpDist:Int64;
		if (Int64.ucompare(gotBits, wantBits) > 0) {
			ulpDist = gotBits - wantBits;
		} else {
			ulpDist = wantBits - gotBits;
		}

		if (Int64.ucompare(ulpDist, 1) > 0) {
			T.fail('got ${got.String()} (${Int64.toStr(gotBits)}), want ${want.String()} (${Int64.toStr(wantBits)}) within 1 ULP (off by ${Int64.toStr(ulpDist)} ULPs)', pos);
		}
	}

	static function numberFromBits(b:Int64):Number {
		return Math.Float64frombits(b);
	}

	static function numberToBits(n:Number):Int64 {
		return Math.Float64bits(n);
	}

	// PORT: [2]uint32 → Array<Int> of two uint32 bit patterns.
	static function numToUint32s(n:Number):Array<Int> {
		final bits = numberToBits(n);
		return [bits.low, bits.high];
	}

	static function uint32sToNum(a:Array<Int>):Number {
		return numberFromBits(Int64.make(a[1], a[0]));
	}

	// JSON for a [2]uint32.
	static function uint32sJSON(a:Array<Int>):String {
		return "[" + Int64.toStr(Int64.make(0, a[0])) + "," + Int64.toStr(Int64.make(0, a[1])) + "]";
	}

	// [2]uint32 from a decoded JSON array.
	static function uint32sFromJSON(v:Dynamic):Array<Int> {
		final a:Array<Dynamic> = v;
		return [for (x in a) {
			final f:Float = x;
			Std.int(f >= 2147483648.0 ? f - 4294967296.0 : f);
		}];
	}

	static final fromBitsToBitsJS = '
		function fromBits(bits) {
			const buffer = new ArrayBuffer(8);
			(new Uint32Array(buffer))[0] = bits[0];
			(new Uint32Array(buffer))[1] = bits[1];
			return new Float64Array(buffer)[0];
		}

		function toBits(number) {
			const buffer = new ArrayBuffer(8);
			(new Float64Array(buffer))[0] = number;
			return [(new Uint32Array(buffer))[0], (new Uint32Array(buffer))[1]];
		}
';

	// evalBinaryOp evaluates a binary JS expression on all cases using Node.js.
	// Returns null (Go: skips the calling test) if Node.js is not available.
	static function evalBinaryOp(op:String, xs:Array<Number>, ys:Array<Number>):Null<Array<Number>> {
		if (!hasNodeJS()) {
			return null;
		}

		final tmpdir = tempDir();
		final inputs = [
			for (i in 0...xs.length)
				'{"x":' + uint32sJSON(numToUint32s(xs[i])) + ',"y":' + uint32sJSON(numToUint32s(ys[i])) + '}'
		];
		final jsonInput = "[" + inputs.join(",") + "]";

		final inputPath = tmpdir + "/input.json";
		writeFile(inputPath, jsonInput);

		final script = '
		import fs from \'fs\';
' + fromBitsToBitsJS + '
		export default function(inputFile) {
			const input = JSON.parse(fs.readFileSync(inputFile, \'utf8\'));
			return input.map(({x, y}) => {
				const a = fromBits(x);
				const b = fromBits(y);
				return { x, y, result: toBits(' + op + ') };
			});
		};
	';

		final results:Array<Dynamic> = evalNodeScript(script, tmpdir, [inputPath]);
		removeTempDir(tmpdir);
		T.eq(xs.length, results.length);

		return [for (r in results) uint32sToNum(uint32sFromJSON(r.result))];
	}

	// evalUnaryOp evaluates a unary JS expression on all cases using Node.js.
	// Returns null (Go: skips the calling test) if Node.js is not available.
	static function evalUnaryOp(op:String, xs:Array<Number>):Null<Array<Number>> {
		if (!hasNodeJS()) {
			return null;
		}

		final tmpdir = tempDir();
		final inputs = [for (x in xs) '{"x":' + uint32sJSON(numToUint32s(x)) + '}'];
		final jsonInput = "[" + inputs.join(",") + "]";

		final inputPath = tmpdir + "/input.json";
		writeFile(inputPath, jsonInput);

		final script = '
		import fs from \'fs\';
' + fromBitsToBitsJS + '
		export default function(inputFile) {
			const input = JSON.parse(fs.readFileSync(inputFile, \'utf8\'));
			return input.map(({x}) => {
				const a = fromBits(x);
				return { x, result: toBits(' + op + ') };
			});
		};
	';

		final results:Array<Dynamic> = evalNodeScript(script, tmpdir, [inputPath]);
		removeTempDir(tmpdir);
		T.eq(xs.length, results.length);

		return [for (r in results) uint32sToNum(uint32sFromJSON(r.result))];
	}

	static final toInt32Tests:Array<ToInt32Test> = [
		new ToInt32Test("0.0", 0.0, 0, true),
		new ToInt32Test("-0.0", negativeZero, 0, false),
		new ToInt32Test("NaN", NaN(), 0, true),
		new ToInt32Test("+Inf", Inf(1), 0, true),
		new ToInt32Test("-Inf", Inf(-1), 0, true),
		new ToInt32Test("MaxInt32", 2147483647.0, 2147483647, false),
		new ToInt32Test("MaxInt32+1", 2147483648.0, 0x80000000, true),
		new ToInt32Test("MinInt32", (-2147483648.0), 0x80000000, false),
		new ToInt32Test("MinInt32-1", (-2147483649.0), 2147483647, true),
		new ToInt32Test("MIN_SAFE_INTEGER", MinSafeInteger, 1, false),
		new ToInt32Test("MIN_SAFE_INTEGER-1", MinSafeInteger - 1, 0, false),
		new ToInt32Test("MIN_SAFE_INTEGER+1", MinSafeInteger + 1, 2, false),
		new ToInt32Test("MAX_SAFE_INTEGER", MaxSafeInteger, -1, true),
		new ToInt32Test("MAX_SAFE_INTEGER-1", MaxSafeInteger - 1, -2, true),
		new ToInt32Test("MAX_SAFE_INTEGER+1", MaxSafeInteger + 1, 0, true),
		new ToInt32Test("-8589934590", (-8589934590.0), 2, false),
		new ToInt32Test("0xDEADBEEF", 3735928559.0, -559038737, true),
		new ToInt32Test("4294967808", 4294967808.0, 512, false),
		new ToInt32Test("-0.4", (-0.4), 0, false),
		new ToInt32Test("SmallestNonzeroFloat64", Math.SmallestNonzeroFloat64, 0, false),
		new ToInt32Test("-SmallestNonzeroFloat64", -Math.SmallestNonzeroFloat64, 0, false),
		new ToInt32Test("MaxFloat64", Math.MaxFloat64, 0, false),
		new ToInt32Test("-MaxFloat64", -Math.MaxFloat64, 0, false),
		new ToInt32Test("Largest subnormal number", numberFromBits(Int64.make(0x000FFFFF, 0xFFFFFFFF)), 0, false),
		new ToInt32Test("Smallest positive normal number", numberFromBits(Int64.make(0x00100000, 0x00000000)), 0, false),
		new ToInt32Test("Largest normal number", Math.MaxFloat64, 0, false),
		new ToInt32Test("-Largest normal number", -Math.MaxFloat64, 0, false),
		new ToInt32Test("1.0", 1.0, 1, false),
		new ToInt32Test("-1.0", (-1.0), -1, false),
		new ToInt32Test("1e308", 1e+308, 0, false),
		new ToInt32Test("-1e308", (-1e+308), 0, false),
		new ToInt32Test("math.Pi", Math.Pi, 3, false),
		new ToInt32Test("-math.Pi", -Math.Pi, -3, false),
		new ToInt32Test("math.E", Math.E, 2, false),
		new ToInt32Test("-math.E", -Math.E, -2, false),
		new ToInt32Test("0.5", 0.5, 0, false),
		new ToInt32Test("-0.5", (-0.5), 0, false),
		new ToInt32Test("0.49999999999999994", 0.49999999999999994, 0, false),
		new ToInt32Test("-0.49999999999999994", (-0.49999999999999994), 0, false),
		new ToInt32Test("0.5000000000000001", 0.5000000000000001, 0, false),
		new ToInt32Test("-0.5000000000000001", (-0.5000000000000001), 0, false),
		new ToInt32Test("2^31 + 0.5", 2147483648.5, 0x80000000, false),
		new ToInt32Test("-2^31 - 0.5", (-2147483648.5), 0x80000000, false),
		new ToInt32Test("2^40", 1099511627776.0, 0, false),
		new ToInt32Test("-2^40", (-1099511627776.0), 0, false),
		new ToInt32Test("TypeFlagsNarrowable", 536624127.0, 536624127, true),
	];
	static final stringTests0:Array<StringTest> = [
		new StringTest(NaN(), "NaN"),
		new StringTest(Inf(1), "Infinity"),
		new StringTest(Inf(-1), "-Infinity"),
		new StringTest(0.0, "0"),
		new StringTest(negativeZero, "0"),
		new StringTest(1.0, "1"),
		new StringTest((-1.0), "-1"),
		new StringTest(0.3, "0.3"),
		new StringTest((-0.3), "-0.3"),
		new StringTest(1.5, "1.5"),
		new StringTest((-1.5), "-1.5"),
		new StringTest(1e+308, "1e+308"),
		new StringTest((-1e+308), "-1e+308"),
		new StringTest(Math.Pi, "3.141592653589793"),
		new StringTest(-Math.Pi, "-3.141592653589793"),
		new StringTest(MaxSafeInteger, "9007199254740991"),
		new StringTest(MinSafeInteger, "-9007199254740991"),
		new StringTest(numberFromBits(Int64.make(0x000FFFFF, 0xFFFFFFFF)), "2.225073858507201e-308"),
		new StringTest(numberFromBits(Int64.make(0x00100000, 0x00000000)), "2.2250738585072014e-308"),
		new StringTest(1234567.8, "1234567.8"),
		new StringTest(1.968610959516923e+19, "19686109595169230000"),
		new StringTest(123.456, "123.456"),
		new StringTest((-123.456), "-123.456"),
		new StringTest(444123.0, "444123"),
		new StringTest((-444123.0), "-444123"),
		new StringTest(444123.7891234568, "444123.7891234568"),
		new StringTest((-444123.7896363636), "-444123.7896363636"),
		new StringTest(1e+21, "1e+21"),
		new StringTest(1e+20, "100000000000000000000"),
	];
	static final ryuTests:Array<StringTest> = [
		new StringTest(2.2250738585072014e-308, "2.2250738585072014e-308"),
		new StringTest(numberFromBits(Int64.make(0x7FEFFFFF, 0xFFFFFFFF)), "1.7976931348623157e+308"),
		new StringTest(numberFromBits(Int64.make(0x00000000, 0x00000001)), "5e-324"),
		new StringTest(2.9802322387695312e-08, "2.9802322387695312e-8"),
		new StringTest((-2.109808898695963e+16), "-21098088986959630"),
		new StringTest(4.940656e-318, "4.940656e-318"),
		new StringTest(1.18575755e-316, "1.18575755e-316"),
		new StringTest(2.989102097996e-312, "2.989102097996e-312"),
		new StringTest(9060801153433600.0, "9060801153433600"),
		new StringTest(4.708356024711512e+18, "4708356024711512000"),
		new StringTest(9.409340012568248e+18, "9409340012568248000"),
		new StringTest(1.2345678, "1.2345678"),
		new StringTest(numberFromBits(Int64.make(0x4830F0CF, 0x064DD592)), "5.764607523034235e+39"),
		new StringTest(numberFromBits(Int64.make(0x4840F0CF, 0x064DD592)), "1.152921504606847e+40"),
		new StringTest(numberFromBits(Int64.make(0x4850F0CF, 0x064DD592)), "2.305843009213694e+40"),
		new StringTest(1.2, "1.2"),
		new StringTest(1.23, "1.23"),
		new StringTest(1.234, "1.234"),
		new StringTest(1.2345, "1.2345"),
		new StringTest(1.23456, "1.23456"),
		new StringTest(1.234567, "1.234567"),
		new StringTest(1.2345678, "1.2345678"),
		new StringTest(1.23456789, "1.23456789"),
		new StringTest(1.234567895, "1.234567895"),
		new StringTest(1.2345678901, "1.2345678901"),
		new StringTest(1.23456789012, "1.23456789012"),
		new StringTest(1.234567890123, "1.234567890123"),
		new StringTest(1.2345678901234, "1.2345678901234"),
		new StringTest(1.23456789012345, "1.23456789012345"),
		new StringTest(1.234567890123456, "1.234567890123456"),
		new StringTest(1.2345678901234567, "1.2345678901234567"),
		new StringTest(4.294967294, "4.294967294"),
		new StringTest(4.294967295, "4.294967295"),
		new StringTest(4.294967296, "4.294967296"),
		new StringTest(4.294967297, "4.294967297"),
		new StringTest(4.294967298, "4.294967298"),
		new StringTest(ieeeParts2Double(false, 4, Int64.make(0x00000000, 0x00000000)), "1.7800590868057611e-307"),
		new StringTest(ieeeParts2Double(false, 6, maxMantissa), "2.8480945388892175e-306"),
		new StringTest(ieeeParts2Double(false, 41, Int64.make(0x00000000, 0x00000000)), "2.446494580089078e-296"),
		new StringTest(ieeeParts2Double(false, 40, maxMantissa), "4.8929891601781557e-296"),
		new StringTest(ieeeParts2Double(false, 1077, Int64.make(0x00000000, 0x00000000)), "18014398509481984"),
		new StringTest(ieeeParts2Double(false, 1076, maxMantissa), "36028797018963964"),
		new StringTest(ieeeParts2Double(false, 307, Int64.make(0x00000000, 0x00000000)), "2.900835519859558e-216"),
		new StringTest(ieeeParts2Double(false, 306, maxMantissa), "5.801671039719115e-216"),
		new StringTest(ieeeParts2Double(false, 934, Int64.make(0x000FA716, 0x1A4D6E0C)), "3.196104012172126e-27"),
		new StringTest(9007199254740991.0, "9007199254740991"),
		new StringTest(9007199254740992.0, "9007199254740992"),
		new StringTest(1.0, "1"),
		new StringTest(12.0, "12"),
		new StringTest(123.0, "123"),
		new StringTest(1234.0, "1234"),
		new StringTest(12345.0, "12345"),
		new StringTest(123456.0, "123456"),
		new StringTest(1234567.0, "1234567"),
		new StringTest(12345678.0, "12345678"),
		new StringTest(123456789.0, "123456789"),
		new StringTest(1234567890.0, "1234567890"),
		new StringTest(1234567895.0, "1234567895"),
		new StringTest(12345678901.0, "12345678901"),
		new StringTest(123456789012.0, "123456789012"),
		new StringTest(1234567890123.0, "1234567890123"),
		new StringTest(12345678901234.0, "12345678901234"),
		new StringTest(123456789012345.0, "123456789012345"),
		new StringTest(1234567890123456.0, "1234567890123456"),
		new StringTest(1.0, "1"),
		new StringTest(10.0, "10"),
		new StringTest(100.0, "100"),
		new StringTest(1000.0, "1000"),
		new StringTest(10000.0, "10000"),
		new StringTest(100000.0, "100000"),
		new StringTest(1000000.0, "1000000"),
		new StringTest(10000000.0, "10000000"),
		new StringTest(100000000.0, "100000000"),
		new StringTest(1000000000.0, "1000000000"),
		new StringTest(10000000000.0, "10000000000"),
		new StringTest(100000000000.0, "100000000000"),
		new StringTest(1000000000000.0, "1000000000000"),
		new StringTest(10000000000000.0, "10000000000000"),
		new StringTest(100000000000000.0, "100000000000000"),
		new StringTest(1000000000000000.0, "1000000000000000"),
		new StringTest(1000000000000001.0, "1000000000000001"),
		new StringTest(1000000000000010.0, "1000000000000010"),
		new StringTest(1000000000000100.0, "1000000000000100"),
		new StringTest(1000000000001000.0, "1000000000001000"),
		new StringTest(1000000000010000.0, "1000000000010000"),
		new StringTest(1000000000100000.0, "1000000000100000"),
		new StringTest(1000000001000000.0, "1000000001000000"),
		new StringTest(1000000010000000.0, "1000000010000000"),
		new StringTest(1000000100000000.0, "1000000100000000"),
		new StringTest(1000001000000000.0, "1000001000000000"),
		new StringTest(1000010000000000.0, "1000010000000000"),
		new StringTest(1000100000000000.0, "1000100000000000"),
		new StringTest(1001000000000000.0, "1001000000000000"),
		new StringTest(1010000000000000.0, "1010000000000000"),
		new StringTest(1100000000000000.0, "1100000000000000"),
		new StringTest(8.0, "8"),
		new StringTest(64.0, "64"),
		new StringTest(512.0, "512"),
		new StringTest(8192.0, "8192"),
		new StringTest(65536.0, "65536"),
		new StringTest(524288.0, "524288"),
		new StringTest(8388608.0, "8388608"),
		new StringTest(67108864.0, "67108864"),
		new StringTest(536870912.0, "536870912"),
		new StringTest(8589934592.0, "8589934592"),
		new StringTest(68719476736.0, "68719476736"),
		new StringTest(549755813888.0, "549755813888"),
		new StringTest(8796093022208.0, "8796093022208"),
		new StringTest(70368744177664.0, "70368744177664"),
		new StringTest(562949953421312.0, "562949953421312"),
		new StringTest(9007199254740992.0, "9007199254740992"),
		new StringTest(8000.0, "8000"),
		new StringTest(64000.0, "64000"),
		new StringTest(512000.0, "512000"),
		new StringTest(8192000.0, "8192000"),
		new StringTest(65536000.0, "65536000"),
		new StringTest(524288000.0, "524288000"),
		new StringTest(8388608000.0, "8388608000"),
		new StringTest(67108864000.0, "67108864000"),
		new StringTest(536870912000.0, "536870912000"),
		new StringTest(8589934592000.0, "8589934592000"),
		new StringTest(68719476736000.0, "68719476736000"),
		new StringTest(549755813888000.0, "549755813888000"),
		new StringTest(8796093022208000.0, "8796093022208000"),
	];
	static final fromStringTests:Array<StringTest> = [
		new StringTest(NaN(), "    NaN"),
		new StringTest(Inf(1), "Infinity    "),
		new StringTest(Inf(-1), "    -Infinity"),
		new StringTest(1.0, "1."),
		new StringTest(1.0, "1.0   "),
		new StringTest(1.0, "+1"),
		new StringTest(1.0, "+1."),
		new StringTest(1.0, "+1.0"),
		new StringTest(NaN(), "whoops"),
		new StringTest(0.0, ""),
		new StringTest(0.0, "0"),
		new StringTest(0.0, "0."),
		new StringTest(0.0, "0.0"),
		new StringTest(0.0, "0.0000"),
		new StringTest(0.0, ".0000"),
		new StringTest(negativeZero, "-0"),
		new StringTest(negativeZero, "-0."),
		new StringTest(negativeZero, "-0.0"),
		new StringTest(negativeZero, "-.0"),
		new StringTest(NaN(), "."),
		new StringTest(NaN(), "e"),
		new StringTest(NaN(), ".e"),
		new StringTest(NaN(), "+"),
		new StringTest(0.0, "0X0"),
		new StringTest(NaN(), "e0"),
		new StringTest(NaN(), "E0"),
		new StringTest(NaN(), "1e"),
		new StringTest(NaN(), "1e+"),
		new StringTest(NaN(), "1e-"),
		new StringTest(1.0, "1e+0"),
		new StringTest(NaN(), "++0"),
		new StringTest(NaN(), "0_0"),
		new StringTest(Inf(1), "1e1000"),
		new StringTest(Inf(-1), "-1e1000"),
		new StringTest(0.0, ".0e0"),
		new StringTest(NaN(), "0e++0"),
		new StringTest(10.0, "0XA"),
		new StringTest(10.0, "0b1010"),
		new StringTest(10.0, "0B1010"),
		new StringTest(10.0, "0o12"),
		new StringTest(10.0, "0O12"),
		new StringTest(1.3117684674637903e+18, "0x123456789abcdef0"),
		new StringTest(1.3117684674637903e+18, "0X123456789ABCDEF0"),
		new StringTest(1.8446744073709552e+19, "0X10000000000000000"),
		new StringTest(1.8446744073709597e+19, "0X1000000000000A801"),
		new StringTest(NaN(), "0B0.0"),
		new StringTest(1.231235345083403e+91, "12312353450834030486384068034683603046834603806830644850340602384608368034634603680348603864"),
		new StringTest(NaN(), "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX8OOOOOOOOOOOOOOOOOOO"),
		new StringTest(Inf(1), "+Infinity"),
		new StringTest(1234.56, "  \t1234.56  "),
		new StringTest(NaN(), "\u200b"),
		new StringTest(0.0, " "),
		new StringTest(0.0, "\n"),
		new StringTest(0.0, "\r"),
		new StringTest(0.0, "\r\n"),
		new StringTest(0.0, "\u2028"),
		new StringTest(0.0, "\u2029"),
		new StringTest(0.0, "\t"),
		new StringTest(0.0, "\x0B"),
		new StringTest(0.0, "\x0C"),
		new StringTest(0.0, "\uFEFF"),
		new StringTest(0.0, "\u00A0"),
		new StringTest(1e+19, "010000000000000000000"),
		new StringTest(NaN(), "0x1.fffffffffffffp1023"),
		new StringTest(NaN(), "0X_1FFFP-16"),
		new StringTest(NaN(), "1_000"),
		new StringTest(0.0, "0x0"),
		new StringTest(0.0, "0X0"),
		new StringTest(NaN(), "0xOOPS"),
		new StringTest(11259375.0, "0xABCDEF"),
		new StringTest(11259375.0, "0xABCDEF"),
		new StringTest(0.0, "0o0"),
		new StringTest(0.0, "0O0"),
		new StringTest(NaN(), "0o8"),
		new StringTest(NaN(), "0O8"),
		new StringTest(5349.0, "0o12345"),
		new StringTest(5349.0, "0O12345"),
		new StringTest(0.0, "0b0"),
		new StringTest(0.0, "0B0"),
		new StringTest(NaN(), "0b2"),
		new StringTest(NaN(), "0b2"),
		new StringTest(21.0, "0b10101"),
		new StringTest(21.0, "0B10101"),
		new StringTest(NaN(), "1.f"),
		new StringTest(NaN(), "1.e"),
		new StringTest(NaN(), "1.0ef"),
		new StringTest(NaN(), "1.0e"),
		new StringTest(NaN(), ".f"),
		new StringTest(NaN(), ".e"),
		new StringTest(NaN(), ".0ef"),
		new StringTest(NaN(), ".0e"),
		new StringTest(NaN(), "a.f"),
		new StringTest(NaN(), "a.e"),
		new StringTest(NaN(), "a.0ef"),
		new StringTest(NaN(), "a.0e"),
	];
	static final stringTests:Array<StringTest> = stringTests0.concat(ryuTests);

	// Runs each case of a binary-op table and its "Node" subtest.
	// PORT: the Go method is selected by `op` instead of a closure: hxcpp calls closures through
	// Dynamic, which boxes an integral Float as Int and so turns -0 into +0.
	static function apply(op:String, x:Number, y:Number):Number {
		return switch (op) {
			case "a & b": x.BitwiseAND(y);
			case "a | b": x.BitwiseOR(y);
			case "a ^ b": x.BitwiseXOR(y);
			case "a >> b": x.SignedRightShift(y);
			case "a >>> b": x.UnsignedRightShift(y);
			case "a << b": x.LeftShift(y);
			case "a % b": x.Remainder(y);
			case "a ** b": x.Exponentiate(y);
			case _: throw "unknown op " + op;
		}
	}

	static function runBinTests(tests:Array<BinTest>, op:String, within1ULP = false) {
		final xs = [for (test in tests) test.x];
		final ys = [for (test in tests) test.y];
		for (test in tests) {
			final got = apply(op, test.x, test.y);
			assertEqualNumber(got, test.want);
		}

		// "Node"
		final jsResults = evalBinaryOp(op, xs, ys);
		if (jsResults != null) {
			for (i in 0...tests.length) {
				final test = tests[i];
				if (within1ULP)
					assertWithinOneULP(apply(op, test.x, test.y), jsResults[i]);
				else
					assertEqualNumber(apply(op, test.x, test.y), jsResults[i]);
			}
		}
	}

	public static function run() {
		T.run("TestToInt32", () -> {
			final inputs = [for (test in toInt32Tests) test.input];
			final zeros:Array<Number> = [for (_ in toInt32Tests) 0.0];
			for (test in toInt32Tests) {
				final got = test.input.toInt32();
				T.isTrue(got == test.want, '${test.name}: got $got, want ${test.want}');
			}

			// "Node"
			final jsResults = evalBinaryOp("a | b", inputs, zeros);
			if (jsResults != null) {
				for (i in 0...toInt32Tests.length) {
					final test = toInt32Tests[i];
					assertEqualNumber(test.input.toInt32(), jsResults[i]);
				}
			}
		});

		// BenchmarkToInt32: not ported (benchmark).

		T.run("TestBitwiseNOT", () -> {
			final tests = [
				// Original pairs: ~(-2147483649) == ~(2147483647)
				new BinTest((-2147483649.0), (-2147483648.0)),
				new BinTest(2147483647.0, (-2147483648.0)),
				// Original pairs: ~(-4294967296) == ~(0)
				new BinTest((-4294967296.0), (-1.0)),
				new BinTest(0.0, (-1.0)),
				// Original pairs: ~(2147483648) == ~(-2147483648)
				new BinTest(2147483648.0, 2147483647.0),
				new BinTest((-2147483648.0), 2147483647.0),
				// Original pairs: ~(4294967296) == ~(0)
				new BinTest(4294967296.0, (-1.0)),
			];

			final xs = [for (test in tests) test.x];
			for (test in tests) {
				final got = test.x.BitwiseNOT();
				assertEqualNumber(got, test.y);
			}

			// "Node"
			final jsResults = evalUnaryOp("~a", xs);
			if (jsResults != null) {
				for (i in 0...tests.length) {
					assertEqualNumber(tests[i].x.BitwiseNOT(), jsResults[i]);
				}
			}
		});

		T.run("TestBitwiseAND", () -> {
			final tests = [
				new BinTest(0.0, 0.0, 0.0),
				new BinTest(0.0, 1.0, 0.0),
				new BinTest(1.0, 0.0, 0.0),
				new BinTest(1.0, 1.0, 1.0),
			];
			runBinTests(tests, "a & b");
		});

		T.run("TestBitwiseOR", () -> {
			final tests = [
				new BinTest(0.0, 0.0, 0.0),
				new BinTest(0.0, 1.0, 1.0),
				new BinTest(1.0, 0.0, 1.0),
				new BinTest(1.0, 1.0, 1.0),
			];
			runBinTests(tests, "a | b");
		});

		T.run("TestBitwiseXOR", () -> {
			final tests = [
				new BinTest(0.0, 0.0, 0.0),
				new BinTest(0.0, 1.0, 1.0),
				new BinTest(1.0, 0.0, 1.0),
				new BinTest(1.0, 1.0, 0.0),
			];
			runBinTests(tests, "a ^ b");
		});

		T.run("TestSignedRightShift", () -> {
			final tests = [
				new BinTest(1.0, 0.0, 1.0),
				new BinTest(1.0, 1.0, 0.0),
				new BinTest(1.0, 2.0, 0.0),
				new BinTest(1.0, 31.0, 0.0),
				new BinTest(1.0, 32.0, 1.0),
				new BinTest((-4.0), 0.0, (-4.0)),
				new BinTest((-4.0), 1.0, (-2.0)),
				new BinTest((-4.0), 2.0, (-1.0)),
				new BinTest((-4.0), 3.0, (-1.0)),
				new BinTest((-4.0), 4.0, (-1.0)),
				new BinTest((-4.0), 31.0, (-1.0)),
				new BinTest((-4.0), 32.0, (-4.0)),
				new BinTest((-4.0), 33.0, (-2.0)),
			];
			runBinTests(tests, "a >> b");
		});

		T.run("TestUnsignedRightShift", () -> {
			final tests = [
				new BinTest(1.0, 0.0, 1.0),
				new BinTest(1.0, 1.0, 0.0),
				new BinTest(1.0, 2.0, 0.0),
				new BinTest(1.0, 31.0, 0.0),
				new BinTest(1.0, 32.0, 1.0),
				new BinTest((-4.0), 0.0, 4294967292.0),
				new BinTest((-4.0), 1.0, 2147483646.0),
				new BinTest((-4.0), 2.0, 1073741823.0),
				new BinTest((-4.0), 3.0, 536870911.0),
				new BinTest((-4.0), 4.0, 268435455.0),
				new BinTest((-4.0), 31.0, 1.0),
				new BinTest((-4.0), 32.0, 4294967292.0),
				new BinTest((-4.0), 33.0, 2147483646.0),
			];
			runBinTests(tests, "a >>> b");
		});

		T.run("TestLeftShift", () -> {
			final tests = [
				new BinTest(1.0, 0.0, 1.0),
				new BinTest(1.0, 1.0, 2.0),
				new BinTest(1.0, 2.0, 4.0),
				new BinTest(1.0, 31.0, (-2147483648.0)),
				new BinTest(1.0, 32.0, 1.0),
				new BinTest((-4.0), 0.0, (-4.0)),
				new BinTest((-4.0), 1.0, (-8.0)),
				new BinTest((-4.0), 2.0, (-16.0)),
				new BinTest((-4.0), 3.0, (-32.0)),
				new BinTest((-4.0), 31.0, 0.0),
				new BinTest((-4.0), 32.0, (-4.0)),
			];
			runBinTests(tests, "a << b");
		});

		T.run("TestRemainder", () -> {
			final tests = [
				new BinTest(NaN(), 1.0, NaN()),
				new BinTest(1.0, NaN(), NaN()),
				new BinTest(Inf(1), 1.0, NaN()),
				new BinTest(Inf(-1), 1.0, NaN()),
				new BinTest(123.0, Inf(1), 123.0),
				new BinTest(123.0, Inf(-1), 123.0),
				new BinTest(123.0, 0.0, NaN()),
				new BinTest(123.0, negativeZero, NaN()),
				new BinTest(0.0, 123.0, 0.0),
				new BinTest(negativeZero, 123.0, negativeZero),
				// Normal cases
				new BinTest(10.0, 3.0, 1.0),
				new BinTest((-10.0), 3.0, (-1.0)),
				new BinTest(10.0, (-3.0), 1.0),
				new BinTest((-10.0), (-3.0), (-1.0)),
				new BinTest(5.5, 2.0, 1.5),
				new BinTest((-5.5), 2.0, (-1.5)),
				new BinTest(1.0, 0.5, 0.0),
				new BinTest((-1.0), 0.5, negativeZero),
				new BinTest(1.5, 1.0, 0.5),
				new BinTest((-1.5), 1.0, (-0.5)),
				// Edge cases that prove the bug in the manual formula:
				// The manual formula n - d*(n/d).trunc() accumulates floating-point
				// rounding errors that IEEE 754 fmod (math.Mod) avoids.
				new BinTest(7.0, 0.1, (Math.Mod(7.0, 0.1) : Number)),
				new BinTest(7.0, 0.2, (Math.Mod(7.0, 0.2) : Number)),
				new BinTest(7.0, 0.3, (Math.Mod(7.0, 0.3) : Number)),
				new BinTest(100.0, 0.3, (Math.Mod(100.0, 0.3) : Number)),
			];
			runBinTests(tests, "a % b");
		});

		T.run("TestExponentiate", () -> {
			final tests = [
				new BinTest(2.0, 3.0, 8.0),
				new BinTest(Inf(1), 3.0, Inf(1)),
				new BinTest(Inf(1), (-5.0), 0.0),
				new BinTest(Inf(-1), 3.0, Inf(-1)),
				new BinTest(Inf(-1), 4.0, Inf(1)),
				new BinTest(Inf(-1), (-3.0), negativeZero),
				new BinTest(Inf(-1), (-4.0), 0.0),
				new BinTest(0.0, 3.0, 0.0),
				new BinTest(0.0, (-10.0), Inf(1)),
				new BinTest(negativeZero, 3.0, negativeZero),
				new BinTest(negativeZero, 4.0, 0.0),
				new BinTest(negativeZero, (-3.0), Inf(-1)),
				new BinTest(negativeZero, (-4.0), Inf(1)),
				new BinTest(3.0, Inf(1), Inf(1)),
				new BinTest((-3.0), Inf(1), Inf(1)),
				new BinTest(3.0, Inf(-1), 0.0),
				new BinTest((-3.0), Inf(-1), 0.0),
				new BinTest(NaN(), 3.0, NaN()),
				new BinTest(1.0, Inf(1), NaN()),
				new BinTest(1.0, Inf(-1), NaN()),
				new BinTest((-1.0), Inf(1), NaN()),
				new BinTest((-1.0), Inf(-1), NaN()),
				new BinTest(1.0, NaN(), NaN()),
				// Cases where math.Pow diverges from V8 by >1 ULP.
				// Expected values are the correctly-rounded IEEE 754 results
				// computed via exact integer arithmetic (big.Int).
				// Cross-engine testing (V8, SpiderMonkey, QuickJS, XS via jsvu)
				// confirmed these match the majority of JS engines.
				new BinTest(10.0, 308.0, numberFromBits(Int64.make(0x7FE1CCF3, 0x85EBC8A0))),
				new BinTest(5.0, 210.0, numberFromBits(Int64.make(0x5E68557F, 0x31326BBB))),
				new BinTest(10.0, 200.0, numberFromBits(Int64.make(0x6974E718, 0xD7D7625A))),
			];

			// The ES spec says exponentiate is "implementation-approximated".
			// Different JS engines (V8, SpiderMonkey, JSC) use different pow
			// implementations that can differ by 1 ULP. Allow that tolerance.
			runBinTests(tests, "a ** b", true);
		});

		// BenchmarkExponentiate: not ported (benchmark).

		// --- pseudobigint_test.go ---

		T.run("TestParsePseudoBigInt", () -> {
			final testNumbers:Array<Number> = [];
			for (i in 0...1000) {
				testNumbers.push(i);
			}
			for (bits in 0...53) {
				final p = std.Math.pow(2, bits); // int64(1<<bits), exact
				testNumbers.push(p);
				testNumbers.push(p - 1);
			}

			// "strip base-10 strings"
			for (testNumber in testNumbers) {
				for (leadingZeros in 0...10) {
					T.eq(testNumber.String(), ParsePseudoBigInt(StringTools.rpad("", "0", leadingZeros) + testNumber.String() + "n"));
				}
			}

			// "parse non-decimal bases (small numbers)"
			final cases = [
				// binary
				new Tc("0b0n", "0"),
				new Tc("0b1n", "1"),
				new Tc("0b1010n", "10"),
				new Tc("0b1010_0101n", "165"),
				new Tc("0B1101n", "13"), // uppercase prefix

				// octal
				new Tc("0o0n", "0"),
				new Tc("0o7n", "7"),
				new Tc("0o755n", "493"),
				new Tc("0o7_5_5n", "493"),
				new Tc("0O12n", "10"), // uppercase prefix

				// hex
				new Tc("0x0n", "0"),
				new Tc("0xFn", "15"),
				new Tc("0xFFn", "255"),
				new Tc("0xF_Fn", "255"),
				new Tc("0X1Fn", "31"), // uppercase prefix
			];

			for (c in cases) {
				final got = ParsePseudoBigInt(c.lit);
				T.isTrue(got == c.out, 'literal: ${c.lit}: got $got, want ${c.out}');
			}

			// "can parse large literals"
			T.eq("123456789012345678901234567890", ParsePseudoBigInt("123456789012345678901234567890n"));
			T.eq("123456789012345678901234567890",
				ParsePseudoBigInt("0b1100011101110100100001111111101101100001101110011111000001110111001001110001111110000101011010010n"));
			T.eq("123456789012345678901234567890", ParsePseudoBigInt("0o143564417755415637016711617605322n"));
			T.eq("123456789012345678901234567890", ParsePseudoBigInt("0x18ee90ff6c373e0ee4e3f0ad2n"));
		});

		// --- string_test.go ---

		T.run("TestString", () -> {
			for (test in stringTests) {
				T.isTrue(test.number.String() == test.str, 'got ${test.number.String()}, want ${test.str}');
			}
		});

		T.run("TestFromString", () -> {
			// "stringTests"
			for (test in stringTests) {
				assertEqualNumber(FromString(test.str), test.number);
				assertEqualNumber(FromString(test.str + " "), test.number);
				assertEqualNumber(FromString(" " + test.str), test.number);
			}

			// "fromStringTests"
			for (test in fromStringTests) {
				assertEqualNumber(FromString(test.str), test.number);
			}
		});

		T.run("TestStringRoundtrip", () -> {
			for (test in stringTests) {
				T.eq(test.str, FromString(test.str).String());
			}
		});

		T.run("TestStringJS", () -> {
			if (!hasNodeJS()) {
				return;
			}

			// "stringTests"
			// These tests should roundtrip both ways.
			final stringTestsResults = getStringResultsFromJS(stringTests);
			for (i in 0...stringTests.length) {
				final test = stringTests[i];
				assertEqualNumber(stringTestsResults[i].number, test.number);
				T.eq(test.str, stringTestsResults[i].str);
			}

			// "fromStringTests"
			// These tests should convert the string to the same number.
			final fromStringTestsResults = getStringResultsFromJS(fromStringTests);
			for (i in 0...fromStringTests.length) {
				final test = fromStringTests[i];
				assertEqualNumber(fromStringTestsResults[i].number, test.number);
			}
		});

		// FuzzStringJS, FuzzFromStringJS: not ported (fuzz targets, see header).
	}

	static function getStringResultsFromJS(tests:Array<StringTest>):Array<StringTest> {
		final tmpdir = tempDir();

		final inputData = [
			for (test in tests)
				'{"bits":' + uint32sJSON(numberToUint32Array(test.number)) + ',"str":' + jsonString(test.str) + '}'
		];

		final jsonInput = "[" + inputData.join(",") + "]";

		final jsonInputPath = tmpdir + "/input.json";
		writeFile(jsonInputPath, jsonInput);

		final script = '
		import fs from \'fs\';
' + fromBitsToBitsJS + '
		export default function(inputFile) {
			const input = JSON.parse(fs.readFileSync(inputFile, \'utf8\'));

			const output = input.map((input) => ({
				str: ""+fromBits(input.bits),
				bits: toBits(+input.str),	
			}));

			return output;
		};
	';

		final outputData:Array<Dynamic> = evalNodeScript(script, tmpdir, [jsonInputPath]);
		removeTempDir(tmpdir);
		T.eq(tests.length, outputData.length);

		return [
			for (outputDatum in outputData)
				new StringTest(uint32ArrayToNumber(uint32sFromJSON(outputDatum.bits)), outputDatum.str)
		];
	}

	static function numberToUint32Array(n:Number):Array<Int> {
		final bits = numberToBits(n);
		return [bits.low, bits.high];
	}

	static function uint32ArrayToNumber(a:Array<Int>):Number {
		return numberFromBits(Int64.make(a[1], a[0]));
	}

	// --- ryu_test.go ---

	static function ieeeParts2Double(sign:Bool, ieeeExponent:Int, ieeeMantissa:Int64):Number {
		if (ieeeExponent > 2047) {
			throw "ieeeExponent > 2047";
		}
		if (ieeeMantissa > maxMantissa) {
			throw "ieeeMantissa > maxMantissa";
		}
		var signBit = 0;
		if (sign) {
			signBit = 1;
		}
		return numberFromBits(Int64.make((signBit << 31) | (ieeeExponent << 20) | ieeeMantissa.high, ieeeMantissa.low));
	}

	// maxMantissa: declared at the top of the class (statics initialize in declaration order).

	// --- testutil/jstest (minimal port of EvalNodeScript / SkipIfNoNodeJS) ---

	static final loaderScript = 'import script from "./script.mjs";
process.stdout.write(JSON.stringify(await script(...process.argv.slice(2))));';

	static var nodeChecked = false;
	static var nodeFound = false;

	static function hasNodeJS():Bool {
		if (!nodeChecked) {
			nodeChecked = true;
			try {
				nodeFound = Sys.command("node", ["-e", ""]) == 0;
			} catch (e:Dynamic) {
				nodeFound = false;
			}
		}
		return nodeFound;
	}

	static var tempCounter = 0;

	static function tempDir():String {
		var base = Sys.getEnv("TMPDIR");
		if (base == null || base == "") {
			base = "/tmp";
		}
		tempCounter++;
		final dir = base + "/jsnum-test-" + Std.string(Std.int(Sys.time() * 1000) % 1000000000) + "-" + Std.random(1000000) + "-" + tempCounter;
		sys.FileSystem.createDirectory(dir);
		return dir;
	}

	static function removeTempDir(dir:String) {
		for (f in sys.FileSystem.readDirectory(dir)) {
			sys.FileSystem.deleteFile(dir + "/" + f);
		}
		sys.FileSystem.deleteDirectory(dir);
	}

	// PORT: files are not written from Haxe (sys.io.File writing needs haxe.io.Bytes, whose
	// hxcpp implementation does not build with the pinned Haxe/hxcpp pair). They are queued here
	// and written by a node bootstrap before the loader runs; node's stdout is written by the
	// bootstrap to a file that Haxe reads with sys.io.File.getContent.
	static var pendingFiles:Array<Array<String>> = [];

	// JSON string literal with every non-printable-ASCII code unit escaped (haxe.Json.stringify
	// leaves control characters unescaped on hxcpp; ASCII-only also keeps command lines simple).
	static function jsonString(s:String):String {
		final b = new StringBuf();
		b.add('"');
		for (i in 0...s.length) {
			final c = StringTools.fastCodeAt(s, i);
			if (c == '"'.code || c == '\\'.code) {
				b.add('\\');
				b.addChar(c);
			} else if (c < 0x20 || c >= 0x7F) {
				b.add('\\u' + StringTools.hex(c, 4));
			} else {
				b.addChar(c);
			}
		}
		b.add('"');
		return b.toString();
	}

	static function writeFile(path:String, content:String) {
		pendingFiles.push([path, content]);
	}

	static final bootstrapScript = "
		import fs from 'fs';
		import { spawnSync } from 'child_process';
		const [outPath, files, dir, ...args] = process.argv.slice(1);
		for (const [p, c] of JSON.parse(files)) fs.writeFileSync(p, c);
		const r = spawnSync(process.execPath, args, { cwd: dir, maxBuffer: 1 << 30 });
		fs.writeFileSync(outPath, Buffer.concat([r.stdout, r.stderr]));
		process.exit(r.status === null ? 1 : r.status);
	";

	static function evalNodeScript(script:String, dir:String, args:Array<String>):Dynamic {
		final scriptPath = dir + "/script.mjs";
		writeFile(scriptPath, script);
		final loaderPath = dir + "/loader.mjs";
		writeFile(loaderPath, loaderScript);

		final outPath = dir + "/output.json";
		final files = "[" + [for (f in pendingFiles) "[" + jsonString(f[0]) + "," + jsonString(f[1]) + "]"].join(",") + "]";
		pendingFiles = [];
		final code = Sys.command("node", ["--input-type=module", "-e", bootstrapScript, outPath, files, dir, loaderPath].concat(args));
		final output = sys.io.File.getContent(outPath);
		if (code != 0) {
			throw "failed to run node: exit " + code + "\n" + output;
		}
		return haxe.Json.parse(output);
	}
}

private class ToInt32Test {
	public final name:String;
	public final input:Number;
	public final want:Int;
	public final bench:Bool;

	public function new(name:String, input:Number, want:Int, bench:Bool) {
		this.name = name;
		this.input = input;
		this.want = want;
		this.bench = bench;
	}
}

// Go `struct { x, y, want Number }` (TestBitwiseNOT: `struct { x, want Number }`, want in y).
private class BinTest {
	public final x:Number;
	public final y:Number;
	public final want:Number;

	public function new(x:Number, y:Number, ?want:Number) {
		this.x = x;
		this.y = y;
		this.want = want;
	}
}

private class Tc {
	public final lit:String;
	public final out:String;

	public function new(lit:String, out:String) {
		this.lit = lit;
		this.out = out;
	}
}

class StringTest {
	public final number:Number;
	public final str:String;

	public function new(number:Number, str:String) {
		this.number = number;
		this.str = str;
	}
}
