import 'package:flutter/material.dart';

class DataTableColumn<T> {
  final String label;
  final Widget Function(T item) cellBuilder;
  final Comparable Function(T item)? valueGetter;

  const DataTableColumn({
    required this.label,
    required this.cellBuilder,
    this.valueGetter,
  });
}

class PremiumDataTable<T> extends StatelessWidget {
  final List<T> items;
  final List<DataTableColumn<T>> columns;
  final int? sortColumnIndex;
  final bool sortAscending;
  final ValueChanged<int>? onSort;

  const PremiumDataTable({
    super.key,
    required this.items,
    required this.columns,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final table = DataTable(
      sortColumnIndex: sortColumnIndex,
      sortAscending: sortAscending,
      headingRowColor: WidgetStateProperty.all(
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      columns: List.generate(columns.length, (index) {
        final col = columns[index];
        return DataColumn(
          label: Text(
            col.label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onSort: onSort != null && col.valueGetter != null
              ? (_, _) => onSort!(index)
              : null,
        );
      }),
      rows: items.map((item) {
        return DataRow(
          cells: columns
              .map((col) => DataCell(col.cellBuilder(item)))
              .toList(),
        );
      }).toList(),
    );

    // The table must always be fully laid out. If it overflows the card and
    // gets clipped, the off-screen rows/columns are "never laid out", which
    // throws "Cannot hit test a render box that has never been laid out" on the
    // next pointer event (the page appears frozen).
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: constraints.hasBoundedWidth
                ? ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: table,
                  )
                : table,
          );
          // Only add vertical scrolling when we have a bounded height.
          // When the height is unbounded (e.g. inside a ListView), the table
          // should size itself to its content instead.
          if (constraints.hasBoundedHeight) {
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: horizontal,
            );
          }
          return horizontal;
        },
      ),
    );
  }
}
