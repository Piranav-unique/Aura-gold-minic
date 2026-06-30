// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'AGS Gold';

  @override
  String get languageEnglish => 'ஆங்கிலம்';

  @override
  String get languageTamil => 'தமிழ்';

  @override
  String get changeAppLanguage => 'பயன்பாட்டு மொழியை மாற்று';

  @override
  String get selectPreferredLanguage =>
      'உங்கள் விருப்ப மொழியைத் தேர்ந்தெடுக்கவும்';

  @override
  String get languageSettings => 'மொழி அமைப்புகள்';

  @override
  String get languageLabel => 'மொழி';

  @override
  String get cancel => 'ரத்து செய்';

  @override
  String get retry => 'மீண்டும் முயற்சி';

  @override
  String get logout => 'வெளியேறு';

  @override
  String get logOut => 'வெளியேறு';

  @override
  String get signIn => 'உள்நுழை';

  @override
  String get signUp => 'பதிவு செய்';

  @override
  String get back => 'பின்செல்';

  @override
  String get save => 'சேமி';

  @override
  String get close => 'மூடு';

  @override
  String get yes => 'ஆம்';

  @override
  String get no => 'இல்லை';

  @override
  String get live => 'நேரடி';

  @override
  String get navAurum => 'AURUM';

  @override
  String get navHome => 'முகப்பு';

  @override
  String get navOverview => 'கண்ணோட்டம்';

  @override
  String get navProfile => 'சுயவிவரம்';

  @override
  String get navAuditLogs => 'தணிக்கை பதிவுகள்';

  @override
  String get navCustomers => 'வாடிக்கையாளர்கள்';

  @override
  String get navInventory => 'சரக்கு';

  @override
  String get navTransactions => 'பரிவர்த்தனைகள்';

  @override
  String get navReports => 'அறிக்கைகள்';

  @override
  String get navWorkflows => 'பணிப்பாய்வுகள்';

  @override
  String get navUsers => 'பயனர்கள்';

  @override
  String get navRoles => 'பாத்திரங்கள்';

  @override
  String get navPermissions => 'அனுமதிகள்';

  @override
  String get navSettings => 'அமைப்புகள்';

  @override
  String get goodMorning => 'காலை வணக்கம்';

  @override
  String get goodAfternoon => 'மதிய வணக்கம்';

  @override
  String get goodEvening => 'மாலை வணக்கம்';

  @override
  String greetingWithName(String salutation, String name) {
    return '$salutation, $name';
  }

  @override
  String get userDashboardKycSubtitle =>
      'தங்கம் மற்றும் வெள்ளி வாங்க/விற்பனையைத் திறக்க KYC சரிபார்ப்பை முடிக்கவும்.';

  @override
  String get userDashboardKycUnlockSubtitle =>
      'பாதுகாப்பான தங்க வர்த்தகத்தைத் திறக்க KYC-ஐ முடிக்கவும்.';

  @override
  String get userDashboardVerifiedSubtitle =>
      'உங்கள் கணக்கு சரிபார்க்கப்பட்டது. எப்போது வேண்டுமானாலும் தங்கம் வாங்கலாம்/விற்கலாம்.';

  @override
  String get customerBadge => 'வாடிக்கையாளர்';

  @override
  String get mobileVerified => 'மொபைல் சரிபார்க்கப்பட்டது';

  @override
  String get completeKycToTrade => 'வர்த்தகத்திற்கு KYC முடிக்கவும்';

  @override
  String get verifyPanBeforeTrading =>
      'தங்கம் வாங்க/விற்பதற்கு முன் உங்கள் PAN-ஐ சரிபார்க்கவும்.';

  @override
  String get completeKyc => 'KYC முடிக்கவும்';

  @override
  String get goldHoldings => 'தங்க வைப்பு';

  @override
  String get completeKycToStartTrading => 'வர்த்தகம் தொடங்க KYC முடிக்கவும்.';

  @override
  String get goldHoldingsFooterVerified =>
      'ஒவ்வொரு வர்த்தகத்திற்கும் பிறகு உங்கள் தங்க இருப்பு புதுப்பிக்கப்படும்.';

  @override
  String liveRatePerGram(String rate) {
    return 'நேரடி விலை: $rate / கிராம்';
  }

  @override
  String get tradeGold => 'தங்கம் வர்த்தகம்';

  @override
  String get buyGoldSubtitleShort => 'நேரடி சந்தை விலையில் வாங்கவும்';

  @override
  String get sellGoldSubtitleShort => 'வைப்பை பணமாக மாற்றவும்';

  @override
  String get kycRequired => 'KYC தேவை';

  @override
  String get goldSchemeTitle => 'தங்க சேமிப்பு திட்டம்';

  @override
  String get goldSchemeChooseBadge => 'திட்டம் தேர்வு';

  @override
  String goldSchemeActiveBadge(String grams) {
    return '$grams g திட்டம்';
  }

  @override
  String get goldSchemeCompletedBadge => 'முடிந்தது';

  @override
  String get goldSchemeChooseSubtitle =>
      'ஒரு திட்டத்தைத் தேர்ந்தெடுத்து சேமிக்கத் தொடங்குங்கள். உங்கள் இலக்கை நிறைவு செய்த பிறகே விற்பனை திறக்கப்படும்.';

  @override
  String goldSchemeTierLabel(int grams) {
    return '$grams g சேமி';
  }

  @override
  String goldSchemeSelected(int grams) {
    return '$grams g தங்க திட்டம் செயல்படுத்தப்பட்டது.';
  }

  @override
  String get goldSchemeSelectFailed =>
      'திட்டத்தை செயல்படுத்த முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';

  @override
  String get goldSchemeKycRequired => 'திட்டம் தேர்வு செய்ய KYC ஐ முடிக்கவும்.';

  @override
  String goldSchemeOfTarget(String grams) {
    return '$grams g இலக்கில்';
  }

  @override
  String goldSchemeProgressPercent(String percent) {
    return 'திட்டத்தில் $percent% முடிந்தது';
  }

  @override
  String get goldSchemeSellLocked => 'விற்பனையைத் திறக்க தங்கம் வாங்கவும்.';

  @override
  String get goldSchemeSellLockedShort => 'முதலில் தங்கம் வாங்கவும்';

  @override
  String get sellBuyGoldFirst => 'விற்பனையைத் திறக்க முதலில் தங்கம் வாங்கவும்.';

  @override
  String get goldSchemeContinueBuying => 'மேலும் தங்கம் வாங்கு';

  @override
  String goldSchemeCompletedBody(String grams) {
    return 'உங்கள் $grams g தங்க சேமிப்பு திட்டம் முடிந்தது.';
  }

  @override
  String get goldSchemeSellUnlocked =>
      'உங்கள் தங்க வைப்பை எப்போது வேண்டுமானாலும் விற்கலாம்.';

  @override
  String get goldSchemeSelectBeforeBuy =>
      'வாங்குவதற்கு முன் தங்க திட்டத்தை (1 g, 5 g, 10 g) தேர்வு செய்யவும்.';

  @override
  String goldSchemeTapBuyToConfirm(int grams) {
    return '$grams g தேர்வு — திட்டத்தை உறுதிப்படுத்த Buy Gold ஐ தட்டவும்.';
  }

  @override
  String get goldHoldingsChooseSchemeFooter =>
      'தங்கம் வாங்க கீழே ஒரு சேமிப்பு திட்டத்தைத் தேர்வு செய்யவும்.';

  @override
  String get goldHoldingsSchemeActiveFooter =>
      'உங்கள் திட்ட இலக்கு முடியும் வரை தொடர்ந்து வாங்குங்கள்.';

  @override
  String get goldSchemeBuyBlockedTitle =>
      'முதலில் உங்கள் தங்க திட்டத்தைத் தேர்வு செய்யுங்கள்';

  @override
  String get goldSchemeBuyBlockedBody =>
      'தங்கம் வாங்குவதற்கு முன் டாஷ்போர்டில் 1 g, 5 g அல்லது 10 g திட்டத்தைத் தேர்ந்தெடுக்கவும்.';

  @override
  String get mySavings => 'என் சேமிப்பு';

  @override
  String get myTransactions => 'என் பரிவர்த்தனைகள்';

  @override
  String buyRatePerGram(String rate) {
    return 'நேரடி வாங்கும் விலை: $rate / கிராம்';
  }

  @override
  String sellRatePerGram(String rate) {
    return 'நேரடி விற்பனை விலை: $rate / கிராம்';
  }

  @override
  String get goldWeightGrams => 'தங்க எடை (கிராம்)';

  @override
  String get amountInr => 'தொகை (₹)';

  @override
  String get continueToPayment => 'பணம் செலுத்த தொடரவும்';

  @override
  String get paymentComingSoon => 'பணம் செலுத்தும் வசதி விரைவில் வருகிறது.';

  @override
  String get paymentSuccess =>
      'பணம் செலுத்தப்பட்டது. உங்கள் தங்க இருப்பு புதுப்பிக்கப்பட்டது.';

  @override
  String get paymentFailed =>
      'பணம் செலுத்த முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';

  @override
  String get enterValidTradeAmount =>
      'சரியான தங்க எடை அல்லது தொகையை உள்ளிடவும்.';

  @override
  String get noTransactionsYet =>
      'இன்னும் பரிவர்த்தனைகள் இல்லை. வாங்க/விற்பனை வரலாறு இங்கே தோன்றும்.';

  @override
  String get addBankAccount => 'வங்கி கணக்கைச் சேர்';

  @override
  String get accountHolderName => 'கணக்கு உரிமையாளர் பெயர்';

  @override
  String get accountNumber => 'கணக்கு எண்';

  @override
  String get chooseBank => 'வங்கியைத் தேர்ந்தெடு';

  @override
  String get ifscCode => 'IFSC குறியீடு';

  @override
  String get accountType => 'கணக்கு வகை';

  @override
  String get savingsAccount => 'சேமிப்பு';

  @override
  String get currentAccount => 'தற்போதைய';

  @override
  String get verifyBankDetails => 'வங்கி விவரங்களை சரிபார்';

  @override
  String get sendBankOtp => 'சரிபார்க்க OTP அனுப்பு';

  @override
  String get confirmBankLink => 'வங்கி இணைப்பை உறுதிசெய்';

  @override
  String get bankLinkStepDetails => 'வங்கி விவரங்கள்';

  @override
  String get bankLinkStepOtp => 'OTP சரிபார்ப்பு';

  @override
  String bankLinkOtpSentToMobile(String last4) {
    return 'மொபைல் முடிவு $last4 க்கு OTP அனுப்பப்பட்டது';
  }

  @override
  String get bankLinkVerified => 'வங்கி இணைப்பு சரிபார்க்கப்பட்டது';

  @override
  String get verifyOtp => 'OTP சரிபார்';

  @override
  String get bankAccountsInfo =>
      'தங்கம் விற்கும்போது பணம் பெற உங்கள் இந்திய வங்கி கணக்கை இணைக்கவும்.';

  @override
  String get noBankAccountLinked => 'வங்கி கணக்கு இணைக்கப்படவில்லை';

  @override
  String get noBankAccountSubtitle =>
      'விற்பனை வருமானம் பெற உங்கள் சேமிப்பு அல்லது நடப்பு கணக்கைச் சேர்க்கவும்.';

  @override
  String get findIfscCode => 'உங்கள் IFSC குறியீட்டைக் கண்டறியுங்கள்';

  @override
  String get searchByState => 'மாநிலம் மூலம் தேடு';

  @override
  String get searchByDistrict => 'மாவட்டம் மூலம் தேடு';

  @override
  String get searchByBranch => 'கிளை மூலம் தேடு';

  @override
  String get selectBank => 'வங்கியைத் தேர்ந்தெடு';

  @override
  String get selectState => 'மாநிலத்தைத் தேர்ந்தெடு';

  @override
  String get selectDistrict => 'மாவட்டத்தைத் தேர்ந்தெடு';

  @override
  String get selectBranch => 'கிளையைத் தேர்ந்தெடு';

  @override
  String get saveAndSendOtp => 'சேமித்து OTP அனுப்பு';

  @override
  String get bankLinkOtpSent =>
      'உங்கள் பதிவு செய்யப்பட்ட மொபைலுக்கு OTP அனுப்பப்பட்டது.';

  @override
  String get bankAccountConnected => 'வங்கி கணக்கு வெற்றிகரமாக இணைக்கப்பட்டது.';

  @override
  String get bankAccountsOtpNote =>
      'வங்கி விவரங்கள் சரிபார்க்கப்பட்டு, பின்னர் உங்கள் பதிவு மொபைலுக்கு 6 இலக்க OTP அனுப்பப்படும்.';

  @override
  String get addBankAccountSheetSubtitle =>
      'PAN அட்டை மற்றும் வங்கி பாஸ்புக்கில் உள்ள பெயரையே பயன்படுத்தவும்.';

  @override
  String get governmentVerifiedIdentity => 'அரசு சரிபார்க்கப்பட்ட அடையாளம்';

  @override
  String get kycStage3Title => 'சரிபார்ப்பு முடிந்தது';

  @override
  String get kycStage3Subtitle =>
      'அரசு தரவுத்தளத்திலிருந்து உங்கள் விவரங்கள் பெறப்பட்டன. வாங்க/விற்பனை இப்போது திறக்கப்பட்டுள்ளது.';

  @override
  String get welcomeToAgsGold => 'AGS GOLD-க்கு வரவேற்கிறோம்';

  @override
  String get howWouldYouLikeToSignIn => 'எப்படி உள்நுழைய விரும்புகிறீர்கள்?';

  @override
  String get iAmAUser => 'நான் பயனர்';

  @override
  String get iAmAUserSubtitle =>
      'உங்கள் கணக்கில் உள்நுழையுங்கள், புதிய பயனராக இருந்தால் பதிவு செய்யுங்கள்.';

  @override
  String get iAmStaffAdmin => 'நான் ஊழியர் / நிர்வாகி';

  @override
  String get iAmStaffAdminSubtitle =>
      'தங்க செயல்பாடுகளை நிர்வகிக்க ஊழியர் சான்றுகளுடன் உள்நுழையவும்.';

  @override
  String get secureEnterprisePortal => 'பாதுகாப்பான நிறுவன போர்டல்';

  @override
  String get staffSignIn => 'ஊழியர் உள்நுழைவு';

  @override
  String get welcomeBack => 'மீண்டும் வருக';

  @override
  String get staffSignInSubtitle =>
      'செயல்பாட்டு போர்டலை அணுக உங்கள் ஊழியர் சான்றுகளை உள்ளிடவும்.';

  @override
  String get endUserSignInSubtitle =>
      'பதிவு செய்தபோது பயன்படுத்திய மொபைல் எண்ணால் உள்நுழையவும்.';

  @override
  String get defaultSignInSubtitle =>
      'உங்கள் கணக்கை அணுக சான்றுகளை உள்ளிடவும்.';

  @override
  String get emailAddress => 'மின்னஞ்சல் முகவரி';

  @override
  String get emailRequired => 'மின்னஞ்சல் முகவரி தேவை.';

  @override
  String get emailInvalid => 'செல்லுபடியான மின்னஞ்சல் முகவரியை உள்ளிடவும்.';

  @override
  String get password => 'கடவுச்சொல்';

  @override
  String get passwordRequired => 'கடவுச்சொல் தேவை.';

  @override
  String get forgotPassword => 'கடவுச்சொல் மறந்துவிட்டதா?';

  @override
  String get enterPassword => 'உங்கள் கடவுச்சொல்லை உள்ளிடவும்';

  @override
  String get dontHaveAccountSignUp => 'கணக்கு இல்லையா? பதிவு செய்யுங்கள்';

  @override
  String get backToAccountType => 'கணக்கு வகைக்குத் திரும்பு';

  @override
  String get createAccount => 'கணக்கை உருவாக்கு';

  @override
  String get createAccountSubtitle =>
      'தங்க சேமிப்பு மற்றும் நேரடி விலைகளைக் கண்காணிக்க AURUM-இல் சேருங்கள்.';

  @override
  String get firstName => 'முதல் பெயர்';

  @override
  String get lastName => 'கடைசி பெயர்';

  @override
  String get confirmPassword => 'கடவுச்சொல்லை உறுதிப்படுத்து';

  @override
  String get passwordsDoNotMatch => 'கடவுச்சொற்கள் பொருந்தவில்லை.';

  @override
  String get accountCreatedSignIn =>
      'கணக்கு வெற்றிகரமாக உருவாக்கப்பட்டது. உள்நுழையவும்.';

  @override
  String get signUpFailed =>
      'பதிவு தோல்வி. இணைப்பைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.';

  @override
  String get alreadyHaveAccountSignIn =>
      'ஏற்கனவே கணக்கு உள்ளதா? உள்நுழையுங்கள்';

  @override
  String get myProfile => 'என் சுயவிவரம்';

  @override
  String get profileSettings => 'சுயவிவர அமைப்புகள்';

  @override
  String get general => 'பொது';

  @override
  String get autoSavings => 'தானியங்கி சேமிப்பு';

  @override
  String get accountDetails => 'கணக்கு விவரங்கள்';

  @override
  String get statements => 'அறிக்கைகள்';

  @override
  String get identityVerification => 'அடையாள சரிபார்ப்பு';

  @override
  String get linkedBankAccount => 'இணைக்கப்பட்ட வங்கி கணக்கு';

  @override
  String get nomineeDetails => 'பயனாளி விவரங்கள்';

  @override
  String get modifyAutoSavings => 'தானியங்கி சேமிப்பை மாற்று';

  @override
  String get referAndEarn => 'பரிந்துரைத்து சம்பாதி';

  @override
  String get referAndEarnSubtitle =>
      'தங்க சேமிப்பு திட்டத்தை நண்பர்களுடன் பகிருங்கள். அவர்கள் பதிவு செய்து அதே திட்டத்தைத் தேர்ந்தெடுத்தால், டிஜிட்டல் பணப்பையில் வெகுமதி கிடைக்கும்.';

  @override
  String get digitalWalletBalance => 'டிஜிட்டல் பணப்பை இருப்பு';

  @override
  String get totalEarned => 'மொத்த வருமானம்';

  @override
  String get successfulReferrals => 'பரிந்துரைகள்';

  @override
  String get yourReferralCode => 'உங்கள் பரிந்துரை குறியீடு';

  @override
  String get shareSchemeEarn => 'திட்டத்தைப் பகிர்ந்து சம்பாதிக்கவும்';

  @override
  String get copyInviteLink => 'இணைப்பை நகலெடு';

  @override
  String get referralCodeCopied => 'பரிந்துரை குறியீடு நகலெடுக்கப்பட்டது.';

  @override
  String get referralLinkCopied => 'அழைப்பு இணைப்பு நகலெடுக்கப்பட்டது.';

  @override
  String referralLoadFailed(String error) {
    return 'பரிந்துரை விவரங்களை ஏற்ற முடியவில்லை: $error';
  }

  @override
  String referralSchemeTitle(int grams) {
    return '$grams g தங்க திட்டம்';
  }

  @override
  String referralSchemeReward(String amount) {
    return 'இந்த திட்டத்தில் சேர்ந்தால் நீங்கள் $amount பெறுவீர்கள்';
  }

  @override
  String get recentReferralRewards => 'சமீபத்திய வெகுமதிகள்';

  @override
  String referralRewardDetail(String grams, String amount) {
    return '$grams g திட்டம் • $amount வரவு வைக்கப்பட்டது';
  }

  @override
  String get referralCodeOptional => 'பரிந்துரை குறியீடு (விரும்பினால்)';

  @override
  String invitedScheme(int grams) {
    return 'அழைக்கப்பட்ட திட்டம்: $grams g';
  }

  @override
  String get applyVoucher => 'வவுச்சர் பயன்படுத்து';

  @override
  String get securityAndPermission => 'பாதுகாப்பு & அனுமதி';

  @override
  String get privacyPolicy => 'தனியுரிமைக் கொள்கை';

  @override
  String get digiGoldTermsTitle => 'Digi Gold விதிமுறைகள் & நிபந்தனைகள்';

  @override
  String get agreeToDigiGoldTerms =>
      'Digi Gold விதிமுறைகள் & நிபந்தனைகளுக்கு நான் ஒப்புக்கொள்கிறேன்';

  @override
  String get mustAcceptDigiGoldTerms =>
      'தொடர விதிமுறைகள் & நிபந்தனைகளை ஏற்க வேண்டும்.';

  @override
  String get viewTermsAndConditions => 'விதிமுறைகள் & நிபந்தனைகளைப் பார்க்க';

  @override
  String get helpAndSupport => 'உதவி & ஆதரவு';

  @override
  String get joinWhatsappChannel => 'WhatsApp சேனலில் சேருங்கள்';

  @override
  String get shareAuraGold => 'Aura Gold-ஐ பகிர்';

  @override
  String get rateAuraGold => 'Aura Gold-க்கு மதிப்பீடு';

  @override
  String get clearCache => 'தற்காலிக நினைவகத்தை அழி';

  @override
  String get cacheCleared => 'தற்காலிக நினைவகம் வெற்றிகரமாக அழிக்கப்பட்டது.';

  @override
  String get followUsToStayUpdated =>
      'புதுப்பித்த நிலையில் இருக்க எங்களைப் பின்தொடருங்கள்';

  @override
  String memberSince(String date) {
    return 'Aura-வில் இருந்து $date முதல்';
  }

  @override
  String comingSoon(String feature) {
    return '$feature விரைவில் வருகிறது.';
  }

  @override
  String get logoutConfirmTitle => 'வெளியேறு';

  @override
  String get logoutConfirmMessage => 'நிச்சயமாக வெளியேற விரும்புகிறீர்களா?';

  @override
  String get logOutConfirmTitle => 'வெளியேறு';

  @override
  String get logOutConfirmMessage =>
      'உங்கள் தற்போதைய அமர்வை முடிக்க விரும்புகிறீர்களா?';

  @override
  String get changePassword => 'கடவுச்சொல்லை மாற்று';

  @override
  String get notificationPreferences => 'அறிவிப்பு விருப்பங்கள்';

  @override
  String get settings => 'அமைப்புகள்';

  @override
  String get themeSettings => 'தீம் அமைப்புகள்';

  @override
  String get themeSystem => 'கணினி';

  @override
  String get themeLight => 'ஒளி';

  @override
  String get themeDark => 'இருள்';

  @override
  String get notificationSettings => 'அறிவிப்பு அமைப்புகள்';

  @override
  String get emailNotifications => 'மின்னஞ்சல் அறிவிப்புகள்';

  @override
  String get pushNotifications => 'புஷ் அறிவிப்புகள்';

  @override
  String get securityAlerts => 'பாதுகாப்பு எச்சரிக்கைகள்';

  @override
  String get systemUpdates => 'கணினி புதுப்பிப்புகள்';

  @override
  String get securitySettings => 'பாதுகாப்பு அமைப்புகள்';

  @override
  String get accountSettings => 'கணக்கு அமைப்புகள்';

  @override
  String get editProfile => 'சுயவிவரத்தைத் திருத்து';

  @override
  String get accountStatus => 'கணக்கு நிலை';

  @override
  String get accountStatusHint =>
      'உங்கள் கணக்கை செயலிழக்க நிர்வாகியைத் தொடர்பு கொள்ளுங்கள்.';

  @override
  String failedToLoadSettings(String error) {
    return 'அமைப்புகளை ஏற்ற முடியவில்லை: $error';
  }

  @override
  String get dashboardSubtitle =>
      'நேரடி தங்க விலைகளும் உங்கள் தங்க சேமிப்பும் ஒரே இடத்தில்.';

  @override
  String failedToLoadDashboard(String error) {
    return 'டாஷ்போர்டை ஏற்ற முடியவில்லை: $error';
  }

  @override
  String get quickActions => 'விரைவு செயல்கள்';

  @override
  String get newSale => 'புதிய விற்பனை';

  @override
  String get customer => 'வாடிக்கையாளர்';

  @override
  String get workflow => 'பணிப்பாய்வு';

  @override
  String get liveMetalPrices => 'நேரடி உலோக விலைகள்';

  @override
  String get gold => 'தங்கம்';

  @override
  String get silver => 'வெள்ளி';

  @override
  String get perGram => '/கிராம்';

  @override
  String get priceHistory => 'விலை வரலாறு';

  @override
  String get gold24k => '24K தங்கம்';

  @override
  String get metalSpotGoldTamilNadu => '24K தங்கம் · தமிழ்நாடு';

  @override
  String get metalSpotSilverTamilNadu => 'வெள்ளி · தமிழ்நாடு';

  @override
  String get priceHistorySubtitleGold => 'தமிழ்நாடு · 24K தங்கம்';

  @override
  String get priceHistorySubtitleSilver => 'தமிழ்நாடு · வெள்ளி';

  @override
  String get perGramLabel => 'ஒரு கிராமுக்கு';

  @override
  String priceUpdatedAt(String time) {
    return 'புதுப்பிக்கப்பட்டது $time';
  }

  @override
  String performanceChangeInRange(String arrow, String percent, String range) {
    return '$arrow $percent% · $range';
  }

  @override
  String get livePrice => 'நேரடி விலை';

  @override
  String get livePriceTitle => 'நேரடி விலை';

  @override
  String get setAlert => 'எச்சரிக்கை அமை';

  @override
  String performanceInRange(String range) {
    return '$range செயல்திறன்';
  }

  @override
  String get goldToSilverRatio => 'தங்கம்-வெள்ளி விகிதம்';

  @override
  String get silverUndervaluedVsGold =>
      'வெள்ளி தங்கத்துடன் ஒப்பிட குறைவாக மதிப்பிடப்படலாம்';

  @override
  String get goldPremiumModerate =>
      'தங்கத்திற்கும் வெள்ளிக்கும் இடையிலான விலை வேறுபாடு மிதமானது';

  @override
  String get yourGoldSavings => 'உங்கள் தங்க சேமிப்பு';

  @override
  String get yourSilverSavings => 'உங்கள் வெள்ளி சேமிப்பு';

  @override
  String get tapMetalIconForChart =>
      'நேரடி விலை வரைபடத்திற்கு தங்கம் அல்லது வெள்ளி ஐகானைத் தட்டவும்';

  @override
  String get backToAurum => 'AURUM-க்குத் திரும்பு';

  @override
  String failedToLoadLivePrice(String error) {
    return 'நேரடி விலையை ஏற்ற முடியவில்லை: $error';
  }

  @override
  String failedToLoadChart(String error) {
    return 'வரைபடத்தை ஏற்ற முடியவில்லை: $error';
  }

  @override
  String get kycVerification => 'KYC முடிக்கவும்';

  @override
  String get verifyForGoldTrading => 'தங்க வர்த்தகத்திற்கு சரிபார்க்கவும்';

  @override
  String get howPanVerificationWorks => 'PAN சரிபார்ப்பு எப்படி வேலை செய்கிறது';

  @override
  String get panVerificationFlowSubtitle =>
      'உங்கள் விவரங்கள் பாதுகாப்பாக உரிமம் பெற்ற KYC வழங்குநருக்கு அனுப்பப்பட்டு அரசு பதிவுகளுடன் சரிபார்க்கப்படும்.';

  @override
  String get panFlowYourDetails => 'உங்கள் விவரங்கள்';

  @override
  String get panFlowYourDetailsSubtitle => 'பெயர், PAN, பிறந்த தேதி';

  @override
  String get panFlowSecureTransfer => 'பாதுகாப்பான பரிமாற்றம்';

  @override
  String get panFlowSecureKycApi => 'பாதுகாப்பான KYC API';

  @override
  String get panFlowLicensedProvider => 'உரிமம் பெற்ற வழங்குநர்';

  @override
  String get kycStepConfirm => 'உறுதிப்படுத்து';

  @override
  String get kycStep1VerifyAadhaar => 'படி 1: ஆதாரை சரிபார்க்கவும்';

  @override
  String get kycAadhaarOtpInstruction =>
      'உங்கள் 12 இலக்க ஆதார் எண்ணை உள்ளிடவும். ஆதாருடன் இணைக்கப்பட்ட மொபைலுக்கு OTP அனுப்பப்படும் — அது நீங்கள் பதிவு செய்த மொபைல் எண்ணுடன் பொருந்த வேண்டும்.';

  @override
  String kycRegisteredMobileHint(String mobile) {
    return 'பதிவு செய்த மொபைல்: $mobile';
  }

  @override
  String get aadhaarMobileVerifiedSubtitle =>
      'ஆதார் சரிபார்க்கப்பட்டது. கீழே உள்ள மொபைல் உங்கள் ஆதாருடன் இணைக்கப்பட்டுள்ளது. PAN இணைப்புடன் தொடரவும்.';

  @override
  String get mobileNumber => 'மொபைல் எண்';

  @override
  String get kycMobileMismatchError =>
      'இந்த ஆதாருடன் இணைக்கப்பட்ட மொபைல் உங்கள் பதிவு செய்த எண்ணுடன் பொருந்தவில்லை. பதிவு செய்த அதே மொபைலைப் பயன்படுத்தவும்.';

  @override
  String get useDigilockerInstead => 'DigiLocker சரிபார்ப்பைப் பயன்படுத்தவும்';

  @override
  String get useManualPanInstead => 'கைமுறை PAN சரிபார்ப்பைப் பயன்படுத்தவும்';

  @override
  String get kycStage1Subtitle =>
      'நிலை 1: UIDAI OTP மூலம் உங்கள் ஆதாரை சரிபார்க்கவும்.';

  @override
  String get kycStage2Subtitle =>
      'நிலை 2: சரிபார்க்கப்பட்ட ஆதாருடன் உங்கள் PAN-ஐ இணைக்கவும்.';

  @override
  String get aadhaarOtpStep => 'ஆதார் OTP';

  @override
  String get panLinkStep => 'PAN இணைப்பு';

  @override
  String get aadhaarNumber => 'ஆதார் எண்';

  @override
  String get aadhaarHint => '12 இலக்க ஆதார் எண்';

  @override
  String get aadhaarInvalid => 'செல்லுபடியான 12 இலக்க ஆதார் எண்ணை உள்ளிடவும்';

  @override
  String get sendOtp => 'OTP அனுப்பு';

  @override
  String get sendingOtp => 'OTP அனுப்பப்படுகிறது...';

  @override
  String otpSentToMobile(String ending) {
    return 'ஆதாருடன் இணைக்கப்பட்ட மொபைலுக்கு OTP அனுப்பப்பட்டது$ending.';
  }

  @override
  String otpSentEnding(String last4) {
    return ' (முடிவு $last4)';
  }

  @override
  String get enterOtp => 'OTP உள்ளிடவும்';

  @override
  String get otpHint => '6 இலக்க OTP';

  @override
  String get otpInvalid => '6 இலக்க OTP-ஐ உள்ளிடவும்';

  @override
  String get changeAadhaarNumber => 'ஆதார் எண்ணை மாற்று';

  @override
  String get resendOtp => 'OTP மீண்டும் அனுப்பு';

  @override
  String get verifyAadhaar => 'ஆதாரை சரிபார்';

  @override
  String get verifying => 'சரிபார்க்கப்படுகிறது...';

  @override
  String get panNumber => 'PAN எண்';

  @override
  String get panHint => 'ABCDE1234F';

  @override
  String get panHelper =>
      'வருமான வரித் துறையில் உங்கள் PAN ஆதாருடன் இணைக்கப்பட்டுள்ளதா என்பதைச் சரிபார்க்கிறோம்.';

  @override
  String get panInvalid => 'செல்லுபடியான PAN-ஐ உள்ளிடவும் (எ.கா. ABCDE1234F)';

  @override
  String get backToAadhaarVerification => 'ஆதார் சரிபார்ப்புக்குத் திரும்பு';

  @override
  String get verifyPanLink => 'PAN இணைப்பை சரிபார்';

  @override
  String get aadhaarVerified => 'ஆதார் சரிபார்க்கப்பட்டது';

  @override
  String aadhaarVerifiedLast4(String last4) {
    return 'ஆதார் சரிபார்க்கப்பட்டது (****$last4)';
  }

  @override
  String get backToDashboard => 'டாஷ்போர்டுக்குத் திரும்பு';

  @override
  String get otpSentSnack => 'உங்கள் ஆதார் இணை மொபைலுக்கு OTP அனுப்பப்பட்டது.';

  @override
  String get aadhaarVerifiedSnack => 'ஆதார் வெற்றிகரமாக சரிபார்க்கப்பட்டது.';

  @override
  String get aadhaarVerifiedContinuePan =>
      'ஆதார் சரிபார்க்கப்பட்டது. தொடர கீழே உங்கள் PAN எண்ணை உள்ளிடவும்.';

  @override
  String get kycCompleteSnack =>
      'KYC முடிந்தது. தங்க வர்த்தகம் இப்போது திறக்கப்பட்டுள்ளது.';

  @override
  String get unableToSendOtp =>
      'OTP அனுப்ப முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';

  @override
  String get otpVerificationFailed =>
      'OTP சரிபார்ப்பு தோல்வி. மீண்டும் முயற்சிக்கவும்.';

  @override
  String get panVerificationFailed =>
      'PAN சரிபார்ப்பு தோல்வி. மீண்டும் முயற்சிக்கவும்.';

  @override
  String get kycBannerCompletePanTitle => 'PAN இணைப்பை முடிக்கவும்';

  @override
  String get kycBannerCompletePanSubtitle =>
      'உங்கள் ஆதார் சரிபார்க்கப்பட்டது. PAN ஆதாருடன் இணைக்கப்பட்டுள்ளதா என உறுதிப்படுத்தி தங்க வர்த்தகத்தைத் திறக்கவும்.';

  @override
  String get kycBannerContinuePan => 'PAN-உடன் தொடரவும்';

  @override
  String get kycBannerPendingTitle => 'KYC சரிபார்ப்பு நடந்து வருகிறது';

  @override
  String get kycBannerPendingSubtitle =>
      'உங்கள் ஆவணங்களை மதிப்பாய்வு செய்கிறோம். அங்கீகாரத்திற்குப் பிறகு தங்க வர்த்தகம் திறக்கப்படும்.';

  @override
  String get kycBannerViewStatus => 'நிலையைக் காண்க';

  @override
  String get kycBannerRejectedTitle => 'KYC சரிபார்ப்புக்கு கவனம் தேவை';

  @override
  String get kycBannerRejectedSubtitle =>
      'PAN உங்கள் ஆதாருடன் இணைக்கப்படவில்லை. வருமான வரித் துறையில் இணைத்து மீண்டும் முயற்சிக்கவும்.';

  @override
  String get kycBannerRestart => 'KYC-ஐ மீண்டும் தொடங்கு';

  @override
  String get kycBannerStartTitle =>
      'தங்க வர்த்தகத்திற்கு KYC சரிபார்ப்பை முடிக்கவும்';

  @override
  String get kycBannerStartSubtitle =>
      'OTP மூலம் ஆதாரை சரிபார்த்து, PAN இணைப்பை உறுதிசெய்து AURUM-இல் தங்க வர்த்தகத்தைத் திறக்கவும்.';

  @override
  String get kycBannerStartAction => 'KYC சரிபார்ப்பைத் தொடங்கு';

  @override
  String get kycStepAadhaar => 'ஆதார் சரிபார்ப்பு (UIDAI OTP)';

  @override
  String get kycStepPan => 'PAN–ஆதார் இணைப்பு';

  @override
  String get kycStepTrading => 'தங்க வர்த்தக அணுகல்';

  @override
  String get goldTrading => 'தங்க வர்த்தகம்';

  @override
  String get buyGold => 'தங்கம் வாங்க';

  @override
  String get sellGold => 'தங்கம் விற்க';

  @override
  String get buySilver => 'வெள்ளி வாங்க';

  @override
  String get sellSilver => 'வெள்ளி விற்க';

  @override
  String get buyGoldSubtitle =>
      'நேரடி விலையில் 24K டிஜிட்டல் தங்கம் வாங்குங்கள்';

  @override
  String get sellGoldSubtitle => 'உங்கள் தங்கத்தை உடனடியாக விற்க';

  @override
  String get buySilverSubtitle => 'நேரடி விலையில் டிஜிட்டல் வெள்ளி வாங்குங்கள்';

  @override
  String get sellSilverSubtitle => 'உங்கள் வெள்ளியை உடனடியாக விற்க';

  @override
  String get kycRequiredForTrading =>
      'தங்கம் மற்றும் வெள்ளி வாங்க/விற்க KYC சரிபார்ப்பை முடிக்கவும்.';

  @override
  String get kycVerifiedTitle => 'KYC சரிபார்க்கப்பட்டது';

  @override
  String get kycVerifiedSubtitle =>
      'AURUM-இல் தங்கம் மற்றும் வெள்ளியை வாங்கலாம்/விற்கலாம்.';

  @override
  String get kycVerifiedDashboardSubtitle =>
      'நீங்கள் பாதுகாப்பாக தங்கம் வாங்கலாம்/விற்கலாம்.';

  @override
  String get kycVerifiedHeading => 'KYC சரிபார்க்கப்பட்டது';

  @override
  String get verifiedViaSandbox =>
      'Sandbox Secure KYC மூலம் சரிபார்க்கப்பட்டது';

  @override
  String get panVerificationLabel => 'PAN சரிபார்ப்பு';

  @override
  String get registeredName => 'பதிவு செய்யப்பட்ட பெயர்';

  @override
  String get dateOfBirth => 'பிறந்த தேதி';

  @override
  String get gender => 'பாலினம்';

  @override
  String get address => 'முகவரி';

  @override
  String get state => 'மாநிலம்';

  @override
  String get district => 'மாவட்டம்';

  @override
  String get pincode => 'அஞ்சல் குறியீடு';

  @override
  String get mobileLinkedAadhaar => 'ஆதாருடன் மொபைல் இணைக்கப்பட்டது';

  @override
  String get aadhaarDetailsFromGov =>
      'இந்த விவரங்கள் UIDAI அரசு பதிவுகளிலிருந்து பெறப்பட்டன.';

  @override
  String get accountSection => 'கணக்கு';

  @override
  String get manageYourProfile =>
      'உங்கள் சுயவிவரத்தைப் பார்க்கவும் புதுப்பிக்கவும்';

  @override
  String get identityVerified => 'அடையாளம் சரிபார்க்கப்பட்டது';

  @override
  String get bankAccounts => 'வங்கி கணக்குகள்';

  @override
  String get manageBankAccounts =>
      'இணைக்கப்பட்ட வங்கி கணக்குகளை நிர்வகிக்கவும்';

  @override
  String get bankAccountsComingSoon => 'வங்கி கணக்கு இணைப்பு விரைவில் வரும்.';

  @override
  String get kycPromptTitle => 'வர்த்தகத்திற்கு KYC தேவை';

  @override
  String kycPromptMessage(String action) {
    return '$action செய்ய, முதலில் அடையாள சரிபார்ப்பை முடிக்கவும். சில நிமிடங்களே ஆகும்.';
  }

  @override
  String get startTrading => 'வர்த்தகத்தைத் தொடங்கு';

  @override
  String get notifications => 'அறிவிப்புகள்';

  @override
  String get noNotifications => 'இன்னும் அறிவிப்புகள் இல்லை';

  @override
  String get markAllRead => 'அனைத்தையும் படித்ததாகக் குறி';

  @override
  String failedToLoadProfile(String error) {
    return 'சுயவிவரத்தை ஏற்ற முடியவில்லை: $error';
  }

  @override
  String get sellGoldInquiryTitle => 'தங்கம் விற்பனை விசாரணை';

  @override
  String get sellGoldInquirySubtitle =>
      'நீங்கள் விற்க விரும்பும் தங்கம் பற்றி எங்களுக்குத் தெரிவிக்கவும். எங்கள் குழு உங்கள் கோரிக்கையை மதிப்பாய்வு செய்து தொடர்பு கொள்ளும்.';

  @override
  String get sellGoldInquirySubtitleShort =>
      'விற்பனை கோரிக்கையை சமர்ப்பிக்கவும்';

  @override
  String get sellGoldInquiryName => 'உங்கள் பெயர்';

  @override
  String get sellGoldInquiryMobile => 'மொபைல் எண்';

  @override
  String get sellGoldInquiryMessage => 'செய்தி';

  @override
  String get sellGoldInquiryNameRequired => 'உங்கள் பெயரை உள்ளிடவும்';

  @override
  String get sellGoldInquiryMobileRequired =>
      'சரியான 10 இலக்க மொபைல் எண்ணை உள்ளிடவும்';

  @override
  String get sellGoldInquiryMessageRequired =>
      'நீங்கள் விற்க விரும்புவதை விவரிக்கவும் (குறைந்தது 10 எழுத்துகள்)';

  @override
  String get sellGoldInquirySubmit => 'விசாரணையை சமர்ப்பிக்கவும்';

  @override
  String get sellGoldInquirySubmitted =>
      'உங்கள் விற்பனை கோரிக்கை சமர்ப்பிக்கப்பட்டது. விரைவில் தொடர்பு கொள்வோம்.';

  @override
  String get sellGoldInquirySubmitFailed =>
      'கோரிக்கையை சமர்ப்பிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';

  @override
  String get navSellInquiries => 'விற்பனை விசாரணைகள்';

  @override
  String goldInvestedAmount(String amount) {
    return 'முதலீடு: $amount';
  }

  @override
  String goldCurrentValue(String amount) {
    return 'தற்போதைய மதிப்பு: $amount';
  }

  @override
  String goldGramsOwned(String grams) {
    return '$grams g உங்கள் வைப்பு';
  }

  @override
  String get goldLiveAtMarketRate => 'நேரடி 24K சந்தை விலையில்';

  @override
  String get navPaymentSettlements => 'கட்டண தீர்வுகள்';

  @override
  String get navUserWallets => 'பயனர் பணப்பைகள்';
}
