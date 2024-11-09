<p align="center"> 
  <img src="https://github.com/javier-games/app-memo/blob/7aee97544898cb6218156752bda6733306ada3dc/Documentation.docc/Resources/memo_github_branding-banner.png"/>
</p>

[![Itch.io](https://img.shields.io/badge/itch.io-%23FF0B34.svg?logo=Itch.io&logoColor=white)](https://javier-games.itch.io/memo)

# Memo Flash Cards

Designed to enhance your learning experience by using customizable flash cards. Whether you're learning a new language, studying complex terms, or memorizing facts, Memo Flash Cards provides a simple, user-friendly interface to create, manage, and practice with your own flash card decks.

<p align="center"> 
  <img src="https://github.com/javier-games/app-memo/blob/7aee97544898cb6218156752bda6733306ada3dc/Documentation.docc/Resources/memo_github_branding-screen_shots.png"/>
</p>

## Features

- **Create Decks and Cards**: Organize your study material by creating decks. Each deck can contain multiple cards with customizable "front" and "back" texts.
- **Add Optional Hints**: Cards can include an optional hint field to provide additional help or a small clue.
- **Practice Mode**: Shuffle and practice with your cards in each deck. Cards appear one-by-one, allowing you to focus on individual items.
    - **Mark as Correct, Wrong, or Skip**: During practice, you can mark each card as correct or incorrect. Skipped cards are placed at the back of the deck for later review.
- **Import and Export Decks**: Share your decks or back them up easily with JSON import and export options.
- **Flexible Study**: Perfect for language learning, memorizing trivia, studying for exams, or any topic that benefits from flash cards.

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

1. **Create a Deck**: Tap on "New Deck" and give your deck a meaningful title.
2. **Add Cards to Deck**: Open a deck and tap "Add Card." Enter text for both the front and back of the card, and optionally, add a hint.
3. **Practice a Deck**: Select a deck and tap "Practice." Cards will be shuffled and presented one by one.
4. **Mark as Correct, Wrong, or Skip**: While practicing, mark each card as correct, incorrect, or skip it to move it to the back of the deck.
5. **Import/Export Decks**: In the settings menu, you can export your decks to JSON or import new decks from JSON files.

## JSON Format for Import/Export

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

When importing, ensure that the JSON file follows this format for successful parsing.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
