import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lecturer_companion/features/auth/auth.dart';

void main() {
  test(
    'Native configuration error identifies package and signing setup safely',
    () {
      final message = signInErrorMessage(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
          description: 'private details',
        ),
      );
      expect(message, contains('SHA-1'));
      expect(message, isNot(contains('private details')));
    },
  );
  test('Cancellation does not assume the user intentionally cancelled', () {
    expect(
      signInErrorMessage(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      ),
      contains('If you did not cancel'),
    );
  });
}
