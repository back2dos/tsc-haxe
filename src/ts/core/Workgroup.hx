package ts.core;

// Port of workgroup.go (NewWorkGroup and NewThrottleGroup are in Core.hx).
// PORT: single-threaded port (PORTING.md §4). Every work group has the semantics of Go's
// singleThreadedWorkGroup: Queue appends, RunAndWait pops and runs the LAST queued function
// until the queue is empty (LIFO; functions queued while running are run too).
// parallelWorkGroup is not ported: NewWorkGroup always returns a singleThreadedWorkGroup.
interface WorkGroup {
	// Queue queues a function to run. It may be invoked immediately, or deferred until RunAndWait.
	// It is not safe to call Queue after RunAndWait has returned.
	function Queue(fn:() -> Void):Void;

	// RunAndWait runs all queued functions, blocking until they have all completed.
	function RunAndWait():Void;
}

class SingleThreadedWorkGroup implements WorkGroup {
	var done:Bool = false;
	var fns:Null<Array<() -> Void>> = null;

	public function new() {}

	public function Queue(fn:() -> Void):Void {
		if (this.done) {
			throw "Queue called after RunAndWait returned";
		}

		if (this.fns == null)
			this.fns = [];
		this.fns.push(fn);
	}

	public function RunAndWait():Void {
		// defer w.done.Store(true)
		try {
			while (true) {
				final fn = this.pop();
				if (fn == null) {
					break;
				}
				fn();
			}
		} catch (e:Dynamic) {
			this.done = true;
			throw e;
		}
		this.done = true;
	}

	function pop():Null<() -> Void> {
		if (this.fns == null || this.fns.length == 0) {
			return null;
		}
		// Go: fn := w.fns[end]; w.fns[end] = nil; w.fns = w.fns[:end]
		return this.fns.pop();
	}
}

// ThrottleGroup is like errgroup.Group but with global concurrency limiting via a semaphore.
// PORT: single-threaded: Go() queues the function, Wait() runs the queue like
// singleThreadedWorkGroup (LIFO) and returns the first error, like errgroup. The semaphore
// (Go `chan struct{}`) cannot limit anything in a single thread; it is kept but unused.
class ThrottleGroup {
	final semaphore:Any;
	final group:Array<() -> Null<Error>> = [];

	@:allow(ts.core)
	function new(semaphore:Any) {
		this.semaphore = semaphore;
	}

	// Go runs the given function in a new goroutine, but first acquires a slot from the semaphore.
	// The semaphore slot is released when the function completes.
	public function Go(fn:() -> Null<Error>):Void {
		this.group.push(fn);
	}

	// Wait waits for all goroutines to complete and returns the first error encountered, if any.
	public function Wait():Null<Error> {
		var err:Null<Error> = null;
		while (this.group.length > 0) {
			final fn = this.group.pop();
			final e = fn();
			if (e != null && err == null)
				err = e;
		}
		return err;
	}
}
