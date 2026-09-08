import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/auth_service.dart';

void main() {
  test('session expires within the renewal window', () {
    final session = AuthSession(
      accessToken: 'access-token',
      idToken: 'id-token',
      expiresAt: DateTime.utc(2026, 1, 1, 0, 0, 29),
    );

    expect(session.isExpiring(now: DateTime.utc(2026)), isTrue);
  });

  test('session JSON round trip preserves tokens and expiry', () {
    final session = AuthSession(
      accessToken: 'access-token',
      idToken: 'id-token',
      expiresAt: DateTime.utc(2026, 1, 1, 1),
    );

    final restored = AuthSession.fromJson(session.toJson());

    expect(restored.accessToken, 'access-token');
    expect(restored.idToken, 'id-token');
    expect(restored.expiresAt, DateTime.utc(2026, 1, 1, 1));
  });
}
