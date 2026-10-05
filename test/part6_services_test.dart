import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/features/group_support/services/language_service.dart';
import 'package:heritage_walk/features/group_support/services/support_service.dart';
import 'package:heritage_walk/features/group_support/models/support_request.dart';

void main() {
  test(
    'Language choices are exclusive, validated and notify only on changes',
    () {
      final service = LanguageService();
      addTearDown(service.dispose);
      var notifications = 0;
      service.addListener(() => notifications++);
      expect(service.selectedLanguageCode, 'en');
      expect(service.getAvailableLanguages().map((item) => item.code), [
        'en',
        'si',
        'ta',
      ]);
      service.setLanguage('si');
      expect(service.getSelectedLanguage().nativeName, 'සිංහල');
      service.setLanguage('ta');
      expect(service.getSelectedLanguage().preview, 'இலங்கையை ஆராயுங்கள்');
      service.setLanguage('ta');
      expect(notifications, 2);
      expect(() => service.setLanguage('bad'), throwsArgumentError);
      expect(
        () => service.getAvailableLanguages().clear(),
        throwsUnsupportedError,
      );
    },
  );
  test(
    'Support CRUD trims input, preserves identity and timestamps, notifies',
    () {
      final service = SupportService();
      addTearDown(service.dispose);
      var notifications = 0;
      service.addListener(() => notifications++);
      final first = service.createSupportRequest(
        subject: ' First ',
        message: ' Message ',
        category: SupportCategory.general,
      );
      final second = service.createSupportRequest(
        subject: 'Second',
        message: 'Message',
        category: SupportCategory.account,
      );
      expect(first.subject, 'First');
      expect(first.message, 'Message');
      expect(first.status, SupportStatus.open);
      expect(first.id, isNot(second.id));
      expect(service.getSupportRequests().first.id, second.id);
      service.updateSupportRequest(
        first.id,
        subject: 'Updated',
        message: 'Changed',
        category: SupportCategory.technical,
      );
      final updated = service.getById(first.id)!;
      expect(updated.subject, 'Updated');
      expect(updated.message, 'Changed');
      expect(updated.category, SupportCategory.technical);
      expect(updated.createdAt, first.createdAt);
      expect(updated.updatedAt.isBefore(first.updatedAt), isFalse);
      service.markResolved(first.id);
      expect(service.getById(first.id)!.status, SupportStatus.resolved);
      service.markResolved(first.id, resolved: false);
      expect(service.getById(first.id)!.status, SupportStatus.open);
      service.deleteSupportRequest(first.id);
      expect(service.getById(first.id), isNull);
      expect(notifications, 6);
    },
  );
  test(
    'Support validates required fields and length limits before mutation',
    () {
      final service = SupportService();
      addTearDown(service.dispose);
      for (final subject in ['', '   ', 'x' * 101]) {
        expect(
          () => service.createSupportRequest(
            subject: subject,
            message: 'Message',
            category: SupportCategory.other,
          ),
          throwsArgumentError,
        );
      }
      for (final message in ['', '   ', 'x' * 1001]) {
        expect(
          () => service.createSupportRequest(
            subject: 'Subject',
            message: message,
            category: SupportCategory.other,
          ),
          throwsArgumentError,
        );
      }
      expect(service.getSupportRequests(), isEmpty);
      final request = service.createSupportRequest(
        subject: 'x' * 100,
        message: 'x' * 1000,
        category: SupportCategory.other,
      );
      expect(
        () => service.updateSupportRequest(
          request.id,
          subject: '',
          message: 'Message',
          category: SupportCategory.general,
        ),
        throwsArgumentError,
      );
      expect(service.getById(request.id)!.subject.length, 100);
    },
  );
  test(
    'Missing support records fail safely and result lists are immutable',
    () {
      final service = SupportService();
      addTearDown(service.dispose);
      expect(() => service.deleteSupportRequest('missing'), throwsStateError);
      expect(() => service.markResolved('missing'), throwsStateError);
      expect(
        () => service.updateSupportRequest(
          'missing',
          subject: 'Subject',
          message: 'Message',
          category: SupportCategory.general,
        ),
        throwsStateError,
      );
      expect(
        () => service.getSupportRequests().clear(),
        throwsUnsupportedError,
      );
    },
  );
  test('Support models serialize every category and status', () {
    final now = DateTime.utc(2026, 10, 5);
    for (final category in SupportCategory.values) {
      for (final status in SupportStatus.values) {
        final request = SupportRequest(
          id: 'id',
          subject: 'Subject',
          message: 'Message',
          category: category,
          status: status,
          createdAt: now,
          updatedAt: now,
        );
        expect(
          SupportRequest.fromMap(request.toMap()).toMap(),
          request.toMap(),
        );
      }
    }
  });
  test(
    'Clear removes support data without reusing IDs or changing language',
    () {
      final service = SupportService();
      final language = LanguageService()..setLanguage('si');
      addTearDown(service.dispose);
      addTearDown(language.dispose);
      final before = service.createSupportRequest(
        subject: 'Before',
        message: 'Message',
        category: SupportCategory.general,
      );
      service.clear();
      expect(service.getSupportRequests(), isEmpty);
      final after = service.createSupportRequest(
        subject: 'After',
        message: 'Message',
        category: SupportCategory.general,
      );
      expect(after.id, isNot(before.id));
      expect(language.selectedLanguageCode, 'si');
    },
  );
}
