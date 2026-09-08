<?php

namespace App\Services;

use Exception;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

class ShopifyService
{
    protected string $shop;

    protected string $clientId;

    protected string $clientSecret;

    protected string $apiVersion;

    public function __construct()
    {
        $this->shop = config('services.shopify.shop');
        $this->clientId = config('services.shopify.client_id');
        $this->clientSecret = config('services.shopify.client_secret');
        $this->apiVersion = config('services.shopify.api_version');
    }

    /**
     *  Get a Shopify Admin API access token
     */
    public function getAccessToken(): string
    {
        return Cache::remember(
            'shopify_acccess_token',
            now()->addHours(23),
            function () {
                $response = Http::asForm()->post(
                    "https://{$this->shop}.myshopify.com/admin/oauth/access_token",
                    [
                        'grant_type' => 'client_credentials',
                        'client_id' => $this->clientId,
                        'client_secret' => $this->clientSecret,
                    ]
                );

                if ($response->failed()) {
                    throw new Exception(
                        'Failed to get Shopify access token: '
                        .$response->body()
                    );
                }

                return $response->json('access_token');
            }
        );
    }

    /**
     * Send a GraphQL request to Shopify
     */
    public function graphql(string $query, array $variables = []): array
    {
        $token = $this->getAccessToken();

        $url =
            "https://{$this->shop}.myshopify.com/admin/api/"
            ."{$this->apiVersion}/graphql.json";

        $response = Http::withHeaders([
            'X-Shopify-Access-Token' => $token,
            'Content-Type' => 'application/json',
        ])->post($url, [
            'query' => $query,
            'variables' => (object) $variables,
        ]);

        if ($response->failed()) {
            throw new Exception(
                'Shopify API request failed: '
                .$response->body()
            );
        }

        $body = $response->json();
        if (! empty($body['errors'])) {
            throw new Exception('Shopify GraphQL error: '.json_encode($body['errors']));
        }

        return $body;
    }
}
