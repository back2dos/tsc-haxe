package ts.core;

// Port of bfs.go (types and methods; the funcs are in Core.hx).

class BreadthFirstSearchResult<N> {
	public var Stopped:Bool = false;
	public var Path:Null<Array<N>> = null;

	public function new(Stopped:Bool = false, ?Path:Array<N>) {
		this.Stopped = Stopped;
		this.Path = Path;
	}
}

// Go unexported breadthFirstSearchJob.
class BreadthFirstSearchJob<N> {
	public var node:N;
	public var parent:Null<BreadthFirstSearchJob<N>> = null;

	public function new(node:N, ?parent:BreadthFirstSearchJob<N>) {
		this.node = node;
		this.parent = parent;
	}
}

class BreadthFirstSearchLevel<K, N> {
	@:allow(ts.core)
	var jobs:Null<OrderedMap<K, BreadthFirstSearchJob<N>>> = null;

	@:allow(ts.core)
	function new(jobs:OrderedMap<K, BreadthFirstSearchJob<N>>) {
		this.jobs = jobs;
	}

	public function Has(key:K):Bool {
		return this.jobs.Has(key);
	}

	public function Delete(key:K):Void {
		this.jobs.Delete(key);
	}

	public function Range(f:(node:N) -> Bool):Void {
		for (job in this.jobs.Values()) {
			if (!f(job.node)) {
				return;
			}
		}
	}
}

// Go `BreadthFirstSearchOptions[K, N]{}` → `new BreadthFirstSearchOptions<K, N>()`.
class BreadthFirstSearchOptions<K, N> {
	// Visited is a set of nodes that have already been visited.
	// If nil, a new set will be created.
	public var Visited:Null<SyncSet<K>> = null;
	// PreprocessLevel is a function that, if provided, will be called
	// before each level, giving the caller an opportunity to remove nodes.
	public var PreprocessLevel:Null<(BreadthFirstSearchLevel<K, N>) -> Void> = null;

	public function new(?Visited:SyncSet<K>, ?PreprocessLevel:(BreadthFirstSearchLevel<K, N>) -> Void) {
		this.Visited = Visited;
		this.PreprocessLevel = PreprocessLevel;
	}
}

// Go local type `result` of BreadthFirstSearchParallelEx.
class BreadthFirstSearchParallelExResult<K, N> {
	public var stop:Bool = false;
	public var job:Null<BreadthFirstSearchJob<N>> = null;
	public var next:Null<OrderedMap<K, BreadthFirstSearchJob<N>>> = null;

	public function new(stop:Bool, job:Null<BreadthFirstSearchJob<N>>, next:Null<OrderedMap<K, BreadthFirstSearchJob<N>>>) {
		this.stop = stop;
		this.job = job;
		this.next = next;
	}
}
