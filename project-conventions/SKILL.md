---
name: project-conventions
description: "Enforce workspace conventions for model downloads, project architecture, file locations, and file naming. Use when starting a new project, downloading a model, or creating any file. Triggers: new project, download model, create file, 新建项目, 下载模型, 创建文件, 项目结构, 文件命名."
---

# Project Conventions

Apply these rules whenever you create files, download models, scaffold a project, or generate any output.

---

## 1 — Model Downloads

### Primary source: ModelScope

Always prefer ModelScope over HuggingFace for downloads. Use the `modelscope` SDK:

```python
from modelscope import snapshot_download

# snapshot_download returns the local cache path
model_path = snapshot_download(
    model_id='Qwen/Qwen2.5-7B-Instruct',   # <org>/<name> on modelscope.cn
    cache_dir='/data/ai-model/models/<type>',
)
```

Or via CLI:
```bash
modelscope download --model Qwen/Qwen2.5-7B-Instruct \
    --local_dir /data/ai-model/models/llm/Qwen/Qwen2.5-7B-Instruct
```

If ModelScope does not have the model, fall back to HuggingFace with `HF_ENDPOINT`:
```bash
HF_ENDPOINT=https://hf-mirror.com huggingface-cli download \
    Qwen/Qwen2.5-7B-Instruct \
    --local-dir /data/ai-model/models/llm/Qwen/Qwen2.5-7B-Instruct
```

### Target directory

| Model type | Target path |
|---|---|
| LLM / chat / instruct | `/data/ai-model/models/llm/<org>/<ModelName>` |
| ASR / speech recognition | `/data/ai-model/models/ASR/<ModelName>` |
| Audio / TTS / voice | `/data/ai-model/models/audio/<ModelName>` |
| Embedding | `/data/ai-model/models/embedding/<org>/<ModelName>` |
| Rerank | `/data/ai-model/models/rerank/<org>/<ModelName>` |
| BERT / encoder-only | `/data/ai-model/models/bert/<org>/<ModelName>` |
| Vision / image | `/data/ai-model/models/vision/<org>/<ModelName>` |
| Video | `/data/ai-model/models/video/<org>/<ModelName>` |
| Diffusion / generation | `/data/ai-model/models/diffusion/<org>/<ModelName>` |
| Multimodal (VLM) | `/data/ai-model/models/multimodel/<org>/<ModelName>` |
| Fine-tuned checkpoints | `/data/ai-model/finetuned/<project>/<run-name>` |

**Never** download models to `/data/ywh/` or any project subdirectory — keep models in `/data/ai-model/`.

Reference model paths in code as constants at the top of the file:
```python
MODEL_DIR = "/data/ai-model/models/llm/Qwen"
MODEL_PATH = f"{MODEL_DIR}/Qwen2.5-7B-Instruct"
```

---

## 2 — New Project Architecture

When scaffolding a Python ML/AI project under `/data/ywh/<project-name>/`:

```
<project-name>/         # kebab-case, no spaces
├── src/                # all application source code
│   ├── __init__.py
│   └── <module>/
├── scripts/            # one-off CLI scripts (not importable)
├── tests/              # self-contained test suite (see Section 2a)
│   ├── <module>/       # one subdir per src module, mirrors src/ structure
│   │   ├── test_<module>.py
│   │   └── ...
│   ├── results/        # test output artefacts — gitignored
│   │   └── <module>/   # one subdir per module, same mirroring
│   ├── conftest.py     # shared fixtures
│   └── requirements.txt  # test-only deps (pytest, pytest-cov, etc.)
├── data/               # local runtime data (gitignored for large files)
│   ├── input/
│   └── output/
├── logs/               # log files (gitignored)
├── configs/            # YAML/JSON config files
├── docs/               # generated and hand-written documentation
│   ├── design/         # architecture and design docs
│   ├── api/            # API / interface docs
│   └── reports/        # analysis reports, experiment summaries
├── docker/             # Dockerfile and compose files (if any)
├── requirements.txt    # pinned dependencies
└── README.md
```

