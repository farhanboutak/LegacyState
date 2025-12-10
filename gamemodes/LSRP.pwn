
// ========================================
// LSRP BETA 0.7.5 - BETA
// ========================================

#define DIALOG_TELEPORT    5000
#define DIALOG_REGISTER    5001
#define DIALOG_LOGIN       5002
#define DIALOG_PAY         5003
#define DIALOG_CHARLIST    5004
#define DIALOG_CHARCREATE  5005
#define DIALOG_CHAR_ACTION 5006
#define DIALOG_CHAR_DELETE 5007
#define DIALOG_GENDER      5008
#define DIALOG_BIRTHDATE   5009
#define DIALOG_SKIN        5010
#define DIALOG_ARRIVAL     5011
#define DIALOG_MENU_UTAMA       9000
#define DIALOG_INFO_SERVER      9001
#define DIALOG_TUKAR_KODE       9002
#define DIALOG_ATM              9003
#define DIALOG_STATS            9004
#define DIALOG_HELP             9005
#define DIALOG_SET_KODE         9005
#define DIALOG_SET_REWARD       9006
#define MAX_REPORTS     50
#define REPORT_COOLDOWN 60 // detik

#define COLOR_WHITE        0xFFFFFFFF
#define COLOR_RED          0xFF0000FF
#define COLOR_GREEN        0x00FF00FF
#define COLOR_YELLOW       0xFFFF00FF

#include <a_samp>
#include <a_mysql>
#include <sscanf2>
#include <zcmd>
#include <whirlpool>
#include <TimestampToDate>
#include <foreach>
#include <crashdetect>


#define SQL_HOST    "localhost"
#define SQL_USER    "root"
#define SQL_PASS    ""
#define SQL_DB      "samp"
#define MAX_CHARS   3

new MySQL:sqldb;

new ReportText[MAX_REPORTS][128];
new ReportPlayer[MAX_REPORTS];
new ReportTime[MAX_REPORTS];
new ReportCount = 0;
new LastReportTime[MAX_PLAYERS];


new tempProposedName[MAX_PLAYERS][24]; // untuk menyimpan nama yang sedang dicek

// pemilihan karakter
new pCurrentPreviewClass[MAX_PLAYERS];
new bool:inSkinClassSelection[MAX_PLAYERS];
new bool:inArrivalClassSelection[MAX_PLAYERS];

new bool:pLogged[MAX_PLAYERS char];
new pLoginAttempts[MAX_PLAYERS];
new pMoney[MAX_PLAYERS];
new Text:UI[3];

new pCharID[MAX_PLAYERS][MAX_CHARS];
new pCharName[MAX_PLAYERS][MAX_CHARS][24];
new pCharSkin[MAX_PLAYERS][MAX_CHARS];
new pSelectedChar[MAX_PLAYERS] = {-1, ...};

new tempCharName[MAX_PLAYERS][24];
new tempGender[MAX_PLAYERS];
new tempBirthdate[MAX_PLAYERS][11];
new tempSkinIndex[MAX_PLAYERS];
new tempArrivalIndex[MAX_PLAYERS];
new tempSkin[MAX_PLAYERS];
new bool:isCreating[MAX_PLAYERS];

// Ganti variabel lama tpX/tpY/tpZ jadi ini (lebih aman & jelas)
new Float:g_LastMapClick[3][MAX_PLAYERS]; // [0]=X, [1]=Y, [2]=Z



new RandomCars[] = {
    400,401,402,404,405,409,411,412,415,418,419,420,421,422,424,426,429,434,436,439,
    442,445,451,458,466,467,474,475,477,478,479,480,489,491,492,496,500,506,507,516,
    517,518,527,529,533,540,541,542,545,546,547,549,550,551,554,555,558,559,560,561,
    562,565,567,575,576,579,580,585,587,589,600,602,603
};

static const MaleSkins[10] = {1, 2, 7, 14, 15, 16, 17, 18, 19, 20};
static const FemaleSkins[10] = {9, 10, 11, 12, 13, 31, 38, 39, 40, 41};

static const ArrivalNames[3][] = {
    "Los Santos Airport",
    "Los Santos Market Station",
    "Los Santos Unity Station"
};

static const Float:ArrivalCoords[3][4] = {
    {1682.0001, -2330.7502, 13.5469, 358.5358},
    {821.4300, -1341.1800, 12.3200, 90.0000},
    {1759.5500, -1945.7900, 13.5600, 270.0000}
};

static const WeekDayName[7][4] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
static const MonthName[12][4] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};

// === FUNGSI GANTI UNDERSCORE KE SPASI ===
stock ReplaceUnderscore(string[])
{
    for(new i = 0, j = strlen(string); i < j; i++)
    {
        if(string[i] == '_') string[i] = ' ';
    }
}

stock LogAdminAction(adminid, action[])
{
    new log[256], adminname[MAX_PLAYER_NAME], year, month, day, hour, minute, second;
    GetPlayerName(adminid, adminname, sizeof(adminname));
    getdate(year, month, day);
    gettime(hour, minute, second);
    
    format(log, sizeof(log), "[%04d-%02d-%02d %02d:%02d:%02d] %s: %s\r\n",
        year, month, day, hour, minute, second, adminname, action);
        
    new File:f = fopen("scriptfiles/admin_logs.txt", io_append);
    if(f) { fwrite(f, log); fclose(f); }
}

stock GetWeekDay(timestamp) {
    return ((timestamp / 86400) % 7 + 4) % 7; // 0=Sun, 1=Mon, ..., 6=Sat
}

// === AMAN BUAT UANG (GUNAKAN INI DI SEMUA TEMPAT) ===
stock SetPlayerMoney(playerid, money)
{
    pMoney[playerid] = money;
    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, money);
}

main() {
    print("\n==================================");
    print(" LSRP BETA 0.7.5 - Fitur Baru!    ");
    print("==================================\n");
}

new pAccountName[MAX_PLAYERS][MAX_PLAYER_NAME];

// === ADMIN SYSTEM ===
new pAdminLevel[MAX_PLAYERS];
new bool:pAdminDuty[MAX_PLAYERS];
new pUCPName[MAX_PLAYERS][MAX_PLAYER_NAME]; // Simpan UCP permanen

new pSpecTarget[MAX_PLAYERS] = {-1, ...}; // Siapa yang lagi di-spectate
new bool:pSpectating[MAX_PLAYERS];

public OnGameModeInit()
{
    SetGameModeText("LS|RP BETA 0.7.5 Fitur Baru!");

    sqldb = mysql_connect(SQL_HOST, SQL_USER, SQL_PASS, SQL_DB);
    if(mysql_errno(sqldb)) print("[MySQL] Koneksi GAGAL!");
    else print("[MySQL] Koneksi Berhasil!");

    // Create tables if not exist
    mysql_tquery(sqldb, "CREATE TABLE IF NOT EXISTS users (name VARCHAR(24) PRIMARY KEY, password VARCHAR(129))");
    mysql_tquery(sqldb, "CREATE TABLE IF NOT EXISTS characters (id INT AUTO_INCREMENT PRIMARY KEY, owner VARCHAR(24), charname VARCHAR(24), skin INT, money INT, lastlogin INT)");

    // Create premium_codes table if not exist
mysql_tquery(sqldb, "CREATE TABLE IF NOT EXISTS premium_codes (code VARCHAR(32) PRIMARY KEY, reward INT DEFAULT 0, used TINYINT DEFAULT 0)");
    // Add birthdate column if not exists
    mysql_tquery(sqldb, "ALTER TABLE characters ADD COLUMN IF NOT EXISTS birthdate VARCHAR(10) NOT NULL DEFAULT ''");

    // Tambah kolom posisi spawn
    mysql_tquery(sqldb, "ALTER TABLE characters ADD COLUMN IF NOT EXISTS pos_x FLOAT DEFAULT 1682.0001");
    mysql_tquery(sqldb, "ALTER TABLE characters ADD COLUMN IF NOT EXISTS pos_y FLOAT DEFAULT -2330.7502");
    mysql_tquery(sqldb, "ALTER TABLE characters ADD COLUMN IF NOT EXISTS pos_z FLOAT DEFAULT 13.5469");
    mysql_tquery(sqldb, "ALTER TABLE characters ADD COLUMN IF NOT EXISTS pos_a FLOAT DEFAULT 358.5358");

    // Membuat charname unik di database (mencegah race condition)
    mysql_tquery(sqldb, "ALTER TABLE characters ADD UNIQUE IF NOT EXISTS unique_charname (charname)");

    // === INI YANG PENTING: MENGHILANGKAN BLIPS PLAYER DI MINIMAP ===
    ShowPlayerMarkers(0); // 100% menghilangkan semua panah player di radar (cara paling umum & pasti jalan)

    // Kalau kamu pakai SA-MP 0.3.7 R3 atau lebih baru, boleh pakai baris di bawah ini saja (ganti yang atas):
    // DisablePlayerMarkersForAll();

    UI[0] = TextDrawCreate(267.0, 5.0, "Legacy");
    TextDrawFont(UI[0], 0); TextDrawLetterSize(UI[0], 0.404166, 1.450000);
    TextDrawColor(UI[0], -1); TextDrawSetOutline(UI[0], 1); TextDrawSetProportional(UI[0], 1);

    UI[1] = TextDrawCreate(269.0, 17.0, "State");
    TextDrawFont(UI[1], 3); TextDrawLetterSize(UI[1], 0.404166, 1.500000);
    TextDrawColor(UI[1], -1); TextDrawSetOutline(UI[1], 1); TextDrawSetProportional(UI[1], 1);

    UI[2] = TextDrawCreate(314.0, 17.0, "Roleplay");
    TextDrawFont(UI[2], 3); TextDrawLetterSize(UI[2], 0.404166, 1.450000);
    TextDrawColor(UI[2], -1); TextDrawSetOutline(UI[2], 1); TextDrawSetProportional(UI[2], 1);

    SetTimer("PayDay", 600000, true);
    
    return 1;
}

public OnPlayerClickMap(playerid, Float:fX, Float:fY, Float:fZ)
{
    // Simpan koordinat yang diklik
    g_LastMapClick[0][playerid] = fX;
    g_LastMapClick[1][playerid] = fY;
    g_LastMapClick[2][playerid] = fZ;

    // Tampilkan koordinat ke player
    new msg[256];
    format(msg, sizeof(msg), 
        "{FFD700}[MAP KLIK] {FFFFFF}Koordinat tersimpan: {00FF00}X: %.4f | Y: %.4f | Z: %.4f",
        fX, fY, fZ
    );
    SendClientMessage(playerid, -1, msg);

    return 1;
}

public OnPlayerConnect(playerid)
{
    new name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));

    // ========================== FIX NAMA SETELAH GMX / RESTART ==========================
    // Kalau player masuk dengan nama karakter (ada underscore) → cari UCP aslinya
    if(strfind(name, "_") != -1)
    {
        new query[128];
        mysql_format(sqldb, query, sizeof(query), 
            "SELECT owner FROM characters WHERE charname = '%e' LIMIT 1", name);
        mysql_tquery(sqldb, query, "OnFixGMXName", "i", playerid);
        
        // JANGAN LANJUTKAN proses di bawah ini dulu, tunggu callback selesai
        return 1;
    }
    // ==================================================================================

    // Jika masuk dengan nama UCP (normal atau pertama kali setelah restart)
    return ContinuePlayerConnect(playerid, name);
}

