import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import 'items.dart';
import 'profile.dart';
import 'reminders.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(onGoTo: (i) => setState(() => _tab = i)),
      const ItemsScreen(),
      const RemindersScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
          child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAssetScreen())),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Items'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Reminders'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

String relativeDue(Reminder r, Asset? a) {
  if (r.nextDue != null) {
    final d = daysUntil(r.nextDue!);
    if (d < 0) return '${-d} day${d == -1 ? '' : 's'} overdue';
    if (d == 0) return 'Due today';
    return 'in $d day${d == 1 ? '' : 's'}';
  }
  return dueLabel(r, a);
}

class Dashboard extends StatelessWidget {
  final ValueChanged<int> onGoTo;
  const Dashboard({super.key, required this.onGoTo});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final overdue = s.byStatus(ReminderStatus.overdue);
    final today = s.byStatus(ReminderStatus.today);
    final upcoming = s.byStatus(ReminderStatus.upcoming);
    final next = s.nextDue();
    final nextAsset = next == null ? null : s.assetById(next.assetId);
    final nextIsLate = next != null && s.status(next) == ReminderStatus.overdue;
    const tints = [Color(0xFFDCE3FF), Color(0xFFD8F5EA), Color(0xFFFFF0CC), Color(0xFFFFE5E1)];
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 96), children: [
      FadeSlide(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.userName.isEmpty ? 'Hello 👋' : 'Hello, ${s.userName} 👋',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Keep your home & vehicles in top condition!'),
            ]),
          ),
          Stack(children: [
            IconButton(icon: const Icon(Icons.notifications_outlined), tooltip: 'Reminders', onPressed: () => onGoTo(2)),
            if (overdue.length + today.length > 0)
              const Positioned(
                right: 10,
                top: 10,
                child: SizedBox(
                  width: 9,
                  height: 9,
                  child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle)),
                ),
              ),
          ]),
          GestureDetector(
            onTap: () => onGoTo(3),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: cs.primary,
              child: Text(initialsOf(s.userName), style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      FadeSlide(
        index: 1,
        child: Tappable(
          onTap: () => next == null ? onGoTo(2) : showReminderActions(context, next),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: const Color(0xFFFFF0CC), borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text(categories[nextAsset?.category] ?? '🗓️', style: const TextStyle(fontSize: 26))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Next Service Due', style: Theme.of(context).textTheme.bodySmall),
                    Text(nextAsset?.name ?? 'Nothing scheduled', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    if (next != null)
                      Text('${next.title} · ${relativeDue(next, nextAsset)}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: nextIsLate ? statusColors['overdue'] : statusColors['upcoming'])),
                  ]),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      FadeSlide(
        index: 2,
        child: Row(children: [
          _Stat('Total Items', s.assets.length, cs.primary),
          const SizedBox(width: 10),
          _Stat('Upcoming', upcoming.length + today.length, statusColors['upcoming']!),
          const SizedBox(width: 10),
          _Stat('Overdue', overdue.length, statusColors['overdue']!),
        ]),
      ),
      const SizedBox(height: 24),
      Text('Categories', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
        children: [
          for (final (i, e) in categories.entries.indexed)
            FadeSlide(
              index: i + 3,
              child: Tappable(
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => ItemsScreen(initialCategory: e.key, standalone: true))),
                child: Card(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: tints[i % tints.length], borderRadius: BorderRadius.circular(14)),
                      child: Center(child: Text(e.value, style: const TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(height: 8),
                    Text(categoryLabels[e.key] ?? e.key, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    Text('${s.assets.where((a) => a.category == e.key).length}', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 24),
      Text('Maintenance timeline', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      if (s.reminders.where((r) => !r.paused).isEmpty)
        const EmptyState(emoji: '🗓️', title: 'Nothing scheduled', message: 'Add an item, then set its first reminder.')
      else
        for (final (i, r) in [...overdue, ...today, ...upcoming].take(6).indexed) ...[
          FadeSlide(index: i, child: ReminderTile(reminder: r)),
          const SizedBox(height: 8),
        ],
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 600),
              builder: (_, v, __) => Text(v.round().toString(),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
            ),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class EmptyState extends StatelessWidget {
  final String emoji, title, message;
  const EmptyState({super.key, required this.emoji, required this.title, required this.message});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
        ]),
      );
}

String dueLabel(Reminder r, Asset? a) {
  final parts = <String>[];
  if (r.nextDue != null) parts.add(DateFormat('d MMM y').format(r.nextDue!));
  if (r.nextDueKm != null) {
    final left = a?.odometer == null ? null : r.nextDueKm! - a!.odometer!;
    parts.add(left == null ? 'at ${r.nextDueKm} km' : (left <= 0 ? '${-left} km over' : '$left km left'));
  }
  return parts.isEmpty ? 'No due date' : parts.join(' · ');
}

class ReminderTile extends StatelessWidget {
  final Reminder reminder;
  const ReminderTile({super.key, required this.reminder});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final a = s.assetById(reminder.assetId);
    final st = s.status(reminder);
    final color = statusColors[st.name]!;
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: .15), child: Text(categories[a?.category] ?? '📦')),
        title: Text(reminder.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${a?.name ?? ''} · ${dueLabel(reminder, a)}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
          child: Text(st.name, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        onTap: () => showReminderActions(context, reminder),
      ),
    );
  }
}
