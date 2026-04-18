import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/refresh_notifier.dart';

class ViolationsScreen extends StatefulWidget {
  final int tabIndex;

  const ViolationsScreen({super.key, required this.tabIndex});

  @override
  State<ViolationsScreen> createState() => _ViolationsScreenState();
}

class _ViolationsScreenState extends State<ViolationsScreen> {
  List<dynamic> _violations = [];
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
        if (mounted) _loadViolations();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadViolations();
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadViolations();
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

  Future<void> _loadViolations() async {
    setState(() => _loading = true);
    final api = context.read<ApiService>();
    final list = await api.getViolations();
    if (mounted) {
      setState(() {
        _violations = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Violation Logs'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadViolations,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _violations.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No violations recorded'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadViolations,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _violations.length,
                    itemBuilder: (context, i) {
                      final v = _violations[i] as Map<String, dynamic>;
                      final vehicle = v['vehicle_number'] ?? 'Unknown';
                      final dateStr = v['violation_date'];
                      DateTime? dt;
                      if (dateStr != null) {
                        try {
                          dt = DateTime.tryParse(dateStr.toString());
                        } catch (_) {}
                      }
                      final location = v['camera_location'] ?? 'Unknown';
                      final reason = v['violation_reason'] ?? 'No helmet';
                      final status = v['status'] ?? 'pending';
                      final ownerName = v['owner_name'];
                      final ownerPhone = v['owner_phone'];
                      final ownerAddress = v['owner_address'];
                      final fineAmount = v['fine_amount'];
                      final hasOwner = ownerName != null && ownerName.toString().isNotEmpty;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.orange.shade100,
                                    child: const Icon(Icons.two_wheeler, color: Colors.orange),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          vehicle,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          '${dt != null ? DateFormat('MMM d, y HH:mm').format(dt) : dateStr} • $location',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                        Text(
                                          reason,
                                          style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Chip(
                                    label: Text(status, style: const TextStyle(fontSize: 11)),
                                    backgroundColor: status == 'paid'
                                        ? Colors.green.shade100
                                        : Colors.orange.shade100,
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Text(
                                'Vehicle / Owner Details',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (hasOwner)
                                _detailRow(Icons.person, 'Owner', ownerName.toString())
                              else
                                _detailRow(Icons.person, 'Owner', 'Not registered'),
                              if (ownerPhone != null && ownerPhone.toString().isNotEmpty)
                                _detailRow(Icons.phone, 'Phone', ownerPhone.toString()),
                              if (ownerAddress != null && ownerAddress.toString().isNotEmpty)
                                _detailRow(Icons.location_on, 'Address', ownerAddress.toString()),
                              if (fineAmount != null)
                                _detailRow(Icons.currency_rupee, 'Fine', '₹$fineAmount'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

Widget _detailRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              children: [
                TextSpan(text: '$label: ', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
