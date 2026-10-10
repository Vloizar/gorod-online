<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\CompanyBonusTransaction;
use App\Models\CompanyEntryCode;
use App\Models\CompanyMembership;
use App\Models\User;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Tests\TestCase;

class CompanyMembershipTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_a_user_joins_a_company_by_code_and_gets_a_company_scoped_bonus_account(): void
    {
        $company = Company::create(['name' => 'Тёплый угол', 'welcome_bonus' => 75]);
        $inviter = User::factory()->create(['name' => 'Мария Соколова']);
        CompanyMembership::create([
            'company_id' => $company->id,
            'user_id' => $inviter->id,
            'entry_source' => 'store',
            'bonus_balance' => 20,
            'joined_at' => now(),
        ]);
        $code = CompanyEntryCode::create([
            'company_id' => $company->id,
            'code' => '127654',
            'source_type' => 'friend',
            'inviter_user_id' => $inviter->id,
        ]);
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/companies/join', ['code' => ' 127654 '])
            ->assertCreated()
            ->assertJsonPath('already_member', false)
            ->assertJsonPath('welcome_bonus', 75)
            ->assertJsonPath('membership.company.name', 'Тёплый угол')
            ->assertJsonPath('membership.bonus_balance', 75)
            ->assertJsonPath('membership.invited_by', 'Мария Соколова')
            ->assertJsonPath('membership.entry_source', 'friend');

        $membership = CompanyMembership::where('user_id', $user->id)->firstOrFail();
        $this->assertSame($company->id, $membership->company_id);
        $this->assertSame($inviter->id, $membership->invited_by_user_id);
        $this->assertSame($code->id, $membership->entry_code_id);
        $this->assertDatabaseHas('company_bonus_transactions', [
            'company_membership_id' => $membership->id,
            'type' => 'welcome',
            'amount' => 75,
            'balance_after' => 75,
        ]);
    }

    public function test_second_level_inviter_is_captured_from_the_inviter_company_membership(): void
    {
        $company = Company::create(['name' => 'Компания']);
        $secondLevel = User::factory()->create();
        $inviter = User::factory()->create();
        CompanyMembership::create([
            'company_id' => $company->id,
            'user_id' => $secondLevel->id,
            'entry_source' => 'store',
            'joined_at' => now(),
        ]);
        CompanyMembership::create([
            'company_id' => $company->id,
            'user_id' => $inviter->id,
            'invited_by_user_id' => $secondLevel->id,
            'entry_source' => 'friend',
            'joined_at' => now(),
        ]);
        CompanyEntryCode::create([
            'company_id' => $company->id,
            'code' => '987654',
            'source_type' => 'friend',
            'inviter_user_id' => $inviter->id,
        ]);
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/companies/join', ['code' => '987654'])->assertCreated();

        $this->assertDatabaseHas('company_memberships', [
            'company_id' => $company->id,
            'user_id' => $user->id,
            'invited_by_user_id' => $inviter->id,
            'second_level_user_id' => $secondLevel->id,
        ]);
    }

    public function test_rejoining_is_idempotent_and_does_not_repeat_the_welcome_bonus(): void
    {
        $company = Company::create(['name' => 'Компания', 'welcome_bonus' => 10]);
        CompanyEntryCode::create([
            'company_id' => $company->id,
            'code' => '123456',
            'source_type' => 'store',
        ]);
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/companies/join', ['code' => '123456'])->assertCreated();
        $this->actingAs($user)->postJson('/api/companies/join', ['code' => '123456'])
            ->assertOk()
            ->assertJsonPath('already_member', true)
            ->assertJsonPath('welcome_bonus', 0);

        $this->assertSame(1, CompanyMembership::count());
        $this->assertSame(1, CompanyBonusTransaction::count());
    }

    public function test_user_cannot_join_with_an_invalid_code_or_when_company_is_not_accepting_members(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user)->postJson('/api/companies/join', ['code' => 'missing'])->assertUnprocessable();

        $company = Company::create(['name' => 'Закрытая', 'accepting_members' => false]);
        CompanyEntryCode::create(['company_id' => $company->id, 'code' => '654321', 'source_type' => 'store']);

        $this->actingAs($user)->postJson('/api/companies/join', ['code' => '654321'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('code');
        $this->assertDatabaseCount('company_memberships', 0);
    }

    public function test_user_cannot_join_through_their_own_invitation(): void
    {
        $company = Company::create(['name' => 'Компания']);
        $user = User::factory()->create();
        CompanyEntryCode::create([
            'company_id' => $company->id,
            'code' => '112233',
            'source_type' => 'friend',
            'inviter_user_id' => $user->id,
        ]);

        $this->actingAs($user)->postJson('/api/companies/join', ['code' => '112233'])->assertUnprocessable();
        $this->assertDatabaseCount('company_memberships', 0);
    }

    public function test_company_membership_list_is_limited_to_the_authenticated_user(): void
    {
        $company = Company::create(['name' => 'Тёплый угол']);
        $user = User::factory()->create();
        $other = User::factory()->create();
        CompanyMembership::create([
            'company_id' => $company->id,
            'user_id' => $user->id,
            'entry_source' => 'store',
            'joined_at' => now(),
        ]);
        CompanyMembership::create([
            'company_id' => $company->id,
            'user_id' => $other->id,
            'entry_source' => 'store',
            'joined_at' => now(),
        ]);

        $this->actingAs($user)->getJson('/api/companies/memberships')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.company.name', 'Тёплый угол')
            ->assertJsonPath('data.0.bonus_balance', 0);
    }
}
