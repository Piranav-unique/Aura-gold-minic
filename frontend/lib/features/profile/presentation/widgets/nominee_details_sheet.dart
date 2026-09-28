import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/widgets/aura_dialog_actions.dart';
import 'package:ags_gold/features/profile/domain/nominee_model.dart';
import 'package:ags_gold/features/profile/presentation/providers/nominee_provider.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

/// Shows the Nominee Details bottom sheet with view & edit capabilities.
Future<void> showNomineeDetailsSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _NomineeDetailsSheetContent(ref: ref),
    ),
  );
}

class _NomineeDetailsSheetContent extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _NomineeDetailsSheetContent({required this.ref});

  @override
  ConsumerState<_NomineeDetailsSheetContent> createState() =>
      _NomineeDetailsSheetContentState();
}

class _NomineeDetailsSheetContentState
    extends ConsumerState<_NomineeDetailsSheetContent> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _dobController;
  late final TextEditingController _phoneController;
  late String _selectedRelationship;

  @override
  void initState() {
    super.initState();
    final nominee = ref.read(nomineeProvider);
    _nameController = TextEditingController(text: nominee.fullName);
    _dobController = TextEditingController(text: nominee.dateOfBirth);
    _phoneController = TextEditingController(text: nominee.phone);
    _selectedRelationship = nominee.relationship;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _localizedRelationship(String rel, BuildContext context) {
    final l10n = context.l10n;
    return switch (rel.toLowerCase()) {
      'spouse' => l10n.relSpouse,
      'mother' => l10n.relMother,
      'father' => l10n.relFather,
      'son' => l10n.relSon,
      'daughter' => l10n.relDaughter,
      'sibling' => l10n.relSibling,
      _ => l10n.relOther,
    };
  }

  void _saveNominee() {
    if (!_formKey.currentState!.validate()) return;

    final updated = NomineeModel(
      fullName: _nameController.text.trim(),
      relationship: _selectedRelationship,
      dateOfBirth: _dobController.text.trim(),
      phone: _phoneController.text.trim(),
      allocation: 100,
      isVerified: true,
    );

    ref.read(nomineeProvider.notifier).updateNominee(updated);

    setState(() => _isEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.nomineeSavedSuccess)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nominee = ref.watch(nomineeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final relationships = [
      'Spouse',
      'Mother',
      'Father',
      'Son',
      'Daughter',
      'Sibling',
      'Other',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Icon & Title
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.family_restroom_rounded,
                  color: AppTheme.primaryGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.nomineeDetails,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.manageNomineeSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryGold),
                  tooltip: l10n.editNominee,
                  onPressed: () => setState(() => _isEditing = true),
                ),
            ],
          ),
          const SizedBox(height: 18),

          if (!_isEditing) ...[
            // View Mode Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  _NomineeDetailRow(
                    icon: Icons.person_outline,
                    label: l10n.nomineeName,
                    value: nominee.fullName,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.nomineeActiveVerified,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                  _NomineeDetailRow(
                    icon: Icons.people_outline,
                    label: l10n.nomineeRelationship,
                    value: _localizedRelationship(nominee.relationship, context),
                  ),
                  const Divider(height: 20),
                  _NomineeDetailRow(
                    icon: Icons.cake_outlined,
                    label: l10n.nomineeDob,
                    value: nominee.dateOfBirth,
                  ),
                  const Divider(height: 20),
                  _NomineeDetailRow(
                    icon: Icons.phone_outlined,
                    label: l10n.nomineePhone,
                    value: nominee.phone,
                  ),
                  const Divider(height: 20),
                  _NomineeDetailRow(
                    icon: Icons.pie_chart_outline,
                    label: l10n.nomineeAllocation,
                    value: '${nominee.allocation}%',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryGold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '${nominee.allocation}% Share',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Regulatory Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryGold.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.security_rounded,
                    size: 16,
                    color: AppTheme.primaryGold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.nomineeLegalDisclaimer,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        height: 1.35,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Edit Action Button
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.editNominee),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGold,
                  side: const BorderSide(color: AppTheme.primaryGold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else ...[
            // Edit Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.nomineeName,
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return l10n.fullNameRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedRelationship,
                    decoration: InputDecoration(
                      labelText: l10n.nomineeRelationship,
                      prefixIcon: const Icon(Icons.people_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: relationships.map((rel) {
                      return DropdownMenuItem(
                        value: rel,
                        child: Text(_localizedRelationship(rel, context)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedRelationship = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _dobController,
                    decoration: InputDecoration(
                      labelText: l10n.nomineeDob,
                      hintText: 'e.g. 14 May 1994',
                      prefixIcon: const Icon(Icons.cake_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Date of birth is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.nomineePhone,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return l10n.mobileNumberRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Actions with equal length and centered
                  AuraDialogActions.buttons(
                    context: context,
                    cancelLabel: l10n.cancel,
                    confirmLabel: l10n.saveNominee,
                    onCancel: () => setState(() => _isEditing = false),
                    onConfirm: _saveNominee,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NomineeDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _NomineeDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGold),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A populated Nominee Card displayed directly on the Profile Screen.
class ProfileNomineeCard extends ConsumerWidget {
  const ProfileNomineeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final nominee = ref.watch(nomineeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => showNomineeDetailsSheet(context, ref),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.family_restroom_rounded,
                          color: AppTheme.primaryGold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nominee.fullName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${nominee.relationship} • ${nominee.allocation}% Share',
                            style: TextStyle(
                              fontSize: 11,
                              color: AurumConsumerTheme.muted(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.nomineeActiveVerified,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${nominee.dateOfBirth}  |  ${nominee.phone}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AurumConsumerTheme.muted(context),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        l10n.details,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: AppTheme.primaryGold,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
