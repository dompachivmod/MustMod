// deno test supabase/functions/ranked/matchmaking_test.ts
import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import { balance, eloDelta, expectedScore, pickLargestMatch, pickPlayers, type Player, roundMargin } from "./matchmaking.ts";

let nextId = 0;
function player(elo: number, games = 30): Player {
  return { steam_id: String(++nextId), name: `p${nextId}`, elo, games, wins: 0, losses: 0, draws: 0, leaves: 0 };
}

const hasLowVeteran = (ps: Player[]) => ps.some((p) => p.games > 15 && p.elo < 2000);
const hasElite = (ps: Player[]) => ps.some((p) => p.elo > 3000);

Deno.test("a low-Elo veteran is never matched with a 3000+ player", () => {
  const queue = [player(3100), player(1900), ...Array.from({ length: 8 }, () => player(2500))];
  const picked = pickPlayers(queue, 4)!;
  assert(!(hasLowVeteran(picked) && hasElite(picked)));
});

Deno.test("the rule does not apply with 15 games or fewer", () => {
  const queue = [player(3100), player(1900, 15), player(2500), player(2500)];
  const picked = pickPlayers(queue, 4)!;
  assertEquals(picked.length, 4);
});

Deno.test("16 games is past the exemption", () => {
  const queue = [player(3100), player(1900, 16), player(2500), player(2500)];
  assertEquals(pickPlayers(queue, 4), null);
});

Deno.test("exactly 2000 and exactly 3000 are allowed together", () => {
  const queue = [player(3000), player(2000), player(2500), player(2500)];
  assertEquals(pickPlayers(queue, 4)?.length, 4);
});

Deno.test("an early elite player does not strand a full match of low veterans", () => {
  const queue = [player(3100), ...Array.from({ length: 4 }, () => player(1800))];
  const picked = pickPlayers(queue, 4)!;
  assertEquals(picked.length, 4);
  assert(!hasElite(picked));
});

Deno.test("queue order is kept when nobody conflicts", () => {
  const queue = Array.from({ length: 6 }, () => player(2500));
  assertEquals(pickPlayers(queue, 4)!.map((p) => p.steam_id), queue.slice(0, 4).map((p) => p.steam_id));
});

Deno.test("balance finds the fairest 5v5 split", () => {
  const players = [3000, 2900, 2600, 2500, 2500, 2400, 2400, 2300, 2100, 2000].map((e) => player(e));
  const [a, b] = balance(players);
  assertEquals(a.length, 5);
  assertEquals(b.length, 5);
  const sum = (t: Player[]) => t.reduce((s, p) => s + p.elo, 0);
  // Total 24700 and every Elo is a multiple of 100, so 100 apart is the best possible.
  assertEquals(Math.abs(sum(a) - sum(b)), 100);
});

Deno.test("greedy balance above the exhaustive limit still gives equal sizes", () => {
  const players = Array.from({ length: 24 }, (_, i) => player(2000 + i * 37));
  const [a, b] = balance(players);
  assertEquals(a.length, 12);
  assertEquals(b.length, 12);
});

Deno.test("Elo: an even 7-5 moves 12 for veterans and 18 for new players", () => {
  assertEquals(expectedScore(2500, 2500), 0.5);
  // 7-5 between even teams: 6 per round x 2 rounds.
  assertEquals(eloDelta(30, 1, 0.5, 2), 12);
  assertEquals(eloDelta(30, 0, 0.5, 2), -12);
  assertEquals(eloDelta(3, 1, 0.5, 2), 18);
});

Deno.test("an upset pays more than a favourite's win", () => {
  const favourite = expectedScore(2700, 2500);
  // Same 3-round margin: 18 between even teams.
  assert(eloDelta(30, 1, 1 - favourite, 3) > 18);
  assert(eloDelta(30, 1, favourite, 3) < 18);
});

Deno.test("round margin", () => {
  assertEquals(roundMargin(1, 7, 5, false), 2);
  assertEquals(roundMargin(2, 0, 7, false), 7);
  assertEquals(roundMargin(0, 3, 3, false), 0);
  assertEquals(roundMargin(1, null, null, false), 1);
  // Surrender: deficit + 1, and at least 1 if the surrendering team was ahead.
  assertEquals(roundMargin(2, 1, 4, true), 4);
  assertEquals(roundMargin(2, 4, 3, true), 1);
});

Deno.test("match size follows the queue: 6 queued is a 3v3", () => {
  const queue = Array.from({ length: 6 }, () => player(2500));
  assertEquals(pickLargestMatch(queue, 1, 16)?.length, 6);
});

Deno.test("an odd queue leaves out the latest joiner", () => {
  const queue = Array.from({ length: 7 }, () => player(2500));
  const picked = pickLargestMatch(queue, 1, 16)!;
  assertEquals(picked.length, 6);
  assert(!picked.includes(queue[6]));
});

Deno.test("the max team size caps the match", () => {
  const queue = Array.from({ length: 12 }, () => player(2500));
  assertEquals(pickLargestMatch(queue, 1, 5)?.length, 10);
});

Deno.test("below the minimum there is no match", () => {
  const queue = Array.from({ length: 3 }, () => player(2500));
  assertEquals(pickLargestMatch(queue, 2, 16), null);
});

Deno.test("the skill-gap rule shrinks the match instead of blocking it", () => {
  // 1 elite + 1 low veteran + 4 normal: 6 together is illegal, a 4 or 5 player set is not.
  const queue = [player(3100), player(1900), ...Array.from({ length: 4 }, () => player(2500))];
  const picked = pickLargestMatch(queue, 1, 16)!;
  assertEquals(picked.length, 4);
  assert(!(hasLowVeteran(picked) && hasElite(picked)));
});
