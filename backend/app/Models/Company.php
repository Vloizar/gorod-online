<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['name', 'accepting_members', 'welcome_bonus', 'short_description', 'description'])]
class Company extends Model
{
    protected function casts(): array
    {
        return ['accepting_members' => 'boolean', 'welcome_bonus' => 'integer'];
    }

    /** @return HasMany<CompanyMembership, $this> */
    public function memberships(): HasMany
    {
        return $this->hasMany(CompanyMembership::class);
    }

    /** @return HasMany<CompanyEntryCode, $this> */
    public function entryCodes(): HasMany
    {
        return $this->hasMany(CompanyEntryCode::class);
    }

    /** @return HasMany<CompanyStore, $this> */
    public function stores(): HasMany
    {
        return $this->hasMany(CompanyStore::class);
    }
}
