# Streaming LLM + TTS Testing Checklist

## Functional Tests

- [ ] Streaming response appears incrementally in UI
- [ ] Sentences are extracted correctly from JSON responses
- [ ] TTS audio plays as sentences complete
- [ ] Queue processes sentences in order
- [ ] High priority items jump the queue
- [ ] Pause/stop functionality works
- [ ] Error handling shows appropriate messages

## Edge Cases

- [ ] Empty response handling
- [ ] Malformed JSON handling
- [ ] Network interruption during stream
- [ ] Very long responses (100+ sentences)
- [ ] Rapid message sending (multiple concurrent streams)

## Performance

- [ ] First sentence TTS plays within 2 seconds of user send
- [ ] UI updates smoothly without lag
- [ ] Memory usage stays reasonable during long streams
- [ ] Queue doesn't block UI thread

## UI/UX

- [ ] Streaming indicator visible during generation
- [ ] Audio playback coordinates with text display
- [ ] No audio gaps between sentences
- [ ] User can interrupt/stop mid-stream