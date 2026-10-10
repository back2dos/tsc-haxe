package go;

import haxe.Int64;
import haxe.io.Bytes;

// Shim for github.com/zeebo/xxh3 v1.1.0 (third-party Go module; used by tracing): the 64-bit
// XXH3 hash with the default secret and seed 0 (Hash, HashString, New, Hasher.WriteString,
// Hasher.Sum64). Ported from the scalar code paths (hash64.go, utils.go, consts.go,
// accum_generic.go accumScalar); the vector paths compute the same values.
// PORT: 64-bit — uint64 values are haxe.Int64 bit patterns.
// PORT: the keyNNN_xxx constants are read from the key bytes (readU64(key, xxx)), which is how
// upstream defines them.
// PORT: Hasher buffers the written bytes and Sum64 hashes them in one shot. XXH3 streaming and
// one-shot results are equal by specification (zeebo's Hasher.Sum64 calls Hash for <= 1024
// bytes and the streaming accumulation for longer input yields the same value).
class Xxh3 {
	static inline final _stripe = 64;
	static inline final _block = 1024;

	static var key_:Bytes = null;

	static function key():Bytes {
		if (key_ == null) {
			final hex = "b8fe6c3923a44bbe7c01812cf721ad1cded46de9839097db7240a4a4b7b3671fcb79e64eccc0e578825ad07dccff7221b8084674f743248ee03590e6813a264c3c2852bb91c300cb88d0658b1b532ea371644897a20df94e3819ef46a9deacd8a8fa763fe39c343ff9dcbbc7c70b4f1d8a51e04bcdb45931c89f7ec9d9787364eac5ac8334d3ebc3c581a0fffa1363eb170ddd51b7f0da49d316552629d4689e2b16be587d47a1fc8ff8b8d17ad031ce45cb3a8f95160428afd7fbcabb4b407e";
			final b = Bytes.alloc(192);
			for (i in 0...192) {
				b.set(i, Std.parseInt("0x" + hex.substr(i * 2, 2)));
			}
			key_ = b;
		}
		return key_;
	}

	// uint64 constants
	static final prime32_1:Int64 = Int64.make(0, 0x9E3779B1);
	static final prime32_2:Int64 = Int64.make(0, 0x85EBCA77);
	static final prime32_3:Int64 = Int64.make(0, 0xC2B2AE3D);
	static final prime64_1:Int64 = Int64.make(0x9E3779B1, 0x85EBCA87);
	static final prime64_2:Int64 = Int64.make(0xC2B2AE3D, 0x27D4EB4F);
	static final prime64_3:Int64 = Int64.make(0x165667B1, 0x9E3779F9);
	static final prime64_4:Int64 = Int64.make(0x85EBCA77, 0xC2B2AE63);
	static final prime64_5:Int64 = Int64.make(0x27D4EB2F, 0x165667C5);

	static inline function readU8(p:Bytes, o:Int):Int {
		return p.get(o);
	}

	static inline function readU16(p:Bytes, o:Int):Int {
		return p.get(o) | (p.get(o + 1) << 8);
	}

	static inline function readU32(p:Bytes, o:Int):Int64 {
		return Int64.make(0, p.getInt32(o));
	}

	static inline function readU64(p:Bytes, o:Int):Int64 {
		return Int64.make(p.getInt32(o + 4), p.getInt32(o));
	}

	static function k64(o:Int):Int64 {
		return readU64(key(), o);
	}

	// Hash returns the hash of the byte slice.
	public static function Hash(b:Bytes):Int64 {
		return hashAny(b, b.length);
	}

	// Hash returns the hash of the string slice.
	// PORT: Go hashes the UTF-8 bytes of the string.
	public static function HashString(s:String):Int64 {
		final b = Utf8.StringToBytes(s);
		return hashAny(b, b.length);
	}

	// HashString128 returns the 128-bit hash of the string slice.
	// PORT: added for execute/incremental (hash128.go hashAny128, scalar accumulation path).
	// Go hashes the UTF-8 bytes of the string.
	public static function HashString128(s:String):Uint128 {
		final b = Utf8.StringToBytes(s);
		return hashAny128(b, b.length);
	}

