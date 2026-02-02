import 'package:flutter/material.dart';
import 'package:livechat_sdk/livechat_sdk.dart';
import 'package:provider/provider.dart';

void main() {
  // 1. Setup the API client
  final livechatApi = LivechatClient(
    httpUrl: 'http://192.168.1.4:8081/graphql',
    wsUrl: 'ws://192.168.1.4:8081/graphql',
    apiKey: 'lc_e88ea623-c069-49d6-b13c-919f50b6de324e4b42dc',
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
        email: 'visitor_$id@payasap.com',
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
      // 3. Drop in the FAB
      floatingActionButton: const LivechatFAB(),
    );
  }
}
