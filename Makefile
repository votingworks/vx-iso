all: deps build

deps:
	sudo pacman -S git archiso

dev:
	git clone https://github.com/bats-core/bats-core.git
	sudo ./bats-core/install.sh /usr/local

build:
	sudo mkarchiso -v -w /tmp/vxiso-tmp -o out .

clean:
	sudo rm -rf /tmp/vxiso-tmp
	sudo rm -rf out/*

clean-all: clean
	sudo rm -rf bats-core
	

