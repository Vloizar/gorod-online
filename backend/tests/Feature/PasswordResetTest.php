<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_a_user_can_reset_their_password_with_their_recovery_code(): void
    {
        $user = User::factory()->create([
            'phone' => '+79991234567',
            'recovery_code_hash' => $this->hashRecoveryCode('1234'),
        ]);
        $user->createToken('existing-session');

        $this->postJson('/api/password/reset', [
            'phone' => $user->phone,
            'recovery_code' => '1234',
            'password' => 'new-secure-password',
            'password_confirmation' => 'new-secure-password',
        ])->assertOk()->assertExactJson(['message' => 'Password reset successfully.']);

        $user->refresh();
        $this->assertTrue(Hash::check('new-secure-password', $user->password));
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_the_recovery_code_hash_is_never_returned_by_the_user_endpoint(): void
    {
        $user = User::factory()->create([
            'recovery_code_hash' => $this->hashRecoveryCode('1234'),
        ]);

        $this->withToken($user->createToken('api-login')->plainTextToken)
            ->getJson('/api/user')
            ->assertOk()
            ->assertJsonMissingPath('recovery_code_hash');
    }

    public function test_unknown_phone_and_wrong_recovery_code_have_the_same_response(): void
    {
        User::factory()->create([
            'phone' => '+79991234567',
            'recovery_code_hash' => $this->hashRecoveryCode('1234'),
        ]);

        $payload = [
            'recovery_code' => '9999',
            'password' => 'new-secure-password',
            'password_confirmation' => 'new-secure-password',
        ];

        $wrongCode = $this->postJson('/api/password/reset', $payload + ['phone' => '+79991234567']);
        $unknownPhone = $this->postJson('/api/password/reset', $payload + ['phone' => '+79991234568']);

        $wrongCode->assertUnauthorized()->assertExactJson(['message' => 'Invalid phone number or recovery code.']);
        $unknownPhone->assertUnauthorized()->assertExactJson(['message' => 'Invalid phone number or recovery code.']);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_invalid_recovery_details_do_not_change_the_password(): void
    {
        $user = User::factory()->create([
            'phone' => '+79991234567',
            'recovery_code_hash' => $this->hashRecoveryCode('1234'),
        ]);

        $this->postJson('/api/password/reset', [
            'phone' => $user->phone,
            'recovery_code' => '12a4',
            'password' => 'short',
            'password_confirmation' => 'different',
        ])->assertUnprocessable()->assertJsonValidationErrors(['recovery_code', 'password']);

        $this->assertTrue(Hash::check('password', $user->refresh()->password));
    }

    public function test_password_reset_is_rate_limited(): void
    {
        $this->freezeTime();
        $payload = [
            'phone' => '+79991234567',
            'recovery_code' => '1234',
            'password' => 'new-secure-password',
            'password_confirmation' => 'new-secure-password',
        ];

        for ($attempt = 0; $attempt < 5; $attempt++) {
            $this->postJson('/api/password/reset', $payload)->assertUnauthorized();
        }

        $this->postJson('/api/password/reset', $payload)
            ->assertTooManyRequests()
            ->assertHeader('Retry-After');
    }

    private function hashRecoveryCode(string $code): string
    {
        return hash_hmac('sha256', $code, config('app.key'));
    }
}
