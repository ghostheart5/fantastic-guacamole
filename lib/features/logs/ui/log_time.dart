String logTimeFromIndex(int index) {
  final int hour = (8 + index).clamp(0, 23);
  return '${hour.toString().padLeft(2, '0')}:00';
}
