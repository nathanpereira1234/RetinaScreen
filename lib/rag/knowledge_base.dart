/// The curated, non-diagnostic knowledge base the assistant is grounded on.
///
/// Every entry is approved patient-education content — what a result means in
/// plain terms, how to prepare for the eye visit, why attending matters, basic
/// diabetic eye-care. Nothing here diagnoses; it explains and encourages
/// follow-up. This is the safety boundary of the RAG assistant: it answers from
/// THIS text, not from a model's open-ended memory. Add/curate entries here.
library;

class KbEntry {
  const KbEntry(this.lang, this.topic, this.text);
  final String lang;
  final String topic;
  final String text;
}

const knowledgeBase = <KbEntry>[
  // --- English ---
  KbEntry('en', 'referable',
      'A "referable" screening means the photos showed signs that an eye doctor should look at more closely. It is not a diagnosis — the eye doctor decides what, if anything, is needed. Most eye problems found early can be treated.'),
  KbEntry('en', 'not-referable',
      'A "not referable" result means no signs needing an eye-doctor visit were found this time. It is not a guarantee — diabetes can affect the eyes over time — so keep attending regular screenings.'),
  KbEntry('en', 'ungradable',
      'An "ungradable" result means the images were not clear enough to read, not that something is wrong. The screening should simply be done again to get a clear picture.'),
  KbEntry('en', 'why-attend',
      'Attending the referral appointment is the single most important step. Diabetic eye disease is usually painless and has no early symptoms, so the only way to catch it in time is to be examined. Early treatment prevents most vision loss.'),
  KbEntry('en', 'prepare-visit',
      'For your eye appointment, bring this report, your diabetes medicines list, and someone to accompany you if possible. Your eyes may be dilated with drops, which blurs vision for a few hours, so do not plan to drive yourself home.'),
  KbEntry('en', 'dilation',
      'Dilating drops widen the pupil so the doctor can see the back of the eye. They sting briefly and make vision blurry and light-sensitive for 4–6 hours. Bring sunglasses and arrange a ride.'),
  KbEntry('en', 'diabetes-eyes',
      'High blood sugar over time can damage the tiny blood vessels in the retina (diabetic retinopathy). Keeping blood sugar, blood pressure and cholesterol controlled lowers the risk and slows it down.'),
  KbEntry('en', 'cost-fear',
      'Many screening programs offer the eye-doctor referral free or at low cost. If cost or travel is a worry, ask your health worker — they can often arrange help so it does not stop you attending.'),
  KbEntry('en', 'no-symptoms',
      'You can have serious diabetic eye changes while your vision still feels normal. Do not wait for symptoms — a "referable" result means go now, even if you see fine.'),
  KbEntry('en', 'follow-up-time',
      'If you were referred, try to attend within a few weeks. If you cannot make the date, tell your health worker so they can help you reschedule rather than miss it.'),
  KbEntry('en', 'screening-frequency',
      'People with diabetes should have their eyes screened regularly, usually once a year, even when a previous result was normal. Your health worker will tell you when your next screening is due.'),
  KbEntry('en', 'privacy',
      'Your screening information is kept on the health worker\'s device to help your follow-up. It is not posted online. You can ask your health worker what is stored and ask for it to be removed.'),

  // --- Hindi ---
  KbEntry('hi', 'why-attend',
      'रेफ़रल अपॉइंटमेंट पर जाना सबसे ज़रूरी कदम है। मधुमेह से होने वाली आँखों की बीमारी अक्सर दर्द रहित होती है और शुरुआती लक्षण नहीं दिखते, इसलिए समय पर पकड़ने का एकमात्र तरीका जाँच है। जल्दी इलाज से दृष्टि बचती है।'),
  KbEntry('hi', 'prepare-visit',
      'आँखों की अपॉइंटमेंट के लिए यह रिपोर्ट और अपनी दवाओं की सूची साथ लाएँ। आँखों में बूँदें डाली जा सकती हैं जिससे कुछ घंटों तक धुंधला दिखता है, इसलिए स्वयं वाहन न चलाएँ।'),
  KbEntry('hi', 'no-symptoms',
      'आपकी दृष्टि सामान्य लगते हुए भी मधुमेह से आँखों में गंभीर बदलाव हो सकते हैं। लक्षणों का इंतज़ार न करें — "रेफ़रल" का मतलब है अभी जाएँ।'),

  // --- Tamil ---
  KbEntry('ta', 'why-attend',
      'பரிந்துரை சந்திப்புக்குச் செல்வது மிக முக்கியமான படி. நீரிழிவு கண் நோய் பெரும்பாலும் வலியற்றது, ஆரம்ப அறிகுறிகள் இருக்காது; எனவே சரியான நேரத்தில் கண்டறிய ஒரே வழி பரிசோதனையே. விரைவு சிகிச்சை பார்வையைக் காக்கிறது.'),
  KbEntry('ta', 'prepare-visit',
      'கண் சந்திப்புக்கு இந்த அறிக்கையையும் உங்கள் மருந்துகளின் பட்டியலையும் கொண்டு வாருங்கள். கண்களில் சொட்டு மருந்து இடப்படலாம்; சில மணி நேரம் மங்கலாகத் தெரியும், எனவே நீங்களே வாகனம் ஓட்ட வேண்டாம்.'),
];
