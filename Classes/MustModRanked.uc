/**
 * MUSTMOD: ranked LTS, modelled on ImbaMod's ranked mode (MIT, Gorilliath 2020).
 * Server-only -- spawned by MustModLTS, never on a client.
 *
 * Flow:
 *   1. Queue. Once 2 x RankedMinTeamSize players are ready in pre-round, a QueueCountdown
 *      starts so more can join. When it ends (or the queue reaches 2 x RankedMaxTeamSize)
 *      everyone queued goes to the backend, which makes the largest even match it can and
 *      balances the teams by Elo. MustModGame.ShouldCountDown holds the match until then.
 *   2. Locked. Teams are forced and locked by SteamID64; nobody else can join a side.
 *   3. Leaver. A locked player disconnecting pauses the game for LeaverPauseSeconds -- at
 *      once between rounds, or mid-round as soon as that round is decided (before the next
 *      one starts), so the leaver's team never plays a round short. If they come back it
 *      resumes (or, back before the round ends, it never pauses). If time runs out, or an admin runs RankedAbandon, the match is
 *      abandoned: leavers lose Elo, everyone else's result is void, and the map restarts.
 *   4. Surrender (optional). After SURRENDER_MIN_ROUNDS rounds, "!ff" in chat starts a team
 *      vote ("!yes" / "!no"). If it passes, the round in play is finished and the match ends
 *      as a loss for that team.
 *   5. Result. A few seconds after EndGame the winner, round scores and per-player stats are
 *      posted and the backend applies the Elo changes, which scale with the round margin.
 *
 * Every call is POST <RankedEndpoint>/<action> with a JSON body and the server's secret in
 * x-server-token; the backend is supabase/functions/ranked. Config lives in the SERVER's
 * UDKGame.ini under [MustMod.MustModRanked]. The token must never go in DefaultMustMod.ini:
 * that ships with the Workshop package, and anything in it is readable by every player.
 */
class MustModRanked extends Info
	config(Game);

const CHAT_COLOUR = "#00BFFF";

// Surrender vote (!ff, then !yes / !no from the team). Passing needs MORE than this percent
// of the team's connected players; anyone who has not voted when it ends counts as no.
const SURRENDER_MIN_ROUNDS = 4;
const SURRENDER_VOTE_SECONDS = 30.0;
const SURRENDER_PASS_PERCENT = 60;
const SURRENDER_RETRY_SECONDS = 60.0;   // after a failed vote, before that team may !ff again

var config bool bRankedEnabled;         // Admin RankedMode 0/1 flips this and saves it
var config string RankedEndpoint;       // https://<project-ref>.supabase.co/functions/v1/ranked
var config string RankedServerToken;
var config int RankedMinTeamSize;       // smallest match, players per side; 0 means 2
var config int RankedMaxTeamSize;       // biggest match, players per side; 0 means 16
var config float QueueCountdown;        // seconds from enough players to matchmaking; 0 means 30
var config float LeaverPauseSeconds;    // 0 means 120
var config bool bRatDisabled;           // admindisablerat 1/0: no Man-at-Arms in a ranked match

enum ERankedState
{
	RS_Queue,       // waiting for enough players / for the backend to make a match
	RS_Requesting,  // a matchmake request is in flight
	RS_Locked,      // match made, teams locked, playing
	RS_Paused,      // a locked player left; waiting for them to come back
	RS_Closing,     // match over (result/abandon/cancel sent); the map restart is scheduled
	RS_Finished     // ranked is off on this map; nothing to do
};

var ERankedState RankedState;

/** Queue countdown, in WorldInfo.TimeSeconds (pre-round is never paused). 0 = not running. */
var float QueueStartTime;
var float NextQueueNotice;
var string MatchId;

/** Locked lineups by SteamID64. Team 1 = Agatha, team 2 = Mason. */
var array<string> Team1Ids;
var array<string> Team2Ids;

/** Locked players currently disconnected, with their names for the countdown messages. */
var array<string> MissingIds;
var array<string> MissingNames;

/** Locked players who left and reconnected: the only spectators allowed to join a side. */
var array<string> ReturnedIds;

/** Pause bookkeeping. RealTimeSeconds, because WorldInfo.TimeSeconds stops while paused. */
var float PauseDeadline;
var float NextPauseNotice;
var bool bPauseableForced;
var bool bPauseableWas;

/** A locked player left mid-round: pause as soon as that round is decided (OnRoundEnded),
 *  so it plays out but the leaver's team never starts a round short. */
var bool bPauseAtRoundEnd;

/** Names as the players chose them, so the "[elo] " prefix is never applied twice. */
var array<string> OriginalNameIds;
var array<string> OriginalNames;

var bool bResultRetried;

/**
 * Stats of lineup players taken as they disconnected (mid-match or on the end screen), as
 * ready-made JSON objects. Used for anyone not connected when the result or abandon is sent;
 * a player who came back is read live instead.
 */
var array<string> SnapshotIds;
var array<string> SnapshotStats;

/** What the running voteranked/voteunranked vote would set bRankedEnabled to. */
var bool bVoteToEnable;

/**
 * Requests still waiting on the native side, with the action each one was for. Holding the
 * reference is what keeps the request alive -- a request nothing points at can be garbage
 * collected mid-flight, and its completion delegate then never fires.
 */
var array<HttpRequestInterface> PendingRequests;
var array<string> PendingActions;

var bool bLoggedNotConfigured;

/**
 * Surrender vote. SurrenderVoteTeam is the team voting (1/2), 0 when none is running. The
 * voters are the team's players connected when it started. Times are RealTimeSeconds, so
 * the vote keeps running through a leaver pause.
 */
var int SurrenderVoteTeam;
var float SurrenderVoteDeadline;
var array<string> SurrenderVoters;
var array<string> SurrenderYes;
var array<string> SurrenderNo;
var float NextSurrenderVote[3];         // indexed by team

/** The team whose surrender passed; the match ends when the round in play does. 0 = none. */
var int SurrenderedTeam;

// ---- Lifecycle -------------------------------------------------------------------------

event PostBeginPlay()
{
	super.PostBeginPlay();

	if (!IsActive())
	{
		RankedState = RS_Finished;
		return;
	}

	RankedState = RS_Queue;
	SetTimer(1.0, true, 'QueueTick');
}

