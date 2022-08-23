#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <sdktools>

#pragma newdecls required

bool bZombie[MAXPLAYERS+1] = {false, ...};

Handle g_hFirstInfectTimer = INVALID_HANDLE;
Handle g_hCountdownInfect = INVALID_HANDLE;

ConVar g_Cvar_Countdown;
ConVar g_Cvar_InfectRatio;

float g_fCountdown;
int g_iCountdownLeft;

float g_fInfectRatio;

bool g_bZombieSpawned;
bool g_bAlreadyMother[MAXPLAYERS+1] = {false, ...};

public Plugin myinfo = 
{
	name = "[TF2] Zombie Mod",
	author = "Oylsister",
	description = "Infection gamemode PVP for Team Fortress 2",
	version = "1.0a",
	url = "https://github.com/oylsister/Zombie-Mode-TF2"
}

public void OnPluginStart()
{
	HookEvent("teamplay_round_active", OnRoundActive);
	HookEvent("teamplay_win_panel", OnRoundEnd);
	
	g_Cvar_Countdown = CreateConVar("zm_infect_countdown_length", "20.0", "Timer countdown for first mother zombie infection.", _, true, 5.0, false);
	g_Cvar_InfectRatio = CreateConVar("zm_infect_motherzombie_ratio", "7.0", "Ratio for motherzombie to spawn in first infection.", _, true, 1.0, true, 32.0);
}

public void OnRoundActive(Event event, const char[] name, bool dontBroadcast)
{
	InitFirstInfection();
}

void InitFirstInfection()
{
	if(g_hFirstInfectTimer != INVALID_HANDLE)
	{
		KillTimer(g_hFirstInfectTimer);
		g_hFirstInfectTimer = INVALID_HANDLE;
	}
	
	if(g_hCountdownInfect != INVALID_HANDLE)
	{
		KillTimer(g_hCountdownInfect);
		g_hCountdownInfect = INVALID_HANDLE;
	}
	
	g_fCountdown = g_Cvar_Countdown.FloatValue;
	
	g_iCountdownLeft = RoundToNearest(g_fCountdown);
	
	g_hFirstInfectTimer = CreateTimer(g_fCountdown, InitMotherZombie);
	g_hCountdownInfect = CreateTimer(1.0, CountDownHud, _, TIMER_REPEAT);
}

public Action InitMotherZombie(Handle timer)
{
	if(g_bZombieSpawned)
		return Plugin_Handled;
		
	SpawnMotherZombie();
	g_bZombieSpawned = true;
	return Plugin_Handled;
}

void SpawnMotherZombie()
{
	int players = GetClientCount(true);
	
	g_fInfectRatio = g_Cvar_InfectRatio.FloatValue;
	
	int total = RoundToNearest(float(players) / g_fInfectRatio);
	
	for(int i = 0; i < total; i++)
	{
		int client = GetRandomPlayer();
		
		InfectClient(client, true);
	}
}

public Action CountDownHud(Handle timer)
{
	PrintCenterTextAll("First Infection Start in %d seconds", g_iCountdownLeft);
	
	if(g_bZombieSpawned)
		return Plugin_Handled;
	
	if(g_iCountdownLeft <= 0)
		return Plugin_Handled;
	
	g_iCountdownLeft--;
	return Plugin_Continue;
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			bZombie[i] = false;
	}
	
	g_bZombieSpawned = false;
}

void InfectClient(int client, bool motherzombie)
{
	if(IsClientZombie(client))
	{
		return;
	}

	bZombie[client] = true;
	
	PrintToChat(client, "[ZM] You have been infected!");
	
	if(motherzombie)
	{
		g_bAlreadyMother[client] = true;
	}
}

bool IsClientZombie(int client)
{
	return bZombie[client];
}

bool IsClientHuman(int client)
{
	return !bZombie[client];
}

stock int GetRandomPlayer()
{
    int[] clients = new int[MaxClients + 1];
    int clientCount;
    for (int i = 1; i <= MaxClients; i++)
    if (IsClientInGame(i) && IsPlayerAlive(i) && IsClientZombie(i))
        clients[clientCount++] = i;
    return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount - 1)];
} 
