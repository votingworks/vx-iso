

all: deps build

deps:
	sudo pacman -S git archiso

dev:
	git submodule update --init
	sudo ./test/bats/install.sh /usr/local

	# use our hooks
	git config core.hooksPath .hooks/

	sudo pacman -S kcov
	
build:
	sudo mkarchiso -v -w /tmp/vxiso-tmp -o out .

clean:
	sudo rm -rf /tmp/vxiso-tmp
	sudo rm -rf out/*

clean-all: clean
	sudo rm -rf bats-core
	
lint:
	shellcheck -x -P airootfs/usr/share/vx-img/ airootfs/usr/share/vx-img/*
	shellcheck -x -P airootfs/usr/share/vx-img/ test/test-* 

test:
	bats test/

test-coverage:
	kcov --include-path=airootfs/usr/share/vx-img ${KCOV_OUTDIR} bats test/test-util.bats
