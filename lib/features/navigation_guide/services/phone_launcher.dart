import 'package:url_launcher/url_launcher.dart';

import '../../../core/firebase/backend_error.dart';
import '../models/emergency_contact.dart';

abstract interface class PhoneLauncher {
  Future<bool> openDialer(Uri uri);
}

class DevicePhoneLauncher implements PhoneLauncher {
  @override
  Future<bool> openDialer(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> dialContact(
  EmergencyContact contact,
  PhoneLauncher launcher,
) async {
  final number = EmergencyValidation.normalizedPhone(contact.phoneNumber);
  if (!contact.isActive || !contact.isVerified || number == null) {
    throw const BackendFailure(
      'This contact is unavailable or has an invalid number.',
    );
  }
  try {
    if (!await launcher.openDialer(Uri(scheme: 'tel', path: number))) {
      throw const BackendFailure(
        'No phone dialer is available on this device.',
      );
    }
  } on BackendFailure {
    rethrow;
  } catch (_) {
    throw const BackendFailure(
      'Unable to open the phone dialer. Try a device with a phone app.',
    );
  }
}
