import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfEditService {
  const PdfEditService._();

  static Future<List<int>> applyEdits(
    List<int> sourceBytes,
    List<Map<String, dynamic>> edits,
  ) async {
    final document = PdfDocument(inputBytes: sourceBytes);

    try {
      for (final edit in edits) {
        final action = edit['action'] as String?;
        final data = Map<String, dynamic>.from(
          edit['data'] as Map? ?? const <String, dynamic>{},
        );

        switch (action) {
          case 'add_blank_page':
            document.pages.add();
            break;
          case 'delete_pages':
            _deletePages(document, data['pageNumbers']);
            break;
          case 'add_image':
            _addImage(document, data);
            break;
          case 'add_text':
            _addText(document, data);
            break;
        }
      }

      if (document.pages.count == 0) {
        document.pages.add();
      }
      return await document.save();
    } finally {
      document.dispose();
    }
  }

  static void _deletePages(PdfDocument document, dynamic pageNumbers) {
    final indexes = (pageNumbers as List? ?? const [])
        .whereType<num>()
        .map((number) => number.toInt() - 1)
        .where((index) => index >= 0 && index < document.pages.count)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    for (final index in indexes) {
      document.pages.removeAt(index);
    }
  }

  static void _addImage(PdfDocument document, Map<String, dynamic> data) {
    final bytes = _asBytes(data['imageBytes']);
    final page = _pageAt(document, data['pageNumber']);
    if (bytes == null || page == null) return;

    final pageSize = page.getClientSize();
    final image = PdfBitmap(bytes);
    page.graphics.drawImage(
      image,
      Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
    );
  }

  static void _addText(PdfDocument document, Map<String, dynamic> data) {
    final text = data['text']?.toString().trim() ?? '';
    final page = _pageAt(document, data['pageNumber']);
    if (text.isEmpty || page == null) return;

    final position = Map<String, dynamic>.from(
      data['position'] as Map? ?? const <String, dynamic>{},
    );
    final x = (position['x'] as num?)?.toDouble() ?? 0;
    final y = (position['y'] as num?)?.toDouble() ?? 0;
    final fontSize = (data['fontSize'] as num?)?.toDouble() ?? 12;
    final colorValue = (data['color'] as num?)?.toInt() ?? 0xFF000000;
    final pageSize = page.getClientSize();

    page.graphics.drawString(
      text,
      PdfStandardFont(PdfFontFamily.helvetica, fontSize),
      brush: PdfSolidBrush(
        PdfColor(
          (colorValue >> 16) & 0xFF,
          (colorValue >> 8) & 0xFF,
          colorValue & 0xFF,
        ),
      ),
      bounds: Rect.fromLTWH(
        x,
        y,
        (pageSize.width - x).clamp(1, pageSize.width),
        (pageSize.height - y).clamp(1, pageSize.height),
      ),
    );
  }

  static PdfPage? _pageAt(PdfDocument document, dynamic pageNumber) {
    if (document.pages.count == 0) return null;
    final index = ((pageNumber as num?)?.toInt() ?? 1) - 1;
    if (index < 0 || index >= document.pages.count) return null;
    return document.pages[index];
  }

  static Uint8List? _asBytes(dynamic value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    if (value is List) {
      return Uint8List.fromList(
          value.whereType<num>().map((e) => e.toInt()).toList());
    }
    return null;
  }
}
