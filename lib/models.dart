const categories = <String, String>{
  'Vehicle': '🚗',
  'Appliance': '🧊',
  'Home Service': '🏠',
  'Other': '📦',
};

const reminderKinds = <String>['Maintenance', 'Warranty', 'Insurance', 'PUC', 'Custom'];

class Asset {
  int? id;
  String name;
  String category;
  String? subtitle;
  int? odometer;
  Asset({this.id, required this.name, required this.category, this.subtitle, this.odometer});

  bool get isVehicle => category == 'Vehicle';

  Map<String, Object?> toMap() =>
      {'id': id, 'name': name, 'category': category, 'subtitle': subtitle, 'odometer': odometer};

  factory Asset.fromMap(Map<String, Object?> m) => Asset(
        id: m['id'] as int?,
        name: m['name'] as String,
        category: m['category'] as String,
        subtitle: m['subtitle'] as String?,
        odometer: m['odometer'] as int?,
      );
}

class Reminder {
  int? id;
  int assetId;
  String title;
  String kind;
  DateTime? nextDue;
  int? intervalValue;
  String? intervalUnit; // days | weeks | months
  int? intervalKm;
  int? nextDueKm;
  int notifyDaysBefore;
  bool paused;

  Reminder({
    this.id,
    required this.assetId,
    required this.title,
    this.kind = 'Maintenance',
    this.nextDue,
    this.intervalValue,
    this.intervalUnit,
    this.intervalKm,
    this.nextDueKm,
    this.notifyDaysBefore = 3,
    this.paused = false,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'asset_id': assetId,
        'title': title,
        'kind': kind,
        'next_due': nextDue?.millisecondsSinceEpoch,
        'interval_value': intervalValue,
        'interval_unit': intervalUnit,
        'interval_km': intervalKm,
        'next_due_km': nextDueKm,
        'notify_days_before': notifyDaysBefore,
        'paused': paused ? 1 : 0,
      };

  factory Reminder.fromMap(Map<String, Object?> m) => Reminder(
        id: m['id'] as int?,
        assetId: m['asset_id'] as int,
        title: m['title'] as String,
        kind: m['kind'] as String,
        nextDue: m['next_due'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['next_due'] as int),
        intervalValue: m['interval_value'] as int?,
        intervalUnit: m['interval_unit'] as String?,
        intervalKm: m['interval_km'] as int?,
        nextDueKm: m['next_due_km'] as int?,
        notifyDaysBefore: m['notify_days_before'] as int,
        paused: (m['paused'] as int) == 1,
      );
}

class ServiceRecord {
  int? id;
  int assetId;
  int? reminderId;
  String title;
  DateTime date;
  double cost;
  String? provider;
  String? notes;
  int? odometer;
  String? receiptPath;
  ServiceRecord({
    this.id,
    required this.assetId,
    this.reminderId,
    required this.title,
    required this.date,
    this.cost = 0,
    this.provider,
    this.notes,
    this.odometer,
    this.receiptPath,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'asset_id': assetId,
        'reminder_id': reminderId,
        'title': title,
        'date': date.millisecondsSinceEpoch,
        'cost': cost,
        'provider': provider,
        'notes': notes,
        'odometer': odometer,
        'receipt_path': receiptPath,
      };

  factory ServiceRecord.fromMap(Map<String, Object?> m) => ServiceRecord(
        id: m['id'] as int?,
        assetId: m['asset_id'] as int,
        reminderId: m['reminder_id'] as int?,
        title: m['title'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        cost: (m['cost'] as num).toDouble(),
        provider: m['provider'] as String?,
        notes: m['notes'] as String?,
        odometer: m['odometer'] as int?,
        receiptPath: m['receipt_path'] as String?,
      );
}

enum ReminderStatus { overdue, today, upcoming, paused }

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addInterval(DateTime d, int value, String unit) {
  switch (unit) {
    case 'days':
      return d.add(Duration(days: value));
    case 'weeks':
      return d.add(Duration(days: 7 * value));
    default:
      return DateTime(d.year, d.month + value, d.day);
  }
}

ReminderStatus statusOf(Reminder r, {int? odometer, DateTime? now}) {
  if (r.paused) return ReminderStatus.paused;
  final today = dateOnly(now ?? DateTime.now());
  if (r.nextDue != null) {
    final d = dateOnly(r.nextDue!);
    if (d.isBefore(today)) return ReminderStatus.overdue;
    if (d == today) return ReminderStatus.today;
  }
  if (r.nextDueKm != null && odometer != null && odometer >= r.nextDueKm!) {
    return ReminderStatus.overdue;
  }
  return ReminderStatus.upcoming;
}

const categoryLabels = <String, String>{
  'Vehicle': 'Vehicles',
  'Appliance': 'Home Appliances',
  'Home Service': 'Home Services',
  'Other': 'Others',
};

int daysUntil(DateTime d, {DateTime? now}) => dateOnly(d).difference(dateOnly(now ?? DateTime.now())).inDays;

String initialsOf(String name) {
  final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  if (p.length == 1) return p.first[0].toUpperCase();
  return (p.first[0] + p.last[0]).toUpperCase();
}

/// Maintenance spend per month (key yyyy-MM) for the last [months] months, oldest first.
Map<String, double> spendByMonth(List<ServiceRecord> records, int months, {DateTime? now}) {
  final n = now ?? DateTime.now();
  String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
  final out = <String, double>{};
  for (var i = months - 1; i >= 0; i--) {
    out[key(DateTime(n.year, n.month - i))] = 0;
  }
  for (final r in records) {
    final k = key(r.date);
    if (out.containsKey(k)) out[k] = out[k]! + r.cost;
  }
  return out;
}
