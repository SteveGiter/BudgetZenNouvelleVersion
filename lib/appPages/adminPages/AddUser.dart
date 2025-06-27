import 'package:flutter/material.dart';
import 'package:budget_zen/services/firebase/messaging.dart';
import '../../colors/app_colors.dart';
import '../../widgets/ForAdmin/admin_bottom_nav_bar.dart';
import '../../widgets/custom_app_bar.dart';
import 'package:budget_zen/services/firebase/firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddUsersPage extends StatefulWidget {
  const AddUsersPage({super.key});

  @override
  State<AddUsersPage> createState() => _AddUsersPageState();
}   

class _AddUsersPageState extends State<AddUsersPage> {
  final FirestoreService _firestore = FirestoreService();
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final _nomPrenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _numeroTelephoneController = TextEditingController();
  String _role = 'utilisateur';
  String _provider = 'manual';
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedCountryCode = '+237'; // Code de pays par défaut
  String? _errorMessage;

  final List<String> _roleOptions = ['utilisateur', 'administrateur'];
  final List<String> _providerOptions = ['manual', 'google'];

  // Liste des codes de pays avec leurs drapeaux
  static const Map<String, String> _countryCodes = {
    '+237': '🇨🇲 Cameroun',
    '+243': '🇨🇩 Congo',
    '+241': '🇬🇦 Gabon',
    '+235': '🇹🇩 Tchad',
  };

  final emailRegex = RegExp(r"^[a-zA-Z0-9]+([._%+-][a-zA-Z0-9]+)*@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$");

