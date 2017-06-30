#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <sdktools>
#include <Modular_LS>

#pragma newdecls required

#define Bar_Fill "█"
#define Bar_Empty "░"

#define BaseTime 0.1

#define ManaPerLevel 5
#define ManaPerPrestige 250

char ManaBar[MAXPLAYERS + 1][64];

int Mana[MAXPLAYERS + 1] = { -1, ... };
int ManaPool[MAXPLAYERS + 1] = { -1, ... };

bool InfiniteMana[MAXPLAYERS + 1];

Handle ManaHud;

enum Spell
{
	Spell_Fireball = 100, //P0L20
	Spell_Meteorite = 300, //P1L30
	Spell_MeteoriteShower = 600, //P2L20
	Spell_LightningOrb = 200, //P325
	Spell_Shield = 120, //P3L40
	Spell_Barricade = 500, //P4L10
	Spell_EMP = 1000, //P4L30
}

#include "Spells/Precache.inc"
#include "Spells/Basic.inc"
#include "Spells/Barricade.inc"
#include "Spells/Shield.inc"

public Plugin myinfo = 
{
	name = "MLS - Magical MvM",
	author = PLUGIN_AUTHOR,
	description = "MLS Module - Reward - Magical MvM",
	version = PLUGIN_VERSION,
	url = "https://keybase.io/rumblefrog"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_spellbook", CmdSpellBook, "Opens Spellbook Menu");
	
	RegConsoleCmd("sm_infinitemana", CmdInfiniteMana, "[Debug] Infinite Mana"); //TODO: SET TO ROOT ONLY
	
	ManaHud = CreateHudSynchronizer();
	
	HookEvent("player_spawn", PlayerSpawn, EventHookMode_Post);
	
	HookEvent("player_death", PlayerDeath, EventHookMode_Post);
	
	CreateTimer(0.5, Timer_ManaHud, _, TIMER_REPEAT);
	
	CreateTimer(BaseTime, Timer_Regenerate, _, TIMER_REPEAT);
}

public Action CmdSpellBook(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
		
	DisplaySpellBook(client);
	
	return Plugin_Handled;
}

public Action CmdInfiniteMana(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
		
	if (!InfiniteMana[client])
		MLS_PrintToClient(client, "{lightseagreen}[MaxDB] {grey}Enabled Infinite Mana");
	else
		MLS_PrintToClient(client, "{lightseagreen}[MaxDB] {grey}Disabled Infinite Mana");
		
	InfiniteMana[client] = !InfiniteMana[client];
	
	return Plugin_Handled;
}

