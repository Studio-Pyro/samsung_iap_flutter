import 'package:material_ui/material_ui.dart';
import 'package:samsung_iap_flutter/samsung_iap_flutter.dart';

/// Product IDs to fetch, comma-separated. Empty fetches every product.
const productIdsDefine = String.fromEnvironment('SAMSUNG_IAP_PRODUCT_IDS');

/// [productIdsDefine] as a list.
List<String> get productIds => idsFrom(productIdsDefine);

/// Splits a comma-separated `--dart-define` into trimmed, non-empty IDs.
List<String> idsFrom(String define) => [
  for (final id in define.split(','))
    if (id.trim().isNotEmpty) id.trim(),
];

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  const new({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _iap = SamsungIap();

  OperationMode _mode = OperationMode.test;
  bool _initialized = false;
  GalaxyStoreStatus? _status;
  List<SamsungProduct>? _products;
  Map<String, PromotionPricing> _pricing = const {};
  List<OwnedProduct>? _owned;
  String? _purchase;
  bool _buying = false;
  List<String> _ackResults = const [];
  String? _planFrom;
  String? _planTo;
  ProrationMode _proration = ProrationMode.instantProratedDate;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _error = null);
    try {
      await action();
    } on SamsungIapException catch (e) {
      setState(
        () => _error =
            '${e.kind.name} (code ${e.code}, detail ${e.detailCode}): '
            '${e.message}',
      );
    }
  }

  Future<void> _initialize() => _run(() async {
    await _iap.initialize(mode: _mode);
    final status = await _iap.getGalaxyStoreStatus();
    setState(() {
      _initialized = true;
      _status = status;
    });
  });

  Future<void> _getProducts() => _run(() async {
    final products = await _iap.getProducts(productIds);
    setState(() {
      _products = products;
      _pricing = const {};
    });
    final subscriptionIds = [
      for (final product in products)
        if (product.type == SamsungProductType.subscription) product.id,
    ];
    if (subscriptionIds.isEmpty) return;
    final eligibility = await _iap.getPromotionEligibility(subscriptionIds);
    setState(
      () => _pricing = {for (final e in eligibility) e.productId: e.pricing},
    );
  });

  Future<void> _getOwnedProducts() => _run(() async {
    final owned = await _iap.getOwnedProducts();
    setState(() => _owned = owned);
  });

  /// Runs [call], which shows Samsung's payment UI, and shows its outcome.
  Future<void> _pay(String verb, Future<SamsungPurchase> Function() call) =>
      _run(() async {
        setState(() {
          _purchase = null;
          _buying = true;
        });
        try {
          final purchase = await call();
          setState(
            () => _purchase =
                '$verb ${purchase.productId}: purchase ${purchase.purchaseId}, '
                'order ${purchase.orderId}',
          );
        } on SamsungIapException catch (e) {
          if (e.kind != SamsungIapErrorKind.userCanceled) rethrow;
          setState(() => _purchase = 'Cancelled');
        } finally {
          setState(() => _buying = false);
        }
      });

  Future<void> _buy(SamsungProduct product) =>
      _pay('Bought', () => _iap.purchase(product.id));

  Future<void> _changePlan(String from, String to) => _pay(
    'Changed to',
    () => _iap.changeSubscriptionPlan(
      fromProductId: from,
      toProductId: to,
      prorationMode: _proration,
    ),
  );

  /// Runs [call], `consume` or `acknowledge`, on [product] and shows each
  /// result, then reloads the owned products to show the change.
  Future<void> _ackAndReload(
    String action,
    Future<List<PurchaseAckResult>> Function(List<String>) call,
    OwnedProduct product,
  ) => _run(() async {
    setState(() => _ackResults = const []);
    final results = await call([product.purchaseId]);
    setState(
      () => _ackResults = [
        for (final r in results)
          '$action ${r.purchaseId}: ${r.status.name} (${r.statusCode})',
      ],
    );
    final owned = await _iap.getOwnedProducts();
    setState(() => _owned = owned);
  });

  @override
  Widget build(BuildContext context) {
    final products = _products;
    final owned = _owned;
    final subscriptions = [
      for (final product in products ?? const <SamsungProduct>[])
        if (product.type == SamsungProductType.subscription) product.id,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Samsung IAP Example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<OperationMode>(
            segments: [
              for (final mode in OperationMode.values)
                ButtonSegment(value: mode, label: Text(mode.name)),
            ],
            selected: {_mode},
            onSelectionChanged: (selected) =>
                setState(() => _mode = selected.single),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _initialize, child: const Text('Initialize')),
          if (_status case final status?) Text('Galaxy Store: ${status.name}'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _initialized ? _getProducts : null,
            child: const Text('Get products'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _initialized ? _getOwnedProducts : null,
            child: const Text('Get owned products'),
          ),
          if (_purchase case final purchase?) Text(purchase),
          for (final result in _ackResults) Text(result),
          if (_error case final error?)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (products != null) Text('${products.length} products'),
          for (final product in products ?? const <SamsungProduct>[])
            ListTile(
              title: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(product.name),
                  if (_offer(_pricing[product.id]) case final offer?)
                    Chip(
                      label: Text(offer),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              subtitle: Text(_describe(product)),
              trailing: FilledButton.tonal(
                onPressed: _buying ? null : () => _buy(product),
                child: Text('Buy ${product.formattedPrice}'),
              ),
            ),
          if (subscriptions.isNotEmpty) _planChanger(subscriptions),
          if (owned != null) Text('${owned.length} owned products'),
          for (final product in owned ?? const <OwnedProduct>[])
            ListTile(
              title: Text(product.name),
              subtitle: Text(_describeOwned(product)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () =>
                        _ackAndReload('Consume', _iap.consume, product),
                    child: const Text('Consume'),
                  ),
                  TextButton(
                    onPressed: () =>
                        _ackAndReload('Acknowledge', _iap.acknowledge, product),
                    child: const Text('Acknowledge'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Picks two subscription tiers and a proration mode, and changes the plan.
  Widget _planChanger(List<String> subscriptions) {
    final from = subscriptions.contains(_planFrom) ? _planFrom : null;
    final to = subscriptions.contains(_planTo) ? _planTo : null;
    DropdownButton<String> tier(
      String hint,
      String? value,
      void Function(String?) onChanged,
    ) => DropdownButton(
      hint: Text(hint),
      value: value,
      items: [
        for (final id in subscriptions)
          DropdownMenuItem(value: id, child: Text(id)),
      ],
      onChanged: onChanged,
    );
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        tier('From', from, (id) => setState(() => _planFrom = id)),
        tier('To', to, (id) => setState(() => _planTo = id)),
        DropdownButton(
          value: _proration,
          items: [
            for (final mode in ProrationMode.values)
              DropdownMenuItem(value: mode, child: Text(mode.name)),
          ],
          onChanged: (mode) => setState(() => _proration = mode!),
        ),
        FilledButton.tonal(
          onPressed: from == null || to == null || _buying
              ? null
              : () => _changePlan(from, to),
          child: const Text('Change plan'),
        ),
      ],
    );
  }

  static String? _offer(PromotionPricing? pricing) => switch (pricing) {
    PromotionPricing.freeTrial => 'Free trial available',
    PromotionPricing.tieredPrice => 'Intro price',
    PromotionPricing.regularPrice || PromotionPricing.unknown || null => null,
  };

  static String _describe(SamsungProduct product) => [
    product.id,
    product.type.name,
    if (product.subscriptionPeriod case final period?)
      'every ${period.count} ${period.unit.name}',
    if (product.freeTrialDays case final days?) '$days-day trial',
    if (product.introductoryOffer case final offer?)
      '${offer.formattedPrice} for ${offer.cycles} periods',
  ].join(' · ');

  static String _describeOwned(OwnedProduct product) => [
    product.productId,
    product.purchaseId,
    product.acknowledgedStatus.name,
    if (product.subscriptionEndDate case final end?) 'until $end',
    if (product.priceChange case final change?)
      'price change to ${change.newFormattedPrice}',
  ].join(' · ');
}