// Fungsi terpisah biar rapi & tidak berantakan
stock ContinuePlayerConnect(playerid, const name[])
{
    // Cek anti name changer (launcher)
    if(strcmp(name, pUCPName[playerid], true) != 0 && pUCPName[playerid][0] != EOS)
    {
        SendClientMessage(playerid, COLOR_RED, "Jangan ganti nama di launcher SA-MP!");
        Kick(playerid);
        return 1;
    }

    // Simpan UCP asli
    format(pUCPName[playerid], MAX_PLAYER_NAME, "%s", name);
    format(pAccountName[playerid], MAX_PLAYER_NAME, "%s", name);

    // === ANTI DUPLIKAT LOGIN ===
    for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if(i != playerid && IsPlayerConnected(i))
        {
            if(!strcmp(pAccountName[playerid], pAccountName[i], true))
            {
                SendClientMessage(playerid, COLOR_RED, "[SERVER] Akun ini sedang digunakan oleh pemain lain. Silakan tunggu atau gunakan akun lain.");
                SetTimerEx("DelayedKick", 1000, false, "i", playerid);
                return 1;
            }
        }
    }

    // Reset variabel player
    pLogged{playerid} = false;
    pLoginAttempts[playerid] = 0;
    pSelectedChar[playerid] = -1;
    pAdminLevel[playerid] = 0;
    pAdminDuty[playerid] = false;

    format(tempCharName[playerid], 24, "");
    tempGender[playerid] = 0;
    format(tempBirthdate[playerid], 11, "");
    tempSkinIndex[playerid] = 0;
    tempArrivalIndex[playerid] = 0;
    tempSkin[playerid] = 0;
    isCreating[playerid] = false;

    // Textdraw UI
    for(new i = 0; i < 3; i++) TextDrawShowForPlayer(playerid, UI[i]);

    TogglePlayerSpectating(playerid, 1);
    SetPlayerColor(playerid, 0x00000000); // sembunyikan dari tablist sampai login

    // Query login + admin level
    new query[256];
    mysql_format(sqldb, query, sizeof(query),
        "SELECT u.password, COALESCE(a.level, 0) AS adminlevel \
         FROM users u \
         LEFT JOIN admins a ON u.name = a.ucp_name \
         WHERE u.name = '%e' LIMIT 1", name);
    mysql_tquery(sqldb, query, "OnPlayerDataCheck", "i", playerid);

    pMoney[playerid] = 0;

    return 1;
}

// Callback untuk memperbaiki nama setelah GMX
forward OnFixGMXName(playerid);
public OnFixGMXName(playerid)
{
    new currentname[MAX_PLAYER_NAME];
    GetPlayerName(playerid, currentname, sizeof(currentname));

    if(cache_num_rows() > 0)
    {
        new ucp_name[24];
        cache_get_value_name(0, "owner", ucp_name, sizeof(ucp_name));

        // Ganti nama jadi UCP asli
        SetPlayerName(playerid, ucp_name);

        SendClientMessage(playerid, 0xFF6347FF, "[ANTI-CHEAT] Nama kamu telah dikembalikan ke UCP asli setelah restart server.");
        SendClientMessage(playerid, -1, "{33CCFF}[SERVER]{FFFFFF} Silahkan login dengan password UCP kamu.");

        // Lanjutkan proses login normal dengan nama UCP yang benar
        ContinuePlayerConnect(playerid, ucp_name);
    }
    else
    {
        // Nama karakter tidak ditemukan di database → kemungkinan cheat
        SendClientMessage(playerid, COLOR_RED, "[SERVER] Nama tidak valid! Gunakan nama UCP asli di launcher.");
        SetTimerEx("DelayedKick", 1000, false, "i", playerid);
    }
    return 1;
}

// Tambah ini jika belum ada (untuk reset variabel saat disconnect)
public OnPlayerDisconnect(playerid, reason)
{
    // Reset report yang dibuat player ini
    for(new i = 0; i < MAX_REPORTS; i++)
    {
        if(ReportPlayer[i] == playerid)
        {
            ReportPlayer[i] = -1;
            ReportText[i][0] = EOS;
        }
    }
    LastReportTime[playerid] = 0;

    // Reset koordinat klik map
    g_LastMapClick[0][playerid] = 0.0;
    g_LastMapClick[1][playerid] = 0.0;
    g_LastMapClick[2][playerid] = 0.0;
    if(pLogged{playerid} && pSelectedChar[playerid] != -1)
    {
        new query[128];
        mysql_format(sqldb, query, sizeof(query), 
            "UPDATE characters SET money = %d WHERE id = %d", 
            pMoney[playerid], pCharID[playerid][pSelectedChar[playerid]]);
        mysql_tquery(sqldb, query);
    }


    // === SPECTATE: Matikan jika ada admin yang sedang spectate player ini ===
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i) && pSpectating[i] && pSpecTarget[i] == playerid)
        {
            SendClientMessage(i, COLOR_RED, "Player yang kamu spectate telah keluar dari server.");
            pSpectating[i] = false;
            pSpecTarget[i] = -1;
            TogglePlayerControllable(i, 1);
            SpawnPlayer(i); // Kembalikan admin ke posisi semula
        }
    }

    // Reset variabel spectate admin yang disconnect (jika dia lagi spectate orang lain)
    pSpectating[playerid] = false;
    pSpecTarget[playerid] = -1;

    format(pAccountName[playerid], MAX_PLAYER_NAME, ""); // Reset UCP
    format(pUCPName[playerid], MAX_PLAYER_NAME, "");     // Reset UCP admin duty

    pLogged{playerid} = false;
    pSelectedChar[playerid] = -1;
    pAdminDuty[playerid] = false;
    pAdminLevel[playerid] = 0;

        // === LOG DISCONNECT DI DEKAT PLAYER ===
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    new dcname[MAX_PLAYER_NAME], str[128], reasontext[20];

    GetPlayerName(playerid, dcname, sizeof(dcname));
    ReplaceUnderscore(dcname);

    switch(reason)
    {
        case 0: reasontext = "Timeout/Crash";
        case 1: reasontext = "Keluar";
        case 2: reasontext = "Kicked/Banned";
    }

    format(str, sizeof(str), "{B0B0B0}[DISCONNECT] {B0B0B0}%s telah keluar dari server (%s)", dcname, reasontext);

    for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if(IsPlayerConnected(i) && playerid != i)
        {
            if(IsPlayerInRangeOfPoint(i, 30.0, x, y, z))
            {
                SendClientMessage(i, -1, str);
            }
        }
    }
    // =======================================

    // ... kode OnPlayerDisconnect kamu yang lain (reset variabel, dll) tetap di sini

    return 1;
}


forward PayDay();
public PayDay()
{
    for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if(IsPlayerConnected(i) && pLogged{i})
        {
            pMoney[i] += 5000; // gaji per 10 menit
            GivePlayerMoney(i, 5000);
            SendClientMessage(i, COLOR_GREEN, "[PAYDAY] Kamu menerima gaji $5,000!");
        }
    }
}

forward DelayedKick(playerid);
public DelayedKick(playerid)
{
    if(IsPlayerConnected(playerid)) Kick(playerid);
    return 1;
}

