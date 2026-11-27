import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:una/una.dart';
import 'package:una_banking/main.dart';
import 'package:una_banking/navigation.dart';
import 'package:una_banking/session.dart';
import 'package:una_banking/shell.dart';

/// A desktop window, a tablet held upright and a phone.
const desktopSize = Size(1440, 900);
const tabletSize = Size(768, 1024);
const phoneSize = Size(375, 812);

/// The `setUpAll` of every test that builds the app: no font fetching in
/// tests, so the text is set in the test font.
Future<void> setUpFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// Pumps fixed frames: entrances, springs and charts animate for a while,
/// and `pumpAndSettle` is not to be relied on here.
Future<void> settle(WidgetTester tester, {int frames = 14}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps the whole [App] in a window of [size], light or dark, past the
/// first frames.
Future<void> pumpApp(
  WidgetTester tester, {
  Size size = desktopSize,
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const App());
  themeModeProvider.of(appContext(tester)).value = brightness == Brightness.dark
      ? ThemeMode.dark
      : ThemeMode.light;
  await settle(tester, frames: 24);
}

/// A context below the app's providers, theme and session: the shell's,
/// which stays mounted under any page pushed over it.
BuildContext appContext(WidgetTester tester) =>
    tester.element(find.byType(BankShell, skipOffstage: false));

/// The session the app is running on.
BankSession sessionOf(WidgetTester tester) => appContext(tester).bank;

/// Shows [destination] and waits out the switch.
Future<void> goTo(WidgetTester tester, Destination destination) async {
  appContext(tester).goTo(destination);
  await settle(tester);
}

/// Pushes [builder]'s page and waits out its entrance.
Future<void> push(WidgetTester tester, WidgetBuilder builder) async {
  appContext(tester).pushPage<void>(builder);
  await settle(tester, frames: 20);
}

/// The form factor the app chose.
FormFactor formFactorOf(WidgetTester tester) =>
    Theme.of(appContext(tester)).formFactor;
