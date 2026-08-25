This folder needs `NotoSansEthiopic-Regular.ttf` before the app will render
Amharic text correctly.

It could NOT be downloaded automatically — the sandbox this scaffold was
built in has no internet access.

## To fix:
1. Go to https://fonts.google.com/noto/specimen/Noto+Sans+Ethiopic
2. Download the font family
3. Copy the Regular weight .ttf file into this folder, named exactly:
   NotoSansEthiopic-Regular.ttf
4. Run `flutter pub get` again

Without this file, `pubspec.yaml`'s `fonts:` section will fail to build
(missing asset), or Amharic text will silently fall back to a font that
can't render Ge'ez script (shows as boxes/tofu).
