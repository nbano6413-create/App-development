
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';

class ResultScreen extends StatelessWidget {
  final String title;
  final File outputPdfFile;
  final int pageCount;

  const ResultScreen({
    super.key,
    required this.title,
    required this.outputPdfFile,
    required this.pageCount,
  });

  Future<String> _getFileSizeString(File file) async {
    final bytes = await file.length();

    if (bytes < 1024) return '$bytes B';

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _saveToDevice(BuildContext context) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final savedPath =
          '${directory.path}/${outputPdfFile.uri.pathSegments.last}';

      await outputPdfFile.copy(savedPath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved successfully to: $savedPath'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Share PDF using share_plus 12.0.2
  Future<void> _shareFile() async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(outputPdfFile.path)],
        text: 'Check out my generated PDF from My Docverter',
      ),
    );
  }

  Future<void> _openFile(BuildContext context) async {
    final result = await OpenFile.open(outputPdfFile.path);

    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: ${result.message}'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Done',
            style: TextStyle(
              color: AppTheme.primaryPurple,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        leadingWidth: 70,
        title: Text(
          title,
          style: TextStyle(
            color: isDark
                ? AppTheme.textPrimaryDark
                : AppTheme.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // File Metadata Header Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkSurface
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetaItem(
                  Icons.insert_drive_file_rounded,
                  'Format',
                  'PDF',
                ),
                _buildMetaItem(
                  Icons.layers_rounded,
                  'Pages',
                  '$pageCount',
                ),
                FutureBuilder<String>(
                  future: _getFileSizeString(outputPdfFile),
                  builder: (context, snapshot) {
                    return _buildMetaItem(
                      Icons.storage_rounded,
                      'Size',
                      snapshot.data ?? 'Calculating...',
                    );
                  },
                ),
              ],
            ),
          ),

          // Interactive PDF Preview
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: PdfPreview(
                  build: (format) => outputPdfFile.readAsBytes(),
                  allowPrinting: true,
                  allowSharing: true,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  pdfFileName:
                  outputPdfFile.uri.pathSegments.last,
                ),
              ),
            ),
          ),

          // Action Buttons Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkSurface
                  : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openFile(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      side: const BorderSide(
                        color: AppTheme.primaryPurple,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(
                      Icons.open_in_new_rounded,
                      color: AppTheme.primaryPurple,
                    ),
                    label: const Text(
                      'Open',
                      style: TextStyle(
                        color: AppTheme.primaryPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareFile,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      side: const BorderSide(
                        color: AppTheme.primaryPurple,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(
                      Icons.share_rounded,
                      color: AppTheme.primaryPurple,
                    ),
                    label: const Text(
                      'Share',
                      style: TextStyle(
                        color: AppTheme.primaryPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _saveToDevice(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      backgroundColor: AppTheme.primaryPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(
      IconData icon,
      String label,
      String value,
      ) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryPurple,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
