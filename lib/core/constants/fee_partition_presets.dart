/// Supported Fee Schedule Preset Types (matching school-erp architecture).
enum FeeScheduleType {
  default12_2('DEFAULT_12_2', '12 Mo + 2 Terms', '14 parts (12 monthly tuition + 2 term fees)', 14),
  monthly12('MONTHLY_12', '12 Monthly', '12 equal monthly installments without separate terms', 12),
  quarterly4('QUARTERLY_4', 'Quarterly', '4 installments (Jun, Sep, Dec, Mar / Apr, Jul, Oct, Jan)', 4),
  halfYearly2('HALF_YEARLY_2', 'Half-Yearly', '2 semester installments (Jun & Nov / Apr & Oct)', 2),
  annual1('ANNUAL_1', 'Annual (1 Part)', '100% full annual payment upfront', 1),
  custom('CUSTOM', 'Custom Parts', 'Arbitrary installment parts, names & amounts', 0);

  final String code;
  final String label;
  final String description;
  final int count;

  const FeeScheduleType(this.code, this.label, this.description, this.count);

  static FeeScheduleType fromCode(String code) {
    return FeeScheduleType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => FeeScheduleType.default12_2,
    );
  }
}

/// Academic Session start month (e.g., June for Western/Southern Indian boards, April for CBSE).
enum SessionStartMonth {
  june('June to May (State / Western Board)', 6),
  april('April to March (CBSE / Northern Board)', 4);

  final String label;
  final int monthNumber;

  const SessionStartMonth(this.label, this.monthNumber);
}

/// Configuration for a single installment part in a schedule.
class InstallmentPartConfig {
  String title;
  int grossPaise;
  String dueDate;
  String dueMonth;
  String feeType; // 'EDUCATION', 'TERM', 'ADMISSION', 'BAG_KIT', 'OTHER'
  int order;

  InstallmentPartConfig({
    required this.title,
    required this.grossPaise,
    required this.dueDate,
    required this.dueMonth,
    required this.feeType,
    required this.order,
  });

  InstallmentPartConfig copyWith({
    String? title,
    int? grossPaise,
    String? dueDate,
    String? dueMonth,
    String? feeType,
    int? order,
  }) {
    return InstallmentPartConfig(
      title: title ?? this.title,
      grossPaise: grossPaise ?? this.grossPaise,
      dueDate: dueDate ?? this.dueDate,
      dueMonth: dueMonth ?? this.dueMonth,
      feeType: feeType ?? this.feeType,
      order: order ?? this.order,
    );
  }
}

/// Utility class for generating fee schedules and partitions.
class FeePartitionHelper {
  static const List<String> juneMonths = [
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
    'January',
    'February',
    'March',
    'April',
    'May',
  ];

  static const List<String> aprilMonths = [
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
    'January',
    'February',
    'March',
  ];

  /// Returns list of month names for the given session start.
  static List<String> getMonthsList(SessionStartMonth start) {
    return start == SessionStartMonth.june ? juneMonths : aprilMonths;
  }

  /// Calculates the calendar year for a given month index in the session.
  /// For June start (idx 0..6 is startYear, idx 7..11 is startYear + 1).
  /// For April start (idx 0..8 is startYear, idx 9..11 is startYear + 1).
  static int getCalendarYear(int monthIndexInSession, int startYear, SessionStartMonth start) {
    if (start == SessionStartMonth.june) {
      return monthIndexInSession <= 6 ? startYear : startYear + 1;
    } else {
      return monthIndexInSession <= 8 ? startYear : startYear + 1;
    }
  }

  /// Returns calendar month number (1..12) for a given month index in session.
  static int getCalendarMonthNumber(int monthIndexInSession, SessionStartMonth start) {
    final startM = start.monthNumber;
    final m = startM + monthIndexInSession;
    return m > 12 ? m - 12 : m;
  }

  /// Formats date YYYY-MM-DD safely.
  static String formatDate(int year, int month, int day) {
    final yStr = year.toString();
    final mStr = month.toString().padLeft(2, '0');
    final dStr = day.clamp(1, 28).toString().padLeft(2, '0');
    return '$yStr-$mStr-$dStr';
  }

