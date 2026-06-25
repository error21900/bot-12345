import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'trade_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        Provider.of<TradingProvider>(context, listen: false).startBot();
      } catch (e) {
        print('Error starting bot: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final provider = Provider.of<TradingProvider>(context, listen: false);
    if (state == AppLifecycleState.resumed) {
      // FIX: Only restart if not already running to prevent double-start
      if (!provider.isRunning) {
        provider.startBot();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        title: const Text('Saad Bot Control Center'),
        actions: [
          Consumer<TradingProvider>(builder: (_, p, __) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: p.isRunning
                    ? const Color(0xFF00C087).withOpacity(0.15)
                    : Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color:
                        p.isRunning ? const Color(0xFF00C087) : Colors.red,
                    width: 1),
              ),
              child: Row(children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color:
                        p.isRunning ? const Color(0xFF00C087) : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  p.isRunning ? 'LIVE ENGINE' : 'ENGINE COOLDOWN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: p.isRunning ? const Color(0xFF00C087) : Colors.red,
                  ),
                ),
              ]),
            );
          }),
        ],
      ),
      body: Consumer<TradingProvider>(builder: (_, provider, __) {
        return RefreshIndicator(
          color: const Color(0xFF00C087),
          backgroundColor: const Color(0xFF141B2D),
          onRefresh: () async {
            if (!provider.isRunning) provider.startBot();
            await Future.delayed(const Duration(seconds: 2));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Control Buttons
              Row(children: [
                Expanded(
                  child: _ActionButton(
                    label: 'ACTIVATE BOT',
                    icon: Icons.play_arrow_rounded,
                    color: const Color(0xFF00C087),
                    onTap: provider.isRunning ? null : provider.startBot,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: 'TERMINATE BOT',
                    icon: Icons.stop_rounded,
                    color: Colors.red,
                    onTap: provider.isRunning ? provider.stopBot : null,
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              Center(
                child: Text(
                  provider.statusMsg,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Balance Cards
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Account Balance',
                      value: '\$${provider.balance.toStringAsFixed(2)}',
                      icon: Icons.account_balance_wallet,
                      iconColor: const Color(0xFF00C087),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Total P&L',
                      value: '\$${provider.totalPnL.toStringAsFixed(2)}',
                      icon: Icons.trending_up,
                      iconColor: provider.totalPnL >= 0
                          ? const Color(0xFF00C087)
                          : Colors.red,
                      valueColor: provider.totalPnL >= 0
                          ? const Color(0xFF00C087)
                          : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Timeframe Selector
              const Text(
                'Active Indicator Evaluation Interval',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF141B2D),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['1', '3', '5', '15', '30', '60'].map((time) {
                    final isSelected = provider.selectedTimeframe == time;
                    final label = time == '60' ? '1H' : '${time}M';
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => provider.updateTimeframe(time),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF00C087)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.black
                                  : Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Live Market Tickers
              const _SectionTitle(title: 'Live Market Tickers', count: 4),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141B2D),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.01)),
                ),
                child: Column(
                  children: ['BTCUSDT', 'SOLUSDT', 'LINKUSDT', 'XRPUSDT']
                      .map((sym) {
                    final data = provider.livePrices[sym];
                    final priceRaw = data?['lastPrice'];
                    final changeRaw = data?['price24hPcnt'];

                    final price =
                        double.tryParse(priceRaw?.toString() ?? '') ?? 0.0;
                    // FIX: price24hPcnt from Bybit is already a decimal (e.g. 0.0123 = 1.23%)
                    final changeDecimal =
                        double.tryParse(changeRaw?.toString() ?? '') ?? 0.0;
                    final changePct = changeDecimal * 100;
                    final isUp = changePct >= 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.monetization_on_rounded,
                                  size: 16, color: Colors.grey[500]),
                              const SizedBox(width: 8),
                              Text(
                                sym.replaceAll('USDT', '/USDT'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                price > 0
                                    ? '\$${price.toStringAsFixed(price > 100 ? 2 : 4)}'
                                    : 'Loading...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isUp
                                      ? const Color(0xFF00C087).withOpacity(0.15)
                                      : Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: isUp
                                        ? const Color(0xFF00C087)
                                        : Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Live Positions
              _SectionTitle(
                  title: 'Live Managed Positions',
                  count: provider.positions.length),
              const SizedBox(height: 10),
              if (provider.positions.isEmpty)
                const _EmptyCard(
                  icon: Icons.hourglass_empty_rounded,
                  message:
                      'No execution loops loaded.\nScanning indicators for matching signals...',
                )
              else
                ...provider.positions.values.map((p) => _PositionCard(pos: p)),
              const SizedBox(height: 24),

              // Trade History
              _SectionTitle(
                  title: 'Executed Orders History',
                  count: provider.trades.length),
              const SizedBox(height: 10),
              if (provider.trades.isEmpty)
                const _EmptyCard(
                  icon: Icons.swap_horiz_rounded,
                  message: 'No trades tracked in recent history bounds.',
                )
              else
                ...provider.trades.take(10).map((t) => _TradeCard(trade: t)),
              const SizedBox(height: 20),

              Center(
                child: Text(
                  'Last Sync Event: ${provider.lastUpdate}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }
}

// ==================== UI Components ====================

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ActionButton(
      {required this.label,
      required this.icon,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.12) : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? color : Colors.grey[800]!,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: enabled ? color : Colors.grey[600], size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: enabled ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color? valueColor;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141B2D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  const _SectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF00C087).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00C087),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF141B2D),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey[700], size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.grey[500], fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  final Position pos;
  const _PositionCard({required this.pos});

  @override
  Widget build(BuildContext context) {
    final isLong = pos.side == 'buy' || pos.side == 'long';
    final color = isLong ? const Color(0xFF00C087) : Colors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141B2D),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pos.symbol.replaceAll('USDT', '/USDT'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                isLong ? 'LONG (10x)' : 'SHORT (10x)',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${pos.unrealizedPnl.toStringAsFixed(2)}',
                style: TextStyle(
                  color: pos.unrealizedPnl >= 0
                      ? const Color(0xFF00C087)
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Size: ${pos.contracts.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TradeCard extends StatelessWidget {
  final Trade trade;
  const _TradeCard({required this.trade});

  @override
  Widget build(BuildContext context) {
    final isLong = trade.direction == 'LONG';
    final color = isLong ? const Color(0xFF00C087) : Colors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141B2D),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trade.symbol.replaceAll('USDT', '/USDT'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 13),
              ),
              const SizedBox(height: 3),
              Text(
                isLong ? 'FILLED BUY/LONG' : 'FILLED SELL/SHORT',
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${trade.price.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              const SizedBox(height: 3),
              Text(
                trade.timestamp,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