	static function hashAny128(p:Bytes, l:Int):Uint128 {
		final acc = new Uint128(0, 0);
		if (l <= 16) {
			if (l > 8) { // 9-16
				final bitflipl = k64(32) ^ k64(40);
				final bitfliph = k64(48) ^ k64(56);

				final input_lo = readU64(p, 0);
				var input_hi = readU64(p, l - 8);

				final m = mul128(input_lo ^ input_hi ^ bitflipl, prime64_1);
				var m128_h = m[0];
				var m128_l = m[1];

				m128_l += Int64.ofInt(l - 1) << 54;
				input_hi = input_hi ^ bitfliph;

				m128_h += input_hi + mul64(lo32(input_hi), prime32_2 - 1);

				m128_l = m128_l ^ reverseBytes64(m128_h);

				final r = mul128(m128_l, prime64_2);
				acc.Hi = r[0];
				acc.Lo = r[1];
				acc.Hi += mul64(m128_h, prime64_2);

				acc.Lo = xxh3Avalanche(acc.Lo);
				acc.Hi = xxh3Avalanche(acc.Hi);

				return acc;
			} else if (l > 3) { // 4-8
				final bitflip = k64(16) ^ k64(24);

				final input_lo = readU32(p, 0);
				final input_hi = readU32(p, l - 4);
				final input_64 = input_lo + (input_hi << 32);
				final keyed = input_64 ^ bitflip;

				final r = mul128(keyed, prime64_1 + (Int64.ofInt(l) << 2));
				acc.Hi = r[0];
				acc.Lo = r[1];

				acc.Hi += acc.Lo << 1;
				acc.Lo = acc.Lo ^ (acc.Hi >>> 3);

				acc.Lo = acc.Lo ^ (acc.Lo >>> 35);
				acc.Lo = mul64(acc.Lo, Int64.make(0x9fb21c65, 0x1e98df25));
				acc.Lo = acc.Lo ^ (acc.Lo >>> 28);
				acc.Hi = xxh3Avalanche(acc.Hi);

				return acc;
			} else if (l == 3) { // 3
				final c12 = Int64.ofInt(readU16(p, 0));
				final c3 = Int64.ofInt(readU8(p, 2));
				acc.Lo = (c12 << 16) + c3 + (3 << 8);
			} else if (l > 1) { // 2
				final c12 = Int64.ofInt(readU16(p, 0));
				acc.Lo = ((c12 * Int64.ofInt((1 << 24) + 1)) >>> 8) + (2 << 8); // < 2^41: no overflow
			} else if (l == 1) { // 1
				final c1 = Int64.ofInt(readU8(p, 0));
				acc.Lo = c1 * Int64.ofInt((1 << 24) + (1 << 16) + 1) + (1 << 8);
			} else { // 0
				return new Uint128(Int64.make(0x99aa06d3, 0x014798d8), Int64.make(0x6001c324, 0x468d497f));
			}

			// bits.RotateLeft32(bits.ReverseBytes32(uint32(acc.Lo)), 13)
			final rb = bswap32(acc.Lo.low);
			acc.Hi = Int64.make(0, (rb << 13) | (rb >>> 19));
			acc.Lo = acc.Lo ^ Int64.make(0, 0xbe4ba423 ^ 0x396cfeb8); // key32_000 ^ key32_004
			acc.Hi = acc.Hi ^ Int64.make(0, 0x1cad21f7 ^ 0x2c81017c); // key32_008 ^ key32_012

			acc.Lo = xxh64AvalancheSmall(acc.Lo);
			acc.Hi = xxh64AvalancheSmall(acc.Hi);

			return acc;
		} else if (l <= 128) {
			acc.Lo = mul64(Int64.ofInt(l), prime64_1);

			if (l > 32) {
				if (l > 64) {
					if (l > 96) {
						final in8 = readU64(p, l - 8 * 8), in7 = readU64(p, l - 7 * 8);
						final i6 = readU64(p, 6 * 8), i7 = readU64(p, 7 * 8);

						acc.Hi += mulFold64(in8 ^ k64(112), in7 ^ k64(120));
						acc.Hi = acc.Hi ^ (i6 + i7);
						acc.Lo += mulFold64(i6 ^ k64(96), i7 ^ k64(104));
						acc.Lo = acc.Lo ^ (in8 + in7);
					} // 96

					final in6 = readU64(p, l - 6 * 8), in5 = readU64(p, l - 5 * 8);
					final i4 = readU64(p, 4 * 8), i5 = readU64(p, 5 * 8);

					acc.Hi += mulFold64(in6 ^ k64(80), in5 ^ k64(88));
					acc.Hi = acc.Hi ^ (i4 + i5);
					acc.Lo += mulFold64(i4 ^ k64(64), i5 ^ k64(72));
					acc.Lo = acc.Lo ^ (in6 + in5);
				} // 64

				final in4 = readU64(p, l - 4 * 8), in3 = readU64(p, l - 3 * 8);
				final i2 = readU64(p, 2 * 8), i3 = readU64(p, 3 * 8);

				acc.Hi += mulFold64(in4 ^ k64(48), in3 ^ k64(56));
				acc.Hi = acc.Hi ^ (i2 + i3);
				acc.Lo += mulFold64(i2 ^ k64(32), i3 ^ k64(40));
				acc.Lo = acc.Lo ^ (in4 + in3);
			} // 32

			final in2 = readU64(p, l - 2 * 8), in1 = readU64(p, l - 1 * 8);
			final i0 = readU64(p, 0 * 8), i1 = readU64(p, 1 * 8);

			acc.Hi += mulFold64(in2 ^ k64(16), in1 ^ k64(24));
			acc.Hi = acc.Hi ^ (i0 + i1);
			acc.Lo += mulFold64(i0 ^ k64(0), i1 ^ k64(8));
			acc.Lo = acc.Lo ^ (in2 + in1);

			final hi = mul64(acc.Lo, prime64_1) + mul64(acc.Hi, prime64_4) + mul64(Int64.ofInt(l), prime64_2);
			final lo = acc.Hi + acc.Lo;
			acc.Hi = hi;
			acc.Lo = lo;

			acc.Hi = neg64(xxh3Avalanche(acc.Hi));
			acc.Lo = xxh3Avalanche(acc.Lo);

			return acc;
		} else if (l <= 240) {
			acc.Lo = mul64(Int64.ofInt(l), prime64_1);

			for (g in 0...4) {
				final o = g * 32;
				final i0 = readU64(p, o + 0), i1 = readU64(p, o + 8), i2 = readU64(p, o + 16), i3 = readU64(p, o + 24);

				acc.Hi += mulFold64(i2 ^ k64(o + 16), i3 ^ k64(o + 24));
				acc.Hi = acc.Hi ^ (i0 + i1);
				acc.Lo += mulFold64(i0 ^ k64(o + 0), i1 ^ k64(o + 8));
				acc.Lo = acc.Lo ^ (i2 + i3);
			}

			// avalanche
			acc.Hi = xxh3Avalanche(acc.Hi);
			acc.Lo = xxh3Avalanche(acc.Lo);

			// trailing groups after 128
			final top = l & ~31;
			var i = 4 * 32;
			while (i < top) {
				final i0 = readU64(p, i + 0), i1 = readU64(p, i + 8), i2 = readU64(p, i + 16), i3 = readU64(p, i + 24);
				final k0 = k64(i - 125), k1 = k64(i - 117), k2 = k64(i - 109), k3 = k64(i - 101);

				acc.Hi += mulFold64(i2 ^ k2, i3 ^ k3);
				acc.Hi = acc.Hi ^ (i0 + i1);
				acc.Lo += mulFold64(i0 ^ k0, i1 ^ k1);
				acc.Lo = acc.Lo ^ (i2 + i3);
				i += 32;
			}

			// last 32 bytes
			{
				final i0 = readU64(p, l - 32), i1 = readU64(p, l - 24), i2 = readU64(p, l - 16), i3 = readU64(p, l - 8);

				acc.Hi += mulFold64(i0 ^ k64(119), i1 ^ k64(127));
				acc.Hi = acc.Hi ^ (i2 + i3);
				acc.Lo += mulFold64(i2 ^ k64(103), i3 ^ k64(111));
				acc.Lo = acc.Lo ^ (i0 + i1);
			}

			final hi = mul64(acc.Lo, prime64_1) + mul64(acc.Hi, prime64_4) + mul64(Int64.ofInt(l), prime64_2);
			final lo = acc.Hi + acc.Lo;
			acc.Hi = hi;
			acc.Lo = lo;

			acc.Hi = neg64(xxh3Avalanche(acc.Hi));
			acc.Lo = xxh3Avalanche(acc.Lo);

			return acc;
		} else {
			acc.Lo = mul64(Int64.ofInt(l), prime64_1);
			final h = mul64(Int64.ofInt(l), prime64_2);
			acc.Hi = Int64.make(~h.high, ~h.low);

			final accs:Array<Int64> = [prime32_3, prime64_1, prime64_2, prime64_3, prime64_4, prime32_2, prime64_5, prime32_1];

			accumScalar(accs, p, l);

			// merge accs
			acc.Lo += mulFold64(accs[0] ^ k64(11), accs[1] ^ k64(19));
			acc.Hi += mulFold64(accs[0] ^ k64(117), accs[1] ^ k64(125));

			acc.Lo += mulFold64(accs[2] ^ k64(27), accs[3] ^ k64(35));
			acc.Hi += mulFold64(accs[2] ^ k64(133), accs[3] ^ k64(141));

			acc.Lo += mulFold64(accs[4] ^ k64(43), accs[5] ^ k64(51));
			acc.Hi += mulFold64(accs[4] ^ k64(149), accs[5] ^ k64(157));

			acc.Lo += mulFold64(accs[6] ^ k64(59), accs[7] ^ k64(67));
			acc.Hi += mulFold64(accs[6] ^ k64(165), accs[7] ^ k64(173));

			acc.Lo = xxh3Avalanche(acc.Lo);
			acc.Hi = xxh3Avalanche(acc.Hi);

			return acc;
		}
	}

