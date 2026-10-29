import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state.dart';
import '../widgets/animations.dart';
import 'expense_sheet.dart';
import 'reminders.dart';
import 'shell.dart';

class ItemsScreen extends StatefulWidget {
  final String? initialCategory;
  final bool standalone;
  const ItemsScreen({super.key, this.initialCategory, this.standalone = false});
  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  String _q = '';
  String? _cat;
  @override
  void initState() {
    super.initState();
    _cat = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final list = s.assets
        .where((a) => (_cat == null || a.category == _cat) && a.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    final body = Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search items'),
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: const Text('All'), selected: _cat == null, onSelected: (_) => setState(() => _cat = null))),
          for (final c in categories.keys)
            Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: Text(c), selected: _cat == c, onSelected: (_) => setState(() => _cat = c))),
        ]),
      ),
      Expanded(
        child: list.isEmpty
            ? const Center(child: EmptyState(emoji: '📦', title: 'No items yet', message: 'Tap + to add your first vehicle or appliance.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final a = list[i];
                  final rs = s.reminders.where((r) => r.assetId == a.id).toList();
                  final overdue = rs.where((r) => s.status(r) == ReminderStatus.overdue).length;
                  return Card(
                    child: ListTile(
                      leading: Text(categories[a.category] ?? '📦', style: const TextStyle(fontSize: 28)),
                      title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([a.subtitle, if (a.odometer != null) '${a.odometer} km'].whereType<String>().join(' · ')),
                      trailing: overdue > 0
                          ? Chip(label: Text('$overdue overdue'), backgroundColor: Colors.red.withValues(alpha: .15))
                          : Text('${rs.length} reminders'),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssetDetail(assetId: a.id!))),
                    ),
                  );
                },
              ),
      ),
    ]);
    if (widget.standalone) return Scaffold(appBar: AppBar(title: Text(_cat ?? 'Items')), body: body);
    return body;
  }
}

class AddAssetScreen extends StatefulWidget {
  const AddAssetScreen({super.key});
  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  static const presets = <(String, String, String)>[
    ('Car', 'Vehicle', '🚗'), ('Bike', 'Vehicle', '🏍️'), ('Scooter', 'Vehicle', '🛵'),
    ('Air conditioner', 'Appliance', '❄️'), ('Refrigerator', 'Appliance', '🧊'),
    ('Washing machine', 'Appliance', '🧺'), ('Water purifier', 'Appliance', '💧'),
    ('Home service', 'Home Service', '🛠️'), ('Custom item', 'Other', '📦'),
  ];
  String? _name, _category;
  final _nameC = TextEditingController();
  final _subC = TextEditingController();
  final _odoC = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add item')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final p in presets)
            ChoiceChip(
              label: Text('${p.$3} ${p.$1}'),
              selected: _name == p.$1,
              onSelected: (_) => setState(() {
                _name = p.$1;
                _category = p.$2;
                _nameC.text = p.$1 == 'Custom item' ? '' : p.$1;
              }),
            ),
        ]),
        const SizedBox(height: 20),
        TextField(controller: _nameC, decoration: const InputDecoration(labelText: 'Name (e.g. Hall AC)')),
        const SizedBox(height: 12),
        TextField(controller: _subC, decoration: const InputDecoration(labelText: 'Model / registration / location (optional)')),
        if (_category == 'Vehicle') ...[
          const SizedBox(height: 12),
          TextField(controller: _odoC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current odometer (km)')),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _category == null
              ? null
              : () async {
                  final name = _nameC.text.trim().isEmpty ? _name! : _nameC.text.trim();
                  await context.read<AppState>().saveAsset(Asset(
                      name: name, category: _category!,
                      subtitle: _subC.text.trim().isEmpty ? null : _subC.text.trim(),
                      odometer: int.tryParse(_odoC.text)));
                  if (context.mounted) Navigator.pop(context);
                },
          child: const Text('Save'),
        ),
      ]),
    );
  }
}

class AssetDetail extends StatelessWidget {
  final int assetId;
  const AssetDetail({super.key, required this.assetId});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final a = s.assetById(assetId);
    if (a == null) return const Scaffold();
    final rs = s.reminders.where((r) => r.assetId == a.id).toList();
    final history = s.services.where((x) => x.assetId == a.id).toList();
    final spend = history.fold(0.0, (t, x) => t + x.cost);
    return Scaffold(
      appBar: AppBar(title: Text(a.name), actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Delete item?'),
                content: const Text('Its reminders and service history will be deleted too.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              await context.read<AppState>().deleteAsset(a);
              if (context.mounted) Navigator.pop(context);
            }
          },
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editReminder(context, assetId: a.id!),
        icon: const Icon(Icons.add_alarm),
        label: const Text('Reminder'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
        if (a.isVehicle)
          Card(
            child: ListTile(
              leading: const Icon(Icons.speed),
              title: Text('${a.odometer ?? '—'} km'),
              subtitle: const Text('Kilometre reminders only update when you enter a new reading.'),
              trailing: TextButton(
                child: const Text('Update'),
                onPressed: () async {
                  final c = TextEditingController(text: '${a.odometer ?? ''}');
                  final v = await showDialog<int>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Odometer reading'),
                      content: TextField(controller: c, keyboardType: TextInputType.number, autofocus: true),
                      actions: [TextButton(onPressed: () => Navigator.pop(d, int.tryParse(c.text)), child: const Text('Save'))],
                    ),
                  );
                  if (v != null && context.mounted) context.read<AppState>().updateOdometer(a, v);
                },
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text('Reminders', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (rs.isEmpty) const EmptyState(emoji: '⏰', title: 'No reminders', message: 'Add one with the button below.'),
        for (final r in rs) ...[ReminderTile(reminder: r), const SizedBox(height: 8)],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text('Service history', style: Theme.of(context).textTheme.titleMedium)),
          Text('Total ₹${spend.toStringAsFixed(0)}'),
          TextButton.icon(
            onPressed: () => expenseSheet(context, assetId: a.id!),
            icon: const Icon(Icons.add),
            label: const Text('Expense'),
          ),
        ]),
        const SizedBox(height: 8),
        if (history.isEmpty) const EmptyState(emoji: '🧾', title: 'No history yet', message: 'Completed maintenance appears here.'),
        for (final (i, h) in history.indexed)
          FadeSlide(
            index: i,
            child: Card(
            child: ListTile(
              onTap: () => expenseSheet(context, assetId: a.id!, existing: h),
              title: Text(h.title),
              subtitle: Text([DateFormat('d MMM y').format(h.date), if (h.provider != null) h.provider!, if (h.notes != null) h.notes!].join(' · ')),
              trailing: Text('₹${h.cost.toStringAsFixed(0)}'),
            ),
          ),
          ),
      ]),
    );
  }
}
