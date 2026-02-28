import '../models/product_model.dart';

/// 所有理财产品静态数据
class ProductsData {
  static const List<ProductModel> all = [
    // ==================== 大陆 - 现金管理类 ====================

    ProductModel(
      id: 'cn_money_fund',
      name: '货币基金',
      shortName: '货基',
      region: 'mainland',
      category: '现金管理',
      riskLevel: 1,
      riskDescription: '历史上从未出现亏损；主要投向银行存款、国债、央票；极端情况可能单日收益为零。不受存款保险保障，但实际风险极低。',
      returnRates: [
        ReturnRate(period: '7日年化（参考）', rate: '1.3%~2.0%', isGuaranteed: false),
      ],
      minInvestment: 1,
      liquidity: 'T+0快速赎回（1万元以内），T+1到账',
      description: '货币基金是投资于短期货币市场工具的基金，包括银行存款、国债、央票等。余额宝（天弘基金）是国内规模最大的货币基金。相比银行活期存款，收益更高，流动性几乎相同。',
      suitableFor: ['闲置资金', '短期备用', '工资理财起点'],
      watchOut: [
        '7日年化利率每天变动，非固定收益',
        '不受存款保险保护（但历史上无亏损记录）',
        '余额宝等单日快速赎回有额度限制（通常1万元）',
        '2024年以来利率持续下行，当前约1.3-1.8%',
      ],
      platformIds: ['alipay', 'wechat', 'tiantian'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'alipay',
          step: '入口',
          imageAsset: 'assets/screenshots/alipay_money_fund_1.png',
          caption: '支付宝 → 我的 → 点击"余额宝"',
        ),
        PlatformScreenshot(
          platformId: 'alipay',
          step: '详情页',
          imageAsset: 'assets/screenshots/alipay_money_fund_2.png',
          caption: '余额宝详情：七日年化 1.1090%、累计收益、转入转出',
        ),
        PlatformScreenshot(
          platformId: 'alipay',
          step: '购买页',
          imageAsset: 'assets/screenshots/alipay_money_fund_3.png',
          caption: '输入转入金额 → 同意协议并转入',
        ),
      ],
    ),

    // ==================== 大陆 - 固定收益类 ====================

