import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/student.dart';
import '../../../data/models/tg.dart';
import '../../../data/sheets/google_attendance_data_source.dart';
import '../../../presentation/providers/student_provider.dart';
import '../../../presentation/providers/tg_provider.dart';

class StudentManagementPage extends StatefulWidget {
  const StudentManagementPage({super.key});

  @override
  State<StudentManagementPage> createState() => _StudentManagementPageState();
}

class _StudentManagementPageState extends State<StudentManagementPage> {
  final TextEditingController _searchController = TextEditingController();

  String _tgFilter = '';
  String _semesterFilter = '';
  String _sectionFilter = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<StudentProvider>().startListening();
      context.read<TgProvider>().startListening();
    });

    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() => setState(() {});

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<GoogleAttendanceDataSource>().refresh();
  }

  Future<void> _deleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Student?'),
          content: Text(
            'Delete ${student.name} (${student.rollNumber}) permanently?\n\n'
            'This removes the student row from Google Sheets and also removes '
            'all attendance history stored on that row.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<StudentProvider>().deleteStudent(student.studentId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student deleted successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  List<Student> _filteredStudents(List<Student> students) {
    final query = _searchController.text.trim().toLowerCase();

    return students.where((student) {
      final matchesSearch = query.isEmpty ||
          student.name.toLowerCase().contains(query) ||
          student.rollNumber.toLowerCase().contains(query) ||
          (student.assignedTgId ?? '').toLowerCase().contains(query);

      final matchesTg = _tgFilter.isEmpty || student.assignedTgId == _tgFilter;

      final matchesSemester =
          _semesterFilter.isEmpty || student.semester == _semesterFilter;

      final matchesSection =
          _sectionFilter.isEmpty || student.section == _sectionFilter;

      return matchesSearch && matchesTg && matchesSemester && matchesSection;
    }).toList();
  }

  Future<void> _addStudent(List<Tg> tgs) async {
    final result = await showDialog<StudentFormResult>(
      context: context,
      builder: (_) => _StudentFormDialog(tgs: tgs),
    );

    if (result == null || !mounted) return;

    try {
      await context.read<StudentProvider>().addStudent(result.student);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student added successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  Future<void> _editStudent(Student student, List<Tg> tgs) async {
    final result = await showDialog<StudentFormResult>(
      context: context,
      builder: (_) => _StudentFormDialog(
        tgs: tgs,
        student: student,
      ),
    );

    if (result == null || !mounted) return;

    try {
      await context.read<StudentProvider>().updateStudent(result.student);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student updated successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Operation failed: $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<StudentProvider, TgProvider>(
      builder: (context, studentProvider, tgProvider, _) {
        if (studentProvider.loading && studentProvider.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (studentProvider.error != null && studentProvider.items.isEmpty) {
          return _ErrorState(
            message: studentProvider.error.toString(),
            onRetry: _refresh,
          );
        }

        final students = studentProvider.items;
        final tgs = tgProvider.items;
        final filtered = _filteredStudents(students);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
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
                              'Student Management',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Manage student records stored in Google Sheets.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: studentProvider.loading ? null : _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed:
                            tgProvider.loading ? null : () => _addStudent(tgs),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Add Student'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SummaryCard(
                    total: students.length,
                    filtered: filtered.length,
                  ),
                  const SizedBox(height: 20),
                  _FilterCard(
                    searchController: _searchController,
                    tgFilter: _tgFilter,
                    semesterFilter: _semesterFilter,
                    sectionFilter: _sectionFilter,
                    tgs: tgs,
                    semesters: _uniqueValues(
                      students.map((student) => student.semester),
                    ),
                    sections: _uniqueValues(
                      students.map((student) => student.section),
                    ),
                    onTgChanged: (value) =>
                        setState(() => _tgFilter = value ?? ''),
                    onSemesterChanged: (value) =>
                        setState(() => _semesterFilter = value ?? ''),
                    onSectionChanged: (value) =>
                        setState(() => _sectionFilter = value ?? ''),
                    onClear: () {
                      _searchController.clear();
                      setState(() {
                        _tgFilter = '';
                        _semesterFilter = '';
                        _sectionFilter = '';
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  _StudentTable(
                    students: filtered,
                    tgs: tgs,
                    onEdit: (student) => _editStudent(student, tgs),
                    onDelete: _deleteStudent,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<String> _uniqueValues(Iterable<String> values) {
    final result = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    result.sort();
    return result;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total, required this.filtered});

  final int total;
  final int filtered;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.school_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            _SummaryValue(label: 'Total Students', value: '$total'),
            const SizedBox(width: 36),
            _SummaryValue(label: 'Showing', value: '$filtered'),
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.searchController,
    required this.tgFilter,
    required this.semesterFilter,
    required this.sectionFilter,
    required this.tgs,
    required this.semesters,
    required this.sections,
    required this.onTgChanged,
    required this.onSemesterChanged,
    required this.onSectionChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String tgFilter;
  final String semesterFilter;
  final String sectionFilter;
  final List<Tg> tgs;
  final List<String> semesters;
  final List<String> sections;
  final ValueChanged<String?> onTgChanged;
  final ValueChanged<String?> onSemesterChanged;
  final ValueChanged<String?> onSectionChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 850;

            final search = TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                hintText: 'Name, roll number or TG ID',
                prefixIcon: Icon(Icons.search),
              ),
            );

            final tg = DropdownButtonFormField<String>(
              initialValue: tgFilter.isEmpty ? null : tgFilter,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'TG'),
              hint: const Text('All TGs'),
              items: tgs
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.tgId,
                      child: Text(
                        '${item.tgId} - ${item.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onTgChanged,
            );

            final semester = _FilterDropdown(
              label: 'Semester',
              value: semesterFilter,
              values: semesters,
              onChanged: onSemesterChanged,
            );

            final section = _FilterDropdown(
              label: 'Section',
              value: sectionFilter,
              values: sections,
              onChanged: onSectionChanged,
            );

            final clear = OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear'),
            );

            if (narrow) {
              return Column(
                children: [
                  search,
                  const SizedBox(height: 12),
                  tg,
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: semester),
                      const SizedBox(width: 12),
                      Expanded(child: section),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: clear,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 2, child: search),
                const SizedBox(width: 12),
                Expanded(child: tg),
                const SizedBox(width: 12),
                Expanded(child: semester),
                const SizedBox(width: 12),
                Expanded(child: section),
                const SizedBox(width: 12),
                clear,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      hint: Text('All $label'),
      items: values
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _StudentTable extends StatelessWidget {
  const _StudentTable({
    required this.students,
    required this.tgs,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Student> students;
  final List<Tg> tgs;
  final ValueChanged<Student> onEdit;
  final ValueChanged<Student> onDelete;

  @override
  Widget build(BuildContext context) {
    final tgNames = <String, String>{
      for (final tg in tgs) tg.tgId: tg.name,
    };

    final grouped = <String, List<Student>>{};

    for (final student in students) {
      final tgId = student.assignedTgId?.trim() ?? '';
      final key = tgId.isEmpty ? 'Unassigned' : tgId;
      grouped.putIfAbsent(key, () => <Student>[]).add(student);
    }

    final tgIds = grouped.keys.toList()
      ..sort((a, b) => _compareNatural(a, b));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Students by TG',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Students are grouped by TG, then by section and Roll No.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            if (students.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('No students match the selected filters.'),
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < tgIds.length; i++) ...[
                    _TgStudentGroup(
                      tgId: tgIds[i],
                      tgName: tgNames[tgIds[i]],
                      students: grouped[tgIds[i]]!,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
                    if (i != tgIds.length - 1)
                      const SizedBox(height: 16),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  static int _compareNatural(String a, String b) {
    final aMatch = RegExp(r'^(.*?)(\d+)$').firstMatch(a);
    final bMatch = RegExp(r'^(.*?)(\d+)$').firstMatch(b);

    if (aMatch != null && bMatch != null) {
      final prefixCompare = aMatch.group(1)!.compareTo(bMatch.group(1)!);
      if (prefixCompare != 0) return prefixCompare;

      return int.parse(aMatch.group(2)!)
          .compareTo(int.parse(bMatch.group(2)!));
    }

    return a.compareTo(b);
  }
}

class _TgStudentGroup extends StatelessWidget {
  const _TgStudentGroup({
    required this.tgId,
    required this.tgName,
    required this.students,
    required this.onEdit,
    required this.onDelete,
  });

  final String tgId;
  final String? tgName;
  final List<Student> students;
  final ValueChanged<Student> onEdit;
  final ValueChanged<Student> onDelete;

  @override
  Widget build(BuildContext context) {
    final bySection = <String, List<Student>>{};

    for (final student in students) {
      final section = student.section.trim().isEmpty
          ? 'No Section'
          : student.section.trim();

      bySection.putIfAbsent(section, () => <Student>[]).add(student);
    }

    final sections = bySection.keys.toList()..sort();

    for (final section in sections) {
      bySection[section]!.sort(
        (a, b) => _compareRollNumbers(
          a.rollNumber,
          b.rollNumber,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.10),
                  child: Icon(
                    Icons.groups_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tgId == 'Unassigned'
                            ? 'Unassigned'
                            : '$tgId — ${tgName ?? 'Unknown TG'}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${students.length} students • '
                        '${sections.length} section${sections.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final section in sections)
                      _SectionCountBadge(
                        section: section,
                        count: bySection[section]!.length,
                      ),
                  ],
                ),
              ],
            ),
          ),
          for (final section in sections)
            _SectionStudentTable(
              section: section,
              students: bySection[section]!,
              onEdit: onEdit,
              onDelete: onDelete,
              showTopBorder: section != sections.first,
            ),
        ],
      ),
    );
  }

  static int _compareRollNumbers(String a, String b) {
    final aTrimmed = a.trim();
    final bTrimmed = b.trim();

    final aNumber = int.tryParse(aTrimmed);
    final bNumber = int.tryParse(bTrimmed);

    if (aNumber != null && bNumber != null) {
      return aNumber.compareTo(bNumber);
    }

    return aTrimmed.compareTo(bTrimmed);
  }
}

class _SectionCountBadge extends StatelessWidget {
  const _SectionCountBadge({
    required this.section,
    required this.count,
  });

  final String section;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        '$section: $count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionStudentTable extends StatelessWidget {
  const _SectionStudentTable({
    required this.section,
    required this.students,
    required this.onEdit,
    required this.onDelete,
    required this.showTopBorder,
  });

  final String section;
  final List<Student> students;
  final ValueChanged<Student> onEdit;
  final ValueChanged<Student> onDelete;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: showTopBorder
          ? BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            )
          : null,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 4,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.class_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '$section (${students.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 46,
              dataRowMaxHeight: 58,
              columns: const [
                DataColumn(label: Text('Student Name')),
                DataColumn(label: Text('Roll No.')),
                DataColumn(label: Text('Semester')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Action')),
              ],
              rows: students.map((student) {
                return DataRow(
                  cells: [
                    DataCell(Text(student.name)),
                    DataCell(Text(student.rollNumber)),
                    DataCell(
                      Text(
                        student.semester.isEmpty
                            ? '—'
                            : student.semester,
                      ),
                    ),
                    DataCell(
                      _StatusBadge(active: student.active),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit student',
                            onPressed: () => onEdit(student),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete student',
                            onPressed: () => onDelete(student),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentFormDialog extends StatefulWidget {
  const _StudentFormDialog({
    required this.tgs,
    this.student,
  });

  final List<Tg> tgs;
  final Student? student;

  @override
  State<_StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<_StudentFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _rollController;
  late final TextEditingController _semesterController;
  late final TextEditingController _sectionController;

  String _tgId = '';

  bool get editing => widget.student != null;

  @override
  void initState() {
    super.initState();

    final student = widget.student;

    _nameController = TextEditingController(text: student?.name ?? '');
    _rollController = TextEditingController(text: student?.rollNumber ?? '');
    _semesterController = TextEditingController(text: student?.semester ?? '');
    _sectionController = TextEditingController(text: student?.section ?? '');
    _tgId = student?.assignedTgId ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _semesterController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final roll = _rollController.text.trim();
    final semester = _semesterController.text.trim();
    final section = _sectionController.text.trim();

    if (name.isEmpty || roll.isEmpty || semester.isEmpty || section.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all student fields.'),
        ),
      );
      return;
    }

    if (_tgId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a TG.')),
      );
      return;
    }

    final existing = widget.student;

    final student = Student(
      studentId: existing?.studentId ?? roll,
      name: name,
      rollNumber: existing?.rollNumber ?? roll,
      semester: semester,
      section: section,
      assignedTgId: _tgId,
      active: existing?.active ?? true,
      createdAt: existing?.createdAt,
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(
      StudentFormResult(student: student),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(editing ? 'Edit Student' : 'Add Student'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Student Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _rollController,
                enabled: !editing,
                decoration: const InputDecoration(
                  labelText: 'Roll No.',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              if (editing) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Roll number is kept fixed so existing attendance history stays linked.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _semesterController,
                decoration: const InputDecoration(
                  labelText: 'Semester',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _sectionController,
                decoration: const InputDecoration(
                  labelText: 'Section',
                  prefixIcon: Icon(Icons.class_outlined),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _tgId.isEmpty ? null : _tgId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'TG',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                items: widget.tgs
                    .map(
                      (tg) => DropdownMenuItem<String>(
                        value: tg.tgId,
                        child: Text(
                          '${tg.tgId} - ${tg.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _tgId = value ?? '');
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(editing ? 'Save Changes' : 'Add Student'),
        ),
      ],
    );
  }
}

class StudentFormResult {
  const StudentFormResult({required this.student});

  final Student student;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withValues(alpha: 0.10)
            : Colors.grey.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? Colors.green.shade700 : Colors.grey.shade700,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'Could not load student data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
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
