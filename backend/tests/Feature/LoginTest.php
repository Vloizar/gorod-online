<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Laravel\Sanctum\PersonalAccessToken;
use PHPUnit\Framework\Attributes\TestWith;
use Tests\TestCase;

class LoginTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_login_returns_a_token_that_authenticates_the_user(): void
    {
        $user = User::factory()->create();

        $response = $this->postJson('/api/login', [
            'phone' => $user->phone,
            'password' => 'password',
            'email' => 'ignored@example.com',
        ])->assertOk()->assertJsonPath('token_type', 'Bearer')
            ->assertJsonPath('user.id', $user->id)
            ->assertJsonPath('user.phone', $user->phone)
            ->assertJsonMissingPath('user.password')
            ->assertJsonMissingPath('user.remember_token');

        $token = $response->json('token');
        $storedToken = PersonalAccessToken::findToken($token);
        $this->assertNotNull($storedToken);
        $this->assertTrue($storedToken->tokenable->is($user));
        $this->assertDatabaseCount('personal_access_tokens', 1);
        $this->assertNotSame($token, $storedToken->token);

        Auth::forgetGuards();
        $this->withToken($token)->getJson('/api/user')
            ->assertOk()->assertJsonPath('id', $user->id);
    }

    #[TestWith([true])]
    #[TestWith([false])]
    public function test_invalid_credentials_do_not_issue_a_token(bool $existingUser): void
    {
        $phone = '+79991234567';
        if ($existingUser) {
            User::factory()->create(['phone' => $phone]);
        }

        $this->postJson('/api/login', ['phone' => $phone, 'password' => 'wrong-password'])
            ->assertUnauthorized()
            ->assertExactJson(['message' => 'Invalid phone number or password.']);

        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    #[TestWith([[], ['phone', 'password']])]
    #[TestWith([['phone' => 'not-a-phone', 'password' => 'password'], ['phone']])]
    #[TestWith([['phone' => '+79991234567', 'password' => []], ['password']])]
    #[TestWith([['phone' => 79991234567, 'password' => 'password'], ['phone']])]
    #[TestWith([['phone' => '+79991234567', 'password' => ''], ['password']])]
    public function test_invalid_input_returns_json_validation_errors(array $input, array $fields): void
    {
        $this->post('/api/login', $input)->assertUnprocessable()->assertJsonValidationErrors($fields);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_login_is_limited_to_five_requests_per_minute_per_ip(): void
    {
        $this->freezeTime();
        $credentials = ['phone' => '+79991234567', 'password' => 'wrong-password'];

        for ($attempt = 0; $attempt < 5; $attempt++) {
            $this->postJson('/api/login', $credentials)->assertUnauthorized();
        }

        $this->postJson('/api/login', $credentials)->assertTooManyRequests()->assertHeader('Retry-After');
        $this->assertDatabaseCount('personal_access_tokens', 0);

        $this->travel(61)->seconds();
        $this->postJson('/api/login', $credentials)->assertUnauthorized();
    }

    public function test_user_endpoint_rejects_missing_or_invalid_tokens(): void
    {
        $this->getJson('/api/user')->assertUnauthorized();
        $this->withToken('invalid-token')->getJson('/api/user')->assertUnauthorized();
    }
}
