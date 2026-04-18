import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'services/refresh_notifier.dart';

void main() {
  runApp(const HelmetViolationApp());
}

class HelmetViolationApp extends StatelessWidget {
  const HelmetViolationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => RefreshNotifier()),
      ],
      child: MaterialApp(
        title: 'Helmet Violation',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B5E20),
            brightness: Brightness.light,
            primary: const Color(0xFF2E7D32),
            secondary: const Color(0xFF43A047),
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
