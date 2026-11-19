# Space Shooter — Game 080

Original mobile arcade space shooter, implemented with Flutter CustomPainter and a pure Dart simulation engine.

## Features in source
- Responsive 2D arcade arena, ship steering by drag or buttons
- Tap/hold-fire controls, laser projectiles and firing cooldown
- Procedural enemies, incoming shots, armor and three lives
- Five score-based waves, pause/resume, win/lose, replay and scoreboard
- Nine deterministic rules-engine tests
- CI workflow for Flutter analysis, unit tests and Android debug APK artifact

## Run locally
```bash
flutter create --platforms=android,ios .
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

## Status
**Prototype code committed, not store-ready.** CI pass, signed builds, real-device tests, production ads/IAP, richer content and store submission have not been verified. See `docs/RELEASE_CHECKLIST.md`.
