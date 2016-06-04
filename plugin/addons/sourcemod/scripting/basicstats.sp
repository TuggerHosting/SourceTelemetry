#include <sourcemod>
#include <sdktools>
#include <regex>
#include <cURL>

public Plugin:myinfo =
{
	name = "basicstats",
	author = "Tugger",
	version = "1.1",
	description = "basic stats tracking for the round",
	url = "http://brokenmice.com"
};

new String:URL[] = ""; //add your url here

new String:EventLog[1000000];
new Float:gtime;

new CURL_Default_opt[][2] = {
	{_:CURLOPT_NOSIGNAL,1},
	{_:CURLOPT_NOPROGRESS,1},
	{_:CURLOPT_TIMEOUT,30},
	{_:CURLOPT_CONNECTTIMEOUT,60},
	{_:CURLOPT_VERBOSE,0}
};

ConVar g_StatsKey;
ConVar g_ListenPort;

new String:SteamID[MAXPLAYERS][128];
new String:PlayerName[MAXPLAYERS][128];

#define CURL_DEFAULT_OPT(%1) curl_easy_setopt_int_array(%1, CURL_Default_opt, sizeof(CURL_Default_opt))
#define CLOSEHANDLE(%1) if(%1 != INVALID_HANDLE) { CloseHandle(%1); %1 = INVALID_HANDLE; }


new bool:gameRunning = false;


public OnPluginStart()
{
	HookEvent("player_connect", Event_PlayerConnect);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	HookEvent("player_death",Event_PlayerDeath);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("controlpoint_captured", Event_ControlPointCaptured);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("game_init", Event_InitStart);
	HookEvent("game_start", Event_InitStart);
	HookEvent("weapon_fire", Event_WeaponFired);
	HookEvent("player_team", Event_PlayerTeam);
	RegConsoleCmd("stat", Cmd_Stats);
	RegConsoleCmd("mystats", Cmd_MyStats);
	RegConsoleCmd("last", Cmd_Last);
	RegConsoleCmd("testpage", Cmd_TestPage);
	RegConsoleCmd("testsend", Cmd_TestSend);

	RegConsoleCmd("steamid", Cmd_steamid);
	RegConsoleCmd("report", Cmd_Report);
	RegConsoleCmd("alive", Cmd_Alive);
	gtime = GetEngineTime();

	g_StatsKey = CreateConVar("tfta_key", "demokey", "access key for tugger full-take analytics");
	g_ListenPort = FindConVar("hostport");
}


public Action:Cmd_Stats(client, args)
{
	
	ShowMOTDPanel(client, "stats", "http://brokenmice.com/gamestats/index.php", MOTDPANEL_TYPE_URL);
}

public Action:Cmd_MyStats(client, args)
{
	new String:buffer[512];
	new String:steamid[256];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));	
	Format(buffer, sizeof(buffer), "http://brokenmice.com/gamestats/player.php?s=%s", steamid );
	ShowMOTDPanel(client, "stats", buffer, MOTDPANEL_TYPE_URL);
	
}

public Action:Cmd_Last(client, args)
{
	ShowMOTDPanel(client, "stats", "http://brokenmice.com/gamestats/last.php", MOTDPANEL_TYPE_URL);
}

public Action:Cmd_Report(client, args)
{
	PrintToConsole(client, EventLog);
}

public Action:Cmd_TestPage(client, args)
{
	ShowMOTDPanel(client, "stats", "http://brokenmice.com/gamestats/static.html", MOTDPANEL_TYPE_URL);
}

public Action:Cmd_TestSend(client, args)
{
	SendInfo("//ignore//this//test//message");
}



public Action:Event_PlayerConnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new Float:currentTime = GetEngineTime() - gtime;
	new String:networkID[128];
	GetEventString(event, "networkid", networkID, sizeof(networkID));
	new String:playerName[256];
	GetEventString(event, "name",playerName, sizeof(playerName));
	ReplaceString(playerName, sizeof(playerName), "\t", " ");
	new String:playerIP[128];
	GetEventString(event, "address", playerIP, sizeof(playerIP));
	new String:cinfo[512];
	Format(cinfo, sizeof(cinfo), "%6.2f\tconnected\t%s\t%s\t%s", currentTime, networkID, playerIP, playerName );
	Format(SteamID[client], 128, "%s", SteamID);
	Format(PlayerName[client], 128, "%s" , playerName);
	SendInfo(cinfo);
	return Plugin_Continue;
}

public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Float:currentTime = GetEngineTime() - gtime;
	new String:networkID[128];
	GetEventString(event, "networkid", networkID, sizeof(networkID));
	new String:buffer[512];
	Format(buffer, sizeof(buffer), "%6.2f\tdisconnect\t%s", currentTime, networkID )
	SendInfo(buffer);
	return Plugin_Continue;
}

