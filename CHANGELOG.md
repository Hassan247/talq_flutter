## 0.1.1

- Made `TalqClient` API-key-first: only `apiKey` is required for standard integration.
- Added internal default Talq endpoints, with optional overrides kept for advanced/self-host setups.
- Simplified example and docs to require only `TALQ_API_KEY`.

## 0.1.0

- Added centralized networking with Dio, including upload/download helpers and request timeouts.
- Introduced BLoC support (`TalqBloc`, events, and state) while preserving provider compatibility.
- Added `TalqSdkScope` to provide controller and optional bloc wiring for host apps.
- Hardened token/device handling and removed sensitive debug output paths.
- Refactored SDK internals to layered architecture (`workflows`, `data/repositories`, `data/sources`).
- Updated example app to use `--dart-define` for configuration instead of hardcoded credentials.
- Applied naming cleanup (`ui`, `sources`, `workflows`) and deprecated API usage fixes.
