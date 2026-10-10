package go;

import haxe.Int64;

// time.Duration: nanoseconds.
typedef Duration = Int64;

// Shim for the parts of Go package time used by the port (vfs: ModTime, Chtimes, test clocks).
// PORT: time.Time is an immutable value: seconds since the Unix epoch (Int64) + nanoseconds.
// No monotonic clock reading and no location; Equal/Before/After compare the instant.
// The zero Time (`time.Time{}`) is January 1, year 1, 00:00:00 UTC, as in Go.
final class Time {
	// Seconds from 0001-01-01 to 1970-01-01 (Go unixToInternal).
	static final unixToInternal:Int64 = Int64.parseString("-62135596800");

	public final sec:Int64; // Unix seconds
	public final nsec:Int; // 0 <= nsec < 1e9

	public function new(sec:Int64, nsec:Int) {
		this.sec = sec;
		this.nsec = nsec;
	}

	// time.Time{}
	public static function Zero():Time {
		return new Time(unixToInternal, 0);
	}

	// time.Now()
	public static function Now():Time {
		final t = Sys.time();
		final s = std.Math.ffloor(t);
		var ns = Std.int((t - s) * 1e9);
		if (ns < 0)
			ns = 0;
		if (ns >= 1000000000)
			ns = 999999999;
		return new Time(Int64.fromFloat(s), ns);
	}

	// time.Unix(sec, nsec)
	public static function Unix(sec:Int64, nsec:Int64):Time {
		final billion = Int64.ofInt(1000000000);
		if (nsec < 0 || nsec >= billion) {
			var n = nsec / billion;
			sec += n;
			nsec -= n * billion;
			if (nsec < 0) {
				nsec += billion;
				sec--;
			}
		}
		return new Time(sec, Int64.toInt(nsec));
	}

	// time.UnixMilli(msec)
	public static function UnixMilli(msec:Int64):Time {
		return Unix(msec / 1000, (msec % 1000) * 1000000);
	}

	// time.Since(t)
	public static function Since(t:Time):Duration {
		return Now().Sub(t);
	}

	// float64(d.Nanoseconds()) for a Duration (int64 nanoseconds; exact up to 2^53).
	public static function DurationFloat64(d:Duration):Float {
		return d.high * 4294967296.0 + (d.low < 0 ? d.low + 4294967296.0 : d.low);
	}

	public function IsZero():Bool {
		return sec == unixToInternal && nsec == 0;
	}

	public function Equal(u:Time):Bool {
		return sec == u.sec && nsec == u.nsec;
	}

	public function Before(u:Time):Bool {
		return sec < u.sec || (sec == u.sec && nsec < u.nsec);
	}

	public function After(u:Time):Bool {
		return sec > u.sec || (sec == u.sec && nsec > u.nsec);
	}

	// t.Compare(u)
	public function Compare(u:Time):Int {
		return Before(u) ? -1 : (After(u) ? 1 : 0);
	}

	// PORT: no overflow saturation (Go clamps to min/max Duration).
	public function Sub(u:Time):Duration {
		return (sec - u.sec) * 1000000000 + (nsec - u.nsec);
	}

	public function Add(d:Duration):Time {
		return Unix(sec, Int64.ofInt(nsec) + d);
	}

	// t.Unix() / t.UnixMilli(). PORT: `_` suffix — Haxe cannot have a static and an instance
	// member with the same name (time.Unix / time.UnixMilli are the statics above).
	public function Unix_():Int64 {
		return sec;
	}

	public function UnixNano():Int64 {
		return sec * 1000000000 + nsec;
	}

	public function UnixMilli_():Int64 {
		return sec * 1000 + Std.int(nsec / 1000000);
	}

	// Seconds since the Unix epoch as a Float (for OS calls).
	public function UnixFloat():Float {
		return sec.high * 4294967296.0 + (sec.low < 0 ? sec.low + 4294967296.0 : sec.low) + nsec / 1e9;
	}

	public function toString():String {
		return 'Time(${Int64.toStr(sec)}s ${nsec}ns)';
	}
}
