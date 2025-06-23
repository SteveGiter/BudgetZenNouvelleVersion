import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../colors/app_colors.dart';
import '../../services/firebase/firestore.dart';
import '../../services/firebase/messaging.dart';
import '../../widgets/custom_app_bar.dart';

class RechargePage extends StatefulWidget {
  final double montantDisponible;

  const RechargePage({super.key, required this.montantDisponible});

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
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  final Map<String, String> _countryCodes = {
    '+237': '🇨🇲 Cameroun',
    '+242': '🇨🇬 Congo',
    '+241': '🇬🇦 Gabon',
    '+235': '🇹🇩 Tchad',
  };

  static const double _minAmount = 100.0;
  static const double _maxAmount = 1000000.0;
  static const int _maxRechargeAttemptsPerHour = 5;

  @override
  void initState() {
    super.initState();
    _loadUserPhoneNumber();
  }

  Future<void> _loadUserPhoneNumber() async {
    if (_currentUser == null) {
      _showError('Utilisateur non authentifié. Veuillez vous reconnecter.');
      Navigator.pop(context);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(_currentUser!.uid)
          .get();
      if (!userDoc.exists) {
        _showError('Profil utilisateur introuvable. Veuillez compléter votre profil.');
        return;
      }

      final phone = userDoc.data()?['numeroTelephone'] as String? ?? '';
      if (phone.isEmpty) {
        _showError('Aucun numéro de téléphone associé. Veuillez en ajouter un dans votre profil.');
        return;
      }

      final parts = phone.split(' ');
      setState(() {
        _selectedCountryCode = parts[0];
        _phoneController.text = parts.sublist(1).join(' ');
      });
    } on FirebaseException catch (e) {
      _showError('Erreur de chargement du numéro : ${e.message}');
    } catch (e) {
      _showError('Erreur inattendue : $e');
      print('Erreur détaillée : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Recharger le compte',
        showBackArrow: true,
        showDarkModeButton: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.05),
        child: Column(
          children: [
            _buildStepIndicator(isDarkMode, screenWidth),
            SizedBox(height: screenWidth * 0.05),
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
                padding: EdgeInsets.all(screenWidth * 0.05),
                child: Column(
                  children: [
                    _buildStepContent(isDarkMode, screenWidth),
                    SizedBox(height: screenWidth * 0.075),
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

  Widget _buildStepIndicator(bool isDarkMode, double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: _buildStepCircle(1, 'Numéro', isDarkMode, screenWidth)),
        _buildStepLine(isDarkMode, screenWidth * 0.15),
        Flexible(child: _buildStepCircle(2, 'Montant', isDarkMode, screenWidth)),
        _buildStepLine(isDarkMode, screenWidth * 0.15),
        Flexible(child: _buildStepCircle(3, 'Code', isDarkMode, screenWidth)),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label, bool isDarkMode, double screenWidth) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        CircleAvatar(
          radius: screenWidth * 0.05,
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
              fontSize: screenWidth * 0.04,
            ),
          ),
        ),
        SizedBox(height: screenWidth * 0.02),
        Text(
          label,
          style: TextStyle(
            fontSize: screenWidth * 0.03,
            color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isDarkMode, double width) {
    return Container(
      width: width,
      height: 2,
      color: isDarkMode ? AppColors.darkBorderColor : Colors.grey[300],
    );
  }

  Widget _buildStepContent(bool isDarkMode, double screenWidth) {
    switch (_currentStep) {
      case 1:
        return _buildPhoneStep(isDarkMode, screenWidth);
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAmountField(isDarkMode, screenWidth),
            SizedBox(height: screenWidth * 0.05),
            _buildCurrentBalance(isDarkMode),
          ],
        );
      case 3:
        return _buildCodeStep(isDarkMode, screenWidth);
      default:
        return const SizedBox();
    }
  }

  Widget _buildPhoneStep(bool isDarkMode, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOperatorSelector(isDarkMode, screenWidth),
        SizedBox(height: screenWidth * 0.05),
        Text(
          'Numéro de téléphone',
          style: TextStyle(
            color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
            fontSize: screenWidth * 0.035,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: screenWidth * 0.02),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 1,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: DropdownButton<String>(
                    value: _selectedCountryCode,
                    dropdownColor: isDarkMode ? Colors.grey[800] : AppColors.cardColor,
                    style: TextStyle(
                      color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
                      fontSize: screenWidth * 0.035,
                    ),
                    underline: const SizedBox(),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
                      size: screenWidth * 0.04,
                    ),
                    items: _countryCodes.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCountryCode = value!);
                    },
                  ),
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.025),
            Expanded(
              flex: 2,
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
                  contentPadding: EdgeInsets.symmetric(
                    vertical: screenWidth * 0.0375,
                    horizontal: screenWidth * 0.0375,
                  ),
                  prefixIcon: Icon(
                    Icons.phone_android,
                    color: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
                    size: screenWidth * 0.05,
                  ),
                ),
                style: TextStyle(
                  color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
                  fontSize: screenWidth * 0.035,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountField(bool isDarkMode, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Montant à recharger (FCFA)',
          style: TextStyle(
            color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
            fontSize: screenWidth * 0.035,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: screenWidth * 0.02),
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
            contentPadding: EdgeInsets.symmetric(
              vertical: screenWidth * 0.0375,
              horizontal: screenWidth * 0.0375,
            ),
            prefixIcon: Icon(
              Icons.money,
              color: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
              size: screenWidth * 0.05,
            ),
            suffixText: 'FCFA',
            suffixStyle: TextStyle(
              color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
              fontWeight: FontWeight.bold,
              fontSize: screenWidth * 0.035,
            ),
          ),
          style: TextStyle(
            color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
            fontSize: screenWidth * 0.035,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentBalance(bool isDarkMode) {
    return StreamBuilder<double>(
      stream: _firestoreService.streamMontantDisponible(_currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Erreur de chargement du solde',
            style: TextStyle(
              color: isDarkMode ? AppColors.darkErrorColor : AppColors.errorColor,
              fontSize: MediaQuery.of(context).size.width * 0.03,
            ),
          );
        }
        final balance = snapshot.data ?? 0.0;
        return Text(
          'Solde disponible : ${balance.toStringAsFixed(2)} FCFA',
          style: TextStyle(
            color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
            fontSize: MediaQuery.of(context).size.width * 0.03,
          ),
        );
      },
    );
  }

