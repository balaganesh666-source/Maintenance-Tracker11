import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/animations.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _edit(BuildContext context, AppState s) {
    final name = TextEditingController(text: s.userName);
    final email = TextEditingController(text: s.userEmail);
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Your profile'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              s.setProfile(name.text, email.text);
              Navigator.pop(c);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(16), children: [
      FadeSlide(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: cs.primary,
                child: Text(initialsOf(s.userName), style: TextStyle(color: cs.onPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.userName.isEmpty ? 'Add your name' : s.userName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  if (s.userEmail.isNotEmpty) Text(s.userEmail),
                  const SizedBox(height: 4),
                  Text('${s.assets.length} items · ₹${s.totalSpend.toStringAsFixed(0)} spent on maintenance',
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
              IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit profile', onPressed: () => _edit(context, s)),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text('Theme gallery', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final p in palettes)
          GestureDetector(
            onTap: () => s.setSeed(p.color),
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.color,
                  shape: BoxShape.circle,
                  border: Border.all(width: 3, color: s.seed.toARGB32() == p.color.toARGB32() ? cs.onSurface : Colors.transparent),
                ),
              ),
              Text(p.name, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
      ]),
      const SizedBox(height: 16),
      SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('System')),
          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
        ],
        selected: {s.themeMode},
        onSelectionChanged: (v) => s.setThemeMode(v.first),
      ),
      const Divider(height: 32),
      ListTile(
        leading: const Icon(Icons.ios_share),
        title: const Text('Export backup (JSON)'),
        subtitle: const Text('Saves items, reminders and history to a file you choose where to share.'),
        onTap: () async {
          final dir = await getTemporaryDirectory();
          final f = File('${dir.path}/nivaro_backup.json');
          await f.writeAsString(const JsonEncoder.withIndent('  ').convert(await s.export()));
          await Share.shareXFiles([XFile(f.path)]);
        },
      ),
      const ListTile(
        leading: Icon(Icons.privacy_tip_outlined),
        title: Text('Privacy'),
        subtitle: Text('Nivaro stores everything on this device only. It collects no personal data and needs no account.'),
      ),
    ]);
  }
}
