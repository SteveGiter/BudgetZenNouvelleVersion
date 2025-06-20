import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../colors/app_colors.dart';
import '../services/firebase/firestore.dart';
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
    Icons.account_balance_wallet,
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

  StreamSubscription<DocumentSnapshot>? _compteSubscription;
  StreamSubscription<double>? _depensesSubscription;
  StreamSubscription<double>? _revenusSubscription;
  StreamSubscription<double>? _epargnesSubscription;
  final FirestoreService _firestoreService = FirestoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
                Icons.bar_chart,
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
          : ListView(
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
                      MaterialPageRoute(builder: (context) => const RechargePage()),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être connecté pour ajouter une épargne'),
          backgroundColor: Colors.red,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: Text('Vous devez être connecté pour ajouter une épargne.')),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final compteRef = FirebaseFirestore.instance.collection('comptesMobiles').doc(_currentUser!.uid);
        final objectifRef = FirebaseFirestore.instance.collection('objectifsEpargne').doc(goalId);

        final compteSnap = await transaction.get(compteRef);
        final objectifSnap = await transaction.get(objectifRef);

        if (!compteSnap.exists) {
          throw Exception('Document compte introuvable.');
        }
        if (!objectifSnap.exists) {
          throw Exception('Objectif d\'épargne introuvable.');
        }

        final compteData = compteSnap.data();
        final objectifData = objectifSnap.data();

        if (compteData == null || objectifData == null) {
          throw Exception('Données invalides ou corrompues.');
        }

        final currentMontant = (compteData['montantDisponible'] as num?)?.toDouble() ?? 0.0;
        final currentMontantActuel = (objectifData['montantActuel'] as num?)?.toDouble() ?? 0.0;
        final montantCible = (objectifData['montantCible'] as num?)?.toDouble() ?? 0.0;
        final isCompleted = (objectifData['isCompleted'] as bool?) ?? false;
        final dateLimite = objectifData['dateLimite'] as Timestamp?;

        if (dateLimite != null && dateLimite.toDate().isBefore(DateTime.now())) {
          throw Exception('Objectif expiré.');
        }

        if (isCompleted || currentMontantActuel >= montantCible) {
          throw Exception('Cet objectif est déjà atteint.');
        }

        if (currentMontant < amount) {
          throw Exception('Solde insuffisant.');
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text('Épargne de ${amount.toStringAsFixed(2)} FCFA ajoutée avec succès')),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text('Erreur: ${e.toString()}')),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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