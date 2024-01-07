#!/bin/sh

CONFIGURE_USB_SERIAL=true
CONFIGURE_USB_WEBCAM=true

cd /sys/kernel/config/usb_gadget/
mkdir xue
cd xue

echo 0x1d6b > idVendor # Linux Foundation
echo 0x0104 > idProduct # Multifunction Composite Gadget
echo 0x0100 > bcdDevice # v1.0.0
echo 0x0200 > bcdUSB # USB2

echo 0xEF   > bDeviceClass
echo 0x02   > bDeviceSubClass
echo 0x01   > bDeviceProtocol

mkdir -p strings/0x409
echo "Good10-12345678" > strings/0x409/serialnumber
echo "Good10" > strings/0x409/manufacturer
echo "Xue USB Device" > strings/0x409/product

mkdir configs/c.1
mkdir configs/c.1/strings/0x409
echo "UVC Configuration" > configs/c.1/strings/0x409/configuration
echo 500 > configs/c.1/MaxPower

#SERIAL=$(cat /sys/firmware/devicetree/base/serial-number)77

config_usb_serial () {
  mkdir -p functions/acm.usb0
  ln -s functions/acm.usb0 configs/c.1/acm.usb0
}


create_uvc_function () {
	# Example usage:
	# create_function <width> <height> <format> <name>

	WIDTH=$1
	HEIGHT=$2
	FORMAT=$3
	NAME=$4

	wdir=functions/uvc.usb0/streaming/$FORMAT/$NAME/${HEIGHT}p

	mkdir -p $wdir
	echo $WIDTH  > $wdir/wWidth
	echo $HEIGHT > $wdir/wHeight
	echo 29491200 > $wdir/dwMinBitRate
	echo 29491200 > $wdir/dwMaxBitRate
	echo $(( $WIDTH * $HEIGHT * 2 )) > $wdir/dwMaxVideoFrameBufferSize
	# dwFrameInterfal is in 100-ns units (fps = 1/(dwFrameInterval * 10000000))
	# 333333 -> 30 fps
	# 666666 -> 15 fps
	# 5000000 -> 2 fps
	cat <<EOF > $wdir/dwFrameInterval
333333
666666
5000000
EOF
}

config_usb_webcam () {
# Add functions here
mkdir functions/uvc.usb0
create_uvc_function 640 360 uncompressed u

mkdir -p functions/uvc.usb0/streaming/header/h
cd functions/uvc.usb0/streaming/header/h
ln -s ../../uncompressed/u
# ln -s ../../mjpeg/m
cd ../../class/fs
ln -s ../../header/h
cd ../../class/hs
ln -s ../../header/h
cd ../../class/ss
ln -s ../../header/h
cd ../../../../../

mkdir -p functions/uvc.usb0/control/header/h
cd functions/uvc.usb0/control
ln -s header/h class/fs
ln -s header/h class/ss
cd ../../../

# Set the packet size: uvc gadget max size is 3k...
# echo 3072 > functions/uvc.usb0/streaming_maxpacket
echo 2048 > functions/uvc.usb0/streaming_maxpacket
# echo 1024 > functions/uvc.usb0/streaming_maxpacket

ln -s functions/uvc.usb0 configs/c.1/uvc.usb0

# End functions
}


if [ "$CONFIGURE_USB_WEBCAM" = true ] ; then
  echo "Configuring USB gadget webcam interface"
  config_usb_webcam
fi

if [ "$CONFIGURE_USB_SERIAL" = true ] ; then
  echo "Configuring USB gadget serial interface"
  config_usb_serial
fi

ls /sys/class/udc > UDC
udevadm settle -t 5 || :
