#!/usr/bin/env bash
# Instala photon-wifi-drive en una Orange Pi con H616/H618 (Zero 2W). Desde la
# carpeta del repo:
#   sudo ./instalar.sh
# Se puede volver a correr: no rehace la memoria ni pisa la configuración.
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
OVERLAY=photon-usb0-periferico

falla() { echo "instalar.sh: $*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || falla "va con sudo: sudo ./instalar.sh"

# Por ahora, solo Orange Pi con H616/H618.
compatible=$(tr '\0' ' ' < /proc/device-tree/compatible)
case "$compatible" in
	*sun50i-h616*|*sun50i-h618*) ;;
	*) falla "esta tarjeta no es una Orange Pi con H616/H618 ($compatible)" ;;
esac

# Lo que hace falta del sistema.
faltan=()
command -v dtc >/dev/null || faltan+=(device-tree-compiler)
command -v mkfs.vfat >/dev/null || faltan+=(dosfstools)
command -v sfdisk >/dev/null || faltan+=(fdisk)
if [ ${#faltan[@]} -gt 0 ]; then
	echo "instalando ${faltan[*]}…"
	apt-get update -qq
	apt-get install -y -qq "${faltan[@]}" >/dev/null
fi

# El kernel tiene que saber poner el USB0 como periférico y armar memorias por
# configfs. Si el sistema no trae su configuración, no se puede revisar antes.
config="/boot/config-$(uname -r)"
if [ -r "$config" ]; then
	grep -Eq '^CONFIG_USB_MUSB_SUNXI=[ym]' "$config" \
		|| falla "el kernel $(uname -r) no trae el controlador del USB0 (CONFIG_USB_MUSB_SUNXI)"
	grep -Eq '^CONFIG_USB_MUSB_(DUAL_ROLE|GADGET)=y' "$config" \
		|| falla "el kernel $(uname -r) no deja el USB0 como periférico (CONFIG_USB_MUSB_DUAL_ROLE)"
	grep -Eq '^CONFIG_USB_CONFIGFS_MASS_STORAGE=y' "$config" \
		|| falla "el kernel $(uname -r) no arma memorias USB por configfs (CONFIG_USB_CONFIGFS_MASS_STORAGE)"
fi

# El USB0 como periférico: un overlay del device tree que el arranque aplica
# después de los del sistema (user_overlays).
env=""
for f in /boot/orangepiEnv.txt /boot/armbianEnv.txt /boot/dietpiEnv.txt; do
	if [ -f "$f" ]; then env=$f; break; fi
done
[ -n "$env" ] || falla "no encontré /boot/orangepiEnv.txt (ni el de Armbian o DietPi): no sé cómo cargar el overlay en este sistema"
[ -e /proc/device-tree/__symbols__/usbotg ] \
	|| falla "el device tree de este sistema no trae la etiqueta usbotg: el overlay no se podría aplicar"
mkdir -p /boot/overlay-user
dtc -@ -q -I dts -O dtb -o "/boot/overlay-user/$OVERLAY.dtbo" "$AQUI/dts/$OVERLAY.dts"
if ! grep -Eq "^user_overlays=(.* )?$OVERLAY( |\$)" "$env"; then
	if grep -q '^user_overlays=' "$env"; then
		sed -i -E "s/^user_overlays=(.*)\$/user_overlays=\\1 $OVERLAY/; s/^user_overlays= +/user_overlays=/" "$env"
	else
		echo "user_overlays=$OVERLAY" >> "$env"
	fi
fi

install -m 755 "$AQUI/photon-wifi-drive" /usr/local/sbin/photon-wifi-drive
[ -f /etc/photon-wifi-drive.conf ] || install -m 644 "$AQUI/photon-wifi-drive.conf" /etc/photon-wifi-drive.conf
install -m 644 "$AQUI/photon-wifi-drive.service" /etc/systemd/system/photon-wifi-drive.service
# shellcheck source=photon-wifi-drive.conf
. /etc/photon-wifi-drive.conf

# La memoria, como una de fábrica: tabla de particiones MBR y una sola
# partición FAT32 desde el primer MiB.
if [ ! -f "$IMAGEN" ]; then
	echo "creando la memoria de $TAMANO en $IMAGEN…"
	mkdir -p "$(dirname "$IMAGEN")"
	nueva="$IMAGEN.nueva"
	rm -f "$nueva"
	fallocate -l "$TAMANO" "$nueva"
	inicio=2048
	sectores=$(( $(stat -c %s "$nueva") / 512 - inicio ))
	echo "start=$inicio, size=$sectores, type=c" | sfdisk -q -X dos "$nueva"
	mkfs.vfat -F 32 -n "$ETIQUETA" -h "$inicio" --offset "$inicio" "$nueva" $(( sectores / 2 )) >/dev/null
	mv "$nueva" "$IMAGEN"
fi

systemctl daemon-reload
systemctl enable --quiet photon-wifi-drive.service
if compgen -G '/sys/class/udc/*' >/dev/null; then
	systemctl restart photon-wifi-drive.service
	echo "listo: la memoria ya está conectada al USB0"
else
	echo "listo: falta reiniciar la tarjeta (sudo reboot) para que el USB0 quede como periférico"
fi
