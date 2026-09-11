import 'package:aegis_vpn/core/error/app_exception.dart';
import 'package:aegis_vpn/core/storage/secure_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The mock messenger lives on the binding, which a plain `test` file does not
  // set up on its own.
  TestWidgetsFlutterBinding.ensureInitialized();

  // The plugin talks over a MethodChannel, so the store is exercised by
  // answering that channel rather than by faking the plugin's Dart class.
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final binding = TestDefaultBinaryMessengerBinding.instance;

  void answer(Future<Object?>? Function(MethodCall call) handler) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, handler);
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
    );
  }

  test('a keystore failure is reported as a LocalException, not a raw platform '
      'error', () async {
    // Left raw, a PlatformException matches nothing in `describeError` and
    // reaches the user as the catch-all "Something went wrong", which says
    // nothing about the keystore being at fault.
    answer((_) async => throw PlatformException(code: 'Unknown', message: 'Bad key'));

    final store = SecureStore(const FlutterSecureStorage());

    await expectLater(
      store.read('k'),
      throwsA(
        isA<LocalException>().having(
          (e) => e.message,
          'message',
          allOf(contains('keystore'), contains('Bad key')),
        ),
      ),
    );
  });

  test('a failed operation does not poison the ones queued behind it', () async {
    var calls = 0;
    answer((call) async {
      calls++;
      if (calls == 1) throw PlatformException(code: 'Unknown');
      return 'value';
    });

    final store = SecureStore(const FlutterSecureStorage());

    // Both are in flight before either completes, so the second is sitting in
    // the queue when the first fails.
    final first = store.read('a');
    final second = store.read('b');

    await expectLater(first, throwsA(isA<LocalException>()));
    expect(await second, 'value');
  });

  test('operations run one at a time', () async {
    // The Android plugin creates its wrapping key lazily, and concurrent access
    // while that happens can fail. Overlap is what the queue exists to prevent.
    var active = 0;
    var maxActive = 0;

    answer((_) async {
      active++;
      maxActive = active > maxActive ? active : maxActive;
      // Yields, so an unserialised implementation would let the next call in.
      await Future<void>.delayed(Duration.zero);
      active--;
      return null;
    });

    final store = SecureStore(const FlutterSecureStorage());

    await Future.wait([
      store.read('a'),
      store.write('b', '1'),
      store.delete('c'),
      store.read('d'),
    ]);

    expect(maxActive, 1);
  });
}
