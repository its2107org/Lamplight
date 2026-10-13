# Lamplight

Ian's bedtime reading app for iPad (it works on iPhone too). Each reading night it shows that night's five pieces from the Bradbury reading challenge (a paper, an AI read, an essay, a short story and a poem) and lets him read them in a calm, warm, dark reader.

## Made for bedtime

- Always dark, in warm amber tones with no bright white or blue. Three page colours (Ember, Candle, Moonless), a choice of fonts and sizes, and an extra dimmer that goes below the screen's lowest brightness.
- Pieces run in bedtime order: the demanding paper first, the poem last.
- Each night's reading is downloaded in advance (on opening and in the background), so it opens instantly and works offline.
- Web pages are cleaned up with Mozilla's [Readability](https://github.com/mozilla/readability) (Apache 2.0). PDFs are shown with their colours flipped and warmed. Pages that can't be cleaned up are shown as the original page in night colours.
- Remembers your place in every piece. A "goodnight" screen at the end recaps what you learnt.
- Optional wind-down reminder on reading nights. Widgets for the Home Screen and Lock Screen. Siri: "Open tonight's reading in Lamplight".
- Before 4am still counts as the previous evening.

## The reading list

`content/nights.json` is the reading list. The "Ray Bradbury reading challenge" thread keeps it up to date; the app downloads it from this repository, so changing it needs no new build. A copy is built into the app as a fallback.

Each night: `night`, `date` ("Mon 12 Oct"), optional `isoDate` ("2026-10-12"), `theme`, `themeLine`, `field`, `paperType`, `learn`, and `items` with `paper`, `ai`, `essay`, `story` and `poem`. Each item has `title`, `by`, `url`, optional `note`, optional `readUrl` (a better copy to read, such as a direct PDF) and optional `minutes`.

## How it's built

Native SwiftUI (iOS 17+) with a widget extension; the Xcode project is generated from `project.yml` with XcodeGen. GitHub Actions builds it and sends it to TestFlight using the same Apple secrets and `Match-Secrets` certificate store as Ian's other apps. It rebuilds on the 1st of each month so it never expires.

## Workflows

1. **Set up with Apple**: `check` the secrets, create the `identifiers`, then `certificates`, then (after the App Store Connect listing exists) `testers`.
2. **Check build and screenshots**: runs on every push; builds for the iPad simulator, tries every link on the reading list and saves screenshots to the `screenshots` branch.
3. **Build Lamplight**: builds and uploads to TestFlight. Runs monthly and on demand.
