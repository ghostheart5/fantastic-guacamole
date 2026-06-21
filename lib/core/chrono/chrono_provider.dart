import 'package:flutter/foundation.dart';

import 'calendar_entry.dart';
import 'calendar_service.dart';
import 'task.dart';
import 'time_block.dart';

class ChronoProvider extends ChangeNotifier {
  ChronoProvider({CalendarService? service}) : _service = service ?? CalendarService();

  final CalendarService _service;

  DateTime selectedDate = DateTime.now();
  bool isFocusMode = false;

  CalendarEntry get currentDay => _service.getDay(selectedDate);

  void selectDate(DateTime date) {
    selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  void addTimeBlock(TimeBlock block) {
    _service.addTimeBlock(selectedDate, block);
    notifyListeners();
  }

  void addTask(Task task) {
    _service.addTask(selectedDate, task);
    notifyListeners();
  }

  void completeTask(String id) {
    _service.completeTask(selectedDate, id);
    notifyListeners();
  }

  void startFocus() {
    isFocusMode = true;
    notifyListeners();
  }

  void endFocus() {
    isFocusMode = false;
    notifyListeners();
  }
}
