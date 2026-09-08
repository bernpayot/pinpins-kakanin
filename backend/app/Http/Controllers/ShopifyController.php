<?php

namespace App\Http\Controllers;

use App\Services\ShopifyService;
use App\Services\ShopifyStorefrontService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ShopifyController extends Controller
{
    public function products(Request $request, ShopifyStorefrontService $shopify): JsonResponse
    {
        return response()->json($shopify->products($request->ip()));
    }

    public function checkout(Request $request, ShopifyStorefrontService $shopify): JsonResponse
    {
        $validated = $request->validate([
            'lines' => ['required', 'array', 'min:1', 'max:250'],
            'lines.*.variantId' => ['required', 'string', 'regex:/^gid:\/\/shopify\/ProductVariant\/\d+$/'],
            'lines.*.quantity' => ['required', 'integer', 'min:1', 'max:250'],
        ]);
        $payload = $shopify->createCart($validated['lines'], $request->ip());

        if (($payload['userErrors'] ?? []) !== []) {
            return response()->json(['errors' => $payload['userErrors']], 422);
        }

        if (empty($payload['cart']['checkoutUrl'])) {
            return response()->json(['message' => 'Shopify could not create a checkout.'], 502);
        }

        return response()->json([
            'checkoutUrl' => $payload['cart']['checkoutUrl'],
            'cost' => $payload['cart']['cost'],
            'warnings' => $payload['warnings'] ?? [],
        ]);
    }

    public function test(ShopifyService $shopify): JsonResponse
    {
        $query = <<<'GRAPHQL'
        query {
            shop {
                id
                name
                email
                myshopifyDomain
            }
        }
        GRAPHQL;

        return response()->json($shopify->graphql($query, []));
    }
}
