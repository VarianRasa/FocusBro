import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/pdf_edit_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('applies page edits without discarding the original PDF', () async {
    final source = PdfDocument();
    source.pages.add();
    source.pages.add();
    final sourceBytes = await source.save();
    source.dispose();

    final editedBytes = await PdfEditService.applyEdits(
      sourceBytes,
      [
        {
          'action': 'delete_pages',
          'data': {
            'pageNumbers': [1],
          },
        },
        {
          'action': 'add_blank_page',
          'data': {'pageNumber': 2},
        },
      ],
    );

    final edited = PdfDocument(inputBytes: editedBytes);
    expect(edited.pages.count, 2);
    edited.dispose();
  });

  test('keeps a valid page when every page is selected for deletion', () async {
    final source = PdfDocument();
    source.pages.add();
    final sourceBytes = await source.save();
    source.dispose();

    final editedBytes = await PdfEditService.applyEdits(
      sourceBytes,
      [
        {
          'action': 'delete_pages',
          'data': {
            'pageNumbers': [1],
          },
        },
      ],
    );

    final edited = PdfDocument(inputBytes: editedBytes);
    expect(edited.pages.count, 1);
    edited.dispose();
  });
}
