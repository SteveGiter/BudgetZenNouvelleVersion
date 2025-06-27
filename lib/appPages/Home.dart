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
  String _selectedBudgetType = 'mensuel';
  double? _currentBudget;

  StreamSubscription<DocumentSnapshot>? _compteSubscription;
  StreamSubscription<double>? _depensesSubscription;
  StreamSubscription<double>? _revenusSubscription;
  StreamSubscription<double>? _epargnesSubscription;
  final FirestoreService _firestoreService = FirestoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();

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
      _checkAndShowSavingsPlanDialog(context, rechargeAmount, rechargeTimestamp);
    }
  }

  Future<void> _checkAndShowSavingsPlanDialog(BuildContext context, double amount, String rechargeTimestamp) async {
    // Vérifier si la boîte de dialogue a déjà été fermée pour ce timestamp
    final prefs = await SharedPreferences.getInstance();
    final dialogClosedKey = 'savingsPlanDialogClosed_$rechargeTimestamp';
    if (prefs.getBool(dialogClosedKey) ?? false) {
      return; // Ne pas afficher si déjà fermé
    }

    bool isClosing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
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
                  Text('• 50% pour les besoins : ${amount * 0.50} FCFA'),
                  Text('• 30% pour les désirs : ${amount * 0.30} FCFA'),
                  Text('• 20% pour l\'épargne : ${amount * 0.20} FCFA'),
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
                      : () async {
                    setDialogState(() => isClosing = true);
                    try {
                      await prefs.setBool(dialogClosedKey, true);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } catch (e) {
                      // Gérer l'erreur silencieusement ou afficher une notification
                      _messagingService.sendLocalNotification(
                        'Erreur',
                        'Erreur lors de la fermeture : $e',
                      );
                      setDialogState(() => isClosing = false);
                    }
                  },
                  child: isClosing
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Fermer'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const SavingsGoalsPage()),
                      );
                    }
                  },
                  child: const Text('Définir des objectifs'),
                ),
              ],
            );
          },
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

  void _fetchCurrentBudget() async {
    if (_currentUser == null) return;
    DateTime now = DateTime.now();
    DateTime periodeDebut;
    DateTime periodeFin;
    if (_selectedBudgetType == 'mensuel') {
      periodeDebut = DateTime(now.year, now.month, 1);
      periodeFin = DateTime(now.year, now.month + 1, 0);
    } else if (_selectedBudgetType == 'annuel') {
      periodeDebut = DateTime(now.year, 1, 1);
      periodeFin = DateTime(now.year, 12, 31);
    } else {
      // hebdomadaire
      int weekday = now.weekday;
      DateTime monday = now.subtract(Duration(days: weekday - 1));
      DateTime sunday = monday.add(Duration(days: 6));
      periodeDebut = DateTime(monday.year, monday.month, monday.day);
      periodeFin = DateTime(sunday.year, sunday.month, sunday.day);
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

  @override
  void dispose() {
    _compteSubscription?.cancel();
    _depensesSubscription?.cancel();
    _revenusSubscription?.cancel();
    _epargnesSubscription?.cancel();
    super.dispose();
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
                  }
                });
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    color: isDarkMode ? AppColors.darkCardColors[0] : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet,
                              color: isDarkMode ? AppColors.darkSecondaryColor : Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Budget',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDarkMode ? AppColors.darkTextColor : Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Center(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedBudgetType,
                                  items: [
                                    DropdownMenuItem(value: 'hebdomadaire', child: Text('Hebdomadaire')),
                                    DropdownMenuItem(value: 'mensuel', child: Text('Mensuel')),
                                    DropdownMenuItem(value: 'annuel', child: Text('Annuel')),
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
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildBudgetRealtimeWidget(),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      SizedBox(
                        height: 220,
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
                              padding: const EdgeInsets.all(20),
                              child: Card(
                                elevation: 5.0,
                                child: IntrinsicWidth(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: isDarkMode
                                            ? AppColors.darkCardColors[index % AppColors.darkCardColors.length]
                                            : cardBgColor[index],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  cardIcons[index],
                                                  size: 32,
                                                  color: isDarkMode
                                                      ? AppColors.darkPrimaryColor
                                                      : AppColors.primaryColor,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  containerTitle[index],
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontFamily: 'LucidaCalligraphy',
                                                    color: isDarkMode
                                                        ? AppColors.darkTextColor
                                                        : AppColors.textColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            space,
                                            Text(
                                              'Montant : ${montant.toStringAsFixed(2)} FCFA',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: isDarkMode
                                                    ? AppColors.darkTextColor
                                                    : AppColors.textColor,
                                              ),
                                            ),
                                            space,
                                            Text(
                                              infoMontant[index],
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDarkMode
                                                    ? AppColors.darkSecondaryTextColor
                                                    : Colors.grey.shade600,
                                              ),
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

  Future<void> _showBudgetFormDialog(BuildContext context) async {
    final _formKey = GlobalKey<FormState>();
    final _amountController = TextEditingController();
    String _selectedType = 'mensuel';
    DateTime now = DateTime.now();
    DateTime periodeDebut = DateTime(now.year, now.month, 1);
    DateTime periodeFin = DateTime(now.year, now.month + 1, 0);
    bool _isSubmitting = false;

    void _updatePeriod(String type) {
      if (type == 'mensuel') {
        periodeDebut = DateTime(now.year, now.month, 1);
        periodeFin = DateTime(now.year, now.month + 1, 0);
      } else if (type == 'annuel') {
        periodeDebut = DateTime(now.year, 1, 1);
        periodeFin = DateTime(now.year, 12, 31);
      } else if (type == 'hebdomadaire') {
        // Trouver le lundi de la semaine courante
        int weekday = now.weekday;
        DateTime monday = now.subtract(Duration(days: weekday - 1));
        DateTime sunday = monday.add(Duration(days: 6));
        periodeDebut = DateTime(monday.year, monday.month, monday.day);
        periodeFin = DateTime(sunday.year, sunday.month, sunday.day);
      }
    }
    _updatePeriod(_selectedType);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Définir mon budget'),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Montant du budget'),
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
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      items: [
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
                      decoration: InputDecoration(labelText: 'Type de budget'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() => _isSubmitting = true);
                            // Vérification de l'existence d'un budget pour la période et le type
                            final existingBudget = await _firestoreService.getBudgetForPeriod(
                              _currentUser!.uid,
                              periodeDebut,
                              periodeFin,
                              type: _selectedType,
                            );
                            if (existingBudget != null) {
                              setState(() => _isSubmitting = false);
                              String errorMsg;
                              if (_selectedType == 'annuel') {
                                errorMsg = 'Vous avez déjà défini un budget annuel pour cette année.';
                              } else if (_selectedType == 'hebdomadaire') {
                                errorMsg = 'Vous avez déjà défini un budget hebdomadaire pour cette semaine.';
                              } else {
                                errorMsg = 'Vous avez déjà défini un budget mensuel pour ce mois.';
                              }
                              _messagingService.sendLocalNotification('Erreur', errorMsg);
                              return;
                            }
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
                              _messagingService.sendLocalNotification('Erreur', 'Erreur lors de l\'enregistrement du budget.');
                            }
                          }
                        },
                  child: _isSubmitting ? CircularProgressIndicator() : Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBudgetRealtimeWidget() {
    if (_currentUser == null) {
      return Text('-', style: TextStyle(color: Colors.grey[400], fontSize: 12));
    }
    DateTime now = DateTime.now();
    DateTime periodeDebut;
    DateTime periodeFin;
    if (_selectedBudgetType == 'mensuel') {
      periodeDebut = DateTime(now.year, now.month, 1);
      periodeFin = DateTime(now.year, now.month + 1, 0);
    } else if (_selectedBudgetType == 'annuel') {
      periodeDebut = DateTime(now.year, 1, 1);
      periodeFin = DateTime(now.year, 12, 31);
    } else {
      int weekday = now.weekday;
      DateTime monday = now.subtract(Duration(days: weekday - 1));
      DateTime sunday = monday.add(Duration(days: 6));
      periodeDebut = DateTime(monday.year, monday.month, monday.day);
      periodeFin = DateTime(sunday.year, sunday.month, sunday.day);
    }
    final query = FirebaseFirestore.instance
        .collection('budgets')
        .where('userId', isEqualTo: _currentUser!.uid)
        .where('periodeDebut', isEqualTo: Timestamp.fromDate(periodeDebut))
        .where('periodeFin', isEqualTo: Timestamp.fromDate(periodeFin))
        .where('type', isEqualTo: _selectedBudgetType)
        .limit(1)
        .snapshots();
    return StreamBuilder<QuerySnapshot>(
      stream: query,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(width: 60, child: LinearProgressIndicator(minHeight: 2));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Text('Aucun', style: TextStyle(color: Colors.grey[400], fontSize: 12));
        }
        final doc = snapshot.data!.docs.first;
        final montant = (doc['montant'] as num?)?.toDouble() ?? 0.0;
        return Text(
          '${montant.toStringAsFixed(0)} FCFA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.green[700],
          ),
        );
      },
    );
  }
}

class _MonthDropdown extends StatelessWidget {
  final int selectedMonth;
  final ValueChanged<int?> onChanged;

  const _MonthDropdown({
    required this.selectedMonth,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<int>(
        value: selectedMonth,
        underline: const SizedBox(),
        icon: Icon(Icons.arrow_drop_down, color: colors.onSurface),
        style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface),
        dropdownColor: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        items: List.generate(12, (index) => index + 1).map((month) {
          return DropdownMenuItem<int>(
            value: month,
            child: Text(
              _getMonthName(month),
              style: theme.textTheme.bodyMedium,
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre'
    ];
    return monthNames[month - 1];
  }
}