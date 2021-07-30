
DOCKER_IMAGES_DIR=$(shell readlink -m $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
DOCKER_IMAGES = \
	qubesos-ci \
	repro-bullseye \
	repro-buster \
	repro-dom0 \
	repro-fedora-33 \
	repro-fedora-34

.ONESHELL:
build: $(DOCKER_IMAGES:%=build-%)

push: $(DOCKER_IMAGES:%=push-%)

build-%: DOCKER_IMAGE=$(subst build-,,$@)
build-%:
	cd $(DOCKER_IMAGES_DIR)/$(DOCKER_IMAGE)
	sudo docker build --no-cache -t fepitre/$(DOCKER_IMAGE):latest .

push-%: DOCKER_IMAGE=$(subst push-,,$@)
push-%:
	sudo docker push fepitre/$(DOCKER_IMAGE):latest
