import 'package:flutter/foundation.dart';

class NavigationController extends ChangeNotifier {
  String _selectedRoute = '/dashboard';

  String get selectedRoute => _selectedRoute;

  void select(String route) {
    if (_selectedRoute == route) return;
    _selectedRoute = route;
    notifyListeners();
  }
}
