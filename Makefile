all: deps build

deps:
	sudo pacman -S git archiso

dev:
	git submodule update --init

build:
	sudo mkarchiso -v -w /tmp/vxiso-tmp -o out .

clean:
	sudo rm -rf /tmp/vxiso-tmp
	sudo rm -rf out/*

clean-all: clean
	sudo rm -rf bats-core
	

