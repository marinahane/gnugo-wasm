// Runs the same GTP script through the native build and the WASM build, and
// checks that stdout is byte-identical. Positions are sent as `play` commands.
// Usage: node test/compare.mts <native-gnugo> <sgf>...
import { runGtp } from "./run.mts";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

const [native, ...sgfs] = process.argv.slice(2);
const letters = "abcdefghjklmnopqrst";

function movesFromSgf(text: string): string[] {
  return [...text.matchAll(/;\s*([BW])\[([a-s]{0,2})\]/g)].map(([, color, xy]) => {
    if (xy.length !== 2) return `play ${color} pass`;
    const col = letters[xy.charCodeAt(0) - 97].toUpperCase();
    const row = 19 - (xy.charCodeAt(1) - 97);
    return `play ${color} ${col}${row}`;
  });
}

let failures = 0;
for (const sgf of sgfs) {
  const moves = movesFromSgf(readFileSync(sgf, "utf8"));
  for (const n of [60, 120, 180, 240]) {
    if (n > moves.length) continue;
    const script = [
      "boardsize 19",
      "clear_board",
      "komi 6.5",
      ...moves.slice(0, n),
      "dragon_data",
      "dragon_status",
      "initial_influence black influence_regions",
      "reg_genmove black",
    ];
    let t = performance.now();
    const nativeOut = execFileSync(native, ["--mode", "gtp"], {
      input: script.join("\n") + "\n",
      maxBuffer: 64 << 20,
    }).toString();
    const nativeMs = performance.now() - t;
    t = performance.now();
    const wasm = await runGtp(script);
    const wasmMs = performance.now() - t;
    const same = wasm.stdout === nativeOut && wasm.exitCode === 0;
    if (!same) failures++;
    console.log(
      `${sgf.split("/").pop()} @${n}: ${same ? "IDENTICAL" : "DIFFERENT"}  ` +
        `native ${nativeMs.toFixed(0)} ms, wasm ${wasmMs.toFixed(0)} ms`,
    );
  }
}
if (failures) {
  console.error(`${failures} position(s) differ`);
  process.exit(1);
}
