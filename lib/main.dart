import 'package:disco/disco.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:una/una.dart';
import 'package:una_banking/app_state.dart';
import 'package:una_banking/navigation.dart';
import 'package:una_banking/session.dart';
import 'package:una_banking/shell.dart';

export 'package:una_banking/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SolidartConfig.devToolsEnabled = false;
  // Transactions and cards have their own menus on a right click; the
  // browser's would open over them.
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  // una bundles no fonts. Fetch the app's face before the first frame, so
  // it does not open in the fallback font and then reflow; and load Liquid
  // Glass's shaders, so the first glass surfaces are not a frame late.
  await Future.wait([
    loadAppFont(timeout: const Duration(seconds: 3)),
    LiquidGlass.initialize(),
  ]);
  runApp(const App());
}

/// The weights the text roles use, fetched up front so the text reflows
/// once rather than once per weight.
const _weights = [
  FontWeight.w400,
  FontWeight.w500,
  FontWeight.w600,
  FontWeight.w700,
];

/// Every text role in Inter: a face made for screens, with tabular figures
/// for every amount and a bold that carries a balance. One object for the
/// whole run; the method is a static tear-off, so the theme compares equal
/// however often it is built.
final appTextTheme = TextTheme.fromGoogleFont(GoogleFonts.inter);

/// Fetches the faces and completes once they are registered, or when
/// fetching fails or is disabled (offline, tests): the text then renders in
/// the fallback face.
Future<void> loadAppFont({
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    for (final weight in _weights) {
      GoogleFonts.inter(fontWeight: weight);
    }
    appTextTheme;
    await GoogleFonts.pendingFonts().timeout(timeout);
  } on Object {
    // Keep the fallback.
  }
}

/// The brand colour: a warm coral, the glow of a lamp in a dark room —
/// friendly where a bank is usually cold, and bright enough to read on the
/// graphite of the dark theme.
const brandSeed = Color(0xFFF2643D);

/// The greys lean warm graphite, so the dark theme reads as soft charcoal
/// rather than blue-black, and the cards and the coral carry the colour.
const brandNeutral = Color(0xFF6E6670);

final _lightScheme = ColorScheme.fromSeed(brandSeed, neutral: brandNeutral);
final _darkScheme = ColorScheme.fromSeed(
  brandSeed,
  neutral: brandNeutral,
  brightness: Brightness.dark,
);

/// The package's default look (Fluid: soft glass, large radii, lively
/// motion) on the brand colours, built once per setting: an unequal theme
/// per build would be a theme change on every rebuild.
ThemeData themeFor(Brightness brightness, LiquidGlassMode mode) =>
    _themes[(brightness, mode)] ??= ThemeData(
      colorScheme: brightness == Brightness.dark ? _darkScheme : _lightScheme,
      textTheme: appTextTheme,
      liquidGlass: mode == LiquidGlassMode.auto
          ? null
          : LiquidGlassTheme(mode: mode),
    );

final _themes = <(Brightness, LiquidGlassMode), ThemeData>{};

/// Every app-level provider: the settings, the shell's destination and
/// selected card, and the session. They sit above [UnaApp], so every route
/// can read them.
final bankProviders = <InstantiableProvider>[
  ...appProviders,
  destinationProvider,
  selectedCardProvider,
  sessionProvider,
];

/// Una Banking: a fictional money app built from una's widgets.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      providers: bankProviders,
      child: SignalBuilder(
        builder: (context, _) {
          final themeMode = themeModeProvider.of(context).value;
          final textScale = textScaleProvider.of(context).value;
          final glass = liquidGlassProvider.of(context).value;
          return UnaApp(
            title: 'Una Banking',
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
            theme: themeFor(Brightness.light, glass),
            darkTheme: themeFor(Brightness.dark, glass),
            home: const BankShell(),
            builder: (context, child) => SessionScope(
              notifier: sessionProvider.of(context),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                ),
                child: child!,
              ),
            ),
          );
        },
      ),
    );
  }
}
