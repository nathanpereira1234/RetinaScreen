/// Lightweight in-app localisation (no codegen).
///
/// The app's own copy lives here as one map per language. `flutter_localizations`
/// still localises Material's built-in widgets (date pickers, etc.) via the
/// delegates wired in `main.dart`; this file covers RetinaScreen's strings.
///
/// Design goals:
/// - **Compile-safe.** Missing keys fall back to English, never crash.
/// - **Reviewable.** Translations sit in plain maps a native speaker can read.
/// - **Testable.** `test/strings_test.dart` asserts every language defines the
///   full English key set, so a forgotten translation is caught in CI.
///
/// Translations for `hi`/`ta` are a starting point and should be reviewed by a
/// native speaker before a real deployment.
library;

/// The languages the app ships. `code` matches the stored `preferredLanguage`
/// and the [Locale] language code.
enum AppLanguage {
  en('en', 'English'),
  hi('hi', 'हिन्दी'),
  ta('ta', 'தமிழ்');

  const AppLanguage(this.code, this.label);

  final String code;

  /// The language's own name (an endonym), so the picker is readable to a
  /// speaker regardless of the current UI language.
  final String label;

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
        (l) => l.code == code,
        orElse: () => AppLanguage.en,
      );
}

/// Resolved strings for one language. Getters read the map; anything missing
/// falls back to English so the UI is never blank.
class AppStrings {
  const AppStrings(this.language, this._table);

  final AppLanguage language;
  final Map<String, String> _table;

  static AppStrings of(AppLanguage language) =>
      AppStrings(language, _tables[language] ?? _en);

  String _get(String key) => _table[key] ?? _en[key] ?? key;

  String _fill(String key, Map<String, String> values) {
    var out = _get(key);
    values.forEach((k, v) => out = out.replaceAll('{$k}', v));
    return out;
  }

  // Navigation / shell
  String get appTitle => _get('appTitle');
  String get allPatients => _get('allPatients');
  String get programMetrics => _get('programMetrics');
  String get settings => _get('settings');

  // Home
  String get dueForFollowUp => _get('dueForFollowUp');
  String get recentlyScreened => _get('recentlyScreened');
  String get noPendingFollowUps => _get('noPendingFollowUps');
  String get noScreeningsYet => _get('noScreeningsYet');
  String get referralsAwaiting => _get('referralsAwaiting');
  String get addPatient => _get('addPatient');

  // Patient list
  String get patients => _get('patients');
  String get searchNameOrPhone => _get('searchNameOrPhone');
  String get noPatientsYet => _get('noPatientsYet');

  // Patient detail
  String get screenings => _get('screenings');
  String get noScreeningsAddBelow => _get('noScreeningsAddBelow');
  String get addScreening => _get('addScreening');
  String get call => _get('call');
  String get navigate => _get('navigate');
  String get remindPatient => _get('remindPatient');
  String get shareReport => _get('shareReport');
  String get printReport => _get('printReport');
  String get screeningReport => _get('screeningReport');
  String get years => _get('years');

  // Results
  String get referable => _get('referable');
  String get notReferable => _get('notReferable');
  String get ungradable => _get('ungradable');

  // Referral status
  String get noReferral => _get('noReferral');
  String get referred => _get('referred');
  String get booked => _get('booked');
  String get attended => _get('attended');
  String get treated => _get('treated');
  String markStatus(String status) => _fill('markStatus', {'status': status});

  // Metrics
  String get attendanceHeadline => _get('attendanceHeadline');
  String get reachedOfReferred => _get('reachedOfReferred');
  String get referralRate => _get('referralRate');
  String get ungradableRate => _get('ungradableRate');
  String get treatmentRate => _get('treatmentRate');
  String get screeningFunnel => _get('screeningFunnel');
  String get attendanceOverTime => _get('attendanceOverTime');
  String get exportCsv => _get('exportCsv');
  String get nothingToExport => _get('nothingToExport');

  // Settings
  String get languageLabel => _get('language');
  String get security => _get('security');
  String get appLock => _get('appLock');
  String get appLockSubtitle => _get('appLockSubtitle');
  String get changePin => _get('changePin');
  String get about => _get('about');
  String get doesNotDiagnose => _get('doesNotDiagnose');
  String get appearance => _get('appearance');
  String get themeSystem => _get('themeSystem');
  String get themeLight => _get('themeLight');
  String get themeDark => _get('themeDark');

