<?php

namespace Tests\Feature;

use App\Models\City;
use App\Models\Company;
use App\Models\CompanyBonusTransaction;
use App\Models\CompanyEntryCode;
use App\Models\CompanyMembership;
use App\Models\CompanyStore;
use App\Models\User;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Tests\TestCase;

class CompanyMembershipTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_a_user_joins_a_company_by_code_and_gets_a_company_scoped_bonus_account(): void
    {
        $company = Company::create(['name' => 'Тёплый угол', 'welcome_bonus' => 75]);
        $this->createActiveStore($company);
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
        $this->createActiveStore($company);
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
        $this->createActiveStore($company);
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
        $this->createActiveStore($company);
        CompanyEntryCode::create(['company_id' => $company->id, 'code' => '654321', 'source_type' => 'store']);

        $this->actingAs($user)->postJson('/api/companies/join', ['code' => '654321'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('code');
        $this->assertDatabaseMissing('company_memberships', ['user_id' => $user->id]);
    }

    public function test_user_cannot_join_through_their_own_invitation(): void
    {
        $company = Company::create(['name' => 'Компания']);
        $this->createActiveStore($company);
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

    public function test_invitation_preview_lists_approved_stores_and_highlights_selected_city(): void
    {
        $company = Company::create([
            'name' => 'Тёплый угол',
            'short_description' => 'Кофейни и завтраки',
            'description' => 'Описание компании',
        ]);
        $cityA = $this->createCity('Мостовской');
        $cityB = $this->createCity('Лабинск');
        $cityC = $this->createCity('Курганинск');
        $inviter = User::factory()->create(['name' => 'Мария']);
        CompanyMembership::create([
            'company_id' => $company->id,
            'user_id' => $inviter->id,
            'entry_source' => 'store',
            'joined_at' => now(),
        ]);
        CompanyEntryCode::create([
            'company_id' => $company->id,
            'code' => '223344',
            'source_type' => 'friend',
            'inviter_user_id' => $inviter->id,
            'city_id' => $cityB->id,
        ]);
        CompanyStore::create([
            'company_id' => $company->id,
            'city_id' => $cityA->id,
            'name' => 'Центральная',
            'address' => 'ул. Ленина, 4',
            'photos' => ['1.jpg', '2.jpg', '3.jpg', '4.jpg', '5.jpg', '6.jpg'],
            'status' => 'active',
        ]);
        CompanyStore::create([
            'company_id' => $company->id,
            'city_id' => $cityB->id,
            'address' => 'ул. Красная, 7',
            'latitude' => 44.635,
            'longitude' => 40.735,
            'status' => 'active',
        ]);
        CompanyStore::create([
            'company_id' => $company->id,
            'city_id' => $cityC->id,
            'address' => 'ул. Новая, 1',
            'status' => 'pending',
        ]);
        $user = User::factory()->create(['city_id' => $cityC->id]);

        $this->actingAs($user)->postJson('/api/companies/invitation-preview', ['code' => '223344'])
            ->assertOk()
            ->assertJsonPath('company.name', 'Тёплый угол')
            ->assertJsonPath('company.short_description', 'Кофейни и завтраки')
            ->assertJsonPath('invited_by', 'Мария')
            ->assertJsonPath('invitation_city.name', 'Лабинск, Мостовской район, Краснодарский край')
            ->assertJsonPath('has_stores_in_user_city', false)
            ->assertJsonPath('accepting_members', true)
            ->assertJsonCount(2, 'stores')
            ->assertJsonPath('stores.0.city.name', 'Мостовской, Мостовской район, Краснодарский край')
            ->assertJsonCount(5, 'stores.0.photos')
            ->assertJsonPath('stores.1.invitation_city', true);

        $this->assertDatabaseMissing('company_memberships', ['user_id' => $user->id]);
    }

    public function test_archived_points_are_hidden_and_cannot_be_used_to_join(): void
    {
        $company = Company::create(['name' => 'Архивная компания']);
        $city = $this->createCity('Мостовской');
        $code = CompanyEntryCode::create([
            'company_id' => $company->id,
            'code' => '445566',
            'source_type' => 'store',
        ]);
        CompanyStore::create([
            'company_id' => $company->id,
            'city_id' => $city->id,
            'address' => 'ул. Старая, 1',
            'status' => 'archived',
            'archived_at' => now(),
        ]);
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/companies/invitation-preview', ['code' => $code->code])
            ->assertOk()
            ->assertJsonPath('accepting_members', false)
            ->assertJsonCount(0, 'stores');
        $this->actingAs($user)->postJson('/api/companies/join', ['code' => $code->code])
            ->assertUnprocessable();
        $this->assertDatabaseCount('company_memberships', 0);
    }

    private function createActiveStore(Company $company): CompanyStore
    {
        $city = $this->createCity();

        return CompanyStore::create([
            'company_id' => $company->id,
            'city_id' => $city->id,
            'address' => 'ул. Центральная, 1',
            'status' => 'active',
        ]);
    }

    private function createCity(string $name = 'Мостовской'): City
    {
        return City::create([
            'region_name' => 'Краснодарский край',
            'district_name' => 'Мостовской район',
            'name' => $name,
            'registration_open' => true,
        ]);
    }
}
