<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['region_name', 'district_name', 'name', 'registration_open'])]
class City extends Model
{
    protected $appends = ['display_name'];

    protected function casts(): array
    {
        return [
            'registration_open' => 'boolean',
        ];
    }

    /** @return HasMany<User, $this> */
    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    public function getDisplayNameAttribute(): string
    {
        return collect([$this->name, $this->district_name, $this->region_name])
            ->filter()
            ->unique()
            ->implode(', ');
    }
}
