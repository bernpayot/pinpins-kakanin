<?php

namespace App\Services;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Http;
use Symfony\Component\HttpKernel\Exception\HttpException;

class ShopifyStorefrontService
{
    private const PRODUCT_FRAGMENT = <<<'GRAPHQL'
    fragment ProductFields on Product {
        handle
        title
        description
        featuredImage {
            url
        }
        variants(first: 50) {
            nodes {
                id
                title
                selectedOptions {
                    value
                }
                availableForSale
                price {
                    amount
                    currencyCode
                }
                image {
                    url
                }
            }
        }
    }
    GRAPHQL;

    private const PRODUCTS_QUERY = <<<'GRAPHQL'
    query Products($after: String, $query: String) {
        products(first: 20, after: $after, query: $query) {
            nodes {
                ...ProductFields
            }
            pageInfo {
                hasNextPage
                endCursor
            }
        }
    }
    GRAPHQL.self::PRODUCT_FRAGMENT;

    private const COLLECTION_PRODUCTS_QUERY = <<<'GRAPHQL'
    query CollectionProducts($handle: String!, $after: String) {
        collection(handle: $handle) {
            products(first: 20, after: $after) {
                nodes {
                    ...ProductFields
                }
                pageInfo {
                    hasNextPage
                    endCursor
                }
            }
        }
    }
    GRAPHQL.self::PRODUCT_FRAGMENT;

    private const COLLECTIONS_QUERY = <<<'GRAPHQL'
    query Collections {
        collections(first: 100, sortKey: TITLE) {
            nodes {
                handle
                title
            }
        }
    }
    GRAPHQL;

    private const PRODUCT_QUERY = <<<'GRAPHQL'
    query Product($handle: String!) {
        product(handle: $handle) {
            handle
            title
            description
            ingredients: metafield(namespace: "custom", key: "ingredients_and_allergens") {
                value
            }
            images(first: 20) {
                nodes {
                    url
                }
            }
            variants(first: 100) {
                nodes {
                    id
                    title
                    selectedOptions {
                        value
                    }
                    availableForSale
                    price {
                        amount
                        currencyCode
                    }
                    image {
                        url
                    }
                }
            }
        }
    }
    GRAPHQL;

