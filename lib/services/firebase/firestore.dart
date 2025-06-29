import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:rxdart/rxdart.dart';

import 'messaging.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StreamSubscription> _activeSubscriptions = {};

  // Getter public
  FirebaseFirestore get firestore => _firestore;

  // -------------------- UTILISATEURS --------------------

  Future<bool> userExists(String uid) async {
    final docSnapshot = await _firestore.collection('utilisateurs').doc(uid).get();
    return docSnapshot.exists;
  }

  Future<void> updateLastLogin(String uid) async {
    final userDoc = _firestore.collection('utilisateurs').doc(uid);
    await userDoc.update({
      'derniereConnexion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createOrUpdateUserProfile({
    required String uid,
    required String nomPrenom,
    required String email,
    String? numeroTelephone,
    String role = 'utilisateur',
    required String provider,
  }) async {
    final userDocRef = _firestore.collection('utilisateurs').doc(uid);
    final exists = await userExists(uid);

    if (exists) {
      await userDocRef.update({
        'nomPrenom': nomPrenom,
        'email': email,
        if (numeroTelephone != null) 'numeroTelephone': numeroTelephone,
        'derniereConnexion': FieldValue.serverTimestamp(),
      });
    } else {
      await userDocRef.set({
        'nomPrenom': nomPrenom,
        'email': email,
        'numeroTelephone': numeroTelephone,
        'role': role,
        'provider': provider,
        'dateInscription': FieldValue.serverTimestamp(),
        'derniereConnexion': FieldValue.serverTimestamp(),
      });

      // Création automatique du compte mobile avec code par défaut
      final compteMobileDoc = _firestore.collection('comptesMobiles').doc(uid);
      await compteMobileDoc.set({
        'montantDisponible': 0.0,
        'numeroTelephone': numeroTelephone ?? '',
        'code': '123456',
        'dateCreation': FieldValue.serverTimestamp(),
      });

      // Ajout d'une entrée dans l'historique de connexion
      final historiqueDoc = _firestore.collection('historique_connexions').doc();
      await historiqueDoc.set({
        'uid': uid,
        'email': email,
        'timestamp': FieldValue.serverTimestamp(),
        'evenement': 'Création du compte',
      });

      // Initialiser les statistiques
      await initializeStatistics(uid);

      // Initialiser le token FCM pour le nouvel utilisateur
      final messagingService = FirebaseMessagingService();
      await messagingService.initialize();
    }
  }

  Future<void> initializeStatistics(String userId) async {
    final statistiquesRef = _firestore.collection('statistiques').doc(userId);
    await statistiquesRef.set({
      'utilisateurId': userId,
      'depensesTotales': 0,
      'revenusTotaux': 0,
      'epargnesTotales': 0,
      'soldeActuel': 0,
      'derniereMiseAJour': FieldValue.serverTimestamp(),
    });

    // Démarrer le suivi en temps réel
    await createOrUpdateStatistiques(userId);
  }

  Future<DocumentSnapshot> getUser(String uid) async {
    return await _firestore.collection('utilisateurs').doc(uid).get();
  }

  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _firestore.collection('utilisateurs').doc(uid).snapshots();
  }

  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('utilisateurs').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['role'] as String?;
      }
    } catch (e) {
      debugPrint("Erreur lors de la récupération du rôle utilisateur : $e");
    }
    return null;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('utilisateurs').doc(uid).update(data);
    } catch (e) {
      debugPrint("Erreur lors de la mise à jour de l'utilisateur $uid : $e");
      throw Exception("Échec de la mise à jour");
    }
  }

  Future<void> deleteUser(String uid) async {
    await _firestore.collection('utilisateurs').doc(uid).delete();
    await _firestore.collection('comptesMobiles').doc(uid).delete();
    cancelStatisticsSubscription(uid);
  }

  // -------------------- COMPTES MOBILES --------------------

  Future<void> createOrUpdateCompteMobile({
    required String uid,
    required String numeroTelephone,
    String? code,
  }) async {
    final compteMobileRef = _firestore.collection('comptesMobiles').doc(uid);
    final docSnapshot = await compteMobileRef.get();

    if (docSnapshot.exists) {
      await compteMobileRef.update({
        'numeroTelephone': numeroTelephone,
        if (code != null) 'code': code,
        'derniereMiseAJour': FieldValue.serverTimestamp(),
      });
    } else {
      await compteMobileRef.set({
        'montantDisponible': 0.0,
        'numeroTelephone': numeroTelephone,
        'code': code ?? '123456', // Code par défaut
        'dateCreation': FieldValue.serverTimestamp(),
        'derniereMiseAJour': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<double?> getMontantDisponible(String userId) async {
    try {
      final doc = await _firestore.collection('comptesMobiles').doc(userId).get();
      return (doc.data()?['montantDisponible'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  Stream<double> streamMontantDisponible(String userId) {
    return _firestore
        .collection('comptesMobiles')
        .doc(userId)
        .snapshots()
        .map((doc) => (doc.data()?['montantDisponible'] as num?)?.toDouble() ?? 0.0);
  }

  Future<void> updateMontantDisponible(String userId, double montant) async {
    await _firestore.collection('comptesMobiles').doc(userId).update({
      'montantDisponible': FieldValue.increment(montant),
      'derniereMiseAJour': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> verifyMobileCode(String userId, String code) async {
    final doc = await _firestore.collection('comptesMobiles').doc(userId).get();
    return doc.exists && doc.data()?['code'] == code;
  }

  // -------------------- TRANSACTIONS -----------------------
  Future<void> saveTransaction({
    required String expediteurId,
    required String destinataireId,
    required double montant,
    required String typeTransaction,
    required String categorie,
    String? description,
  }) async {
    final transactionData = {
      'expediteurId': expediteurId,
      'destinataireId': destinataireId,
      'users': [expediteurId, destinataireId],
      'montant': montant,
      'typeTransaction': typeTransaction,
      'categorie': categorie,
      'description': description,
      'dateHeure': FieldValue.serverTimestamp(),
      'expediteurDeleted': null,
      'destinataireDeleted': null,
    };

    await _firestore.collection('transactions').add(transactionData);
  }

  Future<QuerySnapshot> getTransactions(String userId) async {
    return await _firestore
        .collection('transactions')
        .where('users', arrayContains: userId)
        .where('expediteurDeleted', isEqualTo: null)
        .where('destinataireDeleted', isEqualTo: null)
        .orderBy('dateHeure', descending: true)
        .get();
  }

  Future<void> updateTransaction(String id, Map<String, dynamic> data) async {
    await _firestore.collection('transactions').doc(id).update(data);
  }

  Future<void> softDeleteTransaction(String transactionId, String userId, {String? description}) async {
    final doc = await _firestore.collection('transactions').doc(transactionId).get();
    final data = doc.data();

    if (data == null) return;

    final isExpediteur = data['expediteurId'] == userId;
    final fieldToUpdate = isExpediteur ? 'expediteurDeleted' : 'destinataireDeleted';

    await _firestore.collection('transactions').doc(transactionId).update({
      fieldToUpdate: userId,
    });
    final messagingService = FirebaseMessagingService();
    await messagingService.sendLocalNotification(
      'Transaction supprimée',
      description != null
        ? 'La transaction « $description » a été supprimée de votre historique.'
        : 'Une transaction a été supprimée de votre historique.',
    );
  }

  // -------------------- STATISTIQUES EN TEMPS RÉEL --------------------
  Future<void> createOrUpdateStatistiques(String utilisateurId) async {
    cancelStatisticsSubscription(utilisateurId);

    final statistiquesRef = _firestore.collection('statistiques').doc(utilisateurId);
    final docSnapshot = await statistiquesRef.get();

    if (!docSnapshot.exists) {
      await statistiquesRef.set({
        'utilisateurId': utilisateurId,
        'mois': '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
        'depensesTotales': 0,
        'revenusTotaux': 0,
        'epargnesTotales': 0,
        'soldeActuel': 0,
        'derniereMiseAJour': FieldValue.serverTimestamp(),
      });
    }

    if (_activeSubscriptions.containsKey(utilisateurId)) {
      return;
    }

    final depensesStream = streamTotalDepenses(utilisateurId).distinct();
    final revenusStream = streamTotalRevenus(utilisateurId).distinct();
    final epargnesStream = streamTotalEpargnes(utilisateurId).distinct();
    final montantDisponibleStream = streamMontantDisponible(utilisateurId).distinct();

    final combinedStream = Rx.combineLatest4(
      depensesStream,
      revenusStream,
      epargnesStream,
      montantDisponibleStream,
          (double depenses, double revenus, double epargnes, double montantDisponible) => {
        'depenses': depenses,
        'revenus': revenus,
        'epargnes': epargnes,
        'soldeActuel': montantDisponible,
      },
    ).distinct();

    _activeSubscriptions[utilisateurId] = combinedStream.throttleTime(
      const Duration(seconds: 1),
      trailing: true,
    ).listen((data) async {
      final now = DateTime.now();
      final mois = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      try {
        final newDepenses = data['depenses'] ?? 0.0;
        final newRevenus = data['revenus'] ?? 0.0;
        final newEpargnes = data['epargnes'] ?? 0.0;
        final newSolde = data['soldeActuel'] ?? 0.0;

        await statistiquesRef.set({
          'utilisateurId': utilisateurId,
          'mois': mois,
          'depensesTotales': newDepenses,
          'revenusTotaux': newRevenus,
          'epargnesTotales': newEpargnes,
          'soldeActuel': newSolde,
          'derniereMiseAJour': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Erreur lors de la mise à jour des statistiques : $e');
        cancelStatisticsSubscription(utilisateurId);
        await createOrUpdateStatistiques(utilisateurId);
      }
    });
  }

  void cancelStatisticsSubscription(String userId) {
    if (_activeSubscriptions.containsKey(userId)) {
      _activeSubscriptions[userId]!.cancel();
      _activeSubscriptions.remove(userId);
    }
  }

  Stream<DocumentSnapshot> getStatisticsStream(String userId) {
    return _firestore.collection('statistiques').doc(userId).snapshots();
  }

  // -------------------- OBJECTIFS ÉPARGNE --------------------
  Future<void> createObjectifEpargne({
    required String userId,
    required String nomObjectif,
    required double montantCible,
    required Timestamp dateLimite,
    String? categorie,
  }) async {
    final objectifData = {
      'userId': userId,
      'nomObjectif': nomObjectif,
      'montantCible': montantCible,
      'montantActuel': 0.0,
      'dateLimite': dateLimite,
      'categorie': categorie ?? 'Autre',
      'dateCreation': FieldValue.serverTimestamp(),
      'derniereMiseAJour': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('objectifsEpargne').add(objectifData);
  }

  Future<QuerySnapshot> getObjectifsEpargne(String userId) async {
    return await _firestore
        .collection('objectifsEpargne')
        .where('userId', isEqualTo: userId)
        .orderBy('dateCreation', descending: true)
        .get();
  }

  Future<QuerySnapshot> getObjectifsEpargneByCategorie(String userId, String categorie) async {
    return await _firestore
        .collection('objectifsEpargne')
        .where('userId', isEqualTo: userId)
        .where('categorie', isEqualTo: categorie)
        .orderBy('dateCreation', descending: true)
        .get();
  }

  Future<void> updateObjectifEpargne(String id, Map<String, dynamic> data) async {
    await _firestore.collection('objectifsEpargne').doc(id).update(data);
  }

  Future<void> deleteObjectifEpargne(String id, {String? nomObjectif}) async {
    await _firestore.collection('objectifsEpargne').doc(id).delete();
    final messagingService = FirebaseMessagingService();
    await messagingService.sendLocalNotification(
      'Objectif supprimé',
      nomObjectif != null
        ? 'L\'objectif d\'épargne « $nomObjectif » a été supprimé.'
        : 'Un objectif d\'épargne a été supprimé.',
    );
  }

  Stream<QuerySnapshot> streamObjectifsEpargneByCategorie(String userId, String categorie) {
    return _firestore
        .collection('objectifsEpargne')
        .where('userId', isEqualTo: userId)
        .where('categorie', isEqualTo: categorie)
        .orderBy('dateCreation', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> streamAllObjectifsEpargne(String userId) {
    return _firestore
        .collection('objectifsEpargne')
        .where('userId', isEqualTo: userId)
        .orderBy('dateCreation', descending: true)
        .snapshots();
  }

  // -------------------- REVENUS --------------------
  Future<void> addRevenu({
    required String userId,
    required double montant,
    required String categorie,
    String? description,
  }) async {
    try {
      await _firestore.collection('revenus').add({
        'userId': userId,
        'montant': montant,
        'categorie': categorie,
        'description': description,
        'dateCreation': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Erreur lors de l'ajout du revenu : $e");
      rethrow;
    }
  }

  // -------------------- DEPENSES --------------------
  Future<void> addDepense({
    required String userId,
    required double montant,
    required String categorie,
    String? description,
  }) async {
    try {
      await _firestore.collection('depenses').add({
        'userId': userId,
        'montant': montant,
        'categorie': categorie,
        'description': description,
        'dateCreation': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Erreur lors de l'ajout de la dépense : $e");
      rethrow;
    }
  }

  // -------------------- EPARGNES --------------------
  Future<Map<String, dynamic>> addEpargne({
    required String userId,
    required double montant,
    required String categorie,
    String? description,
    required String objectifId,
  }) async {
    try {
      double montantVerse = montant;
      bool objectifAtteint = false;
      await _firestore.runTransaction((transaction) async {
        final compteRef = _firestore.collection('comptesMobiles').doc(userId);
        final objectifRef = _firestore.collection('objectifsEpargne').doc(objectifId);
        final epargneRef = _firestore.collection('epargnes').doc();

        // Récupérer les documents
        final compteSnap = await transaction.get(compteRef);
        final objectifSnap = await transaction.get(objectifRef);

        // Vérifications
        if (!compteSnap.exists) {
          throw Exception('Compte mobile introuvable.');
        }
        if (!objectifSnap.exists) {
          throw Exception('Objectif d\'épargne introuvable.');
        }

        final compteData = compteSnap.data();
        final objectifData = objectifSnap.data();

        if (compteData == null || objectifData == null) {
          throw Exception('Données invalides ou corrompues.');
        }

        final currentMontant = (compteData['montantDisponible'] as num?)?.toDouble() ?? 0.0;
        final currentMontantActuel = (objectifData['montantActuel'] as num?)?.toDouble() ?? 0.0;
        final montantCible = (objectifData['montantCible'] as num?)?.toDouble() ?? 0.0;
        final isCompleted = (objectifData['isCompleted'] as bool?) ?? false;
        final dateLimite = objectifData['dateLimite'] as Timestamp?;

        if (dateLimite != null && dateLimite.toDate().isBefore(DateTime.now())) {
          throw Exception('Objectif expiré.');
        }

        if (isCompleted || currentMontantActuel >= montantCible) {
          throw Exception('Cet objectif est déjà atteint.');
        }

        if (montant > currentMontant) {
          throw Exception('Solde insuffisant.');
        }

        final montantRestant = montantCible - currentMontantActuel;
        if (montant > montantRestant) {
          montantVerse = montantRestant;
        }

        // Ajouter l'épargne
        transaction.set(epargneRef, {
          'userId': userId,
          'montant': montantVerse,
          'categorie': categorie,
          'description': description,
          'objectifId': objectifId,
          'dateCreation': FieldValue.serverTimestamp(),
        });

        // Débiter le compte mobile
        transaction.update(compteRef, {
          'montantDisponible': FieldValue.increment(-montantVerse),
          'derniereMiseAJour': FieldValue.serverTimestamp(),
        });

        // Mettre à jour l'objectif
        final newMontantActuel = currentMontantActuel + montantVerse;
        objectifAtteint = newMontantActuel >= montantCible;
        transaction.update(objectifRef, {
          'montantActuel': newMontantActuel,
          'isCompleted': objectifAtteint,
          'derniereMiseAJour': FieldValue.serverTimestamp(),
        });
      });
      return {'montantVerse': montantVerse, 'objectifAtteint': objectifAtteint};
    } catch (e) {
      debugPrint("Erreur lors de l'ajout de l'épargne : $e");
      rethrow;
    }
  }

  // -------------------- MÉTHODES DE CALCUL --------------------
  Future<double> getTotalDepenses(String userId) async {
    final query = _firestore.collection('depenses').where('userId', isEqualTo: userId);
    final snapshot = await query.get();
    return snapshot.docs.fold<double>(0.0, (double sum, doc) {
      final data = doc.data();
      return sum + (data['montant'] as num).toDouble();
    });
  }

  Stream<double> streamTotalDepenses(String userId) {
    return _firestore
        .collection('depenses')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.fold<double>(0.0, (double sum, doc) {
      final data = doc.data();
      return sum + (data['montant'] as num?)!.toDouble();
    }));
  }

  Future<double> getTotalRevenus(String userId) async {
    final query = _firestore.collection('revenus').where('userId', isEqualTo: userId);
    final snapshot = await query.get();
    return snapshot.docs.fold<double>(0.0, (double sum, doc) {
      final data = doc.data();
      return sum + (data['montant'] as num?)!.toDouble();
    });
  }

  Stream<double> streamTotalRevenus(String userId) {
    return _firestore
        .collection('revenus')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.fold<double>(0.0, (double sum, doc) {
      final data = doc.data();
      return sum + (data['montant'] as num?)!.toDouble();
    }));
  }

  Future<double> getTotalEpargnes(String userId) async {
    final query = _firestore.collection('epargnes').where('userId', isEqualTo: userId);
    final snapshot = await query.get();
    return snapshot.docs.fold<double>(0.0, (double sum, doc) {
      final data = doc.data();
      return sum + (data['montant'] as num).toDouble();
    });
  }

  Stream<double> streamTotalEpargnes(String userId) {
    return _firestore
        .collection('epargnes')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.fold<double>(0.0, (double sum, doc) {
      final data = doc.data();
      return sum + (data['montant'] as num).toDouble();
    }));
  }

  Stream<double> streamMontantActuelParObjectif(String objectifId) {
    return _firestore
        .collection('epargnes')
        .where('objectifId', isEqualTo: objectifId)
        .snapshots()
        .map((snapshot) => snapshot.docs.fold<double>(0.0, (double sum, doc) {
      final data = doc.data();
      return sum + (data['montant'] as num).toDouble();
    }));
  }

  // -------------------- NOUVELLES MÉTHODES POUR FILTRE MENSUEL --------------------
  Stream<double> streamTotalDepensesByMonth(String userId, int month) {
    final now = DateTime.now();
    final start = Timestamp.fromDate(DateTime(now.year, month, 1));
    final end = Timestamp.fromDate(DateTime(now.year, month + 1, 1).subtract(const Duration(seconds: 1)));

    return _firestore
        .collection('depenses')
        .where('userId', isEqualTo: userId)
        .where('dateCreation', isGreaterThanOrEqualTo: start)
        .where('dateCreation', isLessThanOrEqualTo: end)
        .snapshots()
        .map((snapshot) => snapshot.docs.fold<double>(0.0, (double sum, doc) {
      final data = doc.data();
      return sum + (data['montant'] as num).toDouble();
    }));
  }

  Stream<double> streamTotalRevenusByMonth(String userId, int month) {
    final now = DateTime.now();
    final start = Timestamp.fromDate(DateTime(now.year, month, 1));
    final end = Timestamp.fromDate(DateTime(now.year, month + 1, 1).subtract(const Duration(seconds: 1)));

    return _firestore
        .collection('revenus')
        .where('userId', isEqualTo: userId)
        .where('dateCreation', isGreaterThanOrEqualTo: start)
        .where('dateCreation', isLessThanOrEqualTo: end)
        .snapshots()
        .map((snapshot) => snapshot.docs.fold<double>(0.0, (double sum, doc) {
      final data = doc.data();
      return sum + (data['montant'] as num).toDouble();
    }));
  }

  Stream<double> streamTotalEpargnesByMonth(String userId, int month) {
    final now = DateTime.now();
    final start = Timestamp.fromDate(DateTime(now.year, month, 1));
    final end = Timestamp.fromDate(DateTime(now.year, month + 1, 1).subtract(const Duration(seconds: 1)));

    return _firestore
        .collection('epargnes')
        .where('userId', isEqualTo: userId)
        .where('dateCreation', isGreaterThanOrEqualTo: start)
        .where('dateCreation', isLessThanOrEqualTo: end)
        .snapshots()
        .map((snapshot) => snapshot.docs.fold<double>(0.0, (double sum, doc) {
      final data = doc.data();
      return sum + (data['montant'] as num).toDouble();
    }));
  }

  // -------------------- UTILITAIRE --------------------
  Future<bool> isPhoneNumberUnique(String phoneNumber, String? provider, String uid) async {
    final query = _firestore.collection('comptesMobiles').where('numeroTelephone', isEqualTo: phoneNumber);
    final snapshot = await query.get();

    final existingUsers = snapshot.docs.where((doc) {
      final data = doc.data();
      if (provider == 'google') {
        return data['provider'] == 'google' && doc.id != uid;
      }
      return data['provider'] != 'google';
    });

    return existingUsers.isEmpty;
  }

  Future<bool> isPhoneNumberUniqueForAllUsers(String phoneNumber, String uid) async {
    final query = _firestore.collection('utilisateurs').where('numeroTelephone', isEqualTo: phoneNumber);
    final snapshot = await query.get();

    return snapshot.docs.every((doc) => doc.id == uid);
  }

  Future<void> updatePhoneNumberEverywhere(String uid, String numeroTelephone) async {
    await updateUser(uid, {'numeroTelephone': numeroTelephone});
    final role = await getUserRole(uid);
    if (role != 'administrateur') {
      await createOrUpdateCompteMobile(uid: uid, numeroTelephone: numeroTelephone);
    }
  }

  void dispose() {
    for (var subscription in _activeSubscriptions.values) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();
  }

  // -------------------- BUDGETS UTILISATEUR --------------------

  Future<void> definirBudget({
    required String userId,
    required double montant,
    required String type,
    required DateTime periodeDebut,
    required DateTime periodeFin,
  }) async {
    // Normaliser les dates pour supprimer les composantes horaires
    final normalizedDebut = DateTime(periodeDebut.year, periodeDebut.month, periodeDebut.day);
    final normalizedFin = DateTime(periodeFin.year, periodeFin.month, periodeFin.day, 23, 59, 59);

    // Vérifier la dernière modification pour ce type et cette période
    final existing = await _firestore
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: type)
        .where('periodeDebut', isEqualTo: Timestamp.fromDate(normalizedDebut))
        .where('periodeFin', isEqualTo: Timestamp.fromDate(normalizedFin))
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      final createdAt = (doc['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null) {
        final now = DateTime.now();
        final diff = now.difference(createdAt).inDays;
        if (diff < 5) {
          final nextModificationDate = createdAt.add(const Duration(days: 5));
          final formattedLastDate = '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
          final formattedNextDate = '${nextModificationDate.day.toString().padLeft(2, '0')}/${nextModificationDate.month.toString().padLeft(2, '0')}/${nextModificationDate.year}';
          throw Exception('Délai de modification non respecté. Dernière modification : $formattedLastDate. Prochaine modification possible : $formattedNextDate. Vous devez attendre 5 jours entre chaque modification de budget.');
        }
      }
    }
    await _firestore.collection('budgets').add({
      'userId': userId,
      'montant': montant,
      'type': type,
      'periodeDebut': Timestamp.fromDate(normalizedDebut),
      'periodeFin': Timestamp.fromDate(normalizedFin),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBudget({
    required String budgetId,
    required double montant,
  }) async {
    await _firestore.collection('budgets').doc(budgetId).update({
      'montant': montant,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<QuerySnapshot> getBudgets(String userId) async {
    return await _firestore
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .orderBy('periodeDebut', descending: true)
        .get();
  }

  Future<DocumentSnapshot?> getBudgetForPeriod(String userId, DateTime periodeDebut, DateTime periodeFin, {required String type}) async {
    final query = await _firestore
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .where('periodeDebut', isEqualTo: Timestamp.fromDate(periodeDebut))
        .where('periodeFin', isEqualTo: Timestamp.fromDate(periodeFin))
        .where('type', isEqualTo: type)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return query.docs.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> checkDepassementBudget({
    required String userId,
    required double montantAjoute,
    String type = 'mensuel',
  }) async {
    // Déterminer la période
    final now = DateTime.now();
    late DateTime periodeDebut;
    late DateTime periodeFin;
    if (type == 'mensuel') {
      periodeDebut = DateTime(now.year, now.month, 1);
      periodeFin = DateTime(now.year, now.month + 1, 0);
    } else if (type == 'annuel') {
      periodeDebut = DateTime(now.year, 1, 1);
      periodeFin = DateTime(now.year, 12, 31);
    } else if (type == 'hebdomadaire') {
      // Utiliser la même logique que getCurrentWeekOfMonth
      DateTime firstDay = DateTime(now.year, now.month, 1);
      DateTime lastDay = DateTime(now.year, now.month + 1, 0);
      DateTime currentMonday = firstDay;

      // Aller au premier lundi du mois
      while (currentMonday.weekday != DateTime.monday) {
        currentMonday = currentMonday.add(const Duration(days: 1));
      }

      // Trouver la semaine courante
      List<Map<String, DateTime>> weeks = [];
      while (currentMonday.isBefore(lastDay) || currentMonday.isAtSameMomentAs(lastDay)) {
        DateTime currentSunday = currentMonday.add(const Duration(days: 6));
        if (currentSunday.isAfter(lastDay)) currentSunday = lastDay;
        weeks.add({
          'start': DateTime(currentMonday.year, currentMonday.month, currentMonday.day),
          'end': DateTime(currentSunday.year, currentSunday.month, currentSunday.day, 23, 59, 59),
        });
        currentMonday = currentMonday.add(const Duration(days: 7));
      }

      // Ajouter la première semaine si le mois ne commence pas un lundi
      if (firstDay.isBefore(weeks.isNotEmpty ? weeks[0]['start']! : lastDay)) {
        final previousDay = weeks.isNotEmpty
            ? weeks[0]['start']!.subtract(const Duration(days: 1))
            : lastDay;
        weeks.insert(0, {
          'start': DateTime(firstDay.year, firstDay.month, firstDay.day),
          'end': DateTime(previousDay.year, previousDay.month, previousDay.day, 23, 59, 59),
        });
      }

      // Trouver la semaine courante
      int weekIndex = weeks.indexWhere((w) =>
          now.isAfter(w['start']!.subtract(const Duration(days: 1))) &&
          now.isBefore(w['end']!.add(const Duration(days: 1))));
      if (weekIndex == -1) weekIndex = 0;

      periodeDebut = weeks[weekIndex]['start']!;
      periodeFin = weeks[weekIndex]['end']!;
    } else {
      // Par défaut, mensuel
      periodeDebut = DateTime(now.year, now.month, 1);
      periodeFin = DateTime(now.year, now.month + 1, 0);
    }

    // Récupérer le budget courant
    final budgetDoc = await getBudgetForPeriod(userId, periodeDebut, periodeFin, type: type);
    if (budgetDoc == null || !budgetDoc.exists) return null;
    final budget = budgetDoc.data() as Map<String, dynamic>;
    final montantBudget = (budget['montant'] as num?)?.toDouble() ?? 0.0;

    // Récupérer les dépenses de la période
    final depensesSnap = await _firestore
        .collection('depenses')
        .where('userId', isEqualTo: userId)
        .where('dateCreation', isGreaterThanOrEqualTo: Timestamp.fromDate(periodeDebut))
        .where('dateCreation', isLessThanOrEqualTo: Timestamp.fromDate(periodeFin))
        .get();
    final totalDepenses = depensesSnap.docs.fold<double>(0.0, (sum, doc) {
      final data = doc.data();
      return sum + (data['montant'] as num?)!.toDouble();
    });

    final totalAvecOperation = totalDepenses + montantAjoute;
    if (totalAvecOperation > montantBudget) {
      return {
        'type': type,
        'montantBudget': montantBudget,
        'periodeDebut': periodeDebut,
        'periodeFin': periodeFin,
        'totalDepenses': totalDepenses,
        'totalAvecOperation': totalAvecOperation,
        'depassement': totalAvecOperation - montantBudget,
      };
    }
    return null;
  }

  Future<bool> isBudgetAlreadyExceeded({
    required String userId,
    String type = 'mensuel',
  }) async {
    // Déterminer la période
    final now = DateTime.now();
    late DateTime periodeDebut;
    late DateTime periodeFin;
    if (type == 'mensuel') {
      periodeDebut = DateTime(now.year, now.month, 1);
      periodeFin = DateTime(now.year, now.month + 1, 0);
    } else if (type == 'annuel') {
      periodeDebut = DateTime(now.year, 1, 1);
      periodeFin = DateTime(now.year, 12, 31);
    } else if (type == 'hebdomadaire') {
      // Utiliser la même logique que getCurrentWeekOfMonth
      DateTime firstDay = DateTime(now.year, now.month, 1);
      DateTime lastDay = DateTime(now.year, now.month + 1, 0);
      DateTime currentMonday = firstDay;

      // Aller au premier lundi du mois
      while (currentMonday.weekday != DateTime.monday) {
        currentMonday = currentMonday.add(const Duration(days: 1));
      }

      // Trouver la semaine courante
      List<Map<String, DateTime>> weeks = [];
      while (currentMonday.isBefore(lastDay) || currentMonday.isAtSameMomentAs(lastDay)) {
        DateTime currentSunday = currentMonday.add(const Duration(days: 6));
        if (currentSunday.isAfter(lastDay)) currentSunday = lastDay;
        weeks.add({
          'start': DateTime(currentMonday.year, currentMonday.month, currentMonday.day),
          'end': DateTime(currentSunday.year, currentSunday.month, currentSunday.day, 23, 59, 59),
        });
        currentMonday = currentMonday.add(const Duration(days: 7));
      }

      // Ajouter la première semaine si le mois ne commence pas un lundi
      if (firstDay.isBefore(weeks.isNotEmpty ? weeks[0]['start']! : lastDay)) {
        final previousDay = weeks.isNotEmpty
            ? weeks[0]['start']!.subtract(const Duration(days: 1))
            : lastDay;
        weeks.insert(0, {
          'start': DateTime(firstDay.year, firstDay.month, firstDay.day),
          'end': DateTime(previousDay.year, previousDay.month, previousDay.day, 23, 59, 59),
        });
      }

      // Trouver la semaine courante
      int weekIndex = weeks.indexWhere((w) =>
          now.isAfter(w['start']!.subtract(const Duration(days: 1))) &&
          now.isBefore(w['end']!.add(const Duration(days: 1))));
      if (weekIndex == -1) weekIndex = 0;

      periodeDebut = weeks[weekIndex]['start']!;
      periodeFin = weeks[weekIndex]['end']!;
    } else {
      // Par défaut, mensuel
      periodeDebut = DateTime(now.year, now.month, 1);
      periodeFin = DateTime(now.year, now.month + 1, 0);
    }

    // Récupérer le budget courant
    final budgetDoc = await getBudgetForPeriod(userId, periodeDebut, periodeFin, type: type);
    if (budgetDoc == null || !budgetDoc.exists) return false;
    final budget = budgetDoc.data() as Map<String, dynamic>;
    final montantBudget = (budget['montant'] as num?)?.toDouble() ?? 0.0;

    // Récupérer les dépenses de la période
    final depensesSnap = await _firestore
        .collection('depenses')
        .where('userId', isEqualTo: userId)
        .where('dateCreation', isGreaterThanOrEqualTo: Timestamp.fromDate(periodeDebut))
        .where('dateCreation', isLessThanOrEqualTo: Timestamp.fromDate(periodeFin))
        .get();
    final totalDepenses = depensesSnap.docs.fold<double>(0.0, (sum, doc) {
      final data = doc.data();
      return sum + (data['montant'] as num?)!.toDouble();
    });

    return totalDepenses > montantBudget;
  }

  // -------------------- HISTORIQUE RECHARGES ET RETRAITS --------------------
  Stream<QuerySnapshot> streamRecharges(String userId) {
    return _firestore
        .collection('revenus')
        .where('userId', isEqualTo: userId)
        .where('categorie', isEqualTo: 'Recharge')
        .orderBy('dateCreation', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> streamRetraits(String userId) {
    return _firestore
        .collection('depenses')
        .where('userId', isEqualTo: userId)
        .where('categorie', isEqualTo: 'Retrait')
        .orderBy('dateCreation', descending: true)
        .snapshots();
  }

  Future<List<QueryDocumentSnapshot>> getBudgetsHebdomadairesForMonth(String userId, int year, int month) async {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);

    final query = await _firestore
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'hebdomadaire')
        .where('periodeDebut', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .where('periodeDebut', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
        .get();

    return query.docs;
  }
}