/** Runs even while paused (bAlwaysTick), which is the only reason it exists: timers do not. */
event Tick(float DeltaTime)
{
	local float Remaining;

	super.Tick(DeltaTime);

	if (SurrenderVoteTeam != 0)
	{
		if (IsLocked())
			CheckSurrenderVote();
		else
			SurrenderVoteTeam = 0;   // the match ended or was voided under the vote
	}

	if (RankedState != RS_Paused)
		return;

	Remaining = PauseDeadline - WorldInfo.RealTimeSeconds;
	if (Remaining <= 0)
	{
		Broadcast(JoinNames(MissingNames) @ "did not return in time. The match is abandoned.");
		AbandonMatch();
		return;
	}

	if (WorldInfo.RealTimeSeconds >= NextPauseNotice)
	{
		Broadcast("Waiting for" @ JoinNames(MissingNames) @ "to reconnect:" @ int(Remaining) $ "s left.");
		NextPauseNotice = WorldInfo.RealTimeSeconds + 30.0;
	}
}

/**
 * Persist the admin-changeable settings. SaveConfig only writes the ini; every new map spawns
 * this actor from the class defaults, which were read once at startup, so without updating
 * them too the change is undone by the next map restart (rankedmode 0 "just restarting the
 * map"). Same pattern as MustModGame.ConfigureTournamentMode.
 */
function SaveSettings()
{
	SaveConfig();
	default.bRankedEnabled = bRankedEnabled;
	default.RankedMinTeamSize = RankedMinTeamSize;
	default.RankedMaxTeamSize = RankedMaxTeamSize;
	default.bRatDisabled = bRatDisabled;
}

function bool IsConfigured()
{
	return RankedEndpoint != "" && RankedServerToken != "";
}

function bool IsActive()
{
	return bRankedEnabled && IsConfigured();
}

function int GetMinTeamSize()
{
	return Clamp(RankedMinTeamSize > 0 ? RankedMinTeamSize : 2, 1, GetMaxTeamSize());
}

function int GetMaxTeamSize()
{
	return Clamp(RankedMaxTeamSize > 0 ? RankedMaxTeamSize : 16, 1, 16);
}

function float GetLeaverPauseSeconds()
{
	return LeaverPauseSeconds > 0 ? LeaverPauseSeconds : 120.0;
}

function float GetQueueCountdown()
{
	return QueueCountdown > 0 ? QueueCountdown : 30.0;
}

/** True while a locked player's leave has the game paused (owned by this actor). */
function bool IsLeaverPaused()
{
	return RankedState == RS_Paused;
}

/** MustModGame.ShouldCountDown asks this; the match may not start until teams are locked. */
function bool AllowsCountdown()
{
	return !IsActive() || RankedState == RS_Locked || RankedState == RS_Finished;
}

function bool IsLocked()
{
	return RankedState == RS_Locked || RankedState == RS_Paused;
}

function bool IsPaused()
{
	return RankedState == RS_Paused;
}

/**
 * From matchmaking until the map restart this class schedules. Map restarts/changes by
 * hand are refused in this window: they would void a match or lose its result.
 */
function bool IsMatchLive()
{
	return RankedState == RS_Requesting || IsLocked() || RankedState == RS_Closing;
}

// ---- Queue / matchmaking ---------------------------------------------------------------

/**
 * Every second in pre-round. Enough players starts the countdown, dropping below the
 * minimum stops it, and a full queue (2 x max) skips the rest of the wait.
 */
function QueueTick()
{
	local array<AOCPlayerController> Queue;
	local float Remaining;
	local int Needed;

	if (RankedState != RS_Queue)
		return;

	BuildQueue(Queue);
	Needed = GetMinTeamSize() * 2;

	if (Queue.Length < Needed)
	{
		if (QueueStartTime > 0)
		{
			QueueStartTime = 0;
			Broadcast("Ranked: not enough players any more, countdown stopped.");
		}
		if (Queue.Length > 0 && WorldInfo.TimeSeconds >= NextQueueNotice)
		{
			Broadcast("Ranked: need at least" @ Needed @ "players, have" @ Queue.Length $ ". Pick a team and class to queue.");
			NextQueueNotice = WorldInfo.TimeSeconds + 20.0;
		}
		return;
	}

	if (QueueStartTime == 0)
	{
		QueueStartTime = WorldInfo.TimeSeconds;
		NextQueueNotice = WorldInfo.TimeSeconds + 10.0;
		Broadcast("Ranked match starts in" @ int(GetQueueCountdown()) $ "s. Pick a team and class to join (" $ Queue.Length @ "queued).");
	}

	Remaining = QueueStartTime + GetQueueCountdown() - WorldInfo.TimeSeconds;
	if (Remaining > 0 && Queue.Length < GetMaxTeamSize() * 2)
	{
		if (WorldInfo.TimeSeconds >= NextQueueNotice)
		{
			Broadcast("Ranked match starts in" @ int(Remaining + 0.5) $ "s (" $ Queue.Length @ "queued).");
			NextQueueNotice = WorldInfo.TimeSeconds + 10.0;
		}
		return;
	}

	SendMatchmake(Queue);
}

/** Everyone queued, earliest joiner first: the backend fills the match in this order. */
function BuildQueue(out array<AOCPlayerController> Queue)
{
	local AOCPlayerController PC;
	local int i;

	// AllControllers is not in join order, so sort by PRI.StartTime (insertion sort; the
	// list is tiny).
	foreach WorldInfo.AllControllers(class'AOCPlayerController', PC)
	{
		if (!IsQueued(PC) || SteamIdOf(PC.PlayerReplicationInfo) == "")
			continue;

		for (i = 0; i < Queue.Length; i++)
		{
			if (PC.PlayerReplicationInfo.StartTime < Queue[i].PlayerReplicationInfo.StartTime)
				break;
		}
		Queue.InsertItem(i, PC);
	}
}

/** adminstartmatch: skip the countdown. Returns why it cannot, or "" when it went out. */
function string AdminStartMatch()
{
	local array<AOCPlayerController> Queue;

	if (!IsActive())
		return "Ranked mode is off.";
	if (RankedState != RS_Queue)
		return "A ranked match is already being made or played.";

	BuildQueue(Queue);
	if (Queue.Length < 2 || Queue.Length % 2 != 0)
		return "Need an even number of queued players (have" @ Queue.Length $ ").";

	SendMatchmake(Queue, 1);
	return "";
}

