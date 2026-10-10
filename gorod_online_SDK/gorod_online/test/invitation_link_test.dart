import 'package:flutter_test/flutter_test.dart';
import 'package:gorod_online/invitation_link.dart';

void main() {
  test('extracts and normalizes a short invitation path', () {
    expect(
      invitationCodeFromUri(Uri.parse('https://gorod-online.com/aB1234')),
      'AB1234',
    );
  });

  test('supports the earlier fragment invitation format', () {
    expect(
      invitationCodeFromUri(Uri.parse('https://gorod-online.com/#123654')),
      '123654',
    );
  });

  test('ignores regular site routes and malformed codes', () {
    expect(
      invitationCodeFromUri(Uri.parse('https://gorod-online.com/catalog')),
      null,
    );
    expect(
      invitationCodeFromUri(Uri.parse('https://gorod-online.com/bad-code')),
      null,
    );
    expect(
      invitationCodeFromUri(
        Uri(scheme: 'https', host: 'gorod-online.com', path: '%'),
      ),
      null,
    );
  });
}
