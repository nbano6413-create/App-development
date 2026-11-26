
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/file_storage_service.dart';
import 'tool_result_screen.dart';

enum AnnotationType { text, image, draw, highlight }

class AnnotationItem {
  final String id;
  final int pageIndex;
  final AnnotationType type;
  Offset position;
  Size size;
  String text;
  bool isBold;
  bool isItalic;
  double fontSize;
  Color color;
  Uint8List? imageBytes;
  List<Offset> drawPoints;
  double strokeWidth;

  AnnotationItem({
    required this.id,
    required this.pageIndex,
    required this.type,
    required this.position,
    this.size = const Size(140, 40),
    this.text = '',
    this.isBold = false,
    this.isItalic = false,
    this.fontSize = 18,
    this.color = Colors.black,
    this.imageBytes,
    List<Offset>? drawPoints,
    this.strokeWidth = 3,
  }) : drawPoints = drawPoints ?? [];

  AnnotationItem copy() {
    return AnnotationItem(
      id: id,
      pageIndex: pageIndex,
      type: type,
      position: position,
      size: size,
      text: text,
      isBold: isBold,
      isItalic: isItalic,
      fontSize: fontSize,
      color: color,
      imageBytes: imageBytes,
      drawPoints: List<Offset>.from(drawPoints),
      strokeWidth: strokeWidth,
    );
  }
}

class PdfEditorScreen extends StatefulWidget {
  final String filePath;

  const PdfEditorScreen({
    super.key,
    required this.filePath,
  });

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  late Future<List<Uint8List>> _pagesFuture;

  List<Uint8List> _renderedImages = [];

  String _selectedTool = 'Select';

  // Annotations
  List<AnnotationItem> _annotations = [];
  final List<List<AnnotationItem>> _historyStack = [[]];
  int _historyIndex = 0;

  String? _selectedAnnotationId;
  AnnotationItem? _currentDrawItem;

  // Text settings
  final TextEditingController _textController = TextEditingController();

  bool _isBold = false;
  bool _isItalic = false;

  double _textSize = 18;
  Color _selectedTextColor = Colors.black;

  // Drawing settings
  Color _drawColor = Colors.red;
  double _drawWidth = 4;

  // Highlight settings
  Color _highlightColor = Colors.yellow;

  @override
  void initState() {
    super.initState();
    _pagesFuture = _loadPdfPages();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // LOAD PDF
  // --------------------------------------------------

  Future<List<Uint8List>> _loadPdfPages() async {
    final file = File(widget.filePath);

    if (!await file.exists()) {
      throw Exception('PDF file does not exist.');
    }

    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception('Selected PDF file is empty.');
    }

    if (bytes.length < 5 ||
        !(bytes[0] == 0x25 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x44 &&
            bytes[3] == 0x46 &&
            bytes[4] == 0x2D)) {
      throw Exception('Selected file is not a valid PDF.');
    }

    final List<Uint8List> images = [];

    await for (final page in Printing.raster(bytes, dpi: 120)) {
      images.add(await page.toPng());
    }

    if (images.isEmpty) {
      throw Exception('Unable to render PDF pages.');
    }

    _renderedImages = images;

    return images;
  }

  // --------------------------------------------------
  // UNDO / REDO
  // --------------------------------------------------

  void _pushHistoryState() {
    if (_historyIndex < _historyStack.length - 1) {
      _historyStack.removeRange(
        _historyIndex + 1,
        _historyStack.length,
      );
    }

    _historyStack.add(
      _annotations.map((a) => a.copy()).toList(),
    );

    _historyIndex = _historyStack.length - 1;
  }

  void _undo() {
    if (_historyIndex <= 0) return;

    setState(() {
      _historyIndex--;

      _annotations = _historyStack[_historyIndex]
          .map((a) => a.copy())
          .toList();

      _selectedAnnotationId = null;
    });
  }

  void _redo() {
    if (_historyIndex >= _historyStack.length - 1) return;

    setState(() {
      _historyIndex++;

      _annotations = _historyStack[_historyIndex]
          .map((a) => a.copy())
          .toList();

      _selectedAnnotationId = null;
    });
  }

  // --------------------------------------------------
  // SELECT TOOL
  // --------------------------------------------------

