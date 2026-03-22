import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

final userProfileNotifierProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile?>((ref) {
  return UserProfileNotifier();
});

class UserProfileNotifier extends StateNotifier<UserProfile?> {
  static const _key = 'user_profile';
  static const _skippedKey = 'onboarding_skipped';
  static const _staleAfterDays = 180;

  UserProfileNotifier() : super(null) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json != null) {
      state = UserProfile.fromJson(jsonDecode(json) as Map<String, dynamic>);
    }
  }

  Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
    state = profile;
  }

  Future<void> markSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_skippedKey, true);
  }

  Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_skippedKey) == true) return false;
    if (state != null) {
      final daysSinceUpdate =
          DateTime.now().difference(state!.updatedAt).inDays;
      return daysSinceUpdate > _staleAfterDays;
    }
    return true;
  }

  bool get isStale {
    if (state == null) return false;
    return DateTime.now().difference(state!.updatedAt).inDays > _staleAfterDays;
  }
}
