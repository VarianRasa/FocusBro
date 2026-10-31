import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfOutlineEntry {
  const PdfOutlineEntry({
    required this.title,
    required this.pageNumber,
    required this.level,
  });

  final String title;
  final int pageNumber;
  final int level;
}

class PdfOutlineService {
  const PdfOutlineService._();

  static List<PdfOutlineEntry> extract(List<int> sourceBytes) {
    final document = PdfDocument(inputBytes: sourceBytes);
    try {
      final result = <PdfOutlineEntry>[];
      _appendBookmarks(document, document.bookmarks, 0, result);
      return result;
    } finally {
      document.dispose();
    }
  }

  static void _appendBookmarks(
    PdfDocument document,
    PdfBookmarkBase bookmarks,
    int level,
    List<PdfOutlineEntry> result,
  ) {
    for (var index = 0; index < bookmarks.count; index++) {
      final bookmark = bookmarks[index];
      result.add(
        PdfOutlineEntry(
          title: bookmark.title.trim().isEmpty ? 'Untitled' : bookmark.title,
          pageNumber: _destinationPageNumber(document, bookmark),
          level: level,
        ),
      );
      _appendBookmarks(document, bookmark, level + 1, result);
    }
  }

  static int _destinationPageNumber(
    PdfDocument document,
    PdfBookmark bookmark,
  ) {
    final destination =
        bookmark.destination ?? bookmark.namedDestination?.destination;
    if (destination == null) return 1;

    final index = document.pages.indexOf(destination.page);
    return index < 0 ? 1 : index + 1;
  }
}
