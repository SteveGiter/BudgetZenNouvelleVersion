import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'messaging.dart';

class TransactionNotificationService {
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();
  StreamSubscription<QuerySnapshot>? _transactionSubscription;
  bool _isInitialized = false;
  String? _currentUserId;
  Set<String> _processingTransactions = {}; // Pour éviter les doublons

  Future<void> initialize() async {
    print('=== DÉBUT INITIALISATION TransactionNotificationService ===');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ Aucun utilisateur connecté - Service non initialisé');
      return;
    }

    // Éviter la double initialisation pour le même utilisateur
    if (_isInitialized && _currentUserId == user.uid) {
      print('⚠️ Service déjà initialisé pour l\'utilisateur : ${user.uid}');
      return;
    }

    // Nettoyer l'ancien listener si il existe
    if (_transactionSubscription != null) {
      print('🔄 Nettoyage de l\'ancien listener');
      await _transactionSubscription!.cancel();
      _transactionSubscription = null;
    }

    _currentUserId = user.uid;
    _isInitialized = true;
    _processingTransactions.clear(); // Nettoyer les transactions en cours

    print('✅ Utilisateur connecté : ${user.uid}');
    print('✅ Email utilisateur : ${user.email}');

    // Récupérer les IDs des transactions déjà notifiées
    final prefs = await SharedPreferences.getInstance();
    final notifiedTransactionIds = prefs.getStringList('notified_transaction_ids')?.toSet() ?? {};
    print('📋 Transactions déjà notifiées : ${notifiedTransactionIds.length}');

    print('🔧 Configuration de l\'écouteur pour l\'utilisateur : ${user.uid}');
    bool isFirstSnapshot = true; // Flag pour ignorer le premier snapshot

    _transactionSubscription = FirebaseFirestore.instance
        .collection('transactions')
        .where('users', arrayContains: user.uid)
        .orderBy('dateHeure', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      print('📡 Snapshot reçu, documents : ${snapshot.docs.length}');

      // Ignorer le premier snapshot pour éviter de notifier les transactions existantes
      if (isFirstSnapshot) {
        isFirstSnapshot = false;
        print('⏭️ Premier snapshot ignoré');
        return;
      }

      if (snapshot.docs.isEmpty) {
        print('📭 Aucun document trouvé dans la collection transactions');
        return;
      }

      for (var doc in snapshot.docs) {
        final transactionId = doc.id;
        print('🆔 Transaction ID : $transactionId');
        
        // Vérifier si la transaction est déjà en cours de traitement
        if (_processingTransactions.contains(transactionId)) {
          print('🔄 Transaction déjà en cours de traitement : $transactionId');
          continue;
        }
        
        // Vérifier si la transaction a déjà été notifiée
        if (notifiedTransactionIds.contains(transactionId)) {
          print('🔄 Transaction déjà notifiée : $transactionId');
          continue;
        }

        // Marquer la transaction comme en cours de traitement
        _processingTransactions.add(transactionId);

        final transaction = doc.data();
        print('📊 Traitement de la transaction : $transaction');

        try {
          final expediteurId = transaction['expediteurId'] as String?;
          final destinataireId = transaction['destinataireId'] as String?;
          final montant = (transaction['montant'] as num?)?.toDouble() ?? 0.0;
          final categorie = transaction['categorie'] as String?;
          final description = transaction['description'] as String?;
          final dateHeure = (transaction['dateHeure'] as Timestamp?)?.toDate() ?? DateTime.now();
          final operator = description?.contains('Orange Money') ?? false ? 'Orange Money' : 'MTN Mobile Money';

          print('🔍 Analyse transaction :');
          print('   - Expéditeur : $expediteurId');
          print('   - Destinataire : $destinataireId');
          print('   - Utilisateur actuel : ${user.uid}');
          print('   - Montant : $montant');
          print('   - Catégorie : $categorie');

          if (expediteurId == null || destinataireId == null || categorie == null || description == null) {
            print('❌ Données de transaction incomplètes : $transaction');
            _processingTransactions.remove(transactionId);
            continue;
          }

          String title;
          String body;

          if (!description.contains(' de ') || !description.contains(' à ')) {
            print('❌ Format de description invalide : $description');
            _processingTransactions.remove(transactionId);
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
            print('👤 Rôle : EXPÉDITEUR');
          } else if (user.uid == destinataireId) {
            final senderPhone = description.split(' de ')[1].split(' à ')[0];
            title = '💰 Vous avez reçu un transfert !';
            body = 'Expéditeur : $senderPhone\n'
                'Montant : ${montant.toStringAsFixed(2)} FCFA\n'
                'Catégorie : $categorie\n'
                'Opérateur : $operator\n'
                'Date : ${DateFormat('dd MMMM yyyy HH:mm', 'fr_FR').format(dateHeure)}';
            print('👤 Rôle : DESTINATAIRE');
          } else {
            print('❌ Utilisateur non impliqué dans la transaction : $transaction');
            _processingTransactions.remove(transactionId);
            continue;
          }

          print('📢 Envoi de la notification : $title - $body');
          await _messagingService.sendLocalNotification(title, body);
          print('✅ Notification envoyée avec succès pour la transaction : $transactionId');

          // Ajouter l'ID de la transaction à la liste des notifiées
          notifiedTransactionIds.add(transactionId);
          await prefs.setStringList('notified_transaction_ids', notifiedTransactionIds.toList());
          print('💾 Transaction $transactionId marquée comme notifiée');
          
          // Retirer de la liste des transactions en cours
          _processingTransactions.remove(transactionId);
          
          // Attendre un peu pour éviter les notifications multiples
          await Future.delayed(Duration(milliseconds: 500));
        } catch (e, stackTrace) {
          print('❌ Erreur lors du traitement de la transaction $transactionId : $e\n$stackTrace');
          _processingTransactions.remove(transactionId);
        }
      }
    }, onError: (e, stackTrace) {
      print('❌ Erreur dans l\'écouteur de transactions : $e\n$stackTrace');
    });

    print('✅ Écouteur Firestore configuré avec succès');
    print('=== FIN INITIALISATION TransactionNotificationService ===');
  }

  void dispose() {
    print('🔄 Disposal de TransactionNotificationService');
    _transactionSubscription?.cancel();
    _transactionSubscription = null;
    _isInitialized = false;
    _currentUserId = null;
    _processingTransactions.clear();
  }
}