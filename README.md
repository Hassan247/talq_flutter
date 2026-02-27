# Livechat Flutter SDK

A standard, easy-to-use Flutter SDK for integrating premium livechat into any mobile application.

## Features

- **Zero-Config Auth**: Automatically identifies visitors via Device ID.
- **Smart Identity Defaults**: If first/last name are omitted, backend derives them from email.
- **Real-time Messaging**: Powered by GraphQL Subscriptions for instant updates.
- **Hardened Networking**: Centralized Dio client with auth/header interceptors and safe timeouts.
- **Push Notification Ready**: Built-in support for Firebase Cloud Messaging tokens.
- **Premium UI**: Ready-made, customizable widgets like `LivechatView` and `LivechatFAB`.
- **State Management**: Provider-compatible controller plus first-class BLoC support.
- **Layered Internals**: `usecases -> repository -> remote datasource` for safer extension and maintenance.

## Getting Started

1. Add the dependency to your `pubspec.yaml`:

   ```yaml
   dependencies:
     livechat_sdk:
       path: ./path/to/livechat_sdk
   ```

2. Initialize the SDK scope in your app root:

   ```dart
   final livechatApi = LivechatClient(
     httpUrl: 'https://api.yourdomain.com/graphql',
     wsUrl: 'wss://api.yourdomain.com/graphql',
     apiKey: 'YOUR_API_KEY', // Found in your workspace settings
   );

   runApp(
     LivechatSdkScope(
       client: livechatApi,
       child: const MyApp(),
     ),
   );
   ```

3. Call `initialize()` through either BLoC events or the controller:

   ```dart
   context.read<LivechatController>().initialize(
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

## Internal Architecture

- `LivechatController` handles UI-facing state transitions only.
- `LivechatUseCases` defines application actions and orchestration points.
- `LivechatRepository` centralizes request shaping and GraphQL variable mapping.
- `LivechatRemoteDataSource` is the only layer talking to `LivechatClient`.
