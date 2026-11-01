# RTSP-Firmware für die GNCC GT1 Pro

**[English version](README.md)**

Mach aus deiner GNCC GT1 Pro eine ganz normale Netzwerkkamera: RTSP-Stream, keine Cloud, keine App,
kein Konto, keine Verbindung ins Internet. Du brauchst nur eine microSD-Karte. Du musst die Kamera
nicht öffnen und nichts löten, und du brauchst keinen Linux-PC.

Paket auf eine Karte kopieren, WLAN eintragen, Karte in die Kamera, Strom an, etwa 3 Minuten warten.

## Was du bekommst

- **H.264 über RTSP**: `rtsp://<kamera>:8554/main` (2304×1296) und `/sub` (640×360), für VLC, ffmpeg,
  Frigate, Home Assistant, Scrypted, Blue Iris und andere
- **ONVIF**-Geräteerkennung
- **Nachtsicht in Schwarz-Weiß**: IR-LEDs und IR-Filter schalten von selbst um
- **Kein Weg nach draußen**: Die Kamera ignoriert Gateway und DNS-Server deines Routers und kommt
  deshalb nicht ins Internet, auch ohne Sperrregel im Router
- **Eigene Passwörter** auf jeder Kamera, zufällig erzeugt, wenn du keine vorgibst. Ein Standardpasswort
  gibt es nicht.
- **SSH-Zugang** als root, denn es ist deine Kamera
- **Mikrofon aus** in der Grundeinstellung
- **Eine vollständige Sicherung** des Flash auf deiner Karte, bevor sich irgendetwas ändert, und ein
  einfacher Weg zurück zur Originalfirmware

## Passt das zu deiner Kamera?

| | |
| --- | --- |
| Kamera | **GNCC GT1 Pro**, FCC-ID 2A3PR-GT1 |
| Getestet mit | Originalfirmware 7.3.37 |
| Karte | microSD, **FAT32**, mindestens 256 MB |
| WLAN | 2,4 GHz mit WPA2. WPA2/WPA3 gemischt geht, nur WPA3 nicht. |

Der Installer prüft die Kamera zuerst. Ist es ein anderes Modell oder eine Firmware, die er nicht kennt,
hält er an, sagt dir das und ändert nichts. Du kannst auch nur diese Prüfung laufen lassen: dafür in
`settings.txt` `CHECK_ONLY=yes` setzen.

## Installation

