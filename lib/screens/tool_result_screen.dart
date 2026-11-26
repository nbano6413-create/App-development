
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import 'result_screen.dart';

enum ResultTypeVariant {
  merge,
  split,
  organize,
  pdfToWord,
  wordToPdf,
  jpgToPdf,
  pdfToExcel,
  pdfToPpt,
  excelToPdf,
  ocrPdf,
  generic,
}

class ToolResultScreen extends StatelessWidget {
  final String toolName;
  final File outputPdfFile;
  final int pageCount;
  final int? totalPdfs;
  final ResultTypeVariant variant;

  const ToolResultScreen({
    super.key,
    required this.toolName,
    required this.outputPdfFile,
    required this.pageCount,
    this.totalPdfs,
    required this.variant,
  });

  Future<String> _getFileSizeString(File file) async {
    final bytes = await file.length();

    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _openFolder(BuildContext context) async {
    final dirPath = outputPdfFile.parent.path;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved in Downloads folder: $dirPath'),
        backgroundColor: AppTheme.primaryPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );

    await OpenFile.open(dirPath);
  }

  Future<void> _viewFile(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          title: '$toolName Viewer',
          outputPdfFile: outputPdfFile,
          pageCount: pageCount,
        ),
      ),
    );
  }

  Future<void> _copyOcrText(BuildContext context) async {
    try {
      final extractedText = await outputPdfFile.readAsString();

      await Clipboard.setData(
        ClipboardData(text: extractedText),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OCR text copied successfully!'),
            backgroundColor: AppTheme.primaryPurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to copy text: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareFile() async {
    await Share.shareXFiles(
      [XFile(outputPdfFile.path)],
      text: 'Check out my $toolName output from My Docverter',
    );
  }

  void _backToHome(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final fileName = outputPdfFile.uri.pathSegments.last;
    final isOcr = variant == ResultTypeVariant.ocrPdf;

    String successTitle = '$toolName Successful!';

    if (variant == ResultTypeVariant.merge) {
      successTitle = 'PDFs merged successfully!';
    } else if (variant == ResultTypeVariant.split) {
      successTitle = 'PDF split successfully!';
    } else if (variant == ResultTypeVariant.jpgToPdf) {
      successTitle = 'PDF created successfully!';
    } else if (variant == ResultTypeVariant.pdfToWord) {
      successTitle = 'PDF converted to Word successfully!';
    } else if (variant == ResultTypeVariant.wordToPdf) {
      successTitle = 'Word converted to PDF successfully!';
    } else if (variant == ResultTypeVariant.pdfToExcel) {
      successTitle = 'PDF converted to Excel successfully!';
    } else if (variant == ResultTypeVariant.pdfToPpt) {
      successTitle = 'PDF converted to PowerPoint successfully!';
    } else if (variant == ResultTypeVariant.excelToPdf) {
      successTitle = 'Excel converted to PDF successfully!';
    } else if (isOcr) {
      successTitle = 'OCR completed successfully!';
    }

    return Scaffold(
      backgroundColor:
      isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              const Icon(
                Icons.check_rounded,
                color: Color(0xFF4CAF50),
                size: 56,
              ),

              const SizedBox(height: 14),

              Text(
                successTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              Text(
                isOcr
                    ? 'Your extracted text has been saved as a TXT file.'
                    : 'Your file has been saved successfully in Downloads.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurface
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  children: [
                    if (totalPdfs != null) ...[
                      _buildMetaRow('Total PDFs:', '$totalPdfs'),
                      const SizedBox(height: 12),
                    ],

                    _buildMetaRow(
                      isOcr ? 'Pages Scanned:' : 'Total Pages:',
                      '$pageCount',
                    ),

                    const SizedBox(height: 12),

                    FutureBuilder<String>(
                      future: _getFileSizeString(outputPdfFile),
                      builder: (context, snapshot) {
                        return _buildMetaRow(
                          'File Size:',
                          snapshot.data ?? 'Calculating...',
                        );
                      },
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'File Name:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (isOcr) ...[
                _buildOcrTextPreview(isDark),
                const SizedBox(height: 20),
              ],

              ..._buildActionButtons(context),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOcrTextPreview(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.text_snippet_rounded,
                color: AppTheme.primaryPurple,
              ),
              SizedBox(width: 10),
              Text(
                'Extracted Text Preview',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          FutureBuilder<String>(
            future: outputPdfFile.readAsString(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return const Text(
                  'Unable to load extracted text.',
                  style: TextStyle(color: Colors.red),
                );
              }

              return SelectableText(
                snapshot.data ?? 'No text found.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context) {
    final List<Widget> buttons = [];
    final isOcr = variant == ResultTypeVariant.ocrPdf;

    final openLabel =
    variant == ResultTypeVariant.pdfToPpt
        ? 'OPEN PPT'
        : 'OPEN FOLDER';

    buttons.add(
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => _openFolder(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
          child: Text(
            openLabel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );

    buttons.add(const SizedBox(height: 14));

    if (isOcr) {
      buttons.add(
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => _copyOcrText(context),
            icon: const Icon(Icons.copy_rounded),
            label: const Text('COPY EXTRACTED TEXT'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryPurple,
              side: const BorderSide(
                color: AppTheme.primaryPurple,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      );

      buttons.add(const SizedBox(height: 14));
    } else if (variant != ResultTypeVariant.split) {
      final viewLabel =
      variant == ResultTypeVariant.pdfToPpt
          ? 'VIEW PPT'
          : 'VIEW FILE';

      buttons.add(
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () => _viewFile(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(
                color: AppTheme.primaryPurple,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              viewLabel,
              style: const TextStyle(
                color: AppTheme.primaryPurple,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );

      buttons.add(const SizedBox(height: 14));
    }

    buttons.add(
      SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: _shareFile,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(
              color: AppTheme.primaryPurple,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            isOcr
                ? 'SHARE TEXT FILE'
                : variant == ResultTypeVariant.split
                ? 'SHARE PDF'
                : 'SHARE FILE',
            style: const TextStyle(
              color: AppTheme.primaryPurple,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );

    buttons.add(const SizedBox(height: 20));

    final homeLabel =
    variant == ResultTypeVariant.merge
        ? 'GO TO HOME'
        : 'BACK TO HOME';

    buttons.add(
      TextButton(
        onPressed: () => _backToHome(context),
        child: Text(
          homeLabel,
          style: const TextStyle(
            color: AppTheme.primaryPurple,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    return buttons;
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
