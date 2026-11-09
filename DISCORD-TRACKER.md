# Automatic Discord tracking

The normal loader-beyy.lua starts the passive Discord tracker automatically after the hub is running, including reuse of an existing hub. It stops the tracker on hub unload and avoids duplicate observers. No separate tracker loadstring is required.

Private settings are read from Geode/tracker_config.json in the executor workspace. No bot token or upload key is embedded in this public source. The connected Potassium client is already configured.

Status is shown under Discord → Tracker Status. PetEvents and PetDrop are watched wherever those remotes exist. The five native global boards refresh when Workspace.LobbyMap.Boards exists, copying ranks, team labels, abbreviated scores and race times as displayed for the currently loaded view. In run places without lobby boards, Discord retains the last observation. No game remotes are fired and no tabs are switched.

The main gameplay file is unchanged; the automatic startup hook lives in the loader. The tracker is an observed client feed, not independent verification of awards. Use the normal cache-busted loader-beyy.lua URL when launching.
