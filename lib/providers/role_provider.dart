import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final rolProvider = AsyncNotifierProvider<RolNotifier, String>(RolNotifier.new);

class RolNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() => _fetch();

  Future<String> _fetch() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 'buscador';
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('rol')
          .eq('id', user.id)
          .maybeSingle();
      return (data?['rol'] as String?) ?? 'buscador';
    } catch (_) {
      return 'buscador';
    }
  }

  Future<void> setRole(String rol) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    state = const AsyncLoading();
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'rol': rol})
          .eq('id', user.id);
      state = AsyncData(rol);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  void refresh() => ref.invalidateSelf();
}
