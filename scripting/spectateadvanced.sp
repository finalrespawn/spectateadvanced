#include <sourcemod>
#include <clientprefs>
#include <colours>

#pragma semicolon 1
#pragma newdecls required

#define MAX_SPEC				7
#define MAX_CLIENT_NAME			16
#define TICK_INTERVAL			4
#define SPECMODE_NONE			0
#define SPECMODE_FIRSTPERSON	4
#define SPECMODE_3RDPERSON		5
#define SPECMODE_FREELOOK		6

public Plugin myinfo = {
	name = "Spectate Advanced",
	author = "Clarkey",
	description = "Increases the spectators experience with spec list, show keys and more.",
	version = "1.0",
	url = "http://finalrespawn.com"
};

ConVar g_vDisplayPosition;
ConVar g_vSpecListDefault;
ConVar g_vSpecListOthersDefault;
ConVar g_vShowKeysDefault;
ConVar g_vShowKeysOthersDefault;

Handle g_cSpecList;
Handle g_cSpecListOthers;
Handle g_cShowKeys;
Handle g_cShowKeysOthers;

bool g_bSpecList[MAXPLAYERS + 1];
bool g_bSpecListOthers[MAXPLAYERS + 1];
bool g_bShowKeys[MAXPLAYERS + 1];
bool g_bShowKeysOthers[MAXPLAYERS + 1];
bool g_bSpecListDefault;
bool g_bSpecListOthersDefault;
bool g_bShowKeysDefault;
bool g_bShowKeysOthersDefault;

char g_sSpecListPanel[MAXPLAYERS + 1][256];
char g_sSpecListHud[MAXPLAYERS + 1][256];

int g_iButtonsPressed[MAXPLAYERS + 1];
int g_iDisplayPosition;
int g_iSpectating[MAXPLAYERS + 1];
int g_iTickCounter;

/***********/
/** START **/
/***********/

public void OnPluginStart()
{
	// Commands
	RegConsoleCmd("sm_speclist", Command_SpecList, "Enable and disable the spec list");
	RegConsoleCmd("sm_showkeys", Command_ShowKeys, "Enable and disable the show keys");

	// Cookies
	g_cSpecList = RegClientCookie("SpecList", "Enable and disable the spec list", CookieAccess_Protected);
	g_cSpecListOthers = RegClientCookie("SpecListOthers", "Enable and disable the spec list for others", CookieAccess_Protected);
	g_cShowKeys = RegClientCookie("ShowKeys", "Enable and disable show keys", CookieAccess_Protected);
	g_cShowKeysOthers = RegClientCookie("ShowKeysOthers", "Enable and disable show keys for others", CookieAccess_Protected);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && AreClientCookiesCached(i))
		{
			LoadClientPrefs(i);
		}
	}

	// Translations
	LoadTranslations("spectateadvanced.phrases");

	// Variables
	g_vDisplayPosition = CreateConVar("sm_spectateadvanced_displayposition", "0", "Spectate display position, 0 = panel, 1 = hud, 2 = both", _, true, 0.0, true, 2.0);
	g_vSpecListDefault = CreateConVar("sm_spectateadvanced_speclist", "1", "Default value for showing the spec list", _, true, 0.0);
	g_vSpecListOthersDefault = CreateConVar("sm_spectateadvanced_speclistothers", "1", "Default value for showing the spec list for others", _, true, 0.0);
	g_vShowKeysDefault = CreateConVar("sm_spectateadvanced_showkeys", "0", "Default value for showing the show keys", _, true, 0.0);
	g_vShowKeysOthersDefault = CreateConVar("sm_spectateadvanced_showkeysothers", "1", "Default value for showing the show keys for others", _, true, 0.0);

	AutoExecConfig();
}

