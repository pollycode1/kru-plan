import 'package:flutter/material.dart';

import 'screens/progress_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/today_screen.dart';
import 'blob_store.dart';
import 'scope.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BlobStore.init();
  final store = AppStore();
  await store.load();
  runApp(StoreScope(store: store, child: const KruPlanApp()));
}

class KruPlanApp extends StatelessWidget {
  const KruPlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3949AB);
    return MaterialApp(
      title: 'แผนสอนวันนี้',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          colorSchemeSeed: seed, useMaterial3: true, fontFamily: 'Sarabun'),
      darkTheme: ThemeData(
          colorSchemeSeed: seed,
          brightness: Brightness.dark,
          useMaterial3: true,
          fontFamily: 'Sarabun'),
      // iPad/แท็บเล็ต: ขยายตัวอักษรให้อ่านง่ายขึ้น
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        if (mq.size.shortestSide < 600) return child!;
        return MediaQuery(
            data: mq.copyWith(textScaler: const TextScaler.linear(1.15)),
            child: child!);
      },
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [TodayScreen(), ProgressScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'วันนี้'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'ความคืบหน้า'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'ตั้งค่า'),
        ],
      ),
    );
  }
}
