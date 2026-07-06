// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AGS Gold';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTamil => 'Tamil';

  @override
  String get changeAppLanguage => 'Change App Language';

  @override
  String get selectPreferredLanguage => 'Select your preferred language';

  @override
  String get languageSettings => 'Language Settings';

  @override
  String get languageLabel => 'Language';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get logout => 'Logout';

  @override
  String get logOut => 'Log Out';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign up';

  @override
  String get back => 'Back';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get live => 'LIVE';

  @override
  String get navAurum => 'AURUM';

  @override
  String get navHome => 'Home';

  @override
  String get navOverview => 'Overview';

  @override
  String get navProfile => 'Profile';

  @override
  String get navAuditLogs => 'Audit Logs';

  @override
  String get navCustomers => 'Customers';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get navReports => 'Reports';

  @override
  String get navWorkflows => 'Workflows';

  @override
  String get navUsers => 'Users';

  @override
  String get navRoles => 'Roles';

  @override
  String get navPermissions => 'Permissions';

  @override
  String get navSettings => 'Settings';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String greetingWithName(String salutation, String name) {
    return '$salutation, $name';
  }

  @override
  String get userDashboardKycSubtitle =>
      'Complete KYC verification to unlock gold and silver buy & sell on AURUM.';

  @override
  String get userDashboardKycUnlockSubtitle =>
      'Complete KYC to unlock secure gold trading.';

  @override
  String get userDashboardVerifiedSubtitle =>
      'Your account is verified. Buy or sell gold anytime.';

  @override
  String get customerBadge => 'Customer';

  @override
  String get mobileVerified => 'Mobile verified';

  @override
  String get completeKycToTrade => 'Complete KYC to trade';

  @override
  String get verifyPanBeforeTrading =>
      'Verify your PAN before buying or selling gold.';

  @override
  String get completeKyc => 'Complete KYC';

  @override
  String get goldHoldings => 'Gold holdings';

  @override
  String get completeKycToStartTrading => 'Complete KYC to start trading.';

  @override
  String get goldHoldingsFooterVerified =>
      'Your gold balance updates after each trade.';

  @override
  String liveRatePerGram(String rate) {
    return 'Live rate: $rate / gram';
  }

  @override
  String get tradeGold => 'Trade gold';

  @override
  String get buyGoldSubtitleShort => 'Purchase at live market rates';

  @override
  String get sellGoldSubtitleShort => 'Convert holdings to cash';

  @override
  String get kycRequired => 'KYC required';

  @override
  String get goldSchemeTitle => 'Gold savings scheme';

  @override
  String get goldSchemeChooseBadge => 'Choose plan';

  @override
  String goldSchemeActiveBadge(String grams) {
    return '$grams g plan';
  }

  @override
  String get goldSchemeCompletedBadge => 'Completed';

  @override
  String get goldSchemeChooseSubtitle =>
      'Pick one scheme to start saving. Sell unlocks only after you complete your chosen target.';

  @override
  String goldSchemeTierLabel(int grams) {
    return 'Save $grams g';
  }

  @override
  String goldSchemeSelected(int grams) {
    return '$grams g gold scheme activated.';
  }

  @override
  String get goldSchemeSelectFailed =>
      'Could not activate scheme. Please try again.';

  @override
  String get goldSchemeKycRequired => 'Complete KYC to choose a scheme.';

  @override
  String goldSchemeOfTarget(String grams) {
    return 'of $grams g target';
  }

  @override
  String goldSchemeProgressPercent(String percent) {
    return '$percent% of scheme completed';
  }

  @override
  String get goldSchemeSellLocked => 'Buy gold to unlock selling.';

  @override
  String get goldSchemeSellLockedShort => 'Buy gold first';

  @override
  String get sellBuyGoldFirst => 'Buy gold first to unlock selling.';

  @override
  String get goldSchemeContinueBuying => 'Buy more gold';

  @override
  String goldSchemeCompletedBody(String grams) {
    return 'You completed your $grams g gold savings scheme.';
  }

  @override
  String get goldSchemeSellUnlocked =>
      'You can sell your gold holdings anytime.';

  @override
  String get goldSchemeSelectBeforeBuy =>
      'Choose a gold scheme (1 g, 5 g, or 10 g) before buying.';

  @override
  String goldSchemeTapBuyToConfirm(int grams) {
    return '$grams g selected — tap Buy Gold to confirm and lock your plan.';
  }

  @override
  String get goldHoldingsChooseSchemeFooter =>
      'Choose a savings scheme below to start buying gold.';

  @override
  String get goldHoldingsSchemeActiveFooter =>
      'Plan in progress. Tap Sell Gold to submit a sell enquiry — our team will review it.';

  @override
  String get goldSchemeBuyBlockedTitle => 'Choose your gold scheme first';

  @override
  String get goldSchemeBuyBlockedBody =>
      'Select a 1 g, 5 g, or 10 g plan on your dashboard before purchasing gold.';

  @override
  String goldSchemeCompletionTitle(String grams) {
    return '$grams g scheme completed!';
  }

  @override
  String get goldSchemeCompletionBody =>
      'Would you like to sell your gold or start a higher savings plan?';

  @override
  String get goldSchemeCompletionBodyAfter1g =>
      'You reached your 1 g goal. Sell your gold now, or start a 5 g or 10 g savings plan.';

  @override
  String get goldSchemeCompletionBodyAfter5g =>
      'You reached your 5 g goal. Sell your gold now, or start a 10 g savings plan.';

  @override
  String get goldSchemeCompletionBodyMaxTier =>
      'You completed the 10 g plan — the highest tier. Sell your gold to receive payout in your bank.';

  @override
  String get goldSchemeCompletionAutoSell =>
      '10 g plan complete! Choose how much to sell and which bank to credit.';

  @override
  String get goldSchemeCompletionSell => 'Sell gold';

  @override
  String goldSchemeCompletionUpgrade(int grams) {
    return 'Start $grams g plan';
  }

  @override
  String get goldSchemeCompletionStay => 'Stay on dashboard';

  @override
  String goldSchemeUpgraded(int grams) {
    return '$grams g gold scheme activated.';
  }

  @override
  String get goldSchemeUpgradeFailed =>
      'Could not switch scheme. Please try again.';

  @override
  String get goldSchemeChangePlan => 'Change plan';

  @override
  String get goldSchemeChangePlanTitle => 'Which plan are you shifting to?';

  @override
  String get mySavings => 'My savings';

  @override
  String get myTransactions => 'My transactions';

  @override
  String buyRatePerGram(String rate) {
    return 'Live buy rate: $rate / gram';
  }

  @override
  String sellRatePerGram(String rate) {
    return 'Live sell rate: $rate / gram';
  }

  @override
  String get goldWeightGrams => 'Gold weight (grams)';

  @override
  String get amountInr => 'Amount (₹)';

  @override
  String get continueToPayment => 'Continue to payment';

  @override
  String get paymentComingSoon => 'Payment integration is coming soon.';

  @override
  String get paymentSuccess =>
      'Payment successful. Your gold balance has been updated.';

  @override
  String get paymentFailed => 'Payment failed. Please try again.';

  @override
  String get confirmingPayment => 'Confirming your payment…';

  @override
  String get paymentPending =>
      'Payment not completed yet. If you already paid, stay on this screen while we confirm.';

  @override
  String get enterValidTradeAmount => 'Enter a valid gold weight or amount.';

  @override
  String get noTransactionsYet =>
      'No gold transactions yet. Your buy and sell history will appear here.';

  @override
  String get addBankAccount => 'Add bank account';

  @override
  String get accountHolderName => 'Account holder name';

  @override
  String get accountNumber => 'Account number';

  @override
  String get chooseBank => 'Choose bank';

  @override
  String get ifscCode => 'IFSC code';

  @override
  String get accountType => 'Account type';

  @override
  String get savingsAccount => 'Savings';

  @override
  String get currentAccount => 'Current';

  @override
  String get verifyBankDetails => 'Verify bank details';

  @override
  String get sendBankOtp => 'Send OTP to verify';

  @override
  String get confirmBankLink => 'Confirm bank link';

  @override
  String get bankLinkStepDetails => 'Bank details';

  @override
  String get bankLinkStepOtp => 'OTP verify';

  @override
  String bankLinkOtpSentToMobile(String last4) {
    return 'OTP sent to mobile ending $last4';
  }

  @override
  String get bankLinkVerified => 'Bank link verified';

  @override
  String get verifyOtp => 'Verify OTP';

  @override
  String get bankAccountsInfo =>
      'Link up to 2 Indian bank accounts. When you sell gold, choose which account receives the payout.';

  @override
  String get noBankAccountLinked => 'No bank account linked';

  @override
  String get noBankAccountSubtitle =>
      'Add your savings or current account to receive sell payouts.';

  @override
  String get findIfscCode => 'Find your IFSC code';

  @override
  String get searchByState => 'Search by State';

  @override
  String get searchByDistrict => 'Search by District';

  @override
  String get searchByBranch => 'Search by Branch';

  @override
  String get selectBank => 'Select bank';

  @override
  String get selectState => 'Select State';

  @override
  String get selectDistrict => 'Select District';

  @override
  String get selectBranch => 'Select Branch';

  @override
  String get saveAndSendOtp => 'Save & send OTP';

  @override
  String get bankLinkOtpSent => 'OTP sent to your registered mobile number.';

  @override
  String get bankAccountConnected => 'Bank account linked successfully.';

  @override
  String get bankAccountsOtpNote =>
      'Bank details are verified, then confirmed with a 6-digit OTP sent to your registered mobile number.';

  @override
  String get addBankAccountSheetSubtitle =>
      'Use the same name as on your PAN card and bank passbook.';

  @override
  String get governmentVerifiedIdentity => 'Government verified identity';

  @override
  String get kycStage3Title => 'Verification complete';

  @override
  String get kycStage3Subtitle =>
      'Your details were fetched from government records. Buy and sell are now unlocked.';

  @override
  String get welcomeToAgsGold => 'Welcome to AGS GOLD';

  @override
  String get howWouldYouLikeToSignIn => 'How would you like to sign in?';

  @override
  String get iAmAUser => 'I am a User';

  @override
  String get iAmAUserSubtitle =>
      'Sign in to your account, or create one if you are new.';

  @override
  String get iAmStaffAdmin => 'I am Staff / Admin';

  @override
  String get iAmStaffAdminSubtitle =>
      'Sign in with your staff credentials to manage gold operations.';

  @override
  String get secureEnterprisePortal => 'Secure Enterprise Portal';

  @override
  String get staffSignIn => 'Staff Sign In';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get staffSignInSubtitle =>
      'Enter your staff credentials to access the operations portal.';

  @override
  String get endUserSignInSubtitle =>
      'Sign in with the mobile number you used during signup.';

  @override
  String get defaultSignInSubtitle =>
      'Enter your credentials to access your account.';

  @override
  String get emailAddress => 'Email Address';

  @override
  String get emailRequired => 'Email address is required.';

  @override
  String get emailInvalid => 'Enter a valid email address.';

  @override
  String get password => 'Password';

  @override
  String get passwordRequired => 'Password is required.';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get dontHaveAccountSignUp => 'Don\'t have an account? Sign up';

  @override
  String get backToAccountType => 'Back to account type';

  @override
  String get createAccount => 'Create Account';

  @override
  String get createAccountSubtitle =>
      'Join AURUM to track gold savings and live bullion prices.';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match.';

  @override
  String get accountCreatedSignIn =>
      'Account created successfully. Please sign in.';

  @override
  String get signUpFailed =>
      'Sign up failed. Please check your connection and try again.';

  @override
  String get alreadyHaveAccountSignIn => 'Already have an account? Sign in';

  @override
  String get myProfile => 'My Profile';

  @override
  String get profileSettings => 'Profile Settings';

  @override
  String get general => 'General';

  @override
  String get autoSavings => 'Auto Savings';

  @override
  String get accountDetails => 'Account Details';

  @override
  String get statements => 'Statements';

  @override
  String get identityVerification => 'Identity Verification';

  @override
  String get linkedBankAccount => 'Linked Bank Account';

  @override
  String get nomineeDetails => 'Nominee Details';

  @override
  String get modifyAutoSavings => 'Modify AutoSavings';

  @override
  String get referAndEarn => 'Refer & Earn';

  @override
  String get referAndEarnSubtitle =>
      'Share a gold savings scheme with friends. When they sign up and choose the same scheme, you earn digital wallet money.';

  @override
  String get digitalWalletBalance => 'Digital wallet balance';

  @override
  String get totalEarned => 'Total earned';

  @override
  String get successfulReferrals => 'Referrals';

  @override
  String get yourReferralCode => 'Your referral code';

  @override
  String get shareSchemeEarn => 'Share a scheme & earn';

  @override
  String get copyInviteLink => 'Copy link';

  @override
  String get referralCodeCopied => 'Referral code copied.';

  @override
  String get referralLinkCopied => 'Invite link copied.';

  @override
  String referralLoadFailed(String error) {
    return 'Could not load referral details: $error';
  }

  @override
  String referralSchemeTitle(int grams) {
    return '$grams g gold scheme';
  }

  @override
  String referralSchemeReward(String amount) {
    return 'You earn $amount when they join this scheme';
  }

  @override
  String get recentReferralRewards => 'Recent rewards';

  @override
  String referralRewardDetail(String grams, String amount) {
    return '$grams g scheme • $amount credited';
  }

  @override
  String get referralCodeOptional => 'Referral code (optional)';

  @override
  String invitedScheme(int grams) {
    return 'Invited scheme: $grams g';
  }

  @override
  String get applyVoucher => 'Apply Voucher';

  @override
  String get securityAndPermission => 'Security & Permission';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get digiGoldTermsTitle => 'Digi Gold Terms & Conditions';

  @override
  String get agreeToDigiGoldTerms =>
      'I agree to the Digi Gold Terms & Conditions';

  @override
  String get mustAcceptDigiGoldTerms =>
      'You must accept the Terms & Conditions to continue.';

  @override
  String get viewTermsAndConditions => 'View Terms & Conditions';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get joinWhatsappChannel => 'Join WhatsApp Channel';

  @override
  String get shareAuraGold => 'Share Aura Gold';

  @override
  String get rateAuraGold => 'Rate Aura Gold';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String get cacheCleared => 'Cache cleared successfully.';

  @override
  String get followUsToStayUpdated => 'Follow us, to stay updated';

  @override
  String memberSince(String date) {
    return 'Increasing Aura since, $date';
  }

  @override
  String comingSoon(String feature) {
    return '$feature is coming soon.';
  }

  @override
  String get logoutConfirmTitle => 'Logout';

  @override
  String get logoutConfirmMessage => 'Are you sure you want to logout?';

  @override
  String get logOutConfirmTitle => 'Log Out';

  @override
  String get logOutConfirmMessage =>
      'Are you sure you want to end your current session?';

  @override
  String get exitAppConfirmTitle => 'Exit app?';

  @override
  String get exitAppConfirmMessage => 'Are you sure you want to exit the app?';

  @override
  String get appUpdateAvailableTitle => 'Update available';

  @override
  String appUpdateAvailableMessage(String newVersion, String currentVersion) {
    return 'Version $newVersion is available. You are on $currentVersion.';
  }

  @override
  String get appUpdateReleaseNotes => 'What\'s new';

  @override
  String get appUpdateLater => 'Later';

  @override
  String get appUpdateNow => 'Update now';

  @override
  String get appUpdateDownloading => 'Downloading update…';

  @override
  String get appUpdateInstalling => 'Installing update…';

  @override
  String get appUpdateFailed => 'Update failed. Please try again.';

  @override
  String get appUpdateUpToDate => 'You\'re on the latest version.';

  @override
  String get appUpdateNotConfigured =>
      'In-app updates are not configured on the server yet.';

  @override
  String get appUpdatePermissionError =>
      'Allow install permission to update the app.';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get appVersionLabel => 'App version';

  @override
  String get changePassword => 'Change password';

  @override
  String get notificationPreferences => 'Notification preferences';

  @override
  String get settings => 'Settings';

  @override
  String get themeSettings => 'Theme Settings';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get emailNotifications => 'Email notifications';

  @override
  String get pushNotifications => 'Push notifications';

  @override
  String get securityAlerts => 'Security alerts';

  @override
  String get systemUpdates => 'System updates';

  @override
  String get securitySettings => 'Security Settings';

  @override
  String get accountSettings => 'Account Settings';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get profileUpdated => 'Profile updated successfully.';

  @override
  String get profileUpdateFailed =>
      'Could not update profile. Please try again.';

  @override
  String get currentPasswordRequired =>
      'Enter your current password to change email.';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get newPasswordMinLength => 'Password must be at least 8 characters.';

  @override
  String get passwordChangedRelogin => 'Password changed. Please log in again.';

  @override
  String get passwordChangeFailed =>
      'Could not change password. Please try again.';

  @override
  String get firstNameRequired => 'First name is required.';

  @override
  String get avatarUpdated => 'Profile photo updated.';

  @override
  String get avatarUploadFailed =>
      'Could not upload profile photo. Please try again.';

  @override
  String get accountStatus => 'Account status';

  @override
  String get accountStatusHint =>
      'Contact an administrator to deactivate your account.';

  @override
  String failedToLoadSettings(String error) {
    return 'Failed to load settings: $error';
  }

  @override
  String get dashboardSubtitle =>
      'Live bullion rates and your gold savings in one place.';

  @override
  String failedToLoadDashboard(String error) {
    return 'Failed to load dashboard: $error';
  }

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get newSale => 'New Sale';

  @override
  String get customer => 'Customer';

  @override
  String get workflow => 'Workflow';

  @override
  String get liveMetalPrices => 'Live Metal Prices';

  @override
  String get gold => 'Gold';

  @override
  String get silver => 'Silver';

  @override
  String get perGram => '/gm';

  @override
  String get priceHistory => 'Price History';

  @override
  String get gold24k => '24K Gold';

  @override
  String get metalSpotGoldTamilNadu => '24K Gold · Tamil Nadu';

  @override
  String get metalSpotSilverTamilNadu => 'Silver · Tamil Nadu';

  @override
  String get priceHistorySubtitleGold => 'Tamil Nadu · 24K gold';

  @override
  String get priceHistorySubtitleSilver => 'Tamil Nadu · silver';

  @override
  String get perGramLabel => 'per gram';

  @override
  String priceUpdatedAt(String time) {
    return 'Updated $time';
  }

  @override
  String performanceChangeInRange(String arrow, String percent, String range) {
    return '$arrow $percent% in $range';
  }

  @override
  String get livePrice => 'Live Price';

  @override
  String get livePriceTitle => 'Live Price';

  @override
  String get setAlert => 'Set Alert';

  @override
  String performanceInRange(String range) {
    return 'Performance in $range';
  }

  @override
  String get goldToSilverRatio => 'Gold to Silver Ratio';

  @override
  String get silverUndervaluedVsGold => 'Silver may be undervalued vs gold';

  @override
  String get goldPremiumModerate => 'Gold premium vs silver is moderate';

  @override
  String get yourGoldSavings => 'YOUR GOLD SAVINGS';

  @override
  String get yourSilverSavings => 'YOUR SILVER SAVINGS';

  @override
  String get tapMetalIconForChart =>
      'Tap the gold or silver icon to view live price chart';

  @override
  String get backToAurum => 'Back to AURUM';

  @override
  String failedToLoadLivePrice(String error) {
    return 'Failed to load live price: $error';
  }

  @override
  String failedToLoadChart(String error) {
    return 'Failed to load chart: $error';
  }

  @override
  String get kycVerification => 'Complete KYC';

  @override
  String get verifyForGoldTrading => 'Verify for gold trading';

  @override
  String get howPanVerificationWorks => 'How PAN verification works';

  @override
  String get panVerificationFlowSubtitle =>
      'Your details are checked against official government PAN records – you never leave this app.';

  @override
  String get panFlowYourDetails => 'Your details';

  @override
  String get panFlowYourDetailsSubtitle => 'Name, PAN, DOB';

  @override
  String get panFlowSecureTransfer => 'Secure transfer';

  @override
  String get panFlowSecureKycApi => 'Secure KYC API';

  @override
  String get panFlowLicensedProvider => 'Licensed provider';

  @override
  String get kycStepConfirm => 'Confirm';

  @override
  String get kycStep1VerifyAadhaar => 'Step 1: Verify Aadhaar';

  @override
  String get kycAadhaarOtpInstruction =>
      'Enter your 12-digit Aadhaar number. An OTP will be sent to the mobile linked with your Aadhaar — it must match the mobile number you registered with.';

  @override
  String kycRegisteredMobileHint(String mobile) {
    return 'Registered mobile: $mobile';
  }

  @override
  String get aadhaarMobileVerifiedSubtitle =>
      'Aadhaar verified. The mobile below is linked with your Aadhaar. Continue with PAN linking.';

  @override
  String get mobileNumber => 'Mobile number';

  @override
  String get kycMobileMismatchError =>
      'The mobile linked with this Aadhaar does not match your registered number. Use the same mobile you signed up with.';

  @override
  String get useDigilockerInstead => 'Use DigiLocker verification instead';

  @override
  String get useManualPanInstead => 'Use manual PAN verification instead';

  @override
  String get kycStage1Subtitle =>
      'Stage 1: Verify your Aadhaar with a UIDAI OTP.';

  @override
  String get kycStage2Subtitle =>
      'Stage 2: Link your PAN with your verified Aadhaar.';

  @override
  String get aadhaarOtpStep => 'Aadhaar OTP';

  @override
  String get panLinkStep => 'PAN link';

  @override
  String get aadhaarNumber => 'Aadhaar number';

  @override
  String get aadhaarHint => '12-digit Aadhaar number';

  @override
  String get aadhaarInvalid => 'Enter a valid 12-digit Aadhaar number';

  @override
  String get sendOtp => 'Send OTP';

  @override
  String get sendingOtp => 'Sending OTP...';

  @override
  String otpSentToMobile(String ending) {
    return 'OTP sent to the mobile linked with Aadhaar$ending.';
  }

  @override
  String otpSentEnding(String last4) {
    return ' ending $last4';
  }

  @override
  String get enterOtp => 'Enter OTP';

  @override
  String get otpHint => '6-digit OTP';

  @override
  String get otpInvalid => 'Enter the 6-digit OTP';

  @override
  String get changeAadhaarNumber => 'Change Aadhaar number';

  @override
  String get resendOtp => 'Resend OTP';

  @override
  String get verifyAadhaar => 'Verify Aadhaar';

  @override
  String get verifying => 'Verifying...';

  @override
  String get panNumber => 'PAN number';

  @override
  String get panHint => 'ABCDE1234F';

  @override
  String get panHelper =>
      'We verify that your PAN is linked with your Aadhaar on the Income Tax portal.';

  @override
  String get panInvalid => 'Enter a valid PAN (e.g. ABCDE1234F)';

  @override
  String get backToAadhaarVerification => 'Back to Aadhaar verification';

  @override
  String get verifyPanLink => 'Verify PAN link';

  @override
  String get aadhaarVerified => 'Aadhaar verified';

  @override
  String aadhaarVerifiedLast4(String last4) {
    return 'Aadhaar verified (****$last4)';
  }

  @override
  String get backToDashboard => 'Back to dashboard';

  @override
  String get otpSentSnack => 'OTP sent to your Aadhaar-linked mobile number.';

  @override
  String get aadhaarVerifiedSnack => 'Aadhaar verified successfully.';

  @override
  String get aadhaarVerifiedContinuePan =>
      'Aadhaar verified. Enter your PAN number below to continue.';

  @override
  String get kycCompleteSnack => 'KYC complete. Gold trading is now unlocked.';

  @override
  String get unableToSendOtp => 'Unable to send OTP. Please try again.';

  @override
  String get otpVerificationFailed =>
      'OTP verification failed. Please try again.';

  @override
  String get panVerificationFailed =>
      'PAN verification failed. Please try again.';

  @override
  String get kycBannerCompletePanTitle => 'Complete PAN linking';

  @override
  String get kycBannerCompletePanSubtitle =>
      'Your Aadhaar is verified. Enter your PAN to confirm it is linked with Aadhaar and unlock gold trading.';

  @override
  String get kycBannerContinuePan => 'Continue with PAN';

  @override
  String get kycBannerPendingTitle => 'KYC verification in progress';

  @override
  String get kycBannerPendingSubtitle =>
      'We are reviewing your documents. Gold trading unlocks after approval.';

  @override
  String get kycBannerViewStatus => 'View status';

  @override
  String get kycBannerRejectedTitle => 'KYC verification needs attention';

  @override
  String get kycBannerRejectedSubtitle =>
      'PAN could not be linked with your Aadhaar. Link them on the Income Tax portal and try again.';

  @override
  String get kycBannerRestart => 'Restart KYC';

  @override
  String get kycBannerStartTitle =>
      'Complete KYC verification for gold trading';

  @override
  String get kycBannerStartSubtitle =>
      'Verify your Aadhaar with OTP, then confirm your PAN is linked to unlock bullion trading on AURUM.';

  @override
  String get kycBannerStartAction => 'Start KYC verification';

  @override
  String get kycStepAadhaar => 'Aadhaar verification (UIDAI OTP)';

  @override
  String get kycStepPan => 'PAN–Aadhaar link (Sandbox)';

  @override
  String get kycStepTrading => 'Gold trading access';

  @override
  String get goldTrading => 'Gold Trading';

  @override
  String get buyGold => 'Buy Gold';

  @override
  String get sellGold => 'Sell Gold';

  @override
  String get buySilver => 'Buy Silver';

  @override
  String get sellSilver => 'Sell Silver';

  @override
  String get buyGoldSubtitle => 'Purchase 24K digital gold at live rates';

  @override
  String get sellGoldSubtitle => 'Sell your gold holdings instantly';

  @override
  String get buySilverSubtitle => 'Purchase digital silver at live rates';

  @override
  String get sellSilverSubtitle => 'Sell your silver holdings instantly';

  @override
  String get kycRequiredForTrading =>
      'Complete KYC verification to buy or sell gold and silver.';

  @override
  String get kycVerifiedTitle => 'KYC verified';

  @override
  String get kycVerifiedSubtitle =>
      'You can buy and sell gold and silver on AURUM.';

  @override
  String get kycVerifiedDashboardSubtitle =>
      'You can buy and sell gold securely.';

  @override
  String get kycVerifiedHeading => 'KYC Verified';

  @override
  String get verifiedViaSandbox => 'Verified via Sandbox Secure KYC';

  @override
  String get panVerificationLabel => 'PAN verification';

  @override
  String get registeredName => 'Registered name';

  @override
  String get dateOfBirth => 'Date of birth';

  @override
  String get gender => 'Gender';

  @override
  String get address => 'Address';

  @override
  String get state => 'State';

  @override
  String get district => 'District';

  @override
  String get pincode => 'Pincode';

  @override
  String get mobileLinkedAadhaar => 'Mobile linked with Aadhaar';

  @override
  String get aadhaarDetailsFromGov =>
      'These details were fetched from UIDAI government records.';

  @override
  String get accountSection => 'Account';

  @override
  String get manageYourProfile => 'View and update your profile';

  @override
  String get identityVerified => 'Identity verified';

  @override
  String get bankAccounts => 'Bank accounts';

  @override
  String get manageBankAccounts => 'Manage linked bank accounts';

  @override
  String get bankAccountsComingSoon => 'Bank account linking is coming soon.';

  @override
  String get kycPromptTitle => 'KYC required for trading';

  @override
  String kycPromptMessage(String action) {
    return 'To $action, complete identity verification first. It only takes a few minutes.';
  }

  @override
  String get startTrading => 'Start trading';

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String failedToLoadProfile(String error) {
    return 'Failed to load profile: $error';
  }

  @override
  String get sellGoldInquiryTitle => 'Sell Gold Inquiry';

  @override
  String get sellGoldInquirySubtitle =>
      'Tell us about the gold you want to sell. Our team will review your request and contact you with next steps.';

  @override
  String get sellGoldInquirySubtitleShort =>
      'Submit a sell request to our team';

  @override
  String get sellGoldInquiryName => 'Your name';

  @override
  String get sellGoldInquiryMobile => 'Mobile number';

  @override
  String get sellGoldInquiryMessage => 'Message';

  @override
  String get sellGoldInquiryNameRequired => 'Please enter your name';

  @override
  String get sellGoldInquiryMobileRequired =>
      'Enter a valid 10-digit mobile number';

  @override
  String get sellGoldInquiryMessageRequired =>
      'Please describe what you want to sell (min 10 characters)';

  @override
  String get sellGoldInquirySubmit => 'Submit inquiry';

  @override
  String get sellGoldInquirySubmitted =>
      'Your sell request was submitted. We will contact you soon.';

  @override
  String get sellGoldInquirySubmitFailed =>
      'Could not submit your request. Please try again.';

  @override
  String get sellGoldPayoutBankTitle => 'Credit payout to this bank';

  @override
  String get sellGoldPayoutBankSubtitle =>
      'Select which linked bank account should receive the sell amount.';

  @override
  String get bankAccountsMaxReached =>
      'You can link up to 2 bank accounts. Use one of your linked accounts for sell payouts.';

  @override
  String get sellGoldSuccessPayoutNote =>
      'After we verify your request, the amount will be transferred directly to your selected bank account.';

  @override
  String get sellGoldNoBankLinked =>
      'Add a bank account to receive your sell payout.';

  @override
  String get sellGoldAddBankAccount => 'Add bank account';

  @override
  String get sellGoldSelectPayoutBank => 'Select the bank account for payout';

  @override
  String get navSellInquiries => 'Sell Inquiries';

  @override
  String goldInvestedAmount(String amount) {
    return 'Invested: $amount';
  }

  @override
  String goldCurrentValue(String amount) {
    return 'Current value: $amount';
  }

  @override
  String goldGramsOwned(String grams) {
    return '$grams g owned';
  }

  @override
  String get goldLiveAtMarketRate => 'At live 24K market rate';

  @override
  String get navPaymentSettlements => 'Payment Settlements';

  @override
  String get navUserWallets => 'User Wallets';

  @override
  String get navPortfolio => 'Portfolio';

  @override
  String get myPortfolio => 'My Portfolio';

  @override
  String get recentSavings => 'Recent Savings';

  @override
  String get viewAll => 'View All';

  @override
  String get goldValue => 'Gold Value';

  @override
  String get silverValue => 'Silver Value';

  @override
  String get milestoneReached => 'Milestone reached';

  @override
  String get totalPortfolioValue => 'Total Portfolio Value';

  @override
  String get signUpMobileOtpSubtitle =>
      'Sign up with your mobile OTP to access AURUM GOLD & SILVERS.';

  @override
  String get fullName => 'Full Name';

  @override
  String get yourName => 'Your name';

  @override
  String get fullNameRequired => 'Name is required.';

  @override
  String get tenDigitMobile => '10-digit mobile';

  @override
  String get tenDigitMobileLogin => '10-digit mobile number';

  @override
  String get mobileNumberRequired => 'Mobile number is required.';

  @override
  String get otpFromSms => '6-digit OTP from SMS';

  @override
  String get enterSixDigitOtp => 'Enter the 6-digit OTP.';

  @override
  String get loginOtpIncorrect => 'Please check and enter your OTP.';

  @override
  String get verified => 'Verified';

  @override
  String get verify => 'Verify';

  @override
  String get signUpButton => 'Sign Up';

  @override
  String get reenterPassword => 'Re-enter your password';

  @override
  String get confirmPasswordPrompt => 'Please confirm your password.';

  @override
  String get passwordMin8 => 'Password must be at least 8 characters.';

  @override
  String get passwordAtLeast8 => 'At least 8 characters';

  @override
  String get emailHint => 'name@example.com';

  @override
  String get referralHint => 'ABCD1234';

  @override
  String get joinAurum => 'Join AURUM';

  @override
  String get joinAurumSubtitle => 'Access gold savings & live bullion prices';

  @override
  String get promoInsuredTitle => '100% INSURED';

  @override
  String get promoInsuredSubtitle => 'Vault-backed gold & silver';

  @override
  String get promoPurityTitle => '24K PURITY';

  @override
  String get promoPuritySubtitle => 'Certified bullion';

  @override
  String get socialProofHighlight => 'Thousands of investors ';

  @override
  String get socialProofRest => 'started their wealth journey this month';

  @override
  String get kycDialogTitle => 'Verify your identity';

  @override
  String get kycDialogMessage =>
      'Complete your KYC to unlock buying and selling gold & silver. It only takes a couple of minutes.';

  @override
  String get later => 'Later';

  @override
  String get verifyNow => 'Verify now';

  @override
  String get panCategory => 'PAN category';

  @override
  String get aadhaarLabel => 'Aadhaar';

  @override
  String get panLabel => 'PAN';

  @override
  String get searchHint => 'Search';

  @override
  String get stateLabel => 'State';
}