    ProductModel(
      id: 'cn_fixed_deposit',
      name: '定期存款',
      shortName: '定存',
      region: 'mainland',
      category: '固定收益',
      riskLevel: 1,
      riskDescription: '无本金风险，受存款保险保障（每人50万上限）。提前支取按活期利率计算，损失部分利息。',
      returnRates: [
        ReturnRate(period: '3个月', rate: '1.05%', isGuaranteed: true),
        ReturnRate(period: '6个月', rate: '1.25%', isGuaranteed: true),
        ReturnRate(period: '1年', rate: '1.35%', isGuaranteed: true),
        ReturnRate(period: '2年', rate: '1.45%', isGuaranteed: true),
        ReturnRate(period: '3年', rate: '1.75%', isGuaranteed: true),
        ReturnRate(period: '5年', rate: '1.80%', isGuaranteed: true),
      ],
      minInvestment: 50,
      liquidity: '锁定至到期日，提前支取仅得活期利率',
      description: '定期存款是在银行存入一笔资金，约定存期和利率，到期后取出本息。存期越长，利率通常越高。2025年各大银行定期利率因央行持续降息而处于历史较低水平。',
      suitableFor: ['明确近期不会动用的资金', '保守型投资者', '追求确定收益'],
      watchOut: [
        '提前支取只得活期利率（约0.15%），损失大量利息',
        '银行降息时，新存入的定期利率会更低',
        '国有大行利率通常低于地方性银行；可对比各行利率',
        '建议将大额资金分散存入多家银行（每家不超过50万），确保存款保险全额保障',
      ],
      platformIds: ['icbc', 'cmb', 'ccb', 'boc', 'abc'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'cmb',
          step: '入口',
          imageAsset: 'assets/screenshots/cmb_fixed_deposit_1.png',
          caption: '招行APP → 首页 → 存款 → 定期存款',
        ),
        PlatformScreenshot(
          platformId: 'cmb',
          step: '详情页',
          imageAsset: 'assets/screenshots/cmb_fixed_deposit_2.png',
          caption: '选择存款期限，查看各期限利率',
        ),
        PlatformScreenshot(
          platformId: 'cmb',
          step: '购买页',
          imageAsset: 'assets/screenshots/cmb_fixed_deposit_3.png',
          caption: '输入存款金额，选择到期处理方式，确认存入',
        ),
      ],
    ),

    ProductModel(
      id: 'cn_large_cd',
      name: '大额存单',
      shortName: '大额存单',
      region: 'mainland',
      category: '固定收益',
      riskLevel: 1,
      riskDescription: '与定期存款相同，受存款保险保障。可通过银行柜台办理质押贷款，提高资金使用效率。部分银行支持转让给他人。',
      returnRates: [
        ReturnRate(period: '1年', rate: '1.55%~1.70%', isGuaranteed: true),
        ReturnRate(period: '2年', rate: '1.65%~1.85%', isGuaranteed: true),
        ReturnRate(period: '3年', rate: '1.90%~2.15%', isGuaranteed: true),
      ],
      minInvestment: 200000,
      liquidity: '可转让（部分银行），或办理质押贷款',
      description: '大额存单是银行面向个人和机构投资者发行的记账式存款凭证。起投门槛20万元，利率高于普通定期存款。相比定期存款，大额存单流动性更好——部分银行支持在二级市场转让，无需损失利息。',
      suitableFor: ['50万以上资产', '追求比普通定存高利率', '可接受一定期限锁定'],
      watchOut: [
        '最低20万元起投',
        '转让需要找到愿意接手的买家，不一定能快速变现',
        '不同银行利率差异较大，建议多对比',
        '同样受每家银行50万存款保险限额约束',
      ],
      platformIds: ['icbc', 'cmb', 'ccb', 'boc', 'abc'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'cmb',
          step: '入口',
          imageAsset: 'assets/screenshots/cmb_large_cd_1.png',
          caption: '招行APP → 存款 → 大额存单',
        ),
        PlatformScreenshot(
          platformId: 'cmb',
          step: '详情页',
          imageAsset: 'assets/screenshots/cmb_large_cd_2.png',
          caption: '大额存单产品列表，显示各期限利率（最低20万）',
        ),
        PlatformScreenshot(
          platformId: 'cmb',
          step: '购买页',
          imageAsset: 'assets/screenshots/cmb_large_cd_3.png',
          caption: '输入认购金额（不低于20万），确认利率和到期日',
        ),
      ],
    ),

    ProductModel(
      id: 'cn_treasury_bond',
      name: '国债',
      shortName: '国债',
      region: 'mainland',
      category: '固定收益',
      riskLevel: 1,
      riskDescription: '由国家信用背书，无违约风险，是国内最安全的投资品种之一。电子式国债可在二级市场卖出，但价格受市场利率影响。',
      returnRates: [
        ReturnRate(period: '3年期', rate: '2.38%', isGuaranteed: true),
        ReturnRate(period: '5年期', rate: '2.50%', isGuaranteed: true),
      ],
      minInvestment: 100,
      liquidity: '凭证式：到期或提前兑取（扣利息）；电子式：可二级市场买卖',
      description: '国债是中央政府发行的债券，代表国家信用。凭证式国债在银行购买，固定利率，到期还本付息，中途可提前兑取（利息损失）。电子式国债通过证券账户或银行购买，可在市场交易。',
      suitableFor: ['极度保守型', '养老金规划', '追求比存款略高的无风险收益'],
      watchOut: [
        '每年发行次数有限，发售当天经常被抢购一空',
        '电子式国债价格受利率影响，利率上行时价格下跌',
        '凭证式国债提前兑取会损失利息收益',
      ],
      platformIds: ['icbc', 'cmb', 'ccb', 'boc', 'eastmoney'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'icbc',
          step: '入口',
          imageAsset: 'assets/screenshots/icbc_treasury_1.png',
          caption: '工行APP → 理财 → 国债 → 查看在售国债',
        ),
        PlatformScreenshot(
          platformId: 'icbc',
          step: '详情页',
          imageAsset: 'assets/screenshots/icbc_treasury_2.png',
          caption: '国债详情：期限、利率、发行时间、剩余额度',
        ),
        PlatformScreenshot(
          platformId: 'icbc',
          step: '购买页',
          imageAsset: 'assets/screenshots/icbc_treasury_3.png',
          caption: '输入购买金额（100元起），确认认购',
        ),
      ],
    ),

    ProductModel(
      id: 'cn_bank_wealth',
      name: '银行理财产品',
      shortName: '银行理财',
      region: 'mainland',
      category: '固定收益',
      riskLevel: 2,
      riskDescription: '净值型产品，不保本，极小概率出现净值下跌。主要投向债券、存款，R1-R2级别历史亏损概率极低。不受存款保险保护，2022年底曾发生大规模赎回导致净值短暂下跌事件。',
      returnRates: [
        ReturnRate(period: '固定收益类（7天~1年）', rate: '2.5%~3.5%', isGuaranteed: false),
        ReturnRate(period: '混合类（含少量股票）', rate: '3.0%~5.0%', isGuaranteed: false),
      ],
      minInvestment: 10000,
      liquidity: '封闭期（7天/1月/3月/1年），开放式产品T+1赎回',
      description: '2022年资管新规全面实施后，银行理财全面转为净值型，打破刚性兑付。主要投向债券、存款、货币市场工具，R2级以下波动极小。由银行理财子公司（如招银理财、工银理财）管理。',
      suitableFor: ['追求比存款高收益', '可接受极小波动', '短中期投资'],
      watchOut: [
        '2022年底债市调整导致部分产品净值短暂下跌（多数已恢复）',
        '非银行存款，不受存款保险保护',
        '选择大型银行理财子公司产品，风险相对更低',
        '注意产品封闭期，锁定期内无法赎回',
      ],
      platformIds: ['cmb', 'icbc', 'ccb', 'boc', 'abc'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'cmb',
          step: '入口',
          imageAsset: 'assets/screenshots/cmb_wealth_mgmt_1.png',
          caption: '招行APP → 理财 → 招银理财 → 全部产品',
        ),
        PlatformScreenshot(
          platformId: 'cmb',
          step: '详情页',
          imageAsset: 'assets/screenshots/cmb_wealth_mgmt_2.png',
          caption: '产品详情：业绩比较基准、风险等级R2、封闭期、净值走势',
        ),
        PlatformScreenshot(
          platformId: 'cmb',
          step: '购买页',
          imageAsset: 'assets/screenshots/cmb_wealth_mgmt_3.png',
          caption: '输入购买金额（起购1万），阅读产品说明书，确认购买',
        ),
      ],
    ),

    ProductModel(
      id: 'cn_bond_fund',
      name: '债券基金',
      shortName: '债基',
      region: 'mainland',
      category: '固定收益',
      riskLevel: 2,
      riskDescription: '主要风险：利率风险（市场利率上行时债券价格下跌，净值下跌）；信用风险（持仓债券违约）。2022年底债市波动导致多只债基大幅下跌，部分净值跌幅超5%。',
      returnRates: [
        ReturnRate(period: '纯债基金（近3年年化）', rate: '2%~4%', isGuaranteed: false),
        ReturnRate(period: '一级债基（含打新）', rate: '3%~5%', isGuaranteed: false),
        ReturnRate(period: '二级债基（含少量股票）', rate: '3%~7%', isGuaranteed: false),
      ],
      minInvestment: 1,
      liquidity: 'T+1或T+2赎回到账',
      description: '债券基金主要投资于国债、企业债、可转债等固定收益类资产。纯债基金只买债券；一级债基可参与新股申购；二级债基还可投资不超过20%的股票。整体波动小于股票基金。',
      suitableFor: ['不想买股票但希望跑赢存款', '中低风险偏好', '中长期持有'],
      watchOut: [
        '利率上行周期中，债基净值会下跌',
        '信用债违约会影响净值（需关注基金持仓质量）',
        '2022年底赎回潮教训：避免在市场恐慌时跟风赎回',
        '选择规模大、成立时间长的产品，风险更可控',
      ],
      platformIds: ['tiantian', 'alipay', 'cmb', 'icbc'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'tiantian',
          step: '入口',
          imageAsset: 'assets/screenshots/tiantian_bond_fund_1.png',
          caption: '天天基金APP → 基金 → 按类型筛选"债券型"',
        ),
        PlatformScreenshot(
          platformId: 'tiantian',
          step: '详情页',
          imageAsset: 'assets/screenshots/tiantian_bond_fund_2.png',
          caption: '债基详情：净值走势、近1/3/5年收益率、基金经理信息',
        ),
        PlatformScreenshot(
          platformId: 'tiantian',
          step: '购买页',
          imageAsset: 'assets/screenshots/tiantian_bond_fund_3.png',
          caption: '输入购买金额（1元起），选择快速赎回或普通赎回，确认购买',
        ),
      ],
    ),

    ProductModel(
      id: 'cn_convertible_bond',
      name: '可转债',
      shortName: '可转债',
      region: 'mainland',
      category: '固定收益',
      riskLevel: 3,
      riskDescription: '下有债底保护（一般跌到90-95元附近有支撑）；正股大幅下跌时，可转债同样跌幅可观；信用评级较低公司的可转债存在违约风险；退市风险较低但仍存在。',
      returnRates: [
        ReturnRate(period: '持有到期（票面利率）', rate: '0.4%~2.0%', isGuaranteed: true),
        ReturnRate(period: '主动管理历史年化', rate: '8%~15%', isGuaranteed: false),
      ],
      minInvestment: 1000,
      liquidity: 'T+0交易（无涨跌停限制），资金T+1到账',
      description: '可转债是上市公司发行的，可以按约定价格转换为公司股票的债券。到期不转股则还本付息（债底保护）；正股上涨则可转股获得收益。兼具债券安全性和股票上涨弹性，号称"进可攻退可守"。',
      suitableFor: ['有一定投资经验', '希望参与股市但控制风险', '接受中等波动'],
      watchOut: [
        '需要主动管理，选择正确的可转债才能获得好收益',
        '正股暴跌时，可转债会跟跌，且跌幅可能超出预期',
        '部分低评级可转债面临违约风险',
        '价格高于130元的可转债，下跌空间更大',
      ],
      platformIds: ['eastmoney', 'tonghuashun'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '入口',
          imageAsset: 'assets/screenshots/eastmoney_conv_bond_1.png',
          caption: '东方财富APP → 行情 → 债券 → 可转债行情列表',
        ),
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '详情页',
          imageAsset: 'assets/screenshots/eastmoney_conv_bond_2.png',
          caption: '可转债详情：转股价、溢价率、正股走势、到期时间',
        ),
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '购买页',
          imageAsset: 'assets/screenshots/eastmoney_conv_bond_3.png',
          caption: '委托买入：选择价格类型（限价/市价），输入数量，确认委托',
        ),
      ],
    ),

    ProductModel(
      id: 'cn_trust',
      name: '信托产品',
      shortName: '信托',
      region: 'mainland',
      category: '固定收益',
      riskLevel: 3,
      riskDescription: '刚性兑付打破后不再保本保息。底层资产多为房地产、政府平台、基础设施等，近年房地产信托大量违约。需要认真甄别底层资产质量，选择底层为标准化资产或政府项目的信托。',
      returnRates: [
        ReturnRate(period: '标准化产品（1-3年）', rate: '4%~6%', isGuaranteed: false),
      ],
      minInvestment: 1000000,
      liquidity: '通常1-3年锁定期，流动性较差，提前退出需协商',
      description: '信托是将财产委托给信托公司管理的制度安排。目前合规的信托产品主要投向标准化债券、权益类资产等，高风险的房地产非标信托已大量压缩。100万元是合格投资者门槛。',
      suitableFor: ['100万以上资产', '有一定风险识别能力', '接受长期锁定'],
      watchOut: [
        '100万元起投，购买前需进行合格投资者认定',
        '刚性兑付已打破，必须自担风险',
        '务必了解底层资产（是标准化资产还是非标资产）',
        '选择大型信托公司，避免小型信托公司风险',
        '近年房地产信托违约频发，远离以房地产为底层的产品',
      ],
      platformIds: ['citic_trust', 'ping_an_trust'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'citic_trust',
          step: '入口',
          imageAsset: 'assets/screenshots/citic_trust_1.png',
          caption: '中信信托官网/APP → 产品中心 → 在售产品',
        ),
        PlatformScreenshot(
          platformId: 'citic_trust',
          step: '详情页',
          imageAsset: 'assets/screenshots/citic_trust_2.png',
          caption: '信托产品详情：底层资产、预期收益率、存续期限、风险揭示',
        ),
        PlatformScreenshot(
          platformId: 'citic_trust',
          step: '购买页',
          imageAsset: 'assets/screenshots/citic_trust_3.png',
          caption: '合格投资者认证 → 签署风险确认书 → 输入认购金额（100万起）',
        ),
      ],
    ),

    // ==================== 大陆 - 权益类 ====================

    ProductModel(
      id: 'cn_a_share',
      name: 'A股（沪深主板）',
      shortName: 'A股',
      region: 'mainland',
      category: '权益类',
      riskLevel: 4,
      riskDescription: '个股可能退市归零；市场系统性风险（熔断/政策调整/牛熊转换）；流动性风险（创业板/科创板小盘股可能跌停无法卖出）；操作风险（追涨杀跌）。T+1交收制度限制当日卖出当日买入的股票。',
      returnRates: [
        ReturnRate(period: '沪深300指数（近5年年化）', rate: '3%~8%', isGuaranteed: false),
        ReturnRate(period: '优秀个股（长期）', rate: '不确定，上不封顶', isGuaranteed: false),
      ],
      minInvestment: 100,
      liquidity: '交易日9:30-15:00，T+1交收（卖出后次日到账）',
      description: '中国A股市场包括上交所（沪市）、深交所（深市）、北交所。主板适合一般投资者；科创板、创业板需50万资产+24个月交易经验；北交所需50万资产+24个月。',
      suitableFor: ['积极型投资者', '有时间研究的投资者', '接受高波动高收益'],
      watchOut: [
        '科创板、创业板需要50万资产门槛+24个月证券交易经验',
        '个股可能归零，分散投资降低风险',
        '国内A股政策性波动较大，关注监管政策变化',
        'T+1制度：今天买入的股票明天才能卖出',
        '建议新手从指数ETF入手，而非直接选个股',
      ],
      platformIds: ['eastmoney', 'tonghuashun', 'huatai', 'citic_sec'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '入口',
          imageAsset: 'assets/screenshots/eastmoney_astock_1.png',
          caption: '东方财富APP → 股票 → 搜索股票代码/名称',
        ),
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '详情页',
          imageAsset: 'assets/screenshots/eastmoney_astock_2.png',
          caption: '个股详情：K线走势、财务数据、机构评级、资金流向',
        ),
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '购买页',
          imageAsset: 'assets/screenshots/eastmoney_astock_3.png',
          caption: '买入委托：选择限价/市价，输入价格和数量（至少100股），确认委托',
        ),
      ],
    ),

    ProductModel(
      id: 'cn_etf',
      name: '指数ETF',
      shortName: 'ETF',
      region: 'mainland',
      category: '权益类',
      riskLevel: 3,
      riskDescription: '跟踪指数整体，不会因单一公司问题归零。主要风险是市场整体下跌。行业ETF（医疗/科技/新能源）波动更大。黄金ETF波动中等。',
      returnRates: [
        ReturnRate(period: '沪深300 ETF（近5年年化）', rate: '3%~8%', isGuaranteed: false),
        ReturnRate(period: '中证500 ETF', rate: '2%~10%（波动更大）', isGuaranteed: false),
        ReturnRate(period: '纳指100 ETF（QDII）', rate: '近5年较强，波动大', isGuaranteed: false),
      ],
      minInvestment: 100,
      liquidity: '交易日实时买卖，T+1资金到账',
      description: 'ETF（交易型开放式指数基金）在股市实时交易，追踪特定指数表现。费率极低（约0.1-0.5%/年）。主要品种：宽基ETF（沪深300、中证500）、行业ETF（医疗、消费、科技）、跨境ETF（纳指、标普）。',
      suitableFor: ['不想选个股，希望分享市场整体成长', '长期定投', '降低单一持仓风险'],
      watchOut: [
        '行业ETF波动大于宽基ETF，慎重选择',
        'QDII ETF有时因额度限制出现大幅溢价，购买时注意折溢价率',
        '长期定投宽基ETF是普通投资者参与股市的推荐方式',
        '买ETF需要证券账户',
      ],
      platformIds: ['eastmoney', 'tonghuashun'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '入口',
          imageAsset: 'assets/screenshots/eastmoney_etf_1.png',
          caption: '东方财富APP → 基金 → ETF → 搜索"沪深300 ETF"',
        ),
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '详情页',
          imageAsset: 'assets/screenshots/eastmoney_etf_2.png',
          caption: 'ETF详情：跟踪指数、管理费率、规模、折溢价率、净值走势',
        ),
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '购买页',
          imageAsset: 'assets/screenshots/eastmoney_etf_3.png',
          caption: '像买股票一样委托：输入价格和份数（至少100份），确认买入',
        ),
      ],
    ),

    ProductModel(
      id: 'cn_public_fund',
      name: '公募基金（主动型）',
      shortName: '主动基金',
      region: 'mainland',
      category: '权益类',
      riskLevel: 3,
      riskDescription: '依赖基金经理能力，经理变更影响大；市场整体下行时难以独善其身；管理费1-1.5%/年长期累积较大；过往业绩不代表未来。',
      returnRates: [
        ReturnRate(period: '优秀基金（10年年化）', rate: '10%~20%', isGuaranteed: false),
        ReturnRate(period: '普通水平', rate: '3%~8%', isGuaranteed: false),
        ReturnRate(period: '表现差的基金', rate: '负收益', isGuaranteed: false),
      ],
      minInvestment: 1,
      liquidity: 'T+1或T+2赎回申请，T+3到账',
      description: '主动管理型基金由基金经理主动选股，目标超越市场指数。通过天天基金、支付宝等渠道可便捷购买。选基金比选股更简单，但同样需要一定甄别能力。',
      suitableFor: ['无暇研究个股', '信任专业管理', '中长期投资（3年以上）'],
      watchOut: [
        '过去业绩好≠未来业绩好，避免追热门基金',
        '基金经理跳槽会影响业绩，需关注人员变动',
        '管理费1%/年，10年累积约10%，选低费率的指数基金往往更划算',
        '建议选择任职期超过3年、经历过牛熊的基金经理',
      ],
      platformIds: ['tiantian', 'alipay', 'cmb', 'icbc'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'tiantian',
          step: '入口',
          imageAsset: 'assets/screenshots/tiantian_public_fund_1.png',
          caption: '天天基金APP → 基金 → 按类型筛选"股票型"或"混合型"',
        ),
        PlatformScreenshot(
          platformId: 'tiantian',
          step: '详情页',
          imageAsset: 'assets/screenshots/tiantian_public_fund_2.png',
          caption: '基金详情：近1/3/5/10年收益、基金经理履历、持仓明细、费率',
        ),
        PlatformScreenshot(
          platformId: 'tiantian',
          step: '购买页',
          imageAsset: 'assets/screenshots/tiantian_public_fund_3.png',
          caption: '输入购买金额（1元起），选择普通申购或定期定额，确认购买',
        ),
      ],
    ),

    ProductModel(
      id: 'cn_private_fund',
      name: '私募基金',
      shortName: '私募',
      region: 'mainland',
      category: '权益类',
      riskLevel: 4,
      riskDescription: '不受公募基金监管约束；信息透明度低，尽调难度大；锁定期1-3年流动性差；管理人跑路风险；策略多样，收益差异极大。',
      returnRates: [
        ReturnRate(period: '优秀管理人（年化）', rate: '15%~30%', isGuaranteed: false),
        ReturnRate(period: '普通水平', rate: '5%~15%', isGuaranteed: false),
        ReturnRate(period: '差的私募', rate: '大幅亏损', isGuaranteed: false),
      ],
      minInvestment: 1000000,
      liquidity: '锁定期通常1-3年，提前赎回需支付赎回费',
      description: '私募基金面向合格投资者（100万元起），策略包括股票多头、量化对冲、CTA（期货趋势）、债券等。头部私募（百亿规模以上）管理规范，但进入门槛高。',
      suitableFor: ['100万以上资产', '风险识别能力强', '接受长期锁定', '追求超额收益'],
      watchOut: [
        '100万元合格投资者门槛，需签署风险确认书',
        '必须认真做投资管理人尽职调查',
        '选择在中国证券投资基金业协会（中基协）备案的私募',
        '避免承诺保本保收益的私募（违规）',
      ],
      platformIds: ['cmb_private', 'yingmi'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'cmb_private',
          step: '入口',
          imageAsset: 'assets/screenshots/cmb_private_fund_1.png',
          caption: '招行APP → 财富管理 → 私募基金（需满足合格投资者条件）',
        ),
        PlatformScreenshot(
          platformId: 'cmb_private',
          step: '详情页',
          imageAsset: 'assets/screenshots/cmb_private_fund_2.png',
          caption: '私募产品详情：策略类型、历史业绩、最大回撤、管理人信息',
        ),
        PlatformScreenshot(
          platformId: 'cmb_private',
          step: '购买页',
          imageAsset: 'assets/screenshots/cmb_private_fund_3.png',
          caption: '合格投资者确认 → 阅读风险揭示 → 输入认购金额（100万起）',
        ),
      ],
    ),

    ProductModel(
      id: 'cn_reits',
      name: '公募REITs',
      shortName: 'REITs',
      region: 'mainland',
      category: '权益类',
      riskLevel: 3,
      riskDescription: '底层资产运营风险；利率上行时REITs估值承压；市场流动性相对较小；部分REITs上市以来价格出现下跌。',
      returnRates: [
        ReturnRate(period: '现金分红收益率', rate: '4%~8%', isGuaranteed: false),
        ReturnRate(period: '含价格变动的总回报', rate: '不确定', isGuaranteed: false),
      ],
      minInvestment: 100,
      liquidity: '证券市场实时交易，T+1资金到账',
      description: '公募REITs是将基础设施资产（高速公路、产业园、数据中心、保障房等）证券化，投资者可获得稳定的租金/通行费分红。国内公募REITs自2021年开始上市。',
      suitableFor: ['追求稳定现金流', '类房产投资但无购房资格', '长期持有分红策略'],
      watchOut: [
        '价格受市场情绪影响，上市以来部分REITs破发',
        '分红收益率≠总回报，需关注净值变化',
        '选择底层资产优质的REITs（如交通、数据中心）',
        '流动性不如A股，大额买卖可能影响价格',
      ],
      platformIds: ['eastmoney', 'tonghuashun'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '入口',
          imageAsset: 'assets/screenshots/eastmoney_reits_1.png',
          caption: '东方财富APP → 基金 → 公募REITs → 查看在市REITs列表',
        ),
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '详情页',
          imageAsset: 'assets/screenshots/eastmoney_reits_2.png',
          caption: 'REITs详情：底层资产类型、分红率、近期净值走势、持有期收益',
        ),
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '购买页',
          imageAsset: 'assets/screenshots/eastmoney_reits_3.png',
          caption: '像买股票一样买入：输入委托价格和数量，确认买入',
        ),
      ],
    ),

    // ==================== 大陆 - 保险类 ====================

    ProductModel(
      id: 'cn_life_insurance',
      name: '增额终身寿险',
      shortName: '增额寿',
      region: 'mainland',
      category: '保险理财',
      riskLevel: 1,
      riskDescription: '保险公司信用风险（极低，监管严格）；流动性风险极大（前3-5年退保会亏损本金）；提前退保损失确定。',
      returnRates: [
        ReturnRate(period: '保额复利增长率（写入合同）', rate: '2.5%~3.0%', isGuaranteed: true),
        ReturnRate(period: '现金价值IRR（持有20年）', rate: '约2.5%~3.0%', isGuaranteed: true),
      ],
      minInvestment: 10000,
      liquidity: '极差：前5年退保亏损；10年后现金价值超过已缴保费；可部分减保取现',
      description: '增额终身寿险的保额每年按约定比例（现行最高3%）递增，写入保险合同受法律保护。其核心价值在于：收益率确定写入合同、资金安全（保险监管严格）、可传承（指定受益人）、规避债务和遗产纠纷。',
      suitableFor: ['财富传承规划', '强制储蓄', '保守型长期资金', '资产隔离需求'],
      watchOut: [
        '前3-5年退保必然亏损，必须做好长期持有的心理准备',
        '2023年"炒停售"后监管调整利率上限，当前新产品约2.5-3%',
        '选择偿付能力充足率高的大型保险公司',
        '不适合作为短期理财，也不适合投入应急资金',
        '避免通过中介购买，部分中介夸大收益率',
      ],
      platformIds: ['pingan', 'cpic', 'china_life', 'alipay_insurance'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'pingan',
          step: '入口',
          imageAsset: 'assets/screenshots/pingan_life_ins_1.png',
          caption: '平安金管家APP → 保险 → 储蓄险 → 增额终身寿险',
        ),
        PlatformScreenshot(
          platformId: 'pingan',
          step: '详情页',
          imageAsset: 'assets/screenshots/pingan_life_ins_2.png',
          caption: '产品详情：保额增长率、现金价值演示表、IRR测算',
        ),
        PlatformScreenshot(
          platformId: 'pingan',
          step: '购买页',
          imageAsset: 'assets/screenshots/pingan_life_ins_3.png',
          caption: '填写投保信息、选择缴费年期和年缴保费，确认投保',
        ),
      ],
    ),

    ProductModel(
      id: 'cn_annuity',
      name: '年金保险',
      shortName: '年金险',
      region: 'mainland',
      category: '保险理财',
      riskLevel: 1,
      riskDescription: '与增额终身寿险相似；提前退保亏损；流动性极差；长期锁定资金。',
      returnRates: [
        ReturnRate(period: 'IRR（持有至领取期）', rate: '2.5%~3.5%', isGuaranteed: true),
      ],
      minInvestment: 10000,
      liquidity: '极差，退保亏损，建议持有至领取年龄',
      description: '年金保险在被保人到达约定年龄后，按约定金额定期给付生存年金。核心功能是养老规划——用现在的钱在退休后换取稳定的现金流。商业年金与社保养老金形成补充。',
      suitableFor: ['退休养老规划', '追求退休后稳定收入', '临近退休人群'],
      watchOut: [
        '必须持有到领取年龄才能充分体现价值',
        '通货膨胀可能侵蚀固定年金的实际购买力',
        '结合社保养老金一起规划，避免过度依赖单一产品',
      ],
      platformIds: ['pingan', 'cpic', 'china_life'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'pingan',
          step: '入口',
          imageAsset: 'assets/screenshots/pingan_annuity_1.png',
          caption: '平安金管家APP → 保险 → 养老险 → 年金险产品列表',
        ),
        PlatformScreenshot(
          platformId: 'pingan',
          step: '详情页',
          imageAsset: 'assets/screenshots/pingan_annuity_2.png',
          caption: '年金详情：领取开始年龄、每年领取金额、生存金演示表',
        ),
        PlatformScreenshot(
          platformId: 'pingan',
          step: '购买页',
          imageAsset: 'assets/screenshots/pingan_annuity_3.png',
          caption: '选择缴费方式（趸交/期缴），填写被保人信息，确认投保',
        ),
      ],
    ),

    // ==================== 大陆 - 黄金 ====================

    ProductModel(
      id: 'cn_paper_gold',
      name: '纸黄金/黄金ETF',
      shortName: '黄金',
      region: 'mainland',
      category: '黄金',
      riskLevel: 3,
      riskDescription: '金价受美元汇率、地缘政治、美联储政策等多因素影响，短期波动剧烈；无利息收益；持有成本（买卖价差、管理费）。',
      returnRates: [
        ReturnRate(period: '2024年涨幅', rate: '约+27%（人民币计价）', isGuaranteed: false),
        ReturnRate(period: '近20年年化', rate: '约8%', isGuaranteed: false),
        ReturnRate(period: '短期', rate: '高度不确定', isGuaranteed: false),
      ],
      minInvestment: 10,
      liquidity: '纸黄金：银行交易时段；黄金ETF：交易日实时买卖',
      description: '纸黄金通过银行账户买卖，与实物黄金价格挂钩，无需实物交割。黄金ETF在证券市场交易，费率更低更灵活。黄金是传统避险资产，在通胀高企、地缘风险时表现突出。',
      suitableFor: ['资产配置多元化', '对冲通胀和地缘风险', '占总资产5-15%较合适'],
      watchOut: [
        '黄金没有利息收益，长期持有机会成本较高',
        '短期价格波动剧烈，不适合追涨杀跌',
        '纸黄金买卖价差约1-2%，频繁交易损耗大',
        '以配置功能为主，不建议大比例持仓',
      ],
      platformIds: ['icbc', 'cmb', 'ccb', 'eastmoney'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'icbc',
          step: '入口',
          imageAsset: 'assets/screenshots/icbc_paper_gold_1.png',
          caption: '工行APP → 理财 → 贵金属 → 纸黄金',
        ),
        PlatformScreenshot(
          platformId: 'icbc',
          step: '详情页',
          imageAsset: 'assets/screenshots/icbc_paper_gold_2.png',
          caption: '纸黄金行情：当前金价（元/克）、走势图、买入卖出价差',
        ),
        PlatformScreenshot(
          platformId: 'icbc',
          step: '购买页',
          imageAsset: 'assets/screenshots/icbc_paper_gold_3.png',
          caption: '输入买入克数（最低0.1克），确认买入价，完成交易',
        ),
      ],
    ),

    // ==================== 大陆 - QDII ====================

    ProductModel(
      id: 'cn_qdii',
      name: 'QDII基金（境外投资）',
      shortName: 'QDII',
      region: 'mainland',
      category: 'QDII',
      riskLevel: 3,
      riskDescription: '海外市场风险；人民币升值时美元资产折损；QDII额度有限，有时暂停申购；跨境监管风险。',
      returnRates: [
        ReturnRate(period: '标普500 QDII（近5年年化）', rate: '约12%~18%（美元计价）', isGuaranteed: false),
        ReturnRate(period: '纳指100 QDII（近3年）', rate: '波动更大，近年较强', isGuaranteed: false),
        ReturnRate(period: '港股QDII', rate: '表现较弱', isGuaranteed: false),
        ReturnRate(period: '海外债券QDII', rate: '约3%~6%', isGuaranteed: false),
      ],
      minInvestment: 1,
      liquidity: 'T+1或T+2赎回',
      description: 'QDII（合格境内机构投资者）基金通过监管批准的额度投资境外市场。最受欢迎的是跟踪美股标普500、纳指100的QDII，近年表现出色。让国内投资者不需要出境账户就能配置海外资产。',
      suitableFor: ['希望配置美股等海外资产', '无境外账户', '资产多元化配置'],
      watchOut: [
        'QDII额度有限，热门产品经常暂停申购',
        '汇率风险：人民币升值会侵蚀美元资产收益',
        '美股估值较高，未来回报可能低于历史水平',
        '选择费率低的指数型QDII而非主动管理型',
      ],
      platformIds: ['tiantian', 'alipay', 'cmb'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'tiantian',
          step: '入口',
          imageAsset: 'assets/screenshots/tiantian_qdii_1.png',
          caption: '天天基金APP → 基金 → 筛选"QDII" → 搜索"标普500"或"纳指"',
        ),
        PlatformScreenshot(
          platformId: 'tiantian',
          step: '详情页',
          imageAsset: 'assets/screenshots/tiantian_qdii_2.png',
          caption: 'QDII详情：跟踪指数、近期收益率、汇率风险说明、是否暂停申购',
        ),
        PlatformScreenshot(
          platformId: 'tiantian',
          step: '购买页',
          imageAsset: 'assets/screenshots/tiantian_qdii_3.png',
          caption: '输入购买金额（注意确认是否正常申购状态），确认买入',
        ),
      ],
    ),

    // ==================== 香港 - 港股通 ====================

    ProductModel(
      id: 'hk_stock_connect',
      name: '港股通（H股/蓝筹）',
      shortName: '港股通',
      region: 'hongkong',
      category: '港股',
      riskLevel: 4,
      riskDescription: '与A股相比，港股无涨跌停限制，单日跌幅可以更大；部分港股流动性低，小盘股可能无法快速变现；T+2交收制度；监管环境与A股不同。',
      returnRates: [
        ReturnRate(period: '恒生指数（近5年）', rate: '表现落后A股和美股', isGuaranteed: false),
        ReturnRate(period: '特定蓝筹（如腾讯）', rate: '差异极大', isGuaranteed: false),
      ],
      minInvestment: 100,
      liquidity: '港股交易时段，T+2交收',
      description: '通过沪深港股通，内地投资者可使用人民币买卖指定的香港上市股票（H股、蓝筹等）。无需赴港开户，通过内地证券账户操作。主要买卖：腾讯、阿里、汇丰、恒指ETF等。',
      suitableFor: ['证券账户资产50万以上', '希望配置港股', '看好H股折价修复'],
      watchOut: [
        '需要50万元证券账户资产才能开通港股通权限',
        '港股无涨跌停，波动更剧烈',
        '小盘港股流动性很差，避免买入',
        '汇率：用人民币买，但实际是港币资产，存在汇率波动',
      ],
      platformIds: ['eastmoney', 'tonghuashun', 'futu'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '入口',
          imageAsset: 'assets/screenshots/eastmoney_hk_connect_1.png',
          caption: '东方财富APP → 港股 → 搜索港股代码（如腾讯：00700）',
        ),
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '详情页',
          imageAsset: 'assets/screenshots/eastmoney_hk_connect_2.png',
          caption: '港股详情：股价（港元）、K线、财务摘要（需已开通港股通权限）',
        ),
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '购买页',
          imageAsset: 'assets/screenshots/eastmoney_hk_connect_3.png',
          caption: '港股委托买入：输入价格（港元）和手数，人民币自动兑换，确认委托',
        ),
      ],
    ),

    // ==================== 香港 - 定期存款 ====================

    ProductModel(
      id: 'hk_deposit',
      name: '香港银行定期存款',
      shortName: '港元定存',
      region: 'hongkong',
      category: '现金管理',
      riskLevel: 1,
      riskDescription: '无本金损失风险；受香港存款保护计划保障（每人每家银行50万港元）；主要风险是人民币升值导致港元资产折算损失。',
      returnRates: [
        ReturnRate(period: '港元1个月', rate: '约3.5%~4.5%', isGuaranteed: true),
        ReturnRate(period: '港元3个月', rate: '约4.0%~5.0%', isGuaranteed: true),
        ReturnRate(period: '美元1年', rate: '约4.0%~4.5%', isGuaranteed: true),
      ],
      minInvestment: 5000,
      liquidity: '固定期限，提前支取损失利息',
      description: '香港银行定期存款利率远高于内地，主要因为港元与美元挂钩，利率跟随美联储政策。2022-2024年美元利率高企，香港存款利率也保持在历史高位。需亲赴香港开立银行账户。',
      suitableFor: ['有香港银行账户', '希望持有外币资产', '对冲人民币贬值风险'],
      watchOut: [
        '需赴香港亲自开户（汇丰、恒生、中银香港、渣打等）',
        '汇率风险：港元对人民币汇率约0.9，但港元已与美元挂钩数十年',
        '美联储降息后港元存款利率也会下降',
        '内地每年换汇额度5万美元，资金跨境有限制',
      ],
      platformIds: ['hsbc_hk', 'hang_seng', 'bochk', 'sc_hk'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'hsbc_hk',
          step: '入口',
          imageAsset: 'assets/screenshots/hsbc_hk_deposit_1.png',
          caption: '汇丰香港APP → 账户与存款 → 定期存款 → 新增定期',
        ),
        PlatformScreenshot(
          platformId: 'hsbc_hk',
          step: '详情页',
          imageAsset: 'assets/screenshots/hsbc_hk_deposit_2.png',
          caption: '选择存款货币（港元/美元）和期限，查看当前利率报价',
        ),
        PlatformScreenshot(
          platformId: 'hsbc_hk',
          step: '购买页',
          imageAsset: 'assets/screenshots/hsbc_hk_deposit_3.png',
          caption: '输入存款金额，确认利率和到期日，完成定期存款',
        ),
      ],
    ),

    // ==================== 香港 - 储蓄保险 ====================

    ProductModel(
      id: 'hk_savings_insurance',
      name: '香港储蓄分红保险',
      shortName: '港险',
      region: 'hongkong',
      category: '保险理财',
      riskLevel: 2,
      riskDescription: '前3年退保大幅亏损；非保证分红依赖保险公司经营（保证部分确定）；保险公司经营风险（但大型国际保险公司历史悠久）；人民币升值时美元保单折算可能下降。',
      returnRates: [
        ReturnRate(period: 'IRR（持有15-20年，含保证+非保证）', rate: '约4%~6%', isGuaranteed: false),
        ReturnRate(period: '保证IRR（仅保证部分）', rate: '约2%~3%', isGuaranteed: true),
      ],
      minInvestment: 10000,
      liquidity: '前3年退保严重亏损；5年后回本；10年后现金价值显著增长',
      description: '香港储蓄分红保险以美元计价，由国际知名保险公司（友邦、宏利、保诚等）提供。收益分为保证部分（写入合同）和非保证红利（依经营状况派发）。相比内地保险产品，长期收益更高，且美元计价。',
      suitableFor: ['跨境资产配置', '美元储蓄需求', '子女教育/传承规划', '100万以上资产'],
      watchOut: [
        '必须亲赴香港签署保单（反洗钱要求）',
        '非保证红利不确定，历史派发率较高但不保证',
        '前3年退保损失非常严重，必须做好长期规划',
        '选择知名大型公司：友邦（AIA）、宏利、保诚、安盛',
        '内地资金出境通道有限，转账方式需合规',
      ],
      platformIds: ['aia', 'manulife', 'prudential'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'aia',
          step: '入口',
          imageAsset: 'assets/screenshots/aia_savings_ins_1.png',
          caption: '友邦AIA官网 → 产品 → 储蓄险 → 选择适合产品（需赴港面见顾问）',
        ),
        PlatformScreenshot(
          platformId: 'aia',
          step: '详情页',
          imageAsset: 'assets/screenshots/aia_savings_ins_2.png',
          caption: '产品建议书：保证收益演示、非保证红利历史派发率、现金价值表',
        ),
        PlatformScreenshot(
          platformId: 'aia',
          step: '购买页',
          imageAsset: 'assets/screenshots/aia_savings_ins_3.png',
          caption: '赴港面见顾问 → 签署保单申请书 → 缴纳首期保费（支票/汇款）',
        ),
      ],
    ),

    // ==================== 香港 - 海外ETF ====================

    ProductModel(
      id: 'hk_overseas_etf',
      name: '海外ETF（美股指数）',
      shortName: '海外ETF',
      region: 'hongkong',
      category: '权益类',
      riskLevel: 3,
      riskDescription: '市场风险（美股整体下跌）；汇率风险；需要境外账户。',
      returnRates: [
        ReturnRate(period: 'VOO（标普500，近10年年化）', rate: '约13%~15%（美元）', isGuaranteed: false),
        ReturnRate(period: 'QQQ（纳指100，近10年年化）', rate: '约18%~20%（美元）', isGuaranteed: false),
        ReturnRate(period: 'TLT（美国长期国债）', rate: '利率敏感，近年下跌', isGuaranteed: false),
      ],
      minInvestment: 100,
      liquidity: '纽约股市交易时段（北京时间晚上9:30-4:00）',
      description: '通过香港券商账户（富途、IBKR等），可直接买卖在美国上市的ETF，如VOO（标普500）、QQQ（纳斯达克100）、BND（美国债券）等。费率极低（VOO年费率仅0.03%），是配置美股的最优方式之一。',
      suitableFor: ['希望直接买美股ETF', '有香港账户', '长期配置美股市场'],
      watchOut: [
        '需要香港券商账户（富途香港版、盈透证券）',
        '美股交易时间与中国时差较大',
        '美国股市可能进入估值较高阶段，需注意回撤风险',
        '资金出境合规问题需注意',
      ],
      platformIds: ['futu_hk', 'ibkr'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'futu_hk',
          step: '入口',
          imageAsset: 'assets/screenshots/futu_hk_etf_1.png',
          caption: '富途牛牛（香港版）→ 行情 → 美股 → 搜索"VOO"或"QQQ"',
        ),
        PlatformScreenshot(
          platformId: 'futu_hk',
          step: '详情页',
          imageAsset: 'assets/screenshots/futu_hk_etf_2.png',
          caption: 'ETF详情：跟踪指数、AUM规模、费率、近期走势、持仓前十',
        ),
        PlatformScreenshot(
          platformId: 'futu_hk',
          step: '购买页',
          imageAsset: 'assets/screenshots/futu_hk_etf_3.png',
          caption: '美股委托：选择限价单，输入价格（美元）和股数，确认买入',
        ),
      ],
    ),

    // ==================== 加密货币 ====================

    ProductModel(
      id: 'crypto_btc_etf',
      name: '比特币ETF（香港）',
      shortName: 'BTC ETF',
      region: 'crypto',
      category: '加密货币',
      riskLevel: 5,
      riskDescription: '价格极度波动（年内波动幅度±50-100%属正常）；监管政策风险；市场流动性风险；无任何保本机制。',
      returnRates: [
        ReturnRate(period: 'BTC近5年年化', rate: '约+100%（但波动极大）', isGuaranteed: false),
        ReturnRate(period: '2022年熊市', rate: '-65%', isGuaranteed: false),
        ReturnRate(period: '2023-2024年', rate: '+150%以上', isGuaranteed: false),
      ],
      minInvestment: 100,
      liquidity: '港交所交易时段实时买卖',
      description: '香港联交所上市的比特币现货ETF（如华夏比特币ETF，代码3042.HK），通过港股账户即可购买，无需在加密交易所开户。直接追踪比特币价格。2024年获香港证监会批准，是合规的加密资产投资渠道。',
      suitableFor: ['愿意承受高风险', '希望用合规方式配置小量加密资产（1-5%仓位）', '有港股账户'],
      watchOut: [
        '极高风险，价格可以在数月内腰斩',
        '建议仓位不超过总资产的5%',
        '加密市场7×24小时交易，ETF在港股收盘后不能交易，存在缺口风险',
        '这是合规工具，不等于内地参与加密货币交易（内地仍不合规）',
      ],
      platformIds: ['eastmoney', 'tonghuashun', 'futu'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '入口',
          imageAsset: 'assets/screenshots/eastmoney_btc_etf_1.png',
          caption: '东方财富APP → 港股 → 搜索"3042"（华夏比特币ETF代码）',
        ),
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '详情页',
          imageAsset: 'assets/screenshots/eastmoney_btc_etf_2.png',
          caption: 'ETF详情：追踪BTC现货价格、规模、溢价率、近期走势',
        ),
        PlatformScreenshot(
          platformId: 'eastmoney',
          step: '购买页',
          imageAsset: 'assets/screenshots/eastmoney_btc_etf_3.png',
          caption: '港股委托买入（需已开通港股通）：输入价格和手数，确认买入',
        ),
      ],
    ),

    ProductModel(
      id: 'crypto_hashkey',
      name: '加密货币（HashKey合规交易所）',
      shortName: '合规加密',
      region: 'crypto',
      category: '加密货币',
      riskLevel: 5,
      riskDescription: '价格极度波动；无任何保本机制；监管政策变化风险；交易所本身运营风险（虽然HashKey持有香港牌照）。',
      returnRates: [
        ReturnRate(period: 'BTC（高度波动）', rate: '不确定，历史长期向好', isGuaranteed: false),
        ReturnRate(period: 'ETH', rate: '波动性大于BTC', isGuaranteed: false),
        ReturnRate(period: '稳定币质押收益', rate: '约3%~8%（DeFi）', isGuaranteed: false),
      ],
      minInvestment: 100,
      liquidity: '7×24小时交易，但涉及资金出入金有合规流程',
      description: 'HashKey Exchange是香港证监会（SFC）持牌的虚拟资产交易平台（VASP牌照），可合规买卖BTC、ETH等主流加密货币。面向零售和机构投资者。OSL是另一家持牌交易所。',
      suitableFor: ['了解加密市场风险的投资者', '希望通过合规渠道持有加密资产', '可接受极高风险的小仓位配置'],
      watchOut: [
        '开户需要KYC验证（身份证明）',
        '内地居民在香港合规交易加密货币，但资金出境需合规',
        '务必只配置可承受全部损失的资金',
        '避免参与内地非合规渠道（OTC、VPN使用境外交易所等）',
      ],
      platformIds: ['hashkey', 'osl'],
      screenshots: [
        PlatformScreenshot(
          platformId: 'hashkey',
          step: '入口',
          imageAsset: 'assets/screenshots/hashkey_crypto_1.png',
          caption: 'HashKey Exchange官网/APP → 注册 → KYC身份验证（需香港/内地证件）',
        ),
        PlatformScreenshot(
          platformId: 'hashkey',
          step: '详情页',
          imageAsset: 'assets/screenshots/hashkey_crypto_2.png',
          caption: '交易对详情：BTC/USD实时价格、深度图、近期成交记录',
        ),
        PlatformScreenshot(
          platformId: 'hashkey',
          step: '购买页',
          imageAsset: 'assets/screenshots/hashkey_crypto_3.png',
          caption: '现货买入：选择限价/市价，输入购买金额，确认买入（KYC通过后）',
        ),
      ],
    ),
  ];

  /// 按地区筛选
  static List<ProductModel> byRegion(String region) =>
      all.where((p) => p.region == region).toList();

  /// 按类别筛选
  static List<ProductModel> byCategory(String category) =>
      all.where((p) => p.category == category).toList();

  /// 按风险等级筛选
  static List<ProductModel> byRiskLevel(int level) =>
      all.where((p) => p.riskLevel == level).toList();

  /// 按ID查找
  static ProductModel? findById(String id) =>
      all.where((p) => p.id == id).firstOrNull;
}
