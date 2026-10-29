# Speech fixtures

Real TTS audio for the text-aligned speech analyzer tests
(`test/core/services/audio/speech_analyzer_test.dart`) and the tuning of
`SpeechAnalyzer.maxAlignCost`. 16 kHz, mono, 16-bit PCM WAV, each under
120 KB. Generated with the macOS built-in `say` (macOS 27.2; voices
Samantha, en_US, and Thomas, fr_FR):

```bash
say -v Samantha -o test/fixtures/speech/blue_sky.wav  --data-format=LEI16@16000 "The sky is blue."
say -v Samantha -o test/fixtures/speech/so_true.wav   --data-format=LEI16@16000 "So true, you know."
say -v Samantha -o test/fixtures/speech/fine_view.wav --data-format=LEI16@16000 "A fine view of five vines."
say -v Thomas   -o test/fixtures/speech/bonjour.wav   --data-format=LEI16@16000 "Bonjour, comment allez-vous ?"
```

A different macOS version may ship different voice builds: if the tests drift
after regenerating, re-check the costs the `maxAlignCost` comment quotes.
