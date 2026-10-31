"""
Dailyle Multi-User & Multi-Accent AI Evaluation Simulation Suite
Simulates 5 distinct speaker profiles, calculates PER (Phoneme Error Rate)
and validates scoring accuracy against standard phoneme targets.
"""

import sys
import io
import re
from typing import Dict, List, Tuple

# Ensure UTF-8 printing in Windows Console
if sys.platform.startswith("win"):
    sys.stdout.reconfigure(encoding="utf-8")

class SimulationCase:
    def __init__(
        self,
        user_id: str,
        user_name: str,
        accent_profile: str,
        sentence_text: str,
        standard_ipa: str,
        simulated_spoken_ipa: str,
        expected_score_range: Tuple[int, int],
        max_per: float
    ):
        self.user_id = user_id
        self.user_name = user_name
        self.accent_profile = accent_profile
        self.sentence_text = sentence_text
        self.standard_ipa = standard_ipa
        self.simulated_spoken_ipa = simulated_spoken_ipa
        self.expected_score_range = expected_score_range
        self.max_per = max_per

def needleman_wunsch_phoneme_align(exp_ipa: str, act_ipa: str) -> Dict:
    a = list(re.sub(r"[\/ˈˌ. ]", "", exp_ipa))
    b = list(re.sub(r"[\/ˈˌ. ]", "", act_ipa))
    n, m = len(a), len(b)

    dp = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        dp[i][0] = i
    for j in range(m + 1):
        dp[0][j] = j

    for i in range(1, n + 1):
        for j in range(1, m + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            dp[i][j] = min(
                dp[i - 1][j - 1] + cost,
                dp[i - 1][j] + 1,
                dp[i][j - 1] + 1
            )

    i, j = n, m
    subs, dels, ins = 0, 0, 0

    while i > 0 or j > 0:
        if i > 0 and j > 0 and dp[i][j] == dp[i - 1][j - 1] + (0 if a[i - 1] == b[j - 1] else 1):
            if a[i - 1] != b[j - 1]:
                subs += 1
            i -= 1
            j -= 1
        elif i > 0 and dp[i][j] == dp[i - 1][j] + 1:
            dels += 1
            i -= 1
        else:
            ins += 1
            j -= 1

    total_errors = subs + dels + ins
    per = round((total_errors / max(n, 1)) * 100.0, 2)
    score = max(0, 100 - round(per))

    return {
        "score": score,
        "per": per,
        "substitutions": subs,
        "deletions": dels,
        "insertions": ins,
        "total_phonemes": n
    }

def run_simulation():
    test_cases = [
        SimulationCase(
            user_id="USR-001",
            user_name="David Miller",
            accent_profile="Native General American (US)",
            sentence_text="Think through three thin things.",
            standard_ipa="θɪŋk θruː θriː θɪn θɪŋz",
            simulated_spoken_ipa="θɪŋk θruː θriː θɪn θɪŋz",
            expected_score_range=(95, 100),
            max_per=5.0
        ),
        SimulationCase(
            user_id="USR-002",
            user_name="Emma Watson",
            accent_profile="Native Received Pronunciation (UK)",
            sentence_text="Think through three thin things.",
            standard_ipa="θɪŋk θruː θriː θɪn θɪŋz",
            simulated_spoken_ipa="θɪŋk θruː θriː θɪn θɪŋz",
            expected_score_range=(90, 100),
            max_per=8.0
        ),
        SimulationCase(
            user_id="USR-003",
            user_name="Nguyen Van An",
            accent_profile="Vietnamese - Dropping Final Consonants",
            sentence_text="Think through three thin things.",
            standard_ipa="θɪŋk θruː θriː θɪn θɪŋz",
            simulated_spoken_ipa="θɪŋ θruː θriː θɪn θɪŋ",
            expected_score_range=(80, 92),
            max_per=20.0
        ),
        SimulationCase(
            user_id="USR-004",
            user_name="Tran Thi Mai",
            accent_profile="Vietnamese - Dental Fricatives (θ -> t)",
            sentence_text="Think through three thin things.",
            standard_ipa="θɪŋk θruː θriː θɪn θɪŋz",
            simulated_spoken_ipa="tɪŋk truː triː tɪn tɪŋz",
            expected_score_range=(65, 80),
            max_per=30.0
        ),
        SimulationCase(
            user_id="USR-005",
            user_name="Le Hoang Nam",
            accent_profile="Vietnamese - Severe Combined Interference",
            sentence_text="Think through three thin things.",
            standard_ipa="θɪŋk θruː θriː θɪn θɪŋz",
            simulated_spoken_ipa="tɪŋ tru tri tɪn tɪŋ",
            expected_score_range=(45, 65),
            max_per=55.0
        ),
    ]

    print("==========================================================================================")
    print("                     DAILYLE MULTI-ACCENT SIMULATION EVALUATION REPORT                    ")
    print("==========================================================================================")
    print(f"{'User':<16} | {'Accent Profile':<42} | {'Score':<6} | {'PER':<7} | {'Status':<8}")
    print("-" * 92)

    all_passed = True
    for case in test_cases:
        res = needleman_wunsch_phoneme_align(case.standard_ipa, case.simulated_spoken_ipa)
        score = res["score"]
        per = res["per"]
        min_s, max_s = case.expected_score_range

        passed = (min_s <= score <= max_s) and (per <= case.max_per)
        status = "PASSED" if passed else "FAILED"
        if not passed:
            all_passed = False

        print(f"{case.user_name:<16} | {case.accent_profile:<42} | {score:<6} | {per}%   | {status:<8}")

    print("=" * 92)
    print(f"Overall Test Suite Status: {'ALL PASSED (100%)' if all_passed else 'SOME TESTS FAILED'}")

if __name__ == "__main__":
    run_simulation()
