import 'package:flutter/material.dart';
import 'package:livechat_sdk/livechat_sdk.dart';
import 'package:provider/provider.dart';

void main() {
  // 1. Setup the API client
  // use 127.0.0.1 for simulator, or your Mac's IP (e.g., 192.168.1.5) for physical device
  final livechatApi = LivechatClient(
    httpUrl: 'http://127.0.0.1:8082/graphql',
    wsUrl: 'ws://127.0.0.1:8082/graphql',
    apiKey: 'lc_8b39111a-f6cd-4c14-8ae1-2c86012baf8594bd32e2',
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'packages/livechat_sdk/BricolageGrotesque',
      ),
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
  String _generateUniqueId() =>
      DateTime.now().millisecondsSinceEpoch.toString().substring(7);

  @override
  void initState() {
    super.initState();
    // 2. Initialize the chat session AFTER the first frame to avoid "setState during build"
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = context.read<LivechatController>();
      final id = _generateUniqueId();
      await controller.initialize(
        firstName: 'Visitor',
        lastName: id,
        email: 'visitor_$id@example.com',
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
                final id = _generateUniqueId();
                await controller.initialize(
                  firstName: 'Visitor',
                  lastName: id,
                  email: 'visitor_$id@payasap.com',
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
      // 3. Drop in the FAB with a custom theme
      floatingActionButton: const LivechatFAB(
        theme: LivechatTheme(
          primaryColor: Colors.deepPurple,
          darkHeaderColor: Color(0xFF311B92),
        ),
      ),
    );
  }
}