  // Image quality gate
  String get imageQuality => _get('imageQuality');
  String get qualityGood => _get('qualityGood');
  String get qualityFair => _get('qualityFair');
  String get qualityPoor => _get('qualityPoor');
  String get retakeAdvised => _get('retakeAdvised');
  String get issueTooDark => _get('issueTooDark');
  String get issueTooBright => _get('issueTooBright');
  String get issueBlurry => _get('issueBlurry');
  String get issueLowField => _get('issueLowField');

  // Referral QR + voice
  String get referralQr => _get('referralQr');
  String get scanAtClinic => _get('scanAtClinic');
  String get listen => _get('listen');
  String get spokenReferable => _get('spokenReferable');
  String get spokenNotReferable => _get('spokenNotReferable');
  String get spokenUngradable => _get('spokenUngradable');

  // Batch 2: workflow / insights / accessibility
  String get delete => _get('delete');
  String get deletePatientTitle => _get('deletePatientTitle');
  String deletePatientBody(String name) =>
      _fill('deletePatientBody', {'name': name});
  String get overdue => _get('overdue');
  String get noReminder => _get('noReminder');
  String get reschedule => _get('reschedule');
  String get rangeAll => _get('rangeAll');
  String get range90 => _get('range90');
  String get range30 => _get('range30');
  String get bySite => _get('bySite');
  String get programReport => _get('programReport');
  String get textSize => _get('textSize');
  String get autoLock => _get('autoLock');
  String get immediately => _get('immediately');
  String get activityLog => _get('activityLog');
  String get noActivityYet => _get('noActivityYet');

  // Onboarding
  String get getStarted => _get('getStarted');
  String get skip => _get('skip');
  String get next => _get('next');
  String get onbTitle1 => _get('onbTitle1');
  String get onbBody1 => _get('onbBody1');
  String get onbTitle2 => _get('onbTitle2');
  String get onbBody2 => _get('onbBody2');
  String get onbTitle3 => _get('onbTitle3');
  String get onbBody3 => _get('onbBody3');

  // Lock screen
  String get unlock => _get('unlock');
  String get enterPin => _get('enterPin');
  String get setPin => _get('setPin');
  String get confirmPin => _get('confirmPin');
  String get wrongPin => _get('wrongPin');
  String get pinsDoNotMatch => _get('pinsDoNotMatch');
  String get useBiometric => _get('useBiometric');

  // Patient reminder message (templated). {name}, {site}.
  String reminderWithSite({required String name, required String site}) =>
      _fill('reminderWithSite', {'name': name, 'site': site});
  String reminderNoSite({required String name}) =>
      _fill('reminderNoSite', {'name': name});
}

// ---------------------------------------------------------------------------
// Tables. English is the source of truth; hi/ta mirror its keys.
// ---------------------------------------------------------------------------

