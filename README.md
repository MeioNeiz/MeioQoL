# Meio QoL

Less clicking at vendors and NPCs: water and reagents topped up, guild repairs paid and NPC
chat skipped, each one a switch.

For WoW Forever.

![A vendor beside your backpack: before, the backpack still holds 4 Morning Glory Dew;
with Meio QoL it holds 20 the moment the vendor opens, and chat says "restocked 16 Morning
Glory Dew"](docs/before-after.png)

## What it does

Small automations for things you do many times a day. Each one can be turned off, and
holding Shift at an NPC skips them for that visit.

- **Skip NPC chat**: an NPC with no quests and one chat option picks it for you (vendors,
  trainers, bankers and innkeepers too, if you want)

![Himmik's one chat option: before, "Let me browse your goods" waits for a click; with Meio
QoL the vendor opens straight to its goods](docs/gossip.png)

- **Restock at vendors**: Alt-click an item at a vendor to keep a stack of it; every vendor
  that sells it tops it up, never taking your gold below a reserve you set
- **Guild-funded repair**: repairs from the guild bank when your rank may
- **Accept resurrection**: a resurrection from your group is accepted once the caster is out
  of combat

![Elanya's resurrection: before, the Accept and Decline box; with Meio QoL, accepted for you and
one chat line saying who](docs/resurrection.png)

- **Faster auto loot**: every item taken the moment the loot is ready, without waiting on
  the loot window (it still shows when something is left: bags full, a roll)
- **Group invites**: the inviter's level, class and zone above Accept and Decline; decline
  strangers with a reason if you want (friends, guild and group finder still pop up)
- **Accept summons**: accepted 5 seconds after you are out of combat; Cancel to stay
- **Restock from the bank** and a **low supplies warning** when restock items drop to a
  quarter
- **Vendors and travel**: instant flight map, Shift-click buys many at once, a wider vendor
  window
- Off until you want them: auto repair from your gold, skip bind prompts, farther camera,
  fishing sounds, auto quest accept and turn-in

![Group invite with a line above Accept and Decline: Level 22 Warrior in
Westfall](docs/soon.png)

Works on its own or beside FlareUI: where FlareUI has the same tweak switched on, ours waits
and one line at login says so. `/qol takeover` hands them to Meio QoL, `/qol flare` gives
them back.

Settings: Esc > Options > AddOns > MeioQoL, or `/qol`.

- `/qol help`: every command and what's on
- `/qol gossip on|off`, `services`, `taxi`, `accept`, `turnin`, `repair`, `guildrepair`,
  `bulk`, `wide`, `restock`, `bank`, `low`, `loot`, `confirm`, `res`, `summon`, `inviter`,
  `invites`, `friends`, `fishsound`: each feature
- `/qol invitereason <text>`: whisper this when declining an invite
- `/qol camera on|off` or `/qol camera <distance> <speed>`: farther camera
- `/qol takeover`, `/qol flare`: Meio QoL or FlareUI runs the tweaks you both have
- `/qol restock <item> <n>`: keep n of an item, 0 to stop; `/qol restock` lists them
- `/qol reserve <gold>`: restocking never takes your gold below this

## Install

Use your addon manager (CurseForge, Wago), or unzip a GitHub release into
`World of Warcraft\_forever_\Interface\AddOns` and restart WoW fully.

## Feedback

Bugs, ideas or just a thumbs up: leave a comment on the CurseForge or Wago page you got it from. [GitHub issues](https://github.com/MeioNeiz/MeioQoL/issues) are welcome too.

## More Meio addons

[Meio Trainer Compare](https://www.curseforge.com/wow/addons/trainercompare) | [Meio Next Stop](https://www.curseforge.com/wow/addons/leavebutton) | [Meio Auto Rank](https://www.curseforge.com/wow/addons/meio-autorank) | [Meio Meter Hover](https://www.curseforge.com/wow/addons/meterhover) | [Meio Map](https://addons.wago.io/addons/meiomap) | [Meio Alts](https://addons.wago.io/addons/meioalts) | [Meio DPS](https://addons.wago.io/addons/meiodps) | [Meio Nameplates](https://addons.wago.io/addons/meioplates) | [Meio Hub](https://addons.wago.io/addons/meiohub) | [Meio Pets](https://addons.wago.io/addons/meiopets) | [Meio Stats](https://addons.wago.io/addons/meiostats) | [Meio Bags](https://addons.wago.io/addons/meiobags) | [Meio Fixes](https://addons.wago.io/addons/meiofixes) | [Meio Flight Times](https://addons.wago.io/addons/meioflighttimes) | [Meio Tooltips](https://addons.wago.io/addons/meiotooltipfold) | [Meio Autorun](https://addons.wago.io/addons/meioautorunturn) | [Meio Mail](https://addons.wago.io/addons/meiomail) | [Meio TSM Browse](https://addons.wago.io/addons/tsmbrowse) | [Meio Shards](https://addons.wago.io/addons/meioshards) | [Meionomics](https://www.curseforge.com/wow/addons/meionomics) | [Meio Spike Check](https://addons.wago.io/addons/meiospikecheck) | [Meio BiS Extras](https://addons.wago.io/addons/meiobisextras) | [Meio Buff Thanks](https://addons.wago.io/addons/meiobuffthanks) | [Meio Flare Fixes](https://addons.wago.io/addons/meioflarefixes) | [Meio Flare Questie](https://addons.wago.io/addons/meioflarequestie)

## Licence

[MIT](LICENSE)
