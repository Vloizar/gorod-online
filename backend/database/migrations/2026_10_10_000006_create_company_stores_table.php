<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('companies', function (Blueprint $table): void {
            $table->string('short_description', 280)->nullable();
            $table->text('description')->nullable();
        });

        Schema::create('company_stores', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('city_id')->constrained()->restrictOnDelete();
            $table->string('name')->nullable();
            $table->string('address');
            $table->string('phone', 32)->nullable();
            $table->string('work_schedule')->nullable();
            $table->json('photos')->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('status', 16)->default('pending');
            $table->timestamp('archived_at')->nullable();
            $table->timestamps();
            $table->index(['company_id', 'status']);
            $table->index(['city_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('company_stores');

        Schema::table('companies', function (Blueprint $table): void {
            $table->dropColumn(['short_description', 'description']);
        });
    }
};
