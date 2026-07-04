# Legacy mechanics — preserved, not shipped

This folder holds the original **筊杯 (Jiaobei / Moon Blocks)** and
**求籤 (Fortune Sticks)** implementations. They were swapped out of the
shipping build in v1.0.1 to address Apple review concern **4.3(b)**
("Design – Spam / duplicate concepts") ahead of TestFlight review.

The code is preserved verbatim — including the visual polish work on
`MoonBlockShape` (curved-vs-flat asymmetric treatment, radial gradient
with horizontal falloff, inner-moon composition, sharp light/dark
contrast, curved highlight geometry) and the bamboo-cylinder + stick-draw
flow in `FortuneSticksView`. When Apple approves the app and the
ritual mechanics are cleared to re-appear, this is the archive to
restore from.

## What's here

| File | Purpose |
| --- | --- |
| `JiaoBeiMechanism.swift` | Conformance to `DivinationMechanism` — id, localized display name, SF Symbol. |
| `JiaoBeiView.swift` | Toss animation + sheng / xiao / yin outcome resolution. |
| `MoonBlockShape.swift` | The `Shape` + gradient stack for the two moon-block faces. All the visual polish lives here. |
| `FortuneSticksMechanism.swift` | Conformance to `DivinationMechanism` for 求籤. |
| `FortuneSticksView.swift` | Bamboo-cylinder shake + stick-draw + locale-aware default options. |
| `screenshots/` | (empty on first commit — drop `02-jiaobei.png` / `05-sticks.png` here from the App Store Connect archive if you want them tracked.) |

## Build status

**Excluded from the app target.** `project.yml` has
`excludes: ["Legacy/**"]` under the `bonniechatting` source path, so
xcodegen skips this folder when regenerating the Xcode project. Nothing
here is compiled or linked into the shipping binary.

## How to bring one back

1. Move the `.swift` file(s) from `bonniechatting/Legacy/` back into
   `bonniechatting/Mechanisms/`.
2. Re-register the mechanism in the `mechanisms:` list in
   `bonniechatting/ContentView.swift`.
3. Confirm the `Localizable.xcstrings` entries are still present — the
   `jiaobei.*` and `sticks.*` keys were kept intentionally when v1.0.1
   was merged, so this should just work.
4. `xcodegen generate` and build.

If you'd rather keep the folder as an archive and re-enable via a build
flag instead of moving files, wrap each restored `.swift` file in
`#if RESTORE_LEGACY_MECHANICS ... #endif` and drop the exclude from
`project.yml`. Toggle the flag in your scheme's Swift build settings.
