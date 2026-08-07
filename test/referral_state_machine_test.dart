import 'package:flutter_test/flutter_test.dart';
import 'package:retinascreen/models/enums.dart';

void main() {
  group('ReferralStatus.nextStates', () {
    test('none -> referred only', () {
      expect(ReferralStatus.none.nextStates, {ReferralStatus.referred});
    });

    test('referred -> booked OR attended (walk-in skip)', () {
      expect(
        ReferralStatus.referred.nextStates,
        {ReferralStatus.booked, ReferralStatus.attended},
      );
    });

    test('booked -> attended only', () {
      expect(ReferralStatus.booked.nextStates, {ReferralStatus.attended});
    });

    test('attended -> treated only', () {
      expect(ReferralStatus.attended.nextStates, {ReferralStatus.treated});
    });

    test('treated is terminal', () {
      expect(ReferralStatus.treated.nextStates, isEmpty);
    });
  });

  group('canTransitionTo', () {
    test('allows every legal edge', () {
      for (final from in ReferralStatus.values) {
        for (final to in from.nextStates) {
          expect(from.canTransitionTo(to), isTrue, reason: '$from -> $to');
        }
      }
    });

    test('rejects skipping past attended (referred -> treated)', () {
      expect(
        ReferralStatus.referred.canTransitionTo(ReferralStatus.treated),
        isFalse,
      );
    });

    test('rejects moving backwards (attended -> referred)', () {
      expect(
        ReferralStatus.attended.canTransitionTo(ReferralStatus.referred),
        isFalse,
      );
    });

    test('rejects self-transition', () {
      expect(
        ReferralStatus.booked.canTransitionTo(ReferralStatus.booked),
        isFalse,
      );
    });
  });

  group('hasReachedClinic', () {
    test('true only for attended and treated', () {
      expect(ReferralStatus.attended.hasReachedClinic, isTrue);
      expect(ReferralStatus.treated.hasReachedClinic, isTrue);
    });

    test('booked has NOT reached the clinic (the whole point)', () {
      expect(ReferralStatus.booked.hasReachedClinic, isFalse);
    });

    test('none and referred have not reached the clinic', () {
      expect(ReferralStatus.none.hasReachedClinic, isFalse);
      expect(ReferralStatus.referred.hasReachedClinic, isFalse);
    });
  });

  test('InvalidReferralTransition message lists allowed next states', () {
    final e = InvalidReferralTransition(
      ReferralStatus.referred,
      ReferralStatus.treated,
    );
    expect(e.toString(), contains('referred'));
    expect(e.toString(), contains('treated'));
    expect(e.toString(), contains('booked')); // an allowed next state
  });
}
