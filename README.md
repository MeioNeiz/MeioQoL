# Meio QoL

Less clicking at NPCs and after dying: chat skipped, items restocked, repairs paid, loot
taken at once.

For WoW Forever.

![A vendor with 4 Morning Glory Dew in your bags: before, nothing happens until you buy by
hand; with MeioQoL, "restocked 16 Morning Glory Dew" the moment it opens](docs/before-after.png)

## What it does

Small automations for things you do many times a day. Each one can be turned off, and
holding Shift at an NPC skips them for that visit.

- **Skip NPC chat**: an NPC with no quests and one chat option picks it for you (vendors,
  trainers, bankers and innkeepers too, if you want)
- **Restock at vendors**: Alt-click an item at a vendor to keep a stack of it; every vendor
  that sells it tops it up, never taking your gold below a reserve you set
- **Guild-funded repair**: repairs from the guild bank when your rank may
- **Accept resurrection**: a resurrection from your group is accepted once the caster is out
  of combat
- **Faster auto loot**: every item taken the moment the loot is ready, without waiting on
  the loot window (it still shows when something is left: bags full, a roll)

Works on its own or beside FlareUI: FlareUI's auto repair still pays what the guild doesn't,
and FlareUI's Faster Auto Loot is turned off once so the two don't both loot.

Settings: Esc > Options > AddOns > MeioQoL, or `/qol`.

- `/qol help`: every command and what's on
- `/qol gossip on|off`, `services`, `res`, `guildrepair`, `restock`, `loot`: each feature
- `/qol restock <item> <n>`: keep n of an item, 0 to stop; `/qol restock` lists them
- `/qol reserve <gold>`: restocking never takes your gold below this

## Install

Use your addon manager (CurseForge, Wago), or unzip a GitHub release into
`World of Warcraft\_forever_\Interface\AddOns` and restart WoW fully.

## Feedback

Bugs and ideas: [GitHub issues](https://github.com/MeioNeiz/MeioQoL/issues)

## More Meio addons

[Meio Trainer Compare](https://www.curseforge.com/wow/addons/trainercompare) | [Meio Next Stop](https://www.curseforge.com/wow/addons/leavebutton) | [Meio Auto Rank](https://www.curseforge.com/wow/addons/meio-autorank) | [Meio Meter Hover](https://www.curseforge.com/wow/addons/meterhover) | [Meio Map](https://addons.wago.io/addons/meiomap) | [Meio Alts](https://addons.wago.io/addons/meioalts) | [Meio DPS](https://addons.wago.io/addons/meiodps) | [Meio Plates](https://addons.wago.io/addons/meioplates) | [Meio Hub](https://addons.wago.io/addons/meiohub) | [Meio Pets](https://addons.wago.io/addons/meiopets) | [Meio Stats](https://addons.wago.io/addons/meiostats) | [Meio Bags](https://addons.wago.io/addons/meiobags) | [Meio Fixes](https://addons.wago.io/addons/meiofixes) | [Meio Flight Times](https://addons.wago.io/addons/meioflighttimes) | [Meio Tooltip Fold](https://addons.wago.io/addons/meiotooltipfold) | [Meio Auto Run Turn](https://addons.wago.io/addons/meioautorunturn) | [Meio Mail](https://addons.wago.io/addons/meiomail) | [Meio TSM Browse](https://addons.wago.io/addons/tsmbrowse) | [Meio Shards](https://addons.wago.io/addons/meioshards) | [Meionomics](https://addons.wago.io/addons/meionomics)

## Licence

[MIT](LICENSE)
