import 'dart:math';
import 'package:flutter/material.dart';
import '../models/bill_scan.dart';
import '../services/storage_service.dart';
import 'scan_screen.dart';
import 'analysis_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _totalScanned = 0;
  double _totalSaved = 0;
  List<BillScan> _recentScans = [];
  bool _howItWorksExpanded = true;
  bool _tipDismissed = false;

  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  List<(double, double, double)> _starData = []; // (leftFraction, top, size)

  static const _tips = [
    'Restaurants cannot legally charge service fee in India per MCA 2022.',
    'GST on restaurant food is 5% — charging more is illegal.',
    'Always ask for a GST invoice if the bill shows a GSTIN number.',
    'Packaged food in restaurants is taxed at 12% GST, not 5%.',
  ];

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 8)  return 'Good morning';
    if (hour >= 8 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 16) return 'Good afternoon';
    if (hour >= 16 && hour < 20) return 'Good evening';
    return 'Good night';
  }

  // Sky emoji shown next to greeting
  String get _skyEmoji {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 8)   return '🌅'; // sunrise
    if (hour >= 8 && hour < 12)  return '☀️'; // morning sun
    if (hour >= 12 && hour < 16) return '🌤️'; // midday
    if (hour >= 16 && hour < 19) return '🌇'; // sunset
    if (hour >= 19 && hour < 22) return '🌆'; // dusk
    return '🌙';                               // night
  }

  // Gradient colors for hero section based on time
  List<Color> get _skyGradient {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 8) {
      // Sunrise — warm pink/orange
      return [const Color(0xFFFF9A5C), const Color(0xFFFFD580)];
    } else if (hour >= 8 && hour < 12) {
      // Morning — golden yellow to light blue
      return [const Color(0xFFFFD580), const Color(0xFF87CEEB)];
    } else if (hour >= 12 && hour < 16) {
      // Day — sky blue
      return [const Color(0xFF48CAE4), const Color(0xFF90E0EF)];
    } else if (hour >= 16 && hour < 19) {
      // Sunset — amber/orange
      return [const Color(0xFFFF6B35), const Color(0xFFFFAD60)];
    } else if (hour >= 19 && hour < 22) {
      // Dusk — purple/indigo
      return [const Color(0xFF6B4FBB), const Color(0xFFFF6B35)];
    } else {
      // Night — deep navy
      return [const Color(0xFF0D1B2A), const Color(0xFF1B2A4A)];
    }
  }

  bool get _isNight {
    final hour = DateTime.now().hour;
    return hour >= 22 || hour < 5;
  }

  // Text/icon color based on background brightness
  Color get _skyForeground {
    final hour = DateTime.now().hour;
    if (hour >= 22 || hour < 5) return Colors.white;  // night: dark bg
    if (hour >= 19) return Colors.white;               // dusk: dark bg
    return Colors.black87;                             // else: light bg
  }

  String get _tip => _tips[DateTime.now().day % _tips.length];

  @override
  void initState() {
    super.initState();
    final random = Random();
    _starData = List.generate(15, (_) => (
      random.nextDouble(),          // left as fraction 0.0–1.0
      random.nextDouble() * 80,     // top 0–80px
      random.nextDouble() * 3 + 2,  // size 2–5px
    ));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final summary = await StorageService.getMonthlySummary();
    final scans = await StorageService.getScans();
    if (!mounted) return;
    setState(() {
      _totalScanned = summary['totalScanned'] as int? ?? 0;
      _totalSaved = summary['totalSaved'] as double? ?? 0;
      _recentScans = scans.take(3).toList();
    });
  }

  Future<void> _scan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: _skyGradient.first,
            foregroundColor: _skyForeground,
            flexibleSpace: FlexibleSpaceBar(
              background: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _skyGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    if (_isNight) ..._nightStars(constraints.maxWidth),
                  ],
                ),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_greeting  $_skyEmoji',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _skyForeground)),
                ],
              ),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => _showAlerts(context),
              ),
            ],
          ),
          // ── Colored hero section ──────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _skyGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsRow(cs),
                        const SizedBox(height: 16),
                        if (!_tipDismissed) _buildTipBanner(cs),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Normal section ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScanCard(context, cs),
                  const SizedBox(height: 20),
                  if (_recentScans.isNotEmpty) ...[
                    _buildRecentScans(context),
                    const SizedBox(height: 20),
                  ],
                  _buildHowItWorks(context, cs),
                  const SizedBox(height: 24),
                  Text('What we check',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildCheckGrid(context),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scan,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan Bill'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  List<Widget> _nightStars(double width) {
    return _starData.map((s) => Positioned(
      left: s.$1 * width,
      top: s.$2,
      child: Container(
        width: s.$3,
        height: s.$3,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          shape: BoxShape.circle,
        ),
      ),
    )).toList();
  }

  Future<void> _showAlerts(BuildContext context) async {
    final scans = await StorageService.getScans();
    if (!context.mounted) return;

    final alerts = scans.where((s) =>
        s.status == BillStatus.fraud ||
        s.status == BillStatus.review ||
        s.overchargedAmount > 0).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          builder: (_, controller) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active, color: cs.primary),
                    const SizedBox(width: 10),
                    Text('Alerts', style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    )),
                    const Spacer(),
                    Text('${alerts.length} alerts',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Expanded(
                child: alerts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 48, color: Colors.green),
                            const SizedBox(height: 12),
                            const Text('All clear! No issues found.',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Your scanned bills look clean.',
                                style: TextStyle(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: alerts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final scan = alerts[i];
                          final isFraud = scan.status == BillStatus.fraud;
                          final color = isFraud
                              ? const Color(0xFFE53935)
                              : const Color(0xFFE65100);
                          final bgColor = isFraud
                              ? const Color(0xFFFFEBEE)
                              : const Color(0xFFFFF3E0);
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isFraud ? Icons.warning_amber_rounded : Icons.info_outline,
                                  color: color, size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(scan.restaurantName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          )),
                                      const SizedBox(height: 2),
                                      if (scan.overchargedAmount > 0)
                                        Text(
                                          'Overcharged by ₹${scan.overchargedAmount.toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      if (scan.flaggedIssues.isNotEmpty)
                                        ...scan.flaggedIssues.map((issue) => Text(
                                          '• ${issue.title}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: cs.onSurfaceVariant),
                                        )),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(ColorScheme cs) {
    final total = _recentScans.length;
    final cleanPct = total == 0
        ? 0.0
        : _recentScans.where((s) => s.status == BillStatus.clean).length /
            total;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Bills Scanned',
            value: '$_totalScanned',
            icon: Icons.receipt_long,
            color: const Color(0xFFFFB74D),
            textColor: const Color(0xFF4A2800),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Saved This Month',
            value: '₹${_totalSaved.toStringAsFixed(0)}',
            icon: Icons.savings_outlined,
            color: const Color(0xFF4DB6AC),
            textColor: const Color(0xFF00251A),
          ),
        ),
        if (_recentScans.isNotEmpty) ...[
          const SizedBox(width: 10),
          Expanded(child: _RiskMeterCard(cleanPercent: cleanPct)),
        ],
      ],
    );
  }

  Widget _buildTipBanner(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: cs.onTertiaryContainer, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _tip,
              style: TextStyle(color: cs.onTertiaryContainer, fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _tipDismissed = true),
            child: Icon(Icons.close, color: cs.onTertiaryContainer, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildScanCard(BuildContext context, ColorScheme cs) {
    return GestureDetector(
      onTap: _scan,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.tertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Scan a Bill',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Detect overcharges & illegal fees instantly',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ScaleTransition(
              scale: _pulseAnimation ?? const AlwaysStoppedAnimation(1.0),
              child: Image.asset(
                'assets/camera_icon.png',
                width: 72,
                height: 72,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentScans(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Scans',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recentScans.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final scan = _recentScans[i];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AnalysisResultScreen(scan: scan),
                  ),
                ),
                child: _RecentScanTile(scan: scan),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorks(BuildContext context, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () =>
              setState(() => _howItWorksExpanded = !_howItWorksExpanded),
          child: Row(
            children: [
              Text('How it works',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Icon(
                _howItWorksExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
        if (_howItWorksExpanded) ...[
          const SizedBox(height: 12),
          _buildStepCard(
            icon: Icons.camera_alt_outlined,
            step: '1',
            title: 'Scan your bill',
            desc: 'Take a photo or upload from gallery',
            color: cs.primaryContainer,
          ),
          _buildStepCard(
            icon: Icons.psychology_outlined,
            step: '2',
            title: 'AI Analysis',
            desc: 'Gemini Vision extracts & verifies charges',
            color: cs.secondaryContainer,
          ),
          _buildStepCard(
            icon: Icons.verified_outlined,
            step: '3',
            title: 'Get Results',
            desc: 'See flagged issues and overcharges instantly',
            color: cs.tertiaryContainer,
          ),
        ],
      ],
    );
  }

  Widget _buildStepCard({
    required IconData icon,
    required String step,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: color,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.white.withValues(alpha: 0.5),
          child:
              Text(step, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
        trailing: Icon(icon),
      ),
    );
  }

  Widget _buildCheckGrid(BuildContext context) {
    const items = [
      (Icons.warning_amber_rounded, 'Service Charge', 'Illegal per MCA 2022',
          Color(0xFFFFECB3), Color(0xFFE65100)),
      (Icons.percent, 'GST Rate', '5% for restaurants',
          Color(0xFFE8F5E9), Color(0xFF2E7D32)),
      (Icons.account_balance, 'GSTIN', 'Real-time verification',
          Color(0xFFE3F2FD), Color(0xFF1565C0)),
      (Icons.block, 'Hidden Fees', 'Unlawful charges',
          Color(0xFFFFEBEE), Color(0xFFC62828)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: item.$4,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(item.$1, color: item.$5, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.$2,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: item.$5)),
                    Text(item.$3,
                        style: TextStyle(
                            fontSize: 10,
                            color: item.$5.withValues(alpha: 0.7)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RecentScanTile extends StatelessWidget {
  final BillScan scan;
  const _RecentScanTile({required this.scan});

  Color get _dotColor {
    switch (scan.status) {
      case BillStatus.clean:
        return const Color(0xFF2E7D32);
      case BillStatus.fraud:
        return const Color(0xFFE53935);
      case BillStatus.review:
        return const Color(0xFFE65100);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(scan.statusLabel,
                  style: TextStyle(
                      color: _dotColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          Text(scan.restaurantName,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text('₹${scan.totalAmount.toStringAsFixed(0)}',
              style:
                  TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
        ],
      ),
    );
  }
}

class _RiskMeterCard extends StatelessWidget {
  final double cleanPercent;
  const _RiskMeterCard({required this.cleanPercent});

  @override
  Widget build(BuildContext context) {
    final bgColor = cleanPercent >= 0.7
        ? const Color(0xFF66BB6A)
        : cleanPercent >= 0.4
            ? const Color(0xFFFFA726)
            : const Color(0xFFEF5350);
    const textColor = Colors.white;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: textColor, size: 22),
          const SizedBox(height: 8),
          Text('${(cleanPercent * 100).toInt()}%',
              style: const TextStyle(
                  color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Bills clean',
              style: TextStyle(
                  color: textColor.withValues(alpha: 0.85), fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color textColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  color: textColor.withValues(alpha: 0.7), fontSize: 12)),
        ],
      ),
    );
  }
}
