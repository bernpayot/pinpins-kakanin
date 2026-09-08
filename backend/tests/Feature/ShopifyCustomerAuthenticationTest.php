<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class ShopifyCustomerAuthenticationTest extends TestCase
{
    public function test_account_requires_a_customer_token_and_returns_401(): void
    {
        Http::preventStrayRequests();

        $response = $this->getJson('/api/account');

        $response->assertUnauthorized();
    }

    public function test_account_returns_the_authenticated_shopify_customer(): void
    {
        config(['services.shopify.customer_api_url' => 'https://shop.example/api/customer/graphql']);
        Http::preventStrayRequests();
        Http::fake([
            'https://shop.example/api/customer/graphql' => Http::response([
                'data' => [
                    'customer' => [
                        'id' => 'gid://shopify/Customer/1',
                        'firstName' => 'Sally',
                        'lastName' => 'Test',
                        'emailAddress' => ['emailAddress' => 'sally@example.com'],
                    ],
                ],
            ]),
        ]);

        $response = $this->withToken('customer-token')->getJson('/api/account');

        $response->assertOk()->assertExactJson([
            'id' => 'gid://shopify/Customer/1',
            'firstName' => 'Sally',
            'lastName' => 'Test',
            'emailAddress' => ['emailAddress' => 'sally@example.com'],
        ]);
        Http::assertSent(fn ($request): bool => $request->hasHeader('Authorization', 'Bearer customer-token'));
    }

    public function test_expired_customer_token_returns_401(): void
    {
        config(['services.shopify.customer_api_url' => 'https://shop.example/api/customer/graphql']);
        Http::preventStrayRequests();
        Http::fake([
            'https://shop.example/api/customer/graphql' => Http::response(status: 401),
        ]);

        $response = $this->withToken('expired-token')->getJson('/api/account');

        $response->assertUnauthorized();
    }

    public function test_address_creation_validates_input_before_mutating_shopify(): void
    {
        config(['services.shopify.customer_api_url' => 'https://shop.example/api/customer/graphql']);
        Http::preventStrayRequests();
        Http::fake([
            'https://shop.example/api/customer/graphql' => Http::response([
                'data' => ['customer' => ['id' => 'gid://shopify/Customer/1']],
            ]),
        ]);

        $response = $this->withToken('customer-token')->postJson('/api/account/addresses', []);

        $response->assertUnprocessable()->assertJsonValidationErrors([
            'firstName',
            'lastName',
            'address1',
            'city',
            'territoryCode',
            'zip',
        ]);
        Http::assertSentCount(1);
    }
}
