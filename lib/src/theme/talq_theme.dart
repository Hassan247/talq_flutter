import 'package:flutter/material.dart';

class TalqTheme {
  final Color primaryColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color darkHeaderColor;
  final Color inputBackgroundColor;
  final Color cardShadowColor;
  final Color avatarBackgroundColor;
  final Color avatarIconColor;
  final Color resolvedBackgroundColor;
  final Color resolvedTextColor;
  final Color inputHintColor;
  final Color unavailabilityOverlayColor;

  // Bubbles
  final Color userBubbleColor;
  final Color agentBubbleColor;
  final Color userTextColor;
  final Color agentTextColor;

  // Ticks/Status
  final Color sentTickColor;
  final Color deliveredTickColor;
  final Color readTickColor;
  final Color unreadBadgeColor;
  final Color unreadTextColor;

  // Typography
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
  final TextStyle bodyStyle;
  final TextStyle timestampStyle;

  // Shapes
  final double borderRadius;

  const TalqTheme({
    this.inputBackgroundColor = const Color(0xFFF1F3F5),
    this.cardShadowColor = const Color(
      0x0D000000,
    ), // Colors.black.withValues(alpha: 0.05)
    this.avatarBackgroundColor = const Color(0xFFEBEFF3), // Slate 100
    this.avatarIconColor = const Color(0xFF83888F), // Colors.grey
    this.resolvedBackgroundColor = const Color(0xFFE8F5E9), // Colors.green[50]
    this.resolvedTextColor = const Color(0xFF4CAF50), // Colors.green
    this.inputHintColor = const Color(0xFFBDBDBD), // Colors.grey[400]
    this.unavailabilityOverlayColor = const Color(
      0x80000000,
    ), // Colors.black.withValues(alpha: 0.5)
    this.primaryColor = const Color(0xFF0057FF),
    this.backgroundColor = const Color(0xFFF5F7FA),
    this.surfaceColor = const Color(0xFFFFFFFF),
    this.darkHeaderColor = const Color(0xFF151515),
    this.userBubbleColor = const Color(0xFF151515),
    this.agentBubbleColor = const Color(0xFFFFFFFF),
    this.userTextColor = const Color(0xFFFFFFFF),
    this.agentTextColor = const Color(0xDD000000), // Colors.black87
    this.sentTickColor = const Color(0xFF9E9E9E), // Colors.grey
    this.deliveredTickColor = const Color(0xFF9E9E9E), // Colors.grey
    this.readTickColor = const Color(0xFF2196F3), // Colors.blue
    this.unreadBadgeColor = const Color(0xFFFBECEB),
    this.unreadTextColor = const Color(0xFFD3453D),
    this.titleStyle = const TextStyle(
      fontFamily: 'Inter',
      package: 'talq_sdk',
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Color(0xFF000000),
    ),
    this.subtitleStyle = const TextStyle(
      fontFamily: 'Inter',
      package: 'talq_sdk',
      fontSize: 11,
      fontWeight: FontWeight.normal,
      color: Color(0xFF757575), // Colors.grey[600]
    ),
    this.bodyStyle = const TextStyle(
      fontFamily: 'Inter',
      package: 'talq_sdk',
      fontSize: 15,
      height: 1.4,
      color: Color(0xDD000000), // Colors.black87
    ),
    this.timestampStyle = const TextStyle(
      fontFamily: 'Inter',
      package: 'talq_sdk',
      fontSize: 10,
    ),
    this.borderRadius = 20.0,
  });

  factory TalqTheme.light() => const TalqTheme();

  factory TalqTheme.dark() => const TalqTheme(
    backgroundColor: Color(0xFF121212),
    surfaceColor: Color(0xFF1E1E1E),
    darkHeaderColor: Color(0xFF000000),
    agentBubbleColor: Color(0xFF2C2C2C),
    agentTextColor: Color(0xFFFFFFFF),
    titleStyle: TextStyle(
      fontFamily: 'Inter',
      package: 'talq_sdk',
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Color(0xFFFFFFFF),
    ),
    subtitleStyle: TextStyle(
      fontFamily: 'Inter',
      package: 'talq_sdk',
      fontSize: 11,
      fontWeight: FontWeight.normal,
      color: Color(0xFFAAAAAA),
    ),
  );

  TalqTheme copyWith({
    Color? primaryColor,
    Color? backgroundColor,
    Color? surfaceColor,
    Color? darkHeaderColor,
    Color? inputBackgroundColor,
    Color? cardShadowColor,
    Color? avatarBackgroundColor,
    Color? avatarIconColor,
    Color? resolvedBackgroundColor,
    Color? resolvedTextColor,
    Color? inputHintColor,
    Color? unavailabilityOverlayColor,
    Color? userBubbleColor,
    Color? agentBubbleColor,
    Color? userTextColor,
    Color? agentTextColor,
    Color? sentTickColor,
    Color? deliveredTickColor,
    Color? readTickColor,
    Color? unreadBadgeColor,
    Color? unreadTextColor,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    TextStyle? bodyStyle,
    TextStyle? timestampStyle,
    double? borderRadius,
  }) {
    return TalqTheme(
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      darkHeaderColor: darkHeaderColor ?? this.darkHeaderColor,
      inputBackgroundColor: inputBackgroundColor ?? this.inputBackgroundColor,
      cardShadowColor: cardShadowColor ?? this.cardShadowColor,
      avatarBackgroundColor:
          avatarBackgroundColor ?? this.avatarBackgroundColor,
      avatarIconColor: avatarIconColor ?? this.avatarIconColor,
      resolvedBackgroundColor:
          resolvedBackgroundColor ?? this.resolvedBackgroundColor,
      resolvedTextColor: resolvedTextColor ?? this.resolvedTextColor,
      userBubbleColor: userBubbleColor ?? this.userBubbleColor,
      agentBubbleColor: agentBubbleColor ?? this.agentBubbleColor,
      userTextColor: userTextColor ?? this.userTextColor,
      agentTextColor: agentTextColor ?? this.agentTextColor,
      sentTickColor: sentTickColor ?? this.sentTickColor,
      deliveredTickColor: deliveredTickColor ?? this.deliveredTickColor,
      readTickColor: readTickColor ?? this.readTickColor,
      unreadBadgeColor: unreadBadgeColor ?? this.unreadBadgeColor,
      unreadTextColor: unreadTextColor ?? this.unreadTextColor,
      titleStyle: titleStyle ?? this.titleStyle,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      timestampStyle: timestampStyle ?? this.timestampStyle,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
