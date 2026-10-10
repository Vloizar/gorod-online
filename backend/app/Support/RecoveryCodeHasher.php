<?php

namespace App\Support;

final class RecoveryCodeHasher
{
    public static function digest(string $code): string
    {
        return hash_hmac('sha256', $code, (string) config('app.key'));
    }

    public static function matches(string $code, string $digest): bool
    {
        return hash_equals($digest, self::digest($code));
    }
}
