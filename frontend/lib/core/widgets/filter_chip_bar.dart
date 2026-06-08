import 'package:flutter/material.dart';

class FilterChipBar extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final bool allowClear;

  const FilterChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.allowClear = true,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (allowClear)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('All'),
                selected: selected == null,
                onSelected: (_) => onSelected(null),
              ),
            ),
          ...options.map<Widget>(
            (option) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(option.replaceAll('_', ' ')),
                selected: selected == option,
                onSelected: (_) => onSelected(option),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
