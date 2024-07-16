# Yofardev AI (iOS & Android & Web)

Yofardev AI is a small fun project that brings life to a Large Language Model (LLM) through an animated avatar. Users can interact with the AI assistant through text (or dictate to text), and the app responds with generated text-to-speech and lip-synced animations.

[Free web demo](https://yofardev-ai.web.app) (not all features available because of platform limitations). You need to set your Google Api Key in the settings

<p align="center">
  <img src="screenshots/1.png" width="20%" />
  <img src="screenshots/2.png" width="20%" />
  <img src="screenshots/3.png" width="20%" />
  <img src="screenshots/4.png" width="20%" />
</p>

## Features

- Native text-to-speech and lip-synced animations (customizable voices)
- You can ask Yofardev AI to change clothes and background (sometimes it doesn't want to do it)
- Yofardev AI can play a sound effect at the end of its answer (you can disable it in the settings)
- It can analyze images
- It can leave and come back of the screen
- History of chats (text version, stored locally)
- Customizable system prompt
- English and French supported
- Free and open source

## Demo Video on YouTube

[![Demo Video](https://img.youtube.com/vi/nzVYq8lGkHI/0.jpg)](https://www.youtube.com/watch?v=nzVYq8lGkHI)

## Requirements

To run the app, you can install the [apk](https://github.com/YofarDev/yofardev_ai/releases/) directly for Android, or build it yourself. To build it, you need:

- Flutter (>=3.4.3 <4.0.0)
- Android SDK (for Android builds)
- Xcode (for iOS builds)
- Google API key for Gemini 1.5-flash (you can set it up directly in app)

## Installation

1. Clone the repository:

- `git clone https://github.com/YofarDev/yofardev_ai.git`

2. Navigate to the project directory:

- `cd yofardev_ai`

3. Install dependencies:

- `flutter pub get`

4. Run the app:

- `flutter run`

## Platforms

- Android & iOS: Fully supported
- Web : it's more limited. The tts library I'm using don't let you access the bytes on web, so for the lip sync I just display random mouth states while it's talking. Also there is no image vision, no "spatialization" of voice when avatar is leaving/coming

## Known Issues

- The LLM currently tends to overuse sound effects for no reason. You can disable sound effects completely in the settings.
- Sometimes the lip-sync stop working, need to find out why.
- You can type and send another prompt while it's talking, and then you can have multiple tts playing at the same time.
- The batman costume is meh

## Future Improvements

- An interrupt button to stop the AI's response mid-sentence would be a good idea.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Tools used

- Google's Gemini 1.5-flash as backend LLM (it's actually better than I thought, and it's free)
- Text-to-speech is made localy with android's TTS engine through the flutter_tts plugin
- Stable Diffusion 1.5 for the avatar, customizations and backgrounds (AnyLora Anime Mix), with a custom LORA for the character
