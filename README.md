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
- **AI-Assisted Import**: Turn a text file or a PDF into a deck with Claude or ChatGPT, using your own API key. See [AI-Assisted Import](#ai-assisted-import).
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

## AI-Assisted Import

Memo can hand a file to an AI model and turn the answer into decks. It works
with Claude (Anthropic) and ChatGPT (OpenAI), and uses **your own API key**:
neither company lets another app sign in to a Claude or ChatGPT subscription,
so a key is the only way to connect.

1. Open **Settings** (the gear on the deck list), choose the assistant, paste
   an API key and tap **Connect**. The key is checked against the service
   before it is saved, and is kept in the device's Keychain.
2. In the **Add** menu, the **AI Assisted** section offers **Text File** (plain
   text, CSV, JSON, Markdown…) and **PDF**. Until a tool is connected it shows
   **Connect an AI Tool…** instead, which opens Settings.
3. Pick the file and, if you like, add instructions of your own — "only chapter
   2", "answers in Spanish". They are added to Memo's instructions, never used
   in place of them.
4. Memo shows the decks and card counts it got back. Nothing is added to your
   library until you confirm.

The model is asked to answer in the JSON format above, and its answer goes
through the same importer as a file you picked yourself, so the same rules
apply: cards with no front or no back are skipped, and import only ever adds.

**Using this costs money.** The file is sent to the service you connected,
which charges your API account for every request, separately from any Claude or
ChatGPT subscription. Settings and the import screen both say so. Text files are limited to 1 MB and PDFs to 20 MB; a larger file is
refused, not trimmed.

## iCloud Sync

Decks are stored in SwiftData and replicated across your devices through
CloudKit, in the private database of the iCloud account signed in on the
device. There is nothing to switch on: with an account signed in the decks
sync, and with none they stay on the device until one is. Settings shows which
of the two is happening.

The data model has the shape CloudKit requires: a default on every property,
optional relationships with inverses, no unique constraints, explicit sort
indices.

### What sync depends on

1. `isCloudSyncAvailable` is `true` in `Memo/Shared/AppConfiguration.swift`.
2. The **Memo** target is signed with `Memo/Memo.entitlements` (iCloud with
   CloudKit and the container `iCloud.com.javier.memo`, plus Push
   Notifications) and declares the remote-notification background mode. The
   container identifier is independent of the bundle identifier and should not
   be changed to follow it.
3. In the Apple developer portal, the App ID has **iCloud** (with that
   container assigned) and **Push Notifications** enabled. This needs a paid
   Apple Developer Program membership; with a free personal team, set the flag
   to `false` and remove `CODE_SIGN_ENTITLEMENTS` from the target, or the build
   will not sign.
4. The CloudKit schema is deployed to production; see below.

With the flag `false` the app stays on-device and Settings says nothing about iCloud.

### Checking whether sync is working

Sync needs two devices signed in to the *same* iCloud account, and is not
instant. Filter Console on the subsystem matching the target's bundle
identifier (the app derives it from there); the app reports its store mode and
account status at launch. With an account signed in:

```
[<bundle-id>:Persistence] Opened store with CloudKit configuration.
[<bundle-id>:Sync] iCloud account status: Syncing with iCloud
```

The first line only reports how the store was *configured*. SwiftData opens a
CloudKit-backed store even with no entitlement and no account and simply never
replicates — the `Sync` line is the one that tells you whether replication can
actually happen.

### The CloudKit schema

CloudKit keeps separate development and production schemas, and TestFlight and
App Store builds only ever use production. The record types are created in the
development schema the first time a development build saves a deck and a card
while signed in to iCloud. They then have to be copied across with **Deploy
Schema Changes** in the [CloudKit Console](https://icloud.developer.apple.com).
Until that is done, a TestFlight build keeps working on-device but replicates
nothing.

## Project Structure

```
Memo/
├── AI/           the AI services, the prompt, and AI-assisted import
├── Models/       Deck and Card, the SwiftData models
├── Persistence/  the store, its CloudKit configuration, the one-time migration
├── Practice/     the practice rules, the session, and the screens that use them
├── Settings/     the app-wide settings screen
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
