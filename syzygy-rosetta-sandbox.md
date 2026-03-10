# Syzygy Rosetta — Sandbox

> **Multi-Agent Testing & Drift Simulation Environment**

[![Status: Active Development](https://img.shields.io/badge/Status-Active%20Development-orange.svg)]()
[![Python 3.11](https://img.shields.io/badge/Python-3.11-blue.svg)](https://www.python.org/)

---

## What is This Repository?

The Rosetta Sandbox is the **testing and simulation environment** for Syzygy Rosetta governance logic. It provides tools to:

- Simulate multi-agent conversations and interactions
- Test the `POST /evaluate` endpoint under various conditions
- Demonstrate the difference between governed and ungoverned agent behavior
- Measure drift — the degradation of agent behavior over time without governance enforcement

---

## Why a Sandbox?

One of Rosetta's core value propositions is demonstrating what happens when AI agents operate **without** a governance layer versus **with** one.

The sandbox makes this visible. It runs controlled simulations, documents drift points and boundary violations, and produces evidence of why governance middleware is necessary.

---

## Structure

```
sandbox/
├── agent_sim.py          # Multi-agent conversation simulator
├── drift_tests/          # Drift scenario test cases
│   ├── without_rosetta/  # Agent behavior without governance
│   └── with_rosetta/     # Agent behavior via POST /evaluate
├── case_studies/         # Documented side-by-side comparisons
└── results/              # Test outputs and evaluation logs
```

---

## Running a Simulation

### Prerequisites

Ensure Rosetta is running locally:

```bash
docker run -p 8000:8000 rosetta
```

### Run the Agent Simulator

```bash
python sandbox/agent_sim.py
```

This runs a multi-turn conversation simulation that calls `POST /evaluate` on each agent output.

### Run Drift Tests

```bash
# Without Rosetta governance
python drift_tests/without_rosetta/run.py

# With Rosetta governance
python drift_tests/with_rosetta/run.py
```

---

## What the Sandbox Measures

| Metric | Description |
|---|---|
| **Drift points** | Moments where ungoverned agent behavior deviates from policy |
| **Boundary violations** | Outputs that would be blocked or rewritten by Rosetta |
| **Rewrite prevention** | Cases where Rosetta corrects output before it reaches the user |
| **Escalation triggers** | High-risk outputs that require human review |

---

## Relationship to the MVP

The sandbox produces the **demo evidence** for the Rosetta MVP. The case studies generated here demonstrate governance necessity to enterprise partners and investors.

---

## Related Repositories

| Repository | Role |
|---|---|
| [syzygy-rosetta-originbase](https://github.com/Trivian-Technologies/syzygy-rosetta-originbase) | Core governance engine |
| [syzygy-rosetta-api](https://github.com/Trivian-Technologies/syzygy-rosetta-api) | API layer (private) |
| [syzygy-rosetta-docs](https://github.com/Trivian-Technologies/syzygy-rosetta-docs) | Full documentation |

---

## Organization

Part of the [Trivian Technologies](https://github.com/Trivian-Technologies) organization.

**Website:** [triviantech.com](https://triviantech.com) | **X:** [@TrivianOS](https://x.com/TrivianOS) | **LinkedIn:** [Trivian Technologies](https://www.linkedin.com/company/awakening-the-architect)
