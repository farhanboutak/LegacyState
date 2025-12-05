CHANGELOG – Legacy State Roleplay
Versi: BETA 0.1 (05 Desember 2025)
#Fitur Baru & Perbaikan Sistem#

#- Sistem Character Selection (Multi-Character)
- Setiap akun dapat memiliki hingga 3 karakter berbeda.
- Pemain wajib memilih atau membuat karakter baru setelah login berhasil.
- Nama karakter menggunakan format RP (Firstname_Lastname) dengan validasi panjang dan underscore.
- Data karakter (nama RP, skin, uang) disimpan secara terpisah di tabel MySQL characters.

#- Perbaikan Critical Spawn & Spectating
- Menghilangkan bug “blank screen / stuck di langit” setelah memilih karakter.
- TogglePlayerSpectating dinonaktifkan secara tepat setelah karakter terpilih.
- OnPlayerRequestClass & OnPlayerRequestSpawn diblokir hingga karakter dipilih (anti-bypass).

