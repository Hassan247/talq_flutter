class LivechatGraphqlDocuments {
  static const String initVisitorMutation = r'''
    mutation InitVisitor($input: InitVisitorInput!) {
      initVisitor(input: $input) {
        token
        visitor {
          id
          firstName
          lastName
          email
          rooms {
            id
            status
            unreadCount
            visitorUnreadCount
            lastMessageAt
            lastMessage {
              id
              content
              senderType
              senderName
              senderAvatarUrl
              contentType
              fileUrl
              fileName
              createdAt
              delivered
              read
            }
            createdAt
            rating
            ratingComment
            assignee {
              firstName
              lastName
              avatarUrl
            }
          }
        }
        workspace {
          id
          name
          logoUrl
          livechatLogoUrl
          showResponseTime
          responseTimeType
          customResponseTime
          autoReplyEnabled
          autoReplyMessage
          welcomeMessage
          primaryColor
        }
        agentAvatars
        faqs {
          id
          question
          answer
          sortOrder
        }
      }
    }
  ''';

  static const String startNewConversationMutation = r'''
    mutation {
      startNewConversation {
        id
        status
        createdAt
        lastMessageAt
        lastMessage {
          id
          content
          senderType
          senderName
          senderAvatarUrl
          contentType
          fileUrl
          fileName
          createdAt
          delivered
          read
        }
      }
    }
  ''';

  static const String visitorRoomsQuery = r'''
    query {
      visitorRooms {
        id
        status
        unreadCount
        visitorUnreadCount
        lastMessageAt
        lastMessage {
          id
          content
          senderType
          senderName
          senderAvatarUrl
          contentType
          fileUrl
          fileName
          createdAt
          delivered
          read
        }
        createdAt
        rating
        ratingComment
        assignee {
          id
          firstName
          lastName
          avatarUrl
        }
      }
    }
  ''';

  static const String roomWithMessagesQuery = r'''
    query GetRoom($roomId: ID!, $after: String) {
      room(id: $roomId) {
        id
        status
        unreadCount
        visitorUnreadCount
        messages(first: 20, after: $after) {
          edges {
            node {
              id
              content
              senderType
              senderName
              senderAvatarUrl
              contentType
              fileUrl
              fileName
              createdAt
              read
              delivered
              reactions
              replyTo {
                id
                content
                senderType
                senderName
                contentType
                fileUrl
                fileName
                createdAt
              }
            }
          }
          pageInfo {
            hasNextPage
            endCursor
          }
        }
        events {
          id
          type
          metadata
          createdAt
        }
      }
    }
  ''';

  static const String sendVisitorMessageMutation = r'''
    mutation SendVisitorMessage($input: SendMessageInput!) {
      sendVisitorMessage(input: $input) {
        id
        content
        senderType
        senderName
        senderAvatarUrl
        contentType
        fileUrl
        fileName
        createdAt
        read
        reactions
        replyTo {
          id
          content
          senderType
          senderName
          contentType
          fileUrl
          fileName
          createdAt
        }
        room {
          id
        }
      }
    }
  ''';

  static const String visitorTypingMutation = r'''
    mutation VisitorTyping($roomId: ID!) {
      visitorTyping(roomId: $roomId)
    }
  ''';

  static const String updateVisitorPageMutation = r'''
    mutation UpdateVisitorPage($roomId: ID!, $page: String!) {
      updateVisitorPage(roomId: $roomId, page: $page) {
        id
        currentPage
      }
    }
  ''';

  static const String markMessagesAsReadMutation = r'''
    mutation MarkMessagesAsRead($roomId: ID!) {
      markMessagesAsRead(roomId: $roomId)
    }
  ''';

  static const String markMessagesAsDeliveredMutation = r'''
    mutation VisitorMarkMessagesAsDelivered($roomId: ID!) {
      visitorMarkMessagesAsDelivered(roomId: $roomId)
    }
  ''';

  static const String visitorNewMessageSubscription = r'''
    subscription {
      visitorNewMessage {
        id
        content
        senderType
        senderName
        senderAvatarUrl
        contentType
        fileUrl
        fileName
        createdAt
        read
        reactions
        replyTo {
          id
          content
          senderType
          senderName
          contentType
          fileUrl
          fileName
          createdAt
        }
        room {
          id
        }
      }
    }
  ''';

  static const String visitorRoomUpdatedSubscription = r'''
    subscription {
      visitorRoomUpdated {
        id
        status
        unreadCount
        visitorUnreadCount
        createdAt
        lastMessageAt
        rating
        ratingComment
        assignee {
          id
          firstName
          lastName
          avatarUrl
        }
        lastMessage {
          id
          content
          senderType
          senderName
          senderAvatarUrl
          contentType
          fileUrl
          fileName
          createdAt
          delivered
          read
        }
      }
    }
  ''';

  static const String visitorWorkspaceUpdatedSubscription = r'''
    subscription {
      visitorWorkspaceUpdated {
        id
        name
        logoUrl
        livechatLogoUrl
        showResponseTime
        responseTimeType
        customResponseTime
        autoReplyEnabled
        autoReplyMessage
        welcomeMessage
        primaryColor
      }
    }
  ''';

  static const String typingSubscription = r'''
    subscription OnTyping($roomId: ID!) {
      typing(roomId: $roomId)
    }
  ''';

  static const String rateRoomMutation = r'''
    mutation RateRoom($roomId: ID!, $rating: Int!, $comment: String) {
      rateRoom(roomId: $roomId, rating: $rating, comment: $comment) {
        id
        rating
      }
    }
  ''';

  static const String voteFaqMutation = r'''
    mutation VoteFAQ($id: ID!, $helpful: Boolean!) {
      voteFAQ(id: $id, helpful: $helpful)
    }
  ''';

  static const String roomStatusQuery = r'''
    query GetRoom($id: ID!) {
      room(id: $id) {
        id
        status
        rating
        ratingComment
      }
    }
  ''';

  static const String addReactionMutation = r'''
    mutation AddReaction($messageId: ID!, $emoji: String!) {
      addReaction(messageId: $messageId, emoji: $emoji) {
        id
        reactions
      }
    }
  ''';

  static const String removeReactionMutation = r'''
    mutation RemoveReaction($messageId: ID!, $emoji: String!) {
      removeReaction(messageId: $messageId, emoji: $emoji) {
        id
        reactions
      }
    }
  ''';

  static const String visitorFaqsQuery = r'''
    query VisitorFaqs($query: String, $first: Int, $after: String) {
      visitorFaqs(query: $query, first: $first, after: $after) {
        edges {
          node {
            id
            question
            answer
            sortOrder
          }
          cursor
        }
        pageInfo {
          hasNextPage
          endCursor
        }
        totalCount
      }
    }
  ''';
}
