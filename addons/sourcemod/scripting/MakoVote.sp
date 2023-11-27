#include <cstrike>
#include <multicolors>
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name        = "MakoVote",
	author	    = "Neon, maxime1907, .Rushaway",
	description = "MakoVote",
	version     = "1.5",
	url         = "https://steamcommunity.com/id/n3ontm"
}

#define NUMBEROFSTAGES 7

ConVar g_cDelay;
ConVar g_cRtd;
ConVar g_cRtd_Percent;

bool g_bIsRevote = false;
bool g_bPlayedZM = false;
bool g_bVoteFinished = true;
bool bStartVoteNextRound = false;

bool g_bOnCooldown[NUMBEROFSTAGES];
static char g_sStageName[NUMBEROFSTAGES][512] = {"Extreme 2", "Extreme 2 (Heal + Ultima)", "Extreme 3 (ZED)", "Extreme 3 (Hellz)", "Race Mode", "Zombie Mode", "Extreme 3 (NiDE)"};

int g_Winnerstage;

Handle g_VoteMenu = null;
ArrayList g_StageList = null;
Handle g_CountdownTimer = null;

public void OnPluginStart()
{
	g_cDelay = CreateConVar("sm_makovote_delay", "3.0", "Time in seconds for firing the vote from admin command", FCVAR_NOTIFY, true, 1.0, true, 10.0);
	g_cRtd = CreateConVar("sm_makovote_rtd", "0", "Enable Roll The Dice", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cRtd_Percent = CreateConVar("sm_makovote_rtd_percent", "15", "Percentage chance value to trigger ZM mod with RTD", FCVAR_NOTIFY, true, 0.0, true, 100.0);

	RegAdminCmd("sm_makovote", Command_AdminStartVote, ADMFLAG_CONVARS, "sm_makovote");
	RegServerCmd("sm_makovote", Command_StartVote);

	HookEvent("round_start",  OnRoundStart);
	HookEvent("round_end", OnRoundEnd);

	AutoExecConfig(true);
}

public void OnMapStart()
{
	VerifyMap();

	bStartVoteNextRound = false;
	g_bPlayedZM = false;

	for (int i = 0; i <= (NUMBEROFSTAGES - 1); i++)
		g_bOnCooldown[i] = false;
}

stock void VerifyMap()
{
	char currentMap[64];
	GetCurrentMap(currentMap, sizeof(currentMap));
	if (!StrEqual(currentMap, "ze_FFVII_Mako_Reactor_v5_3"))
	{
		char sFilename[256];
		GetPluginFilename(INVALID_HANDLE, sFilename, sizeof(sFilename));
		ServerCommand("sm plugins unload %s", sFilename);
	}
	else
	{
		PrecacheSound("#makovote/Pendulum - Witchcraft.mp3", true);
		AddFileToDownloadsTable("sound/makovote/Pendulum - Witchcraft.mp3");
	}
}

public void OnEntitySpawned(int iEntity, const char[] sClassname)
{
	if (g_bVoteFinished || !IsValidEntity(iEntity) || !IsValidEdict(iEntity))
		return;

	char sTargetname[128];
	GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	if ((strcmp(sTargetname, "espad") != 0) && (strcmp(sTargetname, "ss_slow") != 0) && (strcmp(sClassname, "ambient_generic") == 0))
		AcceptEntityInput(iEntity, "Kill");
}

public void OnRoundEnd(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	switch(GetEventInt(hEvent, "winner"))
	{
		case(CS_TEAM_CT):
		{
			int iCurrentStage = GetCurrentStage();
			
			if (iCurrentStage > -1)
				Cmd_StartVote();
		}
	}
}

public void OnRoundStart(Event hEvent, const char[] sEvent, bool bDontBroadcast)
{
	if (bStartVoteNextRound)
	{
		delete g_CountdownTimer;
		if (!g_bPlayedZM && g_cRtd.BoolValue)
		{
			CPrintToChatAll("{green}[Mako Vote] {white}ZM has not been played yet. Rolling the dice...");
			if (GetRandomInt(1, 100) <= g_cRtd_Percent.IntValue)
			{
				CPrintToChatAll("{green}[Mako Vote] {white}Result: ZM, restarting round.");
				ServerCommand("sm_stage zm");
				g_bVoteFinished = true;
				bStartVoteNextRound = false;
				g_bPlayedZM = true;
				CS_TerminateRound(1.0, CSRoundEnd_GameStart, false);
				return;
			}
			CPrintToChatAll("{green}[Mako Vote] {white}Result: Normal Mako Vote");
		}
		if (g_bPlayedZM && g_cRtd.BoolValue)
			CPrintToChatAll("{green}[Mako Vote] {white}ZM already has been played. Starting normal vote.");
	
		g_CountdownTimer = CreateTimer(1.0, StartVote, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		bStartVoteNextRound = false;
	}

	if (!(g_bVoteFinished))
	{
		int iStrip = FindEntityByTargetname(INVALID_ENT_REFERENCE, "RaceZone", "game_zone_player");
		if (iStrip != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iStrip, "FireUser1");

		int iButton1 = FindEntityByTargetname(INVALID_ENT_REFERENCE, "boton", "func_button");
		if (iButton1 != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iButton1, "Lock");

		int iButton2 = FindEntityByTargetname(INVALID_ENT_REFERENCE, "RaceMapButton1", "func_button");
		if (iButton2 != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iButton2, "Lock");

		int iButton3 = FindEntityByTargetname(INVALID_ENT_REFERENCE, "RaceMapButton2", "func_button");
		if (iButton3 != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iButton3, "Lock");

		int iButton4 = FindEntityByTargetname(INVALID_ENT_REFERENCE, "RaceMapButton3", "func_button");
		if (iButton4 != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iButton4, "Lock");

		int iButton5 = FindEntityByTargetname(INVALID_ENT_REFERENCE, "RaceMapButton4", "func_button");
		if (iButton5 != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iButton5, "Lock");

		int iCounter = FindEntityByTargetname(INVALID_ENT_REFERENCE, "LevelCase", "logic_case");
		if (iCounter != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iCounter, "Kill");

		int iDestination = FindEntityByTargetname(INVALID_ENT_REFERENCE, "arriba2ex", "info_teleport_destination");
		if (iDestination != INVALID_ENT_REFERENCE)
		{
			SetVariantString("origin -9350 4550 100");
			AcceptEntityInput(iDestination, "AddOutput");

			SetVariantString("angles 0 -90 0");
			AcceptEntityInput(iDestination, "AddOutput");
		}

		int iTeleport = FindEntityByTargetname(INVALID_ENT_REFERENCE, "teleporte_extreme", "trigger_teleport");
		if (iTeleport != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iTeleport, "Enable");

		int iBarrerasfinal2 = FindEntityByTargetname(INVALID_ENT_REFERENCE, "barrerasfinal2", "func_breakable");
		if (iBarrerasfinal2 != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iBarrerasfinal2, "Break");

		int iBarrerasfinal = FindEntityByTargetname(INVALID_ENT_REFERENCE, "barrerasfinal", "prop_dynamic");
		if (iBarrerasfinal != INVALID_ENT_REFERENCE)
				AcceptEntityInput(iBarrerasfinal, "Kill");

		int iFilter = FindEntityByTargetname(INVALID_ENT_REFERENCE, "humanos", "filter_activator_team");
		if (iFilter != INVALID_ENT_REFERENCE)
				AcceptEntityInput(iFilter, "Kill");

		int iTemp1 = FindEntityByTargetname(INVALID_ENT_REFERENCE, "EX2Laser1Temp", "point_template");
		if (iTemp1 != INVALID_ENT_REFERENCE)
		{
				DispatchKeyValue(iTemp1, "OnEntitySpawned", "EX2Laser1Hurt,SetDamage,0,0,-1");
				DispatchKeyValue(iTemp1, "OnEntitySpawned", "EX2Laser1Hurt,AddOutput,OnStartTouch !activator:AddOutput:origin -7000 -1000 100:0:-1,0,-1");
		}

		int iTemp2 = FindEntityByTargetname(INVALID_ENT_REFERENCE, "EX2Laser2Temp", "point_template");
		if (iTemp2 != INVALID_ENT_REFERENCE)
		{
				DispatchKeyValue(iTemp2, "OnEntitySpawned", "EX2Laser2Hurt,SetDamage,0,0,-1");
				DispatchKeyValue(iTemp2, "OnEntitySpawned", "EX2Laser2Hurt,AddOutput,OnStartTouch !activator:AddOutput:origin -7000 -1000 100:0:-1,0,-1");
		}

		int iTemp3 = FindEntityByTargetname(INVALID_ENT_REFERENCE, "EX2Laser3Temp", "point_template");
		if (iTemp3 != INVALID_ENT_REFERENCE)
		{
				DispatchKeyValue(iTemp3, "OnEntitySpawned", "EX2Laser3Hurt,SetDamage,0,0,-1");
				DispatchKeyValue(iTemp3, "OnEntitySpawned", "EX2Laser3Hurt,AddOutput,OnStartTouch !activator:AddOutput:origin -7000 -1000 100:0:-1,0,-1");
		}

		int iTemp4 = FindEntityByTargetname(INVALID_ENT_REFERENCE, "EX2Laser4Temp", "point_template");
		if (iTemp4 != INVALID_ENT_REFERENCE)
		{
				DispatchKeyValue(iTemp4, "OnEntitySpawned", "EX2Laser4Hurt,SetDamage,0,0,-1");
				DispatchKeyValue(iTemp4, "OnEntitySpawned", "EX2Laser4Hurt,AddOutput,OnStartTouch !activator:AddOutput:origin -7000 -1000 100:0:-1,0,-1");

		}

		int iLaserTimer = FindEntityByTargetname(INVALID_ENT_REFERENCE, "cortes2", "logic_timer");
		if (iLaserTimer != INVALID_ENT_REFERENCE)
			AcceptEntityInput(iLaserTimer, "Enable");

		int iLevelText = FindEntityByTargetname(INVALID_ENT_REFERENCE, "LevelText", "game_text");
		if (iLevelText != INVALID_ENT_REFERENCE)
		{
			SetVariantString("message > INTERMISSION ROUND <");
			AcceptEntityInput(iLevelText, "AddOutput");
		}

		int iMusic = FindEntityByTargetname(INVALID_ENT_REFERENCE, "ss_slow", "ambient_generic");
		if (iMusic != INVALID_ENT_REFERENCE)
		{
			SetVariantString("message #makovote/Pendulum - Witchcraft.mp3");
			AcceptEntityInput(iMusic, "AddOutput");
			AcceptEntityInput(iMusic, "PlaySound");
		}
	}
}

public void GenerateArray()
{
	int iBlockSize = ByteCountToCells(PLATFORM_MAX_PATH);

	delete g_StageList;
	g_StageList = new ArrayList(iBlockSize);

	for (int i = 0; i <= (NUMBEROFSTAGES - 1); i++)
		g_StageList.PushString(g_sStageName[i]);

	int iArraySize = GetArraySize(g_StageList);

	for (int i = 0; i <= (iArraySize - 1); i++)
	{
		int iRandom = GetRandomInt(0, iArraySize - 1);
		char sTemp1[128];
		g_StageList.GetString(iRandom, sTemp1, sizeof(sTemp1));

		char sTemp2[128];
		g_StageList.GetString(i, sTemp2, sizeof(sTemp2));

		g_StageList.SetString(i, sTemp1);
		g_StageList.SetString(iRandom, sTemp2);
	}
}

public Action Command_AdminStartVote(int client, int argc)
{
	char name[64];

	if (client == 0)
		name = "The server";
	else if(!GetClientName(client, name, sizeof(name))) 
		Format(name, sizeof(name), "Disconnected (uid:%d)", client);

	if (client != 0)
	{
		CPrintToChatAll("{green}[SM] {cyan}%s {white}has initiated a mako vote round (In %d seconds)", name, g_cDelay.IntValue);
		CreateTimer(g_cDelay.FloatValue, AdminStartVote_Timer);
	}
	else
		CPrintToChatAll("{green}[SM] {cyan}%s {white}has initiated a mako vote round (Next round)", name);

	Cmd_StartVote();

	return Plugin_Handled;
}

stock Action AdminStartVote_Timer(Handle hTimer)
{
	CPrintToChatAll("{green}[MakoVote] {white}Restarting round, be ready to vote.");
	TerminateRound();

	return Plugin_Stop;
}

public Action Command_StartVote(int args)
{
	Cmd_StartVote();
	return Plugin_Handled;
}

public void Cmd_StartVote()
{
	int iCurrentStage = GetCurrentStage();

	if (iCurrentStage > -1)
		g_bOnCooldown[iCurrentStage] = true;

	if (iCurrentStage == 5)
		g_bPlayedZM = true;

	int iOnCD = 0;
	for (int i = 0; i <= (NUMBEROFSTAGES - 1); i++)
	{
		if (g_bOnCooldown[i])
			iOnCD += 1;
	}

	if (iOnCD >= 3)
	{
		for (int i = 0; i <= (NUMBEROFSTAGES - 1); i++)
			g_bOnCooldown[i] = false;
	}

	g_bVoteFinished = false;
	GenerateArray();
	bStartVoteNextRound = true;
}

public Action StartVote(Handle timer)
{
	static int iCountDown = 5;
	PrintCenterTextAll("[MakoVote] Starting Vote in %ds", iCountDown);

	if (iCountDown-- <= 0)
	{
		iCountDown = 5;
		g_CountdownTimer = null;
		InitiateVote();
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public void InitiateVote()
{
	if(IsVoteInProgress())
	{
		CPrintToChatAll("{green}[Mako Vote] {white}Another vote is currently in progress, retrying again in 5s.");
		delete g_CountdownTimer;
		g_CountdownTimer = CreateTimer(5.0, StartVote, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	Handle menuStyle = GetMenuStyleHandle(view_as<MenuStyle>(0));
	g_VoteMenu = CreateMenuEx(menuStyle, Handler_MakoVoteMenu, MenuAction_End | MenuAction_Display | MenuAction_DisplayItem | MenuAction_VoteCancel);

	int iArraySize = g_StageList.Length;
	for (int i = 0; i <= (iArraySize - 1); i++)
	{
		char sBuffer[128];
		g_StageList.GetString(i, sBuffer, sizeof(sBuffer));

		for (int j = 0; j <= (NUMBEROFSTAGES - 1); j++)
		{
			if (strcmp(sBuffer, g_sStageName[j]) == 0)
			{
				if (g_bOnCooldown[j])
					AddMenuItem(g_VoteMenu, sBuffer, sBuffer, ITEMDRAW_DISABLED);
				else
					AddMenuItem(g_VoteMenu, sBuffer, sBuffer);
			}
		}
	}

	SetMenuOptionFlags(g_VoteMenu, MENUFLAG_BUTTON_NOVOTE);
	SetMenuTitle(g_VoteMenu, "What stage to play next?");
	SetVoteResultCallback(g_VoteMenu, Handler_SettingsVoteFinished);
	VoteMenuToAll(g_VoteMenu, 20);
}

public int Handler_MakoVoteMenu(Handle menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			CloseHandle(menu);

			if (param1 != -1)
			{
				g_bVoteFinished = true;
				TerminateRound();
			}
		}
	}
	return 0;
}

public int MenuHandler_NotifyPanel(Menu hMenu, MenuAction iAction, int iParam1, int iParam2)
{
	switch (iAction)
	{
		case MenuAction_Select, MenuAction_Cancel:
			delete hMenu;
	}
	return 0;
}

public void Handler_SettingsVoteFinished(Handle menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	int highest_votes = item_info[0][VOTEINFO_ITEM_VOTES];
	int required_percent = 60;
	int required_votes = RoundToCeil(float(num_votes) * float(required_percent) / 100);

	if ((highest_votes < required_votes) && (!g_bIsRevote))
	{
		CPrintToChatAll("{green}[MakoVote] {white}A revote is needed!");
		char sFirst[128];
		char sSecond[128];
		GetMenuItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], sFirst, sizeof(sFirst));
		GetMenuItem(menu, item_info[1][VOTEINFO_ITEM_INDEX], sSecond, sizeof(sSecond));
		g_StageList.Clear();
		g_StageList.PushString(sFirst);
		g_StageList.PushString(sSecond);
		g_bIsRevote = true;

		delete g_CountdownTimer;
		g_CountdownTimer = CreateTimer(1.0, StartVote, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

		return;
	}

	// No revote needed, continue as normal.
	g_bIsRevote = false;
	Handler_VoteFinishedGeneric(menu, num_votes, num_clients, client_info, num_items, item_info);
}

public void Handler_VoteFinishedGeneric(Handle menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	g_bVoteFinished = true;
	char sWinner[128];
	GetMenuItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], sWinner, sizeof(sWinner));
	float fPercentage = float(item_info[0][VOTEINFO_ITEM_VOTES] * 100) / float(num_votes);

	CPrintToChatAll("{green}[MakoVote] {white}Vote Finished! Winner: {red}%s{white} with %d%% of %d votes!", sWinner, RoundToFloor(fPercentage), num_votes);

	for (int i = 0; i <= (NUMBEROFSTAGES - 1); i++)
	{
		if (strcmp(sWinner, g_sStageName[i]) == 0)
			g_Winnerstage = i;
	}

	ServerCommand("sm_stage %d", (g_Winnerstage + 4));
	TerminateRound();
}

public int GetCurrentStage()
{
	// Spwaned as math_counter, but get changed as info_target
	// "OnUser1" "LevelCounter,AddOutput,classname info_target,0.03,1"
	int iLevelCounterEnt = FindEntityByTargetname(INVALID_ENT_REFERENCE, "LevelCounter", "info_target");

	int offset = FindDataMapInfo(iLevelCounterEnt, "m_OutValue");
	int iCounterVal = RoundFloat(GetEntDataFloat(iLevelCounterEnt, offset));

	int iCurrentStage;
	if (iCounterVal == 5) // Ex2
		iCurrentStage = 0;
	else if (iCounterVal == 6) // ZM Mode
		iCurrentStage = 5;
	else if (iCounterVal == 7) // Ex2 (H+U)
		iCurrentStage = 1;
	else if (iCounterVal == 9) // Ex3 (Hellz)
		iCurrentStage = 3;
	else if (iCounterVal == 10) // Ex3 (ZED)
		iCurrentStage = 2;
	else if (iCounterVal == 11) // Race
		iCurrentStage = 4;
	else if (iCounterVal == 13) // Ex3 (NiDe)
		iCurrentStage = 6;
	else
		iCurrentStage = 0;

	return iCurrentStage;
}

public int FindEntityByTargetname(int entity, const char[] sTargetname, const char[] sClassname)
{
	if(sTargetname[0] == '#') // HammerID
	{
		int HammerID = StringToInt(sTargetname[1]);

		while((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
		{
			if(GetEntProp(entity, Prop_Data, "m_iHammerID") == HammerID)
				return entity;
		}
	}
	else // Targetname
	{
		int Wildcard = FindCharInString(sTargetname, '*');
		char sTargetnameBuf[64];

		while((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
		{
			if(GetEntPropString(entity, Prop_Data, "m_iName", sTargetnameBuf, sizeof(sTargetnameBuf)) <= 0)
				continue;

			if(strncmp(sTargetnameBuf, sTargetname, Wildcard) == 0)
				return entity;
		}
	}
	return INVALID_ENT_REFERENCE;
}

void TerminateRound()
{
	CS_TerminateRound(1.5, CSRoundEnd_Draw, false);

	// Fix the score - Round Draw give 1 point to CT Team
	int score = GetTeamScore(CS_TEAM_CT);
	if (score > 0) SetTeamScore(CS_TEAM_CT, (score - 1));
}