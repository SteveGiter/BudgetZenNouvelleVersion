import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../colors/app_colors.dart';
import '../services/firebase/auth.dart';
import '../services/firebase/firestore.dart';
import '../widgets/custom_app_bar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Auth _authService = Auth();
  final FirestoreService _firestoreService = FirestoreService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isEditingPassword = false;
  bool _isObscuringPassword = true;
  bool _isEditingName = false;
  bool _isEditingPhone = false;
  bool _isProcessing = false;

  User? _currentUser;
  String _selectedCountryCode = '+237';
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;
  double _mobileBalance = 0.0;

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

  void _initializeUserData() {
    _currentUser = _authService.currentUser;
    if (_currentUser != null) {
      _setupUserStreams();
      _loadInitialUserData();
    }
  }

  void _setupUserStreams() {
    _userSubscription = _firestoreService.firestore
        .collection('comptesMobiles')
        .doc(_currentUser!.uid)
        .snapshots()
        .listen(_updateMobileBalanceFromSnapshot);

    _userDataSubscription = _firestoreService.firestore
        .collection('utilisateurs')
        .doc(_currentUser!.uid)
        .snapshots()
        .listen(_updateControllersFromSnapshot);
  }

  Future<void> _loadInitialUserData() async {
    try {
      final userDoc = await _firestoreService.firestore
          .collection('utilisateurs')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists && mounted) {
        _updateControllersFromSnapshot(userDoc);
      }

      final mobileAccountDoc = await _firestoreService.firestore
          .collection('comptesMobiles')
          .doc(_currentUser!.uid)
          .get();

      if (mobileAccountDoc.exists && mounted) {
        _updateMobileBalanceFromSnapshot(mobileAccountDoc);
      }
    } catch (e) {
      _showError('Erreur lors du chargement des données initiales: ${e.toString()}');
    }
  }

  void _updateMobileBalanceFromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?;
    if (mounted && data != null) {
      setState(() {
        _mobileBalance = (data['montantDisponible'] as num?)?.toDouble() ?? 0.0;
      });
    }
  }

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

  String _formatPhoneNumber(String countryCode, String number) => '$countryCode $number';

  Future<void> _updateName() async {
    if (_nameController.text.isEmpty) {
      _showError('Le nom ne peut pas être vide');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await _firestoreService.updateUser(_currentUser!.uid, {
        'nomPrenom': _nameController.text,
      });
      setState(() => _isEditingName = false);
      _showSuccess('Nom mis à jour avec succès');
    } catch (e) {
      _showError('Erreur lors de la mise à jour du nom: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

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
      setState(() => _isEditingPhone = false);
      _showSuccess('Numéro de téléphone mis à jour avec succès');
    } catch (e) {
      _showError('Erreur lors de la mise à jour du numéro: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

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

    setState(() => _isProcessing = true);
    try {
      final credential = EmailAuthProvider.credential(
        email: _currentUser!.email!,
        password: currentPassword,
      );

      await _currentUser!.reauthenticateWithCredential(credential);
      await _currentUser!.updatePassword(_passwordController.text);

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
    } catch (e) {
      _showError('Erreur inattendue: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<String?> _showPasswordDialog(String message) {
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
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccess(String message) {
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
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Profil',
        showBackArrow: true,
        showDarkModeButton: true,
      ),
      body: _currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileAvatar(),
            const SizedBox(height: 16),
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildPersonalInfoCard(),
          ],
        ),
      ),
    );
  }

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

  Widget _buildPersonalInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informations personnelles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            const SizedBox(height: 16),
            _buildMobileBalanceField(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Numéro de téléphone',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 5),
        if (!_isEditingPhone)
          _buildNonEditablePhoneField()
        else
          _buildEditablePhoneField(),
      ],
    );
  }

  Widget _buildNonEditablePhoneField() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_outlined, color: AppColors.secondaryTextColor),
          const SizedBox(width: 10),
          Text(_selectedCountryCode),
          const SizedBox(width: 5),
          Expanded(child: Text(_phoneController.text)),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () => setState(() => _isEditingPhone = true),
          ),
        ],
      ),
    );
  }

  Widget _buildEditablePhoneField() {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.phone_outlined, color: AppColors.secondaryTextColor),
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
                decoration: const InputDecoration(
                  hintText: '6X XX XX XX',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 15),
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

  Widget _buildPasswordField() {
    final isGoogleUser = _currentUser?.providerData.any((userInfo) => userInfo.providerId == 'google.com') ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mot de passe',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 5),
        if (!_isEditingPassword)
          _buildNonEditablePasswordField(isGoogleUser)
        else
          _buildEditablePasswordField(),
      ],
    );
  }

  Widget _buildNonEditablePasswordField(bool isGoogleUser) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: AppColors.secondaryTextColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _passwordController.text,
              style: TextStyle(
                color: _passwordController.text == '********' ? Colors.grey : Colors.black,
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

  Widget _buildEditablePasswordField() {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.secondaryTextColor),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _passwordController,
                obscureText: _isObscuringPassword,
                decoration: InputDecoration(
                  hintText: 'Nouveau mot de passe (min. 6 caractères)',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscuringPassword ? Icons.visibility : Icons.visibility_off,
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

  Widget _buildMobileBalanceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Solde disponible',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade700
                  : AppColors.borderColor,
            ),
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.white,
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade300
                    : AppColors.secondaryTextColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_mobileBalance.toStringAsFixed(2)} FCFA',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : AppColors.textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required VoidCallback onCancel,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 5),
        if (!isEditing)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.secondaryTextColor),
                const SizedBox(width: 10),
                Expanded(child: Text(controller.text)),
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
                  Icon(icon, color: AppColors.secondaryTextColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 15),
                        border: OutlineInputBorder(),
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
    _userSubscription?.cancel();
    _userDataSubscription?.cancel();
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}