# Cake's Screenshare

Cake's Screenshare is a Dalamud plugin for FFXIV that streams your screen or a single window, with its audio,
to everyone in a room. People in the room watch it in a pop-out window, or on a screen
you place in the game world. Streams travel through a relay server through specified rooms.

## Share your screen your way
1. Create a room (public or private, with an optional password) or join one.
2. In Settings, choose a monitor or a window, plus either all system audio or just one app.
   Then press Go live.
3. Press Place screen here to put the screen in the world where you're standing.
   Everyone in the room sees it in the same spot automatically.

Viewers can also click your name to watch in a pop-out window. The video is encoded on your
graphics card where possible, with Media Foundation or libavcodec (NVENC, AMF, or QSV).

## Installation
1. /xlsettings → Experimental → Custom Plugin Repositories, add the URL:
``https://raw.githubusercontent.com/CakeAndBanana/Screenshare/main/repo.json``
2. /xlplugins, search for ScreenShare and install it
3. /screenshare, enter the relay address and a display name, then connect

## Public Relay Server

I am still working on the plugin, and it's not fully completed.

I am providing a public relay server for now; the URL is:
``https://relay.cakeandbanana.nl/hubs/room``
