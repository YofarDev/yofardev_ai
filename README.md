# Yofardev AI (Flutter)

Yofardev AI is a small fun (& open source) project that brings life to a Large Language Model (LLM) through an animated avatar. Users can interact with the AI assistant through text (or dictate to text), and the app responds with generated text-to-speech and lip-synced animations.

It can now call functions (like searching on internet, getting weather, etc.).

[Free web demo](https://yofardev-ai.web.app) (not all features available because of platform limitations). You need to set either a Google Api Key, or you can set up a LLM with the OpenAI format. Some functions calling won't work on this version.

Most of time, I use the Gemini flash model (1.5 or 2.0), because it's free, fast and reliable. 

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

## New features in v2.0

- Function calling (work in progress, not always perfect) :
	* **`getCurrentWeather(location: string)`**
  * **`getMostPopularNewsOfTheDay()`**
	* **`searchGoogle(query: string)`**
	* And more...
	 <p>
<img src="screenshots/9.png" width="20%" /></p>
- You can pick a persona for your assistant (normal, coach, philosopher, conservative...)
- Not limited to only Gemini. Set your OpenAI format LLM (cloud or local)
- It doesn't send a sound effect every message anymore!!


## Features

- Native text-to-speech and lip-synced animations (customizable voices)
- The assistant can switch between multiple assets (backgrounds, costumes, etc.)
- The assistant can play sound effects
- It can analyze images
- Has some specials animations and voice effects based on its costume
- History of chats (text version, stored locally)
- English and French supported

## Demo Video on YouTube

[![Demo Video](https://img.youtube.com/vi/UXpE2vQsJhY/0.jpg)](https://www.youtube.com/watch?v=UXpE2vQsJhY)

## Requirements

To run the app, you can install the [apk](https://github.com/YofarDev/yofardev_ai/releases/) directly for Android, or build it yourself (I didn't provide any api keys, so most of function calling won't work). To build it, you need:

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

4. Configure function calling services (optional):

   The app supports function calling capabilities such as weather information, news retrieval, and web search. To enable these features:

   - Open the app and navigate to **Settings**
   - Tap on **Function Calling Configuration**
   - For each service you want to use:
     * Enter your API key
     * Enable the service toggle
   - Configured and enabled services will be available during conversations

   Supported services:
   - **OpenWeather**: For weather information (get API key at https://openweathermap.org/api)
   - **New York Times**: For news retrieval (get API key at https://developer.nytimes.com/)
   - **Google Search**: For web search (get API key and Engine ID at https://developers.google.com/custom-search/v1/overview)

5. Run the app:

- `flutter run`

## Platforms

- Android & iOS: Fully supported
- Web : some features are missing because of platform limitations.

## Known Issues

- Function calling like internet search are not always reliable.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Tools used

- For LLM integration I use my own package : [llm\_api_picker](https://github.com/YofarDev/llm_api_picker/)
- Stable Diffusion 1.5 for the avatar, customizations and backgrounds (AnyLora Anime Mix), with a custom LORA for the character
