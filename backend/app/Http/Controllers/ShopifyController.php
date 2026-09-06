<?php

namespace App\Http\Controllers;

use App\Services\ShopifyService;

class ShopifyController extends Controller
{
    public function products(ShopifyService $shopify)
    {
        return response()->json($shopify->getProducts());
    }

    public function test(ShopifyService $shopify)
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
