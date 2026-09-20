import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

import 'account_service.dart';
import 'app_theme.dart';
import 'auth_service.dart';
import 'basket_service.dart';
import 'checkout_service.dart';
import 'preorder.dart';
import 'product_service.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pinpins Kakanin',
    debugShowCheckedModeBanner: false,
    theme: pinpinsTheme(),
    home: AuthGate(),
  );
}

class AuthGate extends StatefulWidget {
  AuthGate({ShopifyAuthService? auth, BasketService? basket, super.key})
    : auth = auth ?? ShopifyAuthService(),
      basket = basket ?? BasketService();

  final ShopifyAuthService auth;
  final BasketService basket;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<AuthSession?> _session;

  @override
  void initState() {
    super.initState();
    _session = _restoreSession();
  }

  Future<AuthSession?> _restoreSession() async {
    try {
      return await widget.auth.restoreSession();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AuthSession?>(
    future: _session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return ProductsPage(
        key: ValueKey(snapshot.data != null),
        auth: widget.auth,
        basketService: widget.basket,
        session: snapshot.data,
        onSignedIn: (session) => setState(() {
          _session = Future.value(session);
        }),
        onSignedOut: () => setState(() {
          _session = widget.basket.saveCartId(null).then((_) => null);
        }),
      );
    },
  );
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({
    required this.auth,
    required this.basketService,
    required this.session,
    required this.onSignedIn,
    required this.onSignedOut,
    super.key,
  });

  final ShopifyAuthService auth;
  final BasketService basketService;
  final AuthSession? session;
  final ValueChanged<AuthSession> onSignedIn;
  final VoidCallback onSignedOut;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late Future<ProductBatch> _products;
  Map<String, int> _basket = {};
  Map<String, Map<String, String>> _attributes = {};
  bool _authBusy = false;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _products = _fetchProducts();
    _restoreBasket();
  }

  Future<ProductBatch> _fetchProducts({String? after}) =>
      ProductService.getProductBatch(after: after);

  Future<void> _restoreBasket() async {
    final values = await (
      widget.basketService.load(),
      widget.basketService.loadAttributes(),
    ).wait;
    if (mounted) {
      setState(() {
        _basket = values.$1;
        _attributes = values.$2;
      });
    }
  }

  Future<void> _reload() async {
    try {
      final products = await _fetchProducts();
      if (mounted) setState(() => _products = Future.value(products));
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final current = await _products;
      if (!current.hasNextPage) return;
      final next = await _fetchProducts(after: current.endCursor);
      if (mounted) {
        setState(() {
          _products = Future.value(
            ProductBatch(
              products: [...current.products, ...next.products],
              hasNextPage: next.hasNextPage,
              endCursor: next.endCursor,
            ),
          );
        });
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _login() async {
    setState(() => _authBusy = true);
    try {
      widget.onSignedIn(await widget.auth.login());
    } on FlutterAppAuthUserCancelledException {
      // Closing Shopify sign-in keeps the public store available.
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _authBusy = true);
    try {
      await widget.auth.logout();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      widget.onSignedOut();
    }
  }

  Future<void> _addToBasket(
    ({ProductVariant variant, int quantity, Map<String, String> attributes})
    addition,
  ) async {
    final basket = {..._basket};
    basket[addition.variant.id] =
        ((basket[addition.variant.id] ?? 0) + addition.quantity).clamp(1, 99);
    final attributes = {
      ..._attributes,
      addition.variant.id: addition.attributes,
    };
    await (
      widget.basketService.save(basket),
      widget.basketService.saveAttributes(attributes),
    ).wait;
    if (mounted) {
      setState(() {
        _basket = basket;
        _attributes = attributes;
      });
    }
  }

  Future<void> _openProduct(Product product) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProductDetailsPage(handle: product.handle, onAdd: _addToBasket),
      ),
    );
  }

  Future<void> _openAccount() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (accountContext) => Scaffold(
          appBar: AppBar(title: const Text('Account')),
          body: widget.session == null
              ? StateSurface(
                  message: 'Sign in to view your account',
                  icon: Icons.account_circle_outlined,
                  action: FilledButton(
                    onPressed: () {
                      Navigator.pop(accountContext);
                      _login();
                    },
                    child: const Text('Sign in'),
                  ),
                )
              : AccountPage(
                  auth: widget.auth,
                  signOut: () {
                    Navigator.pop(accountContext);
                    _logout();
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _openBasket() async {
    try {
      final products = (await _products).products;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BasketPage(
            products: products,
            initialBasket: _basket,
            initialAttributes: _attributes,
            basketService: widget.basketService,
            auth: widget.session == null ? null : widget.auth,
          ),
        ),
      );
      await _restoreBasket();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error.toString())));

