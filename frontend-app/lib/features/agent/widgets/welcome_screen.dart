import 'package:flutter/material.dart';

/// Empty-state for the Agent timeline. Mirrors the React `WelcomeScreen`:
/// gradient icon + subtitle + 4 Quick Action cards + collapsible "browse all
/// examples" with 8 categories.
///
/// Usage: `WelcomeScreen(onPick: (prompt) => ...)`.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onPick});
  final ValueChanged<String> onPick;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        // --- Header ---
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
            ),
          ),
          child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 14),
        Text(
          '问一只股票、一个策略，或者你的持仓——我会自己取数据、跑计算，并把每一步摆给你看。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.6, color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 20),

        // --- Quick Actions (always visible) ---
        for (final qa in _quickActions)
          _card(context, qa),

        const SizedBox(height: 8),

        // --- Toggle: browse all / collapse ---
        if (!_showAll)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showAll = true),
              icon: const Icon(Icons.expand_more, size: 18),
              label: const Text('浏览全部示例'),
            ),
          )
        else ...[
          for (final cat in _categories) ...[
            const SizedBox(height: 12),
            Row(children: [
              Icon(cat.icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(cat.title, style: theme.textTheme.titleSmall),
            ]),
            const SizedBox(height: 8),
            for (final ex in cat.examples)
              _card(context, ex),
          ],
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showAll = false),
              icon: const Icon(Icons.expand_less, size: 18),
              label: const Text('收起示例'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _card(BuildContext context, _Example ex) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(ex.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(ex.desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
        ),
        trailing: const Icon(Icons.north_east, size: 18),
        isThreeLine: true,
        onTap: () => widget.onPick(ex.prompt),
      ),
    );
  }

  // --- Data ---
  static const _quickActions = <_Example>[
    _Example(title: '估值核算（PE/PB/ROE）', desc: '逐位精确复核 PE / PB / ROE / 市值，再做乐观／中性／悲观三档估值', prompt: '用 financial_rigor 工具验算贵州茅台估值:股价 1500、EPS 68.6、每股净资产 180，精确算 PE/PB/ROE，再做三情景估值（增速 12%/8%/0%，PE 22/18/14，3 年）'),
    _Example(title: '期权风险指标（Greeks）分析', desc: '给期权定价，并算出它对股价、时间、波动率的敏感度（Greeks：Delta/Gamma/Theta/Vega）', prompt: '利用 Black-Scholes 计算期权希腊字母：现货=100，执行价=105，无风险利率=3%，波动率=25%，到期时间=90天，分析 Delta/Gamma/Theta/Vega'),
    _Example(title: '三只 A 股的仓位配比', desc: '在 3 只 A 股之间分配资金，让每只承担同等风险（风险平价），再与等权组合对比', prompt: '用000001.SZ、600519.SH、000858.SZ构建风险平价组合，回测2024全年，与等权基准对比'),
    _Example(title: '多空辩论：该买还是该卖', desc: '智能体团队辩论：多头 vs 空头，风险审查，投资经理决策', prompt: '[智能体团队模式] 使用 investment_committee 预设评估在当前市场环境下对 600519.SH 进行做多还是做空'),
  ];

  static const _categories = <_Category>[
    _Category(icon: Icons.trending_up, title: 'A股回测', examples: [
      _Example(title: '三只 A 股的仓位配比', desc: '在 3 只 A 股之间分配资金，让每只承担同等风险（风险平价），再与等权组合对比', prompt: '用000001.SZ、600519.SH、000858.SZ构建风险平价组合，回测2024全年，与等权基准对比'),
      _Example(title: 'A股 MACD 策略', desc: '基于分钟级数据的A股MACD策略回测', prompt: '用000001.SZ的5分钟K线做MACD策略回测，快线12慢线26信号线9，近30天'),
      _Example(title: '蓝筹股分散配置', desc: '给 5 只蓝筹分配权重，让风险不压在单只股票上（最大分散化优化器）', prompt: '回测600519.SH、000858.SZ、601318.SH、000001.SZ、600036.SH的最大分散化投资组合，2024全年'),
    ]),
    _Category(icon: Icons.auto_awesome, title: '研究与分析', examples: [
      _Example(title: '多因子 Alpha 模型', desc: '在 300 只股票上合成 4 类选股信号，按各自历史预测准确度（IC）加权', prompt: '在沪深 300 成分股上利用动量、反转、成交量和波动率构建多因子 Alpha 模型，进行 IC 加权因子合成，回测 2023-2024 年'),
      _Example(title: '期权风险指标（Greeks）分析', desc: '给期权定价，并算出它对股价、时间、波动率的敏感度（Greeks：Delta/Gamma/Theta/Vega）', prompt: '利用 Black-Scholes 计算期权希腊字母：现货=100，执行价=105，无风险利率=3%，波动率=25%，到期时间=90天，分析 Delta/Gamma/Theta/Vega'),
    ]),
    _Category(icon: Icons.diamond, title: '价值投资', examples: [
      _Example(title: '四大师价值委员会', desc: '巴菲特/芒格/段永平/李录 四视角辩论一只股票', prompt: '用 run_swarm 执行 value_investing_committee，分析腾讯（00700.HK）:巴菲特看护城河和价格、芒格做逆向、段永平看生意和人、李录看十年确定性，主席综合共识和矛盾'),
      _Example(title: '供应链瓶颈猎手', desc: '在大趋势里找出上游卡脖子的小供应商，再筛掉估值已经太贵的', prompt: '用 bottleneck-hunter 技能找 AI 基础设施的 Layer 2/3 供应链瓶颈机会（光模块/激光器/InP 衬底），给瓶颈评级和过估值门的候选公司'),
      _Example(title: '投资逻辑追踪', desc: '给持仓写下 5 句话投资逻辑、触发卖出的红线和估值锚点', prompt: '用 thesis-tracker 技能给贵州茅台（600519.SH）建立投资论文:5 句话核心论文、可验证假设、红线清单、估值锚点，用 financial_rigor 验算'),
      _Example(title: '估值核算（PE/PB/ROE）', desc: '逐位精确复核 PE / PB / ROE / 市值，再做乐观／中性／悲观三档估值', prompt: '用 financial_rigor 工具验算贵州茅台估值:股价 1500、EPS 68.6、每股净资产 180，精确算 PE/PB/ROE，再做三情景估值（增速 12%/8%/0%，PE 22/18/14，3 年）'),
    ]),
    _Category(icon: Icons.groups, title: '智能体团队', examples: [
      _Example(title: '多空辩论：该买还是该卖', desc: '智能体团队辩论：多头 vs 空头，风险审查，投资经理决策', prompt: '[智能体团队模式] 使用 investment_committee 预设评估在当前市场环境下对 600519.SH 进行做多还是做空'),
      _Example(title: '量化策略工作台', desc: '筛选 → 因子研究 → 回测 → 风险审计流水线', prompt: '[智能体团队模式] 使用 quant_strategy_desk 预设在沪深 300 成分股中寻找并回测最佳动量策略'),
    ]),
    _Category(icon: Icons.public, title: '文档与网络研究', examples: [
      _Example(title: '分析财报 PDF', desc: '上传 PDF 并询问财务问题', prompt: '总结上传财务报告中的核心财务指标、风险和展望'),
      _Example(title: '网络研究：宏观经济展望', desc: '阅读最新网络来源进行宏观分析', prompt: '阅读最新的央行货币政策报告，总结对 A 股市场的影响'),
    ]),
    _Category(icon: Icons.edit_note, title: '交易日志', examples: [
      _Example(title: '分析券商导出数据', desc: '解析同花顺/东财/富途/通用 CSV —— 持仓天数、胜率、盈亏比、小时分布', prompt: '分析我刚刚上传的交易日志 —— 包含持仓统计、胜率、核心标的以及小时分布的完整画像'),
      _Example(title: '诊断行为偏差', desc: '处置效应、过度交易、追涨动量、锚定效应 —— 严重程度 + 数值证据', prompt: '对我的交易日志运行 4 项行为诊断（处置效应、过度交易、追涨、锚定），并告诉我哪种偏差最损害我的盈亏'),
    ]),
    _Category(icon: Icons.account_balance, title: '交易连接器', examples: [
      _Example(title: '检查已选连接器', desc: '列出连接器配置并验证当前选择', prompt: '列出我的交易连接器配置，显示哪一个被选中，然后检查该被选中的连接器。如果未就绪，请明确告诉我缺少什么设置步骤。不要下单或修改订单。'),
      _Example(title: '分析连接器投资组合', desc: '从已选连接器读取账户摘要和持仓', prompt: '使用选定的交易连接器配置来总结我的账户、持仓、集中度、现金和组合风险。不要下单或修改订单。'),
      _Example(title: '报价与趋势', desc: '通过已选连接器获取报价和近 30 日日线数据', prompt: '使用选定的交易连接器获取 600519.SH 的报价和 30 日日线数据，然后总结当前报价与近期趋势的对比。保持只读。'),
    ]),
    _Category(icon: Icons.supervised_user_circle, title: '影子账户', examples: [
      _Example(title: '从日志训练影子账户', desc: '从券商 CSV 提取策略规则并持久化影子账户配置', prompt: '从我刚刚上传的交易日志中训练我的影子账户 —— 展示提取的规则并确认它们符合我的交易习惯'),
      _Example(title: '我少赚了多少？', desc: '回测影子策略并与实际盈亏进行归因分析', prompt: '运行过去 90 天的影子回测，并细化分析我的实际盈亏与影子账户发生分歧的地方（违反规则、过早退出、错过信号）'),
      _Example(title: '生成影子报告', desc: '可分享的 8 部分报告：账户净值曲线、风险调整后收益，以及每笔盈亏的来源拆解', prompt: '渲染影子报告并向我提供 URL —— 以你与影子账户的盈亏差距（Delta）为主导'),
    ]),
  ];
}

class _Example {
  const _Example({required this.title, required this.desc, required this.prompt});
  final String title;
  final String desc;
  final String prompt;
}

class _Category {
  const _Category({required this.icon, required this.title, required this.examples});
  final IconData icon;
  final String title;
  final List<_Example> examples;
}
