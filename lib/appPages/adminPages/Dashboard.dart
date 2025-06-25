import 'package:budget_zen/services/firebase/firestore.dart';
import 'package:budget_zen/services/firebase/messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../colors/app_colors.dart';
import '../../widgets/ForAdmin/admin_bottom_nav_bar.dart';
import '../../widgets/custom_app_bar.dart';
import 'EditUser.dart';

class DashboardAdminPage extends StatefulWidget {
  const DashboardAdminPage({super.key});

  @override
  State<DashboardAdminPage> createState() => _DashboardAdminPageState();
}

class _DashboardAdminPageState extends State<DashboardAdminPage> {
  final FirestoreService _firestore = FirestoreService();
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();
  final DateFormat dateFormat = DateFormat('EEEE dd MMMM yyyy \'à\' HH:mm:ss', 'fr_FR');
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'Tout';
  final Set<String> _selectedUids = {};
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _selectedUids.clear(); // Désélectionner tous les utilisateurs lors d'une nouvelle recherche
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackgroundColor : AppColors.backgroundColor,
      appBar: CustomAppBar(
        title: 'Tableau de bord Admin',
        showBackArrow: false,
        showDarkModeButton: true,
      ),
      body: Column(
        children: [
          if (_selectedUids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _isDeleting ? null : _deleteSelectedUsers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: AppColors.buttonTextColor,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 24,
                    vertical: isSmallScreen ? 12 : 16,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
                child: _isDeleting
                    ? CircularProgressIndicator(color: AppColors.buttonTextColor)
                    : Text(
                  'Supprimer (${_selectedUids.length})',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: AppColors.buttonTextColor,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_selectedUids.isEmpty)
                  ElevatedButton(
                    onPressed: _selectAllUsers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? AppColors.darkCardColor : AppColors.cardColor,
                      foregroundColor: isDarkMode ? AppColors.darkButtonTextColor : Colors.black, // Changé ici (optionnel)
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : 24,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                    ),
                    child: Text(
                      'Tout sélectionner',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: isDarkMode ? AppColors.darkButtonTextColor : Colors.black, // Changé ici
                      ),
                    ),
                  ),
                if (_selectedUids.isNotEmpty)
                  ElevatedButton(
                    onPressed: _deselectAllUsers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? AppColors.darkCardColor : AppColors.cardColor,
                      foregroundColor: isDarkMode ? AppColors.darkButtonTextColor : Colors.black,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : 24,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                    ),
                    child: Text(
                      'Tout décocher',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: isDarkMode ? AppColors.darkButtonTextColor : Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.darkCardColor : AppColors.cardColor,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liste des Utilisateurs',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSearchBar(isDarkMode, isSmallScreen),
                    const SizedBox(height: 12),
                    _buildFilterButtons(context, isDarkMode, isSmallScreen),
                    const SizedBox(height: 12),
                    _buildUsersList(context, isDarkMode, isSmallScreen),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AdminBottomNavBar(
        currentIndex: 0,
        onTabSelected: (index) {
          if (index != 0) {
            final routes = ['/dashboardPage', '/addusersPage', '/adminProfilPage'];
            Navigator.pushReplacementNamed(context, routes[index]);
          }
        },
      ),
    );
  }

