GT1 Pro RTSP firmware: installation
===================================

This card turns a GNCC GT1 Pro into a plain RTSP camera without cloud, app or
account. It first saves a backup of the camera's flash on this card. You can do
this on a closed camera, without any tools.

1. Open settings.txt and enter the name and password of your Wi-Fi.

2. Power the camera off. Put this card into the camera. Power the camera on.

3. Wait, and do not unplug the camera. This takes about 3 minutes:

     red LED steady          backup and building, about 1 minute
     red LED blinking fast   writing the firmware, about half a minute
     blue LED blinking       new firmware, connecting to your Wi-Fi
     blue LED steady         done, the camera is on your network

     red and blue in turns   stopped: read RESULT.txt on this card

4. Power the camera off, take out the card and read these on your computer:

     CAMERA-ACCESS-<serial number>.txt   stream addresses and passwords
     camera-ip.txt                       the address of the camera

   Your stream:  rtsp://camera:PASSWORD@ADDRESS:8554/main

5. Copy the folder backup-<serial number> to your computer. It is your only way
   back to the stock firmware. It holds private data of your camera, like the old
   Wi-Fi password and the cloud certificates: never share it.

This card now holds your Wi-Fi password and your camera passwords. Keep it safe, or
delete settings.txt and CAMERA-ACCESS-*.txt once you have noted them.

More cameras: use the same card again, one camera after the other.

Going back to the stock firmware, problems, details:
https://github.com/LarzVader/gncc-gt1-pro-rtsp