forward OnPlayerDataCheck(playerid);
public OnPlayerDataCheck(playerid)
{
    new ucp_name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, ucp_name, sizeof(ucp_name)); // Pasti UCP karena sudah lewat fix GMX

    new caption[64], info[256];

    if(cache_num_rows() > 0)
    {
        cache_get_value_name_int(0, "adminlevel", pAdminLevel[playerid]);

        format(caption, sizeof(caption), "{FFD700}LOGIN AKUN TERDAFTAR");
        format(info, sizeof(info), 
            "{FFFFFF}Selamat datang kembali di {FFD700}Legacy State Roleplay\n\n\
            {00FF00}UCP: {FFFFFF}%s\n\n\
            {FFFFFF}Masukkan password untuk login:", ucp_name);

        ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, caption, info, "Login", "Keluar");
    }
    else
    {
        format(caption, sizeof(caption), "{FF6347}AKUN BELUM TERDAFTAR");
        format(info, sizeof(info), 
            "{FFFFFF}Kamu belum memiliki akun di server ini.\n\n\
            {00FF00}UCP: {FFFFFF}%s\n\n\
            {FFFFFF}Buat password baru untuk registrasi:", ucp_name);

        ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, caption, info, "Daftar", "Keluar");
    }
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    // ========================================
    // 1. MENU UTAMA (/menu) – SUDAH DIPERBAIKI 100%
    // ========================================
    if(dialogid == DIALOG_MENU_UTAMA)
    {
        if(!response) return 1;

        switch(listitem)
        {
            case 0: // Informasi Server
            {
                new str[600], count = 0;
                for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++) if(IsPlayerConnected(i)) count++;

                strcat(str, "{FFD700}=== INFORMASI SERVER ===\n\n");
                strcat(str, "{FFFFFF}Nama Server : {00FF00}Legacy State Roleplay\n");
                strcat(str, "{FFFFFF}Versi        : {00FF00}BETA 0.7.5\n");
                strcat(str, "{FFFFFF}Website      : {00FF00}www.legacy-state.id\n");
                strcat(str, "{FFFFFF}Discord      : {00FF00}discord.gg/legacystate\n");
                strcat(str, "{FFFFFF}Mode         : {00FF00}Roleplay Serius | Indonesia\n");
                strcat(str, "{FFFFFF}Online       : {00FF00}%d/%d pemain\n", count, GetMaxPlayers());
                strcat(str, "\n{FFFF00}Terima kasih telah bermain di Legacy State!");

                ShowPlayerDialog(playerid, DIALOG_INFO_SERVER, DIALOG_STYLE_MSGBOX, "Informasi Server", str, "Tutup", "");
                return 1;
            }
            case 1: // Tukar Kode Premium
            {
                ShowPlayerDialog(playerid, DIALOG_TUKAR_KODE, DIALOG_STYLE_INPUT, "Tukar Kode Premium",
                    "{FFFFFF}Masukkan kode premium yang kamu miliki:\n\n{FFFF00}Contoh: LEGACY2025-GOLD", "Tukar", "Batal");
                return 1;
            }
            case 2: // ATM & Bank
            {
                SendClientMessage(playerid, COLOR_YELLOW, "Fitur ATM & Bank sedang dalam pengembangan!");
                return 1;
            }
            case 3: // Statistik Karakter (SUDAH DIPERBAIKI – TIDAK ERROR LAGI)
            {
                new str[512], charname[24];
                format(charname, sizeof(charname), "%s", pCharName[playerid][pSelectedChar[playerid]]);
                ReplaceUnderscore(charname);

                format(str, sizeof(str),
                    "{FFFF00}=== STATISTIK KARAKTER ===\n\n\
                    {FFFFFF}Nama Karakter  : {00FF00}%s\n\
                    {FFFFFF}Uang Tunai     : {00FF00}$%d\n\
                    {FFFFFF}Tanggal Lahir  : {00FF00}%s\n\
                    {FFFFFF}Level Admin    : {00FF00}%d\n\
                    {FFFFFF}Skin ID        : {00FF00}%d",
                    charname,
                    pMoney[playerid],
                    (strlen(tempBirthdate[playerid]) > 0) ? tempBirthdate[playerid] : "Belum diatur",
                    pAdminLevel[playerid],
                    GetPlayerSkin(playerid)
                );

                ShowPlayerDialog(playerid, 9999, DIALOG_STYLE_MSGBOX, "Statistik Karakter", str, "Tutup", "");
                return 1;
            }
            case 4: // Bantuan & Peraturan
            {
                ShowPlayerDialog(playerid, DIALOG_HELP, DIALOG_STYLE_MSGBOX, "Bantuan & Peraturan",
                    "{FFFFFF}Perintah penting:\n\n\
                    {00FF00}/me {FFFFFF}- aksi roleplay\n\
                    {00FF00}/do {FFFFFF}- deskripsi roleplay\n\
                    {00FF00}/s {FFFFFF}- teriak/shout\n\
                    {00FF00}/b {FFFFFF}- chat OOC\n\
                    {00FF00}/pay {FFFFFF}- bayar player terdekat\n\
                    {00FF00}/stats {FFFFFF}- lihat statistik\n\
                    {00FF00}/menu {FFFFFF}- buka menu ini\n\n\
                    {FFFF00}Dilarang: Deathmatch, Metagaming, Powergaming, Cheat\n\
                    {FFD700}Butuh bantuan? Hubungi admin di Discord!", "Tutup", "");
                return 1;
            }
            case 5: // Admin Menu
            {
                if(pAdminLevel[playerid] < 1) return SendClientMessage(playerid, COLOR_RED, "Kamu bukan admin!");
                SendClientMessage(playerid, COLOR_RED, "Admin menu akan ditambahkan nanti.");
                return 1;
            }
        }
        return 1;
    }

    // ========================================
    // 2. TUKAR KODE PREMIUM
    // ========================================
    // ========================================
    // TUKAR KODE PREMIUM (DARI DATABASE)
    // ========================================
    if(dialogid == DIALOG_TUKAR_KODE)
    {
        if(!response) return cmd_menu(playerid, "");

        if(strlen(inputtext) < 5)
        {
            ShowPlayerDialog(playerid, DIALOG_TUKAR_KODE, DIALOG_STYLE_INPUT, "Error", 
                "{FF0000}Kode terlalu pendek! Minimal 5 karakter.", "Coba Lagi", "Batal");
            return 1;
        }

        // Query case-insensitive + aman
        new query[256];
        mysql_format(sqldb, query, sizeof(query), 
            "SELECT reward, used FROM premium_codes WHERE LOWER(code) = LOWER('%e') LIMIT 1", inputtext);
        mysql_tquery(sqldb, query, "OnRedeemKode", "is", playerid, inputtext);

        return 1;
    }

    // ========================================
    // 3. SEMUA KODE LAMA KAMU (REGISTRASI, LOGIN, KARAKTER) – TETAP UTUH
    // ========================================
    if(dialogid == DIALOG_REGISTER)
    {
        if(!response) return Kick(playerid);
        if(strlen(inputtext) < 6) return ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Registrasi", "Error: Password minimal 6 karakter!", "Daftar", "Keluar");

        new hash[129], name[MAX_PLAYER_NAME], query[256];
        GetPlayerName(playerid, name, sizeof(name));
        WP_Hash(hash, sizeof(hash), inputtext);
        mysql_format(sqldb, query, sizeof(query), "INSERT INTO users (name, password) VALUES ('%e', '%s')", name, hash);
        mysql_tquery(sqldb, query);

        SendClientMessage(playerid, COLOR_GREEN, "Registrasi berhasil! Silakan login.");
        ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "Masukkan password:", "Login", "Keluar");
        return 1;
    }

    if(dialogid == DIALOG_LOGIN)
    {
        if(!response) return Kick(playerid);

        new name[MAX_PLAYER_NAME], query[256];
        GetPlayerName(playerid, name, sizeof(name));
        mysql_format(sqldb, query, sizeof(query), "SELECT password FROM users WHERE name = '%e'", name);
        mysql_tquery(sqldb, query, "OnPlayerLoginAttempt", "is", playerid, inputtext);
        return 1;
    }

    if(dialogid == DIALOG_CHARLIST)
    {
        if(!response) return Kick(playerid);

        new total_chars = 0;
        for(new i = 0; i < MAX_CHARS; i++)
            if(pCharID[playerid][i] != 0) total_chars++;

        if(listitem >= total_chars)
        {
            if(total_chars >= MAX_CHARS)
            {
                SendClientMessage(playerid, COLOR_RED, "Kamu sudah memiliki 3 karakter maksimal!");
                LoadPlayerCharacters(playerid);
                return 1;
            }
            ShowPlayerDialog(playerid, DIALOG_CHARCREATE, DIALOG_STYLE_INPUT, "Buat Karakter Baru",
                "{FFFFFF}Masukkan Nama Karakter (Format: Firstname_Lastname)\nContoh: Michael_Smith", "Buat", "Kembali");
        }
        else
        {
            pSelectedChar[playerid] = listitem;
            new showname[24], dialogstr[128];
            format(showname, sizeof(showname), "%s", pCharName[playerid][listitem]);
            ReplaceUnderscore(showname);
            format(dialogstr, sizeof(dialogstr), "\nMainkan\nHapus", showname);
            ShowPlayerDialog(playerid, DIALOG_CHAR_ACTION, DIALOG_STYLE_LIST, "Aksi Karakter", dialogstr, "Pilih", "Kembali");
        }
        return 1;
    }

    if(dialogid == DIALOG_CHAR_ACTION)
    {
        if(!response) return LoadPlayerCharacters(playerid);

        if(listitem == 0)
        {
            new query[128];
            mysql_format(sqldb, query, sizeof(query), "SELECT money, skin, pos_x, pos_y, pos_z, pos_a FROM characters WHERE id = %d", pCharID[playerid][pSelectedChar[playerid]]);
            mysql_tquery(sqldb, query, "OnCharacterSelected", "i", playerid);
        }
        else if(listitem == 1)
        {
            new showname[24], dialogstr[128];
            format(showname, sizeof(showname), "%s", pCharName[playerid][pSelectedChar[playerid]]);
            ReplaceUnderscore(showname);
            format(dialogstr, sizeof(dialogstr), "Yakin ingin menghapus %s? Aksi ini tidak bisa dibatalkan!", showname);
            ShowPlayerDialog(playerid, DIALOG_CHAR_DELETE, DIALOG_STYLE_MSGBOX, "Konfirmasi Hapus Karakter", dialogstr, "Ya", "Tidak");
        }
        return 1;
    }

    if(dialogid == DIALOG_CHAR_DELETE)
    {
        if(!response) return LoadPlayerCharacters(playerid);

        new query[128];
        mysql_format(sqldb, query, sizeof(query), "DELETE FROM characters WHERE id = %d", pCharID[playerid][pSelectedChar[playerid]]);
        mysql_tquery(sqldb, query);

        SendClientMessage(playerid, COLOR_RED, "Karakter berhasil dihapus!");
        pSelectedChar[playerid] = -1;
        LoadPlayerCharacters(playerid);
        return 1;
    }

    if(dialogid == DIALOG_CHARCREATE)
    {
        if(!response) return LoadPlayerCharacters(playerid);
        
        if(strfind(inputtext, "_") == -1 || strlen(inputtext) < 5 || strlen(inputtext) > 20)
            return ShowPlayerDialog(playerid, DIALOG_CHARCREATE, DIALOG_STYLE_INPUT, "Error", 
                "{FF0000}Nama harus pakai underscore dan 5-20 karakter!\nContoh: John_Doe", "Buat", "Kembali");

        format(tempProposedName[playerid], 24, "%s", inputtext);

        new query[128];
        mysql_format(sqldb, query, sizeof(query), "SELECT id FROM characters WHERE charname = '%e' LIMIT 1", tempProposedName[playerid]);
        mysql_tquery(sqldb, query, "OnCharacterNameCheck", "i", playerid);
        
        return 1;
    }

    if(dialogid == DIALOG_GENDER)
    {
        if(!response)
        {
            ShowPlayerDialog(playerid, DIALOG_CHARCREATE, DIALOG_STYLE_INPUT, "Buat Karakter Baru",
                "{FFFFFF}Masukkan Nama Karakter (Format: Firstname_Lastname)\nContoh: Michael_Smith", "Buat", "Kembali");
            return 1;
        }
        tempGender[playerid] = listitem;
        ShowPlayerDialog(playerid, DIALOG_BIRTHDATE, DIALOG_STYLE_INPUT, "Tanggal Lahir", "Masukkan tanggal lahir (dd/mm/yyyy)\nContoh: 19/10/2000", "Lanjut", "Batal");
        return 1;
    }

    if(dialogid == DIALOG_BIRTHDATE)
    {
        if(!response) return ShowPlayerDialog(playerid, DIALOG_GENDER, DIALOG_STYLE_LIST, "Gender", "1. Male/Laki-Laki\n2. Female/Perempuan", "Pilih", "Batal");

        new day, month, year;
        if(sscanf(inputtext, "p</>iii", day, month, year) || day < 1 || day > 31 || month < 1 || month > 12 || year < 1900 || year > 2005)
            return ShowPlayerDialog(playerid, DIALOG_BIRTHDATE, DIALOG_STYLE_INPUT, "Error", "{FF0000}Format salah! Masukkan dd/mm/yyyy\nContoh: 19/10/2000", "Lanjut", "Batal");

        format(tempBirthdate[playerid], 11, "%02d/%02d/%d", day, month, year);

        inSkinClassSelection[playerid] = true;
        inArrivalClassSelection[playerid] = false;
        isCreating[playerid] = true;

        new Float:skinX = ArrivalCoords[0][0], Float:skinY = ArrivalCoords[0][1], Float:skinZ = ArrivalCoords[0][2], Float:skinA = ArrivalCoords[0][3];
        if(tempGender[playerid] == 0)
        {
            for(new i = 0; i < 10; i++)
                AddPlayerClass(MaleSkins[i], skinX, skinY, skinZ, skinA, 0, 0, 0, 0, 0, 0);
        }
        else
        {
            for(new i = 0; i < 10; i++)
                AddPlayerClass(FemaleSkins[i], skinX, skinY, skinZ, skinA, 0, 0, 0, 0, 0, 0);
        }

        SetPlayerInterior(playerid, 0);
        SetPlayerVirtualWorld(playerid, 0);
        TogglePlayerSpectating(playerid, 0);

        SendClientMessage(playerid, -1, "");
        SendClientMessage(playerid, -1, "{00FF00}>>> {FFFFFF}Gunakan panah kiri/kanan untuk ganti penampilan");
        SendClientMessage(playerid, -1, "{00FF00}>>> {FFFFFF}Tekan {FFFF00}SPAWN {FFFFFF}jika sudah yakin dengan penampilan ini");

        return 1;
    }
    if(dialogid == DIALOG_SET_KODE)
    {
    if(!response) return 1;

    if(strlen(inputtext) < 5 || strlen(inputtext) > 32)
        return ShowPlayerDialog(playerid, DIALOG_SET_KODE, DIALOG_STYLE_INPUT, "{FF0000}Error", "Kode harus 5-32 karakter!", "Coba Lagi", "Batal");

    // Simpan kode sementara
    SetPVarString(playerid, "TempKode", inputtext);

    ShowPlayerDialog(playerid, DIALOG_SET_REWARD, DIALOG_STYLE_INPUT, "{FFD700}Set Reward Kode",
        "{FFFFFF}Masukkan jumlah uang reward untuk kode ini:\n\n{FFFF00}Contoh: 50000000 (untuk $50.000.000)", "Set", "Batal");
    return 1;
    }

    if(dialogid == DIALOG_SET_REWARD)
    {
    if(!response) return 1;

    new reward;
    if(sscanf(inputtext, "i", reward) || reward < 1000 || reward > 200000000)
        {
        ShowPlayerDialog(playerid, DIALOG_SET_REWARD, DIALOG_STYLE_INPUT, "{FF0000}Error", 
            "{FFFFFF}Reward harus angka (min $1.000 - maks $200.000.000)!", "Coba Lagi", "Batal");
        return 1;
        }   

        new kode[33];
        GetPVarString(playerid, "TempKode", kode, sizeof(kode));

         // === INI YANG BARU & AMAN 100% ===
        new escaped_code[65];
        mysql_escape_string(kode, escaped_code); // ANTI SQL INJECTION & ANTI CRASH

        new query[256];
        mysql_format(sqldb, query, sizeof(query),
        "INSERT INTO premium_codes (code, reward, used) VALUES ('%e', %d, 0) \
         ON DUPLICATE KEY UPDATE reward = %d, used = 0",
        escaped_code, reward, reward);
        mysql_tquery(sqldb, query);

        // Broadcast & info
        new str[128];
        new adminname[MAX_PLAYER_NAME];
GetPlayerName(playerid, adminname, sizeof(adminname));

format(str, sizeof(str), "[ADMIN] %s telah membuat kode premium baru: {FFFF00}%s {FFFFFF}| Reward: {00FF00}$%d", adminname, kode, reward);
        SendClientMessageToAll(0xFFD700FF, str);
        SendClientMessage(playerid, COLOR_GREEN, "Kode premium berhasil dibuat!");

        DeletePVar(playerid, "TempKode");
        return 1;
    }
    // ========================================
    // 3. REDEEM KODE OLEH PLAYER (ubah bagian ini di DIALOG_TUKAR_KODE)
    if(dialogid == DIALOG_TUKAR_KODE)
    {
        if(!response) return cmd_menu(playerid, "");
        if(strlen(inputtext) < 5 || strlen(inputtext) > 32)
        {
            ShowPlayerDialog(playerid, DIALOG_TUKAR_KODE, DIALOG_STYLE_INPUT, "Error",
                "{FF0000}Kode harus 5-32 karakter!", "Tukar", "Batal");
        return 1;
        }

    new query[200];
    mysql_format(sqldb, query, sizeof(query),
        "SELECT reward FROM premium_codes WHERE LOWER(code) = LOWER('%e') LIMIT 1", inputtext);
    mysql_tquery(sqldb, query, "OnRedeemKode", "is", playerid, inputtext);
    return 1;
}
    

    return 0;
}

