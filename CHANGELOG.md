## Miss mechanic removed (2026-10-26)

The near-miss / hitstop parry recovery cut (the 2026-10-16 "Miss mechanic" entry) is gone,
with its `missdebug` console toggle. Removed from `MustModMeleeWeapon.uc`: its tuning vars and
defaults, the target search and blade tracking (`FindMissTarget`, `UpdateMissTracking` and
helpers), the server report and recovery cut (`ServerReportMiss`, `ProcessMissReport`,
`NotifyMissedBy`, `ApplyMissRecovery`, `CutMissRecovery`) and their hooks in Release, Parry
and Recovery. `MissDebug` removed from `MustModPlayerController.uci`. Parry recovery is the
weapon's own again in every case.

Unchanged: the miss stamina costs (15/25), the two-miss lockout and the exhausted-miss
recovery penalty, which are separate features.

NOT YET COMPILED.

## Halberd knockback, 3s stamina regen delay, admin coinflip (2026-10-19)

**Halberd knockback** (`MustModWeaponAttachment_Halberd.uc`): now matches the Zweihander.
Slash 24000 -> 27200, overhead 24000 -> 26800, stab 0 -> 28000. Special, alt and kick
were already the same.

**Stamina regen delay** (`MustModPawn.uci` `ConsumeStamina` override): regen restarts 3.0s
after spending stamina instead of 1.5s. Running dry already waited 3.0s, so both are now 3s.

**coinflip** (`MustModPlayerController.uci`): `admin coinflip` (also `coinflip` or
`AdminCoinFlip` as a logged-in admin) flips heads or tails on the server and announces it in
chat to everyone. The old `AdminCoinFlip` flipped on the admin's own client and looped over
controllers there, so only the admin saw the result.

## Overadmin, setname for everyone, map auto-restart, Bangsword removed, Longsword overhead 92 (2026-10-19)

**Overadmin** (`MustModOverAdmin.uc`, `MustModPlayerController.uci`): a rank above admin.
The password goes in the server's `UDKGame.ini`, never in `DefaultMustMod.ini`:

```
[MustMod.MustModOverAdmin]
OverAdminPassword=<secret>
```

Empty (the default) disables it. `OverAdminLogin <password>` makes the player an admin
(announced like AdminLogin) and an overadmin. A connection gets 5 wrong passwords, then
further attempts are ignored until it reconnects. `AdminLogout` ends overadmin too.

**Bots and game speed are overadmin-only.** `addbots`, `addbluebots`, `addredbots` and
`adddummies` are shadowed by exec functions on the controller, which is searched before
the game when an admin runs `admin addbots 4`, so plain admins are refused there.
`aoc_slomo` (`s_aoc_slomo` override) and `slomo` need overadmin too. Server-side bot
filling (`?NumBots=`, FFA fill) and RCON `SET_GAME_SPEED` are unchanged.

**Unpause**: an overadmin can unpause a game another admin (or RCON) paused. It clears the
pausing admin's `bIsPaused` and runs the normal 3-2-1 countdown. A ranked leaver pause is
excluded (`MustModRanked.IsLeaverPaused`): use `admin RankedAbandon` or wait for its timer.
A plain admin who did not pause now gets "Only the admin who paused the game, or an
overadmin, can unpause it" instead of "not paused".

**setname** (`ServerChangeName` override): open to everyone. Non-admins cannot take a name
another player has and can rename once per 5 seconds. A typed `[1234]` Elo tag is stripped,
and a real ranked tag is kept across the rename. Ranked still reports the name the player
had when ranked first saw them.

**Map auto-restart** (`MustModGame.uci` `GetNextMap`): when a map ends it plays again instead
of moving on in the map rotation, after the same end-of-map wait (`MatchOver` ->
`RestartGame`). Admin map changes and map votes are unaffected.

**Bangsword removed**: `MustModWeapon_Bangsword.uc`, `MustModWeaponAttachment_Bangsword.uc`
and `MustModDmgType_BangswordSpecial.uc` deleted, with its Knight loadout slot, its R-key
special (`Reload`), its stamina exemptions and hit rewrite in `MustModPawn.uci`, and its
localization.

**Longsword**: 2H overhead 90 -> 92 base damage. `damage_graph.html` regenerated.

## Ranked: no joining from spectator, admindisablerat (2026-10-16)

**Spectators** (`MustModRanked.MayJoinTeam`): during a locked match a player in spectator
(or on no side) cannot join a team, even one in the lineup. The exception is a locked player
who left and reconnected (`ReturnedIds`, filled in `PlayerJoined`, cleared when a match
locks). Players already on their side can still change class. Outsiders were already kept
out by the lineup lock.

**admindisablerat 1|0** (console, admin; `MustModPlayerController.uci`, `MustModLTS.uc`,
`MustModRanked.uc`): saved as `bRatDisabled` in `[MustMod.MustModRanked]`. While on and a
match is locked, Man-at-Arms cannot be picked: the class menu refuses it with a chat line,
the loadout confirm turns it into Knight with Longsword, and "random" never rolls it.
Turning it on mid-match, or a match locking with it on, moves every lineup player set to
spawn as Man-at-Arms to Knight with Longsword (default secondary/tertiary for it) from their
next spawn, unless they already picked another class. Nobody is killed for it. Listed in
the admin part of `!rankedhelp`.

## Poleaxe alt mode removed, ranked leaver pause waits for the round to end (2026-10-16)

**Poleaxe** (`MustModWeapon_PoleAxe.uc`, `MustModPawn.uci`): the back-of-the-head hammer mode
(key 1) is gone. `MustModWeapon_PoleAxeBack.uc` and `MustModWeaponAttachment_PoleAxeBack.uc`
are deleted, the Poleaxe's `AlternativeMode` is `none`, and the PaxeBack mesh fix in
`WeaponAttachmentChanged` is removed. Nothing references `SlumpWep_PaxeBack` any more, so
the cooker stops shipping that package. `damage_graph.html` regenerated.

**Ranked leaver pause** (`MustModRanked.uc`, `MustModLTS.uc`): a locked player leaving
mid-round no longer pauses on the spot. The round plays out, and the pause starts the moment
it is decided (`AOCEndRound`: a team wiped out or time up), after it is scored and before the
next round's countdown, so the leaver's team never starts a round short. Leaving between
rounds still pauses at once. If everyone missing is back before the round ends there is no
pause at all. The full `LeaverPauseSeconds` runs from when the pause starts. If that round
ends the match, there is no pause and anyone still missing counts as a leaver, as before.

## !td team damage list, missdebug console toggle (2026-10-16)

**!td** (`MustModGame.uci`): typing `!td` in chat shows every player's team damage this map
to everyone, highest first, one line each (spectators left out). It reads the same
whole-map `MapTeamDamageDealt` total as the 5-minute top-3 callout. Server-wide cooldown of
60s; inside it only the sender is told how many seconds are left. The typed line itself is
never shown.

**missdebug** (`MustModPlayerController.uci`, `MustModMeleeWeapon.uc`): the miss mechanic's
debug chat line is now a client console toggle, `missdebug`, instead of a DefaultProperties
setting. It is per player and lasts the session (stored on the `MustModMeleeWeapon` class
default, so respawns and weapon swaps keep it). The server sends the reason with the
recovery cut and the defender's own game prints it only if the cut actually applied there.

## Miss mechanic: parrying a near miss cuts your parry recovery (2026-10-16)

**What** (`MustModMeleeWeapon.uc`), modelled on Mordhau's "Miss Mechanic+" mod: when an enemy
swing aimed at you misses while your parry overlapped it, and your parry blocked nothing,
the rest of your parry recovery is skipped so you can parry a second attacker's follow-up
(the 2v1 bait whiff). Shields and kicks are excluded.

**Rules**: at release start the attacker's machine notes the target, the enemy closest to
their aim inside a 35 deg cone within blade length + 200. A swing qualifies as either:
- *near miss*: while the attacker was looking at the target (35 deg), the blade (hilt,
  middle or tip) passed within 80 units of the target's body centre line;
- *hitstop*: the swing clanged off a wall or the floor with the attacker within 250 units
  of the target, and the target's parry started at most 0.6s before the clang reached the
  server.

