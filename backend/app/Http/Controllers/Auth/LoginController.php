<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\LoginRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;

class LoginController extends Controller
{
    /**
     * Handle the incoming request.
     */
    public function __invoke(LoginRequest $request): JsonResponse
    {
        $guard = Auth::guard('web');

        if (! $guard->once($request->validated())) {
            return response()->json(['message' => 'Invalid phone number or password.'], 401);
        }

        $user = $guard->user();

        return response()->json([
            'token' => $user->createToken('api-login')->plainTextToken,
            'token_type' => 'Bearer',
            'user' => $user,
        ]);
    }
}
