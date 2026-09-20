import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_page.dart';

class ExcelImportPage extends StatelessWidget {
  const ExcelImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Excel Import',
      description: 'Import TG and student data from Excel in a later phase.',
      icon: Icons.table_view_outlined,
    );
  }
}
