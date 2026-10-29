import 'package:flutter/material.dart';
import 'db.dart';
import 'models.dart';
import 'notification_service.dart';
import 'theme.dart';

class AppState extends ChangeNotifier {
  List<Asset> assets = [];
  List<Reminder> reminders = [];
  List<ServiceRecord> services = [];
  Color seed = palettes.first.color;
  ThemeMode themeMode = ThemeMode.system;
  bool onboarded = false;
  bool notificationsGranted = true;
  String userName = '';
  String userEmail = '';

  final _db = AppDb.instance;

  Future<void> init() async {
    await _db.open();
    await NotificationService.instance.init();
    final s = await _db.setting('seed');
    if (s != null) seed = Color(int.parse(s));
    final m = await _db.setting('themeMode');
    if (m != null) themeMode = ThemeMode.values.firstWhere((e) => e.name == m, orElse: () => ThemeMode.system);
    onboarded = await _db.setting('onboarded') == '1';
    userName = await _db.setting('userName') ?? '';
    userEmail = await _db.setting('userEmail') ?? '';
    await refresh();
  }

  Future<void> refresh() async {
    assets = await _db.assets();
    reminders = await _db.reminders();
    services = await _db.services();
    // Rebuilding every schedule on launch (and from the boot receiver) restores reminders after restart.
    await NotificationService.instance
        .rescheduleAll(reminders, {for (final a in assets) a.id!: a.name});
    notifyListeners();
  }

  Asset? assetById(int id) {
    for (final a in assets) {
      if (a.id == id) return a;
    }
    return null;
  }

  ReminderStatus status(Reminder r) => statusOf(r, odometer: assetById(r.assetId)?.odometer);

  List<Reminder> byStatus(ReminderStatus s) => reminders.where((r) => status(r) == s).toList();

  double get totalSpend => services.fold(0.0, (a, b) => a + b.cost);

  Future<void> finishOnboarding() async {
    onboarded = true;
    await _db.putSetting('onboarded', '1');
    notificationsGranted = await NotificationService.instance.requestPermission();
    notifyListeners();
  }

  Future<void> saveAsset(Asset a) async { await _db.saveAsset(a); await refresh(); }
  Future<void> deleteAsset(Asset a) async { await _db.deleteAsset(a.id!); await refresh(); }
  Future<void> saveReminder(Reminder r) async { await _db.saveReminder(r); await refresh(); }
  Future<void> deleteReminder(Reminder r) async { await _db.deleteReminder(r.id!); await refresh(); }

  Future<void> togglePause(Reminder r) async {
    r.paused = !r.paused;
    await saveReminder(r);
  }

  Future<void> updateOdometer(Asset a, int km) async {
    a.odometer = km;
    await saveAsset(a);
  }

  /// Marks maintenance done: stores history and schedules the next due date / km.
  Future<void> complete(Reminder r,
      {double cost = 0, String? provider, String? notes, int? odometer, DateTime? date}) async {
    final done = date ?? DateTime.now();
    final asset = assetById(r.assetId);
    if (odometer != null && asset != null) {
      asset.odometer = odometer;
      await _db.saveAsset(asset);
    }
    await _db.addService(ServiceRecord(
        assetId: r.assetId, reminderId: r.id, title: r.title, date: done,
        cost: cost, provider: provider, notes: notes, odometer: odometer ?? asset?.odometer));
    if (r.intervalValue != null && r.intervalUnit != null) {
      r.nextDue = addInterval(done, r.intervalValue!, r.intervalUnit!);
    } else {
      r.nextDue = null;
    }
    if (r.intervalKm != null) {
      final odo = odometer ?? asset?.odometer;
      if (odo != null) r.nextDueKm = odo + r.intervalKm!;
    }
    if (r.nextDue == null && r.nextDueKm == null) r.paused = true; // one-off finished
    await saveReminder(r);
  }

  Reminder? nextDue() {
    final l = reminders.where((r) => !r.paused && r.nextDue != null).toList()
      ..sort((a, b) => a.nextDue!.compareTo(b.nextDue!));
    return l.isEmpty ? null : l.first;
  }

  Future<void> setProfile(String name, String email) async {
    userName = name.trim();
    userEmail = email.trim();
    await _db.putSetting('userName', userName);
    await _db.putSetting('userEmail', userEmail);
    notifyListeners();
  }

  /// Records an expense for a maintenance job (with or without a reminder).
  Future<void> addExpense(ServiceRecord r) async {
    final a = assetById(r.assetId);
    if (r.odometer != null && a != null && a.isVehicle && (a.odometer ?? 0) < r.odometer!) {
      a.odometer = r.odometer;
      await _db.saveAsset(a);
    }
    await _db.addService(r);
    await refresh();
  }

  Future<void> updateExpense(ServiceRecord r) async { await _db.updateService(r); await refresh(); }
  Future<void> deleteExpense(ServiceRecord r) async { await _db.deleteService(r.id!); await refresh(); }

  double spendFor(int assetId) => services.where((s) => s.assetId == assetId).fold(0.0, (t, s) => t + s.cost);
  Map<String, double> monthlySpend([int months = 6]) => spendByMonth(services, months);

  Future<void> setSeed(Color c) async {
    seed = c;
    await _db.putSetting('seed', c.toARGB32().toString());
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await _db.putSetting('themeMode', m.name);
    notifyListeners();
  }

  Future<Map<String, Object?>> export() => _db.exportAll();
  Future<void> importData(Map<String, dynamic> d) async { await _db.importAll(d); await refresh(); }
}
