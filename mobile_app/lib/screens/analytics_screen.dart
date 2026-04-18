import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../services/refresh_notifier.dart';

class AnalyticsScreen extends StatefulWidget {
  final int tabIndex;

  const AnalyticsScreen({super.key, required this.tabIndex});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _daily = [];
  List<Map<String, dynamic>> _weekly = [];
  List<Map<String, dynamic>> _monthly = [];
  bool _loading = true;
  int _lastSeenTab = -1;
  int _lastSeenDataCount = -1;
  RefreshNotifier? _refreshNotifier;
  Timer? _periodicTimer;

  void _onRefresh() {
    if (!mounted || _refreshNotifier == null) return;
    if (_refreshNotifier!.shouldRefresh(widget.tabIndex, _lastSeenTab, _lastSeenDataCount)) {
      _lastSeenTab = _refreshNotifier!.selectedTabIndex;
      _lastSeenDataCount = _refreshNotifier!.dataChangeCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadData();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final refresh = context.read<RefreshNotifier>();
    if (_refreshNotifier != refresh) {
      _refreshNotifier?.removeListener(_onRefresh);
      _refreshNotifier = refresh;
      _refreshNotifier!.addListener(_onRefresh);
      _lastSeenTab = _refreshNotifier!.selectedTabIndex;
      _lastSeenDataCount = _refreshNotifier!.dataChangeCount;
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _tabController.dispose();
    _refreshNotifier?.removeListener(_onRefresh);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });
    final api = context.read<ApiService>();
    final dailyRes = await api.getAnalyticsDaily(days: 7);
    final weeklyRes = await api.getAnalyticsWeekly(weeks: 4);
    final monthlyRes = await api.getAnalyticsMonthly(months: 6);
    if (mounted) {
      setState(() {
        _daily = List<Map<String, dynamic>>.from(
          (dailyRes['data'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        _weekly = List<Map<String, dynamic>>.from(
          (weeklyRes['data'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        _monthly = List<Map<String, dynamic>>.from(
          (monthlyRes['data'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ChartTab(data: _daily, labelKey: 'date', valueKey: 'count'),
                  _ChartTab(data: _weekly, labelKey: 'week', valueKey: 'count'),
                  _ChartTab(data: _monthly, labelKey: 'month', valueKey: 'count'),
                ],
              ),
            ),
    );
  }
}

class _ChartTab extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String labelKey;
  final String valueKey;

  const _ChartTab({required this.data, required this.labelKey, required this.valueKey});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: SizedBox(height: 400, child: Center(child: Text('No data available'))),
      );
    }

    final spots = data.asMap().entries.map((e) {
      final v = e.value[valueKey];
      final y = v is num ? (v as num).toDouble() : (double.tryParse(v.toString()) ?? 0.0);
      return FlSpot(e.key.toDouble(), y.isFinite ? y : 0.0);
    }).toList();

    final maxYVal = spots.isEmpty ? 2.0 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxY = maxYVal.isFinite ? maxYVal + 2 : 4.0;
    final labels = data.map((e) {
      final s = e[labelKey]?.toString() ?? '';
      return s.length > 5 ? s.substring(5) : s;
    }).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 280,
          child: BarChart(
            BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (!value.isFinite) return const SizedBox();
                  final i = value.toInt();
                  if (i >= 0 && i < labels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        labels[i],
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 28,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text(
                  value.isFinite ? value.toInt().toString() : '',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: spots.asMap().entries.map((e) {
            final yVal = e.value.y.isFinite ? e.value.y : 0.0;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: yVal,
                  color: Theme.of(context).colorScheme.primary,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
              showingTooltipIndicators: [0],
            );
          }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
