import 'package:flutter/material.dart';

import '../../core/models/run.dart';

/// Monte Carlo / Bootstrap / Walk-Forward visualization — pure widgets (no
/// ECharts in the React original either). Each section renders as a card.
class ValidationPanel extends StatelessWidget {
  const ValidationPanel({super.key, required this.data});

  final ValidationData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (data.monteCarlo != null) _monteCarlo(context, data.monteCarlo!),
        if (data.bootstrap != null) _bootstrap(context, data.bootstrap!),
        if (data.walkForward != null) _walkForward(context, data.walkForward!),
        if (data.monteCarlo == null && data.bootstrap == null && data.walkForward == null)
          const ListTile(title: Text('No validation data for this run.')),
      ],
    );
  }

  Widget _monteCarlo(BuildContext context, MonteCarlo m) => _card(context, 'Monte Carlo', [
        _kv('Actual Sharpe', m.actualSharpe.toStringAsFixed(2)),
        _kv('Simulated mean', m.simulatedSharpeMean.toStringAsFixed(2)),
        _kv('p-value (Sharpe)', m.pValueSharpe.toStringAsFixed(3)),
        _kv('Simulations', '${m.nSimulations}'),
        _bar(context, 'Sharpe significance', m.pValueSharpe, invert: true),
        if (m.error != null) _err(m.error!),
      ]);

  Widget _bootstrap(BuildContext context, Bootstrap b) => _card(context, 'Bootstrap', [
        _kv('Observed Sharpe', b.observedSharpe.toStringAsFixed(2)),
        _kv('95% CI', '[${b.ciLower.toStringAsFixed(2)}, ${b.ciUpper.toStringAsFixed(2)}]'),
        _kv('Median Sharpe', b.ciLower.toStringAsFixed(2)),
        _bar(context, 'Prob(Sharpe > 0)', b.probPositive),
        if (b.error != null) _err(b.error!),
      ]);

  Widget _walkForward(BuildContext context, WalkForward w) => _card(context, 'Walk-Forward', [
        _kv('Windows', '${w.profitableWindows}/${w.nWindows} profitable'),
        _kv('Consistency', '${(w.consistencyRate * 100).toStringAsFixed(0)}%'),
        _kv('Mean return / Sharpe',
            '${(w.returnMean * 100).toStringAsFixed(1)}% / ${w.sharpeMean.toStringAsFixed(2)}'),
        const SizedBox(height: 6),
        SizedBox(
          height: 70,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final win in w.windows)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    height: 40 + (win.ret * 400).clamp(2.0, 60.0).abs().toDouble(),
                    color: win.ret >= 0 ? Colors.green : Colors.red,
                  ),
                ),
            ],
          ),
        ),
        if (w.error != null) _err(w.error!),
      ]);

  Widget _card(BuildContext context, String title, List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...children,
          ]),
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(fontSize: 13)),
          Text(v,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
        ]),
      );

  Widget _bar(BuildContext context, String label, double value, {bool invert = false}) {
    final ratio = (value).clamp(0.0, 1.0);
    final good = invert ? 1 - ratio : ratio;
    final color = good > 0.95
        ? Colors.green
        : good > 0.8
            ? Colors.amber
            : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio, minHeight: 8, backgroundColor: Colors.black12, color: color,
          ),
        ),
      ]),
    );
  }

  Widget _err(String msg) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 12)),
      );
}