forward LoadPlayerCharacters(playerid);
public LoadPlayerCharacters(playerid)
{
    new accname[MAX_PLAYER_NAME], query[256];
    GetPlayerName(playerid, accname, sizeof(accname));

    for(new i = 0; i < MAX_CHARS; i++)
    {
        pCharID[playerid][i] = 0;
        format(pCharName[playerid][i], 24, "Kosong");
        pCharSkin[playerid][i] = 0;
    }

    mysql_format(sqldb, query, sizeof(query),
        "SELECT id, charname, skin, lastlogin, birthdate FROM characters WHERE owner = '%e' ORDER BY id ASC LIMIT %d", accname, MAX_CHARS);
    mysql_tquery(sqldb, query, "OnCharactersLoaded", "i", playerid);

    return 1;
}

forward OnCharactersLoaded(playerid);
public OnCharactersLoaded(playerid)
{
    new rows = cache_num_rows();
    new string[700];

    new char_count = 0;

    // Reset array
    for(new i = 0; i < MAX_CHARS; i++) pCharID[playerid][i] = 0;

    // Tampilkan karakter yang ada
    for(new i = 0; i < rows && i < MAX_CHARS; i++)
    {
        new id, skin;
        new cname[24], showname[24], birthstr[11];
        new lastlogin;
        cache_get_value_name_int(i, "id", id);
        cache_get_value_name(i, "charname", cname, 24);
        cache_get_value_name_int(i, "skin", skin);
        cache_get_value_name_int(i, "lastlogin", lastlogin);
        cache_get_value_name(i, "birthdate", birthstr, 11);

        pCharID[playerid][i] = id;
        format(pCharName[playerid][i], 24, "%s", cname);
        pCharSkin[playerid][i] = skin;

        new laststr[32];
        if(lastlogin == 0) {
            format(laststr, sizeof(laststr), "Never");
        } else {
            new year, month, day, hour, minute, second;
            TimestampToDate(lastlogin, year, month, day, hour, minute, second, 7, 0); // 7 untuk GMT+7 (Indonesia), ganti 0 jika UTC
            new weekday = GetWeekDay(lastlogin);
            format(laststr, sizeof(laststr), "%s %02d %s %d, %02d:%02d:%02d",
                WeekDayName[weekday], day, MonthName[month-1], year, hour, minute, second);
        }

        format(showname, sizeof(showname), "%s", cname);
        ReplaceUnderscore(showname);

        format(string, sizeof(string), "%s{00FF00}[Slot %d] {FFFFFF}%s {AFAFAF}(Skin: %d) - Last Login: %s - Birth: %s\n", string, i+1, showname, skin, laststr, birthstr);
        char_count++;
    }

    // Tambahkan "Buat Karakter Baru" hanya sekali jika ada slot kosong
    if(char_count < MAX_CHARS)
    {
        format(string, sizeof(string), "%s{FFFF00}[Slot %d] {00FF00}Buat Karakter Baru\n", string, char_count+1);
    }

    ShowPlayerDialog(playerid, DIALOG_CHARLIST, DIALOG_STYLE_LIST, "{FFFFFF}=== PILIH KARAKTER ===", string, "Pilih", "Keluar");
}

forward OnCharacterCreated(playerid);
public OnCharacterCreated(playerid)
{
    if(cache_insert_id())
    {
        SendClientMessage(playerid, COLOR_GREEN, "Karakter berhasil dibuat!");
        LoadPlayerCharacters(playerid);
    }
    return 1;
}

forward OnCharacterSelected(playerid);
public OnCharacterSelected(playerid)
{
    if(cache_num_rows() == 0) return LoadPlayerCharacters(playerid);

    new money, skin;
    new Float:posx, Float:posy, Float:posz, Float:posa;

    cache_get_value_name_int(0, "money", money);
    cache_get_value_name_int(0, "skin", skin);
    cache_get_value_name_float(0, "pos_x", posx);
    cache_get_value_name_float(0, "pos_y", posy);
    cache_get_value_name_float(0, "pos_z", posz);
    cache_get_value_name_float(0, "pos_a", posa);

    // Simpan uang
    pMoney[playerid] = money;

    // Update lastlogin
    new now = gettime();
    new upquery[128];
    mysql_format(sqldb, upquery, sizeof(upquery), "UPDATE characters SET lastlogin = %d WHERE id = %d", now, pCharID[playerid][pSelectedChar[playerid]]);
    mysql_tquery(sqldb, upquery);

    // === PERBAIKAN SETPLAYERNAME ANTI-BENTROK ===
    new desiredName[24];

    if(pAdminDuty[playerid])
    {
        // Admin Duty → pakai nama UCP
        format(desiredName, sizeof(desiredName), "%s", pUCPName[playerid]);
        SetPlayerName(playerid, desiredName);
        SetPlayerColor(playerid, 0xFF0000FF); // Merah
    }
    else
    {
        // Normal RP → pakai nama karakter
        format(desiredName, sizeof(desiredName), "%s", pCharName[playerid][pSelectedChar[playerid]]);

        // Coba set nama asli
        if(SetPlayerName(playerid, desiredName) == -1)
        {
            // Nama bentrok! Cari alternatif otomatis (tambah _1, _2, dst)
            new tempName[28];
            for(new i = 1; i <= 50; i++)
            {
                format(tempName, sizeof(tempName), "%s_%d", pCharName[playerid][pSelectedChar[playerid]], i);
                if(SetPlayerName(playerid, tempName) != -1)
                {
                    format(desiredName, sizeof(desiredName), "%s", tempName);
                    SendClientMessage(playerid, 0xFF6347FF, "Peringatan: Nama karakter sudah dipakai. Nama sementara: %s", tempName);
                    break;
                }
            }
        }
        SetPlayerColor(playerid, 0xFFFFFFFF); // Putih
    }

    // Spawn player
    SetSpawnInfo(playerid, 0, skin, posx, posy, posz, posa, 0, 0, 0, 0, 0, 0);
    TogglePlayerSpectating(playerid, 0);
    SpawnPlayer(playerid);
    SetPlayerSkin(playerid, skin);

    pLogged{playerid} = true;

    // Pesan selamat datang
    new showname[28];
    format(showname, sizeof(showname), "%s", desiredName); // pakai nama yang berhasil diset
    ReplaceUnderscore(showname);

    new msg[128];
    format(msg, sizeof(msg), "{33CCFF}[SERVER] {FFFFFF}Anda login sebagai {FFFFFF}%s", showname);
    SendClientMessage(playerid, -1, msg);

    if(pAdminDuty[playerid])
        SendClientMessage(playerid, COLOR_RED, "[ADMIN] ADMIN DUTY: ON | Gunakan command admin dengan bijak!");

        SendClientMessage(playerid, -1, "{33CCFF}[SERVER] {FFFFFF}Karakter berhasil dimuat! Selamat bermain di Legacy State Roleplay!");

    return 1;
}

forward OnPlayerLoginAttempt(playerid, inputpass[]);
public OnPlayerLoginAttempt(playerid, inputpass[])
{
    if(!cache_num_rows())
    {
        pLoginAttempts[playerid]++;
        if(pLoginAttempts[playerid] >= 3) { SendClientMessage(playerid, COLOR_RED, "3x salah password. Kamu dikick!"); Kick(playerid); }
        else {
            new str[128];
            format(str, sizeof(str), "Password salah! Kesempatan tersisa: %d/3", 3 - pLoginAttempts[playerid]);
            ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", str, "Login", "Keluar");
        }
        return 1;
    }

    new dbpass[129];
    cache_get_value_name(0, "password", dbpass, 129);
    new hash[129];
    WP_Hash(hash, sizeof(hash), inputpass);

    if(!strcmp(hash, dbpass))
    {
        SendClientMessage(playerid, -1, "{33CCFF}[SERVER]{FFFFFF} Login berhasil! Memuat karakter...");
        pLoginAttempts[playerid] = 0;
        LoadPlayerCharacters(playerid);

        // Tambah notif jika admin
        if(pAdminLevel[playerid] > 0)
        {
            SendClientMessage(playerid, COLOR_YELLOW, "[ADMIN]: Kamu adalah admin level %d. Gunakan /adminduty untuk on/off duty.");
        }
    }
    else
    {
        pLoginAttempts[playerid]++;
        if(pLoginAttempts[playerid] >= 3) { SendClientMessage(playerid, COLOR_RED, "3x salah password. Kamu dikick!"); Kick(playerid); }
        else {
            new str[128];
            format(str, sizeof(str), "Password salah! Kesempatan tersisa: %d/3", 3 - pLoginAttempts[playerid]);
            ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", str, "Login", "Keluar");
        }
    }
    return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
    pCurrentPreviewClass[playerid] = classid;

    if(inSkinClassSelection[playerid])
    {
        new Float:skinX = ArrivalCoords[0][0], Float:skinY = ArrivalCoords[0][1], Float:skinZ = ArrivalCoords[0][2], Float:skinA = ArrivalCoords[0][3];
        SetPlayerPos(playerid, skinX, skinY, skinZ);
        SetPlayerFacingAngle(playerid, skinA);
        SetPlayerCameraPos(playerid, skinX - 5.0 * floatsin(skinA, degrees), skinY - 5.0 * floatcos(skinA, degrees), skinZ + 0.5);
        SetPlayerCameraLookAt(playerid, skinX, skinY, skinZ);
        SetPlayerTime(playerid, 12, 0);
        SetPlayerWeather(playerid, 1);

        if(tempGender[playerid] == 0)
            SetPlayerSkin(playerid, MaleSkins[classid % 10]);
        else
            SetPlayerSkin(playerid, FemaleSkins[classid % 10]);

        return 1;
    }
    else if(inArrivalClassSelection[playerid])
    {
        new loc = classid % 3;
        SetPlayerInterior(playerid, 0);
        SetPlayerVirtualWorld(playerid, 0);
        SetPlayerPos(playerid, ArrivalCoords[loc][0], ArrivalCoords[loc][1], ArrivalCoords[loc][2]);
        SetPlayerFacingAngle(playerid, ArrivalCoords[loc][3]);
        SetPlayerCameraPos(playerid, ArrivalCoords[loc][0] - 5.0 * floatsin(ArrivalCoords[loc][3], degrees), ArrivalCoords[loc][1] - 5.0 * floatcos(ArrivalCoords[loc][3], degrees), ArrivalCoords[loc][2] + 0.5);
        SetPlayerCameraLookAt(playerid, ArrivalCoords[loc][0], ArrivalCoords[loc][1], ArrivalCoords[loc][2]);
        SetPlayerTime(playerid, 12, 0);
        SetPlayerWeather(playerid, 1);

        SetPlayerSkin(playerid, tempSkin[playerid]);

        GameTextForPlayer(playerid, "~y~~h~Lokasi Kedatangan:~n~~w~%s", 3000, 3, ArrivalNames[loc]);
        return 1;
    }
    return 1;
}

