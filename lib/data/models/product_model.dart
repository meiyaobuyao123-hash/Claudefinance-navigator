/// 理财产品数据模型
class ProductModel {
  final String id;
  final String name;
  final String shortName;
  final String region;        // mainland / hongkong / crypto
  final String category;      // 现金管理/固定收益/权益类/保险/黄金/QDII
  final int riskLevel;        // 1-5
  final String riskDescription; // 具体风险描述
  final List<ReturnRate> returnRates;   // 按期限分级的收益率
  final double? minInvestment; // 最低投资门槛（元）
  final String liquidity;     // 流动性描述
  final String description;   // 产品介绍
  final List<String> suitableFor; // 适合人群标签
  final List<String> watchOut;    // 注意事项
  final List<String> platformIds; // 可购买平台ID列表
  final List<PlatformScreenshot> screenshots; // 平台操作截图

  const ProductModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.region,
    required this.category,
    required this.riskLevel,
    required this.riskDescription,
    required this.returnRates,
    this.minInvestment,
    required this.liquidity,
    required this.description,
    required this.suitableFor,
    required this.watchOut,
    required this.platformIds,
    this.screenshots = const [],
  });
}

/// 按期限的收益率
class ReturnRate {
  final String period;     // "3个月" / "1年" / "长期持有"
  final String rate;       // "1.35%" / "5-8%" / "历史年化8%"
  final bool isGuaranteed; // 是否保证收益

  const ReturnRate({
    required this.period,
    required this.rate,
    this.isGuaranteed = false,
  });
}

/// 平台截图
class PlatformScreenshot {
  final String platformId;
  final String step;         // "入口" / "详情页" / "购买页" / "确认页"
  final String imageAsset;   // assets路径或网络URL
  final String caption;      // 截图说明

  const PlatformScreenshot({
    required this.platformId,
    required this.step,
    required this.imageAsset,
    required this.caption,
  });
}

/// 导航平台模型
class PlatformModel {
  final String id;
  final String name;
  final String logoAsset;
  final String description;
  final String? deepLinkUrl;    // 跳转到APP的DeepLink
  final String? webUrl;         // 网页版URL
  final String appStoreUrl;     // App Store下载链接
  final String playStoreUrl;    // Google Play下载链接

  const PlatformModel({
    required this.id,
    required this.name,
    required this.logoAsset,
    required this.description,
    this.deepLinkUrl,
    this.webUrl,
    required this.appStoreUrl,
    required this.playStoreUrl,
  });
}
