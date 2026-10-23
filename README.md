# photon-wifi-drive

Una Orange Pi Zero 2W conectada al USB de la impresora se hace pasar por una
memoria USB, y los archivos le llegan por la red. Primer objetivo: la Anycubic
Photon M3 Max.

## Cómo funciona

- El USB0 de la tarjeta (el USB-C por el que se alimenta) pasa de host a
  periférico con un overlay del device tree.
- Un gadget USB de almacenamiento masivo (configfs + libcomposite) le presenta
  a la impresora una imagen FAT32 como si fuera una memoria.
- La tarjeta comparte una carpeta por la red (Samba). Cuando llega un archivo
  y la copia termina, la tarjeta saca la memoria, la pone igual que la carpeta
  y la vuelve a meter, para que la impresora vea lo nuevo. Lo mismo al borrar.

La carpeta es la que manda: lo que no esté en ella desaparece de la memoria.

## Lo que se necesita

- Orange Pi Zero 2W (Allwinner H618) con el sistema de Orange Pi (Debian o
  Ubuntu). instalar.sh también reconoce Armbian y DietPi.
- Un cable USB-A a USB-C.

## Instalación en la Orange Pi

1. Grabar el sistema en la microSD, arrancar la tarjeta con su cargador,
   conectarla a la red Wi-Fi y entrar por SSH. En el sistema de Orange Pi la
   red se pone así:

       sudo nmcli dev wifi connect "<red>" password "<clave>"

2. Bajar el repo e instalar:

       sudo apt-get install -y git
       git clone https://github.com/utzilon/photon-wifi-drive.git
       cd photon-wifi-drive
       sudo ./instalar.sh

   instalar.sh pide la clave de la carpeta de la red (usuario `photon`). Pone
   el USB0 como periférico, crea la memoria (4 GB, FAT32, etiqueta `PHOTON`),
   comparte la carpeta y deja un servicio que conecta la memoria al arrancar.
   Para otro tamaño o etiqueta, se edita `photon-wifi-drive.conf` antes de
   correrlo.

3. Reiniciar y revisar:

       sudo reboot
       photon-wifi-drive estado

   Debe decir `USB0: peripheral`.

## Conectarla a la impresora

1. Apagar la tarjeta (`sudo poweroff`) y quitarle el cargador.
2. Con el cable USB-A a USB-C, conectar el USB de la impresora al USB-C por el
   que se alimenta la tarjeta. La impresora la alimenta por ese mismo cable.
3. Encender la impresora. La tarjeta arranca sola y se conecta como memoria.

Por SSH, `photon-wifi-drive estado` dice `configured` cuando la impresora ya la
reconoció.

## Mandarle archivos

Desde la PC se abre la carpeta `\\<ip de la tarjeta>\photon` (la IP la da
`hostname -I` en la tarjeta), con el usuario `photon` y la clave de la
instalación. Se copia el archivo (por ejemplo, el `.pwmb` de Photon Workshop) y,
unos segundos después de que termina la copia, la impresora lo ve.

Lo que tenga la carpeta no debe pasar del tamaño de la memoria (4 GB). La clave
se cambia con `sudo smbpasswd photon`.

## Comandos

| Comando | Qué hace |
|---|---|
| `sudo photon-wifi-drive conectar` | La impresora ve la memoria (como meterla). |
| `sudo photon-wifi-drive desconectar` | La impresora deja de verla (como sacarla). |
| `photon-wifi-drive estado` | Cómo está el USB0 y qué ve la impresora. |

Lo que hace el servicio queda en `journalctl -u photon-wifi-drive`.

## Licencia

MIT.
