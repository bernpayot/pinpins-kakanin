<?php

use App\Http\Controllers\ShopifyController;
use Illuminate\Support\Facades\Route;

Route::get('/shopify/products', [
    ShopifyController::class,
    'products',
]);
Route::get('/shopify/products/{handle}', [
    ShopifyController::class,
    'product',
])->where('handle', '[a-z0-9-]+');
Route::get('/shopify/collections', [
    ShopifyController::class,
    'collections',
]);
Route::post('/shopify/cart/read', [ShopifyController::class, 'cart'])->middleware('throttle:60,1');
Route::post('/shopify/cart', [ShopifyController::class, 'createCart'])->middleware('throttle:20,1');
Route::post('/shopify/cart/change', [ShopifyController::class, 'changeCart'])->middleware('throttle:60,1');
Route::post('/shopify/cart/note', [ShopifyController::class, 'updateCartNote'])->middleware('throttle:60,1');
