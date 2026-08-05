# Baseline Report — FreeRDP Touch for OneMix 3

**Generated:** 2026-08-05T18:45:05Z
**Phase:** 01-environment-gate-build-baseline

## Session

- **Type:** XDG_SESSION_TYPE=<unset>
- **Display:** :0
- **Xorg processes:** 1758 /usr/lib/xorg/Xorg vt2 -displayfd 3 -auth /run/user/1000/gdm/Xauthority -nolisten tcp -background none -noreset -keeptty -novtswitch -verbose 3
- **Xwayland processes:** (none)

## Window Manager

- **WM:** GNOME Shell

## Installed Package (Before)

```
freerdp3-x11 3.15.0+dfsg-2.1+deb13u3 amd64
```

## Source Version

```
3.15.0+dfsg-2.1+deb13u3
```

## Touch Device

```
⎡ Virtual core pointer                    	id=2	[master pointer  (3)]
⎜   ↳ Virtual core XTEST pointer              	id=4	[slave  pointer  (2)]
⎜   ↳ HAILUCK CO.,LTD USB KEYBOARD Mouse      	id=11	[slave  pointer  (2)]
⎜   ↳ GXTP7386:00 27C6:0113                   	id=17	[slave  pointer  (2)]
⎜   ↳ GXTP7386:00 27C6:0113 Stylus stylus     	id=15	[slave  pointer  (2)]
⎜   ↳ GXTP7386:00 27C6:0113 Stylus eraser     	id=19	[slave  pointer  (2)]
⎣ Virtual core keyboard                   	id=3	[master keyboard (2)]
    ↳ Virtual core XTEST keyboard             	id=5	[slave  keyboard (3)]
    ↳ HAILUCK CO.,LTD USB KEYBOARD            	id=10	[slave  keyboard (3)]
    ↳ Sleep Button                            	id=9	[slave  keyboard (3)]
    ↳ HAILUCK CO.,LTD USB KEYBOARD System Control	id=12	[slave  keyboard (3)]
    ↳ Video Bus                               	id=7	[slave  keyboard (3)]
    ↳ AT Translated Set 2 keyboard            	id=18	[slave  keyboard (3)]
    ↳ Power Button                            	id=8	[slave  keyboard (3)]
    ↳ HAILUCK CO.,LTD USB KEYBOARD Wireless Radio Control	id=14	[slave  keyboard (3)]
    ↳ Power Button                            	id=6	[slave  keyboard (3)]
    ↳ HAILUCK CO.,LTD USB KEYBOARD Consumer Control	id=13	[slave  keyboard (3)]
    ↳ GXTP7386:00 27C6:0113 Keyboard          	id=16	[slave  keyboard (3)]
```

