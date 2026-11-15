import 'package:flutter/material.dart';

class FontSizeBar extends StatelessWidget {
  const FontSizeBar({
    super.key,
    required this.value,
    required this.auto,
    required this.onChanged,
    required this.onAuto,
    this.min = 8,
    this.max = 200,
    this.step = 10,
  });

  final double value;
  final bool auto;
  final ValueChanged<double> onChanged;
  final VoidCallback onAuto;
  final double min;
  final double max;
  final double step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = value.clamp(min, max);
    return Row(
      children: [
        Icon(Icons.format_size, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        IconButton(
          tooltip: '减小字号',
          visualDensity: VisualDensity.compact,
          onPressed: clamped <= min
              ? null
              : () => onChanged((clamped - step).clamp(min, max)),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${clamped.round()}',
            key: const ValueKey<String>('font-size-value'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton(
          tooltip: '增大字号',
          visualDensity: VisualDensity.compact,
          onPressed: clamped >= max
              ? null
              : () => onChanged((clamped + step).clamp(min, max)),
          icon: const Icon(Icons.add),
        ),
        const Spacer(),
        FilterChip(
          label: const Text('自动'),
          selected: auto,
          showCheckmark: false,
          onSelected: (_) => onAuto(),
        ),
      ],
    );
  }
}
