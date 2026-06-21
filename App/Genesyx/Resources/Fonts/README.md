# Fonts

Drop the brand font files here, then they'll bundle automatically (listed in `project.yml`
under `UIAppFonts`). Expected files:

- `Outfit-Regular.ttf`, `Outfit-Medium.ttf`, `Outfit-SemiBold.ttf` (display)
- `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf` (body)

Both are free (Google Fonts / SIL Open Font License):
- Outfit: https://fonts.google.com/specimen/Outfit
- Inter: https://fonts.google.com/specimen/Inter

After adding the files, switch `App/Genesyx/UI/Theme/Typography.swift` from `.system(size:…)`
to `.custom("Outfit"/"Inter", size:…)`. Until then the app falls back to the system font at
the correct sizes/weights (matching the Android build's behaviour).
