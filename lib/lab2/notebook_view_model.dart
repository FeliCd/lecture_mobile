import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';
import 'lecturer_workspace_store.dart';

typedef NotebookKey = ({String uid, String noteId});

class NotebookState {
  final bool loading, loadFailed, saveFailed;
  final int pending;
  const NotebookState({
    this.loading = true,
    this.loadFailed = false,
    this.saveFailed = false,
    this.pending = 0,
  });
  String get status => loading
      ? 'Đang mở sổ tay…'
      : loadFailed
      ? 'Không mở được sổ tay. Thử tải lại; dữ liệu cũ được giữ nguyên.'
      : saveFailed
      ? 'Chưa lưu được. Giữ màn hình này và bấm thử lại.'
      : pending > 0
      ? 'Đang lưu trên máy…'
      : 'Đã lưu trên máy • Chưa đồng bộ';
}

final notebookProvider = NotifierProvider.autoDispose
    .family<NotebookController, NotebookState, NotebookKey>(
      NotebookController.new,
    );

class NotebookController extends Notifier<NotebookState> {
  final NotebookKey key;
  NotebookController(this.key);
  int _revision = 0;
  @override
  NotebookState build() => const NotebookState();

  Future<Data?> load() async {
    state = const NotebookState();
    try {
      final data = await ref.read(workspaceStoreProvider(key.uid)).read();
      if (!ref.mounted) return null;
      state = const NotebookState(loading: false);
      return data.notes[key.noteId] ?? <String, dynamic>{};
    } catch (_) {
      if (ref.mounted) {
        state = const NotebookState(loading: false, loadFailed: true);
      }
      return null;
    }
  }

  Future<void> save(Data note) async {
    if (state.loading || state.loadFailed) return;
    final revision = ++_revision;
    state = NotebookState(
      loading: false,
      pending: state.pending + 1,
      saveFailed: state.saveFailed,
    );
    var failed = false;
    try {
      // Serialize through WorkspaceStore; copy lists so later checkbox edits do
      // not mutate an earlier queued write.
      await ref.read(workspaceStoreProvider(key.uid)).saveNote(key.noteId, {
        ...note,
        if (note['checkedPrep'] is List)
          'checkedPrep': List<String>.from(note['checkedPrep'] as List),
      });
    } catch (_) {
      failed = true;
    } finally {
      if (ref.mounted) {
        state = NotebookState(
          loading: false,
          pending: state.pending - 1,
          saveFailed: revision == _revision ? failed : state.saveFailed,
        );
      }
    }
  }
}
