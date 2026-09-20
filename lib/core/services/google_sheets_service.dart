import 'package:googleapis/sheets/v4.dart';
import 'package:http/http.dart' as http;

import 'google_auth_service.dart';

class GoogleSheetsService {
  GoogleSheetsService._();

  static final GoogleSheetsService instance = GoogleSheetsService._();

  static const String spreadsheetId =
      '10gPpynnpcn7fH091rsjy0SYX2kCjBiAaPX2EccM6SoU';

  static const String dailyAttendanceSheet = 'Daily_Attendace';

  Future<List<List<Object?>>> readRange(String range) async {
    final client = await _authenticatedClient();

    try {
      final api = SheetsApi(client);

      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        range,
      );

      return response.values ?? <List<Object?>>[];
    } finally {
      client.close();
    }
  }

  Future<List<List<Object?>>> readDailyAttendance() {
    return readRange(dailyAttendanceSheet);
  }

  Future<List<List<Object?>>> readSheet(String sheetName) {
    return readRange(sheetName);
  }

  Future<void> updateRange(
    String range,
    List<List<Object?>> values,
  ) async {
    final client = await _authenticatedClient();

    try {
      final api = SheetsApi(client);

      await api.spreadsheets.values.update(
        ValueRange(values: values),
        spreadsheetId,
        range,
        valueInputOption: 'USER_ENTERED',
      );
    } finally {
      client.close();
    }
  }

  Future<void> appendRows(
    String range,
    List<List<Object?>> values,
  ) async {
    final client = await _authenticatedClient();

    try {
      final api = SheetsApi(client);

      await api.spreadsheets.values.append(
        ValueRange(values: values),
        spreadsheetId,
        range,
        valueInputOption: 'USER_ENTERED',
        insertDataOption: 'INSERT_ROWS',
      );
    } finally {
      client.close();
    }
  }

  /// Updates one student's P/A value in the date column of Daily_Attendace.
  ///
  /// The student is located by the existing RollNo. column. The date column
  /// is detected from its header, so no date column is hard-coded.
  /// If the date column does not exist yet, the header is added automatically.
  Future<void> replaceSheetValues(
    String sheetName,
    List<List<Object?>> values, {
    String clearRange = 'A:Z',
  }) async {
    final client = await _authenticatedClient();

    try {
      final api = SheetsApi(client);

      await api.spreadsheets.values.clear(
        ClearValuesRequest(),
        spreadsheetId,
        '$sheetName!$clearRange',
      );

      if (values.isEmpty) return;

      await api.spreadsheets.values.update(
        ValueRange(values: values),
        spreadsheetId,
        '$sheetName!A1',
        valueInputOption: 'USER_ENTERED',
      );
    } finally {
      client.close();
    }
  }

  /// Adds a student as a new row in Daily_Attendace.
  ///
  /// Only the six master-data columns are written. Existing date columns
  /// remain untouched and therefore the new student's attendance starts empty.
  Future<void> addStudent({
    required String tgId,
    required String tgName,
    required String name,
    required String rollNumber,
    required String semester,
    required String section,
  }) async {
    final normalizedRoll = rollNumber.trim();
    if (normalizedRoll.isEmpty) {
      throw ArgumentError.value(
        rollNumber,
        'rollNumber',
        'Roll number cannot be empty.',
      );
    }

    final rows = await readDailyAttendance();
    if (rows.isEmpty) {
      throw StateError('$dailyAttendanceSheet sheet is empty.');
    }

    final headers = rows.first;
    final rollColumnIndex = _findHeaderIndex(headers, 'RollNo.');
    if (rollColumnIndex == -1) {
      throw StateError('RollNo. column was not found.');
    }

    if (_findStudentRow(rows, rollColumnIndex, normalizedRoll) != -1) {
      throw StateError(
        'A student with Roll No. $normalizedRoll already exists.',
      );
    }

    await apiAppendRows(<Object?>[
      tgId.trim(),
      tgName.trim(),
      name.trim(),
      normalizedRoll,
      semester.trim(),
      section.trim(),
    ]);
  }

  /// Updates the six master-data fields for an existing student.
  ///
  /// The student's roll number is used as the stable key, so attendance date
  /// columns are not changed.
  Future<void> updateStudent({
    required String rollNumber,
    required String tgId,
    required String tgName,
    required String name,
    required String semester,
    required String section,
  }) async {
    final rows = await readDailyAttendance();
    if (rows.isEmpty) {
      throw StateError('$dailyAttendanceSheet sheet is empty.');
    }

    final headers = rows.first;
    final rollColumnIndex = _findHeaderIndex(headers, 'RollNo.');
    if (rollColumnIndex == -1) {
      throw StateError('RollNo. column was not found.');
    }

    final rowIndex = _findStudentRow(
      rows,
      rollColumnIndex,
      rollNumber,
    );

    if (rowIndex == -1) {
      throw StateError(
        'Student with Roll No. ${rollNumber.trim()} was not found.',
      );
    }

    await updateRange(
      '$dailyAttendanceSheet!A${rowIndex + 1}:F${rowIndex + 1}',
      <List<Object?>>[
        <Object?>[
          tgId.trim(),
          tgName.trim(),
          name.trim(),
          rollNumber.trim(),
          semester.trim(),
          section.trim(),
        ],
      ],
    );
  }

  Future<void> apiAppendRows(List<Object?> row) async {
    final client = await _authenticatedClient();

    try {
      final api = SheetsApi(client);

      await api.spreadsheets.values.append(
        ValueRange(values: <List<Object?>>[row]),
        spreadsheetId,
        '$dailyAttendanceSheet!A:F',
        valueInputOption: 'USER_ENTERED',
        insertDataOption: 'INSERT_ROWS',
      );
    } finally {
      client.close();
    }
  }

  /// Permanently removes the student's row from Daily_Attendace.
  ///
  /// This also removes all attendance values stored on that row. The caller
  /// must therefore confirm the deletion with the user before invoking it.
  Future<void> deleteStudent({required String rollNumber}) async {
    final normalizedRoll = rollNumber.trim();
    if (normalizedRoll.isEmpty) {
      throw ArgumentError.value(
        rollNumber,
        'rollNumber',
        'Roll number cannot be empty.',
      );
    }

    final client = await _authenticatedClient();

    try {
      final api = SheetsApi(client);
      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        dailyAttendanceSheet,
      );
      final rows = response.values ?? <List<Object?>>[];

      if (rows.isEmpty) {
        throw StateError('$dailyAttendanceSheet sheet is empty.');
      }

      final headers = rows.first;
      final rollColumnIndex = _findHeaderIndex(headers, 'RollNo.');
      if (rollColumnIndex == -1) {
        throw StateError('RollNo. column was not found.');
      }

      final rowIndex = _findStudentRow(
        rows,
        rollColumnIndex,
        normalizedRoll,
      );

      if (rowIndex == -1) {
        throw StateError(
          'Student with Roll No. $normalizedRoll was not found.',
        );
      }

      final spreadsheet = await api.spreadsheets.get(spreadsheetId);
      int? sheetId;
      for (final item in spreadsheet.sheets ?? <Sheet>[]) {
        if (item.properties?.title == dailyAttendanceSheet) {
          sheetId = item.properties?.sheetId;
          break;
        }
      }
      if (sheetId == null) {
        throw StateError(
          'Could not find the $dailyAttendanceSheet sheet.',
        );
      }

      await api.spreadsheets.batchUpdate(
        BatchUpdateSpreadsheetRequest(
          requests: <Request>[
            Request(
              deleteDimension: DeleteDimensionRequest(
                range: DimensionRange(
                  sheetId: sheetId,
                  dimension: 'ROWS',
                  startIndex: rowIndex,
                  endIndex: rowIndex + 1,
                ),
              ),
            ),
          ],
        ),
        spreadsheetId,
      );
    } finally {
      client.close();
    }
  }

  /// Ensures today's date exists as the first date column after Section.
  /// Existing date columns are shifted right and their values are preserved.
  Future<void> ensureDailyAttendanceDate(DateTime date) async {
    final client = await _authenticatedClient();

    try {
      final api = SheetsApi(client);
      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        dailyAttendanceSheet,
      );

      final rows = response.values ?? <List<Object?>>[];
      if (rows.isEmpty) {
        throw StateError('$dailyAttendanceSheet sheet is empty.');
      }

      final headers = rows.first;
      if (_findDateColumn(headers, date) != -1) {
        return;
      }

      final firstDateColumn = _firstDateColumnIndex(headers);
      final targetColumnIndex =
          firstDateColumn == -1 ? headers.length : firstDateColumn;

      final spreadsheet = await api.spreadsheets.get(spreadsheetId);
      int? sheetId;

      for (final item in spreadsheet.sheets ?? <Sheet>[]) {
        if (item.properties?.title == dailyAttendanceSheet) {
          sheetId = item.properties?.sheetId;
          break;
        }
      }

      if (sheetId == null) {
        throw StateError(
          'Could not find the $dailyAttendanceSheet sheet.',
        );
      }

      await api.spreadsheets.batchUpdate(
        BatchUpdateSpreadsheetRequest(
          requests: <Request>[
            Request(
              insertDimension: InsertDimensionRequest(
                range: DimensionRange(
                  sheetId: sheetId,
                  dimension: 'COLUMNS',
                  startIndex: targetColumnIndex,
                  endIndex: targetColumnIndex + 1,
                ),
                // Inherit the formatting of the existing first date column
                // when one exists. This keeps the sheet visually consistent.
                inheritFromBefore: firstDateColumn == -1,
              ),
            ),
          ],
        ),
        spreadsheetId,
      );

      await api.spreadsheets.values.update(
        ValueRange(
          values: <List<Object?>>[
            <Object?>[_formatSheetDate(date)],
          ],
        ),
        spreadsheetId,
        '$dailyAttendanceSheet!${_columnName(targetColumnIndex)}1',
        valueInputOption: 'USER_ENTERED',
      );
    } finally {
      client.close();
    }
  }

  Future<void> updateAttendanceStatus({
    required String rollNumber,
    required DateTime date,
    required String status,
  }) async {
    final normalizedStatus = status.trim().toUpperCase();

    if (normalizedStatus != 'P' && normalizedStatus != 'A') {
      throw ArgumentError.value(
        status,
        'status',
        'Attendance status must be P or A.',
      );
    }

    final client = await _authenticatedClient();

    try {
      final api = SheetsApi(client);

      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        dailyAttendanceSheet,
      );

      final rows = response.values ?? <List<Object?>>[];

      if (rows.isEmpty) {
        throw StateError('$dailyAttendanceSheet sheet is empty.');
      }

      final headers = rows.first;
      final rollColumnIndex = _findHeaderIndex(headers, 'RollNo.');

      if (rollColumnIndex == -1) {
        throw StateError('RollNo. column was not found.');
      }

      var targetColumnIndex = _findDateColumn(headers, date);

      if (targetColumnIndex == -1) {
        await ensureDailyAttendanceDate(date);

        // Re-read headers because inserting the new date shifts the columns.
        final refreshed = await api.spreadsheets.values.get(
          spreadsheetId,
          dailyAttendanceSheet,
        );
        final refreshedHeaders = refreshed.values?.first ?? <Object?>[];
        targetColumnIndex = _findDateColumn(refreshedHeaders, date);

        if (targetColumnIndex == -1) {
          throw StateError(
            'Could not create the date column for $date.',
          );
        }
      }

      final targetRowIndex = _findStudentRow(
        rows,
        rollColumnIndex,
        rollNumber,
      );

      if (targetRowIndex == -1) {
        throw StateError(
          'Student with Roll No. ${rollNumber.trim()} was not found.',
        );
      }

      final cell = '${_columnName(targetColumnIndex)}${targetRowIndex + 1}';

      await api.spreadsheets.values.update(
        ValueRange(
          values: <List<Object?>>[
            <Object?>[normalizedStatus],
          ],
        ),
        spreadsheetId,
        '$dailyAttendanceSheet!$cell',
        valueInputOption: 'USER_ENTERED',
      );
    } finally {
      client.close();
    }
  }

  Future<_AuthenticatedClient> _authenticatedClient() async {
    final accessToken = await GoogleAuthService.instance.getAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception(
        'Google account is not authorized for Google Sheets.',
      );
    }

    return _AuthenticatedClient(accessToken);
  }

  static int _findStudentRow(
    List<List<Object?>> rows,
    int rollColumnIndex,
    String rollNumber,
  ) {
    final target = rollNumber.trim();

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];

      if (rollColumnIndex >= row.length) {
        continue;
      }

      final value = row[rollColumnIndex]?.toString().trim() ?? '';

      if (value == target) {
        return rowIndex;
      }
    }

    return -1;
  }

  static int _firstDateColumnIndex(List<Object?> headers) {
    for (var index = 0; index < headers.length; index++) {
      if (_parseSheetDate(headers[index]?.toString() ?? '') != null) {
        return index;
      }
    }

    return -1;
  }

  static DateTime? _parseSheetDate(String value) {
    final parts = value.trim().split('-');
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = _monthNumber(parts[1]);
    var year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return null;
    if (parts[2].length == 2) year += 2000;

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    return date;
  }

  static int? _monthNumber(String value) {
    const months = <String, int>{
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    return months[value.trim().toLowerCase()];
  }

  static int _findDateColumn(
    List<Object?> headers,
    DateTime date,
  ) {
    final shortYear = _formatSheetDate(date);
    final fullYear = _formatSheetDateFullYear(date);

    for (var index = 0; index < headers.length; index++) {
      final header = headers[index]?.toString().trim() ?? '';

      if (header == shortYear || header == fullYear) {
        return index;
      }
    }

    return -1;
  }

  static int _findHeaderIndex(
    List<Object?> headers,
    String expected,
  ) {
    for (var index = 0; index < headers.length; index++) {
      if (headers[index]?.toString().trim() == expected) {
        return index;
      }
    }

    return -1;
  }

  static String _formatSheetDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day}-${months[date.month - 1]}-'
        '${(date.year % 100).toString().padLeft(2, '0')}';
  }

  static String _formatSheetDateFullYear(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day}-${months[date.month - 1]}-${date.year}';
  }

  static String _columnName(int zeroBasedIndex) {
    var index = zeroBasedIndex + 1;
    var result = '';

    while (index > 0) {
      final remainder = (index - 1) % 26;
      result = String.fromCharCode(65 + remainder) + result;
      index = (index - 1) ~/ 26;
    }

    return result;
  }
}

class _AuthenticatedClient extends http.BaseClient {
  _AuthenticatedClient(this.accessToken);

  final String accessToken;
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $accessToken';
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}
