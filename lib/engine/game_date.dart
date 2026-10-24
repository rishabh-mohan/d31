/// The calendar. KSS encodes every date as `DATE_YYYYMMDDTT`, where the last
/// two digits are a *tick* -- the action slot within the day, not an hour.
/// Story 16 references ticks 00..14, so a day is 15 slots by default; the real
/// number is `calendar.ticksPerDay` in pack.json and may be changed.
library;

class GameDate implements Comparable<GameDate> {
  final DateTime day;
  final int tick;

  const GameDate(this.day, this.tick);

  static final RegExp _code = RegExp(r'^DATE_(\d{4})(\d{2})(\d{2})(\d{2})$');

  /// Parses `DATE_2023101600`. Returns null for anything else so a malformed
  /// hand-edited pack degrades to "this condition never matches" instead of
  /// crashing the run.
  static GameDate? tryParse(String? code) {
    if (code == null) return null;
    final m = _code.firstMatch(code);
    if (m == null) return null;
    return GameDate(
      DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)),
      int.parse(m[4]!),
    );
  }

  static GameDate parse(String code) {
    final d = tryParse(code);
    if (d == null) throw FormatException('not a date code: $code');
    return d;
  }

  String get code =>
      'DATE_${_p(day.year, 4)}${_p(day.month, 2)}${_p(day.day, 2)}${_p(tick, 2)}';

  /// The day alone, tick zeroed -- what a "is it this day?" check compares.
  String get dayCode =>
      'DATE_${_p(day.year, 4)}${_p(day.month, 2)}${_p(day.day, 2)}';

  static String _p(int v, int w) => v.toString().padLeft(w, '0');

  GameDate advance(int ticks, int ticksPerDay) {
    var t = tick + ticks;
    var d = day;
    while (t >= ticksPerDay) {
      t -= ticksPerDay;
      d = addDays(d, 1);
    }
    return GameDate(d, t);
  }

  GameDate nextDay() => GameDate(addDays(day, 1), 0);

  /// Calendar days, not 24-hour spans. `day` is local midnight, so adding a
  /// Duration across a daylight-saving change (3 Nov 2024 and 5 Nov 2023 in
  /// the US, both inside a run) lands on 23:00 the day before, and from then
  /// on no `DATE_` condition matches.
  static DateTime addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  bool get isWeekend =>
      day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

  int daysUntil(GameDate other) => DateTime.utc(
    other.day.year,
    other.day.month,
    other.day.day,
  ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;

  /// Sort key used for ordering and for `DATE_INT` style comparisons.
  int get asInt =>
      day.year * 1000000 + day.month * 10000 + day.day * 100 + tick;

  @override
  int compareTo(GameDate other) => asInt.compareTo(other.asInt);

  @override
  bool operator ==(Object other) =>
      other is GameDate && other.day == day && other.tick == tick;

  @override
  int get hashCode => Object.hash(day, tick);

  @override
  String toString() => code;
}
