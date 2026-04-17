import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../state/talq_controller.dart';
import '../theme/talq_theme.dart';
import 'rooms_list_view.dart';
import 'shared_widgets.dart';

class TalqFAB extends StatefulWidget {
  final TalqTheme theme;
  final Widget? icon;
  final double size;

  const TalqFAB({
    super.key,
    this.theme = const TalqTheme(),
    this.icon,
    this.size = 60,
  });

  @override
  State<TalqFAB> createState() => _TalqFABState();
}

class _TalqFABState extends State<TalqFAB> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<TalqController>();
      if (!controller.isInitialized && !controller.isLoading) {
        controller.initialize();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TalqTheme activeTheme = widget.theme;
    int unreadCount = 0;
    try {
      final controller = context.watch<TalqController>();
      activeTheme = controller.theme;
      unreadCount = controller.totalUnreadCount;
    } catch (_) {}

    final primaryColor = activeTheme.primaryColor;
    final darkerColor = HSLColor.fromColor(primaryColor)
        .withLightness(
          (HSLColor.fromColor(primaryColor).lightness - 0.15).clamp(0.0, 1.0),
        )
        .toColor();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTapDown: (_) => _animController.forward(),
          onTapUp: (_) => _animController.reverse(),
          onTapCancel: () => _animController.reverse(),
          onTap: () {
            Navigator.of(context).push(
              TalqPageRoute(
                builder: (context) => RoomsListView(theme: activeTheme),
              ),
            );
          },
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) =>
                Transform.scale(scale: _scaleAnimation.value, child: child),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, darkerColor],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child:
                    widget.icon ??
                    SvgPicture.asset(
                      'packages/talq_flutter/assets/icons/messages.svg',
                      width: 26,
                      height: 26,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
              ),
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
