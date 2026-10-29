import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _c = PageController();
  int _i = 0;
  final _name = TextEditingController();
  static const _pages = [
    ('🏠', 'Everything you own, one place', 'Add vehicles, appliances and home services in seconds.'),
    ('⏰', 'Never miss a service', 'Reminders by date, interval, kilometres, warranty, insurance and PUC.'),
    ('🔒', 'Private and offline', 'Your data stays on this phone. Export a backup whenever you like.'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _c,
              itemCount: _pages.length,
              onPageChanged: (v) => setState(() => _i = v),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(_pages[i].$1, style: const TextStyle(fontSize: 72)),
                  ),
                  const SizedBox(height: 32),
                  Text(_pages[i].$2, textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text(_pages[i].$3, textAlign: TextAlign.center),
                ]),
              ),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _pages.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.all(4),
                width: i == _i ? 24 : 8, height: 8,
                decoration: BoxDecoration(
                    color: i == _i ? cs.primary : cs.outlineVariant, borderRadius: BorderRadius.circular(8)),
              ),
          ]),
          if (_i == _pages.length - 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'Your name (optional)')),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_i < _pages.length - 1) {
                    _c.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  } else {
                    final st = context.read<AppState>();
                    st.setProfile(_name.text, st.userEmail);
                    st.finishOnboarding();
                  }
                },
                child: Text(_i < _pages.length - 1 ? 'Next' : 'Get started'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