  Widget _catalogBody() => FutureBuilder<ProductBatch>(
    future: _products,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return StateSurface(
          message: 'Could not load products\n${snapshot.error}',
          icon: Icons.cloud_off_outlined,
          action: OutlinedButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        );
      }
      final batch = snapshot.data!;
      if (batch.products.isEmpty) {
        return const StateSurface(
          message: 'No products found',
          icon: Icons.rice_bowl_outlined,
        );
      }
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
          children: [
            const _Hero(),
            const SizedBox(height: 22),
            const Eyebrow(
              'Fresh from the steamer',
              icon: Icons.rice_bowl_outlined,
            ),
            const SizedBox(height: 8),
            Text(
              'The four we are known for',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'The four the family has made since the beginning. Every one comes in five sizes from a tub for two to a bilao that feeds a fiesta.',
            ),
            const SizedBox(height: 18),
            for (final product in batch.products) ...[
              _ProductCard(
                product: product,
                onOpen: () => _openProduct(product),
              ),
              const SizedBox(height: 14),
            ],
            if (batch.hasNextPage)
              OutlinedButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: Text(_loadingMore ? 'Loading…' : 'Load more products'),
              ),
            const SizedBox(height: 20),
            const _OrderingSteps(),
            const SizedBox(height: 14),
            const _StoryAndFaq(),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pinpins Kakanin'),
      actions: [
        IconButton(
          onPressed: _authBusy ? null : _openAccount,
          tooltip: 'Account',
          icon: const Icon(Icons.account_circle_outlined),
        ),
      ],
    ),
    body: _catalogBody(),
    floatingActionButton: FloatingActionButton(
      onPressed: _openBasket,
      tooltip: 'Basket',
      child: Badge(
        isLabelVisible: _basket.isNotEmpty,
        label: Text('${_basket.values.fold(0, (sum, value) => sum + value)}'),
        child: const Icon(Icons.shopping_basket_outlined),
      ),
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [PinpinsColors.toastedCream, PinpinsColors.paper],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Home-made kakanin, cooked for the date you choose',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 10),
        const Text(
          'Twenty-five years in one kitchen in Imus, Cavite. Tell us which kakanin you want and the day you want it, and the family cooks your tray for that morning.',
        ),
      ],
    ),
  );
}

