// ========================================
// LSRP BETA 0.1 - FIXED & DITAMBAH FITUR
// ========================================

#define DIALOG_TELEPORT    5000
#define DIALOG_REGISTER    5001
#define DIALOG_LOGIN       5002

#define COLOR_WHITE        0xFFFFFFFF
#define COLOR_RED          0xFF0000FF
#define COLOR_GREEN        0x00FF00FF
#define COLOR_YELLOW       0xFFFF00FF

#include <a_samp>
#include <a_mysql>
#include <sscanf2>
#include <zcmd>
#include <whirlpool>

// DATABASE
#define SQL_HOST    "localhost"
#define SQL_USER    "root"
#define SQL_PASS    ""
#define SQL_DB      "samp"

new MySQL:sqldb;

// Player variables
new bool:pLogged[MAX_PLAYERS char];
new pLoginAttempts[MAX_PLAYERS];
new Float:tpX[MAX_PLAYERS], Float:tpY[MAX_PLAYERS], Float:tpZ[MAX_PLAYERS];

new Text:UI[3];

new RandomCars[] = {
    400,401,402,404,405,409,411,412,415,418,419,420,421,422,424,426,429,434,436,439,
    442,445,451,458,466,467,474,475,477,478,479,480,489,491,492,496,500,506,507,516,
    517,518,527,529,533,540,541,542,545,546,547,549,550,551,554,555,558,559,560,561,
    562,565,567,575,576,579,580,585,587,589,600,602,603
};

main() {
    print("\n==================================");
    print(" LSRP BETA 0.1 - FIXED & UPGRADED");
    print("==================================\n");
}

public OnGameModeInit()
{
    SetGameModeText("LS|RP BETA 0.1");
    AddPlayerClass(280, 1958.3783, 1343.1572, 15.3746, 269.1425, 0, 0, 0, 0, 0, 0);

    sqldb = mysql_connect(SQL_HOST, SQL_USER, SQL_PASS, SQL_DB);
    if(mysql_errno(sqldb)) print("[MySQL] Koneksi GAGAL!");
    else print("[MySQL] Koneksi Berhasil!");

    // Textdraw Logo
    UI[0] = TextDrawCreate(267.0, 5.0, "Legacy");
    TextDrawFont(UI[0], 0); TextDrawLetterSize(UI[0], 0.404166, 1.450000);
    TextDrawColor(UI[0], -1); TextDrawSetOutline(UI[0], 1); TextDrawSetProportional(UI[0], 1);

    UI[1] = TextDrawCreate(269.0, 17.0, "State");
    TextDrawFont(UI[1], 3); TextDrawLetterSize(UI[1], 0.404166, 1.500000);
    TextDrawColor(UI[1], -1); TextDrawSetOutline(UI[1], 1); TextDrawSetProportional(UI[1], 1);

    UI[2] = TextDrawCreate(314.0, 17.0, "Roleplay");
    TextDrawFont(UI[2], 3); TextDrawLetterSize(UI[2], 0.404166, 1.450000);
    TextDrawColor(UI[2], -1); TextDrawSetOutline(UI[2], 1); TextDrawSetProportional(UI[2], 1);

    return 1;
}

public OnPlayerConnect(playerid)
{
    pLogged{playerid} = false;
    pLoginAttempts[playerid] = 0;

    for(new i; i < 3; i++) TextDrawShowForPlayer(playerid, UI[i]);

    // Langsung spectate biar tidak bisa spawn
    TogglePlayerSpectating(playerid, 1);

    new name[MAX_PLAYER_NAME], query[128];
    GetPlayerName(playerid, name, sizeof(name));
    mysql_format(sqldb, query, sizeof(query), "SELECT password FROM users WHERE name = '%e' LIMIT 1", name);
    mysql_tquery(sqldb, query, "OnPlayerDataCheck", "i", playerid);
    return 1;
}

forward OnPlayerDataCheck(playerid);
public OnPlayerDataCheck(playerid)
{
    if(cache_num_rows() > 0)
        ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "Masukkan password:", "Login", "Keluar");
    else
        ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Registrasi", "Akun belum terdaftar!\nMasukkan password baru:", "Daftar", "Keluar");
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == DIALOG_REGISTER)
    {
        if(!response) return Kick(playerid);
        if(strlen(inputtext) < 6) return ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Registrasi", "Error: Password minimal 6 karakter!", "Daftar", "Keluar");

        new hash[129], name[MAX_PLAYER_NAME], query[256];
        GetPlayerName(playerid, name, sizeof(name));
        WP_Hash(hash, sizeof(hash), inputtext);
        mysql_format(sqldb, query, sizeof(query), "INSERT INTO users (name, password) VALUES ('%e', '%s')", name, hash);
        mysql_tquery(sqldb, query);

        SendClientMessage(playerid, COLOR_GREEN, "Registrasi berhasil! Kamu otomatis login.");
        pLogged{playerid} = true;
        TogglePlayerSpectating(playerid, 0);
        SpawnPlayer(playerid);
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

    if(dialogid == DIALOG_TELEPORT)
    {
        if(response)
        {
            SetPlayerPos(playerid, tpX[playerid], tpY[playerid], tpZ[playerid] + 1.0);
            SetPlayerInterior(playerid, 0);
            SetPlayerVirtualWorld(playerid, 0);
            SendClientMessage(playerid, COLOR_WHITE, "Teleportasi berhasil!");
        }
        else SendClientMessage(playerid, COLOR_WHITE, "Teleportasi dibatalkan.");
        return 1;
    }
    return 0;
}

