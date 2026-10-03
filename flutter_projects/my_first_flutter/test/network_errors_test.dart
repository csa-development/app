import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_first_flutter/services/api_service.dart';
import 'package:my_first_flutter/widgets/offline_banner.dart';

void main() {
  group('ApiService.failureFor', () {
    test('network failure while the phone has no network -> offline', () {
      for (final error in [
        const SocketException('no route'),
        http.ClientException('failed'),
      ]) {
        final result = ApiService.failureFor(error, offline: true);
        expect(result['kind'], 'offline');
        expect(result['error'], startsWith('No internet connection.'));
        expect(result['success'], false);
      }
    });

    test('network failure while the phone has a network -> CSA side', () {
      for (final error in [
        const SocketException('refused'),
        http.ClientException('failed'),
        HandshakeException('bad cert'),
      ]) {
        final result = ApiService.failureFor(error, offline: false);
        expect(result['kind'], 'server');
        expect(result['error'], startsWith("We're having trouble reaching CSA"));
      }
    });

    test('unreadable reply (e.g. HTML error page) -> CSA side, even if offline flag is wrong', () {
      expect(
        ApiService.failureFor(const FormatException('<html>'), offline: false)['kind'],
        'server',
      );
      expect(
        ApiService.failureFor(const FormatException('<html>'), offline: true)['kind'],
        'server',
      );
    });

    test('anything else -> generic message that does not blame the connection', () {
      final result = ApiService.failureFor(StateError('bug'), offline: false);
      expect(result['kind'], 'unknown');
      expect(result['error'], 'Something went wrong. Please try again.');
    });
  });

  group('OfflineBanner', () {
    Future<ValueNotifier<bool>> pumpApp(WidgetTester tester) async {
      final offline = ValueNotifier<bool>(false);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              OfflineBanner(offline: offline, child: child!),
          home: Scaffold(appBar: AppBar(title: const Text('Home'))),
        ),
      );
      return offline;
    }

    testWidgets('hidden while online', (tester) async {
      await pumpApp(tester);
      expect(find.textContaining("You're offline"), findsNothing);
    });

    testWidgets('appears when offline and floats over the screen without moving it',
        (tester) async {
      final offline = await pumpApp(tester);
      final titleTopOnline = tester.getTopLeft(find.text('Home')).dy;

      offline.value = true;
      await tester.pumpAndSettle();

      expect(find.textContaining("You're offline"), findsOneWidget);
      expect(tester.getTopLeft(find.text('Home')).dy, titleTopOnline);
    });

    testWidgets('disappears again when the connection returns', (tester) async {
      final offline = await pumpApp(tester);
      final titleTopOnline = tester.getTopLeft(find.text('Home')).dy;

      offline.value = true;
      await tester.pumpAndSettle();
      offline.value = false;
      await tester.pumpAndSettle();

      expect(find.textContaining("You're offline"), findsNothing);
      expect(tester.getTopLeft(find.text('Home')).dy, titleTopOnline);
    });
  });
}