	static function xxh64AvalancheSmall(x:Int64):Int64 {
		x = mul64(x, prime64_2);
		x = x ^ (x >>> 29);
		x = mul64(x, prime64_3);
		x = x ^ hi32(x);
		return x;
	}

	// -x mod 2^64 (two's complement) on 32-bit limbs.
	static function neg64(x:Int64):Int64 {
		final lo = (~x.low) + 1;
		final hi = (~x.high) + (lo == 0 ? 1 : 0);
		return Int64.make(hi, lo);
	}

	// hi, lo := bits.Mul64(x, y) → [hi, lo]; same limb arithmetic as mulFold64.
	static function mul128(x:Int64, y:Int64):Array<Int64> {
		final loLo = mulU32(x.low, y.low);
		final hiLo = mulU32(x.high, y.low);
		final loHi = mulU32(x.low, y.high);
		final hiHi = mulU32(x.high, y.high);
		final t = lo32(loHi) + lo32(hiLo) + hi32(loLo);
		final crossLo = t.low;
		final crossHi = hi32(loHi) + hi32(t);
		final u = hi32(hiLo) + lo32(crossHi) + lo32(hiHi);
		final upperLo = u.low;
		final upperHi = hiHi.high + u.high + crossHi.high; // mod 2^32
		return [Int64.make(upperHi, upperLo), Int64.make(crossLo, loLo.low)];
	}

