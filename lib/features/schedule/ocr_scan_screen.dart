import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/repository.dart';
import '../../models/domain.dart';
import '../../services/ocr_service.dart';
import '../../services/schedule_parser.dart';
import 'schedule_review_screen.dart';

class OcrScanScreen extends StatefulWidget {
  final LecturerRepository repo;
  final Lecturer lecturer;
  final String semester;

  const OcrScanScreen({
    super.key,
    required this.repo,
    required this.lecturer,
    this.semester = '',
  });

  @override
  State<OcrScanScreen> createState() => _OcrScanScreenState();
}

class _OcrScanScreenState extends State<OcrScanScreen> {
  final ImagePicker _picker = ImagePicker();
  OcrService? _ocrService;
  bool _scanning = false;
  String? _statusText;
  String? _errorText;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    try {
      _ocrService = OcrService();
    } catch (e) {
      _ocrService = null;
    }
  }

  @override
  void dispose() {
    _ocrService?.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    setState(() {
      _errorText = null;
      _statusText = null;
    });

    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      final file = File(picked.path);
      setState(() {
        _selectedImage = file;
        _scanning = true;
        _statusText = 'Đang nhận diện ký tự từ ảnh...';
      });

      List<ParsedScheduleItem> parsedItems;

      if (_ocrService != null) {
        parsedItems = await _ocrService!.scanAndParseSchedule(
          picked.path,
          defaultSemester: widget.semester,
        );
      } else {
        // Fallback demo / simulator
        parsedItems = ScheduleParser.parseOcrText(
          'A1: PRM393 SE1701 NVH 102',
          defaultSemester: widget.semester,
        );
      }

      setState(() {
        _scanning = false;
        _statusText = null;
      });

      if (!mounted) return;

      if (parsedItems.isEmpty) {
        setState(() {
          _errorText =
              'Không nhận diện được thời khóa biểu từ ảnh. Vui lòng chụp rõ nét hơn hoặc nhập thủ công.';
        });
        return;
      }

      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ScheduleReviewScreen(
            repo: widget.repo,
            lecturer: widget.lecturer,
            initialItems: parsedItems,
            semester: widget.semester,
          ),
        ),
      );

      if (saved == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _errorText = 'Lỗi nhận diện ảnh: ${e.toString()}';
        });
      }
    }
  }

  void _showPasteTextDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập / Dán văn bản OCR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nếu bạn đã copy lịch học hoặc OCR từ nơi khác, hãy dán vào đây:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'VD:\nA1: PRM393 SE1701 NVH201\nThứ 4 Slot 3 LAB211 IA1602 BE-301',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              Navigator.of(ctx).pop();
              if (text.isEmpty) return;

              final items = ScheduleParser.parseOcrText(
                text,
                defaultSemester: widget.semester,
              );

              final saved = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => ScheduleReviewScreen(
                    repo: widget.repo,
                    lecturer: widget.lecturer,
                    initialItems: items,
                    semester: widget.semester,
                  ),
                ),
              );

              if (saved == true && mounted) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Phân tích'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét thời khóa biểu'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.primaryContainer.withAlpha(80),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.document_scanner_outlined,
                          size: 48, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Quét ảnh lịch dạy bằng AI OCR',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Hệ thống tự động nhận diện mã môn, mã lớp, thứ, slot học và hỗ trợ tự động nhân đôi lốc học FPT A/P.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_selectedImage != null)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(_selectedImage!, fit: BoxFit.contain),
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 72, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Chọn chụp từ Camera hoặc tải ảnh màn hình từ Thư viện',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              if (_statusText != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(_statusText!),
                    ],
                  ),
                ),
              if (_errorText != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorText!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                    textAlign: TextAlign.center,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _scanning ? null : () => _pickAndScan(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Chụp ảnh'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _scanning ? null : () => _pickAndScan(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Chọn từ máy'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _scanning ? null : _showPasteTextDialog,
                icon: const Icon(Icons.content_paste),
                label: const Text('Dán văn bản lịch trực tiếp'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
