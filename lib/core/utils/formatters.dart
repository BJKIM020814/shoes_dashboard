String formatWon(num value) => '${value.toStringAsFixed(0)}원';
String formatDate(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';