```
⎡ Virtual core pointer                    	id=2	[master pointer  (3)]
	Reporting 6 classes:
		Class originated from: 17. Type: XIButtonClass
		Buttons supported: 10
		Button labels: "Button Left" "Button Middle" "Button Right" "Button Wheel Up" "Button Wheel Down" "Button Horiz Wheel Left" "Button Horiz Wheel Right" None None None
		Button state:
		Class originated from: 17. Type: XIValuatorClass
		Detail for Valuator 0:
		  Label: Abs MT Position X
		  Range: 0.000000 - 65535.000000
		  Resolution: 0 units/m
		  Mode: absolute
		  Current value: 6061.093721
		Class originated from: 17. Type: XIValuatorClass
		Detail for Valuator 1:
		  Label: Abs MT Position Y
		  Range: 0.000000 - 65535.000000
		  Resolution: 0 units/m
		  Mode: absolute
		  Current value: 7703.977739
		Class originated from: 17. Type: XIValuatorClass
		Detail for Valuator 2:
		  Label: Rel Horiz Scroll
		  Range: -1.000000 - -1.000000
		  Resolution: 0 units/m
		  Mode: relative
		Class originated from: 17. Type: XIValuatorClass
		Detail for Valuator 3:
		  Label: Rel Vert Scroll
		  Range: -1.000000 - -1.000000
		  Resolution: 0 units/m
		  Mode: relative
		Class originated from: 17. Type: XITouchClass
		Touch mode: direct
		Max number of touches: 10

⎜   ↳ Virtual core XTEST pointer              	id=4	[slave  pointer  (2)]
	Reporting 3 classes:
		Class originated from: 4. Type: XIButtonClass
		Buttons supported: 10
		Button labels: "Button Left" "Button Middle" "Button Right" "Button Wheel Up" "Button Wheel Down" "Button Horiz Wheel Left" "Button Horiz Wheel Right" None None None
		Button state:
		Class originated from: 4. Type: XIValuatorClass
		Detail for Valuator 0:
		  Label: Rel X
		  Range: -1.000000 - -1.000000
		  Resolution: 0 units/m
		  Mode: relative
		Class originated from: 4. Type: XIValuatorClass
		Detail for Valuator 1:
		  Label: Rel Y
		  Range: -1.000000 - -1.000000
		  Resolution: 0 units/m
		  Mode: relative

⎜   ↳ HAILUCK CO.,LTD USB KEYBOARD Mouse      	id=11	[slave  pointer  (2)]
	Reporting 7 classes:
		Class originated from: 11. Type: XIButtonClass
		Buttons supported: 7
		Button labels: "Button Left" "Button Middle" "Button Right" "Button Wheel Up" "Button Wheel Down" "Button Horiz Wheel Left" "Button Horiz Wheel Right"
		Button state:
		Class originated from: 11. Type: XIValuatorClass
		Detail for Valuator 0:
		  Label: Rel X
		  Range: -1.000000 - -1.000000
		  Resolution: 0 units/m
		  Mode: relative
		Class originated from: 11. Type: XIValuatorClass
		Detail for Valuator 1:
		  Label: Rel Y
		  Range: -1.000000 - -1.000000
		  Resolution: 0 units/m
		  Mode: relative
		Class originated from: 11. Type: XIValuatorClass
		Detail for Valuator 2:
		  Label: Rel Horiz Scroll
		  Range: -1.000000 - -1.000000
		  Resolution: 0 units/m
		  Mode: relative
		Class originated from: 11. Type: XIValuatorClass
		Detail for Valuator 3:
		  Label: Rel Vert Scroll
		  Range: -1.000000 - -1.000000
		  Resolution: 0 units/m
		  Mode: relative
		Class originated from: 11. Type: XIScrollClass
		Scroll info for Valuator 2
		  type: 2 (horizontal)
		  increment: 120.000000
		  flags: 0x0
		Class originated from: 11. Type: XIScrollClass
		Scroll info for Valuator 3
		  type: 1 (vertical)
		  increment: 120.000000
		  flags: 0x0

⎜   ↳ GXTP7386:00 27C6:0113                   	id=17	[slave  pointer  (2)]
	Reporting 6 classes:
		Class originated from: 17. Type: XIButtonClass
		Buttons supported: 7
		Button labels: "Button Left" "Button Middle" "Button Right" "Button Wheel Up" "Button Wheel Down" "Button Horiz Wheel Left" "Button Horiz Wheel Right"
		Button state:
		Class originated from: 17. Type: XIValuatorClass
		Detail for Valuator 0:
		  Label: Abs MT Position X
		  Range: 0.000000 - 65535.000000
		  Resolution: 0 units/m
		  Mode: absolute
		  Current value: 6061.093721
		Class originated from: 17. Type: XIValuatorClass
		Detail for Valuator 1:
		  Label: Abs MT Position Y
		  Range: 0.000000 - 65535.000000
		  Resolution: 0 units/m
		  Mode: absolute
		  Current value: 7703.977739
		Class originated from: 17. Type: XIValuatorClass
		Detail for Valuator 2:
		  Label: Rel Horiz Scroll
		  Range: -1.000000 - -1.000000
		  Resolution: 0 units/m
		  Mode: relative
		Class originated from: 17. Type: XIValuatorClass
		Detail for Valuator 3:
		  Label: Rel Vert Scroll
		  Range: -1.000000 - -1.000000
		  Resolution: 0 units/m
		  Mode: relative
		Class originated from: 17. Type: XITouchClass
		Touch mode: direct
		Max number of touches: 10

⎜   ↳ GXTP7386:00 27C6:0113 Stylus stylus     	id=15	[slave  pointer  (2)]
	Reporting 12 classes:
		Class originated from: 15. Type: XIButtonClass
		Buttons supported: 8
		Button labels: None None None None None None None None
		Button state:
		Class originated from: 15. Type: XIKeyClass
		Keycodes supported: 248
		Class originated from: 15. Type: XIValuatorClass
		Detail for Valuator 0:
		  Label: Abs X
		  Range: 0.000000 - 5120.000000
		  Resolution: 28000 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 15. Type: XIValuatorClass
		Detail for Valuator 1:
		  Label: Abs Y
		  Range: 0.000000 - 3200.000000
		  Resolution: 28000 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 15. Type: XIValuatorClass
		Detail for Valuator 2:
		  Label: Abs Pressure
		  Range: 0.000000 - 65536.000000
		  Resolution: 1 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 15. Type: XIValuatorClass
		Detail for Valuator 3:
		  Label: Abs Tilt X
		  Range: -64.000000 - 63.000000
		  Resolution: 57 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 15. Type: XIValuatorClass
		Detail for Valuator 4:
		  Label: Abs Tilt Y
		  Range: -64.000000 - 63.000000
		  Resolution: 57 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 15. Type: XIValuatorClass
		Detail for Valuator 5:
		  Label: Abs Wheel
		  Range: -900.000000 - 899.000000
		  Resolution: 1 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 15. Type: XIValuatorClass
		Detail for Valuator 6:
		  Label: Rel Horiz Scroll
		  Range: -1.000000 - -1.000000
		  Resolution: 1 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 15. Type: XIValuatorClass
		Detail for Valuator 7:
		  Label: Rel Vert Scroll
		  Range: -1.000000 - -1.000000
		  Resolution: 1 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 15. Type: XIScrollClass
		Scroll info for Valuator 6
		  type: 2 (horizontal)
		  increment: 65535.000000
		  flags: 0x0
		Class originated from: 15. Type: XIScrollClass
		Scroll info for Valuator 7
		  type: 1 (vertical)
		  increment: 65535.000000
		  flags: 0x0

⎜   ↳ GXTP7386:00 27C6:0113 Stylus eraser     	id=19	[slave  pointer  (2)]
	Reporting 12 classes:
		Class originated from: 19. Type: XIButtonClass
		Buttons supported: 8
		Button labels: None None None None None None None None
		Button state:
		Class originated from: 19. Type: XIKeyClass
		Keycodes supported: 248
		Class originated from: 19. Type: XIValuatorClass
		Detail for Valuator 0:
		  Label: Abs X
		  Range: 0.000000 - 5120.000000
		  Resolution: 28000 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 19. Type: XIValuatorClass
		Detail for Valuator 1:
		  Label: Abs Y
		  Range: 0.000000 - 3200.000000
		  Resolution: 28000 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 19. Type: XIValuatorClass
		Detail for Valuator 2:
		  Label: Abs Pressure
		  Range: 0.000000 - 65536.000000
		  Resolution: 1 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 19. Type: XIValuatorClass
		Detail for Valuator 3:
		  Label: Abs Tilt X
		  Range: -64.000000 - 63.000000
		  Resolution: 57 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 19. Type: XIValuatorClass
		Detail for Valuator 4:
		  Label: Abs Tilt Y
		  Range: -64.000000 - 63.000000
		  Resolution: 57 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 19. Type: XIValuatorClass
		Detail for Valuator 5:
		  Label: None
		  Range: -1.000000 - -1.000000
		  Resolution: 0 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 19. Type: XIValuatorClass
		Detail for Valuator 6:
		  Label: Rel Horiz Scroll
		  Range: -1.000000 - -1.000000
		  Resolution: 1 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 19. Type: XIValuatorClass
		Detail for Valuator 7:
		  Label: Rel Vert Scroll
		  Range: -1.000000 - -1.000000
		  Resolution: 1 units/m
		  Mode: absolute
		  Current value: 0.000000
		Class originated from: 19. Type: XIScrollClass
		Scroll info for Valuator 6
		  type: 2 (horizontal)
		  increment: 65535.000000
		  flags: 0x0
		Class originated from: 19. Type: XIScrollClass
		Scroll info for Valuator 7
		  type: 1 (vertical)
		  increment: 65535.000000
		  flags: 0x0

⎣ Virtual core keyboard                   	id=3	[master keyboard (2)]
	Reporting 1 classes:
		Class originated from: 10. Type: XIKeyClass
		Keycodes supported: 248

    ↳ Virtual core XTEST keyboard             	id=5	[slave  keyboard (3)]
	Reporting 1 classes:
		Class originated from: 5. Type: XIKeyClass
		Keycodes supported: 248

    ↳ HAILUCK CO.,LTD USB KEYBOARD            	id=10	[slave  keyboard (3)]
	Reporting 1 classes:
		Class originated from: 10. Type: XIKeyClass
		Keycodes supported: 248

    ↳ Sleep Button                            	id=9	[slave  keyboard (3)]
	Reporting 1 classes:
		Class originated from: 9. Type: XIKeyClass
		Keycodes supported: 248

    ↳ HAILUCK CO.,LTD USB KEYBOARD System Control	id=12	[slave  keyboard (3)]
	Reporting 1 classes:
		Class originated from: 12. Type: XIKeyClass
		Keycodes supported: 248

    ↳ Video Bus                               	id=7	[slave  keyboard (3)]
	Reporting 1 classes:
		Class originated from: 7. Type: XIKeyClass
		Keycodes supported: 248

    ↳ AT Translated Set 2 keyboard            	id=18	[slave  keyboard (3)]
	Reporting 1 classes:
		Class originated from: 18. Type: XIKeyClass
		Keycodes supported: 248

    ↳ Power Button                            	id=8	[slave  keyboard (3)]
	Reporting 1 classes:
		Class originated from: 8. Type: XIKeyClass
		Keycodes supported: 248

    ↳ HAILUCK CO.,LTD USB KEYBOARD Wireless Radio Control	id=14	[slave  keyboard (3)]
	Reporting 1 classes:
		Class originated from: 14. Type: XIKeyClass
		Keycodes supported: 248

    ↳ Power Button                            	id=6	[slave  keyboard (3)]
	Reporting 1 classes:
		Class originated from: 6. Type: XIKeyClass
		Keycodes supported: 248

    ↳ HAILUCK CO.,LTD USB KEYBOARD Consumer Control	id=13	[slave  keyboard (3)]
	Reporting 1 classes:
		Class originated from: 13. Type: XIKeyClass
		Keycodes supported: 248

    ↳ GXTP7386:00 27C6:0113 Keyboard          	id=16	[slave  keyboard (3)]
	Reporting 1 classes:
		Class originated from: 16. Type: XIKeyClass
		Keycodes supported: 248
```

