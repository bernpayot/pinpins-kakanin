<?php

namespace App\Http\Controllers;

use App\Services\ShopifyStorefrontService;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class ShopifyController extends Controller
{
    public function products(Request $request, ShopifyStorefrontService $shopify): JsonResponse
    {
        $validated = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'after' => ['nullable', 'string', 'max:1024'],
            'collection' => ['nullable', 'string', 'max:255', 'regex:/^[a-z0-9-]+$/'],
        ]);

        return response()->json($shopify->products(
            $request->ip(),
            $validated['search'] ?? null,
            $validated['after'] ?? null,
            $validated['collection'] ?? null,
        ));
    }

    public function collections(Request $request, ShopifyStorefrontService $shopify): JsonResponse
    {
        return response()->json($shopify->collections($request->ip()));
    }

    public function product(string $handle, Request $request, ShopifyStorefrontService $shopify): JsonResponse
    {
        $product = $shopify->product($handle, $request->ip());

        return $product === []
            ? response()->json(['message' => 'Product not found.'], 404)
            : response()->json($product);
    }

    public function cart(Request $request, ShopifyStorefrontService $shopify): JsonResponse
    {
        $validated = $request->validate([
            'id' => ['required', 'string', 'max:2048', 'regex:/^gid:\/\/shopify\/Cart\//'],
        ]);
        $cart = $shopify->cart($validated['id'], $request->ip());
        if ($cart === []) {
            return response()->json(['message' => 'Cart not found.'], 404);
        }

        $customerAccessToken = $request->bearerToken();

        return $customerAccessToken === null
            ? response()->json($cart)
            : $this->cartPayload($shopify->identifyCart(
                $validated['id'],
                $customerAccessToken,
                $request->ip(),
            ));
    }

    public function createCart(Request $request, ShopifyStorefrontService $shopify): JsonResponse
    {
        $lines = $this->validateLines($request);
        $payload = $shopify->createCart($lines, $request->ip(), $request->bearerToken());

        return $this->cartPayload($payload, 201);
    }

    public function updateCartNote(Request $request, ShopifyStorefrontService $shopify): JsonResponse
    {
        $validated = $request->validate([
            'cartId' => ['required', 'string', 'max:2048', 'regex:/^gid:\/\/shopify\/Cart\//'],
            'note' => ['required', 'string', 'max:500'],
        ]);

        return $this->cartPayload($shopify->updateCartNote(
            $validated['cartId'],
            $validated['note'],
            $request->ip(),
        ));
    }

    public function changeCart(Request $request, ShopifyStorefrontService $shopify): JsonResponse
    {
        $validated = $request->validate([
            'cartId' => ['required', 'string', 'max:2048', 'regex:/^gid:\/\/shopify\/Cart\//'],
            'lineId' => ['nullable', 'string', 'max:2048', 'regex:/^gid:\/\/shopify\/CartLine\//'],
            'variantId' => ['nullable', 'string', 'regex:/^gid:\/\/shopify\/ProductVariant\/\d+$/'],
            'quantity' => ['required', 'integer', 'min:0', 'max:99'],
            'attributes' => ['nullable', 'array', 'max:3'],
            'attributes.*.key' => ['required_with:attributes', 'string', 'in:Preferred Date,Preferred Time,Special request'],
            'attributes.*.value' => ['required_with:attributes', 'string', 'max:500'],
        ]);
        $this->validatePreorderAttributes($validated['attributes'] ?? []);

        if (($validated['quantity'] === 0 && empty($validated['lineId'])) ||
            ($validated['quantity'] > 0 && empty($validated['lineId']) && empty($validated['variantId']))) {
            throw ValidationException::withMessages([
                'line' => 'A cart line ID or variant ID is required.',
            ]);
        }

        $payload = $shopify->changeCart(
            $validated['cartId'],
            $validated['quantity'],
            $request->ip(),
            $validated['lineId'] ?? null,
            $validated['variantId'] ?? null,
            $validated['attributes'] ?? null,
        );

        return $this->cartPayload($payload);
    }

    /**
     * @return array<int, array{variantId: string, quantity: int, attributes?: array<int, array{key: string, value: string}>}>
     */
    private function validateLines(Request $request): array
    {
        $lines = $request->validate([
            'lines' => ['required', 'array', 'min:1', 'max:250'],
            'lines.*.variantId' => ['required', 'string', 'regex:/^gid:\/\/shopify\/ProductVariant\/\d+$/'],
            'lines.*.quantity' => ['required', 'integer', 'min:1', 'max:99'],
            'lines.*.attributes' => ['nullable', 'array', 'max:3'],
            'lines.*.attributes.*.key' => ['required_with:lines.*.attributes', 'string', 'in:Preferred Date,Preferred Time,Special request'],
            'lines.*.attributes.*.value' => ['required_with:lines.*.attributes', 'string', 'max:500'],
        ])['lines'];

        foreach ($lines as $line) {
            $this->validatePreorderAttributes($line['attributes'] ?? []);
        }

        return $lines;
    }

    /** @param array<int, array{key: string, value: string}> $attributes */
    private function validatePreorderAttributes(array $attributes): void
    {
        $attributes = collect($attributes);
        $time = $attributes->firstWhere('key', 'Preferred Time')['value'] ?? null;
        if ($time !== null && ! preg_match('/^(?:(?:0[8-9]|1\d):[0-5][05]|20:00)$/', $time)) {
            throw ValidationException::withMessages([
                'attributes' => 'Preferred Time must be between 08:00 and 20:00 in five-minute increments.',
            ]);
        }

        $date = $attributes->firstWhere('key', 'Preferred Date')['value'] ?? null;
        if ($date === null) {
            return;
        }

        try {
            $selected = CarbonImmutable::createFromFormat('!Y-m-d', $date);
        } catch (\Throwable) {
            $selected = null;
        }
        $today = CarbonImmutable::today();
        $special = $selected && (($selected->month === 11 && $selected->day === 1)
            || ($selected->month === 12 && in_array($selected->day, [24, 31], true)));
        if (! $selected || $selected->format('Y-m-d') !== $date || $selected->lessThanOrEqualTo($today)
            || ($special && $today->diffInDays($selected) < 7)) {
            throw ValidationException::withMessages([
                'attributes' => 'Preferred Date must be tomorrow or later; November 1, December 24, and December 31 require seven days notice.',
            ]);
        }
    }

    private function cartPayload(array $payload, int $status = 200): JsonResponse
    {
        if (($payload['userErrors'] ?? []) !== []) {
            return response()->json(['errors' => $payload['userErrors']], 422);
        }
        if (empty($payload['cart'])) {
            return response()->json(['message' => 'Shopify could not update the cart.'], 502);
        }

        return response()->json($payload['cart'], $status);
    }
}