/** MinTeamSize overrides RankedMinTeamSize (adminstartmatch allows down to 1v1). */
function SendMatchmake(array<AOCPlayerController> Queue, optional int MinTeamSize)
{
	local AOCPlayerController PC;
	local string Players;

	foreach Queue(PC)
	{
		if (Players != "")
			Players $= ",";
		Players $= "{" $ JsonField("steamId", SteamIdOf(PC.PlayerReplicationInfo)) $ "," $ JsonField("name", GetOriginalName(PC)) $ "}";
	}

	if (Send("matchmake", "{" $
		JsonField("map", WorldInfo.GetMapName()) $ "," $
		Quote("minTeamSize") $ ":" $ (MinTeamSize > 0 ? MinTeamSize : GetMinTeamSize()) $ "," $
		Quote("maxTeamSize") $ ":" $ GetMaxTeamSize() $ "," $
		Quote("players") $ ":[" $ Players $ "]}"))
	{
		RankedState = RS_Requesting;
	}
	else
	{
		QueueStartTime = 0;
	}
}

/** Same readiness test as MustModGame.GetActualPlayersCount: on a team, has a class, ready. */
function bool IsQueued(AOCPlayerController PC)
{
	return PC != none && !PC.IsVoluntarySpectator() && PC.CurrentFamilyInfo != none && PC.bReady
		&& PC.PlayerReplicationInfo != none && !PC.PlayerReplicationInfo.bBot;
}

function HandleMatchmake(JsonObject Data)
{
	local JsonObject Team1, Team2, Player, Excluded;
	local AOCGRI GRI;
	local string Id;

	if (Data == none || !Data.GetBoolValue("ok"))
	{
		RankedState = RS_Queue;
		QueueStartTime = 0;
		if (Data != none && Data.GetStringValue("error") != "")
			Broadcast("Ranked: no match yet (" $ Data.GetStringValue("error") $ "). Trying again shortly.");
		return;
	}

	MatchId = Data.GetStringValue("matchId");
	Team1 = Data.GetObject("team1");
	Team2 = Data.GetObject("team2");
	if (MatchId == "" || Team1 == none || Team2 == none)
	{
		RankedState = RS_Queue;
		LogAlwaysInternal("[MustModRanked] matchmake response was missing matchId or teams");
		return;
	}

	ClearTimer('QueueTick');
	Team1Ids.Length = 0;
	Team2Ids.Length = 0;

	Broadcast("Ranked" @ Data.GetIntValue("teamSize") $ "v" $ Data.GetIntValue("teamSize") @ "match found!");
	Broadcast("Agatha [" $ Data.GetIntValue("team1Avg") $ "]:");
	foreach Team1.ObjectArray(Player)
	{
		Team1Ids.AddItem(Player.GetStringValue("steamId"));
		Broadcast("    [" $ Player.GetIntValue("elo") $ "]" @ Player.GetStringValue("name"));
		ShowElo(Player.GetStringValue("steamId"), Player.GetIntValue("elo"));
	}
	Broadcast("Mason [" $ Data.GetIntValue("team2Avg") $ "]:");
	foreach Team2.ObjectArray(Player)
	{
		Team2Ids.AddItem(Player.GetStringValue("steamId"));
		Broadcast("    [" $ Player.GetIntValue("elo") $ "]" @ Player.GetStringValue("name"));
		ShowElo(Player.GetStringValue("steamId"), Player.GetIntValue("elo"));
	}

	// Players left out by the skill-gap rule are told why; the rest just did not fit.
	Excluded = Data.GetObject("excluded");
	if (Excluded != none)
	{
		foreach Excluded.ObjectArray(Player)
			TellPlayer(Player.GetStringValue("steamId"), "Ranked: " $ Player.GetStringValue("reason"));
	}

	GRI = AOCGRI(WorldInfo.GRI);
	if (GRI != none)
	{
		GRI.AgathaNameOverride = "Agatha [" $ Data.GetIntValue("team1Avg") $ "]";
		GRI.MasonNameOverride = "Mason [" $ Data.GetIntValue("team2Avg") $ "]";
	}

	RankedState = RS_Locked;
	bPauseAtRoundEnd = false;
	ReturnedIds.Length = 0;
	ForceTeams();
	if (bRatDisabled)
		ConvertRats();

	// Someone picked by the backend may have disconnected while the request was in flight.
	// They never "left" a locked match, so catch them here or the match starts short.
	foreach Team1.ObjectArray(Player)
	{
		Id = Player.GetStringValue("steamId");
		if (FindPlayer(Id) == none)
			MarkMissing(Id, Player.GetStringValue("name"));
	}
	foreach Team2.ObjectArray(Player)
	{
		Id = Player.GetStringValue("steamId");
		if (FindPlayer(Id) == none)
			MarkMissing(Id, Player.GetStringValue("name"));
	}
}

/** Put every locked player on their side and everyone else in spectator. */
function ForceTeams()
{
	local AOCPlayerController PC;
	local int Team;

	foreach WorldInfo.AllControllers(class'AOCPlayerController', PC)
	{
		Team = LockedTeamOf(SteamIdOf(PC.PlayerReplicationInfo));
		if (Team == 0)
		{
			if (!PC.IsVoluntarySpectator())
			{
				PC.JoinSpectatorTeam();
				TellPlayer(SteamIdOf(PC.PlayerReplicationInfo), "Ranked: you are not in this match. You can watch, and you will be queued for the next one.");
			}
			continue;
		}

		MoveToTeam(PC, Team == 1 ? EFAC_AGATHA : EFAC_MASON);
	}
}

/**
 * Same approach as MustModRCon.MustModForceTeam, which has the reasoning: changing
 * CurrentFamilyInfo first is the only thing that moves anyone. FamilyInfos: 0-4 Agatha,
 * 5-9 Mason.
 */
function MoveToTeam(AOCPlayerController PC, EAOCFaction Target)
{
	local AOCGRI GRI;
	local AOCFamilyInfo NewFamily;
	local int Index;

	GRI = AOCGRI(WorldInfo.GRI);
	if (GRI == none || PC.CurrentFamilyInfo == none || PC.CurrentFamilyInfo.FamilyFaction == Target)
		return;

	Index = PC.CurrentFamilyInfo.default.ClassReference;
	if (Target == EFAC_MASON)
		Index += 5;
	if (Index < 0 || Index > 9 || GRI.FamilyInfos[Index] == none)
		return;

	NewFamily = GRI.FamilyInfos[Index];
	PC.ClientAutoBalance(NewFamily);
	PC.SetNewClass(NewFamily, false, true);
	AOCPRI(PC.PlayerReplicationInfo).MyFamilyInfo = none;
	PC.ServerChangeTeam(NewFamily.FamilyFaction);
}

