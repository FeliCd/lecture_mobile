import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'domain.dart';
import 'repository.dart';
import 'theme.dart';
import 'widgets.dart';
import 'classes.dart';
import 'attendance.dart';
import 'subject_updates.dart';
import 'desktop_sync.dart';
import 'class_attendance_overview.dart';
import 'dashboard_widgets.dart';
import 'timetable.dart';
import 'today.dart';
import 'live_attendance.dart';
import 'import_page.dart';
import 'roster_assignment.dart';
import 'lecturer_workspace.dart';
import 'lecturer_reminders.dart';

final themeProvider = NotifierProvider<ThemeSettings, ThemeMode>(
  ThemeSettings.new,
);

class ThemeSettings extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    restore();
    return ThemeMode.system;
  }

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    final index = p.getInt('campus-theme') ?? 0;
    if (ref.mounted) state = ThemeMode.values[index.clamp(0, 2)];
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await (await SharedPreferences.getInstance()).setInt(
      'campus-theme',
      mode.index,
    );
  }
}

class CampusApp extends ConsumerStatefulWidget {
  const CampusApp({super.key});
  @override
  ConsumerState<CampusApp> createState() => _CampusAppState();
}

class _CampusAppState extends ConsumerState<CampusApp> {
  final refresh = ValueNotifier<int>(0);
  late GoRouter router;
  @override
  void initState() {
    super.initState();
    router = GoRouter(
      refreshListenable: refresh,
      redirect: (context, state) {
        final profile = ref.read(profileProvider);
        final path = state.uri.path;
        if (!quizEnabled && path.startsWith('/quiz/')) return '/';
        if (profile.isLoading) return path == '/loading' ? null : '/loading';
        if (profile.hasError || profile.value == null) {
          return path == '/login' ? null : '/login';
        }
        if (!profile.value!.isLecturer) {
          return path == '/login' ? null : '/login';
        }
        if (path == '/login' || path == '/loading') return '/';
        if (path.startsWith('/host/') && !profile.value!.isLecturer) return '/';
        if (path == '/timetable' && !profile.value!.isLecturer) return '/';
        if (path == '/scan') return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/loading',
          builder: (_, _) =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
        ),
        GoRoute(path: '/login', builder: (_, _) => const CampusLogin()),
        GoRoute(path: '/', builder: (_, _) => const CampusShell()),
        GoRoute(
          path: '/timetable',
          builder: (_, _) => Scaffold(
            appBar: AppBar(title: const Text('Lịch dạy')),
            body: LecturerTimetable(user: ref.read(profileProvider).value!),
          ),
        ),
        GoRoute(
          path: '/class/:id',
          builder: (_, s) => ClassPage(classId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/host/:id',
          builder: (_, s) => useSharedDesktop
              ? LiveAttendancePage(sessionId: s.pathParameters['id']!)
              : AttendanceHost(sessionId: s.pathParameters['id']!),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        GoRoute(
          path: '/workspace',
          builder: (_, s) => LecturerWorkspacePage(
            user: ref.read(profileProvider).value!,
            selectedTask: s.uri.queryParameters['task'],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    router.dispose();
    refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileProvider, (previous, next) {
      refresh.value++;
      if (next.isLoading) return;
      final uid = next.value?.uid;
      if (uid != previous?.value?.uid) {
        LecturerReminders.instance.onOpen = (id) =>
            router.go('/workspace?task=${Uri.encodeQueryComponent(id)}');
        LecturerReminders.instance
            .activate(next.value?.isLecturer == true ? uid : null)
            .catchError((Object _) {});
      }
    });
    return MaterialApp.router(
      title: 'FAP Attendance',
      debugShowCheckedModeBanner: false,
      theme: campusTheme(Brightness.light),
      darkTheme: campusTheme(Brightness.dark),
      themeMode: ref.watch(themeProvider),
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    );
  }
}

class CampusLogin extends ConsumerStatefulWidget {
  const CampusLogin({super.key});
  @override
  ConsumerState<CampusLogin> createState() => _CampusLoginState();
}

class _CampusLoginState extends ConsumerState<CampusLogin> {
  bool busy = false;
  Object? error;
  Future<void> login() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ref.read(repositoryProvider).loginWithGoogle();
      if (mounted) ref.invalidate(profileProvider);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final failure = error ?? profile.error;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.school_outlined,
                      size: 40,
                      color: CampusColors.brand,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'FAP Attendance',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lecturer Companion',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lịch dạy và điểm danh, ngay trong tầm tay.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  if (failure != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        errorMessage(failure),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  AppPrimaryButton(
                    label: busy
                        ? 'Đang kết nối Google…'
                        : 'Tiếp tục với Google',
                    busy: busy,
                    onPressed: login,
                  ),
                  if (profile.hasError)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              await ref.read(repositoryProvider).logout();
                              if (mounted) {
                                ref.invalidate(profileProvider);
                                setState(() => error = null);
                              }
                            },
                      child: const Text('Dùng tài khoản Google khác'),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chỉ tài khoản Google đã được cấp quyền giảng viên mới có thể truy cập.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Trợ lý giảng dạy • FAP Attendance',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CampusShell extends ConsumerStatefulWidget {
  const CampusShell({super.key});
  @override
  ConsumerState<CampusShell> createState() => _CampusShellState();
}

class _CampusShellState extends ConsumerState<CampusShell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(profileProvider).value;
    if (user == null) return const Center(child: CampusLoadingState());
    const labels = ['Hôm nay', 'Lịch dạy', 'Lớp học', 'Cập nhật'];
    const icons = [
      Icons.home_outlined,
      Icons.calendar_month_outlined,
      Icons.groups_outlined,
      Icons.article_outlined,
    ];
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && tab != 0) setState(() => tab = 0);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(labels[tab]),
          actions: [
            if (useSharedDesktop)
              IconButton(
                tooltip: 'Cập nhật dữ liệu Desktop',
                onPressed: sharedDesktop.refresh,
                icon: const Icon(Icons.sync),
              ),
            IconButton(
              tooltip: 'Tài khoản và giao diện',
              onPressed: () => context.push('/settings'),
              icon: CircleAvatar(
                radius: 17,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  user.name.trim().isEmpty
                      ? 'U'
                      : user.name.trim().substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: IndexedStack(
                index: tab,
                children: [
                  TodayPanel(
                    user: user,
                    onTimetable: () => setState(() => tab = 1),
                  ),
                  LecturerTimetable(user: user),
                  ClassList(user: user),
                  SubjectUpdatesPage(user: user),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: List.generate(
            labels.length,
            (i) =>
                NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
          ),
        ),
      ),
    );
  }
}

class HomePanel extends ConsumerWidget {
  final UserProfile user;
  final VoidCallback? onOpenTimetable;
  const HomePanel({super.key, required this.user, this.onOpenTimetable});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        DashboardWelcome(name: user.name, lecturer: user.isLecturer),
        if (user.isLecturer)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: OutlinedButton.icon(
              onPressed: onOpenTimetable ?? () => context.push('/timetable'),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Xem thời khóa biểu'),
            ),
          ),
        if (!user.isLecturer)
          AppPrimaryButton(
            label: 'Quét QR điểm danh',
            onPressed: () => context.push('/scan'),
          ),
        LiveList(
          source: () => repo.classes(user),
          empty: 'Bạn chưa có lớp được phân công hoặc ghi danh.',
          builder: (classes) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardGrid(
                children: [
                  DashboardMetric(
                    value: '${classes.length}',
                    label: user.isLecturer ? 'Lớp phụ trách' : 'Lớp của bạn',
                    icon: Icons.groups_outlined,
                  ),
                  DashboardMetric(
                    value: '${user.subjectIds.length}',
                    label: 'Môn học',
                    icon: Icons.auto_stories_outlined,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              DashboardHeading(
                title: user.isLecturer ? 'Chuyên cần các lớp' : 'Lớp của bạn',
                subtitle: user.isLecturer
                    ? 'Tổng quan điểm danh và sinh viên cần hỗ trợ'
                    : 'Lịch học và hoạt động đang diễn ra',
              ),
              ...classes.map(
                (c) => Column(
                  children: [
                    if (user.isLecturer)
                      ClassAttendanceOverview(cls: c)
                    else
                      ClassTile(data: c),
                    ClassTodayPanel(cls: c, user: user),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ClassTodayPanel extends ConsumerWidget {
  final Data cls;
  final UserProfile user;
  const ClassTodayPanel({super.key, required this.cls, required this.user});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final today = localDate(DateTime.now()).split(' ').first;
    return Column(
      children: [
        LiveList(
          source: () =>
              repo.watch('classSessions', field: 'classId', equals: cls['id']),
          empty: '${cls['classCode']}: chưa có buổi học.',
          hideEmpty: true,
          builder: (sessions) {
            final current = sessions
                .where(
                  (s) =>
                      localDate(dateValue(s['startsAt'])).split(' ').first ==
                      today,
                )
                .toList();
            return Column(
              children: [
                if (current.isNotEmpty)
                  DashboardHeading(
                    title: 'Lịch học hôm nay',
                    subtitle: '${current.length} buổi • ${cls['classCode']}',
                  ),
                ...current.map(
                  (s) => CampusCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(attendanceSessionLabel(s, cls)),
                        Text(localDate(dateValue(s['startsAt']))),
                        if (user.isLecturer)
                          Wrap(
                            spacing: 8,
                            children: [
                              if (!useSharedDesktop)
                                OutlinedButton(
                                  onPressed: () => showDialog<void>(
                                    context: context,
                                    builder: (_) => OpenAttendanceDialog(
                                      sessionId: s['id'],
                                    ),
                                  ),
                                  child: const Text('Mở điểm danh'),
                                ),
                              TextButton(
                                onPressed: () =>
                                    context.push('/host/${s['id']}'),
                                child: const Text('Xem phiên'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        if (quizEnabled)
          LiveList(
            source: () =>
                repo.watch('quizzes', field: 'classId', equals: cls['id']),
            empty: 'Chưa có hoạt động.',
            hideEmpty: true,
            builder: (quizzes) => Column(
              children: quizzes
                  .where((q) => q['status'] == 'open')
                  .map(
                    (q) => CampusCard(
                      child: ListTile(
                        title: Text(q['question']),
                        subtitle: const Text('Hoạt động đang mở'),
                        onTap: () => context.push('/quiz/${q['id']}'),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(profileProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản và cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CampusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u?.name ?? ''),
                Text(
                  u?.email.isNotEmpty == true
                      ? u!.email
                      : 'Email chưa có trong hồ sơ',
                ),
                if (u?.lecturerId.isNotEmpty == true)
                  Text('Mã giảng viên: ${u!.lecturerId}'),
                if (u?.department.isNotEmpty == true) Text(u!.department),
              ],
            ),
          ),
          DropdownButtonFormField<ThemeMode>(
            isExpanded: true,
            style: Theme.of(context).textTheme.bodyLarge,
            initialValue: ref.watch(themeProvider),
            decoration: const InputDecoration(labelText: 'Giao diện'),
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('Theo thiết bị'),
              ),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Sáng')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Tối')),
            ],
            onChanged: (mode) {
              if (mode != null) ref.read(themeProvider.notifier).setMode(mode);
            },
          ),
          const SizedBox(height: 16),
          if (u?.isLecturer == true) WorkspaceShortcut(user: u!),
          CampusOutlineAction(
            onPressed: () => openImport(context),
            icon: Icons.document_scanner_outlined,
            label: 'Nhập lịch từ ảnh',
          ),
          if (u != null)
            LiveList(
              source: () => ref.read(repositoryProvider).classes(u),
              builder: (classes) => CampusOutlineAction(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => RosterAssignmentPage(classes: classes),
                  ),
                ),
                icon: Icons.table_chart_outlined,
                label: 'Nhập sinh viên từ Excel/CSV',
              ),
            ),
          AppPrimaryButton(
            label: 'Đăng xuất',
            onPressed: () => runAction(context, () async {
              if (!await campusConfirm(
                context,
                title: 'Đăng xuất?',
                message:
                    'Bạn sẽ cần đăng nhập Google để truy cập lại dữ liệu giảng dạy.',
                confirm: 'Đăng xuất',
              )) {
                return;
              }
              await ref.read(repositoryProvider).logout();
              ref.invalidate(profileProvider);
            }),
          ),
        ],
      ),
    );
  }
}
