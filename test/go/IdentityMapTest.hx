package go;

// go.IdentityMap: identity keys (not structural equality), deletion, re-insertion, growth with
// deletions in between, insertion-ordered (deterministic) iteration, copy and clear.
class IdentityMapTest {
	public static function run() {
		T.run("TestIdentityMap", () -> {
			final m = new IdentityMap<Key, Int>();
			final a = new Key(1), a2 = new Key(1);
			T.eq(false, m.exists(a));
			T.eq(null, m.get(a));
			T.eq(false, m.remove(a));
			T.eq(true, m.add(a, 10));
			T.eq(false, m.add(a, 11));
			T.eq(11, m.get(a));
			T.eq(false, m.exists(a2)); // identity, not equality
			m.set(a2, 20);
			T.eq(2, m.size());
			T.eq(11, m.get(a));
			T.eq(20, m.get(a2));
			T.eq(true, m.remove(a));
			T.eq(false, m.remove(a));
			T.eq(false, m.exists(a));
			T.eq(1, m.size());
			m.set(a, 30); // re-inserted: goes to the end
			T.eq("2,1", [for (k in m.keys()) k.id + (k == a ? 0 : 1)].join(","));
			T.eq("20,30", [for (v in m) v].join(","));
		});
		T.run("TestIdentityMapOrder", () -> {
			// Many keys, deletions interleaved with growth; iteration must follow insertion order.
			final m = new IdentityMap<Key, Int>();
			final ref = new Array<Key>();
			final all = [for (i in 0...5000) new Key(i)];
			for (i in 0...5000) {
				m.set(all[i], i);
				ref.push(all[i]);
				if (i % 3 == 2) {
					final victim = all[i - 2 - (i % 7 == 0 ? 0 : 1) + 1];
					if (m.remove(victim))
						ref.remove(victim);
				}
			}
			T.eq(ref.length, m.size());
			var ok = true;
			for (i in 0...5000)
				if (m.exists(all[i]) != (ref.indexOf(all[i]) >= 0) || (m.exists(all[i]) && m.get(all[i]) != i))
					ok = false;
			T.isTrue(ok, "membership after deletions");
			T.eq([for (k in ref) k.id].join(","), [for (k in m.keys()) k.id].join(","));
			T.eq([for (k in ref) k.id].join(","), [for (kv in m.keyValueIterator()) kv.value].join(","));
			// Delete everything but every 10th, then reinsert: order = survivors, then reinserted.
			for (k in ref)
				if (k.id % 10 != 0)
					m.remove(k);
			final survivors = [for (k in ref) if (k.id % 10 == 0) k];
			T.eq(survivors.length, m.size());
			m.set(all[1], -1);
			final keys = [for (k in m.keys()) k];
			T.eq(survivors.length + 1, keys.length);
			T.isTrue(keys[keys.length - 1] == all[1], "reinserted key last");
			final c = m.copy();
			m.remove(all[1]);
			T.eq(true, c.exists(all[1]));
			T.eq(-1, c.get(all[1]));
			T.eq([for (k in m.keys()) k.id].join(","), [for (k in c.keys()) if (k != all[1]) k.id].join(","));
			// Changing the map while iterating a snapshot.
			for (k in m.keys())
				m.remove(k);
			T.eq(0, m.size());
			c.clear();
			T.eq(0, c.size());
			T.eq(false, c.exists(all[0]));
			c.set(all[0], 5);
			T.eq(5, c.get(all[0]));
		});
	}
}

private class Key {
	public final id:Int;

	public function new(id:Int) {
		this.id = id;
	}
}
