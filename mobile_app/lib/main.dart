import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

import 'account_service.dart';
import 'auth_service.dart';
import 'basket_service.dart';
import 'checkout_service.dart';
import 'product_service.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pinpins Kakanin',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    ),
    home: AuthGate(),
  );
}

class AuthGate extends StatefulWidget {
  AuthGate({
    ShopifyAuthService? auth,
    BasketService? basket,
    this.productsLoader,
    this.customerLoader,
    super.key,
  }) : auth = auth ?? ShopifyAuthService(),
       basket = basket ?? BasketService();

  final ShopifyAuthService auth;
  final BasketService basket;
  final Future<List<Product>> Function()? productsLoader;
  final Future<CustomerAccount> Function()? customerLoader;

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

  void _signedIn(AuthSession session) {
    setState(() {
      _session = Future.value(session);
    });
  }

  void _signedOut() {
    setState(() {
      _session = Future.value(null);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AuthSession?>(
    future: _session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      return ProductsPage(
        auth: widget.auth,
        basketService: widget.basket,
        session: snapshot.data,
        productsLoader: widget.productsLoader,
        customerLoader: widget.customerLoader,
        onSignedIn: _signedIn,
        onSignedOut: _signedOut,
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
    this.productsLoader,
    this.customerLoader,
    super.key,
  });

  final ShopifyAuthService auth;
  final BasketService basketService;
  final AuthSession? session;
  final ValueChanged<AuthSession> onSignedIn;
  final VoidCallback onSignedOut;
  final Future<List<Product>> Function()? productsLoader;
  final Future<CustomerAccount> Function()? customerLoader;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late Future<List<Product>> _products;
  late Future<CustomerAccount?> _customer;
  Map<String, int> _basket = {};
  bool _authBusy = false;

  @override
  void initState() {
    super.initState();
    _products = _fetchProducts();
    _customer = _fetchCustomer();
    _restoreBasket();
  }

  Future<List<Product>> _fetchProducts() =>
      (widget.productsLoader ?? ProductService.getProducts)();

  Future<CustomerAccount?> _fetchCustomer() async {
    if (widget.session == null || widget.session!.isExpiring()) return null;

    try {
      return await (widget.customerLoader?.call() ??
          AccountService(
            widget.auth,
          ).currentCustomer(renewOnUnauthorized: false));
    } on AuthenticationExpiredException {
      await widget.auth.clearSession();
      if (mounted) widget.onSignedOut();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _restoreBasket() async {
    final basket = await widget.basketService.load();
    if (mounted) setState(() => _basket = basket);
  }

  Future<void> _reload() async {
    final products = _fetchProducts();
    setState(() {
      _products = products;
    });

    try {
      await products;
    } catch (_) {
      // FutureBuilder displays the catalog error.
    }
  }

  Future<void> _login() async {
    setState(() => _authBusy = true);

    try {
      widget.onSignedIn(await widget.auth.login());
    } on FlutterAppAuthUserCancelledException {
      // The store remains available when the browser is closed.
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

  Future<void> _addToBasket(ProductVariant variant) async {
    if ((_basket[variant.id] ?? 0) >= 250) return;

    final basket = {..._basket};
    basket[variant.id] = (basket[variant.id] ?? 0) + 1;
    await widget.basketService.save(basket);
    if (mounted) setState(() => _basket = basket);
  }

  Future<void> _openBasket() async {
    try {
      final products = await _products;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BasketPage(
            products: products,
            initialBasket: _basket,
            basketService: widget.basketService,
          ),
        ),
      );
      await _restoreBasket();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: FutureBuilder<CustomerAccount?>(
        future: _customer,
        builder: (_, snapshot) => Text(
          snapshot.data?.displayName.isNotEmpty == true
              ? snapshot.data!.displayName
              : 'Shopify Products',
        ),
      ),
      actions: [
        IconButton(
          onPressed: _reload,
          tooltip: 'Reload',
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: _openBasket,
          tooltip: 'Basket',
          icon: Badge(
            isLabelVisible: _basket.isNotEmpty,
            label: Text(
              '${_basket.values.fold(0, (total, quantity) => total + quantity)}',
            ),
            child: const Icon(Icons.shopping_basket_outlined),
          ),
        ),
        if (widget.session == null)
          TextButton(
            onPressed: _authBusy ? null : _login,
            child: Text(_authBusy ? 'Signing in…' : 'Sign in'),
          )
        else
          TextButton(
            onPressed: _authBusy ? null : _logout,
            child: Text(_authBusy ? 'Signing out…' : 'Sign out'),
          ),
      ],
    ),
    body: FutureBuilder<List<Product>>(
      future: _products,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load products\n${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }
        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return const Center(child: Text('No products found'));
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) =>
                _ProductCard(product: products[index], onAdd: _addToBasket),
          ),
        );
      },
    ),
  );
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({required this.product, required this.onAdd});

  final Product product;
  final ValueChanged<ProductVariant> onAdd;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  ProductVariant? _selected;

  @override
  void initState() {
    super.initState();
    for (final variant in widget.product.variants) {
      if (variant.availableForSale) {
        _selected = variant;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          height: 140,
          child: widget.product.imageUrl == null
              ? const ColoredBox(
                  color: Colors.black12,
                  child: Icon(Icons.image_outlined, size: 40),
                )
              : Image.network(
                  widget.product.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (widget.product.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                if (widget.product.variants.isEmpty)
                  const Text('Unavailable')
                else
                  DropdownButton<ProductVariant>(
                    isExpanded: true,
                    value: _selected,
                    hint: const Text('Unavailable'),
                    items: widget.product.variants
                        .map(
                          (variant) => DropdownMenuItem(
                            value: variant,
                            enabled: variant.availableForSale,
                            child: Text(
                              '${variant.label} — ${variant.price.formatted}'
                              '${variant.availableForSale ? '' : ' (Unavailable)'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (variant) => setState(() => _selected = variant),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _selected == null
                        ? null
                        : () => widget.onAdd(_selected!),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add to basket'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class BasketPage extends StatefulWidget {
  const BasketPage({
    required this.products,
    required this.initialBasket,
    required this.basketService,
    this.checkoutCreator,
    this.checkoutPresenter,
    super.key,
  });

  final List<Product> products;
  final Map<String, int> initialBasket;
  final BasketService basketService;
  final Future<CheckoutResult> Function(Map<String, int>)? checkoutCreator;
  final Future<CheckoutStatus> Function(Uri)? checkoutPresenter;

  @override
  State<BasketPage> createState() => _BasketPageState();
}

class _BasketPageState extends State<BasketPage> {
  late Map<String, int> _basket;
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    _basket = {...widget.initialBasket};
  }

  List<_BasketItem> get _items {
    final variants = <String, (Product, ProductVariant)>{};
    for (final product in widget.products) {
      for (final variant in product.variants) {
        variants[variant.id] = (product, variant);
      }
    }

    return _basket.entries.map((line) {
      final match = variants[line.key];
      return _BasketItem(
        variantId: line.key,
        quantity: line.value,
        product: match?.$1,
        variant: match?.$2,
      );
    }).toList();
  }

  Future<void> _setQuantity(String variantId, int quantity) async {
    final basket = {..._basket};
    if (quantity < 1) {
      basket.remove(variantId);
    } else if (quantity <= 250) {
      basket[variantId] = quantity;
    }
    await widget.basketService.save(basket);
    if (mounted) setState(() => _basket = basket);
  }

  Future<void> _checkout() async {
    setState(() => _checkingOut = true);

    try {
      final checkout =
          await (widget.checkoutCreator?.call(_basket) ??
              ProductService.createCheckout(_basket));
      final status =
          await (widget.checkoutPresenter?.call(checkout.url) ??
              CheckoutKit.present(checkout.url));
      if (status == CheckoutStatus.completed) {
        await widget.basketService.save({});
        if (mounted) setState(() => _basket = {});
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      appBar: AppBar(title: const Text('Basket')),
      body: items.isEmpty
          ? const Center(child: Text('Your basket is empty'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (_, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item.product?.title ?? 'Unavailable item'),
                  subtitle: Text(
                    item.variant == null
                        ? 'This item may no longer be available'
                        : '${item.variant!.label} — ${item.variant!.price.formatted}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () =>
                            _setQuantity(item.variantId, item.quantity - 1),
                        tooltip: item.quantity == 1 ? 'Remove' : 'Decrease',
                        icon: Icon(
                          item.quantity == 1
                              ? Icons.delete_outline
                              : Icons.remove,
                        ),
                      ),
                      Text('${item.quantity}'),
                      IconButton(
                        onPressed: item.quantity == 250
                            ? null
                            : () => _setQuantity(
                                item.variantId,
                                item.quantity + 1,
                              ),
                        tooltip: 'Increase',
                        icon: const Icon(Icons.add),
                      ),
                      IconButton(
                        onPressed: () => _setQuantity(item.variantId, 0),
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: _checkingOut ? null : _checkout,
                child: Text(_checkingOut ? 'Opening checkout…' : 'Checkout'),
              ),
            ),
    );
  }
}

class _BasketItem {
  const _BasketItem({
    required this.variantId,
    required this.quantity,
    required this.product,
    required this.variant,
  });

  final String variantId;
  final int quantity;
  final Product? product;
  final ProductVariant? variant;
}
