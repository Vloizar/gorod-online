<?php

use App\Http\Controllers\Auth\LoginController;
use App\Http\Controllers\Auth\RegisterController;
use App\Http\Controllers\Auth\ResetPasswordController;
use App\Http\Controllers\Auth\ShowPersonalDataConsentController;
use App\Http\Controllers\CityController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::post('/login', LoginController::class)->middleware('throttle:login')->name('login');
Route::get('/legal/personal-data-consent', ShowPersonalDataConsentController::class)->name('legal.personal-data-consent');
Route::get('/cities', [CityController::class, 'registrationOptions'])->name('cities.registration-options');
Route::post('/register', RegisterController::class)->middleware('throttle:register')->name('register');
Route::post('/password/reset', ResetPasswordController::class)
    ->middleware('throttle:password-reset')
    ->name('password.reset');

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');
