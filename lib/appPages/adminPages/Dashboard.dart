import 'package:budget_zen/services/firebase/firestore.dart';
import 'package:budget_zen/services/firebase/auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/ForAdmin/admin_bottom_nav_bar.dart';
import '../../widgets/custom_app_bar.dart';

class DashboardAdminPage extends StatefulWidget {
  const DashboardAdminPage({super.key});

  @override
  State<DashboardAdminPage> createState() => _DashboardAdminPageState();
}

class _DashboardAdminPageState extends State<DashboardAdminPage> {
  final FirestoreService _firestore = FirestoreService();
  final Auth _auth = Auth();
  final DateFormat dateFormat = DateFormat('EEEE dd MMMM yyyy \'à\' HH:mm:ss', 'fr_FR');

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Tableau de bord Admin',
        showBackArrow: false,
        showDarkModeButton: true,
      ),
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/Administrateur.png'),
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                  colorFilter: ColorFilter.mode(
                    isDarkMode ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.2),
                    BlendMode.darken,
                  ),
                ),
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

  Widget _buildUsersList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.firestore.collection('utilisateurs').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur: ${snapshot.error}',
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

        final users = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userDoc = users[index];
            final userData = userDoc.data() as Map<String, dynamic>;
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    nomPrenom.toUpperCase(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (!isCurrentUser)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      _showDeleteDialog(uid, nomPrenom, context);
                    },
                  ),
              ],
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
              'Rôle: ${role.capitalize()}',
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off,
            size: 100,
            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String uid, String nomPrenom, BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Supprimer l'utilisateur"),
          content: Text("Voulez-vous vraiment supprimer l'utilisateur '$nomPrenom' et toutes ses données associées ?"),
          actions: [
            TextButton(
              child: const Text("Annuler"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _deleteUserAndData(uid);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Utilisateur supprimé avec succès")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur lors de la suppression: $e")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
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
        // Note : La suppression directe via FirebaseAuth.instance.currentUser.delete()
        // n'est pas possible ici car l'utilisateur actuel n'est pas l'utilisateur à supprimer.
        // Une solution serait d'utiliser l'API Admin SDK, mais cela nécessite un backend.
        // Pour l'instant, on peut signaler que cette opération nécessite des privilèges admin.
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