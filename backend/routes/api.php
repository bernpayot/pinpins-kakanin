<?php

use App\Http\Controllers\AccountController;
use App\Http\Controllers\ShopifyController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

Route::get('/shopify/products', [
    ShopifyController::class,
    'products',
]);

Route::get('/shopify/test', [
    ShopifyController::class,
    'test',
]);

Route::get('/products', [
    ShopifyController::class,
    'products',
]);

Route::post('/shopify/checkout', [
    ShopifyController::class,
    'checkout',
])->middleware('throttle:10,1');

Route::middleware(['shopify.customer', 'throttle:60,1'])->prefix('account')->group(function (): void {
    Route::get('/', [AccountController::class, 'show']);
    Route::get('/orders', [AccountController::class, 'orders']);
    Route::get('/addresses', [AccountController::class, 'addresses']);
    Route::post('/addresses', [AccountController::class, 'storeAddress']);
    Route::patch('/profile', [AccountController::class, 'update']);
});
