# Bonnie Chatting / 幫你決定?

A bilingual iOS decision-making app inspired by temple divination practices.
Got a question you can't decide on? Ask the app — and let tradition guide you.

> Marketing names by locale:
> - **zh-Hant** (primary, Taipei / HK / Macao): **幫你決定?**
> - **en**: **Bonnie Chatting**

## v0.1 — 筊杯 (Moon Blocks)

The first divination mechanism is **筊杯** (*jiao bei*), the pair of wooden
crescent blocks tossed at temples to ask the deities yes/no questions.

- Type in your question (or skip it).
- Optionally relabel the three outcomes with your own meanings.
- Tap **擲筊 / Toss**. The blocks tumble through the air and land at random.
- The screen reveals 聖筊 / 笑筊 / 陰筊, your custom answer, and the traditional reading.

Three more mechanisms are planned for v0.2–0.4:
- **求籤** — fortune sticks
- **轉盤** — spinning wheel
- **擲銅板** — coin flip

The mechanism picker already lives in the top-right toolbar so adding the
others is a drop-in change.

## Stack

- **UI:** SwiftUI (iOS 17+)
- **Persistence:** `@AppStorage` — no SwiftData yet (no models worth saving in v0.1)
- **Networking:** none. Local-only, no accounts, no analytics, no backend
- **Localization:** Xcode String Catalog (`Localizable.xcstrings`) — `zh-Hant` (primary) + `en`
- **No third-party packages.** Pure Apple stack

## Repo layout

```
.
├── project.yml                           # xcodegen spec — .xcodeproj is GENERATED, not committed
├── bonniechatting/
│   ├── BonnieChattingApp.swift           # @main entry
│   ├── ContentView.swift                 # NavigationStack + mechanism picker
│   ├── Theme.swift                       # parchment / cinnabar / gold / wood palette
│   ├── Models/
│   │   └── DivinationMechanism.swift     # protocol all mechanisms conform to
│   ├── Mechanisms/
│   │   ├── JiaoBeiMechanism.swift        # 筊杯 descriptor + outcome enum
│   │   ├── JiaoBeiView.swift             # 筊杯 screen + toss animation
│   │   └── MoonBlockShape.swift          # SwiftUI Shape + face renderer
│   ├── Localization/
│   │   ├── Localizable.xcstrings         # zh-Hant + en strings
│   │   ├── en.lproj/InfoPlist.strings    # English display name
│   │   └── zh-Hant.lproj/InfoPlist.strings  # Traditional Chinese display name
│   └── Assets.xcassets/                  # AccentColor (cinnabar) + AppIcon
└── README.md
```

## Open in Xcode

1. Install xcodegen if needed: `brew install xcodegen`
2. Generate the Xcode project:
   ```
   cd /Users/frank/bonnie-chatting
   xcodegen generate
   ```
3. Open it:
   ```
   xed bonniechatting.xcodeproj
   ```
4. In Xcode, wait for indexing, then press **⌘R**.

Signing should auto-detect Frank's team (`632H46CT74`) since it's hard-coded in
`project.yml`.

## Bundle / display info

- **Bundle ID:** `com.frankfu.bonniechatting`
- **Marketing version:** 0.1.0
- **Display name:** `幫你決定?` (zh-Hant), `Bonnie Chatting` (en)
- **Deployment target:** iOS 17.0
- **Devices:** iPhone, portrait only
- **Primary locale:** `zh-Hant`

## Future work

- v0.2: fortune sticks (籤)
- v0.3: spinning wheel (轉盤)
- v0.4: coin flip
- Designed app icon (the current one is a Pillow-rendered 筊 character on parchment)
- Onboarding / first-launch explainer
- TestFlight + App Store submission (after v0.4)
