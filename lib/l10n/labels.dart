/// Localised labels for the domain enums, shared by every screen so the
/// wording stays consistent. Kept out of `strings.dart` because that file has
/// no dependency on the domain enums by design.
library;

import '../models/enums.dart';
import 'strings.dart';

String resultLabel(AppStrings s, ScreeningResult r) => switch (r) {
      ScreeningResult.referable => s.referable,
      ScreeningResult.notReferable => s.notReferable,
      ScreeningResult.ungradable => s.ungradable,
    };

String referralStatusLabel(AppStrings s, ReferralStatus status) =>
    switch (status) {
      ReferralStatus.none => s.noReferral,
      ReferralStatus.referred => s.referred,
      ReferralStatus.booked => s.booked,
      ReferralStatus.attended => s.attended,
      ReferralStatus.treated => s.treated,
    };

/// Full sentence to speak aloud for a result (TTS), in the patient's language.
String spokenResult(AppStrings s, ScreeningResult r) => switch (r) {
      ScreeningResult.referable => s.spokenReferable,
      ScreeningResult.notReferable => s.spokenNotReferable,
      ScreeningResult.ungradable => s.spokenUngradable,
    };
