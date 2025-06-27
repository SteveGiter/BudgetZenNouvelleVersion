import 'package:flutter/material.dart';
import '../../colors/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditUserPage extends StatefulWidget {
  final String uid;

  const EditUserPage({super.key, required this.uid});

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _role = 'utilisateur';
  bool _isLoading = false;
  String? _errorMessage;

  final emailRegex = RegExp(r"^[a-zA-Z0-9]+([._%+-][a-zA-Z0-9]+)*@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$");

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    final doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(widget.uid).get();
    final data = doc.data();
    if (data != null) {
      _nameController.text = data['nomPrenom'] ?? '';
      _emailController.text = data['email'] ?? '';
      _phoneController.text = data['numeroTelephone'] ?? '';
      _role = data['role'] ?? 'utilisateur';
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackgroundColor : AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Modifier un utilisateur'),
        backgroundColor: isDarkMode ? AppColors.darkCardColor : AppColors.cardColor,
        foregroundColor: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
        elevation: 0,
        iconTheme: IconThemeData(color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 24),
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
                      'Modifier les informations',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nom & Prénom',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: isDarkMode ? AppColors.darkBackgroundColor : AppColors.backgroundColor,
                        labelStyle: TextStyle(color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor),
                      ),
                      style: TextStyle(color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor, fontSize: isSmallScreen ? 14 : 16),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Nom requis' : null,
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
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Email requis';
                        if (!emailRegex.hasMatch(value.trim())) return 'Format d\'email invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Numéro de téléphone',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: isDarkMode ? AppColors.darkBackgroundColor : AppColors.backgroundColor,
                        labelStyle: TextStyle(color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor),
                      ),
                      style: TextStyle(color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor, fontSize: isSmallScreen ? 14 : 16),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _role,
                      items: [
                        DropdownMenuItem(value: 'utilisateur', child: Text('Utilisateur')),
                        DropdownMenuItem(value: 'administrateur', child: Text('Administrateur')),
                      ],
                      onChanged: (value) => setState(() => _role = value ?? 'utilisateur'),
                      decoration: InputDecoration(
                        labelText: 'Rôle',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: isDarkMode ? AppColors.darkBackgroundColor : AppColors.backgroundColor,
                        labelStyle: TextStyle(color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor),
                      ),
                      style: TextStyle(color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor, fontSize: isSmallScreen ? 14 : 16),
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_errorMessage!, style: TextStyle(color: Colors.red, fontSize: isSmallScreen ? 12 : 14), textAlign: TextAlign.center),
                      ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? AppColors.darkButtonColor : AppColors.buttonColor,
                        foregroundColor: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 14),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Enregistrer', style: TextStyle(fontSize: isSmallScreen ? 14 : 16, color: isDarkMode ? AppColors.darkButtonTextColor : AppColors.buttonTextColor)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await FirebaseFirestore.instance.collection('utilisateurs').doc(widget.uid).update({
        'nomPrenom': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'numeroTelephone': _phoneController.text.isNotEmpty ? _phoneController.text : null,
        'role': _role,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _errorMessage = 'Erreur : $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

// Extension pour capitaliser les chaînes
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}