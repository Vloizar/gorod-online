<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['company_id', 'city_id', 'name', 'address', 'phone', 'work_schedule', 'photos', 'latitude', 'longitude', 'status', 'archived_at'])]
class CompanyStore extends Model
{
    protected function casts(): array
    {
        return [
            'photos' => 'array',
            'latitude' => 'float',
            'longitude' => 'float',
            'archived_at' => 'datetime',
        ];
    }

    /** @return BelongsTo<Company, $this> */
    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    /** @return BelongsTo<City, $this> */
    public function city(): BelongsTo
    {
        return $this->belongsTo(City::class);
    }
}
