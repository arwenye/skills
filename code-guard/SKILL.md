---
name: code-guard
description: "Three-layer code quality enforcement. Run when user says lint, run tests, set up CI, code quality, code guard, /code-guard, 静态检查, 跑测试, 单元测试, 集成测试, 设置CI, 代码质量, 代码检查, 提交前检查, or asks to check code correctness before committing/merging."
---

# Code Guard

Three-layer defence against bugs. Run each layer in order: Lint → Test → CI.
Stop at first layer that fails and fix before moving on.

---

## Step 1 — Detect project

Before running anything, detect language and tooling:

```bash
# In project root, run:
ls package.json pyproject.toml setup.py setup.cfg go.mod Cargo.toml pom.xml build.gradle 2>/dev/null
cat package.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('scripts:', list(d.get('scripts',{}).keys()))" 2>/dev/null
```

Use detection to pick the right tools below. When a project has its own lint/test scripts (e.g. `npm run lint`, `make test`), **prefer those over invoking tools directly** — they encode project-specific config.

---

## Step 2 — Lint

Goal: catch syntax errors, style violations, and code smells *before* runtime.

### Python
```bash
# Prefer ruff (fast, replaces flake8+isort+pyupgrade)
ruff check . --output-format=concise
# If not installed: pip install ruff
# Also type-check if mypy/pyright config exists:
[ -f mypy.ini ] || [ -f pyrightconfig.json ] && mypy . --ignore-missing-imports || true
```

### JavaScript / TypeScript
```bash
# Use project's own lint script if present
npm run lint 2>/dev/null || npx eslint . --ext .js,.jsx,.ts,.tsx
# Type check separately
npx tsc --noEmit 2>/dev/null || true
```

### Go
```bash
go vet ./...
# If golangci-lint installed:
golangci-lint run ./... 2>/dev/null || true
```

### Rust
```bash
cargo clippy -- -D warnings
```

### Generic fallback
```bash
# At minimum, check for syntax errors in shell scripts
find . -name "*.sh" -not -path "*/node_modules/*" -exec bash -n {} \;
```

**Report**: List every finding with file:line. If zero findings, say so explicitly.

---

## Step 3 — Test

Goal: verify behaviour contracts. A failing test = the code broke a promise.

### Detect and run

```bash
# Python
[ -f pytest.ini ] || [ -f pyproject.toml ] && grep -q pytest pyproject.toml && pytest -x -q

# JS/TS
npm test 2>/dev/null || npx jest --passWithNoTests

# Go
go test ./... -count=1

# Rust
cargo test

# Java/Gradle
./gradlew test

# Java/Maven
mvn test -q
```

Run with `-x` / `--bail` / `--failfast` where available: stop on first failure, don't flood output.

**If no tests exist**: report which files have no test coverage and offer to write minimal tests for the changed files. Do NOT write full test suites unprompted — only write tests for the functions the user just changed, one assertion per behaviour.

---

## Step 4 — CI

Goal: make Lint + Test run automatically on every push so humans can't forget.

### Detect existing CI
```bash
ls .github/workflows/ .gitlab-ci.yml .circleci/ Jenkinsfile 2>/dev/null
```

If CI already exists, read the config and check:
1. Does it run lint?
2. Does it run tests?
3. Does it block merge on failure (branch protection)?

Report gaps, patch the existing file rather than creating a new one.

### If no CI exists — create minimal GitHub Actions workflow

Only create `.github/workflows/ci.yml` if the project is a git repo with a GitHub remote OR the user asks for it.

Template (fill in `<LANG_STEPS>` from detection):

```yaml
name: CI
on:
  push:
    branches: ["**"]
  pull_request:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # <LANG_STEPS> — insert language setup + lint + test commands here
```

**Python example steps**:
```yaml
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: pip install ruff pytest
      - run: ruff check .
      - run: pytest -x -q
```

**Node example steps**:
```yaml
      - uses: actions/setup-node@v4
        with: { node-version: "20", cache: "npm" }
      - run: npm ci
      - run: npm run lint
      - run: npm test
```

Keep the workflow file under 40 lines. No matrix builds, no artifact uploads, no caching unless the user asks.

---

## Output format

After running each layer, print a compact summary:

```
LINT   ✓  0 issues          (or) ✗  3 issues → [file:line message]
TEST   ✓  42 passed          (or) ✗  2 failed → [test name]
CI     ✓  .github/workflows/ci.yml already covers lint+test
        (or) — created .github/workflows/ci.yml
```

Then one line: **"Ready to commit"** or **"Fix lint/test failures above first."**

---

## Constraints

- Never auto-fix lint errors in files the user didn't ask about.
- Never delete or rewrite tests that already exist.
- If lint or test tooling is not installed, say so with the install command, don't fail silently.
- If the project has a `Makefile` with `lint` / `test` / `check` targets, use those instead of invoking tools directly.
