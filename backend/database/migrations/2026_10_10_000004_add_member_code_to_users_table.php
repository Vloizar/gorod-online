<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const ALPHABET = ['А', 'Б', 'В', 'Г', 'Д', 'Е', 'Ж', 'И', 'К', 'Л', 'М', 'Н', 'П', 'Р', 'С', 'Т', 'У', 'Ю', 'Я'];

    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->string('member_code', 6)->nullable();
        });

        DB::table('users')->whereNull('member_code')->orderBy('id')->chunkById(100, function ($users): void {
            foreach ($users as $user) {
                do {
                    $code = self::ALPHABET[random_int(0, count(self::ALPHABET) - 1)]
                        .str_pad((string) random_int(0, 99999), 5, '0', STR_PAD_LEFT);
                } while (DB::table('users')->where('member_code', $code)->exists());

                DB::table('users')->where('id', $user->id)->update(['member_code' => $code]);
            }
        });

        Schema::table('users', function (Blueprint $table): void {
            $table->unique('member_code');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropUnique(['member_code']);
            $table->dropColumn('member_code');
        });
    }
};
