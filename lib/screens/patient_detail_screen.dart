import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'patient_form_screen.dart';
import 'screening_form_screen.dart';

/// A patient's record: profile + call button, screening history, referral
/// advancement, and site navigation (supports A14 / A16 / A18).
class PatientDetailScreen extends ConsumerWidget {
  const PatientDetailScreen({super.key, required this.patientId});

  final int patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientProvider(patientId));
    final screeningsAsync = ref.watch(screeningsProvider(patientId));

    return patientAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(appBar: AppBar(), body: Center(child: Text('Error: $e'))),
      data: (patient) {
        if (patient == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Patient not found.')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(patient.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit patient',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PatientFormScreen(existing: patient),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _PatientCard(patient: patient),
              const SizedBox(height: AppSpacing.md),
              Text('Screenings',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              screeningsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Text('Error: $e'),
                data: (screenings) {
                  if (screenings.isEmpty) {
                    return const Text('No screenings yet. Add one below.');
                  }
                  return Column(
                    children: [
                      for (final s in screenings)
                        _ScreeningCard(patient: patient, screening: s),
                    ],
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ScreeningFormScreen(
                  patientId: patient.id,
                  patientName: patient.name,
                ),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add screening'),
          ),
        );
      },
    );
  }
}

class _PatientCard extends ConsumerWidget {
  const _PatientCard({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = [
      if (patient.age != null) '${patient.age} yrs',
      if (patient.sex != null && patient.sex!.isNotEmpty) patient.sex!,
    ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.isNotEmpty)
              Text(info, style: Theme.of(context).textTheme.bodyLarge),
            if (patient.phone.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: Text(patient.phone)),
                  TextButton.icon(
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                    onPressed: () =>
                        ref.read(launcherServiceProvider).dial(patient.phone),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScreeningCard extends ConsumerWidget {
  const _ScreeningCard({required this.patient, required this.screening});

  final Patient patient;
  final Screening screening;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = screening.referralStatus.nextStates;
    final site = screening.referralSite;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _resultText(screening.result),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _ReferralChip(status: screening.referralStatus),
                _ReportMenu(
                  onSelected: (action) =>
                      _report(context, ref, action),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(_formatDate(screening.screeningDate)),
            if (site != null && site.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(child: Text(site)),
                  TextButton.icon(
                    icon: const Icon(Icons.directions),
                    label: const Text('Navigate'),
                    onPressed: () =>
                        ref.read(launcherServiceProvider).openMaps(site),
                  ),
                ],
              ),
            ],
            if (next.isNotEmpty) ...[
              const Divider(),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final to in next)
                    OutlinedButton(
                      onPressed: () => _advance(context, ref, to),
                      child: Text('Mark ${to.name}'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build the screening report and either share it (system share sheet) or
  /// send it to a printer. The PDF is generated on-device from data already on
  /// the phone — nothing is uploaded.
  Future<void> _report(
    BuildContext context,
    WidgetRef ref,
    _ReportAction action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final history =
          await ref.read(referralHistoryProvider(screening.id).future);
      final service = ref.read(reportServiceProvider);
      switch (action) {
        case _ReportAction.share:
          await service.share(
            patient: patient,
            screening: screening,
            history: history,
          );
        case _ReportAction.print:
          await service.printOut(
            patient: patient,
            screening: screening,
            history: history,
          );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not create report: $e')),
      );
    }
  }

  Future<void> _advance(
    BuildContext context,
    WidgetRef ref,
    ReferralStatus to,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(patientRepositoryProvider)
          .advanceReferral(screeningId: screening.id, to: to);
      // Once the patient has reached the clinic, stop the reminder.
      if (to.hasReachedClinic) {
        await ref.read(notificationServiceProvider).cancel(screening.id);
      }
    } on InvalidReferralTransition catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

enum _ReportAction { share, print }

class _ReportMenu extends StatelessWidget {
  const _ReportMenu({required this.onSelected});

  final ValueChanged<_ReportAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ReportAction>(
      icon: const Icon(Icons.description_outlined),
      tooltip: 'Screening report',
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _ReportAction.share,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.ios_share),
            title: Text('Share report'),
          ),
        ),
        PopupMenuItem(
          value: _ReportAction.print,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.print_outlined),
            title: Text('Print report'),
          ),
        ),
      ],
    );
  }
}

class _ReferralChip extends StatelessWidget {
  const _ReferralChip({required this.status});

  final ReferralStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ReferralStatus.none => ('No referral', Colors.grey),
      ReferralStatus.referred => ('Referred', AppColors.pending),
      ReferralStatus.booked => ('Booked', AppColors.pending),
      ReferralStatus.attended => ('Attended', AppColors.reached),
      ReferralStatus.treated => ('Treated', AppColors.reached),
    };
    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

String _resultText(ScreeningResult r) => switch (r) {
      ScreeningResult.referable => 'Referable',
      ScreeningResult.notReferable => 'Not referable',
      ScreeningResult.ungradable => 'Ungradable',
    };

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';
