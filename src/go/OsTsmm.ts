// PORT: ts-- — go.OsTsmm on node (the native side of OsTsmm.hx in the portable mode): OsHxmc's API over node's fs.
// Plain TypeScript, not ts--; haxe-in-haxe's tsmm generator copies it into the program.
const fs = (): any => (globalThis as any).require("fs");

const names: { [k: string]: number } = {
	ENOENT: 2, EEXIST: 17, ENOTDIR: 20, EISDIR: 21, EACCES: 13, EPERM: 1, ENOTEMPTY: 39, ELOOP: 40, EINVAL: 22, EIO: 5,
	ENAMETOOLONG: 36, EBUSY: 16, EROFS: 30, EXDEV: 18
};

function code(e: any): number {
	const n = e == null ? undefined : names[e.code];
	return n === undefined ? 5 : n;
}

function attempt(f: () => void): number {
	try {
		f();
		return 0;
	} catch (e) {
		return code(e);
	}
}

export class OsTsmm {
	static realpathErrno: number = 0;
	static errname(e: number): string {
		for (const k of Object.keys(names)) if (names[k] === e) return k;
		return String(e);
	}
	// [errno] or [0, mode, size, mtime sec, mtime nsec]
	static stat(path: string, follow: boolean): number[] {
		try {
			const s = follow ? fs().statSync(path, { bigint: true }) : fs().lstatSync(path, { bigint: true });
			const ns: bigint = s.mtimeNs;
			return [0, Number(s.mode), Number(s.size), Number(ns / 1000000000n), Number(ns % 1000000000n)];
		} catch (e) {
			return [code(e)];
		}
	}
	static mkdir(path: string, perm: number): number { return attempt(() => fs().mkdirSync(path, perm)); }
	static unlink(path: string): number { return attempt(() => fs().unlinkSync(path)); }
	static rmdir(path: string): number { return attempt(() => fs().rmdirSync(path)); }
	static symlink(target: string, path: string): number { return attempt(() => fs().symlinkSync(target, path)); }
	static utimes(path: string, atime: number, mtime: number): number { return attempt(() => fs().utimesSync(path, atime, mtime)); }
	static realpath(path: string): string | null {
		try {
			const r: string = fs().realpathSync.native(path);
			OsTsmm.realpathErrno = 0;
			return r;
		} catch (e) {
			OsTsmm.realpathErrno = code(e);
			return null;
		}
	}
}
