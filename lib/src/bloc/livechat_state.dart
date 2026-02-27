import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/livechat_controller.dart';
import '../theme/livechat_theme.dart';

enum LivechatStatus { initial, loading, ready, failure }

class LivechatState extends Equatable {
  final LivechatStatus status;
  final bool isInitialized;
  final bool isLoading;
  final bool isRoomLoading;
  final bool isFetchingMore;
  final bool hasMoreMessages;
  final bool isFaqLoading;
  final bool faqHasNextPage;
  final bool isAgentTyping;
  final bool showRatingPrompt;
  final bool isRatingSubmitted;
  final bool isChatVisible;
  final AppLifecycleState lifecycleState;
  final String? roomId;
  final RoomStatus roomStatus;
  final String? errorMessage;
  final int? rating;
  final String? ratingComment;
  final LivechatVisitor? visitor;
  final LivechatWorkspace? workspace;
  final LivechatMessage? replyingTo;
  final LivechatTheme theme;
  final List<LivechatRoom> rooms;
  final List<LivechatMessage> messages;
  final List<LivechatFAQ> faqs;
  final List<LivechatFAQ> paginatedFaqs;
  final String faqSearchQuery;

  const LivechatState({
    this.status = LivechatStatus.initial,
    this.isInitialized = false,
    this.isLoading = false,
    this.isRoomLoading = false,
    this.isFetchingMore = false,
    this.hasMoreMessages = false,
    this.isFaqLoading = false,
    this.faqHasNextPage = false,
    this.isAgentTyping = false,
    this.showRatingPrompt = false,
    this.isRatingSubmitted = false,
    this.isChatVisible = false,
    this.lifecycleState = AppLifecycleState.resumed,
    this.roomId,
    this.roomStatus = RoomStatus.open,
    this.errorMessage,
    this.rating,
    this.ratingComment,
    this.visitor,
    this.workspace,
    this.replyingTo,
    this.theme = const LivechatTheme(),
    this.rooms = const [],
    this.messages = const [],
    this.faqs = const [],
    this.paginatedFaqs = const [],
    this.faqSearchQuery = '',
  });

  factory LivechatState.fromController(LivechatController controller) {
    return LivechatState(
      status: _deriveStatus(controller),
      isInitialized: controller.isInitialized,
      isLoading: controller.isLoading,
      isRoomLoading: controller.isRoomLoading,
      isFetchingMore: controller.isFetchingMore,
      hasMoreMessages: controller.hasMoreMessages,
      isFaqLoading: controller.isFaqLoading,
      faqHasNextPage: controller.faqHasNextPage,
      isAgentTyping: controller.isAgentTyping,
      showRatingPrompt: controller.showRatingPrompt,
      isRatingSubmitted: controller.isRatingSubmitted,
      isChatVisible: controller.isChatVisible,
      lifecycleState: controller.lifecycleState,
      roomId: controller.roomId,
      roomStatus: controller.roomStatus,
      errorMessage: controller.errorMessage,
      rating: controller.rating,
      ratingComment: controller.ratingComment,
      visitor: controller.visitor,
      workspace: controller.workspace,
      replyingTo: controller.replyingTo,
      theme: controller.theme,
      rooms: List<LivechatRoom>.unmodifiable(controller.rooms),
      messages: List<LivechatMessage>.unmodifiable(controller.messages),
      faqs: List<LivechatFAQ>.unmodifiable(controller.faqs),
      paginatedFaqs: List<LivechatFAQ>.unmodifiable(controller.paginatedFaqs),
      faqSearchQuery: controller.faqSearchQuery,
    );
  }

  LivechatState copyWith({
    LivechatStatus? status,
    bool? isInitialized,
    bool? isLoading,
    bool? isRoomLoading,
    bool? isFetchingMore,
    bool? hasMoreMessages,
    bool? isFaqLoading,
    bool? faqHasNextPage,
    bool? isAgentTyping,
    bool? showRatingPrompt,
    bool? isRatingSubmitted,
    bool? isChatVisible,
    AppLifecycleState? lifecycleState,
    String? roomId,
    RoomStatus? roomStatus,
    String? errorMessage,
    int? rating,
    String? ratingComment,
    LivechatVisitor? visitor,
    LivechatWorkspace? workspace,
    LivechatMessage? replyingTo,
    LivechatTheme? theme,
    List<LivechatRoom>? rooms,
    List<LivechatMessage>? messages,
    List<LivechatFAQ>? faqs,
    List<LivechatFAQ>? paginatedFaqs,
    String? faqSearchQuery,
  }) {
    return LivechatState(
      status: status ?? this.status,
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isRoomLoading: isRoomLoading ?? this.isRoomLoading,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      isFaqLoading: isFaqLoading ?? this.isFaqLoading,
      faqHasNextPage: faqHasNextPage ?? this.faqHasNextPage,
      isAgentTyping: isAgentTyping ?? this.isAgentTyping,
      showRatingPrompt: showRatingPrompt ?? this.showRatingPrompt,
      isRatingSubmitted: isRatingSubmitted ?? this.isRatingSubmitted,
      isChatVisible: isChatVisible ?? this.isChatVisible,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      roomId: roomId ?? this.roomId,
      roomStatus: roomStatus ?? this.roomStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
      visitor: visitor ?? this.visitor,
      workspace: workspace ?? this.workspace,
      replyingTo: replyingTo ?? this.replyingTo,
      theme: theme ?? this.theme,
      rooms: rooms ?? this.rooms,
      messages: messages ?? this.messages,
      faqs: faqs ?? this.faqs,
      paginatedFaqs: paginatedFaqs ?? this.paginatedFaqs,
      faqSearchQuery: faqSearchQuery ?? this.faqSearchQuery,
    );
  }

  @override
  List<Object?> get props => [
    status,
    isInitialized,
    isLoading,
    isRoomLoading,
    isFetchingMore,
    hasMoreMessages,
    isFaqLoading,
    faqHasNextPage,
    isAgentTyping,
    showRatingPrompt,
    isRatingSubmitted,
    isChatVisible,
    lifecycleState,
    roomId,
    roomStatus,
    errorMessage,
    rating,
    ratingComment,
    visitor,
    workspace,
    replyingTo,
    theme,
    rooms,
    messages,
    faqs,
    paginatedFaqs,
    faqSearchQuery,
  ];

  static LivechatStatus _deriveStatus(LivechatController controller) {
    if (!controller.isInitialized && !controller.isLoading) {
      return LivechatStatus.initial;
    }
    if (controller.isLoading ||
        controller.isRoomLoading ||
        controller.isFaqLoading) {
      return LivechatStatus.loading;
    }
    if ((controller.errorMessage ?? '').isNotEmpty) {
      return LivechatStatus.failure;
    }
    return LivechatStatus.ready;
  }
}
