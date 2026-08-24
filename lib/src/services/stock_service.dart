import '../models/models.dart';
import 'api_client.dart';

final class StockService {
  StockService(this._api, {required this.apiKey});

  final ApiClient _api;
  final String apiKey;

  Future<StockQuote> fetch(String rawSymbol) async {
    final symbol = rawSymbol.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9._=-]{1,24}$').hasMatch(symbol)) {
      throw const ApiException('Invalid market symbol');
    }
    if (apiKey.isEmpty) {
      throw const ApiException('FINNHUB_API_KEY is not configured');
    }
    final value = await _api.getJson(
      Uri.https('finnhub.io', '/api/v1/quote', {'symbol': symbol}),
      headers: {'X-Finnhub-Token': apiKey},
      service: 'Finnhub',
    );
    if (value is! Map) {
      throw const ApiException('Finnhub returned an invalid quote');
    }
    final price = _number(value['c']);
    if (price <= 0) {
      throw ApiException('Finnhub returned no current price for $symbol');
    }
    return StockQuote(
      symbol: symbol,
      price: price,
      change: _number(value['d']),
      changePercent: _number(value['dp']),
      high: _number(value['h']),
      low: _number(value['l']),
    );
  }
}

double _number(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : 0;
