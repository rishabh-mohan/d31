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
# D-Day UI

## Results and enrollment

Screens for the application results, Final Decision, Confirm Enrollment, the
Student ID / share scene, the completion summary and the ending reward.
Evidence: `screenshots/dday-applications-2026-10-25/HANDOFF.md` sections
10-13. Engine: `docs/DDAY-FLOW.md`. Everything here reveals stored engine
state; nothing rolls dice.

Files: `lib/ui/dday_results.dart` (the flow), `lib/ui/dday_widgets.dart`
(crest, envelope, result card, confetti, Student ID card),
`lib/ui/end_screen.dart` (completion summary, reward modal),
`lib/ui/printable_score_card.dart`, `lib/ui/student_photo.dart`,
`lib/ui/share_image.dart`. Tests: `test/dday_results_test.dart`.

### Contract

`DdayResultsFlow(game:, onFinished:)` owns everything from the results title
through enrollment and the Student ID scene, then calls `onFinished` once; the
host then plays the authored ending events (`GameScreen._sitCsat`) and shows
`EndScreen` (same constructor as before, now the completion summary).

Resume: the start page comes from saved state, never a reroll.
`finalDecided` -> share scene; `resultsReviewed` (or no applications) ->
Final Decision page; every envelope confirmed -> combined results page;
some confirmed -> the next envelope (confirmed cards sit behind the stack);
none -> the title.

### Sequence

1. Title: near-black, two-line "Application Results Announcement" fades in
   (0.8 s), holds (1.5 s), fades out; a tap skips. RECONSTRUCTED timings.
2. Envelope stack: one pastel envelope per application in submission order,
   front = first; the active one shows "<n>% Acceptance Rate" and the large
   school-coloured glowing control (school, department, Browse Application
   Results). School colour = catalog `colorCode`.
3. Browse: one 2.8 s controller with staged Intervals: others leave and fade,
   the active one centres/enlarges (0-20%), wobbles (20-38%), flap opens
   (38-55%), letter rises (50-72%), the school-coloured rectangle glows over
   a tinted page (60-88%), the white result card appears with school-coloured
   confetti (82-100%). Confirm (school colour) moves the card up behind the
   stack (0.5 s) and brings the next envelope forward; each Confirm calls
   `game.confirmNextResult()` once. Reduced motion jumps straight to the card
   and shows no confetti.
   RECONSTRUCTED: the green double-chevron button skips to the revealed card
   of the current envelope (the recording never taps it); it never confirms.
   RECONSTRUCTED: the Accepted card (same layout, green "Accepted"), the
   envelope drawing and all timings.
4. Combined results: black page, cards stacked in submission order, orange
   Confirm (`game.confirmResults()`), a step separate from the per-envelope
   Confirms.
5. Final Decision (user spec): "Final Decision" fades in. With acceptances the
   cards compact under the title and a "Final Decision" button appears;
   pressing it fades the rejected cards out and slides the accepted ones to
   the centre; tapping one opens Confirm Enrollment. All rejected: the
   single white peach-bordered academy card (names read from the catalog,
   id 0; the two-pill logo is drawn, the SVG is not rendered).
6. Confirm Enrollment modal (X, large crest, school, course, Confirm) ->
   small cream loading square (0.8 s, taps ignored) -> `enroll(id)` or
   `enrollRetake()` -> share scene. The engine is called after the loading
   square, so closing the modal never enrolls.
7. Share scene: school-tinted radial gradient, looping multicolour confetti,
   no global-rank lines (user decision). Landscape Student ID card (75% width);
   "Upload your photo to your student ID!" (gallery picker); dark panel with
   Instagram / X (snack bar "Not available in this build.") and download
   (saves the card as a PNG to the gallery); wide Confirm -> `onFinished`.
   The Student ID number is blank (not in the recording).
8. Completion summary (`EndScreen`): header, Student ID card, panel titled
   with the ending name, five stat chips (`state.stats`), the printable
   Graduation Exam Score Card (`state.csat`, saved Score / Top %), Back to
   Main Menu.
9. Back to Main Menu: brief spinner; if `AccountStore.current
   .pendingEndingReward` exists, "Ending Reward Obtained!" with the Standard
   Trait Pack image and "<n> Standard Trait Pack(s)"; Confirm calls
   `acknowledgeEndingReward()` (claim once) and lands on the first route
   (Home). The recording's transient share-page flash is not built, nor the
   "X2 Reward Pack active" chip (no purchase exists to double it).

### New persisted fields

* `GameState.resultsRevealed` (int): envelope results opened and confirmed.
  Engine helpers `Game.resultsRevealed` / `Game.confirmNextResult()` in
  `dday.dart`; `confirmResults()` now also sets it to the application count.
* `GameState.studentPhotoPath` (String?, absolute): the player's Student ID
  photo, copied to `<documents>/student_photos/` by `StudentPhotos.pick()`.
  Saved with the run and copied to `RunRecord.studentPhoto` (History record)
  when the run closes; absent means the character portrait.

### Packages

`image_picker` (gallery photo), `gal` (save the card PNG). Android: only
`WRITE_EXTERNAL_STORAGE` with `maxSdkVersion=28` for `gal`.

### Not covered

Audio, haptics; the recording's exact easing; Student ID number; Instagram / X
sharing; the "X2" reward chip; a photo editor/cropper.