void DisplaySpellBook(int client)
{
	char CostBuffer[16], DBuffer[64];
	
	Menu SB = new Menu(SpellBookCallBack);
	
	SB.SetTitle("Spellbook");
	
	if (!CanUseSpell(client, Spell_Fireball))
		SB.AddItem("X", "Level up to obtain spells!", ITEMDRAW_DISABLED);
	else
	{
		IntToString(view_as<int>(Spell_Fireball), CostBuffer, sizeof CostBuffer);
		Format(DBuffer, sizeof DBuffer, "Fireball [%s]", CostBuffer);
		SB.AddItem(CostBuffer, DBuffer);
	}
	
	if (CanUseSpell(client, Spell_Meteorite))
	{
		IntToString(view_as<int>(Spell_Meteorite), CostBuffer, sizeof CostBuffer);
		Format(DBuffer, sizeof DBuffer, "Meteorite [%s]", CostBuffer);
		SB.AddItem(CostBuffer, DBuffer);
	}
	
	if (CanUseSpell(client, Spell_MeteoriteShower))
	{
		IntToString(view_as<int>(Spell_MeteoriteShower), CostBuffer, sizeof CostBuffer);
		Format(DBuffer, sizeof DBuffer, "Meteorite Shower [%s]", CostBuffer);
		SB.AddItem(CostBuffer, DBuffer);
	}
	
	if (CanUseSpell(client, Spell_LightningOrb))
	{
		IntToString(view_as<int>(Spell_LightningOrb), CostBuffer, sizeof CostBuffer);
		Format(DBuffer, sizeof DBuffer, "Lightning Orb [%s]", CostBuffer);
		SB.AddItem(CostBuffer, DBuffer);
	}
	
	if (CanUseSpell(client, Spell_Shield))
	{
		IntToString(view_as<int>(Spell_Shield), CostBuffer, sizeof CostBuffer);
		Format(DBuffer, sizeof DBuffer, "Shield [%s]", CostBuffer);
		SB.AddItem(CostBuffer, DBuffer);
	}
	
	if (CanUseSpell(client, Spell_Barricade))
	{
		IntToString(view_as<int>(Spell_Barricade), CostBuffer, sizeof CostBuffer);
		Format(DBuffer, sizeof DBuffer, "Barricade [%s]", CostBuffer);
		SB.AddItem(CostBuffer, DBuffer);
	}
	
	if (CanUseSpell(client, Spell_EMP))
	{
		IntToString(view_as<int>(Spell_MeteoriteShower), CostBuffer, sizeof CostBuffer);
		Format(DBuffer, sizeof DBuffer, "EMP [%s]", CostBuffer);
		SB.AddItem(CostBuffer, DBuffer);
	}
	
	SB.Display(client, MENU_TIME_FOREVER);
}

public int SpellBookCallBack(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Select)
	{
		char buffer[16];
		Spell spell;
		
		menu.GetItem(item, buffer, sizeof buffer);
		spell = view_as<Spell>(StringToInt(buffer));
		
		if (IsValidClient(client, true))
		{
			switch (spell)
			{
			case Spell_Fireball:
				CastBasicSpell(client, Spell_Fireball);
			case Spell_Meteorite:
				CastBasicSpell(client, Spell_Meteorite);
			case Spell_LightningOrb:
				CastBasicSpell(client, Spell_LightningOrb);
			case Spell_Shield:
				CastShield(client);
			case Spell_Barricade:
				SpawnBarricade(client);
			default:
				MLS_PrintToClient(client, "Not yet implemented!"); //TODO: REMOVE
			}
		} else
			MLS_PrintToClient(client, "Cannot cast spell while you are dead.");
		
		DisplaySpellBook(client);
	}
}

bool CanUseSpell(int client, Spell spell)
{
	switch (spell)
	{
		case Spell_Fireball:
			return IsAERank(client, 0, 20);
		case Spell_Meteorite:
			return IsAERank(client, 1, 30);
		case Spell_MeteoriteShower:
			return IsAERank(client, 2, 20);
		case Spell_LightningOrb:
			return IsAERank(client, 3, 25);
		case Spell_Shield:
			return IsAERank(client, 3, 40);
		case Spell_Barricade:
			return IsAERank(client, 4, 10);
		case Spell_EMP:
			return IsAERank(client, 4, 30);
		default:
			return false;
	}
	
	return false;
}

public Action Timer_ManaHud(Handle timer)
{
	SetHudTextParams(0.4, 0.85, 0.6, 42, 42, 214, 0);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if (!IsValidMagic(i))
			{
				ShowSyncHudText(i, ManaHud, "N/A");
			} else
			{
				GenerateProgressBar(Mana[i], ManaPool[i], ManaBar[i], sizeof ManaBar[]);
				ShowSyncHudText(i, ManaHud, "%s %i/%i", ManaBar[i], Mana[i], ManaPool[i]);
			}
		}
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsValidClient(client))
		return;
		
	if (!MLS_IsLoaded(client))
		return;
		
	int Prestige = MLS_GetUserPrestige(client);
	int Level = MLS_GetUserLevel(client);
	
	ManaPool[client]  = (ManaPerPrestige * Prestige) + (Level * ManaPerLevel);
	Mana[client] = ManaPool[client];
}

