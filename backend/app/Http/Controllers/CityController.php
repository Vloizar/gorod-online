<?php

namespace App\Http\Controllers;

use App\Models\City;
use Illuminate\Http\JsonResponse;

class CityController extends Controller
{
    public function registrationOptions(): JsonResponse
    {
        $cities = City::query()
            ->where('registration_open', true)
            ->orderBy('region_name')
            ->orderBy('district_name')
            ->orderBy('name')
            ->get(['id', 'name', 'district_name', 'region_name']);

        return response()->json([
            'data' => $cities->map(fn (City $city): array => [
                'id' => $city->id,
                'name' => $city->name,
                'district' => $city->district_name,
                'region' => $city->region_name,
                'display_name' => $city->display_name,
            ]),
        ]);
    }
}
