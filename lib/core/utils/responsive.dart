import 'package:flutter/material.dart';

class Responsive {
  Responsive._();

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 1100;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 700;
  }
}
