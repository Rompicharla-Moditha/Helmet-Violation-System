import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/refresh_notifier.dart';
import 'camera_screen.dart';
import 'violations_screen.dart';
import 'analytics_screen.dart';
import 'add_vehicle_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  List<Widget> get _screens => [
    const _DashboardTab(tabIndex: 0),
    const CameraScreen(),
    const ViolationsScreen(tabIndex: 2),
    const AnalyticsScreen(tabIndex: 3),
    const AddVehicleScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          context.read<RefreshNotifier>().selectTab(i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.camera_alt), label: 'Detect'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Violations'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Add Vehicle'),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatefulWidget {
  final int tabIndex;

  const _DashboardTab({required this.tabIndex});

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  Future<Map<String, dynamic>>? _summaryFuture;
  int _lastSeenTab = -1;
  int _lastSeenDataCount = -1;
  RefreshNotifier? _refreshNotifier;
  Timer? _periodicTimer;

  void _loadSummary() {
    setState(() {
      _summaryFuture = context.read<ApiService>().getSummary();
    });
  }

  void _onRefresh() {
    if (!mounted || _refreshNotifier == null) return;
    if (_refreshNotifier!.shouldRefresh(widget.tabIndex, _lastSeenTab, _lastSeenDataCount)) {
      _lastSeenTab = _refreshNotifier!.selectedTabIndex;
      _lastSeenDataCount = _refreshNotifier!.dataChangeCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSummary();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadSummary();
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
    _refreshNotifier?.removeListener(_onRefresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Helmet Violation System'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSummary,
          ),
        ],
      ),
      body: FutureBuilder(
        future: _summaryFuture,
        builder: (context, snapshot) {
          final total = snapshot.data?['total'] ?? 0;
          final today = snapshot.data?['today'] ?? 0;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange.shade700),
                        const SizedBox(height: 16),
                        Text('$total', style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        )),
                        const Text('Total Violations'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.today, size: 64, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 16),
                        Text('$today', style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                        const Text('Today\'s Violations'),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CameraScreen()),
                  ),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Start Detection'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
