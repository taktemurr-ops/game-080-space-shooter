# Game-080 — Release checklist

This repository contains an original playable arcade **prototype**, not a final App Store or Google Play release.

## Implemented in source
- Continuous arcade simulation with drag/buttons movement, auto-repeat press-and-hold firing
- Enemy spawning, chase-down and hostile projectiles
- Weapon cooldown, shield armor, three lives, scoring and five waves
- Pause, resume, restart, victory and defeat
- Deterministic simulation unit tests
- GitHub Actions Flutter analyze, test, Android debug APK

## Required before production completion
- Confirm passing CI, actual Android/iOS builds and real-device QA
- Fix any issues found by static analysis, widget tests or 60 FPS stress tests
- Create content/art/audio, multiple enemy classes, bosses, upgrades, accessibility and localization
- Persist high scores and settings
- Integrate real production ads with consent and policy-compliant age design
- Integrate IAP with store authorization, receipt verification, entitlement restore and refunds
- Sign Android AAB/iOS IPA with protected store credentials
- Privacy policy, disclosures, store metadata, screenshots and store reviews

No signed store artifact or successful CI run has yet been verified.
