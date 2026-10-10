package ts.execute.build;

// Port of uptodatestatus.go.

enum abstract UpToDateStatusType(Int) from Int to Int {
	// Errors:

	// config file was not found
	var upToDateStatusTypeConfigFileNotFound = 0;
	// found errors during build
	var upToDateStatusTypeBuildErrors = 1;
	// did not build because upstream project has errors - and we have option to stop build on upstream errors
	var upToDateStatusTypeUpstreamErrors = 2;

	// Its all good, no work to do
	var upToDateStatusTypeUpToDate = 3;

	// Pseudo-builds - touch timestamps, no actual build:

	// The project appears out of date because its upstream inputs are newer than its outputs,
	// but all of its outputs are actually newer than the previous identical outputs of its (.d.ts) inputs.
	// This means we can Pseudo-build (just touch timestamps), as if we had actually built this project.
	var upToDateStatusTypeUpToDateWithUpstreamTypes = 4;
	// The project appears up to date and even though input file changed, its text didnt so just need to update timestamps
	var upToDateStatusTypeUpToDateWithInputFileText = 5;

	// Needs build:

	// input file is missing
	var upToDateStatusTypeInputFileMissing = 6;
	// output file is missing
	var upToDateStatusTypeOutputMissing = 7;
	// input file is newer than output file
	var upToDateStatusTypeInputFileNewer = 8;
	// build info is out of date as we need to emit some files
	var upToDateStatusTypeOutOfDateBuildInfoWithPendingEmit = 9;
	// build info indicates that project has errors and they need to be reported
	var upToDateStatusTypeOutOfDateBuildInfoWithErrors = 10;
	// build info options indicate there is work to do based on changes in options
	var upToDateStatusTypeOutOfDateOptions = 11;
	// file was root when built but not any more
	var upToDateStatusTypeOutOfDateRoots = 12;
	// buildInfo.version mismatch with current ts version
	var upToDateStatusTypeTsVersionOutputOfDate = 13;
	// build because --force was specified
	var upToDateStatusTypeForceBuild = 14;

	// solution file
	var upToDateStatusTypeSolution = 15;
}

class InputOutputName {
	public var input:std.String = "";
	public var output:std.String = "";

	public function new(input:std.String = "", output:std.String = "") {
		this.input = input;
		this.output = output;
	}
}

// PORT: Go value struct; never mutated after construction (assignments replace the whole value).
class FileAndTime {
	public var file:std.String = "";
	public var time:Time = Time.Zero();

	public function new(file:std.String = "", ?time:Time) {
		this.file = file;
		this.time = time == null ? Time.Zero() : time;
	}
}

class InputOutputFileAndTime {
	public var input:FileAndTime = new FileAndTime();
	public var output:FileAndTime = new FileAndTime();
	public var buildInfo:std.String = "";

	public function new(input:FileAndTime, output:FileAndTime, buildInfo:std.String) {
		this.input = input;
		this.output = output;
		this.buildInfo = buildInfo;
	}
}

class UpstreamErrors {
	public var ref:std.String = "";
	public var refHasUpstreamErrors:Bool = false;

	public function new(ref:std.String = "", refHasUpstreamErrors:Bool = false) {
		this.ref = ref;
		this.refHasUpstreamErrors = refHasUpstreamErrors;
	}
}

class UpToDateStatus {
	public var kind:UpToDateStatusType = upToDateStatusTypeConfigFileNotFound;
	// PORT: `data any` holds a string, *inputOutputName, *inputOutputFileAndTime or *upstreamErrors.
	public var data:Any = null;

	public function new(kind:UpToDateStatusType, ?data:Any) {
		this.kind = kind;
		this.data = data;
	}

	public function isError():Bool {
		return switch (this.kind) {
			case upToDateStatusTypeConfigFileNotFound, upToDateStatusTypeBuildErrors, upToDateStatusTypeUpstreamErrors:
				true;
			default:
				false;
		}
	}

	public function isPseudoBuild():Bool {
		return switch (this.kind) {
			case upToDateStatusTypeUpToDateWithUpstreamTypes, upToDateStatusTypeUpToDateWithInputFileText:
				true;
			default:
				false;
		}
	}

	public function inputOutputFileAndTime():Null<InputOutputFileAndTime> {
		return Std.isOfType(this.data, InputOutputFileAndTime) ? (cast this.data : InputOutputFileAndTime) : null;
	}

	public function inputOutputName():Null<InputOutputName> {
		return Std.isOfType(this.data, InputOutputName) ? (cast this.data : InputOutputName) : null;
	}

	public function oldestOutputFileName():std.String {
		if (!this.isPseudoBuild() && this.kind != upToDateStatusTypeUpToDate) {
			throw "only valid for up to date status of pseudo-build or up to date";
		}

		final inputOutputFileAndTime = this.inputOutputFileAndTime();
		if (inputOutputFileAndTime != null) {
			return inputOutputFileAndTime.output.file;
		}
		final inputOutputName = this.inputOutputName();
		if (inputOutputName != null) {
			return inputOutputName.output;
		}
		return (cast this.data : std.String);
	}

	public function upstreamErrors():UpstreamErrors {
		return (cast this.data : UpstreamErrors);
	}
}