	// New returns a new Hasher that implements the hash.Hash interface.
	public static function New():Hasher {
		return new Hasher();
	}

	static function hashAny(p:Bytes, l:Int):Int64 {
		var acc:Int64 = 0;
		if (l <= 16) {
			if (l > 8) { // 9-16
				final inputlo = readU64(p, 0) ^ (k64(24) ^ k64(32));
				final inputhi = readU64(p, l - 8) ^ (k64(40) ^ k64(48));
				final folded = mulFold64(inputlo, inputhi);
				return xxh3Avalanche(Int64.ofInt(l) + reverseBytes64(inputlo) + inputhi + folded);
			} else if (l > 3) { // 4-8
				final input1 = readU32(p, 0);
				final input2 = readU32(p, l - 4);
				final input64 = input2 + (input1 << 32);
				final keyed = input64 ^ (k64(8) ^ k64(16));
				return rrmxmx(keyed, Int64.ofInt(l));
			} else if (l == 3) { // 3
				final c12 = Int64.ofInt(readU16(p, 0));
				final c3 = Int64.ofInt(readU8(p, 2));
				acc = (c12 << 16) + c3 + (3 << 8);
			} else if (l > 1) { // 2
				final c12 = Int64.ofInt(readU16(p, 0));
				acc = ((c12 * Int64.ofInt((1 << 24) + 1)) >>> 8) + (2 << 8); // < 2^41: no overflow
			} else if (l == 1) { // 1
				final c1 = Int64.ofInt(readU8(p, 0));
				acc = c1 * Int64.ofInt((1 << 24) + (1 << 16) + 1) + (1 << 8);
			} else { // 0
				return Int64.make(0x2d068005, 0x38d394c2); // xxh_avalanche(key64_056 ^ key64_064)
			}

			acc = acc ^ Int64.make(0, 0xbe4ba423 ^ 0x396cfeb8); // key32_000 ^ key32_004
			return xxhAvalancheSmall(acc);
		} else if (l <= 128) {
			acc = mul64(Int64.ofInt(l), prime64_1);

			if (l > 32) {
				if (l > 64) {
					if (l > 96) {
						acc += mulFold64(readU64(p, 6 * 8) ^ k64(96), readU64(p, 7 * 8) ^ k64(104));
						acc += mulFold64(readU64(p, l - 8 * 8) ^ k64(112), readU64(p, l - 7 * 8) ^ k64(120));
					} // 96
					acc += mulFold64(readU64(p, 4 * 8) ^ k64(64), readU64(p, 5 * 8) ^ k64(72));
					acc += mulFold64(readU64(p, l - 6 * 8) ^ k64(80), readU64(p, l - 5 * 8) ^ k64(88));
				} // 64
				acc += mulFold64(readU64(p, 2 * 8) ^ k64(32), readU64(p, 3 * 8) ^ k64(40));
				acc += mulFold64(readU64(p, l - 4 * 8) ^ k64(48), readU64(p, l - 3 * 8) ^ k64(56));
			} // 32
			acc += mulFold64(readU64(p, 0 * 8) ^ k64(0), readU64(p, 1 * 8) ^ k64(8));
			acc += mulFold64(readU64(p, l - 2 * 8) ^ k64(16), readU64(p, l - 1 * 8) ^ k64(24));

			return xxh3Avalanche(acc);
		} else if (l <= 240) {
			acc = mul64(Int64.ofInt(l), prime64_1);

			for (g in 0...8) {
				acc += mulFold64(readU64(p, g * 16 + 0) ^ k64(g * 16), readU64(p, g * 16 + 8) ^ k64(g * 16 + 8));
			}

			// avalanche
			acc = xxh3Avalanche(acc);

			// trailing groups after 128
			final top = l & ~15;
			var i = 8 * 16;
			while (i < top) {
				acc += mulFold64(readU64(p, i + 0) ^ k64(i - 125), readU64(p, i + 8) ^ k64(i - 117));
				i += 16;
			}

			// last 16 bytes
			acc += mulFold64(readU64(p, l - 16) ^ k64(119), readU64(p, l - 8) ^ k64(127));

			return xxh3Avalanche(acc);
		} else {
			acc = mul64(Int64.ofInt(l), prime64_1);

			final accs:Array<Int64> = [prime32_3, prime64_1, prime64_2, prime64_3, prime64_4, prime32_2, prime64_5, prime32_1];

			accumScalar(accs, p, l);

			// merge accs
			acc += mulFold64(accs[0] ^ k64(11), accs[1] ^ k64(19));
			acc += mulFold64(accs[2] ^ k64(27), accs[3] ^ k64(35));
			acc += mulFold64(accs[4] ^ k64(43), accs[5] ^ k64(51));
			acc += mulFold64(accs[6] ^ k64(59), accs[7] ^ k64(67));

			return xxh3Avalanche(acc);
		}
	}

