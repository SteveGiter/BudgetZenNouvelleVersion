import 'package:budget_zen/services/firebase/firestore.dart';
import 'package:budget_zen/services/firebase/messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../colors/app_colors.dart';
import '../../widgets/ForAdmin/admin_bottom_nav_bar.dart';
import '../../widgets/custom_app_bar.dart';
import 'EditUser.dart' hide StringExtension;

class DashboardAdminPage extends StatefulWidget {
  const DashboardAdminPage({super.key});

  @override
  State<DashboardAdminPage> createState() => _DashboardAdminPageState();
}

class _DashboardAdminPageState extends State<DashboardAdminPage> {
  final FirestoreService _firestore = FirestoreService();
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();
  final DateFormat dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
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
        _selectedUids.clear();
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
          // Statistics Section
            Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatCard(
                    icon: Icons.people,
                    label: 'Utilisateurs',
                    future: _getTotalUsers(),
                    isDarkMode: isDarkMode,
                    isSmallScreen: isSmallScreen,
                    color: Colors.blue,
                  ),
                  _buildStatCard(
                    icon: Icons.admin_panel_settings,
                    label: 'Admins',
                    future: _getTotalAdmins(),
                    isDarkMode: isDarkMode,
                    isSmallScreen: isSmallScreen,
                    color: Colors.green,
                  ),
                  _buildStatCard(
                    icon: Icons.swap_horiz,
                    label: 'Transactions',
                    future: _getTotalTransactions(),
                    isDarkMode: isDarkMode,
                    isSmallScreen: isSmallScreen,
                    color: Colors.orange,
                  ),
                  _buildStatCard(
                    icon: Icons.account_balance_wallet,
                    label: 'Solde',
                    future: _getTotalSolde().then((value) => NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(value)),
                    isDarkMode: isDarkMode,
                    isSmallScreen: isSmallScreen,
                    color: Colors.purple,
                  ),
                ],
              ),
            ),
          ),
          // Action Bar
          _buildActionBar(
            isDarkMode: isDarkMode,
            isSmallScreen: isSmallScreen,
            onSelectAll: _selectAllUsers,
            onDeselectAll: _deselectAllUsers,
            onDelete: _deleteSelectedUsers,
            hasSelection: _selectedUids.isNotEmpty,
            selectedCount: _selectedUids.length,
            isDeleting: _isDeleting,
          ),
          // User List Section
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(8),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                color: isDarkMode ? AppColors.darkCardColor : AppColors.cardColor,
                child: Column(
                  children: [
                    _buildSearchBar(isDarkMode, isSmallScreen),
                    _buildFilterButtons(context, isDarkMode, isSmallScreen),
                  const Divider(height: 1),
                  Expanded(child: _buildUsersList(context, isDarkMode, isSmallScreen)),
                  ],
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

  // Simplified Stat Card
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required Future future,
    required bool isDarkMode,
    required bool isSmallScreen,
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: isSmallScreen ? 100 : 120,
        padding: const EdgeInsets.all(8),
        child: FutureBuilder(
          future: future,
          builder: (context, snapshot) {
            String value = snapshot.hasData ? snapshot.data.toString() : '0';
            if (snapshot.hasError) value = 'Erreur';

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: isSmallScreen ? 20 : 24, color: color),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 12 : 14,
                    color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 12,
                    color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Simplified Search Bar
  Widget _buildSearchBar(bool isDarkMode, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher (nom, email, JJ/MM/AAAA)',
          prefixIcon: Icon(Icons.search, size: isSmallScreen ? 18 : 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, size: isSmallScreen ? 18 : 20),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedUids.clear();
              });
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: isDarkMode ? AppColors.darkBorderColor : AppColors.borderColor),
          ),
          filled: true,
          fillColor: isDarkMode ? AppColors.darkCardColor : AppColors.cardColor,
          contentPadding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 12, horizontal: 12),
        ),
        style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
      ),
    );
  }

  // Simplified Filter Buttons
  Widget _buildFilterButtons(BuildContext context, bool isDarkMode, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
        child: Row(
          children: ['Tout', 'Administrateur', 'Utilisateur'].map((label) {
            return Padding(
              padding: const EdgeInsets.only(right: 4),
      child: FilterChip(
                label: Text(label, style: TextStyle(fontSize: isSmallScreen ? 10 : 12)),
                selected: _selectedFilter == label,
        selectedColor: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
        backgroundColor: isDarkMode ? AppColors.darkCardColor : AppColors.cardColor,
        shape: RoundedRectangleBorder(
                  side: BorderSide(color: isDarkMode ? AppColors.darkBorderColor : AppColors.borderColor),
                  borderRadius: BorderRadius.circular(8),
        ),
        onSelected: (bool selected) {
          setState(() {
            _selectedFilter = selected ? label : 'Tout';
            _selectedUids.clear();
          });
        },
                labelStyle: TextStyle(
                  color: _selectedFilter == label
                      ? Colors.white
                      : (isDarkMode ? AppColors.darkTextColor : AppColors.textColor),
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Scrollable User List
  Widget _buildUsersList(BuildContext context, bool isDarkMode, bool isSmallScreen) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.firestore.collection('utilisateurs').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur de chargement',
              style: TextStyle(color: Colors.red, fontSize: isSmallScreen ? 12 : 14),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("Aucun utilisateur", context, isDarkMode, isSmallScreen);
        }

        final users = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final nomPrenom = (data['nomPrenom'] as String?)?.toLowerCase() ?? '';
          final email = (data['email'] as String?)?.toLowerCase() ?? '';
          final role = (data['role'] as String?)?.toLowerCase() ?? '';
          final dateInscription = (data['dateInscription'] as Timestamp?)?.toDate();
          final derniereConnexion = (data['derniereConnexion'] as Timestamp?)?.toDate();

          if (_selectedFilter != 'Tout' && role != _selectedFilter.toLowerCase()) return false;
          if (_searchQuery.isEmpty) return true;

          if (nomPrenom.contains(_searchQuery) || email.contains(_searchQuery)) return true;

          final datePattern = RegExp(r'^\d{2}[/-]\d{2}[/-]\d{4} ');
          if (datePattern.hasMatch(_searchQuery)) {
            final formattedSearchDate = _searchQuery.replaceAll('-', '/');
            if (dateInscription != null &&
                DateFormat('dd/MM/yyyy').format(dateInscription) == formattedSearchDate) {
                return true;
            }
            if (derniereConnexion != null &&
                DateFormat('dd/MM/yyyy').format(derniereConnexion) == formattedSearchDate) {
                return true;
            }
          }
          return false;
        }).toList();

        if (users.isEmpty) {
          return _buildEmptyState("Aucun résultat", context, isDarkMode, isSmallScreen);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            return _buildUserCard(users[index], context, isDarkMode, isSmallScreen);
          },
        );
      },
    );
  }

  // Simplified User Card
  Widget _buildUserCard(QueryDocumentSnapshot doc, BuildContext context, bool isDarkMode, bool isSmallScreen) {
    final data = doc.data() as Map<String, dynamic>;
    final uid = doc.id;
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUser = uid == currentUserUid;
    final nomPrenom = isCurrentUser ? 'Vous' : (data['nomPrenom'] as String? ?? 'Non défini');
    final email = data['email'] as String? ?? 'Non défini';
    final role = data['role'] as String? ?? 'utilisateur';
    final dateInscription = (data['dateInscription'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap: isCurrentUser
              ? null
            : () => Navigator.push(context, MaterialPageRoute(builder: (context) => EditUserPage(uid: uid))),
        borderRadius: BorderRadius.circular(8),
          child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
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
                            fontSize: isSmallScreen ? 12 : 14,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
                            ),
                          ),
                        ),
                        if (!isCurrentUser)
                        Icon(Icons.edit, size: isSmallScreen ? 16 : 18, color: isDarkMode ? AppColors.darkIconColor : AppColors.iconColor),
                    ],
                  ),
                    const SizedBox(height: 4),
                  Text('Email: $email', style: TextStyle(fontSize: isSmallScreen ? 10 : 12)),
                  Text('Rôle: ${role.capitalize()}', style: TextStyle(fontSize: isSmallScreen ? 10 : 12)),
                    if (dateInscription != null)
                    Text('Inscription: ${dateFormat.format(dateInscription)}', style: TextStyle(fontSize: isSmallScreen ? 10 : 12)),
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
                        if (value!) _selectedUids.add(uid);
                        else _selectedUids.remove(uid);
                        });
                      },
                      activeColor: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
                  ),
                  ),
              ],
          ),
        ),
      ),
    );
  }

  // Simplified Empty State
  Widget _buildEmptyState(String message, BuildContext context, bool isDarkMode, bool isSmallScreen) {
    return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(Icons.person_off, size: isSmallScreen ? 40 : 60, color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor),
          const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
                  color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/addusersPage'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? AppColors.darkButtonColor : AppColors.buttonColor,
                      foregroundColor: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 8 : 12),
            ),
            child: Text('Ajouter un utilisateur', style: TextStyle(fontSize: isSmallScreen ? 12 : 14, color: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor)),
          ),
        ],
      ),
    );
  }

  // Simplified Action Bar
  Widget _buildActionBar({
    required bool isDarkMode,
    required bool isSmallScreen,
    required VoidCallback? onSelectAll,
    required VoidCallback? onDeselectAll,
    required VoidCallback? onDelete,
    required bool hasSelection,
    required int selectedCount,
    required bool isDeleting,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          if (!hasSelection)
            ElevatedButton(
              onPressed: onSelectAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? AppColors.darkButtonColor : AppColors.buttonColor,
                foregroundColor: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmallScreen ? 8 : 10),
                    ),
                    child: Text(
                'Sélectionner',
                      style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                        color: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor,
                      ),
                    ),
                  ),
          if (hasSelection) ...[
            ElevatedButton(
              onPressed: onDeselectAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? AppColors.darkButtonColor : AppColors.buttonColor,
                    foregroundColor: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmallScreen ? 8 : 10),
                  ),
                  child: Text(
                'Tout décocher',
                    style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                      color: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor,
                    ),
                  ),
                ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isDeleting ? null : onDelete,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmallScreen ? 8 : 10),
              ),
              child: isDeleting
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : Text(
                'Supprimer ($selectedCount)',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Firestore Queries
  Future<int> _getTotalUsers() async {
    final snap = await _firestore.firestore.collection('utilisateurs').get();
    return snap.size;
  }

  Future<int> _getTotalAdmins() async {
    final snap = await _firestore.firestore.collection('utilisateurs').where('role', isEqualTo: 'administrateur').get();
    return snap.size;
  }

  Future<int> _getTotalTransactions() async {
    final snap = await _firestore.firestore.collection('transactions').get();
    return snap.size;
  }

  Future<double> _getTotalSolde() async {
    final snap = await _firestore.firestore.collection('comptesMobiles').get();
    double total = 0;
    for (var doc in snap.docs) {
      total += (doc.data()['montantDisponible'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  // Delete Selected Users
  Future<void> _deleteSelectedUsers() async {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final uidsToDelete = _selectedUids.where((uid) => uid != currentUserUid).toList();

    if (uidsToDelete.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun utilisateur sélectionné'), backgroundColor: Colors.red),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer ${uidsToDelete.length} utilisateur(s) ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);
      try {
        for (String uid in uidsToDelete) {
          await _deleteUserAndData(uid);
        }
        await _messagingService.sendLocalNotification('Succès', '${uidsToDelete.length} utilisateur(s) supprimé(s).');
        setState(() => _selectedUids.clear());
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      } finally {
        setState(() => _isDeleting = false);
      }
    }
  }

  // Select All Users
  Future<void> _selectAllUsers() async {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final snapshot = await _firestore.firestore.collection('utilisateurs').get();
    final allUids = snapshot.docs
        .where((doc) => _selectedFilter == 'Tout' || (doc.data() as Map<String, dynamic>)['role']?.toLowerCase() == _selectedFilter.toLowerCase())
        .map((doc) => doc.id)
        .where((uid) => uid != currentUserUid)
        .toList();
    setState(() {
      _selectedUids.clear();
      _selectedUids.addAll(allUids);
    });
  }

  // Deselect All Users
  void _deselectAllUsers() => setState(() => _selectedUids.clear());

  // Delete User and Data
  Future<void> _deleteUserAndData(String uid) async {
      final batch = _firestore.firestore.batch();
    batch.delete(_firestore.firestore.collection('utilisateurs').doc(uid));
    batch.delete(_firestore.firestore.collection('statistiques').doc(uid));
    final transactions = await _firestore.firestore.collection('transactions').where('users', arrayContains: uid).get();
    for (var doc in transactions.docs) batch.delete(doc.reference);
    final objectifs = await _firestore.firestore.collection('objectifsEpargne').where('userId', isEqualTo: uid).get();
    for (var doc in objectifs.docs) batch.delete(doc.reference);
    final revenus = await _firestore.firestore.collection('revenus').where('userId', isEqualTo: uid).get();
    for (var doc in revenus.docs) batch.delete(doc.reference);
    final depenses = await _firestore.firestore.collection('depenses').where('userId', isEqualTo: uid).get();
    for (var doc in depenses.docs) batch.delete(doc.reference);
    final epargnes = await _firestore.firestore.collection('epargnes').where('userId', isEqualTo: uid).get();
    for (var doc in epargnes.docs) batch.delete(doc.reference);
    final historique = await _firestore.firestore.collection('historique_connexions').where('uid', isEqualTo: uid).get();
    for (var doc in historique.docs) batch.delete(doc.reference);
    batch.delete(_firestore.firestore.collection('comptesMobiles').doc(uid));
      await batch.commit();
      _firestore.cancelStatisticsSubscription(uid);
  }
}

extension StringExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
}