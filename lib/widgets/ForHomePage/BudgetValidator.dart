import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../../services/firebase/firestore.dart';

class BudgetValidator {
  static Future<bool> validateBudget(
      BuildContext context,
      FirestoreService firestoreService,
      String userId,
      double amount,
      String? selectedGoalId,
      List<Map<String, dynamic>> savingsGoals) async {
    // Vérifier si un objectif est sélectionné
    if (selectedGoalId == null) {
      _showSnackBar(context, 'Veuillez choisir un objectif d\'épargne avant de continuer.');
      return false;
    }

    // Vérifier si l'objectif existe dans la liste
    final selectedGoal = savingsGoals.firstWhereOrNull((goal) => goal['id'] == selectedGoalId);
    if (selectedGoal == null) {
      _showSnackBar(context, 'L\'objectif sélectionné n\'est plus disponible. Choisissez un autre objectif.');
      return false;
    }

    // Récupérer le montant disponible du compte mobile
    final compteDoc = await firestoreService.firestore
        .collection('comptesMobiles')
        .doc(userId)
        .get();

    if (!compteDoc.exists) {
      _showSnackBar(context, 'Votre compte n\'est pas configuré. Ajoutez un numéro de téléphone pour continuer.');
      return false;
    }

    final montantDisponible = (compteDoc.data()?['montantDisponible'] as num?)?.toDouble() ?? 0.0;

    // Vérifier si le montant disponible est suffisant
    if (amount > montantDisponible) {
      _showSnackBar(context, 'Vous n\'avez pas assez d\'argent sur votre compte pour cette épargne.');
      return false;
    }

    // Vérifier si le montant dépasse le restant pour l'objectif
    final montantRestant = selectedGoal['montantCible'] - selectedGoal['montantActuel'];
    if (amount > montantRestant) {
      _showSnackBar(context, 'Le montant dépasse ce qui reste pour cet objectif. Maximum : ${montantRestant.toStringAsFixed(2)} FCFA.');
      return false;
    }

    return true;
  }

  static void _showSnackBar(BuildContext context, String message) {
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
        duration: const Duration(seconds: 4),
      ),
    );
  }
}