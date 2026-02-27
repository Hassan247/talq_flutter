import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../bloc/talq_bloc.dart';
import '../core/talq_client.dart';
import '../state/talq_controller.dart';

class TalqSdkScope extends StatefulWidget {
  final TalqClient client;
  final Widget child;
  final bool provideBloc;
  final TalqController? controller;

  const TalqSdkScope({
    super.key,
    required this.client,
    required this.child,
    this.provideBloc = true,
    this.controller,
  });

  @override
  State<TalqSdkScope> createState() => _TalqSdkScopeState();
}

class _TalqSdkScopeState extends State<TalqSdkScope> {
  late final TalqController _controller;
  late final bool _ownsController;
  TalqBloc? _bloc;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TalqController(widget.client);
    if (widget.provideBloc) {
      _bloc = TalqBloc(controller: _controller);
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
    final child = ChangeNotifierProvider<TalqController>.value(
      value: _controller,
      child: widget.child,
    );

    if (_bloc == null) {
      return child;
    }

    return BlocProvider<TalqBloc>.value(value: _bloc!, child: child);
  }
}
