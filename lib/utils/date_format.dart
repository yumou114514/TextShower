String formatDocDate(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = date.toLocal();
  if (local.year == current.year &&
      local.month == current.month &&
      local.day == current.day) {
    return '${_two(local.hour)}:${_two(local.minute)}';
  }
  if (local.year == current.year) {
    return '${local.month}月${local.day}日';
  }
  return '${local.year}年${local.month}月${local.day}日';
}

String _two(int value) => value.toString().padLeft(2, '0');