public OnPlayerRequestSpawn(playerid)
{
    if(inSkinClassSelection[playerid])
    {
        // Simpan skin yang dipilih
        if(tempGender[playerid] == 0)
            tempSkin[playerid] = MaleSkins[pCurrentPreviewClass[playerid] % 10];
        else
            tempSkin[playerid] = FemaleSkins[pCurrentPreviewClass[playerid] % 10];

        // Switch ke preview lokasi kedatangan
        for(new i = 0; i < 3; i++)
        {
            AddPlayerClass(tempSkin[playerid],
                ArrivalCoords[i][0], ArrivalCoords[i][1], ArrivalCoords[i][2], ArrivalCoords[i][3],
                0, 0, 0, 0, 0, 0);
        }

        inSkinClassSelection[playerid] = false;
        inArrivalClassSelection[playerid] = true;

        SendClientMessage(playerid, -1, "");
        SendClientMessage(playerid, -1, "{00FF00}>>> {FFFFFF}Gunakan panah kiri/kanan untuk ganti lokasi kedatangan");
        SendClientMessage(playerid, -1, "{00FF00}>>> {FFFFFF}Tekan {FFFF00}SPAWN {FFFFFF}jika sudah yakin");

        return 0; // tetap di class selection
    }
    else if(inArrivalClassSelection[playerid])
    {
        tempArrivalIndex[playerid] = pCurrentPreviewClass[playerid] % 3;

        // Buat karakter di database dengan posisi arrival yang dipilih
        new accname[MAX_PLAYER_NAME], query[300];
        GetPlayerName(playerid, accname, sizeof(accname));
        mysql_format(sqldb, query, sizeof(query),
            "INSERT INTO characters (owner, charname, skin, money, lastlogin, birthdate, pos_x, pos_y, pos_z, pos_a) VALUES ('%e', '%e', %d, 5000, 0, '%s', %f, %f, %f, %f)",
            accname, tempCharName[playerid], tempSkin[playerid], tempBirthdate[playerid],
            ArrivalCoords[tempArrivalIndex[playerid]][0], ArrivalCoords[tempArrivalIndex[playerid]][1],
            ArrivalCoords[tempArrivalIndex[playerid]][2], ArrivalCoords[tempArrivalIndex[playerid]][3]);
        mysql_tquery(sqldb, query, "OnCharacterCreated", "i", playerid);

        SendClientMessage(playerid, COLOR_GREEN, "[SERVER]: Karakter berhasil dibuat! Selamat datang di Legacy State Roleplay!");

        // Reset state
        isCreating[playerid] = false;
        inSkinClassSelection[playerid] = false;
        inArrivalClassSelection[playerid] = false;

        TogglePlayerSpectating(playerid, 1);
        return 0;
    }

    // Spawn normal untuk karakter yang sudah dipilih (sebelumnya)
    if(pSelectedChar[playerid] == -1 && !isCreating[playerid])
    {
        SendClientMessage(playerid, COLOR_RED, "Kamu harus memilih karakter terlebih dahulu!");
        return 0;
    }
    if(isCreating[playerid]) return 0;
    return 1;
}

public OnPlayerCommandPerformed(playerid, cmdtext[], success)
{
    if(!success)
    {
        if(pLogged{playerid})
        {
            new string[128];
            format(string, sizeof(string), "{33CCFF}[SERVER] {FFFFFF}Perintah \"{CCCCCC}%s{FFFFFF}\" tidak ditemukan.", cmdtext);
            SendClientMessage(playerid, -1, string);
        }
        else SendClientMessage(playerid, COLOR_RED, "Kamu harus login terlebih dahulu!");
    }
    return 1;
}

public OnPlayerSpawn(playerid)
{
    if(!pLogged{playerid} && !isCreating[playerid])
    {
        Kick(playerid);
        return 1;
    }

    if(isCreating[playerid])
    {
        SetPlayerVirtualWorld(playerid, 0);
        TogglePlayerControllable(playerid, 0);
        return 1;
    }

    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, pMoney[playerid]); // uang GTA SA original langsung muncul

    return 1;
}

public OnPlayerText(playerid, text[])
{
    if(!pLogged{playerid})
    {
        SendClientMessage(playerid, COLOR_RED, "Kamu harus login terlebih dahulu!");
        return 0;
    }

    new string[145];
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    // =============================================
    // ADMIN LAGI ON DUTY → SEMUA CHAT JADI OOC OTOMATIS
    // =============================================
    if(pAdminDuty[playerid] && pAdminLevel[playerid] >= 1)
    {
        // Format OOC otomatis: (( UCP [ID:x]: pesan ))
        format(string, sizeof(string), "(( {FF0000}%s {FFFF00}[ID:%d]{FFFFFF}: %s ))", pUCPName[playerid], playerid, text);
        ProxDetector(30.0, playerid, string, 0xAFAFAFFF); // Radius besar biar keliatan semua

        // Admin chat khusus (pakai ! di depan)
        if(text[0] == '!')
        {
            format(string, sizeof(string), "{FF0000}[ADMIN CHAT] {FFFFFF}%s (%d): {FFFFFF}%s", pUCPName[playerid], playerid, text[1]);
            for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
            {
                if(IsPlayerConnected(i) && pAdminLevel[i] >= 1)
                    SendClientMessage(i, -1, string);
            }
        }
        return 0; // Blokir chat IC
    }

    // =============================================
    // PLAYER BIASA / ADMIN OFF DUTY → CHAT ROLEPLAY NORMAL
    // =============================================
    new charname[24];
    format(charname, sizeof(charname), "%s", pCharName[playerid][pSelectedChar[playerid]]);
    ReplaceUnderscore(charname);

    // Shout (/s)
    if(text[0] == '/' && text[1] == 's' && (text[2] == ' ' || text[2] == '\0'))
    {
        format(string, sizeof(string), "{FFFF00}%s shouts: {FFFFFF}%s", charname, text[3]);
        ProxDetector(40.0, playerid, string, -1);
    }
    // Chat normal
    else
    {
        format(string, sizeof(string), "{F5F5F5}%s says: {FFFFFF}%s", charname, text);
        ProxDetector(20.0, playerid, string, -1);
    }

    return 0; // Blokir chat default SA-MP
}

// Di bagian redeem kode (DIALOG_TUKAR_KODE → callback OnRedeemKode)
// Ganti semua callback OnRedeemKode kamu dengan ini (3 callback baru)

forward OnRedeemKode(playerid, inputkode[]);
public OnRedeemKode(playerid, inputkode[])
{
    if(cache_num_rows() == 0)
    {
        SendClientMessage(playerid, COLOR_RED, "Kode premium tidak valid atau salah penulisan!");
        return 1;
    }

    new reward;
    cache_get_value_name_int(0, "reward", reward);

    // Simpan reward & kode sementara di PVar (biar bisa dipakai di callback berikutnya)
    SetPVarInt(playerid, "TempReward", reward);
    SetPVarString(playerid, "TempKode", inputkode);

    // Cek apakah player ini sudah pernah redeem kode ini
    new esc_code[65], esc_ucp[32], query[256];
    mysql_escape_string(inputkode, esc_code);
    mysql_escape_string(pUCPName[playerid], esc_ucp);

    mysql_format(sqldb, query, sizeof(query),
        "SELECT id FROM premium_redeemed WHERE code = '%e' AND ucp_name = '%e' LIMIT 1", esc_code, esc_ucp);
    mysql_tquery(sqldb, query, "OnCheckRedeemed", "i", playerid);
    return 1;
}

forward OnCheckRedeemed(playerid);
public OnCheckRedeemed(playerid)
{
    if(cache_num_rows() > 0)
    {
        SendClientMessage(playerid, COLOR_RED, "Kamu sudah pernah menukarkan kode ini sebelumnya!");
        DeletePVar(playerid, "TempReward");
        DeletePVar(playerid, "TempKode");
        return 1;
    }

    // Belum pernah redeem → simpan ke database
    new kode[33], esc_code[65], esc_ucp[32], query[256];
    GetPVarString(playerid, "TempKode", kode, sizeof(kode));
    mysql_escape_string(kode, esc_code);
    mysql_escape_string(pUCPName[playerid], esc_ucp);

    mysql_format(sqldb, query, sizeof(query),
        "INSERT IGNORE INTO premium_redeemed (code, ucp_name, redeemed_at) VALUES ('%e', '%e', UNIX_TIMESTAMP())",
        esc_code, esc_ucp);
    mysql_tquery(sqldb, query, "OnRewardGiven", "i", playerid);
    return 1;
}

forward OnRewardGiven(playerid);
public OnRewardGiven(playerid)
{
    // Jika INSERT IGNORE gagal = sudah ada (race condition aman)
    if(cache_affected_rows() == 0)
    {
        SendClientMessage(playerid, COLOR_RED, "Kode ini sudah kamu tukarkan sebelumnya!");
        DeletePVar(playerid, "TempReward");
        DeletePVar(playerid, "TempKode");
        return 1;
    }

    // Berhasil! Kasih reward
    new reward = GetPVarInt(playerid, "TempReward");
    new kode[33];
    GetPVarString(playerid, "TempKode", kode, sizeof(kode));

    pMoney[playerid] += reward;
    SetPlayerMoney(playerid, pMoney[playerid]); // Pakai function aman

    new str[256];
    format(str, sizeof(str), "{00FF00}Selamat! {FFFFFF}Kamu berhasil menukarkan kode premium dan mendapat {00FF00}$%d", reward);
    SendClientMessage(playerid, COLOR_GREEN, str);

    format(str, sizeof(str), "{FFD700}%s {FFFFFF}telah menukarkan kode premium {FF6347}%s", pUCPName[playerid], kode);
    SendClientMessageToAll(-1, str);

    // Log optional
    new logstr[256], year, month, day, hour, minute, second;
    getdate(year, month, day); gettime(hour, minute, second);
    format(logstr, sizeof(logstr), "[%04d-%02d-%02d %02d:%02d:%02d] %s redeemed code %s | $%d\r\n",
        year, month, day, hour, minute, second, pUCPName[playerid], kode, reward);
    new File:f = fopen("scriptfiles/premium_log.txt", io_append);
    if(f) { fwrite(f, logstr); fclose(f); }

    // Bersihkan PVar
    DeletePVar(playerid, "TempReward");
    DeletePVar(playerid, "TempKode");
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[]) {
    if(!pLogged{playerid}) { SendClientMessage(playerid, COLOR_RED, "Kamu harus login terlebih dahulu!"); return 1; }
    return 0;
}

CMD:car(playerid, params[])
{
    if(!pLogged{playerid}) return 0;
    new rand = random(sizeof(RandomCars));
    new Float:x, Float:y, Float:z, Float:a;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, a);
    new veh = CreateVehicle(RandomCars[rand], x+3, y, z+1, a+90, -1, -1, 60);
    PutPlayerInVehicle(playerid, veh, 0);
    SendClientMessage(playerid, COLOR_YELLOW, "Mobil random telah dibuat!");
    return 1;
}

CMD:jetpack(playerid, params[])
{
    if(!pLogged{playerid}) return 0;
    if(IsPlayerInAnyVehicle(playerid)) return SendClientMessage(playerid, COLOR_RED, "Keluar dari kendaraan dulu!");
    SetPlayerSpecialAction(playerid, SPECIAL_ACTION_USEJETPACK);
    SendClientMessage(playerid, COLOR_YELLOW, "Jetpack diberikan!");
    return 1;
}

forward OnCharacterNameCheck(playerid);
public OnCharacterNameCheck(playerid)
{
    if(cache_num_rows() > 0)
    {
        // Nama sudah dipakai orang lain
        ShowPlayerDialog(playerid, DIALOG_CHARCREATE, DIALOG_STYLE_INPUT, "Nama Sudah Dipakai",
            "{FF0000}Error: Nama karakter sudah digunakan oleh player lain!\n\
            Silakan gunakan nama lain.\n\n\
            Masukkan Nama Karakter (Format: Firstname_Lastname)\n\
            Contoh: Michael_Smith",
            "Buat", "Kembali");
    }
    else
    {
        // Nama tersedia → lanjut ke proses pembuatan karakter
        format(tempCharName[playerid], 24, "%s", tempProposedName[playerid]);
        ShowPlayerDialog(playerid, DIALOG_GENDER, DIALOG_STYLE_LIST, "Gender", "1. Male/Laki-Laki\n2. Female/Perempuan", "Pilih", "Batal");
    }
    return 1;
}


CMD:pay(playerid, params[])
{
    if(!pLogged{playerid}) return SendClientMessage(playerid, COLOR_RED, "Kamu harus login terlebih dahulu!");

    new targetid, amount;
    if(sscanf(params, "ui", targetid, amount)) 
        return SendClientMessage(playerid, -1, "[CMD] Gunakan: /pay [playerid/nama] [jumlah uang]");

    if(targetid == playerid) 
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] Tidak bisa kirim uang ke diri sendiri!");
    if(!IsPlayerConnected(targetid)) 
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] Player tidak online!");

    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    if(!IsPlayerInRangeOfPoint(targetid, 5.0, x, y, z)) 
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] Player tersebut terlalu jauh!");

    if(amount <= 0) 
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] Jumlah uang harus lebih dari 0!");
    if(pMoney[playerid] < amount) 
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] Uangmu tidak cukup!");

    // Kurangi & tambah uang di variabel
    pMoney[playerid] -= amount;
    pMoney[targetid] += amount;

    // LANGSUNG SYNC KE UANG ORIGINAL GTA SA (ini yang penting!)
    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, pMoney[playerid]);

    ResetPlayerMoney(targetid);
    GivePlayerMoney(targetid, pMoney[targetid]);

    // Notifikasi
    new sendername[24], receivername[24], str[128];
    GetPlayerName(playerid, sendername, sizeof(sendername));
    GetPlayerName(targetid, receivername, sizeof(receivername));
    ReplaceUnderscore(sendername);
    ReplaceUnderscore(receivername);

    format(str, sizeof(str), "Kamu telah mengirim $%d ke %s.", amount, receivername);
    SendClientMessage(playerid, COLOR_GREEN, str);

    format(str, sizeof(str), "%s telah mengirim $%d kepadamu.", sendername, amount);
    SendClientMessage(targetid, COLOR_GREEN, str);

    return 1;
}

