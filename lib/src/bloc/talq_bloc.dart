import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/talq_controller.dart';
import 'talq_event.dart';
import 'talq_state.dart';

class TalqBloc extends Bloc<TalqEvent, TalqState> {
  final TalqController controller;
  final bool disposeControllerOnClose;
  late final VoidCallback _controllerListener;

  TalqBloc({
    required this.controller,
    this.disposeControllerOnClose = false,
  }) : super(TalqState.fromController(controller)) {
    on<TalqSyncRequested>(_onSyncRequested);
    on<TalqInitializeRequested>(_onInitializeRequested);
    on<TalqFetchRoomsRequested>(_onFetchRoomsRequested);
    on<TalqFetchMessagesRequested>(_onFetchMessagesRequested);
    on<TalqSendMessageRequested>(_onSendMessageRequested);
    on<TalqSendFileRequested>(_onSendFileRequested);
    on<TalqPrepareNewConversationRequested>(
      _onPrepareNewConversationRequested,
    );
    on<TalqStartNewConversationRequested>(_onStartNewConversationRequested);
    on<TalqFetchFaqsRequested>(_onFetchFaqsRequested);
    on<TalqRateRoomRequested>(_onRateRoomRequested);
    on<TalqResetSessionRequested>(_onResetSessionRequested);
    on<TalqSetChatVisibilityChanged>(_onSetChatVisibilityChanged);
    on<TalqSetLifecycleChanged>(_onSetLifecycleChanged);
    on<TalqMarkAsReadRequested>(_onMarkAsReadRequested);
    on<TalqClearErrorRequested>(_onClearErrorRequested);

    _controllerListener = () => add(const TalqSyncRequested());
    controller.addListener(_controllerListener);
  }

  Future<void> _onSyncRequested(
    TalqSyncRequested event,
    Emitter<TalqState> emit,
  ) async {
    emit(TalqState.fromController(controller));
  }

  Future<void> _onInitializeRequested(
    TalqInitializeRequested event,
    Emitter<TalqState> emit,
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
    TalqFetchRoomsRequested event,
    Emitter<TalqState> emit,
  ) async {
    await controller.fetchRooms();
  }

  Future<void> _onFetchMessagesRequested(
    TalqFetchMessagesRequested event,
    Emitter<TalqState> emit,
  ) async {
    await controller.fetchMessages(
      roomId: event.roomId,
      isLoadMore: event.isLoadMore,
    );
  }

  Future<void> _onSendMessageRequested(
    TalqSendMessageRequested event,
    Emitter<TalqState> emit,
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
    TalqSendFileRequested event,
    Emitter<TalqState> emit,
  ) async {
    await controller.sendFile(event.filePath, caption: event.caption);
  }

  Future<void> _onPrepareNewConversationRequested(
    TalqPrepareNewConversationRequested event,
    Emitter<TalqState> emit,
  ) async {
    controller.prepareNewConversation();
  }

  Future<void> _onStartNewConversationRequested(
    TalqStartNewConversationRequested event,
    Emitter<TalqState> emit,
  ) async {
    await controller.startNewConversation();
  }

  Future<void> _onFetchFaqsRequested(
    TalqFetchFaqsRequested event,
    Emitter<TalqState> emit,
  ) async {
    await controller.fetchFaqs(reload: event.reload, query: event.query);
  }

  Future<void> _onRateRoomRequested(
    TalqRateRoomRequested event,
    Emitter<TalqState> emit,
  ) async {
    await controller.rateRoom(event.rating, comment: event.comment);
  }

  Future<void> _onResetSessionRequested(
    TalqResetSessionRequested event,
    Emitter<TalqState> emit,
  ) async {
    await controller.resetSession();
  }

  Future<void> _onSetChatVisibilityChanged(
    TalqSetChatVisibilityChanged event,
    Emitter<TalqState> emit,
  ) async {
    controller.setChatVisible(event.isVisible);
  }

  Future<void> _onSetLifecycleChanged(
    TalqSetLifecycleChanged event,
    Emitter<TalqState> emit,
  ) async {
    controller.setLifecycleState(event.lifecycleState);
  }

  Future<void> _onMarkAsReadRequested(
    TalqMarkAsReadRequested event,
    Emitter<TalqState> emit,
  ) async {
    await controller.markAsRead();
  }

  Future<void> _onClearErrorRequested(
    TalqClearErrorRequested event,
    Emitter<TalqState> emit,
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