    private const CART_FRAGMENT = <<<'GRAPHQL'
    fragment CartFields on Cart {
        id
        checkoutUrl
        note
        cost {
            subtotalAmount {
                amount
                currencyCode
            }
        }
        lines(first: 250) {
            nodes {
                id
                quantity
                attributes {
                    key
                    value
                }
                merchandise {
                    ... on ProductVariant {
                        id
                        title
                        availableForSale
                        price {
                            amount
                            currencyCode
                        }
                        product {
                            title
                            featuredImage {
                                url
                            }
                        }
                        image {
                            url
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
                ...CartFields
            }
            userErrors {
                field
                message
                code
            }
        }
    }
    GRAPHQL.self::CART_FRAGMENT;

    private const CART_QUERY = <<<'GRAPHQL'
    query Cart($id: ID!) {
        cart(id: $id) {
            ...CartFields
        }
    }
    GRAPHQL.self::CART_FRAGMENT;

    private const CART_BUYER_IDENTITY_UPDATE_MUTATION = <<<'GRAPHQL'
    mutation CartBuyerIdentityUpdate($cartId: ID!, $buyerIdentity: CartBuyerIdentityInput!) {
        cartBuyerIdentityUpdate(cartId: $cartId, buyerIdentity: $buyerIdentity) {
            cart {
                ...CartFields
            }
            userErrors {
                field
                message
                code
            }
        }
    }
    GRAPHQL.self::CART_FRAGMENT;

    private const CART_NOTE_UPDATE_MUTATION = <<<'GRAPHQL'
    mutation CartNoteUpdate($cartId: ID!, $note: String!) {
        cartNoteUpdate(cartId: $cartId, note: $note) {
            cart {
                ...CartFields
            }
            userErrors {
                field
                message
                code
            }
        }
    }
    GRAPHQL.self::CART_FRAGMENT;

    private const CART_LINES_ADD_MUTATION = <<<'GRAPHQL'
    mutation CartLinesAdd($cartId: ID!, $lines: [CartLineInput!]!) {
        cartLinesAdd(cartId: $cartId, lines: $lines) {
            cart {
                ...CartFields
            }
            userErrors {
                field
                message
                code
            }
        }
    }
    GRAPHQL.self::CART_FRAGMENT;

    private const CART_LINES_UPDATE_MUTATION = <<<'GRAPHQL'
    mutation CartLinesUpdate($cartId: ID!, $lines: [CartLineUpdateInput!]!) {
        cartLinesUpdate(cartId: $cartId, lines: $lines) {
            cart {
                ...CartFields
            }
            userErrors {
                field
                message
                code
            }
        }
    }
    GRAPHQL.self::CART_FRAGMENT;

    private const CART_LINES_REMOVE_MUTATION = <<<'GRAPHQL'
    mutation CartLinesRemove($cartId: ID!, $lineIds: [ID!]!) {
        cartLinesRemove(cartId: $cartId, lineIds: $lineIds) {
            cart {
                ...CartFields
            }
            userErrors {
                field
                message
                code
            }
        }
    }
    GRAPHQL.self::CART_FRAGMENT;

    /**
     * @return array{nodes: array<int, array<string, mixed>>, pageInfo: array<string, mixed>}
     */
    public function products(
        string $buyerIp,
        ?string $search = null,
        ?string $after = null,
        ?string $collection = null,
    ): array {
        $variables = ['after' => $after];
        $query = self::PRODUCTS_QUERY;
        $path = 'products';

        if ($collection !== null) {
            $query = self::COLLECTION_PRODUCTS_QUERY;
            $variables['handle'] = $collection;
            $path = 'collection.products';
        } else {
            $variables['query'] = $search;
        }

        $data = $this->graphql($query, $variables, $buyerIp);

        return Arr::get($data, $path, [
            'nodes' => [],
            'pageInfo' => ['hasNextPage' => false, 'endCursor' => null],
        ]);
    }

    /**
     * @return array<int, array{handle: string, title: string}>
     */
    public function collections(string $buyerIp): array
    {
        return $this->graphql(self::COLLECTIONS_QUERY, [], $buyerIp)['collections']['nodes'] ?? [];
    }

    /**
     * @return array<string, mixed>
     */
    public function product(string $handle, string $buyerIp): array
    {
        return $this->graphql(
            self::PRODUCT_QUERY,
            ['handle' => $handle],
            $buyerIp,
        )['product'] ?? [];
    }

    /**
     * @param  array<int, array{variantId: string, quantity: int, attributes?: array<int, array{key: string, value: string}>}>  $lines
     * @return array<string, mixed>
     */
    public function createCart(array $lines, string $buyerIp, ?string $customerAccessToken = null): array
    {
        $input = [
            'lines' => array_map(fn (array $line): array => array_filter([
                'merchandiseId' => $line['variantId'],
                'quantity' => $line['quantity'],
                'attributes' => $line['attributes'] ?? null,
            ], fn ($value): bool => $value !== null), $lines),
        ];

        if ($customerAccessToken !== null) {
            $input['buyerIdentity'] = ['customerAccessToken' => $customerAccessToken];
        }

        return $this->graphql(
            self::CART_CREATE_MUTATION,
            ['input' => $input],
            $buyerIp,
        )['cartCreate'] ?? [];
    }

    /**
     * @return array<string, mixed>
     */
    public function cart(string $cartId, string $buyerIp): array
    {
        return $this->graphql(
            self::CART_QUERY,
            ['id' => $cartId],
            $buyerIp,
        )['cart'] ?? [];
    }

    /**
     * @return array<string, mixed>
     */
    public function identifyCart(string $cartId, string $customerAccessToken, string $buyerIp): array
    {
        return $this->graphql(
            self::CART_BUYER_IDENTITY_UPDATE_MUTATION,
            [
                'cartId' => $cartId,
                'buyerIdentity' => ['customerAccessToken' => $customerAccessToken],
            ],
            $buyerIp,
        )['cartBuyerIdentityUpdate'] ?? [];
    }

    /** @return array<string, mixed> */
    public function updateCartNote(string $cartId, string $note, string $buyerIp): array
    {
        return $this->graphql(
            self::CART_NOTE_UPDATE_MUTATION,
            ['cartId' => $cartId, 'note' => $note],
            $buyerIp,
        )['cartNoteUpdate'] ?? [];
    }

    /**
     * @return array<string, mixed>
     */
    public function changeCart(
        string $cartId,
        int $quantity,
        string $buyerIp,
        ?string $lineId = null,
        ?string $variantId = null,
        ?array $attributes = null,
    ): array {
        if ($quantity === 0) {
            $mutation = self::CART_LINES_REMOVE_MUTATION;
            $variables = ['cartId' => $cartId, 'lineIds' => [$lineId]];
            $key = 'cartLinesRemove';
        } elseif ($lineId === null) {
            $mutation = self::CART_LINES_ADD_MUTATION;
            $variables = [
                'cartId' => $cartId,
                'lines' => [[
                    'merchandiseId' => $variantId,
                    'quantity' => $quantity,
                    'attributes' => $attributes ?? [],
                ]],
            ];
            $key = 'cartLinesAdd';
        } else {
            $mutation = self::CART_LINES_UPDATE_MUTATION;
            $variables = [
                'cartId' => $cartId,
                'lines' => [array_filter([
                    'id' => $lineId,
                    'quantity' => $quantity,
                    'attributes' => $attributes,
                ], fn ($value): bool => $value !== null)],
            ];
            $key = 'cartLinesUpdate';
        }

        return $this->graphql(
            $mutation,
            $variables,
            $buyerIp,
        )[$key] ?? [];
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
