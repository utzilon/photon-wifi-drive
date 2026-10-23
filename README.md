# photon-wifi-drive

Una Orange Pi Zero 2W conectada al USB de la impresora se hace pasar por una
memoria USB, y los archivos le llegan por la red. Primer objetivo: la Anycubic
Photon M3 Max.

## Cómo funciona

- El USB0 de la tarjeta (el USB-C por el que se alimenta) pasa de host a
  periférico con un overlay del device tree.
- Un gadget USB de almacenamiento masivo (configfs + libcomposite) le presenta
  a la impresora una imagen FAT32 como si fuera una memoria.

En camino: compartir una carpeta por la red (Samba) y, cuando llegue un archivo
nuevo, simular que se saca y se mete la memoria para que la impresora lo vea.

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

   instalar.sh pone el USB0 como periférico, crea la memoria (4 GB, FAT32,
   etiqueta `PHOTON`) en `/var/lib/photon-wifi-drive/disco.img` y deja un
   servicio que la conecta al arrancar. Para otro tamaño o etiqueta, se edita
   `photon-wifi-drive.conf` antes de correrlo.

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

## Poner un archivo a mano

Mientras llega la carpeta por la red, un archivo se mete así (por ejemplo, uno
que se pasó antes a la tarjeta con `scp`):

    sudo photon-wifi-drive desconectar
    sudo mount -o loop,offset=1048576 /var/lib/photon-wifi-drive/disco.img /mnt
    sudo cp prueba.pwmb /mnt/
    sudo umount /mnt
    sudo photon-wifi-drive conectar

La impresora lo ve cuando la memoria se vuelve a conectar.

## Comandos

| Comando | Qué hace |
|---|---|
| `sudo photon-wifi-drive conectar` | La impresora ve la memoria (como meterla). |
| `sudo photon-wifi-drive desconectar` | La impresora deja de verla (como sacarla). |
| `photon-wifi-drive estado` | Cómo está el USB0 y qué ve la impresora. |

## Licencia

MIT.
