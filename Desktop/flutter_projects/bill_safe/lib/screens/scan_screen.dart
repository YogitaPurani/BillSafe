import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/bill_scan.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import 'analysis_result_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  bool _isAnalyzing = false;
  int _step = 0; // 0=idle, 1=captured, 2=extracted, 3=validating, 4=done
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnim;

  final List<String> _steps = [
    'Image captured & enhanced',
    'Items & prices extracted',
    'Validating GSTIN live...',
    'Gemini is thinking deeply...',
  ];

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineAnim =
        Tween<double>(begin: 0.1, end: 0.9).animate(_scanLineController);
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    super.dispose();
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() {
      _isAnalyzing = true;
      _step = 0;
    });

    // Start API call immediately — runs in parallel with animation
    final analysisFuture = GeminiService.analyzeBill(File(picked.path));

    // Animation steps (run while API is already processing)
    for (int i = 1; i <= 3; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() => _step = i);
    }

    // Show "deep thinking" step while waiting for API
    setState(() => _step = 4);

    try {
      final result = await analysisFuture;
      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
        _step = 0;
      });

      if (result != null) {
        // Copy image to app documents so it persists in history
        BillScan scanToSave = result;
        try {
          final docsDir = await getApplicationDocumentsDirectory();
          final destPath = '${docsDir.path}/${result.id}.jpg';
          await File(picked.path).copy(destPath);
          scanToSave = result.withImagePath(destPath);
        } catch (_) {
          // Image copy failed — proceed without it
        }
        await StorageService.saveScan(scanToSave);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisResultScreen(scan: scanToSave, isNew: true),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read bill. Try a clearer image.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _step = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scan Bill'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Camera placeholder / viewfinder
          Column(
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.black,
                      child: const Center(
                        child: Text(
                          'Camera preview\nwill appear here',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                    ),
                    // Corner frame overlay
                    Center(
                      child: SizedBox(
                        width: 280,
                        height: 360,
                        child: CustomPaint(
                          painter: _FramePainter(cs.primary),
                        ),
                      ),
                    ),
                    // Animated scan line
                    if (!_isAnalyzing)
                      AnimatedBuilder(
                        animation: _scanLineAnim,
                        builder: (_, __) {
                          return Align(
                            alignment: Alignment(0, _scanLineAnim.value * 2 - 1),
                            child: Container(
                              width: 280,
                              height: 2,
                              color: cs.primary.withValues(alpha: 0.8),
                            ),
                          );
                        },
                      ),
                    // Hint text
                    if (!_isAnalyzing)
                      const Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Text(
                          'ALIGN BILL WITHIN FRAME',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Bottom sheet
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: _isAnalyzing
                    ? _buildAnalyzingSheet(cs)
                    : _buildActionSheet(cs),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionSheet(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                color: cs.primary,
                onTap: () => _pickAndAnalyze(ImageSource.camera),
              ),
              _ActionButton(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                color: cs.secondary,
                onTap: () => _pickAndAnalyze(ImageSource.gallery),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingSheet(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analyzing bill...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                  Text(
                      _step >= 4 ? 'AI reasoning in progress...' : 'Gemini Vision is working',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _step >= 4 ? null : _step / 3,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              color: _step >= 4 ? cs.tertiary : cs.primary,
            ),
          ),
          const SizedBox(height: 16),
          ..._steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final label = entry.value;
            final done = idx < (_step >= 4 ? 3 : _step);
            final active = _step >= 4 ? idx == 3 : idx == _step - 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? cs.primary
                          : active
                              ? cs.primaryContainer
                              : cs.surfaceContainerHighest,
                    ),
                    child: done
                        ? Icon(Icons.check, size: 13, color: cs.onPrimary)
                        : active
                            ? Padding(
                                padding: const EdgeInsets.all(3),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.primary,
                                ),
                              )
                            : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: done
                          ? cs.primary
                          : active
                              ? cs.onSurface
                              : cs.onSurfaceVariant,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  final Color color;
  _FramePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 28.0;

    // Top-left
    canvas.drawLine(const Offset(0, len), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    // Top-right
    canvas.drawLine(
        Offset(size.width - len, 0), Offset(size.width, 0), paint);
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width, len), paint);
    // Bottom-left
    canvas.drawLine(
        Offset(0, size.height - len), Offset(0, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(len, size.height), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - len, size.height),
        Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - len),
        Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.color != color;
}
