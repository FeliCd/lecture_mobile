import 'package:flutter/material.dart';
import 'theme.dart';

class DashboardHeading extends StatelessWidget {
  final String title, subtitle;
  const DashboardHeading({
    super.key,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

class DashboardMetric extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color? color;
  const DashboardMetric({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(CampusRadius.card),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class DashboardGrid extends StatelessWidget {
  final List<Widget> children;
  const DashboardGrid({super.key, required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 700
          ? 4
          : constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.6
          ? 1
          : 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: children
            .map(
              (child) => SizedBox(
                width: (constraints.maxWidth - (columns - 1) * 12) / columns,
                child: child,
              ),
            )
            .toList(),
      );
    },
  );
}

class SoftLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  const SoftLabel(this.text, {super.key, this.color, this.icon});
  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardWelcome extends StatelessWidget {
  final String name;
  final bool lecturer;
  const DashboardWelcome({
    super.key,
    required this.name,
    required this.lecturer,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.only(bottom: 24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(CampusRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.school_outlined,
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'FAP SMART LECTURER',
                style: TextStyle(
                  color: Color(0xFFCFDBED),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: CampusColors.brand,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Xin chào,',
          style: TextStyle(color: Color(0xFFCFDBED), fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          lecturer
              ? 'Theo dõi chuyên cần và hỗ trợ sinh viên.'
              : 'Điểm danh và theo dõi hành trình học tập.',
          style: TextStyle(color: Color(0xFFCFDBED), height: 1.6, fontSize: 13),
        ),
      ],
    ),
  );
}