/** 1 = Agatha, 2 = Mason, 0 = not in the locked lineup. */
function int LockedTeamOf(string SteamId)
{
	if (SteamId == "")
		return 0;
	if (Team1Ids.Find(SteamId) != INDEX_NONE)
		return 1;
	if (Team2Ids.Find(SteamId) != INDEX_NONE)
		return 2;
	return 0;
}

/**
 * Team gate for RequestJoinTeam/RequestJoinClass while locked. Only the locked lineup may
 * play, each on their own side, and someone in spectator may not come back in -- except a
 * locked player who left and reconnected. A player already on their side can still change
 * class.
 */
function bool MayJoinTeam(AOCPlayerController PC, EAOCFaction Team)
{
	local int Locked;
	local string Id;

	// Spectating is always allowed -- that is also how ForceTeams benches the unpicked.
	if (!IsLocked() || (Team != EFAC_AGATHA && Team != EFAC_MASON))
		return true;

	Id = SteamIdOf(PC.PlayerReplicationInfo);
	Locked = LockedTeamOf(Id);
	if (!((Locked == 1 && Team == EFAC_AGATHA) || (Locked == 2 && Team == EFAC_MASON)))
		return false;

	if (IsSpectating(PC) && ReturnedIds.Find(Id) == INDEX_NONE)
	{
		TellPlayerPC(PC, "Ranked: you cannot join from spectator during the match.");
		return false;
	}
	return true;
}

/** In spectator, or not on a playing side at all. */
function bool IsSpectating(AOCPlayerController PC)
{
	return PC.IsVoluntarySpectator() || PC.PlayerReplicationInfo == none
		|| PC.PlayerReplicationInfo.Team == none || PC.PlayerReplicationInfo.Team.TeamIndex > 1;
}

// ---- Man-at-Arms ban (admindisablerat) -------------------------------------------------

/** Man-at-Arms is barred right now: the setting is on and a match is locked. */
function bool IsRatBlocked()
{
	return bRatDisabled && IsLocked();
}

function SetRatDisabled(bool bDisable)
{
	bRatDisabled = bDisable;
	SaveSettings();
	Broadcast(bDisable ? "Man-at-Arms is disabled in ranked matches." : "Man-at-Arms is allowed in ranked matches again.");

	if (bDisable && IsLocked())
		ConvertRats();
}

/**
 * Every locked player set to spawn as Man-at-Arms becomes Knight with Longsword, unless they
 * have already picked a different class for their next spawn. Takes effect at their next
 * spawn; nobody is killed for it.
 */
function ConvertRats()
{
	local AOCPlayerController PC;
	local AOCPRI APRI;

	foreach WorldInfo.AllControllers(class'AOCPlayerController', PC)
	{
		APRI = AOCPRI(PC.PlayerReplicationInfo);
		if (APRI == none || PC.CurrentFamilyInfo == none || LockedTeamOf(SteamIdOf(APRI)) == 0)
			continue;
		if (PC.CurrentFamilyInfo.ClassReference != ECLASS_ManAtArms)
			continue;
		if (APRI.ToBeClass != ECLASS_MAX && APRI.ToBeClass != ECLASS_ManAtArms)
			continue;

		SwitchToKnightLongsword(PC);
	}
}

/** Next spawn: Knight, Longsword, and that weapon's default secondary/tertiary. */
function SwitchToKnightLongsword(AOCPlayerController PC)
{
	local AOCGRI GRI;
	local AOCFamilyInfo Knight;
	local class<AOCWeapon> Primary, Secondary, Tertiary;
	local int Index, i;

	GRI = AOCGRI(WorldInfo.GRI);
	if (GRI == none || PC.CurrentFamilyInfo == none)
		return;

	// FamilyInfos: EAOCClass order, 0-4 Agatha, 5-9 Mason.
	Index = ECLASS_Knight;
	if (PC.CurrentFamilyInfo.FamilyFaction == EFAC_MASON)
		Index += 5;
	Knight = GRI.FamilyInfos[Index];
	if (Knight == none)
		return;

	PC.SetNewClass(Knight, false, true);
	AOCPRI(PC.PlayerReplicationInfo).ClearNextClass();

	for (i = 0; i < Knight.NewPrimaryWeapons.Length; ++i)
	{
		Primary = Knight.NewPrimaryWeapons[i].CWeapon;
		if (Primary != class'MustModWeapon_Longsword')
			continue;

		if (Knight.NewPrimaryWeapons[i].CForceSecondary.Length > 0)
			Secondary = Knight.NewPrimaryWeapons[i].CForceSecondary[0];
		else
			Secondary = Knight.NewSecondaryWeapons[0].CWeapon;

		if (Knight.NewPrimaryWeapons[i].CForceTertiary.Length > 0)
			Tertiary = Knight.NewPrimaryWeapons[i].CForceTertiary[0];
		else
			Tertiary = Knight.NewTertiaryWeapons[0].CWeapon;

		PC.SetWeapons(Primary, Primary.default.AlternativeMode, Secondary, Tertiary);
		break;
	}

	TellPlayerPC(PC, "Man-at-Arms is disabled in this ranked match: you will spawn as Knight with Longsword.");
}

// ---- Joins and leaves ------------------------------------------------------------------

function PlayerJoined(Controller C)
{
	local AOCPlayerController PC;
	local string Id;
	local int i;

	// Only needs the backend configured, not ranked on: Elo tags show on every LTS map.
	PC = AOCPlayerController(C);
	if (!IsConfigured() || PC == none || PC.PlayerReplicationInfo == none || PC.PlayerReplicationInfo.bBot)
		return;

	Id = SteamIdOf(PC.PlayerReplicationInfo);
	if (Id == "")
		return;

	RememberOriginalName(Id, PC.PlayerReplicationInfo.PlayerName);
	Send("connect", "{" $ JsonField("steamId", Id) $ "," $ JsonField("name", GetOriginalName(PC)) $ "}");

	i = MissingIds.Find(Id);
	if (i == INDEX_NONE)
		return;

	Broadcast(MissingNames[i] @ "is back.");
	ReturnedIds.AddItem(Id);
	MissingIds.Remove(i, 1);
	MissingNames.Remove(i, 1);

	if (MissingIds.Length == 0 && RankedState == RS_Paused)
	{
		RankedState = RS_Locked;
		ResumeGame();
		Broadcast("Everyone is back -- resuming.");
	}
	else if (MissingIds.Length == 0 && bPauseAtRoundEnd)
	{
		// Back before the round they left in was decided: no pause needed.
		bPauseAtRoundEnd = false;
		Broadcast("Everyone is back -- no pause.");
	}
}

