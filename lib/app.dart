import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'state/app_state.dart';
import 'ui/screens/clients/clients_screen.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/more_screen.dart';
import 'ui/screens/movements/movements_screen.dart';
import 'ui/screens/pin_lock_screen.dart';
import 'ui/screens/products/products_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/widgets/form_sections.dart';
import 'ui/widgets/wanma_logo.dart';

/// Racine de l'application Wanma.
class WanmaApp extends StatefulWidget {
  const WanmaApp({super.key});

  @override
  State<WanmaApp> createState() => _WanmaAppState();
}

class _WanmaAppState extends State<WanmaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<AppState>().handleLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const <Locale>[Locale('fr', 'FR'), Locale('fr')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(
            textScaler: data.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.6,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _RootGate(),
    );
  }
}

/// Aiguillage entre démarrage, verrouillage, erreur et navigation principale.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    Widget content;
    if (appState.fatalErrorMessage != null) {
      content = _FatalErrorScreen(message: appState.fatalErrorMessage!);
    } else if (appState.isInitializing || !appState.isInitialized) {
      content = const SplashScreen();
    } else if (appState.isLocked) {
      content = const PinLockScreen();
    } else {
      content = const HomeShell();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey<String>(content.runtimeType.toString()),
        child: content,
      ),
    );
  }
}

class _FatalErrorScreen extends StatelessWidget {
  const _FatalErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const WanmaLogo(size: 74, withBackground: true),
                const SizedBox(height: 24),
                Text(
                  'Impossible de démarrer Wanma',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: appState.retryInitialization,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
                const SizedBox(height: 14),
                const InfoBanner(
                  text:
                      'Vos données locales ne sont pas supprimées par cette '
                      'erreur. Si le problème persiste, vérifiez l’espace '
                      'disponible sur le téléphone.',
                  icon: Icons.storage_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation inférieure persistante de l'application.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.ivory,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppTokens.contentMaxWidth,
            ),
            child: IndexedStack(
              index: _selectedIndex,
              children: <Widget>[
                DashboardScreen(onSelectTab: _selectTab),
                const ProductsScreen(),
                const ClientsScreen(),
                const MovementsScreen(),
                const MoreScreen(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppTokens.contentMaxWidth,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTokens.navRadius),
                  boxShadow: const <BoxShadow>[AppTokens.floatingShadow],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.navRadius),
                  child: NavigationBar(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _selectTab,
                    destinations: const <NavigationDestination>[
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Accueil',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.inventory_2_outlined),
                        selectedIcon: Icon(Icons.inventory_2_rounded),
                        label: 'Produits',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.people_outline_rounded),
                        selectedIcon: Icon(Icons.people_rounded),
                        label: 'Clients',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.swap_vert_rounded),
                        selectedIcon: Icon(Icons.swap_vert_circle_rounded),
                        label: 'Activité',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.grid_view_outlined),
                        selectedIcon: Icon(Icons.grid_view_rounded),
                        label: 'Outils',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
