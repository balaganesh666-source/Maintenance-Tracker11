import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state.dart';
import '../widgets/animations.dart';
import 'shell.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return DefaultTabController(
      length: 4,
      child: Column(children: [
        const TabBar(isScrollable: true, tabs: [Tab(text: 'Overdue'), Tab(text: 'Today'), Tab(text: 'Upcoming'), Tab(text: 'Paused')]),
        Expanded(
          child: TabBarView(children: [
            for (final st in [ReminderStatus.overdue, ReminderStatus.today, ReminderStatus.upcoming, ReminderStatus.paused])
              Builder(builder: (_) {
                final l = s.byStatus(st);
                if (l.isEmpty) return Center(child: EmptyState(emoji: '✅', title: 'All clear', message: 'No ${st.name} reminders.'));
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: l.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => FadeSlide(index: i, child: ReminderTile(reminder: l[i])),
                );
              }),
          ]),
        ),
      ]),
    );
  }
}

void showReminderActions(BuildContext context, Reminder r) {
  final s = context.read<AppState>();
  showModalBottomSheet(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(s.assetById(r.assetId)?.name ?? '')),
        ListTile(leading: const Icon(Icons.check_circle_outline), title: const Text('Mark as done'), onTap: () { Navigator.pop(c); completeSheet(context, r); }),
        ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Edit'), onTap: () { Navigator.pop(c); editReminder(context, existing: r); }),
        ListTile(leading: Icon(r.paused ? Icons.play_arrow : Icons.pause), title: Text(r.paused ? 'Resume' : 'Pause'), onTap: () { Navigator.pop(c); s.togglePause(r); }),
        ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete'), onTap: () { Navigator.pop(c); s.deleteReminder(r); }),
      ]),
    ),
  );
}

void completeSheet(BuildContext context, Reminder r) {
  final asset = context.read<AppState>().assetById(r.assetId);
  final cost = TextEditingController();
  final provider = TextEditingController();
  final notes = TextEditingController();
  final odo = TextEditingController(text: asset?.odometer?.toString() ?? '');
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Complete: ${r.title}', style: Theme.of(c).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(controller: cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Expense for this maintenance (₹)')),
        const SizedBox(height: 8),
        TextField(controller: provider, decoration: const InputDecoration(labelText: 'Service provider')),
        if (asset?.isVehicle ?? false) ...[
          const SizedBox(height: 8),
          TextField(controller: odo, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Odometer (km)')),
        ],
        const SizedBox(height: 8),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () async {
              await context.read<AppState>().complete(r,
                  cost: (double.tryParse(cost.text) ?? 0).clamp(0, double.infinity).toDouble(),
                  provider: provider.text.trim().isEmpty ? null : provider.text.trim(),
                  notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
                  odometer: int.tryParse(odo.text));
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Save & schedule next'),
          ),
        ),
      ]),
    ),
  );
}

/// Create or edit a reminder. Pass [assetId] for new, [existing] to edit.
void editReminder(BuildContext context, {int? assetId, Reminder? existing}) {
  final r = existing ??
      Reminder(assetId: assetId!, title: '', nextDue: DateTime.now().add(const Duration(days: 30)));
  final title = TextEditingController(text: r.title);
  final every = TextEditingController(text: r.intervalValue?.toString() ?? '');
  final km = TextEditingController(text: r.intervalKm?.toString() ?? '');
  final nextKm = TextEditingController(text: r.nextDueKm?.toString() ?? '');
  var unit = r.intervalUnit ?? 'months';
  var kind = r.kind;
  var due = r.nextDue;
  var before = r.notifyDaysBefore;
  final isVehicle = context.read<AppState>().assetById(r.assetId)?.isVehicle ?? false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(existing == null ? 'New reminder' : 'Edit reminder', style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final k in reminderKinds)
                ChoiceChip(label: Text(k), selected: kind == k, onSelected: (_) => set(() {
                  kind = k;
                  if (title.text.isEmpty && k != 'Maintenance' && k != 'Custom') title.text = k == 'PUC' ? 'PUC renewal' : '$k expiry';
                })),
            ]),
            const SizedBox(height: 12),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title (e.g. AC cleaning)')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(due == null ? 'Pick due date' : 'Due ${DateFormat('d MMM y').format(due!)}'),
              onPressed: () async {
                final d = await showDatePicker(context: c, initialDate: due ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) set(() => due = d);
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: every, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Repeat every'))),
              const SizedBox(width: 8),
              DropdownButton<String>(value: unit, items: const [
                DropdownMenuItem(value: 'days', child: Text('days')),
                DropdownMenuItem(value: 'weeks', child: Text('weeks')),
                DropdownMenuItem(value: 'months', child: Text('months')),
              ], onChanged: (v) => set(() => unit = v!)),
            ]),
            if (isVehicle) ...[
              const SizedBox(height: 12),
              TextField(controller: km, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Repeat every (km), optional')),
              const SizedBox(height: 12),
              TextField(controller: nextKm, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Next due at odometer (km), optional')),
            ],
            const SizedBox(height: 12),
            Row(children: [
              const Text('Notify before'),
              const SizedBox(width: 12),
              DropdownButton<int>(value: before, items: const [
                DropdownMenuItem(value: 0, child: Text('on the day')),
                DropdownMenuItem(value: 1, child: Text('1 day')),
                DropdownMenuItem(value: 3, child: Text('3 days')),
                DropdownMenuItem(value: 7, child: Text('7 days')),
                DropdownMenuItem(value: 14, child: Text('14 days')),
                DropdownMenuItem(value: 30, child: Text('30 days')),
              ], onChanged: (v) => set(() => before = v!)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  r
                    ..title = title.text.trim()
                    ..kind = kind
                    ..nextDue = due
                    ..intervalValue = int.tryParse(every.text)
                    ..intervalUnit = int.tryParse(every.text) == null ? null : unit
                    ..intervalKm = int.tryParse(km.text)
                    ..nextDueKm = int.tryParse(nextKm.text)
                    ..notifyDaysBefore = before;
                  await context.read<AppState>().saveReminder(r);
                  if (c.mounted) Navigator.pop(c);
                },
                child: const Text('Save'),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}
