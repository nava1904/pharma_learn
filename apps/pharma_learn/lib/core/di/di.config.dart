// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:connectivity_plus/connectivity_plus.dart' as _i895;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:supabase_flutter/supabase_flutter.dart' as _i454;

import '../../repositories/assessment_repository.dart' as _i368;
import '../../repositories/training_repository.dart' as _i223;
import '../../stores/assessment_store.dart' as _i421;
import '../../stores/auth_store.dart' as _i322;
import '../../stores/certificate_store.dart' as _i1054;
import '../../stores/compliance_store.dart' as _i905;
import '../../stores/dashboard_store.dart' as _i121;
import '../../stores/induction_store.dart' as _i750;
import '../../stores/notification_store.dart' as _i301;
import '../../stores/ojt_store.dart' as _i727;
import '../../stores/self_learning_store.dart' as _i478;
import '../../stores/training_obligations_store.dart' as _i263;
import '../../stores/waiver_store.dart' as _i269;
import '../api/api_client.dart' as _i277;
import '../cache/offline_cache_service.dart' as _i208;
import '../cache/offline_sync_service.dart' as _i516;
import 'di.dart' as _i913;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final supabaseModule = _$SupabaseModule();
    final externalModule = _$ExternalModule();
    gh.singleton<_i208.OfflineCacheService>(() => _i208.OfflineCacheService());
    gh.singleton<_i454.SupabaseClient>(() => supabaseModule.supabase);
    gh.singleton<_i895.Connectivity>(() => externalModule.connectivity);
    gh.singleton<_i558.FlutterSecureStorage>(
      () => externalModule.secureStorage,
    );
    gh.singleton<_i277.ApiClient>(
      () => _i277.ApiClient(gh<_i454.SupabaseClient>()),
    );
    gh.singleton<_i322.AuthStore>(
      () => _i322.AuthStore(
        gh<_i454.SupabaseClient>(),
        gh<_i558.FlutterSecureStorage>(),
      ),
    );
    gh.singleton<_i368.AssessmentRepository>(
      () => _i368.AssessmentRepository(gh<_i277.ApiClient>()),
    );
    gh.singleton<_i223.TrainingRepository>(
      () => _i223.TrainingRepository(gh<_i277.ApiClient>()),
    );
    gh.singleton<_i1054.CertificateStore>(
      () => _i1054.CertificateStore(gh<_i277.ApiClient>()),
    );
    gh.singleton<_i905.ComplianceStore>(
      () => _i905.ComplianceStore(gh<_i277.ApiClient>()),
    );
    gh.singleton<_i301.NotificationStore>(
      () => _i301.NotificationStore(gh<_i277.ApiClient>()),
    );
    gh.singleton<_i727.OjtStore>(() => _i727.OjtStore(gh<_i277.ApiClient>()));
    gh.singleton<_i421.AssessmentStore>(
      () => _i421.AssessmentStore(gh<_i368.AssessmentRepository>()),
    );
    gh.singleton<_i750.InductionStore>(
      () => _i750.InductionStore(gh<_i223.TrainingRepository>()),
    );
    gh.singleton<_i263.TrainingObligationsStore>(
      () => _i263.TrainingObligationsStore(gh<_i223.TrainingRepository>()),
    );
    gh.singleton<_i269.WaiverStore>(
      () => _i269.WaiverStore(gh<_i223.TrainingRepository>()),
    );
    gh.singleton<_i478.SelfLearningStore>(
      () => _i478.SelfLearningStore(
        gh<_i277.ApiClient>(),
        gh<_i208.OfflineCacheService>(),
      ),
    );
    gh.singleton<_i121.DashboardStore>(
      () => _i121.DashboardStore(gh<_i223.TrainingRepository>()),
    );
    gh.singleton<_i516.OfflineSyncService>(
      () => _i516.OfflineSyncService(
        gh<_i208.OfflineCacheService>(),
        gh<_i277.ApiClient>(),
        gh<_i895.Connectivity>(),
      ),
    );
    return this;
  }
}

class _$SupabaseModule extends _i913.SupabaseModule {}

class _$ExternalModule extends _i913.ExternalModule {}
