import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../core/talq_client.dart';
import '../models/models.dart';

class MediaViewerPage extends StatefulWidget {
  final String? url;
  final String? localPath;
  final ContentType contentType;
  final String fileName;

  const MediaViewerPage({
    super.key,
    this.url,
    this.localPath,
    required this.contentType,
    required this.fileName,
  });

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  PdfControllerPinch? _pdfController;
  File? _tempPdfFile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.contentType == ContentType.pdf) {
      _initPdf();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _initPdf() async {
    try {
      if (widget.localPath != null && File(widget.localPath!).existsSync()) {
        _pdfController = PdfControllerPinch(
          document: PdfDocument.openFile(widget.localPath!),
        );
      } else if (widget.url != null) {
        final tempDir = await getTemporaryDirectory();
        final fileName = widget.url!.split('/').last;
        _tempPdfFile = File('${tempDir.path}/view_$fileName');

        if (!await _tempPdfFile!.exists()) {
          final bytes = await TalqClient.downloadBytes(widget.url!);
          await _tempPdfFile!.writeAsBytes(bytes);
        }

        _pdfController = PdfControllerPinch(
          document: PdfDocument.openFile(_tempPdfFile!.path),
        );
      } else {
        throw Exception('No source for PDF');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Inter', package: 'talq_flutter'),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black.withValues(alpha: 0.5),
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
            widget.fileName,
            style: const TextStyle(
              fontFamily: 'Inter',
              package: 'talq_flutter',
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error: $_error',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  package: 'talq_flutter',
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (widget.contentType == ContentType.image) {
      return Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child:
              widget.localPath != null && File(widget.localPath!).existsSync()
              ? Image.file(File(widget.localPath!), fit: BoxFit.contain)
              : CachedNetworkImage(
                  imageUrl: widget.url!,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
        ),
      );
    }

    if (widget.contentType == ContentType.pdf && _pdfController != null) {
      return PdfViewPinch(
        controller: _pdfController!,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      );
    }

    return const Center(
      child: Text(
        'Format not supported',
        style: TextStyle(
          fontFamily: 'Inter',
          package: 'talq_flutter',
          color: Colors.white,
        ),
      ),
    );
  }
}
