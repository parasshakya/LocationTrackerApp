import 'package:intl/intl.dart';

String formateDateTime(DateTime dateTime) {
  final formatter =
      DateFormat('hh:mm:ss a'); // 12-hour format with seconds and AM/PM

  return formatter.format(dateTime);
}