## Display

```
Screen 0: minimum 320 x 200, current 2560 x 1600, maximum 16384 x 16384
eDP-1 connected primary 2560x1600+0+0 left (normal left inverted right x axis y axis) 113mm x 181mm
   1600x2560     55.92*+
HDMI-1 disconnected (normal left inverted right x axis y axis)
DP-1 disconnected (normal left inverted right x axis y axis)
HDMI-2 disconnected (normal left inverted right x axis y axis)
DP-2 disconnected (normal left inverted right x axis y axis)
HDMI-3 disconnected (normal left inverted right x axis y axis)
```

**Active mode:**
```
eDP-1 connected primary 2560x1600+0+0 left (normal left inverted right x axis y axis) 113mm x 181mm
HDMI-1 disconnected (normal left inverted right x axis y axis)
DP-1 disconnected (normal left inverted right x axis y axis)
HDMI-2 disconnected (normal left inverted right x axis y axis)
DP-2 disconnected (normal left inverted right x axis y axis)
HDMI-3 disconnected (normal left inverted right x axis y axis)
```

**DPI:**
```
RESOURCE_MANAGER(STRING) = "*customization:\t-color\nXft.dpi:\t192\nXft.antialias:\t1\nXft.hinting:\t1\nXft.hintstyle:\thintslight\nXft.rgba:\tnone\nXcursor.size:\t48\nXcursor.theme:\tAdwaita\n"
```

