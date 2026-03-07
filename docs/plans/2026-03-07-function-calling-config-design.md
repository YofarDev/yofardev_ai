# Function Calling Configuration Design

**Date:** 2026-03-07
**Status:** Approved

## Overview

Move function calling API keys from `.env` file into the app's settings system with user-configurable enable/disable toggles. Functions only appear in LLM requests when properly configured and explicitly enabled.

## Motivation

- **User Control:** Allow users to configure and manage function calling API keys directly in the app
- **Better UX:** Only show functions that are actually available and enabled
- **No .env Dependency:** Remove environment file requirement for end users
- **Flexibility:** Users can disable specific functions even when keys are configured

## Architecture

### Data Model

**New fields in `SettingsState`:**
```dart
// Google Search
String? googleSearchKey;
String? googleSearchEngineId;
bool googleSearchEnabled (default: true);

// OpenWeather
String? openWeatherKey;
bool openWeatherEnabled (default: true);

// New York Times
String? newYorkTimesKey;
bool newYorkTimesEnabled (default: true);
```

### UI Structure

**New Screen:** `FunctionCallingConfigScreen`

Located at: `lib/features/settings/screens/function_calling_config_screen.dart`

**Screen Layout:**
- Title: "Function Calling Configuration"
- Three sections (one per service):
  - Service name + icon
  - API key input field(s)
  - Enable/disable toggle switch
  - Service description

**Navigation:**
- Accessible from main Settings screen
- New settings tile: "Function Calling"

### Service Layer

**Updated method signatures (method parameters approach):**

```dart
// GoogleSearchService
static Future<List<Map<String, dynamic>>> searchGoogle(
  String query,
  String apiKey,
  String engineId,
)

// WeatherService
static Future<String> getCurrentWeather(
  String location,
  String apiKey,
)

// NewsService
static Future<String> getMostPopularNewsOfTheDay(
  String apiKey,
)
```

### Function Calling Integration

**Function availability logic:**

A function is available to the LLM when ALL of the following are true:
1. API key is configured (not null, not empty)
2. Enable toggle is ON
3. Required additional fields are set (e.g., Engine ID for Google Search)

**Implementation pattern:**
```dart
// Read settings once
final state = settingsCubit.state;

// Build available functions list
final List<FunctionTool> availableFunctions = [];

// Google Search
if (state.googleSearchKey != null &&
    state.googleSearchKey!.isNotEmpty &&
    state.googleSearchEngineId != null &&
    state.googleSearchEngineId!.isNotEmpty &&
    state.googleSearchEnabled) {
  availableFunctions.add(googleSearchFunction);
}

// Similar pattern for Weather and News...
```

## Components

### 1. Settings State & Repository

**Files to modify:**
- `lib/features/settings/presentation/bloc/settings_state.dart`
- `lib/features/settings/data/repositories/settings_repository_impl.dart`
- `lib/features/settings/domain/repositories/settings_repository.dart`
- `lib/core/services/settings_local_datasource.dart`

**Changes:**
- Add 9 new fields to `SettingsState` (3 services × 3 fields each)
- Add 18 new methods to `SettingsRepository` (get/set for each field)
- Add SharedPreferences storage keys

### 2. Function Calling Config Screen

**New files:**
- `lib/features/settings/screens/function_calling_config_screen.dart`
- `lib/features/settings/widgets/function_calling_section.dart` (reusable widget)

**Features:**
- Three collapsible sections (one per service)
- API key input fields with validation
- Toggle switches for enable/disable
- Save button that persists changes to SettingsCubit
- Loading states and error handling

### 3. Service Refactoring

**Files to modify:**
- `lib/core/services/agent/google_search_service.dart`
- `lib/core/services/agent/weather_service.dart`
- `lib/core/services/agent/news_service.dart`

**Changes:**
- Remove `dotenv` imports
- Add API key parameters to method signatures
- Update error handling for missing keys

### 4. Function Calling Integration

**Files to modify:**
- Identify where function tools are assembled for LLM calls (likely in agent or chat services)

**Changes:**
- Read from SettingsCubit instead of checking env variables
- Implement conditional function inclusion logic
- Pass keys to service methods when calling functions

### 5. Remove .env Dependency

**Files to modify:**
- `pubspec.yaml` - remove `flutter_dotenv` dependency
- `lib/main.dart` - remove `dotenv.load()` call
- `.gitignore` - can relax .env restrictions (but keep for safety)

**Cleanup:**
- Delete `.env` file
- Remove dotenv imports from all files

### 6. Localization

**New keys to add:**
```yaml
settings.functionCalling: "Function Calling"
settings.functionCalling.description: "Configure API keys for function calling features"

settings.googleSearch: "Google Search"
settings.googleSearch.description: "Search the web for current information"
settings.apiKey: "API Key"
settings.engineId: "Search Engine ID"

settings.weather: "Weather"
settings.weather.description: "Get current weather for any location"

settings.news: "News"
settings.news.description: "Get today's most popular news"

settings.enable: "Enable"
settings.save: "Save"
settings.saved: "Configuration saved"
```

## Data Flow

```
User Input (FunctionCallingConfigScreen)
    ↓
SettingsCubit (update state)
    ↓
SettingsRepository (persist to SharedPreferences)
    ↓
Service Methods (receive keys as parameters)
    ↓
Function Calling Logic (check enabled state + key presence)
    ↓
LLM Request (only include enabled functions)
```

## Testing Strategy

### Unit Tests
- Test SettingsRepository methods for new fields
- Test SettingsCubit state updates
- Test service methods with mock keys
- Test function availability logic

### Widget Tests
- Test FunctionCallingConfigScreen UI
- Test toggle switch behavior
- Test API key input validation
- Test save functionality

### Integration Tests
- Test end-to-end: configure key → enable → function appears in LLM request
- Test disable → function removed from LLM request
- Test missing key → function not available

## Migration Path

1. Add new settings fields (default to current .env values for development)
2. Create FunctionCallingConfigScreen
3. Update service method signatures
4. Update function calling integration logic
5. Remove .env dependency
6. Add localization strings
7. Test thoroughly

## Success Criteria

- ✅ No `.env` file required for app to run
- ✅ All function calling keys configurable in UI
- ✅ Functions only appear when configured AND enabled
- ✅ Users can toggle functions on/off
- ✅ Clean error handling for missing keys
- ✅ All tests pass