  // Validateur pour le nom et prénom
  String? _nomPrenomValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez entrer un nom et prénom';
    }

    final trimmedValue = value.trim();

    if (trimmedValue.length < 2) {
      return 'Le nom doit contenir au moins 2 caractères';
    }

    if (trimmedValue.length > 50) {
      return 'Le nom ne peut excéder 50 caractères';
    }

    if (!RegExp(r'^[a-zA-ZÀ-ÿ\s\-]+$').hasMatch(trimmedValue)) {
      return 'Seuls les lettres, espaces et tirets sont autorisés';
    }

    if (RegExp(r'[\-\s]{2,}').hasMatch(trimmedValue)) {
      return 'Évitez plusieurs espaces ou tirets consécutifs';
    }

    return null;
  }

  // Validateur pour l'email
  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez entrer un email';
    }
    final trimmedValue = value.trim();
    if (!emailRegex.hasMatch(trimmedValue)) {
      return 'Format d\'email invalide';
    }
    return null;
  }

  // Validateur pour le mot de passe
  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer un mot de passe';
    }

    if (value.length < 8) {
      return 'Minimum 8 caractères';
    }

    if (value.length > 128) {
      return 'Maximum 128 caractères';
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return '1 majuscule minimum';
    }

    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return '1 minuscule minimum';
    }

    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return '1 chiffre minimum';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return '1 caractère spécial minimum';
    } 

    if (value.contains(' ')) {
      return 'Pas d\'espaces autorisés';
    }

    if (RegExp(r'(123|abc|password|azerty|qwerty)').hasMatch(value.toLowerCase())) {
      return 'Mot de passe trop simple';
    }

    if (RegExp(r'(.)\1{3,}').hasMatch(value)) {
      return 'Trop de répétitions';
    }

    return null;
  }

  // Validateur pour le téléphone
  String? _phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Champ optionnel
    }

    final phone = value.trim();

    if (!RegExp(r'^[0-9\s\-]{8,15}$').hasMatch(phone)) {
      return 'Format invalide (ex: 6XX XXX XXX)';
    }

    final digits = phone.replaceAll(RegExp(r'[\s\-]'), '');
    if (digits.length < 8 || digits.length > 15) {
      return 'Doit contenir 8 à 15 chiffres';
    }

    return null;
  }

  // Formater le numéro de téléphone avec le code de pays
  String _formatPhoneNumber(String countryCode, String number) {
    if (number.isEmpty) return '';
    return '$countryCode $number';
  }

  @override
  void dispose() {
    _nomPrenomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _numeroTelephoneController.dispose();
    super.dispose();
  }

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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: Text('Veuillez entrer votre mot de passe.')),
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
              Navigator.pop(context, controller.text);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Vérifier si l'utilisateur connecté est un administrateur
        final adminUser = _auth.currentUser;
        if (adminUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(child: Text('Aucun administrateur connecté.')),
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
          setState(() {
            _isLoading = false;
          });
          return;
        }

        final userDoc = await _firestore.firestore
            .collection('utilisateurs')
            .doc(adminUser.uid)
            .get();
        if (!userDoc.exists || userDoc.data()?['role'] != 'administrateur') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(child: Text('Seuls les administrateurs peuvent ajouter des utilisateurs.')),
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
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Demander le mot de passe de l'administrateur
        final adminPassword = await _showPasswordDialog('Veuillez entrer votre mot de passe d\'administrateur.');
        if (adminPassword == null || adminPassword.isEmpty) {
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Vérifier si le numéro de téléphone est unique (si fourni)
        final phoneNumber = _numeroTelephoneController.text.trim();
        if (phoneNumber.isNotEmpty) {
          final fullPhoneNumber = _formatPhoneNumber(_selectedCountryCode, phoneNumber);
          final isUnique = await _firestore.isPhoneNumberUnique(fullPhoneNumber, _provider, '');
          if (!isUnique) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(child: Text('Ce numéro de téléphone est déjà utilisé.')),
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
            setState(() {
              _isLoading = false;
            });
            return;
          }
        }

        // Créer le nouvel utilisateur
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        final newUser = userCredential.user;

        if (newUser == null) {
          throw Exception('Échec de la création de l\'utilisateur dans l\'authentification');
        }

        // Créer ou mettre à jour le profil de l'utilisateur dans Firestore
        await _firestore.createOrUpdateUserProfile(
          uid: newUser.uid,
          nomPrenom: _nomPrenomController.text.trim(),
          email: _emailController.text.trim(),
          numeroTelephone: phoneNumber.isNotEmpty ? _formatPhoneNumber(_selectedCountryCode, phoneNumber) : null,
          role: _role,
          provider: _provider,
        );

        // Restaurer la session de l'administrateur
        await _auth.signInWithEmailAndPassword(
          email: adminUser.email!,
          password: adminPassword,
        );

        // Afficher une notification pour le succès
        await _messagingService.sendLocalNotification(
          'Utilisateur ajouté',
          'L\'utilisateur ${_nomPrenomController.text} a été ajouté avec succès.',
        );

        // Réinitialiser le formulaire
        _nomPrenomController.clear();
        _emailController.clear();
        _passwordController.clear();
        _numeroTelephoneController.clear();
        setState(() {
          _role = 'utilisateur';
          _provider = 'manual';
          _selectedCountryCode = '+237';
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('Erreur lors de l\'ajout de l\'utilisateur : $e')),
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
        _messagingService.sendLocalNotification('Erreur', 'Erreur lors de l\'ajout de l\'utilisateur : $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackgroundColor : AppColors.backgroundColor,
      appBar: CustomAppBar(
        title: 'Ajouter un utilisateur',
        showBackArrow: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 2,
              color: isDarkMode ? AppColors.darkCardColor : AppColors.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Créer un nouvel utilisateur',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nomPrenomController,
                        decoration: InputDecoration(
                          labelText: 'Nom & Prénom',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: isDarkMode ? AppColors.darkBackgroundColor : AppColors.backgroundColor,
                          labelStyle: TextStyle(color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor),
                        ),
                        style: TextStyle(color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor, fontSize: isSmallScreen ? 14 : 16),
                        validator: _nomPrenomValidator,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: isDarkMode ? AppColors.darkBackgroundColor : AppColors.backgroundColor,
                          labelStyle: TextStyle(color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor),
                        ),
                        style: TextStyle(color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor, fontSize: isSmallScreen ? 14 : 16),
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: isDarkMode ? AppColors.darkBackgroundColor : AppColors.backgroundColor,
                          labelStyle: TextStyle(color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor),
                        ),
                        style: TextStyle(color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor, fontSize: isSmallScreen ? 14 : 16),
                        validator: _passwordValidator,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 130,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCountryCode,
                              decoration: InputDecoration(
                                labelText: 'Code pays',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: isDarkMode ? AppColors.darkBackgroundColor : AppColors.backgroundColor,
                                labelStyle: TextStyle(color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor),
                              ),
                              items: _countryCodes.entries
                                  .map((entry) => DropdownMenuItem(
                                        value: entry.key,
                                        child: Text(entry.value, overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (value) => setState(() => _selectedCountryCode = value ?? '+237'),
                              style: TextStyle(color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor, fontSize: isSmallScreen ? 14 : 16),
                              isExpanded: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _numeroTelephoneController,
                              decoration: InputDecoration(
                                labelText: 'Numéro de téléphone',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: isDarkMode ? AppColors.darkBackgroundColor : AppColors.backgroundColor,
                                labelStyle: TextStyle(color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor),
                              ),
                              style: TextStyle(color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor, fontSize: isSmallScreen ? 14 : 16),
                              validator: _phoneValidator,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _role,
                        items: _roleOptions
                            .map((role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(role[0].toUpperCase() + role.substring(1)),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() => _role = value ?? 'utilisateur');
                        },
                        decoration: InputDecoration(
                          labelText: 'Rôle',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: isDarkMode ? AppColors.darkBackgroundColor : AppColors.backgroundColor,
                          labelStyle: TextStyle(color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor),
                        ),
                        style: TextStyle(color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor, fontSize: isSmallScreen ? 14 : 16),
                        isExpanded: true,
                      ),
                      const SizedBox(height: 20),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_errorMessage!, style: TextStyle(color: Colors.red, fontSize: isSmallScreen ? 12 : 14), textAlign: TextAlign.center),
                        ),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? AppColors.darkButtonColor : AppColors.buttonColor,
                          foregroundColor: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Ajouter', style: TextStyle(fontSize: isSmallScreen ? 14 : 16, color: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AdminBottomNavBar(
        currentIndex: 1,
        onTabSelected: (index) {
          if (index != 1) {
            final routes = ['/dashboardPage', '/addusersPage', '/adminProfilPage'];
            Navigator.pushReplacementNamed(context, routes[index]);
          }
        },
      ),
    );
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}