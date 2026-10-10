<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('companies', function (Blueprint $table): void {
            $table->id();
            $table->string('name');
            $table->boolean('accepting_members')->default(true);
            $table->unsignedInteger('welcome_bonus')->default(0);
            $table->timestamps();
        });

        Schema::create('company_entry_codes', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->string('code', 32)->unique();
            $table->string('source_type', 16)->default('friend');
            $table->foreignId('inviter_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('city_id')->nullable()->constrained()->nullOnDelete();
            $table->boolean('active')->default(true);
            $table->timestamps();
            $table->index(['company_id', 'active']);
        });

        Schema::create('company_memberships', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('invited_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('second_level_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('entry_code_id')->nullable()->constrained('company_entry_codes')->nullOnDelete();
            $table->string('entry_source', 16);
            $table->unsignedBigInteger('bonus_balance')->default(0);
            $table->timestamp('joined_at');
            $table->timestamps();
            $table->unique(['company_id', 'user_id']);
            $table->index(['company_id', 'invited_by_user_id']);
        });

        Schema::create('company_bonus_transactions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('company_membership_id')->constrained()->cascadeOnDelete();
            $table->string('type', 24);
            $table->bigInteger('amount');
            $table->unsignedBigInteger('balance_after');
            $table->string('description');
            $table->timestamps();
            $table->index(['company_membership_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('company_bonus_transactions');
        Schema::dropIfExists('company_memberships');
        Schema::dropIfExists('company_entry_codes');
        Schema::dropIfExists('companies');
    }
};