CMD:aduty(playerid, params[])
{
    if(pAdminLevel[playerid] < 1) return SendClientMessage(playerid, COLOR_RED, "[ERROR] You do not have access to this command");

    pAdminDuty[playerid] = !pAdminDuty[playerid];

    if(pAdminDuty[playerid])
    {
        SetPlayerName(playerid, pUCPName[playerid]);
        SetPlayerColor(playerid, 0xFF0000FF); // Merah
        SendClientMessage(playerid, COLOR_RED, "ADMIN DUTY: ON | Nama & warna telah diubah.");
        GameTextForPlayer(playerid, "~r~ADMIN DUTY ~w~ON", 3000, 3);
    }
    else
    {
        SetPlayerName(playerid, pCharName[playerid][pSelectedChar[playerid]]);
        SetPlayerColor(playerid, 0xFFFFFFFF); // Putih
        SendClientMessage(playerid, COLOR_GREEN, "ADMIN DUTY: OFF | Kembali ke roleplay mode.");
        GameTextForPlayer(playerid, "~g~ADMIN DUTY ~w~OFF", 3000, 3);
    }
    return 1;
}

CMD:adminduty(playerid, params[])
{
    if(pAdminLevel[playerid] < 1) return SendClientMessage(playerid, COLOR_RED, "[ERROR] You do not have access to this command");

    pAdminDuty[playerid] = !pAdminDuty[playerid];

    if(pAdminDuty[playerid])
    {
        SetPlayerName(playerid, pUCPName[playerid]);
        SetPlayerColor(playerid, 0xFF0000FF); // Merah
        SendClientMessage(playerid, COLOR_RED, "ADMIN DUTY: ON | Nama & warna telah diubah.");
        GameTextForPlayer(playerid, "~r~ADMIN DUTY ~w~ON", 3000, 3);
    }
    else
    {
        SetPlayerName(playerid, pCharName[playerid][pSelectedChar[playerid]]);
        SetPlayerColor(playerid, 0xFFFFFFFF); // Putih
        SendClientMessage(playerid, COLOR_GREEN, "ADMIN DUTY: OFF | Kembali ke roleplay mode.");
        GameTextForPlayer(playerid, "~g~ADMIN DUTY ~w~OFF", 3000, 3);
    }
    return 1;
}

// Fungsi custom untuk kick dengan pesan
stock KickPlayer(playerid, reason[128] = "No reason specified")
{
    new kickmsg[144];
    format(kickmsg, sizeof(kickmsg), "{FF0000}[SERVER]: Kamu telah dikick dari server! Alasan: %s", reason);
    SendClientMessage(playerid, -1, kickmsg);
    SetTimerEx("DelayedKick", 1000, false, "i", playerid); // Delay 1 detik agar pesan terbaca
}

CMD:kick(playerid, params[])
{
    if(pAdminLevel[playerid] < 1 || !pAdminDuty[playerid])
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] You do not have access to this command");

    new targetid, reason[64];
    if(sscanf(params, "us[64]", targetid, reason))
        return SendClientMessage(playerid, -1, "[CMD] Gunakan: /kick [playerid] [alasan]");

    if(!IsPlayerConnected(targetid)) return SendClientMessage(playerid, COLOR_RED, "[ERROR] Player tidak online!");

    new adminname[MAX_PLAYER_NAME], targetname[MAX_PLAYER_NAME];
    GetPlayerName(playerid, adminname, sizeof(adminname));
    GetPlayerName(targetid, targetname, sizeof(targetname));

    new str[145];
    format(str, sizeof(str), "AdmCmd: %s telah dikick oleh %s. Alasan: %s", targetname, adminname, reason);
    SendClientMessageToAll(COLOR_RED, str);

    Kick(targetid);
    return 1;
}

CMD:setadmin(playerid, neuen, params[])
{
    if(pAdminLevel[playerid] < 5) return SendClientMessage(playerid, COLOR_RED, "[ERROR] You do not have access to this command");

    new targetname[24], level;
    if(sscanf(params, "s[24]i", targetname, level)) return SendClientMessage(playerid, COLOR_YELLOW, "Gunakan: /setadmin [ucp_name] [level 0-5]");

    if(level < 0 || level > 5) return SendClientMessage(playerid, COLOR_RED, "Level admin: 0 sampai 5!");

    new query[128];
    if(level == 0)
        mysql_format(sqldb, query, sizeof(query), "DELETE FROM admins WHERE ucp_name = '%e'", targetname);
    else
        mysql_format(sqldb, query, sizeof(query), "INSERT INTO admins (ucp_name, level) VALUES ('%e', %d) ON DUPLICATE KEY UPDATE level = %d", targetname, level, level);

    mysql_tquery(sqldb, query);

    new str[128];
    format(str, sizeof(str), "Admin %s telah di-set level %d oleh Owner.", targetname, level);
    SendClientMessageToAll(COLOR_RED, str);
    return 1;
}

// Timer untuk update spectate real-time (HARUS DIATAS semua command)
forward UpdateSpectate(playerid);
public UpdateSpectate(playerid)
{
    if(!IsPlayerConnected(playerid) || !pSpectating[playerid])
        return 0;

    new targetid = pSpecTarget[playerid];

    if(!IsPlayerConnected(targetid))
    {
        SendClientMessage(playerid, COLOR_RED, "[INFO] Player yang kamu spectate telah keluar dari server.");
        
        // Matikan spectate secara manual (tanpa CMD)
        pSpectating[playerid] = false;
        pSpecTarget[playerid] = -1;
        TogglePlayerControllable(playerid, 1);
        SpawnPlayer(playerid);
        KillTimer(GetPVarInt(playerid, "SpecTimer"));
        
        return 0;
    }

    // Update interior & virtual world
    if(GetPlayerInterior(playerid) != GetPlayerInterior(targetid))
        SetPlayerInterior(playerid, GetPlayerInterior(targetid));

    if(GetPlayerVirtualWorld(playerid) != GetPlayerVirtualWorld(targetid))
        SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(targetid));

    // Spectate kendaraan atau player
    if(IsPlayerInAnyVehicle(targetid))
        PlayerSpectateVehicle(playerid, GetPlayerVehicleID(targetid), SPECTATE_MODE_NORMAL);
    else
        PlayerSpectatePlayer(playerid, targetid, SPECTATE_MODE_NORMAL);

    return 1;
}

CMD:spec(playerid, params[])
{
    if(pAdminLevel[playerid] < 1 || !pAdminDuty[playerid])
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] You do not have access to this command");

    new targetid;
    if(sscanf(params, "u", targetid)) 
        return SendClientMessage(playerid, COLOR_YELLOW, "[CMD] Gunakan: /spec [playerid/nama]");

    if(!IsPlayerConnected(targetid) || targetid == playerid) 
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] Player tidak valid!");

    if(pSpectating[playerid]) 
        return SendClientMessage(playerid, COLOR_RED, "[CMD] Gunakan /specoff dulu!");

    // === INI BARIS PENTING YANG HARUS DITAMBAH ===
    TogglePlayerSpectating(playerid, 1); // <--- WAJIB! Biar masuk mode spectate

    pSpecTarget[playerid] = targetid;
    pSpectating[playerid] = true;

    TogglePlayerControllable(playerid, 0);
    SetPlayerInterior(playerid, GetPlayerInterior(targetid));
    SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(targetid));
    PlayerSpectatePlayer(playerid, targetid, SPECTATE_MODE_NORMAL);

    SetPVarInt(playerid, "SpecTimer", SetTimerEx("UpdateSpectate", 500, true, "i", playerid));

    new name[24], msg[128];
    GetPlayerName(targetid, name, sizeof(name));
    format(msg, sizeof(msg), "[CMD] Kamu sekarang spectate %s (ID: %d). Gunakan /specoff untuk berhenti.", name, targetid);
    SendClientMessage(playerid, -1, msg);
    return 1;
}

CMD:specoff(playerid, params[])
{
    if(!pSpectating[playerid])
        return SendClientMessage(playerid, COLOR_RED, "[CMD] Kamu tidak sedang spectate!");

    pSpectating[playerid] = false;
    pSpecTarget[playerid] = -1;
    KillTimer(GetPVarInt(playerid, "SpecTimer"));

    TogglePlayerSpectating(playerid, 0); // <--- INI YANG PENTING
    TogglePlayerControllable(playerid, 1);
    SpawnPlayer(playerid);

    SendClientMessage(playerid, COLOR_GREEN, "[CMD] Spectate mode dimatikan.");
    return 1;
}

CMD:me(playerid, params[])
{
    if(!pLogged{playerid}) return SendClientMessage(playerid, COLOR_RED, "[ERROR] Kamu harus login terlebih dahulu!");
    if(isnull(params)) return SendClientMessage(playerid, -1, "[CMD] Gunakan: /me [aksi]");

    new name[24];
    format(name, sizeof(name), "%s", pCharName[playerid][pSelectedChar[playerid]]);
    ReplaceUnderscore(name);

    new str[128];
    format(str, sizeof(str), "* %s %s", name, params);

    ProxDetector(20.0, playerid, str, 0xC2A2DAAA);
    return 1;
}

CMD:do(playerid, params[])
{
    if(!pLogged{playerid}) return SendClientMessage(playerid, COLOR_RED, "[ERROR] Kamu harus login terlebih dahulu!");
    if(isnull(params)) return SendClientMessage(playerid, -1, "[CMD] Gunakan: /do [aksi]");

    new name[24];
    format(name, sizeof(name), "%s", pCharName[playerid][pSelectedChar[playerid]]);
    ReplaceUnderscore(name);

    new str[128];
    format(str, sizeof(str), "* %s (( %s ))", params, name);

    ProxDetector(20.0, playerid, str, 0xC2A2DAAA);
    return 1;
}

CMD:stats(playerid, params[])
{
    if(!pLogged{playerid})
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] Kamu harus login terlebih dahulu!");

    if(pSelectedChar[playerid] == -1)
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] Karakter belum dipilih dengan benar.");

    new str[512];
    new charname[24];
    format(charname, sizeof(charname), "%s", pCharName[playerid][pSelectedChar[playerid]]);
    ReplaceUnderscore(charname);

    // Ambil data birthdate langsung dari database (pasti akurat & selalu ada)
    new query[256];
    mysql_format(sqldb, query, sizeof(query),
        "SELECT birthdate, money, skin, lastlogin FROM characters WHERE id = %d LIMIT 1",
        pCharID[playerid][pSelectedChar[playerid]]);
    
    mysql_tquery(sqldb, query, "OnPlayerStats", "i", playerid);

    // Simpan data sementara biar bisa dipakai di callback
    SetPVarString(playerid, "Stats_Name", charname);
    SetPVarInt(playerid, "Stats_Money", pMoney[playerid]);
    SetPVarInt(playerid, "Stats_AdminLevel", pAdminLevel[playerid]);

    return 1;
}

// Callback-nya (taruh di bawah semua command)
forward OnPlayerStats(playerid);
public OnPlayerStats(playerid)
{
    if(cache_num_rows() == 0)
    {
        SendClientMessage(playerid, COLOR_RED, "[ERROR] Data karakter tidak ditemukan!");
        return 1;
    }

    new birthdate[11];
    cache_get_value_name(0, "birthdate", birthdate, 11);

    new charname[24];
    GetPVarString(playerid, "Stats_Name", charname, 24);

    new str[512];
    format(str, sizeof(str), 
        "{FFFF00}=== STATISTIK KARAKTER ===\n\n\
        {FFFFFF}Nama Karakter\t: {00FF00}%s\n\
        {FFFFFF}Uang Tunai\t: {00FF00}$%d\n\
        {FFFFFF}Tanggal Lahir\t: {00FF00}%s\n\
        {FFFFFF}Level Admin\t: {00FF00}%d\n\
        {FFFFFF}Skin ID\t\t: {00FF00}%d",
        charname,
        GetPVarInt(playerid, "Stats_Money"),
        (strlen(birthdate) > 0) ? birthdate : "Belum diatur",
        GetPVarInt(playerid, "Stats_AdminLevel"),
        GetPlayerSkin(playerid)
    );

    ShowPlayerDialog(playerid, 9999, DIALOG_STYLE_MSGBOX, "{FFD700}Statistik Karakter", str, "Tutup", "");

    // Bersihkan PVar
    DeletePVar(playerid, "Stats_Name");
    DeletePVar(playerid, "Stats_Money");
    DeletePVar(playerid, "Stats_AdminLevel");

    return 1;
}



