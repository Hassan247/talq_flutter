import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';

sealed class LivechatEvent extends Equatable {
  const LivechatEvent();

  @override
  List<Object?> get props => const [];
}

class LivechatSyncRequested extends LivechatEvent {
  const LivechatSyncRequested();
}

class LivechatInitializeRequested extends LivechatEvent {
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? currentPage;
  final Map<String, dynamic>? metadata;
  final String? pushToken;

  const LivechatInitializeRequested({
    this.firstName,
    this.lastName,
    this.email,
    this.currentPage,
    this.metadata,
    this.pushToken,
  });

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    email,
    currentPage,
    metadata,
    pushToken,
  ];
}

class LivechatFetchRoomsRequested extends LivechatEvent {
  const LivechatFetchRoomsRequested();
}

class LivechatFetchMessagesRequested extends LivechatEvent {
  final String? roomId;
  final bool isLoadMore;

  const LivechatFetchMessagesRequested({this.roomId, this.isLoadMore = false});

  @override
  List<Object?> get props => [roomId, isLoadMore];
}

class LivechatSendMessageRequested extends LivechatEvent {
  final String content;
  final ContentType contentType;
  final String? fileUrl;
  final String? fileName;
  final String? tempId;

  const LivechatSendMessageRequested({
    required this.content,
    this.contentType = ContentType.text,
    this.fileUrl,
    this.fileName,
    this.tempId,
  });

  @override
  List<Object?> get props => [content, contentType, fileUrl, fileName, tempId];
}

class LivechatSendFileRequested extends LivechatEvent {
  final String filePath;
  final String? caption;

  const LivechatSendFileRequested({required this.filePath, this.caption});

  @override
  List<Object?> get props => [filePath, caption];
}

class LivechatPrepareNewConversationRequested extends LivechatEvent {
  const LivechatPrepareNewConversationRequested();
}

class LivechatStartNewConversationRequested extends LivechatEvent {
  const LivechatStartNewConversationRequested();
}

class LivechatFetchFaqsRequested extends LivechatEvent {
  final bool reload;
  final String? query;

  const LivechatFetchFaqsRequested({this.reload = false, this.query});

  @override
  List<Object?> get props => [reload, query];
}

class LivechatRateRoomRequested extends LivechatEvent {
  final int rating;
  final String? comment;

  const LivechatRateRoomRequested({required this.rating, this.comment});

  @override
  List<Object?> get props => [rating, comment];
}

class LivechatResetSessionRequested extends LivechatEvent {
  const LivechatResetSessionRequested();
}

class LivechatSetChatVisibilityChanged extends LivechatEvent {
  final bool isVisible;

  const LivechatSetChatVisibilityChanged(this.isVisible);

  @override
  List<Object?> get props => [isVisible];
}

class LivechatSetLifecycleChanged extends LivechatEvent {
  final AppLifecycleState lifecycleState;

  const LivechatSetLifecycleChanged(this.lifecycleState);

  @override
  List<Object?> get props => [lifecycleState];
}

class LivechatMarkAsReadRequested extends LivechatEvent {
  const LivechatMarkAsReadRequested();
}

class LivechatClearErrorRequested extends LivechatEvent {
  const LivechatClearErrorRequested();
}
