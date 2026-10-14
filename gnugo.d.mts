/** Options for {@link createGnuGo}. Every field is optional. */
export interface GnuGoOptions {
  /** The contents of gnugo.wasm. If given, the module does not fetch it. */
  wasmBinary?: ArrayBuffer | Uint8Array;
  /** Returns the URL to fetch for `path` (always "gnugo.wasm"). Default: next to gnugo.mjs. */
  locateFile?: (path: string, scriptDirectory: string) => string;
  /**
   * Instantiates the module yourself, for example from a cached
   * `WebAssembly.Module`. Call `receiveInstance` when the instance is ready.
   */
  instantiateWasm?: (
    imports: WebAssembly.Imports,
    receiveInstance: (instance: WebAssembly.Instance) => void,
  ) => void;
  /** Called for each byte that GNU Go reads from stdin. Return `null` at end of input. */
  stdin?: () => number | null;
  /** Called for each byte that GNU Go writes to stdout. */
  stdout?: (byte: number) => void;
  /** Called for each byte that GNU Go writes to stderr. */
  stderr?: (byte: number) => void;
  /** Called if the module aborts, for example on a failed assertion. */
  onAbort?: (reason: unknown) => void;
}

/** A GNU Go instance. Each instance runs `main` once. */
export interface GnuGoModule {
  /**
   * Runs GNU Go's `main` with `args` (without the program name) and returns
   * its exit status. Throws if the module aborts.
   *
   * With `["--mode", "gtp"]`, GNU Go reads GTP commands from stdin until end
   * of input, then returns.
   */
  callMain(args?: string[]): number;
}

/** Loads and instantiates GNU Go. */
export default function createGnuGo(options?: GnuGoOptions): Promise<GnuGoModule>;
