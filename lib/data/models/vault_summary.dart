/// Aggregated financial metrics for the FeesVault dashboard.
/// Charges and payments are aggregated strictly independently to avoid JOIN multiplication.
class VaultSummary {
  // All-time metrics
  final int totalNetFeesPaise;
  final int totalCollectedPaise;
  final int totalOutstandingPaise;
  final int totalOverduePaise;

  // Current month metrics
  final int monthNetFeesPaise;
  final int monthCollectedPaise;

  // Counts
  final int activePayersCount;
  final int archivedPayersCount;
  final int totalChargesCount;
  final int overdueChargesCount;

  const VaultSummary({
    required this.totalNetFeesPaise,
    required this.totalCollectedPaise,
    required this.totalOutstandingPaise,
    required this.totalOverduePaise,
    required this.monthNetFeesPaise,
    required this.monthCollectedPaise,
    required this.activePayersCount,
    required this.archivedPayersCount,
    required this.totalChargesCount,
    required this.overdueChargesCount,
  });

  factory VaultSummary.empty() {
    return const VaultSummary(
      totalNetFeesPaise: 0,
      totalCollectedPaise: 0,
      totalOutstandingPaise: 0,
      totalOverduePaise: 0,
      monthNetFeesPaise: 0,
      monthCollectedPaise: 0,
      activePayersCount: 0,
      archivedPayersCount: 0,
      totalChargesCount: 0,
      overdueChargesCount: 0,
    );
  }
}
