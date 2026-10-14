// Checks the published interface (dist/gnugo.mjs): the stdin and stdout
// options and callMain. GNU Go's own correctness is checked by test/regress.sh.
import createGnuGo from "../dist/gnugo.mjs";
import assert from "node:assert/strict";

const input = new TextEncoder().encode("boardsize 19\nplay B D4\ndragon_status D4\n");
let pos = 0;
const output: number[] = [];

const gnugo = await createGnuGo({
  stdin: () => (pos < input.length ? input[pos++] : null),
  stdout: (byte) => output.push(byte),
});

assert.equal(gnugo.callMain(["--mode", "gtp"]), 0);
assert.equal(new TextDecoder().decode(new Uint8Array(output)), "= \n\n= \n\n= alive\n\n");
console.log("smoke test passed");
