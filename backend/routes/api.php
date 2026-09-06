<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ShopifyController;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

Route::get('/shopify/products', [
    ShopifyController::class,
    'products'
]);

Route::get('/shopify/test', [
    ShopifyController::class,
    'test'
]);

Route::get('/products', [
    ShopifyController::class,
    'products'
]);
