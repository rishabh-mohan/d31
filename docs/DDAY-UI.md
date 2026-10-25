# D-Day UI: exam cards, score announcement, Submit route

Screens built on the engine API in docs/DDAY-FLOW.md. Evidence:
`screenshots/dday-applications-2026-10-25/HANDOFF.md` sections 1-9.
Tests: `test/dday_submit_ui_test.dart`.

## Flow and files

| Step | File |
|---|---|
| Exam card in the hand area; tap -> `takeExamSubject()` + one-line scene | `game_screen.dart` (`_ExamHand`, `_takeExam`), `exam_cards.dart` |
| Response line as a normal dialogue message | `Game.examResponseEvent(turn)` (additive helper in `engine/dday.dart`; presentation only) |
| Orchestrator, resumes by `ddayStage` | `csat_screen.dart` (`CsatScreen.show`, `pushResults`) |
| Score announcement dialog, printable card, download | `score_announcement.dart`, `share_image.dart` |
| Submit route, tray, Apply? modal | `submit_page.dart` |
| Tab bodies and shared state (`SubmitModel`) | `submit_tabs.dart` |
| Cards, crests, stars, school cards | `submit_widgets.dart` |
| University Collection modal | `university_collection.dart` |
| Toasts (queued, burnt orange) | `toast.dart` |
| Results hand-off (placeholder) | `dday_results.dart` |

`GameScreen._sitCsat` returns immediately while `examCardsPending` (the hand
area shows the cards); after the last card `_takeExam` calls it again, which
runs `CsatScreen.show`: announcement -> Submit -> `DdayResultsFlow(game:,
onFinished:)` -> the existing ending loop. A save taken between cards resumes
at the next untaken card; every stage resumes from `ddayStage`.

## Reconstructed choices

* Sort menu: Acceptance rate high to low (engine order), low to high, Name
  (school, then major). Not captured.
* Range slider starts at 20-80 (a recorded setting, not a proven default).
* "Badge owned" = the university's badge is in this run's chosen badge set
  (`state.badgeIds`); the build has no other badge inventory.
* Opening a school (Search within Schools) lists its eligible majors as
  recommendation cards with Apply and a back arrow. Back (Android) also closes it.
* Unavailable school overlay text names stories: 16 = "31-Day Mode",
  20 = "Retry Year".
* Instagram / X show "Not available in this build."; the download icon saves
  the printable card to the gallery (`gal`, Android `WRITE_EXTERNAL_STORAGE`
  only up to API 28).
* Turn In with no candidates only shows a toast; 1-2 candidates may be turned in.
* While the keyboard is open the tray is hidden (the original's keyboard covers
  it) and the list uses the remaining height.
* University Collection did not exist in the app: Badge Effect lists the
  pack's badges with their effects, Standard = Korea schools, Elite =
  Special/Global/Taiwan, owned bright, others dimmed.
* The `Korea` sub-tab reads `US` when the run uses the US college set.
