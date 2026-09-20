import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/tg.dart';
import '../../data/repositories/tg_repository.dart';

class TgProvider extends ChangeNotifier {
  TgProvider(this._repository);

  final TgRepository _repository;
  StreamSubscription<List<Tg>>? _subscription;

  List<Tg> _items = const [];
  bool _loading = false;
  Object? _error;

  List<Tg> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  Object? get error => _error;

  void startListening({bool activeOnly = false}) {
    _subscription?.cancel();
    _setLoading(true);
    _error = null;
    _subscription = _repository.watchTgs(activeOnly: activeOnly).listen(
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

  Future<void> setActive(String tgId, bool active) async {
    try {
      await _repository.setActive(tgId, active);
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
