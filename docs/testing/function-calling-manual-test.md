# Function Calling Configuration - Manual Testing Checklist

## Overview
This document provides a step-by-step manual testing guide for the Function Calling Configuration feature. Use this checklist to verify that the feature works correctly end-to-end.

**Test Date**: ___________
**Tester**: ___________
**App Version**: ___________
**Device**: ___________

---

## Test Prerequisites

- [ ] Flutter development environment is set up
- [ ] App can be built and run (`flutter run`)
- [ ] No `.env` file exists in the project root (feature should work without it)
- [ ] Valid Google Search API key (optional, for testing Google Search function)
- [ ] Valid Google Custom Search Engine ID (optional, for testing Google Search function)

---

## Test Cases

### 1. Launch App - Verify No .env Dependency

**Objective**: Ensure the app starts successfully without requiring a `.env` file.

**Steps**:
1. Ensure no `.env` file exists in the project root
2. Run the app: `flutter run`
3. Observe the app launch

**Expected Result**:
- App launches successfully
- No crashes or errors related to missing `.env` file
- Home screen appears normally

**Actual Result**: ___________________________

**Status**: ✅ Pass / ❌ Fail

**Notes**:
_______________________________________________________________
_______________________________________________________________

---

### 2. Navigate to Settings

**Objective**: Verify the Settings screen is accessible and contains the Function Calling option.

**Steps**:
1. From the home screen, locate the Settings entry point
2. Tap on Settings
3. Observe the Settings screen

**Expected Result**:
- Settings screen opens successfully
- "Function Calling" option is visible in the list
- Option is clearly labeled and easy to identify

**Actual Result**: ___________________________

**Status**: ✅ Pass / ❌ Fail

**Notes**:
_______________________________________________________________
_______________________________________________________________

---

### 3. Open Function Calling Configuration Screen

**Objective**: Verify the Function Calling Configuration screen displays all three sections correctly.

**Steps**:
1. From Settings screen, tap on "Function Calling"
2. Observe the Function Calling Configuration screen

**Expected Result**:
- Screen opens successfully
- Three configuration sections are visible:
  - **Google Search** - with API Key and Engine ID fields
  - **Weather** - with enable/disable toggle
  - **News** - with enable/disable toggle
- All UI elements are properly aligned and readable

**Actual Result**: ___________________________

**Status**: ✅ Pass / ❌ Fail

**Notes**:
_______________________________________________________________
_______________________________________________________________

---

### 4. Enter Google Search Credentials

**Objective**: Verify Google Search API key and Engine ID can be entered and saved.

**Steps**:
1. In the Google Search section, locate the "API Key" text field
2. Enter a valid Google Search API key
3. Locate the "Search Engine ID" text field
4. Enter a valid Google Custom Search Engine ID
5. Tap back or navigate away to trigger save

**Expected Result**:
- Text fields accept input without issues
- Input is visible and editable
- Credentials are saved to secure storage
- No errors or warnings appear
- Values persist when returning to the screen

**Actual Result**: ___________________________

**Status**: ✅ Pass / ❌ Fail

**Notes**:
_______________________________________________________________
_______________________________________________________________

---

### 5. Toggle Function Switches

**Objective**: Verify that function enable/disable toggles work correctly.

**Steps**:
1. Locate the Weather toggle
2. Toggle Weather OFF
3. Toggle Weather ON
4. Locate the News toggle
5. Toggle News OFF
6. Toggle News ON
7. Navigate away from the screen
8. Return to Function Calling Configuration screen

**Expected Result**:
- Toggles respond to user interaction
- Visual feedback is clear (ON/OFF state is visible)
- Toggle state persists after navigating away and returning
- No lag or delay in toggle response

**Actual Result**: ___________________________

**Status**: ✅ Pass / ❌ Fail

**Notes**:
_______________________________________________________________
_______________________________________________________________

---

### 6. Start a Chat with All Functions Enabled

**Objective**: Verify that enabled functions are included in the LLM request.

**Prerequisites**:
- Weather function should be ON
- News function should be ON
- Google Search credentials should be entered (if testing Google Search)

**Steps**:
1. Navigate to the chat screen
2. Start a new conversation
3. Send a message: "What's the weather in Paris?"
4. Observe the LLM response

**Expected Result**:
- Chat screen opens successfully
- Message is sent without errors
- LLM receives function calling tools in the request
- If Weather function is enabled, LLM should attempt to call it
- No errors related to function calling appear

**Actual Result**: ___________________________

**Status**: ✅ Pass / ❌ Fail

**Notes**:
_______________________________________________________________
_______________________________________________________________

---

### 7. Test Google Search Function

**Objective**: Verify the Google Search function works correctly when enabled.

**Prerequisites**:
- Valid Google Search API key and Engine ID entered
- Weather function can be OFF to isolate testing

**Steps**:
1. Ensure Google Search credentials are entered
2. In the chat, send: "Search for the latest Flutter 3.0 features"
3. Observe the function call and response
4. Verify search results are displayed

**Expected Result**:
- LLM calls the Google Search function
- Function executes with the provided API key and Engine ID
- Search results are returned to the LLM
- LLM provides a coherent response based on search results
- No authentication errors appear

**Actual Result**: ___________________________

**Status**: ✅ Pass / ❌ Fail / ⏭️ Skipped (no credentials)

**Notes**:
_______________________________________________________________
_______________________________________________________________

---

### 8. Test Weather Function

**Objective**: Verify the Weather function works correctly when enabled.

**Prerequisites**:
- Weather function toggle is ON
- Other functions can be disabled to isolate testing