It never qualifies if the aim moves more than 60 deg off the target (a switch) or if the
swing touches any player (hit, parry or block, the target or anyone else). It is only
reported once the swing has ended, so a drag that lands still lands. For a near miss the
server requires the target's parry to have started no earlier than 0.5s before the release
began. The cut is applied on the server and the defender's client; a miss that lands while
the parry is still up is held for 0.6s and applied when the parry recovery begins.

**Tuning** (DefaultProperties): `fMissRecoveryCut` (1.0 = skip, 0.5 = halve what is left),
`fMissTargetConeAngle`, `fMissSwitchAngle`, `fMissSearchRadius`, `fMaxMissDistance`,
`bMissIncludeHitstops`, `fMaxHitstopDistance`, `fHitstopParryWindow`, `fMissParryLeadTime`,
`fMissPendingWindow`. `missdebug` (console) tells you in chat when it fires and whether it was a near
miss or a hitstop.

## Ranked: Elo by round margin, !ff surrender vote (2026-10-13)

**Elo** (`supabase/functions/ranked/matchmaking.ts`): a result is now worth 6 Elo per round
of margin (`ELO_PER_ROUND`), scaled by the usual Elo expectation and K-factor:
`6 x margin x (K / 32) x 2 x (score - expected)`. An even 7-5 is +-12 for a proven player and
+-18 for one under 15 games; beating a stronger team pays more, beating a weaker one less.
A draw moves nobody. Without round scores a win counts as a margin of 1. Leavers still lose
a flat 50.

**Surrender** (`MustModRanked.uc`, `MustModLTS.uc`, `MustModGame.uci`): after 4 rounds a
player in the match types `!ff` in chat to start a team vote; teammates answer `!yes` /
`!no`. The starter counts as yes. It ends after 30s or when every teammate connected at the
start has voted; anyone who has not voted counts as no. More than 60% yes passes (3 of 5 does
not). A failed vote locks that team out of `!ff` for 60s. On a pass the round in play is
finished, then the match ends as a loss for that team (straight away if it passed between
rounds); `GetWinningTeam` is overridden so the end screen shows the right winner. Elo margin
for a surrender is the deficit at the end + 1 (minimum 1 if they were ahead).

**Backend**: `result` takes `surrender` (0/1/2) and stores it in the new
`ranked_matches.surrendered_team` column (migration `20261013000000_ranked_surrender.sql`);
the Discord match post says who surrendered.

## Messer turn cap, Dane overhead, Morning Star slash windup (2026-10-12)

**Messer** (`MustModWeapon_Messer.uc`, and `MustModWeapon_Messer1H.uc` for the alternate
grip): `AttackHorizRotateSpeed` (horizontal turn cap while attacking) 60000 -> 50000 on the
two-handed grip, 65000 -> 50000 on the one-handed grip.

**Dane Axe** (`MustModWeapon_Dane.uc`): overhead release (`ReleaseAnimations(1)`) 0.6 -> 0.58.

**Morning Star** (`MustModWeapon_MorningStar.uc`): slash windup (`WindupAnimations(0)`)
0.45 -> 0.5.

## Miss stamina 15/25, hits no longer reset the miss lockout, Messer vertical cap (2026-10-09)

**Miss cost** (`MustModMeleeWeapon.uc`): the first miss of the two-miss lockout costs 15
stamina, the second (the one that sends you into Recovery) 25. Flat for every weapon: the
old cost was the family's `iMissMeleeStrikePenalty` (10) plus 5 for two-handers, and the
Quarterstaff's own 10 override is gone. The Bangsword special overhead still costs 0.
`Release.EndState` picks the cost once, before `MissCount` moves, into
`fMissStaminaCostThisSwing`; `GetStaminaLossForMiss()` returns it, so the exhausted-miss
check and vanilla's `S_ConsumeStamina` in `super.EndState` charge the same amount. Tunable
via `fFirstMissStaminaCost` / `fSecondMissStaminaCost`.

**Lockout counting**: landing a hit no longer resets `MissCount`, so miss, hit, miss in one
combo now locks you out. It still resets on feint, flinch, getting hit, the combo ending,
and the lockout itself.

Only the owning client counts misses, so the server prices a remote player's miss as a
first miss (15). The client's `S_ConsumeStamina` is what actually charges it; the server's
own exhausted-miss verdict can only be more lenient than the client's, never stricter.

**Messer** (`MustModWeapon_Messer.uc`, and `MustModWeapon_Messer1H.uc` for the alternate
grip): `VerticalRotateSpeed` 55000 -> 50000. It only applies while attacking; sprint attacks
use `SprintAttackVerticalRotateSpeed` (20000, unchanged). Removed a dead duplicate
`HorizontalRotateSpeed`/`VerticalRotateSpeed` pair at the top of the Messer1H defaults that
the later block was overriding.

## Team damage callout counts the whole map (2026-10-09)

The 5-minute "Top team damage" line now shows each player's total since the match started
on the current map. It used to read `AOCPlayerController.TeamDamageDealt`, which vanilla
`AOCGame.AddPlayerToQueue` zeroes whenever a player is queued to respawn (left over from
the team-damage respawn penalty, which MustMod disables). So in LTS it only covered the
current round, and in respawn modes the current life.

New server-only `MapTeamDamageDealt` on the PRI (`MustModPRI.uci`), added next to the
existing counter in `MustModPawn.uci` (same rules: no peasant targets, no self-hits). It is
cleared at `StartMatch` (warmup doesn't count) and in `PreSeamlessTravelReset` (map change
or restart), and is deliberately not carried in `CopyProperties`. The pawn line is wrapped
in `` `if(`isdefined(GAMEMODE)) `` because the base `MustModPawn` class includes that file
with no game mode defined. The vanilla controller counter is left alone.

## Ranked LTS (2026-10-09)

ImbaMod-style ranked mode for LTS, backed by Supabase. Off unless configured and enabled.

**Flow** (`Classes/MustModRanked.uc`, spawned by `MustModLTS`):
- *Queue*: per server. Once 2 x `RankedMinTeamSize` players are ready (default 2, so 4
  players), a 30s countdown starts so more can join; it skips ahead if the queue reaches
  2 x `RankedMaxTeamSize` (default 16). Then the backend makes the largest even match the
  queue allows (6 queued = 3v3, 7 = 3v3 with the latest joiner left out), earliest
  joiners first, and splits it into the fairest teams by Elo. If the skill-gap rule blocks
  that size it steps down to a smaller match. `MustModGame.ShouldCountDown` holds the
  match until then.
- *Locked*: teams are forced and locked by SteamID64; anyone not picked is moved to
  spectator. Names become `[elo] Name` on every LTS map, ranked on or off, from a few seconds after
  joining (new players show 2500; they are only stored once they are put in a match).
  Updated after each result.
  team names `Agatha [avg]` / `Mason [avg]`. Names carry over between maps, so the tag is
  stripped again on any map where ranked is not running, and never stacks.
- *Skill gap*: a player with more than 15 ranked games and under 2000 Elo is never put in
  a match with anyone over 3000. Players with 15 games or fewer are exempt. Benched
  players are told why.
- *Leavers*: a locked player disconnecting pauses the game for up to 120s. If they come
  back it resumes. If not, or an admin runs `RankedAbandon`, the match is abandoned:
  leavers lose 50 Elo, nobody else's Elo changes, and the map restarts.
- *Result*: 3s after `EndGame` the winner and per-player stats are posted. Team-average
  Elo, K=32 (48 for players still in their first 15 games).

**Prediction data**: each match stores both teams' average and total Elo, the Elo
difference, the win chance Elo predicted at match time, the winner and the rounds won.
`ranked_match_outcomes` (a view over completed matches) lines them up for checking and
tuning the prediction.

**Turning it on and off**: `admin RankedMode 1|0` (saved to the ini *and* the class
defaults -- SaveConfig alone was undone by the map restart, so turning it off did nothing;
restarts the map, and turning it off mid-match voids the match). Anyone can type
`voteranked` / `voteunranked` in the console to vote it on or off; it uses the normal vote
HUD and rules, and on success the map restarts. `voteunranked` is refused while a ranked
match is being played, so a losing side cannot vote away its loss. Only LTS maps have
ranked; on other modes the votes just say so.

