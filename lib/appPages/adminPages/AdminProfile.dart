import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../colors/app_colors.dart';
import '../../services/firebase/auth.dart';
import '../../services/firebase/firestore.dart';
import '../../services/firebase/messaging.dart';
import '../../utils/logout_utils.dart';
import '../../widgets/ForAdmin/admin_bottom_nav_bar.dart';
import '../../widgets/custom_app_bar.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  final Auth _authService = Auth();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();

  // Controllers for input fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // State variables
  bool _isEditingPassword = false;
  bool _isObscuringPassword = true;
  bool _isEditingName = false;
  bool _isEditingPhone = false;
  bool _isProcessing = false;
  bool _isLoading = true;
  bool _isAdmin = false;

  User? _currentUser;
  String _selectedCountryCode = '+237';
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  // Country codes with flags
  static const Map<String, String> _countryCodes = {
    '+237': '🇨🇲 Cameroun',
    '+242': '🇨🇬 Congo',
    '+241': '🇬🇦 Gabon',
    '+235': '🇹🇩 Tchad',
  };

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  /// Initializes user data and checks admin status.
  void _initializeUserData() {
    _currentUser = _authService.currentUser;
    if (_currentUser != null) {
      _checkAdminStatus();
    } else {
      setState(() => _isLoading = false);
      _showError('Aucun utilisateur connecté.');
    }
  }

  /// Checks if the current user is an admin and sets up data streams.
  Future<void> _checkAdminStatus() async {
    try {
      final userDoc = await _firestoreService.firestore
          .collection('utilisateurs')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        if (data?['role'] == 'administrateur') {
          setState(() => _isAdmin = true);
          _setupUserStreams();
          _loadInitialUserData();
        } else {
          if (!mounted) return;
          setState(() {
            _isAdmin = false;
            _isLoading = false;
          });
          _showError('Accès réservé aux administrateurs.');
        }
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showError('Utilisateur non trouvé.');
      }
    } catch (e) {
      _showError('Erreur lors de la vérification du statut admin: ${e.toString()}');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Sets up streams to listen for user data updates.
  void _setupUserStreams() {
    _userDataSubscription = _firestoreService.firestore
        .collection('utilisateurs')
        .doc(_currentUser!.uid)
        .snapshots()
        .listen(_updateControllersFromSnapshot);
  }

  /// Loads initial user data from Firestore.
  Future<void> _loadInitialUserData() async {
    try {
      final userDoc = await _firestoreService.firestore
          .collection('utilisateurs')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists && mounted) {
        _updateControllersFromSnapshot(userDoc);
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      _showError('Erreur lors du chargement des données initiales: ${e.toString()}');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Updates text controllers from Firestore snapshot.
  void _updateControllersFromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) return;

    final phone = data['numeroTelephone'] ?? '';
    final phoneParts = _splitPhoneNumber(phone);

    if (mounted) {
      setState(() {
        _emailController.text = _currentUser?.email ?? '';
        _nameController.text = data['nomPrenom'] ?? '';
        _selectedCountryCode = phoneParts['countryCode'] ?? '+237';
        _phoneController.text = phoneParts['number'] ?? '';
        _passwordController.text = '********';
      });
    }
  }

  /// Splits phone number into country code and number.
  Map<String, String> _splitPhoneNumber(String fullPhone) {
    if (fullPhone.isEmpty) return {'countryCode': '+237', 'number': ''};
    final spaceIndex = fullPhone.indexOf(' ');
    return spaceIndex == -1
        ? {'countryCode': '+237', 'number': fullPhone}
        : {
      'countryCode': fullPhone.substring(0, spaceIndex),
      'number': fullPhone.substring(spaceIndex + 1),
    };
  }

  /// Formats phone number with country code.
  String _formatPhoneNumber(String countryCode, String number) => '$countryCode $number';

  /// Shows an error notification.
  void _showError(String message) {
    _messagingService.sendLocalNotification('Erreur', message);
  }

  /// Shows a success notification.
  void _showSuccess(String message) {
    _messagingService.sendLocalNotification('Succès', message);
  }

  /// Updates the user's name in Firestore.
  Future<void> _updateName() async {
    if (_nameController.text.isEmpty) {
      _showError('Le nom ne peut pas être vide');
      return;
    }

    if (!mounted) return;
    setState(() => _isProcessing = true);
    try {
      await _firestoreService.updateUser(_currentUser!.uid, {
        'nomPrenom': _nameController.text,
      });
      if (!mounted) return;
      setState(() => _isEditingName = false);
      _showSuccess('Nom mis à jour avec succès');
    } catch (e) {
      _showError('Erreur lors de la mise à jour du nom: ${e.toString()}');
    } finally {
      if (!mounted) return;
      setState(() => _isProcessing = false);
    }
  }

  /// Updates the user's phone number in Firestore.
  Future<void> _updatePhone() async {
    final phoneNumber = _formatPhoneNumber(_selectedCountryCode, _phoneController.text.trim());

    if (phoneNumber.isEmpty) {
      _showError('Le numéro de téléphone ne peut pas être vide');
      return;
    }

    if (!RegExp(r'^\+[0-9]{1,3} [0-9]{8,15}$').hasMatch(phoneNumber)) {
      _showError('Format de numéro invalide');
      return;
    }

    if (!mounted) return;
    setState(() => _isProcessing = true);
    try {
      final isUnique = await _firestoreService.isPhoneNumberUniqueForAllUsers(
        phoneNumber,
        _currentUser!.uid,
      );

      if (!isUnique) {
        _showError('Ce numéro est déjà utilisé par un autre compte');
        return;
      }

      await _firestoreService.updateUser(_currentUser!.uid, {
        'numeroTelephone': phoneNumber,
      });
      if (!mounted) return;
      setState(() => _isEditingPhone = false);
      _showSuccess('Numéro de téléphone mis à jour avec succès');
      await _firestoreService.createOrUpdateCompteMobile(
        uid: _currentUser!.uid,
        numeroTelephone: phoneNumber,
      );
    } catch (e) {
      _showError('Erreur lors de la mise à jour du numéro: ${e.toString()}');
    } finally {
      if (!mounted) return;
      setState(() => _isProcessing = false);
    }
  }

  /// Updates the user's password.
  Future<void> _updatePassword() async {
    final isGoogleUser = _currentUser!.providerData.any((userInfo) => userInfo.providerId == 'google.com');
    if (isGoogleUser) {
      _showError('Les utilisateurs Google ne peuvent pas modifier leur mot de passe');
      return;
    }

    if (_passwordController.text.isEmpty || _passwordController.text == '********') {
      _showError('Veuillez entrer un nouveau mot de passe');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }

    final currentPassword = await _showPasswordDialog('Veuillez entrer votre mot de passe actuel');
    if (currentPassword == null || currentPassword.isEmpty) return;

    if (!mounted) return;
    setState(() => _isProcessing = true);
    try {
      final credential = EmailAuthProvider.credential(
        email: _currentUser!.email!,
        password: currentPassword,
      );

      await _currentUser!.reauthenticateWithCredential(credential);
      await _currentUser!.updatePassword(_passwordController.text);

      if (!mounted) return;
      setState(() {
        _isEditingPassword = false;
        _isObscuringPassword = true;
        _passwordController.text = '********';
      });
      _showSuccess('Mot de passe mis à jour avec succès');
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'requires-recent-login':
          errorMessage = 'Veuillez vous reconnecter pour modifier votre mot de passe';
          break;
        case 'weak-password':
          errorMessage = 'Le mot de passe est trop faible';
          break;
        case 'wrong-password':
          errorMessage = 'Mot de passe actuel incorrect';
          break;
        default:
          errorMessage = 'Erreur: ${e.message}';
      }
      _showError(errorMessage);
      _showError('Erreur inattendue: ${e.toString()}');
    } finally {
      if (!mounted) return;
      setState(() => _isProcessing = false);
    }
  }

  /// Shows a dialog to enter the current password.
  Future<String?> _showPasswordDialog(String message) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isEmpty) {
                _showError('Veuillez entrer votre mot de passe');
                return;
              }
              Navigator.pop(context, controller.text);
            },
            child: const Text('Confirmer'),
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
        title: 'Profil Administrateur',
        showBackArrow: false,
        showDarkModeButton: true,
      ),
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isAdmin
          ? Center(
        child: Text(
          'Accès réservé aux administrateurs',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
            fontSize: 16,
          ),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProfileAvatar(),
            const SizedBox(height: 16),
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildPersonalInfoCard(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () => confirmLogout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Déconnexion'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AdminBottomNavBar(
        currentIndex: 2,
        onTabSelected: (index) {
          if (index != 2) {
            final routes = ['/dashboardPage', '/addusersPage', '/adminProfilPage'];
            Navigator.pushReplacementNamed(context, routes[index]);
          }
        },
      ),
    );
  }

  /// Builds the profile avatar with a button to change the photo.
  Widget _buildProfileAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.transparent,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 58,
              backgroundColor: AppColors.primaryColor.withOpacity(0.1),
              backgroundImage: _currentUser?.photoURL != null
                  ? NetworkImage(_currentUser!.photoURL!)
                  : null,
              child: _currentUser?.photoURL == null
                  ? Icon(Icons.person, size: 60, color: AppColors.primaryColor)
                  : null,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => _showError('Fonctionnalité de changement de photo à venir'),
              icon: const Icon(Icons.camera_alt, color: Colors.blue),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the header with the user's name and email.
  Widget _buildProfileHeader() {
    return Column(
      children: [
        Text(
          _nameController.text.isNotEmpty ? _nameController.text : 'Non renseigné',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _currentUser?.email ?? '',
          style: TextStyle(
            color: AppColors.secondaryTextColor,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// Builds the card containing personal information.
  Widget _buildPersonalInfoCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations personnelles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const Divider(height: 20),
            _buildEditableField(
              label: 'Nom complet',
              controller: _nameController,
              isEditing: _isEditingName,
              onEdit: () => setState(() => _isEditingName = true),
              onSave: _updateName,
              onCancel: () => setState(() => _isEditingName = false),
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildPhoneField(),
            const SizedBox(height: 16),
            _buildPasswordField(),
          ],
        ),
      ),
    );
  }

  /// Builds the phone number field.
  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Numéro de téléphone',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey,
          ),
        ),
        const SizedBox(height: 5),
        _isEditingPhone ? _buildEditablePhoneField() : _buildNonEditablePhoneField(),
      ],
    );
  }

  /// Builds the non-editable phone field.
  Widget _buildNonEditablePhoneField() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : AppColors.borderColor,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.phone_outlined,
            color: isDarkMode ? Colors.grey.shade300 : AppColors.secondaryTextColor,
          ),
          const SizedBox(width: 10),
          Text(_selectedCountryCode),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              _phoneController.text.isEmpty ? 'Non défini' : _phoneController.text,
              style: TextStyle(
                color: isDarkMode ? Colors.white : AppColors.textColor,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () => setState(() => _isEditingPhone = true),
          ),
        ],
      ),
    );
  }

  /// Builds the editable phone field.
  Widget _buildEditablePhoneField() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.phone_outlined,
              color: isDarkMode ? Colors.grey.shade300 : AppColors.secondaryTextColor,
            ),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _selectedCountryCode,
              items: _countryCodes.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text('${entry.key} ${entry.value}'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedCountryCode = value!),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 34),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '6X XX XX XX',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _isEditingPhone = false),
              child: const Text('Annuler', style: TextStyle(color: Colors.red)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isProcessing ? null : _updatePhone,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
              child: _isProcessing
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text('Enregistrer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the password field.
  Widget _buildPasswordField() {
    final isGoogleUser = _currentUser?.providerData.any((userInfo) => userInfo.providerId == 'google.com') ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mot de passe',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey,
          ),
        ),
        const SizedBox(height: 5),
        _isEditingPassword ? _buildEditablePasswordField() : _buildNonEditablePasswordField(isGoogleUser),
      ],
    );
  }

  /// Builds the non-editable password field.
  Widget _buildNonEditablePasswordField(bool isGoogleUser) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : AppColors.borderColor,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            color: isDarkMode ? Colors.grey.shade300 : AppColors.secondaryTextColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _passwordController.text,
              style: TextStyle(
                color: _passwordController.text == '********' ? Colors.grey : (isDarkMode ? Colors.white : Colors.black),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () {
              if (isGoogleUser) {
                _showError('Les utilisateurs Google ne peuvent pas modifier leur mot de passe');
              } else {
                setState(() {
                  _isEditingPassword = true;
                  if (_passwordController.text == '********') {
                    _passwordController.clear();
                  }
                });
              }
            },
          ),
          IconButton(
            icon: Icon(
              _isObscuringPassword ? Icons.visibility : Icons.visibility_off,
              size: 20,
              color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
            ),
            onPressed: () {
              if (_passwordController.text != '********') {
                setState(() => _isObscuringPassword = !_isObscuringPassword);
              }
            },
          ),
        ],
      ),
    );
  }

  /// Builds the editable password field.
  Widget _buildEditablePasswordField() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.lock_outline,
              color: isDarkMode ? Colors.grey.shade300 : AppColors.secondaryTextColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _passwordController,
                obscureText: _isObscuringPassword,
                decoration: InputDecoration(
                  hintText: 'Nouveau mot de passe (min. 6 caractères)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscuringPassword ? Icons.visibility : Icons.visibility_off,
                      color: isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                    ),
                    onPressed: () => setState(() => _isObscuringPassword = !_isObscuringPassword),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditingPassword = false;
                  _isObscuringPassword = true;
                  _passwordController.text = '********';
                });
              },
              child: const Text('Annuler', style: TextStyle(color: Colors.red)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isProcessing ? null : _updatePassword,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
              child: _isProcessing
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text('Enregistrer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds a generic editable field.
  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required VoidCallback onCancel,
    TextInputType? keyboardType,
    required IconData icon,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
          ),
        ),
        const SizedBox(height: 5),
        if (!isEditing)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDarkMode ? Colors.grey.shade700 : AppColors.borderColor,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isDarkMode ? Colors.grey.shade300 : AppColors.secondaryTextColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? 'Non défini' : controller.text,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : AppColors.textColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: onEdit,
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: isDarkMode ? Colors.grey.shade300 : AppColors.secondaryTextColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Annuler', style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : onSave,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
                    child: _isProcessing
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text('Enregistrer', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}