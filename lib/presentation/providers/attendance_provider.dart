import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/attendance.dart';
import '../../data/repositories/attendance_repository.dart';

class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider(this._repository);

  final AttendanceRepository _repository;
  StreamSubscription<List<Attendance>>? _subscription;

  List<Attendance> _items = const [];
  bool _loading = false;
  Object? _error;

  List<Attendance> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  Object? get error => _error;

  void listenForDate(DateTime date) {
    _subscription?.cancel();
    _setLoading(true);
    _error = null;

    _subscription = _repository.watchAttendanceForDate(date).listen(
      (items) {
        _items = items;
        _setLoading(false);
      },
      onError: (Object error) {
        _error = error;
        _setLoading(false);
      },
    );
  }

  Future<void> save(Attendance attendance) async {
    _error = null;
    notifyListeners();

    try {
      await _repository.createOrUpdateAttendance(attendance);
    } catch (error) {
      _error = error;
      notifyListeners();
      rethrow;
    }
  }

  void _setLoading(bool value) {
    if (_loading == value) return;
    _loading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
