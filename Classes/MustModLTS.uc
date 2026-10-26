class MustModLTS extends AOCLTS;

`include(MustMod/Include/MustModLTS.uci)
`include(MustMod/Include/MustModGame.uci)


event PostBeginPlay()
{
	super.PostBeginPlay();

	Ranked = Spawn(class'MustModRanked');
	Ranked.Ping();
}

// ---- MUSTMOD: ranked hooks (MustModRanked has the flow) ----------------------------------

function Logout(Controller Exiting)
{
	// Before super: the controller's PRI is still intact here.
	if (Ranked != none)
	{
		Ranked.PlayerLeft(Exiting);
	}

	super.Logout(Exiting);
}

function bool RequestJoinTeam(AOCPlayerController inController, EAOCFaction inTeam, optional bool bForce = false)
{
	if (Ranked != none && !Ranked.MayJoinTeam(inController, inTeam))
	{
		if (!bForce)
		{
			inController.Response_JoinTeam(inTeam, false);
		}
		return false;
	}

	return super.RequestJoinTeam(inController, inTeam, bForce);
}

function RequestJoinClass(AOCPlayerController inController, EAOCFaction inTeam, byte inClass, optional bool bForce = false, optional bool bSetClass = false)
{
	if (Ranked != none && !Ranked.MayJoinTeam(inController, inTeam))
	{
		if (!bForce)
		{
			inController.Response_JoinClass(inClass, false);
		}
		return;
	}

	// Ranked with Man-at-Arms disabled (admindisablerat 1). inClass is an EAOCClass, plus 4 =
	// random. Picking it in the menu is refused; the confirm that follows the loadout screen
	// (bForce) is turned into Knight with Longsword; random never rolls it.
	if (Ranked != none && Ranked.IsRatBlocked())
	{
		if (inClass == 4)
		{
			inClass = Rand(3);              // 0 Archer, 1 -> Vanguard, 2 -> Knight
			if (inClass > 0)
			{
				inClass += 1;
			}
		}
		else if (inClass == ECLASS_ManAtArms)
		{
			if (!bForce)
			{
				inController.Response_JoinClass(inClass, false);
				Ranked.TellPlayerPC(inController, "Man-at-Arms is disabled in this ranked match.");
			}
			else
			{
				Ranked.SwitchToKnightLongsword(inController);
			}
			return;
		}
	}

	super.RequestJoinClass(inController, inTeam, inClass, bForce, bSetClass);
}

function EndGame(PlayerReplicationInfo Winner, string Reason)
{
	super.EndGame(Winner, Reason);

	if (Ranked != none)
	{
		Ranked.MatchEnded();
	}
}

/**
 * A round has just been decided and scored.
 * - A ranked surrender passed in it: if it did not already end the match, end it now. The
 *   next round cannot start in the meantime: MatchEnded puts ranked in RS_Closing, which
 *   holds the pre-round countdown until the map restarts.
 * - A locked player left during it: Ranked.OnRoundEnded starts the leaver pause now, before
 *   the next round, so the leaver's team never plays a round short. A no-op once the match
 *   is over.
 */
function AOCEndRound()
{
	super.AOCEndRound();

	if (!bGameEnded && Ranked != none && Ranked.SurrenderedTeam != 0)
	{
		EndSurrenderedMatch();
	}

	if (Ranked != none)
	{
		Ranked.OnRoundEnded();
	}
}

function EndSurrenderedMatch()
{
	// Teams[0] = Agatha (ranked team 1), Teams[1] = Mason.
	MatchWinner = Teams[Ranked.SurrenderedTeam == 1 ? 1 : 0];
	EndGame(GetFirstPRIFromTeam(MatchWinner), "Surrender");
}

/** After a surrender the other team wins, even if the surrendering one was ahead on rounds. */
function EAOCFaction GetWinningTeam()
{
	if (Ranked != none && Ranked.SurrenderedTeam != 0)
	{
		return Ranked.SurrenderedTeam == 1 ? EFAC_MASON : EFAC_AGATHA;
	}

	return super.GetWinningTeam();
}

