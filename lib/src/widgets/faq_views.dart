import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/livechat_controller.dart';

class FAQListView extends StatelessWidget {
  final Color primaryColor;

  const FAQListView({super.key, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Help Center',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<LivechatController>(
        builder: (context, controller, _) {
          final faqs = controller.faqs;

          if (faqs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.help_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No articles found',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: faqs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final faq = faqs[index];
              return _buildFAQCard(context, faq);
            },
          );
        },
      ),
    );
  }

  Widget _buildFAQCard(BuildContext context, LivechatFAQ faq) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                builder: (_) =>
                    FAQDetailView(faq: faq, primaryColor: primaryColor),
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
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF475569),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    faq.question,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
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
  final Color primaryColor;

  const FAQDetailView({
    super.key,
    required this.faq,
    required this.primaryColor,
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Article',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
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
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            MarkdownBody(
              data: widget.faq.answer,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.black87,
                ),
                h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                listBullet: const TextStyle(fontSize: 16),
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
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              _isHelpful == true
                  ? 'Glad we could help!'
                  : "We'll work on improving this.",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            if (_isHelpful == false) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Navigate to chat
                  Navigator.pop(context); // Back to list
                  // In a real app we might trigger a chat open here
                },
                child: Text(
                  'Start a conversation',
                  style: TextStyle(color: widget.primaryColor),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        const Center(
          child: Text(
            'Was this helpful?',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
          ),
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
        foregroundColor: Colors.grey[700],
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.grey[200]!),
      ),
    );
  }
}
