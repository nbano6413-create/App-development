import 'package:material_ui/material_ui.dart';

enum ToolCategory {
  popular('Popular PDF Tools'),
  conversion('PDF Conversion'),
  security('PDF Security'),
  optimization('PDF Optimization');

  final String title;
  const ToolCategory(this.title);
}

enum ToolOptionType {
  merge,
  split,
  organize,
  pdfToWord,
  wordToPdf,
  jpgToPdf,
  pdfToExcel,
  pdfToPpt,
  excelToPdf,
  protectPdf,
  unlockPdf,
  watermark,
  compressPdf,
  ocrPdf,
  repairPdf,
  rotatePdf,
  editPdf,
  pageNumbers,
}

class PdfTool {
  final String id;
  final String name;
  final String description;
  final ToolCategory category;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final ToolOptionType optionType;
  final String acceptedFileTypes;
  final String actionButtonText;

  const PdfTool({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.optionType,
    required this.acceptedFileTypes,
    required this.actionButtonText,
  });
}
