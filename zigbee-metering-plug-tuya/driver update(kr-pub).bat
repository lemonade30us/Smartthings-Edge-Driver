@echo off

set driverPath=C:\Git\EdgeTest\03done\zigbee-metering-plug-tuya
set driverId=b4c3cf7c-c6a1-4d29-bb40-eb2e7bd519f7
set channelId=466d6a04-2717-4f79-9924-701afabe227b
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
