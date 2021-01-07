#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#include <sdkhooks>

public Plugin myinfo = {
	name = "Zombie Deathmatch",
	author = "James Pizzurro",
	description = "Kill zombies and avoid becoming one yourself before time runs out!",
	version = "0.1.1",
	url = "https://github.com/jamespizzurro/csgo-zombie-deathmatch"
};

// source: https://forums.alliedmods.net/showpost.php?p=1772319&postcount=1
int bloodDecal[13];
float overflow[MAXPLAYERS + 1];

public void OnPluginStart() {
	if (GetEngineVersion() != Engine_CSGO)
		SetFailState("This plugin is for CS:GO only!");
	
	HookEvent("round_prestart", OnRoundPreStart, EventHookMode_Post);
	HookEvent("round_start", OnRoundStart);
	HookEvent("player_team", OnPlayerTeam_Pre, EventHookMode_Pre);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath_Pre, EventHookMode_Pre);
	HookEvent("player_death", OnPlayerDeath_Post, EventHookMode_Post);
	
	HookUserMessage(GetUserMessageId("TextMsg"), OnUserTextMsg, true);
	HookUserMessage(GetUserMessageId("SayText2"), OnUserSayText2, true);
	
	AddCommandListener(OnLookAtWeapon, "+lookatweapon");
	
	AutoExecConfig(true, "zdm", "sourcemod/zdm");
}

