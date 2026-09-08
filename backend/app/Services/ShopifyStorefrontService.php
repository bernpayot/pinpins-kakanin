<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Symfony\Component\HttpKernel\Exception\HttpException;

class ShopifyStorefrontService
{
    private const PRODUCTS_QUERY = <<<'GRAPHQL'
    query Products {
        products(first: 50) {
            nodes {
                id
                title
                description
                featuredImage {
                    url
                    altText
                }
                variants(first: 50) {
                    nodes {
                        id
                        title
                        selectedOptions {
                            name
                            value
                        }
                        availableForSale
                        price {
                            amount
                            currencyCode
                        }
                    }
                }
            }
        }
    }
    GRAPHQL;

    private const CART_CREATE_MUTATION = <<<'GRAPHQL'
    mutation CartCreate($input: CartInput!) {
        cartCreate(input: $input) {
            cart {
                id
                checkoutUrl
                totalQuantity
                cost {
                    subtotalAmount {
                        amount
                        currencyCode
                    }
                    totalAmount {
                        amount
                        currencyCode
                    }
                }
            }
            userErrors {
                field
                message
                code
            }
            warnings {
                code
                target
                message
            }
        }
    }
    GRAPHQL;

    /**
     * @return array<int, array<string, mixed>>
     */
    public function products(string $buyerIp): array
    {
        return $this->graphql(self::PRODUCTS_QUERY, [], $buyerIp)['products']['nodes'] ?? [];
    }

    /**
     * @param  array<int, array{variantId: string, quantity: int}>  $lines
     * @return array<string, mixed>
     */
    public function createCart(array $lines, string $buyerIp): array
    {
        $input = [
            'lines' => array_map(fn (array $line): array => [
                'merchandiseId' => $line['variantId'],
                'quantity' => $line['quantity'],
            ], $lines),
        ];

        return $this->graphql(self::CART_CREATE_MUTATION, ['input' => $input], $buyerIp)['cartCreate'] ?? [];
    }

    /**
     * @param  array<string, mixed>  $variables
     * @return array<string, mixed>
     */
    private function graphql(string $query, array $variables, string $buyerIp): array
    {
        $domain = config('services.shopify.storefront_domain');
        $token = config('services.shopify.storefront_private_token');
        $apiVersion = config('services.shopify.api_version');

        if (! is_string($domain) || $domain === '' || ! is_string($token) || $token === '') {
            throw new HttpException(500, 'Shopify Storefront API is not configured.');
        }

        try {
            $response = Http::withHeaders([
                'Shopify-Storefront-Private-Token' => $token,
                'Shopify-Storefront-Buyer-IP' => $buyerIp,
            ])->acceptJson()->connectTimeout(3)->timeout(10)->post(
                'https://'.rtrim($domain, '/')."/api/{$apiVersion}/graphql.json",
                [
                    'query' => $query,
                    'variables' => (object) $variables,
                ],
            );
        } catch (ConnectionException) {
            throw new HttpException(502, 'Shopify Storefront API is unavailable.');
        }

        if ($response->failed()) {
            throw new HttpException(502, 'Shopify Storefront API request failed.');
        }

        $body = $response->json();

        if (! is_array($body) || ! empty($body['errors'])) {
            throw new HttpException(502, 'Shopify Storefront API returned an error.');
        }

        return $body['data'] ?? [];
    }
}