public void OnMapStart()
{
	CreateTimer(1.0, Timer_GetSpectators, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public void OnConfigsExecuted()
{
	g_iDisplayPosition = g_vDisplayPosition.IntValue;
	g_bSpecListDefault = g_vSpecListDefault.BoolValue;
	g_bSpecListOthersDefault = g_vSpecListOthersDefault.BoolValue;
	g_bShowKeysDefault = g_vShowKeysDefault.BoolValue;
	g_bShowKeysOthersDefault = g_vShowKeysOthersDefault.BoolValue;
}

public void OnClientPutInServer(int client)
{
	if (IsClientInGame(client) && AreClientCookiesCached(client))
	{
		LoadClientPrefs(client);
	}
}

public void LoadClientPrefs(int client)
{
	char SpecList[8], SpecListOthers[8], ShowKeys[8], ShowKeysOthers[8];

	GetClientCookie(client, g_cSpecList, SpecList, sizeof(SpecList));
	GetClientCookie(client, g_cSpecListOthers, SpecListOthers, sizeof(SpecListOthers));
	GetClientCookie(client, g_cShowKeys, ShowKeys, sizeof(ShowKeys));
	GetClientCookie(client, g_cShowKeysOthers, ShowKeysOthers, sizeof(ShowKeysOthers));

	// Load default values
	g_bSpecList[client] = g_bSpecListDefault;
	g_bSpecListOthers[client] = g_bSpecListOthersDefault;
	g_bShowKeys[client] = g_bShowKeysDefault;
	g_bShowKeysOthers[client] = g_bShowKeysOthersDefault;

	// Load custom values
	if (!StrEqual("", SpecList))
	{
		g_bSpecList[client] = view_as<bool>(StringToInt(SpecList));
	}

	if (!StrEqual("", SpecListOthers))
	{
		g_bSpecListOthers[client] = view_as<bool>(StringToInt(SpecListOthers));
	}

	if (!StrEqual("", ShowKeys))
	{
		g_bShowKeys[client] = view_as<bool>(StringToInt(ShowKeys));
	}

	if (!StrEqual("", ShowKeysOthers))
	{
		g_bShowKeysOthers[client] = view_as<bool>(StringToInt(ShowKeysOthers));
	}
}

public void OnClientDisconnect_Post(int client)
{
	g_iButtonsPressed[client] = 0;
	g_iSpectating[client] = 0;
}

/**************/
/** COMMANDS **/
/**************/

public Action Command_SpecList(int client, int args)
{
	if (GetTarget(client) < 1)
	{
		if (g_bSpecList[client])
		{
			g_bSpecList[client] = false;
			SetClientCookie(client, g_cSpecList, "0");
			CPrintToChat(client, "%t", "Spec List Disabled");
		}
		else
		{
			g_bSpecList[client] = true;
			SetClientCookie(client, g_cSpecList, "1");
			CPrintToChat(client, "%t", "Spec List Enabled");
		}
	}
	else
	{
		if (g_bSpecListOthers[client])
		{
			g_bSpecListOthers[client] = false;
			SetClientCookie(client, g_cSpecListOthers, "0");
			CPrintToChat(client, "%t", "Spec List Others Disabled");
		}
		else
		{
			g_bSpecListOthers[client] = true;
			SetClientCookie(client, g_cSpecListOthers, "1");
			CPrintToChat(client, "%t", "Spec List Others Enabled");
		}
	}
}

public Action Command_ShowKeys(int client, int args)
{
	if (GetTarget(client) < 1)
	{
		if (g_bShowKeys[client])
		{
			g_bShowKeys[client] = false;
			SetClientCookie(client, g_cShowKeys, "0");
			CPrintToChat(client, "%t", "Show Keys Disabled");
		}
		else
		{
			g_bShowKeys[client] = true;
			SetClientCookie(client, g_cShowKeys, "1");
			CPrintToChat(client, "%t", "Show Keys Enabled");
		}
	}
	else
	{
		if (g_bShowKeysOthers[client])
		{
			g_bShowKeysOthers[client] = false;
			SetClientCookie(client, g_cShowKeysOthers, "0");
			CPrintToChat(client, "%t", "Show Keys Others Disabled");
		}
		else
		{
			g_bShowKeysOthers[client] = true;
			SetClientCookie(client, g_cShowKeysOthers, "1");
			CPrintToChat(client, "%t", "Show Keys Others Enabled");
		}
	}
}

/************/
/** EVENTS **/
/************/

public void OnGameFrame()
{
	g_iTickCounter++;

	if (g_iTickCounter == TICK_INTERVAL)
	{
		UpdateDisplay();
		g_iTickCounter = 0;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	g_iButtonsPressed[client] = buttons;
}

/**************/
/** HANDLERS **/
/**************/

public int Panel_Spectate(Menu menu, MenuAction action, int param1, int param2)
{
	return 0;
}

/************/
/** STOCKS **/
/************/

stock int GetTarget(int client)
{
	// Playing themselves
	if (IsPlayerAlive(client) && !IsClientObserver(client))
	{
		return -1;
	}

	int SpecMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

	// Spectating the world
	if (SpecMode != SPECMODE_FIRSTPERSON && SpecMode != SPECMODE_3RDPERSON)
	{
		return 0;
	}

	// Normal spectator
	int Target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

	return Target;
}

/************/
/** TIMERS **/
/************/

public Action Timer_GetSpectators(Handle timer, any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
		{
			continue;
		}

		g_iSpectating[i] = GetTarget(i);
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || IsClientObserver(i))
		{
			continue;
		}

		MakeSpecList(i);
	}

	return Plugin_Continue;
}

/************/
/** CUSTOM **/
/************/

void MakeSpecList(int client)
{
	char TempOutputPanel[256];
	int SpecCount;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
		{
			continue;
		}

		// Add their name to the list
		if (client == g_iSpectating[i])
		{
			if (SpecCount < MAX_SPEC)
			{
				char ClientName[64];
				GetClientName(i, ClientName, sizeof(ClientName));

				if (strlen(ClientName) > MAX_CLIENT_NAME)
				{
					ClientName[MAX_CLIENT_NAME - 3] = '.';
					ClientName[MAX_CLIENT_NAME - 2] = '.';
					ClientName[MAX_CLIENT_NAME - 1] = '.';

					for (int j = MAX_CLIENT_NAME; j < sizeof(ClientName); j++)
					{
						ClientName[j] = 0;
					}
				}

				// Create the speclist panel
				if (g_iDisplayPosition != 1)
				{
					// Add their name to the final output
					Format(TempOutputPanel, sizeof(TempOutputPanel), "%s\n%s", TempOutputPanel, ClientName);
				}
			}

			SpecCount++;
		}
	}

	// Wipe the list before creating it
	g_sSpecListPanel[client] = "";
	g_sSpecListHud[client] = "";

	if (SpecCount > 0)
	{
		// Create the speclist panel
		if (g_iDisplayPosition != 1)
		{
			// Title
			Format(g_sSpecListPanel[client], sizeof(g_sSpecListPanel[]), "Spec List (%i)\n", SpecCount);

			// Add the names
			Format(g_sSpecListPanel[client], sizeof(g_sSpecListPanel[]), "%s%s", g_sSpecListPanel[client], TempOutputPanel);

			if (SpecCount > MAX_SPEC)
			{
				Format(g_sSpecListPanel[client], sizeof(g_sSpecListPanel[]), "%s\nand %i more!", g_sSpecListPanel[client], SpecCount - MAX_SPEC);
			}
		}
	}

	// Create the speclist panel
	if (g_iDisplayPosition != 0)
	{
		Format(g_sSpecListHud[client], sizeof(g_sSpecListHud[]), "Spec: %i", SpecCount);
	}
}

