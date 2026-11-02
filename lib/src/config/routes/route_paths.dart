/// Every location in the app, in one place.
abstract final class RoutePaths {
  static const home = '/home';
  static const settings = '/settings';
  static const system = '$home/system';

  static const gallery = '/gallery';
  static String galleryEntry(String id) => '$gallery/$id';

  static const lab = '/lab';
  static String labEntry(String id) => '$lab/$id';

  static const flows = '/flows';
  static const checkout = '$flows/checkout';
  static const onboarding = '$flows/onboarding';
  static const chat = '$flows/chat';

  static const studio = '/studio';
}
