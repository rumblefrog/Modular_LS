int CurrentShield[MAXPLAYERS + 1] =  { INVALID_ENT_REFERENCE, ... };

void CastShield(int client)
{
	if (!CanUseSpell(client, Spell_Barricade))
		return;
		
	if (IsValidEntity(CurrentShield[client]))
	{
		MLS_PrintToClient(client, "You still have a shield!");
		return;
	}
		
	if (!DrainSpellMana(client, Spell_Barricade))
		return;
		
	int shield = CreateEntityByName("entity_medigun_shield");
	
	if (!IsValidEntity(shield))
		return;
		
	CurrentShield[client] = EntIndexToEntRef(shield);
		
	SetEntPropEnt(shield, Prop_Send, "m_hOwnerEntity", client);  
	SetEntProp(shield, Prop_Send, "m_iTeamNum", GetClientTeam(client));  
	SetEntProp(shield, Prop_Data, "m_iInitialTeamNum", GetClientTeam(client));  
						
	DispatchKeyValue(shield, "skin", "0");
			
	SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 100.0);
	SetEntProp(client, Prop_Send, "m_bRageDraining", 1);
	DispatchSpawn(shield);
	EmitSoundToClient(client, MedicShieldSound, shield);
	SetEntityModel(shield, MedicShieldModel);
}

void RemoveShield(int client)
{
	if (IsValidEntity(CurrentShield[client]))
	{
		AcceptEntityInput(CurrentShield[client], "Kill");
		CurrentShield[client] = INVALID_ENT_REFERENCE;
	}
}