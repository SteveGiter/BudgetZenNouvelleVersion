import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'messaging.dart';

class TransactionNotificationService {
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();
  StreamSubscription<QuerySnapshot>? _transactionSubscription;

  Future<void> initialize() async {
    print('Initialisation de TransactionNotificationService');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Aucun utilisateur connecté');
      return;
    }

    // Récupérer les IDs des transactions déjà notifiées
    final prefs = await SharedPreferences.getInstance();
    final notifiedTransactionIds = prefs.getStringList('notified_transaction_ids')?.toSet() ?? {};

    print('Configuration de l\'écouteur pour l\'utilisateur : ${user.uid}');
    bool isFirstSnapshot = true; // Flag pour ignorer le premier snapshot

    _transactionSubscription = FirebaseFirestore.instance
        .collection('transactions')
        .where('users', arrayContains: user.uid)
        .orderBy('dateHeure', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      print('Snapshot reçu, documents : ${snapshot.docs.length}');

      // Ignorer le premier snapshot pour éviter de notifier les transactions existantes
      if (isFirstSnapshot) {
        isFirstSnapshot = false;
        print('Premier snapshot ignoré');
        return;
      }

      if (snapshot.docs.isEmpty) {
        print('Aucun document trouvé dans la collection transactions');
        return;
      }

      for (var doc in snapshot.docs) {
        final transactionId = doc.id;
        // Vérifier si la transaction a déjà été notifiée
        if (notifiedTransactionIds.contains(transactionId)) {
          print('Transaction déjà notifiée : $transactionId');
          continue;
        }

        final transaction = doc.data();
        print('Traitement de la transaction : $transaction');

        try {
          final expediteurId = transaction['expediteurId'] as String?;
          final destinataireId = transaction['destinataireId'] as String?;
          final montant = (transaction['montant'] as num?)?.toDouble() ?? 0.0;
          final categorie = transaction['categorie'] as String?;
          final description = transaction['description'] as String?;
          final dateHeure = (transaction['dateHeure'] as Timestamp?)?.toDate() ?? DateTime.now();
          final operator = description?.contains('Orange Money') ?? false ? 'Orange Money' : 'MTN Mobile Money';

          if (expediteurId == null || destinataireId == null || categorie == null || description == null) {
            print('Données de transaction incomplètes : $transaction');
            continue;
          }

          String title;
          String body;

          if (!description.contains(' de ') || !description.contains(' à ')) {
            print('Format de description invalide : $description');
            continue;
          }

          if (user.uid == expediteurId) {
            final recipientPhone = description.split(' à ')[1];
            title = '💸 Transfert d\'argent réussi !';
            body = 'Destinataire : $recipientPhone\n'
                'Montant : ${montant.toStringAsFixed(2)} FCFA\n'
                'Catégorie : $categorie\n'
                'Opérateur : $operator\n'
                'Date : ${DateFormat('dd MMMM yyyy HH:mm', 'fr_FR').format(dateHeure)}';
          } else if (user.uid == destinataireId) {
            final senderPhone = description.split(' de ')[1].split(' à ')[0];
            title = '💰 Vous avez reçu un transfert !';
            body = 'Expéditeur : $senderPhone\n'
                'Montant : ${montant.toStringAsFixed(2)} FCFA\n'
                'Catégorie : $categorie\n'
                'Opérateur : $operator\n'
                'Date : ${DateFormat('dd MMMM yyyy HH:mm', 'fr_FR').format(dateHeure)}';
          } else {
            print('Utilisateur non impliqué dans la transaction : $transaction');
            continue;
          }

          print('Envoi de la notification : $title - $body');
          await _messagingService.sendLocalNotification(title, body);
          print('Notification envoyée avec succès pour la transaction : $transactionId');

          // Ajouter l'ID de la transaction à la liste des notifiées
          notifiedTransactionIds.add(transactionId);
          await prefs.setStringList('notified_transaction_ids', notifiedTransactionIds.toList());
          print('Transaction $transactionId marquée comme notifiée');
        } catch (e, stackTrace) {
          print('Erreur lors du traitement de la transaction $transactionId : $e\n$stackTrace');
        }
      }
    }, onError: (e, stackTrace) {
      print('Erreur dans l\'écouteur de transactions : $e\n$stackTrace');
    });

    // Gérer la déconnexion ou changement d'utilisateur
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        print('Utilisateur déconnecté, annulation de l\'écouteur');
        _transactionSubscription?.cancel();
      }
    });
  }

  void dispose() {
    print('Disposal de TransactionNotificationService');
    _transactionSubscription?.cancel();
  }
}