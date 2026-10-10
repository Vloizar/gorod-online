<?php

namespace App\Support;

use Illuminate\Support\Facades\File;

final readonly class PersonalDataConsentDocument
{
    public function __construct(
        public string $version,
        public string $content,
        public string $sha256,
    ) {}

    public static function current(): ?self
    {
        $version = config('legal.personal_data_consent.version');
        $path = config('legal.personal_data_consent.path');

        if (! is_string($version) || trim($version) === '' || ! is_string($path) || ! File::isFile($path)) {
            return null;
        }

        $content = File::get($path);

        if (trim($content) === '') {
            return null;
        }

        return new self($version, $content, hash('sha256', $content));
    }
}
