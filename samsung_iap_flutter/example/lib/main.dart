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
  List<OwnedProduct>? _owned;
  String? _purchase;
  bool _buying = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _error = null);
    try {
      await action();
    } on SamsungIapException catch (e) {
      setState(() => _error = '${e.kind.name}: ${e.message}');
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
    setState(() => _products = products);
  });

  Future<void> _getOwnedProducts() => _run(() async {
    final owned = await _iap.getOwnedProducts();
    setState(() => _owned = owned);
  });

  Future<void> _buy(SamsungProduct product) => _run(() async {
    setState(() {
      _purchase = null;
      _buying = true;
    });
    try {
      final purchase = await _iap.purchase(product.id);
      setState(
        () => _purchase =
            'Bought ${purchase.productId}: purchase ${purchase.purchaseId}, '
            'order ${purchase.orderId}',
      );
    } on SamsungIapException catch (e) {
      if (e.kind != SamsungIapErrorKind.userCanceled) rethrow;
      setState(() => _purchase = 'Cancelled');
    } finally {
      setState(() => _buying = false);
    }
  });

  @override
  Widget build(BuildContext context) {
    final products = _products;
    final owned = _owned;
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
          if (_error case final error?)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (products != null) Text('${products.length} products'),
          for (final product in products ?? const <SamsungProduct>[])
            ListTile(
              title: Text(product.name),
              subtitle: Text(_describe(product)),
              trailing: FilledButton.tonal(
                onPressed: _buying ? null : () => _buy(product),
                child: Text('Buy ${product.formattedPrice}'),
              ),
            ),
          if (owned != null) Text('${owned.length} owned products'),
          for (final product in owned ?? const <OwnedProduct>[])
            ListTile(
              title: Text(product.name),
              subtitle: Text(_describeOwned(product)),
              trailing: Text(product.acknowledgedStatus.name),
            ),
        ],
      ),
    );
  }

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
    if (product.subscriptionEndDate case final end?) 'until $end',
    if (product.priceChange case final change?)
      'price change to ${change.newFormattedPrice}',
  ].join(' · ');
}
