package go;

#if tshx_parallel
import haxe.atomic.AtomicInt;
import sys.thread.Condition;
import sys.thread.Mutex;
import sys.thread.Thread;

// PORT: hxmc (-D tshx-parallel) — the goroutines of Go's parallel work groups: a pool of threads that
// run queued functions (ts.core.ParallelWorkGroup), and the running thread's slot, which indexes the
// per-thread state that Go keeps in sync.Pools or on the stack (pooled hashers, buffers, binders).
class Par {
	// 0 on the main thread, 1..threads() on the pool's workers (a copy per thread, zero in a new one)
	@:hxmc.threadLocal public static var slot:Int;
	// slots for the per-thread state: the main thread and at most SLOTS - 1 workers
	public static inline final SLOTS = 64;

	// the lazily computed fields of shared objects (Go's sync.Onces of the program)
	public static final onceMutex = new Mutex();
	// the package-level lazies (Go's sync.OnceValue package vars) built from constant data: a leaf lock, held only
	// while one is built (no other lock is taken under it but go.Regexp's pool lock)
	public static final lazyMutex = new Mutex();

	static final tasks = new TaskQueue();
	static final startMutex = new Mutex();
	static final started = new AtomicInt(0);
	static var count = 0;

	// the pool's size: TSHX_THREADS, else 4 (Go's default number of checkers)
	public static function threads():Int {
		if (count == 0) {
			final v = Sys.getEnv("TSHX_THREADS");
			final n = v == null ? 4 : Std.parseInt(v);
			count = n == null || n < 1 ? 1 : n >= SLOTS ? SLOTS - 1 : n;
		}
		return count;
	}

	// runs fn on a worker
	public static function submit(fn:() -> Void):Void {
		if (started.load() == 0)
			start();
		tasks.add(fn);
	}

	// runs one queued function on this thread, if there is one (a thread waiting for its group helps)
	public static function tryRun():Bool {
		final fn = tasks.pop(false);
		if (fn == null)
			return false;
		fn();
		return true;
	}

	static function start():Void {
		startMutex.acquire();
		if (started.load() == 0) {
			for (i in 1...threads() + 1)
				Thread.create(() -> {
					slot = i;
					while (true)
						tasks.pop(true)();
				});
			started.store(1);
		}
		startMutex.release();
	}
}

// PORT: perf — the pool's FIFO queue: sys.thread.Deque's pop is Array.shift (a copy of the whole queue
// under its lock; t3code-server queues ~220k parse tasks); here the front is an index, and the array is
// compacted when the consumed part is at least half of it.
private class TaskQueue {
	final cond = new Condition();
	var items:Array<() -> Void> = [];
	var head = 0;

	public function new() {}

	public function add(fn:() -> Void):Void {
		cond.acquire();
		items.push(fn);
		cond.signal();
		cond.release();
	}

	// the front function, or (block false) null when there is none
	public function pop(block:Bool):Null<() -> Void> {
		cond.acquire();
		while (head == items.length) {
			if (!block) {
				cond.release();
				return null;
			}
			cond.wait();
		}
		final fn = items[head];
		items[head] = null;
		head++;
		if (head == items.length) {
			items.resize(0);
			head = 0;
		} else if (head >= 1024 && head * 2 >= items.length) {
			items = items.slice(head);
			head = 0;
		}
		cond.release();
		return fn;
	}
}
#end
