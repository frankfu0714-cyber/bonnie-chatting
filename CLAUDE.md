# Working notes for Claude in this repo

This is **Bonnie Chatting / 幫你決定?**, a bilingual iOS divination app. Frank
is the sole developer (Apple ID `frankfu0714@gmail.com`, team ID `632H46CT74`).
The primary locale is **Traditional Chinese (zh-Hant)** — Frank is in Taipei
and the target market is TW/HK/Macao. English is the secondary locale.

## How to build

```
cd /Users/frank/bonnie-chatting
xcodegen generate
xcodebuild -project bonniechatting.xcodeproj -scheme bonniechatting \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -configuration Debug build
```

The `.xcodeproj` is **generated, not committed** (it's in `.gitignore`).
Always edit `project.yml` for build settings, never the Xcode project directly.

## Conventions

- **No third-party packages.** Pure Apple stack — SwiftUI, AudioToolbox, SF Symbols.
- **No backend.** No accounts, no analytics, no network calls. Local-only.
- **Persistence:** `@AppStorage` is fine for small user prefs. Add SwiftData
  only when a real model warrants it (history of past questions, maybe).
- **Localization:** every user-visible string goes in `Localizable.xcstrings`,
  keyed like `jiaobei.outcome.sheng.title`. Both `zh-Hant` and `en` entries
  are required. Don't ship a string that's only in one language.
- **Theme:** colors live in `Theme.swift`. Don't sprinkle `Color(red:...)`
  through views. The accent color (`Theme.cinnabar`) is mirrored in
  `Assets.xcassets/AccentColor.colorset` and applied at the scene root.
- **File layout:** mirrors wordstory-ios — `Models/`, `Views/`, `Services/`
  if needed. Mechanisms get their own `Mechanisms/` folder.

## Adding a new divination mechanism

1. Create `bonniechatting/Mechanisms/<Name>Mechanism.swift`. Conform to
   `DivinationMechanism`. Give it a stable `id`, a `displayName` localized key,
   and an SF Symbol `iconName`.
2. Create the view file `<Name>View.swift` alongside it. Self-contained — no
   shared singletons.
3. Add the mechanism to the `mechanisms: [any DivinationMechanism]` list in
   `ContentView.swift`. The picker UI is already wired.
4. Add all new strings to `Localizable.xcstrings` (both locales).

## Visual / vibe

- **Sacred temple aesthetic.** Aged paper background, deep cinnabar red (`#8B2E2A`),
  warm gold (`#C8A95C`), wood browns.
- **Typography:** zh-Hant headlines use `Songti TC` if available; falls back to
  system serif. Body uses the default system font (PingFang TC in zh-Hant,
  SF Pro in en, both selected by the system automatically).
- **Animations:** weighty, not bouncy. Easings: `.easeOut` for tosses,
  `.spring(response: 0.5, dampingFraction: 0.55)` for landings. Things should
  feel like they have heft.

## Versioning

Bump `MARKETING_VERSION` in `project.yml` between user-visible releases.
Bump `CURRENT_PROJECT_VERSION` between every TestFlight upload (App Store
Connect requires a fresh build number each time).

## Out-of-scope (don't add without asking)

- Cloud sync / accounts / sign-in
- Analytics SDKs (Firebase, Mixpanel, etc.)
- Push notifications
- In-app purchases — Frank wants this to feel like a gift to the community first

## Sources of inspiration / parallel project

- `/Users/frank/wordstory-ios/` — same author, same conventions (xcodegen,
  String Catalog, generated-project pattern, ink/paper theme). When in doubt,
  look there.
