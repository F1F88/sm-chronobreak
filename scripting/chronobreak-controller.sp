#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <multicolors>

// #include <log4sp>
#include <nmrih_player>
#include <usermessages_stock>

#include <chronobreak>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_NAME        "EkkoChronobreakController"
#define PLUGIN_DESCRIPTION "Ekko Abilitie Chronobreak Controller"
#define PLUGIN_VERSION     "1.0.0"

public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = "F1F88",
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = "https://github.com/F1F88/"
};


#define private         /**/


public void OnPluginStart()
{
    HookEvent("player_spawn", Event_PlayerSpawnPost);
    RegAdminCmd("sm_cbe",  CMD_Enable, ADMFLAG_GENERIC);
    RegAdminCmd("sm_cbu", CMD_Use, ADMFLAG_GENERIC);
}

public void OnChronobreakDisablePost(int userId, ChronobreakDisabledReason reason)
{
    if (reason != ChronobreakReason_ClientDisconnect && reason != ChronobreakReason_InvalidClient)
    {
        int client = GetClientOfUserId(userId);
        SDKUnhook(client, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamageAlive);
    }
}

private void Event_PlayerSpawnPost(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);
    if (IsValidClient(client))
    {
        Chronobreak cb = Chronobreak(client);
        cb.Enable(3);
        SDKHook(client, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamageAlive);
        CPrintToChat(client, "{green}[提示]{default} 护身法器已启用，{green}%.0f 秒{default}后可抵挡一次致命伤。", cb.GetPastTime());
    }
}

private Action Hook_OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
    Chronobreak cb = Chronobreak(victim);
    if (cb.GetState() == ChronobreakState_Disabled)
    {
        SDKUnhook(victim, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamageAlive);
        return Plugin_Continue;
    }

    if (cb.GetState() == ChronobreakState_InUse)
    {
        return Plugin_Stop;
    }

    NMR_Player player = NMR_Player(victim);
    if (damage >= float(player.m_iHealth) && cb.GetState() == ChronobreakState_Ready)
    {
        cb.Use();
        return Plugin_Stop;
    }

    return Plugin_Continue;
}


private Action CMD_Enable(int client, int args)
{
    if (!IsValidClient(client))
    {
        ReplyToCommand(client, "[SM] Command is in-game only.");
        return Plugin_Handled;
    }

    if (!IsPlayerAlive(client))
    {
        ReplyToCommand(client, "[SM] Command is alive only.");
        return Plugin_Handled;
    }

    Chronobreak cb = Chronobreak(client);
    ChronobreakState state = cb.GetState();
    if (state != ChronobreakState_Disabled)
    {
        ReplyToCommand(client, "[响应] 已经启用过了. (%d)", state);
        return Plugin_Handled;
    }

    cb.Enable(2);
    PrintToChatAll("[响应] 玩家 %N 开启了时空回溯。", client);
    return Plugin_Handled;
}

private Action CMD_Use(int client, int args)
{
    if (!IsValidClient(client))
    {
        ReplyToCommand(client, "[SM] Command is in-game only.");
        return Plugin_Handled;
    }

    if (!IsPlayerAlive(client))
    {
        ReplyToCommand(client, "[SM] Command is alive only.");
        return Plugin_Handled;
    }

    Chronobreak cb = Chronobreak(client);
    ChronobreakState state = cb.GetState();
    if (state != ChronobreakState_Ready)
    {
        ReplyToCommand(client, "[响应] 时空回溯还未充能完毕。 (%d)", state);
        return Plugin_Handled;
    }

    cb.Use();
    PrintToChatAll("[响应] 玩家 %N 开始时空回溯。", client);
    return Plugin_Handled;
}


// public void OnChronobreakDisablePost(int userId, ChronobreakState oldState)
// {
//     int client = GetClientOfUserId(userId);
//     Chronobreak cb = Chronobreak(client);
//     PrintToServer("[Debug] Client %N disable from state %d.", client, oldState);
//     PrintToServer("[Debug] Client %N state = %d.", client, cb.GetState());
// }

// public void OnChronobreakEnablePost(int userId)
// {
//     int client = GetClientOfUserId(userId);
//     Chronobreak cb = Chronobreak(client);
//     PrintToServer("[Debug] Client %N enable.", client);
//     PrintToServer("[Debug] Client %N state = %d.", client, cb.GetState());
// }

// public void OnChronobreakReadyPost(int userId, BacktrackingData startData, BacktrackingData endData)
// {
//     int client = GetClientOfUserId(userId);
//     Chronobreak cb = Chronobreak(client);
//     PrintToServer("[Debug] Client %N ready.", GetClientOfUserId(userId));
//     PrintToServer("[Debug] Client %N state = %d.", client, cb.GetState());
// }


// public void OnChronobreakUsePost(int userId, BacktrackingData startData, BacktrackingData endData)
// {
//     int client = GetClientOfUserId(userId);
//     Chronobreak cb = Chronobreak(client);
//     PrintToServer("[Debug] Client %N enable.", client);
//     PrintToServer("[Debug] Client %N state = %d.", client, cb.GetState());
// }
