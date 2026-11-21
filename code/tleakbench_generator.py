# -*- coding: utf-8 -*-
"""
TLeakBench — benchmark generator + execution oracle
====================================================
Paper: "Can Generative AI Catch Temporal Data Leakage? An LLM-Based Code
        Review Benchmark for Time-Series Forecasting Pipelines"

What this script does
1. Loads a dekadal streamflow series (date, Q, T, P). If no CSV is given,
   a synthetic snowmelt-driven series (30 years x 36 dekads) is generated.
2. Generates executable forecasting pipelines (Python/sklearn code):
     - 160 leaky snippets  (8 leakage types x 20, variants cycled)
     - 160 clean "twins"   (identical code, the leaky statement fixed)
     -  40 hard negatives  (clean code with suspicious-looking constructs)
3. Executes every snippet (oracle) and measures the score inflation
   delta = NSE(leaky) - NSE(clean twin).
4. Writes:
     tleakbench.jsonl     240 items for LLM evaluation
                          (160 leaky + 40 clean twins + 40 hard negatives)
     twins.jsonl          all 160 clean twins (minimal pairs)
     oracle_summary.csv   inflation statistics per leakage type
Ground-truth lines are recorded per item (leak_lines / decoy_lines, 1-based).

Colab: just run  !python tleakbench_generator.py   (≈2–4 min)
Real data: set CFG['data_csv'] to a CSV with columns date,Q,T,P (dekadal).
"""
import contextlib
import io
import json
import os
import random
import re
import time
import warnings

import numpy as np
import pandas as pd

warnings.filterwarnings("ignore")

CFG = dict(
    out_dir="/content/tleakbench" if os.path.isdir("/content") else "./tleakbench",
    data_csv=None,          # e.g. "/content/drive/MyDrive/ca_discharge_gauge.csv"
    seed=2026,
    n_per_type=20,
    n_clean=40,
    n_hard=40,
    gap_frac=0.06,          # share of missing values injected into Q, T, P
    delta_thr=0.01,         # NSE inflation counted as "confirmed"
)

LEAK_TYPES = {
    "L1": "Preprocessing: scaler fitted on data that includes the test period",
    "L2": "Split: random/shuffled train-test split of a time series",
    "L3": "Look-ahead feature: feature uses future values (negative shift, centred/forward window)",
    "L4": "Target leakage: feature derived from the target at the same step",
    "L5": "Imputation: gap filling uses future observations",
    "L6": "Cross-validation: shuffled/non-temporal CV used to report performance",
    "L7": "Model selection: hyper-parameters chosen on the test set",
    "L8": "Decomposition/climatology computed on the full series incl. test period",
}
N_VARIANTS = {"L1": 3, "L2": 3, "L3": 4, "L4": 3, "L5": 3, "L6": 3, "L7": 2, "L8": 3}

MODELS = {
    "ridge": ("from sklearn.linear_model import Ridge",
              "Ridge(alpha=1.0)", "Ridge(alpha=p)", "[0.01, 0.1, 1.0, 10.0, 100.0]"),
    "knn": ("from sklearn.neighbors import KNeighborsRegressor",
            "KNeighborsRegressor(n_neighbors=10)", "KNeighborsRegressor(n_neighbors=p)",
            "[3, 5, 10, 20, 40]"),
    "rf": ("from sklearn.ensemble import RandomForestRegressor",
           "RandomForestRegressor(n_estimators=100, random_state=0, n_jobs=-1)",
           "RandomForestRegressor(n_estimators=100, max_depth=p, random_state=0, n_jobs=-1)",
           "[3, 5, 8, 12, None]"),
}
SCALERS = {"std": "StandardScaler", "mm": "MinMaxScaler"}
LEAK, DECOY = "  #<LEAK>", "  #<DECOY>"


