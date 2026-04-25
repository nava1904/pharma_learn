import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/sso/configurations
///
/// Lists SSO configurations for the organization.
Future<Response> ssoConfigurationsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to view SSO configurations');
  }

  final configs = await supabase
      .from('sso_configurations')
      .select('id, name, provider_type, is_active, created_at, updated_at')
      .order('name', ascending: true);

  return ApiResponse.ok(configs).toResponse();
}

/// GET /v1/sso/configurations/:id
///
/// Gets a specific SSO configuration.
Future<Response> ssoConfigurationGetHandler(Request req) async {
  final configId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (configId == null || configId.isEmpty) {
    throw ValidationException({'id': 'Configuration ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to view SSO configurations');
  }

  final config = await supabase
      .from('sso_configurations')
      .select('*')
      .eq('id', configId)
      .maybeSingle();

  if (config == null) {
    throw NotFoundException('SSO configuration not found');
  }

  // Mask sensitive fields
  final masked = Map<String, dynamic>.from(config);
  if (masked['client_secret'] != null) {
    masked['client_secret'] = '********';
  }

  return ApiResponse.ok(masked).toResponse();
}

/// POST /v1/sso/configurations
///
/// Creates a new SSO configuration.
/// Body: { name, provider_type, client_id, client_secret, issuer_url, ... }
Future<Response> ssoConfigurationCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to create SSO configurations');
  }

  final name = requireString(body, 'name');
  final providerType = requireString(body, 'provider_type');
  final clientId = requireString(body, 'client_id');
  final clientSecret = requireString(body, 'client_secret');
  final issuerUrl = requireString(body, 'issuer_url');

  // Validate provider type
  final validProviders = ['oidc', 'saml', 'azure_ad', 'okta', 'keycloak'];
  if (!validProviders.contains(providerType)) {
    throw ValidationException({
      'provider_type': 'Must be one of: ${validProviders.join(", ")}'
    });
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final config = await supabase
      .from('sso_configurations')
      .insert({
        'name': name,
        'provider_type': providerType,
        'client_id': clientId,
        'client_secret': clientSecret,
        'issuer_url': issuerUrl,
        'authorization_endpoint': body['authorization_endpoint'],
        'token_endpoint': body['token_endpoint'],
        'userinfo_endpoint': body['userinfo_endpoint'],
        'jwks_uri': body['jwks_uri'],
        'scopes': body['scopes'] ?? ['openid', 'profile', 'email'],
        'is_active': false, // Requires activation after testing
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  // Audit log
  await supabase.from('audit_logs').insert({
    'employee_id': auth.employeeId,
    'event_type': 'sso.configuration_created',
    'entity_type': 'sso_configurations',
    'entity_id': config['id'],
    'details': {'name': name, 'provider_type': providerType},
    'created_at': now,
  });

  return ApiResponse.created(config).toResponse();
}

/// PATCH /v1/sso/configurations/:id
///
/// Updates an SSO configuration.
Future<Response> ssoConfigurationUpdateHandler(Request req) async {
  final configId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (configId == null || configId.isEmpty) {
    throw ValidationException({'id': 'Configuration ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to update SSO configurations');
  }

  final existing = await supabase
      .from('sso_configurations')
      .select('id')
      .eq('id', configId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('SSO configuration not found');
  }

  final updateData = <String, dynamic>{
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  final allowedFields = [
    'name', 'client_id', 'client_secret', 'issuer_url',
    'authorization_endpoint', 'token_endpoint', 'userinfo_endpoint',
    'jwks_uri', 'scopes', 'is_active',
  ];

  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('sso_configurations')
      .update(updateData)
      .eq('id', configId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/sso/configurations/:id
///
/// Deletes an SSO configuration.
Future<Response> ssoConfigurationDeleteHandler(Request req) async {
  final configId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (configId == null || configId.isEmpty) {
    throw ValidationException({'id': 'Configuration ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to delete SSO configurations');
  }

  final existing = await supabase
      .from('sso_configurations')
      .select('id, is_active')
      .eq('id', configId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('SSO configuration not found');
  }

  if (existing['is_active'] == true) {
    throw ConflictException('Cannot delete an active SSO configuration. Deactivate it first.');
  }

  await supabase
      .from('sso_configurations')
      .delete()
      .eq('id', configId);

  // Audit log
  await supabase.from('audit_logs').insert({
    'employee_id': auth.employeeId,
    'event_type': 'sso.configuration_deleted',
    'entity_type': 'sso_configurations',
    'entity_id': configId,
    'created_at': DateTime.now().toUtc().toIso8601String(),
  });

  return ApiResponse.noContent().toResponse();
}

/// POST /v1/auth/sso/login
///
/// Initiates SSO login flow. Returns the authorization URL.
/// Body: { provider_id }
Future<Response> ssoLoginInitHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final providerId = requireString(body, 'provider_id');

  final config = await supabase
      .from('sso_configurations')
      .select('*')
      .eq('id', providerId)
      .eq('is_active', true)
      .maybeSingle();

  if (config == null) {
    throw NotFoundException('SSO provider not found or not active');
  }

  // Generate state and nonce for OIDC
  final state = _generateRandomString(32);
  final nonce = _generateRandomString(32);

  // Store state in temporary table for validation
  await supabase.from('sso_auth_states').insert({
    'state': state,
    'nonce': nonce,
    'provider_id': providerId,
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'expires_at': DateTime.now().add(const Duration(minutes: 10)).toUtc().toIso8601String(),
  });

  // Build authorization URL
  final authUrl = _buildAuthorizationUrl(
    authorizationEndpoint: config['authorization_endpoint'] as String,
    clientId: config['client_id'] as String,
    redirectUri: config['redirect_uri'] as String? ?? '/v1/auth/sso/callback',
    scopes: List<String>.from(config['scopes'] as List? ?? ['openid', 'profile', 'email']),
    state: state,
    nonce: nonce,
  );

  return ApiResponse.ok({
    'authorization_url': authUrl,
    'state': state,
  }).toResponse();
}

/// POST /v1/auth/sso/callback
///
/// Handles SSO callback with authorization code.
/// Body: { code, state }
Future<Response> ssoCallbackHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final code = requireString(body, 'code');
  final state = requireString(body, 'state');

  // Validate state
  final authState = await supabase
      .from('sso_auth_states')
      .select('*, sso_configurations!inner(*)')
      .eq('state', state)
      .gt('expires_at', DateTime.now().toUtc().toIso8601String())
      .maybeSingle();

  if (authState == null) {
    throw AuthException('Invalid or expired SSO state');
  }

  // Delete used state
  await supabase.from('sso_auth_states').delete().eq('state', state);

  final config = authState['sso_configurations'] as Map<String, dynamic>;

  // Exchange code for tokens (would call the provider's token endpoint)
  // This is simplified - in production, use http package to call token endpoint
  final tokenResponse = await _exchangeCodeForTokens(
    tokenEndpoint: config['token_endpoint'] as String,
    clientId: config['client_id'] as String,
    clientSecret: config['client_secret'] as String,
    code: code,
    redirectUri: config['redirect_uri'] as String? ?? '/v1/auth/sso/callback',
  );

  // Get user info from ID token or userinfo endpoint
  final userInfo = await _getUserInfo(
    userinfoEndpoint: config['userinfo_endpoint'] as String?,
    accessToken: tokenResponse['access_token'] as String,
  );

  // Find or create employee by email
  final email = userInfo['email'] as String?;
  if (email == null) {
    throw AuthException('SSO provider did not return email');
  }

  final employee = await supabase
      .from('employees')
      .select('id, email, status, induction_completed')
      .eq('email', email)
      .maybeSingle();

  if (employee == null) {
    throw NotFoundException('No employee account found for this SSO user');
  }

  if (employee['status'] != 'active') {
    throw PermissionDeniedException('Employee account is not active');
  }

  // Create session
  final session = await supabase.rpc('create_sso_session', params: {
    'p_employee_id': employee['id'],
    'p_provider_id': config['id'],
    'p_sso_subject': userInfo['sub'],
  });

  // Audit log
  await supabase.from('audit_logs').insert({
    'employee_id': employee['id'],
    'event_type': EventTypes.authLogin,
    'entity_type': 'sso_configurations',
    'entity_id': config['id'],
    'details': {'method': 'sso', 'provider': config['name']},
    'created_at': DateTime.now().toUtc().toIso8601String(),
  });

  return ApiResponse.ok({
    'session': session,
    'employee': {
      'id': employee['id'],
      'email': employee['email'],
      'induction_completed': employee['induction_completed'],
    },
  }).toResponse();
}

// Helper functions
String _generateRandomString(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = DateTime.now().millisecondsSinceEpoch;
  return List.generate(length, (i) => chars[(random + i) % chars.length]).join();
}

String _buildAuthorizationUrl({
  required String authorizationEndpoint,
  required String clientId,
  required String redirectUri,
  required List<String> scopes,
  required String state,
  required String nonce,
}) {
  final params = {
    'response_type': 'code',
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'scope': scopes.join(' '),
    'state': state,
    'nonce': nonce,
  };
  final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
  return '$authorizationEndpoint?$query';
}

Future<Map<String, dynamic>> _exchangeCodeForTokens({
  required String tokenEndpoint,
  required String clientId,
  required String clientSecret,
  required String code,
  required String redirectUri,
}) async {
  // In production, use http package to POST to token endpoint
  // This is a placeholder
  return {
    'access_token': 'placeholder_access_token',
    'id_token': 'placeholder_id_token',
    'token_type': 'Bearer',
    'expires_in': 3600,
  };
}

Future<Map<String, dynamic>> _getUserInfo({
  required String? userinfoEndpoint,
  required String accessToken,
}) async {
  // In production, call userinfo endpoint with access token
  // Or decode ID token
  return {
    'sub': 'placeholder_subject',
    'email': 'user@example.com',
    'name': 'Example User',
  };
}
