// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "alwaysOn": MessageLookupByLibrary.simpleMessage("Always on"),
    "blockTrafficBody": MessageLookupByLibrary.simpleMessage(
      "This one is not ours to switch. Android will not let an app block the whole device\'s traffic — only the system can, and it is the only thing that covers you after a reboot or once Aegis has been swiped away.",
    ),
    "blockTrafficNote": MessageLookupByLibrary.simpleMessage(
      "Without it, traffic uses your normal connection whenever the tunnel is down.",
    ),
    "blockTrafficTitle": MessageLookupByLibrary.simpleMessage(
      "Block traffic while the VPN is off",
    ),
    "killSwitchTitle": MessageLookupByLibrary.simpleMessage("Kill switch"),
    "noVpnSettingsScreen": MessageLookupByLibrary.simpleMessage(
      "No VPN settings screen on this device.",
    ),
    "openSettingsButton": MessageLookupByLibrary.simpleMessage(
      "Open Android VPN settings",
    ),
    "openSettingsHint": MessageLookupByLibrary.simpleMessage(
      "Some phones bury this under Settings → Connections → More → VPN.",
    ),
    "reconnectBody": MessageLookupByLibrary.simpleMessage(
      "If the tunnel goes down without you asking — a lost network, the system reclaiming the VPN — Aegis brings it straight back, up to five times with a growing delay.",
    ),
    "reconnectTitle": MessageLookupByLibrary.simpleMessage(
      "Reconnect if it drops",
    ),
    "stepOpenSettings": MessageLookupByLibrary.simpleMessage(
      "Open Android\'s VPN settings with the button below.",
    ),
    "stepTapGear": MessageLookupByLibrary.simpleMessage(
      "Tap the gear next to Aegis.",
    ),
    "stepTurnOnAlwaysOn": MessageLookupByLibrary.simpleMessage(
      "Turn on \"Always-on VPN\".",
    ),
    "stepTurnOnBlockConnections": MessageLookupByLibrary.simpleMessage(
      "Turn on \"Block connections without VPN\".",
    ),
  };
}
