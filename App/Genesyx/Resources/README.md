# Resources

## App icon
Add `AppIcon-1024.png` to `Assets.xcassets/AppIcon.appiconset/` — a **1024×1024 PNG, no alpha
channel, no rounded corners** (Apple rounds it). Xcode generates all other sizes from this one.
The catalog + `Contents.json` are already wired (`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`).

## Accent color
`Assets.xcassets/AccentColor.colorset` is set to the electric-lavender brand color
(light `#4D4DAA`, dark `#9B7BD8`) and used as the app's global tint.

## Fonts
See `Fonts/README.md` — drop the Outfit + Inter `.ttf` files in `Fonts/`.
