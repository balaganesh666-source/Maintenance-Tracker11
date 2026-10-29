import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'models.dart';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();
  late Database _db;

  Future<void> open() async {
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'nivaro.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        await db.execute('''CREATE TABLE assets(
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, category TEXT NOT NULL,
          subtitle TEXT, odometer INTEGER)''');
        await db.execute('''CREATE TABLE reminders(
          id INTEGER PRIMARY KEY AUTOINCREMENT, asset_id INTEGER NOT NULL, title TEXT NOT NULL,
          kind TEXT NOT NULL, next_due INTEGER, interval_value INTEGER, interval_unit TEXT,
          interval_km INTEGER, next_due_km INTEGER, notify_days_before INTEGER NOT NULL DEFAULT 3,
          paused INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY(asset_id) REFERENCES assets(id) ON DELETE CASCADE)''');
        await db.execute('''CREATE TABLE service_records(
          id INTEGER PRIMARY KEY AUTOINCREMENT, asset_id INTEGER NOT NULL, reminder_id INTEGER,
          title TEXT NOT NULL, date INTEGER NOT NULL, cost REAL NOT NULL DEFAULT 0,
          provider TEXT, notes TEXT, odometer INTEGER, receipt_path TEXT,
          FOREIGN KEY(asset_id) REFERENCES assets(id) ON DELETE CASCADE)''');
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
      },
    );
  }

  Future<List<Asset>> assets() async =>
      (await _db.query('assets', orderBy: 'name COLLATE NOCASE')).map(Asset.fromMap).toList();

  Future<int> saveAsset(Asset a) async {
    if (a.id == null) return _db.insert('assets', a.toMap()..remove('id'));
    await _db.update('assets', a.toMap(), where: 'id=?', whereArgs: [a.id]);
    return a.id!;
  }

  Future<void> deleteAsset(int id) => _db.delete('assets', where: 'id=?', whereArgs: [id]);

  Future<List<Reminder>> reminders() async =>
      (await _db.query('reminders', orderBy: 'next_due IS NULL, next_due')).map(Reminder.fromMap).toList();

  Future<int> saveReminder(Reminder r) async {
    if (r.id == null) return _db.insert('reminders', r.toMap()..remove('id'));
    await _db.update('reminders', r.toMap(), where: 'id=?', whereArgs: [r.id]);
    return r.id!;
  }

  Future<void> deleteReminder(int id) => _db.delete('reminders', where: 'id=?', whereArgs: [id]);

  Future<List<ServiceRecord>> services() async =>
      (await _db.query('service_records', orderBy: 'date DESC')).map(ServiceRecord.fromMap).toList();

  Future<void> addService(ServiceRecord s) => _db.insert('service_records', s.toMap()..remove('id'));

  Future<void> updateService(ServiceRecord s) =>
      _db.update('service_records', s.toMap(), where: 'id=?', whereArgs: [s.id]);

  Future<void> deleteService(int id) => _db.delete('service_records', where: 'id=?', whereArgs: [id]);

  Future<String?> setting(String key) async {
    final r = await _db.query('settings', where: 'key=?', whereArgs: [key]);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> putSetting(String key, String value) =>
      _db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<Map<String, Object?>> exportAll() async => {
        'app': 'nivaro',
        'version': 1,
        'assets': await _db.query('assets'),
        'reminders': await _db.query('reminders'),
        'service_records': await _db.query('service_records'),
      };

  Future<void> importAll(Map<String, dynamic> data) async {
    await _db.transaction((t) async {
      for (final tbl in ['service_records', 'reminders', 'assets']) {
        await t.delete(tbl);
      }
      for (final tbl in ['assets', 'reminders', 'service_records']) {
        for (final row in (data[tbl] as List)) {
          await t.insert(tbl, Map<String, Object?>.from(row as Map));
        }
      }
    });
  }
}