public void OnMapStart() {
	// Load zombie model
	// source: https://gamebanana.com/skins/140286
	
	PrecacheModel("models/player/kuristaja/zombies/gozombie/gozombie.mdl");
	
	AddFileToDownloadsTable("materials/models/player/kuristaja/zombies/gozombie/csgo_zombie_normal.vtf");
	AddFileToDownloadsTable("materials/models/player/kuristaja/zombies/gozombie/csgo_zombie_skin.vmt");
	
	AddFileToDownloadsTable("models/player/kuristaja/zombies/gozombie/gozombie.dx90.vtx");
	AddFileToDownloadsTable("models/player/kuristaja/zombies/gozombie/gozombie.mdl");
	AddFileToDownloadsTable("models/player/kuristaja/zombies/gozombie/gozombie.phy");
	AddFileToDownloadsTable("models/player/kuristaja/zombies/gozombie/gozombie.vvd");
	
	// Load zombies' knife view model
	// source: https://gamebanana.com/skins/161423
	
	PrecacheModel("models/player/custom_player/zombie/normal_m_09/hand/eminem/hand_normal_m_09.mdl");
	
	AddFileToDownloadsTable("materials/models/player/zombie/shared/npc_a_zombie_total.vmt");
	AddFileToDownloadsTable("materials/models/player/zombie/shared/npc_a_zombie_total.vtf");
	AddFileToDownloadsTable("materials/models/player/zombie/shared/npc_a_zombie_total_normal.vtf");
	
	AddFileToDownloadsTable("models/player/custom_player/zombie/normal_m_09/hand/eminem/hand_normal_m_09.dx90.vtx");
	AddFileToDownloadsTable("models/player/custom_player/zombie/normal_m_09/hand/eminem/hand_normal_m_09.mdl");
	AddFileToDownloadsTable("models/player/custom_player/zombie/normal_m_09/hand/eminem/hand_normal_m_09.vvd");
	
	
	// Load zombies' null knife world view model
	// source: https://forums.alliedmods.net/showpost.php?p=2468248&postcount=3
	
	PrecacheModel("models/weapons/w_knife_default_empty.mdl");
	
	AddFileToDownloadsTable("materials/models/weapons/w_models/w_knife_empty/empty.vmt");
	
	AddFileToDownloadsTable("models/weapons/w_knife_default_empty.dx90.vtx");
	AddFileToDownloadsTable("models/weapons/w_knife_default_empty.mdl");
	AddFileToDownloadsTable("models/weapons/w_knife_default_empty.vvd");
	
	
	// Load flashlight sound
	// source: https://forums.alliedmods.net/showpost.php?p=2042310&postcount=1
	PrecacheSound("items/flashlight1.wav", true);
	
	// if a fog controller and/or sky camera already exists,
	// make the map even foggier
	
	int fogController = FindEntityByClassname(-1, "env_fog_controller");
	if (fogController != -1) {
		DispatchKeyValue(fogController, "fogenable", "1");
		DispatchKeyValueFloat(fogController, "fogstart", 0.0);
		DispatchKeyValueFloat(fogController, "fogend", 1024.0);
		DispatchKeyValueFloat(fogController, "fogmaxdensity", 1.0);
		
		AcceptEntityInput(fogController, "TurnOn");
	}
	
	int skyCamera = FindEntityByClassname(-1, "sky_camera");
	if (skyCamera != -1) {
		DispatchKeyValue(skyCamera, "fogenable", "1");
		DispatchKeyValueFloat(skyCamera, "fogstart", 0.0);
		DispatchKeyValueFloat(skyCamera, "fogend", 1024.0);
		DispatchKeyValueFloat(skyCamera, "fogmaxdensity", 1.0);
		
		AcceptEntityInput(skyCamera, "TurnOn");
	}
	
	// Load gore
	// source: https://forums.alliedmods.net/showpost.php?p=1772319&postcount=1
	
	ForcePrecache("blood_impact_heavy");
	ForcePrecache("blood_impact_goop_heavy");
	ForcePrecache("blood_impact_red_01_chunk");
	ForcePrecache("blood_impact_headshot_01c");
	ForcePrecache("blood_impact_headshot_01b");
	ForcePrecache("blood_impact_headshot_01d");
	ForcePrecache("blood_impact_basic");
	ForcePrecache("blood_impact_medium");
	ForcePrecache("blood_impact_red_01_goop_a");
	ForcePrecache("blood_impact_red_01_goop_b");
	ForcePrecache("blood_impact_goop_medium");
	ForcePrecache("blood_impact_red_01_goop_c");
	ForcePrecache("blood_impact_red_01_drops");
	ForcePrecache("blood_impact_drops1");
	ForcePrecache("blood_impact_red_01_backspray");
	
	bloodDecal[0] = PrecacheDecal("decals/blood_splatter.vtf");
	bloodDecal[1] = PrecacheDecal("decals/bloodstain_003.vtf");
	bloodDecal[2] = PrecacheDecal("decals/bloodstain_101.vtf");
	bloodDecal[3] = PrecacheDecal("decals/bloodstain_002.vtf");
	bloodDecal[4] = PrecacheDecal("decals/bloodstain_001.vtf");
	bloodDecal[5] = PrecacheDecal("decals/blood8.vtf");
	bloodDecal[6] = PrecacheDecal("decals/blood7.vtf");
	bloodDecal[7] = PrecacheDecal("decals/blood6.vtf");
	bloodDecal[8] = PrecacheDecal("decals/blood5.vtf");
	bloodDecal[9] = PrecacheDecal("decals/blood4.vtf");
	bloodDecal[10] = PrecacheDecal("decals/blood3.vtf");
	bloodDecal[11] = PrecacheDecal("decals/blood2.vtf");
	bloodDecal[12] = PrecacheDecal("decals/blood1.vtf");
	
	for (int i = 1; i < MaxClients; i++)
		overflow[i] = 0.0;
}
// source: https://forums.alliedmods.net/showpost.php?p=1772319&postcount=1
public void ForcePrecache(const char[] particleName) {
	int particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle)) {
		DispatchKeyValue(particle, "effect_name", particleName);
		
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		
		CreateTimer(1.0, DeleteParticle, particle, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnRoundPreStart(Handle event, const char[] name, bool dontBroadcast) {
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientConnected(client) && IsClientInGame(client)) {
			int team = GetClientTeam(client);
			if (IsFakeClient(client)) {
				// make any bot survivors zombies before the next round starts
				if (team == CS_TEAM_CT)
					CS_SwitchTeam(client, CS_TEAM_T);
			} else {
				// make any non-bot zombies survivors before the next round starts
				if (team == CS_TEAM_T)
					CS_SwitchTeam(client, CS_TEAM_CT);
			}
		}
	}
	
	return Plugin_Continue;
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	// prevent zombies from being able to buy stuff
	// source: https://forums.alliedmods.net/showpost.php?p=2371918&postcount=9
	GameRules_SetProp("m_bTCantBuy", true, _, _, true);
	
	return Plugin_Continue;
} 

