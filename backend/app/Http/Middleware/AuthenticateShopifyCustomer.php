<?php

namespace App\Http\Middleware;

use App\Services\ShopifyCustomerService;
use Closure;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AuthenticateShopifyCustomer
{
    public function __construct(private ShopifyCustomerService $shopify) {}

    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $accessToken = $request->bearerToken();

        if ($accessToken === null) {
            throw new AuthenticationException('Shopify customer token is required.');
        }

        $customer = $this->shopify->currentCustomer($accessToken);

        if ($customer === []) {
            throw new AuthenticationException('Invalid or expired Shopify customer token.');
        }

        $request->attributes->set('shopifyCustomer', $customer);

        return $next($request);
    }
}
