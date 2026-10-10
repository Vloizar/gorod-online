<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['user_id', 'version', 'document_sha256', 'accepted_at', 'ip_address', 'user_agent'])]
class PersonalDataConsent extends Model
{
    public const CREATED_AT = null;

    public const UPDATED_AT = null;

    protected function casts(): array
    {
        return [
            'accepted_at' => 'immutable_datetime',
        ];
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
