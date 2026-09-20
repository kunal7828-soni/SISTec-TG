import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../presentation/providers/attendance_provider.dart';
import '../../../presentation/providers/student_provider.dart';
import '../../../presentation/providers/tg_provider.dart';
import '../../../data/models/attendance.dart';
import '../../../data/models/tg.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTgId;
  String? _savingStudentId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<TgProvider>().startListening();
      context.read<StudentProvider>().startListening();
      context.read<AttendanceProvider>().listenForDate(
            _selectedDate,
          );
    });
  }

  void _changeDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });

    context.read<AttendanceProvider>().listenForDate(date);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date == null || !mounted) {
      return;
    }

    _changeDate(date);
  }

  Future<void> _toggleAttendance(Attendance attendance) async {
    if (_savingStudentId != null) {
      return;
    }

    final newStatus = attendance.status == AttendanceStatus.present
        ? AttendanceStatus.absent
        : AttendanceStatus.present;

    setState(() {
      _savingStudentId = attendance.studentId;
    });

    try {
      final updated = attendance.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );

      await context.read<AttendanceProvider>().save(updated);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == AttendanceStatus.present
                ? 'Attendance marked Present.'
                : 'Attendance marked Absent.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update attendance: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingStudentId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AttendanceProvider, StudentProvider, TgProvider>(
      builder: (
        context,
        attendanceProvider,
        studentProvider,
        tgProvider,
        _,
      ) {
        if (attendanceProvider.loading && attendanceProvider.items.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (attendanceProvider.error != null &&
            attendanceProvider.items.isEmpty) {
          return _ErrorState(
            message: attendanceProvider.error.toString(),
            onRetry: () {
              attendanceProvider.listenForDate(
                _selectedDate,
              );
            },
          );
        }

        final students = studentProvider.items;
        final tgs = tgProvider.items;

        var attendance = attendanceProvider.items;

        if (_selectedTgId != null) {
          attendance = attendance
              .where(
                (item) => item.tgId == _selectedTgId,
              )
              .toList();
        }

        final studentById = {
          for (final student in students) student.studentId: student,
        };

        final presentCount = attendance
            .where(
              (item) => item.status.name == 'present',
            )
            .length;

        final absentCount = attendance
            .where(
              (item) => item.status.name == 'absent',
            )
            .length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1200,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Attendance',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Attendance loaded from Google Sheets.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: attendanceProvider.loading
                            ? null
                            : () {
                                attendanceProvider.listenForDate(
                                  _selectedDate,
                                );
                              },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _FilterCard(
                    selectedDate: _selectedDate,
                    selectedTgId: _selectedTgId,
                    tgs: tgs,
                    onDateTap: _pickDate,
                    onTgChanged: (value) {
                      setState(() {
                        _selectedTgId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Present',
                          value: presentCount,
                          icon: Icons.check_circle_outline,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Absent',
                          value: absentCount,
                          icon: Icons.cancel_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Marked',
                          value: attendance.length,
                          icon: Icons.fact_check_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Attendance List',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (attendance.isEmpty)
                            const _NoAttendanceState()
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'Student Name',
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Roll No.',
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'TG ID',
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Status',
                                    ),
                                  ),
                                ],
                                rows: attendance.map(
                                  (item) {
                                    final student = studentById[item.studentId];

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            student?.name ?? item.studentId,
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            student?.rollNumber ??
                                                item.studentId,
                                          ),
                                        ),
                                        DataCell(
                                          Text(item.tgId),
                                        ),
                                        DataCell(
                                          InkWell(
                                            onTap: _savingStudentId == null
                                                ? () => _toggleAttendance(item)
                                                : null,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            child: _savingStudentId ==
                                                    item.studentId
                                                ? const SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : _AttendanceBadge(
                                                    isPresent: item.status ==
                                                        AttendanceStatus
                                                            .present,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.selectedDate,
    required this.selectedTgId,
    required this.tgs,
    required this.onDateTap,
    required this.onTgChanged,
  });

  final DateTime selectedDate;
  final String? selectedTgId;
  final List<Tg> tgs;
  final VoidCallback onDateTap;
  final ValueChanged<String?> onTgChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onDateTap,
              icon: const Icon(
                Icons.calendar_today_outlined,
              ),
              label: Text(
                _formatDate(selectedDate),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                initialValue: selectedTgId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'TG',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All TGs'),
                  ),
                  ...tgs.map(
                    (tg) => DropdownMenuItem<String?>(
                      value: tg.tgId,
                      child: Text(
                        '${tg.tgId} - ${tg.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: onTgChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day-$month-${date.year}';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              icon,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceBadge extends StatelessWidget {
  const _AttendanceBadge({
    required this.isPresent,
  });

  final bool isPresent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isPresent
            ? Colors.green.withValues(alpha: 0.10)
            : Colors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPresent ? 'Present' : 'Absent',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}

class _NoAttendanceState extends StatelessWidget {
  const _NoAttendanceState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 46,
            ),
            SizedBox(height: 10),
            Text(
              'No attendance records found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'There are no P/A records for the selected date.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            const Text(
              'Could not load attendance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
