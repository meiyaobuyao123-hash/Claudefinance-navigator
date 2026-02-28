import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 监听 Supabase 认证状态变化（登录/登出/token 刷新）
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// 当前登录用户，null = 未登录
final currentUserProvider = Provider<User?>((ref) {
  final asyncState = ref.watch(authStateProvider);
  return asyncState.when(
    data: (state) => state.session?.user,
    loading: () => Supabase.instance.client.auth.currentUser,
    error: (_, __) => null,
  );
});

/// 将 Supabase Auth 英文错误转为中文提示
String localizeAuthError(String message) {
  final msg = message.toLowerCase();
  if (msg.contains('invalid login credentials') ||
      msg.contains('invalid email or password')) {
    return '邮箱或密码不正确';
  }
  if (msg.contains('user already registered') ||
      msg.contains('already been registered')) {
    return '该邮箱已被注册，请直接登录';
  }
  if (msg.contains('password should be at least')) {
    return '密码至少需要6位';
  }
  if (msg.contains('unable to validate email') ||
      msg.contains('invalid format')) {
    return '邮箱格式不正确';
  }
  if (msg.contains('email not confirmed')) {
    return '请先验证邮箱后再登录';
  }
  if (msg.contains('network') || msg.contains('connection')) {
    return '网络异常，请检查网络后重试';
  }
  return '操作失败：$message';
}
