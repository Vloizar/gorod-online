<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Support\PersonalDataConsentDocument;
use Illuminate\Http\JsonResponse;

class ShowPersonalDataConsentController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $document = PersonalDataConsentDocument::current();

        if ($document === null) {
            return response()->json([
                'message' => 'Документ согласия ещё не подготовлен для регистрации.',
            ], 503);
        }

        return response()->json([
            'version' => $document->version,
            'content' => $document->content,
            'sha256' => $document->sha256,
        ]);
    }
}
