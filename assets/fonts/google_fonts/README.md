# Bundled fonts

Static TTFs bundled so `google_fonts` never fetches at runtime
(`GoogleFonts.config.allowRuntimeFetching = false` in `lib/main.dart`).
`google_fonts` matches these by file name `<Family>-<Variant>.ttf`.

| Family | Files | Source | Licence |
|--------|-------|--------|---------|
| Outfit | `Outfit-Regular/Medium/SemiBold.ttf` | https://github.com/Outfitio/Outfit-Fonts (`fonts/ttf/`) | SIL OFL 1.1, `OFL-Outfit.txt` |
| Plus Jakarta Sans | `PlusJakartaSans-Regular/Medium.ttf` | https://github.com/tokotype/PlusJakartaSans (`fonts/ttf/`) | SIL OFL 1.1, `OFL-PlusJakartaSans.txt` |

Add a weight here only when the app uses it (a missing file throws in tests
and offline).
