import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

/// The reference screen (A12).
///
/// It proves the data layer end-to-end: it lists patients from the DB via
/// [patientListProvider], and adding one persists through
/// [patientRepositoryProvider] so it survives an app restart. Person B builds
/// the richer screens against this same contract (B16).
class PatientListScreen extends ConsumerWidget {
  const PatientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientListProvider);
    final pendingCount = ref.watch(pendingReferralCountProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          if (pendingCount != null && pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: Chip(
                  label: Text('$pendingCount follow-up'
                      '${pendingCount == 1 ? '' : 's'}'),
                  backgroundColor: AppColors.pending,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: patientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load patients:\n$e')),
        data: (patients) {
          if (patients.isEmpty) {
            return const _EmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: patients.length,
            itemBuilder: (context, i) => _PatientTile(patient: patients[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPatientSheet(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add patient'),
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (patient.age != null) '${patient.age} yrs',
      if (patient.sex != null && patient.sex!.isNotEmpty) patient.sex!,
      if (patient.phone.isNotEmpty) patient.phone,
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Text(
            patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          patient.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        // Patient detail / screening entry is Person B's B16/B17.
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined,
                size: 64, color: AppColors.primaryLight),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No patients yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap “Add patient” to register the first person.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal add-patient form — enough to prove persistence for A12. The full
/// validated form (required name, valid phone) is A13 / B16.
Future<void> _showAddPatientSheet(BuildContext context, WidgetRef ref) {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add patient',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Phone is required';
                  if (t.length < 7) return 'Enter a valid phone number';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: ageCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Age (optional)'),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  await ref.read(patientRepositoryProvider).addPatient(
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        age: int.tryParse(ageCtrl.text.trim()),
                      );
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
