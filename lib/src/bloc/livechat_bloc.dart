import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/livechat_controller.dart';
import 'livechat_event.dart';
import 'livechat_state.dart';

class LivechatBloc extends Bloc<LivechatEvent, LivechatState> {
  final LivechatController controller;
  final bool disposeControllerOnClose;
  late final VoidCallback _controllerListener;

  LivechatBloc({
    required this.controller,
    this.disposeControllerOnClose = false,
  }) : super(LivechatState.fromController(controller)) {
    on<LivechatSyncRequested>(_onSyncRequested);
    on<LivechatInitializeRequested>(_onInitializeRequested);
    on<LivechatFetchRoomsRequested>(_onFetchRoomsRequested);
    on<LivechatFetchMessagesRequested>(_onFetchMessagesRequested);
    on<LivechatSendMessageRequested>(_onSendMessageRequested);
    on<LivechatSendFileRequested>(_onSendFileRequested);
    on<LivechatPrepareNewConversationRequested>(
      _onPrepareNewConversationRequested,
    );
    on<LivechatStartNewConversationRequested>(_onStartNewConversationRequested);
    on<LivechatFetchFaqsRequested>(_onFetchFaqsRequested);
    on<LivechatRateRoomRequested>(_onRateRoomRequested);
    on<LivechatResetSessionRequested>(_onResetSessionRequested);
    on<LivechatSetChatVisibilityChanged>(_onSetChatVisibilityChanged);
    on<LivechatSetLifecycleChanged>(_onSetLifecycleChanged);
    on<LivechatMarkAsReadRequested>(_onMarkAsReadRequested);
    on<LivechatClearErrorRequested>(_onClearErrorRequested);

    _controllerListener = () => add(const LivechatSyncRequested());
    controller.addListener(_controllerListener);
  }

  Future<void> _onSyncRequested(
    LivechatSyncRequested event,
    Emitter<LivechatState> emit,
  ) async {
    emit(LivechatState.fromController(controller));
  }

  Future<void> _onInitializeRequested(
    LivechatInitializeRequested event,
    Emitter<LivechatState> emit,
  ) async {
    await controller.initialize(
      firstName: event.firstName,
      lastName: event.lastName,
      email: event.email,
      currentPage: event.currentPage,
      metadata: event.metadata,
      pushToken: event.pushToken,
    );
  }

  Future<void> _onFetchRoomsRequested(
    LivechatFetchRoomsRequested event,
    Emitter<LivechatState> emit,
  ) async {
    await controller.fetchRooms();
  }

  Future<void> _onFetchMessagesRequested(
    LivechatFetchMessagesRequested event,
    Emitter<LivechatState> emit,
  ) async {
    await controller.fetchMessages(
      roomId: event.roomId,
      isLoadMore: event.isLoadMore,
    );
  }

  Future<void> _onSendMessageRequested(
    LivechatSendMessageRequested event,
    Emitter<LivechatState> emit,
  ) async {
    await controller.sendMessage(
      event.content,
      contentType: event.contentType,
      fileUrl: event.fileUrl,
      fileName: event.fileName,
      tempId: event.tempId,
    );
  }

  Future<void> _onSendFileRequested(
    LivechatSendFileRequested event,
    Emitter<LivechatState> emit,
  ) async {
    await controller.sendFile(event.filePath, caption: event.caption);
  }

  Future<void> _onPrepareNewConversationRequested(
    LivechatPrepareNewConversationRequested event,
    Emitter<LivechatState> emit,
  ) async {
    controller.prepareNewConversation();
  }

  Future<void> _onStartNewConversationRequested(
    LivechatStartNewConversationRequested event,
    Emitter<LivechatState> emit,
  ) async {
    await controller.startNewConversation();
  }

  Future<void> _onFetchFaqsRequested(
    LivechatFetchFaqsRequested event,
    Emitter<LivechatState> emit,
  ) async {
    await controller.fetchFaqs(reload: event.reload, query: event.query);
  }

  Future<void> _onRateRoomRequested(
    LivechatRateRoomRequested event,
    Emitter<LivechatState> emit,
  ) async {
    await controller.rateRoom(event.rating, comment: event.comment);
  }

  Future<void> _onResetSessionRequested(
    LivechatResetSessionRequested event,
    Emitter<LivechatState> emit,
  ) async {
    await controller.resetSession();
  }

  Future<void> _onSetChatVisibilityChanged(
    LivechatSetChatVisibilityChanged event,
    Emitter<LivechatState> emit,
  ) async {
    controller.setChatVisible(event.isVisible);
  }

  Future<void> _onSetLifecycleChanged(
    LivechatSetLifecycleChanged event,
    Emitter<LivechatState> emit,
  ) async {
    controller.setLifecycleState(event.lifecycleState);
  }

  Future<void> _onMarkAsReadRequested(
    LivechatMarkAsReadRequested event,
    Emitter<LivechatState> emit,
  ) async {
    await controller.markAsRead();
  }

  Future<void> _onClearErrorRequested(
    LivechatClearErrorRequested event,
    Emitter<LivechatState> emit,
  ) async {
    controller.clearError();
  }

  @override
  Future<void> close() async {
    controller.removeListener(_controllerListener);
    if (disposeControllerOnClose) {
      controller.dispose();
    }
    await super.close();
  }
}
