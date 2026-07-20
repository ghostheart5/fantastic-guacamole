import 'package:fantastic_guacamole/features/monetization/domain/monetization_catalog.dart';
import 'package:flutter/material.dart';

class FeatureComparisonTable extends StatelessWidget {
  const FeatureComparisonTable({super.key, required this.rows});

  final List<FeatureComparisonRow> rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const <DataColumn>[
          DataColumn(label: Text('Feature')),
          DataColumn(label: Text('Free')),
          DataColumn(label: Text('Monthly')),
          DataColumn(label: Text('Yearly')),
          DataColumn(label: Text('Lifetime')),
        ],
        rows: rows
            .map(
              (FeatureComparisonRow row) => DataRow(
                cells: <DataCell>[
                  DataCell(Text(row.feature)),
                  DataCell(Text(row.freeValue)),
                  DataCell(Text(row.monthlyValue)),
                  DataCell(Text(row.yearlyValue)),
                  DataCell(Text(row.lifetimeValue)),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}