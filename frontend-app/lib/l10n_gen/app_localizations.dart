import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n_gen/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ar'),
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'灵策AI'**
  String get appTitle;

  /// No description provided for @navAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get navAgent;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navAlpha.
  ///
  /// In en, this message translates to:
  /// **'Alpha'**
  String get navAlpha;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @agentTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agentTitle;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @alphaTitle.
  ///
  /// In en, this message translates to:
  /// **'Alpha Zoo'**
  String get alphaTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @moreTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTitle;

  /// No description provided for @runDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Run Detail'**
  String get runDetailTitle;

  /// No description provided for @compareTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get compareTitle;

  /// No description provided for @correlationTitle.
  ///
  /// In en, this message translates to:
  /// **'Correlation'**
  String get correlationTitle;

  /// No description provided for @runtimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Runtime'**
  String get runtimeTitle;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get commonTest;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @commonDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @agentWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for SSE events (heartbeat every ~15s)…'**
  String get agentWaiting;

  /// No description provided for @agentSetBackend.
  ///
  /// In en, this message translates to:
  /// **'Set the backend URL in Settings first.'**
  String get agentSetBackend;

  /// No description provided for @agentThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get agentThinking;

  /// No description provided for @agentThoughtProcess.
  ///
  /// In en, this message translates to:
  /// **'Thought process'**
  String get agentThoughtProcess;

  /// No description provided for @composerHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get composerHint;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'What would you like to research?'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Natural-language finance research, backtests, factors, and live execution.'**
  String get welcomeSubtitle;

  /// No description provided for @settingsBackend.
  ///
  /// In en, this message translates to:
  /// **'Backend connection'**
  String get settingsBackend;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsSystem;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Connection saved.'**
  String get settingsSaved;

  /// No description provided for @settingsBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get settingsBaseUrl;

  /// No description provided for @settingsApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key (optional on loopback)'**
  String get settingsApiKey;

  /// No description provided for @settingsLLM.
  ///
  /// In en, this message translates to:
  /// **'LLM'**
  String get settingsLLM;

  /// No description provided for @settingsDataSource.
  ///
  /// In en, this message translates to:
  /// **'Data source'**
  String get settingsDataSource;

  /// No description provided for @settingsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear stored credentials'**
  String get settingsClear;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language switched.'**
  String get settingsLanguageChanged;

  /// No description provided for @provider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get provider;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @temp.
  ///
  /// In en, this message translates to:
  /// **'Temp'**
  String get temp;

  /// No description provided for @timeoutSec.
  ///
  /// In en, this message translates to:
  /// **'Timeout (s)'**
  String get timeoutSec;

  /// No description provided for @retries.
  ///
  /// In en, this message translates to:
  /// **'Retries'**
  String get retries;

  /// No description provided for @tushareToken.
  ///
  /// In en, this message translates to:
  /// **'Tushare token'**
  String get tushareToken;

  /// No description provided for @reasoningLabel.
  ///
  /// In en, this message translates to:
  /// **'reasoning: {effort}'**
  String reasoningLabel(String effort);

  /// No description provided for @reasoningProviderDefault.
  ///
  /// In en, this message translates to:
  /// **'Provider default'**
  String get reasoningProviderDefault;

  /// No description provided for @composerUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload document'**
  String get composerUpload;

  /// No description provided for @composerGoal.
  ///
  /// In en, this message translates to:
  /// **'Research goal'**
  String get composerGoal;

  /// No description provided for @composerSwarm.
  ///
  /// In en, this message translates to:
  /// **'Agent swarm'**
  String get composerSwarm;

  /// No description provided for @composerConnector.
  ///
  /// In en, this message translates to:
  /// **'Check connector'**
  String get composerConnector;

  /// No description provided for @composerPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Analyze portfolio'**
  String get composerPortfolio;

  /// No description provided for @promptDefineGoal.
  ///
  /// In en, this message translates to:
  /// **'Help me define a research goal.'**
  String get promptDefineGoal;

  /// No description provided for @promptContinueGoal.
  ///
  /// In en, this message translates to:
  /// **'Continue the active research goal.'**
  String get promptContinueGoal;

  /// No description provided for @promptSwarmTeam.
  ///
  /// In en, this message translates to:
  /// **'[Swarm Team Mode] Use the swarm tool to assemble the best specialist team. Auto-select the most appropriate preset.'**
  String get promptSwarmTeam;

  /// No description provided for @promptCheckConnector.
  ///
  /// In en, this message translates to:
  /// **'Check my broker connector status and report authorization, mandate, and runner state for each broker.'**
  String get promptCheckConnector;

  /// No description provided for @liveActive.
  ///
  /// In en, this message translates to:
  /// **'Live runtime active'**
  String get liveActive;

  /// No description provided for @halt.
  ///
  /// In en, this message translates to:
  /// **'HALT'**
  String get halt;

  /// No description provided for @sessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessions;

  /// No description provided for @newSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get newSession;

  /// No description provided for @noSessions.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get noSessions;

  /// No description provided for @exportChat.
  ///
  /// In en, this message translates to:
  /// **'Export chat'**
  String get exportChat;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @connLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get connLost;

  /// No description provided for @connRestored.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get connRestored;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploading;

  /// No description provided for @timedOut.
  ///
  /// In en, this message translates to:
  /// **'Execution timed out'**
  String get timedOut;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String connectionFailed(String error);

  /// No description provided for @failedToLoadRun.
  ///
  /// In en, this message translates to:
  /// **'Failed to load run: {error}'**
  String failedToLoadRun(String error);

  /// No description provided for @tabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tabOverview;

  /// No description provided for @tabChart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get tabChart;

  /// No description provided for @tabTrades.
  ///
  /// In en, this message translates to:
  /// **'Trades'**
  String get tabTrades;

  /// No description provided for @tabRunCard.
  ///
  /// In en, this message translates to:
  /// **'Run Card'**
  String get tabRunCard;

  /// No description provided for @tabCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get tabCode;

  /// No description provided for @tabValidation.
  ///
  /// In en, this message translates to:
  /// **'Validation'**
  String get tabValidation;

  /// No description provided for @metricTotalReturn.
  ///
  /// In en, this message translates to:
  /// **'Total return'**
  String get metricTotalReturn;

  /// No description provided for @metricAnnual.
  ///
  /// In en, this message translates to:
  /// **'Annual'**
  String get metricAnnual;

  /// No description provided for @metricMaxDD.
  ///
  /// In en, this message translates to:
  /// **'MaxDD'**
  String get metricMaxDD;

  /// No description provided for @metricSharpe.
  ///
  /// In en, this message translates to:
  /// **'Sharpe'**
  String get metricSharpe;

  /// No description provided for @metricWinRate.
  ///
  /// In en, this message translates to:
  /// **'Win rate'**
  String get metricWinRate;

  /// No description provided for @metricTrades.
  ///
  /// In en, this message translates to:
  /// **'Trades'**
  String get metricTrades;

  /// No description provided for @metricCalmar.
  ///
  /// In en, this message translates to:
  /// **'Calmar'**
  String get metricCalmar;

  /// No description provided for @metricSortino.
  ///
  /// In en, this message translates to:
  /// **'Sortino'**
  String get metricSortino;

  /// No description provided for @metricVolatility.
  ///
  /// In en, this message translates to:
  /// **'Volatility'**
  String get metricVolatility;

  /// No description provided for @metricProfitFactor.
  ///
  /// In en, this message translates to:
  /// **'Profit factor'**
  String get metricProfitFactor;

  /// No description provided for @metricAvgWin.
  ///
  /// In en, this message translates to:
  /// **'Avg win'**
  String get metricAvgWin;

  /// No description provided for @metricAvgLoss.
  ///
  /// In en, this message translates to:
  /// **'Avg loss'**
  String get metricAvgLoss;

  /// No description provided for @metricMaxConsecLosses.
  ///
  /// In en, this message translates to:
  /// **'Max consecutive losses'**
  String get metricMaxConsecLosses;

  /// No description provided for @metricExposureTime.
  ///
  /// In en, this message translates to:
  /// **'Exposure time'**
  String get metricExposureTime;

  /// No description provided for @metricAvgHolding.
  ///
  /// In en, this message translates to:
  /// **'Avg holding period'**
  String get metricAvgHolding;

  /// No description provided for @noPriceData.
  ///
  /// In en, this message translates to:
  /// **'No price data'**
  String get noPriceData;

  /// No description provided for @noChartSymbol.
  ///
  /// In en, this message translates to:
  /// **'No chart for this symbol'**
  String get noChartSymbol;

  /// No description provided for @noEquityData.
  ///
  /// In en, this message translates to:
  /// **'No equity data'**
  String get noEquityData;

  /// No description provided for @noTrades.
  ///
  /// In en, this message translates to:
  /// **'No trades'**
  String get noTrades;

  /// No description provided for @noRunCard.
  ///
  /// In en, this message translates to:
  /// **'No run card'**
  String get noRunCard;

  /// No description provided for @noSourceCode.
  ///
  /// In en, this message translates to:
  /// **'No source code'**
  String get noSourceCode;

  /// No description provided for @noValidation.
  ///
  /// In en, this message translates to:
  /// **'No validation data'**
  String get noValidation;

  /// No description provided for @noValidationForRun.
  ///
  /// In en, this message translates to:
  /// **'No validation data for this run.'**
  String get noValidationForRun;

  /// No description provided for @maxDrawdown.
  ///
  /// In en, this message translates to:
  /// **'Max drawdown'**
  String get maxDrawdown;

  /// No description provided for @backtestComplete.
  ///
  /// In en, this message translates to:
  /// **'Backtest complete'**
  String get backtestComplete;

  /// No description provided for @rawJson.
  ///
  /// In en, this message translates to:
  /// **'Raw'**
  String get rawJson;

  /// No description provided for @warnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get warnings;

  /// No description provided for @dataSources.
  ///
  /// In en, this message translates to:
  /// **'Data sources'**
  String get dataSources;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @pine.
  ///
  /// In en, this message translates to:
  /// **'Pine'**
  String get pine;

  /// No description provided for @exportTradesCsv.
  ///
  /// In en, this message translates to:
  /// **'Export trades CSV'**
  String get exportTradesCsv;

  /// No description provided for @exportMetricsCsv.
  ///
  /// In en, this message translates to:
  /// **'Export metrics CSV'**
  String get exportMetricsCsv;

  /// No description provided for @nOfM.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total}'**
  String nOfM(String shown, String total);

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @searchRun.
  ///
  /// In en, this message translates to:
  /// **'Search run id / prompt'**
  String get searchRun;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get sortOldest;

  /// No description provided for @sortReturnDesc.
  ///
  /// In en, this message translates to:
  /// **'Return ↓'**
  String get sortReturnDesc;

  /// No description provided for @sortSharpeDesc.
  ///
  /// In en, this message translates to:
  /// **'Sharpe ↓'**
  String get sortSharpeDesc;

  /// No description provided for @noReports.
  ///
  /// In en, this message translates to:
  /// **'No reports'**
  String get noReports;

  /// No description provided for @globalHalt.
  ///
  /// In en, this message translates to:
  /// **'Global halt'**
  String get globalHalt;

  /// No description provided for @brokers.
  ///
  /// In en, this message translates to:
  /// **'Brokers'**
  String get brokers;

  /// No description provided for @authorized.
  ///
  /// In en, this message translates to:
  /// **'Authorized'**
  String get authorized;

  /// No description provided for @runners.
  ///
  /// In en, this message translates to:
  /// **'Runners'**
  String get runners;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @noLiveBrokers.
  ///
  /// In en, this message translates to:
  /// **'No live brokers configured'**
  String get noLiveBrokers;

  /// No description provided for @pillAuthorized.
  ///
  /// In en, this message translates to:
  /// **'authorized'**
  String get pillAuthorized;

  /// No description provided for @pillNoAuth.
  ///
  /// In en, this message translates to:
  /// **'no auth'**
  String get pillNoAuth;

  /// No description provided for @pillRunner.
  ///
  /// In en, this message translates to:
  /// **'runner'**
  String get pillRunner;

  /// No description provided for @pillStopped.
  ///
  /// In en, this message translates to:
  /// **'stopped'**
  String get pillStopped;

  /// No description provided for @pillHalted.
  ///
  /// In en, this message translates to:
  /// **'halted'**
  String get pillHalted;

  /// No description provided for @pillMandate.
  ///
  /// In en, this message translates to:
  /// **'mandate'**
  String get pillMandate;

  /// No description provided for @searchIdNickname.
  ///
  /// In en, this message translates to:
  /// **'Search id / nickname'**
  String get searchIdNickname;

  /// No description provided for @runBenchmark.
  ///
  /// In en, this message translates to:
  /// **'Run benchmark'**
  String get runBenchmark;

  /// No description provided for @compareAlphas.
  ///
  /// In en, this message translates to:
  /// **'Compare alphas'**
  String get compareAlphas;

  /// No description provided for @topByIr.
  ///
  /// In en, this message translates to:
  /// **'Top by IR'**
  String get topByIr;

  /// No description provided for @alive.
  ///
  /// In en, this message translates to:
  /// **'Alive'**
  String get alive;

  /// No description provided for @reversed.
  ///
  /// In en, this message translates to:
  /// **'Reversed'**
  String get reversed;

  /// No description provided for @dead.
  ///
  /// In en, this message translates to:
  /// **'Dead'**
  String get dead;

  /// No description provided for @skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get skipped;

  /// No description provided for @detail.
  ///
  /// In en, this message translates to:
  /// **'Detail'**
  String get detail;

  /// No description provided for @idsHint.
  ///
  /// In en, this message translates to:
  /// **'alpha ids (comma/space)'**
  String get idsHint;

  /// No description provided for @benchZoo.
  ///
  /// In en, this message translates to:
  /// **'zoo'**
  String get benchZoo;

  /// No description provided for @benchUniverse.
  ///
  /// In en, this message translates to:
  /// **'universe'**
  String get benchUniverse;

  /// No description provided for @benchPeriod.
  ///
  /// In en, this message translates to:
  /// **'period'**
  String get benchPeriod;

  /// No description provided for @benchTop.
  ///
  /// In en, this message translates to:
  /// **'top'**
  String get benchTop;

  /// No description provided for @rankByIr.
  ///
  /// In en, this message translates to:
  /// **'rank by IR'**
  String get rankByIr;

  /// No description provided for @rankByIcMean.
  ///
  /// In en, this message translates to:
  /// **'rank by IC mean'**
  String get rankByIcMean;

  /// No description provided for @rankByIcPos.
  ///
  /// In en, this message translates to:
  /// **'rank by IC positive %'**
  String get rankByIcPos;

  /// No description provided for @selectRun.
  ///
  /// In en, this message translates to:
  /// **'Select run'**
  String get selectRun;

  /// No description provided for @winner.
  ///
  /// In en, this message translates to:
  /// **'Winner'**
  String get winner;

  /// No description provided for @codesHint.
  ///
  /// In en, this message translates to:
  /// **'codes (comma-separated)'**
  String get codesHint;

  /// No description provided for @compute.
  ///
  /// In en, this message translates to:
  /// **'Compute'**
  String get compute;

  /// No description provided for @matrix.
  ///
  /// In en, this message translates to:
  /// **'Matrix'**
  String get matrix;

  /// No description provided for @regimeTimeline.
  ///
  /// In en, this message translates to:
  /// **'Regime timeline'**
  String get regimeTimeline;

  /// No description provided for @windowDays.
  ///
  /// In en, this message translates to:
  /// **'{n}d'**
  String windowDays(String n);

  /// No description provided for @methodPearson.
  ///
  /// In en, this message translates to:
  /// **'Pearson'**
  String get methodPearson;

  /// No description provided for @methodSpearman.
  ///
  /// In en, this message translates to:
  /// **'Spearman'**
  String get methodSpearman;

  /// No description provided for @toggleRegime.
  ///
  /// In en, this message translates to:
  /// **'Regime'**
  String get toggleRegime;

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goal;

  /// No description provided for @goalCriteria.
  ///
  /// In en, this message translates to:
  /// **'Criteria'**
  String get goalCriteria;

  /// No description provided for @goalEvidence.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get goalEvidence;

  /// No description provided for @goalContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get goalContinue;

  /// No description provided for @goalEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get goalEdit;

  /// No description provided for @goalCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel goal'**
  String get goalCancel;

  /// No description provided for @editGoalObjective.
  ///
  /// In en, this message translates to:
  /// **'Edit goal objective'**
  String get editGoalObjective;

  /// No description provided for @mandateProposal.
  ///
  /// In en, this message translates to:
  /// **'Mandate proposal'**
  String get mandateProposal;

  /// No description provided for @mandateNote.
  ///
  /// In en, this message translates to:
  /// **'Review and confirm the trading mandate. This authorizes the broker to trade within the chosen limits.'**
  String get mandateNote;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @chooseProfile.
  ///
  /// In en, this message translates to:
  /// **'Choose a profile'**
  String get chooseProfile;

  /// No description provided for @confirmBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Confirm with biometrics'**
  String get confirmBiometrics;

  /// No description provided for @noProfiles.
  ///
  /// In en, this message translates to:
  /// **'No profiles in proposal'**
  String get noProfiles;

  /// No description provided for @doubleConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm mandate'**
  String get doubleConfirmTitle;

  /// No description provided for @doubleConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'No biometrics available. Submit this mandate profile?'**
  String get doubleConfirmBody;

  /// No description provided for @mandateCommitFailed.
  ///
  /// In en, this message translates to:
  /// **'Mandate commit failed — please retry.'**
  String get mandateCommitFailed;

  /// No description provided for @swarmAgents.
  ///
  /// In en, this message translates to:
  /// **'agents'**
  String get swarmAgents;

  /// No description provided for @swarmWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for events…'**
  String get swarmWaiting;

  /// No description provided for @swarmLayer.
  ///
  /// In en, this message translates to:
  /// **'Layer'**
  String get swarmLayer;

  /// No description provided for @pineTitle.
  ///
  /// In en, this message translates to:
  /// **'Pine Script'**
  String get pineTitle;

  /// No description provided for @pineDocs.
  ///
  /// In en, this message translates to:
  /// **'Pine docs'**
  String get pineDocs;

  /// No description provided for @pineHint.
  ///
  /// In en, this message translates to:
  /// **'TradingView → Pine Editor → New blank indicator → Paste → Add to Chart'**
  String get pineHint;

  /// No description provided for @runtimeLabel.
  ///
  /// In en, this message translates to:
  /// **'RUNTIME'**
  String get runtimeLabel;

  /// No description provided for @rtOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get rtOk;

  /// No description provided for @rtUnknown.
  ///
  /// In en, this message translates to:
  /// **'(unknown)'**
  String get rtUnknown;

  /// No description provided for @rtActiveMandate.
  ///
  /// In en, this message translates to:
  /// **'Active mandate'**
  String get rtActiveMandate;

  /// No description provided for @rtNoMandate.
  ///
  /// In en, this message translates to:
  /// **'No active mandate'**
  String get rtNoMandate;

  /// No description provided for @rtExpired.
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get rtExpired;

  /// No description provided for @rtPresent.
  ///
  /// In en, this message translates to:
  /// **'present'**
  String get rtPresent;

  /// No description provided for @rtMissing.
  ///
  /// In en, this message translates to:
  /// **'missing'**
  String get rtMissing;

  /// No description provided for @rtOauthToken.
  ///
  /// In en, this message translates to:
  /// **'OAuth token'**
  String get rtOauthToken;

  /// No description provided for @rtTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get rtTransport;

  /// No description provided for @rtConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get rtConnection;

  /// No description provided for @rtError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get rtError;

  /// No description provided for @rtLastTick.
  ///
  /// In en, this message translates to:
  /// **'Last tick'**
  String get rtLastTick;

  /// No description provided for @rtAgo.
  ///
  /// In en, this message translates to:
  /// **'{s}s ago'**
  String rtAgo(String s);

  /// No description provided for @rtSdkNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'SDK profile not configured'**
  String get rtSdkNotConfigured;

  /// No description provided for @rtStartRunner.
  ///
  /// In en, this message translates to:
  /// **'Start runner'**
  String get rtStartRunner;

  /// No description provided for @rtStopRunner.
  ///
  /// In en, this message translates to:
  /// **'Stop runner'**
  String get rtStopRunner;

  /// No description provided for @rtResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get rtResume;

  /// No description provided for @rtAuthorizeBtn.
  ///
  /// In en, this message translates to:
  /// **'Authorize'**
  String get rtAuthorizeBtn;

  /// No description provided for @rtAuthorizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Authorize {broker}'**
  String rtAuthorizeTitle(String broker);
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
      <String>['ar', 'en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
