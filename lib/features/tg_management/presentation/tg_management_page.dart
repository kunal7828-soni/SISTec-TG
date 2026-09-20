import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../presentation/providers/student_provider.dart';
import '../../../presentation/providers/tg_provider.dart';
import '../../../data/sheets/google_attendance_data_source.dart';

class TgManagementPage extends StatefulWidget {
  const TgManagementPage({super.key});

  @override
  State<TgManagementPage> createState() => _TgManagementPageState();
}

class _TgManagementPageState extends State<TgManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TgProvider>().startListening();
      context.read<StudentProvider>().startListening();
    });
  }

  void _onSearchChanged() {
    final value = _searchController.text.trim().toLowerCase();
    if (value == _search) return;
    setState(() => _search = value);
  }

  Future<void> _refresh() async {
    await context.read<GoogleAttendanceDataSource>().refresh();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TgProvider, StudentProvider>(
      builder: (context, tgProvider, studentProvider, _) {
        final loading = tgProvider.loading || studentProvider.loading;
        final error = tgProvider.error ?? studentProvider.error;

        final filtered = tgProvider.items.where((tg) {
          if (_search.isEmpty) return true;
          return tg.tgId.toLowerCase().contains(_search) ||
              tg.name.toLowerCase().contains(_search);
        }).toList();

        final studentCounts = <String, int>{};
        for (final student in studentProvider.items) {
          final tgId = student.assignedTgId;
          if (tgId == null || tgId.isEmpty) continue;
          studentCounts[tgId] = (studentCounts[tgId] ?? 0) + 1;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
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
                              'TG Management',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'TG profiles and assigned students from Google Sheets.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: loading ? null : _refresh,
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SummaryCard(
                    totalTgs: tgProvider.items.length,
                    totalStudents: studentProvider.items.length,
                    filteredTgs: filtered.length,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search TG ID or TG name',
                          prefixIcon: const Icon(Icons.search_outlined),
                          suffixIcon: _search.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: _searchController.clear,
                                  icon: const Icon(Icons.clear_outlined),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (error != null)
                    _ErrorBanner(
                      message: error.toString(),
                      onRetry: _refresh,
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'TG List',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                '${filtered.length} shown',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (loading && tgProvider.items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (filtered.isEmpty)
                            const _EmptyState()
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 42,
                                columns: const [
                                  DataColumn(label: Text('TG ID')),
                                  DataColumn(label: Text('TG Name')),
                                  DataColumn(label: Text('Students')),
                                  DataColumn(label: Text('Status')),
                                ],
                                rows: filtered.map((tg) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          tg.tgId,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(tg.name),
                                      ),
                                      DataCell(
                                        Text(
                                          '${studentCounts[tg.tgId] ?? 0}',
                                        ),
                                      ),
                                      DataCell(
                                        _StatusBadge(active: tg.active),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'TG records are currently derived from the Daily_Attendace sheet. TG create/edit/delete actions will be enabled after a dedicated TG master structure is finalized in Google Sheets.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalTgs,
    required this.totalStudents,
    required this.filteredTgs,
  });

  final int totalTgs;
  final int totalStudents;
  final int filteredTgs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _Metric(
              icon: Icons.groups_outlined,
              label: 'Total TGs',
              value: '$totalTgs',
            ),
            const SizedBox(width: 40),
            _Metric(
              icon: Icons.school_outlined,
              label: 'Total Students',
              value: '$totalStudents',
            ),
            const SizedBox(width: 40),
            _Metric(
              icon: Icons.filter_alt_outlined,
              label: 'Showing',
              value: '$filteredTgs',
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primary),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
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
        ),
      ],
    );
  }
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
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.groups_outlined, size: 48),
            SizedBox(height: 12),
            Text(
              'No TG records found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Try a different search or refresh the Google Sheet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
