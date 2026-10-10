<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['company_id', 'user_id', 'invited_by_user_id', 'second_level_user_id', 'entry_code_id', 'entry_source', 'bonus_balance', 'joined_at'])]
class CompanyMembership extends Model
{
    protected function casts(): array
    {
        return ['bonus_balance' => 'integer', 'joined_at' => 'datetime'];
    }

    /** @return BelongsTo<Company, $this> */
    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    /** @return BelongsTo<User, $this> */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** @return BelongsTo<User, $this> */
    public function inviter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'invited_by_user_id');
    }

    /** @return HasMany<CompanyBonusTransaction, $this> */
    public function bonusTransactions(): HasMany
    {
        return $this->hasMany(CompanyBonusTransaction::class);
    }
}