// === VERSI PALING AMAN & PALING BANYAK DIPAKAI (RECOMMENDED) ===
stock ProxDetector(Float:radius, playerid, const string[], color)
{
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if(IsPlayerConnected(i) && IsPlayerInRangeOfPoint(i, radius, x, y, z))
        {
            SendClientMessage(i, color, string);
        }
    }
}

CMD:b(playerid, params[])
{
    if(!pLogged{playerid}) return SendClientMessage(playerid, COLOR_RED, "[ERROR] Kamu harus login terlebih dahulu!");
    if(isnull(params)) return SendClientMessage(playerid, -1, "[CMD] Gunakan: /b [pesan OOC]");

    new name[24];
    format(name, sizeof(name), "%s", pCharName[playerid][pSelectedChar[playerid]]);
    ReplaceUnderscore(name);

    new str[145];
    format(str, sizeof(str), "(( %s [ID:%d]: %s ))", name, playerid, params);

    ProxDetector(20.0, playerid, str, 0xAFAFAFFF); // Abu-abu muda biar kelihatan OOC
    return 1;
}

CMD:o(playerid, params[])
{
    if(!pLogged{playerid}) return SendClientMessage(playerid, COLOR_RED, "[ERROR] Kamu harus login terlebih dahulu!");
    if(isnull(params)) return SendClientMessage(playerid, -1, "[CMD] Gunakan: /o [pesan OOC global]");

    new name[24];
    format(name, sizeof(name), "%s", pCharName[playerid][pSelectedChar[playerid]]);
    ReplaceUnderscore(name);

    new str[145];
    format(str, sizeof(str), "{FF9900}[OOC GLOBAL] {FFFFFF}%s [%d]: {CCCCCC}%s", name, playerid, params);
    SendClientMessageToAll(-1, str);
    return 1;
}

CMD:ame(playerid, params[])
{
    if(!pLogged{playerid}) return SendClientMessage(playerid, COLOR_RED, "[ERROR] Kamu harus login terlebih dahulu!");
    if(isnull(params)) return SendClientMessage(playerid, -1, "[CMD] Gunakan: /ame [aksi]");

    new name[24], str[128];
    format(name, sizeof(name), "%s", pCharName[playerid][pSelectedChar[playerid]]);
    ReplaceUnderscore(name);

    format(str, sizeof(str), "* %s %s", name, params);
    SetPlayerChatBubble(playerid, str, 0xC2A2DAAA, 30.0, 5000);

    ProxDetector(20.0, playerid, str, 0xC2A2DAAA);
    return 1;
}

CMD:ado(playerid, params[])
{
    if(!pLogged{playerid}) return SendClientMessage(playerid, COLOR_RED, "[ERROR] Kamu harus login terlebih dahulu!");
    if(isnull(params)) return SendClientMessage(playerid, -1, "[CMD] Gunakan: /ado [deskripsi]");

    new name[24], str[128];
    format(name, sizeof(name), "%s", pCharName[playerid][pSelectedChar[playerid]]);
    ReplaceUnderscore(name);

    format(str, sizeof(str), "* %s (( %s ))", params, name);
    SetPlayerChatBubble(playerid, str, 0xE0FFFFFF, 30.0, 10000);

    ProxDetector(25.0, playerid, str, 0xE0FFFFFF);
    return 1;
}

CMD:low(playerid, params[])
{
    if(!pLogged{playerid}) return 0;
    if(isnull(params)) return SendClientMessage(playerid, -1, "[CMD] Gunakan: /low [teks pelan]");

    new name[24];
    format(name, sizeof(name), "%s", pCharName[playerid][pSelectedChar[playerid]]);
    ReplaceUnderscore(name);

    new str[128];
    format(str, sizeof(str), "%s says (low): %s", name, params);
    ProxDetector(5.0, playerid, str, 0xDDDDDDFF);
    return 1;
}

CMD:w(playerid, params[])
{
    if(!pLogged{playerid}) return 0;
    new targetid;
    if(sscanf(params, "u", targetid)) return SendClientMessage(playerid, -1, "[CMD] Gunakan: /whisper [id/nama]");
    if(!IsPlayerConnected(targetid) || !ProxDetectorCheck(playerid, targetid, 3.0))
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] Player terlalu jauh atau tidak online!");

    new text[128], name[24], targetname[24];
    if(sscanf(params, "us[128]", targetid, text)) return SendClientMessage(playerid, -1, "[CMD] Gunakan: /whisper [id] [pesan]");

    format(name, sizeof(name), "%s", pCharName[playerid][pSelectedChar[playerid]]);
    ReplaceUnderscore(name);
    format(targetname, sizeof(targetname), "%s", pCharName[targetid][pSelectedChar[targetid]]);
    ReplaceUnderscore(targetname);

    new str[144];
    format(str, sizeof(str), "%s whispers to you: %s", name, text);
    SendClientMessage(targetid, 0xAAAAAAAA, str);

    format(str, sizeof(str), "You whisper to %s: %s", targetname, text);
    SendClientMessage(playerid, 0xAAAAAAAA, str);
    return 1;
}

// ========================================
// ADMIN COMMAND LEVEL 1+ (Junior Mod s/d Owner)
// ========================================


CMD:gethere(playerid, params[])
{
    if(pAdminLevel[playerid] < 1 || !pAdminDuty[playerid])
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] You do not have access to this command");

    new targetid;
    if(sscanf(params, "u", targetid))
        return SendClientMessage(playerid, COLOR_YELLOW, "[CMD] Gunakan: /gethere [playerid/nama]");

    if(!IsPlayerConnected(targetid))
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] Player tidak online!");

    new Float:x, Float:y, Float:z, interiorid = GetPlayerInterior(playerid), vwid = GetPlayerVirtualWorld(playerid);
    GetPlayerPos(playerid, x, y, z);

    SetPlayerInterior(targetid, interiorid);
    SetPlayerVirtualWorld(targetid, vwid);
    SetPlayerPos(targetid, x + 1.5, y, z);

    new adminname[MAX_PLAYER_NAME], targetname[MAX_PLAYER_NAME];
    GetPlayerName(playerid, adminname, sizeof(adminname));
    GetPlayerName(targetid, targetname, sizeof(targetname));

    SendClientMessage(targetid, 0xFF6347FF, "[SERVER] Kamu telah di-teleport oleh admin %s.", adminname);
    SendClientMessage(playerid, 0x00FF00FF, "[SERVER] Kamu telah menarik %s ke posisimu.", targetname);
    return 1;
}

CMD:savepos(playerid, params[])
{
    if(pAdminLevel[playerid] < 1 || !pAdminDuty[playerid])
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] You do not have access to this command");

    new Float:x, Float:y, Float:z, Float:a;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, a);

    new str[256], filename[64], File:file;
    format(filename, sizeof(filename), "savedpositions/%s.txt", pUCPName[playerid]);

    format(str, sizeof(str), "Posisi tersimpan!\r\nX: %.4f | Y: %.4f | Z: %.4f | A: %.4f\r\nInterior: %d | VW: %d",
        x, y, z, a, GetPlayerInterior(playerid), GetPlayerVirtualWorld(playerid));

    file = fopen(filename, io_write);
    if(file)
    {
        fwrite(file, str);
        fclose(file);
        SendClientMessage(playerid, COLOR_GREEN, "Posisi berhasil disimpan di folder savedpositions/%s.txt", pUCPName[playerid]);
    }
    else SendClientMessage(playerid, COLOR_RED, "Gagal menyimpan posisi!");
    return 1;
}

CMD:loadpos(playerid, params[])
{
    if(pAdminLevel[playerid] < 1 || !pAdminDuty[playerid])
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] You do not have access to this command");

    new filename[64], File:file, line[256];
    format(filename, sizeof(filename), "savedpositions/%s.txt", pUCPName[playerid]);

    file = fopen(filename, io_read);
    if(!file)
        return SendClientMessage(playerid, COLOR_RED, "Kamu belum pernah menyimpan posisi! Gunakan /savepos dulu.");

    new Float:x, Float:y, Float:z, Float:a, interiorid, vwid;

    // Baca baris ke-3 dan ke-4
    fread(file, line); // skip line 1
    fread(file, line);
    sscanf(line, "p<|:>ffff", x, y, z, a);
    fread(file, line);
    sscanf(line, "p<|:>dd", interiorid, vwid);

    fclose(file);

    SetPlayerPos(playerid, x, y, z);
    SetPlayerFacingAngle(playerid, a);
    SetPlayerInterior(playerid, interiorid);
    SetPlayerVirtualWorld(playerid, vwid);

    SendClientMessage(playerid, COLOR_GREEN, "Posisi berhasil dimuat dari file!");
    return 1;
}

// Bonus: /v untuk spawn kendaraan pribadi admin (level 3+)
CMD:v(playerid, params[])
{
    if(pAdminLevel[playerid] < 3 || !pAdminDuty[playerid])
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] Minimal Admin Level 3!");

    new modelid;
    if(sscanf(params, "i", modelid)) return SendClientMessage(playerid, COLOR_YELLOW, "[CMD] Gunakan: /v [modelid]");

    if(modelid < 400 || modelid > 611) return SendClientMessage(playerid, COLOR_RED, "Model ID kendaraan: 400-611!");

    new Float:x, Float:y, Float:z, Float:a;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, a);

    new veh = CreateVehicle(modelid, x+3, y, z+1, a+90, -1, -1, 600);
    PutPlayerInVehicle(playerid, veh, 0);
    SendClientMessage(playerid, COLOR_YELLOW, "Kendaraan %d berhasil dibuat!", modelid);
    return 1;
}

CMD:rcrestart(playerid, params[])
{
    // Hanya RCON Admin yang boleh pakai
    if(!IsPlayerAdmin(playerid))
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] You do not have access to this command");

    new ucp_name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, ucp_name, sizeof(ucp_name)); // Pasti UCP karena admin duty pakai UCP

    new string[128];
    format(string, sizeof(string), 
        "{FF0000}[SERVER RESTART] {FFFFFF}Server akan direstart dalam 10 detik oleh RCON Admin: {FFFF00}%s", ucp_name);
    SendClientMessageToAll(-1, string);
    SendClientMessageToAll(-1, "{FF6347}>>> {FFFFFF}Simpan roleplay kamu sekarang! Server restart sebentar lagi!");

    GameTextForAll("~r~SERVER RESTART~n~~w~10 detik lagi...", 10000, 3);

    // Restart setelah 10 detik
    SetTimer("DoGMXRestart", 10000, false);
    return 1;
}

// Timer restart
forward DoGMXRestart();
public DoGMXRestart()
{
    SendRconCommand("gmx");
    return 1;
}

// HAPUS FUNGSI GetPlayerNameEx yang lama! Kita ganti jadi yang ini:
stock GetUCPName(playerid)
{
    new name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));
    return name; // Selalu mengembalikan nama UCP asli (bukan karakter RP)
}

CMD:tp(playerid, params[])
{
    if(!pLogged{playerid})
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] You do not have access to this command");

    if(pAdminLevel[playerid] < 1 || !pAdminDuty[playerid]) return SendClientMessage(playerid, COLOR_RED, "[ERROR] You do not have access to this command");

    // Cek apakah pernah klik map
    if(g_LastMapClick[0][playerid] == 0.0 && g_LastMapClick[1][playerid] == 0.0 && g_LastMapClick[2][playerid] == 0.0)
        return SendClientMessage(playerid, COLOR_RED, "Tidak ada lokasi teleport yang disimpan! Klik dulu di peta.");

    // Teleport player
    SetPlayerPos(playerid, 
        g_LastMapClick[0][playerid], 
        g_LastMapClick[1][playerid], 
        g_LastMapClick[2][playerid] + 1.0  // +1 biar ga masuk tanah
    );

    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);

    SendClientMessage(playerid, COLOR_GREEN, "[TP] Teleport berhasil ke lokasi yang dipilih di peta!");

    return 1;
}

