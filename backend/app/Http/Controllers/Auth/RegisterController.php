<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\RegisterRequest;
use App\Models\PersonalDataConsent;
use App\Models\User;
use App\Support\MemberCodeGenerator;
use App\Support\PersonalDataConsentDocument;
use App\Support\RecoveryCodeHasher;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class RegisterController extends Controller
{
    public function __invoke(RegisterRequest $request, MemberCodeGenerator $memberCodes): JsonResponse
    {
        $document = PersonalDataConsentDocument::current();

        if ($document === null) {
            return response()->json([
                'message' => 'Регистрация временно недоступна: документ согласия не утверждён.',
            ], 503);
        }

        $data = $request->validated();

        if ($data['consent_version'] !== $document->version || ! hash_equals($document->sha256, $data['consent_sha256'])) {
            return response()->json([
                'message' => 'Текст согласия обновился. Откройте его и подтвердите ещё раз.',
            ], 409);
        }

        $user = DB::transaction(function () use ($data, $document, $request, $memberCodes): User {
            $user = User::create([
                'name' => $data['name'],
                'phone' => $data['phone'],
                'city_id' => $data['city_id'],
                'password' => $data['password'],
                'member_code' => $memberCodes->generate(),
            ]);

            $user->forceFill([
                'recovery_code_hash' => RecoveryCodeHasher::digest($data['recovery_code']),
            ])->save();

            PersonalDataConsent::create([
                'user_id' => $user->id,
                'version' => $document->version,
                'document_sha256' => $document->sha256,
                'accepted_at' => now(),
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);

            $user->load('city');

            return $user;
        });

        return response()->json([
            'token' => $user->createToken('api-registration')->plainTextToken,
            'token_type' => 'Bearer',
            'user' => $user,
        ], 201);
    }
}
