import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/student.dart';
import '../../data/repositories/student_repository.dart';

class StudentProvider extends ChangeNotifier {
  StudentProvider(this._repository);

  final StudentRepository _repository;
  StreamSubscription<List<Student>>? _subscription;

  List<Student> _items = const [];
  bool _loading = false;
  Object? _error;

  List<Student> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  Object? get error => _error;

  void startListening({bool activeOnly = false}) {
    _subscription?.cancel();
    _setLoading(true);
    _error = null;
    _subscription = _repository.watchStudents(activeOnly: activeOnly).listen(
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

  Future<void> addStudent(Student student) async {
    try {
      await _repository.addStudent(student);
    } catch (error) {
      _error = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateStudent(Student student) async {
    try {
      await _repository.updateStudent(student);
    } catch (error) {
      _error = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteStudent(String studentId) async {
    try {
      await _repository.deleteStudent(studentId);
    } catch (error) {
      _error = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> assignToTg(String studentId, String? tgId) async {
    try {
      await _repository.assignToTg(studentId, tgId);
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
