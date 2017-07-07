#pragma semicolon 1

#define PLUGIN_AUTHOR "Fishy"
#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <Modular_LS>

#pragma newdecls required

//#define Bar_Fill "█"
//#define Bar_Empty "░"

#define Bar_Fill "█"
#define Bar_Empty "▓"

#define ManaSymbol "ϟ"

#define BaseMana 500
#define BaseTime 0.1

#define ManaPerLevel 10
#define ManaPerPrestige 500

char ManaBar[MAXPLAYERS + 1][64];

int Mana[MAXPLAYERS + 1] = { -1, ... };
int ManaPool[MAXPLAYERS + 1] = { -1, ... };

int CurrencyCollected;

bool InfiniteMana[MAXPLAYERS + 1];

Handle ManaHud;

enum Spell
{
	Spell_Fireball,
	Spell_Meteorite,
	Spell_Teleport,
	Spell_LightningOrb,
	Spell_Shield,
	Spell_Barricade,
	Spell_EMP,
	Spell_Count
}

enum Spell_Cost
{
	Fireball_Cost = 100,
	Meteorite_Cost = 300,
	Teleport_Cost = 80,
	LightningOrb_Cost = 200,
	Shield_Cost = 120,
	Barricade_Cost = 500,
	EMP_Cost = 1000
}

enum Spell_Cooldown
{
	float:Fireball_Cooldown = 2.0,
	float:Meteorite_Cooldown = 8.0,
	float:Teleport_Cooldown = 3.0,
	float:LightningOrb_Cooldown = 4.0,
	float:Shield_Cooldown = 10.0,
	float:Barricade_Cooldown = 70.0,
	float:EMP_Cooldown = 120.0
}

float SpellNextUse[MAXPLAYERS + 1][Spell_Count];

#include "Spells/Precache.inc"
#include "Spells/Basic.inc"
#include "Spells/Barricade.inc"
#include "Spells/Shield.inc"
#include "Spells/EMP.inc"

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
	
	RegConsoleCmd("sm_mmvm_dump", CmdDump, "Dump user data");
	
	ManaHud = CreateHudSynchronizer();
	
	HookEvent("player_spawn", PlayerSpawn, EventHookMode_Post);
	
	HookEvent("player_death", PlayerDeath, EventHookMode_Post);
	
	HookEvent("mvm_pickup_currency", PickUpCurrency, EventHookMode_Post);
	
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

public Action CmdDump(int client, int args)
{
	PrintToConsole(client, "Mana: %f", Mana[client]);
	PrintToConsole(client, "ManaPool: %i", ManaPool[client]);
	PrintToConsole(client, "InfiniteMana: %i", InfiniteMana[client]);
	
	PrintToConsole(client, "<-------------------------->");
	
	return Plugin_Handled;
}

public Action CmdInfiniteMana(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
		
	if (!InfiniteMana[client])
		MLS_PrintToClient(client, "Enabled Infinite Mana");
	else
		MLS_PrintToClient(client, "Disabled Infinite Mana");
		
	InfiniteMana[client] = !InfiniteMana[client];
	
	return Plugin_Handled;
}

