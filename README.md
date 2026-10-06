<p align="center"> 
  <img src="https://github.com/javier-games/app-memo/blob/7aee97544898cb6218156752bda6733306ada3dc/Documentation.docc/Resources/memo_github_branding-banner.png"/>
</p>

[![Itch.io](https://img.shields.io/badge/itch.io-%23FF0B34.svg?logo=Itch.io&logoColor=white)](https://javier-games.itch.io/memo)

# Memo Decks

Designed to enhance your learning experience by using customizable flash cards. Whether you're learning a new language, studying complex terms, or memorizing facts, Memo Decks provides a simple, user-friendly interface to create, manage, and practice with your own flash card decks.

<p align="center"> 
  <img src="https://github.com/javier-games/app-memo/blob/7aee97544898cb6218156752bda6733306ada3dc/Documentation.docc/Resources/memo_github_branding-screen_shots.png"/>
</p>

## Features

- **Create Decks and Cards**: Organize your study material by creating decks. Each deck can contain multiple cards with customizable "front" and "back" texts, and a name, icon and colour of its own.
- **Add Optional Hints**: Cards can include an optional hint field to provide additional help or a small clue.
- **Practice**: Cards appear one-by-one so you can focus on individual items.
    - **Mark as Correct, Wrong, or Skip**: Correct and wrong both settle a card; skipping sends it to the back of the deck for later, and does not count as an answer.
    - **Session results**: Finishing a deck shows how many you got right, wrong and skipped, and offers another run.
- **Practice Options**: Four orders to practise in, an inverse mode that flips which side asks the question, and a limit so you can drill part of a deck. See [Practice Options](#practice-options).
- **Progress per Card**: Each card counts consecutive correct answers towards a target. A wrong answer sends it back to zero, so the count reflects what you currently know rather than what you once did.
- **Import and Export Decks**: Import decks from the **Add** menu on the deck list, and share a deck from the **share** button at the top of it. Both work in JSON and CSV.
- **Reorder**: Long-press and drag to rearrange decks or cards. Card order is what the *In Order* practice mode deals.
- **Flexible Study**: Perfect for language learning, memorizing trivia, studying for exams, or any topic that benefits from flash cards.

## Requirements

- iOS 17.0 or later, iPhone
- Xcode 16 or later to build

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/javier-games/app-memo
   ```

2. Open the project in Xcode:
   ```bash
   open Memo.xcodeproj
   ```

3. Build and run the project on your iOS simulator or device.

## Usage

1. **Create a Deck**: On the deck list, tap **Add** → **New Deck**, then give it a name, an icon and a colour.
2. **Add Cards to Deck**: Open a deck and tap **Add**. Enter text for both sides, and optionally a hint for each. Both text fields grow to fit, so a term above its reading stays readable while you type it.
3. **Practice a Deck**: Open a deck and tap **Practice**. Tap or drag the card to flip it; swipe it right for correct, left for wrong.
4. **Mark as Correct, Wrong, or Skip**: Correct and wrong both move the deck on. Skipping sends the card to the back and does not move the progress bar — the card is deferred, not answered, so a run cannot end on a skip.
5. **Adjust How You Practise**: Tap the **sliders** button at the top of a deck. See [Practice Options](#practice-options).
6. **Edit a Deck**: Tap the **pencil** button at the top of a deck to change its name, icon or colour.
7. **Edit a Card**: Tap it in the deck, or tap the **pencil** button while practising to fix the card in front of you.
8. **Reorder**: Long-press a deck or a card and drag.
9. **Import Decks**: On the deck list, tap **Add** and choose **JSON** or **CSV**. Memo shows what the file contains before anything is added, and importing only ever adds — nothing already in your library is changed.
10. **Export a Deck**: Open a deck and tap the **share** button at the top, then choose **JSON** or **CSV**.

## Practice Options

Reached from the **sliders** button at the top of a deck. The settings apply to
every deck and are captured when a run starts, so changing them mid-run will not
reshape a session already in progress.

| Option | Default | What it does |
| --- | --- | --- |
| **Inverse** | Off | Swaps which side asks and which answers, hints included. |
| **Mode** | Random | The order cards are dealt in — see below. |
| **Cards** | All | Practise a slice of the deck rather than all of it. Stored as "no limit" rather than a number, so it keeps meaning across decks of different sizes. |
| **Practice Target** | 10 | Correct answers a card needs before it counts as learned. **0** turns progress tracking off entirely, without discarding progress already recorded. |

### Modes

| Mode | Order |
| --- | --- |
| **Random** | The whole deck, shuffled. |
| **In Order** | The deck as you arranged it, start to finish. Always the whole deck, so the card limit does not apply. |
| **Least Practiced** | Lowest progress first, ties keeping the deck's order. The same run every time. |
| **Least Practiced, Shuffled** | Lowest progress first, but ties vary each run. |

The two *Least Practiced* modes put the cards you keep getting wrong — and the
ones you have never seen — ahead of the ones you have already learned. Combined
with **Cards**, they give you "the twenty I am worst at". With **Practice
Target** set to 0 every card sits at zero progress, so both fall back to their
unordered form.

### Progress

A card's progress goes up by one for each correct answer and back to zero after
a wrong one, up to the Practice Target. The deck list shows each card's standing
— grey while short of the target, green once reached. If you have already
practised a card elsewhere, you can set its count by hand in the card editor.

## File Formats

Decks are exported to JSON in the following structure:

```json
{
  "deckList": [
    {
      "name": "Food",
      "icon": "🥩",
      "color": "253,251,102,255",
      "cardList": [
        {
          "frontText": "Tea",
          "frontHintText": "",
          "backText": "お茶",
          "backHintText": "「お」ちゃ"
        },
        {
          "frontText": "Sushi",
          "frontHintText": "",
          "backText": "お寿司",
          "backHintText": "🍣"
        }
      ]
    }
  ]
}
```

Everything except `cardList` is optional, so a hand-written file needs only what
you care about. Cards with no front or no back are skipped, and the import
summary says how many were left out.

### CSV

CSV has nowhere to record a deck's name, icon or colour, so the **file name
becomes the deck name** — a CSV export is named after its deck, and a CSV import
names the new deck after the file. The columns are:

```csv
front,frontHint,back,backHint
Tea,a hot drink,Té,
"a, b",,"say ""hi""",
```

The header row is optional, and short rows are padded, so a plain two-column
file imports fine.

## iCloud Sync (built, currently turned off)

Decks are stored in SwiftData. The app is written to replicate them across your
devices through CloudKit, but **sync is disabled in this build** because
CloudKit needs a paid Apple Developer Program membership — a free personal team
cannot provision the iCloud or Push Notifications capabilities, and a build
carrying those entitlements will not sign at all.

With sync off the app runs entirely on-device. Nothing is missing or stubbed:
the data model already has the shape CloudKit requires (a default on every
property, optional relationships with inverses, no unique constraints, explicit
sort indices), so turning sync on later needs no migration and no model changes.

### Turning it on

1. Set `isCloudSyncEnabled` to `true` in `Memo/Shared/AppConfiguration.swift`.
2. In the **Memo** target → **Signing & Capabilities**, add:
   - **iCloud**, with **CloudKit** ticked and the container
     `iCloud.com.javier.memo` (press **+** to create it if absent). It must
     match `Memo/Memo.entitlements`, which is still in the repository and still
     correct. The container identifier is independent of the bundle
     identifier and should not be changed to follow it — adding the capability restores the
     `CODE_SIGN_ENTITLEMENTS` build setting that points at it.
   - **Background Modes** → **Remote notifications**.
   - **Push Notifications**.

Only `MemoModelContainer` and `CloudSyncStatus` branch on the flag.

### Checking whether sync is working

Sync needs two devices signed in to the *same* iCloud account, and is not
instant. Filter Console on the subsystem matching the target's bundle
identifier (the app derives it from there); the app reports its store mode and
account status at launch:

```
[<bundle-id>:Persistence] Sync disabled in this build; opened local-only store.
[<bundle-id>:Sync] iCloud sync is disabled in this build.
```

With sync enabled and an account signed in those become:

```
[<bundle-id>:Persistence] Opened store with CloudKit configuration.
[<bundle-id>:Sync] iCloud account status: Syncing with iCloud
```

The first line only reports how the store was *configured*. SwiftData opens a
CloudKit-backed store even with no entitlement and no account and simply never
replicates — the `Sync` line is the one that tells you whether replication can
actually happen.

### Before releasing with sync on

CloudKit keeps separate development and production schemas. Deploy the schema to
production in the [CloudKit Console](https://icloud.developer.apple.com) before
shipping, or synced devices will find no records.

## Project Structure

```
Memo/
├── Models/       Deck and Card, the SwiftData models
├── Persistence/  the store, its CloudKit configuration, the one-time migration
├── Practice/     the practice rules, the session, and the screens that use them
├── Transfer/     the JSON and CSV file formats, import and export
└── Shared/       small pieces used in more than one place
```

The practice rules — modes, the card limit, which side asks, how progress is
recorded — are plain values with no SwiftUI and no storage, kept apart from the
views that show them and the store that persists them. Adding a rule means
adding it to `PracticeSettings` and, if it affects ordering, to
`PracticePlanner`; the options panel builds itself from `PracticeMode.allCases`.

## Tests

```bash
xcodebuild test -project Memo.xcodeproj -scheme Memo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Unit tests cover the practice session, the settings and planner, per-card
progress, reordering, and the file formats — including the legacy
`UserDefaults` migration against the exact JSON documented above. UI tests cover
launch and deck creation.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