/** Called from MustModLTS.Logout before the controller goes away. */
function PlayerLeft(Controller C)
{
	local string Id;
	local int i;

	// RS_Closing too: someone quitting in the 3s before the result goes out keeps their stats.
	if ((!IsLocked() && RankedState != RS_Closing) || C == none || AOCPRI(C.PlayerReplicationInfo) == none)
		return;

	Id = SteamIdOf(C.PlayerReplicationInfo);
	if (LockedTeamOf(Id) == 0)
		return;

	i = SnapshotIds.Find(Id);
	if (i == INDEX_NONE)
	{
		i = SnapshotIds.Length;
		SnapshotIds.AddItem(Id);
		SnapshotStats.AddItem("");
	}
	SnapshotStats[i] = PlayerStatsJson(AOCPRI(C.PlayerReplicationInfo), Id);

	if (IsLocked())
		MarkMissing(Id, GetOriginalNameById(Id, C.PlayerReplicationInfo.PlayerName));
}

/**
 * A locked player is gone: add them to the running pause, or start one. Mid-round the pause
 * waits for that round to be decided (OnRoundEnded), so the round plays out and the pause
 * lands before the next one starts; between rounds it starts straight away.
 */
function MarkMissing(string Id, string PlayerName)
{
	if (MissingIds.Find(Id) != INDEX_NONE)
		return;

	MissingIds.AddItem(Id);
	MissingNames.AddItem(PlayerName);

	if (RankedState == RS_Paused)
	{
		Broadcast(PlayerName @ "also left.");
		return;
	}

	if (WorldInfo.Game != none && WorldInfo.Game.IsInState('AOCRoundInProgress'))
	{
		if (bPauseAtRoundEnd)
		{
			Broadcast(PlayerName @ "also left.");
		}
		else
		{
			bPauseAtRoundEnd = true;
			Broadcast(PlayerName @ "left the ranked match. The game pauses when this round ends, for up to" @ int(GetLeaverPauseSeconds()) $ "s.");
		}
		return;
	}

	StartLeaverPause(PlayerName);
}

/** From MustModLTS.AOCEndRound, right after the round is scored and before the next one. */
function OnRoundEnded()
{
	if (!bPauseAtRoundEnd)
		return;

	bPauseAtRoundEnd = false;
	if (RankedState == RS_Locked && MissingIds.Length > 0)
		StartLeaverPause(JoinNames(MissingNames), true);
}

function StartLeaverPause(string PlayerName, optional bool bAtRoundEnd)
{
	RankedState = RS_Paused;
	PauseDeadline = WorldInfo.RealTimeSeconds + GetLeaverPauseSeconds();
	NextPauseNotice = WorldInfo.RealTimeSeconds + 30.0;
	PauseGame();
	if (bAtRoundEnd)
		Broadcast("Round over. Paused for up to" @ int(GetLeaverPauseSeconds()) $ "s for" @ PlayerName @ "to reconnect.");
	else
		Broadcast(PlayerName @ "left the ranked match. Paused for up to" @ int(GetLeaverPauseSeconds()) $ "s.");
	Broadcast("Admins: 'admin RankedExtend <seconds>' to wait longer, 'admin RankedAbandon' to end it now (leavers lose Elo).");
}

// ---- Pause -----------------------------------------------------------------------------

/**
 * Same mechanics as MustModRCon.HandleSetPause, which has the reasoning: AOCGame inherits
 * bPauseable=false, so it is forced on around SetPause, and a connected controller has to
 * own the pause. AOCGame.SetPause announces "<owner> paused the game" with that borrowed
 * name; the leaver message right after it says what actually happened.
 */
function PauseGame()
{
	local AOCPlayerController PC, PauseOwner;
	local AOCGame Game;

	Game = AOCGame(WorldInfo.Game);
	if (Game == none || WorldInfo.Pauser != none)
		return;

	foreach WorldInfo.AllControllers(class'AOCPlayerController', PC)
	{
		PauseOwner = PC;
		break;
	}
	if (PauseOwner == none)
		return;

	if (!bPauseableForced)
	{
		bPauseableWas = Game.bPauseable;
		bPauseableForced = true;
	}
	Game.bPauseable = true;

	if (!Game.SetPause(PauseOwner))
		RestorePauseable();
}

function ResumeGame()
{
	if (WorldInfo.Game != none && WorldInfo.Pauser != none)
		WorldInfo.Game.ClearPause();

	RestorePauseable();
}

function RestorePauseable()
{
	if (bPauseableForced && WorldInfo.Game != none)
		WorldInfo.Game.bPauseable = bPauseableWas;

	bPauseableForced = false;
}

/** Admin: push the deadline back. Seconds <= 0 means another full LeaverPauseSeconds. */
function ExtendPause(int Seconds)
{
	if (RankedState != RS_Paused)
		return;

	if (Seconds <= 0)
		Seconds = int(GetLeaverPauseSeconds());

	PauseDeadline += Seconds;
	NextPauseNotice = WorldInfo.RealTimeSeconds;
	Broadcast("An admin extended the wait by" @ Seconds $ "s.");
}

// ---- Surrender vote --------------------------------------------------------------------

/**
 * From MustModGame.BroadcastMessage with the chat line lowercased and spaces stripped.
 * Returns true if it was a surrender command and must not be shown as chat. Outside a
 * ranked match, and for !yes/!no from anyone not in the running vote, it is plain chat.
 */
function bool HandleChatCommand(AOCPlayerController PC, string Command)
{
	local string Id;

	if (Command == "!ff")
	{
		if (!IsLocked())
			return false;

		StartSurrenderVote(PC);
		return true;
	}

	if ((Command == "!yes" || Command == "!no") && SurrenderVoteTeam != 0)
	{
		Id = SteamIdOf(PC.PlayerReplicationInfo);
		if (SurrenderVoters.Find(Id) == INDEX_NONE)
			return false;

		CastSurrenderVote(PC, Id, Command == "!yes");
		return true;
	}

	return false;
}