void DisplaySpellBook(int client)
{
	char IndexBuffer[8], DBuffer[64];
	
	Menu SB = new Menu(SpellBookCallBack);
	
	SB.SetTitle("Spellbook");
	
	IntToString(view_as<int>(Spell_Fireball), IndexBuffer, sizeof IndexBuffer);
	Format(DBuffer, sizeof DBuffer, "Fireball [%i]", Fireball_Cost);
	SB.AddItem(IndexBuffer, DBuffer);
	
	if (CanUseSpell(client, Spell_Meteorite))
	{
		IntToString(view_as<int>(Spell_Meteorite), IndexBuffer, sizeof IndexBuffer);
		Format(DBuffer, sizeof DBuffer, "Meteorite [%i]", Meteorite_Cost);
		SB.AddItem(IndexBuffer, DBuffer);
	}
	
	if (CanUseSpell(client, Spell_Teleport))
	{
		IntToString(view_as<int>(Spell_Teleport), IndexBuffer, sizeof IndexBuffer);
		Format(DBuffer, sizeof DBuffer, "Teleport [%i]", Teleport_Cost);
		SB.AddItem(IndexBuffer, DBuffer);
	}
	
	if (CanUseSpell(client, Spell_LightningOrb))
	{
		IntToString(view_as<int>(Spell_LightningOrb), IndexBuffer, sizeof IndexBuffer);
		Format(DBuffer, sizeof DBuffer, "Lightning Orb [%i]", LightningOrb_Cost);
		SB.AddItem(IndexBuffer, DBuffer);
	}
	
	if (CanUseSpell(client, Spell_Shield))
	{
		IntToString(view_as<int>(Spell_Shield), IndexBuffer, sizeof IndexBuffer);
		Format(DBuffer, sizeof DBuffer, "Shield [%i]", Shield_Cost);
		SB.AddItem(IndexBuffer, DBuffer);
	}
	
	if (CanUseSpell(client, Spell_Barricade))
	{
		IntToString(view_as<int>(Spell_Barricade), IndexBuffer, sizeof IndexBuffer);
		Format(DBuffer, sizeof DBuffer, "Barricade [%i]", Barricade_Cost);
		SB.AddItem(IndexBuffer, DBuffer);
	}
	
	if (CanUseSpell(client, Spell_EMP))
	{
		IntToString(view_as<int>(Spell_EMP), IndexBuffer, sizeof IndexBuffer);
		Format(DBuffer, sizeof DBuffer, "EMP [%i]", EMP_Cost);
		SB.AddItem(IndexBuffer, DBuffer);
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
			case Spell_Teleport:
				CastBasicSpell(client, Spell_Teleport);
			case Spell_LightningOrb:
				CastBasicSpell(client, Spell_LightningOrb);
			case Spell_Shield:
				CastShield(client);
			case Spell_Barricade:
				SpawnBarricade(client);
			case Spell_EMP:
				CastEMP(client);
			default:
				MLS_PrintToClient(client, "Not a valid spell!");
			}
		} else
			MLS_PrintToClient(client, "Cannot cast spell while you are dead.");
		
		DisplaySpellBook(client);
	}
}

bool CanUseSpell(int client, Spell spell)
{
	LSRL Rank = MLS_GetUserRank(client);
	
	if (Rank == LSRL_Admin || Rank == LSRL_Tester) //TODO: Limit to Admin after?
		return true;
	
	switch (spell)
	{
		case Spell_Fireball:
			return true;
		case Spell_Meteorite:
			return CurrencyCollected >= 400;
		case Spell_Teleport:
			return CurrencyCollected >= 800;
		case Spell_LightningOrb:
			return CurrencyCollected >= 1200;
		case Spell_Shield:
			return CurrencyCollected >= 1600;
		case Spell_Barricade:
			return CurrencyCollected >= 2000;
		case Spell_EMP:
			return CurrencyCollected >= 2400;
		default:
			return false;
	}
	
	return false;
}

public Action Timer_ManaHud(Handle timer)
{	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if (!IsValidMagic(i))
			{
				SetHudTextParams(-1.0, 0.85, 0.6, 42, 42, 214, 0);
				ShowSyncHudText(i, ManaHud, "N/A");
			} else
			{
				SetHudTextParams(0.4, 0.85, 0.6, 42, 42, 214, 0);
				GenerateProgressBar(Mana[i], ManaPool[i], ManaBar[i], sizeof ManaBar[]);
				ShowSyncHudText(i, ManaHud, "%s %s %i/%i", ManaSymbol, ManaBar[i], Mana[i], ManaPool[i]);
			}
		}
	}
}

public void MLS_OnClientDataLoaded(int client)
{
	if (!IsValidClient(client))
		return;
			
	CalculatePool(client);
	
	Mana[client] = ManaPool[client];
	
	PrintToConsole(client, "[MaxDB] Successfully loaded your data");
}

public Action Timer_Regenerate(Handle timer, any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidMagic(i))
		{
			if (IsAERank(i, 1, 50))
				AddMana(i, 1);
			else
				AddMana(i, 3);
		}
	}
}

