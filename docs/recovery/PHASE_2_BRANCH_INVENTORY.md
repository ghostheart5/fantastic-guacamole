# ChronoSpark Phase 2 Branch Inventory

The full per-ref inventory (name, tip, date, upstream, merge-base with `main`, unique-commit count, represented status, classification, and tip subject) was captured before Phase 2 documentation in the protected local artifact:

`C:\Users\keegan radetski\ChronoSparkRecovery\phase2-20260812-164222\branch-inventory.json`

SHA-256: `B99EDF6EC5C688D948BDA7439BA01C50391B78F2D851C01814B6E780ADCB89D1`

| Inventory dimension | Result |
| --- | ---: |
| Local branches | 12 |
| Remote `origin/*` branches (excluding symbolic `origin/HEAD`) | 146 |
| Total preserved refs assessed | 158 |
| Fully represented / redundant refs | 92 |
| Unique history — review required | 59 |
| Current active work refs | 4 |
| Authoritative candidate refs | 1 |
| Unknown — preserve refs | 2 |

Local branches were all retained. The current branch, `backup-before-review-20260808` at `9b3880d5477d87d67ff0b236bd490e978eb02084`, is the sole authoritative candidate. `main` is behind it by 108 commits and ahead by 61 commits, so neither branch is fully represented by the other.

No branch was merged, deleted, rebased, pushed, or otherwise rewritten.