	// One stripe: 8 lanes of data at p against the key at offset k.
	// PORT: the unrolled `off = 0, 2, 4, 6` blocks of accumScalar as a loop; the last-stripe
	// block (key64_121 ...) is the same computation with key offset 121.
	static function accumStripe(accs:Array<Int64>, data:Bytes, p:Int, k:Int):Void {
		final secret = key();
		var off = 0;
		while (off < 8) {
			final dv0 = readU64(data, p + 8 * off);
			final dk0 = dv0 ^ readU64(secret, k + 8 * off);
			var ac1 = dv0;
			var ac0 = mulU32(dk0.low, dk0.high);

			final dv1 = readU64(data, p + 8 * off + 8);
			final dk1 = dv1 ^ readU64(secret, k + 8 * off + 8);
			ac0 += dv1;
			ac1 += mulU32(dk1.low, dk1.high);

			accs[off] += ac0;
			accs[off + 1] += ac1;
			off += 2;
		}
	}

	static function accumScalar(accs:Array<Int64>, data:Bytes, l:Int):Void {
		var p = 0;
		while (l > _block) {
			var k = 0;

			// accs
			for (i in 0...16) {
				accumStripe(accs, data, p, k);
				l -= _stripe;
				if (l > 0) {
					p += _stripe;
					k += 8;
				}
			}

			// scramble accs
			for (j in 0...8) {
				var a = accs[j];
				a = a ^ (a >>> 47);
				a = a ^ k64(128 + 8 * j);
				a = mul64(a, prime32_1);
				accs[j] = a;
			}
		}

		if (l > 0) {
			final t = Std.int((l - 1) / _stripe);
			var k = 0;

			for (i in 0...t) {
				accumStripe(accs, data, p, k);
				l -= _stripe;
				if (l > 0) {
					p += _stripe;
					k += 8;
				}
			}

			if (l > 0) {
				p = p - (_stripe - l);
				accumStripe(accs, data, p, 121);
			}
		}
	}