public void MLS_OnClientDataLoaded(int client)
{
	if (!IsValidClient(client))
		return;
		
	int Prestige = MLS_GetUserPrestige(client);
	int Level = MLS_GetUserLevel(client);
	
	ManaPool[client]  = (ManaPerPrestige * Prestige) + (Level * ManaPerLevel);
	Mana[client] = ManaPool[client];
}

public Action Timer_Regenerate(Handle timer, any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidMagic(i))
		{
			if (IsAERank(i, 1, 50))
				AddMana(i, 3);
			else
				AddMana(i, 5);
		}
	}
}

bool DrainSpellMana(int client, Spell spell)
{
	if (!IsValidMagic(client))
		return false;
		
	if (InfiniteMana[client])
		return true;
		
	int amount = view_as<int>(spell);
		
	if (Mana[client] < amount)
	{
		MLS_PrintToClient(client, "You do not have enough mana!");
		return false;
	}
		
	Mana[client] -= amount;
		
	return true;
}

bool AddMana(int client, int amount)
{
	if (!IsValidMagic(client))
		return false;
		
	if (Mana[client] >= ManaPool[client])
		return false;
		
	Mana[client] += amount;
	
	return true;
}

public void PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsValidMagic(client))
		return;
	
	Mana[client] = ManaPool[client];
}

public void PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsValidMagic(client))
		RemoveShield(client);
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidMagic(i))
			RemoveShield(i);
}

public void OnClientDisconnect(int client)
{
	if (IsValidMagic(client))
		RemoveShield(client);
}

void GenerateProgressBar(int value, int base, char[] buffer, int size)
{
	Format(buffer, size, "");
	
	int filled = RoundToFloor((float(value) / float(base)) * 10);
	
	int empty = 10 - filled;
	
	for (int i = 1; i <= filled; i++)
	{
		Format(buffer, size, "%s%s", buffer, Bar_Fill);
	}
	
	for (int i = 1; i <= empty; i++)
	{
		Format(buffer, size, "%s%s", buffer, Bar_Empty);
	}
}

bool IsValidMagic(int client)
{
	if (!IsValidClient(client))
		return false;
		
	if (Mana[client] == -1 || ManaPool[client] == -1)
		return false;
		
	return true;
}

public void MLS_OnClientLeveledUp(int client, int level, int prestige)
{
	if (!IsValidMagic(client))
		return;
	
	ManaPool[client]  = (ManaPerPrestige * prestige) + (level * ManaPerLevel);
	
	if (DoubleEqual(level, prestige, 50, 1))	
		MLS_PrintToClient(client, "You have unlocked {chartreuse}+60% Mana Regen{grey}!.");
		
	if (DoubleEqual(level, prestige, 20, 0))
		MLS_PrintToClient(client, "You have unlocked {chartreuse}Fireball Spell{grey}!.");
		
	if (DoubleEqual(level, prestige, 30, 1))
		MLS_PrintToClient(client, "You have unlocked {chartreuse}Metorite Spell{grey}!.");
		
	if (DoubleEqual(level, prestige, 20, 2))
		MLS_PrintToClient(client, "You have unlocked {chartreuse}Metorite Shower Spell{grey}!.");
		
	if (DoubleEqual(level, prestige, 25, 3))
		MLS_PrintToClient(client, "You have unlocked {chartreuse}Lightning Orb Spell{grey}!.");
		
	if (DoubleEqual(level, prestige, 40, 3))
		MLS_PrintToClient(client, "You have unlocked {chartreuse}Shield Spell{grey}!.");
		
	if (DoubleEqual(level, prestige, 10, 4))
		MLS_PrintToClient(client, "You have unlocked {chartreuse}Barricade Spell{grey}!.");
		
	if (DoubleEqual(level, prestige, 30, 4))
		MLS_PrintToClient(client, "You have unlocked {chartreuse}EMP Spell{grey}!.");
}