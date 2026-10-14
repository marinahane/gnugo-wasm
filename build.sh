#!/bin/bash
# Builds GNU Go 3.8 to WebAssembly in two stages:
#   1. A native build, only to run the pattern generators (mkpat, mkeyes,
#      joseki, uncompress_fuseki, mkmcpat). Their output is C source.
#   2. emcc compiles the engine sources plus the generated pattern sources.
# Usage: ./build.sh [out-dir]   (default: dist)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
OUT=$(mkdir -p "${1:-$ROOT/dist}" && cd "${1:-$ROOT/dist}" && pwd)
WORK="$ROOT/build"
SRC="$WORK/gnugo-3.8"
NATIVE="$WORK/native"
WASMCFG="$WORK/wasm-config"
OBJ="$WORK/obj"
JOBS=$(getconf _NPROCESSORS_ONLN)

TARBALL_URL=https://ftp.gnu.org/gnu/gnugo/gnugo-3.8.tar.gz
TARBALL_SHA256=da68d7a65f44dcf6ce6e4e630b6f6dd9897249d34425920bfdd4e07ff1866a72
TARBALL="$ROOT/vendor/gnugo-3.8.tar.gz"

if [ ! -f "$TARBALL" ]; then
  mkdir -p "$ROOT/vendor"
  curl -sfL "$TARBALL_URL" -o "$TARBALL"
fi
echo "$TARBALL_SHA256  $TARBALL" | shasum -a 256 -c -

rm -rf "$WORK"
mkdir -p "$WORK" "$NATIVE" "$WASMCFG" "$OBJ"
# emconfigure runs its test programs with Node. Without this file, Node uses
# the repo's "type": "module" and the CommonJS test programs fail.
echo '{"type": "commonjs"}' >"$WORK/package.json"
tar -xzf "$TARBALL" -C "$WORK"
for p in "$ROOT"/patches/*.patch; do
  patch -d "$SRC" -p1 <"$p"
done

# GNU Go defines some globals in more than one file. Modern compilers reject
# that unless -fcommon is given.
echo "== stage 1: native pattern generation"
(cd "$NATIVE" && "$SRC/configure" CC="${NATIVE_CC:-clang}" CFLAGS="-O2 -fcommon" >configure.log 2>&1 && make -j"$JOBS" >make.log 2>&1)

echo "== stage 2: wasm config.h"
(cd "$WASMCFG" && emconfigure "$SRC/configure" CFLAGS="-O2 -fcommon" --without-readline --without-curses >configure.log 2>&1)

UTILS="getopt getopt1 random gg_utils"
SGF="sgf_utils sgfnode sgftree"
ENGINE="aftermath board boardlib breakin cache clock combination dragon endgame filllib fuseki genmove globals handicap hash influence interface matchpat montecarlo move_reasons movelist optics oracle owl persistent printutils readconnect reading semeai sgfdecide sgffile shapes showbord surround unconditional utils value_moves worm"
PATTERNS_SRC="connections helpers transform"
PATTERNS_GEN="conn patterns apatterns dpatterns eyes influence barriers endgame aa_attackpat owl_attackpat owl_vital_apat owl_defendpat fusekipat fuseki9 fuseki13 fuseki19 josekidb handipat oraclepat mcpat"
INTERFACE="main play_ascii play_gmp play_gtp play_solo play_test gmp gtp"

export OBJ
export CFLAGS_STR="-O2 -fcommon -DHAVE_CONFIG_H -I$WASMCFG -I$SRC -I$SRC/engine -I$SRC/patterns -I$SRC/sgf -I$SRC/utils -I$SRC/interface -I$NATIVE/patterns -Wno-everything"

echo "== stage 2: compile"
{
  for f in $UTILS; do echo "utils $SRC/utils/$f.c $f"; done
  for f in $SGF; do echo "sgf $SRC/sgf/$f.c $f"; done
  for f in $ENGINE; do echo "engine $SRC/engine/$f.c $f"; done
  for f in $PATTERNS_SRC; do echo "patterns $SRC/patterns/$f.c $f"; done
  for f in $PATTERNS_GEN; do echo "patterns $NATIVE/patterns/$f.c $f"; done
  for f in $INTERFACE; do echo "interface $SRC/interface/$f.c $f"; done
} | xargs -P "$JOBS" -L 1 bash -c 'emcc $CFLAGS_STR -c "$1" -o "$OBJ/$0_$2.o"'

# GNU Go's reading code is deeply recursive. Emscripten's default stack is
# 64 KB; 8 MB matches the usual native default.
echo "== stage 2: link"
emcc -O2 "$OBJ"/*.o -o "$OUT/gnugo.mjs" \
  -sMODULARIZE=1 -sEXPORT_ES6=1 -sEXPORT_NAME=createGnuGo \
  -sENVIRONMENT=worker,web,node \
  -sINVOKE_RUN=0 -sEXIT_RUNTIME=1 \
  -sEXPORTED_RUNTIME_METHODS=callMain \
  -sINCOMING_MODULE_JS_API=wasmBinary,locateFile,instantiateWasm,stdin,stdout,stderr,onAbort \
  -sALLOW_MEMORY_GROWTH=1 -sSTACK_SIZE=8MB

# The same objects, linked as a Node command-line program with real file
# access, so the regression suite can run it in place of a native binary.
echo "== stage 2: link test CLI"
emcc -O2 "$OBJ"/*.o -o "$WORK/gnugo-wasm-cli.js" \
  -sENVIRONMENT=node -sNODERAWFS=1 -sEXIT_RUNTIME=1 \
  -sALLOW_MEMORY_GROWTH=1 -sSTACK_SIZE=8MB

# gnugo.d.mts describes the options above and must change with them.
cp "$ROOT/gnugo.d.mts" "$OUT/gnugo.d.mts"
ls -la "$OUT"/gnugo.mjs "$OUT"/gnugo.wasm "$OUT"/gnugo.d.mts
