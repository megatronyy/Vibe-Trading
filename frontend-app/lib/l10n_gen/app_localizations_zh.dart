// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '灵策AI';

  @override
  String get navAgent => '会话';

  @override
  String get navReports => '运行';

  @override
  String get navAlpha => 'Alpha';

  @override
  String get navSettings => '设置';

  @override
  String get navMore => '更多';

  @override
  String get agentTitle => '会话';

  @override
  String get reportsTitle => '回测报告';

  @override
  String get alphaTitle => 'Alpha 因子库';

  @override
  String get settingsTitle => '设置';

  @override
  String get moreTitle => '更多';

  @override
  String get runDetailTitle => '回测详情';

  @override
  String get compareTitle => '对比';

  @override
  String get correlationTitle => '相关性';

  @override
  String get runtimeTitle => '实盘运行时';

  @override
  String get commonSave => '保存';

  @override
  String get commonTest => '测试';

  @override
  String get commonCancel => '取消';

  @override
  String get commonRefresh => '刷新';

  @override
  String get commonSubmit => '提交';

  @override
  String get commonDismiss => '关闭';

  @override
  String get commonBack => '返回';

  @override
  String get send => '发送';

  @override
  String get stop => '停止';

  @override
  String get more => '更多';

  @override
  String get agentWaiting => '等待 SSE 事件（约每 15s 一个心跳）…';

  @override
  String get agentSetBackend => '请先在设置里填写后端地址。';

  @override
  String get agentThinking => '思考中…';

  @override
  String get agentThoughtProcess => '思考过程';

  @override
  String get composerHint => '输入消息…';

  @override
  String get welcomeTitle => '你想研究什么？';

  @override
  String get welcomeSubtitle => '自然语言金融研究、回测、因子与实盘执行。';

  @override
  String get settingsBackend => '后端连接';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsSystem => '跟随系统';

  @override
  String get settingsSaved => '连接已保存。';

  @override
  String get settingsBaseUrl => '后端地址';

  @override
  String get settingsApiKey => 'API Key（loopback 可留空）';

  @override
  String get settingsLLM => '大模型';

  @override
  String get settingsDataSource => '数据源';

  @override
  String get settingsClear => '清除已存凭据';

  @override
  String get settingsThemeSystem => '系统';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsLanguageChanged => '语言已切换。';

  @override
  String get provider => '提供商';

  @override
  String get model => '模型';

  @override
  String get temp => '温度';

  @override
  String get timeoutSec => '超时(秒)';

  @override
  String get retries => '重试';

  @override
  String get tushareToken => 'Tushare 令牌';

  @override
  String reasoningLabel(String effort) {
    return '推理: $effort';
  }

  @override
  String get reasoningProviderDefault => '跟随供应商默认';

  @override
  String get composerUpload => '上传文档';

  @override
  String get composerGoal => '研究目标';

  @override
  String get composerSwarm => '智能体集群';

  @override
  String get composerConnector => '检查连接器';

  @override
  String get composerPortfolio => '分析组合';

  @override
  String get promptDefineGoal => '帮我定义一个研究目标。';

  @override
  String get promptContinueGoal => '继续当前的研究目标。';

  @override
  String get promptSwarmTeam => '[智能体团队模式] 使用 swarm 工具组建最佳专家团队，自动选择最合适的预设。';

  @override
  String get promptCheckConnector => '检查我的交易连接器状态，报告每个券商的授权、交易授权和 Runner 状态。';

  @override
  String get liveActive => '实盘运行中';

  @override
  String get halt => '停止';

  @override
  String get sessions => '会话';

  @override
  String get newSession => '新建会话';

  @override
  String get noSessions => '暂无会话';

  @override
  String get exportChat => '导出聊天';

  @override
  String get openSettings => '打开设置';

  @override
  String get connLost => '连接已断开';

  @override
  String get connRestored => '连接已恢复';

  @override
  String get copied => '已复制';

  @override
  String get uploading => '上传中…';

  @override
  String get timedOut => '执行超时';

  @override
  String connectionFailed(String error) {
    return '失败：$error';
  }

  @override
  String failedToLoadRun(String error) {
    return '加载回测失败：$error';
  }

  @override
  String get tabOverview => '概览';

  @override
  String get tabChart => '图表';

  @override
  String get tabTrades => '交易';

  @override
  String get tabRunCard => '运行卡';

  @override
  String get tabCode => '代码';

  @override
  String get tabValidation => '验证';

  @override
  String get metricTotalReturn => '总收益';

  @override
  String get metricAnnual => '年化';

  @override
  String get metricMaxDD => '最大回撤';

  @override
  String get metricSharpe => '夏普';

  @override
  String get metricWinRate => '胜率';

  @override
  String get metricTrades => '交易数';

  @override
  String get metricCalmar => '卡玛比率';

  @override
  String get metricSortino => '索提诺比率';

  @override
  String get metricVolatility => '波动率';

  @override
  String get metricProfitFactor => '盈利因子';

  @override
  String get metricAvgWin => '平均盈利';

  @override
  String get metricAvgLoss => '平均亏损';

  @override
  String get metricMaxConsecLosses => '最大连亏';

  @override
  String get metricExposureTime => '持仓时间占比';

  @override
  String get metricAvgHolding => '平均持仓周期';

  @override
  String get noPriceData => '无价格数据';

  @override
  String get noChartSymbol => '该标的无图表';

  @override
  String get noEquityData => '无净值数据';

  @override
  String get noTrades => '无交易';

  @override
  String get noRunCard => '无运行卡';

  @override
  String get noSourceCode => '无源码';

  @override
  String get noValidation => '无验证数据';

  @override
  String get noValidationForRun => '该回测无验证数据。';

  @override
  String get maxDrawdown => '最大回撤';

  @override
  String get backtestComplete => '回测完成';

  @override
  String get rawJson => '原始';

  @override
  String get warnings => '警告';

  @override
  String get dataSources => '数据源';

  @override
  String get report => '报告';

  @override
  String get pine => 'Pine';

  @override
  String get exportTradesCsv => '导出交易 CSV';

  @override
  String get exportMetricsCsv => '导出指标 CSV';

  @override
  String nOfM(String shown, String total) {
    return '$shown / $total';
  }

  @override
  String get filter => '筛选';

  @override
  String get searchRun => '搜索 run id / 提示词';

  @override
  String get sortNewest => '最新';

  @override
  String get sortOldest => '最旧';

  @override
  String get sortReturnDesc => '收益 ↓';

  @override
  String get sortSharpeDesc => '夏普 ↓';

  @override
  String get noReports => '暂无报告';

  @override
  String get globalHalt => '全局停止';

  @override
  String get brokers => '券商数';

  @override
  String get authorized => '已授权';

  @override
  String get runners => '运行中';

  @override
  String get verify => '验证';

  @override
  String get noLiveBrokers => '未配置实盘券商';

  @override
  String get pillAuthorized => '已授权';

  @override
  String get pillNoAuth => '未授权';

  @override
  String get pillRunner => '运行中';

  @override
  String get pillStopped => '已停止';

  @override
  String get pillHalted => '已停止';

  @override
  String get pillMandate => '有授权';

  @override
  String get searchIdNickname => '搜索 id / 别名';

  @override
  String get runBenchmark => '运行基准';

  @override
  String get compareAlphas => '对比因子';

  @override
  String get topByIr => 'IR 领先';

  @override
  String get alive => '有效';

  @override
  String get reversed => '反转';

  @override
  String get dead => '失效';

  @override
  String get skipped => '跳过';

  @override
  String get detail => '详情';

  @override
  String get idsHint => '因子 id（逗号/空格）';

  @override
  String get benchZoo => '因子库';

  @override
  String get benchUniverse => '股票池';

  @override
  String get benchPeriod => '周期';

  @override
  String get benchTop => '前 N';

  @override
  String get rankByIr => '按 IR 排序';

  @override
  String get rankByIcMean => '按 IC 均值排序';

  @override
  String get rankByIcPos => '按 IC 正占比排序';

  @override
  String get selectRun => '选择回测';

  @override
  String get winner => '冠军';

  @override
  String get codesHint => '代码（逗号分隔）';

  @override
  String get compute => '计算';

  @override
  String get matrix => '矩阵';

  @override
  String get regimeTimeline => '市场状态时间线';

  @override
  String windowDays(String n) {
    return '$n天';
  }

  @override
  String get methodPearson => '皮尔逊';

  @override
  String get methodSpearman => '斯皮尔曼';

  @override
  String get toggleRegime => '市场状态';

  @override
  String get goal => '目标';

  @override
  String get goalCriteria => '准则';

  @override
  String get goalEvidence => '证据';

  @override
  String get goalContinue => '继续';

  @override
  String get goalEdit => '编辑';

  @override
  String get goalCancel => '取消目标';

  @override
  String get editGoalObjective => '编辑目标';

  @override
  String get mandateProposal => '交易授权提案';

  @override
  String get mandateNote => '请审阅并确认交易授权。这将允许券商在所选限额内交易。';

  @override
  String get account => '账户';

  @override
  String get chooseProfile => '选择方案';

  @override
  String get confirmBiometrics => '生物识别确认';

  @override
  String get noProfiles => '提案中无方案';

  @override
  String get doubleConfirmTitle => '确认授权';

  @override
  String get doubleConfirmBody => '无可用生物识别。是否提交该授权方案？';

  @override
  String get mandateCommitFailed => '授权提交失败，请重试。';

  @override
  String get swarmAgents => '智能体';

  @override
  String get swarmWaiting => '等待事件…';

  @override
  String get swarmLayer => '层级';

  @override
  String get pineTitle => 'Pine 脚本';

  @override
  String get pineDocs => 'Pine 文档';

  @override
  String get pineHint => 'TradingView → Pine Editor → 新建空白指标 → 粘贴 → 添加到图表';

  @override
  String get runtimeLabel => '运行时';

  @override
  String get rtOk => '正常';

  @override
  String get rtUnknown => '(未知)';

  @override
  String get rtActiveMandate => '有效授权';

  @override
  String get rtNoMandate => '无有效授权';

  @override
  String get rtExpired => '已过期';

  @override
  String get rtPresent => '已有';

  @override
  String get rtMissing => '缺失';

  @override
  String get rtOauthToken => 'OAuth 令牌';

  @override
  String get rtTransport => '传输方式';

  @override
  String get rtConnection => '连接状态';

  @override
  String get rtError => '错误';

  @override
  String get rtLastTick => '最近心跳';

  @override
  String rtAgo(String s) {
    return '$s秒前';
  }

  @override
  String get rtSdkNotConfigured => 'SDK 配置文件未配置';

  @override
  String get rtStartRunner => '启动 Runner';

  @override
  String get rtStopRunner => '停止 Runner';

  @override
  String get rtResume => '恢复';

  @override
  String get rtAuthorizeBtn => '授权';

  @override
  String rtAuthorizeTitle(String broker) {
    return '授权 $broker';
  }
}
