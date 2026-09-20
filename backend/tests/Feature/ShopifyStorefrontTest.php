<?php

namespace Tests\Feature;

use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class ShopifyStorefrontTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        config([
            'services.shopify.api_version' => '2026-07',
            'services.shopify.storefront_domain' => 'shop.example',
            'services.shopify.storefront_private_token' => 'private-token',
        ]);
        Http::preventStrayRequests();
    }

    public function test_products_are_public_and_use_the_storefront_api(): void
    {
        Http::fake([
            'https://shop.example/api/2026-07/graphql.json' => Http::response([
                'data' => [
                    'products' => [
                        'nodes' => [[
                            'id' => 'gid://shopify/Product/1',
                            'title' => 'Bibingka',
                            'description' => 'Rice cake',
                            'featuredImage' => null,
                            'variants' => ['nodes' => [[
                                'id' => 'gid://shopify/ProductVariant/1',
                                'title' => 'Small',
                                'selectedOptions' => [['name' => 'Size', 'value' => 'Small']],
                                'availableForSale' => true,
                                'price' => ['amount' => '120.00', 'currencyCode' => 'PHP'],
                            ]]],
                        ]],
                    ],
                ],
            ]),
        ]);

        $this->getJson('/api/shopify/products')
            ->assertOk()
            ->assertJsonPath('nodes.0.variants.nodes.0.price.currencyCode', 'PHP');

        Http::assertSent(fn (Request $request): bool => $request->hasHeader(
            'Shopify-Storefront-Private-Token',
            'private-token',
        ) && $request->hasHeader('Shopify-Storefront-Buyer-IP', '127.0.0.1'));
    }

    public function test_products_support_search_collection_and_cursor_pagination(): void
    {
        Http::fake(function (Request $request) {
            $variables = (array) $request->data()['variables'];
            $this->assertSame('rice cake', $variables['query'] ?? null);
            $this->assertSame('next-page', $variables['after'] ?? null);

            return Http::response([
                'data' => [
                    'products' => [
                        'nodes' => [],
                        'pageInfo' => ['hasNextPage' => false, 'endCursor' => null],
                    ],
                ],
            ]);
        });

        $this->getJson('/api/shopify/products?search=rice%20cake&after=next-page')
            ->assertOk()
            ->assertExactJson([
                'nodes' => [],
                'pageInfo' => ['hasNextPage' => false, 'endCursor' => null],
            ]);
    }

    public function test_guest_can_create_a_cart_from_variant_ids_and_quantities(): void
    {
        Http::fake(function (Request $request) {
            $variables = (array) $request->data()['variables'];
            $lines = $variables['input']['lines'];

            $this->assertSame([[
                'merchandiseId' => 'gid://shopify/ProductVariant/123',
                'quantity' => 2,
            ]], $lines);

            return Http::response([
                'data' => [
                    'cartCreate' => [
                        'cart' => [
                            'checkoutUrl' => 'https://shop.example/checkouts/abc',
                            'cost' => [
                                'totalAmount' => ['amount' => '240.00', 'currencyCode' => 'PHP'],
                            ],
                        ],
                        'userErrors' => [],
                    ],
                ],
            ]);
        });

        $this->postJson('/api/shopify/cart', [
            'lines' => [[
                'variantId' => 'gid://shopify/ProductVariant/123',
                'quantity' => 2,
            ]],
        ])->assertCreated()->assertJson([
            'checkoutUrl' => 'https://shop.example/checkouts/abc',
            'cost' => [
                'totalAmount' => ['amount' => '240.00', 'currencyCode' => 'PHP'],
            ],
        ]);
    }

    public function test_authenticated_cart_sets_the_customer_buyer_identity(): void
    {
        Http::fake(function (Request $request) {
            $variables = (array) $request->data()['variables'];
            $input = $variables['input'];

            $this->assertSame([
                'customerAccessToken' => 'customer-token',
            ], $input['buyerIdentity']);

            return Http::response([
                'data' => [
                    'cartCreate' => [
                        'cart' => [
                            'checkoutUrl' => 'https://shop.example/checkouts/abc',
                            'cost' => [],
                        ],
                        'userErrors' => [],
                    ],
                ],
            ]);
        });

        $this->withToken('customer-token')->postJson('/api/shopify/cart', [
            'lines' => [[
                'variantId' => 'gid://shopify/ProductVariant/123',
                'quantity' => 1,
            ]],
        ])->assertCreated();
    }

    public function test_cart_line_attributes_are_validated_and_forwarded(): void
    {
        $date = now()->addDays(8)->format('Y-m-d');
        Http::fake(function (Request $request) use ($date) {
            $line = ((array) $request->data()['variables'])['input']['lines'][0];
            $this->assertSame([
                ['key' => 'Preferred Date', 'value' => $date],
                ['key' => 'Special request', 'value' => 'Less sweet'],
            ], $line['attributes']);

            return Http::response([
                'data' => ['cartCreate' => [
                    'cart' => ['id' => 'gid://shopify/Cart/1'],
                    'userErrors' => [],
                ]],
            ]);
        });

        $this->postJson('/api/shopify/cart', ['lines' => [[
            'variantId' => 'gid://shopify/ProductVariant/123',
            'quantity' => 1,
            'attributes' => [
                ['key' => 'Preferred Date', 'value' => $date],
                ['key' => 'Special request', 'value' => 'Less sweet'],
            ],
        ]]])->assertCreated();

        $this->postJson('/api/shopify/cart', ['lines' => [[
            'variantId' => 'gid://shopify/ProductVariant/123',
            'quantity' => 1,
            'attributes' => [[
                'key' => 'Preferred Date',
                'value' => now()->subDay()->format('Y-m-d'),
            ]],
        ]]])->assertUnprocessable();
    }

    public function test_admin_test_route_is_not_public(): void
    {
        $this->getJson('/api/shopify/test')->assertNotFound();
    }

    public function test_authenticated_cart_read_updates_the_buyer_identity(): void
    {
        $requestNumber = 0;
        Http::fake(function (Request $request) use (&$requestNumber) {
            $requestNumber++;
            if ($requestNumber === 1) {
                return Http::response([
                    'data' => ['cart' => ['id' => 'gid://shopify/Cart/1']],
                ]);
            }

            $variables = (array) $request->data()['variables'];
            $this->assertSame([
                'customerAccessToken' => 'customer-token',
            ], $variables['buyerIdentity']);

            return Http::response([
                'data' => [
                    'cartBuyerIdentityUpdate' => [
                        'cart' => ['id' => 'gid://shopify/Cart/1'],
                        'userErrors' => [],
                    ],
                ],
            ]);
        });

        $this->withToken('customer-token')->postJson('/api/shopify/cart/read', [
            'id' => 'gid://shopify/Cart/1',
        ])->assertOk();

        $this->assertSame(2, $requestNumber);
    }

    public function test_cart_change_uses_add_update_and_remove_mutations(): void
    {
        $expectedMutations = ['cartLinesAdd', 'cartLinesUpdate', 'cartLinesRemove'];
        Http::fake(function (Request $request) use (&$expectedMutations) {
            $mutation = array_shift($expectedMutations);
            $this->assertStringContainsString($mutation, $request->data()['query']);

            return Http::response([
                'data' => [
                    $mutation => [
                        'cart' => ['id' => 'gid://shopify/Cart/1'],
                        'userErrors' => [],
                    ],
                ],
            ]);
        });

        $base = ['cartId' => 'gid://shopify/Cart/1'];
        $this->postJson('/api/shopify/cart/change', $base + [
            'variantId' => 'gid://shopify/ProductVariant/123',
            'quantity' => 1,
        ])->assertOk();
        $this->postJson('/api/shopify/cart/change', $base + [
            'lineId' => 'gid://shopify/CartLine/1',
            'quantity' => 2,
        ])->assertOk();
        $this->postJson('/api/shopify/cart/change', $base + [
            'lineId' => 'gid://shopify/CartLine/1',
            'quantity' => 0,
        ])->assertOk();

        $this->assertSame([], $expectedMutations);
    }

    public function test_cart_rejects_invalid_quantities_before_calling_shopify(): void
    {
        Http::fake();

        $this->postJson('/api/shopify/cart', [
            'lines' => [[
                'variantId' => 'gid://shopify/ProductVariant/123',
                'quantity' => 0,
            ]],
        ])->assertUnprocessable()->assertJsonValidationErrors('lines.0.quantity');

        Http::assertNothingSent();
    }

    public function test_cart_returns_shopify_errors(): void
    {
        Http::fake([
            '*' => Http::response([
                'data' => [
                    'cartCreate' => [
                        'cart' => null,
                        'userErrors' => [[
                            'field' => ['input', 'lines', '0', 'quantity'],
                            'message' => 'The merchandise is not available.',
                            'code' => 'MERCHANDISE_NOT_LINE_ITEM',
                        ]],
                    ],
                ],
            ]),
        ]);

        $this->postJson('/api/shopify/cart', [
            'lines' => [[
                'variantId' => 'gid://shopify/ProductVariant/123',
                'quantity' => 1,
            ]],
        ])->assertUnprocessable()->assertJsonPath(
            'errors.0.message',
            'The merchandise is not available.',
        );
    }
}