function StartSurrenderVote(AOCPlayerController PC)
{
	local array<string> Lineup;
	local string Id, Voter;
	local int Team, Played;

	Id = SteamIdOf(PC.PlayerReplicationInfo);
	Team = LockedTeamOf(Id);
	if (Team == 0)
	{
		TellPlayerPC(PC, "Only players in the match can start a surrender vote.");
		return;
	}
	if (SurrenderedTeam != 0)
	{
		TellPlayerPC(PC, TeamName(SurrenderedTeam) @ "already surrendered. The match ends after this round.");
		return;
	}
	if (SurrenderVoteTeam != 0)
	{
		TellPlayerPC(PC, "A surrender vote is already running.");
		return;
	}

	Played = AOCLTS(WorldInfo.Game) != none ? AOCLTS(WorldInfo.Game).RoundsPlayed : 0;
	if (Played < SURRENDER_MIN_ROUNDS)
	{
		TellPlayerPC(PC, "You can surrender after" @ SURRENDER_MIN_ROUNDS @ "rounds (" $ Played @ "played so far).");
		return;
	}
	if (WorldInfo.RealTimeSeconds < NextSurrenderVote[Team])
	{
		TellPlayerPC(PC, "Your team's last surrender vote failed. Try again in" @ int(NextSurrenderVote[Team] - WorldInfo.RealTimeSeconds + 0.5) $ "s.");
		return;
	}

	SurrenderVoteTeam = Team;
	SurrenderVoteDeadline = WorldInfo.RealTimeSeconds + SURRENDER_VOTE_SECONDS;
	SurrenderVoters.Length = 0;
	SurrenderYes.Length = 0;
	SurrenderNo.Length = 0;

	GetLineup(Team, Lineup);
	foreach Lineup(Voter)
	{
		if (FindPlayer(Voter) != none)
			SurrenderVoters.AddItem(Voter);
	}

	// Starting the vote is a yes.
	SurrenderYes.AddItem(Id);

	Broadcast(GetOriginalName(PC) @ "started a surrender vote for" @ TeamName(Team) $ ".");
	TellTeam(Team, "Surrender? Type !yes or !no in chat (" $ int(SURRENDER_VOTE_SECONDS) $ "s). Needs more than" @ SURRENDER_PASS_PERCENT $ "% yes; not voting counts as no.");
	CheckSurrenderVote();
}

function CastSurrenderVote(AOCPlayerController PC, string Id, bool bYes)
{
	SurrenderYes.RemoveItem(Id);
	SurrenderNo.RemoveItem(Id);
	if (bYes)
		SurrenderYes.AddItem(Id);
	else
		SurrenderNo.AddItem(Id);

	TellTeam(SurrenderVoteTeam, GetOriginalName(PC) @ "voted" @ (bYes ? "yes" : "no") @ "(" $ SurrenderYes.Length @ "yes," @ SurrenderNo.Length @ "no, of" @ SurrenderVoters.Length $ ").");
	CheckSurrenderVote();
}

/** Ends the vote once everyone has voted or time is up. */
function CheckSurrenderVote()
{
	local int Total;

	if (SurrenderVoteTeam == 0)
		return;

	Total = SurrenderVoters.Length;
	if (SurrenderYes.Length + SurrenderNo.Length < Total && WorldInfo.RealTimeSeconds < SurrenderVoteDeadline)
		return;

	// In whole numbers, so exactly 60% (3 of 5) does not pass.
	EndSurrenderVote(Total > 0 && SurrenderYes.Length * 100 > Total * SURRENDER_PASS_PERCENT);
}

function EndSurrenderVote(bool bPassed)
{
	local MustModLTS Game;
	local int Team;

	Team = SurrenderVoteTeam;
	SurrenderVoteTeam = 0;

	Broadcast(TeamName(Team) @ "surrender vote:" @ SurrenderYes.Length @ "yes," @ (SurrenderVoters.Length - SurrenderYes.Length) @ "no.");

	if (!bPassed)
	{
		NextSurrenderVote[Team] = WorldInfo.RealTimeSeconds + SURRENDER_RETRY_SECONDS;
		Broadcast("The vote failed. The match goes on.");
		return;
	}

	SurrenderedTeam = Team;
	Game = MustModLTS(WorldInfo.Game);

	// Mid-round: MustModLTS.AOCEndRound ends the match when this round is over. Between
	// rounds there is nothing left to play out, so it ends now.
	if (Game != none && !Game.IsInState('AOCRoundInProgress'))
	{
		Broadcast(TeamName(Team) @ "surrendered.");
		Game.EndSurrenderedMatch();
	}
	else
	{
		Broadcast(TeamName(Team) @ "surrendered. The match ends when this round is over.");
	}
}

/** Copy of the locked lineup for team 1 or 2. */
function GetLineup(int Team, out array<string> Ids)
{
	if (Team == 1)
		Ids = Team1Ids;
	else
		Ids = Team2Ids;
}

function string TeamName(int Team)
{
	return Team == 1 ? "Agatha" : "Mason";
}

/** Chat line for the connected players of one locked team. */
function TellTeam(int Team, string Message)
{
	local array<string> Lineup;
	local string Id;

	GetLineup(Team, Lineup);
	foreach Lineup(Id)
		TellPlayer(Id, Message);
}

// ---- Ending a match --------------------------------------------------------------------

/** Leavers lose Elo, everyone else's result is void, then the map restarts. */
function AbandonMatch()
{
	if (!IsLocked())
		return;

	RankedState = RS_Closing;
	ResumeGame();
	Send("abandon", "{" $ JsonField("matchId", MatchId) $ "," $
		Quote("leavers") $ ":" $ JsonStringArray(MissingIds) $ "," $
		Quote("players") $ ":[" $ CollectPlayerStats() $ "]}");

	// Restart even if the backend never answers; the request gets a head start first.
	SetTimer(10.0, false, 'RestartMap');
}

/** Void the match for everyone, nobody's Elo changes (adminterminatematch, RankedMode 0). */
function CancelMatch()
{
	if (!IsLocked())
		return;

	RankedState = RS_Closing;
	ResumeGame();
	Send("cancel", "{" $ JsonField("matchId", MatchId) $ "}");
	Broadcast("The ranked match was terminated. No Elo changes. Restarting the map.");
	SetTimer(5.0, false, 'RestartMap');
}

