import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../livechat_client.dart';

class PdfMetadata {
  final File? thumbnail;
  final int pageCount;
  final int fileSize;

  PdfMetadata({
    required this.thumbnail,
    required this.pageCount,
    required this.fileSize,
  });

  Map<String, dynamic> toJson() => {
    'pageCount': pageCount,
    'fileSize': fileSize,
  };

  factory PdfMetadata.fromJson(Map<String, dynamic> json, File? thumbnail) {
    return PdfMetadata(
      thumbnail: thumbnail,
      pageCount: json['pageCount'] as int,
      fileSize: json['fileSize'] as int,
    );
  }
}

class PdfThumbnailHelper {
  static Future<PdfMetadata?> getMetadata(String filePathOrUrl) async {
    try {
      final isRemote =
          filePathOrUrl.startsWith('http://') ||
          filePathOrUrl.startsWith('https://');
      final tempDir = await getTemporaryDirectory();

      // lowercase comments: use a hash of the path/url as the cache key
      final hash = md5.convert(utf8.encode(filePathOrUrl)).toString();
      final cacheKey = 'pdf_cache_$hash';
      final thumbFile = File('${tempDir.path}/${cacheKey}_thumb.jpg');
      final metaFile = File('${tempDir.path}/${cacheKey}_meta.json');

      // lowercase comments: check cache first
      if (await thumbFile.exists() && await metaFile.exists()) {
        final metaJson = json.decode(await metaFile.readAsString());
        return PdfMetadata.fromJson(metaJson, thumbFile);
      }

      String localPath = filePathOrUrl;
      if (isRemote) {
        // lowercase comments: download remote file to temp location
        final downloadPath = '${tempDir.path}/${cacheKey}_download.pdf';
        final bytes = await LivechatClient.downloadBytes(filePathOrUrl);
        await File(downloadPath).writeAsBytes(bytes);
        localPath = downloadPath;
      }

      final file = File(localPath);
      if (!await file.exists()) return null;

      final fileSize = await file.length();
      final document = await PdfDocument.openFile(localPath);
      final pageCount = document.pagesCount;

      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.jpeg,
        quality: 80,
      );

      if (pageImage != null) {
        await thumbFile.writeAsBytes(pageImage.bytes);
      }

      final metadata = PdfMetadata(
        thumbnail: pageImage != null ? thumbFile : null,
        pageCount: pageCount,
        fileSize: fileSize,
      );

      // lowercase comments: save metadata to cache
      await metaFile.writeAsString(json.encode(metadata.toJson()));

      await page.close();
      await document.close();

      // lowercase comments: clean up downloaded file if it was remote
      if (isRemote) {
        try {
          await File(localPath).delete();
        } catch (e) {
          // ignore cleanup errors
        }
      }

      return metadata;
    } catch (e) {
      // ignore metadata errors
      return null;
    }
  }
}
