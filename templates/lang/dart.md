### Dart
- `dart format` and `dart analyze` clean against the project's `analysis_options.yaml`.
- `final` by default, `const` wherever possible; sound null safety with no `!` unless proven.
- Flutter: small widgets, no logic in `build`, state via the project's chosen solution.
- Tests: `dart test` / `flutter test`; widget tests for UI, unit tests for logic.