	static function xxhAvalancheSmall(x:Int64):Int64 {
		x = x ^ (x >>> 33);
		x = mul64(x, prime64_2);
		x = x ^ (x >>> 29);
		x = mul64(x, prime64_3);
		x = x ^ hi32(x);
		return x;
	}

	static function xxh3Avalanche(x:Int64):Int64 {
		x = x ^ (x >>> 37);
		x = mul64(x, Int64.make(0x16566791, 0x9e3779f9));
		x = x ^ hi32(x);
		return x;
	}

	static function rrmxmx(h64:Int64, len:Int64):Int64 {
		h64 = h64 ^ (rotateLeft64(h64, 49) ^ rotateLeft64(h64, 24));
		h64 = mul64(h64, Int64.make(0x9fb21c65, 0x1e98df25));
		h64 = h64 ^ ((h64 >>> 35) + len);
		h64 = mul64(h64, Int64.make(0x9fb21c65, 0x1e98df25));
		h64 = h64 ^ (h64 >>> 28);
		return h64;
	}

	static inline function rotateLeft64(x:Int64, k:Int):Int64 {
		return (x << k) | (x >>> (64 - k));
	}

	static function bswap32(x:Int):Int {
		return ((x & 0xff) << 24) | (((x >>> 8) & 0xff) << 16) | (((x >>> 16) & 0xff) << 8) | ((x >>> 24) & 0xff);
	}

	// bits.ReverseBytes64
	static function reverseBytes64(x:Int64):Int64 {
		return Int64.make(bswap32(x.low), bswap32(x.high));
	}

