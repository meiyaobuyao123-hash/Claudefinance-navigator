class AppConstants {
  // API配置 - 替换为你的实际后端地址
  static const String baseUrl = 'http://localhost:3000/api';
  static const String claudeApiUrl = 'https://api.anthropic.com/v1/messages';

  // 存储Key
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String userProfileKey = 'user_profile';

  // 产品分区
  static const String regionMainland = 'mainland';
  static const String regionHongkong = 'hongkong';
  static const String regionCrypto = 'crypto';

  // 风险等级
  static const int riskVeryLow = 1;
  static const int riskLow = 2;
  static const int riskMedium = 3;
  static const int riskHigh = 4;
  static const int riskVeryHigh = 5;

  // 财富等级
  static const double wealthTier1Min = 500000;   // 50万
  static const double wealthTier1Max = 1000000;  // 100万
  static const double wealthTier2Min = 1000000;  // 100万
  static const double wealthTier2Max = 5000000;  // 500万
  static const double wealthTier3Min = 5000000;  // 500万
  static const double wealthTier3Max = 10000000; // 1000万
}
