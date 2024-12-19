# Yofardev AI (Flutter)

Yofardev AI is a small fun (& open source) project that brings life to a Large Language Model (LLM) through an animated avatar. Users can interact with the AI assistant through text (or dictate to text), and the app responds with generated text-to-speech and lip-synced animations.

It can now call functions (like searching on internet, getting weather, etc.).

[Free web demo (old version)](https://yofardev-ai.web.app) (not all features available because of platform limitations). You need to set either a Google Api Key, or you can set up a LLM with the OpenAI format.

Most of time, I use the Gemini 1.5-flash model, because it's free, fast and reliable. 

Also, the app is probably only working on Android (needs to test more on iOS).

<p align="center">
  <img src="screenshots/1.png" width="20%" />
  <img src="screenshots/2.png" width="20%" />
  <img src="screenshots/3.png" width="20%" />
  <img src="screenshots/4.png" width="20%" />
</p>

<p align="center">
  <img src="screenshots/5.png" width="20%" />
  <img src="screenshots/6.png" width="20%" />
  <img src="screenshots/7.png" width="20%" />
  <img src="screenshots/8.png" width="20%" />
</p>

## New Features in 2.0

- Function calling :
	* **`getCurrentWeather(location: string)`**
   	* **`getMostPopularNewsOfTheDay()`**
	* **`searchGoogle(query: string)`**
	* And more...
- You can pick a persona for your assistant (normal, coach, philosopher, conservative...)
- Not limited to only Gemini. Set your OpenAI format LLM (cloud or local)



## Features

- Native text-to-speech and lip-synced animations (customizable voices)
- The assistant can switch between multiple assets (backgrounds, costumes, etc.)
- The assistant can play sound effects
- It can analyze images
- Has some specials animations and voice effects based on its costume
- History of chats (text version, stored locally)
- English and French supported

## Demo Video on YouTube (old version)

[![Demo Video](https://img.youtube.com/vi/nzVYq8lGkHI/0.jpg)](https://www.youtube.com/watch?v=nzVYq8lGkHI)

## Requirements

To run the app, you can install the [apk](https://github.com/YofarDev/yofardev_ai/releases/) directly for Android, or build it yourself. To build it, you need:

- Flutter (>=3.4.3 <4.0.0)
- Android SDK (for Android builds)
- Api Key for a LLM service if you use a cloud service, or you can use a local one if it has the OpenAI format

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

- Android: Fully supported
- iOS: it's not far from being supported but some packages need additional steps, I may do it later
- Web : some features are missing because of platform limitations.

## Known Issues

- Internet search can fail if the website has heavy scraping protection

## Future Improvements

- An interrupt button to stop the AI's response mid-sentence would be a good idea.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Tools used

- Stable Diffusion 1.5 for the avatar, customizations and backgrounds (AnyLora Anime Mix), with a custom LORA for the character
