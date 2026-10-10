package ts.core;

// Port of stack.go. Go zero value `Stack[T]{}` → `new Stack<T>()`.
class Stack<T> {
	var data:Null<Array<T>> = null;

	public function new() {}

	public function Push(item:T):Void {
		if (data == null)
			data = [];
		data.push(item);
	}

	public function Pop():T {
		final l = data == null ? 0 : data.length;
		if (l == 0) {
			throw "stack is empty";
		}
		// PORT: Go zeroes the popped slot (for the GC) and reslices; Array.pop does both.
		return data.pop();
	}

	public function Peek():T {
		final l = data == null ? 0 : data.length;
		if (l == 0) {
			throw "stack is empty";
		}
		return data[l - 1];
	}

	public function Len():Int {
		return data == null ? 0 : data.length;
	}
}
