package ts.core;

// Port of watchoptions.go.
class WatchOptions {
	public var Interval:Null<Int> = null; // json:"watchInterval"
	public var FileKind:WatchFileKind = WatchFileKindNone; // json:"watchFile"
	public var DirectoryKind:WatchDirectoryKind = WatchDirectoryKindNone; // json:"watchDirectory"
	public var FallbackPolling:PollingKind = PollingKindNone; // json:"fallbackPolling"
	public var SyncWatchDir:Tristate = TSUnknown; // json:"synchronousWatchDirectory"
	public var ExcludeDir:Null<Array<String>> = null; // json:"excludeDirectories"
	public var ExcludeFiles:Null<Array<String>> = null; // json:"excludeFiles"

	public function new() {}

	// PORT: time.Duration (int64 nanoseconds) → Float nanoseconds (exact up to 2^53).
	// Nil receiver: `inline` with a `this == null` check like the Go `w != nil` check.
	public inline function WatchInterval():Float {
		var watchInterval = 2000 * 1e6; // 2000 * time.Millisecond
		if (this != null && this.Interval != null) {
			watchInterval = (this.Interval : Int) * 1e6; // time.Duration(*w.Interval) * time.Millisecond
		}
		return watchInterval;
	}
}

enum abstract WatchFileKind(Int) from Int to Int {
	// PORT: Go integer ordering of the enum values.
	@:op(A < B) static function lt(a:WatchFileKind, b:WatchFileKind):Bool;
	@:op(A <= B) static function lte(a:WatchFileKind, b:WatchFileKind):Bool;
	@:op(A > B) static function gt(a:WatchFileKind, b:WatchFileKind):Bool;
	@:op(A >= B) static function gte(a:WatchFileKind, b:WatchFileKind):Bool;

	var WatchFileKindNone = 0;
	var WatchFileKindFixedPollingInterval = 1;
	var WatchFileKindPriorityPollingInterval = 2;
	var WatchFileKindDynamicPriorityPolling = 3;
	var WatchFileKindFixedChunkSizePolling = 4;
	var WatchFileKindUseFsEvents = 5;
	var WatchFileKindUseFsEventsOnParentDirectory = 6;
}

enum abstract WatchDirectoryKind(Int) from Int to Int {
	// PORT: Go integer ordering of the enum values.
	@:op(A < B) static function lt(a:WatchDirectoryKind, b:WatchDirectoryKind):Bool;
	@:op(A <= B) static function lte(a:WatchDirectoryKind, b:WatchDirectoryKind):Bool;
	@:op(A > B) static function gt(a:WatchDirectoryKind, b:WatchDirectoryKind):Bool;
	@:op(A >= B) static function gte(a:WatchDirectoryKind, b:WatchDirectoryKind):Bool;

	var WatchDirectoryKindNone = 0;
	var WatchDirectoryKindUseFsEvents = 1;
	var WatchDirectoryKindFixedPollingInterval = 2;
	var WatchDirectoryKindDynamicPriorityPolling = 3;
	var WatchDirectoryKindFixedChunkSizePolling = 4;
}

enum abstract PollingKind(Int) from Int to Int {
	// PORT: Go integer ordering of the enum values.
	@:op(A < B) static function lt(a:PollingKind, b:PollingKind):Bool;
	@:op(A <= B) static function lte(a:PollingKind, b:PollingKind):Bool;
	@:op(A > B) static function gt(a:PollingKind, b:PollingKind):Bool;
	@:op(A >= B) static function gte(a:PollingKind, b:PollingKind):Bool;

	var PollingKindNone = 0;
	var PollingKindFixedInterval = 1;
	var PollingKindPriorityInterval = 2;
	var PollingKindDynamicPriority = 3;
	var PollingKindFixedChunkSize = 4;
}
