import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../colors/app_colors.dart';
import '../services/firebase/firestore.dart';
import '../services/firebase/messaging.dart';
import '../widgets/EpargnesChart.dart';
import '../widgets/ForHomePage/AddSavingDialog.dart';
import '../widgets/ForHomePage/BudgetValidator.dart';
import '../widgets/RechargePage.dart';
import '../widgets/RetraitPage.dart';
import '../widgets/RevenusChart.dart';
import '../widgets/CircularChart.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/DepensesChart.dart';
import 'SavingsGoalsPage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> containerTitle = [
    'Mon solde',
    'Mes dépenses',
    'Mes revenus',
    'Mes épargnes'
  ];

  List<IconData> cardIcons = [
    Icons.account_balance,
    Icons.shopping_cart,
    Icons.monetization_on,
    Icons.savings,
  ];

  List<Color> cardBgColor = [
    Colors.grey.shade300,
    Colors.pink.shade100,
    Colors.green.shade100,
    Colors.blue.shade100,
  ];

  List<String> infoMontant = [
    'Solde actuel disponible',
    'Montant total de toutes les dépenses',
    'Montant total des revenus',
    'Montant total épargné'
  ];

  final space = const SizedBox(height: 10);
  double montantDisponible = 0.0;
  double depenses = 0.0;
  double revenus = 0.0;
  double epargnes = 0.0;
  bool isExpanded = false;
  int selectedMonth = DateTime.now().month;
  int selectedWeekIndex = 0;

  StreamSubscription<DocumentSnapshot>? _compteSubscription;
  StreamSubscription<double>? _depensesSubscription;
  StreamSubscription<double>? _revenusSubscription;
  StreamSubscription<double>? _epargnesSubscription;
  final FirestoreService _firestoreService = FirestoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();

  String _selectedBudgetType = 'mensuel';
  double? _currentBudget;

  Map<String, dynamic> getCurrentWeekOfMonth(int year, int month) {
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;
    final today = isCurrentMonth ? now : DateTime(year, month, 1);
    DateTime firstDay = DateTime(year, month, 1);
    DateTime lastDay = DateTime(year, month + 1, 0);
    List<Map<String, DateTime>> weeks = [];
    DateTime currentMonday = firstDay;

    // Aller au premier lundi du mois
    while (currentMonday.weekday != DateTime.monday) {
      currentMonday = currentMonday.add(const Duration(days: 1));
    }

    // Générer les semaines
    while (currentMonday.isBefore(lastDay) || currentMonday.isAtSameMomentAs(lastDay)) {
      DateTime currentSunday = currentMonday.add(const Duration(days: 6));
      if (currentSunday.isAfter(lastDay)) currentSunday = lastDay;
      weeks.add({
        'start': DateTime(currentMonday.year, currentMonday.month, currentMonday.day),
        'end': DateTime(currentSunday.year, currentSunday.month, currentSunday.day, 23, 59, 59),
      });
      currentMonday = currentMonday.add(const Duration(days: 7));
    }

// Ajouter la première semaine si le mois ne commence pas un lundi
    if (firstDay.isBefore(weeks.isNotEmpty ? weeks[0]['start']! : lastDay)) {
      final previousDay = weeks.isNotEmpty
          ? weeks[0]['start']!.subtract(const Duration(days: 1))
          : lastDay;
      weeks.insert(0, {
        'start': DateTime(firstDay.year, firstDay.month, firstDay.day),
        'end': DateTime(previousDay.year, previousDay.month, previousDay.day, 23, 59, 59),
      });
    }

    // Trouver la semaine courante
    int weekIndex = isCurrentMonth
        ? weeks.indexWhere((w) =>
    today.isAfter(w['start']!.subtract(const Duration(days: 1))) &&
        today.isBefore(w['end']!.add(const Duration(days: 1))))
        : 0; // Par défaut, première semaine pour un mois non courant
    if (weekIndex == -1) weekIndex = 0;

    print('DEBUG: Semaines calculées: ${weeks.length}, weekIndex=$weekIndex');
    return {
      'weekIndex': weekIndex,
      'start': weeks[weekIndex]['start'],
      'end': weeks[weekIndex]['end'],
      'weeks': weeks,
    };
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchCurrentBudget();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args.containsKey('rechargeAmount') && args.containsKey('rechargeTimestamp')) {
      final double rechargeAmount = args['rechargeAmount'] as double;
      final String rechargeTimestamp = args['rechargeTimestamp'] as String;
      SharedPreferences.getInstance().then((prefs) async {
        final notifKey = 'rechargeNotifShown_$rechargeTimestamp';
        final notifShown = prefs.getBool(notifKey) ?? false;
        if (!notifShown) {
          await Future.delayed(const Duration(milliseconds: 100));
          _messagingService.sendLocalNotification(
              'Recharge effectuée avec succès',
              'Montant: ${rechargeAmount.toStringAsFixed(2)} FCFA\nVotre solde a été mis à jour.'
          );
          await prefs.setBool(notifKey, true);
        }
        _checkAndShowSavingsPlanDialog(context, rechargeAmount, rechargeTimestamp);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.settings.arguments is Map) {
          final currentArgs = ModalRoute.of(context)!.settings.arguments as Map;
          if (currentArgs.containsKey('rechargeAmount') || currentArgs.containsKey('rechargeTimestamp')) {
            final newArgs = Map<String, dynamic>.from(currentArgs);
            newArgs.remove('rechargeAmount');
            newArgs.remove('rechargeTimestamp');

            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
                settings: RouteSettings(
                  name: '/HomePage',
                  arguments: newArgs.isEmpty ? null : newArgs,
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return child;
                },
              ),
            );
          }
        }
      });
    }
  }

  Future<void> _checkAndShowSavingsPlanDialog(BuildContext context, double amount, String rechargeTimestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'savingsPlanDialogClosed_$rechargeTimestamp';
    final isDialogClosed = prefs.getBool(key) ?? false;

    if (!isDialogClosed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSavingsPlanDialog(context, amount, rechargeTimestamp);
      });
    }
  }

  Future<void> _showSavingsPlanDialog(BuildContext context, double amount, String rechargeTimestamp) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool isClosing = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Plan de gestion de votre revenu'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nous vous proposons d\'allouer votre revenu selon la règle 50/30/20 :',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text('• 50% pour les besoins : ${(amount * 0.50).toStringAsFixed(2)} FCFA'),
                Text('• 30% pour les désirs : ${(amount * 0.30).toStringAsFixed(2)} FCFA'),
                Text('• 20% pour l\'épargne : ${(amount * 0.20).toStringAsFixed(2)} FCFA'),
                const SizedBox(height: 10),
                const Text(
                  'Vous pouvez ajuster ces montants dans vos objectifs financiers.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isClosing
                    ? null
                    : () {
                  setState(() => isClosing = true);
                  Navigator.of(dialogContext).pop();
                  SharedPreferences.getInstance().then((prefs) {
                    prefs.setBool('savingsPlanDialogClosed_$rechargeTimestamp', true);
                  });
                },
                child: const Text('Fermer'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SavingsGoalsPage()),
                  );
                },
                child: const Text('Définir des objectifs'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadUserData() async {
    if (_currentUser != null) {
      _compteSubscription = FirebaseFirestore.instance
          .collection('comptesMobiles')
          .doc(_currentUser!.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              montantDisponible = (data['montantDisponible'] as num?)?.toDouble() ?? 0.0;
            });
          }
        }
      });

      _updateSubscriptions(_currentUser!.uid);
    }
  }

  void _updateSubscriptions(String userId) {
    _depensesSubscription?.cancel();
    _revenusSubscription?.cancel();
    _epargnesSubscription?.cancel();

    _firestoreService.getTotalDepenses(userId).then((total) {
      if (mounted) setState(() => depenses = total);
    });
    _firestoreService.getTotalRevenus(userId).then((total) {
      if (mounted) setState(() => revenus = total);
    });
    _firestoreService.getTotalEpargnes(userId).then((total) {
      if (mounted) setState(() => epargnes = total);
    });

    _depensesSubscription = _firestoreService
        .streamTotalDepensesByMonth(userId, selectedMonth)
        .listen((total) {
      if (mounted) {
        setState(() {
          depenses = total;
        });
      }
    });

    _revenusSubscription = _firestoreService
        .streamTotalRevenusByMonth(userId, selectedMonth)
        .listen((total) {
      if (mounted) {
        setState(() {
          revenus = total;
        });
      }
    });

    _epargnesSubscription = _firestoreService
        .streamTotalEpargnesByMonth(userId, selectedMonth)
        .listen((total) {
      if (mounted) {
        setState(() {
          epargnes = total;
        });
      }
    });
  }

  String _getMonthName(int month) {
    if (month < 1 || month > 12) return 'Mois inconnu';
    const monthNames = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return monthNames[month - 1];
  }

  Widget _buildHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights,
                color: isDarkMode ? AppColors.darkSecondaryColor : Colors.blue.shade800,
                size: 50,
              ),
              const SizedBox(width: 10),
              Text(
                'Statistiques',
                style: TextStyle(
                  fontSize: 20,
                  color: isDarkMode ? AppColors.darkSecondaryColor : Colors.blue.shade800,
                ),
              ),
            ],
          ),
          _MonthDropdown(
            selectedMonth: selectedMonth,
            onChanged: (value) {
              if (value != null && value != selectedMonth) {
                setState(() {
                  selectedMonth = value;
                  if (_currentUser != null) {
                    _updateSubscriptions(_currentUser!.uid);
                    _fetchCurrentBudget();
                  }
                });
              }
            },
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Accueil',
        showBackArrow: false,
        showDarkModeButton: true,
      ),
      body: _currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.darkCardColors[0] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Budget:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDarkMode ? AppColors.darkTextColor : Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDarkMode ? AppColors.darkCardColors[1] : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedBudgetType,
                                items: [
                                  DropdownMenuItem(
                                    value: 'hebdomadaire',
                                    child: Text(
                                      'Hebdomadaire',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDarkMode ? AppColors.darkTextColor : Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'mensuel',
                                    child: Text(
                                      'Mensuel',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDarkMode ? AppColors.darkTextColor : Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'annuel',
                                    child: Text(
                                      'Annuel',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDarkMode ? AppColors.darkTextColor : Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedBudgetType = value ?? 'mensuel';
                                    _fetchCurrentBudget();
                                  });
                                },
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isDarkMode ? AppColors.darkTextColor : Colors.blue.shade900,
                                ),
                                dropdownColor: isDarkMode ? AppColors.darkCardColors[0] : Colors.white,
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: isDarkMode ? AppColors.darkTextColor : Colors.blue.shade900,
                                ),
                                isDense: true,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildBudgetRealtimeWidget(isDarkMode),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildBudgetInfo(isDarkMode),
                Expanded(
                  child: ListView(
                    children: [
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: containerTitle.length,
                          itemBuilder: (BuildContext context, int index) {
                            double montant = 0.0;
                            switch (index) {
                              case 0:
                                montant = montantDisponible;
                                break;
                              case 1:
                                montant = depenses;
                                break;
                              case 2:
                                montant = revenus;
                                break;
                              case 3:
                                montant = epargnes;
                                break;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                              child: Card(
                                elevation: 4.0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IntrinsicWidth(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minWidth: 180,
                                      maxWidth: 250,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: isDarkMode
                                            ? AppColors.darkCardColors[index % AppColors.darkCardColors.length]
                                            : cardBgColor[index],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  cardIcons[index],
                                                  size: 28,
                                                  color: isDarkMode
                                                      ? AppColors.darkPrimaryColor
                                                      : AppColors.primaryColor,
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    containerTitle[index],
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontFamily: 'LucidaCalligraphy',
                                                      color: isDarkMode
                                                          ? AppColors.darkTextColor
                                                          : AppColors.textColor,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Montant : ${montant.toStringAsFixed(2)} FCFA',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDarkMode
                                                    ? AppColors.darkTextColor
                                                    : AppColors.textColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              infoMontant[index],
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDarkMode
                                                    ? AppColors.darkSecondaryTextColor
                                                    : Colors.grey.shade600,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      _buildHeader(isDarkMode),
                      const SizedBox(height: 20),
                      CircularChart(
                        userId: _currentUser!.uid,
                        selectedMonth: selectedMonth,
                      ),
                      const SizedBox(height: 20),
                      RevenusChart(
                        userId: _currentUser!.uid,
                        selectedMonth: selectedMonth,
                      ),
                      const SizedBox(height: 20),
                      DepensesChart(
                        userId: _currentUser!.uid,
                        selectedMonth: selectedMonth,
                      ),
                      const SizedBox(height: 20),
                      EpargnesChart(
                        userId: _currentUser!.uid,
                        selectedMonth: selectedMonth,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: Stack(
        children: [
          Positioned(
            bottom: 70,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'main-fab',
              shape: const CircleBorder(),
              backgroundColor: isDarkMode ? AppColors.darkSecondaryColor : Colors.blueAccent,
              child: Icon(
                isExpanded ? Icons.remove : Icons.add,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  isExpanded = !isExpanded;
                });
              },
            ),
          ),
          if (isExpanded) ...[
            Positioned(
              bottom: 130,
              right: 16,
              child: Tooltip(
                message: "Ajouter une épargne",
                child: FloatingActionButton(
                  heroTag: 'savings-fab',
                  shape: const CircleBorder(),
                  backgroundColor: isDarkMode ? AppColors.darkSecondaryColor : Colors.blueAccent,
                  child: const Icon(Icons.savings, color: Colors.white),
                  onPressed: () {
                    _showAddSavingsDialog(context);
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 190,
              right: 16,
              child: Tooltip(
                message: "Recharger le compte",
                child: FloatingActionButton(
                  heroTag: 'recharge-fab',
                  shape: const CircleBorder(),
                  backgroundColor: isDarkMode ? AppColors.darkSecondaryColor : Colors.orangeAccent,
                  child: const Icon(Icons.add_circle_outline, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RechargePage(montantDisponible: montantDisponible),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 250,
              right: 16,
              child: Tooltip(
                message: "Retirer de l'argent",
                child: FloatingActionButton(
                  heroTag: 'retrait-fab',
                  shape: const CircleBorder(),
                  backgroundColor: isDarkMode ? AppColors.darkSecondaryColor : Colors.redAccent,
                  child: const Icon(Icons.remove_circle_outline, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RetraitPage()),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 310,
              right: 16,
              child: Tooltip(
                message: "Transférer de l'argent",
                child: FloatingActionButton(
                  heroTag: 'transfer-fab',
                  shape: const CircleBorder(),
                  backgroundColor: isDarkMode ? AppColors.darkSecondaryColor : Colors.purpleAccent,
                  child: const Icon(Icons.send, color: Colors.white),
                  onPressed: () {
                    Navigator.pushNamed(context, '/money_transfer');
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 370,
              right: 16,
              child: Tooltip(
                message: "Définir mon budget",
                child: FloatingActionButton(
                  heroTag: 'budget-fab',
                  shape: const CircleBorder(),
                  backgroundColor: isDarkMode ? AppColors.darkSecondaryColor : Colors.green,
                  child: const Icon(Icons.account_balance_wallet, color: Colors.white),
                  onPressed: () {
                    _showBudgetFormDialog(context);
                  },
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 0,
        onTabSelected: (index) {
          if (index != 0) {
            final routes = ['/HomePage', '/HistoriqueTransactionPage', '/historique-epargne-no-back', '/SettingsPage'];
            Navigator.pushReplacementNamed(context, routes[index]);
          }
        },
      ),
    );
  }

  Future<void> _showAddSavingsDialog(BuildContext context) async {
    if (_currentUser == null) {
      _messagingService.sendLocalNotification('Erreur', 'Vous devez être connecté pour ajouter une épargne.');
      return;
    }

    try {
      final goalsSnapshot = await _firestoreService.getObjectifsEpargne(_currentUser!.uid);
      bool allGoalsUnusable = false;

      if (goalsSnapshot.docs.isNotEmpty) {
        allGoalsUnusable = goalsSnapshot.docs.every((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final montantActuel = (data['montantActuel'] as num?)?.toDouble() ?? 0.0;
          final montantCible = (data['montantCible'] as num?)?.toDouble() ?? 0.0;
          final isCompleted = (data['isCompleted'] as bool?) ?? false;
          final dateLimite = data['dateLimite'] as Timestamp?;
          final isExpired = dateLimite != null && dateLimite.toDate().isBefore(DateTime.now());

          return isCompleted || montantActuel >= montantCible || isExpired;
        });
      }

      if (goalsSnapshot.docs.isEmpty || allGoalsUnusable) {
        await _showNoSavingsGoalDialog(context, goalsSnapshot.docs.isEmpty);
        return;
      }

      await showDialog(
        context: context,
        builder: (context) => AddSavingsDialog(
          onSavingsAdded: (amount, category, description, goalId, savingsGoals) async {
            final isBudgetValid = await BudgetValidator.validateBudget(
              context,
              _firestoreService,
              _currentUser!.uid,
              amount,
              goalId,
              savingsGoals,
            );
            if (isBudgetValid) {
              await _addSavings(amount, category, description, goalId);
            }
          },
          userId: _currentUser!.uid,
          firestoreService: _firestoreService,
        ),
      );
    } catch (e) {
      _messagingService.sendLocalNotification('Erreur', 'Une erreur s\'est produite. Vérifiez votre connexion ou réessayez plus tard.');
    }
  }

  Future<void> _showNoSavingsGoalDialog(BuildContext context, bool noGoalsDefined) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aucun objectif d\'épargne disponible'),
        content: Text(
          noGoalsDefined
              ? 'Vous n\'avez pas encore défini d\'objectif d\'épargne. Veuillez en créer un pour ajouter des épargnes.'
              : 'Tous vos objectifs d\'épargne sont soit atteints, soit expirés. Veuillez créer un nouvel objectif pour continuer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavingsGoalsPage()),
              );
            },
            child: const Text('Définir un objectif'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSavings(double amount, String category, String? description, String goalId) async {
    if (_currentUser == null) {
      _messagingService.sendLocalNotification('Erreur', 'Vous devez être connecté pour ajouter une épargne.');
      return;
    }

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final compteRef = FirebaseFirestore.instance.collection('comptesMobiles').doc(_currentUser!.uid);
        final objectifRef = FirebaseFirestore.instance.collection('objectifsEpargne').doc(goalId);

        final compteSnap = await transaction.get(compteRef);
        final objectifSnap = await transaction.get(objectifRef);

        if (!compteSnap.exists) {
          throw Exception('Votre compte n\'a pas été trouvé. Configurez-le dans les paramètres.');
        }
        if (!objectifSnap.exists) {
          throw Exception('L\'objectif sélectionné n\'existe plus. Choisissez un autre.');
        }

        final compteData = compteSnap.data();
        final objectifData = objectifSnap.data();

        if (compteData == null || objectifData == null) {
          throw Exception('Une erreur technique est survenue. Contactez le support si cela persiste.');
        }

        final currentMontant = (compteData['montantDisponible'] as num?)?.toDouble() ?? 0.0;
        final currentMontantActuel = (objectifData['montantActuel'] as num?)?.toDouble() ?? 0.0;
        final montantCible = (objectifData['montantCible'] as num?)?.toDouble() ?? 0.0;
        final isCompleted = (objectifData['isCompleted'] as bool?) ?? false;
        final dateLimite = objectifData['dateLimite'] as Timestamp?;

        if (dateLimite != null && dateLimite.toDate().isBefore(DateTime.now())) {
          throw Exception('Cet objectif est expiré. Sélectionnez un objectif actif.');
        }

        if (isCompleted || currentMontantActuel >= montantCible) {
          throw Exception('Cet objectif est déjà complété. Choisissez un autre.');
        }

        if (currentMontant < amount) {
          throw Exception('Votre solde est trop faible pour cette épargne. Ajoutez des fonds.');
        }

        final epargneRef = FirebaseFirestore.instance.collection('epargnes').doc();
        transaction.set(epargneRef, {
          'userId': _currentUser!.uid,
          'montant': amount,
          'categorie': category,
          'description': description,
          'objectifId': goalId,
          'dateCreation': FieldValue.serverTimestamp(),
        });

        transaction.update(compteRef, {
          'montantDisponible': FieldValue.increment(-amount),
          'derniereMiseAJour': FieldValue.serverTimestamp(),
        });

        final newMontantActuel = currentMontantActuel + amount;
        transaction.update(objectifRef, {
          'montantActuel': newMontantActuel,
          'isCompleted': newMontantActuel >= montantCible,
        });
      });

      _messagingService.sendLocalNotification('Succès', 'Épargne de ${amount.toStringAsFixed(2)} FCFA ajoutée avec succès');
    } catch (e) {
      _messagingService.sendLocalNotification('Erreur', 'Erreur : Une erreur est survenue. Vérifiez votre solde ou réessayez.');
    }
  }

  Future<void> _showBudgetFormDialog(BuildContext context, {String? initialType}) async {
    final _formKey = GlobalKey<FormState>();
    final _amountController = TextEditingController();
    String _selectedType = initialType ?? 'mensuel';
    DateTime now = DateTime.now();
    DateTime periodeDebut = DateTime(now.year, selectedMonth, 1);
    DateTime periodeFin = DateTime(now.year, selectedMonth + 1, 0);
    bool _isSubmitting = false;

    void _updatePeriod(String type) {
      if (type == 'mensuel') {
        periodeDebut = DateTime(now.year, selectedMonth, 1);
        periodeFin = DateTime(now.year, selectedMonth + 1, 0);
      } else if (type == 'annuel') {
        periodeDebut = DateTime(now.year, 1, 1);
        periodeFin = DateTime(now.year, 12, 31);
      } else if (type == 'hebdomadaire') {
        final weekInfo = getCurrentWeekOfMonth(now.year, selectedMonth);
        periodeDebut = weekInfo['start'];
        periodeFin = weekInfo['end'];
      }
    }
    _updatePeriod(_selectedType);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Définir mon budget'),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Montant du budget'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un montant';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Veuillez entrer un nombre valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      items: const [
                        DropdownMenuItem(value: 'hebdomadaire', child: Text('Hebdomadaire')),
                        DropdownMenuItem(value: 'mensuel', child: Text('Mensuel')),
                        DropdownMenuItem(value: 'annuel', child: Text('Annuel')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value ?? 'mensuel';
                          _updatePeriod(_selectedType);
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Type de budget'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() => _isSubmitting = true);
                      final existingBudget = await _firestoreService.getBudgetForPeriod(
                        _currentUser!.uid,
                        periodeDebut,
                        periodeFin,
                        type: _selectedType,
                      );
                      if (existingBudget != null) {
                        setState(() => _isSubmitting = false);

                        // Vérifier si on peut modifier le budget existant (après 5 jours)
                        final createdAt = (existingBudget['createdAt'] as Timestamp?)?.toDate();
                        if (createdAt != null) {
                          final now = DateTime.now();
                          final diff = now.difference(createdAt).inDays;

                          if (diff < 5) {
                            // Délai de modification non respecté
                            final nextModificationDate = createdAt.add(const Duration(days: 5));
                            final formattedLastDate = '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
                            final formattedNextDate = '${nextModificationDate.day.toString().padLeft(2, '0')}/${nextModificationDate.month.toString().padLeft(2, '0')}/${nextModificationDate.year}';

                            final errorMsg = '⏰ Modification du budget temporairement bloquée\n\n'
                                'Dernière modification : $formattedLastDate\n'
                                'Prochaine modification possible : $formattedNextDate\n\n'
                                '💡 Pourquoi cette limitation ?\n'
                                '• Cela vous aide à maintenir la cohérence de votre budget\n'
                                '• Évite les modifications trop fréquentes qui peuvent déséquilibrer votre gestion\n'
                                '• Vous encourage à bien réfléchir avant de définir vos objectifs\n\n'
                                '🔄 En attendant, vous pouvez :\n'
                                '• Consulter vos statistiques actuelles\n'
                                '• Ajuster vos dépenses pour respecter votre budget actuel\n'
                                '• Planifier vos prochaines modifications';

                            _messagingService.sendLocalNotification('Modification du budget', errorMsg);
                            return;
                          }
                        }

                        // Si on peut modifier, on met à jour le budget existant
                        try {
                          await _firestoreService.updateBudget(
                            budgetId: existingBudget.id,
                            montant: double.parse(_amountController.text),
                          );
                          Navigator.of(dialogContext).pop();
                          _messagingService.sendLocalNotification('Succès', 'Budget modifié avec succès !');
                        } catch (e) {
                          setState(() => _isSubmitting = false);
                          _messagingService.sendLocalNotification('Erreur', 'Erreur lors de la modification du budget.');
                        }
                        return;
                      }

                      // Si aucun budget existant, on en crée un nouveau
                      try {
                        await _firestoreService.definirBudget(
                          userId: _currentUser!.uid,
                          montant: double.parse(_amountController.text),
                          type: _selectedType,
                          periodeDebut: periodeDebut,
                          periodeFin: periodeFin,
                        );
                        Navigator.of(dialogContext).pop();
                        _messagingService.sendLocalNotification('Succès', 'Budget enregistré avec succès !');
                      } catch (e) {   
                        setState(() => _isSubmitting = false);

                        // Gestion spécifique de l'erreur de délai de modification
                        String errorMessage;
                        if (e.toString().contains('Délai de modification non respecté')) {
                          // Extraire la date de la dernière modification depuis le message d'erreur
                          final errorText = e.toString();
                          final dateMatch = RegExp(r'(\d{2}/\d{2}/\d{4})').firstMatch(errorText);
                          final lastModificationDate = dateMatch?.group(1) ?? 'date inconnue';

                          // Calculer la date de prochaine modification possible
                          final now = DateTime.now();
                          final nextModificationDate = now.add(const Duration(days: 5));
                          final formattedNextDate = '${nextModificationDate.day.toString().padLeft(2, '0')}/${nextModificationDate.month.toString().padLeft(2, '0')}/${nextModificationDate.year}';

                          errorMessage = '⏰ Modification du budget temporairement bloquée\n\n'
                              'Dernière modification : $lastModificationDate\n'
                              'Prochaine modification possible : $formattedNextDate\n\n'
                              '💡 Pourquoi cette limitation ?\n'
                              '• Cela vous aide à maintenir la cohérence de votre budget\n'
                              '• Évite les modifications trop fréquentes qui peuvent déséquilibrer votre gestion\n'
                              '• Vous encourage à bien réfléchir avant de définir vos objectifs\n\n'
                              '🔄 En attendant, vous pouvez :\n'
                              '• Consulter vos statistiques actuelles\n'
                              '• Ajuster vos dépenses pour respecter votre budget actuel\n'
                              '• Planifier vos prochaines modifications';
                        } else {
                          errorMessage = 'Erreur lors de l\'enregistrement du budget. Veuillez réessayer.';
                        }

                        _messagingService.sendLocalNotification('Modification du budget', errorMessage);
                      }
                    }
                  },
                  child: _isSubmitting ? const CircularProgressIndicator() : const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBudgetRealtimeWidget(bool isDarkMode) {
    if (_currentUser == null) {
      return Semantics(
        label: 'Aucun utilisateur connecté',
        child: Text(
          '-',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (_selectedBudgetType == 'hebdomadaire') {
      final now = DateTime.now();
      final weekInfo = getCurrentWeekOfMonth(now.year, selectedMonth);
      final week = {
        'start': weekInfo['start'] as DateTime,
        'end': weekInfo['end'] as DateTime,
      };

      return FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _firestoreService.getBudgetsHebdomadairesForMonth(
            _currentUser!.uid, now.year, selectedMonth),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDarkMode ? AppColors.darkSecondaryColor : Colors.blue.shade800,
              ),
            );
          }

          if (snapshot.hasError) {
            return Text(
              'Non défini',
              style: TextStyle(
                color: isDarkMode ? AppColors.darkSecondaryTextColor : Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            );
          }

          final budgets = snapshot.data ?? [];
          QueryDocumentSnapshot? weekBudget;

          try {
            weekBudget = budgets.firstWhere(
              (b) {
                final periodeDebut = (b['periodeDebut'] as Timestamp).toDate();
                final periodeFin = (b['periodeFin'] as Timestamp).toDate();
                final startMatch = periodeDebut.year == week['start']!.year &&
                    periodeDebut.month == week['start']!.month &&
                    periodeDebut.day == week['start']!.day;
                final endMatch = periodeFin.year == week['end']!.year &&
                    periodeFin.month == week['end']!.month &&
                    periodeFin.day == week['end']!.day;
                return startMatch && endMatch;
              },
            );
          } catch (_) {
            weekBudget = null;
          }

          if (weekBudget == null) {
            return Text(
              'Non défini',
              style: TextStyle(
                color: isDarkMode ? AppColors.darkSecondaryTextColor : Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            );
          }

          final data = weekBudget.data() as Map<String, dynamic>;
          final montant = (data['montant'] as num?)?.toDouble() ?? 0.0;

          return Text(
            '${montant.toStringAsFixed(0)} FCFA',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDarkMode ? Colors.green[300] : Colors.green[700],
            ),
          );
        },
      );
    } 

    // Pour les budgets mensuels et annuels, utiliser l'approche directe
    DateTime periodeDebut;
    DateTime periodeFin;
    final now = DateTime.now();

    if (_selectedBudgetType == 'mensuel') {
      periodeDebut = DateTime(now.year, selectedMonth, 1);
      periodeFin = DateTime(now.year, selectedMonth + 1, 0);
    } else if (_selectedBudgetType == 'annuel') {
      periodeDebut = DateTime(now.year, 1, 1);
      periodeFin = DateTime(now.year, 12, 31);
    } else {
      periodeDebut = DateTime(now.year, selectedMonth, 1);
      periodeFin = DateTime(now.year, selectedMonth + 1, 0);
    }

     final query = FirebaseFirestore.instance
        .collection('budgets')
        .where('userId', isEqualTo: _currentUser!.uid)
        .where('type', isEqualTo: _selectedBudgetType)
        .where('periodeDebut', isLessThanOrEqualTo: periodeDebut)
        .where('periodeFin', isGreaterThanOrEqualTo: periodeFin)
        .limit(1)
        .snapshots();

    return Semantics(
      label: _selectedBudgetType == 'mensuel'
          ? 'Budget ${_selectedBudgetType} pour ${_getMonthName(selectedMonth)}'
          : 'Budget ${_selectedBudgetType} actuel',
      child: StreamBuilder<QuerySnapshot>(
        stream: query,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDarkMode ? AppColors.darkSecondaryColor : Colors.blue.shade800,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Text(
              'Non défini',
              style: TextStyle(
                color: isDarkMode ? AppColors.darkSecondaryTextColor : Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            );
          }

          final doc = snapshot.data!.docs.first;
          final montant = (doc['montant'] as num?)?.toDouble() ?? 0.0;

          return Text(
            '${montant.toStringAsFixed(0)} FCFA',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDarkMode ? Colors.green[300] : Colors.green[700],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBudgetInfo(bool isDarkMode) {
    final now = DateTime.now();
    if (_selectedBudgetType == 'hebdomadaire') {
      // Define week at the top level to ensure it's accessible
      final weekInfo = getCurrentWeekOfMonth(now.year, selectedMonth);
      final week = {
        'start': weekInfo['start'] as DateTime,
        'end': weekInfo['end'] as DateTime,
      };
      QueryDocumentSnapshot? weekBudget;

      return FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _firestoreService.getBudgetsHebdomadairesForMonth(
            _currentUser!.uid, now.year, selectedMonth),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('DEBUG: Erreur dans FutureBuilder des budgets: ${snapshot.error}');
            return const Text('Erreur lors du chargement des budgets');
          }
          final budgets = snapshot.data ?? [];
          print('DEBUG: Budgets récupérés pour le mois: ${budgets.length}');
          try {
            weekBudget = budgets.firstWhere(
                  (b) {
                final periodeDebut = (b['periodeDebut'] as Timestamp).toDate();
                final periodeFin = (b['periodeFin'] as Timestamp).toDate();
                final startMatch = periodeDebut.year == week['start']!.year &&
                    periodeDebut.month == week['start']!.month &&
                    periodeDebut.day == week['start']!.day;
                final endMatch = periodeFin.year == week['end']!.year &&
                    periodeFin.month == week['end']!.month &&
                    periodeFin.day == week['end']!.day;
                print(
                    'DEBUG: Comparaison budget - periodeDebut=$periodeDebut, periodeFin=$periodeFin, startMatch=$startMatch, endMatch=$endMatch');
                return startMatch && endMatch;
              },
            );
          } catch (_) {
            weekBudget = null;
            print('DEBUG: Aucun budget trouvé pour la semaine courante');
          }
          double budgetMontant = 0.0;
          if (weekBudget != null && weekBudget?.data() != null) {
            final data = weekBudget!.data() as Map<String, dynamic>;
            budgetMontant = (data['montant'] as num?)?.toDouble() ?? 0.0;
            print('DEBUG: Budget trouvé - Montant=$budgetMontant');
          }
          final hasBudget = weekBudget != null;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.darkCardColors[0] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Budget hebdomadaire',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDarkMode
                                ? AppColors.darkTextColor
                                : Colors.blue.shade900,
                          ),
                        ),
                        Text(
                          'Semaine ${weekInfo['weekIndex'] + 1} : ${week['start']!.day}/${week['start']!.month} - ${week['end']!.day}/${week['end']!.month}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                              fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('depenses')
                          .where('userId', isEqualTo: _currentUser!.uid)
                          .where('dateCreation',
                          isGreaterThanOrEqualTo:
                          Timestamp.fromDate(week['start']!))
                          .where('dateCreation',
                          isLessThanOrEqualTo: Timestamp.fromDate(DateTime(
                              week['end']!.year,
                              week['end']!.month,
                              week['end']!.day,
                              23,
                              59,
                              59)))
                          .snapshots(),
                      builder: (context, depensesSnapshot) {
                        print(
                            'DEBUG: Période filtrée - Début=${week['start']} Fin=${DateTime(week['end']!.year, week['end']!.month, week['end']!.day, 23, 59, 59)}');
                        if (depensesSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }
                        if (depensesSnapshot.hasError) {
                          print(
                              'DEBUG: Erreur dans StreamBuilder des dépenses: ${depensesSnapshot.error}');
                          return const Text(
                              'Erreur lors du chargement des dépenses');
                        }
                        double totalDepenses = 0.0;
                        if (depensesSnapshot.hasData) {
                          totalDepenses = depensesSnapshot.data!.docs
                              .fold<double>(0.0, (sum, doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            print(
                                'DEBUG: Dépense trouvée - ID=${doc.id}, Montant=${data['montant']}, Date=${(data['dateCreation'] as Timestamp).toDate()}');
                            return sum + (data['montant'] as num?)!.toDouble();
                          });
                        }
                        print('DEBUG: Total dépenses calculé: $totalDepenses');
                        final pourcentage = hasBudget && budgetMontant > 0
                            ? (totalDepenses / budgetMontant * 100)
                            : 0;
                        final reste = hasBudget ? (budgetMontant - totalDepenses) : null;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Montant: ${hasBudget ? '${budgetMontant.toStringAsFixed(0)} FCFA' : 'Budget non défini'}',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                isDarkMode ? AppColors.darkTextColor : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dépenses: ${totalDepenses.toStringAsFixed(0)} FCFA${hasBudget && budgetMontant > 0 ? ' (${pourcentage.toStringAsFixed(1)}%)' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                isDarkMode ? AppColors.darkTextColor : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: hasBudget && budgetMontant > 0
                                  ? (pourcentage / 100).clamp(0.0, 1.0)
                                  : 0.0,
                              backgroundColor:
                              isDarkMode ? Colors.grey[700] : Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                hasBudget && budgetMontant > 0
                                    ? (pourcentage > 80
                                    ? Colors.red
                                    : (pourcentage > 50 ? Colors.orange : Colors.green))
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasBudget
                                  ? 'Reste: ${reste!.toStringAsFixed(0)} FCFA'
                                  : 'Reste: Budget non défini',
                              style: TextStyle(
                                fontSize: 12,
                                color: !hasBudget
                                    ? Colors.grey
                                    : (reste != null && reste < 0
                                    ? Colors.red
                                    : (isDarkMode
                                    ? AppColors.darkTextColor
                                    : Colors.black)),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // Handle monthly or annual budget
    DateTime periodeDebut;
    DateTime periodeFin;
    String titre = '';
    String periodeAffichee = '';
    if (_selectedBudgetType == 'mensuel') {
      periodeDebut = DateTime(now.year, selectedMonth, 1);
      periodeFin = DateTime(now.year, selectedMonth + 1, 0);
      titre = 'Budget mensuel';
      periodeAffichee = '${periodeDebut.day}/${periodeDebut.month} - ${periodeFin.day}/${periodeFin.month}';
    } else if (_selectedBudgetType == 'annuel') {
      periodeDebut = DateTime(now.year, 1, 1);
      periodeFin = DateTime(now.year, 12, 31);
      titre = 'Budget annuel';
      periodeAffichee = '${now.year}';
    } else {
      periodeDebut = DateTime(now.year, selectedMonth, 1);
      periodeFin = DateTime(now.year, selectedMonth + 1, 0);
      titre = 'Budget';
      periodeAffichee = '${periodeDebut.day}/${periodeDebut.month} - ${periodeFin.day}/${periodeFin.month}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkCardColors[0] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    titre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDarkMode ? AppColors.darkTextColor : Colors.blue.shade900,
                    ),
                  ),
                  Text(
                    periodeAffichee,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('budgets')
                    .where('userId', isEqualTo: _currentUser!.uid)
                    .where('type', isEqualTo: _selectedBudgetType)
                    .where('periodeDebut', isLessThanOrEqualTo: periodeDebut)
                    .where('periodeFin', isGreaterThanOrEqualTo: periodeFin)
                    .limit(1)
                    .snapshots(),
                builder: (context, budgetSnapshot) {
                  if (budgetSnapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  final budgetDoc = (budgetSnapshot.hasData && budgetSnapshot.data!.docs.isNotEmpty)
                      ? budgetSnapshot.data!.docs.first
                      : null;
                  final budgetMontant = (budgetDoc != null && budgetDoc['montant'] != null)
                      ? (budgetDoc['montant'] as num?)?.toDouble() ?? 0.0
                      : 0.0;
                  final hasBudget = budgetDoc != null;

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('depenses')
                        .where('userId', isEqualTo: _currentUser!.uid)
                        .where('dateCreation',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(periodeDebut))
                        .where('dateCreation',
                        isLessThanOrEqualTo: Timestamp.fromDate(periodeFin))
                        .snapshots(),
                    builder: (context, depensesSnapshot) {
                      if (depensesSnapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      double totalDepenses = 0.0;
                      if (depensesSnapshot.hasData) {
                        totalDepenses = depensesSnapshot.data!.docs.fold<double>(
                            0.0, (sum, doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return sum + (data['montant'] as num?)!.toDouble();
                        });
                      }
                      final pourcentage = hasBudget && budgetMontant > 0
                          ? (totalDepenses / budgetMontant * 100)
                          : 0;
                      final reste = hasBudget ? (budgetMontant - totalDepenses) : null;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Montant: ${hasBudget ? '${budgetMontant.toStringAsFixed(0)} FCFA' : 'Budget non défini'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? AppColors.darkTextColor : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dépenses: ${totalDepenses.toStringAsFixed(0)} FCFA${hasBudget && budgetMontant > 0 ? ' (${pourcentage.toStringAsFixed(1)}%)' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? AppColors.darkTextColor : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: hasBudget && budgetMontant > 0
                                ? (pourcentage / 100).clamp(0.0, 1.0)
                                : 0.0,
                            backgroundColor:
                            isDarkMode ? Colors.grey[700] : Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              hasBudget && budgetMontant > 0
                                  ? (pourcentage > 80
                                  ? Colors.red
                                  : (pourcentage > 50 ? Colors.orange : Colors.green))
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasBudget
                                ? 'Reste: ${reste!.toStringAsFixed(0)} FCFA'
                                : 'Reste: Budget non défini',
                            style: TextStyle(
                              fontSize: 12,
                              color: !hasBudget
                                  ? Colors.grey
                                  : (reste != null && reste < 0
                                  ? Colors.red
                                  : (isDarkMode
                                  ? AppColors.darkTextColor
                                  : Colors.black)),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _fetchCurrentBudget() async {
    if (_currentUser == null) return;
    DateTime periodeDebut;
    DateTime periodeFin;
    final now = DateTime.now();
    if (_selectedBudgetType == 'mensuel') {
      periodeDebut = DateTime(now.year, selectedMonth, 1);
      periodeFin = DateTime(now.year, selectedMonth + 1, 0);
    } else if (_selectedBudgetType == 'annuel') {
      periodeDebut = DateTime(now.year, 1, 1);
      periodeFin = DateTime(now.year, 12, 31);
    } else if (_selectedBudgetType == 'hebdomadaire') {
      final weekInfo = getCurrentWeekOfMonth(now.year, selectedMonth);
      periodeDebut = weekInfo['start'];
      periodeFin = weekInfo['end'];
    } else {
      periodeDebut = DateTime(now.year, selectedMonth, 1);
      periodeFin = DateTime(now.year, selectedMonth + 1, 0);
    }
    final doc = await _firestoreService.getBudgetForPeriod(
      _currentUser!.uid,
      periodeDebut,
      periodeFin,
      type: _selectedBudgetType,
    );
    if (mounted) {
      setState(() {
        _currentBudget = doc != null ? (doc['montant'] as num?)?.toDouble() : null;
      });
    }
  }
}

class _MonthDropdown extends StatelessWidget {
  final int selectedMonth;
  final ValueChanged<int?> onChanged;
  final bool isDarkMode;

  const _MonthDropdown({
    required this.selectedMonth,
    required this.onChanged,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkCardColors[1] : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedMonth,
          items: List.generate(12, (index) => index + 1).map((month) {
            return DropdownMenuItem<int>(
              value: month,
              child: Text(
                context.findAncestorStateOfType<_HomePageState>()?._getMonthName(month) ?? 'Mois inconnu',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? AppColors.darkTextColor : Colors.blue.shade900,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isDarkMode ? AppColors.darkTextColor : Colors.blue.shade900,
          ),
          dropdownColor: isDarkMode ? AppColors.darkCardColors[0] : Colors.white,
          icon: Icon(
            Icons.arrow_drop_down,
            color: isDarkMode ? AppColors.darkTextColor : Colors.blue.shade900,
          ),
          isDense: true,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}