Rules:
- Project root name: **kebab-case** (e.g. `after-call-check`, `ad-select`)
- Source modules: **snake_case** (e.g. `src/audio_processor.py`)
- `src/` is the only importable package; `scripts/` are entry-point runners
- Put constants (model paths, data paths) in `src/config.py` or `src/constants.py`, not scattered across files
- Docker volumes always map `/data/ai-model:/data/ai-model` and `/data/ywh:/data/ywh`

### 2a — Tests directory

`tests/` is self-contained and independent from `src/`:

```
tests/
├── conftest.py              # shared pytest fixtures
├── requirements.txt         # test-only deps, separate from project requirements.txt
├── <module>/                # one dir per src module (e.g. audio_processor/, pipeline/)
│   ├── test_<module>.py     # unit / integration tests for that module
│   └── fixtures/            # static input files used only by this module's tests
└── results/                 # artefacts produced during test runs — gitignored
    └── <module>/            # mirrors the test dir structure
```

Rules for `tests/`:
- Each `tests/<module>/` directory mirrors a `src/<module>` — one-to-one mapping
- `tests/results/` stores any files written during test execution (JSON outputs, generated audio, logs). **Never assert on paths outside `tests/results/`.**
- `tests/requirements.txt` lists only test tooling (`pytest`, `pytest-cov`, `hypothesis`, etc.); production deps come from the project root `requirements.txt`
- Tests must be runnable standalone: `cd tests && pytest` should work without installing the main project in editable mode (add `sys.path` fixup in `conftest.py` if needed)

**Functional / evaluation tests** (model benchmarks, end-to-end pipeline checks) also live under `tests/`, but in a task-named subdirectory rather than a module-mirroring one:

```
tests/
├── asr/                     # functional eval: ASR model benchmarks
│   ├── qwen_asr.py          # standalone runner — no test_ prefix needed
│   ├── whisper_asr.py
│   └── ...
└── results/
    └── asr/                 # JSON outputs, metrics.csv — gitignored
```

Rules for functional/eval scripts in `tests/<task>/`:
- No `test_` prefix required — these are standalone CLI runners, not pytest cases
- File names: **snake_case** (rename from any kebab-case originals when moving)
- **Never hardcode absolute paths.** Use `Path(__file__)` to anchor output paths:
  ```python
  # tests/asr/qwen_asr.py
  RESULTS_DIR = Path(__file__).parent.parent / "results" / "asr"
  METRICS_CSV = RESULTS_DIR / "metrics.csv"
  DEFAULT_OUT  = str(RESULTS_DIR / "qwen-1.7b")
  ```
- When migrating existing scripts that had hardcoded absolute paths, update all path constants to use `Path(__file__)`-relative forms before moving
- Results written by these scripts go to `tests/results/<task>/` — already covered by the `.gitignore` entry for `tests/results/`

`.gitignore` additions (always include these in every project):
```gitignore
# test artefacts
tests/results/

# runtime outputs
data/output/
logs/
*.log
```

---

## 3 — File Locations

### Output and result files

| Content | Location |
|---|---|
| Model inference results (JSON per sample) | `/data/ywh/<project>/data/<task>/<model-tag>/` |
| Aggregated metrics CSV | `/data/ywh/<project>/data/<task>/metrics.csv` |
| Experiment logs | `/data/ywh/<project>/logs/` or `/data/ywh/logs/` |
| Processed datasets | `/data/ywh/<project>/data/processed/` |
| Raw input data | `/data/ywh/<project>/data/input/` or `/ceph/…` for large data |
| Fine-tuning output checkpoints | `/data/ai-model/finetuned/<project>/<run>/` |
| Temporary scratch files | `/tmp/` — never commit or persist |

### Documentation files

All documents generated by Claude or written by hand go into `<project>/docs/`:

