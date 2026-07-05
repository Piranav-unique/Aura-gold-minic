import 'package:flutter/material.dart';

class FilterChipBar extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final bool allowClear;
  final bool compact;

  const FilterChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.allowClear = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final chipPadding = compact
        ? const EdgeInsets.symmetric(horizontal: 2)
        : const EdgeInsets.only(right: 8);
    final labelStyle = compact ? const TextStyle(fontSize: 12) : null;

    Widget chip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: chipPadding,
        child: FilterChip(
          label: Text(label.replaceAll('_', ' '), style: labelStyle),
          selected: selected,
          onSelected: (_) => onTap(),
          visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
          materialTapTargetSize: compact
              ? MaterialTapTargetSize.shrinkWrap
              : MaterialTapTargetSize.padded,
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 6)
              : null,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (allowClear)
            chip('All', selected == null, () => onSelected(null)),
          ...options.map(
            (option) => chip(
              option,
              selected == option,
              () => onSelected(option),
            ),
          ),
        ],
      ),
    );
  }
}
