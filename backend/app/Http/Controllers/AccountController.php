<?php

namespace App\Http\Controllers;

use App\Services\ShopifyCustomerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;

class AccountController extends Controller
{
    private const ORDERS_QUERY = <<<'GRAPHQL'
    query CustomerOrders {
        customer {
            orders(first: 20, reverse: true) {
                nodes {
                    id
                    name
                    processedAt
                    financialStatus
                    fulfillmentStatus
                    totalPrice {
                        amount
                        currencyCode
                    }
                }
            }
        }
    }
    GRAPHQL;

    private const ADDRESSES_QUERY = <<<'GRAPHQL'
    query CustomerAddresses {
        customer {
            defaultAddress {
                id
            }
            addresses(first: 20) {
                nodes {
                    id
                    firstName
                    lastName
                    company
                    address1
                    address2
                    city
                    zoneCode
                    territoryCode
                    zip
                    phoneNumber
                    formatted
                }
            }
        }
    }
    GRAPHQL;

    private const CREATE_ADDRESS_MUTATION = <<<'GRAPHQL'
    mutation CreateCustomerAddress($address: CustomerAddressInput!, $defaultAddress: Boolean) {
        customerAddressCreate(address: $address, defaultAddress: $defaultAddress) {
            customerAddress {
                id
                firstName
                lastName
                company
                address1
                address2
                city
                zoneCode
                territoryCode
                zip
                phoneNumber
                formatted
            }
            userErrors {
                field
                message
                code
            }
        }
    }
    GRAPHQL;

    private const UPDATE_CUSTOMER_MUTATION = <<<'GRAPHQL'
    mutation UpdateCustomer($input: CustomerUpdateInput!) {
        customerUpdate(input: $input) {
            customer {
                id
                firstName
                lastName
                emailAddress {
                    emailAddress
                }
            }
            userErrors {
                field
                message
            }
        }
    }
    GRAPHQL;

    public function show(Request $request): JsonResponse
    {
        return response()->json($request->attributes->get('shopifyCustomer'));
    }

    public function orders(Request $request, ShopifyCustomerService $shopify): JsonResponse
    {
        $data = $shopify->graphql(self::ORDERS_QUERY, [], $request->bearerToken());

        return response()->json(Arr::get($data, 'customer.orders.nodes', []));
    }

    public function addresses(Request $request, ShopifyCustomerService $shopify): JsonResponse
    {
        $data = $shopify->graphql(self::ADDRESSES_QUERY, [], $request->bearerToken());

        return response()->json($data['customer'] ?? []);
    }

    public function storeAddress(Request $request, ShopifyCustomerService $shopify): JsonResponse
    {
        $validated = $request->validate([
            'firstName' => ['required', 'string', 'max:255'],
            'lastName' => ['required', 'string', 'max:255'],
            'company' => ['nullable', 'string', 'max:255'],
            'address1' => ['required', 'string', 'max:255'],
            'address2' => ['nullable', 'string', 'max:255'],
            'city' => ['required', 'string', 'max:255'],
            'zoneCode' => ['nullable', 'string', 'max:10'],
            'territoryCode' => ['required', 'string', 'size:2'],
            'zip' => ['required', 'string', 'max:32'],
            'phoneNumber' => ['nullable', 'string', 'max:32'],
            'defaultAddress' => ['sometimes', 'boolean'],
        ]);

        $defaultAddress = Arr::pull($validated, 'defaultAddress', false);
        $payload = $shopify->graphql(self::CREATE_ADDRESS_MUTATION, [
            'address' => $validated,
            'defaultAddress' => $defaultAddress,
        ], $request->bearerToken())['customerAddressCreate'];

        if ($payload['userErrors'] !== []) {
            return response()->json(['errors' => $payload['userErrors']], 422);
        }

        return response()->json($payload['customerAddress'], 201);
    }

    public function update(Request $request, ShopifyCustomerService $shopify): JsonResponse
    {
        $input = $request->validate([
            'firstName' => ['sometimes', 'nullable', 'string', 'max:255'],
            'lastName' => ['sometimes', 'nullable', 'string', 'max:255'],
        ]);

        if ($input === []) {
            return response()->json(['message' => 'At least one profile field is required.'], 422);
        }

        $payload = $shopify->graphql(
            self::UPDATE_CUSTOMER_MUTATION,
            ['input' => $input],
            $request->bearerToken(),
        )['customerUpdate'];

        if ($payload['userErrors'] !== []) {
            return response()->json(['errors' => $payload['userErrors']], 422);
        }

        return response()->json($payload['customer']);
    }
}