function RestartMap()
{
	WorldInfo.ServerTravel("?restart", false);
}

/**
 * From MustModLTS.EndGame. The delay lets the last kill's stats land first. The map
 * restarts 10s after the Elo changes are announced (see RequestComplete); the 20s timer is
 * the fallback if the backend never answers. Either way it beats AOCGame's own end-of-game
 * travel, which waits 25s before even entering MatchOver.
 */
function MatchEnded()
{
	if (!IsLocked())
		return;

	RankedState = RS_Closing;
	SetTimer(3.0, false, 'SubmitResult');
	SetTimer(20.0, false, 'RestartMap');
}

function SubmitResult()
{
	local int Winner;

	switch (AOCGame(WorldInfo.Game).GetWinningTeam())
	{
		case EFAC_AGATHA: Winner = 1; break;
		case EFAC_MASON:  Winner = 2; break;
		default:          Winner = 0;
	}

	// Anyone still missing here was unpaused past by an admin; they count as leavers.
	// After a surrender, GetWinningTeam already names the other team.
	Send("result", "{" $
		JsonField("matchId", MatchId) $ "," $
		Quote("winner") $ ":" $ Winner $ "," $
		Quote("surrender") $ ":" $ SurrenderedTeam $ "," $
		Quote("team1Score") $ ":" $ int(AOCGRI(WorldInfo.GRI).GetTeamScore(EFAC_AGATHA)) $ "," $
		Quote("team2Score") $ ":" $ int(AOCGRI(WorldInfo.GRI).GetTeamScore(EFAC_MASON)) $ "," $
		Quote("leavers") $ ":" $ JsonStringArray(MissingIds) $ "," $
		Quote("players") $ ":[" $ CollectPlayerStats() $ "]}");
}

/** {"steamId":..,"score":..,...} for one lineup player. */
function string PlayerStatsJson(AOCPRI PRI, string Id)
{
	return "{" $ JsonField("steamId", Id) $ "," $
		Quote("score") $ ":" $ int(PRI.Score) $ "," $
		Quote("kills") $ ":" $ PRI.NumKills $ "," $
		Quote("deaths") $ ":" $ PRI.Deaths $ "," $
		Quote("assists") $ ":" $ PRI.NumAssists $ "," $
		Quote("enemyDamage") $ ":" $ PRI.EnemyDamageDealt $ "}";
}

/**
 * Stats for the whole lineup: live for everyone connected, the disconnect snapshot for
 * everyone else. Comma-separated JSON objects, ready to go inside [ ].
 */
function string CollectPlayerStats()
{
	local AOCPlayerController PC;
	local AOCPRI PRI;
	local array<string> Seen;
	local string Result, Id;
	local int i;

	foreach WorldInfo.AllControllers(class'AOCPlayerController', PC)
	{
		PRI = AOCPRI(PC.PlayerReplicationInfo);
		if (PRI == none)
			continue;

		Id = SteamIdOf(PRI);
		if (LockedTeamOf(Id) == 0 || Seen.Find(Id) != INDEX_NONE)
			continue;

		Seen.AddItem(Id);
		Result $= (Result != "" ? "," : "") $ PlayerStatsJson(PRI, Id);
	}

	for (i = 0; i < SnapshotIds.Length; i++)
	{
		if (Seen.Find(SnapshotIds[i]) == INDEX_NONE)
			Result $= (Result != "" ? "," : "") $ SnapshotStats[i];
	}

	return Result;
}

/** Shared by result and abandon: announce each player's Elo change. */
function HandleEloChanges(JsonObject Data)
{
	local JsonObject Changes, Change;
	local int Before, After;

	if (Data == none || !Data.GetBoolValue("ok"))
		return;

	Changes = Data.GetObject("changes");
	if (Changes == none)
		return;

	foreach Changes.ObjectArray(Change)
	{
		Before = Change.GetIntValue("before");
		After = Change.GetIntValue("after");
		if (Before == After)
			continue;

		Broadcast((After > Before ? "+" : "") $ (After - Before) @ Change.GetStringValue("name") @ "(" $ After $ ")");
		ShowElo(Change.GetStringValue("steamId"), After);
	}
}

// ---- Names -----------------------------------------------------------------------------

function RememberOriginalName(string SteamId, string PlayerName)
{
	if (OriginalNameIds.Find(SteamId) != INDEX_NONE)
		return;

	OriginalNameIds.AddItem(SteamId);
	OriginalNames.AddItem(StripEloTag(PlayerName));
}

/**
 * "[2516] Name" -> "Name". Names survive map changes (PRI.CopyProperties copies PlayerName),
 * so a tag from the last ranked map is still on the name when this map reads it; without
 * this it would stack ("[2516] [2500] Name") and end up in the database. Only an all-digit
 * tag is removed, so clan tags like "[ABC] Name" are left alone.
 */
static function string StripEloTag(string PlayerName)
{
	local int Close, i;
	local string C;

	if (Left(PlayerName, 1) != "[")
		return PlayerName;

	Close = InStr(PlayerName, "] ");
	if (Close < 2)
		return PlayerName;

	for (i = 1; i < Close; i++)
	{
		C = Mid(PlayerName, i, 1);
		if (C < "0" || C > "9")
			return PlayerName;
	}

	return Mid(PlayerName, Close + 2);
}

function string GetOriginalName(AOCPlayerController PC)
{
	return GetOriginalNameById(SteamIdOf(PC.PlayerReplicationInfo), PC.PlayerReplicationInfo.PlayerName);
}

function string GetOriginalNameById(string SteamId, string Fallback)
{
	local int i;

	i = OriginalNameIds.Find(SteamId);
	return i == INDEX_NONE ? StripEloTag(Fallback) : OriginalNames[i];
}

/** Rename to "[elo] name", like ImbaMod. Always built from the original name. */
function ShowElo(string SteamId, int Elo)
{
	local AOCPlayerController PC;

	PC = FindPlayer(SteamId);
	if (PC == none)
		return;

	RememberOriginalName(SteamId, PC.PlayerReplicationInfo.PlayerName);
	WorldInfo.Game.ChangeName(PC, "[" $ Elo $ "]" @ GetOriginalName(PC), false);
}

// ---- HTTP ------------------------------------------------------------------------------

