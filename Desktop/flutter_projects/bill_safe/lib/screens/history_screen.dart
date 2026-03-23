import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill_scan.dart';
import '../services/storage_service.dart';
import 'analysis_result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<BillScan> _scans = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  StreamSubscription<void>? _scanSub;

  @override
  void initState() {
    super.initState();
    _load();
    _scanSub = StorageService.onScanSaved.listen((_) => _load());
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final scans = await StorageService.getScans();
    final summary = await StorageService.getMonthlySummary();
    if (!mounted) return;
    setState(() {
      _scans = scans;
      _summary = summary;
      _loading = false;
    });
  }

  List<BillScan> get _filtered {
    if (_search.isEmpty) return _scans;
    final q = _search.toLowerCase();
    return _scans
        .where((s) =>
            s.restaurantName.toLowerCase().contains(q) ||
            s.category.toLowerCase().contains(q) ||
            s.location.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: _showSearch
                ? TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search bills...',
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  )
                : const Text('History',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
            actions: [
              IconButton(
                icon: Icon(_showSearch ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _search = '';
                      _searchCtrl.clear();
                    }
                  });
                },
              ),
            ],
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_scans.isEmpty)
            SliverFillRemaining(child: _buildEmpty(context))
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildSummaryCard(cs),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'RECENT SCANS',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final scan = _filtered[index];
                  return _ScanTile(
                    scan: scan,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AnalysisResultScreen(scan: scan, isNew: false),
                      ),
                    ),
                    onDelete: () async {
                      await StorageService.deleteScan(scan.id);
                      _load();
                    },
                  );
                },
                childCount: _filtered.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ColorScheme cs) {
    final saved = (_summary['totalSaved'] as double? ?? 0);
    final scanned = _summary['totalScanned'] as int? ?? 0;
    final fraud = _summary['fraudCaught'] as int? ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF00695C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.15,
              child: Icon(Icons.currency_rupee,
                  size: 120, color: Colors.white),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOTAL SAVINGS THIS MONTH',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Text(
                '₹ ${NumberFormat('#,##0').format(saved)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '$scanned bills scanned · $fraud frauds caught',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          const Text('No scans yet',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Scan a bill to get started',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ScanTile extends StatelessWidget {
  final BillScan scan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ScanTile({
    required this.scan,
    required this.onTap,
    required this.onDelete,
  });

  Color get _statusColor {
    switch (scan.status) {
      case BillStatus.fraud:
        return const Color(0xFFE53935);
      case BillStatus.clean:
        return const Color(0xFF2E7D32);
      case BillStatus.review:
        return const Color(0xFFE65100);
    }
  }

  Color get _iconBg {
    switch (scan.status) {
      case BillStatus.fraud:
        return const Color(0xFFFFEBEE);
      case BillStatus.clean:
        return const Color(0xFFE8F5E9);
      case BillStatus.review:
        return const Color(0xFFFFF3E0);
    }
  }

  IconData get _categoryIcon {
    switch (scan.category.toLowerCase()) {
      case 'medical':
        return Icons.local_hospital;
      case 'grocery':
        return Icons.shopping_basket;
      default:
        return Icons.restaurant;
    }
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scanDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(scanDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(scan.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onTap: onTap,
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_categoryIcon, color: _statusColor),
          ),
          title: Text(scan.restaurantName,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${_timeLabel(scan.scannedAt)} · ${scan.category}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${NumberFormat('#,##0').format(scan.totalAmount)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  scan.statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
