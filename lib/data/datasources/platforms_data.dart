import '../models/product_model.dart';

/// 所有导航平台数据
class PlatformsData {
  static const List<PlatformModel> all = [
    // ==================== 大陆平台 ====================
    PlatformModel(
      id: 'alipay',
      name: '支付宝',
      logoAsset: 'assets/icons/alipay.png',
      description: '余额宝货基、理财产品、保险、股票基金',
      deepLinkUrl: 'alipays://platformapi/startapp?appId=20000003',
      webUrl: 'https://www.alipay.com',
      appStoreUrl: 'https://apps.apple.com/cn/app/alipay/id333206289',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.eg.android.AlipayGphone',
    ),
    PlatformModel(
      id: 'wechat',
      name: '微信零钱通',
      logoAsset: 'assets/icons/wechat.png',
      description: '零钱通货基、微信理财通基金',
      deepLinkUrl: 'weixin://',
      webUrl: 'https://weixin.qq.com',
      appStoreUrl: 'https://apps.apple.com/cn/app/wechat/id414478124',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.tencent.mm',
    ),
    PlatformModel(
      id: 'tiantian',
      name: '天天基金',
      logoAsset: 'assets/icons/tiantian.png',
      description: '公募基金、ETF、债券基金一站式购买',
      deepLinkUrl: 'amkt://',
      webUrl: 'https://fund.eastmoney.com',
      appStoreUrl: 'https://apps.apple.com/cn/app/%E5%A4%A9%E5%A4%A9%E5%9F%BA%E9%87%91/id607966999',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.eastmoney.android.fund',
    ),
    PlatformModel(
      id: 'eastmoney',
      name: '东方财富',
      logoAsset: 'assets/icons/eastmoney.png',
      description: 'A股、ETF、港股通、债券交易',
      deepLinkUrl: 'eastmoney://',
      webUrl: 'https://www.eastmoney.com',
      appStoreUrl: 'https://apps.apple.com/cn/app/%E4%B8%9C%E6%96%B9%E8%B4%A2%E5%AF%8C/id573991393',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.eastmoney.android.berlin',
    ),
    PlatformModel(
      id: 'tonghuashun',
      name: '同花顺',
      logoAsset: 'assets/icons/tonghuashun.png',
      description: 'A股行情、交易、ETF、港股通',
      deepLinkUrl: 'ths://',
      webUrl: 'https://www.10jqka.com.cn',
      appStoreUrl: 'https://apps.apple.com/cn/app/%E5%90%8C%E8%8A%B1%E9%A1%BA-level2%E8%A1%8C%E6%83%85%E7%82%92%E8%82%A1%E8%BD%AF%E4%BB%B6/id443007245',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.hexin.plato.android',
    ),
    PlatformModel(
      id: 'cmb',
      name: '招商银行',
      logoAsset: 'assets/icons/cmb.png',
      description: '定存、大额存单、国债、银行理财',
      deepLinkUrl: 'cmbmobilebank://',
      webUrl: 'https://www.cmbchina.com',
      appStoreUrl: 'https://apps.apple.com/cn/app/%E6%8B%9B%E5%95%86%E9%93%B6%E8%A1%8C/id416058607',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=cmb.pb.activityaccount',
    ),
    PlatformModel(
      id: 'icbc',
      name: '工商银行',
      logoAsset: 'assets/icons/icbc.png',
      description: '存款、国债、纸黄金、理财产品',
      deepLinkUrl: 'icbc://',
      webUrl: 'https://www.icbc.com.cn',
      appStoreUrl: 'https://apps.apple.com/cn/app/%E5%B7%A5%E5%95%86%E9%93%B6%E8%A1%8C/id377898500',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.icbc',
    ),
    PlatformModel(
      id: 'pingan',
      name: '平安保险',
      logoAsset: 'assets/icons/pingan.png',
      description: '增额终身寿、年金险、万能险',
      deepLinkUrl: 'pingan://',
      webUrl: 'https://www.pingan.com',
      appStoreUrl: 'https://apps.apple.com/cn/app/%E5%B9%B3%E5%AE%89%E9%87%91%E7%AE%A1%E5%AE%B6/id606999467',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.pingan.papd.activities',
    ),
    PlatformModel(
      id: 'futu',
      name: '富途牛牛',
      logoAsset: 'assets/icons/futu.png',
      description: '港股、美股、A股、ETF交易',
      deepLinkUrl: 'futu://',
      webUrl: 'https://www.futunn.com',
      appStoreUrl: 'https://apps.apple.com/cn/app/%E5%AF%8C%E9%80%94%E7%89%9B%E7%89%9B-%E6%B8%AF%E7%BE%8E%E8%82%A1%E8%87%AA%E9%80%89%E8%82%A1/id668174641',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.futu.moo',
    ),

    // ==================== 香港平台 ====================
    PlatformModel(
      id: 'hsbc_hk',
      name: '汇丰香港',
      logoAsset: 'assets/icons/hsbc.png',
      description: '香港银行账户、定期存款、投资产品',
      deepLinkUrl: null,
      webUrl: 'https://www.hsbc.com.hk',
      appStoreUrl: 'https://apps.apple.com/hk/app/hsbc-hk-mobile-banking/id393505688',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=hk.com.hsbc.hsbcmobile',
    ),
    PlatformModel(
      id: 'aia',
      name: '友邦保险（AIA）',
      logoAsset: 'assets/icons/aia.png',
      description: '香港储蓄分红保险、重疾险（需赴港）',
      deepLinkUrl: null,
      webUrl: 'https://www.aia.com.hk',
      appStoreUrl: 'https://apps.apple.com/hk/app/aia-connect/id1059695266',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=hk.aia.aia',
    ),
    PlatformModel(
      id: 'ibkr',
      name: '盈透证券（IBKR）',
      logoAsset: 'assets/icons/ibkr.png',
      description: '港美股、海外ETF（VOO/QQQ）、债券',
      deepLinkUrl: 'ibkr://',
      webUrl: 'https://www.interactivebrokers.com.hk',
      appStoreUrl: 'https://apps.apple.com/cn/app/ibkr-mobile/id1490447474',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=atws.app.interactivebrokers',
    ),

    // ==================== 加密货币平台 ====================
    PlatformModel(
      id: 'hashkey',
      name: 'HashKey Exchange',
      logoAsset: 'assets/icons/hashkey.png',
      description: '香港证监会持牌合规加密交易所，BTC/ETH',
      deepLinkUrl: null,
      webUrl: 'https://www.hashkey.com',
      appStoreUrl: 'https://apps.apple.com/hk/app/hashkey-exchange/id6443919686',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.hashkey.exchange',
    ),
  ];

  static PlatformModel? findById(String id) =>
      all.where((p) => p.id == id).firstOrNull;

  static List<PlatformModel> findByIds(List<String> ids) =>
      all.where((p) => ids.contains(p.id)).toList();
}
