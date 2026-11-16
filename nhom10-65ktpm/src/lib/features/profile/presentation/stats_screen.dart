import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/ui/widgets.dart';
import '../../progress/data/progress_service.dart';
import '../../progress/domain/progress_rules.dart';

const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// Weekly statistics (words, listening minutes, pronunciation) and badges.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(progressSnapshotProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê học tập')),
      body: snapAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (s) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                _Pill(Icons.bolt, '${s.totalXp} XP'),
                _Pill(Icons.military_tech, 'Cấp ${s.level.level}'),
                _Pill(Icons.local_fire_department, 'Chuỗi ${s.streak} ngày'),
                _Pill(Icons.emoji_events_outlined, 'Dài nhất ${s.longestStreak} ngày'),
                _Pill(Icons.calendar_view_week, 'Tuần này ${s.weekXp} XP'),
              ]),
            ),
            _ChartCard(
              title: 'Số từ đã học (7 ngày)',
              week: s.week,
              value: (d) => d.wordsSaved.toDouble(),
              color: Colors.teal,
              format: (v) => v.toInt().toString(),
            ),
            _ChartCard(
              title: 'Số phút nghe (7 ngày)',
              week: s.week,
              value: (d) => double.parse(d.listenMinutes.toStringAsFixed(1)),
              color: Colors.indigo,
              format: (v) => v.toStringAsFixed(1),
            ),
            _ChartCard(
              title: 'Điểm phát âm trung bình (7 ngày)',
              week: s.week,
              value: (d) => d.pronunciationAvg ?? 0,
              color: Colors.deepOrange,
              format: (v) => v.toStringAsFixed(0),
              maxY: 100,
            ),
            _ChartCard(
              title: 'XP mỗi ngày (7 ngày)',
              week: s.week,
              value: (d) => d.xp.toDouble(),
              color: Colors.amber.shade800,
              format: (v) => v.toInt().toString(),
            ),
            const SectionTitle('Huy hiệu'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final b in AchievementBadge.values)
                    _BadgeTile(badge: b, unlockedAt: s.badges[b]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) =>
      Chip(avatar: Icon(icon, size: 18), label: Text(text));
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.week,
    required this.value,
    required this.color,
    required this.format,
    this.maxY,
  });

  final String title;
  final List<DayStats> week;
  final double Function(DayStats) value;
  final Color color;
  final String Function(double) format;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final values = week.map(value).toList();
    final top = maxY ?? (values.fold<double>(0, (a, b) => a > b ? a : b) * 1.25).clamp(1, double.infinity);
    final total = values.fold<double>(0, (a, b) => a + b);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.textTheme.titleSmall),
            Text(maxY == null ? 'Tổng: ${format(total)}' : 'Cao nhất: ${format(values.reduce((a, b) => a > b ? a : b))}',
                style: t.textTheme.labelSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  maxY: top.toDouble(),
                  minY: 0,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                        format(rod.toY),
                        TextStyle(color: t.colorScheme.onInverseSurface),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= week.length) return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(_weekdays[week[i].day.weekday - 1],
                                style: t.textTheme.labelSmall),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < values.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: values[i],
                          color: color,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, this.unlockedAt});

  final AchievementBadge badge;
  final DateTime? unlockedAt;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final on = unlockedAt != null;
    return Tooltip(
      message: badge.description,
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: on ? t.colorScheme.tertiaryContainer : t.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(on ? Icons.workspace_premium : Icons.lock_outline,
              color: on ? Colors.amber.shade800 : t.colorScheme.outline, size: 32),
          const SizedBox(height: 4),
          Text(badge.title,
              textAlign: TextAlign.center,
              style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text(
            on
                ? '${unlockedAt!.day}/${unlockedAt!.month}/${unlockedAt!.year}'
                : badge.description,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.labelSmall,
          ),
        ]),
      ),
    );
  }
}
