import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../core/app_state.dart';
import '../widgets/dashboard_widgets.dart';

class StocksScreen extends StatelessWidget {
  const StocksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    return FeaturePage(
      title: 'Markets',
      subtitle: 'A deliberately small watchlist powered by Finnhub, with keys supplied only at build time.',
      actions: [
        FilledButton.icon(
          onPressed: controller.refreshStocks,
          icon: controller.loading(OperationLane.stocks)
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
      children: [
        if (controller.stockData.isEmpty)
          EmptyPanel(
            icon: Icons.candlestick_chart,
            title: 'No market quotes loaded',
            message: 'Add FINNHUB_API_KEY as a dart-define, then refresh your watchlist.',
            action: OutlinedButton(
              onPressed: controller.refreshStocks,
              child: const Text('Try now'),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final quote in controller.stockData)
                SummaryCard(
                  label: quote.symbol,
                  value: '\$${quote.price.toStringAsFixed(2)}',
                  detail:
                      '${quote.change >= 0 ? '+' : ''}${quote.change.toStringAsFixed(2)} · ${quote.changePercent.toStringAsFixed(2)}%',
                  icon: quote.change >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: quote.change >= 0 ? Colors.green : Colors.red,
                ),
            ],
          ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Market data is informational and may be delayed. Happy Wakey does not provide investment advice.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}
