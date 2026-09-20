import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';

import 'data/repositories/impl/google_sheets_attendance_repository.dart';
import 'data/repositories/impl/google_sheets_student_repository.dart';
import 'data/repositories/impl/google_sheets_tg_repository.dart';

import 'data/sheets/google_attendance_data_source.dart';

import 'features/attendance/presentation/attendance_page.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/excel_import/presentation/excel_import_page.dart';
import 'features/google_connection/presentation/google_connection_page.dart';
import 'features/reports/presentation/reports_page.dart';
import 'features/student_management/presentation/student_management_page.dart';
import 'features/tg_management/presentation/tg_management_page.dart';

import 'presentation/providers/attendance_provider.dart';
import 'presentation/providers/student_provider.dart';
import 'presentation/providers/tg_provider.dart';

import 'shared/widgets/dashboard_shell.dart';
import 'core/services/google_sheets_service.dart';

class SuperTgAttendanceApp extends StatefulWidget {
  const SuperTgAttendanceApp({super.key});

  @override
  State<SuperTgAttendanceApp> createState() => _SuperTgAttendanceAppState();
}

class _SuperTgAttendanceAppState extends State<SuperTgAttendanceApp> {
  late final GoogleAttendanceDataSource _dataSource;

  late final GoogleSheetsTgRepository _tgRepository;
  late final GoogleSheetsStudentRepository _studentRepository;
  late final GoogleSheetsAttendanceRepository _attendanceRepository;

  @override
  void initState() {
    super.initState();

    // One shared Google Sheet data source for the whole app.
    _dataSource = GoogleAttendanceDataSource();

    _tgRepository = GoogleSheetsTgRepository(
      dataSource: _dataSource,
    );

    _studentRepository = GoogleSheetsStudentRepository(
      dataSource: _dataSource,
    );

    _attendanceRepository = GoogleSheetsAttendanceRepository(
      dataSource: _dataSource,
      sheetsService: GoogleSheetsService.instance,
    );
  }

  @override
  void dispose() {
    _dataSource.dispose();
    super.dispose();
  }

  static final GoRouter _router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return DashboardShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/tg-management',
            builder: (context, state) => const TgManagementPage(),
          ),
          GoRoute(
            path: '/student-management',
            builder: (context, state) => const StudentManagementPage(),
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendancePage(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/excel-import',
            builder: (context, state) => const ExcelImportPage(),
          ),
          GoRoute(
            path: '/google-connection',
            builder: (context, state) => const GoogleConnectionPage(),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<GoogleAttendanceDataSource>.value(
          value: _dataSource,
        ),
        ChangeNotifierProvider<TgProvider>(
          create: (_) => TgProvider(_tgRepository),
        ),
        ChangeNotifierProvider<StudentProvider>(
          create: (_) => StudentProvider(_studentRepository),
        ),
        ChangeNotifierProvider<AttendanceProvider>(
          create: (_) => AttendanceProvider(_attendanceRepository),
        ),
      ],
      child: MaterialApp.router(
        title: 'Super TG Attendance Dashboard',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