  Widget _buildCodeStep(bool isDarkMode, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Code de confirmation',
          style: TextStyle(
            color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
            fontSize: screenWidth * 0.035,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: screenWidth * 0.02),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Entrez le code (6 chiffres)',
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              vertical: screenWidth * 0.0375,
              horizontal: screenWidth * 0.0375,
            ),
            prefixIcon: Icon(
              Icons.lock,
              color: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
              size: screenWidth * 0.05,
            ),
          ),
          style: TextStyle(
            color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
            fontSize: screenWidth * 0.035,
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorSelector(bool isDarkMode, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: screenWidth * 0.025,
        horizontal: screenWidth * 0.05,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: ChoiceChip(
              label: Text(
                'Orange Money',
                style: TextStyle(
                  color: _selectedOperator == 'orange'
                      ? AppColors.buttonTextColor
                      : (isDarkMode ? AppColors.darkTextColor : AppColors.textColor),
                  fontSize: screenWidth * 0.035,
                ),
                textAlign: TextAlign.center,
              ),
              selected: _selectedOperator == 'orange',
              onSelected: (selected) => setState(() => _selectedOperator = 'orange'),
              selectedColor: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
              backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[200],
            ),
          ),
          SizedBox(width: screenWidth * 0.025),
          Container(
            height: screenWidth * 0.075,
            width: 1,
            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          ),
          SizedBox(width: screenWidth * 0.025),
          Expanded(
            child: ChoiceChip(
              label: Text(
                'MTN Mobile',
                style: TextStyle(
                  color: _selectedOperator == 'mtn'
                      ? AppColors.buttonTextColor
                      : (isDarkMode ? AppColors.darkTextColor : AppColors.textColor),
                  fontSize: screenWidth * 0.035,
                ),
                textAlign: TextAlign.center,
              ),
              selected: _selectedOperator == 'mtn',
              onSelected: (selected) => setState(() => _selectedOperator = 'mtn'),
              selectedColor: isDarkMode ? AppColors.darkPrimaryColor : AppColors.primaryColor,
              backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[200],
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
          Expanded(
            child: ElevatedButton(
              onPressed: () => setState(() => _currentStep--),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05,
                  vertical: MediaQuery.of(context).size.width * 0.03,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 3,
              ),
              child: Text(
                'Retour',
                style: TextStyle(
                  color: isDarkMode ? AppColors.darkTextColor : AppColors.textColor,
                  fontSize: MediaQuery.of(context).size.width * 0.04,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        else
          const SizedBox.shrink(),
        if (_currentStep > 1) SizedBox(width: MediaQuery.of(context).size.width * 0.025),
        Expanded(
          child: ElevatedButton(
            onPressed: _handleNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? AppColors.darkButtonColor : AppColors.buttonColor,
              foregroundColor: AppColors.buttonTextColor,
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
                vertical: MediaQuery.of(context).size.width * 0.03,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 3,
              minimumSize: Size(120, MediaQuery.of(context).size.width * 0.12),
            ),
            child: Text(
              _currentStep == 3 ? 'Confirmer' : 'Suivant',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.04,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleNext() async {
    if (_currentUser == null) {
      _showError('Utilisateur non authentifié. Veuillez vous reconnecter.');
      Navigator.pop(context);
      return;
    }

    try {
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
        if (!userDoc.exists) {
          _showError('Profil utilisateur introuvable. Veuillez compléter votre profil.');
          return;
        }
        if (userDoc.data()?['numeroTelephone'] != fullPhone) {
          _showError('Le numéro doit correspondre à celui de votre compte.');
          return;
        }

        final isUnique = await _firestoreService.isPhoneNumberUnique(
          fullPhone,
          userDoc.data()?['provider'] ?? 'unknown',
          _currentUser!.uid,
        );
        if (!isUnique) {
          _showError('Ce numéro est déjà utilisé par un autre compte.');
          return;
        }

        setState(() => _currentStep++);
      } else if (_currentStep == 2) {
        final amount = double.tryParse(_amountController.text.trim());
        if (amount == null) {
          _showError('Montant invalide. Entrez un nombre valide.');
          return;
        }
        if (amount < _minAmount) {
          _showError('Montant minimum : $_minAmount FCFA.');
          return;
        }
        if (amount > _maxAmount) {
          _showError('Montant maximum : $_maxAmount FCFA.');
          return;
        }

        if (await _exceededRechargeAttempts()) {
          _showError('Trop de tentatives de recharge. Réessayez dans une heure.');
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
        if (!RegExp(r'^\d{6}$').hasMatch(code)) {
          _showError('Le code doit être composé de 6 chiffres.');
          return;
        }

        final compteDoc = await FirebaseFirestore.instance
            .collection('comptesMobiles')
            .doc(_currentUser!.uid)
            .get();
        if (!compteDoc.exists) {
          _showError('Compte mobile non configuré. Contactez le support.');
          return;
        }

        final codeExpiration = compteDoc.data()?['codeExpiration'] as Timestamp?;
        if (codeExpiration != null && codeExpiration.toDate().isBefore(DateTime.now())) {
          _showError('Code de confirmation expiré. Demandez un nouveau code.');
          return;
        }

        final isCodeValid = await _firestoreService.verifyMobileCode(_currentUser!.uid, code);
        if (!isCodeValid) {
          _showError('Code de confirmation invalide.');
          return;
        }

        double newBalance = 0.0;
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final compteRef = FirebaseFirestore.instance
              .collection('comptesMobiles')
              .doc(_currentUser!.uid);
          final rechargeAttemptRef = FirebaseFirestore.instance
              .collection('recharge_attempts')
              .doc('${_currentUser!.uid}_${DateTime.now().hour}');

          final compteSnapshot = await transaction.get(compteRef);
          newBalance = (compteSnapshot.data()?['montantDisponible'] ?? 0.0) + amount;

          transaction.update(compteRef, {
            'montantDisponible': FieldValue.increment(amount),
            'derniereMiseAJour': FieldValue.serverTimestamp(),
            'codeExpiration': null,
          });

          transaction.set(rechargeAttemptRef, {
            'userId': _currentUser!.uid,
            'timestamp': FieldValue.serverTimestamp(),
            'amount': amount,
            'operator': _selectedOperator,
          });
        });

        await _firestoreService.addRevenu(
          userId: _currentUser!.uid,
          montant: amount,
          categorie: 'Recharge',
          description: 'Recharge via ${_selectedOperator == 'orange' ? 'Orange Money' : 'MTN Mobile Money'}',
        );

        // Envoyer une notification locale
        final fullPhone = '$_selectedCountryCode ${_phoneController.text.trim()}';
        final operatorName = _selectedOperator == 'orange' ? 'Orange Money' : 'MTN Mobile Money';
        final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
        await _messagingService.sendLocalNotification(
          'Recharge réussie',
          'Montant: ${amount.toStringAsFixed(2)} FCFA\nOpérateur: $operatorName\nNuméro: $fullPhone\nDate: $formattedDate\nNouveau solde: ${newBalance.toStringAsFixed(2)} FCFA',
        );

        _showSuccess('Recharge de ${amount.toStringAsFixed(2)} FCFA effectuée !');
        Navigator.pop(context, true);

        await showDialog(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Plan de gestion de votre revenu'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nous vous proposons d\'allouer votre revenu selon la règle 50/30/20 :',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text('• 50% pour les besoins : ${(amount * 0.50).toStringAsFixed(2)} FCFA'),
                Text('• 30% pour les désirs : ${(amount * 0.30).toStringAsFixed(2)} FCFA'),
                Text('• 20% pour l\'épargne : ${(amount * 0.20).toStringAsFixed(2)} FCFA'),
                const SizedBox(height: 10),
                const Text(
                  'Vous pouvez ajuster ces montants dans vos objectifs financiers.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Fermer'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pushNamed(dialogContext, '/SavingsGoalsPage');
                },
                child: const Text('Définir des objectifs'),
              ),
            ],
          ),
        );
      }
    } on FirebaseException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'network-request-failed':
          errorMessage = 'Aucune connexion réseau. Vérifiez votre connexion.';
          break;
        case 'permission-denied':
          errorMessage = 'Accès refusé. Contactez le support.';
          break;
        default:
          errorMessage = 'Erreur Firestore : ${e.message}';
      }
      _showError(errorMessage);
      print('Erreur Firestore : $e');
    } catch (e) {
      _showError('Erreur inattendue : $e');
      print('Erreur détaillée : $e');
    }
  }

  Future<bool> _exceededRechargeAttempts() async {
    final now = DateTime.now();
    final hourKey = '${_currentUser!.uid}_${now.hour}';
    final attemptDoc = await FirebaseFirestore.instance
        .collection('recharge_attempts')
        .doc(hourKey)
        .get();

    if (!attemptDoc.exists) {
      return false;
    }

    final attempts = (attemptDoc.data()?['attemptCount'] as int?) ?? 0;
    if (attempts >= _maxRechargeAttemptsPerHour) {
      return true;
    }

    await FirebaseFirestore.instance
        .collection('recharge_attempts')
        .doc(hourKey)
        .set({
      'userId': _currentUser!.uid,
      'attemptCount': FieldValue.increment(1),
      'lastAttempt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return false;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as bool?;

    if (args == true) {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Plan de gestion de votre revenu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nous vous proposons d\'allouer votre revenu selon la règle 50/30/20 :',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text('• 50% pour les besoins : ${(widget.montantDisponible * 0.50).toStringAsFixed(2)} FCFA'),
              Text('• 30% pour les désirs : ${(widget.montantDisponible * 0.30).toStringAsFixed(2)} FCFA'),
              Text('• 20% pour l\'épargne : ${(widget.montantDisponible * 0.20).toStringAsFixed(2)} FCFA'),
              const SizedBox(height: 10),
              const Text(
                'Vous pouvez ajuster ces montants dans vos objectifs financiers.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pushNamed(dialogContext, '/SavingsGoalsPage');
              },
              child: const Text('Définir des objectifs'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}