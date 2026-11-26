
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:archive/archive.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;
import 'package:xml/xml.dart';

/// PDF and document conversion helpers.
///
/// Page-image operations rasterize pages and do not preserve selectable text.
/// Word/PDF and Excel/PDF conversions extract basic text/cells, not full layout.
/// PDF-to-PowerPoint creates image-based slides. editPdf overlays text.
class PdfEngineService {
  static Future<File> _outputFile(String prefix, String extension) async {
    final dir = await getTemporaryDirectory();
    return File(
      '${dir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
  }

  static Future<Uint8List> _readFile(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      throw Exception('Selected file does not exist: $path');
    }

    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception('Selected file is empty.');
    }

    return bytes;
  }

  static Future<List<Uint8List>> _renderPages(
      String filePath, {
        double dpi = 150,
      }) async {
    final bytes = await _readFile(filePath);
    final pages = <Uint8List>[];

    await for (final page in Printing.raster(bytes, dpi: dpi)) {
      pages.add(await page.toPng());
    }

    if (pages.isEmpty) {
      throw Exception('No pages found in this PDF.');
    }

    return pages;
  }

  static Future<Map<String, dynamic>> _createPdf(
      List<Uint8List> images,
      String prefix,
      ) async {
    if (images.isEmpty) {
      throw Exception('There are no pages to save.');
    }

    final pdf = pw.Document();

    for (final bytes in images) {
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw Exception('A page image could not be decoded.');
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(
            child: pw.Image(
              pw.MemoryImage(
                Uint8List.fromList(
                  img.encodeJpg(decoded, quality: 88),
                ),
              ),
              fit: pw.BoxFit.contain,
            ),
          ),
        ),
      );
    }

    final output = await _outputFile(prefix, 'pdf');

    await output.writeAsBytes(
      await pdf.save(),
      flush: true,
    );

    return {
      'file': output,
      'pageCount': images.length,
    };
  }

  static sf.PdfDocument _openPdf(Uint8List bytes) =>
      sf.PdfDocument(inputBytes: bytes);

  // 1. Merge PDFs.
  static Future<Map<String, dynamic>> mergePdfs(
      List<String> filePaths,
      ) async {
    if (filePaths.length < 2) {
      throw Exception('Please select at least two PDF files.');
    }

    final pages = <Uint8List>[];

    for (final path in filePaths) {
      pages.addAll(await _renderPages(path));
    }

    return _createPdf(pages, 'Merged_Document');
  }

  // 2. Split PDF by 1-based inclusive page range.
  static Future<Map<String, dynamic>> splitPdf(
      String filePath,
      int fromPage,
      int toPage,
      ) async {
    if (fromPage < 1 || toPage < fromPage) {
      throw Exception('Please enter a valid page range.');
    }

    final pages = await _renderPages(filePath);

    if (toPage > pages.length) {
      throw Exception('This PDF has only ${pages.length} pages.');
    }

    return _createPdf(
      pages.sublist(fromPage - 1, toPage),
      'Split_Document',
    );
  }

  // 3. Rearrange pages with zero-based indexes.
  static Future<Map<String, dynamic>> organizePdf(
      String filePath,
      List<int> pageOrder,
      ) async {
    final pages = await _renderPages(filePath);

    if (pageOrder.isEmpty) {
      throw Exception('Please provide a page order.');
    }

    for (final index in pageOrder) {
      if (index < 0 || index >= pages.length) {
        throw Exception('Invalid page number in the page order.');
      }
    }

    return _createPdf(
      pageOrder.map((i) => pages[i]).toList(),
      'Organized_Document',
    );
  }

  // 4. Rotate all pages.
  static Future<Map<String, dynamic>> rotatePdf(
      String filePath,
      int angle,
      ) async {
    if (![90, 180, 270].contains(angle)) {
      throw Exception('Rotation angle must be 90, 180 or 270.');
    }

    final rotated = <Uint8List>[];

    for (final bytes in await _renderPages(filePath)) {
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Could not read a PDF page image.');
      }

      rotated.add(
        Uint8List.fromList(
          img.encodePng(
            img.copyRotate(image, angle: angle),
          ),
        ),
      );
    }

    return _createPdf(rotated, 'Rotated_Document');
  }

  // 5. JPG/PNG to PDF with page size, orientation, image fit and margins.
  static Future<Map<String, dynamic>> jpgToPdf(
      List<String> imagePaths, {
        String pageSize = 'A4',
        String orientation = 'Portrait',
        String imageFit = 'Fit to Page',
        String margin = 'None',
      }) async {
    if (imagePaths.isEmpty) {
      throw Exception('Please select at least one image.');
    }

    PdfPageFormat getPageFormat(String size) {
      switch (size) {
        case 'A3':
          return PdfPageFormat.a3;
        case 'A5':
          return PdfPageFormat.a5;
        case 'Letter':
          return PdfPageFormat.letter;
        case 'Legal':
          return PdfPageFormat.legal;
        case 'A4':
        default:
          return PdfPageFormat.a4;
      }
    }

    double getMargin(String value) {
      switch (value) {
        case 'Small':
          return 18;
        case 'Medium':
          return 36;
        case 'Large':
          return 54;
        case 'None':
        default:
          return 0;
      }
    }

    pw.BoxFit getImageFit(String value) {
      switch (value) {
        case 'Fill Page':
          return pw.BoxFit.cover;
        case 'Fit to Image':
        case 'Original Size':
        case 'Fit to Page':
        default:
          return pw.BoxFit.contain;
      }
    }

    final pdf = pw.Document();
    final selectedMargin = getMargin(margin);

    for (final path in imagePaths) {
      final bytes = await _readFile(path);
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw Exception('Invalid image file: $path');
      }

      PdfPageFormat format;

      if (imageFit == 'Fit to Image' ||
          imageFit == 'Original Size') {
        final scale = imageFit == 'Original Size' ? 0.75 : 1.0;

        format = PdfPageFormat(
          decoded.width * scale + selectedMargin * 2,
          decoded.height * scale + selectedMargin * 2,
        );
      } else {
        format = getPageFormat(pageSize);

        if (orientation == 'Landscape') {
          format = format.landscape;
        } else {
          format = format.portrait;
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.all(selectedMargin),
          build: (_) {
            return pw.Center(
              child: pw.Image(
                pw.MemoryImage(bytes),
                fit: getImageFit(imageFit),
              ),
            );
          },
        ),
      );
    }

    final output = await _outputFile('Images_To_PDF', 'pdf');

    await output.writeAsBytes(
      await pdf.save(),
      flush: true,
    );

    return {
      'file': output,
      'pageCount': imagePaths.length,
    };
  }

  // 6. Add page numbers.
  static Future<Map<String, dynamic>> addPageNumbers(
      String filePath,
      String position,
      ) async {
    final pages = await _renderPages(filePath);
    final pdf = pw.Document();

    final alignment = position.contains('Top')
        ? (position.contains('Right')
        ? pw.Alignment.topRight
        : position.contains('Left')
        ? pw.Alignment.topLeft
        : pw.Alignment.topCenter)
        : (position.contains('Right')
        ? pw.Alignment.bottomRight
        : position.contains('Left')
        ? pw.Alignment.bottomLeft
        : pw.Alignment.bottomCenter);

    for (var i = 0; i < pages.length; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Stack(
            children: [
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(pages[i]),
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.Align(
                alignment: alignment,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(20),
                  child: pw.Text(
                    '${i + 1} / ${pages.length}',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final output = await _outputFile('Numbered_Document', 'pdf');

    await output.writeAsBytes(
      await pdf.save(),
      flush: true,
    );

    return {
      'file': output,
      'pageCount': pages.length,
    };
  }

  static String _escapeXml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static String _elementText(XmlElement e) =>
      e.descendants.whereType<XmlText>().map((t) => t.value).join();

  static void _addZipText(
      Archive archive,
      String name,
      String content,
      ) {
    final bytes = utf8.encode(content);

    archive.addFile(
      ArchiveFile(name, bytes.length, bytes),
    );
  }

  static List<int> _encodeZip(Archive archive) {
    final result = ZipEncoder().encode(archive);

    if (result.isEmpty) {
      throw Exception('Could not create Office document.');
    }

    return result;
  }

  // 7. PDF to Word (DOCX): selectable text extraction.
  static Future<Map<String, dynamic>> pdfToWord(
    String filePath, {
    String outputFormat = 'DOC',
    bool preserveFormatting = true,
    bool extractImages = true,
  }) async {
    final bytes = await _readFile(filePath);
    sf.PdfDocument? doc;

    try {
      doc = _openPdf(bytes);
      final count = doc.pages.count;

      if (count == 0) {
        throw Exception('No pages found in this PDF.');
      }

      final extractor = sf.PdfTextExtractor(doc);
      final texts = <String>[];

      for (var i = 0; i < count; i++) {
        texts.add(
          extractor.extractText(
            startPageIndex: i,
            endPageIndex: i,
          ),
        );
      }

      if (texts.join().trim().isEmpty) {
        throw Exception('No selectable text found. Try OCR first.');
      }

      final body = StringBuffer();

      for (var i = 0; i < texts.length; i++) {
        for (final line in texts[i].split(RegExp(r'\r?\n'))) {
          body.write(
            '<w:p><w:r><w:t xml:space="preserve">${_escapeXml(line)}</w:t></w:r></w:p>',
          );
        }

        if (i < texts.length - 1) {
          body.write(
            '<w:p><w:r><w:br w:type="page"/></w:r></w:p>',
          );
        }
      }

      final archive = Archive();

      _addZipText(
        archive,
        '[Content_Types].xml',
        '''
<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''',
      );

      _addZipText(
        archive,
        '_rels/.rels',
        '''
<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''',
      );

      _addZipText(
        archive,
        'word/document.xml',
        '''
<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body></w:document>''',
      );

      final output = await _outputFile('PDF_To_Word', 'docx');

      await output.writeAsBytes(
        _encodeZip(archive),
        flush: true,
      );

      return {
        'file': output,
        'pageCount': count,
      };
    } finally {
      doc?.dispose();
    }
  }

  // 8. Word (DOCX) to PDF.

  // 8. Word (DOCX) to PDF.
  // Supports basic paragraphs, headings, alignment and tables.
  // Legacy .doc files must be saved as .docx first.

  static Future<Map<String, dynamic>> wordToPdf(
      String filePath,
      ) async {
    final lowerPath = filePath.toLowerCase();

    if (lowerPath.endsWith('.doc') &&
        !lowerPath.endsWith('.docx')) {
      throw Exception(
        'Legacy .doc format is not supported. '
            'Please open the file in Word or WPS Office '
            'and save it as .docx.',
      );
    }

    if (!lowerPath.endsWith('.docx')) {
      throw Exception('Please select a valid DOCX file.');
    }

    try {
      final bytes = await _readFile(filePath);
      final archive = ZipDecoder().decodeBytes(bytes);

      final docFile = archive.findFile('word/document.xml');

      if (docFile == null) {
        throw Exception(
          'Invalid DOCX file. document.xml is missing.',
        );
      }

      final xml = XmlDocument.parse(
        utf8.decode(docFile.content as List<int>),
      );

      final body = xml.findAllElements('w:body').firstOrNull;

      if (body == null) {
        throw Exception('Invalid DOCX document body.');
      }

      final widgets = <pw.Widget>[];

      for (final node in body.children) {
        if (node is! XmlElement) continue;

        if (node.name.qualified == 'w:p') {
          final paragraphText = node
              .findAllElements('w:t')
              .map(_elementText)
              .join();

          final properties = node
              .findElements('w:pPr')
              .firstOrNull;

          final styleName = properties
              ?.findElements('w:pStyle')
              .firstOrNull
              ?.getAttribute('w:val') ?? '';

          final isHeading =
              styleName.toLowerCase().contains('heading') ||
                  styleName.toLowerCase().contains('title');

          final isBold = node.findAllElements('w:b').any(
                (element) => element.getAttribute('w:val') != '0',
          );

          final alignmentValue = properties
              ?.findElements('w:jc')
              .firstOrNull
              ?.getAttribute('w:val');

          final pw.TextAlign alignment;

          switch (alignmentValue) {
            case 'center':
              alignment = pw.TextAlign.center;
              break;
            case 'right':
              alignment = pw.TextAlign.right;
              break;
            case 'both':
              alignment = pw.TextAlign.justify;
              break;
            default:
              alignment = pw.TextAlign.left;
          }

          if (paragraphText.trim().isNotEmpty) {
            widgets.add(
              pw.Padding(
                padding: pw.EdgeInsets.only(
                  bottom: isHeading ? 10 : 6,
                ),
                child: pw.Text(
                  paragraphText,
                  textAlign: alignment,
                  style: pw.TextStyle(
                    fontSize: isHeading ? 16 : 11,
                    fontWeight: (isHeading || isBold)
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                    color: isHeading
                        ? PdfColors.deepPurple
                        : PdfColors.black,
                  ),
                ),
              ),
            );
          }
        } else if (node.name.qualified == 'w:tbl') {
          final tableRows = <List<String>>[];

          for (final tr in node.findElements('w:tr')) {
            final rowCells = <String>[];

            for (final tc in tr.findElements('w:tc')) {
              final cellText = tc
                  .findAllElements('w:t')
                  .map(_elementText)
                  .join()
                  .trim();

              rowCells.add(cellText);
            }

            if (rowCells.isNotEmpty) {
              tableRows.add(rowCells);
            }
          }

          if (tableRows.isNotEmpty) {
            final columnCount = tableRows
                .map((row) => row.length)
                .reduce((a, b) => a > b ? a : b);

            final normalizedRows = tableRows.map((row) {
              return List<String>.generate(
                columnCount,
                    (index) => index < row.length ? row[index] : '',
              );
            }).toList();

            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.TableHelper.fromTextArray(
                  data: normalizedRows,
                  border: pw.TableBorder.all(
                    color: PdfColors.grey500,
                    width: 0.5,
                  ),
                  headerStyle: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellPadding: const pw.EdgeInsets.all(5),
                ),
              ),
            );
          }
        }
      }

      if (widgets.isEmpty) {
        throw Exception(
          'No readable paragraphs or tables were found in this DOCX.',
        );
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (_) => widgets,
        ),
      );

      final output = await _outputFile('Word_To_PDF', 'pdf');

      final pdfBytes = await pdf.save();

      await output.writeAsBytes(
        pdfBytes,
        flush: true,
      );

      sf.PdfDocument? generatedPdf;

      try {
        generatedPdf = sf.PdfDocument(inputBytes: pdfBytes);

        return {
          'file': output,
          'pageCount': generatedPdf.pages.count,
        };
      } finally {
        generatedPdf?.dispose();
      }
    } catch (e) {
      throw Exception('Word to PDF conversion failed: $e');
    }
  }


  // Read basic values from the first XLSX worksheet.
  static List<List<String>> _readFirstWorksheet(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final workbookFile = archive.findFile('xl/workbook.xml');

    if (workbookFile == null) {
      throw Exception('Invalid Excel workbook.');
    }

    final workbook = XmlDocument.parse(
      utf8.decode(workbookFile.content as List<int>),
    );

    final firstSheet = workbook.findAllElements('sheet').firstOrNull;

    if (firstSheet == null) {
      throw Exception('Workbook has no worksheets.');
    }

    final rid = firstSheet.getAttribute('r:id');
    var sheetPath = 'xl/worksheets/sheet1.xml';

    final relFile = archive.findFile('xl/_rels/workbook.xml.rels');

    if (rid != null && relFile != null) {
      final rels = XmlDocument.parse(
        utf8.decode(relFile.content as List<int>),
      );

      for (final rel in rels.findAllElements('Relationship')) {
        if (rel.getAttribute('Id') == rid) {
          final target = rel.getAttribute('Target');

          if (target != null) {
            sheetPath = target.startsWith('/')
                ? target.substring(1)
                : (target.startsWith('xl/') ? target : 'xl/$target');
          }
        }
      }
    }

    final sheetFile = archive.findFile(sheetPath);

    if (sheetFile == null) {
      throw Exception('Could not read first worksheet.');
    }

    final shared = <String>[];
    final sharedFile = archive.findFile('xl/sharedStrings.xml');

    if (sharedFile != null) {
      final sst = XmlDocument.parse(
        utf8.decode(sharedFile.content as List<int>),
      );

      for (final si in sst.findAllElements('si')) {
        shared.add(
          si.findAllElements('t').map(_elementText).join(),
        );
      }
    }

    final sheet = XmlDocument.parse(
      utf8.decode(sheetFile.content as List<int>),
    );

    final rows = <int, Map<int, String>>{};

    for (final cell in sheet.findAllElements('c')) {
      final ref = cell.getAttribute('r') ?? '';
      final m = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(ref);

      if (m == null) continue;

      var col = 0;

      for (final unit in m.group(1)!.codeUnits) {
        col = col * 26 + unit - 64;
      }

      final row = int.parse(m.group(2)!) - 1;
      final type = cell.getAttribute('t');

      var value = cell.findElements('v').firstOrNull?.innerText ?? '';

      if (type == 's') {
        final index = int.tryParse(value);

        value = index != null && index >= 0 && index < shared.length
            ? shared[index]
            : '';
      } else if (type == 'inlineStr') {
        value = cell.findAllElements('t').map(_elementText).join();
      }

      rows.putIfAbsent(row, () => {})[col - 1] = value;
    }

    if (rows.isEmpty) {
      throw Exception('No cell data found in first worksheet.');
    }

    final maxRow = rows.keys.reduce((a, b) => a > b ? a : b);

    return List.generate(maxRow + 1, (r) {
      final row = rows[r] ?? <int, String>{};
      final maxCol =
      row.isEmpty ? -1 : row.keys.reduce((a, b) => a > b ? a : b);

      return List.generate(
        maxCol + 1,
            (c) => row[c] ?? '',
      );
    });
  }

  // 9. Excel (XLSX) to PDF.
  static Future<Map<String, dynamic>> excelToPdf(
      String filePath,
      ) async {
    final rows = _readFirstWorksheet(await _readFile(filePath));
    final headers = rows.first;
    final data = rows.length > 1 ? rows.sublist(1) : <List<String>>[];

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: headers.isEmpty ? ['Column 1'] : headers,
            data: data,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );

    final output = await _outputFile('Excel_To_PDF', 'pdf');

    await output.writeAsBytes(
      await pdf.save(),
      flush: true,
    );

    return {
      'file': output,
      'pageCount': 1,
    };
  }

  // 10. PDF to Excel: Coordinate-based multi-column table extraction.
  static Future<Map<String, dynamic>> pdfToExcel(
      String filePath,
      ) async {
    final bytes = await _readFile(filePath);
    sf.PdfDocument? doc;

    try {
      doc = _openPdf(bytes);
      final count = doc.pages.count;

      if (count == 0) {
        throw Exception('No pages found in this PDF.');
      }

      final extractor = sf.PdfTextExtractor(doc);
      final workbook = xls.Workbook();

      try {
        final sheet = workbook.worksheets[0];
        sheet.name = 'PDF Data';

        var excelRowIndex = 1;
        bool hasData = false;

        for (var p = 0; p < count; p++) {
          final lines = extractor.extractTextLines(
            startPageIndex: p,
            endPageIndex: p,
          );

          if (lines.isEmpty) continue;

          final List<_WordBox> words = [];

          for (final line in lines) {
            for (final word in line.wordCollection) {
              final t = word.text.trim();

              if (t.isNotEmpty) {
                words.add(
                  _WordBox(
                    text: t,
                    left: word.bounds.left,
                    top: word.bounds.top,
                    right: word.bounds.left + word.bounds.width,
                    height: word.bounds.height,
                  ),
                );
              }
            }
          }

          if (words.isEmpty) continue;

          words.sort((a, b) => a.top.compareTo(b.top));

          final List<List<_WordBox>> rowGroups = [];

          for (final word in words) {
            bool placed = false;

            for (final row in rowGroups) {
              final avgTop =
                  row.fold<double>(0.0, (sum, w) => sum + w.top) / row.length;

              if ((word.top - avgTop).abs() <= 6.0) {
                row.add(word);
                placed = true;
                break;
              }
            }

            if (!placed) {
              rowGroups.add([word]);
            }
          }

          rowGroups.sort(
                (a, b) => a.first.top.compareTo(b.first.top),
          );

          for (final row in rowGroups) {
            row.sort((a, b) => a.left.compareTo(b.left));

            final List<String> cellValues = [];
            final StringBuffer currentCell = StringBuffer();
            _WordBox? prevWord;

            for (final word in row) {
              if (prevWord == null) {
                currentCell.write(word.text);
              } else {
                final gap = word.left - prevWord.right;

                if (gap > 12.0) {
                  cellValues.add(currentCell.toString());
                  currentCell.clear();
                  currentCell.write(word.text);
                } else {
                  currentCell.write(' ');
                  currentCell.write(word.text);
                }
              }

              prevWord = word;
            }

            if (currentCell.isNotEmpty) {
              cellValues.add(currentCell.toString());
            }

            if (cellValues.isNotEmpty) {
              hasData = true;

              for (var c = 0; c < cellValues.length; c++) {
                final val = cellValues[c].trim();
                final range = sheet.getRangeByIndex(
                  excelRowIndex,
                  c + 1,
                );

                final numVal = double.tryParse(
                  val.replaceAll(',', ''),
                );

                if (numVal != null &&
                    !val.startsWith('0') &&
                    val.length < 12) {
                  range.setNumber(numVal);
                } else {
                  range.setText(val);
                }

                if (excelRowIndex == 1) {
                  range.cellStyle.bold = true;
                }
              }

              excelRowIndex++;
            }
          }
        }

        if (!hasData) {
          throw Exception(
            'No table or text data found in PDF. Try OCR first.',
          );
        }

        for (var c = 1; c <= 10; c++) {
          try {
            sheet.autoFitColumn(c);
          } catch (_) {}
        }

        final output = await _outputFile('PDF_To_Excel', 'xlsx');

        await output.writeAsBytes(
          workbook.saveAsStream(),
          flush: true,
        );

        return {
          'file': output,
          'pageCount': count,
        };
      } finally {
        workbook.dispose();
      }
    } finally {
      doc?.dispose();
    }
  }

  // 11. PDF to PowerPoint: each PDF page is converted to a PowerPoint slide.
  static Future<Map<String, dynamic>> pdfToPpt(
    String filePath, {
    bool preserveFormatting = true,
    bool onePagePerSlide = true,
    bool extractImages = true,
  }) async {
    final bytes = await _readFile(filePath);
    sf.PdfDocument? doc;

    try {
      doc = _openPdf(bytes);
      final count = doc.pages.count;

      if (count == 0) {
        throw Exception('No pages found in this PDF.');
      }

      final renderedPages = await _renderPages(
        filePath,
        dpi: 200,
      );

      if (renderedPages.length != count) {
        throw Exception('Could not render all PDF pages.');
      }

      final decodedPages = <img.Image>[];

      for (final pageBytes in renderedPages) {
        final decoded = img.decodeImage(pageBytes);

        if (decoded == null) {
          throw Exception('Could not decode a PDF page image.');
        }

        decodedPages.add(decoded);
      }

      const int maxSlideWidth = 9144000;
      const int maxSlideHeight = 5143500;

      final firstPage = decodedPages.first;
      final aspectRatio = firstPage.width / firstPage.height;

      late final int slideWidth;
      late final int slideHeight;

      if (aspectRatio >= maxSlideWidth / maxSlideHeight) {
        slideWidth = maxSlideWidth;
        slideHeight = (maxSlideWidth / aspectRatio).round();
      } else {
        slideHeight = maxSlideHeight;
        slideWidth = (maxSlideHeight * aspectRatio).round();
      }

      final archive = Archive();

      const rel =
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

      final slideIds = StringBuffer();
      final presentationRels = StringBuffer();
      final contentOverrides = StringBuffer();

      _addZipText(
        archive,
        '_rels/.rels',
        '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="$rel/officeDocument" Target="ppt/presentation.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="$rel/extended-properties" Target="docProps/app.xml"/>
</Relationships>
''',
      );

      _addZipText(
        archive,
        'docProps/core.xml',
        '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <dc:title>PDF to PowerPoint</dc:title>
  <dc:creator>My Docverter</dc:creator>
  <cp:lastModifiedBy>My Docverter</cp:lastModifiedBy>
</cp:coreProperties>
''',
      );

      _addZipText(
        archive,
        'docProps/app.xml',
        '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
  <Application>My Docverter</Application>
  <PresentationFormat>On-screen Show (16:9)</PresentationFormat>
  <Slides>$count</Slides>
</Properties>
''',
      );

      for (var i = 0; i < count; i++) {
        final n = i + 1;
        final slideRelId = 'rId${i + 2}';
        final image = decodedPages[i];

        slideIds.write(
          '<p:sldId id="${255 + n}" r:id="$slideRelId"/>',
        );

        presentationRels.write('''
<Relationship Id="$slideRelId" Type="$rel/slide" Target="slides/slide$n.xml"/>
''');

        contentOverrides.write('''
<Override PartName="/ppt/slides/slide$n.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
''');

        final pageRatio = image.width / image.height;
        final slideRatio = slideWidth / slideHeight;

        late final int imageWidth;
        late final int imageHeight;
        late final int imageLeft;
        late final int imageTop;

        if (pageRatio >= slideRatio) {
          imageWidth = slideWidth;
          imageHeight = (slideWidth / pageRatio).round();
          imageLeft = 0;
          imageTop = ((slideHeight - imageHeight) / 2).round();
        } else {
          imageHeight = slideHeight;
          imageWidth = (slideHeight * pageRatio).round();
          imageLeft = ((slideWidth - imageWidth) / 2).round();
          imageTop = 0;
        }

        final imageName = 'image$n.png';
        final imageBytes = renderedPages[i];

        archive.addFile(
          ArchiveFile(
            'ppt/media/$imageName',
            imageBytes.length,
            imageBytes,
          ),
        );

        _addZipText(
          archive,
          'ppt/slides/_rels/slide$n.xml.rels',
          '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="$rel/image" Target="../media/$imageName"/>
  <Relationship Id="rId2" Type="$rel/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>
''',
        );

        _addZipText(
          archive,
          'ppt/slides/slide$n.xml',
          '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="$rel" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:bg>
      <p:bgPr>
        <a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill>
        <a:effectLst/>
      </p:bgPr>
    </p:bg>
    <p:spTree>
      <p:nvGrpSpPr>
        <p:cNvPr id="1" name=""/>
        <p:cNvGrpSpPr/>
        <p:nvPr/>
      </p:nvGrpSpPr>
      <p:grpSpPr>
        <a:xfrm>
          <a:off x="0" y="0"/>
          <a:ext cx="0" cy="0"/>
          <a:chOff x="0" y="0"/>
          <a:chExt cx="0" cy="0"/>
        </a:xfrm>
      </p:grpSpPr>
      <p:pic>
        <p:nvPicPr>
          <p:cNvPr id="2" name="PDF Page $n"/>
          <p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>
          <p:nvPr/>
        </p:nvPicPr>
        <p:blipFill>
          <a:blip r:embed="rId1"/>
          <a:stretch><a:fillRect/></a:stretch>
        </p:blipFill>
        <p:spPr>
          <a:xfrm>
            <a:off x="$imageLeft" y="$imageTop"/>
            <a:ext cx="$imageWidth" cy="$imageHeight"/>
          </a:xfrm>
          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </p:spPr>
      </p:pic>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sld>
''',
        );
      }

      _addZipText(
        archive,
        '[Content_Types].xml',
        '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
  $contentOverrides
</Types>
''',
      );

      _addZipText(
        archive,
        'ppt/presentation.xml',
        '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="$rel" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
  <p:sldIdLst>$slideIds</p:sldIdLst>
  <p:sldSz cx="$slideWidth" cy="$slideHeight" type="custom"/>
  <p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>
''',
      );

      _addZipText(
        archive,
        'ppt/_rels/presentation.xml.rels',
        '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="$rel/slideMaster" Target="slideMasters/slideMaster1.xml"/>
  $presentationRels
</Relationships>
''',
      );

      _addZipText(
        archive,
        'ppt/slideMasters/slideMaster1.xml',
        '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="$rel" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr>
        <a:xfrm>
          <a:off x="0" y="0"/>
          <a:ext cx="0" cy="0"/>
          <a:chOff x="0" y="0"/>
          <a:chExt cx="0" cy="0"/>
        </a:xfrm>
      </p:grpSpPr>
    </p:spTree>
  </p:cSld>
  <p:clrMap accent1="4F81BD" accent2="C0504D" accent3="9BBB59" accent4="8064A2" accent5="4BACC6" accent6="F79646" bg1="lt1" bg2="lt2" tx1="dk1" tx2="dk2" hlink="blue" folHlink="purple"/>
  <p:sldLayoutIdLst><p:sldLayoutId id="1" r:id="rId1"/></p:sldLayoutIdLst>
  <p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles>
</p:sldMaster>
''',
      );

      _addZipText(
        archive,
        'ppt/slideMasters/_rels/slideMaster1.xml.rels',
        '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="$rel/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
  <Relationship Id="rId2" Type="$rel/theme" Target="../theme/theme1.xml"/>
</Relationships>
''',
      );

      _addZipText(
        archive,
        'ppt/slideLayouts/slideLayout1.xml',
        '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="$rel" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">
  <p:cSld name="Blank">
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr>
        <a:xfrm>
          <a:off x="0" y="0"/>
          <a:ext cx="0" cy="0"/>
          <a:chOff x="0" y="0"/>
          <a:chExt cx="0" cy="0"/>
        </a:xfrm>
      </p:grpSpPr>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sldLayout>
''',
      );

      _addZipText(
        archive,
        'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
        '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="$rel/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>
''',
      );

      _addZipText(
        archive,
        'ppt/theme/theme1.xml',
        '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="My Docverter">
  <a:themeElements>
    <a:clrScheme name="Office">
      <a:dk1><a:srgbClr val="000000"/></a:dk1>
      <a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="1F497D"/></a:dk2>
      <a:lt2><a:srgbClr val="EEECE1"/></a:lt2>
      <a:accent1><a:srgbClr val="4F81BD"/></a:accent1>
      <a:accent2><a:srgbClr val="C0504D"/></a:accent2>
      <a:accent3><a:srgbClr val="9BBB59"/></a:accent3>
      <a:accent4><a:srgbClr val="8064A2"/></a:accent4>
      <a:accent5><a:srgbClr val="4BACC6"/></a:accent5>
      <a:accent6><a:srgbClr val="F79646"/></a:accent6>
      <a:hlink><a:srgbClr val="0000FF"/></a:hlink>
      <a:folHlink><a:srgbClr val="800080"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="Office">
      <a:majorFont><a:latin typeface="Arial"/></a:majorFont>
      <a:minorFont><a:latin typeface="Arial"/></a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name="Office">
      <a:fillStyleLst>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:gradFill rotWithShape="1">
          <a:gsLst>
            <a:gs pos="0"><a:schemeClr val="phClr"/></a:gs>
            <a:gs pos="100000"><a:schemeClr val="phClr"/></a:gs>
          </a:gsLst>
          <a:lin ang="5400000" scaled="1"/>
        </a:gradFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
      </a:fillStyleLst>
      <a:lnStyleLst>
        <a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
        <a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
        <a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
      </a:lnStyleLst>
      <a:effectStyleLst>
        <a:effectStyle><a:effectLst/></a:effectStyle>
        <a:effectStyle><a:effectLst/></a:effectStyle>
        <a:effectStyle><a:effectLst/></a:effectStyle>
      </a:effectStyleLst>
      <a:bgFillStyleLst>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
      </a:bgFillStyleLst>
    </a:fmtScheme>
  </a:themeElements>
</a:theme>
''',
      );

      final output = await _outputFile(
        'PDF_To_PowerPoint',
        'pptx',
      );

      await output.writeAsBytes(
        _encodeZip(archive),
        flush: true,
      );

      return {
        'file': output,
        'pageCount': count,
      };
    } finally {
      doc?.dispose();
    }
  }

  // 12. Protect PDF.
  static Future<Map<String, dynamic>> protectPdf(
      String filePath,
      String password,
      ) async {
    if (password.trim().length < 4) {
      throw Exception('Password must contain at least 4 characters.');
    }

    sf.PdfDocument? doc;

    try {
      doc = _openPdf(await _readFile(filePath));
      final count = doc.pages.count;

      if (count == 0) {
        throw Exception('No pages found in this PDF.');
      }

      doc.security
        ..userPassword = password
        ..ownerPassword = password
        ..algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;

      final output = await _outputFile('Protected_Document', 'pdf');

      await output.writeAsBytes(
        await doc.save(),
        flush: true,
      );

      return {
        'file': output,
        'pageCount': count,
      };
    } finally {
      doc?.dispose();
    }
  }

  // 13. Unlock PDF with the correct password.
  static Future<Map<String, dynamic>> unlockPdf(
      String filePath,
      String password,
      ) async {
    if (password.isEmpty) {
      throw Exception('Please enter the PDF password.');
    }

    sf.PdfDocument? doc;

    try {
      doc = sf.PdfDocument(
        inputBytes: await _readFile(filePath),
        password: password,
      );

      final count = doc.pages.count;

      if (count == 0) {
        throw Exception('No pages found in this PDF.');
      }

      doc.security
        ..userPassword = ''
        ..ownerPassword = '';

      doc.security.permissions.clear();

      final output = await _outputFile('Unlocked_Document', 'pdf');

      await output.writeAsBytes(
        await doc.save(),
        flush: true,
      );

      return {
        'file': output,
        'pageCount': count,
      };
    } finally {
      doc?.dispose();
    }
  }

  // 14. Watermark every page.
  static Future<Map<String, dynamic>> watermarkPdf(
      String filePath,
      String text,
      double opacity,
      ) async {
    if (text.trim().isEmpty) {
      throw Exception('Please enter watermark text.');
    }

    if (opacity < 0 || opacity > 1) {
      throw Exception('Opacity must be between 0 and 1.');
    }

    sf.PdfDocument? doc;

    try {
      doc = _openPdf(await _readFile(filePath));
      final count = doc.pages.count;

      if (count == 0) {
        throw Exception('No pages found in this PDF.');
      }

      final font = sf.PdfStandardFont(
        sf.PdfFontFamily.helvetica,
        30,
        style: sf.PdfFontStyle.bold,
      );

      for (var i = 0; i < count; i++) {
        final page = doc.pages[i];
        final size = page.getClientSize();
        final state = page.graphics.save();

        page.graphics.setTransparency(1 - opacity);

        page.graphics.drawString(
          text.trim(),
          font,
          brush: sf.PdfBrushes.gray,
          bounds: Rect.fromLTWH(
            0,
            (size.height - 60) / 2,
            size.width,
            60,
          ),
          format: sf.PdfStringFormat(
            alignment: sf.PdfTextAlignment.center,
            lineAlignment: sf.PdfVerticalAlignment.middle,
          ),
        );

        page.graphics.restore(state);
      }

      final output = await _outputFile('Watermarked_Document', 'pdf');

      await output.writeAsBytes(
        await doc.save(),
        flush: true,
      );

      return {
        'file': output,
        'pageCount': count,
      };
    } finally {
      doc?.dispose();
    }
  }

  // 15. Compress by rasterizing at lower DPI/quality.
  static Future<Map<String, dynamic>> compressPdf(
      String filePath,
      String level,
      ) async {
    final bytes = await _readFile(filePath);
    final normalized = level.toLowerCase().trim();

    final int dpi;
    final int quality;

    switch (normalized) {
      case 'low':
        dpi = 150;
        quality = 85;
        break;
      case 'medium':
        dpi = 120;
        quality = 70;
        break;
      case 'high':
        dpi = 90;
        quality = 55;
        break;
      default:
        throw Exception('Please select a valid compression level.');
    }

    final pages = <Uint8List>[];

    await for (final page in Printing.raster(
      bytes,
      dpi: dpi.toDouble(),
    )) {
      final decoded = img.decodeImage(await page.toPng());

      if (decoded == null) {
        throw Exception('Could not process a PDF page.');
      }

      pages.add(
        Uint8List.fromList(
          img.encodeJpg(decoded, quality: quality),
        ),
      );
    }

    final result = await _createPdf(
      pages,
      'Compressed_Document',
    );

    final output = result['file'] as File;

    return {
      ...result,
      'originalSize': bytes.length,
      'compressedSize': await output.length(),
      'compressionLevel': normalized,
    };
  }

  // 16. OCR scanned PDF pages.
  static Future<Map<String, dynamic>> ocrPdf(
      String filePath,
      ) async {
    final bytes = await _readFile(filePath);
    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    final extracted = StringBuffer();
    var count = 0;

    try {
      await for (final page in Printing.raster(
        bytes,
        dpi: 200,
      )) {
        count++;

        final temp = await _outputFile('ocr_page', 'png');

        await temp.writeAsBytes(
          await page.toPng(),
          flush: true,
        );

        try {
          final result = await recognizer.processImage(
            InputImage.fromFilePath(temp.path),
          );

          extracted.writeln(result.text);
          extracted.writeln('\n--------------------\n');
        } finally {
          if (await temp.exists()) {
            await temp.delete();
          }
        }
      }

      final text = extracted.toString().trim();

      if (count == 0 || text.isEmpty) {
        throw Exception('No readable text found in this PDF.');
      }

      final output = await _outputFile('OCR_Result', 'txt');

      await output.writeAsString(
        text,
        flush: true,
      );

      return {
        'file': output,
        'pageCount': count,
        'extractedText': text,
      };
    } finally {
      await recognizer.close();
    }
  }

  // 17. Repair by rebuilding pages that can still be rendered.
  static Future<Map<String, dynamic>> repairPdf(
      String filePath,
      ) async {
    await _readFile(filePath);

    try {
      final pages = await _renderPages(filePath);

      if (pages.isEmpty) {
        throw Exception('No recoverable pages found.');
      }

      return await _createPdf(
        pages,
        'Repaired_Document',
      );
    } catch (e) {
      throw Exception(
        'Could not repair this PDF. It may be severely damaged. Details: $e',
      );
    }
  }

  // 18. Add text overlay to each page.
  static Future<Map<String, dynamic>> editPdf(
      String filePath,
      String text,
      ) async {
    if (text.trim().isEmpty) {
      throw Exception('Please enter text to add to the PDF.');
    }

    sf.PdfDocument? doc;

    try {
      doc = _openPdf(await _readFile(filePath));
      final count = doc.pages.count;

      if (count == 0) {
        throw Exception('No pages found in this PDF.');
      }

      final font = sf.PdfStandardFont(
        sf.PdfFontFamily.helvetica,
        16,
      );

      for (var i = 0; i < count; i++) {
        final page = doc.pages[i];
        final size = page.getClientSize();

        page.graphics.drawString(
          text.trim(),
          font,
          brush: sf.PdfBrushes.black,
          bounds: Rect.fromLTWH(
            30,
            30,
            size.width - 60,
            50,
          ),
        );
      }

      final output = await _outputFile('Edited_Document', 'pdf');

      await output.writeAsBytes(
        await doc.save(),
        flush: true,
      );

      return {
        'file': output,
        'pageCount': count,
      };
    } finally {
      doc?.dispose();
    }
  }
}

class _WordBox {
  final String text;
  final double left;
  final double top;
  final double right;
  final double height;

  _WordBox({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.height,
  });
}
