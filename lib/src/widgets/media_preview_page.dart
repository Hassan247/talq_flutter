import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../core/utils/pdf_thumbnail_helper.dart';
import '../models/models.dart' as models;
import '../state/talq_controller.dart';

class MediaPreviewPage extends StatefulWidget {
  final File file;
  final models.ContentType contentType;

  const MediaPreviewPage({
    super.key,
    required this.file,
    required this.contentType,
  });

  @override
  State<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends State<MediaPreviewPage> {
  late final TextEditingController _captionController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSend() {
    final controller = context.read<TalqController>();
    controller.sendFile(
      widget.file.path,
      caption: _captionController.text.trim(),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TalqController>();
    final theme = controller.theme;
    final fileName = p.basename(widget.file.path);

    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Inter', package: 'talq_flutter'),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leadingWidth: 70,
          leading: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/icons/arrow-left.svg',
                  package: 'talq_flutter',
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  width: 20,
                  height: 20,
                ),
              ),
            ),
          ),
          title: Text(
            fileName,
            style: const TextStyle(
              fontFamily: 'Inter',
              package: 'talq_flutter',
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: widget.contentType == models.ContentType.image
                    ? Image.file(widget.file, fit: BoxFit.contain)
                    : FutureBuilder<PdfMetadata?>(
                        future: PdfThumbnailHelper.getMetadata(
                          widget.file.path,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator(
                              color: Colors.white,
                            );
                          }
                          final metadata = snapshot.data;
                          final thumbnail = metadata?.thumbnail;

                          final sizeStr = metadata != null
                              ? (metadata.fileSize < 1024 * 1024
                                    ? '${(metadata.fileSize / 1024).toStringAsFixed(1)} KB'
                                    : '${(metadata.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB')
                              : '';
                          final pagesStr = metadata != null
                              ? '${metadata.pageCount} ${metadata.pageCount == 1 ? 'page' : 'pages'}'
                              : '';

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (thumbnail != null)
                                Expanded(
                                  child: Image.file(
                                    thumbnail,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: SvgPicture.asset(
                                    'assets/icons/pdf.svg',
                                    package: 'talq_flutter',
                                    width: 64,
                                    height: 64,
                                    colorFilter: const ColorFilter.mode(
                                      Colors.white,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/icons/pdf.svg',
                                      package: 'talq_flutter',
                                      width: 20,
                                      height: 20,
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '$pagesStr • $sizeStr',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        package: 'talq_flutter',
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 40),
                            ],
                          );
                        },
                      ),
              ),
            ),

            // Caption area
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _captionController,
                        focusNode: _focusNode,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          package: 'talq_flutter',
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            package: 'talq_flutter',
                            color: Colors.white54,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        maxLines: 4,
                        minLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _onSend,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/send-message.svg',
                          package: 'talq_flutter',
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          width: 22,
                          height: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
