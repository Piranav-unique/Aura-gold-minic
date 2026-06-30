import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ta.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ta'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AGS Gold'**
  String get appTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageTamil.
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get languageTamil;

  /// No description provided for @changeAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change App Language'**
  String get changeAppLanguage;

  /// No description provided for @selectPreferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language'**
  String get selectPreferredLanguage;

  /// No description provided for @languageSettings.
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get languageSettings;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @navAurum.
  ///
  /// In en, this message translates to:
  /// **'AURUM'**
  String get navAurum;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get navOverview;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navAuditLogs.
  ///
  /// In en, this message translates to:
  /// **'Audit Logs'**
  String get navAuditLogs;

  /// No description provided for @navCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get navCustomers;

  /// No description provided for @navInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get navInventory;

  /// No description provided for @navTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get navTransactions;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navWorkflows.
  ///
  /// In en, this message translates to:
  /// **'Workflows'**
  String get navWorkflows;

  /// No description provided for @navUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get navUsers;

  /// No description provided for @navRoles.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get navRoles;

  /// No description provided for @navPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get navPermissions;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @greetingWithName.
  ///
  /// In en, this message translates to:
  /// **'{salutation}, {name}'**
  String greetingWithName(String salutation, String name);

  /// No description provided for @userDashboardKycSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Complete KYC verification to unlock gold and silver buy & sell on AURUM.'**
  String get userDashboardKycSubtitle;

  /// No description provided for @userDashboardKycUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Complete KYC to unlock secure gold trading.'**
  String get userDashboardKycUnlockSubtitle;

  /// No description provided for @userDashboardVerifiedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your account is verified. Buy or sell gold anytime.'**
  String get userDashboardVerifiedSubtitle;

  /// No description provided for @customerBadge.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customerBadge;

  /// No description provided for @mobileVerified.
  ///
  /// In en, this message translates to:
  /// **'Mobile verified'**
  String get mobileVerified;

  /// No description provided for @completeKycToTrade.
  ///
  /// In en, this message translates to:
  /// **'Complete KYC to trade'**
  String get completeKycToTrade;

  /// No description provided for @verifyPanBeforeTrading.
  ///
  /// In en, this message translates to:
  /// **'Verify your PAN before buying or selling gold.'**
  String get verifyPanBeforeTrading;

  /// No description provided for @completeKyc.
  ///
  /// In en, this message translates to:
  /// **'Complete KYC'**
  String get completeKyc;

  /// No description provided for @goldHoldings.
  ///
  /// In en, this message translates to:
  /// **'Gold holdings'**
  String get goldHoldings;

  /// No description provided for @completeKycToStartTrading.
  ///
  /// In en, this message translates to:
  /// **'Complete KYC to start trading.'**
  String get completeKycToStartTrading;

  /// No description provided for @goldHoldingsFooterVerified.
  ///
  /// In en, this message translates to:
  /// **'Your gold balance updates after each trade.'**
  String get goldHoldingsFooterVerified;

  /// No description provided for @liveRatePerGram.
  ///
  /// In en, this message translates to:
  /// **'Live rate: {rate} / gram'**
  String liveRatePerGram(String rate);

  /// No description provided for @tradeGold.
  ///
  /// In en, this message translates to:
  /// **'Trade gold'**
  String get tradeGold;

  /// No description provided for @buyGoldSubtitleShort.
  ///
  /// In en, this message translates to:
  /// **'Purchase at live market rates'**
  String get buyGoldSubtitleShort;

  /// No description provided for @sellGoldSubtitleShort.
  ///
  /// In en, this message translates to:
  /// **'Convert holdings to cash'**
  String get sellGoldSubtitleShort;

  /// No description provided for @kycRequired.
  ///
  /// In en, this message translates to:
  /// **'KYC required'**
  String get kycRequired;

  /// No description provided for @goldSchemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Gold savings scheme'**
  String get goldSchemeTitle;

  /// No description provided for @goldSchemeChooseBadge.
  ///
  /// In en, this message translates to:
  /// **'Choose plan'**
  String get goldSchemeChooseBadge;

  /// No description provided for @goldSchemeActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'{grams} g plan'**
  String goldSchemeActiveBadge(String grams);

  /// No description provided for @goldSchemeCompletedBadge.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get goldSchemeCompletedBadge;

  /// No description provided for @goldSchemeChooseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick one scheme to start saving. Sell unlocks only after you complete your chosen target.'**
  String get goldSchemeChooseSubtitle;

  /// No description provided for @goldSchemeTierLabel.
  ///
  /// In en, this message translates to:
  /// **'Save {grams} g'**
  String goldSchemeTierLabel(int grams);

  /// No description provided for @goldSchemeSelected.
  ///
  /// In en, this message translates to:
  /// **'{grams} g gold scheme activated.'**
  String goldSchemeSelected(int grams);

  /// No description provided for @goldSchemeSelectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not activate scheme. Please try again.'**
  String get goldSchemeSelectFailed;

  /// No description provided for @goldSchemeKycRequired.
  ///
  /// In en, this message translates to:
  /// **'Complete KYC to choose a scheme.'**
  String get goldSchemeKycRequired;

  /// No description provided for @goldSchemeOfTarget.
  ///
  /// In en, this message translates to:
  /// **'of {grams} g target'**
  String goldSchemeOfTarget(String grams);

  /// No description provided for @goldSchemeProgressPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of scheme completed'**
  String goldSchemeProgressPercent(String percent);

  /// No description provided for @goldSchemeSellLocked.
  ///
  /// In en, this message translates to:
  /// **'Buy gold to unlock selling.'**
  String get goldSchemeSellLocked;

  /// No description provided for @goldSchemeSellLockedShort.
  ///
  /// In en, this message translates to:
  /// **'Buy gold first'**
  String get goldSchemeSellLockedShort;

  /// No description provided for @sellBuyGoldFirst.
  ///
  /// In en, this message translates to:
  /// **'Buy gold first to unlock selling.'**
  String get sellBuyGoldFirst;

  /// No description provided for @goldSchemeContinueBuying.
  ///
  /// In en, this message translates to:
  /// **'Buy more gold'**
  String get goldSchemeContinueBuying;

  /// No description provided for @goldSchemeCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'You completed your {grams} g gold savings scheme.'**
  String goldSchemeCompletedBody(String grams);

  /// No description provided for @goldSchemeSellUnlocked.
  ///
  /// In en, this message translates to:
  /// **'You can sell your gold holdings anytime.'**
  String get goldSchemeSellUnlocked;

  /// No description provided for @goldSchemeSelectBeforeBuy.
  ///
  /// In en, this message translates to:
  /// **'Choose a gold scheme (1 g, 5 g, or 10 g) before buying.'**
  String get goldSchemeSelectBeforeBuy;

  /// No description provided for @goldSchemeTapBuyToConfirm.
  ///
  /// In en, this message translates to:
  /// **'{grams} g selected — tap Buy Gold to confirm and lock your plan.'**
  String goldSchemeTapBuyToConfirm(int grams);

  /// No description provided for @goldHoldingsChooseSchemeFooter.
  ///
  /// In en, this message translates to:
  /// **'Choose a savings scheme below to start buying gold.'**
  String get goldHoldingsChooseSchemeFooter;

  /// No description provided for @goldHoldingsSchemeActiveFooter.
  ///
  /// In en, this message translates to:
  /// **'Keep buying until your scheme target is complete.'**
  String get goldHoldingsSchemeActiveFooter;

  /// No description provided for @goldSchemeBuyBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your gold scheme first'**
  String get goldSchemeBuyBlockedTitle;

  /// No description provided for @goldSchemeBuyBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Select a 1 g, 5 g, or 10 g plan on your dashboard before purchasing gold.'**
  String get goldSchemeBuyBlockedBody;

  /// No description provided for @mySavings.
  ///
  /// In en, this message translates to:
  /// **'My savings'**
  String get mySavings;

  /// No description provided for @myTransactions.
  ///
  /// In en, this message translates to:
  /// **'My transactions'**
  String get myTransactions;

  /// No description provided for @buyRatePerGram.
  ///
  /// In en, this message translates to:
  /// **'Live buy rate: {rate} / gram'**
  String buyRatePerGram(String rate);

  /// No description provided for @sellRatePerGram.
  ///
  /// In en, this message translates to:
  /// **'Live sell rate: {rate} / gram'**
  String sellRatePerGram(String rate);

  /// No description provided for @goldWeightGrams.
  ///
  /// In en, this message translates to:
  /// **'Gold weight (grams)'**
  String get goldWeightGrams;

  /// No description provided for @amountInr.
  ///
  /// In en, this message translates to:
  /// **'Amount (₹)'**
  String get amountInr;

  /// No description provided for @continueToPayment.
  ///
  /// In en, this message translates to:
  /// **'Continue to payment'**
  String get continueToPayment;

  /// No description provided for @paymentComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Payment integration is coming soon.'**
  String get paymentComingSoon;

  /// No description provided for @paymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment successful. Your gold balance has been updated.'**
  String get paymentSuccess;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. Please try again.'**
  String get paymentFailed;

  /// No description provided for @enterValidTradeAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid gold weight or amount.'**
  String get enterValidTradeAmount;

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No gold transactions yet. Your buy and sell history will appear here.'**
  String get noTransactionsYet;

  /// No description provided for @addBankAccount.
  ///
  /// In en, this message translates to:
  /// **'Add bank account'**
  String get addBankAccount;

  /// No description provided for @accountHolderName.
  ///
  /// In en, this message translates to:
  /// **'Account holder name'**
  String get accountHolderName;

  /// No description provided for @accountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get accountNumber;

  /// No description provided for @chooseBank.
  ///
  /// In en, this message translates to:
  /// **'Choose bank'**
  String get chooseBank;

  /// No description provided for @ifscCode.
  ///
  /// In en, this message translates to:
  /// **'IFSC code'**
  String get ifscCode;

  /// No description provided for @accountType.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get accountType;

  /// No description provided for @savingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get savingsAccount;

  /// No description provided for @currentAccount.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentAccount;

  /// No description provided for @verifyBankDetails.
  ///
  /// In en, this message translates to:
  /// **'Verify bank details'**
  String get verifyBankDetails;

  /// No description provided for @sendBankOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP to verify'**
  String get sendBankOtp;

  /// No description provided for @confirmBankLink.
  ///
  /// In en, this message translates to:
  /// **'Confirm bank link'**
  String get confirmBankLink;

  /// No description provided for @bankLinkStepDetails.
  ///
  /// In en, this message translates to:
  /// **'Bank details'**
  String get bankLinkStepDetails;

  /// No description provided for @bankLinkStepOtp.
  ///
  /// In en, this message translates to:
  /// **'OTP verify'**
  String get bankLinkStepOtp;

  /// No description provided for @bankLinkOtpSentToMobile.
  ///
  /// In en, this message translates to:
  /// **'OTP sent to mobile ending {last4}'**
  String bankLinkOtpSentToMobile(String last4);

  /// No description provided for @bankLinkVerified.
  ///
  /// In en, this message translates to:
  /// **'Bank link verified'**
  String get bankLinkVerified;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verifyOtp;

  /// No description provided for @bankAccountsInfo.
  ///
  /// In en, this message translates to:
  /// **'Link your Indian bank account to receive payouts when you sell gold.'**
  String get bankAccountsInfo;

  /// No description provided for @noBankAccountLinked.
  ///
  /// In en, this message translates to:
  /// **'No bank account linked'**
  String get noBankAccountLinked;

  /// No description provided for @noBankAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your savings or current account to receive sell payouts.'**
  String get noBankAccountSubtitle;

  /// No description provided for @findIfscCode.
  ///
  /// In en, this message translates to:
  /// **'Find your IFSC code'**
  String get findIfscCode;

  /// No description provided for @searchByState.
  ///
  /// In en, this message translates to:
  /// **'Search by State'**
  String get searchByState;

  /// No description provided for @searchByDistrict.
  ///
  /// In en, this message translates to:
  /// **'Search by District'**
  String get searchByDistrict;

  /// No description provided for @searchByBranch.
  ///
  /// In en, this message translates to:
  /// **'Search by Branch'**
  String get searchByBranch;

  /// No description provided for @selectBank.
  ///
  /// In en, this message translates to:
  /// **'Select bank'**
  String get selectBank;

  /// No description provided for @selectState.
  ///
  /// In en, this message translates to:
  /// **'Select State'**
  String get selectState;

  /// No description provided for @selectDistrict.
  ///
  /// In en, this message translates to:
  /// **'Select District'**
  String get selectDistrict;

  /// No description provided for @selectBranch.
  ///
  /// In en, this message translates to:
  /// **'Select Branch'**
  String get selectBranch;

  /// No description provided for @saveAndSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Save & send OTP'**
  String get saveAndSendOtp;

  /// No description provided for @bankLinkOtpSent.
  ///
  /// In en, this message translates to:
  /// **'OTP sent to your registered mobile number.'**
  String get bankLinkOtpSent;

  /// No description provided for @bankAccountConnected.
  ///
  /// In en, this message translates to:
  /// **'Bank account linked successfully.'**
  String get bankAccountConnected;

  /// No description provided for @bankAccountsOtpNote.
  ///
  /// In en, this message translates to:
  /// **'Bank details are verified, then confirmed with a 6-digit OTP sent to your registered mobile number.'**
  String get bankAccountsOtpNote;

  /// No description provided for @addBankAccountSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the same name as on your PAN card and bank passbook.'**
  String get addBankAccountSheetSubtitle;

  /// No description provided for @governmentVerifiedIdentity.
  ///
  /// In en, this message translates to:
  /// **'Government verified identity'**
  String get governmentVerifiedIdentity;

  /// No description provided for @kycStage3Title.
  ///
  /// In en, this message translates to:
  /// **'Verification complete'**
  String get kycStage3Title;

  /// No description provided for @kycStage3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your details were fetched from government records. Buy and sell are now unlocked.'**
  String get kycStage3Subtitle;

  /// No description provided for @welcomeToAgsGold.
  ///
  /// In en, this message translates to:
  /// **'Welcome to AGS GOLD'**
  String get welcomeToAgsGold;

  /// No description provided for @howWouldYouLikeToSignIn.
  ///
  /// In en, this message translates to:
  /// **'How would you like to sign in?'**
  String get howWouldYouLikeToSignIn;

  /// No description provided for @iAmAUser.
  ///
  /// In en, this message translates to:
  /// **'I am a User'**
  String get iAmAUser;

  /// No description provided for @iAmAUserSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account, or create one if you are new.'**
  String get iAmAUserSubtitle;

  /// No description provided for @iAmStaffAdmin.
  ///
  /// In en, this message translates to:
  /// **'I am Staff / Admin'**
  String get iAmStaffAdmin;

  /// No description provided for @iAmStaffAdminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your staff credentials to manage gold operations.'**
  String get iAmStaffAdminSubtitle;

  /// No description provided for @secureEnterprisePortal.
  ///
  /// In en, this message translates to:
  /// **'Secure Enterprise Portal'**
  String get secureEnterprisePortal;

  /// No description provided for @staffSignIn.
  ///
  /// In en, this message translates to:
  /// **'Staff Sign In'**
  String get staffSignIn;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @staffSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your staff credentials to access the operations portal.'**
  String get staffSignInSubtitle;

  /// No description provided for @endUserSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with the mobile number you used during signup.'**
  String get endUserSignInSubtitle;

  /// No description provided for @defaultSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your credentials to access your account.'**
  String get defaultSignInSubtitle;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email address is required.'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get emailInvalid;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required.'**
  String get passwordRequired;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPassword;

  /// No description provided for @dontHaveAccountSignUp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get dontHaveAccountSignUp;

  /// No description provided for @backToAccountType.
  ///
  /// In en, this message translates to:
  /// **'Back to account type'**
  String get backToAccountType;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @createAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join AURUM to track gold savings and live bullion prices.'**
  String get createAccountSubtitle;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @accountCreatedSignIn.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully. Please sign in.'**
  String get accountCreatedSignIn;

  /// No description provided for @signUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed. Please check your connection and try again.'**
  String get signUpFailed;

  /// No description provided for @alreadyHaveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccountSignIn;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Profile Settings'**
  String get profileSettings;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @autoSavings.
  ///
  /// In en, this message translates to:
  /// **'Auto Savings'**
  String get autoSavings;

  /// No description provided for @accountDetails.
  ///
  /// In en, this message translates to:
  /// **'Account Details'**
  String get accountDetails;

  /// No description provided for @statements.
  ///
  /// In en, this message translates to:
  /// **'Statements'**
  String get statements;

  /// No description provided for @identityVerification.
  ///
  /// In en, this message translates to:
  /// **'Identity Verification'**
  String get identityVerification;

  /// No description provided for @linkedBankAccount.
  ///
  /// In en, this message translates to:
  /// **'Linked Bank Account'**
  String get linkedBankAccount;

  /// No description provided for @nomineeDetails.
  ///
  /// In en, this message translates to:
  /// **'Nominee Details'**
  String get nomineeDetails;

  /// No description provided for @modifyAutoSavings.
  ///
  /// In en, this message translates to:
  /// **'Modify AutoSavings'**
  String get modifyAutoSavings;

  /// No description provided for @referAndEarn.
  ///
  /// In en, this message translates to:
  /// **'Refer & Earn'**
  String get referAndEarn;

  /// No description provided for @referAndEarnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share a gold savings scheme with friends. When they sign up and choose the same scheme, you earn digital wallet money.'**
  String get referAndEarnSubtitle;

  /// No description provided for @digitalWalletBalance.
  ///
  /// In en, this message translates to:
  /// **'Digital wallet balance'**
  String get digitalWalletBalance;

  /// No description provided for @totalEarned.
  ///
  /// In en, this message translates to:
  /// **'Total earned'**
  String get totalEarned;

  /// No description provided for @successfulReferrals.
  ///
  /// In en, this message translates to:
  /// **'Referrals'**
  String get successfulReferrals;

  /// No description provided for @yourReferralCode.
  ///
  /// In en, this message translates to:
  /// **'Your referral code'**
  String get yourReferralCode;

  /// No description provided for @shareSchemeEarn.
  ///
  /// In en, this message translates to:
  /// **'Share a scheme & earn'**
  String get shareSchemeEarn;

  /// No description provided for @copyInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyInviteLink;

  /// No description provided for @referralCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Referral code copied.'**
  String get referralCodeCopied;

  /// No description provided for @referralLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite link copied.'**
  String get referralLinkCopied;

  /// No description provided for @referralLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load referral details: {error}'**
  String referralLoadFailed(String error);

  /// No description provided for @referralSchemeTitle.
  ///
  /// In en, this message translates to:
  /// **'{grams} g gold scheme'**
  String referralSchemeTitle(int grams);

  /// No description provided for @referralSchemeReward.
  ///
  /// In en, this message translates to:
  /// **'You earn {amount} when they join this scheme'**
  String referralSchemeReward(String amount);

  /// No description provided for @recentReferralRewards.
  ///
  /// In en, this message translates to:
  /// **'Recent rewards'**
  String get recentReferralRewards;

  /// No description provided for @referralRewardDetail.
  ///
  /// In en, this message translates to:
  /// **'{grams} g scheme • {amount} credited'**
  String referralRewardDetail(String grams, String amount);

  /// No description provided for @referralCodeOptional.
  ///
  /// In en, this message translates to:
  /// **'Referral code (optional)'**
  String get referralCodeOptional;

  /// No description provided for @invitedScheme.
  ///
  /// In en, this message translates to:
  /// **'Invited scheme: {grams} g'**
  String invitedScheme(int grams);

  /// No description provided for @applyVoucher.
  ///
  /// In en, this message translates to:
  /// **'Apply Voucher'**
  String get applyVoucher;

  /// No description provided for @securityAndPermission.
  ///
  /// In en, this message translates to:
  /// **'Security & Permission'**
  String get securityAndPermission;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @digiGoldTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'Digi Gold Terms & Conditions'**
  String get digiGoldTermsTitle;

  /// No description provided for @agreeToDigiGoldTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Digi Gold Terms & Conditions'**
  String get agreeToDigiGoldTerms;

  /// No description provided for @mustAcceptDigiGoldTerms.
  ///
  /// In en, this message translates to:
  /// **'You must accept the Terms & Conditions to continue.'**
  String get mustAcceptDigiGoldTerms;

  /// No description provided for @viewTermsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'View Terms & Conditions'**
  String get viewTermsAndConditions;

  /// No description provided for @helpAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpAndSupport;

  /// No description provided for @joinWhatsappChannel.
  ///
  /// In en, this message translates to:
  /// **'Join WhatsApp Channel'**
  String get joinWhatsappChannel;

  /// No description provided for @shareAuraGold.
  ///
  /// In en, this message translates to:
  /// **'Share Aura Gold'**
  String get shareAuraGold;

  /// No description provided for @rateAuraGold.
  ///
  /// In en, this message translates to:
  /// **'Rate Aura Gold'**
  String get rateAuraGold;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared successfully.'**
  String get cacheCleared;

  /// No description provided for @followUsToStayUpdated.
  ///
  /// In en, this message translates to:
  /// **'Follow us, to stay updated'**
  String get followUsToStayUpdated;

  /// No description provided for @memberSince.
  ///
  /// In en, this message translates to:
  /// **'Increasing Aura since, {date}'**
  String memberSince(String date);

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'{feature} is coming soon.'**
  String comingSoon(String feature);

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirmMessage;

  /// No description provided for @logOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOutConfirmTitle;

  /// No description provided for @logOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to end your current session?'**
  String get logOutConfirmMessage;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @notificationPreferences.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get notificationPreferences;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @themeSettings.
  ///
  /// In en, this message translates to:
  /// **'Theme Settings'**
  String get themeSettings;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @emailNotifications.
  ///
  /// In en, this message translates to:
  /// **'Email notifications'**
  String get emailNotifications;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get pushNotifications;

  /// No description provided for @securityAlerts.
  ///
  /// In en, this message translates to:
  /// **'Security alerts'**
  String get securityAlerts;

  /// No description provided for @systemUpdates.
  ///
  /// In en, this message translates to:
  /// **'System updates'**
  String get systemUpdates;

  /// No description provided for @securitySettings.
  ///
  /// In en, this message translates to:
  /// **'Security Settings'**
  String get securitySettings;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @accountStatus.
  ///
  /// In en, this message translates to:
  /// **'Account status'**
  String get accountStatus;

  /// No description provided for @accountStatusHint.
  ///
  /// In en, this message translates to:
  /// **'Contact an administrator to deactivate your account.'**
  String get accountStatusHint;

  /// No description provided for @failedToLoadSettings.
  ///
  /// In en, this message translates to:
  /// **'Failed to load settings: {error}'**
  String failedToLoadSettings(String error);

  /// No description provided for @dashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live bullion rates and your gold savings in one place.'**
  String get dashboardSubtitle;

  /// No description provided for @failedToLoadDashboard.
  ///
  /// In en, this message translates to:
  /// **'Failed to load dashboard: {error}'**
  String failedToLoadDashboard(String error);

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @newSale.
  ///
  /// In en, this message translates to:
  /// **'New Sale'**
  String get newSale;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @workflow.
  ///
  /// In en, this message translates to:
  /// **'Workflow'**
  String get workflow;

  /// No description provided for @liveMetalPrices.
  ///
  /// In en, this message translates to:
  /// **'Live Metal Prices'**
  String get liveMetalPrices;

  /// No description provided for @gold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get gold;

  /// No description provided for @silver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get silver;

  /// No description provided for @perGram.
  ///
  /// In en, this message translates to:
  /// **'/gm'**
  String get perGram;

  /// No description provided for @priceHistory.
  ///
  /// In en, this message translates to:
  /// **'Price History'**
  String get priceHistory;

  /// No description provided for @gold24k.
  ///
  /// In en, this message translates to:
  /// **'24K Gold'**
  String get gold24k;

  /// No description provided for @metalSpotGoldTamilNadu.
  ///
  /// In en, this message translates to:
  /// **'24K Gold · Tamil Nadu'**
  String get metalSpotGoldTamilNadu;

  /// No description provided for @metalSpotSilverTamilNadu.
  ///
  /// In en, this message translates to:
  /// **'Silver · Tamil Nadu'**
  String get metalSpotSilverTamilNadu;

  /// No description provided for @priceHistorySubtitleGold.
  ///
  /// In en, this message translates to:
  /// **'Tamil Nadu · 24K gold'**
  String get priceHistorySubtitleGold;

  /// No description provided for @priceHistorySubtitleSilver.
  ///
  /// In en, this message translates to:
  /// **'Tamil Nadu · silver'**
  String get priceHistorySubtitleSilver;

  /// No description provided for @perGramLabel.
  ///
  /// In en, this message translates to:
  /// **'per gram'**
  String get perGramLabel;

  /// No description provided for @priceUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String priceUpdatedAt(String time);

  /// No description provided for @performanceChangeInRange.
  ///
  /// In en, this message translates to:
  /// **'{arrow} {percent}% in {range}'**
  String performanceChangeInRange(String arrow, String percent, String range);

  /// No description provided for @livePrice.
  ///
  /// In en, this message translates to:
  /// **'Live Price'**
  String get livePrice;

  /// No description provided for @livePriceTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Price'**
  String get livePriceTitle;

  /// No description provided for @setAlert.
  ///
  /// In en, this message translates to:
  /// **'Set Alert'**
  String get setAlert;

  /// No description provided for @performanceInRange.
  ///
  /// In en, this message translates to:
  /// **'Performance in {range}'**
  String performanceInRange(String range);

  /// No description provided for @goldToSilverRatio.
  ///
  /// In en, this message translates to:
  /// **'Gold to Silver Ratio'**
  String get goldToSilverRatio;

  /// No description provided for @silverUndervaluedVsGold.
  ///
  /// In en, this message translates to:
  /// **'Silver may be undervalued vs gold'**
  String get silverUndervaluedVsGold;

  /// No description provided for @goldPremiumModerate.
  ///
  /// In en, this message translates to:
  /// **'Gold premium vs silver is moderate'**
  String get goldPremiumModerate;

  /// No description provided for @yourGoldSavings.
  ///
  /// In en, this message translates to:
  /// **'YOUR GOLD SAVINGS'**
  String get yourGoldSavings;

  /// No description provided for @yourSilverSavings.
  ///
  /// In en, this message translates to:
  /// **'YOUR SILVER SAVINGS'**
  String get yourSilverSavings;

  /// No description provided for @tapMetalIconForChart.
  ///
  /// In en, this message translates to:
  /// **'Tap the gold or silver icon to view live price chart'**
  String get tapMetalIconForChart;

  /// No description provided for @backToAurum.
  ///
  /// In en, this message translates to:
  /// **'Back to AURUM'**
  String get backToAurum;

  /// No description provided for @failedToLoadLivePrice.
  ///
  /// In en, this message translates to:
  /// **'Failed to load live price: {error}'**
  String failedToLoadLivePrice(String error);

  /// No description provided for @failedToLoadChart.
  ///
  /// In en, this message translates to:
  /// **'Failed to load chart: {error}'**
  String failedToLoadChart(String error);

  /// No description provided for @kycVerification.
  ///
  /// In en, this message translates to:
  /// **'Complete KYC'**
  String get kycVerification;

  /// No description provided for @verifyForGoldTrading.
  ///
  /// In en, this message translates to:
  /// **'Verify for gold trading'**
  String get verifyForGoldTrading;

  /// No description provided for @howPanVerificationWorks.
  ///
  /// In en, this message translates to:
  /// **'How PAN verification works'**
  String get howPanVerificationWorks;

  /// No description provided for @panVerificationFlowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your details are checked against official government PAN records – you never leave this app.'**
  String get panVerificationFlowSubtitle;

  /// No description provided for @panFlowYourDetails.
  ///
  /// In en, this message translates to:
  /// **'Your details'**
  String get panFlowYourDetails;

  /// No description provided for @panFlowYourDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Name, PAN, DOB'**
  String get panFlowYourDetailsSubtitle;

  /// No description provided for @panFlowSecureTransfer.
  ///
  /// In en, this message translates to:
  /// **'Secure transfer'**
  String get panFlowSecureTransfer;

  /// No description provided for @panFlowSecureKycApi.
  ///
  /// In en, this message translates to:
  /// **'Secure KYC API'**
  String get panFlowSecureKycApi;

  /// No description provided for @panFlowLicensedProvider.
  ///
  /// In en, this message translates to:
  /// **'Licensed provider'**
  String get panFlowLicensedProvider;

  /// No description provided for @kycStepConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get kycStepConfirm;

  /// No description provided for @kycStep1VerifyAadhaar.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Verify Aadhaar'**
  String get kycStep1VerifyAadhaar;

  /// No description provided for @kycAadhaarOtpInstruction.
  ///
  /// In en, this message translates to:
  /// **'Enter your 12-digit Aadhaar number. An OTP will be sent to the mobile linked with your Aadhaar — it must match the mobile number you registered with.'**
  String get kycAadhaarOtpInstruction;

  /// No description provided for @kycRegisteredMobileHint.
  ///
  /// In en, this message translates to:
  /// **'Registered mobile: {mobile}'**
  String kycRegisteredMobileHint(String mobile);

  /// No description provided for @aadhaarMobileVerifiedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Aadhaar verified. The mobile below is linked with your Aadhaar. Continue with PAN linking.'**
  String get aadhaarMobileVerifiedSubtitle;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get mobileNumber;

  /// No description provided for @kycMobileMismatchError.
  ///
  /// In en, this message translates to:
  /// **'The mobile linked with this Aadhaar does not match your registered number. Use the same mobile you signed up with.'**
  String get kycMobileMismatchError;

  /// No description provided for @useDigilockerInstead.
  ///
  /// In en, this message translates to:
  /// **'Use DigiLocker verification instead'**
  String get useDigilockerInstead;

  /// No description provided for @useManualPanInstead.
  ///
  /// In en, this message translates to:
  /// **'Use manual PAN verification instead'**
  String get useManualPanInstead;

  /// No description provided for @kycStage1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Stage 1: Verify your Aadhaar with a UIDAI OTP.'**
  String get kycStage1Subtitle;

  /// No description provided for @kycStage2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Stage 2: Link your PAN with your verified Aadhaar.'**
  String get kycStage2Subtitle;

  /// No description provided for @aadhaarOtpStep.
  ///
  /// In en, this message translates to:
  /// **'Aadhaar OTP'**
  String get aadhaarOtpStep;

  /// No description provided for @panLinkStep.
  ///
  /// In en, this message translates to:
  /// **'PAN link'**
  String get panLinkStep;

  /// No description provided for @aadhaarNumber.
  ///
  /// In en, this message translates to:
  /// **'Aadhaar number'**
  String get aadhaarNumber;

  /// No description provided for @aadhaarHint.
  ///
  /// In en, this message translates to:
  /// **'12-digit Aadhaar number'**
  String get aadhaarHint;

  /// No description provided for @aadhaarInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 12-digit Aadhaar number'**
  String get aadhaarInvalid;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOtp;

  /// No description provided for @sendingOtp.
  ///
  /// In en, this message translates to:
  /// **'Sending OTP...'**
  String get sendingOtp;

  /// No description provided for @otpSentToMobile.
  ///
  /// In en, this message translates to:
  /// **'OTP sent to the mobile linked with Aadhaar{ending}.'**
  String otpSentToMobile(String ending);

  /// No description provided for @otpSentEnding.
  ///
  /// In en, this message translates to:
  /// **' ending {last4}'**
  String otpSentEnding(String last4);

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtp;

  /// No description provided for @otpHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit OTP'**
  String get otpHint;

  /// No description provided for @otpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit OTP'**
  String get otpInvalid;

  /// No description provided for @changeAadhaarNumber.
  ///
  /// In en, this message translates to:
  /// **'Change Aadhaar number'**
  String get changeAadhaarNumber;

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get resendOtp;

  /// No description provided for @verifyAadhaar.
  ///
  /// In en, this message translates to:
  /// **'Verify Aadhaar'**
  String get verifyAadhaar;

  /// No description provided for @verifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get verifying;

  /// No description provided for @panNumber.
  ///
  /// In en, this message translates to:
  /// **'PAN number'**
  String get panNumber;

  /// No description provided for @panHint.
  ///
  /// In en, this message translates to:
  /// **'ABCDE1234F'**
  String get panHint;

  /// No description provided for @panHelper.
  ///
  /// In en, this message translates to:
  /// **'We verify that your PAN is linked with your Aadhaar on the Income Tax portal.'**
  String get panHelper;

  /// No description provided for @panInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid PAN (e.g. ABCDE1234F)'**
  String get panInvalid;

  /// No description provided for @backToAadhaarVerification.
  ///
  /// In en, this message translates to:
  /// **'Back to Aadhaar verification'**
  String get backToAadhaarVerification;

  /// No description provided for @verifyPanLink.
  ///
  /// In en, this message translates to:
  /// **'Verify PAN link'**
  String get verifyPanLink;

  /// No description provided for @aadhaarVerified.
  ///
  /// In en, this message translates to:
  /// **'Aadhaar verified'**
  String get aadhaarVerified;

  /// No description provided for @aadhaarVerifiedLast4.
  ///
  /// In en, this message translates to:
  /// **'Aadhaar verified (****{last4})'**
  String aadhaarVerifiedLast4(String last4);

  /// No description provided for @backToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Back to dashboard'**
  String get backToDashboard;

  /// No description provided for @otpSentSnack.
  ///
  /// In en, this message translates to:
  /// **'OTP sent to your Aadhaar-linked mobile number.'**
  String get otpSentSnack;

  /// No description provided for @aadhaarVerifiedSnack.
  ///
  /// In en, this message translates to:
  /// **'Aadhaar verified successfully.'**
  String get aadhaarVerifiedSnack;

  /// No description provided for @aadhaarVerifiedContinuePan.
  ///
  /// In en, this message translates to:
  /// **'Aadhaar verified. Enter your PAN number below to continue.'**
  String get aadhaarVerifiedContinuePan;

  /// No description provided for @kycCompleteSnack.
  ///
  /// In en, this message translates to:
  /// **'KYC complete. Gold trading is now unlocked.'**
  String get kycCompleteSnack;

  /// No description provided for @unableToSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Unable to send OTP. Please try again.'**
  String get unableToSendOtp;

  /// No description provided for @otpVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'OTP verification failed. Please try again.'**
  String get otpVerificationFailed;

  /// No description provided for @panVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'PAN verification failed. Please try again.'**
  String get panVerificationFailed;

  /// No description provided for @kycBannerCompletePanTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete PAN linking'**
  String get kycBannerCompletePanTitle;

  /// No description provided for @kycBannerCompletePanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your Aadhaar is verified. Enter your PAN to confirm it is linked with Aadhaar and unlock gold trading.'**
  String get kycBannerCompletePanSubtitle;

  /// No description provided for @kycBannerContinuePan.
  ///
  /// In en, this message translates to:
  /// **'Continue with PAN'**
  String get kycBannerContinuePan;

  /// No description provided for @kycBannerPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'KYC verification in progress'**
  String get kycBannerPendingTitle;

  /// No description provided for @kycBannerPendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We are reviewing your documents. Gold trading unlocks after approval.'**
  String get kycBannerPendingSubtitle;

  /// No description provided for @kycBannerViewStatus.
  ///
  /// In en, this message translates to:
  /// **'View status'**
  String get kycBannerViewStatus;

  /// No description provided for @kycBannerRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'KYC verification needs attention'**
  String get kycBannerRejectedTitle;

  /// No description provided for @kycBannerRejectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'PAN could not be linked with your Aadhaar. Link them on the Income Tax portal and try again.'**
  String get kycBannerRejectedSubtitle;

  /// No description provided for @kycBannerRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart KYC'**
  String get kycBannerRestart;

  /// No description provided for @kycBannerStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete KYC verification for gold trading'**
  String get kycBannerStartTitle;

  /// No description provided for @kycBannerStartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your Aadhaar with OTP, then confirm your PAN is linked to unlock bullion trading on AURUM.'**
  String get kycBannerStartSubtitle;

  /// No description provided for @kycBannerStartAction.
  ///
  /// In en, this message translates to:
  /// **'Start KYC verification'**
  String get kycBannerStartAction;

  /// No description provided for @kycStepAadhaar.
  ///
  /// In en, this message translates to:
  /// **'Aadhaar verification (UIDAI OTP)'**
  String get kycStepAadhaar;

  /// No description provided for @kycStepPan.
  ///
  /// In en, this message translates to:
  /// **'PAN–Aadhaar link (Sandbox)'**
  String get kycStepPan;

  /// No description provided for @kycStepTrading.
  ///
  /// In en, this message translates to:
  /// **'Gold trading access'**
  String get kycStepTrading;

  /// No description provided for @goldTrading.
  ///
  /// In en, this message translates to:
  /// **'Gold Trading'**
  String get goldTrading;

  /// No description provided for @buyGold.
  ///
  /// In en, this message translates to:
  /// **'Buy Gold'**
  String get buyGold;

  /// No description provided for @sellGold.
  ///
  /// In en, this message translates to:
  /// **'Sell Gold'**
  String get sellGold;

  /// No description provided for @buySilver.
  ///
  /// In en, this message translates to:
  /// **'Buy Silver'**
  String get buySilver;

  /// No description provided for @sellSilver.
  ///
  /// In en, this message translates to:
  /// **'Sell Silver'**
  String get sellSilver;

  /// No description provided for @buyGoldSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase 24K digital gold at live rates'**
  String get buyGoldSubtitle;

  /// No description provided for @sellGoldSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sell your gold holdings instantly'**
  String get sellGoldSubtitle;

  /// No description provided for @buySilverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase digital silver at live rates'**
  String get buySilverSubtitle;

  /// No description provided for @sellSilverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sell your silver holdings instantly'**
  String get sellSilverSubtitle;

  /// No description provided for @kycRequiredForTrading.
  ///
  /// In en, this message translates to:
  /// **'Complete KYC verification to buy or sell gold and silver.'**
  String get kycRequiredForTrading;

  /// No description provided for @kycVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'KYC verified'**
  String get kycVerifiedTitle;

  /// No description provided for @kycVerifiedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can buy and sell gold and silver on AURUM.'**
  String get kycVerifiedSubtitle;

  /// No description provided for @kycVerifiedDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can buy and sell gold securely.'**
  String get kycVerifiedDashboardSubtitle;

  /// No description provided for @kycVerifiedHeading.
  ///
  /// In en, this message translates to:
  /// **'KYC Verified'**
  String get kycVerifiedHeading;

  /// No description provided for @verifiedViaSandbox.
  ///
  /// In en, this message translates to:
  /// **'Verified via Sandbox Secure KYC'**
  String get verifiedViaSandbox;

  /// No description provided for @panVerificationLabel.
  ///
  /// In en, this message translates to:
  /// **'PAN verification'**
  String get panVerificationLabel;

  /// No description provided for @registeredName.
  ///
  /// In en, this message translates to:
  /// **'Registered name'**
  String get registeredName;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get dateOfBirth;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// No description provided for @pincode.
  ///
  /// In en, this message translates to:
  /// **'Pincode'**
  String get pincode;

  /// No description provided for @mobileLinkedAadhaar.
  ///
  /// In en, this message translates to:
  /// **'Mobile linked with Aadhaar'**
  String get mobileLinkedAadhaar;

  /// No description provided for @aadhaarDetailsFromGov.
  ///
  /// In en, this message translates to:
  /// **'These details were fetched from UIDAI government records.'**
  String get aadhaarDetailsFromGov;

  /// No description provided for @accountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSection;

  /// No description provided for @manageYourProfile.
  ///
  /// In en, this message translates to:
  /// **'View and update your profile'**
  String get manageYourProfile;

  /// No description provided for @identityVerified.
  ///
  /// In en, this message translates to:
  /// **'Identity verified'**
  String get identityVerified;

  /// No description provided for @bankAccounts.
  ///
  /// In en, this message translates to:
  /// **'Bank accounts'**
  String get bankAccounts;

  /// No description provided for @manageBankAccounts.
  ///
  /// In en, this message translates to:
  /// **'Manage linked bank accounts'**
  String get manageBankAccounts;

  /// No description provided for @bankAccountsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Bank account linking is coming soon.'**
  String get bankAccountsComingSoon;

  /// No description provided for @kycPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'KYC required for trading'**
  String get kycPromptTitle;

  /// No description provided for @kycPromptMessage.
  ///
  /// In en, this message translates to:
  /// **'To {action}, complete identity verification first. It only takes a few minutes.'**
  String kycPromptMessage(String action);

  /// No description provided for @startTrading.
  ///
  /// In en, this message translates to:
  /// **'Start trading'**
  String get startTrading;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllRead;

  /// No description provided for @failedToLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile: {error}'**
  String failedToLoadProfile(String error);

  /// No description provided for @sellGoldInquiryTitle.
  ///
  /// In en, this message translates to:
  /// **'Sell Gold Inquiry'**
  String get sellGoldInquiryTitle;

  /// No description provided for @sellGoldInquirySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about the gold you want to sell. Our team will review your request and contact you with next steps.'**
  String get sellGoldInquirySubtitle;

  /// No description provided for @sellGoldInquirySubtitleShort.
  ///
  /// In en, this message translates to:
  /// **'Submit a sell request to our team'**
  String get sellGoldInquirySubtitleShort;

  /// No description provided for @sellGoldInquiryName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get sellGoldInquiryName;

  /// No description provided for @sellGoldInquiryMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get sellGoldInquiryMobile;

  /// No description provided for @sellGoldInquiryMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get sellGoldInquiryMessage;

  /// No description provided for @sellGoldInquiryNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get sellGoldInquiryNameRequired;

  /// No description provided for @sellGoldInquiryMobileRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number'**
  String get sellGoldInquiryMobileRequired;

  /// No description provided for @sellGoldInquiryMessageRequired.
  ///
  /// In en, this message translates to:
  /// **'Please describe what you want to sell (min 10 characters)'**
  String get sellGoldInquiryMessageRequired;

  /// No description provided for @sellGoldInquirySubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit inquiry'**
  String get sellGoldInquirySubmit;

  /// No description provided for @sellGoldInquirySubmitted.
  ///
  /// In en, this message translates to:
  /// **'Your sell request was submitted. We will contact you soon.'**
  String get sellGoldInquirySubmitted;

  /// No description provided for @sellGoldInquirySubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not submit your request. Please try again.'**
  String get sellGoldInquirySubmitFailed;

  /// No description provided for @navSellInquiries.
  ///
  /// In en, this message translates to:
  /// **'Sell Inquiries'**
  String get navSellInquiries;

  /// No description provided for @goldInvestedAmount.
  ///
  /// In en, this message translates to:
  /// **'Invested: {amount}'**
  String goldInvestedAmount(String amount);

  /// No description provided for @goldCurrentValue.
  ///
  /// In en, this message translates to:
  /// **'Current value: {amount}'**
  String goldCurrentValue(String amount);

  /// No description provided for @goldGramsOwned.
  ///
  /// In en, this message translates to:
  /// **'{grams} g owned'**
  String goldGramsOwned(String grams);

  /// No description provided for @goldLiveAtMarketRate.
  ///
  /// In en, this message translates to:
  /// **'At live 24K market rate'**
  String get goldLiveAtMarketRate;

  /// No description provided for @navPaymentSettlements.
  ///
  /// In en, this message translates to:
  /// **'Payment Settlements'**
  String get navPaymentSettlements;

  /// No description provided for @navUserWallets.
  ///
  /// In en, this message translates to:
  /// **'User Wallets'**
  String get navUserWallets;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