/**
 * Fire one request. Returns false if it never left the server; failures after that arrive
 * in RequestComplete.
 */
function bool Send(string Action, string JsonBody)
{
	local HttpRequestInterface Request;

	if (!IsConfigured())
	{
		if (!bLoggedNotConfigured)
		{
			LogAlwaysInternal("[MustModRanked] not configured -- see [MustMod.MustModRanked] in UDKGame.ini");
			bLoggedNotConfigured = true;
		}
		return false;
	}

	Request = class'HttpFactory'.static.CreateRequest();
	if (Request == none)
	{
		LogAlwaysInternal("[MustModRanked] HttpFactory returned no request object; check HttpRequestClassName in UDKEngine.ini");
		return false;
	}

	Request.SetURL(RankedEndpoint $ "/" $ Action);
	Request.SetVerb("POST");
	Request.SetHeader("Content-Type", "application/json");
	Request.SetHeader("x-server-token", RankedServerToken);
	Request.SetContentAsString(JsonBody);
	Request.SetProcessRequestCompleteDelegate(RequestComplete);

	PendingRequests.AddItem(Request);
	PendingActions.AddItem(Action);

	if (!Request.ProcessRequest())
	{
		LogAlwaysInternal("[MustModRanked]" @ Action @ "could not be started");
		ForgetRequest(Request);
		return false;
	}

	return true;
}

function RequestComplete(HttpRequestInterface Request, HttpResponseInterface Response, bool bDidSucceed)
{
	local string Action, Body;
	local int Code;
	local JsonObject Data;

	Action = ForgetRequest(Request);

	// bDidSucceed is transport-level only: DNS, connect, TLS. A 401 or 500 still counts as
	// success here, so the status code has to be checked separately.
	if (!bDidSucceed || Response == none)
	{
		LogAlwaysInternal("[MustModRanked]" @ Action @ "failed in transport (DNS, connection or TLS)");
	}
	else
	{
		Code = Response.GetResponseCode();
		Body = Response.GetContentAsString();
		LogAlwaysInternal("[MustModRanked]" @ Action @ "->" @ Code @ "|" @ Left(Body, 300));
		if (Code >= 200 && Code < 300)
			Data = class'JsonObject'.static.DecodeJson(Body);
	}

	switch (Action)
	{
		case "matchmake":
			if (Data == none)
			{
				RankedState = RS_Queue;
				QueueStartTime = 0;
				Broadcast("Ranked: the ranked service did not answer. Trying again shortly.");
			}
			else
				HandleMatchmake(Data);
			break;

		case "connect":
			if (Data != none && Data.GetBoolValue("ok"))
				ShowElo(Data.GetStringValue("steamId"), Data.GetIntValue("elo"));
			break;

		case "result":
			// 409 = the backend already has this result, so a retry would be pointless.
			if (Data == none && !bResultRetried && Code != 409)
			{
				bResultRetried = true;
				SetTimer(5.0, false, 'SubmitResult');
				SetTimer(20.0, false, 'RestartMap');   // fresh fallback for the retry
				break;
			}

			if (Data == none && Code != 409)
				Broadcast("Ranked: could not record the match result.");
			else
				HandleEloChanges(Data);

			Broadcast("Restarting the map in 10s.");
			SetTimer(10.0, false, 'RestartMap');
			break;

		case "abandon":
			HandleEloChanges(Data);
			break;
	}
}

/** Drop a finished request from the pending lists and return the action it was for. */
function string ForgetRequest(HttpRequestInterface Request)
{
	local int i;
	local string Action;

	i = PendingRequests.Find(Request);
	if (i == INDEX_NONE)
		return "?";

	Action = PendingActions[i];
	PendingRequests.Remove(i, 1);
	PendingActions.Remove(i, 1);
	return Action;
}

/** Connectivity check: proves DNS, TLS, the token and the function are all working. */
function Ping()
{
	Send("ping", "{" $ JsonField("map", WorldInfo.GetMapName()) $ "}");
}

// ---- Helpers ---------------------------------------------------------------------------

function string SteamIdOf(PlayerReplicationInfo PRI)
{
	local OnlineSubsystemSteamworks Steam;

	if (PRI == none || WorldInfo.Game == none)
		return "";

	Steam = OnlineSubsystemSteamworks(WorldInfo.Game.OnlineSub);
	if (Steam == none)
		return "";

	return Steam.UniqueNetIdToInt64(PRI.UniqueId);
}

function AOCPlayerController FindPlayer(string SteamId)
{
	local AOCPlayerController PC;

	foreach WorldInfo.AllControllers(class'AOCPlayerController', PC)
	{
		if (SteamIdOf(PC.PlayerReplicationInfo) == SteamId)
			return PC;
	}
	return none;
}

function Broadcast(string Message)
{
	local AOCPlayerController PC;

	foreach WorldInfo.AllControllers(class'AOCPlayerController', PC)
		PC.ReceiveChatMessage(Message, EFAC_ALL, false, true, CHAT_COLOUR, false);
}

function TellPlayer(string SteamId, string Message)
{
	local AOCPlayerController PC;

	TellPlayerPC(FindPlayer(SteamId), Message);
}

/** Chat line only this player sees (sent to them alone, not flagged private). */
function TellPlayerPC(AOCPlayerController PC, string Message)
{
	if (PC != none)
		PC.ReceiveChatMessage(Message, EFAC_ALL, false, true, CHAT_COLOUR, false);
}

function string JoinNames(array<string> Names)
{
	local string Result;
	local int i;

	for (i = 0; i < Names.Length; i++)
		Result $= (i > 0 ? ", " : "") $ Names[i];
	return Result;
}

function string Quote(string S)
{
	return Chr(34) $ S $ Chr(34);
}

/** "key":"value", with the value escaped -- player names can contain quotes and backslashes. */
function string JsonField(string Key, string Value)
{
	Value = Repl(Value, "\\", "\\\\");
	Value = Repl(Value, Chr(34), "\\" $ Chr(34));
	return Quote(Key) $ ":" $ Quote(Value);
}

/** SteamIDs only, so no escaping needed. */
function string JsonStringArray(array<string> Values)
{
	local string Result;
	local int i;

	for (i = 0; i < Values.Length; i++)
		Result $= (i > 0 ? "," : "") $ Quote(Values[i]);
	return "[" $ Result $ "]";
}

DefaultProperties
{
	bAlwaysTick=true
}