**Help**: typing `!rankedhelp` in chat shows the ranked help to everyone, at most once
per 30s server-wide (extra requests inside that window are silently dropped). The typed
line itself is never shown; admin commands go only to the admin who asked. Every player gets a chat line pointing at it on every map
load and restart (8s after they are in, so the HUD is up), in every mode, ranked on or off.

**End of match**: the map restarts 10s after the Elo changes are announced (20s fallback
if the backend does not answer), well before AOCGame's own end-of-game travel. While a
ranked match is live, `AdminRestartMap`, `AdminChangeMap` (and every `AdminGoto*`
shortcut) and the restart/change-map votes are refused.

**Stats**: every finished or abandoned match stores each player's kills, deaths, assists,
enemy damage and score in `ranked_match_players.stats`. A player who disconnects (mid-match
or on the end screen) has their stats snapshotted at that moment, so leavers keep theirs; the `ranked_match_stats` view lays them out.

**Discord**: the `ranked` function posts every finished or abandoned match (teams, Elo
changes, K/D/A, damage) to the `DISCORD_MATCHES_WEBHOOK` channel, and keeps one top-20
leaderboard message in the `DISCORD_LEADERBOARD_WEBHOOK` channel edited in place (its id
is kept in `ranked_settings`). Both optional; posts run after the reply, so Discord being
down cannot affect results. The `leaderboard` action refreshes it by hand.

**Admin commands**: `adminstartmatch` (skip the countdown; any even number queued, even
below `RankedMinTeamSize`), `adminterminatematch` (ends the live ranked match, no Elo changes for
anyone, restarts the map), plus `admin RankedMinTeamSize <n>`, `admin RankedMaxTeamSize <n>`, `admin RankedExtend
[seconds]`, `admin RankedAbandon` (during a leaver pause: leavers lose Elo, the rest is
void), `admin RankedPing`.

**Backend** (`supabase/`): migration with `ranked_players`, `ranked_matches`,
`ranked_match_players`; Edge Function `ranked` with matchmaking/Elo rules in
`matchmaking.ts` (unit tests in `matchmaking_test.ts`). Deploy with JWT verification off
(`supabase/config.toml`); servers authenticate with their own token instead.

**Config**, server-side only, in the server's `UDKGame.ini` -- never in
`DefaultMustMod.ini`, which ships to every player:

```
[MustMod.MustModRanked]
bRankedEnabled=true
RankedEndpoint=https://<project-ref>.supabase.co/functions/v1/ranked
RankedServerToken=<secret; listed as name:secret in RANKED_SERVER_TOKENS>
RankedMinTeamSize=2
RankedMaxTeamSize=16
QueueCountdown=30
LeaverPauseSeconds=120
```

## Voice chat removed (2026-09-02)

EU players reported voice not working at all, so the whole voice arc is out rather than
left half-working. Removed from `MustModPlayerController.uci`: `ToggleSpeaking` (the
enabler -- without it AOCPlayerController's empty stub applies again and the keybind does
nothing), `GBA_ToggleSpeaking`, the `VoiceTrace` / `VoiceStatus` / `VoiceFix` execs, the
5-second `MustModVoiceSweepTick` timer and local-talker claim, and the four `bMustModVoice*`
vars. Removed from `MustModGame.uci`: the `PostLogin` override, `MustModSetupVoiceMuteList`
and `MustModVoiceChannelOf`.

Kept: the netspeed half of `MustModRepairPersistedConfig` (the proximity half went with the
voice code). `VoiceDebug` became `NetDebug` with its voice lines stripped, because it also
carried the saturation and auto-netspeed diagnostics, which are staying.

Left alone: `ClientNotifyPlayerTalking` and `bEnableProximityChat`. That proximity filtering
predates this work and is now inert with the enabler gone; say the word if it should go too.

## Archer flag/spiked mace removed (2026-09-07)

Removed from Archer's primary weapon list (`MustModFamilyInfo_Agatha_Archer.uc` and
`MustModFamilyInfo_Mason_Archer.uc`): the team flag weapon (`MustModWeapon_AgathaFlag` /
`MustModWeapon_MasonFlag`) and `MustModWeapon_SpikedMace`. `MustModWeapon_BastardSword`
renumbered down to fill the gap left in `NewPrimaryWeapons`.

Followup: deleted the now-unused weapon/attachment classes entirely rather than just
delisting them, since nothing else referenced them --
`MustModWeapon_AgathaFlag/MasonFlag/SpikedMace`,
`MustModWeaponAttachment_AgathaFlag/MasonFlag/SpikedMace`, and
`MustModInventoryAttachment_AgathaFlag/MasonFlag`. Also dropped the dead
`MustModWeapon_SpikedMace` check from `MustModPawn.uci`'s `MustModIsNinjaPrimary()` (the
other four ninja-skin weapons are untouched).

## Archer reduced to polearms only (2026-09-08)

Removed all bows and javelins from Archer's primary list in
`MustModFamilyInfo_Agatha_Archer.uc` and `MustModFamilyInfo_Mason_Archer.uc`:
Shortbow, Longbow, Warbow, Short Spear (melee), Javelin (melee) and Heavy Javelin (melee).
Remaining primaries are Spear, Brandistock and Bastard Sword, renumbered to 0-2.

Also removed the now-useless Bodkin and Broadhead arrow entries from `NewTertiaryWeapons`,
leaving Hunting Knife and Buckler (renumbered to 0-1). Secondaries are unchanged.

Archer now has no ranged option at all and is effectively a second polearm class.

## Server browser name changed to "MustMod" (2026-09-09)

`ModDisplayString` in `MustModGame.uci` was still `"SlumpMod 2.5.0"`, so the mod
advertised itself under the old lineage name in the server browser. Now `"MustMod"`.

Left alone deliberately: the `AOCTO-Slumpshill_p` / `AOCTO-Slumppost_p` map names and the
`?modname=Slump3` admin travel command (those are real map/mod identifiers, not branding),
the `SlumpStats` endpoints and `slumpmod-production` server id in `MustMod.ini`, the
`"=== Welcome to SlumpMod ==="` join message, and `MustModKOTH.uc`'s own
`ModDisplayString="Chivalry: Advanced"` override, which still wins for KOTH.

## Halberd LMB damage raised 65 -> 70 (2026-09-09)

`AttackTypeInfo(0)` in `MustModWeaponAttachment_Halberd.uc`. Goal was to make the
LMB-to-torso into stab-to-legs chain lethal on Man-at-Arms: stab to legs deals 49, so the
slash had to reach 51, and SwingBlunt vs MaA resists at 0.725 (0.5x0.80 swing + 0.5x0.65
blunt), which needs base 69.66. 70 is the first clean integer. 71 would round to the same
51, so there is no reason to go past 70.

Everyone is 100 HP in this mod (MaA and Archer set it explicitly, Knight and Vanguard
inherit 100 from vanilla `AOCFamilyInfo_*`), so this crosses more thresholds than the one
combination it was aimed at. Vs MaA, slash-legs + stab-torso now kills too (99 -> 102), and
double slash to torso goes 94 -> 102. Only the all-legs chain still survives (87 -> 90).

Archer picks it up as well, since its SwingBlunt resistance is also 0.725: slash-torso +
stab-legs 98 -> 101 and double slash to torso 98 -> 104 are both new two-hit kills.
Knight (0.505 resist) and Vanguard (0.65) are unaffected -- their best two-hit lines reach
71 and 103 respectively, so nothing new becomes lethal that was not already.

## Exhausted-miss recovery penalty (2026-09-09)

Missing a melee attack while holding less stamina than the miss itself costs now locks you
in Recovery for a flat **2.0 seconds** instead of the weapon's own recovery length. New in
`MustModMeleeWeapon.uc`: `bExhaustedMiss` / `fExhaustedMissRecovery`, the verdict set in
`state Release`'s `EndState`, and a `PlayStateAnimation` override in `state Recovery`.

