import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '/utils/page_mixins.dart';
import '/utils/app_bar.dart';
import '/services/electricity/service.dart';
import '/types/electricity.dart';
import '/utils/haptic.dart';

class ElectricityPage extends StatefulWidget {
  const ElectricityPage({super.key});

  @override
  State<ElectricityPage> createState() => _ElectricityPageState();
}

class _ElectricityPageState extends State<ElectricityPage>
    with PageStateMixin, LoadingStateMixin {
  final ElectricityService _service = ElectricityService();
  final TextEditingController _ammeterController = TextEditingController();

  int? _ammeterNumber;
  List<RemainingElectricity> _history = [];
  String? _message;
  bool _hasQueried = false;

  @override
  void onServiceInit() {
    _loadSavedAmmeter();
  }

  @override
  void dispose() {
    _ammeterController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAmmeter() async {
    final saved = await _service.getSavedAmmeterNumber();
    if (saved != null && mounted) {
      setState(() {
        _ammeterNumber = saved;
        _ammeterController.text = saved.toString();
      });
    }
  }

  Future<void> _saveAndQuery() async {
    final text = _ammeterController.text.trim();
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入电表号')),
        );
      }
      return;
    }

    final number = int.tryParse(text);
    if (number == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('电表号必须是数字')),
        );
      }
      return;
    }

    await _service.saveAmmeterNumber(number);
    if (mounted) {
      setState(() => _ammeterNumber = number);
    }
    await _doQuery(number);
  }

  Future<void> _doQuery(int ammeterNumber) async {
    setLoading(true);
    try {
      final result = await _service.fetchAndRecord(ammeterNumber);
      if (mounted) {
        setState(() {
          _history = result.history;
          _message = result.message;
          _hasQueried = true;
        });
        setLoading(false);
      }
    } catch (e) {
      if (mounted) {
        setError('查询失败: $e');
        setState(() => _hasQueried = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(title: '电费查询'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputSection(),
            if (hasError) _buildErrorCard(),
            if (isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              if (_hasQueried && _history.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildCurrentCard(),
                if (_message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _message!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (_history.length >= 2) ...[
                  const SizedBox(height: 16),
                  _buildChart(),
                ],
                const SizedBox(height: 16),
                _buildHistoryTable(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('电表号',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ammeterController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '输入电表号',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _saveAndQuery(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: isLoading
                      ? null
                      : () {
                          Haptics.medium();
                          _saveAndQuery();
                        },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('查询'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(errorMessage!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer)),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Haptics.light();
                clearError();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentCard() {
    final last = _history.last;
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '$_ammeterNumber',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onPrimaryContainer
                    .withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${last.remain}',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '剩余电量 (kWh)',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onPrimaryContainer
                    .withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final spots = _history.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.remain.toDouble(),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('用电趋势',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _calculateInterval(spots),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: _bottomLabelInterval(spots.length),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= _history.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            '${_history[index].date.month}/${_history[index].date.day}',
                            style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: primaryColor,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: primaryColor,
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: primaryColor.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          final record = _history[index];
                          return LineTooltipItem(
                            '${record.date.month}/${record.date.day}\n${spot.y.toInt()} kWh',
                            TextStyle(
                                color: theme.colorScheme.onInverseSurface,
                                fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 10;
    final values = spots.map((s) => s.y).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min;
    if (range <= 10) return 2;
    if (range <= 50) return 10;
    if (range <= 200) return 50;
    return (range / 5).ceilToDouble();
  }

  double _bottomLabelInterval(int count) {
    if (count <= 7) return 1;
    return (count / 5).ceilToDouble();
  }

  Widget _buildHistoryTable() {
    final theme = Theme.of(context);
    final reversed = _history.reversed.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('历史记录',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Table(
              border: TableBorder(
                horizontalInside:
                    BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  children: [
                    _tableHeader('日期', theme),
                    _tableHeader('剩余 (kWh)', theme),
                    _tableHeader('日均用量', theme),
                  ],
                ),
                ...reversed.map((record) {
                  return TableRow(
                    children: [
                      _tableCell(
                          '${record.date.year}/${record.date.month.toString().padLeft(2, '0')}/${record.date.day.toString().padLeft(2, '0')}',
                          theme),
                      _tableCell('${record.remain}', theme),
                      _tableCell(
                          record.average > 0
                              ? record.average.toStringAsFixed(1)
                              : '-',
                          theme),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant)),
    );
  }

  Widget _tableCell(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text,
          style:
              TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
    );
  }
}
