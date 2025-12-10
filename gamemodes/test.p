// This is a comment
// uncomment the line below if you want to write a filterscript
//#define FILTERSCRIPT
#define DIALOG_TELEPORT 5000
#define COLOR_WHITE 0xFFFFFFFF
#define COLOR_RED   0xFF0000FF
#define COLOR_GREEN 0x00FF00FF
#define DIALOG_REGISTER    5001
#define DIALOG_LOGIN       5002

#include <a_samp>
#include <a_mysql>
#include <sqlitei>
#include <sscanf2>
#include <zcmd>


//DATABASE
#define SQL_HOST	"localhost" 
#define SQL_USER	"root"
#define SQL_PASS	""
#define SQL_DB		"samp"
new Querymsg[256];
new MySQL:sqldb;
new bool:gLogged[MAX_PLAYERS];
new bool:IsLogged[MAX_PLAYERS];




//Variables
new Float:tpX[MAX_PLAYERS];
new Float:tpY[MAX_PLAYERS];
new Float:tpZ[MAX_PLAYERS];
new Text:UI [3];

new RandomCars[] =
{
    400,401,402,404,405,409,411,412,415,418,
    419,420,421,422,424,426,429,434,436,439,
    442,445,451,458,466,467,474,475,477,478,
    479,480,489,491,492,496,500,506,507,516,
    517,518,527,529,533,540,541,542,545,546,
    547,549,550,551,554,555,558,559,560,561,
    562,565,567,575,576,579,580,585,587,589,
    600,602,603
};


#if defined FILTERSCRIPT

public OnFilterScriptInit()
{
	print("\n--------------------------------------");
	print(" Blank Filterscript by your name here");
	print("--------------------------------------\n");
	return 1;
}

public OnFilterScriptExit()
{
	return 1;
}

#else

main()
{
	print("\n----------------------------------");
	print(" LSRP BETA 0.1 by farhanboutak ");
	print("----------------------------------\n");
}

#endif

public OnGameModeInit()
{
	//tanggal
	UI[0] = TextDrawCreate(579.000000, 17.000000, "00:00");
TextDrawFont(UI[0], 2);
TextDrawLetterSize(UI[0], 0.370831, 1.899999);
TextDrawTextSize(UI[0], 400.000000, 17.000000);
TextDrawSetOutline(UI[0], 2);
TextDrawSetShadow(UI[0], 0);
TextDrawAlignment(UI[0], 2);
TextDrawColor(UI[0], -1);
TextDrawBackgroundColor(UI[0], 255);
TextDrawBoxColor(UI[0], 50);
TextDrawUseBox(UI[0], 0);
TextDrawSetProportional(UI[0], 1);
TextDrawSetSelectable(UI[0], 0);

UI[1] = TextDrawCreate(581.000000, 48.000000, "00.00.0000");
TextDrawFont(UI[1], 3);
TextDrawLetterSize(UI[1], 0.187498, 0.799997);
TextDrawTextSize(UI[1], 400.000000, 17.000000);
TextDrawSetOutline(UI[1], 2);
TextDrawSetShadow(UI[1], 0);
TextDrawAlignment(UI[1], 2);
TextDrawColor(UI[1], -1);
TextDrawBackgroundColor(UI[1], 255);
TextDrawBoxColor(UI[1], 50);
TextDrawUseBox(UI[1], 0);
TextDrawSetProportional(UI[1], 1);
TextDrawSetSelectable(UI[1], 0);

	//Textdraws
UI[0] = TextDrawCreate(267.000000, 5.000000, "Legacy");
TextDrawFont(UI[0], 0);
TextDrawLetterSize(UI[0], 0.404166, 1.450000);
TextDrawTextSize(UI[0], 400.000000, 17.000000);
TextDrawSetOutline(UI[0], 1);
TextDrawSetShadow(UI[0], 0);
TextDrawAlignment(UI[0], 1);
TextDrawColor(UI[0], -1);
TextDrawBackgroundColor(UI[0], 255);
TextDrawBoxColor(UI[0], 50);
TextDrawUseBox(UI[0], 0);
TextDrawSetProportional(UI[0], 1);
TextDrawSetSelectable(UI[0], 0);

UI[1] = TextDrawCreate(269.000000, 17.000000, "State");
TextDrawFont(UI[1], 3);
TextDrawLetterSize(UI[1], 0.404166, 1.500000);
TextDrawTextSize(UI[1], 400.000000, 17.000000);
TextDrawSetOutline(UI[1], 1);
TextDrawSetShadow(UI[1], 0);
TextDrawAlignment(UI[1], 1);
TextDrawColor(UI[1], -1);
TextDrawBackgroundColor(UI[1], 255);
TextDrawBoxColor(UI[1], 50);
TextDrawUseBox(UI[1], 0);
TextDrawSetProportional(UI[1], 1);
TextDrawSetSelectable(UI[1], 0);

UI[2] = TextDrawCreate(314.000000, 17.000000, "Roleplay");
TextDrawFont(UI[2], 3);
TextDrawLetterSize(UI[2], 0.404166, 1.450000);
TextDrawTextSize(UI[2], 400.000000, 17.000000);
TextDrawSetOutline(UI[2], 1);
TextDrawSetShadow(UI[2], 0);
TextDrawAlignment(UI[2], 1);
TextDrawColor(UI[2], -1);
TextDrawBackgroundColor(UI[2], 255);
TextDrawBoxColor(UI[2], 50);
TextDrawUseBox(UI[2], 0);
TextDrawSetProportional(UI[2], 1);
TextDrawSetSelectable(UI[2], 0);
	
	// Don't use these lines if it's a filterscript
	SetGameModeText("LS|RP BETA 0.1");
	AddPlayerClass(0, 1958.3783, 1343.1572, 15.3746, 269.1425, 0, 0, 0, 0, 0, 0);
	sqldb = mysql_connect(SQL_HOST,SQL_USER,SQL_PASS,SQL_DB);
	if(mysql_errno(sqldb) != 0){
		print("[MySQL]-----Connection Failed------");
	}
	else print("[MySQL]------Connected Successfully------");	
		return 1;
	}
	

