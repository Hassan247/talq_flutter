# Talq Flutter SDK

A standard, easy-to-use Flutter SDK for integrating premium talq into any mobile application.

## Features

- **Zero-Config Auth**: Automatically identifies visitors via Device ID.
- **Smart Identity Defaults**: If first/last name are omitted, backend derives them from email.
- **Real-time Messaging**: Powered by GraphQL Subscriptions for instant updates.
- **Hardened Networking**: Centralized Dio client with auth/header interceptors and safe timeouts.
- **Push Notification Ready**: Built-in support for Firebase Cloud Messaging tokens.
- **Premium UI**: Ready-made, customizable widgets like `TalqView` and `TalqFAB`.
- **State Management**: Provider-compatible controller plus first-class BLoC support.
- **Layered Internals**: `usecases -> repository -> remote datasource` for safer extension and maintenance.

## Getting Started

1. Add the dependency to your `pubspec.yaml`:

   ```yaml
   dependencies:
     talq_sdk:
       path: ./path/to/talq_sdk
   ```

2. Initialize the SDK scope in your app root:

   ```dart
   final talqApi = TalqClient(
     apiKey: 'YOUR_API_KEY', // Found in your workspace settings
   );

   runApp(
     TalqSdkScope(
       client: talqApi,
       child: const MyApp(),
     ),
   );
   ```

   `TalqClient` uses Talq-managed default endpoints internally. Integrators only need an API key.

3. Call `initialize()` through either BLoC events or the controller:

   ```dart
   context.read<TalqController>().initialize(
     email: 'visitor@example.com',
   );
   ```

4. Drop the `TalqFAB` onto any scaffold:
   ```dart
   floatingActionButton: const TalqFAB(),
   ```

## Native Setup

- **Android**: Ensure you have Internet permissions in `AndroidManifest.xml`.
- **iOS**: Ensure you have `NSAppTransportSecurity` configured for your API domain.

## Internal Architecture

- `TalqController` handles UI-facing state transitions only.
- `TalqUseCases` defines application actions and orchestration points.
- `TalqRepository` centralizes request shaping and GraphQL variable mapping.
- `TalqRemoteDataSource` is the only layer talking to `TalqClient`.
