"""
Rosetta service reachability without /healthz.

On GCP, /healthz is often blocked or reserved. Prefer GET / (home) or POST /evaluate.
"""

from __future__ import annotations

from typing import Tuple

import requests

_EVALUATE_SMOKE = {
    "input": "connection probe",
    "context": {"environment": "staging", "industry": "general"},
}


def check_rosetta_reachable(base_url: str, timeout: int = 10) -> Tuple[bool, str]:
    """
    Return (ok, detail). Does not use /healthz.

    Order:
      1) GET {base}/  (home — typical Cloud Run landing)
      2) GET {base}/health (common alternative)
      3) POST {base}/evaluate (authoritative for this sandbox)
    """
    base = base_url.strip().rstrip("/")

    # 1) Home and light GET probes (avoid /healthz on GCP)
    for path in ("/", "/health"):
        url = f"{base}{path}" if path != "/" else f"{base}/"
        try:
            r = requests.get(url, timeout=min(5, timeout))
            if 200 <= r.status_code < 500:
                return True, f"GET {path or '/'}"
        except Exception as e:
            continue

    # 2) Evaluate — real API this repo depends on
    try:
        r = requests.post(
            f"{base}/evaluate",
            json=_EVALUATE_SMOKE,
            timeout=timeout,
        )
        if r.status_code == 200:
            return True, "POST /evaluate"
        return False, f"POST /evaluate -> {r.status_code}"
    except Exception as e:
        return False, str(e)