# ----------------------------------------------------------------------------
# 1. Data
# ----------------------------------------------------------------------------
def make_synthetic(n_years=30, seed=0):
    """Dekadal snowmelt-driven streamflow with temperature and precipitation."""
    rng = np.random.default_rng(seed)
    dates = [pd.Timestamp(y, m, d) for y in range(1991, 1991 + n_years)
             for m in range(1, 13) for d in (1, 11, 21)]
    n = len(dates)
    dek = np.arange(n) % 36
    year_anom = np.repeat(rng.normal(0, 1, n_years), 36)
    T = 8 - 14 * np.cos(2 * np.pi * dek / 36) + 1.5 * year_anom + rng.normal(0, 2.0, n)
    P = rng.gamma(2.0, 6.0 * (1 + 0.6 * np.sin(2 * np.pi * (dek - 6) / 36)), n)
    snow, q, Q = 0.0, 20.0, np.zeros(n)
    for t in range(n):
        if T[t] < 0:
            snow += P[t]
            melt, rain = 0.0, 0.0
        else:
            melt = min(snow, 2.5 * T[t])
            snow -= melt
            rain = P[t]
        q = 0.65 * q + 0.35 * (8 + 0.9 * melt + 0.5 * rain) + rng.normal(0, 2.0)
        Q[t] = max(q, 0.5)
    return pd.DataFrame({"date": dates, "Q": Q, "T": T, "P": P})


def add_gaps(df, frac, seed=1):
    rng = np.random.default_rng(seed)
    df = df.copy()
    for c in ["Q", "T", "P"]:
        idx = rng.choice(np.arange(10, len(df)), int(frac * len(df)), replace=False)
        df.loc[idx, c] = np.nan
    return df


def load_data():
    if CFG["data_csv"]:
        df = pd.read_csv(CFG["data_csv"], parse_dates=["date"])
        missing = {"date", "Q", "T", "P"} - set(df.columns)
        if missing:
            raise ValueError(f"CSV is missing columns: {missing}")
        df = df[["date", "Q", "T", "P"]].sort_values("date").reset_index(drop=True)
        source = os.path.basename(CFG["data_csv"])
    else:
        df = make_synthetic(seed=CFG["seed"])
        source = "synthetic"
    return add_gaps(df, CFG["gap_frac"], seed=CFG["seed"]), source


