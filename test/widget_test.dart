import 'package:flutter_test/flutter_test.dart';
import 'package:super_tg_attendance_dashboard/app.dart';

void main() {
  testWidgets('Super TG Attendance Dashboard loads', (tester) async {
    await tester.pumpWidget(const SuperTgAttendanceApp());

    expect(find.text('Overview'), findsOneWidget);
  });
}