**1. Herunterladen.** Lade die Datei `gt1pro-rtsp-sdcard-*.zip` von den
[Releases](https://github.com/LarzVader/gncc-gt1-pro-rtsp/releases) und entpacke sie direkt auf die leere
Karte, sodass die Ordner `wifitest` und `rtsp-setup` ganz oben auf der Karte liegen.

**2. WLAN eintragen** in der Datei `settings.txt` auf der Karte:

```
WIFI_SSID=Name deines Netzes
WIFI_PASSWORD=dein Passwort
```

**3. Installieren.** Kamera ausschalten, Karte hinein, einschalten und etwa 3 Minuten in Ruhe lassen:

| LED | Bedeutung |
| --- | --- |
| Rot, dauerhaft | Sicherung und Bauen, etwa 1 Minute |
| Rot, schnell blinkend | Firmware wird geschrieben, etwa eine halbe Minute. **Nicht ausstecken.** |
| Blau, blinkend | die neue Firmware läuft und verbindet sich mit deinem WLAN |
| **Blau, dauerhaft** | **fertig**, die Kamera ist in deinem Netz |
| Rot und Blau im Wechsel | angehalten. Warum, steht in `RESULT.txt` auf der Karte. |

**4. Ergebnis lesen.** Kamera ausschalten, Karte herausnehmen und in den Computer stecken:

- `CAMERA-ACCESS-<Seriennummer>.txt`: Stream-Adressen und Passwörter
- `camera-ip.txt`: die Adresse der Kamera. Du findest sie auch in der Geräteliste deines Routers unter dem
  Namen `gt1pro`.

**5. Kopiere den Ordner `backup-<Seriennummer>` auf deinen Computer.** Er ist dein einziger Weg zurück zur
Originalfirmware. Er enthält private Daten deiner Kamera, etwa dein altes WLAN-Passwort und die
Cloud-Zertifikate: gib ihn nie weiter.

Die Karte kann ab jetzt draußen bleiben, die Kamera braucht sie nicht. Auf der Karte stehen dein
WLAN-Passwort und die Passwörter der Kamera. Bewahre sie also gut auf oder lösche `settings.txt` und
`CAMERA-ACCESS-*.txt`.

Noch mehr Kameras? Nimm einfach dieselbe Karte noch einmal, eine Kamera nach der anderen.

## Den Stream ansehen

```bash
ffplay -rtsp_transport tcp "rtsp://camera:PASSWORT@192.168.1.50:8554/main"
```

In VLC: *Medien → Netzwerkstream öffnen*, mit derselben Adresse.

Unter `http://<kamera>/` gibt es außerdem eine kleine Webseite, mit demselben Benutzernamen und Passwort.

## Gut zu wissen

- **Gib der Kamera eine feste Adresse** im Router, damit ihre Stream-Adresse gleich bleibt.
- **Die Bildrate liegt bei etwa 6 Bildern pro Sekunde** mit den Einstellungen des Pakets (`fps = 10`). So
  kann der Sensor nachts länger belichten, und das Bild rauscht deutlich weniger. Mit `fps = 15` sind es
  etwa 9 Bilder, nachts mit mehr Rauschen. Warum die echte Rate unter der Einstellung liegt, ist noch
  nicht geklärt.
- **Nachts wird das Bild alle 10 Minuten für etwa 5 Sekunden dunkel.** Die Kamera hat keinen Lichtsensor und
  schaltet deshalb ab und zu ihr IR-Licht aus, um zu prüfen, ob es schon Tag ist. `ir_peek_s` in `ipcd.conf`
  stellt den Abstand in Sekunden ein.
- **RTSP läuft nur über TCP.** Eine Anfrage nach UDP bekommt `461 Unsupported Transport`, und ffmpeg, VLC und
  die anderen wechseln dann von selbst auf TCP. Über WLAN würde UDP nur Pakete verlieren. `rtsp_udp = 1` in
  `ipcd.conf` erlaubt UDP trotzdem.
- **Die Uhr geht falsch**, weil die Kamera nicht ins Internet kommt und die Firmware keinen NTP-Client
  hat. Auf das Video hat das keinen Einfluss.
- **Nachtbilder sind schwarz-weiß.** Infrarotlicht hat keine Farbe, die der Sensor zeigen könnte, nur einen
  Lila-Stich. Darum nimmt die Firmware die Farbe heraus. Sobald die Kamera auf Tag schaltet, kommt sie von selbst zurück.
- **Drück die Reset-Taste nicht im laufenden Betrieb.** Sie ist nur für die Rettung beim Einschalten gedacht.
- Es gibt kein Einrichtungsportal: Diese Firmware öffnet nie einen eigenen WLAN-Zugangspunkt. Dein WLAN änderst
  du mit einer Datei auf der Karte, siehe [Fehlersuche](docs/troubleshooting.md#the-blue-led-keeps-blinking-the-camera-does-not-get-onto-the-wi-fi)
  (englisch).

## Wenn etwas schiefgeht

Lies [Troubleshooting and recovery](docs/troubleshooting.md) (englisch). Dort steht auch, wie du zur
Originalfirmware zurückkommst.

Der Installer schreibt nie auf U-Boot, den Teil der Kamera, der alles startet. U-Boot hat einen eigenen
Updater, der mit der Reset-Taste funktioniert, egal was sonst im Flash steht. Eine schiefgegangene
Installation lässt sich deshalb fast immer mit einer Karte reparieren.

## Wieso das erlaubt ist

Eine Firmware für diese Kamera braucht Dateien, die nicht frei sind, etwa die Medienbibliotheken des
Chipherstellers und den Treiber für den Sensor. Die darf niemand veröffentlichen, ein fertiges Firmware-Abbild
kann es also nicht geben. Aber sie liegen schon auf deiner Kamera. Deshalb **enthält dieses Paket keine
Herstellerdateien**: Es enthält die freien Teile, und deine Kamera baut sich die Firmware selbst zusammen, aus
ihren eigenen Dateien. Das Ergebnis wird Bit für Bit mit der getesteten Firmware verglichen.

Wie das funktioniert und was sonst anders ist als bei der Originalfirmware: [How it works](docs/how-it-works.md).
Selbst bauen: [Building](docs/building.md).

## Risiken

Du ersetzt die Firmware eines Geräts, auf eigene Gefahr und nur bei einer Kamera, die dir gehört. Du verlierst
die Garantie und die Cloud-Funktionen der App. Die Firmware läuft bisher auf zwei Kameras. Der Installer lief auf
einer davon, mit Version 1.0 und einer CONFIG-Sicherung ohne WLAN-Daten und ohne Cloud-Daten der Originalfirmware. Der
Rückweg hat dort die Originalfirmware geschrieben und geprüft, aber niemand hat sie danach laufen sehen. Das ist nicht viel. Hat es bei dir geklappt oder nicht? Sag bitte in einem [Issue](https://github.com/LarzVader/gncc-gt1-pro-rtsp/issues)
Bescheid, mit deiner Firmware-Version.

## Danke

Dieses Projekt baut auf der Arbeit anderer auf:

- **[akost-firmware](https://github.com/michelostojski/akost-firmware)** von Michel Ostojski (MIT): die freie
  Firmware für diesen Chip und die Unterstützung für diese Kamera. Dieses Projekt ist ein Fork davon. Das Schwierige
  wurde dort gemacht.
- **[ipcd](https://github.com/medevil84/ipcd)** von medevil (MIT): das Programm, das die eigentliche Kameraarbeit
  macht, mit RTSP, ONVIF und der Webseite.
- **[thingino](https://github.com/themactep/thingino-firmware)**: das Vorbild dafür, wie sich eine Kamera-Firmware
  selbst aktualisieren sollte.
- **[TECKIN-TC100 Anyka hacks](https://github.com/ThatUsernameAlreadyExist/TECKIN-TC100-Anyka-AK3918-camera-hacks)**:
  der SD-Karten-Einstieg, der ohne Werkzeug die Tür öffnet.
- Die GPL-Quellen im [Tuya BSP](https://github.com/tuya/tuya-bsp-gpl-public-components): Kernel und Werkzeugkette.
- Wesentliche Durchbrüche in diesem Projekt, vom Installer, der die Firmware auf der Kamera baut, über die
  Korrekturen in `ipcd` bis zu dieser Anleitung, sind zusammen mit einer KI entstanden.

## Lizenz

Die Arbeit in diesem Projekt steht unter der [MIT-Lizenz](LICENSE). Das Paket enthält außerdem Software anderer
unter deren eigenen Lizenzen. [THIRD-PARTY.md](THIRD-PARTY.md) listet sie auf und sagt, was im Quellpaket jedes Release liegt.
