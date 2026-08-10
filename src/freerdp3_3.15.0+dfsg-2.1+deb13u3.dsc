-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA512

Format: 3.0 (quilt)
Source: freerdp3
Binary: freerdp3-x11, libfreerdp3-3, libfreerdp-client3-3, libfreerdp-server3-3, libwinpr3-3, libwinpr-tools3-3, libwinpr3-dev, freerdp3-dev, winpr3-utils, libfreerdp-shadow3-3, libfreerdp-shadow-subsystem3-3, freerdp3-shadow-x11, freerdp3-wayland, freerdp3-sdl, libfreerdp-server-proxy3-3, freerdp3-proxy-modules, freerdp3-proxy
Architecture: any
Version: 3.15.0+dfsg-2.1+deb13u3
Maintainer: Debian Remote Maintainers <debian-remote@lists.debian.org>
Uploaders:  Mike Gabriel <sunweaver@debian.org>, Bernhard Miklautz <bernhard.miklautz@shacknet.at>, Michael Tokarev <mjt@tls.msk.ru>,
Homepage: https://www.freerdp.com/
Standards-Version: 4.7.2
Vcs-Browser: https://salsa.debian.org/debian-remote-team/freerdp3
Vcs-Git: https://salsa.debian.org/debian-remote-team/freerdp3.git
Testsuite: autopkgtest
Testsuite-Triggers: xauth, xrdp, xvfb
Build-Depends: debhelper-compat (= 13), cmake, dpkg-dev (>= 1.22.5), libasound2-dev, libavcodec-dev, libavutil-dev, libswscale-dev, libcairo2-dev, libjson-c-dev, libcups2-dev, libfuse3-dev, libgsm1-dev, libicu-dev, libjpeg-dev, libkrb5-dev, libopus-dev, libpam0g-dev, libpcsclite-dev, libpkcs11-helper1-dev, libpng-dev, libpulse-dev, libsdl2-dev <pkg.freerdp3.sdl2>, libsdl2-image-dev <pkg.freerdp3.sdl2>, libsdl2-ttf-dev <pkg.freerdp3.sdl2>, libsdl3-dev <!pkg.freerdp3.sdl2>, libsdl3-image-dev <!pkg.freerdp3.sdl2>, libsdl3-ttf-dev <!pkg.freerdp3.sdl2>, libssl-dev, libv4l-dev [linux-any], libswresample-dev, libsystemd-dev [linux-any], libudev-dev [linux-any], libusb-1.0-0-dev [linux-any], liburiparser-dev, libwayland-dev [linux-any], libwebp-dev, libx11-dev, libxcursor-dev, libxdamage-dev, libxext-dev, libxfixes-dev, libxinerama-dev, libxi-dev, libxkbcommon-dev, libxkbfile-dev, libxrandr-dev, libxrender-dev, libxtst-dev, libxv-dev, pkgconf, uuid-dev, xmlto, xsltproc
Package-List:
 freerdp3-dev deb devel optional arch=any
 freerdp3-proxy deb x11 optional arch=any
 freerdp3-proxy-modules deb x11 optional arch=any
 freerdp3-sdl deb x11 optional arch=any
 freerdp3-shadow-x11 deb x11 optional arch=any
 freerdp3-wayland deb x11 optional arch=linux-any
 freerdp3-x11 deb x11 optional arch=any
 libfreerdp-client3-3 deb libs optional arch=any
 libfreerdp-server-proxy3-3 deb libs optional arch=any
 libfreerdp-server3-3 deb libs optional arch=any
 libfreerdp-shadow-subsystem3-3 deb libs optional arch=any
 libfreerdp-shadow3-3 deb libs optional arch=any
 libfreerdp3-3 deb libs optional arch=any
 libwinpr-tools3-3 deb libs optional arch=any
 libwinpr3-3 deb libs optional arch=any
 libwinpr3-dev deb libdevel optional arch=any
 winpr3-utils deb utils optional arch=any
Checksums-Sha1:
 b1152ed947a310fed84fe996fad202ba43765fff 4438956 freerdp3_3.15.0+dfsg.orig.tar.xz
 54b3631c05ce83b1ffae1b086091f90b8bb7c6fe 136168 freerdp3_3.15.0+dfsg-2.1+deb13u3.debian.tar.xz
Checksums-Sha256:
 221f093417b78e62f565a30dec4001a07645e1e193721a8ed177b69329df6d62 4438956 freerdp3_3.15.0+dfsg.orig.tar.xz
 3fff1c95c64c015989283353e676cc30110ef1ef903fc2d740a4c713ad51bc68 136168 freerdp3_3.15.0+dfsg-2.1+deb13u3.debian.tar.xz
Files:
 5065812d413da8e49908e1ce11c0c201 4438956 freerdp3_3.15.0+dfsg.orig.tar.xz
 7511f92e36b5dea5fcbedb0cce0a8c96 136168 freerdp3_3.15.0+dfsg-2.1+deb13u3.debian.tar.xz

-----BEGIN PGP SIGNATURE-----

iQIzBAEBCgAdFiEEZKoqtTHVaQM2a/75gqpKJDselHgFAmn6+xcACgkQgqpKJDse
lHhOfw/+MgK599DIkhehuwFCI4+sULP+Fevb44nPDO3m+HPrP+kQ6wR7cIYBwSIw
mGsew3DIpfJV/JCH+U1veR8NWd7j7rckN8ksd6W9NGywn4xk2CfEjx938Z/Rk3C/
X6zKYg2axy5r7MD3FCdlYU/kaLA6mm6H8lLjPa2xbghVO47KpIVwIAKfyTHtZHqh
YYATrB4+IHMfMmvfyCQEzYUeMIbwjVlHFwuC3NZSwonw/ZNoejZHpQjW5FLuSxzn
wtIjG3M1tuBstbtflMoCapJqcZQNodIsG7gb1/tdoDHQ3sqyXuKfBs4LJhS51e16
mHNKDo29D8Z1Guz5S/7tl8wdI/KiCv/HYAKf6eiYdrhrDDc5eVDkdMsFgHOdPkq+
KwbriPFwy74u0aNw79IFbsCRtY9QR+3bdo6rV5RR5IfJgDYIMclqCLOr/NuuPd+M
fRRefZTjlttu+Sq16uVRLZkobofRvFdtLWI+nlPFyWlFeWJfxYWxmsYeMqdcrPz2
hfSQ8ZT3kNXLxnSv0xcq5CFPhHaf/1+pu0FQabRI1KQAFDUiop4ypA7wiJgPRAlr
D29A35BcqzOA85cjH+R0Qj8SU9BF2/ROOaFY22vDWSpP3Ba/Za1phv7cWiTP9DP9
MsVO8pUuicwomjG73ZJHjhh6AGxGTNqUnbl6XgPCrTh9cE5MsOc=
=VIBD
-----END PGP SIGNATURE-----
