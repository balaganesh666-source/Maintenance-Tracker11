import 'package:flutter_test/flutter_test.dart';
import 'package:nivaro/models.dart';

void main() {
  test('spendByMonth sums records inside the window only', () {
    final now = DateTime(2026, 10, 28);
    ServiceRecord r(DateTime d, double c) => ServiceRecord(assetId: 1, title: 't', date: d, cost: c);
    final out = spendByMonth([r(DateTime(2026, 10, 5), 500), r(DateTime(2026, 10, 20), 250), r(DateTime(2026, 9, 10), 300), r(DateTime(2026, 3, 1), 999)], 3, now: now);
    expect(out.keys.toList(), ['2026-08', '2026-09', '2026-10']);
    expect(out['2026-08'], 0);
    expect(out['2026-09'], 300);
    expect(out['2026-10'], 750);
  });

  test('initialsOf', () {
    expect(initialsOf(''), '?');
    expect(initialsOf('bala'), 'B');
    expect(initialsOf('Bala Ganesh'), 'BG');
  });

  test('daysUntil ignores time of day', () {
    final now = DateTime(2026, 10, 28, 22);
    expect(daysUntil(DateTime(2026, 11, 2, 1), now: now), 5);
    expect(daysUntil(DateTime(2026, 10, 27), now: now), -1);
  });
}
