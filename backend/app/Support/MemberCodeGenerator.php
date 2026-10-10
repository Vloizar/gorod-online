<?php

namespace App\Support;

use App\Models\User;
use RuntimeException;

final class MemberCodeGenerator
{
    private const ALPHABET = ['А', 'Б', 'В', 'Г', 'Д', 'Е', 'Ж', 'И', 'К', 'Л', 'М', 'Н', 'П', 'Р', 'С', 'Т', 'У', 'Ю', 'Я'];

    public function generate(): string
    {
        for ($attempt = 0; $attempt < 20; $attempt++) {
            $code = self::ALPHABET[random_int(0, count(self::ALPHABET) - 1)]
                .str_pad((string) random_int(0, 99_999), 5, '0', STR_PAD_LEFT);

            if (! User::where('member_code', $code)->exists()) {
                return $code;
            }
        }

        throw new RuntimeException('Unable to generate a unique member code.');
    }
}
