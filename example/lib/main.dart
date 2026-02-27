import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:talq_sdk/talq_sdk.dart';

const _apiKey = String.fromEnvironment('TALQ_API_KEY');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TalqExampleApp());
}

class TalqExampleApp extends StatelessWidget {
  const TalqExampleApp({super.key});

  bool get _isConfigured => _apiKey.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_isConfigured) {
      return const MaterialApp(home: _ConfigurationErrorScreen());
    }

    final client = TalqClient(
      apiKey: _apiKey,
    );

    return TalqSdkScope(
      client: client,
      child: MaterialApp(
        title: 'Talq SDK Example',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          fontFamily: 'packages/talq_sdk/BricolageGrotesque',
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
    context.read<TalqBloc>().add(
      TalqInitializeRequested(email: 'visitor_$id@example.com'),
    );
  }

  Future<void> _resetSession() async {
    final bloc = context.read<TalqBloc>();
    bloc.add(const TalqResetSessionRequested());
    final id = _generateUniqueId();
    bloc.add(TalqInitializeRequested(email: 'visitor_$id@example.com'));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TalqBloc, TalqState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.errorMessage == null || state.errorMessage!.isEmpty) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      },
      builder: (context, state) {
        final isBusy = state.status == TalqStatus.loading;

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
          floatingActionButton: const TalqFAB(
            theme: TalqTheme(
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
      appBar: AppBar(title: const Text('Talq SDK Example')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Missing required API key.\n\n'
          'Run with:\n'
          'flutter run '
          '--dart-define=TALQ_API_KEY=lc_your_api_key',
        ),
      ),
    );
  }
}
