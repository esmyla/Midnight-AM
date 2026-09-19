# Midnight

Turn 2 AM motivation into a contract with your future self.

Type "Tomorrow, block TikTok and Instagram until I finish two LeetCode problems." gpt-5-nano
parses it into a commitment. Tomorrow morning, opening a locked app pulls you straight back into
Midnight until you submit a screenshot that gpt-5-mini verifies. Giving up is allowed, but the
lock stays on until 7 PM.

## How blocking works (no paid Apple account needed)

Apple's Family Controls API requires a paid developer account. Midnight instead exposes an App
Intent, **Get Midnight Lock Status**, and the user creates one Shortcuts automation covering all
their distracting apps: "When any of these apps is opened: Get Midnight Lock Status; If it is
LOCKED, Open App Midnight." Shortcuts does the opening itself, so there is no confirmation dialog.
The intent also stamps the time it answered LOCKED, which the app uses to show the "Nice try"
banner. The in-app Setup screen walks through the taps. Known escape: disabling the automation.

## Layout

| Path | Purpose |
|---|---|
| `Midnight/Views` | Capture, Confirm, Setup, Active, Verify, Give Up, History |
| `Midnight/Services/CommitmentEngine.swift` | Lifecycle, local notifications |
| `Midnight/Services/CommitmentParser.swift` | Sentence to structured commitment (gpt-5-nano) |
| `Midnight/Services/VerificationService.swift` | Screenshot or photo judged by gpt-5-mini |
| `Midnight/Services/LLMClient.swift` | Raw HTTP to the OpenAI Responses API with strict JSON schemas |
| `Midnight/Intents/EnforceIntent.swift` | The App Intents Shortcuts calls |

## Setup

1. `cp Secrets.example.xcconfig Secrets.xcconfig`; fill in your Team ID and OpenAI API key.
2. `brew install xcodegen && xcodegen generate`
3. Open `Midnight.xcodeproj`, plug in your iPhone, run.
4. In the app, lock a commitment, then follow the Setup screen to add one automation per app.

## Known limits (MVP)

- One live commitment at a time.
- The API key is in the bundle. Move model calls behind a proxy before giving this to anyone else.
- Financial and social collateral are not implemented.
