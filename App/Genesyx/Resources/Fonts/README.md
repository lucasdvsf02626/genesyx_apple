# Optional brand fonts

The shipping app uses Apple's system font and does not declare unbundled fonts in `UIAppFonts`.
If the design later adopts the brand fonts, add these files here:

- `Outfit-Regular.ttf`, `Outfit-Medium.ttf`, `Outfit-SemiBold.ttf` (display)
- `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf` (body)

Both are free (Google Fonts / SIL Open Font License):
- Outfit: https://fonts.google.com/specimen/Outfit
- Inter: https://fonts.google.com/specimen/Inter

After adding the files, register them in `project.yml`/`Info.plist`, confirm they are copied into
the built app, and switch `App/Genesyx/UI/Theme/Typography.swift` from `.system(size:…)` to
`.custom("Outfit"/"Inter", size:…)`.
