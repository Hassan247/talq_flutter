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
          backgroundColor: widget.theme.surfaceColor,
          elevation: 0,
          leading: IconButton(
            icon: SvgPicture.asset(
              'assets/icons/arrow-left.svg',
              package: 'livechat_sdk',
              colorFilter: ColorFilter.mode(
                widget.theme.titleStyle.color!,
                BlendMode.srcIn,
              ),
              width: 16,
              height: 16,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Help Center',
            style: widget.theme.titleStyle.copyWith(fontSize: 18),
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
                            color: widget.theme.avatarIconColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            controller.faqSearchQuery.isEmpty
                                ? 'No articles found'
                                : 'No results for "${controller.faqSearchQuery}"',
                            style: widget.theme.subtitleStyle.copyWith(
                              fontSize: 16,
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
                      horizontal: 20,
                      vertical: 24,
                    ),
                    itemCount:
                        faqs.length + (controller.faqHasNextPage ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      color: widget.theme.surfaceColor,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search for articles...',
          hintStyle: widget.theme.subtitleStyle.copyWith(fontSize: 14),
          prefixIcon: Icon(
            Icons.search,
            color: widget.theme.subtitleStyle.color,
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: widget.theme.backgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
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
        boxShadow: [
          BoxShadow(
            color: widget.theme.cardShadowColor,
            blurRadius: 10,
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
            padding: const EdgeInsets.all(20),
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
                      widget.theme.subtitleStyle.color!,
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
                    style: widget.theme.titleStyle.copyWith(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 10),
                SvgPicture.asset(
                  'assets/icons/arrow-right.svg',
                  package: 'livechat_sdk',
                  colorFilter: ColorFilter.mode(
                    widget.theme.subtitleStyle.color!,
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
      backgroundColor: widget.theme.surfaceColor,
      appBar: AppBar(
        backgroundColor: widget.theme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/icons/arrow-left.svg',
            package: 'livechat_sdk',
            colorFilter: ColorFilter.mode(
              widget.theme.titleStyle.color!,
              BlendMode.srcIn,
            ),
            width: 16,
            height: 16,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Article',
          style: widget.theme.titleStyle.copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.faq.question,
              style: widget.theme.titleStyle.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 24),
            MarkdownBody(
              data: widget.faq.answer,
              styleSheet: MarkdownStyleSheet(
                p: widget.theme.bodyStyle.copyWith(height: 1.6),
                h1: widget.theme.titleStyle.copyWith(fontSize: 22),
                h2: widget.theme.titleStyle.copyWith(fontSize: 20),
                listBullet: widget.theme.bodyStyle,
              ),
            ),
            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 24),
            _buildFeedbackSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    if (_voted) {
      return Center(
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: widget.theme.resolvedTextColor,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              _isHelpful == true
                  ? 'Glad we could help!'
                  : "We'll work on improving this.",
              style: widget.theme.titleStyle.copyWith(fontSize: 16),
            ),
            if (_isHelpful == false) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Navigate to chat
                  Navigator.pop(context); // Back to list
                },
                child: Text(
                  'Start a conversation',
                  style: TextStyle(color: widget.theme.primaryColor),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        Center(
          child: Text('Was this helpful?', style: widget.theme.subtitleStyle),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFeedbackButton(Icons.thumb_up_outlined, 'Yes', true),
            const SizedBox(width: 20),
            _buildFeedbackButton(Icons.thumb_down_outlined, 'No', false),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedbackButton(IconData icon, String label, bool helpful) {
    return OutlinedButton.icon(
      onPressed: () => _handleVote(helpful),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: widget.theme.subtitleStyle.color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: widget.theme.avatarBackgroundColor),
      ),
    );
  }
}
