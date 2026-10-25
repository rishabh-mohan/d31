# Global and Taiwan university names — 2026-10-25

User request: replace the imported catalog's deliberately altered names with
the intended real school names. All ten Global and seventy Taiwan labels now
come from `content/kss/university-names.json`, shared by account-catalog and
pack-badge generation through `tools/university_names.py`.

Examples: Sfantord → Stanford; Oxfsword → University of Oxford; Taiwen → Taiwan;
Prudence → Providence; National Midland → National Central; National Allied →
National United; Austral Taiwen → Southern Taiwan. Tsinghua (Global) and National
Tsing Hua (Taiwan) remain distinct institutions and spellings. The two China/Asia
University names retain a Taiwan qualifier to distinguish their institutions.

Sources for English names and romanization:

- [Taiwan Ministry of Education university directory](https://english.moe.gov.tw/fp-21-14441-4EC5E-1.html)
  and its [Study in Taiwan school finder](https://www.studyintaiwan.org/how-to-apply/school).
- [MOE open directory including English names](https://data.gov.tw/dataset/33207)
  provides the source directory context; its direct CSV download returned an
  access error during this pass, so no automated CSV reconciliation is claimed.
- [University of Auckland](https://www.auckland.ac.nz/en/about-us/about-the-university.html),
  [Nanyang Technological University](https://www.ntu.edu.sg/about-us/history),
  and [IIT Bombay](https://www.iitb.ac.in/deanpl/tenders/fss/tdfss.pdf).
- [MacKay's official rename notice](https://www.mmu.edu.tw/en/xmdoc/cont?xsmsid=0Q006406225391344137)
  establishes MacKay Medical University from August 2025; this label deliberately
  uses its current name rather than the older College name.

Identity inferences: imported ID 206's Oakland is treated as Auckland, consistent
with the Korean name and international set. ID 209's Nanyoung is treated as NTU.
ID 208's Pampay is interpreted as IIT Bombay from the Bombay-like name and the
lotus-and-ribbon crest; this is an inference about the parody's intended target,
not a recovered explicit real-name mapping. Its original art is retained.

Generation comparison confirmed eighty changed labels in each of
`assets/account/catalog.json`, `packs/kss16/badges.json` and
`packs/kss20/badges.json`. University IDs, ranks, colors, regions, sort IDs and
badge effects remain identical. Admission cutoffs and Korean/US renaming are
unaffected. Old account enrollment counters need no migration because IDs stay
the same. Generated files are ignored; change the tracked overlay and rebuild.
