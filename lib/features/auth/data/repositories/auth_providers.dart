import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/repositories/auth_repository.dart';
import 'supabase_auth_repository_impl.dart';

part 'auth_providers.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) => SupabaseAuthRepositoryImpl();