const Map<String, String> _en = {
  'appTitle': 'RetinaScreen',
  'allPatients': 'All patients',
  'programMetrics': 'Program metrics',
  'settings': 'Settings',
  'dueForFollowUp': 'Due for follow-up',
  'recentlyScreened': 'Recently screened',
  'noPendingFollowUps': 'No pending follow-ups.',
  'noScreeningsYet': 'No screenings recorded yet.',
  'referralsAwaiting': 'referrals awaiting follow-up',
  'addPatient': 'Add patient',
  'patients': 'Patients',
  'searchNameOrPhone': 'Search name or phone',
  'noPatientsYet': 'No patients yet',
  'screenings': 'Screenings',
  'noScreeningsAddBelow': 'No screenings yet. Add one below.',
  'addScreening': 'Add screening',
  'call': 'Call',
  'navigate': 'Navigate',
  'remindPatient': 'Remind patient',
  'shareReport': 'Share report',
  'printReport': 'Print report',
  'screeningReport': 'Screening report',
  'years': 'yrs',
  'referable': 'Referable',
  'notReferable': 'Not referable',
  'ungradable': 'Ungradable',
  'noReferral': 'No referral',
  'referred': 'Referred',
  'booked': 'Booked',
  'attended': 'Attended',
  'treated': 'Treated',
  'markStatus': 'Mark {status}',
  'attendanceHeadline': 'of referred patients reached the clinic',
  'reachedOfReferred': '{reached} of {referred} referrals',
  'referralRate': 'Referral rate',
  'ungradableRate': 'Ungradable rate',
  'treatmentRate': 'Treatment rate',
  'screeningFunnel': 'Screening funnel',
  'attendanceOverTime': 'Screenings over time',
  'exportCsv': 'Export CSV',
  'nothingToExport': 'Nothing to export yet.',
  'language': 'Language',
  'security': 'Security',
  'appLock': 'App lock',
  'appLockSubtitle': 'Require a PIN or biometric to open the app',
  'changePin': 'Change PIN',
  'about': 'About',
  'doesNotDiagnose':
      'This app does not diagnose. A trained health worker records every '
          'result; the app explains it and helps the patient follow up.',
  'unlock': 'Unlock',
  'enterPin': 'Enter PIN',
  'setPin': 'Set a PIN',
  'confirmPin': 'Confirm PIN',
  'wrongPin': 'Wrong PIN. Try again.',
  'pinsDoNotMatch': 'PINs do not match.',
  'useBiometric': 'Use biometric',
  'reminderWithSite':
      'Hello {name}, this is a reminder from your eye-screening program. '
          'Please visit {site} for your eye check-up. Attending is important '
          'for your eye health.',
  'reminderNoSite':
      'Hello {name}, this is a reminder from your eye-screening program. '
          'Please visit the eye clinic for your check-up. Attending is '
          'important for your eye health.',
  'appearance': 'Appearance',
  'themeSystem': 'System default',
  'themeLight': 'Light',
  'themeDark': 'Dark',
  'imageQuality': 'Image quality',
  'qualityGood': 'Good quality',
  'qualityFair': 'Acceptable — could be clearer',
  'qualityPoor': 'Poor quality',
  'retakeAdvised': 'Retake advised before grading.',
  'issueTooDark': 'Too dark',
  'issueTooBright': 'Too bright / glare',
  'issueBlurry': 'Blurry / out of focus',
  'issueLowField': 'Retina not centred / too small',
  'referralQr': 'Referral QR',
  'scanAtClinic': 'Scan at the referral clinic to intake this patient.',
  'listen': 'Listen',
  'spokenReferable':
      'Your eye screening found signs that should be checked by an eye doctor. '
          'Please visit the referral clinic. Attending is important.',
  'spokenNotReferable':
      'Your eye screening found no urgent concern. Please continue regular '
          'screening as advised.',
  'spokenUngradable':
      'Your eye images were not clear enough. Please arrange to be screened '
          'again.',
  'getStarted': 'Get started',
  'skip': 'Skip',
  'next': 'Next',
  'onbTitle1': 'Screen. Refer. Follow up.',
  'onbBody1':
      'RetinaScreen helps health workers track diabetic-retinopathy referrals '
          'and make sure patients actually reach the clinic.',
  'onbTitle2': 'We explain — we do not diagnose',
  'onbBody2':
      'A trained health worker records every result. The app explains it in '
          'plain language and chases the follow-up.',
  'onbTitle3': 'Works offline, on any phone',
  'onbBody3':
      'Everything runs on the device — reminders, reports, QR hand-off and '
          'metrics — with no internet needed.',
  'delete': 'Delete',
  'deletePatientTitle': 'Delete patient?',
  'deletePatientBody':
      'This permanently removes {name} and all their screenings. This cannot '
          'be undone.',
  'overdue': 'Overdue',
  'noReminder': 'No reminder set',
  'reschedule': 'Reschedule',
  'rangeAll': 'All time',
  'range90': '90 days',
  'range30': '30 days',
  'bySite': 'By referral site',
  'programReport': 'Program PDF',
  'textSize': 'Text size',
  'autoLock': 'Auto-lock',
  'immediately': 'Immediately',
  'activityLog': 'Activity log',
  'noActivityYet': 'No activity yet.',
};

