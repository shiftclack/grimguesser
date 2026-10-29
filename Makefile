GRIM_INSTALL_DIR ?= C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns\GrimGuesser
GRIM_INSTALL_DIR_MACOS ?= /Applications/World of Warcraft/_classic_era_/Interface/AddOns
GRIM_SOURCES := src/*.lua tests/*.lua tests/fixtures/*.lua .busted .luacov
DOCKER_SRC_DIR ?= /lua
DOCKER_TEST_IMAGE ?= ghcr.io/shiftclack/lua-wow:1.3.0
LUA ?= lua
BUSTED ?= busted
TEST_ARGS ?=
LUA_LANGUAGE_SERVER ?= lua-language-server
LUAC ?= luac
LUACHECK ?= luacheck

.NOTPARALLEL:

.PHONY: \
	all \
	build \
	build-ci \
	check \
	check-ci \
	check-docker \
	clean \
	clean-ci \
	coverage \
	coverage-report \
	coverage-summary \
	deps \
	deps-ci \
	dist \
	dist-ci \
	dist-docker \
	install \
	install-macos \
	lint \
	luals \
	luals-ci \
	minify-ci \
	syntax \
	test \
	test-dist-ci \
	version-ci

all: check build

check: syntax lint luals test

check-ci: syntax lint luals-ci test

check-docker:
	docker run -v $(CURDIR):$(DOCKER_SRC_DIR) $(DOCKER_TEST_IMAGE) make check-ci

syntax:
	$(LUAC) -p $(GRIM_SOURCES)

lint:
	$(LUACHECK) $(GRIM_SOURCES)

luals:
	$(LUA_LANGUAGE_SERVER) --check .

luals-ci:
	[ -d "${DOCKER_SRC_DIR}" ] && $(LUA_LANGUAGE_SERVER) --check $(DOCKER_SRC_DIR) || $(LUA_LANGUAGE_SERVER) --check .

test:
	"$(BUSTED)" --lua="$(LUA)" $(TEST_ARGS)

test-dist-ci:
	GRIMGUESSER_TEST_SOURCE_DIR=dist/GrimGuesser "$(BUSTED)" --lua="$(LUA)" $(TEST_ARGS)

coverage:
	$(LUA) -e "os.remove('luacov.stats.out'); os.remove('luacov.report.out')"
	"$(BUSTED)" --lua="$(LUA)" --coverage $(TEST_ARGS)

coverage-report: coverage
	$(LUA) -e "require('luacov.reporter').report()"

coverage-summary: coverage-report
	$(LUA) -e "local summary = false; for line in io.lines([[luacov.report.out]]) do if line == [[Summary]] then summary = true end; if summary then print(line) end end"

# note: use dist-ci to build a real package
dist: test clean build
	cd /D dist && zip -r GrimGuesser.zip GrimGuesser

dist-ci: clean-ci build-ci minify-ci version-ci test-dist-ci
	cd dist && zip -r GrimGuesser.zip GrimGuesser

dist-docker:
	docker run -v "$(CURDIR):$(DOCKER_SRC_DIR)" \
		-e "SRC_DIR=$(DOCKER_SRC_DIR)" \
		-e "TAG=${TAG}" \
		"$(DOCKER_TEST_IMAGE)" make dist-ci

version-ci:
	bash ./scripts/version.sh "$(TAG)" "dist/GrimGuesser/GrimGuesser_Vanilla.toc" "dist/GrimGuesser/GrimConstants.lua"

build:
	powershell -NoProfile -Command "New-Item -ItemType Directory -Force -Path dist,dist\GrimGuesser,dist\GrimGuesser\libs | Out-Null"
	powershell -NoProfile -Command "Copy-Item -Recurse README.md,LICENSE.md,src\*.lua,src\*.toc,libs dist\GrimGuesser\ -Force"

build-ci:
	mkdir -p dist/GrimGuesser
	cp LICENSE.md README.md src/*.lua src/*.toc dist/GrimGuesser/
	mkdir -p dist/GrimGuesser/libs
	cp -r libs/LibStub libs/CallbackHandler-1.0 libs/LibDataBroker-1.1 libs/LibDBIcon-1.0 dist/GrimGuesser/libs/

minify-ci:
	bash scripts/minify.sh

clean:
	powershell -NoProfile -Command "if (Test-Path dist) { Remove-Item -Recurse -Force dist }"
	powershell -NoProfile -Command "if (Test-Path GrimGuesser.zip) { Remove-Item -Force GrimGuesser.zip }"

clean-ci:
	rm -rf dist GrimGuesser.zip

# using scoop on windows https://scoop.sh/
deps:
	scoop install lua-for-windows make luacheck zip unzip lua-language-server
	luarocks install luacov
	luarocks install luasrcdiet

deps-ci:
	apt update
	apt install -y lua5.1 lua-check luarocks
	luarocks install luacov
	luarocks install luasrcdiet

install: build
	powershell -NoProfile -Command "if ('$(GRIM_INSTALL_DIR)' -notmatch '[\\/]Interface[\\/]AddOns[\\/]GrimGuesser$$') { throw 'GRIM_INSTALL_DIR must end with Interface\\AddOns\\GrimGuesser' }"
	powershell -NoProfile -Command "Copy-Item -Path dist\GrimGuesser\* -Destination '$(GRIM_INSTALL_DIR)' -Recurse -Force"

install-macos: build-ci
	cp -r "dist/GrimGuesser" "$(GRIM_INSTALL_DIR_MACOS)"
