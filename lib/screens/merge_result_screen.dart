
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import 'result_screen.dart';

class MergeResultScreen extends StatelessWidget {
  final int totalPdfs;
  final int totalPages;
  final File outputPdfFile;

  const MergeResultScreen({
    super.key,
    required this.totalPdfs,
    required this.totalPages,
    required this.outputPdfFile,
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
        content: Text('Folder path: $dirPath'),
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
          title: 'Merged PDF Viewer',
          outputPdfFile: outputPdfFile,
          pageCount: totalPages,
        ),
      ),
    );
  }

  // Updated share_plus API
  Future<void> _shareFile() async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(outputPdfFile.path)],
        text: 'Check out my merged PDF from My Docverter',
      ),
    );
  }

  void _goToHome(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final fileName = outputPdfFile.uri.pathSegments.last;

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
              const SizedBox(height: 20),

              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF4CAF50),
                  size: 52,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'PDFs merged successfully!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Your file has been saved successfully.',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurface
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  children: [
                    _buildMetaRow(
                      'Total PDFs:',
                      '$totalPdfs',
                    ),

                    const SizedBox(height: 16),

                    _buildMetaRow(
                      'Total Pages:',
                      '$totalPages',
                    ),

                    const SizedBox(height: 16),

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
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'File Name:',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 15,
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

              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => _openFolder(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    'OPEN FOLDER',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 54,
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
                  child: const Text(
                    'VIEW FILE',
                    style: TextStyle(
                      color: AppTheme.primaryPurple,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 54,
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
                  child: const Text(
                    'SHARE FILE',
                    style: TextStyle(
                      color: AppTheme.primaryPurple,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              TextButton(
                onPressed: () => _goToHome(context),
                child: const Text(
                  'GO TO HOME',
                  style: TextStyle(
                    color: AppTheme.primaryPurple,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
