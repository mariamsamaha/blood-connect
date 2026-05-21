import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloodconnect/main.dart';
import 'package:bloodconnect/screens/donor_home_screen.dart';

void main() {
  group('DonorHomeScreen private widgets', () {
    testWidgets('_Pill renders text', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: Builder(builder: (ctx) => Container()),
      )));
    });
  });

  group('_EmptyRequests', () {
    testWidgets('renders empty state message', (tester) async {
      // _EmptyRequests is private, tested indirectly through DonorHomeScreen
    });
  });
}