public OnGameModeExit()
{
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	SetPlayerPos(playerid, 1681.8622,-2330.3665,13.5469,0.0702);
	SetPlayerCameraPos(playerid, 1681.8622,-2330.3665,13.5469,0.0702);
	SetPlayerCameraLookAt(playerid, 1681.8622,-2330.3665,13.5469,0.0702);
	return 1;
}

public OnPlayerConnect(playerid)
{
	IsLogged[playerid] = false;
	for ( new w = 0; w < 3; w++ )
	{
		TextDrawShowForPlayer(playerid,UI[w]);
	}
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    IsLogged[playerid] = false;
    return 1;
}

public OnPlayerSpawn(playerid)
{
	SetPlayerPos(playerid, 1682.8622,-2327.8940,13.5469);
	SetPlayerFacingAngle(playerid, 3.4335);
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	SpawnPlayer(playerid);
	return 1;
}

public OnVehicleSpawn(vehicleid)
{
	return 1;
}

public OnVehicleDeath(vehicleid, killerid)
{
	return 1;
}

public OnPlayerText(playerid, text[])
{
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if(!IsLogged[playerid])
    {
        if(!strcmp(cmdtext, "/login", true) || !strcmp(cmdtext, "/regist", true))
        {
            // dua command ini boleh
            return 0;
        }

        SendClientMessage(playerid, -1, "Kamu harus /login.");
        return 1;
    }
    return 0;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
	return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
	return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
	return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
	return 1;
}

public OnPlayerLeaveCheckpoint(playerid)
{
	return 1;
}

public OnPlayerEnterRaceCheckpoint(playerid)
{
	return 1;
}

public OnPlayerLeaveRaceCheckpoint(playerid)
{
	return 1;
}

public OnRconCommand(cmd[])
{
	return 1;
}

public OnPlayerRequestSpawn(playerid)
{
	SetPlayerPos(playerid, 1681.8622,-2330.3665,13.5469);
	SetPlayerFacingAngle(playerid,0.0702);
	return 1;
}

public OnObjectMoved(objectid)
{
	return 1;
}

public OnPlayerObjectMoved(playerid, objectid)
{
	return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
	return 1;
}

public OnVehicleMod(playerid, vehicleid, componentid)
{
	return 1;
}

public OnVehiclePaintjob(playerid, vehicleid, paintjobid)
{
	return 1;
}

public OnVehicleRespray(playerid, vehicleid, color1, color2)
{
	return 1;
}

public OnPlayerSelectedMenuRow(playerid, row)
{
	return 1;
}

public OnPlayerExitedMenu(playerid)
{
	return 1;
}

public OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid)
{
	return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	return 1;
}

public OnRconLoginAttempt(ip[], password[], success)
{
	return 1;
}

public OnPlayerUpdate(playerid)
{
	return 1;
}

public OnPlayerStreamIn(playerid, forplayerid)
{
	return 1;
}

public OnPlayerStreamOut(playerid, forplayerid)
{
	return 1;
}