/** Admin: "admin RankedMode 1|0". */
exec function RankedMode(bool bEnable)
{
	SetRankedMode(bEnable);
}

/**
 * Turn ranked on or off and save it to UDKGame.ini, so it stays that way across maps until
 * changed again. Restarts the map either way: turning on starts the queue from a clean
 * pre-round, turning off voids a live ranked match first (no Elo changes).
 */
function SetRankedMode(bool bEnable)
{
	if (Ranked == none || Ranked.bRankedEnabled == bEnable)
	{
		return;
	}

	Ranked.bRankedEnabled = bEnable;
	Ranked.SaveSettings();
	Ranked.Broadcast(bEnable ? "Ranked mode is ON. Restarting the map -- pick a team and class to queue." : "Ranked mode is OFF. Restarting the map.");

	if (Ranked.IsLocked())
	{
		Ranked.CancelMatch();
	}
	else
	{
		WorldInfo.ServerTravel("?restart", false);
	}
}

/**
 * MUSTMOD: "voteranked" / "voteunranked". Rides on the restart-map vote: same HUD, same
 * tally, same DidVoteSucceed rules as every other vote; only the text is overridden
 * (ImbaMod's trick). MustModGame.UpdateVoteTally already falls back to the EndCustomVote
 * timer for this.
 */
function InitiateVoteRanked(AOCPlayerController VoteInstigator, bool bEnable)
{
	local AOCPlayerController PC;
	local int FailReasonPMCode;

	if (Ranked == none || !Ranked.IsConfigured())
	{
		VoteInstigator.ClientDisplayConsoleMessage("Ranked is not set up on this server.");
		return;
	}

	if (Ranked.bRankedEnabled == bEnable)
	{
		Ranked.TellPlayerPC(VoteInstigator, bEnable ? "Ranked mode is already on." : "Ranked mode is already off.");
		return;
	}

	// Voting it off mid-match would let a losing side void its own loss.
	if (!bEnable && Ranked.IsLocked())
	{
		Ranked.TellPlayerPC(VoteInstigator, "Ranked can only be voted off between matches. An admin can use adminterminatematch.");
		return;
	}

	if (!IsAllowedToInitiateVote(VoteInstigator, FailReasonPMCode))
	{
		LocalizedPrivateMessage(VoteInstigator, FailReasonPMCode);
		return;
	}

	Ranked.bVoteToEnable = bEnable;
	VoteCategory = EVOTECAT_RestartMap;
	fTimeVoteStarted = WorldInfo.TimeSeconds;
	SetTimer(fVoteDurationSeconds, false, 'EndCustomVote');

	foreach WorldInfo.AllControllers(class'AOCPlayerController', PC)
	{
		PC.BeginVote(EVOTECAT_RestartMap, "", fVoteDurationSeconds);
		if (MustModLTSPlayerController(PC) != none)
		{
			MustModLTSPlayerController(PC).OverrideVoteText(bEnable ? "Enable?" : "Disable?", "Ranked mode");
		}
	}

	AOCGRI(GameReplicationInfo).VotesNo = 0;
	AOCGRI(GameReplicationInfo).VotesYes = 0;

	InitiateNewVote(VoteInstigator);
	VoteInstigator.Vote = EVOTE_Yes;
	SetTimer(0.5f, true, 'CountVotes');

	Ranked.Broadcast(VoteInstigator.PlayerReplicationInfo.PlayerName @ "started a vote to turn ranked mode" @ (bEnable ? "on." : "off."));
}

function EndCustomVote()
{
	local AOCPlayerController PC;
	local bool bSuccess;

	ClearTimer('CountVotes');
	bSuccess = DidVoteSucceed();
	EndVoting();

	foreach WorldInfo.AllControllers(class'AOCPlayerController', PC)
	{
		PC.FinishVote(bSuccess, fVoteEnactDelaySeconds);
	}

	if (bSuccess)
	{
		SetTimer(fVoteEnactDelaySeconds, false, 'EnactRankedVote');
	}
}