bool DrainSpellMana(int client, Spell spell)
{
	if (!IsValidMagic(client))
		return false;
		
	if (InfiniteMana[client])
		return true;
		
	Spell_Cost cost;
	
	switch (spell)
	{
		case Spell_Fireball:
			cost = Fireball_Cost;
		case Spell_Meteorite:
			cost = Meteorite_Cost;
		case Spell_Teleport:
			cost = Teleport_Cost;
		case Spell_LightningOrb:
			cost = LightningOrb_Cost;
		case Spell_Shield:
			cost = Shield_Cost;
		case Spell_Barricade:
			cost = Barricade_Cost;
		case Spell_EMP:
			cost = EMP_Cost;
	}
	
	int amount = view_as<int>(cost);
		
	if (Mana[client] < amount)
	{
		EmitSoundToClient(client, FailSound);
		PrintHintText(client, "You do not have enough mana!");
		return false;
	}
	
	if (IsInCoolDown(client, spell))
	{
		EmitSoundToClient(client, FailSound);
		PrintHintText(client, "You cannot use this spell for another %i second", GetCoolDownDuration(client, spell));
		
		return false;
	}
		
	Mana[client] -= amount;
	
	StartCoolDown(client, spell);
		
	return true;
}

bool IsInCoolDown(int client, Spell spell)
{
	int iIndex = view_as<int>(spell);
	
	float CurrentTime = GetGameTime();
	
	return (SpellNextUse[client][iIndex] > CurrentTime);
}

int GetCoolDownDuration(int client, Spell spell)
{
	int iIndex = view_as<int>(spell);
	
	if (!IsInCoolDown(client, spell))
		return -1;
		
	float CurrentTime = GetGameTime();
		
	return RoundToCeil(SpellNextUse[client][iIndex] - CurrentTime);
}

stock void GetCoolDownDurationString(int client, Spell spell, char[] buffer, int size)
{
	if (!IsInCoolDown(client, spell))
		return;
		
	int Duration;
	
	if ((Duration = GetCoolDownDuration(client, spell)) == -1)
		return;

	int iMinutes = RoundToFloor(float(Duration / 60));
	int iSeconds = Duration % 60;

	Format(buffer, size, "%i:%i", iMinutes, iSeconds);
}

void StartCoolDown(int client, Spell spell)
{
	int iIndex;
	
	float CurrentTime = GetGameTime();
	float Cooldown;
	
	iIndex = view_as<int>(spell);
					
	switch (spell)
	{
		case Spell_Fireball:
			Cooldown = view_as<float>(Fireball_Cooldown);
		case Spell_Meteorite:
			Cooldown = view_as<float>(Meteorite_Cooldown);
		case Spell_Teleport:
			Cooldown = view_as<float>(Teleport_Cooldown);
		case Spell_LightningOrb:
			Cooldown = view_as<float>(LightningOrb_Cooldown);
		case Spell_Shield:
			Cooldown = view_as<float>(Shield_Cooldown);
		case Spell_Barricade:
			Cooldown = view_as<float>(Barricade_Cooldown);
		case Spell_EMP:
			Cooldown = view_as<float>(EMP_Cooldown);
	}
	
	SpellNextUse[client][iIndex] = CurrentTime + Cooldown;
}

bool AddMana(int client, int amount)
{
	if (!IsValidMagic(client))
		return false;
		
	if (Mana[client] >= ManaPool[client])
		return false;
		
	if ((Mana[client] + amount) > ManaPool[client])
		Mana[client] = ManaPool[client];
	else
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

public void PickUpCurrency(Event event, const char[] name, bool dontBroadcast)
{	
	int cash = event.GetInt("currency");
	
	CurrencyCollected += cash;
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

void CalculatePool(int client)
{		
	int Prestige = MLS_GetUserPrestige(client);
	int Level = MLS_GetUserLevel(client);
	
	ManaPool[client]  = (ManaPerPrestige * Prestige) + (Level * ManaPerLevel) + BaseMana;
}

public void MLS_OnClientLeveledUp(int client, int level, int prestige)
{
	if (!IsValidMagic(client))
		return;
	
	CalculatePool(client);
	
	if (DoubleEqual(level, prestige, 50, 1))	
		MLS_PrintToClient(client, "You have unlocked {chartreuse}3x Faster Mana Regen{grey}!.");
		
}