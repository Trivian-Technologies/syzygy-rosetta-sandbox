# Syzygy Rosetta — Sandbox

> **Multi-Agent Testing & Before/After Drift Simulation Environment**

[![Status: Active — Testing in Progress](https://img.shields.io/badge/Status-Active%20Testing-green.svg)]()
[![Python 3.11](https://img.shields.io/badge/Python-3.11-blue.svg)](https://www.python.org/)

---

## What is This Repository?

The Rosetta Sandbox is the **testing and simulation environment** for Syzygy Rosetta governance logic. It runs controlled multi-agent scenarios to demonstrate what happens when AI agents operate without a governance layer versus with one — producing the before/after evidence that proves Rosetta works in real deployment conditions.

---

## Why a Sandbox?

One of Rosetta's core value propositions is demonstrable governance. The sandbox makes this concrete. It runs agents through identical inputs in two conditions:

**Scenario A — Without Rosetta:** Agents run freely. Outputs are captured raw — unsafe, non-compliant, or high-risk responses are documented as-is.

**Scenario B — With Rosetta:** Same agents, same inputs. Every output passes through `POST /evaluate` first. Rosetta intercepts, rewrites, or escalates what the raw agents produced.

The evaluation logs from `logs/evaluations.json` serve as the audit trail for every governance decision made.

---

## Current Testing — In Progress

Three before/after scenarios are currently being run across all three industry contexts:

| Scenario | Industry | Status |
|---|---|---|
| Coercive financial instruction | Finance | 🔄 In Progress |
| Unsafe medication directive | Healthcare | 🔄 In Progress |
| System prompt injection / jailbreak | General | 🔄 In Progress |

Each scenario produces a full evaluation log entry showing the raw agent output, Rosetta's governance decision, and the corrected or escalated result.

---

## What the Sandbox Measures

| Metric | Description |
|---|---|
| **Drift points** | Moments where ungoverned agent behavior deviates from policy |
| **Boundary violations** | Outputs that would be blocked or rewritten by Rosetta |
| **Rewrite prevention** | Cases where Rosetta corrects output before it reaches users |
| **Escalation triggers** | High-risk outputs that require human review |
| **Response time** | Latency added by Rosetta governance per evaluation |

---

## Evaluation Log Format

Every governed agent output appends one entry to `logs/evaluations.json`:

```json
{
  "timestamp": "2026-03-21T14:32:00Z",
  "input": "the agent output evaluated",
  "decision": "allow | rewrite | escalate",
  "risk_score": 0.85,
  "confidence": 0.91,
  "violations": ["coercive_financial_instruction"],
  "rewrite": "rewritten output or null",
  "context": {
    "user_id": null,
    "environment": "staging",
    "industry": "finance"
  }
}
```

---

## Relationship to the MVP

The sandbox produces the **primary investor demo evidence** for Syzygy Rosetta. The before/after case studies generated here demonstrate governance necessity to enterprise partners and investors in a format that is concrete, reproducible, and auditable.

---

## Related Repositories

| Repository | Role |
|---|---|
| [syzygy-rosetta-originbase](https://github.com/Trivian-Technologies/syzygy-rosetta-originbase) | Core governance engine |
| [syzygy-rosetta-docs](https://github.com/Trivian-Technologies/syzygy-rosetta-docs) | Full documentation |

---

SANDBOX DEMO live on GCP: https://rosetta-sandbox-6tl4ak7zmq-uc.a.run.app/

## Organization

Part of the [Trivian Technologies](https://github.com/Trivian-Technologies) organization.

**Website:** [triviantech.com](https://triviantech.com) | **X:** [@TrivianOS](https://x.com/TrivianOS) | **LinkedIn:** [Trivian Technologies](https://www.linkedin.com/company/awakening-the-architect) | **Contact:** se@trivianinstitute.org
