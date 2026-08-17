import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';

/// The reference screen (A12). Lists patients from the DB via
/// [patientListProvider]; tapping opens the detail screen, and the FAB opens
/// the add-patient form (A13). A search box filters by name or phone — the
/// filter is applied client-side over the already-loaded list, so it stays
/// instant and fully offline.
class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Case-insensitive match on name or phone (digits only, so a spaced or
  /// dashed query still matches a stored number).
  bool _matches(Patient p) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    if (p.name.toLowerCase().contains(q)) return true;
    final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isNotEmpty && p.phone.contains(digits);
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientListProvider);
    final pendingCount = ref.watch(pendingReferralCountProvider).valueOrNull;
    final s = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.patients),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                hintText: s.searchNameOrPhone,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear',
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
      body: patientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load patients:\n$e')),
        data: (patients) {
          if (patients.isEmpty) {
            return const _EmptyState();
          }
          final filtered = patients.where(_matches).toList();
          if (filtered.isEmpty) {
            return _NoMatches(query: _query);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: filtered.length,
            itemBuilder: (context, i) => _PatientTile(patient: filtered[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PatientFormScreen()),
        ),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(s.addPatient),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'No patients match “$query”.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
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
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PatientDetailScreen(patientId: patient.id),
          ),
        ),
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
