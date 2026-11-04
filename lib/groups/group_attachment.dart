import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

const groupAttachmentMaxBytes = 512000;
const groupAttachmentExtensions = [
  'pdf',
  'txt',
  'png',
  'jpg',
  'jpeg',
  'xlsx',
  'docx',
  'csv',
];

Future<Map<String, dynamic>> readGroupAttachment(PlatformFile file) async {
  if (file.name.isEmpty ||
      file.name.length > 120 ||
      RegExp(r'[\x00-\x1f\\/]').hasMatch(file.name) ||
      !groupAttachmentExtensions.contains(file.extension?.toLowerCase())) {
    throw const FormatException(
      'Chọn PDF, ảnh, Word, Excel, TXT hoặc CSV. Tên tệp tối đa 120 ký tự.',
    );
  }
  if (file.size > groupAttachmentMaxBytes) {
    throw const FormatException('Tệp tối đa 500 KB.');
  }
  final bytes = BytesBuilder(copy: false);
  if (file.bytes != null) {
    if (file.bytes!.length > groupAttachmentMaxBytes) {
      throw const FormatException('Tệp tối đa 500 KB.');
    }
    bytes.add(file.bytes!);
  } else if (file.readStream != null) {
    await for (final chunk in file.readStream!) {
      if (bytes.length + chunk.length > groupAttachmentMaxBytes) {
        throw const FormatException('Tệp tối đa 500 KB.');
      }
      bytes.add(chunk);
    }
  } else {
    throw const FormatException(
      'Chưa đọc được tệp. Chọn lại tệp đã tải về máy.',
    );
  }
  if (bytes.isEmpty) {
    throw const FormatException('Tệp đang rỗng. Chọn tệp có nội dung.');
  }
  final content = bytes.takeBytes();
  return {
    'name': file.name,
    'size': content.length,
    'base64': base64Encode(content),
  };
}