  void _selectTool(String tool) {
    setState(() {
      _selectedTool = tool;
      _selectedAnnotationId = null;
    });

    if (tool == 'Add Image') {
      _pickImageAndPrepare();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$tool mode selected'),
          duration: const Duration(milliseconds: 800),
          backgroundColor: Colors.deepPurple,
        ),
      );
    }
  }

  // --------------------------------------------------
  // PAGE TAP / SELECT ANNOTATION
  // --------------------------------------------------

  void _handlePageTap(int pageIndex, Offset localPos) {
    if (_selectedTool == 'Add Text') {
      _showAddTextDialog(pageIndex, localPos);
      return;
    }

    if (_selectedTool == 'Highlight') {
      _addHighlightAnnotation(pageIndex, localPos);
      return;
    }

    if (_selectedTool == 'Select') {
      AnnotationItem? found;

      for (final ann in _annotations.reversed) {
        if (ann.pageIndex != pageIndex) continue;

        Rect rect;

        if (ann.type == AnnotationType.draw &&
            ann.drawPoints.isNotEmpty) {
          final xs = ann.drawPoints.map((p) => p.dx);
          final ys = ann.drawPoints.map((p) => p.dy);

          final minX = xs.reduce((a, b) => a < b ? a : b);
          final maxX = xs.reduce((a, b) => a > b ? a : b);
          final minY = ys.reduce((a, b) => a < b ? a : b);
          final maxY = ys.reduce((a, b) => a > b ? a : b);

          rect = Rect.fromLTRB(
            minX - 10,
            minY - 10,
            maxX + 10,
            maxY + 10,
          );
        } else {
          rect = Rect.fromLTWH(
            ann.position.dx,
            ann.position.dy,
            ann.size.width,
            ann.size.height,
          );
        }

        if (rect.contains(localPos)) {
          found = ann;
          break;
        }
      }

      setState(() {
        _selectedAnnotationId = found?.id;
      });
    }
  }

  // --------------------------------------------------
  // DRAW TOOL
  // --------------------------------------------------

  void _handlePanStart(int pageIndex, Offset localPos) {
    if (_selectedTool != 'Draw') return;

    final newItem = AnnotationItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      pageIndex: pageIndex,
      type: AnnotationType.draw,
      position: Offset.zero,
      color: _drawColor,
      strokeWidth: _drawWidth,
      drawPoints: [localPos],
    );

    setState(() {
      _currentDrawItem = newItem;
      _annotations.add(newItem);
    });
  }

  void _handlePanUpdate(int pageIndex, Offset localPos) {
    if (_selectedTool != 'Draw' || _currentDrawItem == null) {
      return;
    }

    setState(() {
      _currentDrawItem!.drawPoints.add(localPos);
    });
  }

  void _handlePanEnd(int pageIndex) {
    if (_selectedTool == 'Draw' && _currentDrawItem != null) {
      _currentDrawItem = null;
      _pushHistoryState();
    }
  }

  // --------------------------------------------------
  // ADD / EDIT TEXT
  // --------------------------------------------------

  void _showAddTextDialog(
      int pageIndex,
      Offset tapPos, {
        AnnotationItem? existingItem,
      }) {
    if (existingItem != null) {
      _textController.text = existingItem.text;
      _isBold = existingItem.isBold;
      _isItalic = existingItem.isItalic;
      _textSize = existingItem.fontSize;
      _selectedTextColor = existingItem.color;
    } else {
      _textController.clear();
      _isBold = false;
      _isItalic = false;
      _textSize = 18;
      _selectedTextColor = Colors.black;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              existingItem != null ? 'Edit Text' : 'Add Text',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _textController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter text',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setDialogState(() {
                              _isBold = !_isBold;
                            });
                          },
                          child: const Text(
                            'BOLD',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setDialogState(() {
                              _isItalic = !_isItalic;
                            });
                          },
                          child: const Text(
                            'ITALIC',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Text Size',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  Slider(
                    value: _textSize,
                    min: 10,
                    max: 40,
                    activeColor: Colors.deepPurple,
                    onChanged: (value) {
                      setDialogState(() {
                        _textSize = value;
                      });
                    },
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Text Color',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _textColorCircle(Colors.black, setDialogState),
                      _textColorCircle(Colors.red, setDialogState),
                      _textColorCircle(Colors.blue, setDialogState),
                      _textColorCircle(Colors.green, setDialogState),
                      _textColorCircle(Colors.orange, setDialogState),
                      _textColorCircle(
                        Colors.white,
                        setDialogState,
                        hasBorder: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final txt = _textController.text.trim();

                  if (txt.isEmpty) return;

                  setState(() {
                    if (existingItem != null) {
                      // Save old state before editing.
                      _pushHistoryState();

                      existingItem.text = txt;
                      existingItem.isBold = _isBold;
                      existingItem.isItalic = _isItalic;
                      existingItem.fontSize = _textSize;
                      existingItem.color = _selectedTextColor;
                    } else {
                      _annotations.add(
                        AnnotationItem(
                          id: DateTime.now()
                              .microsecondsSinceEpoch
                              .toString(),
                          pageIndex: pageIndex,
                          type: AnnotationType.text,
                          position: tapPos,
                          text: txt,
                          isBold: _isBold,
                          isItalic: _isItalic,
                          fontSize: _textSize,
                          color: _selectedTextColor,
                        ),
                      );
                    }
                  });

                  if (existingItem != null) {
                    // The pre-edit state is already in history.
                    // Add the edited state as the next history entry.
                    _pushHistoryState();
                  } else {
                    _pushHistoryState();
                  }

                  Navigator.pop(ctx);
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _textColorCircle(
      Color color,
      StateSetter setDialogState, {
        bool hasBorder = false,
      }) {
    final selected = _selectedTextColor == color;

    return GestureDetector(
      onTap: () {
        setDialogState(() {
          _selectedTextColor = color;
        });
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Colors.deepPurple
                : (hasBorder ? Colors.grey : Colors.transparent),
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // ADD IMAGE
  // --------------------------------------------------

  Future<void> _pickImageAndPrepare() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );

      if (picked == null || picked.files.isEmpty) return;

      final path = picked.files.first.path;

      if (path == null) return;

      final imageBytes = await File(path).readAsBytes();

      setState(() {
        _annotations.add(
          AnnotationItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            pageIndex: 0,
            type: AnnotationType.image,
            position: const Offset(40, 100),
            size: const Size(120, 120),
            imageBytes: imageBytes,
          ),
        );
      });

      _pushHistoryState();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image added. Drag it to reposition.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to add image: $e')),
        );
      }
    }
  }

  // --------------------------------------------------
  // HIGHLIGHT
  // --------------------------------------------------

  void _addHighlightAnnotation(int pageIndex, Offset tapPos) {
    setState(() {
      _annotations.add(
        AnnotationItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          pageIndex: pageIndex,
          type: AnnotationType.highlight,
          position: tapPos,
          size: const Size(160, 24),
          color: _highlightColor.withValues(alpha: 0.4),
        ),
      );
    });

    _pushHistoryState();
  }

  // --------------------------------------------------
  // DELETE ANNOTATION
  // --------------------------------------------------

  void _deleteAnnotation(String id) {
    setState(() {
      _annotations.removeWhere((a) => a.id == id);
      _selectedAnnotationId = null;
    });

    _pushHistoryState();
  }

  // --------------------------------------------------
  // SAVE DRAWING AS SVG
  // --------------------------------------------------

  String _buildDrawingSvg(List<AnnotationItem> annotations) {
    final buffer = StringBuffer();

    buffer.write(
      '<svg xmlns="http://www.w3.org/2000/svg" '
          'width="360" height="509" viewBox="0 0 360 509">',
    );

    for (final ann in annotations) {
      if (ann.type != AnnotationType.draw ||
          ann.drawPoints.isEmpty) {
        continue;
      }

      final hex = (ann.color.toARGB32() & 0xFFFFFF)
          .toRadixString(16)
          .padLeft(6, '0');

      final opacity = ((ann.color.toARGB32() >> 24) & 0xFF) / 255;

      final path = StringBuffer();

      for (int i = 0; i < ann.drawPoints.length; i++) {
        final point = ann.drawPoints[i];

        if (i == 0) {
          path.write('M ${point.dx} ${point.dy} ');
        } else {
          path.write('L ${point.dx} ${point.dy} ');
        }
      }

      buffer.write(
        '<path d="${path.toString()}" '
            'fill="none" stroke="#$hex" '
            'stroke-opacity="$opacity" '
            'stroke-width="${ann.strokeWidth}" '
            'stroke-linecap="round" '
            'stroke-linejoin="round"/>',
      );
    }

    buffer.write('</svg>');

    return buffer.toString();
  }

  // --------------------------------------------------
  // SAVE EDITED PDF
  // --------------------------------------------------

  Future<void> _saveEditedPdf() async {
    try {
      if (_renderedImages.isEmpty) {
        throw Exception('No PDF pages available.');
      }

      final pdf = pw.Document();

      const designWidth = 360.0;
      const designHeight = 509.0;

      final scaleX = PdfPageFormat.a4.width / designWidth;
      final scaleY = PdfPageFormat.a4.height / designHeight;

      for (int i = 0; i < _renderedImages.length; i++) {
        final pageImg = _renderedImages[i];

        final pageAnns = _annotations
            .where((a) => a.pageIndex == i)
            .toList();

        final drawingAnns = pageAnns
            .where((a) => a.type == AnnotationType.draw)
            .toList();

        final drawingSvg = _buildDrawingSvg(drawingAnns);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (context) {
              return pw.Stack(
                children: [
                  pw.Positioned.fill(
                    child: pw.Image(
                      pw.MemoryImage(pageImg),
                      fit: pw.BoxFit.fill,
                    ),
                  ),

                  // Highlights
                  ...pageAnns
                      .where((a) => a.type == AnnotationType.highlight)
                      .map((ann) {
                    return pw.Positioned(
                      left: ann.position.dx * scaleX,
                      top: ann.position.dy * scaleY,
                      child: pw.Container(
                        width: ann.size.width * scaleX,
                        height: ann.size.height * scaleY,
                        color: PdfColor.fromInt(
                          ann.color.toARGB32(),
                        ),
                      ),
                    );
                  }),

                  // Text annotations
                  ...pageAnns
                      .where((a) => a.type == AnnotationType.text)
                      .map((ann) {
                    return pw.Positioned(
                      left: ann.position.dx * scaleX,
                      top: ann.position.dy * scaleY,
                      child: pw.Text(
                        ann.text,
                        style: pw.TextStyle(
                          fontSize: ann.fontSize * scaleX,
                          fontWeight: ann.isBold
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal,
                          fontStyle: ann.isItalic
                              ? pw.FontStyle.italic
                              : pw.FontStyle.normal,
                          color: PdfColor.fromInt(
                            ann.color.toARGB32(),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Image annotations
                  ...pageAnns
                      .where((a) =>
                  a.type == AnnotationType.image &&
                      a.imageBytes != null)
                      .map((ann) {
                    return pw.Positioned(
                      left: ann.position.dx * scaleX,
                      top: ann.position.dy * scaleY,
                      child: pw.Image(
                        pw.MemoryImage(ann.imageBytes!),
                        width: ann.size.width * scaleX,
                        height: ann.size.height * scaleY,
                        fit: pw.BoxFit.contain,
                      ),
                    );
                  }),

                  // Freehand drawing layer
                  if (drawingAnns.isNotEmpty)
                    pw.Positioned.fill(
                      child: pw.SvgImage(
                        svg: drawingSvg,
                      ),
                    ),
                ],
              );
            },
          ),
        );
      }

      final tempDirectory = await getTemporaryDirectory();

      final tempFile = File(
        '${tempDirectory.path}/Edited_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      await tempFile.writeAsBytes(await pdf.save());

      final savedFile = await FileStorageService.saveFileToDownloads(
        tempFile,
        'Edited_Document_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ToolResultScreen(
            toolName: 'Edit PDF',
            outputPdfFile: savedFile,
            pageCount: _renderedImages.length,
            variant: ResultTypeVariant.generic,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --------------------------------------------------
  // BUILD SCREEN
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        title: const Text(
          'Edit PDF',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),

      body: Stack(
        children: [
          FutureBuilder<List<Uint8List>>(
            future: _pagesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading PDF: ${snapshot.error}'),
                );
              }

              final pages = snapshot.data ?? [];

              if (pages.isEmpty) {
                return const Center(
                  child: Text('No pages found.'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  return _buildPageItem(index, pages[index]);
                },
              );
            },
          ),

          // DRAW COLOR AND WIDTH BAR
          if (_selectedTool == 'Draw')
            Positioned(
              bottom: 85,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Pen:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        ...[
                          Colors.red,
                          Colors.blue,
                          Colors.green,
                          Colors.black,
                          Colors.orange,
                          Colors.purple,
                        ].map((color) {
                          return GestureDetector(
                            onTap: () {
                              setState(() => _drawColor = color);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              width: 27,
                              height: 27,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _drawColor == color
                                      ? Colors.deepPurple
                                      : Colors.grey,
                                  width: _drawColor == color ? 3 : 1,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),

                    Row(
                      children: [
                        const Text('Width:'),
                        Expanded(
                          child: Slider(
                            value: _drawWidth,
                            min: 1,
                            max: 12,
                            divisions: 11,
                            activeColor: Colors.deepPurple,
                            onChanged: (value) {
                              setState(() => _drawWidth = value);
                            },
                          ),
                        ),
                        Text(_drawWidth.toStringAsFixed(0)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // HIGHLIGHT COLOR BAR
          if (_selectedTool == 'Highlight')
            Positioned(
              bottom: 85,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _highlightChip('Yellow', Colors.yellow),
                      const SizedBox(width: 8),
                      _highlightChip('Green', Colors.greenAccent),
                      const SizedBox(width: 8),
                      _highlightChip('Pink', Colors.pinkAccent),
                    ],
                  ),
                ),
              ),
            ),

          // SAVE BUTTON
          Positioned(
            bottom: (_selectedTool == 'Draw' ||
                _selectedTool == 'Highlight')
                ? 175
                : 80,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: _saveEditedPdf,
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.save_alt_rounded),
              label: const Text('Save PDF'),
            ),
          ),
        ],
      ),

      // BOTTOM TOOLBAR
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 8,
            ),
            child: Row(
              children: [
                _toolButton(Icons.search_rounded, 'Select'),
                _toolButton(Icons.edit_note_rounded, 'Add Text'),
                _toolButton(Icons.image_outlined, 'Add Image'),
                _toolButton(Icons.draw_outlined, 'Draw'),
                _toolButton(Icons.highlight_rounded, 'Highlight'),

                const SizedBox(width: 8),

                Container(
                  height: 30,
                  width: 1,
                  color: Colors.grey.shade300,
                ),

                IconButton(
                  icon: Icon(
                    Icons.undo_rounded,
                    color: _historyIndex > 0
                        ? Colors.deepPurple
                        : Colors.grey,
                  ),
                  tooltip: 'Undo',
                  onPressed: _historyIndex > 0 ? _undo : null,
                ),

                IconButton(
                  icon: Icon(
                    Icons.redo_rounded,
                    color: _historyIndex < _historyStack.length - 1
                        ? Colors.deepPurple
                        : Colors.grey,
                  ),
                  tooltip: 'Redo',
                  onPressed: _historyIndex < _historyStack.length - 1
                      ? _redo
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // PDF PAGE WIDGET
  // --------------------------------------------------

  Widget _buildPageItem(int pageIndex, Uint8List pageImage) {
    final pageAnnotations = _annotations
        .where((a) => a.pageIndex == pageIndex)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = constraints.maxWidth;
        final pageHeight = pageWidth * 1.414;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          width: pageWidth,
          height: pageHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // PDF IMAGE AND GESTURES
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  _handlePageTap(
                    pageIndex,
                    details.localPosition,
                  );
                },
                onPanStart: (details) {
                  _handlePanStart(
                    pageIndex,
                    details.localPosition,
                  );
                },
                onPanUpdate: (details) {
                  _handlePanUpdate(
                    pageIndex,
                    details.localPosition,
                  );
                },
                onPanEnd: (_) {
                  _handlePanEnd(pageIndex);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      pageImage,
                      fit: BoxFit.contain,
                      width: pageWidth,
                      height: pageHeight,
                    ),
                  ),
                ),
              ),

              // DRAWING AND HIGHLIGHT PAINTER
              IgnorePointer(
                child: CustomPaint(
                  size: Size(pageWidth, pageHeight),
                  painter: _PageDrawingPainter(
                    annotations: pageAnnotations
                        .where(
                          (a) =>
                      a.type == AnnotationType.draw ||
                          a.type == AnnotationType.highlight,
                    )
                        .toList(),
                  ),
                ),
              ),

              // TEXT AND IMAGE ANNOTATIONS
              ...pageAnnotations
                  .where(
                    (a) =>
                a.type == AnnotationType.text ||
                    a.type == AnnotationType.image,
              )
                  .map(
                    (ann) => _buildAnnotationWidget(
                  ann,
                  pageWidth,
                  pageHeight,
                ),
              ),

              // PAGE NUMBER
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${pageIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------
  // DRAGGABLE TEXT / IMAGE
  // --------------------------------------------------

  Widget _buildAnnotationWidget(
      AnnotationItem ann,
      double pageWidth,
      double pageHeight,
      ) {
    final isSelected = _selectedAnnotationId == ann.id;

    return Positioned(
      left: ann.position.dx.clamp(
        0.0,
        pageWidth - ann.size.width,
      ),
      top: ann.position.dy.clamp(
        0.0,
        pageHeight - ann.size.height,
      ),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedAnnotationId = ann.id;
          });

          if (ann.type == AnnotationType.text) {
            _showAddTextDialog(
              ann.pageIndex,
              ann.position,
              existingItem: ann,
            );
          }
        },
        onPanUpdate: (details) {
          if (_selectedTool != 'Select') return;

          setState(() {
            _selectedAnnotationId = ann.id;

            ann.position = Offset(
              (ann.position.dx + details.delta.dx).clamp(
                0.0,
                pageWidth - ann.size.width,
              ),
              (ann.position.dy + details.delta.dy).clamp(
                0.0,
                pageHeight - ann.size.height,
              ),
            );
          });
        },
        onPanEnd: (_) {
          if (_selectedTool == 'Select') {
            _pushHistoryState();
          }
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? Colors.deepPurple
                      : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ann.type == AnnotationType.text
                  ? Text(
                ann.text,
                style: TextStyle(
                  fontSize: ann.fontSize,
                  fontWeight: ann.isBold
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontStyle: ann.isItalic
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: ann.color,
                ),
              )
                  : Image.memory(
                ann.imageBytes!,
                width: ann.size.width,
                height: ann.size.height,
                fit: BoxFit.contain,
              ),
            ),

            if (isSelected)
              Positioned(
                top: -12,
                right: -12,
                child: GestureDetector(
                  onTap: () => _deleteAnnotation(ann.id),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // HIGHLIGHT COLOR CHIP
  // --------------------------------------------------

  Widget _highlightChip(String label, Color color) {
    final isSelected = _highlightColor == color;

    return ActionChip(
      backgroundColor: color,
      side: BorderSide(
        color: isSelected ? Colors.deepPurple : Colors.transparent,
        width: 2,
      ),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: () {
        setState(() {
          _highlightColor = color;
        });
      },
    );
  }

  // --------------------------------------------------
  // TOOL BUTTON
  // --------------------------------------------------

  Widget _toolButton(IconData icon, String title) {
    final selected = _selectedTool == title;

    return InkWell(
      onTap: () => _selectTool(title),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 10,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Colors.deepPurple.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected
                  ? Colors.deepPurple
                  : Colors.grey.shade700,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? Colors.deepPurple
                    : Colors.grey.shade700,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// DRAWING AND HIGHLIGHT PAINTER
// --------------------------------------------------

class _PageDrawingPainter extends CustomPainter {
  final List<AnnotationItem> annotations;

  _PageDrawingPainter({
    required this.annotations,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final ann in annotations) {
      if (ann.type == AnnotationType.draw &&
          ann.drawPoints.isNotEmpty) {
        final paint = Paint()
          ..color = ann.color
          ..strokeWidth = ann.strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        if (ann.drawPoints.length == 1) {
          canvas.drawCircle(
            ann.drawPoints.first,
            ann.strokeWidth / 2,
            Paint()
              ..color = ann.color
              ..style = PaintingStyle.fill,
          );
        } else {
          final path = Path()
            ..moveTo(
              ann.drawPoints.first.dx,
              ann.drawPoints.first.dy,
            );

          for (int i = 1; i < ann.drawPoints.length; i++) {
            path.lineTo(
              ann.drawPoints[i].dx,
              ann.drawPoints[i].dy,
            );
          }

          canvas.drawPath(path, paint);
        }
      } else if (ann.type == AnnotationType.highlight) {
        final paint = Paint()
          ..color = ann.color
          ..style = PaintingStyle.fill;

        canvas.drawRect(
          ann.position & ann.size,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(
      covariant _PageDrawingPainter oldDelegate,
      ) {
    return true;
  }
}
