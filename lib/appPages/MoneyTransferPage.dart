import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../colors/app_colors.dart';
import '../services/firebase/firestore.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_bottom_nav_bar.dart';

class MoneyTransferPage extends StatefulWidget {
  const MoneyTransferPage({super.key});

  @override
  State<MoneyTransferPage> createState() => _MoneyTransferPageState();
}

class _MoneyTransferPageState extends State<MoneyTransferPage> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  String _selectedCountryCode = '+237';
  String? _selectedCategory;
  String _selectedOperator = 'orange';
  bool _showCodeField = false;

  static const Color _orangePrimary = Color(0xFFFF7900);
  static const Color _orangeLight = Color(0xFFFF9E40);
  static const Color _mtnPrimary = Color(0xFFFFCC00);
  static const Color _mtnDark = Color(0xFFF5B800);
  static const Color _mtnLight = Color(0xFFFFE040);

  final Map<String, String> _countryCodes = {
    '+237': '🇨🇲 Cameroun',
    '+242': '🇨🇬 Congo',
    '+241': '🇬🇦 Gabon',
    '+235': '🇹🇩 Tchad',
    '+33': '🇫🇷 France',
    '+1': '🇺🇸 USA',
    '+44': '🇬🇧 UK',
    '+49': '🇩🇪 Allemagne',
  };

  final List<Map<String, String>> _transactionCategories = [
    {'value': 'Personnel', 'label': '💼 Personnel'},
    {'value': 'Affaires', 'label': '🏢 Affaires'},
    {'value': 'Cadeau', 'label': '🎁 Cadeau'},
    {'value': 'Éducation', 'label': '📚 Éducation'},
    {'value': 'Santé', 'label': '🏥 Santé'},
    {'value': 'Famille', 'label': '👨‍👩‍👧‍👦 Famille'},
    {'value': 'Nourriture', 'label': '🍔 Nourriture'},
    {'value': 'Transport', 'label': '🚗 Transport'},
    {'value': 'Loisirs', 'label': '🎭 Loisirs'},
    {'value': 'Factures', 'label': '💡 Factures'},
    {'value': 'Autre', 'label': '❓ Autre'},
  ];

  Color get _primaryColor => _selectedOperator == 'orange' ? _orangePrimary : _mtnPrimary;
  Color get _primaryLight => _selectedOperator == 'orange' ? _orangeLight : _mtnLight;
  Color get _primaryDark => _selectedOperator == 'orange' ? _orangePrimary : _mtnDark;
  Color get _textColor => _selectedOperator == 'orange' ? Colors.white : Colors.black;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Transfert d\'argent',
        showBackArrow: true,
        showDarkModeButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildOperatorSelector(isDarkMode),
            const SizedBox(height: 20),
            _buildHeaderSection(isDarkMode, screenWidth),
            const SizedBox(height: 20),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              color: isDarkMode ? AppColors.darkCardColor : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildPhoneField(isDarkMode),
                    const SizedBox(height: 20),
                    _buildAmountField(isDarkMode),
                    const SizedBox(height: 20),
                    _buildCategoryDropdown(isDarkMode),
                    if (_showCodeField) ...[
                      const SizedBox(height: 20),
                      _buildCodeField(isDarkMode),
                    ],
                    const SizedBox(height: 30),
                    _buildTransferButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorSelector(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildOperatorButton(
            label: 'Orange Money',
            imagePath: 'assets/orange_money_logo.png',
            isSelected: _selectedOperator == 'orange',
            onTap: () => setState(() => _selectedOperator = 'orange'),
          ),
          Container(
            height: 30,
            width: 1,
            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          _buildOperatorButton(
            label: 'MTN Mobile',
            imagePath: 'assets/mtn_momo_logo.png',
            isSelected: _selectedOperator == 'mtn',
            onTap: () => setState(() => _selectedOperator = 'mtn'),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorButton({
    required String label,
    required String imagePath,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              imagePath,
              height: 30,
              width: 30,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.money,
                  size: 30,
                  color: isSelected ? _primaryColor : Colors.grey,
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _primaryColor : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(bool isDarkMode, double screenWidth) {
    return Column(
      children: [
        Text(
          _selectedOperator == 'orange' ? 'Orange Money' : 'MTN Mobile Money',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Envoyez de l\'argent en toute sécurité',
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Numéro du destinataire',
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<String>(
                value: _selectedCountryCode,
                dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
                underline: const SizedBox(),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
                items: _countryCodes.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCountryCode = value!;
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _recipientController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '6X XX XX XX',
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                  prefixIcon: Icon(
                    Icons.phone_android,
                    color: _primaryLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountField(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Montant à envoyer (FCFA)',
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '0',
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
            prefixIcon: Icon(
              Icons.money,
              color: _primaryLight,
            ),
            suffixText: 'FCFA',
            suffixStyle: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catégorie de transaction',
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: InputDecoration(
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          ),
          dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 14,
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: isDarkMode ? Colors.white70 : Colors.grey[600],
          ),
          hint: Text(
            'Sélectionnez une catégorie',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey[600],
            ),
          ),
          items: _transactionCategories.map((category) {
            return DropdownMenuItem<String>(
              value: category['value'],
              child: Text(category['label']!),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategory = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCodeField(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Code de confirmation',
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Entrez le code',
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
            prefixIcon: Icon(
              Icons.lock,
              color: _primaryLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleTransfer,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: _textColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 3,
        ),
        child: Text(
          _showCodeField ? 'CONFIRMER' : 'SUIVANT',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  void _handleTransfer() async {
    if (!_showCodeField) {
      _validateAndShowCodeField();
      return;
    }

    final phoneNumber = '$_selectedCountryCode ${_recipientController.text.trim()}';
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText.replaceAll(RegExp(r'[^0-9.]'), ''));
    final category = _selectedCategory;
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      _showError('Veuillez entrer le code de confirmation');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showError('Session expirée, veuillez vous reconnecter');
      return;
    }

    try {
      // Vérifier le code (simulé ici, à remplacer par une API opérateur réelle)
      final isCodeValid = await _simulateCodeVerification(code);
      if (!isCodeValid) {
        _showError('Code de confirmation invalide');
        return;
      }

      // Vérifier si le numéro du destinataire existe
      final recipientQuery = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .where('numeroTelephone', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (recipientQuery.size == 0) {
        _showError('Aucun compte associé à $phoneNumber');
        return;
      }

      final recipientUid = recipientQuery.docs.first.id;
      final senderPhone = (await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(currentUser.uid)
          .get())
          .data()?['numeroTelephone'] as String?;

      if (senderPhone == phoneNumber) {
        _showError('Vous ne pouvez pas vous transférer de l\'argent à vous-même');
        return;
      }

      // Effectuer la transaction
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final senderRef = FirebaseFirestore.instance.collection('comptesMobiles').doc(currentUser.uid);
        final recipientRef = FirebaseFirestore.instance.collection('comptesMobiles').doc(recipientUid);
        final depenseRef = FirebaseFirestore.instance.collection('depenses').doc();
        final revenuRef = FirebaseFirestore.instance.collection('revenus').doc();
        final transactionRef = FirebaseFirestore.instance.collection('transactions').doc();

        // Récupérer les comptes
        final senderCompte = await transaction.get(senderRef);
        final recipientCompte = await transaction.get(recipientRef);

        // Vérifications
        if (!senderCompte.exists) {
          throw Exception('Votre compte mobile n\'est pas configuré');
        }
        if (!recipientCompte.exists) {
          throw Exception('Le compte mobile du destinataire n\'est pas configuré');
        }

        final senderMontant = (senderCompte.data()!['montantDisponible'] as num?)?.toDouble() ?? 0.0;
        if (senderMontant < amount!) {
          throw Exception('Solde insuffisant pour effectuer le transfert');
        }

        // Débiter le compte de l'expéditeur
        transaction.update(senderRef, {
          'montantDisponible': FieldValue.increment(-amount),
          'derniereMiseAJour': FieldValue.serverTimestamp(),
        });

        // Créditer le compte du destinataire
        transaction.update(recipientRef, {
          'montantDisponible': FieldValue.increment(amount),
          'derniereMiseAJour': FieldValue.serverTimestamp(),
        });

        // Enregistrer la dépense pour l'expéditeur
        transaction.set(depenseRef, {
          'userId': currentUser.uid,
          'montant': amount,
          'categorie': category!,
          'description': 'Transfert envoyé via ${_selectedOperator == 'orange' ? 'Orange Money' : 'MTN Mobile Money'} à $phoneNumber',
          'dateCreation': FieldValue.serverTimestamp(),
        });

        // Enregistrer le revenu pour le destinataire
        transaction.set(revenuRef, {
          'userId': recipientUid,
          'montant': amount,
          'categorie': category,
          'description': 'Transfert reçu via ${_selectedOperator == 'orange' ? 'Orange Money' : 'MTN Mobile Money'} de $senderPhone',
          'dateCreation': FieldValue.serverTimestamp(),
        });

        // Enregistrer la transaction
        transaction.set(transactionRef, {
          'expediteurId': currentUser.uid,
          'destinataireId': recipientUid,
          'users': [currentUser.uid, recipientUid],
          'montant': amount,
          'typeTransaction': 'transfert',
          'categorie': category,
          'description': 'Transfert via ${_selectedOperator == 'orange' ? 'Orange Money' : 'MTN Mobile Money'} de $senderPhone à $phoneNumber',
          'dateHeure': FieldValue.serverTimestamp(),
          'expediteurDeleted': null,
          'destinataireDeleted': null,
        });
      });

      _resetForm();
      _showSuccess('Transfert de ${amount?.toStringAsFixed(2)} FCFA effectué avec succès !');
    } catch (e) {
      _showError('Erreur lors du transfert : $e');
      print('Erreur détaillée : $e');
    }
  }

  void _validateAndShowCodeField() {
    final phoneNumber = '$_selectedCountryCode ${_recipientController.text.trim()}';
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText.replaceAll(RegExp(r'[^0-9.]'), ''));
    final category = _selectedCategory;

    if (_recipientController.text.isEmpty) {
      _showError('Veuillez entrer un numéro de téléphone');
      return;
    }

    if (!RegExp(r'^[0-9]{8,15}$').hasMatch(_recipientController.text.trim())) {
      _showError('Format de numéro invalide (8-15 chiffres)');
      return;
    }

    if (amount == null || amount <= 0) {
      _showError('Montant invalide (doit être > 0)');
      return;
    }

    if (category == null) {
      _showError('Veuillez sélectionner une catégorie');
      return;
    }

    setState(() {
      _showCodeField = true;
    });
  }

  Future<bool> _simulateCodeVerification(String code) async {
    // À remplacer par une API réelle pour vérifier le code auprès de l'opérateur
    // Pour cette simulation, on accepte tout code de 6 chiffres
    return RegExp(r'^\d{6}$').hasMatch(code);
  }

  void _resetForm() {
    _recipientController.clear();
    _amountController.clear();
    _codeController.clear();
    setState(() {
      _selectedCategory = null;
      _showCodeField = false;
    });
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
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ],
        ),
        backgroundColor: AppColors.errorColor,
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
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ],
        ),
        backgroundColor: AppColors.successColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}