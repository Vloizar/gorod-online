<?php

namespace Tests\Feature;

use App\Models\PersonalDataConsent;
use App\Models\User;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Tests\TestCase;

class DeleteAccountTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_authenticated_user_can_delete_their_account_and_revoke_sessions(): void
    {
        $user = User::factory()->create();
        PersonalDataConsent::create([
            'user_id' => $user->id,
            'version' => '1.0',
            'document_sha256' => str_repeat('a', 64),
            'accepted_at' => now(),
        ]);
        $token = $user->createToken('api-login')->plainTextToken;

        $this->withToken($token)->deleteJson('/api/user')
            ->assertOk()
            ->assertExactJson(['message' => 'Учётная запись удалена.']);

        $this->assertDatabaseMissing('users', ['id' => $user->id]);
        $this->assertDatabaseMissing('personal_data_consents', ['user_id' => $user->id]);
        $this->assertDatabaseCount('personal_access_tokens', 0);
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/user')->assertUnauthorized();
    }

    public function test_account_deletion_requires_authentication(): void
    {
        $this->deleteJson('/api/user')->assertUnauthorized();
        $this->assertDatabaseCount('users', 0);
    }
}