CMD:menu(playerid, params[])
{
    if(!pLogged{playerid}) return SendClientMessage(playerid, COLOR_RED, "[ERROR] Kamu harus login terlebih dahulu!");

    new string[512];

    strcat(string, "{FFFFFF}Informasi Server\n");
    strcat(string, "{FFFFFF}Tukar Kode Premium\n");
    strcat(string, "{FFFFFF}ATM & Bank\n");
    strcat(string, "{FFFFFF}Statistik Karakter\n");
    strcat(string, "{FFFFFF}Bantuan & Peraturan\n");
    if(pAdminLevel[playerid] >= 1)
        strcat(string, "{FFFFFF}Admin Menu (khusus staff)");

    ShowPlayerDialog(playerid, DIALOG_MENU_UTAMA, DIALOG_STYLE_LIST, "{FFD700}Menu Utama Legacy State Roleplay", string, "Pilih", "Keluar");
    return 1;
}

CMD:admin(playerid, params[])
{
    if(!pLogged{playerid}) 
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] Kamu harus login terlebih dahulu!");

    new count = 0;
    new line[128];

    // Header keren
    SendClientMessage(playerid, 0xFFD700FF, "------------------------------------------------------------------------");
    SendClientMessage(playerid, 0xFF6347FF, "    ADMIN YANG SEDANG ON DUTY       ");
    SendClientMessage(playerid, 0xFFD700FF, "------------------------------------------------------------------------");

    for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if(IsPlayerConnected(i) && pAdminLevel[i] >= 1 && pAdminDuty[i])
        {
            count++;

            new levelname[32];
            switch(pAdminLevel[i])
            {
                case 1: levelname = "Junior Moderator";
                case 2: levelname = "Moderator";
                case 3: levelname = "Senior Moderator";
                case 4: levelname = "Administrator";
                case 5: levelname = "Head Admin";
                case 6: levelname = "Server Owner";
                default: levelname = "Staff";
            }

            format(line, sizeof(line), " {FF0000}%s {A0A0A0}(ID: %d) - {FFD700}%s", pUCPName[i], i, levelname);
            SendClientMessage(playerid, -1, line);
        }
    }

    if(count == 0)
    {
        SendClientMessage(playerid, 0xFFFFFFFF, "   Tidak ada admin yang sedang on duty saat ini.");
    }

    SendClientMessage(playerid, 0xFFD700FF, "------------------------------------------------------------------------");
    return 1;
}

CMD:akun(playerid)
{
    if(!pLogged{playerid}) return 0;
    
    new str[128];
    format(str, sizeof(str), "{FFD700}[AKUN] {FFFFFF}UCP: {00FF00}%s {FFFFFF}| Admin Level: {00FF00}%d", 
        pUCPName[playerid], pAdminLevel[playerid]);
    SendClientMessage(playerid, -1, str);
    return 1;
}

CMD:admins(playerid, params[])
{
    if(!pLogged{playerid}) 
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] Kamu harus login terlebih dahulu!");

    new count = 0;
    new line[128];

    // Header keren
    SendClientMessage(playerid, 0xFFD700FF, "------------------------------------------------------------------------");
    SendClientMessage(playerid, 0xFF6347FF, "    ADMIN YANG SEDANG ON DUTY       ");
    SendClientMessage(playerid, 0xFFD700FF, "------------------------------------------------------------------------");

    for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if(IsPlayerConnected(i) && pAdminLevel[i] >= 1 && pAdminDuty[i])
        {
            count++;

            new levelname[32];
            switch(pAdminLevel[i])
            {
                case 1: levelname = "Junior Moderator";
                case 2: levelname = "Moderator";
                case 3: levelname = "Senior Moderator";
                case 4: levelname = "Administrator";
                case 5: levelname = "Head Admin";
                case 6: levelname = "Server Owner";
                default: levelname = "Staff";
            }

            format(line, sizeof(line), " {FF0000}%s {A0A0A0}(ID: %d) - {FFD700}%s", pUCPName[i], i, levelname);
            SendClientMessage(playerid, -1, line);
        }
    }

    if(count == 0)
    {
        SendClientMessage(playerid, 0xFFFFFFFF, "   Tidak ada admin yang sedang on duty saat ini.");
    }

    SendClientMessage(playerid, 0xFFD700FF, "------------------------------------------------------------------------");
    return 1;
}


// Command /kode – HANYA ADMIN
CMD:kode(playerid, params[])
{
    if(pAdminLevel[playerid] < 1 || !pAdminDuty[playerid]) return SendClientMessage(playerid, COLOR_RED, "[ERROR]Hanya admin on duty yang bisa menggunakan command ini!");

    ShowPlayerDialog(playerid, DIALOG_SET_KODE, DIALOG_STYLE_INPUT, "{FFD700}Set Kode Premium Baru",
        "{FFFFFF}Masukkan kode premium baru (maks 32 karakter):\n\n{FFFF00}Contoh: LEGACYDEC2025", "Set", "Batal");
    return 1;
}

CMD:report(playerid, params[])
{
    if(!pLogged{playerid}) return SendClientMessage(playerid, COLOR_RED, "[ERROR] Kamu harus login terlebih dahulu!");
    
    if(gettime() - LastReportTime[playerid] < REPORT_COOLDOWN)
        return SendClientMessage(playerid, COLOR_RED, "[REPORT] Tunggu beberapa detik sebelum report lagi!");

    if(isnull(params))
        return SendClientMessage(playerid, COLOR_YELLOW, "[CMD] Gunakan: /report [alasan laporan]");

    if(strlen(params) > 100)
        return SendClientMessage(playerid, COLOR_RED, "[REPORT] Alasan terlalu panjang! Maksimal 100 karakter.");

    if(ReportCount >= MAX_REPORTS) ReportCount = 0; // loop

    format(ReportText[ReportCount], 128, "%s", params);
    ReportPlayer[ReportCount] = playerid;
    ReportTime[ReportCount] = gettime();
    ReportCount++;

    LastReportTime[playerid] = gettime();

    // Kirim ke semua admin yang on duty
    new pname[MAX_PLAYER_NAME], string[256];
    GetPlayerName(playerid, pname, sizeof(pname));
    ReplaceUnderscore(pname);

    for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if(IsPlayerConnected(i) && pAdminLevel[i] >= 1 && pAdminDuty[i])
        {
            SendClientMessage(i, 0xFF6347FF, "================================");
            format(string, sizeof(string), "{FF0000}[REPORT] {FFFFFF}%s (ID: %d)", pname, playerid);
            SendClientMessage(i, -1, string);
            format(string, sizeof(string), "{FFFFFF}Alasan: {FFFF00}%s", params);
            SendClientMessage(i, -1, string);
            SendClientMessage(i, 0xFF6347FF, "================================");
        }                                     
    }

    SendClientMessage(playerid, 0x00FF00FF, "[REPORT] Report kamu telah dikirim ke admin yang sedang on duty. Terima kasih!");
    return 1;
}

CMD:ask(playerid, params[])
{
    if(!pLogged{playerid}) return SendClientMessage(playerid, COLOR_RED, "[ERROR] Kamu harus login terlebih dahulu!");
    
    if(isnull(params))
        return SendClientMessage(playerid, COLOR_YELLOW, "[CMD] Gunakan: /ask [pertanyaan]");

    new pname[MAX_PLAYER_NAME], string[256];
    GetPlayerName(playerid, pname, sizeof(pname));
    ReplaceUnderscore(pname);

    for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if(IsPlayerConnected(i) && pAdminLevel[i] >= 1 && pAdminDuty[i])
        {
            format(string, sizeof(string), "{00FFFFFF}[ASK] {FFFFFF}%s (ID: %d): {FFFF00}%s", pname, playerid, params);
            SendClientMessage(i, 0x87CEEBFF, string);
        }
    }

    SendClientMessage(playerid, 0x87CEEBFF, "[ASK] Pertanyaan kamu telah dikirim ke admin. Tunggu jawaban ya!");
    return 1;
}

CMD:reports(playerid, params[])
{
    if(!pLogged{playerid}) return SendClientMessage(playerid, COLOR_RED, "[ERROR] Kamu harus login terlebih dahulu!");

    new string[1024], line[128], found = 0;
    new currentTime = gettime();

    SendClientMessage(playerid, 0xFFD700FF, "====================================");
    SendClientMessage(playerid, 0xFF6347FF, "             DAFTAR REPORT TERKINI");
    SendClientMessage(playerid, 0xFFD700FF, "====================================");
                                             
    for(new i = 0; i < MAX_REPORTS; i++)
    {
        if(ReportPlayer[i] != -1 && IsPlayerConnected(ReportPlayer[i]))
        {
            new pname[MAX_PLAYER_NAME];
            GetPlayerName(ReportPlayer[i], pname, sizeof(pname));
            ReplaceUnderscore(pname);

            new minutes = (currentTime - ReportTime[i]) / 60;
            format(line, sizeof(line), " {FF0000}%02d {FFFFFF}%s (ID: %d) - {FFFF00}%s (%d menit lalu)", 
                i, pname, ReportPlayer[i], ReportText[i], minutes);
            strcat(string, line, sizeof(string));
            strcat(string, "\n", sizeof(string));
            found++;
        }
    }

    if(found == 0)
    {
        SendClientMessage(playerid, 0xFFFFFFFF, "[REPORTS] Belum ada report saat ini.");
    }
    else
    {
        SendClientMessage(playerid, -1, string);
        format(line, sizeof(line), " Total Report Aktif: {FF0000}%d", found);
        SendClientMessage(playerid, 0xFFD700FF, line);
    }

    SendClientMessage(playerid, 0xFFD700FF, "====================================");
    return 1;
}

CMD:answer(playerid, params[])
{
    if(pAdminLevel[playerid] < 1 || !pAdminDuty[playerid])
        return SendClientMessage(playerid, COLOR_RED, "[ANS] You do not have access to this command");

    new targetid, pesan[128];
    if(sscanf(params, "us[128]", targetid, pesan))
        return SendClientMessage(playerid, COLOR_YELLOW, "[CMD] Gunakan: /answer [playerid] [jawaban]");

    if(!IsPlayerConnected(targetid))
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] Player tidak online!");

    if(isnull(pesan))
        return SendClientMessage(playerid, COLOR_RED, "[ERROR] Tulis jawaban terlebih dahulu!");

    new adminname[MAX_PLAYER_NAME], playername[MAX_PLAYER_NAME];
    GetPlayerName(playerid, adminname, sizeof(adminname));
    GetPlayerName(targetid, playername, sizeof(playername));
    ReplaceUnderscore(adminname);
    ReplaceUnderscore(playername);

    // Kirim ke player yang nanya

    format(pesan, sizeof(pesan), "[ASK] {FFD700}%s {FFFFFF}(Admin): {87CEEB}%s", adminname, pesan);
    SendClientMessage(targetid, -1, pesan);


    // Konfirmasi ke admin
    format(pesan, sizeof(pesan), "[ANS] Kamu telah menjawab pertanyaan {00FF00}%s (ID: %d)", playername, targetid);
    SendClientMessage(playerid, 0x00FF00FF, pesan);

    // Broadcast ke semua admin on duty (opsional, biar tahu siapa yang dijawab)
    for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
    {
        if(IsPlayerConnected(i) && pAdminLevel[i] >= 1 && pAdminDuty[i] && i != playerid)
        {
            format(pesan, sizeof(pesan), "[ADMIN] %s menjawab pertanyaan %s (ID: %d)", adminname, playername, targetid);
            SendClientMessage(i, 0x87CEEBFF, pesan);
        }
    }

    return 1;
}

// Helper untuk /whisper
stock ProxDetectorCheck(playerid, targetid, Float:range)
{
    new Float:x1, Float:y1, Float:z1;
    GetPlayerPos(playerid, x1, y1, z1);
    return IsPlayerInRangeOfPoint(targetid, range, x1, y1, z1);
}