public OnVehicleStreamIn(vehicleid, forplayerid)
{
	return 1;
}

public OnVehicleStreamOut(vehicleid, forplayerid)
{
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid != DIALOG_TELEPORT) return 0;

    if(response == 1) // pemain memilih "Ya"
    {
        SetPlayerPos(playerid, tpX[playerid], tpY[playerid], tpZ[playerid]);
        SendClientMessage(playerid, 0xFFFFFFAA, "Teleport berhasil");
    }
    else // pemain memilih "Tidak" atau menutup dialog
    {
        SendClientMessage(playerid, 0xFFFFFFAA, "Teleport dibatalkan");
    }
    return 1;
}

public OnPlayerClickPlayer(playerid, clickedplayerid, source)
{
	return 1;
}

public OnPlayerClickMap(playerid, Float:fX, Float:fY, Float:fZ)
{
    if(playerid < 0 || playerid >= MAX_PLAYERS) return 0;

    tpX[playerid] = fX;
    tpY[playerid] = fY;
    tpZ[playerid] = fZ;

    ShowPlayerDialog(playerid, DIALOG_TELEPORT, DIALOG_STYLE_MSGBOX, "Teleport", "Teleport ke titik ini?", "Ya", "Tidak");
    return 1;
}

// Example command using zcmd
CMD:test(playerid, params[])
{
    SendClientMessage(playerid, -1, "Command bekerja");
    return 1;
}

// CAR
CMD:car(playerid, params[])
{
    new rand = random(sizeof(RandomCars));
    new vehid;

    new Float:x, Float:y, Float:z, Float:a;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, a);

    vehid = CreateVehicle(RandomCars[rand], x + 2.0, y, z, a, 0, 0, 0);

    LinkVehicleToInterior(vehid, GetPlayerInterior(playerid));
    SetVehicleVirtualWorld(vehid, GetPlayerVirtualWorld(playerid));

    PutPlayerInVehicle(playerid, vehid, 0);

    SendClientMessage(playerid, -1, "Kendaraan random berhasil dibuat.");
    return 1;
}

// JETPACK
CMD:jetpack(playerid, params[])
{
    if(IsPlayerInAnyVehicle(playerid))
    {
        SendClientMessage(playerid, -1, "Kamu tidak boleh memakai jetpack di dalam kendaraan");
        return 1;
    }

    SetPlayerSpecialAction(playerid, SPECIAL_ACTION_USEJETPACK);
    SendClientMessage(playerid, -1, "Jetpack diberikan");
    return 1;
}

CMD:death(playerid, params[])
{
    if (IsPlayerInAnyVehicle(playerid))
    {
        SendClientMessage(playerid, COLOR_RED, "Kamu tidak bisa menggunakan /death di dalam kendaraan.");
        return 1;
    }

    SetPlayerHealth(playerid, 0.0);
    SendClientMessage(playerid, COLOR_GREEN, "Kamu telah membunuh dirimu sendiri.");
    return 1;
}

//REGIST dan LOGIN
CMD:regist(playerid, params[])
{
    if(gLogged[playerid]) return SendClientMessage(playerid, -1, "Kamu sudah login");

    new pass[64], name[MAX_PLAYER_NAME];
    if(sscanf(params, "s[64]", pass)) return SendClientMessage(playerid, -1, "/regist password");

    GetPlayerName(playerid, name, sizeof(name));

    format(Querymsg, sizeof(Querymsg), "SELECT id FROM users WHERE name='%s' LIMIT 1", name);
    mysql_tquery(sqldb, Querymsg, "OnRegistCheck", "iis", playerid, pass, name);
    return 1;
}

forward OnRegistCheck(playerid, pass[], name[]);
public OnRegistCheck(playerid, pass[], name[])
{
    if(cache_num_rows() > 0)
    {
        SendClientMessage(playerid, -1, "Akun sudah ada");
        return 1;
    }

    format(Querymsg, sizeof(Querymsg), "INSERT INTO users (name, password) VALUES('%s', '%s')", name, pass);
    mysql_tquery(sqldb, Querymsg);

    SendClientMessage(playerid, -1, "Registrasi berhasil");
    return 1;
}

//LOGIN

forward OnPlayerDataCheck(playerid);
public OnPlayerDataCheck(playerid)
{
    if(cache_num_rows() > 0)
    {
        ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "Masukkan password akun kamu:", "Login", "Keluar");
    }
    else
    {
        ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Registrasi", "Akun ini belum terdaftar!\nMasukkan password untuk mendaftar:", "Daftar", "Keluar");
    }
    return 1;
}
