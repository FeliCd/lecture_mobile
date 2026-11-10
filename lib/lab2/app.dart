import 'motion.dart';
import 'auth_view_model.dart';
import 'dart:async';
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
import 'quick_attendance.dart';
import 'attendance_follow_up.dart';
import 'dart:convert';
import 'timetable_domain.dart';
import 'timetable_card.dart';
import 'profile_academic_term.dart';
import '../cloud/cloud_pages.dart';
import '../cloud/cloud_services.dart';
import '../cloud/cloud_view_model.dart';
import '../cloud/cloud_diagnostics.dart';
import '../cloud/push_notifications.dart';
import '../groups/study_groups.dart';

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
  final messenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<void>? pushChanges;
  late GoRouter router;
  @override
  void initState() {
    super.initState();
    pushChanges = PushNotifications.instance.changes.stream.listen((_) {
      if (!mounted || ref.read(profileProvider).value?.isLecturer != true) {
        return;
      }
      messenger.currentState?.showSnackBar(
        SnackBar(
          content: const Text('Có thông báo mới trong trung tâm thông báo.'),
          action: SnackBarAction(
            label: 'Xem',
            onPressed: () => router.push('/notifications'),
          ),
        ),
      );
    });
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
          builder: (_, _) => CampusScaffold(
            appBar: AppBar(title: const Text('Lịch dạy')),
            body: LecturerTimetable(user: ref.read(profileProvider).value!),
          ),
        ),
        GoRoute(
          path: '/class/:id',
          builder: (_, s) => ClassPage(
            classId: s.pathParameters['id']!,
            initialTab: int.tryParse(s.uri.queryParameters['tab'] ?? '') ?? 0,
          ),
        ),
        GoRoute(
          path: '/chat/:classId/:groupId',
          builder: (context, s) => CampusScaffold(
            appBar: AppBar(
              title: const Text('Tin nhắn nhóm'),
              leading: IconButton(
                tooltip: 'Về trang chủ',
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined),
              ),
            ),
            body: StudyGroups(
              classId: s.pathParameters['classId']!,
              initialGroupId: s.pathParameters['groupId'],
              groupChanges: PushNotifications.instance.groupChanges.stream,
              call: (method, data) => ref.read(repositoryProvider).call(
                'groupCall',
                {'method': method, 'data': data},
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/host/:id',
          builder: (_, s) => useSharedDesktop
              ? LiveAttendancePage(sessionId: s.pathParameters['id']!)
              : AttendanceHost(sessionId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/quick',
          builder: (_, s) => QuickAttendancePage(
            selector: quickSelectorFromQuery(s.uri.queryParameters),
            uid: ref.read(profileProvider).value!.uid,
          ),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        GoRoute(
          path: '/cloud-settings',
          builder: (_, _) => const CloudSettingsPage(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) =>
              NotificationCenter(uid: PushNotifications.instance.uid ?? ''),
        ),
        GoRoute(
          path: '/attendance-reminder',
          builder: (_, s) {
            final d = Map<String, dynamic>.from(
              jsonDecode(s.uri.queryParameters['data']!) as Map,
            );
            final p = TeachingPeriod(
              day: DateTime.parse(d['day']),
              classId: d['classId'],
              sessionId: d['sessionId'],
              scheduleId: d['scheduleId'],
              exceptionId: d['exceptionId'],
              classCode: d['classCode'],
              subjectId: d['subjectId'],
              subjectName: d['subjectName'],
              room: d['room'],
              term: d['term'],
              slot: d['slot'],
              start: d['start'],
              end: d['end'],
              recurring: d['sessionId'] == null,
            );
            return CampusScaffold(
              appBar: AppBar(
                title: const Text('Kiểm tra buổi học'),
                leading: IconButton(
                  icon: const Icon(Icons.home_outlined),
                  onPressed: () => router.go('/'),
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Lịch đã tải · ${p.sessionDate}'),
                  TeachingPeriodCard(period: p, showAction: true),
                  const Text(
                    'Mở buổi học để lấy trạng thái mới nhất từ hệ thống.',
                  ),
                ],
              ),
            );
          },
        ),
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
    pushChanges?.cancel();
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
        ref.invalidate(reportUploadProvider);
        ref.invalidate(cloudDiagnosticsProvider);
        if (next.value?.isLecturer == true) {
          unawaited(PushNotifications.instance.activateGroupPush());
          PushNotifications.instance.onOpen = (route) => router.go(route);
          final pending = PushNotifications.instance.pendingRoute;
          PushNotifications.instance.pendingRoute = null;
          if (pending != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) router.go(pending);
            });
          }
        } else {
          PushNotifications.instance.onOpen = null;
        }
        LecturerReminders.instance.onOpen = (id) => id.startsWith('lesson:')
            ? router.go(
                '/attendance-reminder?data=${Uri.encodeQueryComponent(id.substring(7))}',
              )
            : router.go('/workspace?task=${Uri.encodeQueryComponent(id)}');
        LecturerReminders.instance.onOpenAttendance = (selector) =>
            router.push(quickAttendanceLocation(selector));
        LecturerReminders.instance
            .activate(next.value?.isLecturer == true ? uid : null)
            .catchError((Object _) {});
      }
    });
    return MaterialApp.router(
      scaffoldMessengerKey: messenger,
      title: 'FAP Attendance',
      builder: (context, child) {
        final user = ref.watch(profileProvider).value;
        return user?.isLecturer == true
            ? AttendanceReminderCoordinator(
                key: ValueKey(user!.uid),
                user: user,
                child: child!,
              )
            : child!;
      },
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

class CampusLogin extends ConsumerWidget {
  const CampusLogin({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(authActionsProvider);
    final busy = action.busy;
    final profile = ref.watch(profileProvider);
    final failure = action.error ?? profile.error;
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
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              'F.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'FAP Smart Lecturer',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cổng thông tin & Điểm danh giảng viên FPT Education',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 32),
                  CampusCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Xác thực quyền giảng viên',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Truy cập lịch giảng, quản lý lớp & điểm danh học kỳ hiện hành',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              Image.asset(
                                'assets/stitch-campus.jpg',
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  color: const Color(0xBB172033),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.school_outlined,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'FPT University · Giảng dạy & kết nối',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
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
                    onPressed: () =>
                        ref.read(authActionsProvider.notifier).login(),
                  ),
                  if (profile.hasError)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () =>
                                ref.read(authActionsProvider.notifier).logout(),
                      child: const Text('Dùng tài khoản Google khác'),
                    ),
                  const SizedBox(height: 16),
                  const CampusInfoBanner(
                    icon: Icons.verified_user_outlined,
                    title: 'Đăng nhập an toàn với Google',
                    subtitle:
                        'Chỉ tài khoản Google đã được cấp quyền giảng viên mới có thể truy cập.',
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
  void initState() {
    super.initState();
    CloudTelemetry.event('view_teaching_day');
  }

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
          title: CampusBrandTitle(section: labels[tab]),
          actions: [
            if (useSharedDesktop)
              IconButton(
                tooltip: 'Cập nhật dữ liệu Desktop',
                onPressed: sharedDesktop.refresh,
                icon: const Icon(Icons.sync),
              ),
            IconButton(
              tooltip: 'Thông báo',
              onPressed: () => context.push('/notifications'),
              icon: const Icon(Icons.notifications_outlined),
            ),
            IconButton(
              tooltip: 'Tài khoản và giao diện',
              onPressed: () => context.push('/settings'),
              icon: CircleAvatar(
                radius: 17,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  user.name.trim().isEmpty
                      ? 'U'
                      : user.name.trim().substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: CampusPageBody(
          child: CampusEntrance(
            trigger: tab,
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
    return CampusScaffold(
      appBar: AppBar(title: const Text('Tài khoản và cài đặt')),
      body: ListView(
        padding: CampusSpace.pageInsets,
        children: [
          const CampusSectionHeader(title: 'Hồ sơ giảng viên'),
          CampusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u?.name ?? '',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: CampusSpace.xs),
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
          const CampusSectionHeader(title: 'Tùy chọn'),
          if (u?.isLecturer == true) ProfileAcademicTermSelector(user: u!),
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
          const CampusSectionHeader(title: 'Công cụ và dịch vụ'),
          if (u?.isLecturer == true) WorkspaceShortcut(user: u!),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Thông báo'),
            onTap: () => context.push('/notifications'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Dịch vụ đám mây'),
            onTap: () => context.push('/cloud-settings'),
          ),
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
          const SizedBox(height: CampusSpace.lg),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
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
              if (!await ref.read(authActionsProvider.notifier).logout()) {
                throw ref.read(authActionsProvider).error ??
                    StateError('Đang xử lý đăng nhập.');
              }
            }),
          ),
        ],
      ),
    );
  }
}
