import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

import '../core/api/api_client.dart';

part 'certificate_store.g.dart';

/// Store for managing employee certificates.
/// Handles listing, downloading, and revocation initiation.
@singleton
class CertificateStore = _CertificateStoreBase with _$CertificateStore;

abstract class _CertificateStoreBase with Store {
  final ApiClient _api;
  
  _CertificateStoreBase(this._api);
  
  // ---------------------------------------------------------------------------
  // Observable State
  // ---------------------------------------------------------------------------
  
  @observable
  bool isLoading = false;
  
  @observable
  String? errorMessage;
  
  @observable
  ObservableList<Certificate> certificates = ObservableList<Certificate>();
  
  @observable
  Certificate? selectedCertificate;
  
  @observable
  bool isDownloading = false;
  
  @observable
  String filterStatus = 'all'; // all, active, expired, revoked
  
  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------
  
  @computed
  List<Certificate> get filteredCertificates {
    if (filterStatus == 'all') return certificates.toList();
    return certificates.where((c) => c.status == filterStatus).toList();
  }
  
  @computed
  int get activeCount => certificates.where((c) => c.status == 'active').length;
  
  @computed
  int get expiredCount => certificates.where((c) => c.status == 'expired').length;
  
  @computed
  List<Certificate> get expiringCertificates {
    final now = DateTime.now();
    final threshold = now.add(const Duration(days: 30));
    return certificates
        .where((c) => c.status == 'active' && 
                      c.expiresAt != null && 
                      c.expiresAt!.isBefore(threshold))
        .toList();
  }
  
  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  
  @action
  Future<void> loadCertificates() async {
    isLoading = true;
    errorMessage = null;
    
    try {
      final response = await _api.get('/v1/certify/certificates/my');
      final data = response.data as Map<String, dynamic>;
      final list = data['data'] ?? data['certificates'] ?? [];
      certificates = ObservableList.of(
        (list as List).map((c) => Certificate.fromJson(c)).toList(),
      );
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<void> loadCertificateDetail(String id) async {
    isLoading = true;
    errorMessage = null;
    
    try {
      final response = await _api.get('/v1/certify/certificates/$id');
      final data = response.data as Map<String, dynamic>;
      selectedCertificate = Certificate.fromJson(data['data'] ?? data);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<String?> getDownloadUrl(String certificateId) async {
    isDownloading = true;
    
    try {
      final response = await _api.get('/v1/certify/certificates/$certificateId/download');
      final data = response.data as Map<String, dynamic>;
      return data['url'] ?? data['download_url'];
    } catch (e) {
      errorMessage = e.toString();
      return null;
    } finally {
      isDownloading = false;
    }
  }
  
  @action
  Future<bool> initiateRevocation({
    required String certificateId,
    required String reason,
    required String esigPassword,
    required String meaning,
  }) async {
    isLoading = true;
    errorMessage = null;
    
    try {
      await _api.post(
        '/v1/certify/certificates/$certificateId/revoke',
        data: {
          'reason': reason,
          'esig_password': esigPassword,
          'meaning': meaning,
        },
      );
      await loadCertificates(); // Refresh list
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
    }
  }
  
  @action
  void setFilter(String status) {
    filterStatus = status;
  }
  
  @action
  void clearSelectedCertificate() {
    selectedCertificate = null;
  }
  
  @action
  void clearError() {
    errorMessage = null;
  }
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class Certificate {
  final String id;
  final String certificateNumber;
  final String courseId;
  final String courseTitle;
  final String status;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final String? revokedReason;
  final DateTime? revokedAt;
  
  Certificate({
    required this.id,
    required this.certificateNumber,
    required this.courseId,
    required this.courseTitle,
    required this.status,
    required this.issuedAt,
    this.expiresAt,
    this.revokedReason,
    this.revokedAt,
  });
  
  bool get isExpiringSoon {
    if (expiresAt == null) return false;
    return expiresAt!.difference(DateTime.now()).inDays <= 30;
  }
  
  factory Certificate.fromJson(Map<String, dynamic> json) {
    return Certificate(
      id: json['id'],
      certificateNumber: json['certificate_number'] ?? '',
      courseId: json['course_id'],
      courseTitle: json['course_title'] ?? json['courses']?['title'] ?? '',
      status: json['status'] ?? 'active',
      issuedAt: DateTime.parse(json['issued_at']),
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at']) 
          : null,
      revokedReason: json['revoked_reason'],
      revokedAt: json['revoked_at'] != null 
          ? DateTime.parse(json['revoked_at']) 
          : null,
    );
  }
}
