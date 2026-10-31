import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/pdf_outline_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('extracts real nested PDF bookmarks with destination pages', () async {
    final document = PdfDocument();
    final firstPage = document.pages.add();
    final secondPage = document.pages.add();
    final intro = document.bookmarks.add('Introduction');
    intro.destination = PdfDestination(firstPage);
    final chapter = document.bookmarks.add('Chapter');
    chapter.destination = PdfDestination(secondPage);
    final nested = chapter.add('Nested topic');
    nested.destination = PdfDestination(secondPage);
    final bytes = await document.save();
    document.dispose();

    final outline = PdfOutlineService.extract(bytes);

    expect(outline.map((entry) => entry.title),
        ['Introduction', 'Chapter', 'Nested topic']);
    expect(outline.map((entry) => entry.pageNumber), [1, 2, 2]);
    expect(outline.map((entry) => entry.level), [0, 0, 1]);
  });

  test('returns no synthetic outline for a PDF without bookmarks', () async {
    final document = PdfDocument();
    document.pages.add();
    final bytes = await document.save();
    document.dispose();

    expect(PdfOutlineService.extract(bytes), isEmpty);
  });
}
