@echo off

set driverPath=C:\Git\EdgeTest\03done\zigbee-multichannel-goqual-custom
set driverId=99b36b1a-df92-4984-a54d-05efd0c577ec
set channelId=736c6820-f9e6-44e7-927c-22d8464032f5
set hubId=c3580cf5-4a4b-4c14-9466-21ea125e7da8
set hub_address=192.168.1.10


echo Packaging Driver...
smartthings edge:drivers:package "%driverPath%"

echo:
echo Publishing Driver to Channel...
smartthings edge:drivers:publish %driverId% --channel %channelId%

echo:
echo Installing Driver...
smartthings edge:drivers:install %driverId% --channel %channelId% --hub %hubId%
smartthings edge:drivers:logcat %driverId% --hub-address=%hub_address%
