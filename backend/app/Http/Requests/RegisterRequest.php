<?php

namespace App\Http\Requests;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'regex:/^\+7[0-9]{10}$/', 'unique:users,phone'],
            'city_id' => [
                'required',
                'integer',
                Rule::exists('cities', 'id')->where('registration_open', true),
            ],
            'password' => ['required', 'string', 'min:8', 'max:1024', 'confirmed'],
            'password_confirmation' => ['required', 'string', 'min:8', 'max:1024'],
            'recovery_code' => ['required', 'string', 'regex:/^[0-9]{4}$/'],
            'accepts_personal_data_consent' => ['required', 'accepted'],
            'consent_version' => ['required', 'string', 'max:40'],
            'consent_sha256' => ['required', 'string', 'regex:/^[a-f0-9]{64}$/i'],
        ];
    }
}
