# Find the Groom — Old Town Prague, Friday 21 August 2026

**Play here:** https://slguich.github.io/stag-hunt/
**Organiser's control room:** https://slguich.github.io/stag-hunt/#admin

15 people · 3 teams of 5 · 18 pubs · one of them has a table reserved.

All pubs are in **Staré Město / Josefov (Prague 1)**, within about 800m.

---

## The short version (read this one out loud)

> One pub in Old Town has a table booked in Tom's name. Nobody's sitting in it —
> you have to find it.
>
> Walk to a pub, open the app, tap the pub you're standing in. If it's the
> wrong one, the app spins a wheel that decides what your team drinks there.
> Buy it, photograph it, move on. If it's the right one, you bank 5 points and
> keep playing.
>
> Most points at the end wins. Finding the table is worth the most, but so is
> covering ground. There are bananas. It'll make sense.

---

## For players

### Joining
Open the link, tap your team — **ALPHA**, **BRAVO** or **CHARLIE**. That's it:
no accounts, no passwords. Your phone remembers your team.

All five phones on a team share one game. If one person guesses, everyone on
that team sees the result within a few seconds.

### Guessing
The list shows all 18 pubs. Tap the one you are physically standing in, then
confirm. **You get one shot at each pub** — once your team has tried it, it's
struck off your list for good.

It's honour-system. There's no GPS. Fourteen mates are the enforcement.

### When you're wrong
The screen turns red: **NOT HERE**.

1. **Spin the wheel.** It decides your forfeit — how many of you drink and
   what. Everyone on your team sees the same result, so there's no arguing.
2. **Buy the round** and drink it.
3. **Photograph it** and upload — tap the big white button, it opens your
   camera.
4. **Then, and only then**, the next pub unlocks.

