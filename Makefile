MODULE		:= hotfix-kvadra-touchpad

obj-m 		:= $(MODULE).o
$(MODULE)-objs	:= module.o

PWD := $(shell pwd)

all:
	echo $(PWD)
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean

install: install_module
	install -Dm644 hotfix-kvadra-touchpad.conf /usr/lib/modules-load.d/hotfix-kvadra-touchpad.conf

install_module:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules_install
