import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../colors/app_colors.dart';
import '../../services/firebase/firestore.dart';
import '../../widgets/custom_app_bar.dart';

class RechargePage extends StatefulWidget {
  const RechargePage({super.key});

  @override
  State<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends State<RechargePage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  String _selectedCountryCode = '+237';
  String _selectedOperator = 'orange';
  int _currentStep = 1;
  final FirestoreService _firestoreService = FirestoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  final Map<String, String> _countryCodes = {
    '+237': '🇨🇲 Cameroun',
    '+242': '🇨🇬 Congo',
    '+241': '🇬🇦 Gabon',
    '+235': '🇹🇩 Tchad',
  };

  @override
  void initState() {
    super.initState();
    _loadUserPhoneNumber();
  }

  Future<void> _loadUserPhoneNumber() async {
    if (_currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(_currentUser!.uid)
          .get();
      final phone = userDoc.data()?['numeroTelephone'] as String? ?? '';
      if (phone.isNotEmpty) {
        final parts = phone.split(' ');
        setState(() {
          _selectedCountryCode = parts[0];
          _phoneController.text = parts.sublist(1).join(' ');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Recharger le compte',
        showBackArrow: true,
        showDarkModeButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildStepIndicator(isDarkMode),
            const SizedBox(height: 20),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(
                  color: isDarkMode ? AppColors.darkBorderColor : AppColors.borderColor,
                  width: 1,
                ),
              ),
              color: isDarkMode ? AppColors.darkCardColor : AppColors.cardColor,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildStepContent(isDarkMode),
                    const SizedBox(height: 30),
                    _buildNavigationButtons(isDarkMode),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStepCircle(1, 'Numéro', isDarkMode),
        _buildStepLine(isDarkMode),
        _buildStepCircle(2, 'Montant', isDarkMode),
        _buildStepLine(isDarkMode),
        _buildStepCircle(3, 'Code', isDarkMode),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label, bool isDarkMode) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: isActive
              ? (isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor)
              : (isDarkMode ? Colors.grey[700] : Colors.grey[300]),
          child: Text(
            '$step',
            style: TextStyle(
              color: isActive
                  ? AppColors.buttonTextColor
                  : (isDarkMode ? AppColors.darkSecondaryTextColor : Colors.grey[600]),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isDarkMode) {
    return Expanded(
      child: Container(
        height: 2,
        color: isDarkMode ? AppColors.darkBorderColor : Colors.grey[300],
      ),
    );
  }

  Widget _buildStepContent(bool isDarkMode) {
    switch (_currentStep) {
      case 1:
        return _buildPhoneStep(isDarkMode);
      case 2:
        return _buildAmountStep(isDarkMode);
      case 3:
        return _buildCodeStep(isDarkMode);
      default:
        return const SizedBox();
    }
  }

  Widget _buildPhoneStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOperatorSelector(isDarkMode),
        const SizedBox(height: 20),
        Text(
          'Numéro de téléphone',
          style: TextStyle(
            color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
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
                dropdownColor: isDarkMode ? Colors.grey[800] : AppColors.cardColor,
                style: TextStyle(
                  color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
                  fontSize: 14,
                ),
                underline: const SizedBox(),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
                ),
                items: _countryCodes.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedCountryCode = value!);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _phoneController,
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
                    color: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
                  ),
                ),
                style: TextStyle(
                  color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Montant à recharger (FCFA)',
          style: TextStyle(
            color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
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
              color: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
            ),
            suffixText: 'FCFA',
            suffixStyle: TextStyle(
              color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: TextStyle(
            color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCodeStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Code de confirmation',
          style: TextStyle(
            color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
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
              color: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
            ),
          ),
          style: TextStyle(
            color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
          ),
        ),
      ],
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
          ChoiceChip(
            label: const Text('Orange Money'),
            selected: _selectedOperator == 'orange',
            onSelected: (selected) => setState(() => _selectedOperator = 'orange'),
            selectedColor: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
            backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[200],
            labelStyle: TextStyle(
              color: _selectedOperator == 'orange'
                  ? AppColors.buttonTextColor
                  : (isDarkMode ? AppColors.darkTextColor : AppColors.textColor),
            ),
          ),
          Container(
            height: 30,
            width: 1,
            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          ChoiceChip(
            label: const Text('MTN Mobile'),
            selected: _selectedOperator == 'mtn',
            onSelected: (selected) => setState(() => _selectedOperator = 'mtn'),
            selectedColor: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
            backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[200],
            labelStyle: TextStyle(
              color: _selectedOperator == 'mtn'
                  ? AppColors.buttonTextColor
                  : (isDarkMode ? AppColors.darkTextColor : AppColors.textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 1)
          ElevatedButton(
            onPressed: () => setState(() => _currentStep--),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[400],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 3,
            ),
            child: Text(
              'Retour',
              style: TextStyle(
                color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else
          const SizedBox(width: 0),
        ElevatedButton(
          onPressed: _handleNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDarkMode ? AppColors.darkButtonColor : AppColors.buttonColor,
            foregroundColor: AppColors.buttonTextColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 3,
            minimumSize: const Size(120, 48),
          ),
          child: Text(
            _currentStep == 3 ? 'Confirmer' : 'Suivant',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleNext() async {
    if (_currentStep == 1) {
      if (_phoneController.text.isEmpty) {
        _showError('Veuillez entrer un numéro de téléphone.');
        return;
      }
      if (!RegExp(r'^[0-9]{8,15}$').hasMatch(_phoneController.text.trim())) {
        _showError('Format de numéro invalide (8-15 chiffres).');
        return;
      }
      final fullPhone = '$_selectedCountryCode ${_phoneController.text.trim()}';
      final userDoc = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(_currentUser!.uid)
          .get();
      if (userDoc.data()?['numeroTelephone'] != fullPhone) {
        _showError('Le numéro doit correspondre à celui de votre compte.');
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == 2) {
      final amount = double.tryParse(_amountController.text.trim());
      if (amount == null || amount <= 0) {
        _showError('Montant invalide (doit être > 0).');
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == 3) {
      final code = _codeController.text.trim();
      final amount = double.parse(_amountController.text.trim());
      if (code.isEmpty) {
        _showError('Veuillez entrer le code de confirmation.');
        return;
      }
      try {
        // Vérifier si le compte mobile existe
        final compteDoc = await FirebaseFirestore.instance
            .collection('comptesMobiles')
            .doc(_currentUser!.uid)
            .get();
        if (!compteDoc.exists) {
          _showError('Compte mobile non configuré.');
          return;
        }

        // Vérifier le code de sécurité
        final isCodeValid = await _firestoreService.verifyMobileCode(_currentUser!.uid, code);
        if (!isCodeValid) {
          _showError('Code de confirmation invalide.');
          return;
        }

        // Effectuer la recharge
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final compteRef = FirebaseFirestore.instance
              .collection('comptesMobiles')
              .doc(_currentUser!.uid);
          transaction.update(compteRef, {
            'montantDisponible': FieldValue.increment(amount),
            'derniereMiseAJour': FieldValue.serverTimestamp(),
          });
        });

        // Enregistrer le revenu
        await _firestoreService.addRevenu(
          userId: _currentUser!.uid,
          montant: amount,
          categorie: 'Recharge',
          description: 'Recharge via ${_selectedOperator == 'orange' ? 'Orange Money' : 'MTN Mobile Money'}',
        );

        _showSuccess('Recharge de ${amount.toStringAsFixed(2)} FCFA effectuée !');
        Navigator.pop(context);
      } catch (e) {
        _showError('Erreur lors de la recharge : $e');
        print('Erreur détaillée : $e');
      }
    }
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
              onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
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
    _phoneController.dispose();
    _amountController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}