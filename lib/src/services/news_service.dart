import '../models/models.dart';
import 'api_client.dart';

final class NewsService {
  NewsService(this._api, {required this.apiKey});

  final ApiClient _api;
  final String apiKey;

  Future<List<NewsItem>> fetch(List<String> keywords) async {
    if (apiKey.isEmpty) {
      throw const ApiException('NEWS_API_KEY is not configured');
    }
    final clean = keywords
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(20);
    final needles = clean.map((value) => value.toLowerCase()).toList();
    final value = await _api.getJson(
      Uri.https('newsapi.org', '/v2/everything', {
        'q': clean.isEmpty ? 'technology' : clean.join(' OR '),
        'pageSize': '25',
        'sortBy': 'publishedAt',
        'language': 'en',
      }),
      headers: {'X-Api-Key': apiKey},
      service: 'NewsAPI',
    );
    if (value is! Map || value['articles'] is! List) {
      throw const ApiException('NewsAPI returned an invalid article list');
    }
    final seen = <String>{};
    final result = <NewsItem>[];
    for (final raw in value['articles'] as List) {
      if (raw is! Map) continue;
      final title = raw['title']?.toString().trim() ?? '';
      final description = raw['description']?.toString().trim();
      final uri = Uri.tryParse(raw['url']?.toString() ?? '');
      if (title.isEmpty || title == '[Removed]' || uri == null || !_http(uri)) {
        continue;
      }
      if (!seen.add(uri.toString())) continue;
      final haystack = '$title ${description ?? ''}'.toLowerCase();
      if (needles.isNotEmpty && !needles.any(haystack.contains)) continue;
      final source = raw['source'] is Map
          ? ((raw['source'] as Map)['name']?.toString() ?? 'Unknown')
          : 'Unknown';
      final image = Uri.tryParse(raw['urlToImage']?.toString() ?? '');
      result.add(
        NewsItem(
          title: title,
          source: source,
          url: uri,
          publishedAt: DateTime.tryParse(raw['publishedAt']?.toString() ?? ''),
          description: description?.isEmpty == true ? null : description,
          imageUrl: image != null && _http(image) ? image : null,
        ),
      );
      if (result.length == 8) break;
    }
    return result;
  }
}

bool _http(Uri uri) =>
    (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
