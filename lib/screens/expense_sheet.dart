import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state.dart';

/// Log, edit or delete the expense of one maintenance job.
void expenseSheet(BuildContext context, {required int assetId, ServiceRecord? existing}) {
  final s = context.read<AppState>();
  final isVehicle = s.assetById(assetId)?.isVehicle ?? false;
  final titles = s.reminders.where((r) => r.assetId == assetId).map((r) => r.title).toSet().toList();
  final title = TextEditingController(text: existing?.title ?? '');
  final amount = TextEditingController(text: existing == null ? '' : existing.cost.toStringAsFixed(0));
  final provider = TextEditingController(text: existing?.provider ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  final odo = TextEditingController(text: existing?.odometer?.toString() ?? '');
  var date = existing?.date ?? DateTime.now();
  String? error;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(existing == null ? 'Log expense' : 'Edit expense', style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (titles.isNotEmpty)
              Wrap(spacing: 8, children: [
                for (final t in titles) ActionChip(label: Text(t), onPressed: () => title.text = t),
              ]),
            const SizedBox(height: 8),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Maintenance (e.g. AC cleaning)')),
            const SizedBox(height: 8),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(DateFormat('d MMM y').format(date)),
              onPressed: () async {
                final d = await showDatePicker(
                    context: c, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 1)));
                if (d != null) set(() => date = d);
              },
            ),
            const SizedBox(height: 8),
            TextField(controller: provider, decoration: const InputDecoration(labelText: 'Service provider')),
            if (isVehicle) ...[
              const SizedBox(height: 8),
              TextField(controller: odo, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Odometer (km)')),
            ],
            const SizedBox(height: 8),
            TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: Theme.of(c).colorScheme.error))),
            const SizedBox(height: 16),
            Row(children: [
              if (existing != null)
                TextButton(
                  onPressed: () async {
                    await s.deleteExpense(existing);
                    if (c.mounted) Navigator.pop(c);
                  },
                  child: const Text('Delete'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  final amt = double.tryParse(amount.text);
                  if (title.text.trim().isEmpty || amt == null || amt < 0) {
                    set(() => error = 'Enter the maintenance name and a valid amount');
                    return;
                  }
                  final rec = ServiceRecord(
                    id: existing?.id,
                    assetId: assetId,
                    reminderId: existing?.reminderId,
                    title: title.text.trim(),
                    date: date,
                    cost: amt,
                    provider: provider.text.trim().isEmpty ? null : provider.text.trim(),
                    notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
                    odometer: int.tryParse(odo.text),
                    receiptPath: existing?.receiptPath,
                  );
                  if (existing == null) {
                    await s.addExpense(rec);
                  } else {
                    await s.updateExpense(rec);
                  }
                  if (c.mounted) Navigator.pop(c);
                },
                child: const Text('Save'),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}
