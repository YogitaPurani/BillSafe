import 'dart:io';
import 'package:flutter/material.dart';
import '../models/bill_scan.dart';
import '../services/storage_service.dart';
import '../services/gstin_service.dart';

class AnalysisResultScreen extends StatelessWidget {
  final BillScan scan;
  final bool isNew;

  const AnalysisResultScreen({
    super.key,
    required this.scan,
    this.isNew = false,
  });

  bool get _isFraud => scan.status == BillStatus.fraud;
  bool get _isClean => scan.status == BillStatus.clean;

  Color _headerColor(BuildContext context) {
    if (_isFraud) return const Color(0xFFE53935);
    if (_isClean) return const Color(0xFF2E7D32);
    return const Color(0xFFE65100);
  }

  @override
  Widget build(BuildContext context) {
    final headerColor = _headerColor(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildHeader(context, headerColor),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (scan.imagePath != null) _buildBillImage(context),
                  if (scan.imagePath != null) const SizedBox(height: 16),
                  if (scan.gstinNumber != null) _buildGstinCard(context),
                  const SizedBox(height: 16),
                  if (_isFraud) _buildFlaggedIssues(context),
                  if (_isClean) _buildCleanBreakdown(context),
                  if (scan.status == BillStatus.review)
                    _buildReviewBreakdown(context),
                  const SizedBox(height: 8),
                  if (_isClean) _buildBadges(context),
                  const SizedBox(height: 16),
                  _buildLegalTip(context),
                  const SizedBox(height: 24),
                  if (isNew) _buildActions(context, cs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color color) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: color,
      foregroundColor: Colors.white,
      title: const Text(
        'Analysis Result',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          color: color,
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      scan.restaurantName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.restaurant,
                            color: Colors.white70, size: 13),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${scan.category} · ${scan.location}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildStatusBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (_isFraud) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('OVERCHARGED',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            Text(
              '₹${scan.overchargedAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            _isClean ? 'Legitimate' : 'Review',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalTip(BuildContext context) {
    final hasFraud = _isFraud;
    final hasWrongGst = scan.flaggedIssues.any((i) => i.type == IssueType.wrongRate);
    final hasServiceCharge = scan.flaggedIssues.any((i) => i.type == IssueType.illegal);

    String tip;
    Color bg;
    Color iconColor;
    IconData icon;

    if (hasFraud && hasServiceCharge) {
      tip = 'You can legally REFUSE to pay service charge. Quote MCA circular dated July 4, 2022. File complaint at consumerhelpline.gov.in';
      bg = const Color(0xFFFFEBEE);
      iconColor = const Color(0xFFE53935);
      icon = Icons.gavel;
    } else if (hasFraud && hasWrongGst) {
      tip = 'Restaurants must charge only 5% GST (without ITC). Report to GST helpline: 1800-103-4786 (toll-free).';
      bg = const Color(0xFFFFF3E0);
      iconColor = const Color(0xFFE65100);
      icon = Icons.percent;
    } else if (_isClean) {
      tip = 'Great! This bill follows all legal guidelines. Keep scanning every bill to stay protected.';
      bg = const Color(0xFFE8F5E9);
      iconColor = const Color(0xFF2E7D32);
      icon = Icons.verified;
    } else {
      tip = 'Consumer Helpline: 1800-11-4000 (toll-free). File complaints at consumerhelpline.gov.in';
      bg = const Color(0xFFE3F2FD);
      iconColor = const Color(0xFF1565C0);
      icon = Icons.lightbulb_outline;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Legal Tip',
                    style: TextStyle(
                        color: iconColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(tip,
                    style: TextStyle(
                        fontSize: 12,
                        color: iconColor.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillImage(BuildContext context) {
    final file = File(scan.imagePath!);
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Image.file(file, fit: BoxFit.contain,
                    width: double.infinity, height: double.infinity),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Image.file(
              file,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Tap to zoom',
                        style:
                            TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGstinCard(BuildContext context) {
    return FutureBuilder<GSTINResult>(
      future: GSTINService.verify(scan.gstinNumber!),
      builder: (context, snap) {
        final result = snap.data;
        final loading = snap.connectionState != ConnectionState.done;
        final formatValid = result?.isFormatValid ?? false;
        final dbVerified = result?.isVerified ?? false;
        final notFound = formatValid && !dbVerified && result?.gstStatus == 'Not Found';

        Color color;
        Color bg;
        String badgeText;
        if (!formatValid) {
          color = const Color(0xFFE53935);
          bg = const Color(0xFFFFEBEE);
          badgeText = '✗ Invalid Format';
        } else if (dbVerified) {
          final isActive = (result?.gstStatus ?? '').toLowerCase() == 'active';
          color = isActive ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
          bg = isActive ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);
          badgeText = isActive ? '✓ Active' : '⚠ ${result!.gstStatus}';
        } else if (notFound) {
          color = const Color(0xFFE53935);
          bg = const Color(0xFFFFEBEE);
          badgeText = '✗ Not in DB';
        } else {
          color = const Color(0xFF1565C0);
          bg = const Color(0xFFE3F2FD);
          badgeText = '~ Format OK';
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance, color: color, size: 24),
                  const SizedBox(width: 10),
                  Text('GSTIN Verification',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                  const Spacer(),
                  if (loading)
                    SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: color))
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(badgeText,
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Business name (from API) or GSTIN number
              if (result?.businessName != null) ...[
                Text(
                  result!.businessName!,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 4),
              ],
              Text(scan.gstinNumber ?? '',
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              if (result != null && formatValid) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (result.stateName != null)
                      _GstinChip(Icons.location_on_outlined, result.stateName!,
                          color: color),
                    if (result.entityType != null)
                      _GstinChip(
                          Icons.business_outlined, result.entityType!,
                          color: color),
                    if (result.pan != null)
                      _GstinChip(
                          Icons.credit_card_outlined, 'PAN: ${result.pan}',
                          color: color),
                    if (result.registrationDate != null)
                      _GstinChip(Icons.calendar_today_outlined,
                          'Since ${result.registrationDate}',
                          color: color),
                  ],
                ),
                if (!dbVerified && !notFound) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Add GSTIN_API_KEY to .env for live database verification',
                    style: TextStyle(
                        fontSize: 11,
                        color: color.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFlaggedIssues(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FLAGGED ISSUES (${scan.flaggedIssues.length})',
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        ...scan.flaggedIssues.map((issue) => _IssueCard(issue: issue)),
      ],
    );
  }

  Widget _buildCleanBreakdown(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00695C),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Paid',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text(
                  '₹ ${scan.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...scan.breakdown.entries.map(
                  (e) => _BreakdownRow(
                    label: e.key,
                    amount: e.value,
                    isGst: e.key.toLowerCase().contains('gst'),
                  ),
                ),
                const _BreakdownRow(
                  label: 'Service charge',
                  amount: 0,
                  isNone: true,
                ),
                const _BreakdownRow(
                  label: 'GSTIN status',
                  amount: 0,
                  isActive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewBreakdown(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: scan.breakdown.entries
              .map((e) => _BreakdownRow(label: e.key, amount: e.value))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildBadges(BuildContext context) {
    return Row(
      children: [
        _Badge(icon: Icons.account_balance, label: 'GST Valid'),
        const SizedBox(width: 8),
        _Badge(icon: Icons.balance, label: 'Legal'),
        const SizedBox(width: 8),
        _Badge(icon: Icons.bar_chart, label: 'Rate OK'),
      ],
    );
  }

  Widget _buildActions(BuildContext context, ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              await StorageService.saveScan(scan);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved to history')),
                );
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: cs.primary),
              foregroundColor: cs.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              // Share functionality
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _IssueCard extends StatelessWidget {
  final FlaggedIssue issue;
  const _IssueCard({required this.issue});

  Color get _borderColor {
    switch (issue.type) {
      case IssueType.illegal:
        return const Color(0xFFE53935);
      case IssueType.wrongRate:
        return const Color(0xFFE65100);
      case IssueType.invalid:
        return const Color(0xFFE53935);
    }
  }

  Widget get _icon {
    switch (issue.type) {
      case IssueType.illegal:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFE53935)),
        );
      case IssueType.wrongRate:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.bar_chart, color: Color(0xFFE65100)),
        );
      case IssueType.invalid:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.block, color: Color(0xFFE53935)),
        );
    }
  }

  String get _badgeLabel {
    switch (issue.type) {
      case IssueType.illegal:
        return 'ILLEGAL';
      case IssueType.wrongRate:
        return 'WRONG RATE';
      case IssueType.invalid:
        return 'INVALID';
    }
  }

  Color get _badgeColor {
    switch (issue.type) {
      case IssueType.illegal:
        return const Color(0xFFFFCDD2);
      case IssueType.wrongRate:
        return const Color(0xFFFFE0B2);
      case IssueType.invalid:
        return const Color(0xFFFFCDD2);
    }
  }

  Color get _badgeTextColor {
    switch (issue.type) {
      case IssueType.illegal:
        return const Color(0xFFE53935);
      case IssueType.wrongRate:
        return const Color(0xFFE65100);
      case IssueType.invalid:
        return const Color(0xFFE53935);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _borderColor, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _icon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(issue.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(issue.description,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '₹ ${issue.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: _borderColor,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          fontSize: 15),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _badgeColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_badgeLabel,
                          style: TextStyle(
                              color: _badgeTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isGst;
  final bool isNone;
  final bool isActive;

  const _BreakdownRow({
    required this.label,
    required this.amount,
    this.isGst = false,
    this.isNone = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (isNone)
                Row(children: [
                  const Icon(Icons.check, color: Color(0xFF2E7D32), size: 16),
                  const SizedBox(width: 4),
                  const Text('None',
                      style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600)),
                ])
              else if (isActive)
                Row(children: [
                  const Icon(Icons.check, color: Color(0xFF2E7D32), size: 16),
                  const SizedBox(width: 4),
                  const Text('Active',
                      style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600)),
                ])
              else
                Row(children: [
                  if (isGst)
                    const Icon(Icons.check,
                        color: Color(0xFF2E7D32), size: 16),
                  if (isGst) const SizedBox(width: 4),
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isGst
                          ? const Color(0xFF2E7D32)
                          : null,
                    ),
                  ),
                ]),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _GstinChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _GstinChip(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF2E7D32);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: c,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF2E7D32), size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
