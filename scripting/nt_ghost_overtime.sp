
#include <sdktools>

#pragma semicolon 1

#define PLUGIN_VERSION "1.2.0"

public Plugin myinfo =
{
    name = "NEOTOKYO° Ghost Overtime",
    author = "Agiel",
    description = "Extends the timer while the ghost is held",
    version = PLUGIN_VERSION,
    url = ""
};

Handle g_hGhostOvertimeDecay;
Handle g_hGhostOvertimeGrace;
Handle g_hGhostOvertimeDecayExp;
Handle g_hGhostOvertimeGraceReset;
Handle g_hRoundTimeLimit;
Handle g_hTimer_GhostOvertime;
float g_fRoundStartTime;
float g_fGhostOvertime;
float g_fGhostOvertimeTick;
bool g_bGhostOvertimeFirstTick;

public void OnPluginStart()
{
    g_hGhostOvertimeDecay = CreateConVar("sm_ghost_overtime", "30", "Add up to this many seconds to the round time while the ghost is held.", _, true, 0.0, true, 120.0);
    g_hGhostOvertimeGrace = CreateConVar("sm_ghost_overtime_grace", "10", "Freeze the round timer at this many seconds while the ghost is held. 0 = disabled", _, true, 0.0, true, 30.0);
    g_hGhostOvertimeDecayExp = CreateConVar("sm_ghost_overtime_decay_exp", "0", "Whether ghost overtime should decay exponentially or linearly.", _, true, 0.0, true, 1.0);
    g_hGhostOvertimeGraceReset = CreateConVar("sm_ghost_overtime_grace_reset", "1", "When the ghost is picked up, reset the timer to where it would be on the decay curve if the ghost was never dropped. This means the full overtime can be used even when juggling.", _, true, 0.0, true, 1.0);
    g_hRoundTimeLimit = FindConVar("neo_round_timelimit");

    HookEvent("game_round_start", Event_RoundStart);

    AutoExecConfig(true);
}

public OnAllPluginsLoaded()
{
    CheckGhostcapPlugin();
}

void CheckGhostcapPlugin()
{
    Handle ghostcapPlugin = FindConVar("sm_ntghostcap_version");

    // Look for ghost cap plugin's version variable
    if (ghostcapPlugin == null)
    {
        char ghostcapUrl[] = "https://github.com/Agiel/nt-sourcemod-plugins";
        LogError("This plugin requires Soft as HELL's Ghost cap event plugin to work properly. Find it at: %s", ghostcapUrl);
    }
}

public OnGhostPickUp(client)
{
    int gameState = GameRules_GetProp("m_iGameState");
    if (gameState == 2 && GetConVarInt(g_hGhostOvertimeDecay) > 0)
    {
        bool graceReset = GetConVarBool(g_hGhostOvertimeGraceReset);
        if (!graceReset)
        {
            float timeLeft = GameRules_GetPropFloat("m_fRoundTimeLeft");
            if (timeLeft < g_fGhostOvertime)
            {
                g_fGhostOvertime = g_fGhostOvertimeTick = timeLeft;
            }
        }
        g_bGhostOvertimeFirstTick = true;
        // Inverval of 0.9 to tick before the second flips over to prevent HUD flicker
        g_hTimer_GhostOvertime = CreateTimer(0.5, CheckGhostOvertime, _, TIMER_REPEAT);
        CheckGhostOvertime(g_hTimer_GhostOvertime);
    }
}

public OnGhostDrop(client)
{
    if (g_hTimer_GhostOvertime != INVALID_HANDLE)
    {
        CloseHandle(g_hTimer_GhostOvertime);
        g_hTimer_GhostOvertime = INVALID_HANDLE;
    }
}

public Action CheckGhostOvertime(Handle timer)
{
    int gameState = GameRules_GetProp("m_iGameState");
    if (gameState != 2)
    {
        g_hTimer_GhostOvertime = INVALID_HANDLE;
        return Plugin_Stop;
    }

    float timeLeft = GameRules_GetPropFloat("m_fRoundTimeLeft");
    float graceTime = GetConVarFloat(g_hGhostOvertimeGrace);
    if (timeLeft <= graceTime)
    {
        float realTimeLeft;
        float decayTime = GetConVarFloat(g_hGhostOvertimeDecay) + graceTime;
        bool graceReset = GetConVarBool(g_hGhostOvertimeGraceReset);
        if (graceReset)
        {
            float roundTime = GetConVarFloat(g_hRoundTimeLimit) * 60;
            float overtime = GetGameTime() - (g_fRoundStartTime + roundTime - graceTime);
            bool decayExp = GetConVarBool(g_hGhostOvertimeDecayExp);
            if (decayExp)
            {
                g_fGhostOvertime = graceTime + 1 - Pow(graceTime + 1, overtime / decayTime);
            }
            else
            {
                g_fGhostOvertime = graceTime - graceTime * overtime / decayTime;
            }
            realTimeLeft = decayTime - overtime;
        }
        else
        {
            float timePassed = g_fGhostOvertimeTick - timeLeft;
            g_fGhostOvertime -= timePassed * graceTime / decayTime;
            g_fGhostOvertimeTick = float(RoundToCeil(g_fGhostOvertime));
            realTimeLeft = g_fGhostOvertime * decayTime / graceTime;
        }
        // Round up to nearest int to prevent HUD flicker
        GameRules_SetPropFloat("m_fRoundTimeLeft", float(RoundToCeil(g_fGhostOvertime)));
        // Everything's multiplied by 2 because we want to tick every second, but the interval is 0.5
        bool printTick = g_bGhostOvertimeFirstTick
            || (RoundToCeil(realTimeLeft * 2) % RoundToCeil(graceTime * 2) == 0) // Divisible by graceTime
            || (realTimeLeft < graceTime && RoundToCeil(realTimeLeft * 2) % 10 == 0) // Divisible by 5
            || (realTimeLeft < 5 && RoundToCeil(realTimeLeft * 2) % 2 == 0);
        if (printTick) {
            PrintToChatAll("Ghost overtime engaged. %d seconds remaining.", RoundToCeil(realTimeLeft));
            g_bGhostOvertimeFirstTick = false;
        }
    }

    return Plugin_Continue;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    g_fRoundStartTime = GetGameTime();
    g_fGhostOvertime = g_fGhostOvertimeTick = GetConVarFloat(g_hGhostOvertimeGrace);
}