| Content | Location |
|---|---|
| Architecture / design docs | `<project>/docs/design/<kebab-name>.md` |
| API / interface specs | `<project>/docs/api/<kebab-name>.md` |
| Experiment / analysis reports | `<project>/docs/reports/<kebab-name>_<YYYY-MM-DD>.md` |
| Onboarding / usage guides | `<project>/docs/<kebab-name>.md` (flat, top-level) |

Rules:
- File format: **Markdown (`.md`)** by default; use `.pdf` or `.html` only when the recipient requires it
- File name: **kebab-case**, no spaces, no uppercase (e.g. `asr-model-selection.md`)
- Reports that are tied to a date append `_YYYY-MM-DD` as a suffix (e.g. `asr-benchmark_2026-09-23.md`)
- Never drop docs into the project root, `src/`, or `data/`

### Config files

- Project-level config: `<project>/configs/<name>.yaml`
- Per-run overrides: pass via CLI args, not extra config files
- Secrets and credentials: `.env` file at project root, never committed

### Docker

- `Dockerfile` in `<project>/docker/Dockerfile`
- `docker-compose.yml` in `<project>/docker/docker-compose.yml`
- Volume mount convention (always include):
  ```yaml
  volumes:
    - /data/ai-model:/data/ai-model
    - /data/ywh:/data/ywh
    - /ceph:/ceph
  ```

---

## 4 — Logging

### Log file location

- Runtime logs go to `<project>/logs/` (gitignored)
- Name pattern: `<module-or-task>_<YYYY-MM-DD>.log` (e.g. `asr_pipeline_2026-09-23.log`)
- Rotate daily or by size; never let logs grow unbounded in long-running services

### Logger setup (Python)

Use the standard `logging` module with a shared setup helper. Every module gets its own named logger via `logging.getLogger(__name__)` — this makes every log line carry the module path automatically.

```python
# src/logger.py  — create once, import everywhere
import logging
import sys
from pathlib import Path

def get_logger(name: str, log_dir: str | Path | None = None) -> logging.Logger:
    logger = logging.getLogger(name)
    if logger.handlers:          # avoid duplicate handlers on re-import
        return logger
    logger.setLevel(logging.DEBUG)

    fmt = logging.Formatter(
        "%(asctime)s  %(levelname)-8s  %(name)s:%(lineno)d  %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # always log to stderr
    sh = logging.StreamHandler(sys.stderr)
    sh.setLevel(logging.INFO)
    sh.setFormatter(fmt)
    logger.addHandler(sh)

    # optionally also write to a file
    if log_dir:
        Path(log_dir).mkdir(parents=True, exist_ok=True)
        from logging.handlers import TimedRotatingFileHandler
        fh = TimedRotatingFileHandler(
            Path(log_dir) / f"{name.split('.')[-1]}.log",
            when="midnight", backupCount=7, encoding="utf-8",
        )
        fh.setLevel(logging.DEBUG)
        fh.setFormatter(fmt)
        logger.addHandler(fh)

    return logger
```

Usage in any module:
```python
from src.logger import get_logger
log = get_logger(__name__, log_dir="logs")   # __name__ = "src.audio_processor"

log.info("Loading model from %s", model_path)
log.debug("Input shape: %s", tensor.shape)
log.warning("No GPU found, falling back to CPU")
log.error("Failed to open %s: %s", file_path, e)
```

### Format requirements

The format string **must** include:
- `%(name)s` — module dotted path (e.g. `src.pipeline.chunker`)
- `%(lineno)d` — line number within that file
- `%(asctime)s` — timestamp for correlating across logs
- `%(levelname)s` — severity

This produces lines like:
```
2026-09-23 14:05:32  ERROR     src.audio_processor:87  Failed to open /data/ywh/…/audio.wav: [Errno 2] No such file
```
which tells you exactly which file and line to open.

### Rules