function EnactRankedVote()
{
	// Re-checked: a match may have been locked in while the vote was running.
	if (!Ranked.bVoteToEnable && Ranked.IsLocked())
	{
		Ranked.Broadcast("A ranked match started during the vote, so ranked stays on. Vote again after it.");
		return;
	}

	SetRankedMode(Ranked.bVoteToEnable);
}

/** AOCGame.CancelVote only knows the vanilla vote timers; AdminCancelVote must stop ours too. */
function CancelVote()
{
	ClearTimer('EndCustomVote');
	super.CancelVote();
}

/**
 * True (and the player told why) if a ranked match is live. Restarting or changing the map
 * then would void the match or lose its result; adminterminatematch is the way out.
 */
function bool RankedBlocksMapChange(PlayerController PC)
{
	if (Ranked == none || !Ranked.IsMatchLive())
	{
		return false;
	}

	if (AOCPlayerController(PC) != none)
	{
		Ranked.TellPlayerPC(AOCPlayerController(PC), "Not during a ranked match. The map restarts by itself when it ends (admins: adminterminatematch).");
	}
	return true;
}

function InitiateVoteRestartMap(AOCPlayerController VoteInstigator)
{
	if (!RankedBlocksMapChange(VoteInstigator))
	{
		super.InitiateVoteRestartMap(VoteInstigator);
	}
}

function InitiateVoteChangeMap(AOCPlayerController VoteInstigator, string MapName)
{
	if (!RankedBlocksMapChange(VoteInstigator))
	{
		super.InitiateVoteChangeMap(VoteInstigator, MapName);
	}
}

/** "adminstartmatch": start now with any even queue. Returns why not, or "". */
function string AdminStartRankedMatch()
{
	if (Ranked == none)
	{
		return "Ranked mode is only available on LTS maps.";
	}
	return Ranked.AdminStartMatch();
}

/** "adminterminatematch": void the live ranked match for everyone. No Elo changes. */
/** Admin: "admindisablerat 1|0". False when there is no ranked actor (not an LTS map). */
function bool SetRatDisabled(bool bDisable)
{
	if (Ranked == none)
	{
		return false;
	}

	Ranked.SetRatDisabled(bDisable);
	return true;
}

function bool TerminateRankedMatch()
{
	if (Ranked == none || !Ranked.IsLocked())
	{
		return false;
	}

	Ranked.CancelMatch();
	return true;
}

/** Admin: smallest ranked match, players per side (1 = 1v1 allowed). */
exec function RankedMinTeamSize(int Size)
{
	if (Ranked == none || Size < 1 || Size > 16)
	{
		return;
	}

	Ranked.RankedMinTeamSize = Size;
	Ranked.SaveSettings();
	Ranked.Broadcast("Admin RankedMinTeamSize" @ Size);
}

/** Admin: biggest ranked match, players per side; extra queued players wait for the next. */
exec function RankedMaxTeamSize(int Size)
{
	if (Ranked == none || Size < 1 || Size > 16)
	{
		return;
	}

	Ranked.RankedMaxTeamSize = Size;
	Ranked.SaveSettings();
	Ranked.Broadcast("Admin RankedMaxTeamSize" @ Size);
}

/** Admin: wait longer for a leaver. No argument = another full LeaverPauseSeconds. */
exec function RankedExtend(optional int Seconds)
{
	if (Ranked != none)
	{
		Ranked.ExtendPause(Seconds);
	}
}

/** Admin: end a paused match now. Leavers lose Elo, nobody else's changes. */
exec function RankedAbandon()
{
	if (Ranked != none && Ranked.IsPaused())
	{
		Ranked.Broadcast("An admin ended the match.");
		Ranked.AbandonMatch();
	}
}

/** Admin/RCON connectivity check for the ranked backend; the result lands in the server log. */
exec function RankedPing()
{
	if (Ranked != none)
	{
		Ranked.Ping();
	}
}