const Map<String, String> _hi = {
  'appTitle': 'RetinaScreen',
  'allPatients': 'सभी मरीज़',
  'programMetrics': 'कार्यक्रम आँकड़े',
  'settings': 'सेटिंग्स',
  'dueForFollowUp': 'फ़ॉलो-अप बाकी',
  'recentlyScreened': 'हाल में जाँचे गए',
  'noPendingFollowUps': 'कोई फ़ॉलो-अप बाकी नहीं।',
  'noScreeningsYet': 'अभी तक कोई जाँच दर्ज नहीं।',
  'referralsAwaiting': 'रेफ़रल फ़ॉलो-अप के इंतज़ार में',
  'addPatient': 'मरीज़ जोड़ें',
  'patients': 'मरीज़',
  'searchNameOrPhone': 'नाम या फ़ोन खोजें',
  'noPatientsYet': 'अभी कोई मरीज़ नहीं',
  'screenings': 'जाँचें',
  'noScreeningsAddBelow': 'अभी कोई जाँच नहीं। नीचे जोड़ें।',
  'addScreening': 'जाँच जोड़ें',
  'call': 'कॉल',
  'navigate': 'रास्ता',
  'remindPatient': 'मरीज़ को याद दिलाएँ',
  'shareReport': 'रिपोर्ट साझा करें',
  'printReport': 'रिपोर्ट प्रिंट करें',
  'screeningReport': 'जाँच रिपोर्ट',
  'years': 'साल',
  'referable': 'रेफ़र करने योग्य',
  'notReferable': 'रेफ़रल की ज़रूरत नहीं',
  'ungradable': 'जाँच योग्य नहीं',
  'noReferral': 'कोई रेफ़रल नहीं',
  'referred': 'रेफ़र किया',
  'booked': 'बुक किया',
  'attended': 'पहुँचे',
  'treated': 'इलाज हुआ',
  'markStatus': '{status} चिह्नित करें',
  'attendanceHeadline': 'रेफ़र मरीज़ों में से क्लिनिक पहुँचे',
  'reachedOfReferred': '{referred} में से {reached} पहुँचे',
  'referralRate': 'रेफ़रल दर',
  'ungradableRate': 'अयोग्य दर',
  'treatmentRate': 'इलाज दर',
  'screeningFunnel': 'जाँच फ़नल',
  'attendanceOverTime': 'समय के साथ जाँचें',
  'exportCsv': 'CSV निर्यात',
  'nothingToExport': 'अभी निर्यात के लिए कुछ नहीं।',
  'language': 'भाषा',
  'security': 'सुरक्षा',
  'appLock': 'ऐप लॉक',
  'appLockSubtitle': 'ऐप खोलने के लिए PIN या बायोमेट्रिक ज़रूरी',
  'changePin': 'PIN बदलें',
  'about': 'बारे में',
  'doesNotDiagnose':
      'यह ऐप निदान नहीं करता। हर नतीजा प्रशिक्षित स्वास्थ्यकर्मी दर्ज करता है; '
          'ऐप उसे समझाता है और फ़ॉलो-अप में मदद करता है।',
  'unlock': 'अनलॉक',
  'enterPin': 'PIN दर्ज करें',
  'setPin': 'PIN सेट करें',
  'confirmPin': 'PIN की पुष्टि करें',
  'wrongPin': 'ग़लत PIN। फिर कोशिश करें।',
  'pinsDoNotMatch': 'PIN मेल नहीं खाते।',
  'useBiometric': 'बायोमेट्रिक इस्तेमाल करें',
  'reminderWithSite':
      'नमस्ते {name}, यह आपके नेत्र-जाँच कार्यक्रम की याद दिलाने वाला संदेश है। '
          'कृपया अपनी आँखों की जाँच के लिए {site} जाएँ। पहुँचना आपकी आँखों की '
          'सेहत के लिए ज़रूरी है।',
  'reminderNoSite':
      'नमस्ते {name}, यह आपके नेत्र-जाँच कार्यक्रम की याद दिलाने वाला संदेश है। '
          'कृपया जाँच के लिए नेत्र क्लिनिक जाएँ। पहुँचना आपकी आँखों की सेहत के '
          'लिए ज़रूरी है।',
  'appearance': 'दिखावट',
  'themeSystem': 'सिस्टम डिफ़ॉल्ट',
  'themeLight': 'लाइट',
  'themeDark': 'डार्क',
  'imageQuality': 'छवि गुणवत्ता',
  'qualityGood': 'अच्छी गुणवत्ता',
  'qualityFair': 'ठीक — और साफ़ हो सकती है',
  'qualityPoor': 'ख़राब गुणवत्ता',
  'retakeAdvised': 'ग्रेडिंग से पहले दोबारा लेने की सलाह।',
  'issueTooDark': 'बहुत गहरा',
  'issueTooBright': 'बहुत चमकीला / चमक',
  'issueBlurry': 'धुंधला / फ़ोकस नहीं',
  'issueLowField': 'रेटिना केंद्रित नहीं / बहुत छोटा',
  'referralQr': 'रेफ़रल QR',
  'scanAtClinic': 'इस मरीज़ को दर्ज करने हेतु रेफ़रल क्लिनिक पर स्कैन करें।',
  'listen': 'सुनें',
  'spokenReferable':
      'आपकी आँखों की जाँच में ऐसे संकेत मिले जिन्हें नेत्र चिकित्सक को देखना '
          'चाहिए। कृपया रेफ़रल क्लिनिक जाएँ। पहुँचना ज़रूरी है।',
  'spokenNotReferable':
      'आपकी आँखों की जाँच में कोई तत्काल चिंता नहीं मिली। कृपया सलाह अनुसार '
          'नियमित जाँच जारी रखें।',
  'spokenUngradable':
      'आपकी आँखों की छवियाँ पर्याप्त साफ़ नहीं थीं। कृपया दोबारा जाँच कराएँ।',
  'getStarted': 'शुरू करें',
  'skip': 'छोड़ें',
  'next': 'आगे',
  'onbTitle1': 'जाँच। रेफ़रल। फ़ॉलो-अप।',
  'onbBody1':
      'RetinaScreen स्वास्थ्यकर्मियों को डायबिटिक रेटिनोपैथी रेफ़रल ट्रैक करने '
          'और यह सुनिश्चित करने में मदद करता है कि मरीज़ क्लिनिक पहुँचें।',
  'onbTitle2': 'हम समझाते हैं — निदान नहीं करते',
  'onbBody2':
      'हर नतीजा प्रशिक्षित स्वास्थ्यकर्मी दर्ज करता है। ऐप उसे सरल भाषा में '
          'समझाता है और फ़ॉलो-अप कराता है।',
  'onbTitle3': 'ऑफ़लाइन, किसी भी फ़ोन पर',
  'onbBody3':
      'सब कुछ डिवाइस पर चलता है — रिमाइंडर, रिपोर्ट, QR और आँकड़े — बिना '
          'इंटरनेट के।',
  'delete': 'हटाएँ',
  'deletePatientTitle': 'मरीज़ हटाएँ?',
  'deletePatientBody':
      'यह {name} और उनकी सभी जाँचें स्थायी रूप से हटा देगा। इसे पूर्ववत नहीं '
          'किया जा सकता।',
  'overdue': 'बकाया',
  'noReminder': 'कोई रिमाइंडर नहीं',
  'reschedule': 'फिर से तय करें',
  'rangeAll': 'पूरा समय',
  'range90': '90 दिन',
  'range30': '30 दिन',
  'bySite': 'रेफ़रल साइट अनुसार',
  'programReport': 'कार्यक्रम PDF',
  'textSize': 'टेक्स्ट आकार',
  'autoLock': 'ऑटो-लॉक',
  'immediately': 'तुरंत',
  'activityLog': 'गतिविधि लॉग',
  'noActivityYet': 'अभी कोई गतिविधि नहीं।',
};

