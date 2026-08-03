import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolWidgetTest('patrol smoke harness boots a widget tree', ($) async {
    await $.pumpWidgetAndSettle(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Patrol Smoke Ready'),
          ),
        ),
      ),
    );

    expect($('Patrol Smoke Ready'), findsOneWidget);
  });
}
