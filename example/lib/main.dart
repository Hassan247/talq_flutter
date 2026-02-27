import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livechat_sdk/livechat_sdk.dart';

const _httpUrl = String.fromEnvironment('LIVECHAT_HTTP_URL');
const _wsUrl = String.fromEnvironment('LIVECHAT_WS_URL');
const _apiKey = String.fromEnvironment('LIVECHAT_API_KEY');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LivechatExampleApp());
}

class LivechatExampleApp extends StatelessWidget {
  const LivechatExampleApp({super.key});

  bool get _isConfigured =>
      _httpUrl.isNotEmpty && _wsUrl.isNotEmpty && _apiKey.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_isConfigured) {
      return const MaterialApp(home: _ConfigurationErrorScreen());
    }

    final client = LivechatClient(
      httpUrl: _httpUrl,
      wsUrl: _wsUrl,
      apiKey: _apiKey,
    );

    return LivechatSdkScope(
      client: client,
      child: MaterialApp(
        title: 'Livechat SDK Example',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          fontFamily: 'packages/livechat_sdk/BricolageGrotesque',
        ),
        home: const MyHomePage(),
      ),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeVisitor();
    });
  }

  void _initializeVisitor() {
    final id = _generateUniqueId();
    context.read<LivechatBloc>().add(
      LivechatInitializeRequested(email: 'visitor_$id@example.com'),
    );
  }

  Future<void> _resetSession() async {
    final bloc = context.read<LivechatBloc>();
    bloc.add(const LivechatResetSessionRequested());
    final id = _generateUniqueId();
    bloc.add(LivechatInitializeRequested(email: 'visitor_$id@example.com'));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LivechatBloc, LivechatState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.errorMessage == null || state.errorMessage!.isEmpty) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      },
      builder: (context, state) {
        final isBusy = state.status == LivechatStatus.loading;

        return Scaffold(
          appBar: AppBar(title: const Text('My App')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Click the chat button below to start talking!'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isBusy ? null : _resetSession,
                  child: Text(isBusy ? 'Please wait...' : 'Reset Session'),
                ),
              ],
            ),
          ),
          floatingActionButton: const LivechatFAB(
            theme: LivechatTheme(
              primaryColor: Colors.deepPurple,
              darkHeaderColor: Color(0xFF311B92),
            ),
          ),
        );
      },
    );
  }
}

class _ConfigurationErrorScreen extends StatelessWidget {
  const _ConfigurationErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Livechat SDK Example')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Missing required --dart-define values.\n\n'
          'Run with:\n'
          'flutter run '
          '--dart-define=LIVECHAT_HTTP_URL=https://your-domain.com/graphql '
          '--dart-define=LIVECHAT_WS_URL=wss://your-domain.com/graphql '
          '--dart-define=LIVECHAT_API_KEY=lc_your_api_key',
        ),
      ),
    );
  }
}
