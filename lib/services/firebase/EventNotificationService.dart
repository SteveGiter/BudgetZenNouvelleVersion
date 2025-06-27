import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'messaging.dart';

class EventNotificationService {
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();
  final List<StreamSubscription> _subscriptions = [];
  bool _isInitialized = false;
  String? _currentUserId;

  Future<void> initialize() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_isInitialized && _currentUserId == user.uid) return;
    await dispose();
    _currentUserId = user.uid;
    _isInitialized = true;
    final prefs = await SharedPreferences.getInstance();

    _subscriptions.add(_listenBudgetExceeded(user.uid, prefs));
    _subscriptions.add(_listenLowBalance(user.uid, prefs));
    _subscriptions.add(_listenGoalReached(user.uid, prefs));
    _subscriptions.add(_listenBigTransaction(user.uid, prefs));
    // Rappel d'épargne périodique : à planifier côté UI/app (notification locale planifiée)
    _subscriptions.add(_listenUnusualExpense(user.uid, prefs));
    // Résumé périodique : à planifier côté UI/app (notification locale planifiée)
    _subscriptions.add(_listenTransactionRefused(user.uid, prefs));
    _subscriptions.add(_listenSecurityAlert(user.uid, prefs));
    _subscriptions.add(_listenSuddenBalanceChange(user.uid, prefs));
    _subscriptions.add(_listenBudget75Percent(user.uid, prefs));
  }

  // 1. Dépassement de budget
  StreamSubscription _listenBudgetExceeded(String userId, SharedPreferences prefs) {
    return FirebaseFirestore.instance
        .collection('depenses')
        .where('userId', isEqualTo: userId)
        .orderBy('dateCreation', descending: true)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;
      final now = DateTime.now();
      final budgetQuery = await FirebaseFirestore.instance
          .collection('budgets')
          .where('userId', isEqualTo: userId)
          .where('periodeDebut', isLessThanOrEqualTo: now)
          .where('periodeFin', isGreaterThanOrEqualTo: now)
          .limit(1)
          .get();
      if (budgetQuery.docs.isEmpty) return;
      final budget = budgetQuery.docs.first;
      final montantBudget = (budget['montant'] as num?)?.toDouble() ?? 0.0;
      final budgetId = budget.id;
      final periodeDebut = (budget['periodeDebut'] as Timestamp).toDate();
      final periodeFin = (budget['periodeFin'] as Timestamp).toDate();
      final type = budget['type'] as String? ?? 'mensuel';
      final depenses = snapshot.docs
          .where((d) {
            final date = (d['dateCreation'] as Timestamp).toDate();
            return date.isAfter(periodeDebut.subtract(const Duration(seconds: 1))) &&
                   date.isBefore(periodeFin.add(const Duration(seconds: 1)));
          })
          .map((d) => (d['montant'] as num?)?.toDouble() ?? 0.0)
          .toList();
      final total = depenses.fold(0.0, (a, b) => a + b);
      final depassement = total - montantBudget;
      final notifiedKey = 'notified_budget_$budgetId';
      if (total > montantBudget && !(prefs.getBool(notifiedKey) ?? false)) {
        // Génération du message personnalisé
        String periodeLabel = '';
        String titre = '';
        String conseil = '';
        final now = DateTime.now();
        if (type == 'mensuel') {
          final mois = _moisFrancais(periodeDebut.month);
          periodeLabel = '$mois ${periodeDebut.year}';
          titre = 'Budget mensuel dépassé !';
          conseil = 'Essayez de limiter vos dépenses pour le reste du mois.';
        } else if (type == 'annuel') {
          periodeLabel = '${periodeDebut.year}';
          titre = 'Budget annuel dépassé !';
          conseil = 'Pensez à revoir vos objectifs pour l\'année.';
        } else if (type == 'hebdomadaire') {
          final semaine = _numeroSemaine(periodeDebut);
          periodeLabel = 'Semaine $semaine';
          titre = 'Budget hebdomadaire dépassé !';
          conseil = 'Essayez de rééquilibrer vos dépenses la semaine prochaine.';
        } else {
          periodeLabel = '';
          titre = 'Budget dépassé !';
          conseil = '';
        }
        final message =
            'Vous avez dépassé votre budget $periodeLabel de ${depassement.toStringAsFixed(0)} FCFA.\n$conseil';
        await _messagingService.sendLocalNotification(
          titre,
          message,
        );
        await prefs.setBool(notifiedKey, true);
      }
    });
  }

  // 2. Solde faible
  StreamSubscription _listenLowBalance(String userId, SharedPreferences prefs) {
    return FirebaseFirestore.instance
        .collection('comptesMobiles')
        .doc(userId)
        .snapshots()
        .listen((doc) async {
      final montant = (doc.data()?['montantDisponible'] as num?)?.toDouble() ?? 0.0;
      const seuil = 1000.0;
      final notifiedKey = 'notified_low_balance';
      if (montant < seuil && !(prefs.getBool(notifiedKey) ?? false)) {
        await _messagingService.sendLocalNotification(
          'Solde faible',
          'Votre solde est inférieur à $seuil FCFA.',
        );
        await prefs.setBool(notifiedKey, true);
      }
      if (montant >= seuil) {
        await prefs.setBool(notifiedKey, false);
      }
    });
  }

  // 3. Objectif d'épargne atteint
  StreamSubscription _listenGoalReached(String userId, SharedPreferences prefs) {
    return FirebaseFirestore.instance
        .collection('objectifsEpargne')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs) {
        final id = doc.id;
        final montantCible = (doc['montantCible'] as num?)?.toDouble() ?? 0.0;
        final montantActuel = (doc['montantActuel'] as num?)?.toDouble() ?? 0.0;
        final notifiedKey = 'notified_goal_$id';
        if (montantActuel >= montantCible && !(prefs.getBool(notifiedKey) ?? false)) {
          await _messagingService.sendLocalNotification(
            'Objectif d\'épargne atteint',
            'Félicitations ! Vous avez atteint votre objectif d\'épargne.',
          );
          await prefs.setBool(notifiedKey, true);
        }
      }
    });
  }

  // 4. Transaction importante
  StreamSubscription _listenBigTransaction(String userId, SharedPreferences prefs) {
    return FirebaseFirestore.instance
        .collection('transactions')
        .where('users', arrayContains: userId)
        .orderBy('dateHeure', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs) {
        final id = doc.id;
        final montant = (doc['montant'] as num?)?.toDouble() ?? 0.0;
        const seuil = 100000.0;
        final notifiedKey = 'notified_big_tx_$id';
        if (montant >= seuil && !(prefs.getBool(notifiedKey) ?? false)) {
          await _messagingService.sendLocalNotification(
            'Transaction importante',
            'Une transaction de ${montant.toStringAsFixed(0)} FCFA a été détectée.',
          );
          await prefs.setBool(notifiedKey, true);
        }
      }
    });
  }

  // 5. Rappel d'épargne périodique : à planifier côté UI/app (notification locale planifiée)

  // 6. Dépense inhabituelle
  StreamSubscription _listenUnusualExpense(String userId, SharedPreferences prefs) {
    return FirebaseFirestore.instance
        .collection('depenses')
        .where('userId', isEqualTo: userId)
        .orderBy('dateCreation', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;
      final doc = snapshot.docs.first;
      final id = doc.id;
      final montant = (doc['montant'] as num?)?.toDouble() ?? 0.0;
      final notifiedKey = 'notified_unusual_expense_$id';
      // Calcul de la moyenne des 30 derniers jours
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(Duration(days: 30));
      final query = await FirebaseFirestore.instance
          .collection('depenses')
          .where('userId', isEqualTo: userId)
          .where('dateCreation', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .get();
      final depenses = query.docs.map((d) => (d['montant'] as num?)?.toDouble() ?? 0.0).toList();
      final moyenne = depenses.isNotEmpty ? depenses.reduce((a, b) => a + b) / depenses.length : 0.0;
      if (moyenne > 0 && montant > 2 * moyenne && !(prefs.getBool(notifiedKey) ?? false)) {
        await _messagingService.sendLocalNotification(
          'Dépense inhabituelle',
          'Une dépense inhabituelle de ${montant.toStringAsFixed(0)} FCFA a été détectée.',
        );
        await prefs.setBool(notifiedKey, true);
      }
    });
  }

  // 8. Résumé périodique : à planifier côté UI/app (notification locale planifiée)

  // 10. Transaction refusée
  StreamSubscription _listenTransactionRefused(String userId, SharedPreferences prefs) {
    return FirebaseFirestore.instance
        .collection('transactions')
        .where('users', arrayContains: userId)
        .where('status', isEqualTo: 'refusée')
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs) {
        final id = doc.id;
        final notifiedKey = 'notified_refused_tx_$id';
        if (!(prefs.getBool(notifiedKey) ?? false)) {
          await _messagingService.sendLocalNotification(
            'Transaction refusée',
            'Une transaction a été refusée.',
          );
          await prefs.setBool(notifiedKey, true);
        }
      }
    });
  }

  // 11. Alerte de sécurité
  StreamSubscription _listenSecurityAlert(String userId, SharedPreferences prefs) {
    // Suppose une collection 'historique_connexions' avec champ 'uid' et 'suspicious' booléen
    return FirebaseFirestore.instance
        .collection('historique_connexions')
        .where('uid', isEqualTo: userId)
        .where('suspicious', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs) {
        final id = doc.id;
        final notifiedKey = 'notified_security_$id';
        if (!(prefs.getBool(notifiedKey) ?? false)) {
          await _messagingService.sendLocalNotification(
            'Alerte de sécurité',
            'Connexion suspecte détectée sur votre compte.',
          );
          await prefs.setBool(notifiedKey, true);
        }
      }
    });
  }

  // 12. Changement de solde soudain
  StreamSubscription _listenSuddenBalanceChange(String userId, SharedPreferences prefs) {
    double? lastSolde;
    return FirebaseFirestore.instance
        .collection('comptesMobiles')
        .doc(userId)
        .snapshots()
        .listen((doc) async {
      final montant = (doc.data()?['montantDisponible'] as num?)?.toDouble() ?? 0.0;
      if (lastSolde != null && lastSolde! > 0) {
        final variation = ((montant - lastSolde!).abs() / lastSolde!) * 100;
        if (variation > 30) {
          await _messagingService.sendLocalNotification(
            'Changement de solde soudain',
            'Votre solde a changé de plus de 30% en une opération.',
          );
        }
      }
      lastSolde = montant;
    });
  }

  // Notification si 75% du budget est dépassé (hebdo, mensuel, annuel)
  StreamSubscription _listenBudget75Percent(String userId, SharedPreferences prefs) {
    return FirebaseFirestore.instance
        .collection('depenses')
        .where('userId', isEqualTo: userId)
        .orderBy('dateCreation', descending: true)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;
      final now = DateTime.now();
      final List<Map<String, dynamic>> budgetsToCheck = [
        {'type': 'hebdomadaire', 'label': 'hebdomadaire'},
        {'type': 'mensuel', 'label': 'mensuel'},
        {'type': 'annuel', 'label': 'annuel'},
      ];
      for (final budgetInfo in budgetsToCheck) {
        final type = budgetInfo['type'];
        final label = budgetInfo['label'];
        // Déterminer la période
        late DateTime periodeDebut;
        late DateTime periodeFin;
        if (type == 'mensuel') {
          periodeDebut = DateTime(now.year, now.month, 1);
          periodeFin = DateTime(now.year, now.month + 1, 0);
        } else if (type == 'annuel') {
          periodeDebut = DateTime(now.year, 1, 1);
          periodeFin = DateTime(now.year, 12, 31);
        } else if (type == 'hebdomadaire') {
          int weekday = now.weekday;
          DateTime monday = now.subtract(Duration(days: weekday - 1));
          DateTime sunday = monday.add(Duration(days: 6));
          periodeDebut = DateTime(monday.year, monday.month, monday.day);
          periodeFin = DateTime(sunday.year, sunday.month, sunday.day);
        }
        // Récupérer le budget courant
        final budgetQuery = await FirebaseFirestore.instance
            .collection('budgets')
            .where('userId', isEqualTo: userId)
            .where('periodeDebut', isEqualTo: periodeDebut)
            .where('periodeFin', isEqualTo: periodeFin)
            .where('type', isEqualTo: type)
            .limit(1)
            .get();
        if (budgetQuery.docs.isEmpty) continue;
        final budget = budgetQuery.docs.first;
        final montantBudget = (budget['montant'] as num?)?.toDouble() ?? 0.0;
        final budgetId = budget.id;
        // Calculer les dépenses de la période
        final depenses = snapshot.docs
            .where((d) {
              final date = (d['dateCreation'] as Timestamp).toDate();
              return date.isAfter(periodeDebut.subtract(const Duration(seconds: 1))) &&
                     date.isBefore(periodeFin.add(const Duration(seconds: 1)));
            })
            .map((d) => (d['montant'] as num?)?.toDouble() ?? 0.0)
            .toList();
        final total = depenses.fold(0.0, (a, b) => a + b);
        final percent = montantBudget > 0 ? (total / montantBudget) * 100 : 0.0;
        final notifiedKey = 'notified_budget75_${budgetId}_$type';
        if (percent >= 75 && percent < 100 && !(prefs.getBool(notifiedKey) ?? false)) {
          String periodeLabel = '';
          String titre = '';
          if (type == 'mensuel') {
            final mois = _moisFrancais(periodeDebut.month);
            periodeLabel = '$mois ${periodeDebut.year}';
            titre = 'Alerte : 75% de votre budget mensuel utilisé !';
          } else if (type == 'annuel') {
            periodeLabel = '${periodeDebut.year}';
            titre = 'Alerte : 75% de votre budget annuel utilisé !';
          } else if (type == 'hebdomadaire') {
            final semaine = _numeroSemaine(periodeDebut);
            periodeLabel = 'Semaine $semaine';
            titre = 'Alerte : 75% de votre budget hebdomadaire utilisé !';
          }
          final message =
              'Vous avez déjà utilisé 75% de votre budget $label ($periodeLabel).\n'
              'Il vous reste seulement 25% pour finir la période.\n'
              'Dépenses : ${total.toStringAsFixed(0)} FCFA / ${montantBudget.toStringAsFixed(0)} FCFA.\n'
              'Pensez à ajuster vos dépenses pour éviter de dépasser votre objectif.\n'
              'Consultez vos statistiques pour mieux piloter votre budget.';
          await _messagingService.sendLocalNotification(
            titre,
            message,
          );
          await prefs.setBool(notifiedKey, true);
        }
        // On ne notifie qu'une seule fois par période/budget
      }
    });
  }

  Future<void> dispose() async {
    for (var sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    _isInitialized = false;
    _currentUserId = null;
  }

  // Fonctions utilitaires pour la personnalisation
  String _moisFrancais(int mois) {
    const moisNoms = [
      '', 'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return moisNoms[mois];
  }

  int _numeroSemaine(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysOffset = firstDayOfYear.weekday - 1;
    final firstMonday = firstDayOfYear.subtract(Duration(days: daysOffset));
    final diff = date.difference(firstMonday).inDays;
    return (diff / 7).ceil() + 1;
  }
} 