public Action:Event_WeaponFired(Handle:event, const String:name[], bool:dontBroadcast)
{
	if ( gameRunning == false ){
		return Plugin_Continue;
	}
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new weaponid = GetEventInt(event, "weaponid");
	new Float:ang[3];
	new Float:pos[3];
	GetClientEyeAngles(client, ang);
	GetClientAbsOrigin(client, pos);
	new Float:currentTime = GetEngineTime() - gtime;
	Format(EventLog, sizeof(EventLog), "%s\n%6.2f\tfired\t%s\t%s\t%d\t%7.2f\t%7.2f\t%7.2f\t%7.2f\t%7.2f", 
		EventLog, currentTime, SteamID[client], PlayerName[client], weaponid, pos[0], pos[1], pos[2], ang[1], ang[0]);
	return Plugin_Continue;
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new Float:currentTime = GetEngineTime() - gtime;
	new team = GetClientTeam(client);
	Format(EventLog, sizeof(EventLog), "%s\n%6.2f\tspawn\t%s\t%s%d", EventLog, currentTime, SteamID[client], PlayerName[client], team );
	return Plugin_Continue;
} //this doesn't work for whatever reason :(

public Action:Event_GrenadeThrown(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new gID = GetEventInt(event, "id");
	new Float:pos[3];
	GetClientAbsOrigin(client, pos);
	new Float:currentTime = GetEngineTime() - gtime;
	Format(EventLog, sizeof(EventLog), "%s\n%6.2f\tgrenade_detonate\t%s\t%s\t%d\t%7.2f\t%7.2f\t%7.2f", EventLog, currentTime, 
		SteamID[client], PlayerName[client], gID, pos[0], pos[1], pos[2]);
	return Plugin_Continue;
}

public Action:Event_GrenadeDetonate(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new Float:posx = GetEventFloat(event, "x");
	new Float:posy = GetEventFloat(event, "y");
	new Float:posz = GetEventFloat(event, "z");
	new gID = GetEventInt(event, "id");
	new Float:currentTime = GetEngineTime() - gtime;
	Format(EventLog, sizeof(EventLog), "%s\n%6.2f\tgrenade_detonate\t%s\t%s\t%d\t%7.2f\t%7.2f\t%7.2f", EventLog, currentTime, 
		SteamID[client], PlayerName[client], gID, posx, posy, posz)
	return Plugin_Continue;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if ( gameRunning == false ) {
		return Plugin_Continue;
	}
	new Float:currentTime =  GetEngineTime() - gtime;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new String:attackerName[128];
	new String:attackerSteam[128];
	new Float:cang[3];
	new Float:cpos[3];
	new Float:aang[3];
	new Float:apos[3];
	if ( attacker == 0 )
	{
		Format(attackerName, sizeof(attackerName), "The Cruel World");
		Format(attackerSteam, sizeof(attackerSteam), "World");
	}
	else
	{
		strcopy(attackerName, sizeof(attackerName), PlayerName[attacker]);
		strcopy(attackerSteam, sizeof(attackerSteam), SteamID[attacker]);
		GetClientEyeAngles(attacker, aang);
		GetClientAbsOrigin(attacker, apos);
	}
	GetClientEyeAngles(client, cang);
	GetClientAbsOrigin(client, cpos);
	Format(EventLog, sizeof(EventLog), "%s\n%6.2f\tkilled\t%s\t%s\t%7.2f\t%7.2f\t%7.2f\t%7.2f\t%7.2f\t%s\t%s\t%7.2f\t%7.2f\t%7.2f\t%7.2f\t%7.2f", EventLog, currentTime, 
		SteamID[client], PlayerName[client], cpos[0], cpos[1], cpos[2], cang[1], cang[0],
		attackerSteam, attackerName, apos[0], apos[1], apos[2], aang[1], aang[0]);
	return Plugin_Continue;
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if ( gameRunning == false ) {
		return Plugin_Continue;
	}
	new Float:currentTime = GetEngineTime() - gtime;
	new String:weapon[128];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	new hitgroup = GetEventInt(event, "hitgroup");
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new String:attackerSteam[128];
	new String:attackerName[128];
	new Float:cang[3];
	new Float:cpos[3];
	new Float:aang[3];
	new Float:apos[3];
	if ( attacker == 0 )
	{
		Format(attackerName, sizeof(attackerName), "The Cruel World");
		Format(attackerSteam, sizeof(attackerSteam), "World");
	}
	else
	{
		strcopy(attackerName, sizeof(attackerName), PlayerName[attacker]);
		strcopy(attackerSteam, sizeof(attackerSteam), SteamID[attacker]);
		GetClientEyeAngles(attacker, aang);
		GetClientAbsOrigin(attacker, apos);
	}
	GetClientEyeAngles(client, cang);
	GetClientAbsOrigin(client, cpos);
	Format(EventLog, sizeof(EventLog), "%s\n%6.2f\thurt\t%s\t%s\t%d\t%7.2f\t%7.2f\t%7.2f\t%7.2f\t%7.2f\t%s\t%s\t%7.2f\t%7.2f\t%7.2f\t%7.2f\t%7.2f", EventLog, currentTime, 
		SteamID[client], PlayerName[client], hitgroup, cpos[0], cpos[1], cpos[2], cang[1], cang[0],
		attackerSteam, attackerName, apos[0], apos[1], apos[2], aang[1], aang[0]);
	return Plugin_Continue;
}

