## 1.2.2

- Show an "edited" marker on messages the agent has rewritten.

## 1.2.1

- Quoted-message panel restyled to match the dashboard (inset accent bar, reply glyph, "You" for your own quoted message).

## 1.2.0

- Fix messages from one conversation appearing inside another (thread and cache
  were keyed on the wrong room).
- Deleted messages keep their deleted state after a refetch; hollow bubble, no tail.
- Long-press menu matches the agent app: blurred thread, reaction bar, Reply / Copy text.
- Reactions render below the bubble as pills with the reactor's avatar; one
  reaction per person.
- Keyboard opens on every swipe-to-quote; system notices can't be quoted.
- Greeting stays visible above the keyboard on a new chat.
- Talq logo in the "Powered by" attribution.
- Conversation list no longer spins forever at the end.

## 1.1.0

- Fixed visitors losing their chat history on a new device or app version: the
  user's email never reached the backend after the first run, so each install
  stayed pinned to its own device id and the backend's merge-by-email never ran.
- Fixed conversations sometimes opening empty until you backed out and reopened.
- The closed / rating banner now appears immediately on open instead of after a
  network round-trip.
- Added swipe-right-to-reply: the bubble tracks your finger with a reply glyph
  and haptic, and the quote bar is now a flush strip that focuses the keyboard.
  Quoting is disabled once a conversation is closed.
- Added message reactions: long-press an agent message for quick emojis plus a
  full picker. Visitors can only react to agent messages.
- Redesigned deleted messages as a hollow outlined bubble.
- The rated / closed banner now follows the workspace brand colour instead of a
  fixed green, and chat bubbles use a flatter, less shadowed style.
- The welcome greeting stays visible when the keyboard is open.
- Added a "Powered by Talq" line to the chat home screen.

## 0.1.1

- Made `TalqClient` API-key-first: only `apiKey` is required for standard integration.
- Added internal default Talq endpoints managed inside the SDK.
- Simplified example and docs to require only `TALQ_API_KEY`.

## 0.1.0

- Added centralized networking with Dio, including upload/download helpers and request timeouts.
- Introduced BLoC support (`TalqBloc`, events, and state) while preserving provider compatibility.
- Added `TalqSdkScope` to provide controller and optional bloc wiring for host apps.
- Hardened token/device handling and removed sensitive debug output paths.
- Refactored SDK internals to layered architecture (`workflows`, `data/repositories`, `data/sources`).
- Updated example app to use `--dart-define` for configuration instead of hardcoded credentials.
- Applied naming cleanup (`ui`, `sources`, `workflows`) and deprecated API usage fixes.