Both locks have to clear before you can guess again: the **cooldown timer**
(10 minutes by default — that's the drinking time) *and* the **photo**. If the
timer runs out and you haven't uploaded, the screen switches to
**📸 PROOF NEEDED** and stays there. No photo, no next pub.

**FREE PASS** is one of the wheel segments. Land on it and nobody drinks, and
no photo is owed — just wait out the timer and go.

### When you're right
Green screen: **YOU FOUND HIM**. +5 points, and the reserved table is yours —
have a drink there.

**The game does not end.** You keep hunting for points afterwards. Finding the
table early is a big lead, not a finish line.

### 🍌 Bananas
Each team gets **3 bananas**. Once you've drunk at a pub, a 🍌 button appears
next to it. Drop one and you've trapped that pub.

If a **rival team** later guesses a pub you trapped, their forfeit is
**DOUBLED** — and their screen names you as the culprit. Two teams trapping the
same pub makes it ×4.

Rivals can't see traps until they hit one. Choose the obvious pubs.

Note the risk: a doubled **FREE PASS** is still a free pass. Wasted banana.

### Scoring
| | Points |
|---|---|
| Finding the reserved table | **5** |
| Any other pub you drink at | **1** |
| A pub you drink at that a rival banana'd | **2** (or 4 if double-trapped) |

Getting banana'd costs you drink but *earns* you points. Suffering pays.

### The hint
After 4 wrong guesses, a team gets a hint (if the organiser has written one) —
usually narrowing it to a street.

### The end
The organiser ends the game (or it ends by itself once all three teams have
found the table). Every phone flips to the final leaderboard showing the pub,
the standings, and who found it.

Anyone who never found the table buys the groom a drink.

---

## For the organiser

Everything below lives at **`#admin`**, behind your passphrase.

> ⚠️ **Change the passphrase to something longer.** It's currently 3
> characters. Anyone with the game link can reach the admin endpoint, and short
> passphrases are guessable even with the built-in delay. Use the *Change admin
> passphrase* box.

### Before you start
1. **Reset everything** — clears every guess, banana, photo and rig from testing.
2. **Set the target bar.** The screen shouts at you in red until you do. With no
   target set, every guess comes back wrong and nobody can ever score the 5.
3. **Check the cooldown** — 10 minutes is the default and about right for
   actually finishing a drink.
4. Optionally write a **hint** and set how many wrong guesses unlock it.
5. Send the plain link to the group. Tell people their teams.

### What you can see
- **Team cards** — points, pubs tried, bananas left, photo compliance
  (📸 2/3), whether they're locked, on cooldown, or **⏳ owes proof**, plus
  the forfeit their last guess dealt them.
- **Live feed** — every guess as it happens: time, team, pub, the forfeit,
  🍌 if it was trapped, 🎯 if you rigged it, and a tap-to-open photo thumbnail.
- **Banana intel** — who trapped what (players never see this).

### What you can change mid-game
- **Target bar** — move it if the table has to move.
- **Cooldown** — shorten it if the night is dragging.
- **Hint text** and how many wrong guesses reveal it.
- **Wheel segments** — see below.
- **Forfeit wheel ON/OFF** — the mercy switch if people are getting wrecked.
  With it off, wrong guesses cost nothing but time and no photos are required.
- **Reveal rivals' pubs** — off by default (competitive). Turn it on late if
  nobody's close and you want the game to finish.

### Customising the wheel
The segment editor gives you one row per segment: name it, set its **share**,
mark it **FREE** (nobody drinks, no photo owed), or delete it. A live preview
shows the wheel as you type. Between 2 and 8 segments.

**Setting the odds.** Each segment has a share number and shows its resulting
percentage next to it. The easiest way to think about it: *make the shares add
up to 100 and they read straight as percentages.* The note under the preview
tells you the running total.

> Want beer at 50%? Set pints to `50` and let the other four be
> `13, 12, 13, 12`. Total 100, and the rows read 50% / 13% / 12% / 13% / 12%.

The wheel is drawn to match — a 50% segment physically takes up half the
circle, so the spin looks honest rather than landing on a suspiciously small
wedge. **Even odds** resets everything to an equal share.

Edits apply to *future* spins only. A team mid-forfeit keeps the result they
were already dealt — the wheel can't be used to retroactively change a round
someone is already drinking.

### A different wheel per pub
The **Which wheel** dropdown at the top of the Wheel tab picks what you're
editing: the **default wheel** (used everywhere) or a **single pub**. Choose a
pub, adjust its segments to whatever that place actually serves — Becherovka
Pilsner at U Zlatého tygra, a cocktail list at Hemingway — and save. Pubs with their own
wheel are marked ★ in the dropdown.

Selecting a pub with no override starts from a copy of the default, so you're
always editing something sensible. **Remove override** puts a pub back on the
default wheel.

Rigs follow the *name* of the segment you chose, so rigging "Shots" still
lands on Shots at a pub whose custom wheel lists them in a different order. If
that pub's wheel has no matching segment, the rig is dropped and the spin is
fair.

### 🎯 Rigging a spin
Pick a team, an outcome, and a drink count, then **Rig it**. Their *next wrong
guess* lands on exactly that, with the wheel spinning convincingly on the way.
The rig then clears itself. Active rigs are listed with a clear button, and
rigged results show 🎯 in your feed only.

Bananas still double a rigged result. Rigging the groom's brother for five
shots is between you and your conscience.

### Getting a team unstuck
**Unlock** clears both a team's cooldown *and* their photo debt. Use it when
someone's camera dies, an upload won't go through in a stone cellar, or a team
is stranded and the night needs to move.

### Ending it
**End game & reveal scores** flips all 15 phones to the leaderboard. Suggested
finish: around 23:00, everyone converges on the reserved table.

---

## Practical notes

**Signal.** Old Town cellar bars kill mobile data. The app handles it: guesses can
never be lost or double-counted, a failed send offers a safe retry, and the
screen tells you when it's showing stale data. If a phone seems stuck, walk
toward the door or pull down to refresh.

**Anyone can play from any phone** — five phones per team all show the same
state. If one person's battery dies, the team carries on.

**Busy pubs.** Old Town on a Friday night is much busier than Žižkov. The
admin screen flags three when you pick them as the target: U Zlatého tygra
(tiny locals' pub), Black Angel's (cellar, queues) and Hemingway Bar (small,
often needs a booking). They're all fine to *visit* — just risky as the
reserved-table pub. Book the table somewhere with room.

**Photos** are compressed on the phone before upload, so they go through on bad
signal and won't eat anyone's data.

---

## The pubs

All within about 10 minutes' walk of each other, all fine for a one-drink stop.

| Pub | Address |
|---|---|
| U Zlatého tygra | Husova 17 *(tiny, often full)* |
| U Tří růží | Husova 10 |
| U Medvídků | Na Perštýně 7 |
| U Vejvodů | Jilská 4 |
| AnonymouS Bar | Michalská 12 |
| Black Angel's Bar | Staroměstské nám. 29 *(cellar, can queue)* |
| U Dvou koček | Uhelný trh 10 |
| U Provaznice | Provaznická 3 |
| Pivnice Radegast | Templová 2 |
| Lokál Dlouhá | Dlouhá 33 |
| Prague Beer Museum | Dlouhá 46 |
| Kolkovna | V Kolkovně 8 |
| James Dean | V Kolkovně 1 |
| Pivnice U Pivrnce | Maiselova 3 |
| U Rudolfina | Křižovnická 10 |
| Hemingway Bar | Karoliny Světlé 26 *(small, may need booking)* |
| Konvikt Pub | Bartolomějská 11 |
| Bugsy's Bar | Pařížská 10 |

Every pub row has a 📍 button that opens it in Google Maps.

To add photos of the pubs, drop images into `bars/` — see `bars/README.md` for
the filenames.