public Action:Event_ControlPointCaptured(Handle:event, const String:name[], bool:dontBroadcast)
{
	if ( gameRunning == false ) 
	{
		return Plugin_Continue;
	}
	new cp = GetEventInt(event, "cp");
	new Float:currentTime = GetEngineTime() - gtime;
	new String:cappers[256];
	GetEventString(event, "cappers", cappers, sizeof(cappers));

	new team = GetEventInt(event, "team");
	for (new i = 0; i < strlen(cappers); i++)
	{
		new client = cappers[i];
		if(client > 0 && client <= MaxClients && IsClientInGame(client))
		{
			Format(EventLog, sizeof(EventLog), "%s\n%6.2f\tcapture\t%s\t%s\t%i\t%i",EventLog, currentTime, SteamID[client], PlayerName[client], team, cp);
		}
	}
	return Plugin_Continue;
}

public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new team = GetEventInt(event, "team");
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new Float:currentTime = GetEngineTime() - gtime;
	Format(EventLog, sizeof(EventLog), "%s\n%6.2f\tteam\t%s\t%s\t%d", EventLog, currentTime, SteamID[client], PlayerName[client], team );
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	gameRunning = true;
	new String.statsKey[256];
	g_StatsKey.GetString(statsKey, 128);
	new String:mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	gtime = GetEngineTime()
	Format(EventLog,sizeof(EventLog),"round_start\t%s\t%s\n", statsKey, g_ListenPort.Intvalue, mapName );
	new team;
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if(IsClientInGame(i))
		{
			GetClientName(i, PlayerName[i], 128);
			ReplaceString(PlayerName[i], 128, "\t", " ");

			GetClientAuthId(i, AuthId_Steam2, SteamID[i], 128);
			team = GetClientTeam(i);
			Format(EventLog, sizeof(EventLog), "%s\n%4.2f\tteam\t%s\t%s\t%d", EventLog, 0.00, SteamID[i], PlayerName[i], team );
		}/*
		else
		{
			PrintToServer("client %d is not InGame", i);
		}*/
	}
	CreateTimer(0.2, Timer_GetPositions, _, TIMER_REPEAT);
	return Plugin_Continue;
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	gameRunning = false;
	SendInfo( EventLog );
	return Plugin_Continue;
}



public Action:Event_InitStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	gameRunning = false;
	return Plugin_Continue;
}


public Action:Cmd_Alive(client, args)
{
	for (new i=1; i <= GetMaxClients(); i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i))
		{
			PrintToConsole(client, "client %i is alive: %s", i, SteamID[i]);
		}
	}
}

public Action:Cmd_steamid(client, args)
{
	new String:steamID[256];
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if(IsClientInGame(i))
		{
			GetClientAuthId(i, AuthId_Steam2, steamID, sizeof(steamID));
			strcopy(SteamID[i], 256, steamID);
		}
	}
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		PrintToConsole(client, "client %i is alive: %s", i, SteamID[i]);
	}

}

public Action:Timer_GetPositions(Handle:timer)
{
	if ( gameRunning == false ){
		return Plugin_Stop;
	}
	new Float:currentTime = GetEngineTime() - gtime;
	new Float:origin[3];
	new Float:angles[3];
	new aliveClients;
	for (new i=1; i <= GetMaxClients(); i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i,origin);
			GetClientEyeAngles(i,angles);
			Format(EventLog, sizeof(EventLog), "%s\n%5.2f\tpos\t%s\t%7.1f\t%7.1f\t%7.1f\t%7.1f\t%7.1f",EventLog, currentTime, SteamID[i], origin[0], origin[1], origin[2], angles[1], angles[0]);
			aliveClients++;
		}
	}
	//PrintToServer("clients position recorded: %i", aliveClients);
	return Plugin_Continue;
}



SendInfo(String:cinfo[])
{
	new Handle:curl = curl_easy_init();
	if(curl != INVALID_HANDLE)
	{
		CURL_DEFAULT_OPT(curl);
		curl_easy_setopt_string(curl, CURLOPT_POSTFIELDS, cinfo);
		curl_easy_setopt_string(curl, CURLOPT_URL, URL);
		curl_load_opt(curl);
		curl_easy_perform_thread(curl, closeCURLHandle, 1);
	}
	else
	{
		PrintToServer("error with basic stats cURL");
	}
}

closeCURLHandle(Handle:curl, CURLcode: res)
{
	if(res != CURLE_OK)
	{
		new String:CurlError[1024];
		curl_easy_strerror(res, CurlError, sizeof(CurlError));
		PrintToServer("curl_easy_perform_thread() failed: %s\n", CurlError);
	}
	CloseHandle(curl);
}

