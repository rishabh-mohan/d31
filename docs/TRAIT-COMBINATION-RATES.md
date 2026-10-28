# Trait combination probabilities — 25 October 2026

The user supplied `Traits Combination Probability Information.pdf` from
Downloads. Page 1 contains the published rank-result table below; page 2
contains no additional rates. This supersedes the former highest-input-rank
plus 25% upgrade approximation. Trait combining is separate from stationery.

| Inputs | S | A | B | C |
| --- | ---: | ---: | ---: | ---: |
| AAA | 6% | 94% | 0% | 0% |
| AAB | 4% | 81% | 15% | 0% |
| ABB | 2% | 68% | 30% | 0% |
| BBB | 0% | 55% | 45% | 0% |
| BBC | 0% | 37% | 53% | 10% |
| BCC | 0% | 19% | 61% | 20% |
| CCC | 0% | 1% | 69% | 30% |

The PDF omits AAC, ABC and ACC. The user explicitly clarified these in chat:
AAC uses ABB; ABC uses BBB; ACC uses BBC. Those mappings are user decisions,
not claims about the published document. Input order does not matter.

SSS continues to return S under the existing S-only rule; the PDF supplies
no S-input row. Exactly three unlocked copies are required, mixed S/non-S
inputs remain rejected, and results still draw from the selected campaign's
eligible rank pool. Copies are consumed only after a result is available.
This reference establishes rank odds, not individual-card probabilities.

`Account.combineRates` stores the published percentages;
`combineRateAliases` stores the user mappings. `combineRatesFor` canonicalizes
input order. The draw and the Combine Rates dialog share these definitions,
including the displayed mappings, so UI text cannot retain the old 25% rule.

Verification: 22 focused tests pass and Flutter analysis is clean. Tests
cover all input permutations, 100 deterministic percentile bins for every
valid input mix across Standard/Winter/Retry (3,300 actual combines), exact
AAA/CCC boundaries, copy consumption, existing locks/S restrictions, and the
rates dialog. Rendered source pages are retained locally in
`references/recovery/trait-combine-probabilities/`.

Deployment: profile APK SHA-256
`6f638fb38819d01850cb79af5d6eb0c5fef8c487c4c3323a307c3f699daa21ba`
built and installed on Nord N30 `7c2c1cc8` with `adb install -r`, preserving
app data. Launch returned Status: ok and hardware Impeller initialized.
Manage Traits, Combine Traits and the full Combine Rates panel were visually
checked on the awake phone; the seven rows, three aliases and Confirm fit
without clipping. Sampled app logs have no RenderFlex, missing-asset or
unhandled/FATAL errors. No owned traits were consumed during device checks.
The panel screenshot is retained locally as `phone-rates.png` beside the
source render and startup logs. Source PDF SHA-256:
`4516c0a0fc438dc118e27d1f611271172c509404f6fc27facd89d3c585c1c197`.
