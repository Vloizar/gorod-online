<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('cities', function (Blueprint $table) {
            $table->id();
            $table->string('region_name');
            $table->string('district_name')->nullable();
            $table->string('name');
            $table->boolean('registration_open')->default(false);
            $table->timestamps();
            $table->unique(['region_name', 'district_name', 'name']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('cities');
    }
};