# ----------------------------------------------------------------------------
# 2. Code generator (block composer)
# ----------------------------------------------------------------------------
def build(spec):
    """Compose one pipeline from a spec. Returns (code, leak_lines, decoy_lines)."""
    lk, v = spec["leak"], spec["variant"]
    dec = set(spec.get("decoys", []))
    SC = SCALERS[spec["scaler"]]
    m_imp, m_def, m_par, m_grid = MODELS[spec["model"]]
    imports = {"import numpy as np", "import pandas as pd", m_imp,
               f"from sklearn.preprocessing import {SC}"}
    c = spec["comments"]
    body = []

    def cm(text):
        if c:
            body.append(f"# {text}")

    # --- loading & setup
    body += ["§ = df.copy()",
             "§['date'] = pd.to_datetime(§['date'])",
             "§ = §.sort_values('date').reset_index(drop=True)",
             "H = 1",
             "cut_date = §['date'].iloc[int(len(§) * 0.7)]",
             "§['dek'] = (§['date'].dt.month - 1) * 3 + (§['date'].dt.day - 1) // 10"]

    # --- imputation
    cm("fill gaps in the raw series")
    body.append("cols = ['Q', 'T', 'P']")
    if lk == "L5":
        if v == 0:
            body.append("§[cols] = §[cols].interpolate(limit_direction='both')" + LEAK)
        elif v == 1:
            body.append("§[cols] = §[cols].bfill().ffill()" + LEAK)
        else:
            body.append("§[cols] = §[cols].fillna(§[cols].rolling(5, center=True, min_periods=1).mean())" + LEAK)
            body.append("§[cols] = §[cols].ffill()")
    elif "impute" in dec:
        body.append("§[cols] = §[cols].fillna(§[cols].shift(1).rolling(3, min_periods=1).mean()).ffill()" + DECOY)
    else:
        body.append("§[cols] = §[cols].ffill()")
    body.append("§ = §.dropna(subset=cols).reset_index(drop=True)")

    # --- decomposition / climatology
    cm("seasonal signal")
    dc = spec["decomp"]
    if dc in ("clim", "zclim"):
        if lk == "L8" and v == 0:
            body.append("clim = §.groupby('dek')['Q'].mean()" + LEAK)
        else:
            body.append("clim = §.loc[§['date'] < cut_date].groupby('dek')['Q'].mean()")
        body.append("§['Q_clim'] = §['dek'].map(clim)")
        if dc == "clim":
            body.append("§['Q_anom'] = §['Q'] - §['Q_clim']")
        else:
            if lk == "L8" and v == 2:
                body.append("§['Q_anom'] = (§['Q'] - §['Q_clim']) / §.groupby('dek')['Q'].transform('std')" + LEAK)
            else:
                body.append("sd = §.loc[§['date'] < cut_date].groupby('dek')['Q'].std()")
                body.append("§['Q_anom'] = (§['Q'] - §['Q_clim']) / §['dek'].map(sd)")
        dfeats = ["Q_clim", "Q_anom"]
    else:  # stl
        if lk == "L8" and v == 1:
            imports.add("from statsmodels.tsa.seasonal import STL")
            body += ["res = STL(§['Q'], period=36, robust=True).fit()" + LEAK,
                     "§['Q_trend'] = res.trend",
                     "§['Q_seas'] = res.seasonal"]
        elif "decomp" in dec:
            imports.add("from statsmodels.tsa.seasonal import STL")
            body += ["tr = §.loc[§['date'] < cut_date]",
                     "res = STL(tr['Q'].values, period=36, robust=True).fit()" + DECOY,
                     "seas = pd.Series(res.seasonal, index=tr.index).groupby(tr['dek']).mean()",
                     "§['Q_trend'] = §['Q'].rolling(36, min_periods=12).mean()",
                     "§['Q_seas'] = §['dek'].map(seas)"]
        else:
            body += ["clim = §.loc[§['date'] < cut_date].groupby('dek')['Q'].mean()",
                     "§['Q_trend'] = §['Q'].rolling(36, min_periods=12).mean()",
                     "§['Q_seas'] = §['dek'].map(clim) - clim.mean()"]
        dfeats = ["Q_trend", "Q_seas"]

    # --- features
    cm("lagged and aggregated predictors")
    fe = {
        "Q_l1": "§['Q_l1'] = §['Q'].shift(1)",
        "Q_l2": "§['Q_l2'] = §['Q'].shift(2)",
        "Q_rm3": "§['Q_rm3'] = §['Q'].rolling(3).mean()",
        "T_rm3": "§['T_rm3'] = §['T'].rolling(3).mean()",
        "P_sum3": "§['P_sum3'] = §['P'].rolling(3).sum()",
    }
    if lk == "L3":
        key, line = [("Q_rm3", "§['Q_rm3'] = §['Q'].rolling(3, center=True).mean()"),
                     ("P_sum3", "§['P_sum3'] = §['P'][::-1].rolling(3).sum()[::-1]"),
                     ("T_rm3", "§['T_rm3'] = §['T'].rolling(3).mean().shift(-1)"),
                     ("Q_l1", "§['Q_l1'] = §['Q'].shift(-1)")][v]
        fe[key] = line + LEAK
    elif "fe" in dec:
        key, line = [("Q_rm3", "§['Q_rm3'] = §['Q'].rolling(3, closed='left').mean()"),
                     ("T_rm3", "§['T_rm3'] = §['T'].ewm(span=3, adjust=False).mean()"),
                     ("P_sum3", "§['P_sum3'] = §['P'].shift(1).rolling(3).sum()")][spec["fe_decoy"]]
        fe[key] = line + DECOY
    body += list(fe.values())
    body += ["§['sin_d'] = np.sin(2 * np.pi * §['dek'] / 36)",
             "§['cos_d'] = np.cos(2 * np.pi * §['dek'] / 36)"]

    # --- target and target-related feature
    cm("forecast target: discharge H dekads ahead")
    body.append("§['y'] = §['Q'].shift(-H)")
    k = spec["tfe"]
    tname = ["Q_ratio", "y_sm", "dQ"][k]
    clean_t = ["§['Q_ratio'] = §['Q'] / (§['Q_rm3'] + 1e-6)",
               "§['y_sm'] = §['y'].shift(H).rolling(2).mean()",
               "§['dQ'] = §['Q'] - §['Q'].shift(1)"][k]
    leak_t = ["§['Q_ratio'] = §['y'] / (§['Q_rm3'] + 1e-6)",
              "§['y_sm'] = §['y'].rolling(2).mean()",
              "§['dQ'] = §['y'] - §['Q']"][k]
    if lk == "L4":
        body.append(leak_t + LEAK)
    else:
        body.append(clean_t + (DECOY if ("tfe" in dec and k == 1) else ""))

    feats = list(fe.keys()) + ["sin_d", "cos_d"] + dfeats + [tname]
    body.append(f"features = {feats}")
    body.append("§ = §.dropna(subset=features + ['y']).reset_index(drop=True)")
    body.append("X, y = §[features], §['y']")

    # --- L1 variant 0: scaling before the split
    mode = spec["mode"]
    if lk == "L1" and v == 0:
        body.append(f"X = pd.DataFrame({SC}().fit_transform(X), columns=X.columns, index=X.index)" + LEAK)

    # --- split
    cm("train / test split")
    if lk == "L2":
        imports.add("from sklearn.model_selection import train_test_split")
        if v == 0:
            body.append("X_tr, X_te, y_tr, y_te = train_test_split(X, y, test_size=0.3, random_state=42)" + LEAK)
        elif v == 1:
            body.append("X_tr, X_te, y_tr, y_te = train_test_split(X, y, test_size=0.3, shuffle=True, random_state=0)" + LEAK)
        else:
            body += ["idx = §.sample(frac=0.7, random_state=1).index" + LEAK,
                     "X_tr, y_tr = X.loc[idx], y.loc[idx]",
                     "X_te, y_te = X.drop(idx), y.drop(idx)"]
    elif spec["split"] == "tts":
        imports.add("from sklearn.model_selection import train_test_split")
        body.append("X_tr, X_te, y_tr, y_te = train_test_split(X, y, test_size=0.3, shuffle=False)"
                    + (DECOY if "split" in dec else ""))
    else:
        body += ["train = §['date'] < cut_date",
                 "X_tr, X_te, y_tr, y_te = X[train], X[~train], y[train], y[~train]"]

    # --- model / evaluation
    if mode == "holdout":
        if spec["piped"]:
            imports.add("from sklearn.pipeline import make_pipeline")
            cm("fit and evaluate")
            body += [f"model = make_pipeline({SC}(), {m_def})",
                     "model.fit(X_tr, y_tr)",
                     "pred = model.predict(X_te)"]
        else:
            cm("scaling")
            if lk == "L1" and v == 0:
                body.append("X_tr_s, X_te_s = X_tr.values, X_te.values")
            else:
                if lk == "L1" and v == 1:
                    body.append(f"sc = {SC}().fit(pd.concat([X_tr, X_te]))" + LEAK)
                elif lk == "L1" and v == 2:
                    body.append(f"sc = {SC}().fit(X)" + LEAK)
                else:
                    body.append(f"sc = {SC}().fit(X_tr)")
                body.append("X_tr_s, X_te_s = sc.transform(X_tr), sc.transform(X_te)")
            cm("fit and evaluate")
            body += [f"model = {m_def}",
                     "model.fit(X_tr_s, y_tr)",
                     "pred = model.predict(X_te_s)"]
        body.append("score = nse(y_te, pred)")

    elif mode == "tune":
        imports.add("from sklearn.pipeline import make_pipeline")
        cm("hyper-parameter selection")
        if lk == "L7" and v == 0:
            body += ["best, score = None, -np.inf",
                     f"for p in {m_grid}:",
                     f"    m = make_pipeline({SC}(), {m_par}).fit(X_tr, y_tr)",
                     "    s = nse(y_te, m.predict(X_te))" + LEAK,
                     "    if s > score:",
                     "        best, score = p, s"]
        elif lk == "L7" and v == 1:
            body += [f"scores = {{p: nse(y_te, make_pipeline({SC}(), {m_par}).fit(X_tr, y_tr).predict(X_te)) for p in {m_grid}}}" + LEAK,
                     "best = max(scores, key=scores.get)",
                     "score = scores[best]"]
        else:
            body += ["n_val = int(len(X_tr) * 0.2)",
                     "X_fit, X_val = X_tr.iloc[:-n_val], X_tr.iloc[-n_val:]",
                     "y_fit, y_val = y_tr.iloc[:-n_val], y_tr.iloc[-n_val:]",
                     "best, best_val = None, -np.inf",
                     f"for p in {m_grid}:",
                     f"    m = make_pipeline({SC}(), {m_par}).fit(X_fit, y_fit)",
                     "    s = nse(y_val, m.predict(X_val))",
                     "    if s > best_val:",
                     "        best, best_val = p, s",
                     "p = best",
                     f"model = make_pipeline({SC}(), {m_par}).fit(X_tr, y_tr)",
                     "score = nse(y_te, model.predict(X_te))"]

    else:  # cv
        imports |= {"from sklearn.pipeline import make_pipeline",
                    "from sklearn.model_selection import cross_val_score"}
        cm("cross-validated performance")
        body.append(f"pipe = make_pipeline({SC}(), {m_def})")
        cvarg = "cv"
        if lk == "L6" and v == 0:
            imports.add("from sklearn.model_selection import KFold")
            body.append("cv = KFold(n_splits=5, shuffle=True, random_state=0)" + LEAK)
        elif lk == "L6" and v == 1:
            imports.add("from sklearn.model_selection import ShuffleSplit")
            body.append("cv = ShuffleSplit(n_splits=5, test_size=0.2, random_state=0)" + LEAK)
        elif lk == "L6" and v == 2:
            cvarg = "5"
        else:
            imports.add("from sklearn.model_selection import TimeSeriesSplit")
            if "cv" in dec:
                body.append("cv = TimeSeriesSplit(n_splits=5, gap=H)" + DECOY)
            else:
                body.append("cv = TimeSeriesSplit(n_splits=5)")
        line = f"scores = cross_val_score(pipe, X_tr, y_tr, cv={cvarg}, scoring='r2')"
        body.append(line + (LEAK if (lk == "L6" and v == 2) else ""))
        body.append("score = scores.mean()")

    body.append("print(f'NSE = {score:.3f}')")

    # --- assemble
    D = spec["D"]
    body = [b.replace("§", D) for b in body]
    order = ["import numpy as np", "import pandas as pd"]
    head = order + sorted(i for i in imports if i not in order)
    head += ["", "",
             "def nse(obs, sim):",
             "    obs, sim = np.asarray(obs, dtype=float), np.asarray(sim, dtype=float)",
             "    return 1.0 - np.sum((obs - sim) ** 2) / np.sum((obs - obs.mean()) ** 2)",
             "", ""]
    if spec["style"] == "function":
        lines = head + ["def run_experiment(df):"] + ["    " + b for b in body] + ["    return score"]
    else:
        lines = head + body

    leak_lines, decoy_lines, clean = [], [], []
    for i, ln in enumerate(lines, start=1):
        if ln.endswith(LEAK):
            leak_lines.append(i)
            ln = ln[: -len(LEAK)]
        elif ln.endswith(DECOY):
            decoy_lines.append(i)
            ln = ln[: -len(DECOY)]
        clean.append(ln)
    return "\n".join(clean) + "\n", leak_lines, decoy_lines


