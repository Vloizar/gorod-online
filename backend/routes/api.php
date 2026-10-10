<?php

use App\Http\Controllers\Auth\DeleteAccountController;
use App\Http\Controllers\Auth\LoginController;
use App\Http\Controllers\Auth\RegisterController;
use App\Http\Controllers\Auth\ResetPasswordController;
use App\Http\Controllers\Auth\ShowPersonalDataConsentController;
use App\Http\Controllers\CityController;
use App\Http\Controllers\CompanyMembershipController;
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
    return $request->user()->load('city');
})->middleware('auth:sanctum');
Route::delete('/user', DeleteAccountController::class)->middleware('auth:sanctum')->name('user.delete');
Route::middleware('auth:sanctum')->prefix('companies')->name('companies.')->group(function (): void {
    Route::get('/memberships', [CompanyMembershipController::class, 'index'])->name('memberships.index');
    Route::post('/join', [CompanyMembershipController::class, 'join'])->middleware('throttle:30,1')->name('memberships.join');
});
