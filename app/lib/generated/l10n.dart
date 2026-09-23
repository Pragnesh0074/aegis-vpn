// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Kill switch`
  String get killSwitchTitle {
    return Intl.message(
      'Kill switch',
      name: 'killSwitchTitle',
      desc: 'Title for the Kill Switch screen',
      args: [],
    );
  }

  /// `No VPN settings screen on this device.`
  String get noVpnSettingsScreen {
    return Intl.message(
      'No VPN settings screen on this device.',
      name: 'noVpnSettingsScreen',
      desc: 'Error message when the system VPN settings cannot be opened',
      args: [],
    );
  }

  /// `Reconnect if it drops`
  String get reconnectTitle {
    return Intl.message(
      'Reconnect if it drops',
      name: 'reconnectTitle',
      desc: 'Title for the auto-reconnect card',
      args: [],
    );
  }

  /// `If the tunnel goes down without you asking — a lost network, the system reclaiming the VPN — Aegis brings it straight back, up to five times with a growing delay.`
  String get reconnectBody {
    return Intl.message(
      'If the tunnel goes down without you asking — a lost network, the system reclaiming the VPN — Aegis brings it straight back, up to five times with a growing delay.',
      name: 'reconnectBody',
      desc: 'Description of the auto-reconnect functionality',
      args: [],
    );
  }

  /// `Always on`
  String get alwaysOn {
    return Intl.message(
      'Always on',
      name: 'alwaysOn',
      desc: 'Status badge label indicating auto-reconnect is active',
      args: [],
    );
  }

  /// `Block traffic while the VPN is off`
  String get blockTrafficTitle {
    return Intl.message(
      'Block traffic while the VPN is off',
      name: 'blockTrafficTitle',
      desc: 'Title for the system-level traffic blocking card',
      args: [],
    );
  }

  /// `This one is not ours to switch. Android will not let an app block the whole device's traffic — only the system can, and it is the only thing that covers you after a reboot or once Aegis has been swiped away.`
  String get blockTrafficBody {
    return Intl.message(
      'This one is not ours to switch. Android will not let an app block the whole device\'s traffic — only the system can, and it is the only thing that covers you after a reboot or once Aegis has been swiped away.',
      name: 'blockTrafficBody',
      desc: 'Explanation of Android\'s OS-level traffic blocking requirement',
      args: [],
    );
  }

  /// `Without it, traffic uses your normal connection whenever the tunnel is down.`
  String get blockTrafficNote {
    return Intl.message(
      'Without it, traffic uses your normal connection whenever the tunnel is down.',
      name: 'blockTrafficNote',
      desc: 'Warning note when system kill switch is not configured',
      args: [],
    );
  }

  /// `Open Android's VPN settings with the button below.`
  String get stepOpenSettings {
    return Intl.message(
      'Open Android\'s VPN settings with the button below.',
      name: 'stepOpenSettings',
      desc: 'Step 1 for setting up system kill switch',
      args: [],
    );
  }

  /// `Tap the gear next to Aegis.`
  String get stepTapGear {
    return Intl.message(
      'Tap the gear next to Aegis.',
      name: 'stepTapGear',
      desc: 'Step 2 for setting up system kill switch',
      args: [],
    );
  }

  /// `Turn on "Always-on VPN".`
  String get stepTurnOnAlwaysOn {
    return Intl.message(
      'Turn on "Always-on VPN".',
      name: 'stepTurnOnAlwaysOn',
      desc: 'Step 3 for setting up system kill switch',
      args: [],
    );
  }

  /// `Turn on "Block connections without VPN".`
  String get stepTurnOnBlockConnections {
    return Intl.message(
      'Turn on "Block connections without VPN".',
      name: 'stepTurnOnBlockConnections',
      desc: 'Step 4 for setting up system kill switch',
      args: [],
    );
  }

  /// `Open Android VPN settings`
  String get openSettingsButton {
    return Intl.message(
      'Open Android VPN settings',
      name: 'openSettingsButton',
      desc: 'Label on the button that opens Android\'s VPN settings',
      args: [],
    );
  }

  /// `Some phones bury this under Settings → Connections → More → VPN.`
  String get openSettingsHint {
    return Intl.message(
      'Some phones bury this under Settings → Connections → More → VPN.',
      name: 'openSettingsHint',
      desc:
          'Hint text for navigating to VPN settings on various Android OEM devices',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[Locale.fromSubtags(languageCode: 'en')];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