const Map<String, String> _ta = {
  'appTitle': 'RetinaScreen',
  'allPatients': 'அனைத்து நோயாளிகள்',
  'programMetrics': 'திட்ட அளவீடுகள்',
  'settings': 'அமைப்புகள்',
  'dueForFollowUp': 'பின்தொடர்தல் நிலுவை',
  'recentlyScreened': 'சமீபத்தில் பரிசோதிக்கப்பட்டவர்',
  'noPendingFollowUps': 'நிலுவையில் பின்தொடர்தல் இல்லை.',
  'noScreeningsYet': 'இதுவரை பரிசோதனை பதிவு இல்லை.',
  'referralsAwaiting': 'பரிந்துரைகள் பின்தொடர்தலுக்கு காத்திருக்கின்றன',
  'addPatient': 'நோயாளியைச் சேர்',
  'patients': 'நோயாளிகள்',
  'searchNameOrPhone': 'பெயர் அல்லது தொலைபேசி தேடு',
  'noPatientsYet': 'இதுவரை நோயாளிகள் இல்லை',
  'screenings': 'பரிசோதனைகள்',
  'noScreeningsAddBelow': 'இதுவரை பரிசோதனை இல்லை. கீழே சேர்க்கவும்.',
  'addScreening': 'பரிசோதனையைச் சேர்',
  'call': 'அழை',
  'navigate': 'வழி',
  'remindPatient': 'நோயாளிக்கு நினைவூட்டு',
  'shareReport': 'அறிக்கையைப் பகிர்',
  'printReport': 'அறிக்கையை அச்சிடு',
  'screeningReport': 'பரிசோதனை அறிக்கை',
  'years': 'வயது',
  'referable': 'பரிந்துரைக்கத்தக்கது',
  'notReferable': 'பரிந்துரை தேவையில்லை',
  'ungradable': 'மதிப்பிட முடியாது',
  'noReferral': 'பரிந்துரை இல்லை',
  'referred': 'பரிந்துரைக்கப்பட்டது',
  'booked': 'முன்பதிவு',
  'attended': 'வந்தடைந்தார்',
  'treated': 'சிகிச்சை',
  'markStatus': '{status} எனக் குறி',
  'attendanceHeadline': 'பரிந்துரைக்கப்பட்டவர்களில் மருத்துவமனை சென்றவர்',
  'reachedOfReferred': '{referred} இல் {reached} சென்றனர்',
  'referralRate': 'பரிந்துரை விகிதம்',
  'ungradableRate': 'மதிப்பிடமுடியா விகிதம்',
  'treatmentRate': 'சிகிச்சை விகிதம்',
  'screeningFunnel': 'பரிசோதனை புனல்',
  'attendanceOverTime': 'காலப்போக்கில் பரிசோதனைகள்',
  'exportCsv': 'CSV ஏற்றுமதி',
  'nothingToExport': 'ஏற்றுமதி செய்ய எதுவும் இல்லை.',
  'language': 'மொழி',
  'security': 'பாதுகாப்பு',
  'appLock': 'ஆப் பூட்டு',
  'appLockSubtitle': 'ஆப்பைத் திறக்க PIN அல்லது பயோமெட்ரிக் தேவை',
  'changePin': 'PIN மாற்று',
  'about': 'பற்றி',
  'doesNotDiagnose':
      'இந்த ஆப் நோயறியாது. ஒவ்வொரு முடிவையும் பயிற்சி பெற்ற சுகாதார பணியாளர் '
          'பதிவு செய்கிறார்; ஆப் அதை விளக்கி பின்தொடர்தலுக்கு உதவுகிறது.',
  'unlock': 'திற',
  'enterPin': 'PIN உள்ளிடு',
  'setPin': 'PIN அமை',
  'confirmPin': 'PIN உறுதிப்படுத்து',
  'wrongPin': 'தவறான PIN. மீண்டும் முயற்சி செய்.',
  'pinsDoNotMatch': 'PIN பொருந்தவில்லை.',
  'useBiometric': 'பயோமெட்ரிக் பயன்படுத்து',
  'reminderWithSite':
      'வணக்கம் {name}, இது உங்கள் கண் பரிசோதனை திட்டத்தின் நினைவூட்டல். '
          'உங்கள் கண் பரிசோதனைக்கு {site} க்கு வரவும். வருகை உங்கள் கண் '
          'ஆரோக்கியத்திற்கு முக்கியம்.',
  'reminderNoSite':
      'வணக்கம் {name}, இது உங்கள் கண் பரிசோதனை திட்டத்தின் நினைவூட்டல். '
          'பரிசோதனைக்கு கண் மருத்துவமனைக்கு வரவும். வருகை உங்கள் கண் '
          'ஆரோக்கியத்திற்கு முக்கியம்.',
  'appearance': 'தோற்றம்',
  'themeSystem': 'சிஸ்டம் இயல்பு',
  'themeLight': 'ஒளி',
  'themeDark': 'இருள்',
  'imageQuality': 'பட தரம்',
  'qualityGood': 'நல்ல தரம்',
  'qualityFair': 'ஏற்கத்தக்கது — தெளிவாக இருக்கலாம்',
  'qualityPoor': 'மோசமான தரம்',
  'retakeAdvised': 'மதிப்பிடுவதற்கு முன் மீண்டும் எடுக்க பரிந்துரை.',
  'issueTooDark': 'மிக இருட்டு',
  'issueTooBright': 'மிக பிரகாசம் / ஒளிர்வு',
  'issueBlurry': 'மங்கலானது / குவியம் இல்லை',
  'issueLowField': 'விழித்திரை மையப்படவில்லை / மிகச் சிறியது',
  'referralQr': 'பரிந்துரை QR',
  'scanAtClinic':
      'இந்த நோயாளியைச் சேர்க்க பரிந்துரை மருத்துவமனையில் ஸ்கேன் செய்யவும்.',
  'listen': 'கேள்',
  'spokenReferable':
      'உங்கள் கண் பரிசோதனையில் கண் மருத்துவரால் பரிசோதிக்கப்பட வேண்டிய '
          'அறிகுறிகள் கண்டறியப்பட்டன. பரிந்துரை மருத்துவமனைக்கு வரவும். வருகை '
          'முக்கியம்.',
  'spokenNotReferable':
      'உங்கள் கண் பரிசோதனையில் அவசர கவலை எதுவும் இல்லை. பரிந்துரைப்படி வழக்கமான '
          'பரிசோதனையைத் தொடரவும்.',
  'spokenUngradable':
      'உங்கள் கண் படங்கள் போதிய தெளிவாக இல்லை. மீண்டும் பரிசோதனை செய்யவும்.',
  'getStarted': 'தொடங்கு',
  'skip': 'தவிர்',
  'next': 'அடுத்து',
  'onbTitle1': 'பரிசோதி. பரிந்துரை. பின்தொடர்.',
  'onbBody1':
      'RetinaScreen சுகாதார பணியாளர்களுக்கு நீரிழிவு விழித்திரை பரிந்துரைகளைக் '
          'கண்காணிக்கவும், நோயாளிகள் மருத்துவமனைக்கு வருவதை உறுதிசெய்யவும் '
          'உதவுகிறது.',
  'onbTitle2': 'நாங்கள் விளக்குகிறோம் — நோயறியவில்லை',
  'onbBody2':
      'ஒவ்வொரு முடிவையும் பயிற்சி பெற்ற பணியாளர் பதிவு செய்கிறார். ஆப் அதை '
          'எளிய மொழியில் விளக்கி பின்தொடர்தலுக்கு உதவுகிறது.',
  'onbTitle3': 'இணையம் இல்லாமல், எந்த தொலைபேசியிலும்',
  'onbBody3':
      'அனைத்தும் சாதனத்தில் இயங்கும் — நினைவூட்டல்கள், அறிக்கைகள், QR மற்றும் '
          'அளவீடுகள் — இணையம் தேவையில்லை.',
  'delete': 'நீக்கு',
  'deletePatientTitle': 'நோயாளியை நீக்கவா?',
  'deletePatientBody':
      'இது {name} மற்றும் அவரது அனைத்து பரிசோதனைகளையும் நிரந்தரமாக நீக்கும். '
          'இதைத் திரும்பப் பெற முடியாது.',
  'overdue': 'தாமதம்',
  'noReminder': 'நினைவூட்டல் இல்லை',
  'reschedule': 'மறுஅட்டவணை',
  'rangeAll': 'எல்லா நேரமும்',
  'range90': '90 நாட்கள்',
  'range30': '30 நாட்கள்',
  'bySite': 'பரிந்துரை தளம் வாரியாக',
  'programReport': 'திட்ட PDF',
  'textSize': 'எழுத்து அளவு',
  'autoLock': 'தானியங்கு பூட்டு',
  'immediately': 'உடனடியாக',
  'activityLog': 'செயல்பாட்டு பதிவு',
  'noActivityYet': 'இதுவரை செயல்பாடு இல்லை.',
};

const Map<AppLanguage, Map<String, String>> _tables = {
  AppLanguage.en: _en,
  AppLanguage.hi: _hi,
  AppLanguage.ta: _ta,
};

/// Exposed for the completeness test.
Map<String, String> get englishStrings => _en;
Map<AppLanguage, Map<String, String>> get allStringTables => _tables;