public OnPlayerCommandPerformed(playerid, cmdtext[], success)
{
    if(!success) // artinya command yang diketik player TIDAK ADA di server
    {
        if(pLogged{playerid}) // hanya muncul kalau sudah login
        {
            new string[128];
            format(string, sizeof(string), "{FF6347}[SERVER] {FFFFFF}Perintah \"{CCCCCC}%s{FFFFFF}\" tidak ditemukan.", cmdtext);
            SendClientMessage(playerid, -1, string);
        }
        else
        {
            SendClientMessage(playerid, COLOR_RED, "Kamu harus login terlebih dahulu!");
        }
    }
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
        SendClientMessage(playerid, COLOR_GREEN, "Login berhasil! Selamat bermain di Legacy State Roleplay.");
        pLogged{playerid} = true;
        pLoginAttempts[playerid] = 0;
        TogglePlayerSpectating(playerid, 0);
        SpawnPlayer(playerid);
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

// === WAJIB: BLOKIR SPAWN SEBELUM LOGIN ===
public OnPlayerRequestClass(playerid, classid) {
    if(!pLogged{playerid}) {
        TogglePlayerSpectating(playerid, 1); // tetap spectate
        return 1;
    }
    return 1;
}

public OnPlayerRequestSpawn(playerid) {
    if(!pLogged{playerid}) {
        SendClientMessage(playerid, COLOR_RED, "Kamu harus login terlebih dahulu!");
        return 0;
    }
    return 1;
}

public OnPlayerSpawn(playerid)
{
    if(!pLogged{playerid})
    {
        Kick(playerid); // safety
        return 1;
    }
    SetPlayerPos(playerid, 1682.0001,-2330.7502,13.5469,358.5358); // spawn di LSPD atau sesuai keinginan

    return 1;
}

// Blokir chat & command sebelum login
// GANTI OnPlayerText kamu dengan ini (100% no error)
public OnPlayerText(playerid, text[])
{
    if(!pLogged{playerid})
    {
        SendClientMessage(playerid, COLOR_RED, "Kamu harus login terlebih dahulu!");
        return 0;
    }

    new name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));

    new string[144];
    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    // Cek apakah player ngetik /s untuk shout
    if(text[0] == '/' && text[1] == 's' && (text[2] == ' ' || text[2] == '\0'))
    {
        format(string, sizeof(string), "{FFFF00}%s shouts: {FFFFFF}%s", name, text[3]);
        
        // Kirim ke player dalam radius 40 meter (shout)
        for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
        {
            if(IsPlayerConnected(i) && IsPlayerInRangeOfPoint(i, 40.0, x, y, z))
            {
                SendClientMessage(i, -1, string);
            }
        }
    }
    else
    {
        format(string, sizeof(string), "{AFAFAF}%s says: {FFFFFF}%s", name, text);
        
        // Kirim ke player dalam radius 20 meter (chat biasa)
        for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
        {
            if(IsPlayerConnected(i) && IsPlayerInRangeOfPoint(i, 20.0, x, y, z))
            {
                SendClientMessage(i, -1, string);
            }
        }
    }

    return 0; // PENTING! biar chat default SA-MP gak muncul (no dobel)
}

public OnPlayerCommandText(playerid, cmdtext[]) {
    if(!pLogged{playerid}) { SendClientMessage(playerid, COLOR_RED, "Kamu harus login terlebih dahulu!"); return 1; }
    return 0;
}

// === FITUR ADMIN / PLAYER ===

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

CMD:death(playerid, params[])
{
    if(!pLogged{playerid}) return 0;
    if(IsPlayerInAnyVehicle(playerid)) return SendClientMessage(playerid, COLOR_RED, "Keluar dari kendaraan dulu!");
    SetPlayerHealth(playerid, 0.0);
    SendClientMessage(playerid, COLOR_GREEN, "Kamu telah bunuh diri.");
    return 1;
}

// Teleport dari klik peta
public OnPlayerClickMap(playerid, Float:fX, Float:fY, Float:fZ)
{
    if(!pLogged{playerid}) return SendClientMessage(playerid, COLOR_RED, "Login dulu!");
    
    tpX[playerid] = fX;
    tpY[playerid] = fY;
    tpZ[playerid] = fZ;

    ShowPlayerDialog(playerid, DIALOG_TELEPORT, DIALOG_STYLE_MSGBOX, "Teleport", 
        "Yakin ingin teleport ke lokasi di peta?", "Ya", "Tidak");
    return 1;
}