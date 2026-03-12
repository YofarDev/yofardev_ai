# Documentation Index

**Start here** → Choose based on your task

| Document | When to Read |
|----------|--------------|
| **00_ARCHITECTURE.md** | First time exploring, big picture |
| **01_FEATURES.md** | Working on specific features |
| **02_SERVICES.md** | Understanding service interactions |
| **03_DATA_FLOW.md** | Debugging workflows |
| **04_CONVENTIONS.md** | Writing code |

## Architecture Summary

```
Presentation → Domain → Data → Core Services
```

**Dependencies flow inward only.**

## 3 Critical Rules

1. All DI in `service_locator.dart`
2. No cubit-to-cubit dependencies
3. No cross-feature imports

## Quick Reference

| Task | Entry Point |
|------|-------------|
| Send message | `ChatCubit.sendMessage()` |
| TTS playback | `ChatTtsCubit.enqueueTts()` |
| Avatar anim | `AvatarAnimationService.playNewChatSequence()` |
| Interrupt | `InterruptionService.interrupt()` |

## Tech Stack

Flutter 3.8+, flutter_bloc 9.1.1, freezed 3.2.5, fpdart 1.2.0, get_it 9.2.1

---

**v3.0.0+6** | 2026-03-12
