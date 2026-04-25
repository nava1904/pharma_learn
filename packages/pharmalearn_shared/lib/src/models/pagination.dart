/// Pagination metadata for list responses.
class Pagination {
  final int page;
  final int perPage;
  final int total;
  final int totalPages;

  const Pagination({
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  /// Computes [totalPages] from [total] and [perPage].
  factory Pagination.compute({
    required int page,
    required int perPage,
    required int total,
  }) {
    final totalPages = perPage > 0 ? (total / perPage).ceil() : 0;
    return Pagination(
      page: page,
      perPage: perPage,
      total: total,
      totalPages: totalPages,
    );
  }

  Map<String, dynamic> toJson() => {
        'page': page,
        'per_page': perPage,
        'total': total,
        'total_pages': totalPages,
      };
}