**Steps**:
1. Ensure Weather toggle is ON
2. In the chat, send: "What's the weather in Tokyo?"
3. Observe the function call and response
4. Try a different city: "How's the weather in New York?"

**Expected Result**:
- LLM calls the Weather function
- Function executes with the provided location
- Weather data is returned to the LLM
- LLM provides a coherent weather report
- No errors appear in the function call

**Actual Result**: ___________________________

**Status**: ✅ Pass / ❌ Fail

**Notes**:
_______________________________________________________________
_______________________________________________________________

---

### 9. Test News Function

**Objective**: Verify the News function works correctly when enabled.

**Prerequisites**:
- News function toggle is ON
- Other functions can be disabled to isolate testing

**Steps**:
1. Ensure News toggle is ON
2. In the chat, send: "What are the latest tech news?"
3. Observe the function call and response
4. Try a different query: "Show me sports news"

**Expected Result**:
- LLM calls the News function
- Function executes with the provided query
- News articles are returned to the LLM
- LLM provides a coherent summary of news
- No errors appear in the function call

**Actual Result**: ___________________________

**Status**: ✅ Pass / ❌ Fail

**Notes**:
_______________________________________________________________
_______________________________________________________________

---

### 10. Disable a Function and Verify

**Objective**: Verify that disabled functions are not included in LLM requests.

**Steps**:
1. Go to Function Calling Configuration screen
2. Toggle Weather OFF
3. Go back to chat
4. Send: "What's the weather in London?"
5. Observe the LLM response

**Expected Result**:
- Weather function is NOT called
- LLM responds without attempting to use the Weather function
- LLM may explain it cannot access weather data
- No function call is made

**Actual Result**: ___________________________

**Status**: ✅ Pass / ❌ Fail

**Notes**:
_______________________________________________________________
_______________________________________________________________

---

### 11. Restart App and Verify Settings Persist

**Objective**: Ensure that all settings are correctly saved and persist across app restarts.

**Steps**:
1. Configure the following:
   - Enter Google Search API key: "test-key-123"
   - Enter Engine ID: "test-engine-456"
   - Toggle Weather: ON
   - Toggle News: OFF
2. Completely close the app (kill the process)
3. Relaunch the app
4. Navigate to Settings → Function Calling
5. Verify all settings are preserved

**Expected Result**:
- App restarts successfully
- Google Search API key shows "test-key-123"
- Engine ID shows "test-engine-456"
- Weather toggle is ON
- News toggle is OFF
- No settings were lost or reset

**Actual Result**: ___________________________

**Status**: ✅ Pass / ❌ Fail

**Notes**:
_______________________________________________________________
_______________________________________________________________

---

### 12. Test All Functions Disabled

**Objective**: Verify behavior when all functions are disabled.

**Steps**:
1. Go to Function Calling Configuration screen
2. Toggle Weather OFF
3. Toggle News OFF
4. (Optional) Clear Google Search credentials
5. Go to chat
6. Send: "Search for something and tell me the weather"

**Expected Result**:
- No functions are called
- LLM responds without any function calls
- LLM explains it cannot perform these actions
- No crashes or errors occur

**Actual Result**: ___________________________

**Status**: ✅ Pass / ❌ Fail

**Notes**:
_______________________________________________________________
_______________________________________________________________

---

### 13. Test Invalid Google Search Credentials

**Objective**: Verify error handling when invalid Google Search credentials are used.

**Steps**:
1. Go to Function Calling Configuration screen
2. Enter invalid API key: "invalid-key"
3. Enter invalid Engine ID: "invalid-engine"
4. Go to chat
5. Send: "Search for something"

**Expected Result**:
- App does not crash
- LLM attempts to call Google Search function
- Function returns an error (invalid credentials)
- LLM handles the error gracefully
- User receives a clear error message
- App remains stable

**Actual Result**: ___________________________

**Status**: ✅ Pass / ❌ Fail

**Notes**:
_______________________________________________________________
_______________________________________________________________

---

### 14. Test UI Localization (if applicable)

**Objective**: Verify that the Function Calling Configuration UI supports multiple languages.

**Steps**:
1. Change device language to French (if supported)
2. Navigate to Settings → Function Calling
3. Verify all labels are translated
4. Change device language to English
5. Verify all labels are in English

**Expected Result**:
- All UI strings are correctly translated
- No missing translations (no raw keys visible)
- Layout remains intact in all languages
- No text overflow or truncation issues

**Actual Result**: ___________________________

**Status**: ✅ Pass / ❌ Fail / ⏭️ Skipped (single language)

**Notes**:
_______________________________________________________________
_______________________________________________________________

---

## Summary

**Total Tests**: 14
**Passed**: _______
**Failed**: _______
**Skipped**: _______

**Overall Status**: ✅ All Passed / ⚠️ Some Failed / ❌ Critical Failures

---

## Critical Issues Found

List any critical bugs or issues that prevent the feature from working:

1. _______________________________________________________________
2. _______________________________________________________________
3. _______________________________________________________________

---

## Non-Critical Issues Found

List any minor bugs or improvements:

1. _______________________________________________________________
2. _______________________________________________________________
3. _______________________________________________________________

---

## Test Environment Details

**Flutter Version**: ___________________________
**Dart Version**: ___________________________
**Device/Emulator**: ___________________________
**OS Version**: ___________________________
**App Build**: Debug / Release

---

## Additional Notes

Any additional observations, suggestions, or comments:

_______________________________________________________________
_______________________________________________________________
_______________________________________________________________
_______________________________________________________________

---

## Tester Sign-off

**Tester Name**: ___________________________
**Test Completion Date**: ___________________________
**Sign-off**: ✅ Approved for Release / ⚠️ Approved with Minor Issues / ❌ Needs Retesting
