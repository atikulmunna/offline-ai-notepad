# Development Setup

## Flutter Baseline

- Flutter: `3.41.5`
- Dart: `3.11.3`
- Channel: `stable`
- Local SDK path on this machine: `C:\Users\Munna\tools\flutter`

## Version Policy

Use the installed `3.41.x` stable line as the project baseline.

Do not move back to `3.40.x` unless:
- a required plugin fails on `3.41.x`,
- CI or team environments need a temporary pin,
- or we discover a regression that materially blocks delivery.

## Android Toolchain Notes

- Android SDK path: `C:\Users\Munna\AppData\Local\Android\Sdk`
- JDK path configured for Flutter: `C:\Program Files\Android\Android Studio\jbr`
- Android command-line tools were installed into `cmdline-tools\latest`

## Current Status

- Flutter is installed and working.
- Android SDK is detected by Flutter.
- The remaining Android blocker is license acceptance via `flutter doctor --android-licenses`, which appears to require an interactive terminal session on this machine.
