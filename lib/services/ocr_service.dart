import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'schedule_parser.dart';

class OcrService {
  final TextRecognizer _recognizer;

  OcrService({TextRecognitionScript script = TextRecognitionScript.latin})
      : _recognizer = TextRecognizer(script: script);

  /// Process image file and extract raw text
  Future<String> processImagePath(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    final recognizedText = await _recognizer.processImage(inputImage);
    return recognizedText.text;
  }

  /// Recognize image and parse directly into schedule draft items
  Future<List<ParsedScheduleItem>> scanAndParseSchedule(
    String path, {
    String defaultSemester = '',
  }) async {
    final text = await processImagePath(path);
    return ScheduleParser.parseOcrText(text, defaultSemester: defaultSemester);
  }

  /// Clean up native resources
  Future<void> dispose() async {
    await _recognizer.close();
  }
}
