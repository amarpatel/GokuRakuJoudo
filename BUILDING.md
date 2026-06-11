# Building Goku

This repo builds a native `goku` executable with Leiningen and GraalVM Native
Image.

## Prerequisites

- macOS or Linux with `make`
- Leiningen available as `lein`
- GraalVM Native Image available as `native-image`

On this machine, the Homebrew GraalVM formula installs `native-image` under:

```sh
/opt/homebrew/opt/graalvm/bin/native-image
```

If `native-image` is not already on `PATH`, prepend that directory when building:

```sh
PATH="/opt/homebrew/opt/graalvm/bin:$PATH" make all
```

## Standard Build

From the repo root:

```sh
make all
```

`make all` runs:

1. `lein clean`
2. `lein compile`
3. `lein uberjar`
4. `native-image` against `target/karabiner-configurator-0.1.0-standalone.jar`

The resulting binary is written to:

```sh
./goku
```

Verify it with:

```sh
./goku --version
```

## Local Fork Build

Use the local build script when you want the binary to clearly identify this
checkout instead of an upstream or Homebrew build:

```sh
scripts/build-local-goku.sh
```

The script reads the newest reachable `v*` git tag, temporarily builds with an
`a` suffix, and then restores the source file. For example, release tag `v0.8.0`
builds a binary that reports `0.8.0a`. If no matching git tag exists, it falls
back to the version currently returned by `goku --version` in the source.

Verify the binary that your shell will run:

```sh
type -a goku
readlink "$(command -v goku)"
goku --version
```

On this machine, `/opt/homebrew/bin/goku` is expected to point at this checkout's
`./goku` binary.
