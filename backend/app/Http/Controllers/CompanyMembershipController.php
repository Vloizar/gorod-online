<?php

namespace App\Http\Controllers;

use App\Models\CompanyBonusTransaction;
use App\Models\CompanyEntryCode;
use App\Models\CompanyMembership;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CompanyMembershipController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $memberships = CompanyMembership::query()
            ->with(['company:id,name', 'inviter:id,name'])
            ->where('user_id', $request->user()->id)
            ->orderBy('company_id')
            ->get()
            ->map(fn (CompanyMembership $membership): array => $this->present($membership));

        return response()->json(['data' => $memberships]);
    }

    public function join(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code' => ['required', 'string', 'min:4', 'max:32'],
        ]);
        $codeValue = mb_strtoupper(trim($data['code']), 'UTF-8');

        $result = DB::transaction(function () use ($request, $codeValue): array {
            $entryCode = CompanyEntryCode::query()
                ->whereRaw('upper(code) = ?', [$codeValue])
                ->lockForUpdate()
                ->first();

            if ($entryCode === null || ! $entryCode->active) {
                throw ValidationException::withMessages([
                    'code' => ['Не удалось найти действующий код компании. Проверьте код и попробуйте ещё раз.'],
                ]);
            }

            $company = $entryCode->company()->lockForUpdate()->firstOrFail();
            $user = $request->user();

            if (! $company->accepting_members) {
                throw ValidationException::withMessages([
                    'code' => ['Компания временно не принимает новых участников.'],
                ]);
            }

            $existing = CompanyMembership::query()
                ->where('company_id', $company->id)
                ->where('user_id', $user->id)
                ->first();

            if ($existing !== null) {
                return ['membership' => $existing->load(['company:id,name', 'inviter:id,name']), 'already_member' => true, 'welcome_bonus' => 0];
            }

            if ($entryCode->inviter_user_id === $user->id) {
                throw ValidationException::withMessages([
                    'code' => ['Нельзя вступить в компанию по собственному приглашению.'],
                ]);
            }

            $inviterMembership = null;
            if ($entryCode->inviter_user_id !== null) {
                $inviterMembership = CompanyMembership::query()
                    ->where('company_id', $company->id)
                    ->where('user_id', $entryCode->inviter_user_id)
                    ->first();

                if ($inviterMembership === null) {
                    throw ValidationException::withMessages([
                        'code' => ['Приглашение больше недоступно. Попросите друга прислать новый код.'],
                    ]);
                }
            }

            $membership = CompanyMembership::create([
                'company_id' => $company->id,
                'user_id' => $user->id,
                'invited_by_user_id' => $inviterMembership?->user_id,
                'second_level_user_id' => $inviterMembership?->invited_by_user_id,
                'entry_code_id' => $entryCode->id,
                'entry_source' => $entryCode->source_type,
                'bonus_balance' => $company->welcome_bonus,
                'joined_at' => now(),
            ]);

            if ($company->welcome_bonus > 0) {
                CompanyBonusTransaction::create([
                    'company_membership_id' => $membership->id,
                    'type' => 'welcome',
                    'amount' => $company->welcome_bonus,
                    'balance_after' => $company->welcome_bonus,
                    'description' => 'Приветственный бонус при вступлении',
                ]);
            }

            return [
                'membership' => $membership->load(['company:id,name', 'inviter:id,name']),
                'already_member' => false,
                'welcome_bonus' => $company->welcome_bonus,
            ];
        });

        return response()->json([
            'membership' => $this->present($result['membership']),
            'already_member' => $result['already_member'],
            'welcome_bonus' => $result['welcome_bonus'],
        ], $result['already_member'] ? 200 : 201);
    }

    /** @return array<string, mixed> */
    private function present(CompanyMembership $membership): array
    {
        return [
            'id' => $membership->id,
            'company' => [
                'id' => $membership->company->id,
                'name' => $membership->company->name,
            ],
            'bonus_balance' => $membership->bonus_balance,
            'invited_by' => $membership->inviter?->name,
            'entry_source' => $membership->entry_source,
            'joined_at' => $membership->joined_at?->toISOString(),
        ];
    }
}
