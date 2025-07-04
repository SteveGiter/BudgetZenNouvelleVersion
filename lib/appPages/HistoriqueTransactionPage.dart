import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../colors/app_colors.dart';
import '../services/firebase/firestore.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../services/firebase/messaging.dart';

class HistoriqueTransactionPage extends StatefulWidget {
  const HistoriqueTransactionPage({super.key});

  @override
  State<HistoriqueTransactionPage> createState() => _HistoriqueTransactionPageState();
}

class _HistoriqueTransactionPageState extends State<HistoriqueTransactionPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();
  final DateFormat dateFormat = DateFormat('EEEE dd MMMM yyyy \'à\' HH:mm:ss', 'fr_FR');
  String _selectedFilter = 'Tout';
  String _searchQuery = '';

  // Date actuelle mise à jour à 04:49 PM WAT, 20 juin 2025
  final DateTime currentDate = DateTime(2025, 6, 20, 16, 49); // 04:49 PM WAT, June 20, 2025

  Color _getCardColor(bool isIncome, BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? (isIncome ? AppColors.darkCardColors[1].withOpacity(0.2) : AppColors.darkCardColors[0].withOpacity(0.2))
        : (isIncome ? AppColors.cardColors[1] : AppColors.cardColors[0]);
  }

  Color _getTextColor(bool isIncome, BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? (isIncome ? AppColors.darkTertiaryColor : AppColors.darkSecondaryColor)
        : (isIncome ? AppColors.primaryColor : AppColors.secondaryColor);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Veuillez vous connecter")),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Historique des transactions',
        showBackArrow: false,
        showDarkModeButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 8),
            _buildFilterButtons(context),
            const SizedBox(height: 8),
            _buildTransactionList(currentUser.uid, context),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 1,
        onTabSelected: (index) {
          if (index != 1) {
            final routes = ['/HomePage', '/HistoriqueTransactionPage', '/historique-epargne-no-back', '/SettingsPage'];
            Navigator.pushReplacementNamed(context, routes[index]);
          }
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Rechercher une transaction...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBorderColor
                  : AppColors.borderColor,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBorderColor
                  : AppColors.borderColor,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkPrimaryColor
                  : AppColors.primaryColor,
            ),
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkCardColor
              : AppColors.cardColor,
        ),
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkTextColor
              : AppColors.textColor,
        ),
      ),
    );
  }

  Widget _buildFilterButtons(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: ['Tout', 'Dépense', 'Revenu']
              .map((label) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildFilterChip(label, context),
          ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, BuildContext context) {
    final isSelected = _selectedFilter == label;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: isDarkMode ? AppColors.darkButtonColor : AppColors.buttonColor,
      checkmarkColor: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor,
      labelStyle: TextStyle(
        color: isSelected
            ? (isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor)
            : (isDarkMode ? AppColors.darkTextColor : AppColors.textColor),
      ),
      backgroundColor: isDarkMode ? AppColors.darkCardColor : AppColors.cardColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isDarkMode ? AppColors.darkBorderColor : AppColors.borderColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = selected ? label : 'Tout';
        });
      },
    );
  }

  Widget _buildMonthHeader(DateTime date) {
    final moisAnnee = DateFormat('MMMM yyyy', 'fr_FR').format(date);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          const Expanded(
            child: Divider(thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              moisAnnee.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextColor
                    : AppColors.textColor,
              ),
            ),
          ),
          const Expanded(
            child: Divider(thickness: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(String userId, BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.firestore
          .collection('transactions')
          .where('users', arrayContains: userId)
          .orderBy('expediteurDeleted')
          .orderBy('destinataireDeleted')
          .orderBy('dateHeure', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur: ${snapshot.error}',
              style: const TextStyle(color: AppColors.errorColor),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkPrimaryColor
                  : AppColors.primaryColor,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("Aucune transaction trouvée", context);
        }

        final visibleTransactions = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final expediteurDeleted = data['expediteurDeleted'];
          final destinataireDeleted = data['destinataireDeleted'];
          final expediteurId = data['expediteurId'];
          final destinataireId = data['destinataireId'];

          if (expediteurId == userId && expediteurDeleted == userId) return false;
          if (destinataireId == userId && destinataireDeleted == userId) return false;
          return true;
        }).toList();

        final filteredTransactions = visibleTransactions.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final categorie = (data['categorie'] as String?)?.toLowerCase() ?? '';
          final montantStr = data['montant'].toString().toLowerCase();
          final isIncome = data['destinataireId'] == userId;
          if (_searchQuery.isNotEmpty && !categorie.contains(_searchQuery) && !montantStr.contains(_searchQuery)) return false;
          if (_selectedFilter == 'Revenu') return isIncome;
          if (_selectedFilter == 'Dépense') return !isIncome;
          return true;
        }).toList();

        if (filteredTransactions.isEmpty) {
          return _buildEmptyState("Aucune transaction pour '$_selectedFilter'", context);
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filteredTransactions.length,
          itemBuilder: (context, index) {
            final currentDoc = filteredTransactions[index];
            final currentData = currentDoc.data() as Map<String, dynamic>;
            final currentDate = (currentData['dateHeure'] as Timestamp).toDate();

            bool showMonthHeader = false;

            if (index == 0) {
              showMonthHeader = true;
            } else {
              final previousData = filteredTransactions[index - 1].data() as Map<String, dynamic>;
              final previousDate = (previousData['dateHeure'] as Timestamp).toDate();
              if (currentDate.month != previousDate.month || currentDate.year != previousDate.year) {
                showMonthHeader = true;
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showMonthHeader) _buildMonthHeader(currentDate),
                _buildTransactionCard(currentDoc, userId, context),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message, BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkSecondaryTextColor
        : AppColors.secondaryTextColor;

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - kToolbarHeight - kBottomNavigationBarHeight - 56,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Tooltip(
                message: 'Aucune transaction disponible',
                child: Image.asset(
                  'assets/noTransactionImage.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(fontSize: 16, color: color),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(QueryDocumentSnapshot doc, String userId, BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final montant = data['montant'] as num;
    final categorie = data['categorie'] as String;
    final isIncome = data['destinataireId'] == userId;
    final dateHeure = (data['dateHeure'] as Timestamp).toDate();

    final cardColor = _getCardColor(isIncome, context);
    final textColor = _getTextColor(isIncome, context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIncome ? 'REVENU' : 'DÉPENSE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        categorie.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${NumberFormat.decimalPattern('fr').format(montant)} FCFA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.errorColor),
                  onPressed: () {
                    _showDeleteDialog(doc.id, context, categorie);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(
                  dateFormat.format(dateHeure),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(String transactionId, BuildContext context, String description) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Supprimer la transaction"),
          content: const Text("Voulez-vous vraiment supprimer cette transaction ?"),
          actions: [
            TextButton(
              child: const Text("Annuler"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Supprimer"),
              onPressed: () async {
                Navigator.of(context).pop();
                await _firestoreService.softDeleteTransaction(transactionId, _auth.currentUser!.uid, description: description);
                await _messagingService.sendLocalNotification(
                  'Transaction supprimée',
                  'La transaction « $description » a bien été supprimée de votre historique.',
                );
              },
            ),
          ],
        );
      },
    );
  }
}