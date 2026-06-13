import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'providers/cash_provider.dart';
import 'providers/credit_provider.dart';
import 'providers/debts_provider.dart';
import 'providers/employees_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es_CO';
  await initializeDateFormatting('es_CO');
  runApp(const TendaApp());
}

class TendaApp extends StatelessWidget {
  const TendaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()..load()),
        ChangeNotifierProvider(create: (_) => DebtsProvider()..load()),
        ChangeNotifierProvider(create: (_) => SalesProvider()..loadToday()),
        ChangeNotifierProvider(create: (_) => CreditProvider()..load()),
        ChangeNotifierProvider(create: (_) => EmployeesProvider()..load()),
        ChangeNotifierProvider(create: (_) => CashProvider()..load()),
      ],
      child: MaterialApp(
        title: 'Tenda',
        debugShowCheckedModeBanner: false,
        locale: const Locale('es', 'CO'),
        supportedLocales: const [Locale('es', 'CO'), Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Tema pensado para que la app sea fácil de leer y de tocar:
        // textos y botones grandes, buen contraste y áreas táctiles amplias.
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00754B)),
          visualDensity: VisualDensity.comfortable,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            filled: true,
          ),
          // Botones cómodos de presionar (alto mínimo 52).
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
          ),
          listTileTheme: const ListTileThemeData(minVerticalPadding: 10),
          navigationBarTheme: NavigationBarThemeData(
            height: 72,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
