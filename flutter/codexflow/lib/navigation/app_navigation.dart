import 'package:flutter/material.dart';

import '../screens/session_detail_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void openSessionChatPage(String sessionId) {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) {
    return;
  }
  navigator.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => SessionDetailScreen(sessionId: sessionId),
    ),
  );
}