  /// Generates the standard preset installment parts based on annual fee and options.
  static List<InstallmentPartConfig> generatePresetParts({
    required FeeScheduleType type,
    required int annualFeePaise,
    required int startYear,
    SessionStartMonth sessionStart = SessionStartMonth.june,
    int dueDay = 10,
    int termFeeOverridePaise = 0,
    int admissionFeePaise = 0,
    int bagKitFeePaise = 0,
  }) {
    final results = <InstallmentPartConfig>[];
    int orderCounter = 1;

    final startMonthNum = sessionStart.monthNumber;

    // 1. One-time Admission Fee (if specified)
    if (admissionFeePaise > 0) {
      results.add(
        InstallmentPartConfig(
          title: 'Admission Fee',
          grossPaise: admissionFeePaise,
          dueDate: formatDate(startYear, startMonthNum, 5),
          dueMonth: 'One-time',
          feeType: 'ADMISSION',
          order: orderCounter++,
        ),
      );
    }

    // 2. One-time Bag & Kit Fee (if specified)
    if (bagKitFeePaise > 0) {
      results.add(
        InstallmentPartConfig(
          title: 'Bag & Kit Fee',
          grossPaise: bagKitFeePaise,
          dueDate: formatDate(startYear, startMonthNum, 5),
          dueMonth: 'One-time',
          feeType: 'BAG_KIT',
          order: orderCounter++,
        ),
      );
    }

    // 3. Generate main fee schedule based on preset type
    final months = getMonthsList(sessionStart);

    switch (type) {
      case FeeScheduleType.default12_2:
        // DEFAULT_12_2: 14 parts (12 monthly education + 2 term fees)
        // Matching school-erp: educationAmount = round(annualFee / 14)
        int termAmount;
        int eduBase;
        int eduRem;

        if (termFeeOverridePaise > 0) {
          termAmount = termFeeOverridePaise;
          final remainingAnnual = annualFeePaise - (termAmount * 2);
          final safeRem = remainingAnnual > 0 ? remainingAnnual : 0;
          eduBase = safeRem ~/ 12;
          eduRem = safeRem - (eduBase * 12);
        } else {
          // Equal 14-part split: annualFee / 14
          final partBase = annualFeePaise ~/ 14;
          final partRem = annualFeePaise - (partBase * 14);
          termAmount = partBase;
          eduBase = partBase;
          eduRem = partRem; // Add remainder to 1st education month
        }

        if (sessionStart == SessionStartMonth.june) {
          // Term 1 (Due before June)
          results.add(
            InstallmentPartConfig(
              title: 'Term 1 Fee',
              grossPaise: termAmount,
              dueDate: formatDate(startYear, 6, 15),
              dueMonth: 'Term 1',
              feeType: 'TERM',
              order: orderCounter++,
            ),
          );

          // Jun to Nov (first 6 months)
          for (int i = 0; i < 6; i++) {
            final mName = months[i];
            final cYear = getCalendarYear(i, startYear, sessionStart);
            final cMonth = getCalendarMonthNumber(i, sessionStart);
            final amount = (i == 0) ? eduBase + eduRem : eduBase;

            results.add(
              InstallmentPartConfig(
                title: '$mName Tuition Fee',
                grossPaise: amount,
                dueDate: formatDate(cYear, cMonth, dueDay),
                dueMonth: mName,
                feeType: 'EDUCATION',
                order: orderCounter++,
              ),
            );
          }

          // Term 2 (Due in November/December)
          results.add(
            InstallmentPartConfig(
              title: 'Term 2 Fee',
              grossPaise: termAmount,
              dueDate: formatDate(startYear, 11, 15),
              dueMonth: 'Term 2',
              feeType: 'TERM',
              order: orderCounter++,
            ),
          );

          // Dec to May (next 6 months)
          for (int i = 6; i < 12; i++) {
            final mName = months[i];
            final cYear = getCalendarYear(i, startYear, sessionStart);
            final cMonth = getCalendarMonthNumber(i, sessionStart);

            results.add(
              InstallmentPartConfig(
                title: '$mName Tuition Fee',
                grossPaise: eduBase,
                dueDate: formatDate(cYear, cMonth, dueDay),
                dueMonth: mName,
                feeType: 'EDUCATION',
                order: orderCounter++,
              ),
            );
          }
        } else {
          // April start
          results.add(
            InstallmentPartConfig(
              title: 'Term 1 Fee',
              grossPaise: termAmount,
              dueDate: formatDate(startYear, 4, 15),
              dueMonth: 'Term 1',
              feeType: 'TERM',
              order: orderCounter++,
            ),
          );

          for (int i = 0; i < 6; i++) {
            final mName = months[i];
            final cYear = getCalendarYear(i, startYear, sessionStart);
            final cMonth = getCalendarMonthNumber(i, sessionStart);
            final amount = (i == 0) ? eduBase + eduRem : eduBase;

            results.add(
              InstallmentPartConfig(
                title: '$mName Tuition Fee',
                grossPaise: amount,
                dueDate: formatDate(cYear, cMonth, dueDay),
                dueMonth: mName,
                feeType: 'EDUCATION',
                order: orderCounter++,
              ),
            );
          }

          results.add(
            InstallmentPartConfig(
              title: 'Term 2 Fee',
              grossPaise: termAmount,
              dueDate: formatDate(startYear, 10, 15),
              dueMonth: 'Term 2',
              feeType: 'TERM',
              order: orderCounter++,
            ),
          );

          for (int i = 6; i < 12; i++) {
            final mName = months[i];
            final cYear = getCalendarYear(i, startYear, sessionStart);
            final cMonth = getCalendarMonthNumber(i, sessionStart);

            results.add(
              InstallmentPartConfig(
                title: '$mName Tuition Fee',
                grossPaise: eduBase,
                dueDate: formatDate(cYear, cMonth, dueDay),
                dueMonth: mName,
                feeType: 'EDUCATION',
                order: orderCounter++,
              ),
            );
          }
        }
        break;

      case FeeScheduleType.monthly12:
        final base = annualFeePaise ~/ 12;
        final rem = annualFeePaise - (base * 12);

        for (int i = 0; i < 12; i++) {
          final mName = months[i];
          final cYear = getCalendarYear(i, startYear, sessionStart);
          final cMonth = getCalendarMonthNumber(i, sessionStart);
          final amount = (i == 0) ? base + rem : base;

          results.add(
            InstallmentPartConfig(
              title: '$mName Tuition Fee',
              grossPaise: amount,
              dueDate: formatDate(cYear, cMonth, dueDay),
              dueMonth: mName,
              feeType: 'EDUCATION',
              order: orderCounter++,
            ),
          );
        }
        break;

      case FeeScheduleType.quarterly4:
        final quarters = sessionStart == SessionStartMonth.june
            ? [
                {'name': '1st Quarter (Jun - Aug)', 'month': 'June', 'mNum': 6, 'yOffset': 0},
                {'name': '2nd Quarter (Sep - Nov)', 'month': 'September', 'mNum': 9, 'yOffset': 0},
                {'name': '3rd Quarter (Dec - Feb)', 'month': 'December', 'mNum': 12, 'yOffset': 0},
                {'name': '4th Quarter (Mar - May)', 'month': 'March', 'mNum': 3, 'yOffset': 1},
              ]
            : [
                {'name': '1st Quarter (Apr - Jun)', 'month': 'April', 'mNum': 4, 'yOffset': 0},
                {'name': '2nd Quarter (Jul - Sep)', 'month': 'July', 'mNum': 7, 'yOffset': 0},
                {'name': '3rd Quarter (Oct - Dec)', 'month': 'October', 'mNum': 10, 'yOffset': 0},
                {'name': '4th Quarter (Jan - Mar)', 'month': 'January', 'mNum': 1, 'yOffset': 1},
              ];

        final base = annualFeePaise ~/ 4;
        final rem = annualFeePaise - (base * 4);

        for (int i = 0; i < 4; i++) {
          final q = quarters[i];
          final amount = (i == 0) ? base + rem : base;
          final cYear = startYear + (q['yOffset'] as int);
          final cMonth = q['mNum'] as int;

          results.add(
            InstallmentPartConfig(
              title: q['name'] as String,
              grossPaise: amount,
              dueDate: formatDate(cYear, cMonth, dueDay),
              dueMonth: q['month'] as String,
              feeType: 'EDUCATION',
              order: orderCounter++,
            ),
          );
        }
        break;

      case FeeScheduleType.halfYearly2:
        final halves = sessionStart == SessionStartMonth.june
            ? [
                {'name': 'Term 1 Installment (Jun - Nov)', 'month': 'June', 'mNum': 6, 'yOffset': 0},
                {'name': 'Term 2 Installment (Dec - May)', 'month': 'November', 'mNum': 11, 'yOffset': 0},
              ]
            : [
                {'name': 'Term 1 Installment (Apr - Sep)', 'month': 'April', 'mNum': 4, 'yOffset': 0},
                {'name': 'Term 2 Installment (Oct - Mar)', 'month': 'October', 'mNum': 10, 'yOffset': 0},
              ];

        final base = annualFeePaise ~/ 2;
        final rem = annualFeePaise - (base * 2);

        for (int i = 0; i < 2; i++) {
          final h = halves[i];
          final amount = (i == 0) ? base + rem : base;
          final cYear = startYear + (h['yOffset'] as int);
          final cMonth = h['mNum'] as int;

          results.add(
            InstallmentPartConfig(
              title: h['name'] as String,
              grossPaise: amount,
              dueDate: formatDate(cYear, cMonth, dueDay),
              dueMonth: h['month'] as String,
              feeType: 'EDUCATION',
              order: orderCounter++,
            ),
          );
        }
        break;

      case FeeScheduleType.annual1:
        results.add(
          InstallmentPartConfig(
            title: 'Full Annual Fee',
            grossPaise: annualFeePaise,
            dueDate: formatDate(startYear, startMonthNum, dueDay),
            dueMonth: months[0],
            feeType: 'EDUCATION',
            order: orderCounter++,
          ),
        );
        break;

      case FeeScheduleType.custom:
        // Returns empty base or initial 4 installments to be edited by user
        final base = annualFeePaise ~/ 4;
        final rem = annualFeePaise - (base * 4);
        for (int i = 0; i < 4; i++) {
          final mIndex = (i * 3) % 12;
          final mName = months[mIndex];
          final cYear = getCalendarYear(mIndex, startYear, sessionStart);
          final cMonth = getCalendarMonthNumber(mIndex, sessionStart);
          final amount = (i == 0) ? base + rem : base;

          results.add(
            InstallmentPartConfig(
              title: 'Installment ${i + 1}',
              grossPaise: amount,
              dueDate: formatDate(cYear, cMonth, dueDay),
              dueMonth: mName,
              feeType: 'EDUCATION',
              order: orderCounter++,
            ),
          );
        }
        break;
    }

    return results;
  }
}