- **Never** use `print()` for operational messages — use the logger
- Log at `DEBUG` for values/shapes that help during development, `INFO` for normal progress, `WARNING` for recoverable issues, `ERROR` for failures
- Include the problematic value or path in the message — `"file not found"` is useless; `"file not found: %s" % path` is actionable
- Do not catch-and-silence exceptions without logging them first (`log.exception(...)` logs the full traceback)

---

## 5 — File Naming

### Python files

| Pattern | Example |
|---|---|
| Modules: `snake_case.py` | `audio_processor.py` |
| Entry-point scripts: `snake_case.py` | `run_batch_asr.py` |
| Test files: `test_<module>.py` | `test_audio_processor.py` |
| Config dataclass: `config.py` or `constants.py` | `config.py` |

### Data / output files

| Pattern | Use case |
|---|---|
| `<stem>.json` | Per-sample inference result (stem = source filename stem) |
| `metrics.csv` | Aggregated metrics across a run |
| `<task>_<YYYY-MM-DD>.csv` | Date-stamped batch exports, date as suffix |
| `<model-tag>_results.jsonl` | Streaming multi-record output |

### Shell scripts

- `kebab-case.sh` in `sh/` at workspace root or `<project>/scripts/`
- Prefix with action verb: `run-`, `build-`, `deploy-`, `eval-`
- Example: `run-ms-swift.sh`, `build-docker.sh`, `eval-asr.sh`

### Directories

- Always **kebab-case** for project dirs and task dirs
- Always **snake_case** for Python package dirs under `src/`

### Model-tag convention in filenames and logs

When a filename or log entry needs to identify a model, use the pattern `<family>-<size>` in lowercase:
- `qwen-1.7b`, `qwen-7b`, `deepseek-7b`, `glm-9b`
- Example output directory: `data/asr-test/qwen-1.7b/`

---

## 6 — README Structure

Every project's `README.md` must include a **File Map** section that lists every significant directory and file with a one-line description of its purpose. Keep it in sync when files are added or moved.

Template:

```markdown
## File Map

| Path | Purpose |
|---|---|
| `src/` | Application source code (importable package) |
| `src/config.py` | Central constants: model paths, data paths, env vars |
| `src/<module>.py` | … |
| `scripts/` | CLI entry-points and one-off runners |
| `data/input/` | Raw input files (not committed for large data) |
| `data/output/` | Inference results and processed outputs |
| `logs/` | Runtime logs, rotated daily (gitignored) |
| `configs/` | YAML/JSON configuration files |
| `docs/` | Design docs, API specs, experiment reports |
| `docker/` | Dockerfile and compose files |
| `tests/` | pytest test suite mirroring `src/` structure |
| `requirements.txt` | Pinned Python dependencies |
```

Rules:
- The File Map must be present from project creation, not added later
- When you add a new significant file or directory, update the File Map in the same change
- Paths are repo-relative; use inline code formatting
- Descriptions answer "what lives here" in ≤10 words — no implementation detail

---

## Checklist — before generating any file

1. **Model path**: does the path start with `/data/ai-model/models/<type>/`?
2. **Project root**: is it under `/data/ywh/` with a kebab-case name?
3. **File name**: snake_case for Python, kebab-case for shell/dirs, no spaces, no uppercase, date as suffix `_YYYY-MM-DD`?
4. **Output location**: is it inside `<project>/data/` (not `src/`, not project root)?
5. **Documentation**: does the doc go into `<project>/docs/` with a kebab-case `.md` name?
6. **Logging**: does every Python module use `logging.getLogger(__name__)` with `%(name)s:%(lineno)d` in the format?
7. **Tests**: does each new `src/` module have a matching `tests/<module>/test_<module>.py`? Are test outputs written to `tests/results/<module>/`? For functional/eval scripts, do they live in `tests/<task>/` with snake_case names and `Path(__file__)`-relative output paths?
8. **README File Map**: is the new file listed in the README File Map?
9. **No secrets**: no API keys, tokens, or passwords hard-coded in any file?