The check runs at the top of `Release.EndState`, before `super.EndState()` spends the
stamina -- afterwards the pool is already docked and floored at 0, which would flag anyone
who merely finished a swing below the cost rather than those who could not afford it. It
sits outside the `IsLocallyControlled()` gate so the server reaches the same verdict for
remote players, and `bInfiniteStamina` is exempt.

Miss cost is 10 stamina one-handed and 15 two-handed (`iMissMeleeStrikePenalty` 10 + 0,
plus 5 for `bTwoHander`), identical for all four classes. QuarterStaff and DoubleBlade
override `GetStaminaLossForMiss` to skip the two-hander surcharge, so they threshold at 10.

Stretching `fAnimationLength` is the same lever vanilla already uses for a combo whiff
(x1.25) and a shove/sprint whiff (x1.5); it drives the `OnAttackAnimEnd` timer that ends
the state, and replicates as a percentage of the real clip, so the animation plays slowed
to fill the window instead of freezing. For scale, ordinary melee recovery runs 0.40s
(daggers, Cudgel) to 0.90s (Zweihander, Maul, PoleAxe, Nodachi), so 2.0s is a little over
double the worst case and roughly five times the best.

Slash/overhead/stab have no up-front stamina gate, so a gassed player can still open the
swing freely and this will fire often. Parry and shove are excluded, matching the existing
miss block. `CanGotoParry()` is still honoured, so parrying out of the lockout early
remains possible exactly as it does for normal recovery -- say the word if the penalty
should be inescapable instead.

NOT YET COMPILED OR PLAYTESTED. Numbers above are read from source, not measured in game.

## Cudgel, DoubleBlade and both flails removed (2026-09-09)

Removed from every loadout and deleted outright, following the precedent set by the Archer
flag/spiked mace removal: `MustModWeapon_Cudgel`, `MustModWeapon_DoubleBlade`,
`MustModWeapon_HFlail`, `MustModWeapon_2HFlail`, plus
`MustModWeaponAttachment_{Cudgel,DoubleBlade,HFlail,2HFlail}` and
`MustModWeaponInventory_2HFlail`. 20 loadout lines across 11 family files; every array
renumbered contiguously.

Where they were: DoubleBlade was Vanguard `NewPrimaryWeapons(8)` (Fork renumbered 9 -> 8),
HFlail and 2HFlail were Knight `NewPrimaryWeapons(10)` and `(11)`, and Cudgel was a
*secondary* for Assassin, Knight (7), Man-at-Arms (1) and Vanguard (1) -- never a primary
anywhere, despite the icon-only presentation making it look like one.

Also removed, so no cudgel survives anywhere: Archer's `NewSecondaryWeapons(3)`, which
pointed at the *vanilla* `AOCWeapon_Cudgel` rather than the mod class, and the base
`MustModFamilyInfo_ManAtArms.uc` entries (`NewPrimaryWeapons(10)`=HFlail,
`NewSecondaryWeapons(5)`=`AOCWeapon_Cudgel`) -- dead config, since the team subclasses call
`NewPrimaryWeapons.empty` and rebuild, but left in place it would mislead the next edit.
The commented-out DoubleBlade primary in both Archer files went too; the commented GrandLance
line beside it was left alone.

