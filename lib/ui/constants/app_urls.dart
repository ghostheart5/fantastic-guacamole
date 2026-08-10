import 'package:fantastic_guacamole/config/env.dart';

class AppUrls {
  // Web
  static const String website = Env.publicWebsiteUrl;
  static const String privacy = Env.privacyPolicyUrl;
  static const String deleteAccount = Env.deleteAccountUrl;
  static const String terms = Env.termsOfServiceUrl;
  static const String support = Env.supportUrl;
  static const String changelog = '${Env.publicWebsiteUrl}/changelog/';

  // App stores
  static const String googlePlay =
      'https://play.google.com/store/apps/details?id=com.ghostheart5.chronospark';
  static const String appStore =
      'https://apps.apple.com/app/chronospark/id6746118744';

  // Deep link scheme
  static const String deepLinkScheme = 'chronospark';
  static const String deepLinkBase = '${Env.productionAppLinkOrigin}/app/';
  static const String authCallback = Env.productionAuthCallbackUrl;
}
