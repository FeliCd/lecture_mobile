import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'domain.dart';

List<String> academicTerms(Iterable<Data> rows) {
  final values = rows
      .map((r) => '${r['term'] ?? ''}'.trim())
      .where((term) => term.isNotEmpty)
      .toSet()
      .toList();
  values.sort((a, b) {
    int rank(String value) {
      final match = RegExp(
        r'^(SP|SPRING|SU|SUMMER|FA|FALL|AUTUMN)\s*(\d{2}|\d{4})$',
        caseSensitive: false,
      ).firstMatch(value);
      if (match == null) return 0;
      var year = int.parse(match[2]!);
      if (year < 100) year += 2000;
      final season = match[1]!.toUpperCase();
      return year * 10 +
          (season.startsWith('SP')
              ? 1
              : season.startsWith('SU')
              ? 2
              : 3);
    }

    final order = rank(a).compareTo(rank(b));
    return order == 0 ? a.compareTo(b) : order;
  });
  return values;
}

String? resolveAcademicTerm(List<String> terms, String? saved) =>
    saved != null && saved.trim().isNotEmpty
    ? saved
    : terms.isEmpty
    ? null
    : terms.last;

final selectedAcademicTermProvider =
    AsyncNotifierProvider.family<AcademicTermSettings, String?, String>(
      AcademicTermSettings.new,
    );

class AcademicTermSettings extends AsyncNotifier<String?> {
  final String uid;
  AcademicTermSettings(this.uid);
  static String preferenceKey(String uid) =>
      'academic-term-${sha256.convert(utf8.encode(uid))}';
  @override
  Future<String?> build() async {
    try {
      return (await SharedPreferences.getInstance()).getString(
        preferenceKey(uid),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> select(String term) async {
    if (term.trim().isEmpty) throw ArgumentError('EMPTY_TERM');
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(preferenceKey(uid), term)) {
      throw StateError('SAVE_FAILED');
    }
    if (ref.mounted) state = AsyncData(term);
  }
}
