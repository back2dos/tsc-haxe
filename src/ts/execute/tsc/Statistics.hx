package ts.execute.tsc;

// Port of statistics.go (types and methods; package-level funcs are in Tsc.hx).

// Go type `tableRow` (unexported).
class TableRow {
	public var name:std.String = "";
	public var value:std.String = "";

	public function new(name:std.String, value:std.String) {
		this.name = name;
		this.value = value;
	}
}

// Go type `table` (unexported).
class Table {
	public var rows:Null<Array<TableRow>> = null;

	public function new() {}

	// PORT: `value any` is a time.Duration (Int64), an int, or a string; Durations are passed through
	// addDuration because Int64 is not distinguishable at run time on every target.
	public function add(name:std.String, value:Any):Void {
		if (this.rows == null)
			this.rows = [];
		this.rows.push(new TableRow(name, Fmt.Sprint([value])));
	}

	public function addDuration(name:std.String, d:Duration):Void {
		this.add(name, Tsc.formatDuration(d));
	}

	public function print(w:Writer):Void {
		var nameWidth = 0;
		var valueWidth = 0;
		for (r in this.rows) {
			nameWidth = Std.int(Math.max(nameWidth, r.name.length));
			valueWidth = Std.int(Math.max(valueWidth, r.value.length));
		}

		for (r in this.rows) {
			Fmt.Fprintf(w, "%-*s %*s\n", [nameWidth + 1, r.name + ":", valueWidth, r.value]);
		}
	}
}

class Statistics {
	public var isAggregate:Bool = false;
	public var Projects:Int = 0;
	public var ProjectsBuilt:Int = 0;
	public var TimestampUpdates:Int = 0;
	public var files:Int = 0;
	public var lines:Int = 0;
	public var identifiers:Int = 0;
	public var symbols:Int = 0;
	public var types:Int = 0;
	public var instantiations:Int = 0;
	// PORT: uint64 → Float (exact up to 2^53).
	public var memoryUsed:Float = 0.0;
	public var memoryAllocs:Float = 0.0;
	public var compileTimes:Null<CompileTimes> = null;

	public function new() {}

	public function Report(w:Writer, testing:Null<CommandLineTesting>):Void {
		if (testing != null) {
			testing.OnStatisticsStart(w);
		}
		final table = new Table();
		var prefix = "";

		if (this.isAggregate) {
			prefix = "Aggregate ";
			table.add("Projects in scope", this.Projects);
			table.add("Projects built", this.ProjectsBuilt);
			table.add("Timestamps only updates", this.TimestampUpdates);
		}
		table.add(prefix + "Files", this.files);
		table.add(prefix + "Lines", this.lines);
		table.add(prefix + "Identifiers", this.identifiers);
		table.add(prefix + "Symbols", this.symbols);
		table.add(prefix + "Types", this.types);
		table.add(prefix + "Instantiations", this.instantiations);
		table.add(prefix + "Memory used", Tsc.formatUint(Math.ffloor(this.memoryUsed / 1024)) + "K");
		table.add(prefix + "Memory allocs", Tsc.formatUint(this.memoryAllocs));
		if (this.compileTimes.ConfigTime != 0) {
			table.addDuration(prefix + "Config time", this.compileTimes.ConfigTime);
		}
		if (this.compileTimes.BuildInfoReadTime != 0) {
			table.addDuration(prefix + "BuildInfo read time", this.compileTimes.BuildInfoReadTime);
		}
		table.addDuration(prefix + "Parse time", this.compileTimes.ParseTime);
		if (this.compileTimes.bindTime != 0) {
			table.addDuration(prefix + "Bind time", this.compileTimes.bindTime);
		}
		if (this.compileTimes.checkTime != 0) {
			table.addDuration(prefix + "Check time", this.compileTimes.checkTime);
		}
		if (this.compileTimes.emitTime != 0) {
			table.addDuration(prefix + "Emit time", this.compileTimes.emitTime);
		}
		if (this.compileTimes.ChangesComputeTime != 0) {
			table.addDuration(prefix + "Changes compute time", this.compileTimes.ChangesComputeTime);
		}
		table.addDuration(prefix + "Total time", this.compileTimes.totalTime);
		table.print(w);
		if (testing != null) {
			testing.OnStatisticsEnd(w);
		}
	}

	public function Aggregate(stat:Statistics):Void {
		this.isAggregate = true;
		if (this.compileTimes == null) {
			this.compileTimes = new CompileTimes();
		}
		// Aggregate statistics
		this.files += stat.files;
		this.lines += stat.lines;
		this.identifiers += stat.identifiers;
		this.symbols += stat.symbols;
		this.types += stat.types;
		this.instantiations += stat.instantiations;
		this.memoryUsed += stat.memoryUsed;
		this.memoryAllocs += stat.memoryAllocs;
		this.compileTimes.ConfigTime += stat.compileTimes.ConfigTime;
		this.compileTimes.BuildInfoReadTime += stat.compileTimes.BuildInfoReadTime;
		this.compileTimes.ParseTime += stat.compileTimes.ParseTime;
		this.compileTimes.bindTime += stat.compileTimes.bindTime;
		this.compileTimes.checkTime += stat.compileTimes.checkTime;
		this.compileTimes.emitTime += stat.compileTimes.emitTime;
		this.compileTimes.ChangesComputeTime += stat.compileTimes.ChangesComputeTime;
	}

	public function SetTotalTime(totalTime:Duration):Void {
		if (this.compileTimes == null) {
			this.compileTimes = new CompileTimes();
		}
		this.compileTimes.totalTime = totalTime;
	}
}
