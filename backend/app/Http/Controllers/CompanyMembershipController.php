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
    public function preview(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code' => ['required', 'string', 'min:4', 'max:32'],
        ]);
        $codeValue = mb_strtoupper(trim($data['code']), 'UTF-8');
        $entryCode = CompanyEntryCode::query()
            ->with(['company', 'inviter:id,name', 'city:id,region_name,district_name,name'])
            ->where('code', $codeValue)
            ->first();

        if ($entryCode === null || ! $entryCode->active) {
            return response()->json([
                'message' => 'Не удалось найти действующий код компании. Проверьте код и попробуйте ещё раз.',
            ], 404);
        }

        $company = $entryCode->company;
        if (! in_array($entryCode->source_type, ['friend', 'store'], true)) {
            return response()->json(['message' => 'Это приглашение больше недоступно.'], 404);
        }
        if ($entryCode->source_type === 'friend' && ($entryCode->inviter_user_id === null || ! CompanyMembership::query()
            ->where('company_id', $company->id)
            ->where('user_id', $entryCode->inviter_user_id)
            ->exists())) {
            return response()->json(['message' => 'Это приглашение больше недоступно.'], 404);
        }
        $company->load(['stores' => function ($query): void {
            $query->where('status', 'active')
                ->whereNull('archived_at')
                ->with('city:id,region_name,district_name,name')
                ->orderBy('city_id')
                ->orderBy('id');
        }]);
        $stores = $company->stores;

        return response()->json([
            'company' => [
                'id' => $company->id,
                'name' => $company->name,
                'short_description' => $company->short_description,
                'description' => $company->description,
            ],
            'invited_by' => $entryCode->inviter?->name,
            'invitation_city' => $entryCode->city === null ? null : [
                'id' => $entryCode->city->id,
                'name' => $entryCode->city->display_name,
            ],
            'has_stores_in_user_city' => $stores->contains('city_id', $request->user()->city_id),
            'accepting_members' => $company->accepting_members && $stores->isNotEmpty(),
            'already_member' => CompanyMembership::query()
                ->where('company_id', $company->id)
                ->where('user_id', $request->user()->id)
                ->exists(),
            'stores' => $stores->map(fn ($store): array => [
                'id' => $store->id,
                'name' => $store->name,
                'address' => $store->address,
                'phone' => $store->phone,
                'work_schedule' => $store->work_schedule,
                'photos' => array_slice($store->photos ?? [], 0, 5),
                'latitude' => $store->latitude,
                'longitude' => $store->longitude,
                'city' => [
                    'id' => $store->city->id,
                    'name' => $store->city->display_name,
                ],
                'invitation_city' => $entryCode->city_id === $store->city_id,
            ])->values(),
        ]);
    }

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
                ->where('code', $codeValue)
                ->lockForUpdate()
                ->first();

            if ($entryCode === null || ! $entryCode->active) {
                throw ValidationException::withMessages([
                    'code' => ['Не удалось найти действующий код компании. Проверьте код и попробуйте ещё раз.'],
                ]);
            }

            $company = $entryCode->company()->lockForUpdate()->firstOrFail();
            $user = $request->user();

            $existing = CompanyMembership::query()
                ->where('company_id', $company->id)
                ->where('user_id', $user->id)
                ->first();

            if ($existing !== null) {
                return ['membership' => $existing->load(['company:id,name', 'inviter:id,name']), 'already_member' => true, 'welcome_bonus' => 0];
            }

            if (! in_array($entryCode->source_type, ['friend', 'store'], true)) {
                throw ValidationException::withMessages([
                    'code' => ['Это приглашение больше недоступно.'],
                ]);
            }

            $hasActiveStores = $company->stores()
                ->where('status', 'active')
                ->whereNull('archived_at')
                ->exists();

            if (! $company->accepting_members || ! $hasActiveStores) {
                throw ValidationException::withMessages([
                    'code' => ['Компания временно не принимает новых участников.'],
                ]);
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
            } elseif ($entryCode->source_type === 'friend') {
                throw ValidationException::withMessages([
                    'code' => ['Приглашение больше недоступно. Попросите друга прислать новый код.'],
                ]);
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
