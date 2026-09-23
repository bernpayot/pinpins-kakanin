import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/app_theme.dart';

void main() {
  test('Pinpins theme owns typography and component styling', () {
    final theme = pinpinsTheme();

    expect(theme.textTheme.bodyMedium?.fontFamily, 'PinpinsSans');
    expect(theme.textTheme.headlineLarge?.fontFamily, 'PinpinsSerif');
    expect(theme.scaffoldBackgroundColor, PinpinsColors.cream);
    expect(theme.cardTheme.color, PinpinsColors.paper);
    expect(
      theme.filledButtonTheme.style?.backgroundColor?.resolve({}),
      PinpinsColors.brown,
    );
    expect(theme.searchBarTheme.side?.resolve({})?.color, PinpinsColors.border);
    expect(theme.datePickerTheme.headerBackgroundColor, PinpinsColors.deepLeaf);
    expect(theme.snackBarTheme.backgroundColor, PinpinsColors.deepLeaf);
  });

  testWidgets('the custom controls fit a narrow screen at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: pinpinsTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('Neneng and Andy Kakanin Store')),
          body: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              const SearchBar(hintText: 'Search products'),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Freshly cooked for the date you choose'),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {},
                child: const Text('Start your pre-order'),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                label: 'Products',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_circle_outlined),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('body and heading text inherit bundled font families', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: pinpinsTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const Text('Body copy'),
                Text(
                  'Heading',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final bodyContext = tester.element(find.text('Body copy'));
    expect(DefaultTextStyle.of(bodyContext).style.fontFamily, 'PinpinsSans');
    expect(
      tester.widget<Text>(find.text('Heading')).style?.fontFamily,
      'PinpinsSerif',
    );
  });
}
