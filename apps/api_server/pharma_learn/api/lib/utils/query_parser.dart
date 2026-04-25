import 'package:relic/relic.dart';

/// Parsed representation of common list-query parameters.
class QueryParams {
  final int page;
  final int perPage;
  final String? sortBy;
  final String sortOrder; // 'asc' | 'desc'
  final String? search;
  final Map<String, String> filters;

  QueryParams({
    this.page = 1,
    this.perPage = 20,
    this.sortBy,
    this.sortOrder = 'desc',
    this.search,
    this.filters = const {},
  });

  factory QueryParams.fromRequest(Request req) {
    // Relic's Request uses .url (a Uri) — not .requestedUri
    final q = req.url.queryParameters;
    return QueryParams(
      page: int.tryParse(q['page'] ?? '1') ?? 1,
      perPage: (int.tryParse(q['per_page'] ?? '20') ?? 20).clamp(1, 100),
      sortBy: q['sort_by'],
      sortOrder: q['sort_order'] == 'asc' ? 'asc' : 'desc',
      search: q['search'],
      filters: Map.fromEntries(
        q.entries.where(
          (e) => ![
            'page',
            'per_page',
            'sort_by',
            'sort_order',
            'search',
          ].contains(e.key),
        ),
      ),
    );
  }
}
