# Apple Say

A native macOS Document app for system speech. Write or open UTF-8 text, LRC, or Enhanced LRC in one editor, choose a system Voice, Preview, and Export audio. Speech synthesis uses `/usr/bin/say`; no cloud services or additional runtimes are required.

## Build and run

Requires macOS 14 or later and the Xcode Command Line Tools with Swift 6 or later.

```sh
./scripts/build-app.sh
open "build/Apple Say.app"
```

The script builds a standalone, ad hoc signed app. Copy it to Applications for normal use. Distribution to other Macs requires your own Developer ID signing and notarization.

## Use

New, Open, Save, and Open Recent use the standard macOS Document workflow. The editor detects valid timed text automatically; malformed or mixed syntax remains Plain Text. Voice Language filters available Voices without translating or editing the Document. The Voice menu opens macOS settings to add Voices and manage Personal Voice.

The Speech Inspector includes Speech Speed, Pitch, and the audio formats supported by the current Mac. Advanced settings expose available data formats, channels, bitrate, converter quality, and playback destinations. Export opens the standard save panel.

| Action | Shortcut |
| --- | --- |
| Preview | ⌘Return |
| Stop | ⌘. |
| Export Audio | ⇧⌘E |
| Show or hide Speech Inspector | ⌥⌘I |

Documents save as UTF-8 text; speech settings belong to the current window and are not embedded in the text file. For Timed Text, timestamps constrain absolute audio placement. Apple Say measures rendered speech and increases Speech Speed when needed to fit the next timestamp; an impossible fit reports a Timing Error.

Personal Voice requires authorization in the app and a Personal Voice available on the Mac. If the current system cannot provide a safe audio export route, Export reports the limitation.

## Development

```sh
swift build
swift test
```

Product specification and work items live in [GitHub Issues](https://github.com/thedavidweng/apple-say/issues). [CONTEXT.md](CONTEXT.md) defines project terminology.