public Action OnPlayerTeam_Pre(Event event, const char[] name, bool dontBroadcast) {
	// prevent team joining messages from showing
	// source: https://forums.alliedmods.net/showpost.php?p=2589086&postcount=6
	if (!event.GetBool("silent")) {
		dontBroadcast = true;
		
		// TODO: the line below causes players to get prompted to change their team again if the team change menu is open,
		// e.g. when first choosing a team after joining the server
		event.BroadcastDisabled = true;
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsClientConnected(client) && IsClientInGame(client)) {
		int team = GetClientTeam(client);
		if (team == CS_TEAM_T) {
			// change the name of zombie bots when they spawn
			if (IsFakeClient(client)) {
				char nameBuffer[MAX_NAME_LENGTH];
				Format(nameBuffer, sizeof(nameBuffer), "Zombie %i", client);
				SetClientName(client, nameBuffer);
			}
			
			// replace the player's model
			// source: https://gamebanana.com/skins/140286
			SetEntityModel(client, "models/player/kuristaja/zombies/gozombie/gozombie.mdl");
			
			// replace the player's view model
			// source: https://forums.alliedmods.net/showpost.php?p=2357429&postcount=1
			//         https://gamebanana.com/skins/161423
			int replacementViewModel = PrecacheModel("models/player/custom_player/zombie/normal_m_09/hand/eminem/hand_normal_m_09.mdl");
			SetEntProp(Weapon_GetViewModelIndex(client, -1), Prop_Send, "m_nModelIndex", replacementViewModel);
			
			// replace the world model of the player's knife
			// source: https://forums.alliedmods.net/showpost.php?p=2467451&postcount=1
			//         https://forums.alliedmods.net/showpost.php?p=2468248&postcount=3
			int knife = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);
			int knifeWorldModel = GetEntPropEnt(knife, Prop_Send, "m_hWeaponWorldModel");
			int replacementKnifeWorldModel = PrecacheModel("models/weapons/w_knife_default_empty.mdl");
			SetEntProp(knifeWorldModel, Prop_Send, "m_nModelIndex", replacementKnifeWorldModel);
		} else {
			// change the name of survivor bots when they spawn
			if (IsFakeClient(client)) {
				char nameBuffer[MAX_NAME_LENGTH];
				Format(nameBuffer, sizeof(nameBuffer), "Survivor %i", client);
				SetClientName(client, nameBuffer);
			}
		}
	}
}
// source: https://forums.alliedmods.net/showpost.php?p=2357429&postcount=1
public int Weapon_GetViewModelIndex(int client, int sIndex) {
	while ((sIndex = FindEntityByClassname2(sIndex, "predicted_viewmodel")) != -1) {
		if (GetEntPropEnt(sIndex, Prop_Send, "m_hOwner") != client)
			continue;
		
		return sIndex;
	}
	
	return -1;
}
// source: https://forums.alliedmods.net/showpost.php?p=2357429&postcount=1
public int FindEntityByClassname2(int sStartEnt, const char[] szClassname) {
	while ((sStartEnt > -1) && !IsValidEntity(sStartEnt))
		sStartEnt--;
	
	return FindEntityByClassname(sStartEnt, szClassname);
}

