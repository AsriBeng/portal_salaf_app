import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/config.dart';
import 'core/push_service.dart';
import 'core/router.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  if (kIsWeb) {
    // Alamat halaman tanpa '#', misalnya /app/santri/12
    usePathUrlStrategy();
  } else {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  // retry: null → kesalahan dari API langsung ditampilkan, tidak diulang otomatis
  runApp(ProviderScope(retry: (_, _) => null, child: const PortalSalafApp()));
}

class PortalSalafApp extends ConsumerWidget {
  const PortalSalafApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: pesanGlobalKey,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
