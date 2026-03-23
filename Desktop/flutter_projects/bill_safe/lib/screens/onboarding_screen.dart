import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show MainShell;


class _OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color accent;
  final List<String> bullets;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.accent,
    required this.bullets,
  });
}

const _pages = [
  _OnboardingPage(
    title: 'Scan Any Bill',
    subtitle: 'Point your camera at any restaurant,\nshop or medical bill.',
    icon: Icons.document_scanner_rounded,
    color: Color(0xFF00695C),
    accent: Color(0xFF80CBC4),
    bullets: [
      'Camera or gallery — your choice',
      'Works on blurry or angled photos',
      'Results in under 10 seconds',
    ],
  ),
  _OnboardingPage(
    title: 'Catch Fraud Instantly',
    subtitle: 'AI checks every charge against\nIndian consumer laws.',
    icon: Icons.shield_outlined,
    color: Color(0xFF1565C0),
    accent: Color(0xFF90CAF9),
    bullets: [
      'Illegal service charges flagged',
      'Wrong GST rates detected',
      'GSTIN verified in real-time',
    ],
  ),
  _OnboardingPage(
    title: 'Know Your Rights',
    subtitle: 'Legal tips and dispute tools\nright in your pocket.',
    icon: Icons.gavel_rounded,
    color: Color(0xFF6A1B9A),
    accent: Color(0xFFCE93D8),
    bullets: [
      'MCA 2022 service charge rules',
      'GST helpline & complaint links',
      'Share reports with ease',
    ],
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _pages.length,
            itemBuilder: (_, i) => _PageView(page: _pages[i]),
          ),
          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final page = _pages[_page];
    final isLast = _page == _pages.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 48),
      decoration: BoxDecoration(
        color: page.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // Skip button
              if (!isLast)
                TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                )
              else
                const SizedBox(width: 70),
              const Spacer(),
              // Next / Get Started button
              FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: page.color,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLast ? 'Get Started' : 'Next',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isLast
                          ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  final _OnboardingPage page;
  const _PageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            page.color.withValues(alpha: 0.08),
            Colors.white,
            page.color,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Big icon circle
              Center(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: page.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: page.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(page.icon, size: 56, color: page.color),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // Title
              Text(
                page.title,
                style: TextStyle(
                  color: page.color,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              // Subtitle
              Text(
                page.subtitle,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              // Bullet points
              ...page.bullets.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: page.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check,
                              size: 13, color: page.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            b,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
