
import 'dart:io';

import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../models/pdf_tool.dart';
import '../providers/app_state.dart';
import '../services/ad_service.dart';
import '../services/file_storage_service.dart';
import '../services/pdf_engine_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dashed_upload_box.dart';
import '../widgets/security_footer.dart';
import 'merge_result_screen.dart';
import 'tool_result_screen.dart';
import 'settings_screen.dart';
import 'pdf_editor_screen.dart';

class ToolDetailScreen extends StatefulWidget {
  final PdfTool tool;
  final AppState appState;

  const ToolDetailScreen({
    super.key,
    required this.tool,
    required this.appState,
  });

  @override
  State<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends State<ToolDetailScreen> {
  final List<String> _selectedFiles = [];

  final TextEditingController _fromPageController =
  TextEditingController(text: '1');

  final TextEditingController _toPageController =
  TextEditingController(text: '2');

  final TextEditingController _passwordController =
  TextEditingController();

  final TextEditingController _confirmPasswordController =
  TextEditingController();

  final TextEditingController _unlockPasswordController =
  TextEditingController();

  final TextEditingController _watermarkController =
  TextEditingController();

  int _rotationAngle = 90;
  String _pageNumberPosition = 'Bottom Center';
  double _watermarkOpacity = 0.25;
  String _compressionLevel = 'Medium';

  // PDF TO POWERPOINT OPTIONS
  bool _pptPreserveFormatting = true;
  bool _pptOnePagePerSlide = true;
  bool _pptExtractImages = true;

  // JPG TO PDF OPTIONS
  String _jpgPageSize = 'A4';
  String _jpgOrientation = 'Portrait';
  String _jpgImageFit = 'Fit to Page';
  String _jpgMargin = 'None';

  // PDF TO WORD OPTIONS
  String _wordOutputFormat = 'DOC';
  bool _wordPreserveFormatting = true;
  bool _wordExtractImages = true;

  @override
  void dispose() {
    _fromPageController.dispose();
    _toPageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _unlockPasswordController.dispose();
    _watermarkController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final optionType = widget.tool.optionType;

      final isMulti =
          optionType == ToolOptionType.merge ||
              optionType == ToolOptionType.jpgToPdf;

      final isImage = optionType == ToolOptionType.jpgToPdf;
      final isWord = optionType == ToolOptionType.wordToPdf;
      final isExcel = optionType == ToolOptionType.excelToPdf;

      List<String> extensions = ['pdf'];

      if (isImage) {
        extensions = ['jpg', 'jpeg', 'png'];
      } else if (isWord) {
        extensions = ['doc', 'docx'];
      } else if (isExcel) {
        extensions = ['xls', 'xlsx'];
      }

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: isMulti,
        type: FileType.custom,
        allowedExtensions: extensions,
      );

      if (!mounted || result == null) return;

      setState(() {
        for (final file in result.files) {
          final path = file.path;

          if (path != null && !_selectedFiles.contains(path)) {
            _selectedFiles.add(path);
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error picking file: $e', Colors.red);
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _processAction() async {
    if (_selectedFiles.isEmpty) {
      _showMessage(
        'Please select at least one file for ${widget.tool.name}.',
        Colors.orange,
      );
      return;
    }

    if (widget.tool.optionType == ToolOptionType.editPdf) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfEditorScreen(
            filePath: _selectedFiles.first,
          ),
        ),
      );
      return;
    }

    if (widget.tool.optionType == ToolOptionType.protectPdf) {
      final password = _passwordController.text;

      if (password.trim().length < 4) {
        _showMessage(
          'Password must contain at least 4 characters.',
          Colors.red,
        );
        return;
      }

      if (password != _confirmPasswordController.text) {
        _showMessage('Passwords do not match.', Colors.red);
        return;
      }
    }

    if (widget.tool.optionType == ToolOptionType.unlockPdf &&
        _unlockPasswordController.text.trim().isEmpty) {
      _showMessage('Please enter your PDF password.', Colors.red);
      return;
    }

    if (widget.tool.optionType == ToolOptionType.watermark &&
        _watermarkController.text.trim().isEmpty) {
      _showMessage('Please enter watermark text.', Colors.red);
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProcessingDialog(
        toolName: widget.tool.name,
        onProcess: _executeEngineTask,
      ),
    );
  }

  Future<void> _executeEngineTask(
      Function(double, String) updateProgress,
      ) async {
    try {
      updateProgress(0.2, 'Loading documents...');
      await Future.delayed(const Duration(milliseconds: 300));

      Map<String, dynamic> result;

      updateProgress(0.6, 'Processing ${widget.tool.name}...');

      switch (widget.tool.optionType) {
        case ToolOptionType.merge:
          result = await PdfEngineService.mergePdfs(_selectedFiles);
          break;

        case ToolOptionType.split:
          final from = int.tryParse(_fromPageController.text) ?? 1;
          final to = int.tryParse(_toPageController.text) ?? 2;

          if (from < 1 || to < from) {
            throw Exception('Please enter a valid page range.');
          }

          result = await PdfEngineService.splitPdf(
            _selectedFiles.first,
            from,
            to,
          );
          break;

        case ToolOptionType.organize:
          final pdfBytes =
          await File(_selectedFiles.first).readAsBytes();

          final pages =
          await Printing.raster(pdfBytes, dpi: 150.0).toList();

          if (pages.isEmpty) {
            throw Exception('PDF mein koi pages nahi hain.');
          }

          final defaultOrder = List<int>.generate(
            pages.length,
                (index) => index,
          );

          result = await PdfEngineService.organizePdf(
            _selectedFiles.first,
            defaultOrder,
          );
          break;

        case ToolOptionType.rotatePdf:
          result = await PdfEngineService.rotatePdf(
            _selectedFiles.first,
            _rotationAngle,
          );
          break;

        case ToolOptionType.jpgToPdf:
          result = await PdfEngineService.jpgToPdf(
            _selectedFiles,
            pageSize: _jpgPageSize,
            orientation: _jpgOrientation,
            imageFit: _jpgImageFit,
            margin: _jpgMargin,
          );
          break;

        case ToolOptionType.pageNumbers:
          result = await PdfEngineService.addPageNumbers(
            _selectedFiles.first,
            _pageNumberPosition,
          );
          break;

        case ToolOptionType.protectPdf:
          result = await PdfEngineService.protectPdf(
            _selectedFiles.first,
            _passwordController.text,
          );
          break;

        case ToolOptionType.unlockPdf:
          result = await PdfEngineService.unlockPdf(
            _selectedFiles.first,
            _unlockPasswordController.text,
          );
          break;

        case ToolOptionType.watermark:
          result = await PdfEngineService.watermarkPdf(
            _selectedFiles.first,
            _watermarkController.text.trim(),
            _watermarkOpacity,
          );
          break;

        case ToolOptionType.compressPdf:
          result = await PdfEngineService.compressPdf(
            _selectedFiles.first,
            _compressionLevel.toLowerCase(),
          );
          break;

        case ToolOptionType.ocrPdf:
          result = await PdfEngineService.ocrPdf(
            _selectedFiles.first,
          );
          break;

        case ToolOptionType.editPdf:
          throw Exception('Please open the PDF Editor.');

        case ToolOptionType.repairPdf:
          result = await PdfEngineService.repairPdf(
            _selectedFiles.first,
          );
          break;

        case ToolOptionType.wordToPdf:
          result = await PdfEngineService.wordToPdf(
            _selectedFiles.first,
          );
          break;

        case ToolOptionType.excelToPdf:
          result = await PdfEngineService.excelToPdf(
            _selectedFiles.first,
          );
          break;

        case ToolOptionType.pdfToWord:
          result = await PdfEngineService.pdfToWord(
            _selectedFiles.first,
            outputFormat: _wordOutputFormat,
            preserveFormatting: _wordPreserveFormatting,
            extractImages: _wordExtractImages,
          );
          break;

        case ToolOptionType.pdfToPpt:
          result = await PdfEngineService.pdfToPpt(
            _selectedFiles.first,
            preserveFormatting: _pptPreserveFormatting,
            onePagePerSlide: _pptOnePagePerSlide,
            extractImages: _pptExtractImages,
          );
          break;

        case ToolOptionType.pdfToExcel:
          result = await PdfEngineService.pdfToExcel(
            _selectedFiles.first,
          );
          break;
      }

      updateProgress(0.9, 'Saving to Downloads...');

      final tempFile = result['file'] as File;

      final savedFile = await FileStorageService.saveFileToDownloads(
        tempFile,
        tempFile.uri.pathSegments.last,
      );

      final pageCount = result['pageCount'] as int? ?? 0;

      updateProgress(1.0, 'Completed successfully!');
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;

      Navigator.of(context).pop();

      ResultTypeVariant variant = ResultTypeVariant.generic;

      switch (widget.tool.optionType) {
        case ToolOptionType.merge:
          variant = ResultTypeVariant.merge;
          break;
        case ToolOptionType.split:
          variant = ResultTypeVariant.split;
          break;
        case ToolOptionType.organize:
          variant = ResultTypeVariant.organize;
          break;
        case ToolOptionType.pdfToWord:
          variant = ResultTypeVariant.pdfToWord;
          break;
        case ToolOptionType.wordToPdf:
          variant = ResultTypeVariant.wordToPdf;
          break;
        case ToolOptionType.jpgToPdf:
          variant = ResultTypeVariant.jpgToPdf;
          break;
        case ToolOptionType.pdfToExcel:
          variant = ResultTypeVariant.pdfToExcel;
          break;
        case ToolOptionType.pdfToPpt:
          variant = ResultTypeVariant.pdfToPpt;
          break;
        case ToolOptionType.excelToPdf:
          variant = ResultTypeVariant.excelToPdf;
          break;
        case ToolOptionType.ocrPdf:
          variant = ResultTypeVariant.ocrPdf;
          break;
        default:
          variant = ResultTypeVariant.generic;
      }

      AdService.instance.showInterstitialIfEligible(context, () async {
        if (!mounted) return;

        if (widget.tool.optionType == ToolOptionType.merge) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MergeResultScreen(
                totalPdfs: _selectedFiles.length,
                totalPages: pageCount,
                outputPdfFile: savedFile,
              ),
            ),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ToolResultScreen(
                toolName: widget.tool.name,
                outputPdfFile: savedFile,
                pageCount: pageCount,
                variant: variant,
              ),
            ),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();
      _showMessage('Processing error: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Back',
            style: TextStyle(
              color: AppTheme.primaryPurple,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        leadingWidth: 70,
        title: Text(
          widget.tool.name,
          style: TextStyle(
            color: isDark
                ? AppTheme.textPrimaryDark
                : AppTheme.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    appState: widget.appState,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopInfoCard(isDark),
            const SizedBox(height: 20),
            DashedUploadBox(
              title: _selectedFiles.isEmpty
                  ? (widget.tool.optionType == ToolOptionType.jpgToPdf
                  ? 'Select Images'
                  : 'Select PDF File')
                  : 'Add More Files',
              subtitle: 'Tap to browse device storage',
              onTap: _pickFiles,
              selectedFiles: _selectedFiles
                  .map((path) =>
              path.split(Platform.pathSeparator).last)
                  .toList(),
              onRemoveFile: (index) {
                setState(() => _selectedFiles.removeAt(index));
              },
              onClearAll: () {
                setState(() => _selectedFiles.clear());
              },
            ),
            const SizedBox(height: 24),
            _buildToolOptionsForm(isDark),
            const SizedBox(height: 24),
            const SecurityFooter(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _processAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 3,
              ),
              child: Text(
                widget.tool.actionButtonText,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTopInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: widget.tool.backgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              widget.tool.icon,
              color: widget.tool.iconColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tool.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.tool.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolOptionsForm(bool isDark) {
    switch (widget.tool.optionType) {
      case ToolOptionType.split:
        return _buildSplitPdfForm(isDark);
      case ToolOptionType.rotatePdf:
        return _buildRotatePdfForm(isDark);
      case ToolOptionType.pageNumbers:
        return _buildPageNumbersForm(isDark);
      case ToolOptionType.organize:
        return _buildOrganizePdfForm(isDark);
      case ToolOptionType.protectPdf:
        return _buildProtectPdfForm(isDark);
      case ToolOptionType.unlockPdf:
        return _buildUnlockPdfForm(isDark);
      case ToolOptionType.watermark:
        return _buildWatermarkPdfForm(isDark);
      case ToolOptionType.compressPdf:
        return _buildCompressPdfForm(isDark);
      case ToolOptionType.ocrPdf:
        return _buildOcrPdfForm(isDark);
      case ToolOptionType.editPdf:
        return _buildEditPdfForm(isDark);
      case ToolOptionType.repairPdf:
        return _buildRepairPdfForm(isDark);

      case ToolOptionType.pdfToPpt:
        return _buildPdfToPptForm(isDark);

      case ToolOptionType.jpgToPdf:
        return _buildJpgToPdfForm(isDark);

      case ToolOptionType.pdfToWord:
        return _buildPdfToWordForm(isDark);

      default:
        return const SizedBox.shrink();
    }
  }

  // PDF TO POWERPOINT OPTIONS
  Widget _buildPdfToPptForm(bool isDark) {
    return _optionsCard(
      isDark,
      title: 'Conversion Options',
      subtitle: 'Customize your PowerPoint conversion',
      children: [
        _buildSwitchOption(
          title: 'Preserve Formatting',
          subtitle: 'Keep the original PDF layout and text formatting',
          value: _pptPreserveFormatting,
          onChanged: (value) {
            setState(() => _pptPreserveFormatting = value);
          },
        ),
        _buildSwitchOption(
          title: 'One Page Per Slide',
          subtitle: 'Create one PowerPoint slide for each PDF page',
          value: _pptOnePagePerSlide,
          onChanged: (value) {
            setState(() => _pptOnePagePerSlide = value);
          },
        ),
        _buildSwitchOption(
          title: 'Extract Images',
          subtitle: 'Include images from the original PDF',
          value: _pptExtractImages,
          onChanged: (value) {
            setState(() => _pptExtractImages = value);
          },
        ),
      ],
    );
  }

  // JPG TO PDF OPTIONS
  Widget _buildJpgToPdfForm(bool isDark) {
    return _optionsCard(
      isDark,
      title: 'Conversion Options',
      subtitle: 'Customize your image PDF',
      children: [
        _buildDropdownOption(
          title: 'Page Size',
          value: _jpgPageSize,
          options: const [
            'A3',
            'A4',
            'A5',
            'Letter',
            'Legal',
          ],
          onChanged: (value) {
            setState(() => _jpgPageSize = value);
          },
        ),
        _buildDropdownOption(
          title: 'Orientation',
          value: _jpgOrientation,
          options: const [
            'Portrait',
            'Landscape',
          ],
          onChanged: (value) {
            setState(() => _jpgOrientation = value);
          },
        ),
        _buildDropdownOption(
          title: 'Image Fit',
          value: _jpgImageFit,
          options: const [
            'Fit to Image',
            'Fit to Page',
            'Fill Page',
            'Original Size',
          ],
          onChanged: (value) {
            setState(() => _jpgImageFit = value);
          },
        ),
        _buildDropdownOption(
          title: 'Margins',
          value: _jpgMargin,
          options: const [
            'None',
            'Small',
            'Medium',
            'Large',
          ],
          onChanged: (value) {
            setState(() => _jpgMargin = value);
          },
        ),
      ],
    );
  }

  // PDF TO WORD OPTIONS
  Widget _buildPdfToWordForm(bool isDark) {
    return _optionsCard(
      isDark,
      title: 'Conversion Options',
      subtitle: 'Customize your Word document',
      children: [
        _buildDropdownOption(
          title: 'Output Format',
          value: _wordOutputFormat,
          options: const ['DOC'],
          displayValues: const ['DOC (Recommended)'],
          onChanged: (value) {
            setState(() => _wordOutputFormat = value);
          },
        ),
        _buildSwitchOption(
          title: 'Preserve Formatting',
          subtitle: 'Keep the original PDF formatting',
          value: _wordPreserveFormatting,
          onChanged: (value) {
            setState(() => _wordPreserveFormatting = value);
          },
        ),
        _buildSwitchOption(
          title: 'Extract Images',
          subtitle: 'Include images in the Word document',
          value: _wordExtractImages,
          onChanged: (value) {
            setState(() => _wordExtractImages = value);
          },
        ),
      ],
    );
  }

  // COMMON OPTIONS CARD
  Widget _optionsCard(
      bool isDark, {
        required String title,
        required String subtitle,
        required List<Widget> children,
      }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // SWITCH WITH RIGHT SIDE ON/OFF CONTROL
  Widget _buildSwitchOption({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11),
      ),
      value: value,
      activeThumbColor: AppTheme.primaryPurple,
      onChanged: onChanged,
    );
  }

  // REUSABLE DROPDOWN
  Widget _buildDropdownOption({
    required String title,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    List<String>? displayValues,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: List.generate(options.length, (index) {
              return DropdownMenuItem<String>(
                value: options[index],
                child: Text(
                  displayValues != null
                      ? displayValues[index]
                      : options[index],
                ),
              );
            }),
            onChanged: (newValue) {
              if (newValue != null) {
                onChanged(newValue);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSplitPdfForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Split Options',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Page Range to Extract',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _fromPageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'From Page',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _toPageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'To Page',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRotatePdfForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rotation Direction',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: [90, 180, 270].map((angle) {
            final selected = _rotationAngle == angle;

            return ChoiceChip(
              label: Text(
                '$angle° ${angle == 90
                    ? "Right"
                    : angle == 270
                    ? "Left"
                    : "Upside Down"}',
              ),
              selected: selected,
              onSelected: (value) {
                if (value) {
                  setState(() => _rotationAngle = angle);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPageNumbersForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Page Number Position',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _pageNumberPosition,
          items: [
            'Bottom Center',
            'Bottom Right',
            'Top Center',
          ].map(
                (position) => DropdownMenuItem(
              value: position,
              child: Text(position),
            ),
          ).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _pageNumberPosition = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildOrganizePdfForm(bool isDark) {
    return _infoCard(
      'Organize tool reorders and optimizes page sequences into a new PDF document.',
      Icons.info_rounded,
    );
  }

  Widget _buildProtectPdfForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Set PDF Password'),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Enter Password',
            hintText: 'Minimum 4 characters',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: Icon(Icons.lock),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildUnlockPdfForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Unlock PDF'),
        const SizedBox(height: 12),
        TextField(
          controller: _unlockPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Enter Current PDF Password',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildWatermarkPdfForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Watermark Settings'),
        const SizedBox(height: 12),
        TextField(
          controller: _watermarkController,
          decoration: const InputDecoration(
            labelText: 'Watermark Text',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Watermark Opacity: ${(_watermarkOpacity * 100).round()}%',
        ),
        Slider(
          value: _watermarkOpacity,
          min: 0.1,
          max: 1.0,
          divisions: 9,
          onChanged: (value) {
            setState(() => _watermarkOpacity = value);
          },
        ),
      ],
    );
  }

  Widget _buildCompressPdfForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Compression Settings'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _compressionLevel,
          items: const [
            DropdownMenuItem(value: 'Low', child: Text('Low')),
            DropdownMenuItem(value: 'Medium', child: Text('Medium')),
            DropdownMenuItem(value: 'High', child: Text('High')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _compressionLevel = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildOcrPdfForm(bool isDark) {
    return _infoCard(
      'Extract readable English text from scanned PDF pages. The extracted text will be saved as a TXT file.',
      Icons.document_scanner_rounded,
    );
  }

  Widget _buildEditPdfForm(bool isDark) {
    return _infoCard(
      'Select a PDF file and tap Edit PDF to open the editor screen.',
      Icons.edit_document,
    );
  }

  Widget _buildRepairPdfForm(bool isDark) {
    return _infoCard(
      'Repair a damaged PDF by rebuilding its pages into a new PDF document.',
      Icons.build_circle_outlined,
    );
  }

  Widget _infoCard(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingDialog extends StatefulWidget {
  final String toolName;
  final Future<void> Function(Function(double, String)) onProcess;

  const _ProcessingDialog({
    required this.toolName,
    required this.onProcess,
  });

  @override
  State<_ProcessingDialog> createState() =>
      _ProcessingDialogState();
}

class _ProcessingDialogState extends State<_ProcessingDialog> {
  double _progress = 0.0;
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();

    widget.onProcess((progress, message) {
      if (!mounted) return;

      setState(() {
        _progress = progress;
        _statusMessage = message;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppTheme.primaryPurple,
              strokeWidth: 4,
            ),
            const SizedBox(height: 24),
            Text(
              'Processing ${widget.toolName}...',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${(_progress * 100).toInt()}% Completed',
              style: const TextStyle(
                color: AppTheme.primaryPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor:
                AppTheme.primaryPurple.withValues(alpha: 0.15),
                color: AppTheme.primaryPurple,
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
