# Livechat Flutter SDK

A standard, easy-to-use Flutter SDK for integrating premium livechat into any mobile application.

## Features

- **Zero-Config Auth**: Automatically identifies visitors via Device ID.
- **Real-time Messaging**: Powered by GraphQL Subscriptions for instant updates.
- **Push Notification Ready**: Built-in support for Firebase Cloud Messaging tokens.
- **Premium UI**: Ready-made, customizable widgets like `LivechatView` and `LivechatFAB`.
- **State Management**: Uses the Provider pattern for reactive UI updates.

## Getting Started

1. Add the dependency to your `pubspec.yaml`:

   ```yaml
   dependencies:
     livechat_sdk:
       path: ./path/to/livechat_sdk
   ```

2. Initialize the `LivechatController` in your app root:

   ```dart
   final livechatApi = LivechatClient(
     httpUrl: 'https://api.yourdomain.com/graphql',
     wsUrl: 'wss://api.yourdomain.com/graphql',
     apiKey: 'YOUR_API_KEY', // Found in your workspace settings
   );

   runApp(
     MultiProvider(
       providers: [
         ChangeNotifierProvider(
           create: (_) => LivechatController(livechatApi),
         ),
       ],
       child: MyApp(),
     ),
   );
   ```

3. Call `initialize()` on app startup or when identifying a user:

   ```dart
   context.read<LivechatController>().initialize(
     name: 'Visitor Name',
     email: 'visitor@example.com',
   );
   ```

4. Drop the `LivechatFAB` onto any scaffold:
   ```dart
   floatingActionButton: const LivechatFAB(),
   ```

## Native Setup

- **Android**: Ensure you have Internet permissions in `AndroidManifest.xml`.
- **iOS**: Ensure you have `NSAppTransportSecurity` configured for your API domain.
