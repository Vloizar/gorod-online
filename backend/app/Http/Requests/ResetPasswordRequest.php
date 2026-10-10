<?php

namespace App\Http\Requests;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

class ResetPasswordRequest extends FormRequest
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
            'phone' => ['required', 'string', 'regex:/^\+?[1-9][0-9]{6,14}$/'],
            'recovery_code' => ['required', 'string', 'regex:/^[0-9]{4}$/'],
            'password' => ['required', 'string', 'min:8', 'max:1024', 'confirmed'],
            'password_confirmation' => ['required', 'string', 'min:8', 'max:1024'],
        ];
    }
}
