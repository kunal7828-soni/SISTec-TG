import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../../data/models/attendance.dart';
import '../../../data/models/student.dart';
import '../../../data/models/tg.dart';
import '../../../data/sheets/google_attendance_data_source.dart';
import '../../../shared/widgets/page_container.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/stat_card.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime _from = _startOfDay(DateTime.now());
  DateTime _to = _startOfDay(DateTime.now());
  String? _selectedTgId;
  String? _selectedStudentId;
  bool _loading = true;
  Object? _error;

  List<Attendance> _attendance = const [];
  List<Student> _students = const [];
  List<Tg> _tgs = const [];

  GoogleAttendanceDataSource? _dataSource;

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dataSource != null) return;

    _dataSource = context.read<GoogleAttendanceDataSource>();
    _loadReport();
  }

  Future<void> _loadReport() async {
    final source = _dataSource;
    if (source == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await source.load(forceRefresh: true);

      if (!mounted) return;

      setState(() {
        _attendance = List<Attendance>.from(source.attendance);
        _students = List<Student>.from(source.students);
        _tgs = List<Tg>.from(source.tgs);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  List<Attendance> get _filteredAttendance {
    return _attendance.where((item) {
      final date = _startOfDay(item.date);
      if (date.isBefore(_from) || date.isAfter(_to)) return false;
      if (_selectedTgId != null && item.tgId != _selectedTgId) return false;
      if (_selectedStudentId != null && item.studentId != _selectedStudentId) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Student> get _filteredStudents {
    return _students.where((student) {
      if (_selectedTgId != null && student.assignedTgId != _selectedTgId) {
        return false;
      }
      if (_selectedStudentId != null &&
          student.studentId != _selectedStudentId) {
        return false;
      }
      return true;
    }).toList();
  }

  String _tgName(String tgId) {
    for (final tg in _tgs) {
      if (tg.tgId == tgId) return tg.name;
    }
    return tgId;
  }

  List<Attendance> get _todayAttendance {
    final today = _startOfDay(DateTime.now());
    return _attendance.where((item) => _startOfDay(item.date) == today).where(
      (item) {
        if (_selectedTgId != null && item.tgId != _selectedTgId) return false;
        if (_selectedStudentId != null &&
            item.studentId != _selectedStudentId) {
          return false;
        }
        return true;
      },
    ).toList();
  }

  List<Student> get _todayStudents {
    return _students.where((student) {
      if (_selectedTgId != null && student.assignedTgId != _selectedTgId) {
        return false;
      }
      if (_selectedStudentId != null &&
          student.studentId != _selectedStudentId) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _copyText(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard.')),
    );
  }

  String _todayDetailedText() {
    final date = _startOfDay(DateTime.now());
    final students = _todayStudents;
    final attendance = _todayAttendance;

    final byStudent = <String, Attendance>{
      for (final item in attendance) item.studentId: item,
    };

    final semesterGroups = <String, List<Student>>{};
    for (final student in students) {
      final semester = student.semester.trim().isEmpty
          ? 'Unknown Semester'
          : student.semester.trim();
      semesterGroups.putIfAbsent(semester, () => []).add(student);
    }

    final semesters = semesterGroups.keys.toList()
      ..sort((a, b) => _semesterSortKey(b).compareTo(_semesterSortKey(a)));

    final lines = <String>[
      'Today\'s Attendance ${_slashDate(date)}',
      '',
    ];

    for (var index = 0; index < semesters.length; index++) {
      final semester = semesters[index];
      final semesterStudents = semesterGroups[semester]!;
      final tgGroups = <String, List<Student>>{};

      for (final student in semesterStudents) {
        final tgId = student.assignedTgId ?? 'Unassigned';
        tgGroups.putIfAbsent(tgId, () => []).add(student);
      }

      lines.add(_semesterHeading(semester));
      lines.add('');

      final tgIds = tgGroups.keys.toList()..sort((a, b) => a.compareTo(b));

      for (final tgId in tgIds) {
        final groupStudents = tgGroups[tgId]!;
        final bySection = <String, List<Student>>{};

        for (final student in groupStudents) {
          final section = student.section.trim().isEmpty
              ? 'Section'
              : student.section.trim();
          bySection.putIfAbsent(section, () => []).add(student);
        }

        final sections = bySection.keys.toList()..sort();
        final presentParts = <String>[];
        var totalStudents = 0;

        for (final section in sections) {
          final sectionStudents = bySection[section]!;
          totalStudents += sectionStudents.length;

          final present = sectionStudents.where((student) {
            return byStudent[student.studentId]?.status ==
                AttendanceStatus.present;
          }).length;
          presentParts.add('$present');
        }

        final label = tgId == 'Unassigned'
            ? 'Unassigned'
            : '${_tgInitials(_tgName(tgId))} (${sections.join(' + ')})';

        lines.add('$label: ${presentParts.join('+')}/$totalStudents');
      }

      if (index != semesters.length - 1) {
        lines.add('-----------------------------------');
        lines.add('');
      }
    }

    return lines.join('\n');
  }

  String _todaySemesterText() {
    final date = _startOfDay(DateTime.now());
    final students = _todayStudents;
    final attendance = _todayAttendance;

    final presentIds = attendance
        .where((item) => item.status == AttendanceStatus.present)
        .map((item) => item.studentId)
        .toSet();

    final groups = <String, List<Student>>{};
    for (final student in students) {
      final semester = student.semester.trim().isEmpty
          ? 'Unknown Semester'
          : student.semester.trim();
      groups.putIfAbsent(semester, () => []).add(student);
    }

    final semesters = groups.keys.toList()
      ..sort((a, b) => _semesterSortKey(b).compareTo(_semesterSortKey(a)));

    final lines = <String>[
      'Today\'s attendance: ${_slashDate(date)}',
      '',
    ];

    for (final semester in semesters) {
      final group = groups[semester]!;
      final present = group
          .where((student) => presentIds.contains(student.studentId))
          .length;
      final total = group.length;
      final rate = total == 0 ? 0.0 : present / total * 100;

      lines.add(
        '$semester Sem: $present/$total (${_formatRate(rate)}%)',
      );
    }

    return lines.join('\n');
  }

  bool get _isTodayRange {
    final today = _startOfDay(DateTime.now());
    return _from == today && _to == today;
  }

  String _rangeText() {
    final grouped = <DateTime, List<Attendance>>{};

    for (final item in _filteredAttendance) {
      final date = _startOfDay(item.date);
      grouped.putIfAbsent(date, () => []).add(item);
    }

    final dates = grouped.keys.toList()..sort();
    final lines = <String>[
      'Attendance Report: ${_slashDate(_from)} - ${_slashDate(_to)}',
      '',
    ];

    for (final date in dates) {
      final items = grouped[date]!;
      final present =
          items.where((item) => item.status == AttendanceStatus.present).length;
      final marked = items.length;
      final rate = marked == 0 ? 0.0 : present / marked * 100;
      lines
          .add('${_slashDate(date)}: $present/$marked (${_formatRate(rate)}%)');
    }

    if (dates.isEmpty) {
      lines.add('No attendance records found for the selected range.');
    }

    return lines.join('\n');
  }

  String _rangeSemesterText() {
    final attendanceByKey = <String, Attendance>{
      for (final item in _filteredAttendance)
        '${_startOfDay(item.date).millisecondsSinceEpoch}|${item.studentId}':
            item,
    };

    final groups = <String, List<Student>>{};
    for (final student in _filteredStudents) {
      final semester = student.semester.trim().isEmpty
          ? 'Unknown Semester'
          : student.semester.trim();
      groups.putIfAbsent(semester, () => []).add(student);
    }

    final lines = <String>[
      'Attendance by Semester: ${_slashDate(_from)} - ${_slashDate(_to)}',
      '',
    ];

    for (final semester in groups.keys.toList()
      ..sort((a, b) => _semesterSortKey(b).compareTo(_semesterSortKey(a)))) {
      var present = 0;
      var marked = 0;
      for (final student in groups[semester]!) {
        for (var date = _from;
            !date.isAfter(_to);
            date = date.add(const Duration(days: 1))) {
          final item = attendanceByKey[
              '${date.millisecondsSinceEpoch}|${student.studentId}'];
          if (item == null) continue;
          marked++;
          if (item.status == AttendanceStatus.present) present++;
        }
      }
      final rate = marked == 0 ? 0.0 : present / marked * 100;
      lines.add('$semester Sem: $present/$marked (${_formatRate(rate)}%)');
    }

    if (groups.isEmpty) {
      lines.add('No students found for the selected filters.');
    }
    return lines.join('\n');
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;

    final value = _startOfDay(picked);
    setState(() {
      _from = value;
      if (_from.isAfter(_to)) _to = value;
    });
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;

    final value = _startOfDay(picked);
    setState(() {
      _to = value;
      if (_to.isBefore(_from)) _from = value;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedTgId = null;
      _selectedStudentId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final attendance = _filteredAttendance;
    final students = _filteredStudents;
    final present = attendance
        .where((item) => item.status == AttendanceStatus.present)
        .length;
    final absent = attendance
        .where((item) => item.status == AttendanceStatus.absent)
        .length;
    final marked = present + absent;
    final rate = marked == 0 ? 0.0 : present / marked * 100;

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Reports',
            subtitle: 'Attendance analytics calculated from Google Sheets.',
          ),
          const SizedBox(height: 20),
          _FilterCard(
            from: _from,
            to: _to,
            selectedTgId: _selectedTgId,
            selectedStudentId: _selectedStudentId,
            tgs: _tgs,
            students: _students,
            onFromDate: _pickFromDate,
            onToDate: _pickToDate,
            onTgChanged: (value) {
              setState(() {
                _selectedTgId = value;
                _selectedStudentId = null;
              });
            },
            onStudentChanged: (value) {
              setState(() => _selectedStudentId = value);
            },
            onClear: _clearFilters,
            onRefresh: _loadReport,
            loading: _loading,
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            _ErrorCard(error: _error.toString(), onRetry: _loadReport),
            const SizedBox(height: 20),
          ],
          _Stats(
            loading: _loading,
            marked: marked,
            present: present,
            absent: absent,
            rate: rate,
          ),
          const SizedBox(height: 24),
          if (_isTodayRange)
            _TodayReportSection(
              loading: _loading,
              detailedText: _todayDetailedText(),
              semesterText: _todaySemesterText(),
              onCopyDetailed: () =>
                  _copyText(_todayDetailedText(), 'Detailed today report'),
              onCopySemester: () =>
                  _copyText(_todaySemesterText(), 'Semester today report'),
            )
          else
            _RangeReportSection(
              loading: _loading,
              rangeText: _rangeText(),
              semesterText: _rangeSemesterText(),
              onCopyRange: () =>
                  _copyText(_rangeText(), 'Date-wise range report'),
              onCopySemester: () =>
                  _copyText(_rangeSemesterText(), 'Range semester report'),
            ),
          const SizedBox(height: 24),
          _TgReportCard(
            attendance: attendance,
            tgs: _tgs,
            title: 'TG-wise Report — Selected Range',
            subtitle: 'Overall attendance for the selected period.',
          ),
          const SizedBox(height: 20),
          _StudentReportCard(
            attendance: attendance,
            students: students,
            tgName: _tgName,
            title: 'Student-wise Report — Selected Range',
            subtitle: 'Individual attendance for the selected period.',
          ),
        ],
      ),
    );
  }
}

class _RangeReportSection extends StatelessWidget {
  const _RangeReportSection({
    required this.loading,
    required this.rangeText,
    required this.semesterText,
    required this.onCopyRange,
    required this.onCopySemester,
  });

  final bool loading;
  final String rangeText;
  final String semesterText;
  final VoidCallback onCopyRange;
  final VoidCallback onCopySemester;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Selected Range Attendance',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(
          'Date-wise reports for the selected range, ready to copy to WhatsApp.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final first = _CopyReportCard(
              title: 'Date-wise Report',
              subtitle: 'Overall attendance for each date.',
              text: rangeText,
              loading: loading,
              onCopy: onCopyRange,
            );
            final second = _CopyReportCard(
              title: 'Semester Summary',
              subtitle: 'Present / marked attendance for the range.',
              text: semesterText,
              loading: loading,
              onCopy: onCopySemester,
            );
            if (constraints.maxWidth < 900) {
              return Column(
                  children: [first, const SizedBox(height: 16), second]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: first),
                const SizedBox(width: 16),
                Expanded(child: second),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TodayReportSection extends StatelessWidget {
  const _TodayReportSection({
    required this.loading,
    required this.detailedText,
    required this.semesterText,
    required this.onCopyDetailed,
    required this.onCopySemester,
  });

  final bool loading;
  final String detailedText;
  final String semesterText;
  final VoidCallback onCopyDetailed;
  final VoidCallback onCopySemester;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Attendance',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          'Ready-to-copy WhatsApp formats generated from today\'s Google Sheet data.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  _CopyReportCard(
                    title: 'Detailed TG Report',
                    subtitle: 'Semester → TG → section breakdown.',
                    text: detailedText,
                    loading: loading,
                    onCopy: onCopyDetailed,
                  ),
                  const SizedBox(height: 16),
                  _CopyReportCard(
                    title: 'Semester Summary',
                    subtitle: 'Present / total students by semester.',
                    text: semesterText,
                    loading: loading,
                    onCopy: onCopySemester,
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CopyReportCard(
                    title: 'Detailed TG Report',
                    subtitle: 'Semester → TG → section breakdown.',
                    text: detailedText,
                    loading: loading,
                    onCopy: onCopyDetailed,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CopyReportCard(
                    title: 'Semester Summary',
                    subtitle: 'Present / total students by semester.',
                    text: semesterText,
                    loading: loading,
                    onCopy: onCopySemester,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CopyReportCard extends StatelessWidget {
  const _CopyReportCard({
    required this.title,
    required this.subtitle,
    required this.text,
    required this.loading,
    required this.onCopy,
  });

  final String title;
  final String subtitle;
  final String text;
  final bool loading;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: loading ? null : onCopy,
                  icon: const Icon(Icons.copy_outlined, size: 17),
                  label: const Text('Copy'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 160),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SelectableText(
                loading ? 'Loading...' : text,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.from,
    required this.to,
    required this.selectedTgId,
    required this.selectedStudentId,
    required this.tgs,
    required this.students,
    required this.onFromDate,
    required this.onToDate,
    required this.onTgChanged,
    required this.onStudentChanged,
    required this.onClear,
    required this.onRefresh,
    required this.loading,
  });

  final DateTime from;
  final DateTime to;
  final String? selectedTgId;
  final String? selectedStudentId;
  final List<Tg> tgs;
  final List<Student> students;
  final VoidCallback onFromDate;
  final VoidCallback onToDate;
  final ValueChanged<String?> onTgChanged;
  final ValueChanged<String?> onStudentChanged;
  final VoidCallback onClear;
  final Future<void> Function() onRefresh;
  final bool loading;

  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.year}';

  @override
  Widget build(BuildContext context) {
    final visibleStudents = selectedTgId == null
        ? students
        : students
            .where((student) => student.assignedTgId == selectedTgId)
            .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _DateButton(label: 'From', value: _date(from), onTap: onFromDate),
            _DateButton(label: 'To', value: _date(to), onTap: onToDate),
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String?>(
                initialValue: selectedTgId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'TG',
                  prefixIcon: Icon(Icons.groups_outlined),
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
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String?>(
                initialValue: selectedStudentId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Student',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Students'),
                  ),
                  ...visibleStudents.map(
                    (student) => DropdownMenuItem<String?>(
                      value: student.studentId,
                      child: Text(
                        '${student.name} (${student.rollNumber})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: onStudentChanged,
              ),
            ),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all_outlined, size: 18),
              label: const Text('Clear'),
            ),
            OutlinedButton.icon(
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh_outlined, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          border: const OutlineInputBorder(),
        ),
        child: Text(value),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({
    required this.loading,
    required this.marked,
    required this.present,
    required this.absent,
    required this.rate,
  });

  final bool loading;
  final int marked;
  final int present;
  final int absent;
  final double rate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 700
                ? 2
                : 1;

        final cards = [
          StatCard(
            title: 'Marked Attendance',
            value: loading ? '...' : '$marked',
            subtitle: 'P + A records in range',
            icon: Icons.fact_check_outlined,
          ),
          StatCard(
            title: 'Present',
            value: loading ? '...' : '$present',
            subtitle: 'Present records',
            icon: Icons.check_circle_outline,
          ),
          StatCard(
            title: 'Absent',
            value: loading ? '...' : '$absent',
            subtitle: 'Absent records',
            icon: Icons.cancel_outlined,
          ),
          StatCard(
            title: 'Attendance %',
            value: loading ? '...' : '${rate.toStringAsFixed(1)}%',
            subtitle: 'Present / marked records',
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

class _TgReportCard extends StatelessWidget {
  const _TgReportCard({
    required this.attendance,
    required this.tgs,
    required this.title,
    required this.subtitle,
  });

  final List<Attendance> attendance;
  final List<Tg> tgs;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final rows = <_TgSummary>[];

    for (final tg in tgs) {
      final items = attendance.where((item) => item.tgId == tg.tgId).toList();
      final present =
          items.where((item) => item.status == AttendanceStatus.present).length;
      final absent =
          items.where((item) => item.status == AttendanceStatus.absent).length;
      final marked = present + absent;

      if (marked > 0) {
        rows.add(
          _TgSummary(
            tgId: tg.tgId,
            name: tg.name,
            present: present,
            absent: absent,
            marked: marked,
          ),
        );
      }
    }

    rows.sort((a, b) => b.marked.compareTo(a.marked));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 18),
            if (rows.isEmpty)
              const _EmptyState(
                message: 'No attendance records match the selected filters.',
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('TG ID')),
                    DataColumn(label: Text('TG Name')),
                    DataColumn(label: Text('Present')),
                    DataColumn(label: Text('Absent')),
                    DataColumn(label: Text('Marked')),
                    DataColumn(label: Text('Attendance %')),
                  ],
                  rows: rows.map((row) {
                    return DataRow(
                      cells: [
                        DataCell(Text(row.tgId)),
                        DataCell(Text(row.name)),
                        DataCell(Text('${row.present}')),
                        DataCell(Text('${row.absent}')),
                        DataCell(Text('${row.marked}')),
                        DataCell(Text('${row.rate.toStringAsFixed(1)}%')),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StudentReportCard extends StatelessWidget {
  const _StudentReportCard({
    required this.attendance,
    required this.students,
    required this.tgName,
    required this.title,
    required this.subtitle,
  });

  final List<Attendance> attendance;
  final List<Student> students;
  final String Function(String) tgName;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final rows = <_StudentSummary>[];

    for (final student in students) {
      final items = attendance
          .where((item) => item.studentId == student.studentId)
          .toList();
      final present =
          items.where((item) => item.status == AttendanceStatus.present).length;
      final absent =
          items.where((item) => item.status == AttendanceStatus.absent).length;
      final marked = present + absent;

      if (marked == 0) continue;

      rows.add(
        _StudentSummary(
          name: student.name,
          rollNumber: student.rollNumber,
          tgName: tgName(student.assignedTgId ?? ''),
          present: present,
          absent: absent,
          marked: marked,
        ),
      );
    }

    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 18),
            if (rows.isEmpty)
              const _EmptyState(
                message: 'No student attendance matches the selected filters.',
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Student')),
                    DataColumn(label: Text('Roll No.')),
                    DataColumn(label: Text('TG')),
                    DataColumn(label: Text('Present')),
                    DataColumn(label: Text('Absent')),
                    DataColumn(label: Text('Marked')),
                    DataColumn(label: Text('Attendance %')),
                  ],
                  rows: rows.map((row) {
                    return DataRow(
                      cells: [
                        DataCell(Text(row.name)),
                        DataCell(Text(row.rollNumber)),
                        DataCell(Text(row.tgName)),
                        DataCell(Text('${row.present}')),
                        DataCell(Text('${row.absent}')),
                        DataCell(Text('${row.marked}')),
                        DataCell(Text('${row.rate.toStringAsFixed(1)}%')),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TgSummary {
  const _TgSummary({
    required this.tgId,
    required this.name,
    required this.present,
    required this.absent,
    required this.marked,
  });

  final String tgId;
  final String name;
  final int present;
  final int absent;
  final int marked;

  double get rate => marked == 0 ? 0 : present / marked * 100;
}

class _StudentSummary {
  const _StudentSummary({
    required this.name,
    required this.rollNumber,
    required this.tgName,
    required this.present,
    required this.absent,
    required this.marked,
  });

  final String name;
  final String rollNumber;
  final String tgName;
  final int present;
  final int absent;
  final int marked;

  double get rate => marked == 0 ? 0 : present / marked * 100;
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(error)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

String _slashDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _tgInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) return 'TG';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return '${parts.first.substring(0, 1)}'
          '${parts[1].substring(0, 1)}'
      .toUpperCase();
}

int _semesterSortKey(String semester) {
  final match = RegExp(r'(\d+)').firstMatch(semester);
  return match == null ? -1 : int.parse(match.group(1)!);
}

String _semesterHeading(String semester) {
  return semester.toLowerCase().endsWith('sem') ? semester : '$semester Sem';
}

String _formatRate(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}
