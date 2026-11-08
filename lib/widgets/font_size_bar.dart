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
  });

  final double value;
  final bool auto;
  final ValueChanged<double> onChanged;
  final VoidCallback onAuto;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = value.clamp(min, max);
    return Row(
      children: [
        Icon(Icons.format_size, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Slider(
            value: clamped,
            min: min,
            max: max,
            divisions: ((max - min)).round(),
            label: '${clamped.round()}',
            activeColor: scheme.primary,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${clamped.round()}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
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
