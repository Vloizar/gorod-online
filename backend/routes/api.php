<?php

use App\Http\Controllers\Auth\LoginController;
use App\Http\Controllers\Auth\ResetPasswordController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::post('/login', LoginController::class)->middleware('throttle:login')->name('login');
Route::post('/password/reset', ResetPasswordController::class)
    ->middleware('throttle:password-reset')
    ->name('password.reset');

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');
