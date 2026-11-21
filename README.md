# TLeakBench

Replication package for the paper **"Can Generative AI Catch Temporal Data Leakage? An LLM-Based Code Review Benchmark for Time-Series Forecasting Pipelines"** (under double-blind review).

TLeakBench is an executable benchmark of 240 Python forecasting pipelines covering eight temporal data-leakage types (L1–L8). Leaky pipelines are paired with clean twins that differ in one statement, and hard negatives contain suspicious but correct constructs. An execution oracle measures the score inflation (ΔNSE) of every leak.

## Contents

```
code/
  tleakbench_generator.py          benchmark generator + execution oracle (CPU, ~1–2 min)
  TLeakBench_LLM_Evaluation.ipynb  LLM reviewers B0–B4, static rules B3, metrics, repair stage (GPU)
bench/
  tleakbench.jsonl                 240 evaluation items (code, label, leak type, ground-truth lines)
  twins.jsonl                      160 clean twins (minimal pairs)
  oracle_summary.csv               score inflation per leakage type
results/
  raw_<model>_<B0|B1|B2|B4>.jsonl  raw model outputs for detection
  raw_<model>_R.jsonl              raw model outputs for repair
  main_results.csv                 detection metrics per model and reviewer
  extra_metrics.csv                balanced accuracy and MCC
  per_type_recall.csv              recall per leakage type
  mcnemar.csv                      paired exact McNemar tests
  repair_*.csv                     repair results (summary, per type, per item)
  oracle_items.csv                 ΔNSE for every minimal pair
figures/
  Fig*.m / Fig*.png                MATLAB scripts (one self-contained file per figure) and renders
```

## Mapping to the paper

| Paper | Source |
|---|---|
| Fig. 1 (overview) | `figures/Fig1_TLeakBench_Framework.m` |
| Table I (taxonomy) | `code/tleakbench_generator.py` (`LEAK_TYPES`, `build`) |
| Fig. 2 (score inflation) | `figures/Fig2_Oracle_Inflation.m`, `results/oracle_items.csv` |
| Table II (detection) | `results/main_results.csv`, `results/extra_metrics.csv` |
| Fig. 3 (recall per type) | `figures/Fig4_PerType_Recall.m`, `results/per_type_recall.csv` |
| RQ3 tests | `results/mcnemar.csv` |
| RQ4 (repair) | `results/repair_*.csv` |

`Fig3_Detection_Performance.m` and `Fig5_Tradeoff_and_Repair.m` are additional figures not included in the page-limited paper.

## Reproduction

1. **Benchmark and oracle** (CPU): `python code/tleakbench_generator.py`. The synthetic dekadal series and all pipelines are generated deterministically (seed 2026).
2. **LLM evaluation** (GPU): open `code/TLeakBench_LLM_Evaluation.ipynb` on Kaggle (GPU T4×2, Internet on) or Colab (T4 or better), put `tleakbench_generator.py` next to it and run all cells. Outputs are checkpointed after every batch, so interrupted runs resume. `DRY_RUN = True` runs the whole pipeline without a GPU using a fake model.
3. **Figures**: run each `figures/Fig*.m` in MATLAB R2020a or later; each script writes a 600-dpi PNG and a vector PDF.

Models: Qwen2.5-Coder-7B-Instruct and Qwen2.5-Coder-3B-Instruct (Hugging Face), greedy decoding, one run per item.

## Requirements

See `requirements.txt` (Python ≥ 3.10).
