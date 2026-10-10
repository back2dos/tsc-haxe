// Summarize a V8 .cpuprofile (node --cpu-prof): self time per function (top N) and, with
// --inclusive, inclusive time per function. Usage: node tools/perf/cpuprofile.js <file> [N] [--inclusive]
const fs = require("fs");
const [file, nArg, mode] = process.argv.slice(2);
const N = +(nArg || 30);
const p = JSON.parse(fs.readFileSync(file, "utf8"));
const byId = new Map(p.nodes.map(n => [n.id, n]));
const parent = new Map();
for (const n of p.nodes) for (const c of n.children || []) parent.set(c, n.id);
const dt = new Map();
for (let i = 0; i < p.samples.length; i++) dt.set(p.samples[i], (dt.get(p.samples[i]) || 0) + (p.timeDeltas[i] || 0));
const total = [...dt.values()].reduce((a, b) => a + b, 0);
const key = n => `${n.callFrame.functionName || "(anon)"} ${n.callFrame.url.split("/").pop()}:${n.callFrame.lineNumber + 1}`;
const agg = new Map();
if (mode === "--inclusive") {
	for (const [id, t] of dt) {
		const seen = new Set();
		for (let c = id; c != null; c = parent.get(c)) {
			const k = key(byId.get(c));
			if (!seen.has(k)) { seen.add(k); agg.set(k, (agg.get(k) || 0) + t); }
		}
	}
} else for (const [id, t] of dt) { const k = key(byId.get(id)); agg.set(k, (agg.get(k) || 0) + t); }
console.log(`total ${(total / 1e6).toFixed(2)} s`);
for (const [k, t] of [...agg].sort((a, b) => b[1] - a[1]).slice(0, N))
	console.log(`${(100 * t / total).toFixed(1).padStart(5)}%  ${k}`);
