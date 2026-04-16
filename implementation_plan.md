# Sync Web App Changes → iOS App

The web app (`toonpod-trivia`) has received several important updates in the last ~10 commits (v288–v301). This plan mirrors all those logic changes into the native iOS SwiftUI app.

---

## Summary of Web App Changes to Port

| Web File | Change | Impact |
|---|---|---|
| `types/game.ts` | Added `'elimination'` to `QuestionType` | iOS needs `elimination` case in `QuestionType` enum + renderer routing |
| `store/gameStore.ts` | `finishQuestion` now applies `partyScoreMultiplier` to party-mode scores and decrements it | iOS `GameViewModel.finishQuestion` needs multiplier support |
| `lib/specialRounds.ts` | `pick()` helper added | Utility already trivially available in Swift |
| `lib/specialRounds.ts` | `specialBuzzIn` — on hand-raise, calls `SpeechInput.abortListen()` to stop leaking pending transcript | N/A – voice pipeline is different on iOS |
| `lib/specialRounds.ts` | Grid reveal `'question'` case: now generates a live bonus 4_options Q, reads the answer, awards cash from `PARTY_PRIZE_LADDER` | iOS `GameViewModel` + party state needs: `specialRoundQuestion`, `partyScoreMultiplier` state, and `PARTY_PRIZE_LADDER` constant |
| `renderers/FourOptionsRenderer.tsx` | Wrong-answer highlight now also triggers on `hotSeatPlayerAnswer` if it's a wrong option | iOS `FourOptionsRenderer` wrong-answer logic needs matching fix |
| `config/constants.ts` | `APP_VERSION` bumped to `v301` | iOS `Constants.swift` version bump |

---

## Proposed Changes

### 1. Models — `GameModels.swift`

#### [MODIFY] [GameModels.swift](file:///Users/pixelforge/AndroidStudioProjects/Trivia/Trivia/Models/GameModels.swift)

- Add `elimination = "elimination"` to `QuestionType` enum.
- Add `loginStreakBonus: Int` field to `GameResult` (already missing from Swift vs web).

---

### 2. Config — `Constants.swift`

#### [MODIFY] [Constants.swift](file:///Users/pixelforge/AndroidStudioProjects/Trivia/Trivia/Config/Constants.swift)

- Bump `appVersion` to `"v301"`.
- Add `partyPrizeLadder: [Int]` — matching `PARTY_PRIZE_LADDER` from the web.

---

### 3. ViewModels — `GameViewModel.swift`

#### [MODIFY] [GameViewModel.swift](file:///Users/pixelforge/AndroidStudioProjects/Trivia/Trivia/ViewModels/GameViewModel.swift)

Key changes:
- Add `partyScoreMultiplier: PartyScoreMultiplier?` published state (`struct PartyScoreMultiplier { var questionsLeft: Int; var factor: Double }`).
- Add `specialRoundQuestion: Question?` published state (for bonus question display during grid reveal).
- Update `finishQuestion` to apply `partyScoreMultiplier` when in party mode (mirrors the web's `effectivePrize = mul ? totalPrize * mul.factor : totalPrize` logic, and decrements the multiplier).
- Add `loginStreakMultiplier: Double` and wire it into `finishQuestion` (matches `loginStreakBon` added in web).
- Add `decrementMultiplier()`, `setPartyScoreMultiplier()`, `setSpecialRoundQuestion()` helpers.

---

### 4. Renderers — `FourOptionsRenderer.swift`

#### [MODIFY] [FourOptionsRenderer.swift](file:///Users/pixelforge/AndroidStudioProjects/Trivia/Trivia/Views/Game/Renderers/FourOptionsRenderer.swift)

Fix wrong-answer highlighting logic to also show wrong highlight on the `hotSeatPlayerAnswer` option (if it's wrong), matching the web fix:

```
wrong: showReveal && opt !== effectiveCorrect && (
  (selectedIdx !== null && selectedIdx === i) ||
  (!!hotSeatPlayerAnswer && opt === hotSeatPlayerAnswer)
)
```

For the iOS version: the renderer needs a `hotSeatPlayerAnswer: String?` parameter and updated wrong-answer condition.

---

### 5. Renderers — `QuestionRenderer.swift`

#### [MODIFY] [QuestionRenderer.swift](file:///Users/pixelforge/AndroidStudioProjects/Trivia/Trivia/Views/Game/Renderers/QuestionRenderer.swift)

- Add a `default` / `elimination` case that shows a basic `FourOptionsRenderer` (since the elimination question type is a special party round handled programmatically, not via a unique UI renderer).

---

### 6. New Renderer — `EliminationRenderer.swift`

#### [NEW] [EliminationRenderer.swift](file:///Users/pixelforge/AndroidStudioProjects/Trivia/Trivia/Views/Game/Renderers/EliminationRenderer.swift)

A placeholder view for the elimination round (shows players still active and current prompt), since the actual logic is orchestrated via voice in the web but can have a fallback UI in iOS.

---

## Open Questions

> [!IMPORTANT]
> **Party Mode State**: The iOS app has `partyMode: Bool` in `GameViewModel` but does NOT yet have `partyScores`, `partyStreaks`, `partyLifelines`, `partyScoreMultiplier`, etc. This plan adds only the `partyScoreMultiplier` (needed for the scoring fix) and `specialRoundQuestion`. Full party mode state porting is **out of scope** for this PR unless you want me to also do that.

> [!NOTE]  
> The `hotSeatPlayerAnswer` property doesn't exist yet in the iOS `GameViewModel`. The `FourOptionsRenderer.swift` fix requires either (a) passing it through from the ViewModel, or (b) a simpler approach of just fixing the revealed-wrong logic for the tapped index. I'll implement option (b) since hot seat voice is not yet wired in iOS.

---

## Verification Plan

### Automated
- Xcode build check (no compile errors).

### Manual
- Confirm `elimination` type questions decode without crashing.
- Confirm wrong-answer color highlights correctly in `FourOptionsRenderer` after answer reveal.
- Confirm `partyPrizeLadder` constants are accessible.
- Confirm version string shows `v301`.
