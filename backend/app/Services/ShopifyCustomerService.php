<?php

namespace App\Services;

use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Symfony\Component\HttpKernel\Exception\HttpException;

class ShopifyCustomerService
{
    private const CURRENT_CUSTOMER_QUERY = <<<'GRAPHQL'
    query CurrentCustomer {
        customer {
            id
            firstName
            lastName
            emailAddress {
                emailAddress
            }
        }
    }
    GRAPHQL;

    /**
     * @return array<string, mixed>
     */
    public function currentCustomer(string $accessToken): array
    {
        return $this->graphql(self::CURRENT_CUSTOMER_QUERY, [], $accessToken)['customer'] ?? [];
    }

    /**
     * @param  array<string, mixed>  $variables
     * @return array<string, mixed>
     */
    public function graphql(string $query, array $variables, string $accessToken): array
    {
        $apiUrl = config('services.shopify.customer_api_url');

        if (! is_string($apiUrl) || $apiUrl === '') {
            throw new HttpException(500, 'Shopify Customer Account API is not configured.');
        }

        try {
            $response = Http::withToken($accessToken)
                ->acceptJson()
                ->connectTimeout(3)
                ->timeout(10)
                ->post($apiUrl, [
                    'query' => $query,
                    'variables' => (object) $variables,
                ]);
        } catch (ConnectionException) {
            throw new HttpException(502, 'Shopify Customer Account API is unavailable.');
        }

        if ($response->unauthorized()) {
            throw new AuthenticationException('Invalid or expired Shopify customer token.');
        }

        if ($response->failed()) {
            throw new HttpException(502, 'Shopify Customer Account API request failed.');
        }

        $body = $response->json();

        if (! is_array($body) || ! empty($body['errors'])) {
            throw new HttpException(502, 'Shopify Customer Account API returned an error.');
        }

        return $body['data'] ?? [];
    }
}
