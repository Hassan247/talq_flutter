import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/livechat_controller.dart';
import '../theme/livechat_theme.dart';

class FAQListView extends StatefulWidget {
  final LivechatTheme theme;

  const FAQListView({super.key, this.theme = const LivechatTheme()});

  @override
  State<FAQListView> createState() => _FAQListViewState();
}

class _FAQListViewState extends State<FAQListView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Initial fetch if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<LivechatController>();
      if (controller.paginatedFaqs.isEmpty) {
        controller.fetchFaqs(reload: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<LivechatController>().fetchFaqs();
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<LivechatController>().fetchFaqs(query: query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: widget.theme.backgroundColor,
        appBar: AppBar(
          backgroundColor: widget.theme.backgroundColor, // seamless
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: SvgPicture.asset(
              'assets/icons/arrow-left.svg',
              package: 'livechat_sdk',
              colorFilter: ColorFilter.mode(
                widget.theme.titleStyle.color!,
                BlendMode.srcIn,
              ),
              width: 20,
              height: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Help Center',
            style: widget.theme.titleStyle.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: Consumer<LivechatController>(
                builder: (context, controller, _) {
                  final faqs = controller.paginatedFaqs;

                  if (faqs.isEmpty && controller.isFaqLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (faqs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.help_outline,
                            size: 64,
                            color: widget.theme.subtitleStyle.color?.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            controller.faqSearchQuery.isEmpty
                                ? 'No articles found'
                                : 'No results for "${controller.faqSearchQuery}"',
                            style: widget.theme.subtitleStyle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    key: const PageStorageKey('faq_list'),
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount:
                        faqs.length + (controller.faqHasNextPage ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == faqs.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      final faq = faqs[index];
                      return _buildFAQCard(context, faq);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      color: widget.theme.backgroundColor, // seamless
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        style: widget.theme.bodyStyle,
        decoration: InputDecoration(
          hintText: 'Search for articles...',
          hintStyle: widget.theme.subtitleStyle.copyWith(fontSize: 15),
          prefixIcon: Icon(
            Icons.search,
            color: widget.theme.subtitleStyle.color,
            size: 22,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    size: 18,
                    color: widget.theme.subtitleStyle.color,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: widget.theme.surfaceColor, // Input is white/surface
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: widget.theme.primaryColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFAQCard(BuildContext context, LivechatFAQ faq) {
    return Container(
      decoration: BoxDecoration(
        color: widget.theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.theme.cardShadowColor.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.theme.cardShadowColor.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FAQDetailView(faq: faq, theme: widget.theme),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.theme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/article.svg',
                    package: 'livechat_sdk',
                    colorFilter: ColorFilter.mode(
                      widget.theme.primaryColor, // Use primary color for icon
                      BlendMode.srcIn,
                    ),
                    width: 20,
                    height: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    faq.question,
                    style: widget.theme.titleStyle.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SvgPicture.asset(
                  'assets/icons/arrow-right.svg',
                  package: 'livechat_sdk',
                  colorFilter: ColorFilter.mode(
                    widget.theme.subtitleStyle.color!.withValues(alpha: 0.5),
                    BlendMode.srcIn,
                  ),
                  width: 14,
                  height: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FAQDetailView extends StatefulWidget {
  final LivechatFAQ faq;
  final LivechatTheme theme;

  const FAQDetailView({
    super.key,
    required this.faq,
    this.theme = const LivechatTheme(),
  });

  @override
  State<FAQDetailView> createState() => _FAQDetailViewState();
}

class _FAQDetailViewState extends State<FAQDetailView> {
  bool _voted = false;
  bool? _isHelpful;

  Future<void> _handleVote(bool helpful) async {
    if (_voted) return;

    setState(() {
      _voted = true;
      _isHelpful = helpful;
    });

    final controller = context.read<LivechatController>();
    await controller.voteFAQ(widget.faq.id, helpful);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: widget.theme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/icons/arrow-left.svg',
            package: 'livechat_sdk',
            colorFilter: ColorFilter.mode(
              widget.theme.titleStyle.color!,
              BlendMode.srcIn,
            ),
            width: 20,
            height: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Article',
          style: widget.theme.titleStyle.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: widget.theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Article',
                style: TextStyle(
                  color: widget.theme.primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.faq.question,
              style: widget.theme.titleStyle.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 28),
            MarkdownBody(
              data: widget.faq.answer,
              styleSheet: MarkdownStyleSheet(
                p: widget.theme.bodyStyle.copyWith(
                  height: 1.7,
                  fontSize: 16,
                  color: widget.theme.titleStyle.color?.withValues(alpha: 0.7),
                ),
                h1: widget.theme.titleStyle.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                h2: widget.theme.titleStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                listBullet: widget.theme.bodyStyle.copyWith(fontSize: 16),
              ),
            ),
            const SizedBox(height: 48),
            _buildFeedbackSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return Container(
      decoration: BoxDecoration(
        color: widget.theme.backgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.theme.cardShadowColor.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: _voted ? _buildVotedContent() : _buildVoteContent(),
    );
  }

  Widget _buildVotedContent() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.theme.resolvedTextColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              color: widget.theme.resolvedTextColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isHelpful == true
                ? 'Glad we could help!'
                : "We'll work on improving this.",
            style: widget.theme.titleStyle.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          if (_isHelpful == false) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: widget.theme.primaryColor,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              child: const Text('Start a conversation'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoteContent() {
    return Column(
      children: [
        Center(
          child: Text(
            'Was this helpful?',
            style: widget.theme.subtitleStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: widget.theme.titleStyle.color?.withValues(alpha: 0.5),
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFeedbackButton(Icons.thumb_up_rounded, 'Yes', true),
            const SizedBox(width: 12),
            _buildFeedbackButton(Icons.thumb_down_rounded, 'No', false),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedbackButton(IconData icon, String label, bool helpful) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () => _handleVote(helpful),
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: widget.theme.titleStyle.color?.withValues(
            alpha: 0.8,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(
            color: widget.theme.cardShadowColor.withValues(alpha: 0.12),
          ),
          backgroundColor: widget.theme.surfaceColor,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: -0.2,
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
