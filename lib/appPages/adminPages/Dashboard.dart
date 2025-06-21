import 'package:budget_zen/services/firebase/firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  final DateFormat dateFormat = DateFormat('EEEE dd MMMM yyyy \'à\' HH:mm:ss', 'fr_FR');
  String _searchQuery = '';
  String _selectedFilter = 'Tout';
  final Set<String> _selectedUids = {};

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
                onPressed: _deleteSelectedUsers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Supprimer les utilisateurs sélectionnés (${_selectedUids.length})', style: const TextStyle(color: Colors.white)),
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
                      backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Tout sélectionner', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
                  ),
                if (_selectedUids.isNotEmpty)
                  ElevatedButton(
                    onPressed: _deselectAllUsers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Tout décocher', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liste des Utilisateurs',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 8),
                    _buildFilterButtons(context),
                    const SizedBox(height: 8),
                    _buildUsersList(context),
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

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
            _selectedUids.clear(); // Désélectionner tous les utilisateurs lors d'une nouvelle recherche
          });
        },
        decoration: InputDecoration(
          hintText: 'Rechercher par nom, email ou date (JJ/MM/AAAA)...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[600]!
                  : Colors.grey[400]!,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[600]!
                  : Colors.grey[400]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]!
              : Colors.grey[200]!,
        ),
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
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
          children: ['Tout', 'Administrateur', 'Utilisateur']
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
      selectedColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
      checkmarkColor: isDarkMode ? Colors.white : Colors.black87,
      labelStyle: TextStyle(
        color: isSelected
            ? (isDarkMode ? Colors.white : Colors.black87)
            : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
      ),
      backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = selected ? label : 'Tout';
          _selectedUids.clear(); // Désélectionner tous les utilisateurs lors d'un changement de filtre
        });
      },
    );
  }

  Widget _buildUsersList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.firestore.collection('utilisateurs').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur: Une erreur s\'est produite. Veuillez réessayer.',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("Aucun utilisateur trouvé", context);
        }

        final users = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final nomPrenom = (data['nomPrenom'] as String?)?.toLowerCase() ?? '';
          final email = (data['email'] as String?)?.toLowerCase() ?? '';
          final role = (data['role'] as String?)?.toLowerCase() ?? '';
          final dateInscription = (data['dateInscription'] as Timestamp?)?.toDate();
          final derniereConnexion = (data['derniereConnexion'] as Timestamp?)?.toDate();

          // Vérification du filtre par rôle
          if (_selectedFilter != 'Tout' && role != _selectedFilter.toLowerCase()) {
            return false;
          }

          // Si la recherche est vide, on retourne tous les utilisateurs qui correspondent au filtre
          if (_searchQuery.isEmpty) {
            return true;
          }

          // Recherche par nom ou email
          if (nomPrenom.contains(_searchQuery) || email.contains(_searchQuery)) {
            return true;
          }

          // Recherche par date (format JJ/MM/AAAA ou JJ-MM-AAAA)
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
          return _buildEmptyState("Aucun utilisateur trouvé pour cette recherche ou filtre", context);
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userDoc = users[index];
            return _buildUserCard(userDoc, context);
          },
        );
      },
    );
  }

  Widget _buildUserCard(QueryDocumentSnapshot doc, BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final uid = doc.id;
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUser = uid == currentUserUid;

    final nomPrenom = isCurrentUser ? 'Vous' : (data['nomPrenom'] as String? ?? 'Non défini');
    final email = data['email'] as String? ?? 'Non défini';
    final role = data['role'] as String? ?? 'utilisateur';
    final dateInscription = (data['dateInscription'] as Timestamp?)?.toDate();
    final derniereConnexion = (data['derniereConnexion'] as Timestamp?)?.toDate();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (!isCurrentUser) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditUserPage(uid: uid),
            ),
          );
        }
      },
      child: MouseRegion(
        cursor: isCurrentUser ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: isDarkMode ? Colors.grey[800] : Colors.white,
          child: InkWell(
            onTap: () {
              if (!isCurrentUser) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditUserPage(uid: uid),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomPrenom.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Email: $email',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rôle: ${StringExtension(role).capitalize()}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (dateInscription != null)
                        Text(
                          'Inscription: ${dateFormat.format(dateInscription)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (derniereConnexion != null)
                        Text(
                          'Dernière connexion: ${dateFormat.format(derniereConnexion)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      if (!isCurrentUser)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Cliquez pour éditer >',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (!isCurrentUser)
                    Positioned(
                      top: 8,
                      right: 8,
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
                        activeColor: Colors.blue,
                        checkColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600; // Pour les téléphones

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/no-data.png',
                width: isSmallScreen ? 120 : 150,
                height: isSmallScreen ? 120 : 150,
                //color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.error_outline,
                  size: isSmallScreen ? 60 : 80,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: isSmallScreen ? 16 : 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8.0 : 16.0),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: isSmallScreen ? 16 : 24),
              if (_searchQuery.isNotEmpty || _selectedFilter != 'Tout')
                SizedBox(
                  width: isSmallScreen ? double.infinity : null, // Pleine largeur sur mobile
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _selectedFilter = 'Tout';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? Colors.blue[700] : Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 12 : 16,
                        horizontal: isSmallScreen ? 16 : 24,
                      ),
                    ),
                    child: Text(
                      'Réinitialiser la recherche',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.white,
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
        const SnackBar(content: Text("Aucun utilisateur sélectionné à supprimer ou vous ne pouvez pas supprimer votre propre compte.")),
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
      try {
        for (String uid in uidsToDelete) {
          await _deleteUserAndData(uid);
        }
        setState(() {
          _selectedUids.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${uidsToDelete.length} utilisateur(s) supprimé(s) avec succès"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la suppression: Une erreur s'est produite. Veuillez réessayer.")),
        );
      }
    }
  }

  void _selectAllUsers() {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final usersSnapshot = _firestore.firestore.collection('utilisateurs').snapshots();
    usersSnapshot.listen((snapshot) {
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