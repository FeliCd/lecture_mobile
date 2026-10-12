import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'ocr_layout.dart';

class MobileOcrResult {
  final String path, text;
  const MobileOcrResult(this.path, this.text);
}

Future<MobileOcrResult?> recognizeTimetableImage() async {
  if (kIsWeb ||
      ![
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform)) {
    throw const FormatException(
      'OCR ảnh chạy trên Android/iOS. Bạn có thể dán văn bản OCR để phân tích.',
    );
  }
  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['png', 'jpg', 'jpeg'],
    withData: false,
  );
  if (picked == null) return null;
  final file = picked.files.single;
  if (file.path == null || file.size > 20 * 1024 * 1024) {
    throw const FormatException('Chọn ảnh PNG/JPG rõ nét, tối đa 20 MB.');
  }
  return recognizeTimetablePath(file.path!);
}

Future<MobileOcrResult> recognizeTimetablePath(String path) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    final words = [
      for (final block in result.blocks)
        for (final line in block.lines)
          for (final word in line.elements)
            {
              'text': word.text,
              'x': word.boundingBox.left,
              'y': word.boundingBox.top,
            },
    ];
    final text = OcrLayout.reconstruct({
      'text': result.text,
      'words': words,
    }).trim();
    if (text.isEmpty) {
      throw const FormatException(
        'Không đọc được chữ. Chọn ảnh rõ hơn hoặc dán văn bản OCR.',
      );
    }
    return MobileOcrResult(path, text);
  } finally {
    await recognizer.close();
  }
}