## Build

- **Artifact:** `freerdp3-x11_3.15.0+dfsg-2.1+deb13u3_amd64.deb`
- **SHA-256:** `b4486501e2391560958e8b010372ec4e395c48a3fa6e44a9a6f7e0e0ee7d03fc`
- **Build command:** `dpkg-buildpackage -us -uc -b -j$(nproc)`

## Install

- **During version:** freerdp3-x11 3.15.0+dfsg-2.1+deb13u3 amd64
- **Install command:** `apt install ./freerdp3-x11_3.15.0+dfsg-2.1+deb13u3_amd64.deb`

## Smoke Test

- **Windowed:** yes
- **Fullscreen:** yes

## Rollback

- **After version:** freerdp3-x11 3.15.0+dfsg-2.1+deb13u3 amd64
- **Rollback method:** apt install --reinstall
- **Stock verification:** This is FreeRDP version 3.15.0 (n/a)

## Launch Command (sanitized)

```
xfreerdp3   /v:HOST-IP   /u:ngleh   /p:***   /f /smart-sizing:2560x1600 /scale-desktop:200   /clipboard   /sound:sys:pulse /microphone:sys:pulse   /drive:Onemix,"$HOME"   /cert:ignore
```

## Windows Target (sanitized)

```
Windows 11 Pro 22H2 on LAN
```