# ----------------------------------------------------------------------------
# 3. Spec sampling
# ----------------------------------------------------------------------------
def base_spec(rng):
    return dict(
        leak=None, variant=0, decoys=[], fe_decoy=0,
        D=rng.choice(["df", "data", "frame", "ts"]),
        style=rng.choice(["script", "function"]),
        comments=rng.random() < 0.6,
        model=rng.choice(list(MODELS)),
        scaler=rng.choice(list(SCALERS)),
        decomp=rng.choice(["clim", "zclim", "stl"]),
        tfe=rng.randrange(3),
        split=rng.choice(["date", "tts"]),
        mode=rng.choice(["holdout", "tune"]),
        piped=rng.random() < 0.3,
    )


def leaky_spec(lt, i, rng):
    s = base_spec(rng)
    v = i % N_VARIANTS[lt]
    s.update(leak=lt, variant=v)
    if lt == "L1":
        s.update(mode="holdout", piped=False)
    elif lt == "L2":
        s.update(mode="holdout", split="tts")
    elif lt == "L4":
        s.update(tfe=v)
    elif lt == "L6":
        s.update(mode="cv")
    elif lt == "L7":
        s.update(mode="tune")
    elif lt == "L8":
        s.update(decomp=["clim", "stl", "zclim"][v])
    return s


