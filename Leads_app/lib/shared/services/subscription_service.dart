import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription_plan_model.dart';
import '../models/payment_history_model.dart';

class SubscriptionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Seed the default subscription plans if the collection is empty.
  static Future<void> seedPlans() async {
    try {
      final snap = await _firestore.collection('subscription_plans').get();
      if (snap.docs.isEmpty) {
        final batch = _firestore.batch();
        
        final defaultPlans = [
          {
            'planId': 'free',
            'name': 'Free',
            'freeEmployeeLimit': 5,
            'pricePerEmployee': 0.0,
            'description': 'Free Plan for up to 5 active employees with Google Ads enabled.',
          },
          {
            'planId': 'paid',
            'name': 'Paid',
            'freeEmployeeLimit': 0,
            'pricePerEmployee': 0.50,
            'description': 'Paid Plan for unlimited active employees at USD 0.50 per active employee.',
          },
          {
            'planId': 'starter',
            'name': 'Starter',
            'freeEmployeeLimit': 5,
            'pricePerEmployee': 0.50,
            'description': 'Ideal for small startups. Includes 5 free employees.',
          },
        ];

        for (final plan in defaultPlans) {
          final docRef = _firestore.collection('subscription_plans').doc(plan['planId'] as String);
          batch.set(docRef, plan);
        }
        
        await batch.commit();
      }
    } catch (e) {
      print('Error seeding subscription plans: $e');
    }
  }

  /// Get the list of all subscription plans.
  static Future<List<SubscriptionPlanModel>> getPlans() async {
    await seedPlans();
    final snap = await _firestore.collection('subscription_plans').get();
    return snap.docs.map((doc) => SubscriptionPlanModel.fromMap(doc.data())).toList();
  }

  /// Real-time backend validation check:
  /// Returns whether a company can create or activate an active employee.
  /// If Free Plan and active employee count >= 5, returns false.
  static Future<bool> canAddOrActivateActiveEmployee(String companyId) async {
    if (companyId.isEmpty) return true;

    final companyDoc = await _firestore.collection('companies').doc(companyId).get();
    if (!companyDoc.exists) return true;

    final companyData = companyDoc.data() ?? {};
    final planName = (companyData['planName'] ?? companyData['subscriptionPlan'] ?? 'Free').toString().trim();
    final subStatus = (companyData['subscriptionStatus'] ?? '').toString().trim().toLowerCase();
    
    final isPaid = planName.toLowerCase() == 'paid' ||
        planName.toLowerCase() == 'standard' ||
        planName.toLowerCase() == 'enterprise' ||
        planName.toLowerCase() == 'pro' ||
        planName.toLowerCase() == 'business' ||
        planName.toLowerCase() == 'growth' ||
        subStatus == 'paid';

    if (isPaid) return true;

    // Count current active employees strictly for this company/tenant
    final usersSnap = await _firestore
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .get();

    int activeCount = 0;
    for (final doc in usersSnap.docs) {
      final data = doc.data();
      final role = (data['role'] ?? '').toString();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();

      if (role != 'Company Admin' && role != 'Super Admin' && status == 'active') {
        activeCount++;
      }
    }

    return activeCount < 5;
  }

  /// Recalculate active employees, chargeable count, monthly bill and update the company document immediately.
  static Future<void> recalculateAndSyncSubscription(String companyId) async {
    if (companyId.isEmpty) return;

    // 1. Fetch all users for this company to calculate active employee count
    final usersSnap = await _firestore
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .get();

    int activeCount = 0;
    for (final doc in usersSnap.docs) {
      final data = doc.data();
      final role = data['role'] ?? '';
      final status = (data['status'] ?? '').toString().trim().toLowerCase();

      // Only count active employees (exclude company admins and super admins)
      if (role != 'Company Admin' && role != 'Super Admin' && status == 'active') {
        activeCount++;
      }
    }

    // 2. Fetch the company document to see which plan they are on
    final companyRef = _firestore.collection('companies').doc(companyId);
    final companyDoc = await companyRef.get();
    if (!companyDoc.exists) return;

    final companyData = companyDoc.data() ?? {};
    final planName = (companyData['planName'] ?? companyData['subscriptionPlan'] ?? 'Free').toString().trim();
    final isPaid = planName.toLowerCase() == 'paid' ||
        planName.toLowerCase() == 'standard' ||
        planName.toLowerCase() == 'enterprise' ||
        planName.toLowerCase() == 'pro' ||
        planName.toLowerCase() == 'business' ||
        planName.toLowerCase() == 'growth';

    // 4. Check if cancellation effective date has passed
    final cancelAtPeriodEnd = companyData['cancelAtPeriodEnd'] == true;
    final cancelEffDate = companyData['cancellationEffectiveDate'] != null
        ? (companyData['cancellationEffectiveDate'] as Timestamp).toDate()
        : null;

    bool effectiveIsPaid = isPaid;
    if (cancelAtPeriodEnd && cancelEffDate != null && DateTime.now().isAfter(cancelEffDate)) {
      if (activeCount <= 5) {
        effectiveIsPaid = false;
        await companyRef.update({
          'planName': 'Free',
          'subscriptionPlan': 'Free',
          'subscriptionStatus': 'Active',
          'cancelAtPeriodEnd': false,
          'cancellationEffectiveDate': null,
          'cancellationReason': null,
        });
      } else {
        await companyRef.update({
          'subscriptionStatus': 'Expired',
        });
      }
    }

    final int freeLimit = effectiveIsPaid ? 0 : 5;
    final double pricePerEmployee = effectiveIsPaid ? 0.50 : 0.0;
    final double monthlyBill = effectiveIsPaid ? (activeCount * pricePerEmployee) : 0.0;
    final int chargeableCount = effectiveIsPaid ? activeCount : max(0, activeCount - freeLimit);

    // 5. Update company document
    await companyRef.update({
      'planName': effectiveIsPaid ? 'Paid' : 'Free',
      'subscriptionPlan': effectiveIsPaid ? 'Paid' : 'Free',
      'freeEmployeeLimit': freeLimit,
      'pricePerEmployee': pricePerEmployee,
      'activeEmployees': activeCount,
      'chargeableEmployees': chargeableCount,
      'monthlyBill': monthlyBill,
      'currency': 'USD',
      'updatedAt': Timestamp.now(),
    });
  }

  /// Simulate a successful payment and update company billing status and payment history.
  static Future<void> simulatePayment({
    required String companyId,
    required double amount,
    required String billingMonth,
  }) async {
    final companyRef = _firestore.collection('companies').doc(companyId);
    
    final paymentId = _firestore.collection('companies').doc(companyId).collection('payments').doc().id;
    final refNum = 'TXN-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(900) + 100}';

    final payment = PaymentHistoryModel(
      paymentId: paymentId,
      amount: amount,
      paidDate: DateTime.now(),
      billingMonth: billingMonth,
      status: 'Paid',
      transactionReference: refNum,
    );

    // Write to payments subcollection
    await companyRef.collection('payments').doc(paymentId).set(payment.toMap());

    // Update billingStatus & nextBillingDate on company document
    await companyRef.update({
      'billingStatus': 'Paid',
      'subscriptionStatus': 'Active',
      'nextBillingDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Change subscription plan dynamically and recalculate
  static Future<void> updatePlan(String companyId, String newPlanName) async {
    final companyRef = _firestore.collection('companies').doc(companyId);
    final targetPlan = newPlanName.trim().toLowerCase() == 'paid' ? 'Paid' : 'Free';
    
    final nextBilling = DateTime.now().add(const Duration(days: 30));

    // Set planName and subscriptionPlan fields
    await companyRef.update({
      'planName': targetPlan,
      'subscriptionPlan': targetPlan,
      'billingStatus': 'Active',
      'subscriptionStatus': 'Active',
      'cancelAtPeriodEnd': false,
      'cancellationEffectiveDate': null,
      'cancellationReason': null,
      'nextBillingDate': targetPlan == 'Paid' ? Timestamp.fromDate(nextBilling) : null,
      'updatedAt': Timestamp.now(),
    });

    // Recalculate metrics immediately
    await recalculateAndSyncSubscription(companyId);
  }

  /// Request cancellation of Paid Subscription.
  /// Keeps Paid Plan features active until current billing period ends (nextBillingDate).
  static Future<void> requestCancellation(String companyId, {String? reason}) async {
    final companyRef = _firestore.collection('companies').doc(companyId);
    final companyDoc = await companyRef.get();
    if (!companyDoc.exists) return;

    final data = companyDoc.data() ?? {};
    final nextBilling = data['nextBillingDate'] != null
        ? (data['nextBillingDate'] as Timestamp).toDate()
        : DateTime.now().add(const Duration(days: 30));

    await companyRef.update({
      'subscriptionStatus': 'Cancellation Pending',
      'cancelAtPeriodEnd': true,
      'cancellationEffectiveDate': Timestamp.fromDate(nextBilling),
      'cancellationReason': reason ?? 'User requested cancellation',
      'updatedAt': Timestamp.now(),
    });
  }

  /// Resume / Keep Paid Subscription when cancellation is pending.
  static Future<void> resumeSubscription(String companyId) async {
    final companyRef = _firestore.collection('companies').doc(companyId);
    await companyRef.update({
      'subscriptionStatus': 'Active',
      'cancelAtPeriodEnd': false,
      'cancellationEffectiveDate': null,
      'cancellationReason': null,
      'updatedAt': Timestamp.now(),
    });
  }
}
