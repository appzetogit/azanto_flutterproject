import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/quick/ui/screens/profile/privacy_policy/legal_document_screen.dart';

void main() {
  test('CMS rich text renders as plain paragraphs', () {
    expect(
      plainTextFromHtml('<p>Hello <b>there</b></p><p>Second</p>'),
      'Hello there\nSecond',
    );
    expect(plainTextFromHtml('a<br/>b'), 'a\nb');
    expect(plainTextFromHtml('  plain  '), 'plain');
  });
}