def hard_spec(rng):
    s = base_spec(rng)
    decoys = rng.sample(["impute", "decomp", "fe", "tfe", "split", "cv"], rng.choice([2, 3]))
    s["decoys"] = decoys
    if "decomp" in decoys:
        s["decomp"] = "stl"
    if "fe" in decoys:
        s["fe_decoy"] = rng.randrange(3)
    if "tfe" in decoys:
        s["tfe"] = 1
    if "split" in decoys:
        s["split"] = "tts"
    if "cv" in decoys:
        s["mode"] = "cv"
    return s


# ----------------------------------------------------------------------------
# 4. Oracle
# ----------------------------------------------------------------------------
def execute(code, style, df):
    ns = {"__name__": "tleak_snippet", "df": df.copy()}
    with contextlib.redirect_stdout(io.StringIO()):
        exec(compile(code, "<snippet>", "exec"), ns)
        score = ns["run_experiment"](df.copy()) if style == "function" else ns["score"]
    return float(score)


def run_item(spec, df):
    code, ll, dl = build(spec)
    t0 = time.time()
    try:
        score, err = execute(code, spec["style"], df), None
    except Exception as e:  # noqa: BLE001
        score, err = None, f"{type(e).__name__}: {e}"
    return dict(code=code, leak_lines=ll, decoy_lines=dl, nse_reported=score,
                error=err, exec_s=round(time.time() - t0, 3))


