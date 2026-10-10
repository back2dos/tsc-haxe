// Allocation profiler for hxcpp builds (tools/perf/build-fp.sh --alloc). Linked into the binary by
// tools/perf/g++-fp. Every GC allocation calls hxperf_alloc (patched hx/GC.h inline allocator, plus
// --wrap of hx::InternalNew / hx::InternalRealloc for strings and array buffers):
//  - exact count and bytes per class name (the generated code passes the Haxe class name);
//  - every HXPERF_SAMPLE bytes (default 65536) the frame-pointer call stack, weighted by bytes.
// At exit it writes $HXPERF_OUT (default hxperf-alloc.txt); tools/perf/allocreport.py symbolizes it.
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <unordered_map>
#include <vector>
#include <algorithm>

namespace {
struct Counter { uint64_t count = 0, bytes = 0; };
const int kDepth = 24;
std::unordered_map<const char *, Counter> *byName;
std::unordered_map<std::string, uint64_t> *byStack;
uint64_t sample = 65536, sinceSample = 0;
uintptr_t stackLo = 0, stackHi = 0, base = 0;
bool ready = false, inHook = false;

void dump() {
	const char *out = getenv("HXPERF_OUT");
	FILE *f = fopen(out ? out : "hxperf-alloc.txt", "w");
	if (!f) return;
	fprintf(f, "sample %llu\n", (unsigned long long)sample);
	std::unordered_map<std::string, Counter> merged; // the same name can come from several literals
	for (auto &e : *byName) {
		Counter &c = merged[e.first ? e.first : "(unnamed)"];
		c.count += e.second.count; c.bytes += e.second.bytes;
	}
	for (auto &e : merged)
		fprintf(f, "class %llu %llu %s\n", (unsigned long long)e.second.count, (unsigned long long)e.second.bytes, e.first.c_str());
	for (auto &e : *byStack) {
		fprintf(f, "stack %llu", (unsigned long long)e.second);
		const uintptr_t *pc = (const uintptr_t *)e.first.data();
		for (size_t i = 1; i < e.first.size() / sizeof(uintptr_t); i++) fprintf(f, " %lx", (unsigned long)(pc[i] - base));
		fprintf(f, " | %s\n", pc[0] ? (const char *)pc[0] : "(unnamed)");
	}
	fclose(f);
}

void init() {
	byName = new std::unordered_map<const char *, Counter>();
	byStack = new std::unordered_map<std::string, uint64_t>();
	if (const char *s = getenv("HXPERF_SAMPLE")) sample = strtoull(s, 0, 10);
	pthread_attr_t a;
	void *addr; size_t size;
	pthread_getattr_np(pthread_self(), &a);
	pthread_attr_getstack(&a, &addr, &size);
	stackLo = (uintptr_t)addr; stackHi = stackLo + size;
	Dl_info info;
	dladdr((void *)&init, &info);
	base = (uintptr_t)info.dli_fbase;
	atexit(dump);
	ready = true;
}

__attribute__((noinline)) void record(uint64_t weight, const char *name) {
	uintptr_t pc[kDepth + 1];
	int n = 0;
	pc[n++] = (uintptr_t)name; // first entry: the class name of the sampled allocation
	uintptr_t *fp = (uintptr_t *)__builtin_frame_address(0);
	while (n <= kDepth && (uintptr_t)fp >= stackLo && (uintptr_t)fp < stackHi && ((uintptr_t)fp & 7) == 0) {
		uintptr_t ret = fp[1];
		if (!ret) break;
		pc[n++] = ret - 1; // inside the call instruction
		uintptr_t *next = (uintptr_t *)fp[0];
		if (next <= fp) break;
		fp = next;
	}
	(*byStack)[std::string((const char *)pc, n * sizeof(uintptr_t))] += weight;
}
} // namespace

extern "C" __attribute__((noinline)) void hxperf_alloc(int size, const char *name) {
	if (inHook) return;
	if (!ready) init();
	inHook = true;
	Counter &c = (*byName)[name];
	c.count++; c.bytes += size;
	sinceSample += size;
	if (sinceSample >= sample) { record(sinceSample, name); sinceSample = 0; }
	inHook = false;
}

extern "C" void *__real__ZN2hx11InternalNewEib(int, bool);
extern "C" void *__real__ZN2hx15InternalReallocEiPvib(int, void *, int, bool);
extern "C" __attribute__((noinline)) void *__wrap__ZN2hx11InternalNewEib(int size, bool isObject) {
	hxperf_alloc(size, isObject ? "(InternalNew object)" : "(InternalNew bytes: string/array buffer)");
	return __real__ZN2hx11InternalNewEib(size, isObject);
}
extern "C" __attribute__((noinline)) void *__wrap__ZN2hx15InternalReallocEiPvib(int from, void *data, int size, bool expand) {
	hxperf_alloc(size, "(InternalRealloc: array growth)");
	return __real__ZN2hx15InternalReallocEiPvib(from, data, size, expand);
}