	// hi, lo := bits.Mul64(x, y); return hi ^ lo
	// PORT: computed on 32-bit limbs so that no Int64 operation overflows: hxcpp maps Int64 to a
	// signed C++ int64, and the C++ optimizer exploits signed overflow when it knows operand
	// ranges (measured: the straightforward `(x & mask) * (y & mask)` version gives wrong results
	// on hxcpp).
	static function mulFold64(x:Int64, y:Int64):Int64 {
		final loLo = mulU32(x.low, y.low);
		final hiLo = mulU32(x.high, y.low);
		final loHi = mulU32(x.low, y.high);
		final hiHi = mulU32(x.high, y.high);
		// cross = (loLo >> 32) + (hiLo & 0xFFFFFFFF) + loHi
		final t = lo32(loHi) + lo32(hiLo) + hi32(loLo);
		final crossLo = t.low;
		final crossHi = hi32(loHi) + hi32(t);
		// upper = (hiLo >> 32) + (cross >> 32) + hiHi
		final u = hi32(hiLo) + lo32(crossHi) + lo32(hiHi);
		final upperLo = u.low;
		final upperHi = hiHi.high + u.high + crossHi.high; // mod 2^32
		// lower = (cross << 32) | (loLo & 0xFFFFFFFF)
		final lowerHi = crossLo;
		final lowerLo = loLo.low;
		return Int64.make(upperHi ^ lowerHi, upperLo ^ lowerLo);
	}

	// uint64(a) * uint64(b) for 32-bit a, b (bit patterns), on 16-bit pieces (no Int64 overflow).
	static function mulU32(a:Int, b:Int):Int64 {
		final al = Int64.ofInt(a & 0xFFFF), ah = Int64.ofInt(a >>> 16);
		final bl = Int64.ofInt(b & 0xFFFF), bh = Int64.ofInt(b >>> 16);
		final mid = ah * bl + al * bh; // < 2^33
		final loFull = al * bl + ((mid & Int64.ofInt(0xFFFF)) << 16); // < 2^33
		final hi = ah * bh + (mid >> 16) + hi32(loFull); // < 2^32
		return Int64.make(hi.low, loFull.low);
	}

	// x * y mod 2^64 (wrapping uint64 multiplication) on 32-bit limbs; see mulFold64.
	static function mul64(x:Int64, y:Int64):Int64 {
		final ll = mulU32(x.low, y.low);
		final hi = ll.high + mulU32(x.low, y.high).low + mulU32(x.high, y.low).low; // mod 2^32
		return Int64.make(hi, ll.low);
	}

	static inline function lo32(x:Int64):Int64 {
		return Int64.make(0, x.low);
	}

	// x >>> 32
	// PORT: Haxe 4.3.7 on JS computes Int64 `x >>> 32` as make(0, x.high >>> 0), whose low word is
	// a non-normalized (unsigned) JS number; a following Int64 addition then loses its carry
	// (measured). Build the value from the signed high word instead.
	static inline function hi32(x:Int64):Int64 {
		return Int64.make(0, x.high);
	}
}

// Hasher implements the hash.Hash interface
// PORT: see the header — the written data is buffered; only WriteString and Sum64 are ported.
class Hasher {
	var data:String = "";

	public function new() {}

	// WriteString adds more data to the running hash.
	// It never returns an error.
	// PORT: (int, error) → the byte count only.
	public function WriteString(s:String):Int {
		data += s;
		return Utf8.StringToBytes(s).length;
	}

	// Sum64 returns the 64-bit hash of the written data.
	public function Sum64():Int64 {
		return Xxh3.HashString(data);
	}
}

// Uint128 is a 128 bit value (xxh3 utils.go).
class Uint128 {
	public var Hi:Int64;
	public var Lo:Int64;

	public function new(Hi:Int64, Lo:Int64) {
		this.Hi = Hi;
		this.Lo = Lo;
	}

	// Bytes returns the uint128 as an array of bytes in canonical form (big-endian encoded).
	public function Bytes():haxe.io.Bytes {
		final b = haxe.io.Bytes.alloc(16);
		for (i in 0...4) {
			b.set(i, (Hi.high >>> (24 - 8 * i)) & 0xff);
			b.set(4 + i, (Hi.low >>> (24 - 8 * i)) & 0xff);
			b.set(8 + i, (Lo.high >>> (24 - 8 * i)) & 0xff);
			b.set(12 + i, (Lo.low >>> (24 - 8 * i)) & 0xff);
		}
		return b;
	}
}
