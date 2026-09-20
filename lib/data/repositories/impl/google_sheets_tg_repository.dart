import 'dart:async';

import '../../models/tg.dart';
import '../tg_repository.dart';
import '../../sheets/google_attendance_data_source.dart';

class GoogleSheetsTgRepository implements TgRepository {
  GoogleSheetsTgRepository({
    GoogleAttendanceDataSource? dataSource,
  }) : _dataSource = dataSource ?? GoogleAttendanceDataSource();

  final GoogleAttendanceDataSource _dataSource;

  @override
  Stream<List<Tg>> watchTgs({
    bool activeOnly = false,
  }) async* {
    await _dataSource.load();

    yield _filter(
      _dataSource.tgs,
      activeOnly: activeOnly,
    );

    await for (final _ in _dataSource.changes) {
      yield _filter(
        _dataSource.tgs,
        activeOnly: activeOnly,
      );
    }
  }

  List<Tg> _filter(
    List<Tg> items, {
    required bool activeOnly,
  }) {
    if (!activeOnly) {
      return List<Tg>.from(items);
    }

    return items.where((tg) => tg.active).toList();
  }

  @override
  Future<Tg?> getTgById(String tgId) async {
    await _dataSource.load();

    for (final tg in _dataSource.tgs) {
      if (tg.tgId == tgId) {
        return tg;
      }
    }

    return null;
  }

  @override
  Future<void> addTg(Tg tg) {
    throw UnimplementedError(
      'Adding a TG will be implemented after the '
      'Google Sheet TG structure is finalized.',
    );
  }

  @override
  Future<void> updateTg(Tg tg) {
    throw UnimplementedError(
      'Updating a TG will be implemented after the '
      'Google Sheet TG structure is finalized.',
    );
  }

  @override
  Future<void> setActive(
    String tgId,
    bool active,
  ) {
    throw UnimplementedError(
      'TG active status is not yet represented '
      'in Daily_Attendace.',
    );
  }

  @override
  Future<void> deleteTg(String tgId) {
    throw UnimplementedError(
      'Deleting a TG will be implemented after '
      'the Google Sheet structure is finalized.',
    );
  }
}
