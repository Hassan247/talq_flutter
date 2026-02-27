import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../bloc/livechat_bloc.dart';
import '../core/livechat_client.dart';
import '../state/livechat_controller.dart';

class LivechatSdkScope extends StatefulWidget {
  final LivechatClient client;
  final Widget child;
  final bool provideBloc;
  final LivechatController? controller;

  const LivechatSdkScope({
    super.key,
    required this.client,
    required this.child,
    this.provideBloc = true,
    this.controller,
  });

  @override
  State<LivechatSdkScope> createState() => _LivechatSdkScopeState();
}

class _LivechatSdkScopeState extends State<LivechatSdkScope> {
  late final LivechatController _controller;
  late final bool _ownsController;
  LivechatBloc? _bloc;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? LivechatController(widget.client);
    if (widget.provideBloc) {
      _bloc = LivechatBloc(controller: _controller);
    }
  }

  @override
  void dispose() {
    if (_bloc != null) {
      unawaited(_bloc!.close());
    }
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = ChangeNotifierProvider<LivechatController>.value(
      value: _controller,
      child: widget.child,
    );

    if (_bloc == null) {
      return child;
    }

    return BlocProvider<LivechatBloc>.value(value: _bloc!, child: child);
  }
}
