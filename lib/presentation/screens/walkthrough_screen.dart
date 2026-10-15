import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Interactive 4-step Walkthrough Guide explaining the core Academy workflow.
/// Can be presented on first launch or opened anytime from Settings > Help.
class AcademyWalkthroughScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const AcademyWalkthroughScreen({super.key, this.onComplete});

  @override
  State<AcademyWalkthroughScreen> createState() =>
      _AcademyWalkthroughScreenState();
}

class _AcademyWalkthroughScreenState extends State<AcademyWalkthroughScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_WalkthroughStep> _steps = const [
    _WalkthroughStep(
      badge: 'STEP 1 OF 4',
      title: 'Register Students & Contacts',
      subtitle:
          'Add learners, parent contact numbers, and course/batch details',
      icon: Icons.school_outlined,
      accentColor: AppColors.brand,
      description:
          'Start by adding each student with their legal name, course or class (e.g. "Class 10 Science" or "NEET Morning"), and parent/guardian phone number for fee communication. You can also save roll numbers or admission remarks.',
      bulletPoints: [
        'Organized by Course / Batch or Class',
        'Direct Parent / Guardian phone reference',
        'Optional Student ID or Roll Number',
      ],
      quickTip:
          'Tip: You can search students by name, batch, or parent contact phone at any time.',
    ),
    _WalkthroughStep(
      badge: 'STEP 2 OF 4',
      title: 'Set Up Course Fees & Installments',
      subtitle:
          'Specify academic year, fee amounts, concessions, and due dates',
      icon: Icons.request_quote_outlined,
      accentColor: AppColors.partialBlue,
      description:
          'Assign fees to students for their course or academic year. If the student received a scholarship or sibling discount, enter it as a Concession—the net fee updates automatically. You can add a single annual fee or multiple term installments with separate due dates.',
      bulletPoints: [
        'Academic Year tagging (e.g. 2026-27 or Term 1)',
        'Deduct Concessions & Scholarships cleanly',
        'Set calendar due dates to track upcoming dues',
      ],
      quickTip:
          'Tip: Fees with due dates in the past automatically highlight in Overdue alerts.',
    ),
    _WalkthroughStep(
      badge: 'STEP 3 OF 4',
      title: 'Record Payments & Issue Receipts',
      subtitle:
          'Collect fees via Cash, UPI, or Bank Transfer with instant receipts',
      icon: Icons.receipt_long_outlined,
      accentColor: AppColors.settledGreen,
      description:
          'When a parent or student pays, record the payment against the corresponding fee installment. FeesVault supports partial payments and automatically computes remaining dues. Each payment receives a unique, permanent receipt number (e.g. #1001).',
      bulletPoints: [
        'Supports Cash, UPI, Bank Transfer, and Other',
        'Monotonic, non-reusable receipt numbering',
        'Mandatory correction reason if modifying history',
      ],
      quickTip:
          'Tip: Overpayments above the outstanding fee balance are strictly prevented.',
    ),
    _WalkthroughStep(
      badge: 'STEP 4 OF 4',
      title: 'Monitor Academy Dues & Totals',
      subtitle: 'Stay in complete financial control directly on your device',
      icon: Icons.analytics_outlined,
      accentColor: AppColors.textPrimary,
      description:
          'The Academy Dashboard provides an instant, accurate picture of your finances: total fees raised, total collected into your vault, pending dues, and overdue installments. All records remain 100% private and encrypted on this device.',
      bulletPoints: [
        'Clear separation of All-Time vs This Month totals',
        'One-tap access to Overdue Installments',
        'Zero cloud dependency: works fully offline',
      ],
      quickTip:
          'Tip: Access this guide anytime from Settings > Academy User Guide.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentPage];
    final isLast = _currentPage == _steps.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              )
            : null,
        title: const Text(
          'Academy Workflow Guide',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _finish,
            child: Text(
              isLast ? 'Done' : 'Skip',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) {
                  final s = _steps[index];
                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    children: [
                      // Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: s.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.badge,
                              style: TextStyle(
                                color: s.accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Icon + Title Banner
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: s.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(s.icon, size: 32, color: s.accentColor),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s.subtitle,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Description Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          s.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Key Features Bullets
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Key Capabilities:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...s.bulletPoints.map(
                              (bp) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: AppColors.settledGreen,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        bp,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick Tip Box
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.brand.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lightbulb_outline,
                              size: 18,
                              color: AppColors.brand,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.quickTip,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Bottom Navigation & Page Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dots
                  Row(
                    children: List.generate(
                      _steps.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: _currentPage == i ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? step.accentColor
                              : AppColors.divider,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // Next / Get Started Button
                  ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: step.accentColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLast ? 'Get Started' : 'Next Step',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isLast ? Icons.check : Icons.arrow_forward,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkthroughStep {
  final String badge;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String description;
  final List<String> bulletPoints;
  final String quickTip;

  const _WalkthroughStep({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.description,
    required this.bulletPoints,
    required this.quickTip,
  });
}
