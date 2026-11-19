---
name: experiment-protocol
description: "为 AI Agent 实验生成 experiment_protocol.json（实验契约）和 manifest.json（验收清单+文件指纹）。在新建实验、跑完实验需要存档、或审查已有实验结果时使用。触发词：实验协议、实验契约、experiment protocol、manifest、验收清单、实验存档。"
---

# Experiment Protocol & Manifest Skill

实验结论的可信度不能只靠"作者说跑过了"。这个 skill 帮你生成两件事：
- **experiment_protocol.json**：实验前锁定契约（跑什么、用什么模型、怎么设计）
- **manifest.json**：实验后验收（逐项核查 + 每个结果文件的 SHA256 指纹）

---

## 使用场景

| 场景 | 做什么 |
|------|--------|
| 新建实验 | 生成 `experiment_protocol.json` 草稿，逼你在跑之前想清楚实验设计 |
| 跑完存档 | 生成 `manifest.json`，锁定结果文件完整性 |
| 审查已有结果 | 校验 manifest 里的 SHA256 是否与文件一致 |

---

## Step 1 — 生成 experiment_protocol.json

向用户询问以下信息（没有的用 `null` 或合理默认值），然后生成文件：

```json
{
  "experiment_id": "<章节号-序号，如 2-5>",
  "protocol_version": "1.0.0",
  "manuscript_contract": {
    "hypothesis": "<一句话：你预测什么会发生>",
    "independent_variables": ["<自变量1>", "<自变量2>"],
    "dependent_variable": "<因变量：用什么指标量化>",
    "control_group": "<对照组描述>",
    "judge_type": "deterministic | llm-judge | human"
  },
  "provider": {
    "name": "<openai | dashscope | moonshot | ...>",
    "base_url": "<endpoint，官方可省略>",
    "model": "<模型名>",
    "temperature": 0.7
  },
  "design": {
    "trials_per_cell": 5,
    "expected_cells": "<自变量组合数 × trials_per_cell>",
    "max_agent_steps_per_user_turn": 6,
    "isolated_execution_per_trial": true,
    "acceptance_independent_of_hypothesis": true
  }
}
```

**关键设计检查**（生成前逐项问自己）：

1. **自变量和因变量分离了吗？** 每次只改一个维度
2. **判定器是确定性的吗？** 规则判定 > LLM 判定（稳定、零额外成本、可重复）
3. **对照组存在吗？** 没有基线就没有对比
4. **模型选择符合教学目标吗？** 要展示防御效果需要"故意可被攻破"的基线模型；要展示模型能力需要能被攻破的攻击

---

## Step 2 — 跑完实验后生成 manifest.json

```bash
# 计算所有结果文件的 SHA256（在实验结果目录下运行）
find cells/ -name "*.json" | sort | while read f; do
  sha256sum "$f"
done
```

然后生成 manifest：

```json
{
  "experiment_id": "<同 protocol>",
  "status": "passed | failed | partial",
  "protocol_sha256": "<experiment_protocol.json 的 SHA256>",
  "acceptance": {
    "full_matrix_complete": true,
    "all_trials_complete": true,
    "real_provider_receipts": true,
    "judge_applied_to_all_cells": true,
    "credential_scan_passed": true,
    "passed": true
  },
  "artifacts": {
    "cells/trial-X-Y-ZZ.json": {
      "sha256": "<sha256>",
      "bytes": 12345
    }
  }
}
```

**acceptance 的核查逻辑**：

| 字段 | 核查方法 |
|------|----------|
| `full_matrix_complete` | 文件数 == `expected_cells` × `trials_per_cell` |
| `all_trials_complete` | 每个 cell 文件里没有 `"error"` 字段（或 error 为 null） |
| `real_provider_receipts` | cell 文件里有 `provider_calls` 且非空 |
| `credential_scan_passed` | `grep -r "sk-\|api_key\|SECRET" cells/` 无命中 |

---

## Step 3 — 校验已有 manifest（可选）

```bash
# 重新计算所有文件的 SHA256，与 manifest 对比
python3 - <<'EOF'
import json, hashlib, pathlib, sys

manifest = json.loads(pathlib.Path("manifest.json").read_text())
errors = []
for path, meta in manifest["artifacts"].items():
    data = pathlib.Path(path).read_bytes()
    actual = hashlib.sha256(data).hexdigest()
    if actual != meta["sha256"]:
        errors.append(f"MISMATCH: {path}")
    if len(data) != meta["bytes"]:
        errors.append(f"SIZE DIFF: {path}")
if errors:
    print("\n".join(errors)); sys.exit(1)
print(f"OK: {len(manifest['artifacts'])} files verified")
EOF
```

---

## 设计原则（来自 exp2-5 的实践）

- **结论、原始数据、验收标准三者分离**：protocol 定契约，cells/ 存原始数据，manifest 做验收
- **文件指纹 = 防篡改**：SHA256 让任何人都能独立核查结果没有被事后修改
- **acceptance_independent_of_hypothesis**：验收标准不能依赖假设是否成立——即使结论出乎意料也要通过验收
- **credential_scan_passed**：结果文件绝不能包含 API key、SECRET 等机密（实验里用的 SECRET_KEY 是假的测试值，真实部署要扫描）
