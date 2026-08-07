// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AI Trading';

  @override
  String get navAgent => 'Agent';

  @override
  String get navReports => 'Reports';

  @override
  String get navAlpha => 'Alpha';

  @override
  String get navSettings => 'Settings';

  @override
  String get navMore => 'More';

  @override
  String get agentTitle => 'Agent';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get alphaTitle => 'Alpha Zoo';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get moreTitle => 'More';

  @override
  String get runDetailTitle => 'Run Detail';

  @override
  String get compareTitle => 'Compare';

  @override
  String get correlationTitle => 'Correlation';

  @override
  String get runtimeTitle => 'Live Runtime';

  @override
  String get commonSave => 'Save';

  @override
  String get commonTest => 'Test';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get commonBack => 'Back';

  @override
  String get send => 'Send';

  @override
  String get stop => 'Stop';

  @override
  String get more => 'More';

  @override
  String get agentWaiting => 'Waiting for SSE events (heartbeat every ~15s)…';

  @override
  String get agentSetBackend => 'Set the backend URL in Settings first.';

  @override
  String get agentThinking => 'Thinking…';

  @override
  String get agentThoughtProcess => 'Thought process';

  @override
  String get composerHint => 'Message…';

  @override
  String get welcomeTitle => 'What would you like to research?';

  @override
  String get welcomeSubtitle =>
      'Natural-language finance research, backtests, factors, and live execution.';

  @override
  String get settingsBackend => 'Backend connection';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsSystem => 'System';

  @override
  String get settingsSaved => 'Connection saved.';

  @override
  String get settingsBaseUrl => 'Base URL';

  @override
  String get settingsApiKey => 'API key (optional on loopback)';

  @override
  String get settingsLLM => 'LLM';

  @override
  String get settingsDataSource => 'Data source';

  @override
  String get settingsClear => 'Clear stored credentials';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguageChanged => 'Language switched.';

  @override
  String get provider => 'Provider';

  @override
  String get model => 'Model';

  @override
  String get temp => 'Temp';

  @override
  String get timeoutSec => 'Timeout (s)';

  @override
  String get retries => 'Retries';

  @override
  String get tushareToken => 'Tushare token';

  @override
  String reasoningLabel(String effort) {
    return 'reasoning: $effort';
  }

  @override
  String get composerUpload => 'Upload document';

  @override
  String get composerGoal => 'Research goal';

  @override
  String get composerSwarm => 'Agent swarm';

  @override
  String get composerConnector => 'Check connector';

  @override
  String get composerPortfolio => 'Analyze portfolio';

  @override
  String get liveActive => 'Live runtime active';

  @override
  String get halt => 'HALT';

  @override
  String get sessions => 'Sessions';

  @override
  String get newSession => 'New session';

  @override
  String get noSessions => 'No sessions yet';

  @override
  String get exportChat => 'Export chat';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get connLost => 'Connection lost';

  @override
  String get connRestored => 'Connection restored';

  @override
  String get copied => 'Copied';

  @override
  String get uploading => 'Uploading…';

  @override
  String get timedOut => 'Execution timed out';

  @override
  String connectionFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String failedToLoadRun(String error) {
    return 'Failed to load run: $error';
  }

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabChart => 'Chart';

  @override
  String get tabTrades => 'Trades';

  @override
  String get tabRunCard => 'Run Card';

  @override
  String get tabCode => 'Code';

  @override
  String get tabValidation => 'Validation';

  @override
  String get metricTotalReturn => 'Total return';

  @override
  String get metricAnnual => 'Annual';

  @override
  String get metricMaxDD => 'MaxDD';

  @override
  String get metricSharpe => 'Sharpe';

  @override
  String get metricWinRate => 'Win rate';

  @override
  String get metricTrades => 'Trades';

  @override
  String get noPriceData => 'No price data';

  @override
  String get noChartSymbol => 'No chart for this symbol';

  @override
  String get noEquityData => 'No equity data';

  @override
  String get noTrades => 'No trades';

  @override
  String get noRunCard => 'No run card';

  @override
  String get noSourceCode => 'No source code';

  @override
  String get noValidation => 'No validation data';

  @override
  String get noValidationForRun => 'No validation data for this run.';

  @override
  String get maxDrawdown => 'Max drawdown';

  @override
  String get backtestComplete => 'Backtest complete';

  @override
  String get rawJson => 'Raw';

  @override
  String get warnings => 'Warnings';

  @override
  String get dataSources => 'Data sources';

  @override
  String get report => 'Report';

  @override
  String get pine => 'Pine';

  @override
  String get exportTradesCsv => 'Export trades CSV';

  @override
  String get exportMetricsCsv => 'Export metrics CSV';

  @override
  String nOfM(String shown, String total) {
    return '$shown of $total';
  }

  @override
  String get filter => 'Filter';

  @override
  String get searchRun => 'Search run id / prompt';

  @override
  String get sortNewest => 'Newest';

  @override
  String get sortOldest => 'Oldest';

  @override
  String get sortReturnDesc => 'Return ↓';

  @override
  String get sortSharpeDesc => 'Sharpe ↓';

  @override
  String get noReports => 'No reports';

  @override
  String get globalHalt => 'Global halt';

  @override
  String get brokers => 'Brokers';

  @override
  String get authorized => 'Authorized';

  @override
  String get runners => 'Runners';

  @override
  String get verify => 'Verify';

  @override
  String get noLiveBrokers => 'No live brokers configured';

  @override
  String get pillAuthorized => 'authorized';

  @override
  String get pillNoAuth => 'no auth';

  @override
  String get pillRunner => 'runner';

  @override
  String get pillStopped => 'stopped';

  @override
  String get pillHalted => 'halted';

  @override
  String get pillMandate => 'mandate';

  @override
  String get searchIdNickname => 'Search id / nickname';

  @override
  String get runBenchmark => 'Run benchmark';

  @override
  String get compareAlphas => 'Compare alphas';

  @override
  String get topByIr => 'Top by IR';

  @override
  String get alive => 'Alive';

  @override
  String get reversed => 'Reversed';

  @override
  String get dead => 'Dead';

  @override
  String get skipped => 'Skipped';

  @override
  String get detail => 'Detail';

  @override
  String get idsHint => 'alpha ids (comma/space)';

  @override
  String get benchZoo => 'zoo';

  @override
  String get benchUniverse => 'universe';

  @override
  String get benchPeriod => 'period';

  @override
  String get benchTop => 'top';

  @override
  String get rankByIr => 'rank by IR';

  @override
  String get rankByIcMean => 'rank by IC mean';

  @override
  String get rankByIcPos => 'rank by IC positive %';

  @override
  String get selectRun => 'Select run';

  @override
  String get winner => 'Winner';

  @override
  String get codesHint => 'codes (comma-separated)';

  @override
  String get compute => 'Compute';

  @override
  String get matrix => 'Matrix';

  @override
  String get regimeTimeline => 'Regime timeline';

  @override
  String get goal => 'Goal';

  @override
  String get goalCriteria => 'Criteria';

  @override
  String get goalEvidence => 'Evidence';

  @override
  String get goalContinue => 'Continue';

  @override
  String get goalEdit => 'Edit';

  @override
  String get goalCancel => 'Cancel goal';

  @override
  String get editGoalObjective => 'Edit goal objective';

  @override
  String get mandateProposal => 'Mandate proposal';

  @override
  String get mandateNote =>
      'Review and confirm the trading mandate. This authorizes the broker to trade within the chosen limits.';

  @override
  String get account => 'Account';

  @override
  String get chooseProfile => 'Choose a profile';

  @override
  String get confirmBiometrics => 'Confirm with biometrics';

  @override
  String get noProfiles => 'No profiles in proposal';

  @override
  String get doubleConfirmTitle => 'Confirm mandate';

  @override
  String get doubleConfirmBody =>
      'No biometrics available. Submit this mandate profile?';

  @override
  String get swarmAgents => 'agents';

  @override
  String get swarmWaiting => 'Waiting for events…';

  @override
  String get swarmLayer => 'Layer';

  @override
  String get pineTitle => 'Pine Script';

  @override
  String get pineDocs => 'Pine docs';

  @override
  String get pineHint =>
      'TradingView → Pine Editor → New blank indicator → Paste → Add to Chart';

  @override
  String get runtimeLabel => 'RUNTIME';

  @override
  String get rtOk => 'OK';

  @override
  String get rtUnknown => '(unknown)';

  @override
  String get rtActiveMandate => 'Active mandate';

  @override
  String get rtNoMandate => 'No active mandate';

  @override
  String get rtExpired => 'expired';

  @override
  String get rtPresent => 'present';

  @override
  String get rtMissing => 'missing';

  @override
  String get rtOauthToken => 'OAuth token';

  @override
  String get rtTransport => 'Transport';

  @override
  String get rtConnection => 'Connection';

  @override
  String get rtError => 'Error';

  @override
  String get rtLastTick => 'Last tick';

  @override
  String rtAgo(String s) {
    return '${s}s ago';
  }

  @override
  String get rtSdkNotConfigured => 'SDK profile not configured';

  @override
  String get rtStartRunner => 'Start runner';

  @override
  String get rtStopRunner => 'Stop runner';

  @override
  String get rtResume => 'Resume';

  @override
  String get rtAuthorizeBtn => 'Authorize';

  @override
  String rtAuthorizeTitle(String broker) {
    return 'Authorize $broker';
  }
}
