// One request = one fresh instance. GTP commands go in on stdin; at end of
// input GNU Go's GTP loop ends, main returns, and all of stdout comes back.
import createGnuGo from "../dist/gnugo.mjs";
import { readFileSync } from "node:fs";

const wasmBinary = readFileSync(new URL("../dist/gnugo.wasm", import.meta.url));

export interface GtpResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

export async function runGtp(commands: string[], args: string[] = []): Promise<GtpResult> {
  const input = new TextEncoder().encode(commands.join("\n") + "\n");
  let pos = 0;
  const out: number[] = [];
  const err: number[] = [];
  const gnugo = await createGnuGo({
    wasmBinary,
    stdin: () => (pos < input.length ? input[pos++] : null),
    stdout: (byte) => out.push(byte),
    stderr: (byte) => err.push(byte),
  });
  const exitCode = gnugo.callMain(["--mode", "gtp", ...args]);
  return {
    stdout: new TextDecoder().decode(new Uint8Array(out)),
    stderr: new TextDecoder().decode(new Uint8Array(err)),
    exitCode,
  };
}
