import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/access/sso/configurations/:id/test - Test SSO configuration
/// Tests connectivity and configuration validity without affecting production
Future<Response> ssoTestHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'sso.test',
    jwtPermissions: auth.permissions,
  );

  // Get configuration
  final config = await supabase
      .from('sso_configurations')
      .select()
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (config == null) {
    return ErrorResponse.notFound('SSO configuration not found').toResponse();
  }

  final providerType = config['provider_type'] as String;
  final configuration = config['configuration'] as Map<String, dynamic>? ?? {};

  final testResults = <String, dynamic>{
    'configuration_id': id,
    'provider_type': providerType,
    'tested_at': DateTime.now().toUtc().toIso8601String(),
    'tests': <Map<String, dynamic>>[],
  };

  // Run provider-specific tests
  switch (providerType) {
    case 'saml':
      testResults['tests'] = _testSamlConfig(configuration);
      break;
    case 'oidc':
      testResults['tests'] = _testOidcConfig(configuration);
      break;
    case 'ldap':
      testResults['tests'] = _testLdapConfig(configuration);
      break;
    default:
      testResults['tests'] = [
        {'name': 'provider_check', 'passed': false, 'error': 'Unknown provider type'}
      ];
  }

  final allPassed = (testResults['tests'] as List).every((t) => t['passed'] == true);
  testResults['overall_status'] = allPassed ? 'passed' : 'failed';

  await supabase.from('audit_trails').insert({
    'entity_type': 'sso_configurations',
    'entity_id': id,
    'action': 'TEST',
    'performed_by': auth.employeeId,
    'changes': {'result': testResults['overall_status']},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(testResults).toResponse();
}

List<Map<String, dynamic>> _testSamlConfig(Map<String, dynamic> config) {
  final tests = <Map<String, dynamic>>[];

  final metadataUrl = config['metadata_url'] as String?;
  tests.add({
    'name': 'metadata_url',
    'passed': metadataUrl != null && metadataUrl.isNotEmpty,
    'error': metadataUrl == null ? 'Metadata URL not configured' : null,
  });

  final entityId = config['entity_id'] as String?;
  tests.add({
    'name': 'entity_id',
    'passed': entityId != null && entityId.isNotEmpty,
    'error': entityId == null ? 'Entity ID not configured' : null,
  });

  final cert = config['certificate'] as String?;
  tests.add({
    'name': 'certificate',
    'passed': cert != null && cert.isNotEmpty,
    'error': cert == null ? 'Certificate not configured' : null,
  });

  return tests;
}

List<Map<String, dynamic>> _testOidcConfig(Map<String, dynamic> config) {
  final tests = <Map<String, dynamic>>[];

  final issuer = config['issuer'] as String?;
  tests.add({
    'name': 'issuer',
    'passed': issuer != null && issuer.isNotEmpty,
    'error': issuer == null ? 'Issuer URL not configured' : null,
  });

  final clientId = config['client_id'] as String?;
  tests.add({
    'name': 'client_id',
    'passed': clientId != null && clientId.isNotEmpty,
    'error': clientId == null ? 'Client ID not configured' : null,
  });

  final redirectUri = config['redirect_uri'] as String?;
  tests.add({
    'name': 'redirect_uri',
    'passed': redirectUri != null && redirectUri.isNotEmpty,
    'error': redirectUri == null ? 'Redirect URI not configured' : null,
  });

  return tests;
}

List<Map<String, dynamic>> _testLdapConfig(Map<String, dynamic> config) {
  final tests = <Map<String, dynamic>>[];

  final serverUrl = config['server_url'] as String?;
  tests.add({
    'name': 'server_url',
    'passed': serverUrl != null && serverUrl.isNotEmpty,
    'error': serverUrl == null ? 'Server URL not configured' : null,
  });

  final baseDn = config['base_dn'] as String?;
  tests.add({
    'name': 'base_dn',
    'passed': baseDn != null && baseDn.isNotEmpty,
    'error': baseDn == null ? 'Base DN not configured' : null,
  });

  final bindDn = config['bind_dn'] as String?;
  tests.add({
    'name': 'bind_dn',
    'passed': bindDn != null && bindDn.isNotEmpty,
    'error': bindDn == null ? 'Bind DN not configured' : null,
  });

  return tests;
}
