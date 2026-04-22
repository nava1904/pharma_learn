// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'certificate_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CertificateStore on _CertificateStoreBase, Store {
  Computed<List<Certificate>>? _$filteredCertificatesComputed;

  @override
  List<Certificate> get filteredCertificates =>
      (_$filteredCertificatesComputed ??= Computed<List<Certificate>>(
        () => super.filteredCertificates,
        name: '_CertificateStoreBase.filteredCertificates',
      )).value;
  Computed<int>? _$activeCountComputed;

  @override
  int get activeCount => (_$activeCountComputed ??= Computed<int>(
    () => super.activeCount,
    name: '_CertificateStoreBase.activeCount',
  )).value;
  Computed<int>? _$expiredCountComputed;

  @override
  int get expiredCount => (_$expiredCountComputed ??= Computed<int>(
    () => super.expiredCount,
    name: '_CertificateStoreBase.expiredCount',
  )).value;
  Computed<List<Certificate>>? _$expiringCertificatesComputed;

  @override
  List<Certificate> get expiringCertificates =>
      (_$expiringCertificatesComputed ??= Computed<List<Certificate>>(
        () => super.expiringCertificates,
        name: '_CertificateStoreBase.expiringCertificates',
      )).value;

  late final _$isLoadingAtom = Atom(
    name: '_CertificateStoreBase.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$errorMessageAtom = Atom(
    name: '_CertificateStoreBase.errorMessage',
    context: context,
  );

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$certificatesAtom = Atom(
    name: '_CertificateStoreBase.certificates',
    context: context,
  );

  @override
  ObservableList<Certificate> get certificates {
    _$certificatesAtom.reportRead();
    return super.certificates;
  }

  @override
  set certificates(ObservableList<Certificate> value) {
    _$certificatesAtom.reportWrite(value, super.certificates, () {
      super.certificates = value;
    });
  }

  late final _$selectedCertificateAtom = Atom(
    name: '_CertificateStoreBase.selectedCertificate',
    context: context,
  );

  @override
  Certificate? get selectedCertificate {
    _$selectedCertificateAtom.reportRead();
    return super.selectedCertificate;
  }

  @override
  set selectedCertificate(Certificate? value) {
    _$selectedCertificateAtom.reportWrite(value, super.selectedCertificate, () {
      super.selectedCertificate = value;
    });
  }

  late final _$isDownloadingAtom = Atom(
    name: '_CertificateStoreBase.isDownloading',
    context: context,
  );

  @override
  bool get isDownloading {
    _$isDownloadingAtom.reportRead();
    return super.isDownloading;
  }

  @override
  set isDownloading(bool value) {
    _$isDownloadingAtom.reportWrite(value, super.isDownloading, () {
      super.isDownloading = value;
    });
  }

  late final _$filterStatusAtom = Atom(
    name: '_CertificateStoreBase.filterStatus',
    context: context,
  );

  @override
  String get filterStatus {
    _$filterStatusAtom.reportRead();
    return super.filterStatus;
  }

  @override
  set filterStatus(String value) {
    _$filterStatusAtom.reportWrite(value, super.filterStatus, () {
      super.filterStatus = value;
    });
  }

  late final _$loadCertificatesAsyncAction = AsyncAction(
    '_CertificateStoreBase.loadCertificates',
    context: context,
  );

  @override
  Future<void> loadCertificates() {
    return _$loadCertificatesAsyncAction.run(() => super.loadCertificates());
  }

  late final _$loadCertificateDetailAsyncAction = AsyncAction(
    '_CertificateStoreBase.loadCertificateDetail',
    context: context,
  );

  @override
  Future<void> loadCertificateDetail(String id) {
    return _$loadCertificateDetailAsyncAction.run(
      () => super.loadCertificateDetail(id),
    );
  }

  late final _$getDownloadUrlAsyncAction = AsyncAction(
    '_CertificateStoreBase.getDownloadUrl',
    context: context,
  );

  @override
  Future<String?> getDownloadUrl(String certificateId) {
    return _$getDownloadUrlAsyncAction.run(
      () => super.getDownloadUrl(certificateId),
    );
  }

  late final _$initiateRevocationAsyncAction = AsyncAction(
    '_CertificateStoreBase.initiateRevocation',
    context: context,
  );

  @override
  Future<bool> initiateRevocation({
    required String certificateId,
    required String reason,
    required String esigPassword,
    required String meaning,
  }) {
    return _$initiateRevocationAsyncAction.run(
      () => super.initiateRevocation(
        certificateId: certificateId,
        reason: reason,
        esigPassword: esigPassword,
        meaning: meaning,
      ),
    );
  }

  late final _$_CertificateStoreBaseActionController = ActionController(
    name: '_CertificateStoreBase',
    context: context,
  );

  @override
  void setFilter(String status) {
    final _$actionInfo = _$_CertificateStoreBaseActionController.startAction(
      name: '_CertificateStoreBase.setFilter',
    );
    try {
      return super.setFilter(status);
    } finally {
      _$_CertificateStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearSelectedCertificate() {
    final _$actionInfo = _$_CertificateStoreBaseActionController.startAction(
      name: '_CertificateStoreBase.clearSelectedCertificate',
    );
    try {
      return super.clearSelectedCertificate();
    } finally {
      _$_CertificateStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_CertificateStoreBaseActionController.startAction(
      name: '_CertificateStoreBase.clearError',
    );
    try {
      return super.clearError();
    } finally {
      _$_CertificateStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
certificates: ${certificates},
selectedCertificate: ${selectedCertificate},
isDownloading: ${isDownloading},
filterStatus: ${filterStatus},
filteredCertificates: ${filteredCertificates},
activeCount: ${activeCount},
expiredCount: ${expiredCount},
expiringCertificates: ${expiringCertificates}
    ''';
  }
}