class _FactChip extends StatelessWidget {
  const _FactChip(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 17, color: PinpinsColors.deepLeaf),
    label: Text(label),
    backgroundColor: PinpinsColors.paper,
    side: const BorderSide(color: PinpinsColors.border),
    labelStyle: const TextStyle(
      color: PinpinsColors.brown,
      fontSize: 12,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onOpen});
  final Product product;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final available = product.variants
        .where((variant) => variant.availableForSale)
        .toList();
    final from = available.isEmpty
        ? null
        : available.reduce(
            (a, b) =>
                double.parse(a.price.amount) <= double.parse(b.price.amount)
                ? a
                : b,
          );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: product.imageUrl == null
                        ? const ColoredBox(
                            color: Color(0xFFFFF7E8),
                            child: Icon(Icons.image_outlined, size: 50),
                          )
                        : Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            semanticLabel: product.title,
                          ),
                  ),
                  const Positioned(
                    top: 12,
                    left: 12,
                    child: Chip(
                      avatar: Icon(Icons.eco_outlined, size: 15),
                      label: Text('MADE TO ORDER'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.description.isEmpty
                        ? productStory(product.handle)
                        : product.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (available.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final variant in available)
                          Chip(
                            label: Text(sizeGuide(variant.label).label),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          from == null
                              ? 'Unavailable'
                              : 'From ${from.price.formatted} • ${available.length} ${available.length == 1 ? 'size' : 'sizes'}',
                          style: const TextStyle(
                            color: PinpinsColors.brown,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: available.isEmpty ? null : onOpen,
                        child: const Text('Pre-order'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderingSteps extends StatelessWidget {
  const _OrderingSteps();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: PinpinsColors.deepLeaf,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Four simple steps', icon: Icons.eco_outlined),
        const SizedBox(height: 8),
        Text(
          'How pre-ordering works',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: PinpinsColors.cream),
        ),
        const SizedBox(height: 12),
        for (final step in const [
          ('01', Icons.rice_bowl_outlined, 'Pick your kakanin'),
          ('02', Icons.calendar_month_outlined, 'Name the day'),
          ('03', Icons.wallet_outlined, 'Check out'),
          ('04', Icons.local_shipping_outlined, 'Collect or receive'),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: PinpinsColors.gold,
                  foregroundColor: PinpinsColors.brown,
                  child: Icon(step.$2),
                ),
                const SizedBox(width: 10),
                Text(
                  '${step.$1}  ${step.$3}',
                  style: const TextStyle(
                    color: PinpinsColors.cream,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _StoryAndFaq extends StatelessWidget {
  const _StoryAndFaq();
  @override
  Widget build(BuildContext context) => const PaperCard(
    child: Column(
      children: [
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('One kitchen in Imus, twenty-five years on'),
          children: [
            Text(
              'No branches, no franchise, no second location — just the Ramirez family and the same four kakanin. Customers found us by word of mouth; this app is the old order notebook without the chance of losing a page.',
            ),
          ],
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('The five things people ask first'),
          children: [
            ListTile(
              title: Text('How do I pay?'),
              subtitle: Text(
                'Choose PayMongo, Cash on Pickup, or Credit Card at Shopify checkout.',
              ),
            ),
            ListTile(
              title: Text('Is there a minimum order?'),
              subtitle: Text('None. One tub is a real order.'),
            ),
            ListTile(
              title: Text('Do you deliver?'),
              subtitle: Text(
                'We book Lalamove wherever it has coverage; its fare is separate.',
              ),
            ),
            ListTile(
              title: Text('How far ahead?'),
              subtitle: Text(
                'Tomorrow for most orders; seven days for the three busiest dates.',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({
    required this.handle,
    required this.onAdd,
    super.key,
  });
  final String handle;
  final Future<void> Function(
    ({ProductVariant variant, int quantity, Map<String, String> attributes}),
  )
  onAdd;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late final Future<Product> _product = ProductService.getProduct(
    widget.handle,
  );
  final _request = TextEditingController();
  final _scrollController = ScrollController();
  final _submitKey = GlobalKey();
  ProductVariant? _selected;
  DateTime _date = firstAvailableDate();
  int _quantity = 1;
  bool _adding = false;
  bool _showSticky = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncSticky);
  }

  void _syncSticky() {
    final box = _submitKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final show = box.localToGlobal(Offset.zero).dy < kToolbarHeight;
    if (show != _showSticky) setState(() => _showSticky = show);
  }

  @override
  void dispose() {
    _request.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: dateOnly(DateTime.now()).add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    final error = preorderDateError(picked);
    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }
    setState(() => _date = picked);
  }

  Future<void> _add() async {
    final variant = _selected;
    if (variant == null) return;
    final error = preorderDateError(_date);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _adding = true);
    await widget.onAdd((
      variant: variant,
      quantity: _quantity,
      attributes: {
        'Preferred Date': isoDate(_date),
        if (_request.text.trim().isNotEmpty)
          'Special request': _request.text.trim(),
      },
    ));
    if (mounted) {
      setState(() => _adding = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to basket')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pre-order')),
    body: FutureBuilder<Product>(
      future: _product,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return StateSurface(
            message: 'Could not load product\n${snapshot.error}',
            icon: Icons.cloud_off_outlined,
          );
        }
        final product = snapshot.data!;
        _selected ??= product.variants
            .where((variant) => variant.availableForSale)
            .firstOrNull;
        final selected = _selected;
        final guide = selected == null ? null : sizeGuide(selected.label);
        final image = selected?.imageUrl ?? product.imageUrl;
        final total = selected == null
            ? ''
            : '${selected.price.currencyCode} ${(double.parse(selected.price.amount) * _quantity).toStringAsFixed(2)}';
        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 120),
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: image == null
                          ? const Icon(Icons.image_outlined, size: 64)
                          : AnimatedSwitcher(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                              child: Image.network(
                                image,
                                key: ValueKey(image),
                                fit: BoxFit.cover,
                                semanticLabel:
                                    '${product.title}${guide == null ? '' : ' — ${guide.label}'}',
                              ),
                            ),
                    ),
                    const Positioned(
                      top: 14,
                      left: 14,
                      child: Chip(
                        avatar: Icon(
                          Icons.eco_outlined,
                          size: 15,
                          color: PinpinsColors.cream,
                        ),
                        label: Text('MADE TO ORDER'),
                        backgroundColor: PinpinsColors.deepLeaf,
                        labelStyle: TextStyle(
                          color: PinpinsColors.cream,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _FactChip(Icons.local_fire_department_outlined, 'Cooked fresh'),
                _FactChip(Icons.family_restroom, 'Family-made'),
                _FactChip(Icons.rice_bowl_outlined, 'No minimum'),
              ],
            ),
            const SizedBox(height: 16),
            const Eyebrow('Made to order'),
            Text(
              product.title,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            if (selected != null)
              Text(
                '${selected.price.formatted} per ${guide!.label}',
                style: const TextStyle(
                  color: PinpinsColors.brown,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              product.description.isEmpty
                  ? productStory(product.handle)
                  : product.description,
            ),
            const SizedBox(height: 18),
            _StepCard(
              number: '1',
              title: 'Choose your size',
              hint: 'Pick the tray that suits your table.',
              child: Column(
                children: [
                  for (final variant in product.variants)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SizeOption(
                        variant: variant,
                        selected: variant.id == selected?.id,
                        onTap: variant.availableForSale
                            ? () => setState(() => _selected = variant)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _StepCard(
              number: '2',
              title: 'Date you need it',
              hint: 'The earliest is tomorrow.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(formatDate(_date)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    children: [
                      for (final shortcut in const [
                        (1, 'Tomorrow'),
                        (3, 'In 3 days'),
                        (7, 'In 7 days'),
                      ])
                        ActionChip(
                          label: Text(shortcut.$2),
                          onPressed: () {
                            final value = dateOnly(
                              DateTime.now(),
                            ).add(Duration(days: shortcut.$1));
                            final error = preorderDateError(value);
                            if (error == null) {
                              setState(() => _date = value);
                            } else {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(error)));
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'November 1, December 24, and December 31 require seven days’ notice.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _StepCard(
              number: '3',
              title: 'Quantity and review',
              hint: 'Check the details, then add this to your basket.',
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Quantity',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      _QuantityStepper(
                        quantity: _quantity,
                        minimum: 1,
                        onChanged: (value) => setState(() => _quantity = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _request,
                    maxLength: 500,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Special request (optional)',
                      hintText: 'Less sweet, or sliced into 24 pieces',
                    ),
                  ),
                  const SizedBox(height: 10),
                  PaperCard(
                    child: Column(
                      children: [
                        _SummaryRow('Size', guide?.label ?? '—'),
                        _SummaryRow('Date', formatDate(_date)),
                        _SummaryRow('Order total', total, strong: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _InfoRow(
                    Icons.local_shipping_outlined,
                    'Pickup or delivery',
                    'Choose pickup in Imus or Lalamove at checkout. Delivery fare is separate.',
                  ),
                  const _InfoRow(
                    Icons.wallet_outlined,
                    'Payment',
                    'Choose PayMongo, Cash on Pickup, or Credit Card at checkout.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: _submitKey,
                      onPressed: selected == null || _adding ? null : _add,
                      icon: const Icon(Icons.shopping_basket_outlined),
                      label: Text(
                        _adding ? 'Adding…' : 'Add to pre-order basket',
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Nothing is charged yet.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _ProductAccordions(),
          ],
        );
      },
    ),
    bottomNavigationBar: FutureBuilder<Product>(
      future: _product,
      builder: (_, snapshot) =>
          snapshot.hasData && _selected != null && _showSticky
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  color: PinpinsColors.cream,
                  border: Border(top: BorderSide(color: PinpinsColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${snapshot.data!.title}\n${_selected!.price.formatted}',
                        maxLines: 2,
                        style: const TextStyle(
                          color: PinpinsColors.brown,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: _adding ? null : _add,
                      child: const Text('Add to basket'),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    ),
  );
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.hint,
    required this.child,
  });
  final String number;
  final String title;
  final String hint;
  final Widget child;
  @override
  Widget build(BuildContext context) => PaperCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: PinpinsColors.deepLeaf,
              foregroundColor: PinpinsColors.cream,
              child: Text(number),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  Text(hint, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _SizeOption extends StatelessWidget {
  const _SizeOption({
    required this.variant,
    required this.selected,
    required this.onTap,
  });
  final ProductVariant variant;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final guide = sizeGuide(variant.label);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? const Color(0x1A66734A) : PinpinsColors.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? PinpinsColors.deepLeaf : PinpinsColors.border,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: onTap == null
                    ? PinpinsColors.ink.withValues(alpha: .45)
                    : PinpinsColors.deepLeaf,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${guide.label} • ${variant.price.formatted}',
                      style: const TextStyle(
                        color: PinpinsColors.brown,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      [
                        guide.serves,
                        guide.dimensions,
                      ].where((text) => text.isNotEmpty).join(' • '),
                    ),
                    if (guide.occasion.isNotEmpty)
                      Text(
                        guide.occasion,
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (!variant.availableForSale) const Text('Unavailable'),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.minimum,
    required this.onChanged,
  });
  final int quantity;
  final int minimum;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: PinpinsColors.border, width: 2),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: quantity > minimum ? () => onChanged(quantity - 1) : null,
          tooltip: quantity == 1 && minimum == 0 ? 'Remove' : 'Decrease',
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          onPressed: quantity < 99 ? () => onChanged(quantity + 1) : null,
          tooltip: 'Increase',
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(
            color: strong ? PinpinsColors.deepLeaf : PinpinsColors.brown,
            fontSize: strong ? 17 : 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: PinpinsColors.brown),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
    subtitle: Text(text),
  );
}

class _ProductAccordions extends StatelessWidget {
  const _ProductAccordions();
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      ExpansionTile(
        title: Text('Ingredients and allergens'),
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Our kakanin is made from rice flour, coconut milk, and sugar, in a kitchen that also handles eggs and dairy. Message us before ordering about allergies.',
            ),
          ),
        ],
      ),
      ExpansionTile(
        title: Text('Size guide'),
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Tub: 1–2 • X-Small: 4–6 • Small: 8–10 • Medium: 15–20 • Large: 25–30 pax',
            ),
          ),
        ],
      ),
      ExpansionTile(
        title: Text('Pickup and delivery'),
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Collect at 137 Malagasang 2-A, Imus, Cavite, or choose Lalamove at checkout.',
            ),
          ),
        ],
      ),
      ExpansionTile(
        title: Text('Payment'),
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'We accept PayMongo, Cash on Pickup, and Credit Card. Shopify checkout remains authoritative.',
            ),
          ),
        ],
      ),
    ],
  );
}

class BasketPage extends StatefulWidget {
  const BasketPage({
    required this.products,
    required this.initialBasket,
    required this.basketService,
    this.initialAttributes = const {},
    this.auth,
    super.key,
  });
  final List<Product> products;
  final Map<String, int> initialBasket;
  final Map<String, Map<String, String>> initialAttributes;
  final BasketService basketService;
  final ShopifyAuthService? auth;

  @override
  State<BasketPage> createState() => _BasketPageState();
}

class _BasketPageState extends State<BasketPage> {
  late Map<String, int> _basket = {...widget.initialBasket};
  late Map<String, Map<String, String>> _attributes = {
    for (final entry in widget.initialAttributes.entries)
      entry.key: {...entry.value},
  };
  ShopifyCart? _cart;
  bool _checkingOut = false;
  bool _syncing = false;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialSync());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _initialSync() async {
    if (_basket.isEmpty) return;
    final defaultDate = isoDate(firstAvailableDate());
    for (final id in _basket.keys) {
      _attributes[id] = {'Preferred Date': defaultDate, ...?_attributes[id]};
    }
    await widget.basketService.saveAttributes(_attributes);
    try {
      await _syncCart();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<ShopifyCart> _syncCart() async {
    setState(() => _syncing = true);
    try {
      final cart = await ProductService.syncCart(
        _basket,
        attributes: _attributes,
        cartId: await widget.basketService.loadCartId(),
        customerAccessToken: await widget.auth?.accessToken(),
      );
      await widget.basketService.saveCartId(cart.id);
      if (_note.text.isEmpty && cart.note.isNotEmpty) {
        _note.text = cart.note;
      }
      for (final line in cart.lines) {
        _attributes[line.variantId] = {
          ...line.attributes,
          ...?_attributes[line.variantId],
        };
      }
      await widget.basketService.saveAttributes(_attributes);
      if (mounted) setState(() => _cart = cart);
      await CheckoutKit.preload(cart.checkoutUrl);
      return cart;
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error.toString())));

  List<
    ({
      String variantId,
      int quantity,
      Product? product,
      ProductVariant? variant,
      ShopifyCartLine? cartLine,
    })
  >
  get _items {
    final variants = <String, (Product, ProductVariant)>{};
    for (final product in widget.products) {
      for (final variant in product.variants) {
        variants[variant.id] = (product, variant);
      }
    }
    final cartLines = {
      for (final line in _cart?.lines ?? <ShopifyCartLine>[])
        line.variantId: line,
    };
    return _basket.entries.map((entry) {
      final match = variants[entry.key];
      return (
        variantId: entry.key,
        quantity: entry.value,
        product: match?.$1,
        variant: match?.$2,
        cartLine: cartLines[entry.key],
      );
    }).toList();
  }

  Future<void> _saveLocal() => (
    widget.basketService.save(_basket),
    widget.basketService.saveAttributes(_attributes),
  ).wait;

  Future<void> _setQuantity(String id, int quantity) async {
    if (quantity < 1) {
      _basket.remove(id);
      _attributes.remove(id);
    } else {
      _basket[id] = quantity.clamp(1, 99);
    }
    await _saveLocal();
    if (mounted) setState(() {});
    if (_basket.isEmpty) {
      await widget.basketService.saveCartId(null);
      setState(() => _cart = null);
      return;
    }
    try {
      await _syncCart();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _editDate(String id) async {
    final current =
        DateTime.tryParse(_attributes[id]?['Preferred Date'] ?? '') ??
        firstAvailableDate();
    final value = await showDatePicker(
      context: context,
      initialDate: current.isAfter(DateTime.now())
          ? current
          : firstAvailableDate(),
      firstDate: dateOnly(DateTime.now()).add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (value == null) return;
    final error = preorderDateError(value);
    if (error != null) {
      if (mounted) _showError(error);
      return;
    }
    _attributes[id] = {...?_attributes[id], 'Preferred Date': isoDate(value)};
    await _saveLocal();
    if (mounted) setState(() {});
    try {
      await _syncCart();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _checkout() async {
    setState(() => _checkingOut = true);
    try {
      var cart = _cart ?? await _syncCart();
      if (_note.text.trim().isNotEmpty && _note.text.trim() != cart.note) {
        cart = await ProductService.updateCartNote(cart.id, _note.text);
        if (mounted) setState(() => _cart = cart);
      }
      final status = await CheckoutKit.present(cart.checkoutUrl);
      if (status == CheckoutStatus.completed) {
        await (
          widget.basketService.save({}),
          widget.basketService.saveAttributes({}),
          widget.basketService.saveCartId(null),
        ).wait;
        if (mounted) {
          setState(() {
            _basket = {};
            _attributes = {};
            _cart = null;
          });
        }
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Your basket')),
      body: items.isEmpty
          ? StateSurface(
              message: 'Your basket is empty',
              icon: Icons.shopping_basket_outlined,
              action: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to the kakanin'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: [
                const Eyebrow(
                  'Made to order',
                  icon: Icons.shopping_basket_outlined,
                ),
                Text(
                  'Your pre-order basket',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                Text(
                  '${_basket.values.fold(0, (sum, value) => sum + value)} items ready to reserve',
                ),
                const SizedBox(height: 16),
                for (final item in items) ...[
                  _BasketItemCard(
                    title:
                        item.cartLine?.productTitle ??
                        item.product?.title ??
                        'Unavailable item',
                    variant:
                        item.cartLine?.variantTitle ??
                        item.variant?.label ??
                        '',
                    price: item.cartLine?.price ?? item.variant?.price,
                    imageUrl:
                        item.cartLine?.imageUrl ??
                        item.variant?.imageUrl ??
                        item.product?.imageUrl,
                    quantity: item.quantity,
                    attributes: item.cartLine?.attributes.isNotEmpty == true
                        ? item.cartLine!.attributes
                        : (_attributes[item.variantId] ?? const {}),
                    busy: _syncing,
                    onQuantity: (value) => _setQuantity(item.variantId, value),
                    onDate: () => _editDate(item.variantId),
                    onRemove: () => _setQuantity(item.variantId, 0),
                  ),
                  const SizedBox(height: 12),
                ],
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Back to the kakanin'),
                ),
                const SizedBox(height: 12),
                PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Order summary',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _note,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes for the family (optional)',
                          hintText: 'A landmark for the rider, or pickup time',
                        ),
                      ),
                      const Divider(height: 26),
                      _SummaryRow(
                        'Estimated subtotal',
                        _cart?.subtotal.formatted ?? 'Updating…',
                        strong: true,
                      ),
                      const Text(
                        'Shipping and final taxes are calculated at checkout.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      const _InfoRow(
                        Icons.wallet_outlined,
                        'Payment',
                        'PayMongo, Cash on Pickup, or Credit Card',
                      ),
                      const _InfoRow(
                        Icons.local_shipping_outlined,
                        'Fulfilment',
                        'Pickup and delivery are chosen at checkout.',
                      ),
                      if (_syncing) const LinearProgressIndicator(),
                      const SizedBox(height: 10),
                      const SizedBox(height: 8),
                      const Text(
                        'Need to change something after ordering? Contact the family.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: PinpinsColors.deepLeaf,
                ),
                onPressed:
                    _checkingOut ||
                        _syncing ||
                        _cart == null ||
                        items.any(
                          (item) => item.cartLine?.availableForSale != true,
                        )
                    ? null
                    : _checkout,
                icon: const Icon(Icons.arrow_forward),
                label: Text(_checkingOut ? 'Opening checkout…' : 'Checkout'),
              ),
            ),
    );
  }
}

class _BasketItemCard extends StatelessWidget {
  const _BasketItemCard({
    required this.title,
    required this.variant,
    required this.price,
    required this.imageUrl,
    required this.quantity,
    required this.attributes,
    required this.busy,
    required this.onQuantity,
    required this.onDate,
    required this.onRemove,
  });
  final String title;
  final String variant;
  final Money? price;
  final String? imageUrl;
  final int quantity;
  final Map<String, String> attributes;
  final bool busy;
  final ValueChanged<int> onQuantity;
  final VoidCallback onDate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final lineTotal = price == null
        ? ''
        : '${price!.currencyCode} ${(double.parse(price!.amount) * quantity).toStringAsFixed(2)}';
    final date = DateTime.tryParse(attributes['Preferred Date'] ?? '');
    return PaperCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl == null
                    ? const ColoredBox(
                        color: Color(0xFFFFF7E8),
                        child: SizedBox.square(
                          dimension: 88,
                          child: Icon(Icons.image_outlined),
                        ),
                      )
                    : Image.network(
                        imageUrl!,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        semanticLabel: title,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      variant,
                      style: const TextStyle(
                        color: PinpinsColors.deepLeaf,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (price != null) Text('${price!.formatted} each'),
                    Text(
                      lineTotal,
                      style: const TextStyle(
                        color: PinpinsColors.brown,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    date == null ? 'Choose preferred date' : formatDate(date),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _QuantityStepper(
                quantity: quantity,
                minimum: 0,
                onChanged: busy ? (_) {} : onQuantity,
              ),
            ],
          ),
          if (attributes['Special request'] case final request?) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.edit_note, color: PinpinsColors.deepLeaf),
                const SizedBox(width: 6),
                Expanded(child: Text(request)),
              ],
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: busy ? null : onRemove,
              icon: const Icon(Icons.close),
              label: const Text('Remove'),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({required this.auth, required this.signOut, super.key});
  final ShopifyAuthService auth;
  final VoidCallback signOut;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final AccountService _service = AccountService(widget.auth);
  late Future<CustomerAccount> _customer = _service.currentCustomer();
  late Future<AccountConnection<CustomerOrder>> _orders = _service.orders();
  late Future<AccountConnection<CustomerAddress>> _addresses = _service
      .addresses();
  bool _loadingMoreOrders = false;
  bool _loadingMoreAddresses = false;

  Future<void> _reload() async {
    final customer = _service.currentCustomer();
    final orders = _service.orders();
    final addresses = _service.addresses();
    setState(() {
      _customer = customer;
      _orders = orders;
      _addresses = addresses;
    });
    try {
      await (customer, orders, addresses).wait;
    } catch (_) {}
  }

  Future<void> _loadMoreOrders() async {
    if (_loadingMoreOrders) return;
    setState(() => _loadingMoreOrders = true);
    try {
      final current = await _orders;
      if (!current.hasNextPage) return;
      final next = await _service.orders(after: current.endCursor);
      if (mounted) {
        setState(() {
          _orders = Future.value(
            AccountConnection(
              items: [...current.items, ...next.items],
              hasNextPage: next.hasNextPage,
              endCursor: next.endCursor,
            ),
          );
        });
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _loadingMoreOrders = false);
    }
  }

  Future<void> _loadMoreAddresses() async {
    if (_loadingMoreAddresses) return;
    setState(() => _loadingMoreAddresses = true);
    try {
      final current = await _addresses;
      if (!current.hasNextPage) return;
      final next = await _service.addresses(after: current.endCursor);
      if (mounted) {
        setState(() {
          _addresses = Future.value(
            AccountConnection(
              items: [...current.items, ...next.items],
              hasNextPage: next.hasNextPage,
              endCursor: next.endCursor,
            ),
          );
        });
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _loadingMoreAddresses = false);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error.toString())));

  Widget _error(Object? error, VoidCallback retry) => StateSurface(
    message: error.toString(),
    icon: Icons.error_outline,
    action: TextButton.icon(
      onPressed: retry,
      icon: const Icon(Icons.refresh),
      label: const Text('Retry'),
    ),
  );

  Future<void> _editProfile(CustomerAccount customer) async {
    var firstName = customer.firstName;
    var lastName = customer.lastName;
    final values = await showDialog<({String firstName, String lastName})>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: firstName,
              onChanged: (value) => firstName = value,
              decoration: const InputDecoration(labelText: 'First name'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: lastName,
              onChanged: (value) => lastName = value,
              decoration: const InputDecoration(labelText: 'Last name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              firstName: firstName.trim(),
              lastName: lastName.trim(),
            )),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (values == null) return;
    try {
      final updated = await _service.updateProfile(
        firstName: values.firstName,
        lastName: values.lastName,
      );
      if (mounted) {
        setState(() {
          _customer = Future.value(updated);
        });
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _reload,
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          FutureBuilder<CustomerAccount>(
            future: _customer,
            builder: (_, snapshot) {
              if (snapshot.hasError) {
                return _error(
                  snapshot.error,
                  () => setState(() {
                    _customer = _service.currentCustomer();
                  }),
                );
              }
              final customer = snapshot.data;
              return PaperCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_circle_outlined, size: 44),
                  title: Text(
                    customer == null
                        ? 'Loading profile…'
                        : customer.displayName.isEmpty
                        ? 'Customer'
                        : customer.displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  subtitle: customer == null ? null : Text(customer.email),
                  trailing: customer == null
                      ? const CircularProgressIndicator()
                      : IconButton(
                          onPressed: () => _editProfile(customer),
                          tooltip: 'Edit profile',
                          icon: const Icon(Icons.edit_outlined),
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Eyebrow('Order history'),
          Text('Orders', style: Theme.of(context).textTheme.headlineSmall),
          FutureBuilder<AccountConnection<CustomerOrder>>(
            future: _orders,
            builder: (_, snapshot) {
              if (snapshot.hasError) {
                return _error(
                  snapshot.error,
                  () => setState(() {
                    _orders = _service.orders();
                  }),
                );
              }
              final page = snapshot.data;
              if (page == null) return const LinearProgressIndicator();
              if (page.items.isEmpty) {
                return const StateSurface(
                  message: 'No orders yet',
                  icon: Icons.receipt_long_outlined,
                );
              }
              return Column(
                children: [
                  for (final order in page.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PaperCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            order.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${order.processedAt.toLocal().toIso8601String().split('T').first}\n${order.financialStatus} • ${order.fulfillmentStatus}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${order.currencyCode} ${order.amount}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Chip(
                                label: Text('Order'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (page.hasNextPage)
                    TextButton(
                      onPressed: _loadingMoreOrders ? null : _loadMoreOrders,
                      child: Text(
                        _loadingMoreOrders ? 'Loading…' : 'Load more orders',
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Eyebrow('Saved details'),
          Text(
            'Saved addresses',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          FutureBuilder<AccountConnection<CustomerAddress>>(
            future: _addresses,
            builder: (_, snapshot) {
              if (snapshot.hasError) {
                return _error(
                  snapshot.error,
                  () => setState(() {
                    _addresses = _service.addresses();
                  }),
                );
              }
              final page = snapshot.data;
              if (page == null) return const LinearProgressIndicator();
              if (page.items.isEmpty) {
                return const StateSurface(
                  message: 'No saved addresses',
                  icon: Icons.location_off_outlined,
                );
              }
              return Column(
                children: [
                  for (final address in page.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PaperCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: PinpinsColors.deepLeaf,
                          ),
                          title: Text(address.formatted.join('\n')),
                          trailing: address.isDefault
                              ? const Chip(
                                  avatar: Icon(Icons.eco_outlined, size: 15),
                                  label: Text('Default'),
                                )
                              : null,
                        ),
                      ),
                    ),
                  if (page.hasNextPage)
                    TextButton(
                      onPressed: _loadingMoreAddresses
                          ? null
                          : _loadMoreAddresses,
                      child: Text(
                        _loadingMoreAddresses
                            ? 'Loading…'
                            : 'Load more addresses',
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: widget.signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    ),
  );
}
