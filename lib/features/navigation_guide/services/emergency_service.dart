import '../models/emergency_contact.dart';

class EmergencyService {
  List<EmergencyContact> getContacts() => const [
    EmergencyContact(
      id: 'police',
      name: 'Police',
      description: 'Verified contact data is not connected yet.',
    ),
    EmergencyContact(
      id: 'ambulance',
      name: 'Ambulance / Medical',
      description: 'Verified contact data is not connected yet.',
    ),
    EmergencyContact(
      id: 'tourist',
      name: 'Tourist Assistance',
      description: 'Verified contact data is not connected yet.',
    ),
    EmergencyContact(
      id: 'medical',
      name: 'Nearest Medical Facility',
      description:
          'A verified nearby facility will require location integration.',
    ),
  ];
  static const callingMessage =
      'Calling functionality will be connected during device integration.';
  static const sharingMessage =
      'To share location, open a group and start sharing in Group Tracking.';
}
