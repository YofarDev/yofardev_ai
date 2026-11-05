# README screenshots

These are real frames from the macOS app recordings captured for the final Rive rework review on 1 November 2026. They show the stage UI, Rive avatar, weather prop, captions, and scenes. They are not mockups or Android device screenshots.

The conversations and weather in these recordings are scripted using the integration harness, with in-memory preferences and no live API requests. The recordings use macOS `say`; production speech uses Kokoro. See the [capture notes](../rive/review/m12/wow/README.md) for details and instructions for recording again.

| Image | Recording | Time in recording |
| --- | --- | --- |
| `stage-living-room.png` | `rive/review/m12/wow/wow2.mp4` | 0.0 s |
| `weather-tablet.png` | `rive/review/m12/wow/wow2.mp4` | 6.8 s |
| `campfire-story.png` | `rive/review/m12/wow/wow1.mp4` | 6.0 s |
| `beach-sunset.png` | `rive/review/m12/wow/wow3.mp4` | 11.5 s |

The PNGs are extracted at the recordings' original 486 × 832 resolution without retouching. From the repository root, for example:

```bash
ffmpeg -y -ss 6.8 -i rive/review/m12/wow/wow2.mp4 -frames:v 1 screenshots/weather-tablet.png
```

The old numbered screenshots showed the previous avatar and interface and have been replaced.