`MustModWeaponAttachment_Firebug` extended `MustModWeaponAttachment_Cudgel`, and Firebug is a
live Man-at-Arms primary, so it was reparented to `AOCWeaponAttachment_Cudgel` (the Cudgel
attachment's own parent) and given the four properties it had been inheriting: the shared
`MustModWeaponAttachment.uci` include, `KickOffset`/`KickSize`, `WeaponID=EWEP_Cudgel` and
`WeaponSocket=wep1hpoint`. Its meshes, `WeaponClass` and all six `AttackTypeInfo` entries
were already declared locally and are byte-identical to Cudgel's, so Firebug's stats are
unchanged. `WeaponID` stays `EWEP_Cudgel` to match `MustModWeapon_Firebug`'s own
`CurrentWeaponType`.

Side effect of the Vanguard renumber: `NewSecondaryWeapons` had a pre-existing hole at index
2 (it jumped 1 -> 3). Rebuilding the list contiguously closed it, so that phantom empty slot
is gone as well.

`DoubleBlade.upk` was one of the eight packages the cooker drops and the fix script
re-injects. Nothing references the package any more, so it was dropped from
`$RequiredPackages` in `SDK - Fix MustMod Content.ps1` -- the injected list is now seven.
The `.upk` itself is still in the repo and in `ContentSDK`; delete it separately if you want
the ~1.8 MB back.

Left in place, needs a decision: `MustModCustomizationContent.uc` still carries cosmetics for
the removed weapons -- `HFlail_Variant_01` (line 1079, `WeaponType=EWEP_HFlail`),
`Cudgel_Variant_01` (1287) and `Peasant_Cudgel` (1447), both `EWEP_Cudgel`, with matching
`GearData` at 268, 418 and 532. They still compile, since those enum values are vanilla, but
they are now unreachable skins.

`MustModWeapon_Flail` and `MustModWeaponAttachment_Flail` were kept. `MustModWeapon_HFlail`
extended `MustModWeapon_Flail`, but Flail itself is in no loadout and was already orphaned
before this change, so it is untouched dead code rather than part of the removal.

NOT YET COMPILED.

## Panting now means "cannot feint" - 13 or less, and never above (2026-09-09)

The exhausted-breathing loop now starts at 13 stamina or less and, unlike before, genuinely
never plays above it. Two parts, both in `MustModPawn.uci`.

**The threshold.** Was `Stamina <= 15.0f`, now 13, expressed through a new
`MustModShouldPant()` so there is one source of truth. 13 is chosen from the cheapest feint
in the game: `MustModWeapon_WarAxe` at `iFeintStaminaCost=14`, with every other
primary/secondary weapon at 15 or 18. At 13 or less no weapon can feint, so the sound now
means exactly that. Absolute rather than a fraction of `MaxStamina`, so identical for every
class and weapon (`MaxStamina` is a flat 100 on `AOCPawn` with no family or weapon override).

**The fix that makes "never above" true.** `PlayLowStaminaLoop` is now overridden to gate
every caller through `MustModShouldPant()`. This matters because `AOCPawn`'s own `Tick` also
calls it, asking for the loop below `MaxStamina * 0.2f` (below 20), and that runs via our
`super.Tick()` before our own line. `bPlayingExhaustLoop` is edge-triggered, so between the
two thresholds vanilla flipped the flag on and we flipped it straight back off inside the
same frame -- a 0.5s `FadeIn` plus a 0.5s `FadeOut`, every frame, for the whole band. That
had been true at 15 as well; lowering to 13 would only have widened it from 5 stamina to 7.
Gating in the override means the loop can only ever be started by our rule, whoever asks, so
the vanilla call is now inert instead of fought. A caller passing false still stops the loop,
so `AOCPawn`'s stop-on-death call is unaffected, and `Health > 0.0f` is kept in the rule.

Untouched: `PlayLowStaminaGrunt`, the separate one-shot grunt for failing an action through
lack of stamina (dodge at `MustModPawn.uci`, and the controller's call). It keys off the
specific action's cost, not this threshold, and is a different sound from the panting loop.

## Man-at-Arms dodge cost raised to a flat 28 (2026-09-09)

`iDodgeCost` 25 -> 28 in `MustModFamilyInfo_Agatha_ManAtArms.uc:53` and
`Mason_ManAtArms.uc:52`, the two classes that actually spawn.

Flat now means flat: `CalcDodgeCost()` in `MustModPawn.uci` used to return a hardcoded 22
when the held weapon was `MustModWeapon_Hatchet`, so a Hatchet MaA dodged for 22 while
everyone else paid 25. That branch is gone and the function is a straight
`return PawnFamily.iDodgeCost`, kept as a function because `StartDodge` uses it for the
affordability check.

Removed with it: the two `ConsumeStamina(CalcDodgeCost() - PawnFamily.iDodgeCost)` calls
(commented "Consume extra stamina") in `StartDodge` and its client branch. Those charged only
the *difference* between the per-weapon cost and the family cost -- for the Hatchet, 22 - 25 =
-3, i.e. a 3 stamina refund, which is how the 22 was actually delivered. With no per-weapon
override the delta is always 0, and `ConsumeStamina(0)` is a verified no-op (`AOCPawn.uc:2087`
only sets the 1.5s regen delay when `Amount > 0`), so removing them changes nothing today and
removes the machinery that made the cost non-flat. Re-add both if a per-weapon dodge cost is
ever wanted again.

Also set the base `MustModFamilyInfo_ManAtArms.uc:82` from 20 to 28. That value is dead --
both team subclasses override it and nothing instantiates the base directly (Assassin extends
`MustModFamilyInfo_Archer`, not this) -- but a stale 20 sitting there is the same trap that
already misled a lookup earlier in this session.

Unaffected: Archer 40 (and its separate `iRollStaminaCost=25`), Assassin 20.

## Cudgel restored, Firebug removed (2026-09-09)

Reversal of part of the earlier removal, plus a new one.

**Cudgel is back**, exactly as it was: `MustModWeapon_Cudgel` and
`MustModWeaponAttachment_Cudgel` restored from git, and all ten loadout entries reinstated --
`NewSecondaryWeapons` for Assassin, Knight, Man-at-Arms and Vanguard on both teams, plus
Archer's slot, which points at the *vanilla* `AOCWeapon_Cudgel` rather than the mod class, and
the dead base `MustModFamilyInfo_ManAtArms` entry. No content package is involved; the Cudgel
attachment uses vanilla `WP_aux_Shortsword`.

**Firebug (the fire cudgel) is removed.** `MustModWeapon_Firebug` and
`MustModWeaponAttachment_Firebug` deleted. It was `NewPrimaryWeapons(11)` for *both*
Man-at-Arms and Assassin on both teams -- four live slots, not two -- plus a commented-out
line in `Mason_Archer`. All gone, arrays renumbered.

Firebug also had live logic in `MustModPawn.uci`, all of which went with it: the
`StoredFirebugHitActor` var, the ignition block at the end of `AttackOtherPawn` (which set a
0.25s timer so the blunt impact cue finished before the fire scream), the
`DelayedFirebugIgnite()` callback, and the stale explanatory comment left in `TakeDamage`.

The reparent from the previous entry is void -- `MustModWeaponAttachment_Firebug` was pointed
at `AOCWeaponAttachment_Cudgel` to survive the Cudgel's deletion, and both premises have now
reversed, so the file is simply gone and the restored `MustModWeaponAttachment_Cudgel` has no
children.

Now orphaned by Firebug's removal, left in place: `MustModWeapon_FirebugThrow` and
`MustModWeaponAttachment_FirebugThrow` (the throw mode, already dead -- Firebug's
`AlternativeMode` line was commented out), and `MustModDmgType_TorchBurn`, which only
`DelayedFirebugIgnite` used. Nothing references any of the three, so they compile as dead
code; say the word to delete them.

Still removed from the earlier pass: DoubleBlade, HFlail, 2HFlail and their attachments, and
`DoubleBlade.upk` remains out of the fix script's `$RequiredPackages` (seven packages).

NOT YET COMPILED.

## HuntingKnife is the only secondary for every class but Man-at-Arms (2026-09-09)

`NewSecondaryWeapons` rebuilt down to a single entry --
`MustModWeapon_HuntingKnife` with `CorrespondingDuelProp=EDUEL_HuntingKnifeUse` -- in all
eight non-MaA family files:

| class    | secondaries before | after |
|----------|--------------------|-------|
| Archer   | 9                  | 1     |
| Knight   | 8                  | 1     |
| Vanguard | 6                  | 1     |
| Assassin | 3                  | 1     |

Man-at-Arms is untouched and keeps Saber / Cudgel / Dagesse.

Assassin is included because it is a selectable class in its own right --
`Families(ECLASS_SiegeEngineer)=MustModFamilyInfo_Agatha_Assassin` in `MustModGame.uci` --
even though it inherits from `MustModFamilyInfo_Archer`. Say so if it was meant to sit with
Man-at-Arms instead.

The dead base `MustModFamilyInfo_ManAtArms` secondary list (six vanilla `AOCWeapon_*` entries)
was left alone, being both Man-at-Arms and inert.

Needs a decision: Archer, Knight and Vanguard now carry HuntingKnife as their *tertiary* as
well (`NewTertiaryWeapons(0)`, unchanged from before), so the same weapon occupies two slots
in the selection screen for those three. Knight's ten primaries additionally list
`MustModWeapon_HuntingKnife` first in every `CForceTertiary` array. Whether the UI tolerates
one class in two slots is untested. Assassin has no HuntingKnife tertiary, so it is unaffected.

NOT YET COMPILED.

## Feint cost flattened to 16, panting follows to 15 (2026-09-15)

Every weapon that feinted for 14 or 15 now feints for 16. That is 49 weapon files: the
lone 14 (`MustModWeapon_WarAxe`) and the 48 sitting at 15, i.e. every melee primary and
secondary except the three that were already above. `iFeintStaminaCost` only.

| cost | weapons | note |
|------|---------|------|
| 16   | 49      | was 14 (WarAxe) or 15 (everything else) |
| 18   | 2       | HolyWaterSprinkler, Messer -- unchanged |
| 20   | 1       | ThrowingKnife -- unchanged |
| 35   | 1       | HuntingKnife -- unchanged |
| 0    | 14      | bows, crossbows, Sling, OilPot, SmokePot, the `*Throw` modes -- they do not feint |

The 8 shield files declare no `iFeintStaminaCost` at all and were untouched.

**Panting moves with it.** `MustModShouldPant()` in `MustModPawn.uci` goes from
`Stamina <= 13.0f` to `<= 15.0f`. The rule is unchanged -- pant exactly when no weapon in
the game can afford a feint -- but the cheapest feint is now 16 rather than 14, so the
threshold is 15 rather than 13. Doc comment updated to match, including the guard band in
the `PlayLowStaminaLoop` override, which narrows from 13-to-20 to 15-to-20 (the vanilla
`MaxStamina * 0.2f` end of it has not moved).

WarAxe loses its 1-stamina feint discount; it is now identical to everything else.

NOT YET COMPILED.

## Ground clangs now trigger the exhausted-miss punish; recovery cut to 1.30s (2026-09-15)

Two changes in `MustModMeleeWeapon.uc`, both around `bExhaustedMiss`.

**The bug.** Hitting terrain on an empty stamina bar was *cheaper* than whiffing into air.
`Release.EndState` flags `bExhaustedMiss` correctly for a world clang -- terrain is not
`bHitDestructibleObject`, so the whiff takes `MissCount++` and the miss stamina cost like
any other -- but the flat recovery that the flag is supposed to buy lived only in
`Recovery.PlayStateAnimation`. A clang routes `Release -> WorldDeflect -> Active` via
`AOCWeapon`'s `Deflect.OnStateAnimationEnd` and never enters `Recovery`, so the flag was
written and then discarded. Net effect: ~0.85s of deflect instead of the punish.

**The fix.** `WorldDeflect` is now declared outright here (rather than inherited, since
`AOCMeleeWeapon`'s version extends its own `Deflect` and we override `Deflect`) with a
`PlayStateAnimation` that stretches `StateAnimations[0]` to `fExhaustedMissRecovery` --
the same `fAnimationLength` + `bForce` trick `Recovery` already uses, which drives the
`OnAttackAnimEnd` timer and plays the clip slowed rather than freezing on a pose. Vanilla
`WorldDeflect`'s `BeginFire` is preserved, so you still cannot parry out of a world clang.

Scoped to `WorldDeflect`, never plain `Deflect`. Being parried lands in `Deflect` too, and
while `bExhaustedMiss` is false there today -- `MustModPawn.uci` sets `bHitPawn = true` on
any registered parry, including a parried one -- punishing parried swings is not the intent
and should not depend on that coupling.

**Leak closed.** `Deflect.EndState` now clears `bExhaustedMiss`. Previously only
`Recovery.EndState` did, so a clang's flag survived into `Active`, and since a parry never
passes back through `Release.EndState` to recompute it, a whiffed parry after a low-stamina
clang would have inherited the flat recovery instead of its own 0.50s.

**Value lowered: `fExhaustedMissRecovery` 2.000 -> 1.300.** 1.30s is the floor that keeps
the punish meaningful against the fastest weapons. Worst realistic case: a Halberd parries
200ms into a shortsword (Cudgel/Dagesse) overhead, the attacker whiffs, the parry whiffs
with them. The Halberd commits 2.475s before its stab lands -- 0.2 react, 0.5 raise
(`WindupAnimations(4)`), 0.5 active window (`ReleaseAnimations(4)`), 0.5 parry recovery,
0.775 stab windup -- while the shortsword needs 0.850s to finish the whiff plus a 0.400s
slash windup. Below ~1.23s the exhausted player wins that trade anyway; 1.30 covers both
shortswords with margin. Still well clear of the longest ordinary melee recovery (0.90s).

NOT YET COMPILED. The one thing static reading cannot settle is whether the compiler
accepts `state WorldDeflect extends Deflect` in a subclass that also overrides `Deflect`;
if it does not, move the override onto `Deflect` and gate it on `IsInState('WorldDeflect')`.

## DualBucklers removed from Man-at-Arms (2026-09-15)

`NewPrimaryWeapons(10)=(CWeapon=class'MustModWeapon_DualBucklers')` deleted from
`MustModFamilyInfo_Agatha_ManAtArms.uc` and `MustModFamilyInfo_Mason_ManAtArms.uc`. It was
the last index in both, so nothing needed renumbering -- MaA primaries now run 0-9, ending
at QuarterStaff. The shared `MustModFamilyInfo_ManAtArms.uc` never listed it (it stops at 9
on vanilla `AOCWeapon_` classes), so it needed no change.

Prompted by the weapon-select screen: DualBucklers was the only MaA primary showing a shield
icon. It has no art of its own and borrows the buckler cosmetic --
`WeaponLargePortrait="UI_CustWeaponImages_SWF.skin_vicomte_buckler_png"` and
`WeaponSmallPortrait="UI_WeaponImages_SWF.icon_weapon_select_buckler_png"` -- the latter
being the same icon the actual Buckler shield uses, so in a list it read as a shield rather
than as a pair of bucklers. The other ten primaries all use their own
`UI_WeaponImages_SWF.weapon_select_<name>` art.

Left in place deliberately:

- **Assassin still has it**, at index 10 in both `MustModFamilyInfo_Agatha_Assassin.uc` and
  `MustModFamilyInfo_Mason_Assassin.uc`. Only MaA was asked for.
- **The classes themselves.** `MustModWeapon_DualBucklers` and
  `MustModWeaponAttachment_DualBucklers` are untouched, unlike the flag/spiked-mace removal
  which deleted the classes outright -- Assassin still references them, and
  `MustModPawn.uci` calls `MustModWeaponAttachment_DualBucklers.UpdateLeftHandVisibility`
  on view changes.

NOT YET COMPILED.

## Bangsword added to Knight (2026-09-15)

XangMod's Longsword imported as a separate weapon under the name "bangsword", last in the
Knight weapon-select list on both teams.

Two new classes, copied from `SlumpMod-main/Classes/XangModWeapon_Longsword.uc` and
`XangModWeaponAttachment_Longsword.uc`. **No values were changed** -- the only edits are
identifier renames:

| file | changed lines |
|------|---------------|
| `MustModWeapon_Bangsword.uc` | class decl, `AttachmentClass`, `AlternativeMode`, header comment |
| `MustModWeaponAttachment_Bangsword.uc` | class decl, `include` path, `WeaponClass` |

Everything else is byte-identical to the XangMod source, verified by diff. That includes
`CurrentWeaponType=EWEP_Longsword`, `InventoryAttachmentClass=class'AOCInventoryAttachment_Longsword'`,
all `A_Phys_Mat_Impacts.Longsword_*` sound cues, and the portraits --
`weapon_select_longsword` / `icon_weapon_select_longsword_png` -- so it carries the longsword
icon as asked, with no new content package needed.

Registered as `NewPrimaryWeapons(10)` in `MustModFamilyInfo_Agatha_Knight.uc` and
`MustModFamilyInfo_Mason_Knight.uc`, after Katana. Name set in `Localization/INT/MustMod.INT`
under `[MustModWeapon_Bangsword]`.

Worth knowing, both consequences of keeping the source values as-is:

- **`iFeintStaminaCost=15`**, not 16. Bangsword is now the only weapon in the mod below 16,
  and therefore the cheapest feint in the game -- which is the value the panting threshold is
  derived from. The rule "pant when no weapon can afford a feint" would put panting at 14
  again rather than 15. Left alone, since changing it means changing a value.
- **`AlternativeMode=class'MustModWeapon_Longsword1H'`** points at the existing 1H class, as
  there is no Bangsword1H. Switching Bangsword to 1H gives the ordinary Longsword1H, and
  switching back returns the ordinary Longsword rather than Bangsword, since
  `MustModWeapon_Longsword1H.uc:163` points back at `MustModWeapon_Longsword`.

NOT YET COMPILED.

## Top-3 team damage announced in chat every 5 minutes (2026-09-15)

New `AnnounceTopTeamDamage()` in `MustModGame.uci`, started from `StartMatch` on a looping
300s timer alongside the existing catapult and stats sweeps.

**Why chat and not the scoreboard.** There is no column free. The Flash scoreboard exposes
exactly six data keys -- `score`, `kill`, `death`, `assist`, `ping`, `rank` -- and
`MustModView_HUD_Scoreboard` already uses all six, having taken `ping` for the Prys column
and pushed real ping onto `rank`. A seventh means editing
`Flash/FLA/Scoreboard/Scoreboard_newUI.fla` and `ScoreboardItemRenderer.as` with the
Scaleform GFx exporter, which is out of scope here.

Worse, the number is not reachable client-side at all. `AOCPRI.TeamDamageDealt` is
repurposed for the parry count, and the real running total lives on
`AOCPlayerController.TeamDamageDealt` (`MustModPawn.uci`), which is never replicated to
anyone but its owner. Announcing from the game class sidesteps both problems: the server
holds every controller, so no new replicated var was needed.

**The silence rule.** The callout builds a numbers-only signature of the three totals and
returns early when it matches the previous one, so an idle round does not repeat the same
line every five minutes. Comparing numbers rather than the rendered text is deliberate --
two players swapping places on identical totals is not a change worth announcing.
`LastTeamDamageSignature` resets in `StartMatch` with the other per-match counters.

Players with zero team damage and voluntary spectators are skipped, so an entirely clean
round says nothing at all. Selection is a three-deep insertion sort rather than sorting the
whole player array.

Output is six-argument `BroadcastMessage` system messages in `#D1A04A`, matching the admin
callouts in `MustModRCon.uc`:

```
Top team damage:
  1. SomePlayer - 340
  2. Another - 120
  3. Third - 45
```

COMPILED: `Success - 0 error(s)`, and both `AnnounceTopTeamDamage` and
`LastTeamDamageSignature` verified present in `MustMod.u`. Not yet playtested -- the 5 minute
cadence and the change-detection have not been observed on a live server.

Changelog
=========

Note: The base values in this document are taken from Mercs Mod 1.995 (thanks GIRU GIRU for providing the numbers for this).

---

# 2.0.2
* Increased messer feint recovery on LMB/overhead (0.3 -> 0.325)
* Increased messer feint recovery on stabs (0.43 -> 0.45)
* Increased messer feint recovery on combos (0.535 -> 0.55)
* Increased longsword feint recovery on LMB/overhead (0.2 -> 0.225)
* Increased longsword feint recovery on combos (0.5 -> 0.525)
* Increased feint recovery on LMB/overhead for all polearms except halberd (0.2 -> 0.3)
* Increased feint recovery on stabs for all polearms except halberd (0.4 -> 0.45)
* Increased feint recovery on combos for all polearms except halberd (0.5 -> 0.55)
* Doubled handle tracers on polearms (this should reduce the amount of handlehits that occur)
* Increase horizontal turncap on all daggers, meaning you can turn faster (75000 -> 85000)
* Reduce turncap on halberd (55000 -> 45000)

# 2.0.1
* Fixed buggy handlehits on polearms from the previous patch
* Reduced halberd knockback on overhead/LMB from 34500 -> 30000
* Reduced halberd knockback on stab from 30175 -> 29000

# 2.0.0

**General Gameplay**

* Added mechanic to cancel ripostes into parries at any time<sup>1</sup>
* Ripostes are no longer flinchable during release state<sup>2</sup>
* MAA stamina on kill increased from 30 to 50
* MAA dodge out of parry cost increased from 25 to 30<sup>3</sup>
* MAA attack lockout after dodge decreased from 0.3 to 0.2 when dodging forwards
* MAA backpedal speed decreased from 0.85 to 0.8
* Archer projectile modifier for torso and arms increased from 2 to 2.25<sup>4</sup>

**Weapon Tweaks**

* Messer stab feint recovery increased from 0.400 to 0.435
* Messer combo feint recovery increased from 0.500 to 0.535
* Poleaxe turncap increased from 53000 to 53800
* Removed handle tracers from all polearms
* Halberd overhead windup increased from 0.600 to 0.625
* Hatchet overhead damage decreased from 95 to 85
* Hatchet swing damage decreased from 95 to 70
* Hatchet damage type for overheads and swings changed from swing to chop

**Console Commands**

* Added admingotoduel to change map to duelyard

**Notes**

* 1 - This mechanic costs 15 stamina not including the stamina drain of the parry
* 2 - Currently, ripostes are also unflinchable during windup, this makes them unflinchable at all times
* 3 - This only affects dodges during a parry, it does not affect normal dodges
* 4 - This is the damage archers take from projectiles, not the damage archer primary weapons deal. This allows light crossbow to 1 shot other archers without needing a headshot.

# 1.6.0
* Stamina values have been fully rewritten, new values can be found [here](https://docs.google.com/spreadsheets/d/1gaXfSi5lQ256lwTdCtGf68Hzlo7aJJf1jZUe5mlNTRA/edit?usp=sharing) while old values can be found [here](https://docs.google.com/spreadsheets/d/1oe2dZvHpgk-lW4AvaQkj5sE0ETmtme6Oabfw2Utof3g/edit?usp=sharing).
* Sword of War overhead damage decreased to 68 swing from 70 swing.
* Sword of War stab damage decreased to 63 pierce from 77.5 pierce.
* Sword of War stab windup decreased to 0.625 seconds from 0.7 seconds.
* Sword of War LMB release decreased to 0.5 seconds from 0.525 seconds.
* Sword of War stab release decreased to 0.375 seconds from 0.4 seconds.
* Sword of War stab feint recovery increased to 0.45 seconds from 0.4 seconds.

# 1.5.0
* Feint window increased on 2h weapons for both combos and normal attacks by 0.05
* Reduce throwing axe ammo to 1 and throwing knife ammo to 2
* Reduce initial projectile speed for firepots from 2000 to 1500
* Increase greatsword combo times on overhead and slash to 0.7
* Increase broadsword stab release to 0.35 and overhead release to 0.4

# 1.4.0

Feint window changes:
* Feint window reduction out of combos increased to (0.275) from (0.25)
* Feint recovery changes reverted for:
* 2H Longsword LMB reverted to (0.2) from (0.36)
* 2H Longsword overhead reverted to (0.2) from (0.36)
* 2H Messer stab reverted to (0.4) from (0.46)
* Greatsword LMB reverted to (0.2) from (0.26)
* Greatsword overhead reverted to (0.2) from (0.26)
* Greatsword stab reverted to (0.4) from (0.46)
* Claymore stab reverted to (0.4) from (0.46)

Feint recovery changes decreased for:
* 2H Longsword stab reduced to (0.45) from (0.52) - pre v1.2.0 was (0.4)
* 2H Messer LMB reduced to (0.3) from (0.36) - pre v1.2.0 was (0.2)
* 2H Messer overhead reduced to (0.3) from (0.36) - pre v1.2.0 was (0.2)
* 1H All Weapons stab reduced to (0.45) from (0.475) - pre v1.2.0 was (0.4)

Feint recovery changes remaining at 1.3.0 values for:
* 1H All weapons LMB will remain at (0.35) - pre v1.2.0 was (0.3)
* 1H All weapons overhead will remain at (0.35) - pre v1.2.0 was (0.3)
* 2H Sword of War LMB will remain at (0.28) - pre v1.2.0 was (0.2)
* 2H Sword of War overhead will remain at (0.28) - pre v1.2.0 was (0.2)
* Poleaxe LMB will remain at (0.18) - pre v1.2.0 was (0.2)
* Poleaxe overhead will remain at (0.18) - pre v1.2.0 was (0.2)
* Quaterstaff LMB will remain at (0.32) - pre v1.2.0 was (0.2)
* Quarterstaff overhead will remain at (0.32) - previously (0.2)
* Quarterstaff stab will remain at (0.46) - pre v1.2.0 was (0.4)

# 1.3.0
* Moved kick tracer down so it is now jumpable (Z=-10 -> Z=-65)
* Readded CauseEvent, but it now displays in chat when used (it can be useful to map makers sometimes)
* Fixed some sling zoom bugs
* Bardiche overhead damage type changed (CHOP -> CUT)
* Bardiche overhead damage increased (100 -> 105)
* Sword of War overhead release time decreased (0.525 -> 0.5)
* Quarterstaff overhead & LMB windups increased (0.4 & 0.45 -> 0.5)
* Waraxe overhead & LMB windups increased (0.4 & 0.45 -> 0.5)
* Holy Water Sprinkler overhead & LMB windups increased (0.4 & 0.45 -> 0.5)
* Flinch duration for two-handed weapons increased (0.9 -> 1.0)

#### 1.2.1
* Longsword stab feint recovery increased from (0.4) -> (0.52)
* Messer stab feint recovery increased from (0.4) -> (0.46)
* All 1H stab feint recoveries increased from (0.475) -> (0.52)
* Sword of war overhead / LMB feint recovery increased from (0.2 -> 0.28)
* Smoke pot and oil pot no longer flinch

# 1.2.0

#### KNIGHT PRIMARY WEAPONS
Poleaxe
* Horizontal swing feint recovery decreased from (0.2) to (0.18)
* Overhead feint recovery decreased from (0.2) to (0.18)

Bearded Axe
* Horizontal swing windup increased from (0.525) to (0.55)
* Stab windup increased from (0.55) to (0.6)
* Overhead stamina drain increased from (26) to (29)

Grand Mace
* Overhead windup increased from (0.575) to (0.6)
* Overhead release decreased from (0.6) to (0.575)

Longsword (2 Handed)
* Horizontal swing feint recovery increased from (0.2) to (0.36)
* Overhead feint recovery increased from (0.2) to (0.36)

Longsword (1 Handed)
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

Messer (2 Handed)
* Overhead release time decreased from (0.6) to (0.575)
* Horizontal swing feint recovery increased from (0.2) to (0.36)
* Overhead feint recovery increased from (0.2) to (0.36)

#### KNIGHT TERTIARY WEAPONS
Throwing Knives
* Damage to archer head decreased to (76) from (86)

Throwing Axes
* Damage to archer head decreased to (119) from (135)

#### VANGUARD PRIMARY WEAPONS
Greatsword
* Overhead windup increased from (0.55) to (0.575)
* Horizontal swing feint recovery increased from (0.2) to (0.26)
* Overhead feint recovery increased from (0.2) to (0.26)
* Stab feint recovery increased from (0.4) to (0.46)

Claymore
* Stab feint recovery increased from (0.4) to (0.46)

Spear
* Overhead recovery decreased from (0.725) to (0.675)
* Stab recovery decreased from (0.65) to (0.625)

Bardiche
* Alternate horizontal swing into stab combo increased from (0.7) to (0.8)

Billhook
* Alternate horizontal swing into stab combo increased from (0.7) to (0.8)
* Horizontal swing stamina drain increased from (25) to (27)
* Overhead stamina drain increased from (27) to (29)
* Stab stamina drain increased from (26) to (28)

Halberd
* Overhead release time decreased from (0.6) to (0.575)
* Alternate horizontal swing into stab combo increased from (0.7) to (0.8)

Polehammer
* Polehammer alt-LMB to stab combo (0.725 -> 0.825)

#### VANGUARD TERTIARY WEAPONS
Smoke Pots
* Ammo increased to 3
* Initial projectile speed increased from (1500) to (2000)
* Maximum projectile speed increased from (2000) to (2500)

#### MAN AT ARMS PRIMARY WEAPONS
Broadsword
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

Norse Sword
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

Falchion
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

Hatchet
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

War Axe
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

Dane Axe
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

Mace
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

Morningstar
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

Holy Water Sprinkler
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

Quaterstaff
* Horizontal swing feint recovery increased from (0.2) to (0.32)
* Overhead feint recovery increased from (0.2) to (0.32)
* Stab feint recovery increased from (0.4) to (0.46)

#### MAN AT ARMS SECONDARY WEAPONS
Shortsword
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

Sabre
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

Cudgel
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

Broad Dagger
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

Hunting Knife
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

Thrusting Dagger
* Horizontal swing feint recovery increased from (0.3) to (0.35)
* Overhead feint recovery increased from (0.3) to (0.35)
* Stab feint recovery increased from (0.4) to (0.475)

#### ARCHER PRIMARY WEAPONS
Longbow
* Bodkin arrows removed
* Broadhead damage to knight to head decreased to (42) from (46)
* Broadhead damage to knight to torso decreased to (21) from (23)
* Broadhead damage to knight to legs decreased to (14) from (15)
* Broadhead damage to vanguard to head decreased to (63) from (68)
* Broadhead damage to vanguard to torso decreased to (32) from (34)
* Broadhead damage to vanguard to legs decreased to (21) from (22)
* Broadhead damage to man at arms to head decreased to (90) from (97)
* Broadhead damage to man at arms to torso decreased to (45) from (49)
* Broadhead damage to man at arms to legs decreased to (29) from (31)
* Broadhead damage to archer to head decreased to (155) from (188)
* Broadhead damage to archer to torso decreased to (102) from (110)
* Broadhead damage to archer to legs decreased to (38) from (41)
* Arrow cam removed

Shortbow
* Broadhead arrows removed
* Bodkin damage to knight to head decreased to (49) from (50)
* Bodkin damage to knight to torso decreased to (24) from (25)
* Bodkin damage to vanguard to head decreased to (65) from (68)
* Bodkin damage to vanguard to torso decreased to (33) from (34)
* Bodkin damage to vanguard to legs decreased to (21) from (22)
* Bodkin damage to man at arms to head decreased to (70) from (72)
* Bodkin damage to man at arms to torso decreased to (35) from (36)
* Bodkin damage to archer to head decreased to (99) from (115)
* Bodkin damage to archer to torso decreased to (65) from (67)
* Bodkin damage to archer to legs decreased to (24) from (25)
* Arrow cam removed

Warbow
* Broadhead arrows removed
* Bodkin damage to knight to head increased to (74) from (72)
* Bodkin damage to knight to torso increased to (37) from (36)
* Bodkin damage to knight to legs increased to (24) from (23)
* Bodkin damage to vanguard to head increased to (99) from (98)
* Bodkin damage to vanguard to torso increased to (50) from (49)
* Bodkin damage to vanguard to legs increased to (33) from (32)
* Bodkin damage to man at arms to head increased to (107) from (104)
* Bodkin damage to man at arms to torso increased to (54) from (52)
* Bodkin damage to man at arms to legs increased to (35) from (34)
* Bodkin damage to archer to head decreased to (151) from (166)
* Bodkin damage to archer to torso increased to (100) from (97)
* Bodkin damage to archer to legs increased to (37) from (36)
* Arrow cam removed

Crossbow
* Arrow cam removed

Light Crossbow
* Arrow cam removed

Heavy Crossbow
* Arrow cam removed

Javelins
* Thrown damage to archer head decreased to (167) from (189)
* Arrow cam removed

Short Spears
* Thrown damage to archer head decreased to (155) from (176)
* Arrow cam removed

Heavy Javelins
* Thrown damage to archer head decreased to (215) from (243)
* Arrow cam removed

Sling
* Pebble minimum damage to archer head decreased to (45) from (50)
* Pebble maximum damage to archer head decreased to (74) from (84)
* Lead ball minimum damage to archer head decreased to (37) from (42)
* Lead ball maximum damage to archer head decreased to (104) from (118)
* Added zoom feature
* Arrow cam removed

#### OTHER GAMEPLAY CHANGES
* Removed stamina gain on teamkills

#### ADMINISTRATOR COMMANDS
All Modes
* Added 'AdminBroadcastMessage' command - will send chat message in yellow to all players
* AdminForceSpectate will alert you that you are not logged in as an administrator if you attempt to use it as a regular user
* AdminChangeTeam will alert you that you are not logged in as an administrator if you attempt to use it as a regular user
* AdminCancelVote will alert you that you are not logged in as an administrator if you attempt to use it as a regular user
* AdminReadyAll will alert you that you are not logged in as an administrator if you attempt to use it as a regular user
* AdminChangeTeamdDamageAmount will alert you that you are not logged in as an administrator if you attempt to use it as a regular user

Tournament Mode
* Tournament mode greeting message will no longer be sent on respawn

Normal Mode
* AdminForceSpectate will display in chat on use
* AdminChangeTeam will display in chat on use
* AdminCancelVote will display in chat on use
* AdminReadyAll will display in chat on use
* AdminChangeTeamdDamageAmount will display in chat on use

#### 1.1.1
+ Added `AdminForceSpectate` command (similar to `AdminChangeTeam`) which forces a player into spectate mode
+ Added `AdminGotoMoor` and `AdminGotoDF` commands, simply aliases for `AdminChangeMap AOCLTS-Moor_p` and `AdminChangeMap AOCTO-Darkforest_p` respectively
* Fixed not being able to parry shortly after dodge
* Falchion damage reduced (95 -> 90)
* Bardiche overhead release time decreased (0.6s -> 0.55s)
* Bardiche horizontal turncap while attacking nerfed (55000 -> 49500)
* FOV console command no longer requires weapon switch if above 120. Also introduces FOV cap of 165.
* You are no longer able to parry ballista bolts
* Improved projectile hit detection again (uses a directional system again rather than the parry tracer)
- Removed the invisible Mercs pitchfork which was selectable
- Removed standing health regen on king (now same as vanilla)
- Removed `CauseEvent` / `CE` admin commands

## 1.1.0
+ Fists always flinch
+ Added `GetAdmins` console command which tells you a list of logged-in admins
* F10 suicide delay reduced (5.0s -> 1.0s)
* Improved hit detection for projectiles
* Kick flinches (unless the other player has a shield raised)
* Shield heavy bash stuns a raised shield
* Spear overhead/long attack knockback reduced by 15% (31500 -> 26775)
* Halberd stab knockback reduced by 15% (35500 -> 30175)
* Longsword LMB damage reduced (84 -> 79)
* Norse sword stab damage reduced (59 -> 57)
* Bubble reduced (50 -> 39)
* Reduced weapon sheath times on all bows, crossbows and sling (0.5s -> 0.2s)
* Javelins can't be fliched while raised (fixes parry lockout issue)
- Disabled team flinch during pre-game warmup
- Removed PauseBreak exploit which allowed a non-admin to unpause


#### 1.0.2
* Firepots and smokepots are no longer parryable by non-shield weapons
- Projectiles don't flinch you if they hit a teammate

#### 1.0.1
* Projectiles can no longer be backparried
- Fists can no longer parry projectiles

# 1.0.0
+ Added the ability to parry projectiles with normal weapons (15 stamina)
+ If you attack a teammate, you get flinched (they still take damage)
+ Man-at-Arms is now locked out of attacking for 300ms after dodging
* ~~Reverted bubble size back to vanilla (50 -> 39)~~
* Raised SoW stab windup (0.65 -> 0.7)
* Raised SoW stab damage (68 -> 77.5)
* Raised SoW overhead windup (0.525 -> 0.55)
* Raised SoW combo speeds (all 0.675 -> 0.7)
- Removed the flinch/stun effect from kick
