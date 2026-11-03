# R8 keep rules for the release build.
#
# Without these, `flutter build apk --release` fails outright at
# :app:minifyReleaseWithR8 with "Missing classes detected". Debug builds do not
# run R8, which is why this only ever surfaces on a release build.

# google_mlkit_text_recognition references every script variant from its
# initialize() switch, but only the Latin recognizer is bundled. The other
# options classes are genuinely absent and never reached at runtime.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder

# firebase-iid is excluded in build.gradle.kts to resolve a duplicate-class
# clash with firebase-messaging; ML Kit's link-firebase module still references
# it from a code path this app does not use.
-dontwarn com.google.firebase.iid.FirebaseInstanceId
