# Bundled fonts

Static TTFs bundled so `google_fonts` never fetches at runtime
(`GoogleFonts.config.allowRuntimeFetching = false` in `lib/main.dart`).
`google_fonts` matches these by file name `<Family>-<Variant>.ttf`.

| Family | Files | Source | Licence |
|--------|-------|--------|---------|
| Fraunces | `Fraunces-Regular/Medium/SemiBold.ttf` | Static instances served by Google Fonts (fonts.gstatic.com), as fetched by `google_fonts`; project https://github.com/undercasetype/Fraunces | SIL OFL 1.1, `OFL-Fraunces.txt` (https://raw.githubusercontent.com/undercasetype/Fraunces/master/OFL.txt) |
| Manrope | `Manrope-Regular/Medium.ttf` | Static instances served by Google Fonts (fonts.gstatic.com), as fetched by `google_fonts`; project https://github.com/googlefonts/manrope | SIL OFL 1.1, `OFL-Manrope.txt` (https://raw.githubusercontent.com/google/fonts/main/ofl/manrope/OFL.txt) |

Fraunces and Manrope are the Storybook night look's fonts. Checked static (no
`fvar` table); SHA-256:

| File | SHA-256 |
|------|---------|
| `Fraunces-Regular.ttf` | `097259a58f5d36e83a9cb47d9faf54d89bc62ae07e8fc563a5f015f73ae629e6` |
| `Fraunces-Medium.ttf` | `e37ca7854810d52284c225fa3063a4cc1ac86058f60c603f33285666b91ddaf9` |
| `Fraunces-SemiBold.ttf` | `089e9beb4054ffa5870fd97578bcb6bc8e2664ba610d1a76389be114997d1d33` |
| `Manrope-Regular.ttf` | `be2c40a58fbf6c664a5103f086beaad13008d72dc642b82cc214feaaac3b4512` |
| `Manrope-Medium.ttf` | `f85a9b09c9449d2093b67354ac5894890891fa31daf02c470f0d4206b1e03f2d` |

Add a weight here only when the app uses it (a missing file throws in tests
and offline).
