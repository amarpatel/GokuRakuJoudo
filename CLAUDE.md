# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Goku (GokuRakuJoudo) is a CLI tool that compiles a concise EDN config (`karabiner.edn`) into Karabiner-Elements' verbose `karabiner.json`. It is written in Clojure, AOT-compiled with Leiningen, and built into a native macOS binary with GraalVM `native-image`. This checkout is a personal fork (`origin` = amarpatel/GokuRakuJoudo, `upstream` = yqrashawn/GokuRakuJoudo); on this machine `/opt/homebrew/bin/goku` is expected to point at this checkout's `./goku` binary (see BUILDING.md).

## Commands

- `lein test` — run all tests
- `lein test karabiner-configurator.rules-test` — run one test namespace
- `lein test :only karabiner-configurator.core-test/generate-conf` — run a single deftest
- `lein repl` — development REPL
- `make` — full native build (`lein clean` → `lein compile` + `lein uberjar` → `native-image`), produces `./goku` at the repo root
- `make compile` / `make bin` — just the uberjar / just the native-image step
- `scripts/build-local-goku.sh` — fork build: derives the version from the newest `v*` git tag, appends an `a` suffix (e.g. `0.8.0a`), builds, and verifies `./goku --version`
- `./install-dev-software.sh` — installs lein and GraalVM/native-image (via sdkman)

If `native-image` isn't on PATH: `PATH="/opt/homebrew/opt/graalvm/bin:$PATH" make all` (the local build script does this fallback automatically).

Caution: `make test-binary` is a CI smoke test that **overwrites** `~/.config/karabiner.edn` and `~/.config/karabiner/karabiner.json`. Don't run it on a machine with a real Karabiner config.

`GOKU_IS_DEV=1` (set by `.envrc`) changes dev behavior: `exit` skips `System/exit`, and a failed `massert` throws an AssertionError with a stacktrace instead of printing and exiting the process. REPL work and debugging assertion failures depend on this.

The compiled binary has two runtime (not build/test) dependencies: `joker` (lints the edn config before parsing) and `watchexec` (used by the `gokuw` watch wrapper).

## Architecture

The program is a single-pass compiler from EDN to JSON whose parsing stages communicate through shared mutable state:

- `data.clj` holds the central `conf-data` atom containing every parsed section (profiles, applications, devices, input-sources, templates, modifiers, froms, tos, layers, simlayers). All parser namespaces read from and write into this atom; `init-conf-data` resets it. It also defines the keyword/key-type predicates, backed by `keys_info.clj` (the registry of all key codes and their properties: modifier, consumer key, pointing button, from/to restrictions).
- `parse-edn` in `core.clj` runs the sections **in dependency order**: profiles → static sections (applications/devices/input-sources/templates) → modifiers → layers → simlayers → froms → tos → main rules. Later stages resolve keyword references to earlier ones via `conf-data`, so reordering breaks resolution.
- `keys.clj` + `modifiers.clj` parse the key shorthand notation (`:!Ca` mandatory left-command + a, `:#Sa` optional shift, `:!!a` hyper, `:!Qa` right-command, etc.); `froms.clj` / `tos.clj` expand from/to event definitions into karabiner event maps. The notation is documented in `tutorial.md`.
- `layers.clj` expands `:layers` (held key sets a variable to 1) and `:simlayers` (simultaneous key press, threshold from `:simlayer-threshold`) into template manipulators stored back into `conf-data`.
- `conditions.clj` turns condition expressions (`:chrome`, `:!vi-mode`, `["var" 1]`, device/input-source keywords) into karabiner `conditions`, tagging layer-based ones with metadata so `rules.clj` can auto-generate the layer manipulators.
- `rules.clj` (the largest namespace) parses the `:main` section. Each rule is `[<from> <to> <conditions> <other-options>]`. Within one `:des` block's `:rules` vector, bare items act as stateful markers for all following rules: a condition keyword or `[:condi ...]` sets ambient conditions, a profile keyword or `[:profiles ...]` sets target profiles (tracked in atoms). Parsed manipulators carry their target profiles as metadata; the `multi-profile-rules` atom accumulates output grouped by profile, and an "Auto generated layer conditions" rule group is prepended per profile.
- `update-to-karabiner-json` in `core.clj` loads the existing karabiner.json and replaces only the `complex_modifications` of profiles goku generated, preserving everything else. Each target profile **must already exist** in karabiner.json (created via the Karabiner GUI) or it asserts. `--dry-run` / `--dry-run-all` print to stdout instead of writing.

The CLI version string is hardcoded in `core.clj` (`validate-args`, the `:version` case) — `project.clj`'s version (0.1.0) only names the jar. `build-local-goku.sh` temporarily patches the `core.clj` string during a build and restores it afterward.

## Tests

Plain `clojure.test`, roughly one test namespace per source namespace. The pattern: seed state with `init-conf-data` / `update-conf-data`, feed EDN structures to the parser under test, and compare against expected EDN literals. Sample configs live in `resources/configurations/` (`edn/` inputs, `generated_edn/` expected outputs, `json/empty-karabiner.json` for the binary smoke test). Because parsers share the `conf-data` atom, a test that skips re-initialization leaks state into later tests.

## DSL documentation

`tutorial.md` (full DSL walkthrough including the modifier-prefix table) and `examples.org` (cookbook of config snippets) are the user-facing spec. When changing parsing behavior, update these and `CHANGELOG.org` accordingly.
