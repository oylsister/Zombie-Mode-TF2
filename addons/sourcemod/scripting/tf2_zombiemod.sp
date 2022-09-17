#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdktools>
#include <sdkhooks>

#include <tf2_zm>

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

#define MAXCLASS 10

enum struct HumanClass_Data
{
	char hc_classname[64];
	float hc_speed;
	int hc_health;
}

enum struct ZombieClass_Data
{
	char zc_classname[64];
	char zc_modelpath[PLATFORM_MAX_PATH];
	float zc_speed;
	int zc_health;
}

HumanClass_Data g_humanclass[MAXCLASS];
ZombieClass_Data g_zombieclass[MAXCLASS];

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
	HookEvent("player_hurt", OnPlayerHurt);
	
	g_Cvar_Countdown = CreateConVar("zm_infect_countdown_length", "20.0", "Timer countdown for first mother zombie infection.", _, true, 5.0, false);
	g_Cvar_InfectRatio = CreateConVar("zm_infect_motherzombie_ratio", "7.0", "Ratio for motherzombie to spawn in first infection.", _, true, 1.0, true, 32.0);
}

public void OnConfigsExecuted()
{
	ClassInit();
}

void ClassInit()
{
	ClassHumanLoad();
	ClassZombieLoad();
}

void ClassHumanLoad()
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/zm/humans.cfg");
	
	if(!FileExists(path))
	{
		SetFailState("Couldn't find human class config file \"%s\".", path);
		return;
	}
	
	KeyValues kv = CreateKeyValues("human");
	FileToKeyValues(kv, path);
	
	int classindex = 0;
	
	if(KvGotoFirstSubKey(kv))
	{
		do
		{
			KvGetSectionName(kv, g_humanclass[classindex].hc_classname, 64);
			g_humanclass[classindex].hc_speed = KvGetFloat(kv, "speed", 300.0);
			g_humanclass[classindex].hc_health = KvGetNum(kv, "health", 200);
		}
		while(KvGotoNextKey(kv));
	}
	
	delete kv;
}

void ClassZombieLoad()
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/zm/zombie.cfg");
	
	if(!FileExists(path))
	{
		SetFailState("Couldn't find zombie class config file \"%s\".", path);
		return;
	}
	
	KeyValues kv = CreateKeyValues("zombie");
	FileToKeyValues(kv, path);
	
	int classindex = 0;
	
	if(KvGotoFirstSubKey(kv))
	{
		do
		{
			KvGetSectionName(kv, g_zombieclass[classindex].zc_classname, 64);
			KvGetString(kv, "model_path", g_zombieclass[classindex].zc_modelpath, PLATFORM_MAX_PATH, "default");
			g_zombieclass[classindex].zc_speed = KvGetFloat(kv, "speed", 300.0);
			g_zombieclass[classindex].zc_health = KvGetNum(kv, "health", 200);
		}
		while(KvGotoNextKey(kv));
	}
	
	delete kv;
}

public void OnRoundActive(Event event, const char[] name, bool dontBroadcast)
{
	InitFirstInfection();
}

public void OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if(bZombie[attacker])
	{
		InfectClient(client);
	}
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

void InfectClient(int client, bool motherzombie = false)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}

	bZombie[client] = true;
	
	PrintToChat(client, "[ZM] You have been infected!");

	TFClassType clientclass = TF2_GetPlayerClass(client);

	ApplyClientZombieClass(client, clientclass);
	
	if(motherzombie)
	{
		g_bAlreadyMother[client] = true;
	}
}

void ApplyClientZombieClass(int client, TFClassType class)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}

	int classconvert = view_as<int>(class);
	int classindex = GetClassIndexByName(g_sClassString[classconvert], bZombie[client]);

	SetEntityModel(client, g_zombieclass[classindex].zc_modelpath);
	SetEntityHealth(client, g_zombieclass[classindex].zc_health);
}

int GetClassIndexByName(const char[] classname, bool zombie)
{
	if(!zombie)
	{
		for(int i = 0; i < MAXCLASS; i++)
		{
			if(StrEqual(classname, g_humanclass[i].hc_classname))
			{
				return i;
			}
		}
	}

	else
	{
		for(int i = 0; i < MAXCLASS; i++)
		{
			if(StrEqual(classname, g_zombieclass[i].zc_classname))
			{
				return i;
			}
		}
	}

	return -1;
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

void TF_TerminateRound(TFTeam team)
{
	if(team != TFTeam_Blue && team != TFTeam_Red)
		team = TFTeam_Unassigned;
		
	int entity = -1;
	entity = FindEntityByClassname(entity, "game_round_win");
	
	if(entity < 1)
	{
		entity = CreateEntityByName("game_round_win");
		
		if(IsValidEntity(entity))
			DispatchSpawn(entity);
			
		else
		{
			SetFailState("Unable to find or create a game_round_win entity!");
			return;
		}
	}
	
	SetVariantInt(view_as<int>(team));
	AcceptEntityInput(entity, "SetTeam");
	AcceptEntityInput(entity, "RoundWin");
}
