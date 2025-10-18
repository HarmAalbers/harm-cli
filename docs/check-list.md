# Function/Module Definition‑of‑Done (DoD) — Bash/Zsh + ShellSpec

Use this **checklist for every new function or module**. It’s terse on purpose. Copy/paste and tick.

---

## 0) Metadata & Scope

* [ ] **Single purpose**: the name and docstring state one clear responsibility.
* [ ] **Pure vs Side‑effect** labeled: outputs via stdout vs writes/execs.
* [ ] **Shell target**: bash‑portable or zsh‑specific (and why).

---

## 1) File Header & Strictness

* [ ] Shebang correct: `#!/usr/bin/env bash` **or** `#!/usr/bin/env zsh`.
* [ ] **Strict mode**:

  * Bash: `set -Eeuo pipefail; IFS=$'\n\t'`.
  * Zsh: `emulate -L zsh -o errexit -o err_return -o nounset -o pipe_fail`.
* [ ] `trap` present for cleanup & errors (ties into common `on_err`, `cleanup`).

---

## 2) API & Contracts

* [ ] **Inputs validated** (`${1:?param required}`; regex guards; type checks).
* [ ] **Outputs**: values on **stdout** only; logs/errors on **stderr**.
* [ ] **Exit codes** documented: {0 OK, 2 usage, 16 lock, 64 unknown cmd, 70 internal, 111 temp, 124 timeout, 130 interrupt}.
* [ ] **Determinism**: no hidden env reliance; defaults via params/env (`CLI_*`) with precedence (flags > env > config > defaults).

---

## 3) Safety & Side‑effects

* [ ] **Idempotent** or clearly documented non‑idempotent behavior.
* [ ] **Atomic I/O** for writes (`atomic_write`),
  **locking** for shared resources (`with_lock`).
* [ ] **Temp dirs** via `mktemp` under a tracked var; cleaned in `trap`.
* [ ] **Timeouts** around external calls (`with_timeout SECS cmd…`).
* [ ] **Retries** only for idempotent ops (`retry N backoff`).
* [ ] **Resource limits** considered (files, memory, `ulimit` if needed).

---

## 4) Performance & Portability

* [ ] Prefer **builtins**; avoid useless subshells/forks.
* [ ] Quote everything; avoid word‑splitting; use arrays safely.
* [ ] No bash‑isms if file claims POSIX; no zsh‑isms if file claims bash.
* [ ] Large loops stream with `while IFS= read -r …`; no `cat | while` UUOC.

---

## 5) Observability

* [ ] Uses common **logging** helpers: `log INFO|DEBUG|WARN|ERROR`.
* [ ] **--format** parity: supports `text` and `json` where user‑visible.
* [ ] Messages actionable; include key values (never secrets).

---

## 6) Security

* [ ] No injection via unquoted vars; no `eval` unless justified & reviewed.
* [ ] Paths normalized; avoid writing outside intended dirs.
* [ ] Secrets never logged; redaction where needed.
* [ ] External binaries checked with `req cmd` before use.

---

## 7) Tests (ShellSpec)

* [ ] **Spec file** created under `spec/…_spec.sh`.
* [ ] **Runner** coverage: at least bash **and** zsh if portable; else zsh.
* [ ] **Happy path** assertions: status, stdout exact, stderr sane.
* [ ] **Edge cases**: empty/invalid inputs, timeouts, retries off/on, lock held.
* [ ] **Golden output** added when UX must not drift (help banners/JSON).
* [ ] **Failure modes**: asserts correct exit code & message (e.g., 2, 124).
* [ ] **Concurrency** (if relevant): parallel calls don’t corrupt state.

---

## 8) Docs & UX

* [ ] Help/usage updated (global + subcommand help).
* [ ] Examples added (both text & JSON forms if applicable).
* [ ] README snippet or manpage touched if behavior is user‑visible.

---

## 9) Style & Tooling

* [ ] `shfmt` clean; `shellcheck` clean (or justified ignores).
* [ ] Pre‑commit passes locally.
* [ ] `just ci` green.

---

# Mini Templates

## Function (bash, pure)

```bash
# shellcheck shell=bash
foo_strip() {
  local input="${1:?input required}" pattern="${2:?pattern required}"
  [[ -n "$pattern" ]] || die 2 "pattern empty"
  printf '%s\n' "${input//${pattern}/}"
}
```

## Function (bash, side‑effect with timeout + atomic write)

```bash
foo_fetch() {
  local url="${1:?url}" out="${2:?out}" to="${3:-10}"
  ensure_writable_dir "$(dirname -- "$out")"; req curl
  with_timeout "$to" curl -fsSL "$url" | atomic_write "$out" || {
    ec=$?; [[ $ec -eq 124 ]] && die 124 "timeout $url" || die "$ec" "curl failed($ec)"
  }
}
```

## Module header (zsh)

```zsh
#!/usr/bin/env zsh
emulate -L zsh -o errexit -o err_return -o nounset -o pipe_fail
# functions here use zsh arrays/globbing; document assumptions
```

## ShellSpec (portable)

```sh
Describe 'foo_strip'
  Include spec/helpers/env.sh
  It 'removes pattern'
    When call bash -lc 'source lib/foo.sh; foo_strip "abcXdef" X'
    The status should be success
    The output should eq 'abcdef'
  End
End
```

## ShellSpec (zsh runner)

```sh
Describe 'zsh‑specific logic'
  Shell '/bin/zsh'
  It 'behaves with zsh options'
    When run bin/cli greet --upper Harm
    The status should be success
    The output should eq 'HELLO, HARM!'
  End
End
```

---

# One‑page DoD (copy into PR template)

* [ ] Strict mode & traps
* [ ] Inputs validated, outputs on stdout, errors on stderr
* [ ] Exit codes documented & tested (0/2/124/etc.)
* [ ] Timeouts & retries (idempotent only)
* [ ] Atomic writes, locks, tempdir cleanup
* [ ] Builtins over forks; streaming I/O
* [ ] Logging via helpers; text/json parity
* [ ] No secrets in logs; no unsafe eval
* [ ] Shell portability honored (or explicitly zsh‑only)
* [ ] ShellSpec tests: happy/edge/failure/golden/concurrency
* [ ] Help/README/man updated; examples included
* [ ] shfmt & shellcheck clean; `just ci` green
  ``
