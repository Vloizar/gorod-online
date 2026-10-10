<?php

namespace Tests\Feature;

use App\Models\City;
use App\Models\PersonalDataConsent;
use App\Support\PersonalDataConsentDocument;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

class RegistrationTest extends TestCase
{
    use LazilyRefreshDatabase;

    private City $openCity;

    protected function setUp(): void
    {
        parent::setUp();

        $this->openCity = City::create([
            'region_name' => 'Краснодарский край',
            'district_name' => 'Мостовской район',
            'name' => 'Мостовской',
            'registration_open' => true,
        ]);
    }

    public function test_registration_shows_only_open_cities(): void
    {
        City::create([
            'region_name' => 'Краснодарский край',
            'district_name' => 'Мостовской район',
            'name' => 'Закрытое поселение',
            'registration_open' => false,
        ]);

        $this->getJson('/api/cities')->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.display_name', 'Мостовской, Мостовской район, Краснодарский край');
    }

    public function test_registration_is_disabled_until_a_consent_document_is_configured(): void
    {
        config(['legal.personal_data_consent.version' => null, 'legal.personal_data_consent.path' => null]);

        $this->getJson('/api/legal/personal-data-consent')->assertServiceUnavailable();
        $this->postJson('/api/register', $this->registrationPayload())->assertServiceUnavailable();

        $this->assertDatabaseCount('users', 0);
        $this->assertDatabaseCount('personal_data_consents', 0);
    }

    public function test_registration_records_the_exact_consent_and_issues_a_token(): void
    {
        $consentPath = tempnam(sys_get_temp_dir(), 'consent-');
        file_put_contents($consentPath, 'Test consent document v1');
        config([
            'legal.personal_data_consent.version' => '1.0',
            'legal.personal_data_consent.path' => $consentPath,
        ]);

        try {
            $document = PersonalDataConsentDocument::current();
            $this->assertNotNull($document);
            $this->getJson('/api/legal/personal-data-consent')->assertOk()
                ->assertJsonPath('version', '1.0')
                ->assertJsonPath('content', 'Test consent document v1')
                ->assertJsonPath('sha256', $document->sha256);

            $response = $this->postJson('/api/register', $this->registrationPayload([
                'consent_version' => '1.0',
                'consent_sha256' => $document->sha256,
            ]))->assertCreated()
                ->assertJsonPath('user.phone', '+79900000001')
                ->assertJsonPath('user.city_id', $this->openCity->id)
                ->assertJsonMissingPath('user.password')
                ->assertJsonMissingPath('user.recovery_code_hash');

            $this->assertDatabaseHas('personal_data_consents', [
                'user_id' => $response->json('user.id'),
                'version' => '1.0',
                'document_sha256' => $document->sha256,
            ]);
            $this->assertSame(1, PersonalDataConsent::count());
            $token = PersonalAccessToken::findToken($response->json('token'));
            $this->assertNotNull($token);
            $this->assertSame(1, $token->tokenable_id);
        } finally {
            @unlink($consentPath);
        }
    }

    public function test_registration_rejects_closed_city_or_stale_consent_without_creating_account(): void
    {
        $consentPath = tempnam(sys_get_temp_dir(), 'consent-');
        file_put_contents($consentPath, 'Test consent document v1');
        config([
            'legal.personal_data_consent.version' => '1.0',
            'legal.personal_data_consent.path' => $consentPath,
        ]);

        try {
            $document = PersonalDataConsentDocument::current();
            $payload = $this->registrationPayload([
                'consent_version' => 'outdated',
                'consent_sha256' => $document->sha256,
            ]);
            $this->postJson('/api/register', $payload)->assertStatus(409);

            $closedCity = City::create([
                'region_name' => 'Краснодарский край',
                'district_name' => null,
                'name' => 'Закрыт',
                'registration_open' => false,
            ]);
            $this->postJson('/api/register', $this->registrationPayload([
                'city_id' => $closedCity->id,
                'consent_version' => '1.0',
                'consent_sha256' => $document->sha256,
            ]))->assertUnprocessable()->assertJsonValidationErrors('city_id');

            $this->assertDatabaseCount('users', 0);
            $this->assertDatabaseCount('personal_data_consents', 0);
            $this->assertDatabaseCount('personal_access_tokens', 0);
        } finally {
            @unlink($consentPath);
        }
    }

    private function registrationPayload(array $overrides = []): array
    {
        return array_replace([
            'name' => 'Андрей',
            'phone' => '+79900000001',
            'city_id' => $this->openCity->id,
            'password' => 'very-secure-password',
            'password_confirmation' => 'very-secure-password',
            'recovery_code' => '1234',
            'accepts_personal_data_consent' => true,
            'consent_version' => '1.0',
            'consent_sha256' => str_repeat('a', 64),
        ], $overrides);
    }
}
