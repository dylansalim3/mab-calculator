import 'package:flutter/material.dart';

import '../cpf/cpf_screen.dart';
import '../interest/interest_screen.dart';
import '../mortgage/mortgage_screen.dart';

/// One bottom-bar tab hosting the Interest, Mortgage and CPF calculators behind
/// a segmented switcher. Each keeps its inputs while you switch (IndexedStack).
class CalculatorsScreen extends StatefulWidget {
  const CalculatorsScreen({super.key});

  @override
  State<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends State<CalculatorsScreen> {
  static const _titles = [
    'Interest Calculator',
    'Mortgage Calculator',
    'CPF Interest Calculator',
  ];

  var _index = 0;

  @override
  Widget build(BuildContext context) {
    // Keep the three short labels on one line even with a large system font.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2);
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 608),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: scaler),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        padding: WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Interest', maxLines: 1),
                          ),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Mortgage', maxLines: 1),
                          ),
                        ),
                        ButtonSegment(
                          value: 2,
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('CPF', maxLines: 1),
                          ),
                        ),
                      ],
                      selected: {_index},
                      onSelectionChanged: (s) =>
                          setState(() => _index = s.first),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          InterestScreen(embedded: true),
          MortgageScreen(embedded: true),
          CpfScreen(embedded: true),
        ],
      ),
    );
  }
}
