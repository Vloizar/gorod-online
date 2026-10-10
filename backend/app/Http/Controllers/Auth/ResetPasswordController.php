<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\ResetPasswordRequest;
use App\Models\User;
use App\Support\RecoveryCodeHasher;
use Illuminate\Http\JsonResponse;

class ResetPasswordController extends Controller
{
    public function __invoke(ResetPasswordRequest $request): JsonResponse
    {
        $data = $request->validated();
        $user = User::where('phone', $data['phone'])->first();
        if ($user === null || $user->recovery_code_hash === null || ! RecoveryCodeHasher::matches($data['recovery_code'], $user->recovery_code_hash)) {
            return response()->json(['message' => 'Invalid phone number or recovery code.'], 401);
        }

        $user->forceFill(['password' => $data['password']])->save();
        $user->tokens()->delete();

        return response()->json(['message' => 'Password reset successfully.']);
    }
}
