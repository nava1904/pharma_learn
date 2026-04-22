/// Supported sort directions.
enum SortDirection {
  asc,
  desc;

  /// Convert to PostgreSQL sort direction string.
  String toPostgres() => switch (this) {
    SortDirection.asc => 'asc',
    SortDirection.desc => 'desc',
  };

  /// Parse from string (case-insensitive).
  static SortDirection fromString(String? value) {
    if (value == null) return SortDirection.asc;
    return switch (value.toLowerCase()) {
      'desc' || 'descending' || '-1' => SortDirection.desc,
      _ => SortDirection.asc,
    };
  }
}

/// Sort options for paginated queries.
class SortOptions {
  /// Column to sort by.
  final String column;

  /// Sort direction.
  final SortDirection direction;

  const SortOptions({
    required this.column,
    this.direction = SortDirection.asc,
  });

  /// Parse sort options from query parameters.
  ///
  /// Supports formats:
  /// - `sort=column` (ascending)
  /// - `sort=-column` (descending, prefix with -)
  /// - `sort=column&order=desc` (explicit order)
  factory SortOptions.fromQuery(
    Map<String, String> query, {
    String defaultColumn = 'created_at',
    SortDirection defaultDirection = SortDirection.desc,
    Set<String>? allowedColumns,
  }) {
    var sortParam = query['sort'] ?? query['sortBy'];
    final orderParam = query['order'] ?? query['orderBy'];

    // Handle empty sort
    if (sortParam == null || sortParam.isEmpty) {
      return SortOptions(
        column: defaultColumn,
        direction: defaultDirection,
      );
    }

    // Check for - prefix
    SortDirection direction;
    if (sortParam.startsWith('-')) {
      sortParam = sortParam.substring(1);
      direction = SortDirection.desc;
    } else if (sortParam.startsWith('+')) {
      sortParam = sortParam.substring(1);
      direction = SortDirection.asc;
    } else {
      direction = SortDirection.fromString(orderParam);
    }

    // Validate column if allowed list provided
    if (allowedColumns != null && !allowedColumns.contains(sortParam)) {
      return SortOptions(
        column: defaultColumn,
        direction: defaultDirection,
      );
    }

    return SortOptions(
      column: sortParam,
      direction: direction,
    );
  }

  /// Create multiple sort options from comma-separated string.
  ///
  /// Example: `sort=created_at,-name` → sort by created_at ASC, then name DESC
  static List<SortOptions> fromQueryMulti(
    Map<String, String> query, {
    String defaultColumn = 'created_at',
    SortDirection defaultDirection = SortDirection.desc,
    Set<String>? allowedColumns,
  }) {
    final sortParam = query['sort'] ?? query['sortBy'];

    if (sortParam == null || sortParam.isEmpty) {
      return [
        SortOptions(
          column: defaultColumn,
          direction: defaultDirection,
        ),
      ];
    }

    final parts = sortParam.split(',');
    final results = <SortOptions>[];

    for (var part in parts) {
      part = part.trim();
      if (part.isEmpty) continue;

      SortDirection direction;
      String column;

      if (part.startsWith('-')) {
        column = part.substring(1);
        direction = SortDirection.desc;
      } else if (part.startsWith('+')) {
        column = part.substring(1);
        direction = SortDirection.asc;
      } else {
        column = part;
        direction = SortDirection.asc;
      }

      // Validate column if allowed list provided
      if (allowedColumns == null || allowedColumns.contains(column)) {
        results.add(SortOptions(column: column, direction: direction));
      }
    }

    // Fallback if no valid sorts
    if (results.isEmpty) {
      return [
        SortOptions(
          column: defaultColumn,
          direction: defaultDirection,
        ),
      ];
    }

    return results;
  }

  /// Convert to query string format.
  String toQueryString() {
    return direction == SortDirection.desc ? '-$column' : column;
  }

  /// Check if this is descending sort.
  bool get isDescending => direction == SortDirection.desc;

  /// Check if this is ascending sort.
  bool get isAscending => direction == SortDirection.asc;

  @override
  String toString() => 'SortOptions($column ${direction.name})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SortOptions &&
        other.column == column &&
        other.direction == direction;
  }

  @override
  int get hashCode => Object.hash(column, direction);
}
