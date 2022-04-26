all: deps build

deps:
	sudo pacman -S git archiso

build:
	sudo mkarchiso -v -w /tmp/vxiso-tmp -o out .

clean:
	sudo rm -rf /tmp/vxiso-tmp
	sudo rm -rf out/*

