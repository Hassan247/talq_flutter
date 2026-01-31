import 'package:flutter/material.dart';
import 'package:livechat_sdk/livechat_sdk.dart';
import 'package:provider/provider.dart';

void main() {
  // 1. Setup the API client
  final livechatApi = LivechatClient(
    httpUrl: 'http://localhost:8081/graphql',
    wsUrl: 'ws://localhost:8081/graphql',
    apiKey: 'lc_0a034c8d-3047-4b99-9184-1cd57e6ef0ed75fd1f88',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LivechatController(livechatApi)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Livechat SDK Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    // 2. Initialize the chat session AFTER the first frame to avoid "setState during build"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LivechatController>().initialize(
        name: 'John Doe',
        email: 'john@example.com',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Click the chat button below to start talking!'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final controller = context.read<LivechatController>();
                await controller.resetSession();
                // Re-initialize to register as a new user
                await controller.initialize(
                  name:
                      'New User ${DateTime.now().millisecondsSinceEpoch % 1000}',
                  email:
                      'user${DateTime.now().millisecondsSinceEpoch % 1000}@example.com',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Session Reset! New identity created.'),
                    ),
                  );
                }
              },
              child: const Text('Reset Session'),
            ),
          ],
        ),
      ),
      // 3. Drop in the FAB
      floatingActionButton: const LivechatFAB(),
    );
  }
}
