import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/config/app_config.dart';
import 'package:singlearn/features/social/domain/social_models.dart';

void main() {
  test('optional cloud services are disabled by default', () {
    expect(AppConfig.storageEnabled, isFalse);
    expect(AppConfig.messagingEnabled, isFalse);
    expect(AppConfig.googleSignInEnabled, isFalse);
  });

  test('cloud serialization excludes email but local search retains it', () {
    const profile = PublicProfile(
      uid: 'learner',
      displayName: 'Learner',
      userCode: 'ABC123',
      email: 'private@example.invalid',
      xp: 10,
    );
    final cloud = profile.toCloudJson();
    expect(cloud, isNot(contains('email')));
    expect(cloud['xp'], 10);
    expect(PublicProfile.fromJson(cloud).email, isEmpty);
    expect(profile.toJson()['email'], 'private@example.invalid');
  });
}