# ----------------------------------------------------------------------------
# 5. Main
# ----------------------------------------------------------------------------
def main():
    os.makedirs(CFG["out_dir"], exist_ok=True)
    rng = random.Random(CFG["seed"])
    df, source = load_data()
    print(f"data: {source}, n={len(df)}, gaps={int(df[['Q', 'T', 'P']].isna().sum().sum())}")

    leaky, twins, hards = [], [], []
    for lt in LEAK_TYPES:
        for i in range(CFG["n_per_type"]):
            s = leaky_spec(lt, i, rng)
            t = dict(s, leak=None)
            r_l, r_t = run_item(s, df), run_item(t, df)
            meta = {k: s[k] for k in ("D", "style", "comments", "model", "scaler",
                                      "decomp", "tfe", "split", "mode", "piped")}
            pid = f"{lt}-{i:02d}"
            d = (None if None in (r_l["nse_reported"], r_t["nse_reported"])
                 else r_l["nse_reported"] - r_t["nse_reported"])
            leaky.append(dict(pair_id=pid, label=1, leak_type=lt, variant=s["variant"],
                              **meta, **r_l, nse_twin=r_t["nse_reported"], delta_nse=d,
                              confirmed=(d is not None and d > CFG["delta_thr"])))
            twins.append(dict(pair_id=pid, label=0, leak_type=None, variant=None,
                              twin_of_type=lt, **meta, **r_t))
        print(f"  {lt} done")
    for i in range(CFG["n_hard"]):
        s = hard_spec(rng)
        meta = {k: s[k] for k in ("D", "style", "comments", "model", "scaler",
                                  "decomp", "tfe", "split", "mode", "piped")}
        hards.append(dict(pair_id=f"HN-{i:02d}", label=0, leak_type=None, variant=None,
                          hard_negative=True, decoys=s["decoys"], **meta, **run_item(s, df)))
    print("  hard negatives done")

    clean_pick = rng.sample(twins, CFG["n_clean"])
    bench = leaky + [dict(t, hard_negative=False) for t in clean_pick] + hards
    rng.shuffle(bench)
    for j, b in enumerate(bench):
        b["id"] = f"TLB-{j:03d}"
        b.setdefault("hard_negative", False)

    def dump(path, rows):
        with open(path, "w", encoding="utf-8") as f:
            for r in rows:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")

    dump(os.path.join(CFG["out_dir"], "tleakbench.jsonl"), bench)
    dump(os.path.join(CFG["out_dir"], "twins.jsonl"), twins)

    L = pd.DataFrame(leaky)
    summ = (L.groupby("leak_type")
              .agg(n=("delta_nse", "size"),
                   confirmed_pct=("confirmed", lambda x: 100 * x.mean()),
                   delta_mean=("delta_nse", "mean"),
                   delta_median=("delta_nse", "median"),
                   delta_min=("delta_nse", "min"),
                   delta_max=("delta_nse", "max"),
                   nse_twin_mean=("nse_twin", "mean"))
              .round(4))
    summ["description"] = [LEAK_TYPES[k] for k in summ.index]
    summ.to_csv(os.path.join(CFG["out_dir"], "oracle_summary.csv"))

    errs = [r for r in leaky + twins + hards if r["error"]]
    print(f"\nitems in benchmark: {len(bench)}  "
          f"(leaky {sum(b['label'] for b in bench)}, clean {sum(1 - b['label'] for b in bench)})")
    print(f"execution errors: {len(errs)}")
    for e in errs[:5]:
        print("  ", e["pair_id"], e["error"])
    print("\nNSE inflation per leakage type (leaky - clean twin):")
    print(summ.drop(columns="description").to_string())
    print(f"\nsaved to {CFG['out_dir']}")


if __name__ == "__main__":
    main()
