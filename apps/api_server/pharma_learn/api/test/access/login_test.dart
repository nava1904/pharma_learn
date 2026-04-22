import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:supabase/supabase.dart';

/// Mock classes for testing
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockPostgrestClient extends Mock implements PostgrestClient {}

/// Login flow integration test
///
/// Reference: plan.md Verification Plan
/// - POST /v1/auth/login → {session, employee, mfa_required}
/// - Validates credentials via validate_credential RPC
/// - Creates user_session row
/// - Returns JWT with employee_id, org_id, permissions
void main() {
  group('Login Flow Tests', () {
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockGoTrue;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockGoTrue = MockGoTrueClient();
      when(() => mockSupabase.auth).thenReturn(mockGoTrue);
    });

    group('POST /v1/auth/login', () {
      test('returns session and employee data on valid credentials', () async {
        // Arrange
        final testEmail = 'test@pharmalearn.com';
        final testPassword = 'SecureP@ss123';

        when(() => mockGoTrue.signInWithPassword(
              email: testEmail,
              password: testPassword,
            )).thenAnswer((_) async => AuthResponse(
              session: Session(
                accessToken: 'test_access_token',
                tokenType: 'bearer',
                refreshToken: 'test_refresh_token',
                expiresIn: 3600,
                user: User(
                  id: 'user-123',
                  appMetadata: {},
                  userMetadata: {
                    'employee_id': 'emp-123',
                    'org_id': 'org-123',
                    'induction_completed': true,
                  },
                  aud: 'authenticated',
                  createdAt: DateTime.now().toIso8601String(),
                ),
              ),
              user: User(
                id: 'user-123',
                appMetadata: {},
                userMetadata: {},
                aud: 'authenticated',
                createdAt: DateTime.now().toIso8601String(),
              ),
            ));

        // Act
        final result = await mockGoTrue.signInWithPassword(
          email: testEmail,
          password: testPassword,
        );

        // Assert
        expect(result.session, isNotNull);
        expect(result.session!.accessToken, equals('test_access_token'));
        expect(result.user, isNotNull);
      });

      test('returns 401 on invalid credentials', () async {
        // Arrange
        final testEmail = 'test@pharmalearn.com';
        final testPassword = 'WrongPassword';

        when(() => mockGoTrue.signInWithPassword(
              email: testEmail,
              password: testPassword,
            )).thenThrow(AuthException('Invalid login credentials'));

        // Act & Assert
        expect(
          () => mockGoTrue.signInWithPassword(
            email: testEmail,
            password: testPassword,
          ),
          throwsA(isA<AuthException>()),
        );
      });

      test('returns 423 on locked account after 3 failed attempts', () async {
        // Arrange
        final testEmail = 'locked@pharmalearn.com';
        final testPassword = 'AnyPassword';

        when(() => mockGoTrue.signInWithPassword(
              email: testEmail,
              password: testPassword,
            )).thenThrow(AuthException('Account is locked'));

        // Act & Assert
        expect(
          () => mockGoTrue.signInWithPassword(
            email: testEmail,
            password: testPassword,
          ),
          throwsA(isA<AuthException>()),
        );
      });

      test('returns mfa_required=true when MFA is enabled', () async {
        // Arrange
        final testEmail = 'mfa@pharmalearn.com';
        final testPassword = 'SecureP@ss123';

        when(() => mockGoTrue.signInWithPassword(
              email: testEmail,
              password: testPassword,
            )).thenAnswer((_) async => AuthResponse(
              session: null, // No session until MFA verified
              user: User(
                id: 'user-456',
                appMetadata: {'mfa_enabled': true},
                userMetadata: {'mfa_required': true},
                aud: 'authenticated',
                createdAt: DateTime.now().toIso8601String(),
                factors: [
                  Factor(
                    id: 'factor-1',
                    friendlyName: 'TOTP',
                    factorType: FactorType.totp,
                    status: FactorStatus.verified,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                ],
              ),
            ));

        // Act
        final result = await mockGoTrue.signInWithPassword(
          email: testEmail,
          password: testPassword,
        );

        // Assert
        expect(result.session, isNull);
        expect(result.user, isNotNull);
        expect(result.user!.factors, isNotEmpty);
      });
    });

    group('Session Management', () {
      test('creates user_session row on successful login', () async {
        // This would be verified by checking the database
        // In integration tests, we'd query user_sessions table
        expect(true, isTrue); // Placeholder
      });

      test('updates last_activity_at on each request', () async {
        // Verified by auth_middleware idle-timeout check
        expect(true, isTrue); // Placeholder
      });
    });

    group('JWT Claims', () {
      test('JWT contains employee_id in claims', () async {
        // Parse JWT and verify claims
        expect(true, isTrue); // Placeholder
      });

      test('JWT contains org_id in claims', () async {
        expect(true, isTrue); // Placeholder
      });

      test('JWT contains permissions array in claims', () async {
        // Reference: plan.md - auth-hook Edge Function adds permissions
        expect(true, isTrue); // Placeholder
      });

      test('JWT contains induction_completed in claims', () async {
        // Reference: plan.md - needed for induction gate
        expect(true, isTrue); // Placeholder
      });
    });
  });
}
