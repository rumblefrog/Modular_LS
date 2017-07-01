int CastBasicSpell(int client, Spell spell)
{
	if (!CanUseSpell(client, spell))
		return -1;
		
	if (!DrainSpellMana(client, spell))
		return -1;
	
	char strEntname[45];
	float vAngles[3], vPosition[3];
	
	GetClientEyeAngles(client, vAngles);
	GetClientEyePosition(client, vPosition);
	
	switch (spell)
	{
		case Spell_Fireball:
			strEntname = "tf_projectile_spellfireball";
		case Spell_Meteorite:
			strEntname = "tf_projectile_spellmeteorshower";
		case Spell_Teleport:
			strEntname = "tf_projectile_spelltransposeteleport";
		case Spell_LightningOrb:
			strEntname = "tf_projectile_lightningorb";
	}
	
	int iTeam = GetClientTeam(client);
	int iSpell = CreateEntityByName(strEntname);
	
	if(!IsValidEntity(iSpell))
		return -1;
	
	float vVelocity[3], vBuffer[3];
	
	GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
	
	vVelocity[0] = vBuffer[0]*2000.0;
	vVelocity[1] = vBuffer[1]*2000.0;
	vVelocity[2] = vBuffer[2]*2000.0;
	
	SetEntPropEnt(iSpell, Prop_Send, "m_hOwnerEntity", client);
	SetEntProp(iSpell,    Prop_Send, "m_bCritical", (GetRandomInt(0, 100) <= 5)? 1 : 0, 1);
	SetEntProp(iSpell,    Prop_Send, "m_iTeamNum",     iTeam, 1);
	SetEntProp(iSpell,    Prop_Send, "m_nSkin", (iTeam-2));
	
	TeleportEntity(iSpell, vPosition, vAngles, NULL_VECTOR);
	/*switch(spell)
	{
		case FIREBALL, LIGHTNING:
		{
			TeleportEntity(iSpell, vPosition, vAngles, vVelocity);
		}
		case BATS, METEOR, TELE:
		{
			//TeleportEntity(iSpell, vPosition, vAngles, vVelocity);
			//SetEntPropVector(iSpell, Prop_Send, "m_vecForce", vVelocity);
			
		}
	}*/
	
	SetVariantInt(iTeam);
	AcceptEntityInput(iSpell, "TeamNum", -1, -1, 0);
	SetVariantInt(iTeam);
	AcceptEntityInput(iSpell, "SetTeam", -1, -1, 0); 
	
	DispatchSpawn(iSpell);
	/*
	switch(spell)
	{
		//These spells have arcs.
		case BATS, METEOR, TELE:
		{
			vVelocity[2] += 32.0;
		}
	}*/
	TeleportEntity(iSpell, NULL_VECTOR, NULL_VECTOR, vVelocity);
	
	return iSpell;
}