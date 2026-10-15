import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/payer.dart';
import '../controllers/vault_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/status_badge.dart';
import 'payer_detail_screen.dart';
import 'payer_form_screen.dart';

/// Students management screen featuring real-time search, active/archived filters,
/// course/batch badges, and outstanding balance summaries.
class PayersScreen extends StatefulWidget {
  final VaultController controller;

  const PayersScreen({super.key, required this.controller});

  @override
  State<PayersScreen> createState() => _PayersScreenState();
}

class _PayersScreenState extends State<PayersScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showArchived = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase().trim();

    // Filter students
    final filtered = widget.controller.payers.where((p) {
      if (!_showArchived && p.archived) return false;
      if (_showArchived && !p.archived) return false;

      if (query.isEmpty) return true;
      final matchName = p.name.toLowerCase().contains(query);
      final matchPhone = p.phone?.toLowerCase().contains(query) ?? false;
      final matchBatch = p.batch?.toLowerCase().contains(query) ?? false;
      final matchNotes = p.notes?.toLowerCase().contains(query) ?? false;
      return matchName || matchPhone || matchBatch || matchNotes;
    }).toList();

    final allStudentsEmpty = widget.controller.payers.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Students',
          style: TextStyle(
            color: AppColors.navyDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.primaryTealDark),
            tooltip: 'Add Student',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PayerFormScreen(controller: widget.controller),
                ),
              );
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PayerFormScreen(controller: widget.controller),
            ),
          );
        },
        backgroundColor: AppColors.primaryTealDark,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
        label: const Text(
          'Add Student',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search student, parent phone, or batch...',
                    hintStyle: const TextStyle(fontSize: 14, color: AppColors.slate),
                    prefixIcon: const Icon(Icons.search, color: AppColors.slate, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceSubtle,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text('Active Students (${widget.controller.payers.where((p) => !p.archived).length})'),
                      selected: !_showArchived,
                      selectedColor: AppColors.primaryTealLight,
                      labelStyle: TextStyle(
                        color: !_showArchived ? AppColors.primaryTealDark : AppColors.slate,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                      onSelected: (val) {
                        setState(() => _showArchived = false);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Archived (${widget.controller.payers.where((p) => p.archived).length})'),
                      selected: _showArchived,
                      selectedColor: AppColors.archivedGrayBg,
                      labelStyle: TextStyle(
                        color: _showArchived ? AppColors.navyDark : AppColors.slate,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                      onSelected: (val) {
                        setState(() => _showArchived = true);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // Student List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => widget.controller.refreshAll(),
              color: AppColors.primaryTealDark,
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              allStudentsEmpty ? Icons.school_outlined : Icons.search_off,
                              size: 48,
                              color: AppColors.slate.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              allStudentsEmpty
                                  ? 'No Students Registered Yet'
                                  : (_showArchived ? 'No archived students.' : 'No matching students found.'),
                              style: const TextStyle(
                                color: AppColors.navyDark,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              allStudentsEmpty
                                  ? 'Register your academy students to set up their course fees, installments, and track payment receipts.'
                                  : 'Try adjusting your search query or check the archived tab.',
                              style: const TextStyle(color: AppColors.slate, fontSize: 13, height: 1.4),
                              textAlign: TextAlign.center,
                            ),
                            if (allStudentsEmpty) ...[
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PayerFormScreen(controller: widget.controller),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 18),
                                label: const Text('Register First Student', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryTealDark,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final student = filtered[index];
                        return _studentItem(context, student);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentItem(BuildContext context, Payer student) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PayerDetailScreen(
                payerId: student.id,
                controller: widget.controller,
              ),
            ),
          );
        },
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: student.archived ? AppColors.archivedGrayBg : AppColors.primaryTealLight,
              foregroundColor: student.archived ? AppColors.archivedGray : AppColors.primaryTealDark,
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          student.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navyDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (student.archived) ...[
                        const SizedBox(width: 6),
                        StatusBadge.archived(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      if (student.batch != null && student.batch!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Text(
                            student.batch!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.navyDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (student.phone != null && student.phone!.isNotEmpty)
                        Text(
                          'Parent: ${student.phone!}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.slate,
                          ),
                        ),
                      Text(
                        '${student.chargeCount} fee installments',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.slateLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatPaise(student.totalOutstandingPaise),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: student.totalOutstandingPaise > 0
                        ? AppColors.unpaidAmber
                        : AppColors.settledGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  student.totalOutstandingPaise > 0 ? 'Due' : 'All Clear',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: student.totalOutstandingPaise > 0 ? AppColors.unpaidAmber : AppColors.settledGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