public Action OnUserSayText2(UserMsg msgID, Handle hPb, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit) {
	if (bReliable) {
		// prevent messages from showing in chat about bots changing their names
		// source: https://forums.alliedmods.net/showpost.php?p=2085836&postcount=11
		if (GetUserMessageType() == UM_Protobuf) {
			char szText[64];
			PbReadString(hPb, "msg_name", szText, sizeof(szText));
			if (StrContains(szText, "#Cstrike_Name_Change", false) != -1)
				return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action OnWeaponCanUse(int client, int weapon) {
	if (IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client)) {
		int team = GetClientTeam(client);
		if (team == CS_TEAM_T) {
			// prevent zombies from being able to use weapons other than a knife
			char weaponClassname[32];
			GetEdictClassname(weapon, weaponClassname, sizeof(weaponClassname));
			if (StrContains(weaponClassname, "weapon_knife", false) == -1) {
				RemovePlayerItem(client, weapon);
				return Plugin_Handled;
			}
		} else if (team == CS_TEAM_CT) {
			// prevent survivors from being able to use heavy machine guns
			char weaponClassname[32];
			GetEdictClassname(weapon, weaponClassname, sizeof(weaponClassname));
			if ((StrContains(weaponClassname, "weapon_m249", false) != -1) || (StrContains(weaponClassname, "weapon_negev", false) != -1)) {
				RemovePlayerItem(client, weapon);
				GivePlayerItem(client, "weapon_p90");
				
				PrintToChat(client, "Heavy machine guns are not allowed on this server! You've been given a P90 instead.");
				return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
	// light survivors and zombies on fire for a short time if they are hit with the fire from an incendiary grenade
	if (damagetype == DMG_BURN) {
		IgniteEntity(victim, 3.0);
	}
	
	return Plugin_Continue;
}

public Action OnLookAtWeapon(int client, const char[] command, int argc) {
	if (IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client)) {
		// give survivors the ability to toggle their flashlight
		// source: https://forums.alliedmods.net/showpost.php?p=2042310&postcount=1
		int team = GetClientTeam(client);
		if (team == CS_TEAM_CT) {
			SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") ^ 4);
			EmitSoundToAll("items/flashlight1.wav", client);
		}
	}
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
	if (IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client)) {
		// make it so survivors can't jump
		// source: https://forums.alliedmods.net/showthread.php?p=2122070
		int team = GetClientTeam(client);
		if (team == CS_TEAM_CT) {
			if (buttons & IN_JUMP) {
				buttons &= ~IN_JUMP;
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	// spray blood everywhere
	// source: https://forums.alliedmods.net/showpost.php?p=1772319&postcount=1
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int damage = GetEventInt(event, "dmg_health");
	int health = GetEventInt(event, "health");
	
	if (overflow[client] > GetGameTime() - 0.1) {
		overflow[client] = GetGameTime();
		
		for (int i = 0; i < 3; i++) {
			ChanceParticle(client, damage, "blood_impact_red_01_backspray");
			ChanceParticle(client, damage, "blood_impact_drops1");
			ChanceParticle(client, damage, "blood_impact_red_01_drops");
		}
		
		ChanceParticle(client, damage, "blood_impact_red_01_goop_c");
		ChanceParticle(client, damage, "blood_impact_goop_medium");
		ChanceParticle(client, damage, "blood_impact_red_01_goop_b");
		ChanceParticle(client, damage, "blood_impact_red_01_goop_a");
		ChanceParticle(client, damage, "blood_impact_medium");
		ChanceParticle(client, damage, "blood_impact_basic");
		
		if (health > 0)
			GoreDecal(client, (damage / 20));
		else
			GoreDecal(client, 30);
	}
	
	return Plugin_Continue;
}
// source: https://forums.alliedmods.net/showpost.php?p=1772319&postcount=1
public void ChanceParticle(int client, int chance, const char[] particleName) {
	ChanceParticleImpl(client, chance, particleName, false, false);
}
public void ChanceParticleImpl(int client, int chance, const char[] particleName, bool dead, bool headshot) {
	int roll = GetRandomInt(1, 100);
	if (roll <= chance)
		CreateParticle(client, particleName, dead, headshot);
}
// source: https://forums.alliedmods.net/showpost.php?p=1772319&postcount=1
void CreateParticle(int client, const char[] particleName, bool dead, bool headshot) {
	int particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle) && IsValidEdict(client)) {
		float origin[3];
		char targetName[64];
		
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", origin);
		
		origin[2] += GetRandomFloat(25.0, 75.0);
		
		TeleportEntity(particle, origin, NULL_VECTOR, NULL_VECTOR);
		
		Format(targetName, sizeof(targetName), "Client%d", client);
		DispatchKeyValue(client, "targetname", targetName);
		GetEntPropString(client, Prop_Data, "m_iName", targetName, sizeof(targetName));
		
		DispatchKeyValue(particle, "targetname", "CSGOParticle");
		DispatchKeyValue(particle, "parentname", targetName);
		DispatchKeyValue(particle, "effect_name", particleName);
		
		DispatchSpawn(particle);
		
		if (dead) {
			ParentToBody(client, particle, headshot);
		} else {
			SetVariantString(targetName);
			AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		}
		
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		
		CreateTimer(1.0, DeleteParticle, particle);
	}
}
// source: https://forums.alliedmods.net/showpost.php?p=1772319&postcount=1
void ParentToBody(int client, int particle, bool headshot = false) {
	if (IsValidEdict(client)) {
		char targetName[64], className[64];
		
		int body = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		
		if (IsValidEdict(body)) {
			Format(targetName, sizeof(targetName), "Body%d", body);
			
			GetEdictClassname(body, className, sizeof(className));
			
			if (IsValidEdict(body) && StrEqual(className, "cs_ragdoll", false)) {
				DispatchKeyValue(body, "targetname", targetName);
				GetEntPropString(body, Prop_Data, "m_iName", targetName, sizeof(targetName));
				
				SetVariantString(targetName);
				AcceptEntityInput(particle, "SetParent", particle, particle, 0);
				
				if (headshot)
					// source: https://forums.alliedmods.net/showpost.php?p=2612992&postcount=60
					SetVariantString("facemask");
				else
					SetVariantString("primary");
				
				AcceptEntityInput(particle, "SetParentAttachment", particle, particle, 0);
			}
		}
	}
}
// source: https://forums.alliedmods.net/showpost.php?p=1772319&postcount=1
public Action DeleteParticle(Handle Timer, int particle) {
	if (IsValidEdict(particle)) {
		char className[64];
		GetEdictClassname(particle, className, sizeof(className));
		if (StrEqual(className, "info_particle_system", false))
			RemoveEdict(particle);
	}
}
// source: https://forums.alliedmods.net/showpost.php?p=1772319&postcount=1
public void GoreDecal(int client, int count) {
	int decal;
	float origin[3];
	
	GetClientAbsOrigin(client, origin);
	
	for (int i = 0; i < count; i++) {
		origin[0] += GetRandomFloat(-50.0, 50.0);
		origin[1] += GetRandomFloat(-50.0, 50.0);
		
		if (GetRandomInt(1, 20) == 20)
			decal = GetRandomInt(2, 4);
		else
			decal = GetRandomInt(5, 12);
		
		TE_Start("World Decal");
		TE_WriteVector("m_vecOrigin", origin);
		TE_WriteNum("m_nIndex", bloodDecal[decal]);
		TE_SendToAll();
	}
}

public Action OnPlayerDeath_Pre(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (IsClientConnected(victim) && IsClientInGame(victim)) {
		// remove domination for victim
		// source: https://forums.alliedmods.net/showpost.php?p=2703986&postcount=7
		SetEntProp(victim, Prop_Send, "m_bPlayerDominatingMe", false, _, attacker);
	}
	
	if (IsClientConnected(attacker) && IsClientInGame(attacker)) {
		// remove domination for attacker
		// source: https://forums.alliedmods.net/showpost.php?p=2703986&postcount=7
		SetEntProp(attacker, Prop_Send, "m_bPlayerDominated", false, _, victim);
		event.SetBool("dominated", false);
		
		// prevent kill sound from playing for attacker
		// source: https://forums.alliedmods.net/showpost.php?p=2703986&postcount=7
		StopSound(attacker, SNDCHAN_ITEM, "buttons/bell1.wav");
		RequestFrame(RequestFrame_PlayerGetKill, GetClientUserId(attacker));
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
public void RequestFrame_PlayerGetKill(int userId) {
	int client = GetClientOfUserId(userId);
	if (!client || !IsClientInGame(client))
		return;
		
	// prevent kill sound from playing
	// source: https://forums.alliedmods.net/showpost.php?p=2703986&postcount=7
	StopSound(client, SNDCHAN_ITEM, "buttons/bell1.wav");
}

public Action OnPlayerDeath_Post(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsClientConnected(client) && IsClientInGame(client)) {
		// make a survivor a zombie when they die
		int team = GetClientTeam(client);
		if (team == CS_TEAM_CT) {
			CS_SwitchTeam(client, CS_TEAM_T);
			
			// if this was the last survivor to become a zombie, start the next round
			// (this is the only win condition for zombies that we need to explicitly handle; CS:GO will handle the rest natively)
			if (GetTeamClientCount(CS_TEAM_CT) <= 0)
				CS_TerminateRound(GetConVarFloat(FindConVar("mp_round_restart_delay")), CSRoundEnd_TerroristWin);
		}
	}
	
	return Plugin_Continue;
}

public Action OnUserTextMsg(UserMsg msgID, Handle hPb, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit) {
	if (bReliable) {
		// prevent messages from showing in chat about getting points for a kill
		// source: https://forums.alliedmods.net/showpost.php?p=2703986&postcount=7
		char szText[64];
		PbReadString(hPb, "params", szText, sizeof(szText), 0);
		if (StrContains(szText, "#Player_Point_Award_", false) != -1)
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
