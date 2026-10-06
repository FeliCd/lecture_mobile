import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../api/repository.dart';
import '../../core/config.dart';
import '../../core/widgets.dart';
import '../../models/domain.dart';

class QrScreen extends StatefulWidget {
  final LecturerRepository repo;
  final Lecturer lecturer;
  final TeachingClass cls;
  final String sessionId;
  const QrScreen({
    super.key,
    required this.repo,
    required this.lecturer,
    required this.cls,
    required this.sessionId,
  });
  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> with WidgetsBindingObserver {
  SessionAttendance? data;
  String? error;
  bool busy = false, foreground = true;
  Timer? timer;
  int ticks = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !foreground) return;
      setState(() => ticks++);
      if (ticks % 15 == 0 && !busy && error == null) load();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      setState(() => data = null);
      load();
    } else if (mounted) {
      setState(() => data = null);
    }
  }

  Future<void> load({bool rotate = false, bool? secret}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (rotate && data != null) {
        await widget.repo.rotate(
          data!.session,
          secret: secret ?? data!.session.currentSecretCode.isNotEmpty,
        );
      }
      final fresh = await widget.repo.attendance(
        widget.cls,
        widget.sessionId,
        widget.lecturer.lecturerId,
      );
      // Validate configuration before showing a token.
      checkinUri(AppConfig.checkinUrl, fresh.session);
      if (mounted && foreground) {
        setState(() {
          data = fresh;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = safeMessage(e);
          data = null;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = data?.session;
    final expiry = session == null
        ? null
        : DateTime.tryParse(session.tokenExpiredAt);
    final remaining = expiry?.difference(DateTime.now().toUtc()).inSeconds ?? 0;
    final usable =
        foreground &&
        !busy &&
        session != null &&
        session.isOpen &&
        remaining > 0 &&
        session.currentToken.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('QR attendance')),
      body: SafeArea(
        child: error != null
            ? MessagePanel(message: error!, action: load)
            : session == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    '${widget.cls.subjectCode} · ${widget.cls.classCode}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('${session.date} · Slot ${session.slot}'),
                  const SizedBox(height: 20),
                  if (usable)
                    Center(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(16),
                        child: Semantics(
                          label:
                              'Student attendance QR code. Expires in $remaining seconds.',
                          child: QrImageView(
                            data: checkinUri(
                              AppConfig.checkinUrl,
                              session,
                            ).toString(),
                            size: 250,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else
                    MessagePanel(
                      message: busy
                          ? 'Refreshing attendance…'
                          : session.isOpen
                          ? 'QR expired. Generate a new code to continue.'
                          : 'This session is closed.',
                    ),
                  const SizedBox(height: 16),
                  if (usable)
                    Text(
                      'Expires in $remaining seconds',
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    '${data!.count('PRESENT')} / ${data!.roster.length} present',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Students use the existing check-in page, sign in with their school Google account and confirm their presence. Attendance refreshes every 15 seconds.',
                    textAlign: TextAlign.center,
                  ),
                  if (session.isOpen) ...[
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: busy ? null : () => load(rotate: true),
                      child: const Text('Generate new QR'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Require secret code'),
                      value: session.currentSecretCode.isNotEmpty,
                      onChanged: busy
                          ? null
                          : (value) => load(rotate: true, secret: value),
                    ),
                    if (usable && session.currentSecretCode.isNotEmpty)
                      Text(
                        session.currentSecretCode,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}
