import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/attendance.dart';
import '../../../data/models/student.dart';
import '../../../data/models/tg.dart';
import '../../../data/sheets/google_attendance_data_source.dart';
import '../../../presentation/providers/attendance_provider.dart';
import '../../../presentation/providers/student_provider.dart';
import '../../../presentation/providers/tg_provider.dart';
import '../../../shared/widgets/page_container.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/stat_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TgProvider>().startListening();
      context.read<StudentProvider>().startListening();
      context.read<AttendanceProvider>().listenForDate(_selectedDate);
    });
  }

  Future<void> _refresh() async {
    await context.read<GoogleAttendanceDataSource>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<TgProvider, StudentProvider, AttendanceProvider>(
      builder: (
        context,
        tgProvider,
        studentProvider,
        attendanceProvider,
        _,
      ) {
        final tgs = tgProvider.items;
        final students = studentProvider.items;
        final attendance = attendanceProvider.items;

        final presentCount = attendance
            .where((item) => item.status == AttendanceStatus.present)
            .length;
        final absentCount = attendance
            .where((item) => item.status == AttendanceStatus.absent)
            .length;
        final totalMarked = presentCount + absentCount;
        final attendanceRate =
            students.isEmpty ? 0.0 : presentCount / students.length * 100;

        final loading = tgProvider.loading ||
            studentProvider.loading ||
            attendanceProvider.loading;
        final error = tgProvider.error ??
            studentProvider.error ??
            attendanceProvider.error;

        return PageContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: SectionHeader(
                      title: 'Overview',
                      subtitle:
                          'Monitor TG and student attendance from one place.',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: loading ? null : _refresh,
                    icon: const Icon(
                      Icons.refresh_outlined,
                      size: 18,
                    ),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (error != null)
                _ErrorBanner(
                  message: error.toString(),
                  onRetry: _refresh,
                ),
              _DashboardStats(
                totalTgs: tgs.length,
                totalStudents: students.length,
                presentToday: presentCount,
                attendanceRate: attendanceRate,
                loading: loading,
              ),
              const SizedBox(height: 28),
              _DashboardDetails(
                attendance: attendance,
                totalStudents: students.length,
                presentCount: presentCount,
                absentCount: absentCount,
                totalMarked: totalMarked,
                loading: loading,
              ),
              const SizedBox(height: 20),
              _StudentsByTgCard(
                students: students,
                tgs: tgs,
                loading: loading,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardStats extends StatelessWidget {
  const _DashboardStats({
    required this.totalTgs,
    required this.totalStudents,
    required this.presentToday,
    required this.attendanceRate,
    required this.loading,
  });

  final int totalTgs;
  final int totalStudents;
  final int presentToday;
  final double attendanceRate;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1150
            ? 4
            : constraints.maxWidth >= 700
                ? 2
                : 1;

        final cards = [
          StatCard(
            title: 'Total TGs',
            value: loading ? '...' : '$totalTgs',
            subtitle: 'TG records from Google Sheets',
            icon: Icons.groups_outlined,
          ),
          StatCard(
            title: 'Total Students',
            value: loading ? '...' : '$totalStudents',
            subtitle: 'Student records from Google Sheets',
            icon: Icons.school_outlined,
          ),
          StatCard(
            title: 'Present Today',
            value: loading ? '...' : '$presentToday',
            subtitle: 'Present attendance records',
            icon: Icons.person_outline,
          ),
          StatCard(
            title: 'Attendance Rate',
            value: loading ? '...' : '${attendanceRate.toStringAsFixed(1)}%',
            subtitle: 'Present / total students',
            icon: Icons.trending_up_outlined,
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: columns == 1 ? 3.0 : 1.9,
          ),
          itemBuilder: (_, index) => cards[index],
        );
      },
    );
  }
}

class _DashboardDetails extends StatelessWidget {
  const _DashboardDetails({
    required this.attendance,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    required this.totalMarked,
    required this.loading,
  });

  final List<Attendance> attendance;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final int totalMarked;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              _AttendanceSummaryCard(
                presentCount: presentCount,
                absentCount: absentCount,
                totalMarked: totalMarked,
                totalStudents: totalStudents,
                loading: loading,
              ),
              const SizedBox(height: 16),
              _RecentActivityCard(
                attendance: attendance,
                loading: loading,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _AttendanceSummaryCard(
                presentCount: presentCount,
                absentCount: absentCount,
                totalMarked: totalMarked,
                totalStudents: totalStudents,
                loading: loading,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _RecentActivityCard(
                attendance: attendance,
                loading: loading,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AttendanceSummaryCard extends StatelessWidget {
  const _AttendanceSummaryCard({
    required this.presentCount,
    required this.absentCount,
    required this.totalMarked,
    required this.totalStudents,
    required this.loading,
  });

  final int presentCount;
  final int absentCount;
  final int totalMarked;
  final int totalStudents;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final presentPercentage =
        totalStudents == 0 ? 0.0 : presentCount / totalStudents * 100;
    final absentPercentage =
        totalStudents == 0 ? 0.0 : absentCount / totalStudents * 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Attendance",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Live attendance summary from Google Sheets.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 24),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (totalMarked == 0)
              const _EmptyDashboardState(
                icon: Icons.fact_check_outlined,
                title: 'No attendance marked',
                message: 'There are no attendance records for today.',
              )
            else ...[
              _ProgressRow(
                label: 'Present',
                value: presentCount,
                total: totalStudents,
                percentage: presentPercentage,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 16),
              _ProgressRow(
                label: 'Absent',
                value: absentCount,
                total: totalStudents,
                percentage: absentPercentage,
                icon: Icons.cancel_outlined,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(label: 'Marked', value: '$totalMarked'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child:
                        _MiniStat(label: 'Students', value: '$totalStudents'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.total,
    required this.percentage,
    required this.icon,
  });

  final String label;
  final int value;
  final int total;
  final double percentage;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);

    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$value (${percentage.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(value: progress, minHeight: 8),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.attendance,
    required this.loading,
  });

  final List<Attendance> attendance;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final recent = attendance.reversed.take(6).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Latest attendance records for today.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 20),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (recent.isEmpty)
              const _EmptyDashboardState(
                icon: Icons.history_outlined,
                title: 'No recent activity',
                message: 'Attendance activity will appear here.',
              )
            else
              Column(
                children: [
                  for (var i = 0; i < recent.length; i++) ...[
                    _ActivityItem(attendance: recent[i]),
                    if (i != recent.length - 1) const Divider(height: 20),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.attendance});

  final Attendance attendance;

  @override
  Widget build(BuildContext context) {
    final isPresent = attendance.status == AttendanceStatus.present;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isPresent
                ? Colors.green.withValues(alpha: 0.08)
                : Colors.red.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPresent ? Icons.check : Icons.close,
            size: 18,
            color: isPresent ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attendance.studentId,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 3),
              Text(
                'TG ${attendance.tgId}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ),
        ),
        Text(
          isPresent ? 'Present' : 'Absent',
          style: TextStyle(
            color: isPresent ? Colors.green : Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StudentsByTgCard extends StatelessWidget {
  const _StudentsByTgCard({
    required this.students,
    required this.tgs,
    required this.loading,
  });

  final List<Student> students;
  final List<Tg> tgs;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final student in students) {
      final tgId = student.assignedTgId;
      if (tgId == null || tgId.trim().isEmpty) continue;
      counts[tgId] = (counts[tgId] ?? 0) + 1;
    }

    final rows = tgs
        .map(
          (tg) => _TgStudentCount(
            tgId: tg.tgId,
            tgName: tg.name,
            count: counts[tg.tgId] ?? 0,
          ),
        )
        .toList();

    final knownTgIds = tgs.map((tg) => tg.tgId).toSet();
    rows.addAll(
      counts.entries.where((entry) => !knownTgIds.contains(entry.key)).map(
            (entry) => _TgStudentCount(
              tgId: entry.key,
              tgName: 'TG record not found',
              count: entry.value,
            ),
          ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Students by TG',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Current student distribution from Google Sheets.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (rows.isEmpty)
              const _EmptyDashboardState(
                icon: Icons.groups_outlined,
                title: 'No TG records',
                message: 'TG distribution will appear here.',
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 3
                      : constraints.maxWidth >= 560
                          ? 2
                          : 1;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 4.5,
                    ),
                    itemBuilder: (context, index) {
                      return _TgStudentCountTile(item: rows[index]);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TgStudentCount {
  const _TgStudentCount({
    required this.tgId,
    required this.tgName,
    required this.count,
  });

  final String tgId;
  final String tgName;
  final int count;
}

class _TgStudentCountTile extends StatelessWidget {
  const _TgStudentCountTile({required this.item});

  final _TgStudentCount item;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.groups_outlined,
              size: 18,
              color: primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.tgId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  item.tgName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${item.count}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyDashboardState extends StatelessWidget {
  const _EmptyDashboardState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
