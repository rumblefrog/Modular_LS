void CastEMP(int client)
{
	if (!CanUseSpell(client, Spell_EMP))
		return;
		
	if (!DrainSpellMana(client, Spell_EMP))
		return;
	
	EmitSoundToClient(client, EMPSound);
		
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsFakeClient(i))
			TF2_AddCondition(i, TFCond_MVMBotRadiowave, 30.0, client);
	}
}