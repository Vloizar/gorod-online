/// Extracts an invitation code from links such as
/// `https://gorod-online.com/123456` or the earlier `/#123456` format.
String? invitationCodeFromUri(Uri uri) {
  final candidate = uri.fragment.isNotEmpty
      ? uri.fragment
      : uri.pathSegments.isEmpty
      ? ''
      : uri.pathSegments.last;
  late final String decoded;
  try {
    decoded = Uri.decodeComponent(candidate);
  } catch (_) {
    return null;
  }
  final code = decoded.trim().toUpperCase();
  if (code.length < 4 || code.length > 32) return null;
  final isNumericCode = RegExp(r'^[0-9]{4,32}$').hasMatch(code);
  final isLetterPrefixedCode = RegExp(r'^[A-ZА-ЯЁ]+[0-9]{4,6}$').hasMatch(code);
  if (!isNumericCode && !isLetterPrefixedCode) return null;
  return code;
}
