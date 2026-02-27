import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';

sealed class TalqEvent extends Equatable {
  const TalqEvent();

  @override
  List<Object?> get props => const [];
}

class TalqSyncRequested extends TalqEvent {
  const TalqSyncRequested();
}

class TalqInitializeRequested extends TalqEvent {
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? currentPage;
  final Map<String, dynamic>? metadata;
  final String? pushToken;

  const TalqInitializeRequested({
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

class TalqFetchRoomsRequested extends TalqEvent {
  const TalqFetchRoomsRequested();
}

class TalqFetchMessagesRequested extends TalqEvent {
  final String? roomId;
  final bool isLoadMore;

  const TalqFetchMessagesRequested({this.roomId, this.isLoadMore = false});

  @override
  List<Object?> get props => [roomId, isLoadMore];
}

class TalqSendMessageRequested extends TalqEvent {
  final String content;
  final ContentType contentType;
  final String? fileUrl;
  final String? fileName;
  final String? tempId;

  const TalqSendMessageRequested({
    required this.content,
    this.contentType = ContentType.text,
    this.fileUrl,
    this.fileName,
    this.tempId,
  });

  @override
  List<Object?> get props => [content, contentType, fileUrl, fileName, tempId];
}

class TalqSendFileRequested extends TalqEvent {
  final String filePath;
  final String? caption;

  const TalqSendFileRequested({required this.filePath, this.caption});

  @override
  List<Object?> get props => [filePath, caption];
}

class TalqPrepareNewConversationRequested extends TalqEvent {
  const TalqPrepareNewConversationRequested();
}

class TalqStartNewConversationRequested extends TalqEvent {
  const TalqStartNewConversationRequested();
}

class TalqFetchFaqsRequested extends TalqEvent {
  final bool reload;
  final String? query;

  const TalqFetchFaqsRequested({this.reload = false, this.query});

  @override
  List<Object?> get props => [reload, query];
}

class TalqRateRoomRequested extends TalqEvent {
  final int rating;
  final String? comment;

  const TalqRateRoomRequested({required this.rating, this.comment});

  @override
  List<Object?> get props => [rating, comment];
}

class TalqResetSessionRequested extends TalqEvent {
  const TalqResetSessionRequested();
}

class TalqSetChatVisibilityChanged extends TalqEvent {
  final bool isVisible;

  const TalqSetChatVisibilityChanged(this.isVisible);

  @override
  List<Object?> get props => [isVisible];
}

class TalqSetLifecycleChanged extends TalqEvent {
  final AppLifecycleState lifecycleState;

  const TalqSetLifecycleChanged(this.lifecycleState);

  @override
  List<Object?> get props => [lifecycleState];
}

class TalqMarkAsReadRequested extends TalqEvent {
  const TalqMarkAsReadRequested();
}

class TalqClearErrorRequested extends TalqEvent {
  const TalqClearErrorRequested();
}
