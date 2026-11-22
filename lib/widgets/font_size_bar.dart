import 'package:flutter/material.dart';

Future<void> showQuickFontSizeSheet(
  BuildContext context, {
  required double value,
  required ValueChanged<double> onChanged,
  double min = 8,
  double max = 200,
}) {
  var current = value.clamp(min, max);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '快速调整字号',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${current.round()}',
                      key: const ValueKey<String>('quick-font-size-value'),
                      style: TextStyle(
                        fontSize: 16,
                        color: scheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Slider(
                  key: const ValueKey<String>('quick-font-size-slider'),
                  value: current,
                  min: min,
                  max: max,
                  onChanged: (next) {
                    setSheetState(() => current = next);
                    onChanged(next);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${min.round()}',
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                    Text(
                      '${max.round()}',
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

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
          width: 48,
          height: 48,
          child: InkWell(
            key: const ValueKey<String>('font-size-quick-adjust'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => showQuickFontSizeSheet(
              context,
              value: clamped,
              onChanged: onChanged,
              min: min,
              max: max,
            ),
            child: Center(
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