void UpdateDisplay()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
		{
			continue;
		}

		char OutputPanel[512], OutputHud[512];

		// Who are they spectating, is it themself?
		int Target = GetTarget(i);
		if (Target == -1)
		{
			Target = i;
		}

		// Do we need to render the show keys menu
		if ((g_bShowKeys[i] && GetTarget(i) == -1) || (g_bShowKeysOthers[i] && GetTarget(i) > 0))
		{
			int Buttons = g_iButtonsPressed[Target];

			// Create the showkeys panel
			if (g_iDisplayPosition != 1)
			{
				// Title
				Format(OutputPanel, sizeof(OutputPanel), "Show Keys\n");

				// Are they pressing "W"?
				if(Buttons & IN_FORWARD)
					Format(OutputPanel, sizeof(OutputPanel), "%s       W\n", OutputPanel);
				else
					Format(OutputPanel, sizeof(OutputPanel), "%s       _\n", OutputPanel);

				// Are they pressing "A"?
				if(Buttons & IN_MOVELEFT)
					Format(OutputPanel, sizeof(OutputPanel), "%s   A", OutputPanel);
				else
					Format(OutputPanel, sizeof(OutputPanel), "%s   _", OutputPanel);

				// Are they pressing "S"?
				if(Buttons & IN_BACK)
					Format(OutputPanel, sizeof(OutputPanel), "%s  S", OutputPanel);
				else
					Format(OutputPanel, sizeof(OutputPanel), "%s  _", OutputPanel);

				// Are they pressing "D"?
				if(Buttons & IN_MOVERIGHT)
					Format(OutputPanel, sizeof(OutputPanel), "%s  D\n \n", OutputPanel);
				else
					Format(OutputPanel, sizeof(OutputPanel), "%s  _\n \n", OutputPanel);

				// Are they pressing "SPACE"?
				if(Buttons & IN_JUMP)
					Format(OutputPanel, sizeof(OutputPanel), "%s    JUMP\n", OutputPanel);
				else
					Format(OutputPanel, sizeof(OutputPanel), "%s    ____\n", OutputPanel);

				// Are they pressing "CTRL"?
				if(Buttons & IN_DUCK)
					Format(OutputPanel, sizeof(OutputPanel), "%s    DUCK\n", OutputPanel);
				else
					Format(OutputPanel, sizeof(OutputPanel), "%s    ____\n", OutputPanel);

				// Are they pressing "SHIFT"?
				if(Buttons & IN_SPEED)
					Format(OutputPanel, sizeof(OutputPanel), "%s    WALK", OutputPanel);
				else
					Format(OutputPanel, sizeof(OutputPanel), "%s    ____", OutputPanel);
			}

			// Create the showkeys hud
			if (g_iDisplayPosition != 0)
			{
				// Title
				Format(OutputHud, sizeof(OutputHud), "Keys:");

				// Are they pressing "A"?
				if(Buttons & IN_MOVELEFT)
					Format(OutputHud, sizeof(OutputHud), "%s A", OutputHud);
				else
					Format(OutputHud, sizeof(OutputHud), "%s _", OutputHud);

				// Are they pressing "W"?
				if(Buttons & IN_FORWARD)
					Format(OutputHud, sizeof(OutputHud), "%s W", OutputHud);
				else
					Format(OutputHud, sizeof(OutputHud), "%s _", OutputHud);

				// Are they pressing "S"?
				if(Buttons & IN_BACK)
					Format(OutputHud, sizeof(OutputHud), "%s S", OutputHud);
				else
					Format(OutputHud, sizeof(OutputHud), "%s _", OutputHud);

				// Are they pressing "D"?
				if(Buttons & IN_MOVERIGHT)
					Format(OutputHud, sizeof(OutputHud), "%s D", OutputHud);
				else
					Format(OutputHud, sizeof(OutputHud), "%s _", OutputHud);

				// Are they pressing "SPACE"?
				if(Buttons & IN_JUMP)
					Format(OutputHud, sizeof(OutputHud), "%s - J", OutputHud);
				else
					Format(OutputHud, sizeof(OutputHud), "%s - _", OutputHud);

				// Are they pressing "CTRL"?
				if(Buttons & IN_DUCK)
					Format(OutputHud, sizeof(OutputHud), "%s C", OutputHud);
				else
					Format(OutputHud, sizeof(OutputHud), "%s _", OutputHud);

				// Are they pressing "SHIFT"?
				if(Buttons & IN_SPEED)
					Format(OutputHud, sizeof(OutputHud), "%s W", OutputHud);
				else
					Format(OutputHud, sizeof(OutputHud), "%s _", OutputHud);
			}
		}

		// Add the speed to the hud
		// We only add the speed if something else is showing as well
		if (!StrEqual("", OutputHud) || (!StrEqual("", g_sSpecListHud[Target]) && ((g_bSpecList[i] && GetTarget(i) == -1) || (g_bSpecListOthers[i] && GetTarget(i) > 0))))
		{
			if (g_iDisplayPosition != 0)
			{
				// Do we need to create new lines or not?
				if (!StrEqual("", OutputHud))
				{
					Format(OutputHud, sizeof(OutputHud), "%s\n", OutputHud);
				}

				float Velocity[3], Speed;
				GetEntPropVector(Target, Prop_Data, "m_vecVelocity", Velocity);
				Speed = SquareRoot(Pow(Velocity[0], 2.0) + Pow(Velocity[1], 2.0));

				Format(OutputHud, sizeof(OutputHud), "%sSpeed: %.2f", OutputHud, Speed);
			}
		}

		// Do we need to render the spec list
		if ((g_bSpecList[i] && GetTarget(i) == -1) || (g_bSpecListOthers[i] && GetTarget(i) > 0))
		{
			// Create the speclist panel
			if (g_iDisplayPosition != 1)
			{
				// Do we need to create new lines or not?
				if (!StrEqual("", OutputPanel) && !StrEqual("", g_sSpecListPanel[Target]))
				{
					Format(OutputPanel, sizeof(OutputPanel), "%s\n \n", OutputPanel);
				}

				Format(OutputPanel, sizeof(OutputPanel), "%s%s", OutputPanel, g_sSpecListPanel[Target]);
			}

			// Create the speclist hud
			if (g_iDisplayPosition != 0)
			{
				Format(OutputHud, sizeof(OutputHud), "%s\n%s", OutputHud, g_sSpecListHud[Target]);
			}
		}

		// Display the panel
		if (g_iDisplayPosition != 1)
		{
			// If the output is not empty we can display something
			if (!StrEqual("", OutputPanel))
			{
				if (!IsVoteInProgress())
				{
					Panel panel = new Panel();
					panel.DrawText(OutputPanel);
					panel.Send(i, Panel_Spectate, 1);

					delete panel;
				}
			}
		}

		// Display the hud
		if (g_iDisplayPosition != 0)
		{
			// If the output is not empty we can display something
			if (!StrEqual("", OutputHud))
			{
				PrintHintText(i, OutputHud);
			}
		}
	}
}
