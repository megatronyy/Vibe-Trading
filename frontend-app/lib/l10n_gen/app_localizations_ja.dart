// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '灵策AI';

  @override
  String get navAgent => 'エージェント';

  @override
  String get navReports => 'レポート';

  @override
  String get navAlpha => 'Alpha';

  @override
  String get navSettings => '設定';

  @override
  String get navMore => 'その他';

  @override
  String get agentTitle => 'エージェント';

  @override
  String get reportsTitle => 'レポート';

  @override
  String get alphaTitle => 'Alpha Zoo';

  @override
  String get settingsTitle => '設定';

  @override
  String get moreTitle => 'その他';

  @override
  String get runDetailTitle => '実行詳細';

  @override
  String get compareTitle => '比較';

  @override
  String get correlationTitle => '相関';

  @override
  String get runtimeTitle => 'ランタイム';

  @override
  String get commonSave => '保存';

  @override
  String get commonTest => 'テスト';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonRefresh => '更新';

  @override
  String get commonSubmit => '送信';

  @override
  String get commonDismiss => '閉じる';

  @override
  String get commonBack => '戻る';

  @override
  String get send => 'Send';

  @override
  String get stop => 'Stop';

  @override
  String get more => 'More';

  @override
  String get agentWaiting => 'SSE イベントを待っています（約15秒ごとのハートビート）…';

  @override
  String get agentSetBackend => 'まず設定でバックエンド URL を入力してください。';

  @override
  String get agentThinking => '考え中…';

  @override
  String get agentThoughtProcess => '思考プロセス';

  @override
  String get composerHint => 'メッセージ…';

  @override
  String get welcomeTitle => '何を研究しますか？';

  @override
  String get welcomeSubtitle => '自然言語による金融研究、バックテスト、ファクター、ライブ実行。';

  @override
  String get settingsBackend => 'バックエンド接続';

  @override
  String get settingsAppearance => '外観';

  @override
  String get settingsTheme => 'テーマ';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsSystem => 'システム';

  @override
  String get settingsSaved => '接続を保存しました。';

  @override
  String get settingsBaseUrl => 'ベース URL';

  @override
  String get settingsApiKey => 'API キー（ループバックは省略可）';

  @override
  String get settingsLLM => 'LLM';

  @override
  String get settingsDataSource => 'データソース';

  @override
  String get settingsClear => '保存した認証情報を消去';

  @override
  String get settingsThemeSystem => 'システム';

  @override
  String get settingsThemeLight => 'ライト';

  @override
  String get settingsThemeDark => 'ダーク';

  @override
  String get settingsLanguageChanged => '言語を切り替えました。';

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
  String get reasoningProviderDefault => 'Provider default';

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
  String get promptDefineGoal => 'Help me define a research goal.';

  @override
  String get promptContinueGoal => 'Continue the active research goal.';

  @override
  String get promptSwarmTeam =>
      '[Swarm Team Mode] Use the swarm tool to assemble the best specialist team. Auto-select the most appropriate preset.';

  @override
  String get promptCheckConnector =>
      'Check my broker connector status and report authorization, mandate, and runner state for each broker.';

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
  String get metricCalmar => 'Calmar';

  @override
  String get metricSortino => 'Sortino';

  @override
  String get metricVolatility => 'Volatility';

  @override
  String get metricProfitFactor => 'Profit factor';

  @override
  String get metricAvgWin => 'Avg win';

  @override
  String get metricAvgLoss => 'Avg loss';

  @override
  String get metricMaxConsecLosses => 'Max consecutive losses';

  @override
  String get metricExposureTime => 'Exposure time';

  @override
  String get metricAvgHolding => 'Avg holding period';

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
  String get mandateCommitFailed => 'Mandate commit failed — please retry.';

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