  Widget _buildSearchBar(bool isDarkMode, bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? AppColors.darkBorderColor : AppColors.borderColor,
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher par nom, email ou date (JJ/MM/AAAA)...',
          prefixIcon: Icon(
            Icons.search,
            color: isDarkMode ? AppColors.darkIconColor : AppColors.iconColor,
            size: isSmallScreen ? 20 : 24,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(
              Icons.clear,
              color: isDarkMode ? AppColors.darkIconColor : AppColors.iconColor,
              size: isSmallScreen ? 20 : 24,
            ),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedUids.clear();
              });
            },
          )
              : null,
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
            fontSize: isSmallScreen ? 14 : 16,
          ),
          filled: true,
          fillColor: isDarkMode ? AppColors.darkCardColor : AppColors.cardColor,
        ),
        style: TextStyle(
          color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
          fontSize: isSmallScreen ? 14 : 16,
        ),
      ),
    );
  }

  Widget _buildFilterButtons(BuildContext context, bool isDarkMode, bool isSmallScreen) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: ['Tout', 'Administrateur', 'Utilisateur'].map((label) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(label, context, isDarkMode, isSmallScreen),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, BuildContext context, bool isDarkMode, bool isSmallScreen) {
    final isSelected = _selectedFilter == label;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            color: isSelected
                ? (isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor)
                : (isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor),
          ),
        ),
        selected: isSelected,
        selectedColor: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
        checkmarkColor: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor,
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
            _selectedUids.clear();
          });
        },
      ),
    );
  }

  Widget _buildUsersList(BuildContext context, bool isDarkMode, bool isSmallScreen) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.firestore.collection('utilisateurs').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur : Une erreur s\'est produite. Veuillez réessayer.',
              style: TextStyle(
                color: Colors.red,
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("Aucun utilisateur trouvé", context, isDarkMode, isSmallScreen);
        }

        final users = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final nomPrenom = (data['nomPrenom'] as String?)?.toLowerCase() ?? '';
          final email = (data['email'] as String?)?.toLowerCase() ?? '';
          final role = (data['role'] as String?)?.toLowerCase() ?? '';
          final dateInscription = (data['dateInscription'] as Timestamp?)?.toDate();
          final derniereConnexion = (data['derniereConnexion'] as Timestamp?)?.toDate();

          if (_selectedFilter != 'Tout' && role != _selectedFilter.toLowerCase()) {
            return false;
          }

          if (_searchQuery.isEmpty) {
            return true;
          }

          if (nomPrenom.contains(_searchQuery) || email.contains(_searchQuery)) {
            return true;
          }

          final datePattern = RegExp(r'^\d{2}[/-]\d{2}[/-]\d{4}$');
          if (datePattern.hasMatch(_searchQuery)) {
            final formattedSearchDate = _searchQuery.replaceAll('-', '/');
            if (dateInscription != null) {
              final inscriptionDateStr = DateFormat('dd/MM/yyyy').format(dateInscription);
              if (inscriptionDateStr == formattedSearchDate) {
                return true;
              }
            }
            if (derniereConnexion != null) {
              final connexionDateStr = DateFormat('dd/MM/yyyy').format(derniereConnexion);
              if (connexionDateStr == formattedSearchDate) {
                return true;
              }
            }
          }

          return false;
        }).toList();

        if (users.isEmpty) {
          return _buildEmptyState("Aucun utilisateur trouvé pour cette recherche ou filtre", context, isDarkMode, isSmallScreen);
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userDoc = users[index];
            return _buildUserCard(userDoc, context, isDarkMode, isSmallScreen);
          },
        );
      },
    );
  }

  Widget _buildUserCard(QueryDocumentSnapshot doc, BuildContext context, bool isDarkMode, bool isSmallScreen) {
    final data = doc.data() as Map<String, dynamic>;
    final uid = doc.id;
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUser = uid == currentUserUid;

    final nomPrenom = isCurrentUser ? 'Vous' : (data['nomPrenom'] as String? ?? 'Non défini');
    final email = data['email'] as String? ?? 'Non défini';
    final role = data['role'] as String? ?? 'utilisateur';
    final dateInscription = (data['dateInscription'] as Timestamp?)?.toDate();
    final derniereConnexion = (data['derniereConnexion'] as Timestamp?)?.toDate();

    return MouseRegion(
      cursor: isCurrentUser ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: isDarkMode ? AppColors.darkCardColor : AppColors.cardColor,
        child: InkWell(
          onTap: isCurrentUser
              ? null
              : () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditUserPage(uid: uid),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            nomPrenom.toUpperCase(),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
                            ),
                          ),
                        ),
                        if (!isCurrentUser)
                          Icon(
                            Icons.edit,
                            size: isSmallScreen ? 18 : 20,
                            color: isDarkMode ? AppColors.darkIconColor : AppColors.iconColor,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Email: $email',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rôle: ${StringExtension(role).capitalize()}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (dateInscription != null)
                      Text(
                        'Inscription: ${dateFormat.format(dateInscription)}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
                        ),
                      ),
                    const SizedBox(height: 4),
                    if (derniereConnexion != null)
                      Text(
                        'Dernière connexion: ${dateFormat.format(derniereConnexion)}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
                        ),
                      ),
                  ],
                ),
                if (!isCurrentUser)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Checkbox(
                      value: _selectedUids.contains(uid),
                      onChanged: (value) {
                        setState(() {
                          if (value!) {
                            _selectedUids.add(uid);
                          } else {
                            _selectedUids.remove(uid);
                          }
                        });
                      },
                      activeColor: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
                      checkColor: AppColors.buttonTextColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, BuildContext context, bool isDarkMode, bool isSmallScreen) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_off,
                size: isSmallScreen ? 60 : 80,
                color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
              ),
              SizedBox(height: isSmallScreen ? 16 : 24),
              Text(
                message,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isSmallScreen ? 16 : 24),
              if (_searchQuery.isNotEmpty || _selectedFilter != 'Tout')
                SizedBox(
                  width: isSmallScreen ? double.infinity : 200,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _selectedFilter = 'Tout';
                        _selectedUids.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? AppColors.darkButtonColor : AppColors.buttonColor,
                      foregroundColor: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 12 : 16,
                        horizontal: isSmallScreen ? 16 : 24,
                      ),
                      elevation: 3,
                    ),
                    child: Text(
                      'Réinitialiser la recherche',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor,
                      ),
                    ),
                  ),
                ),
              SizedBox(height: isSmallScreen ? 8 : 12),
              SizedBox(
                width: isSmallScreen ? double.infinity : 200,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/addusersPage');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? AppColors.darkButtonColor : AppColors.buttonColor,
                    foregroundColor: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 12 : 16,
                      horizontal: isSmallScreen ? 16 : 24,
                    ),
                    elevation: 3,
                  ),
                  child: Text(
                    'Ajouter un utilisateur',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSelectedUsers() async {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final uidsToDelete = _selectedUids.where((uid) => uid != currentUserUid).toList();

    if (uidsToDelete.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text("Aucun utilisateur sélectionné ou vous ne pouvez pas supprimer votre propre compte."),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: Text("Voulez-vous vraiment supprimer ${uidsToDelete.length} utilisateur(s) et toutes leurs données associées ?"),
        actions: [
          TextButton(
            child: const Text("Annuler"),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() {
        _isDeleting = true;
      });
      try {
        for (String uid in uidsToDelete) {
          await _deleteUserAndData(uid);
        }
        await _messagingService.sendLocalNotification(
          'Utilisateurs supprimés',
          '${uidsToDelete.length} utilisateur(s) supprimé(s) avec succès.',
        );
        setState(() {
          _selectedUids.clear();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text("Erreur lors de la suppression : $e")),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } finally {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _selectAllUsers() async {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final snapshot = await _firestore.firestore.collection('utilisateurs').get();
    final allUids = snapshot.docs
        .where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final role = (data['role'] as String?)?.toLowerCase() ?? '';
      return _selectedFilter == 'Tout' || role == _selectedFilter.toLowerCase();
    })
        .map((doc) => doc.id)
        .where((uid) => uid != currentUserUid)
        .toList();
    setState(() {
      _selectedUids.clear();
      _selectedUids.addAll(allUids);
    });
  }

  void _deselectAllUsers() {
    setState(() {
      _selectedUids.clear();
    });
  }

  Future<void> _deleteUserAndData(String uid) async {
    try {
      final batch = _firestore.firestore.batch();

      // Suppression du document utilisateur
      final userRef = _firestore.firestore.collection('utilisateurs').doc(uid);
      batch.delete(userRef);

      // Suppression du document budget
      final budgetRef = _firestore.firestore.collection('budgets').doc(uid);
      batch.delete(budgetRef);

      // Suppression du document statistiques
      final statsRef = _firestore.firestore.collection('statistiques').doc(uid);
      batch.delete(statsRef);

      // Suppression des transactions impliquant l'utilisateur
      final transactionsSnapshot = await _firestore.firestore
          .collection('transactions')
          .where('users', arrayContains: uid)
          .get();
      for (var doc in transactionsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Suppression des objectifs d'épargne
      final objectifsSnapshot = await _firestore.firestore
          .collection('objectifsEpargne')
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in objectifsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Suppression des revenus
      final revenusSnapshot = await _firestore.firestore
          .collection('revenus')
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in revenusSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Suppression des dépenses
      final depensesSnapshot = await _firestore.firestore
          .collection('depenses')
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in depensesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Suppression des épargnes
      final epargnesSnapshot = await _firestore.firestore
          .collection('epargnes')
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in epargnesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Suppression de l'historique de connexion
      final historiqueSnapshot = await _firestore.firestore
          .collection('historique_connexions')
          .where('uid', isEqualTo: uid)
          .get();
      for (var doc in historiqueSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Suppression du compte mobile
      final compteMobileRef = _firestore.firestore.collection('comptesMobiles').doc(uid);
      batch.delete(compteMobileRef);

      // Validation du batch Firestore
      await batch.commit();

      // Annulation des abonnements actifs
      _firestore.cancelStatisticsSubscription(uid);

      // Suppression du compte dans Firebase Authentication
      try {
        print('Note : La suppression du compte Firebase Authentication nécessite l\'Admin SDK.');
      } catch (e) {
        print('Erreur lors de la tentative de suppression du compte Auth: $e');
        throw Exception('Impossible de supprimer le compte d\'authentification. Utilisez l\'Admin SDK.');
      }
    } catch (e) {
      print('Erreur lors de la suppression des données: $e');
      rethrow;
    }
  }
}

// Extension pour capitaliser les chaînes
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}