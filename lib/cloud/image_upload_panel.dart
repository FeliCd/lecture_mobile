import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cloud_view_model.dart';

class ImageUploadPanel extends ConsumerStatefulWidget {
  const ImageUploadPanel({super.key});
  @override
  ConsumerState<ImageUploadPanel> createState() => _ImageUploadPanelState();
}

class _ImageUploadPanelState extends ConsumerState<ImageUploadPanel> {
  bool selecting = false;
  String? error;
  Uint8List? preview;
  Future<void> pick() async {
    setState(() {
      selecting = true;
      error = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        withReadStream: true,
      );
      if (!mounted || result == null) return;
      final file = result.files.single;
      if (file.size > 5 * 1024 * 1024) {
        throw const FormatException('Ảnh tối đa 5 MB.');
      }
      final builder = BytesBuilder(copy: false);
      if (file.bytes != null) {
        builder.add(file.bytes!);
      } else if (file.readStream != null) {
        await for (final chunk in file.readStream!) {
          if (builder.length + chunk.length > 5 * 1024 * 1024) {
            throw const FormatException('Ảnh tối đa 5 MB.');
          }
          builder.add(chunk);
        }
      }
      final bytes = builder.takeBytes();
      if (!mounted) return;
      setState(() => preview = bytes);
      await ref.read(imageUploadProvider.notifier).upload(bytes, file.name);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Không đọc được ảnh. Chọn PNG/JPEG tối đa 5 MB.',
        );
      }
    } finally {
      if (mounted) setState(() => selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageUploadProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ảnh Firebase Storage · PNG/JPEG tối đa 5 MB'),
        FilledButton.icon(
          onPressed: selecting || state.busy ? null : pick,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            selecting || state.busy ? 'Đang tải ảnh…' : 'Chọn và upload ảnh',
          ),
        ),
        if (state.busy) LinearProgressIndicator(value: state.progress),
        if (error != null || state.error != null) Text(error ?? state.error!),
        if (preview != null)
          Image.memory(
            preview!,
            height: 140,
            cacheWidth: 600,
            errorBuilder: (_, _, _) => const Text('Ảnh không đọc được.'),
          ),
        if (state.receipt != null) ...[
          const Text(
            'Upload thành công. Đối chiếu đường dẫn trong Firebase Console → Storage.',
          ),
          SelectableText(state.receipt!.path),
          SelectableText(state.receipt!.url),
        ],
      ],
    );
  }
}
