# Talq Flutter SDK

The official Flutter SDK for [Talq](https://usetalq.app) — add live chat to your Flutter app in minutes.

## Features

- **Drop-in live chat** — Ready-made UI with conversation list, chat view, and floating action button
- **Real-time messaging** — Instant updates via GraphQL subscriptions
- **Visitor identification** — Auto-identifies users by device; optionally attach email and name
- **In-app notifications** — Built-in notification banners for new messages
- **Push notifications** — Firebase Cloud Messaging support out of the box
- **Fully themeable** — Customize colors, text styles, bubble colors, and border radius
- **Light & dark mode** — Preset themes with full `copyWith` support
- **File attachments** — Send and receive images and files
- **State management** — Works with Provider and BLoC

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  talq_flutter:
    git:
      url: https://github.com/Hassan247/talq_flutter.git
      ref: main
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Initialize the SDK

Wrap your app with `TalqSdkScope` and provide your API key (found in your [Talq dashboard](https://usetalq.app) under Settings > Installation):

```dart
import 'package:talq_flutter/talq_flutter.dart';

void main() {
  final client = TalqClient(apiKey: 'YOUR_API_KEY');

  runApp(
    TalqSdkScope(
      client: client,
      child: const MyApp(),
    ),
  );
}
```

### 2. Add the chat button

Drop `TalqFAB` into any Scaffold:

```dart
Scaffold(
  floatingActionButton: const TalqFAB(),
  body: ...,
)
```

That's it. Your users can now start conversations and your team can respond from the [Talq dashboard](https://usetalq.app).

### 3. Open chat programmatically

Navigate directly to the conversation list:

```dart
Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute(builder: (_) => const RoomsListView()),
);
```

### 4. Identify visitors (optional)

Attach user info so agents can see who they're talking to:

```dart
context.read<TalqController>().initialize(
  email: 'user@example.com',
  firstName: 'hassan',
  lastName: 'gani',
);
```

If you provide an email without a name, the name is derived automatically.

## Customization

### Theme

Pass a `TalqTheme` to customize the look:

```dart
TalqFAB(
  theme: TalqTheme(
    primaryColor: Color(0xFF6200EE),
    userBubbleColor: Color(0xFF6200EE),
    borderRadius: 16,
  ),
)
```

Or use the built-in dark theme:

```dart
TalqFAB(theme: TalqTheme.dark())
```

### Available theme properties

| Property           | Default   | Description                          |
| ------------------ | --------- | ------------------------------------ |
| `primaryColor`     | `#0057FF` | Accent color for buttons, FAB, links |
| `backgroundColor`  | `#F5F7FA` | Chat screen background               |
| `surfaceColor`     | `#FFFFFF` | Cards and input background           |
| `userBubbleColor`  | `#151515` | Sent message bubble                  |
| `agentBubbleColor` | `#FFFFFF` | Received message bubble              |
| `userTextColor`    | White     | Text in sent messages                |
| `agentTextColor`   | Black87   | Text in received messages            |
| `borderRadius`     | `20.0`    | Corner radius for message bubbles    |
| `unreadBadgeColor` | Red       | Unread count badge on FAB            |

### Custom FAB icon

```dart
TalqFAB(
  icon: Icon(Icons.chat, color: Colors.white),
  size: 56,
)
```

### In-app notifications

Enabled by default. Disable them:

```dart
TalqSdkScope(
  client: client,
  showInAppNotifications: false,
  child: const MyApp(),
)
```

## Widgets

| Widget                  | Description                                                          |
| ----------------------- | -------------------------------------------------------------------- |
| `TalqSdkScope`          | Required root wrapper. Provides client and state to the widget tree. |
| `TalqFAB`               | Floating action button with unread message badge.                    |
| `RoomsListView`         | Full-screen conversation list.                                       |
| `ChatView`              | Single conversation chat screen.                                     |
| `TalqInAppNotification` | Notification banner for incoming messages.                           |

## Platform Setup

**Android** — No additional setup required. Internet permission is included by default.

**iOS** — Add camera and photo library permissions to `Info.plist` if you want file attachments:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to take photos for chat</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to share photos in chat</string>
```

## Support

- Website: [usetalq.app](https://usetalq.app)
- Email: [support@usetalq.app](mailto:support@usetalq.app)
