import 'dart:async';
import 'package:budget_zen/appPages/Initial.dart';
import 'package:budget_zen/appPages/Settings.dart';
import 'package:budget_zen/appPages/SignUp.dart';
import 'package:budget_zen/appPages/adminPages/AddUser.dart';
import 'package:budget_zen/widgets/RechargePage.dart';
import 'package:budget_zen/widgets/RetraitPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'appPages/About.dart';
import 'appPages/HistoriqueObjectifsEpargne/HistoriqueObjectifsEpargneWithBackArrow.dart';
import 'appPages/HistoriqueObjectifsEpargne/HistoriqueObjectifsEpargneWithoutBackArrow.dart';
import 'appPages/Home.dart';
import 'appPages/Login.dart';
import 'appPages/MoneyTransferPage.dart';
import 'appPages/Profile.dart';
import 'appPages/Redirection.dart';
import 'appPages/Reset_password.dart';
import 'appPages/SavingsGoalsPage.dart';
import 'appPages/HistoriqueTransactionPage.dart';
import 'appPages/Welcome.dart';
import 'appPages/adminPages/AdminProfile.dart';
import 'appPages/adminPages/Dashboard.dart';
import 'colors/app_colors.dart';
import 'firebase_options.dart';

class ThemeNotifier with ChangeNotifier {
  bool _isDark = false;

  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'MainNavigator');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Enregistrez l'erreur ici si nécessaire
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    // Gérer les erreurs non capturées
    return true; // Indique que l'erreur a été gérée
  };

  await initializeDateFormatting('fr_FR', null); // Initialise les données françaises

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late Future<String> _initialRouteFuture;
  Timer? _sessionTimer; // Timer pour la temporisation de session
  static const int _sessionTimeoutDuration = 15 * 60; // 15 minutes en secondes

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialRouteFuture = _getInitialRoute();
    _startSessionTimer(); // Démarre le timer de session
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel(); // Annule le timer lors de la fermeture
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resetSessionTimer(); // Réinitialise le timer quand l'app revient au premier plan
    }
    // Ne rien faire pour inactive ou paused pour éviter une déconnexion automatique
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(Duration(seconds: _sessionTimeoutDuration), () {
      _handleSessionTimeout();
    });
  }

  void _resetSessionTimer() {
    _startSessionTimer(); // Réinitialise le timer à chaque interaction
  }

  Future<void> _handleSessionTimeout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseAuth.instance.signOut();
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/LoginPage', (Route<dynamic> route) => false);
      _showError('Votre session a expiré. Veuillez vous reconnecter.');
    }
  }

  Future<String> _getInitialRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    return user != null ? '/RedirectionPage' : '/WelcomePage';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(message)),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ],
        ),
        backgroundColor: AppColors.errorColor,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return FutureBuilder<String>(
      future: _initialRouteFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: AppColors.primaryColor,
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryColor,
              secondary: AppColors.secondaryColor,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: AppColors.darkPrimaryColor,
            colorScheme: ColorScheme.dark(
              primary: AppColors.darkPrimaryColor,
              secondary: AppColors.darkSecondaryColor,
            ),
          ),
          themeMode: themeNotifier.isDark ? ThemeMode.dark : ThemeMode.light,
          initialRoute: snapshot.data,
          routes: {
            // Routes des utilisateurs
            '/WelcomePage': (context) => const WelcomePage(),
            '/LoginPage': (context) => const LoginPage(),
            '/SignUpPage': (context) => const SignUpPage(),
            '/ResetPasswordPage': (context) => const ResetPasswordPage(),
            '/RedirectionPage': (context) => const RedirectionPage(),
            '/HomePage': (context) => const HomePage(),
            '/HistoriqueTransactionPage': (context) => const HistoriqueTransactionPage(),
            '/money_transfer': (context) => const MoneyTransferPage(),
            '/RetraitPage': (context) => const RetraitPage(),
            '/RechargePage': (context) => const RechargePage(montantDisponible: 0.0),
            '/SettingsPage': (context) => const SettingsPage(),
            '/ProfilePage': (context) => const ProfilePage(),
            '/AboutPage': (context) => AboutPage(),
            '/SavingsGoalsPage': (context) => SavingsGoalsPage(),
            '/historique-epargne': (context) => const HistoriqueObjectifsEpargneWithBackArrow(),
            '/historique-epargne-no-back': (context) => const HistoriqueObjectifsEpargneWithoutBackArrow(),

            // Routes de l'administrateur
            '/dashboardPage': (context) => const DashboardAdminPage(),
            '/addusersPage': (context) => const AddUsersPage(),
            '/adminProfilPage': (context) => const AdminProfilePage(),
          },
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/InitialPage':
                return MaterialPageRoute(builder: (_) => const InitialPage());
              default:
                return MaterialPageRoute(builder: (_) => const WelcomePage());
            }
          },
        );
      },
    );
  }
}