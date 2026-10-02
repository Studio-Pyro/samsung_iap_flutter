import 'package:flutter_test/flutter_test.dart';
import 'package:samsung_iap_flutter_android/src/parsing.dart';
import 'package:samsung_iap_flutter_platform_interface/samsung_iap_flutter_platform_interface.dart';

void main() {
  test('finiteOrNull drops the NaN of a missing price', () {
    final cases = <double?, double?>{
      7.99: 7.99,
      0: 0,
      double.nan: null,
      double.infinity: null,
      null: null,
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      expect(finiteOrNull(input), expected, reason: '$input');
    }
  });

  test('parseYesNo', () {
    final cases = <String, bool?>{'Y': true, 'N': false, '': null, 'y': null};
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      expect(parseYesNo(input), expected, reason: input);
    }
  });

  group('parseLocalDateTime', () {
    test('reads the SDK format as local time', () {
      expect(
        parseLocalDateTime('2026-03-29 01:30:05'),
        DateTime(2026, 3, 29, 1, 30, 5),
      );
      expect(parseLocalDateTime('2026-03-29 01:30:05')!.isUtc, isFalse);
    });

    test('returns null for anything but the SDK format', () {
      for (final input in [
        '',
        '2026-03-29',
        '2026-03-29T01:30:05',
        '2026-03-29 01:30:05Z',
        '٢٠٢٦-٠٣-٢٩ ٠١:٣٠:٠٥',
      ]) {
        expect(parseLocalDateTime(input), isNull, reason: input);
      }
    });

    test('returns null for the epoch the SDK writes for a missing date', () {
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      String two(int n) => n.toString().padLeft(2, '0');
      final formatted =
          '${epoch.year}-${two(epoch.month)}-${two(epoch.day)} '
          '${two(epoch.hour)}:${two(epoch.minute)}:${two(epoch.second)}';

      expect(parseLocalDateTime(formatted), isNull);
    });
  });

  test('parseUri', () {
    expect(parseUri(''), isNull);
    expect(parseUri('http://[::1'), isNull);
    expect(
      parseUri('https://img.samsungapps.com/a.png'),
      Uri.parse('https://img.samsungapps.com/a.png'),
    );
  });

  test('nonEmptyOrNull', () {
    expect(nonEmptyOrNull(''), isNull);
    expect(nonEmptyOrNull(' '), ' ');
    expect(nonEmptyOrNull('account'), 'account');
  });

  test('parseAcknowledgedStatus', () {
    final cases = {
      'UNSUPPORTED': AcknowledgedStatus.unsupported,
      'NOT_ACKNOWLEDGED': AcknowledgedStatus.notAcknowledged,
      'ACKNOWLEDGED': AcknowledgedStatus.acknowledged,
      '': AcknowledgedStatus.unknown,
      'Y': AcknowledgedStatus.unknown,
      'acknowledged': AcknowledgedStatus.unknown,
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      expect(parseAcknowledgedStatus(input), expected, reason: input);
    }
  });

  test('parseMinorStatus', () {
    final cases = {
      'UNIDENTIFIED': MinorStatus.unidentified,
      'NOT_MINOR': MinorStatus.notMinor,
      'MINOR': MinorStatus.minor,
      '': MinorStatus.unknown,
      'Y': MinorStatus.unknown,
      'minor': MinorStatus.unknown,
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      expect(parseMinorStatus(input), expected, reason: input);
    }
  });

  test('parsePriceChangeMode', () {
    final cases = {
      'PRICE_INCREASE_USER_AGREEMENT_REQUIRED':
          PriceChangeMode.increaseConsentRequired,
      'PRICE_INCREASE_NO_USER_AGREEMENT_REQUIRED':
          PriceChangeMode.increaseNoConsentRequired,
      'PRICE_DECREASE': PriceChangeMode.decrease,
      '': PriceChangeMode.unknown,
      '0': PriceChangeMode.unknown,
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      expect(parsePriceChangeMode(input), expected, reason: input);
    }
  });

  test('parseProductType', () {
    final cases = {
      'item': SamsungProductType.item,
      'subscription': SamsungProductType.subscription,
      '': SamsungProductType.unknown,
      'bundle': SamsungProductType.unknown,
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      expect(parseProductType(input), expected, reason: input);
    }
  });

  test('parsePeriodUnit', () {
    final cases = {
      'WEEK': PeriodUnit.week,
      'MONTH': PeriodUnit.month,
      'YEAR': PeriodUnit.year,
      'DAY': PeriodUnit.unknown,
      'month': PeriodUnit.unknown,
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      expect(parsePeriodUnit(input), expected, reason: input);
    }
  });

  test('parseSubscriptionPeriod', () {
    final cases = <(String, String), SubscriptionPeriod?>{
      ('1', 'MONTH'): const SubscriptionPeriod(
        count: 1,
        unit: PeriodUnit.month,
      ),
      ('3', 'WEEK'): const SubscriptionPeriod(count: 3, unit: PeriodUnit.week),
      ('2', 'DAY'): const SubscriptionPeriod(
        count: 2,
        unit: PeriodUnit.unknown,
      ),
      ('', ''): null,
      ('', 'MONTH'): null,
      ('1', ''): null,
      ('one', 'MONTH'): null,
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      expect(
        parseSubscriptionPeriod(multiplier: input.$1, unit: input.$2),
        expected,
        reason: '$input',
      );
    }
  });
}
