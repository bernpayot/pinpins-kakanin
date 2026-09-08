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
            ->assertJsonPath('0.variants.nodes.0.price.currencyCode', 'PHP');

        Http::assertSent(fn (Request $request): bool => $request->hasHeader(
            'Shopify-Storefront-Private-Token',
            'private-token',
        ) && $request->hasHeader('Shopify-Storefront-Buyer-IP', '127.0.0.1'));
    }

    public function test_guest_can_create_a_checkout_from_variant_ids_and_quantities(): void
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
                        'warnings' => [],
                    ],
                ],
            ]);
        });

        $this->postJson('/api/shopify/checkout', [
            'lines' => [[
                'variantId' => 'gid://shopify/ProductVariant/123',
                'quantity' => 2,
            ]],
        ])->assertOk()->assertJson([
            'checkoutUrl' => 'https://shop.example/checkouts/abc',
            'cost' => [
                'totalAmount' => ['amount' => '240.00', 'currencyCode' => 'PHP'],
            ],
        ]);
    }

    public function test_checkout_rejects_invalid_quantities_before_calling_shopify(): void
    {
        Http::fake();

        $this->postJson('/api/shopify/checkout', [
            'lines' => [[
                'variantId' => 'gid://shopify/ProductVariant/123',
                'quantity' => 0,
            ]],
        ])->assertUnprocessable()->assertJsonValidationErrors('lines.0.quantity');

        Http::assertNothingSent();
    }

    public function test_checkout_returns_shopify_cart_errors(): void
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
                        'warnings' => [],
                    ],
                ],
            ]),
        ]);

        $this->postJson('/api/shopify/checkout', [
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
