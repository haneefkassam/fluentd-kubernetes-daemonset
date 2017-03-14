# This Makefile automates possible operations of this project.
#
# Images and description on Docker Hub will be automatically rebuilt on
# pushes to `master` branch of this repo and on updates of parent images.
#
# Note! Docker Hub `post_push` hook must be always up-to-date with values
# specified in current Makefile. To update it just use:
#	make post-push-hook-all
#
# It's still possible to build, tag and push images manually. Just use:
#	make release-all

IMAGE_NAME := fluent/fluentd-kubernetes
ALL_IMAGES := \
	v0.12/elasticsearch:v0.12.33-elasticsearch,v0.12-elasticsearch,stable-elasticsearch,elasticsearch \
	v0.12/loggly:v0.12.33-loggly,v0.12-loggly,stable-loggly,loggly \
	v0.12/logentries:v0.12.33-logentries,v0.12-logentries,stable-logentries,logentries
#	<Dockerfile>:<version>,<tag1>,<tag2>,...

# Default is first image from ALL_IMAGES list.
DOCKERFILE ?= $(word 1,$(subst :, ,$(word 1,$(ALL_IMAGES))))
VERSION ?=  $(word 1,$(subst $(comma), ,\
                     $(word 2,$(subst :, ,$(word 1,$(ALL_IMAGES))))))
TAGS ?= $(word 2,$(subst :, ,$(word 1,$(ALL_IMAGES))))

no-cache ?= no

comma := ,
empty :=
space := $(empty) $(empty)
eq = $(if $(or $(1),$(2)),$(and $(findstring $(1),$(2)),\
                                $(findstring $(2),$(1))),1)

## Docker image management

# Build Docker image.
#
# Usage:
#	make image [no-cache=(yes|no)] [DOCKERFILE=] [VERSION=]

no-cache-arg = $(if $(call eq, $(no-cache), yes), --no-cache, $(empty))

image:
	docker build $(no-cache-arg) -t $(IMAGE_NAME):$(VERSION) docker-image/$(DOCKERFILE)

# Tag Docker image with given tags.
#
# Usage:
#	make tags [VERSION=] [TAGS=t1,t2,...]

parsed-tags = $(subst $(comma), $(space), $(TAGS))

tags:
	(set -e ; $(foreach tag, $(parsed-tags), \
		docker tag $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):$(tag) ; \
	))

# Manually push Docker images to Docker Hub.
#
# Usage:
#	make push [TAGS=t1,t2,...]

push:
	(set -e ; $(foreach tag, $(parsed-tags), \
		docker push $(IMAGE_NAME):$(tag) ; \
	))

# Make manual release of Docker images to Docker Hub.
#
# Usage:
#	make release [no-cache=(yes|no)] [DOCKERFILE=] [VERSION=] [TAGS=t1,t2,...]

release: | image tags push

# Make manual release of all supported Docker images to Docker Hub.
#
# Usage:
#	make release-all [no-cache=(yes|no)]

release-all:
	(set -e ; $(foreach img,$(ALL_IMAGES), \
		make release no-cache=$(no-cache) \
			DOCKERFILE=$(word 1,$(subst :, ,$(img))) \
			VERSION=$(word 1,$(subst $(comma), ,\
			                 $(word 2,$(subst :, ,$(img))))) \
			TAGS=$(word 2,$(subst :, ,$(img))) ; \
	))


## Template processing

# Generate Docker image sources.
#
# Usage:
#	make src [DOCKERFILE=] [VERSION=] [TAGS=t1,t2,...]

src: dockerfile fluent.conf kubernetes.conf plugins post-push-hook

# Generate sources for all supported Docker images.
#
# Usage:
#	make src-all

src-all:
	(set -e ; $(foreach img,$(ALL_IMAGES), \
		make src \
			DOCKERFILE=$(word 1,$(subst :, ,$(img))) \
			VERSION=$(word 1,$(subst $(comma), ,\
			                 $(word 2,$(subst :, ,$(img))))) \
			TAGS=$(word 2,$(subst :, ,$(img))) ; \
	))


# Generate Dockerfile from template.
#
# Usage:
#	make dockerfile [DOCKERFILE=] [VERSION=]

dockerfile:
	mkdir -p docker-image/$(DOCKERFILE)
	cp $(PWD)/templates/.dockerignore docker-image/$(DOCKERFILE)/.dockerignore
	docker run --rm -i -v $(PWD)/templates/Dockerfile.erb:/Dockerfile.erb:ro \
		ruby:alpine erb -U -T 1 \
			dockerfile='$(DOCKERFILE)' \
			version='$(VERSION)' \
		/Dockerfile.erb > docker-image/$(DOCKERFILE)/Dockerfile


# Generate fluent.conf from template.
#
# Usage:
#	make fluent.conf [DOCKERFILE=] [VERSION=]

fluent.conf:
	mkdir -p docker-image/$(DOCKERFILE)/conf
	docker run --rm -i -v $(PWD)/templates/conf/fluent.conf.erb:/fluent.conf.erb:ro \
		ruby:alpine erb -U -T 1 \
			dockerfile='$(DOCKERFILE)' \
			version='$(VERSION)' \
		/fluent.conf.erb > docker-image/$(DOCKERFILE)/conf/fluent.conf

# Generate kubernetes.conf from template.
#
# Usage:
#	make kubernetes.conf [DOCKERFILE=] [VERSION=]

kubernetes.conf:
	mkdir -p docker-image/$(DOCKERFILE)/conf
	docker run --rm -i -v $(PWD)/templates/conf/kubernetes.conf.erb:/kubernetes.conf.erb:ro \
		ruby:alpine erb -U -T 1 \
			dockerfile='$(DOCKERFILE)' \
			version='$(VERSION)' \
		/kubernetes.conf.erb > docker-image/$(DOCKERFILE)/conf/kubernetes.conf


# Generate plugins for version
#
# Usage:
#    make plugins [DOCKERFILE=]

plugins:
	mkdir -p docker-image/$(DOCKERFILE)/plugins
	cp -R plugins/$(word 1,$(subst /, ,$(DOCKERFILE)))/shared/ docker-image/$(DOCKERFILE)/plugins/
	cp -R plugins/$(DOCKERFILE)/ docker-image/$(DOCKERFILE)/plugins/

# Create `post_push` Docker Hub hook.
#
# When Docker Hub triggers automated build all the tags defined in `post_push`
# hook will be assigned to built image. It allows to link the same image with
# different tags, and not to build identical image for each tag separately.
# See details:
# http://windsock.io/automated-docker-image-builds-with-multiple-tags
#
# Usage:
#	make post-push-hook [DOCKERFILE=] [TAGS=t1,t2,...]

post-push-hook:
	mkdir -p docker-image/$(DOCKERFILE)/hooks
	docker run --rm -i -v $(PWD)/templates/post_push.erb:/post_push.erb:ro \
		ruby:alpine erb -U \
			image_tags='$(TAGS)' \
		/post_push.erb > docker-image/$(DOCKERFILE)/hooks/post_push


# Generate Dockerfile from template for all supported Docker images.
#
# Usage:
#	make dockerfile-all

dockerfile-all:
	(set -e ; $(foreach img,$(ALL_IMAGES), \
		make dockerfile \
			DOCKERFILE=$(word 1,$(subst :, ,$(img))) \
			VERSION=$(word 1,$(subst $(comma), ,\
			                 $(word 2,$(subst :, ,$(img))))) ; \
	))

# Generate fluent.conf from template for all supported Docker images.
#
# Usage:
#	make fluent.conf-all

fluent.conf-all:
	(set -e ; $(foreach img,$(ALL_IMAGES), \
		make fluent.conf \
			DOCKERFILE=$(word 1,$(subst :, ,$(img))) \
			VERSION=$(word 1,$(subst $(comma), ,\
			                 $(word 2,$(subst :, ,$(img))))) ; \
	))

# Generate kubernetes.conf from template for all supported Docker images.
#
# Usage:
#	make kubernetes.conf-all

kubernetes.conf-all:
	(set -e ; $(foreach img,$(ALL_IMAGES), \
		make kubernetes.conf \
			DOCKERFILE=$(word 1,$(subst :, ,$(img))) \
			VERSION=$(word 1,$(subst $(comma), ,\
			                 $(word 2,$(subst :, ,$(img))))) ; \
	))

# copy plugins required for all supported Docker images.
#
# Usage:
#	make plugins-all

plugins-all:
	(set -e ; $(foreach img,$(ALL_IMAGES), \
		make plugins \
			DOCKERFILE=$(word 1,$(subst :, ,$(img))) ; \
	))

# Create `post_push` Docker Hub hook for all supported Docker images.
#
# Usage:
#	make post-push-hook-all

post-push-hook-all:
	(set -e ; $(foreach img,$(ALL_IMAGES), \
		make post-push-hook \
			DOCKERFILE=$(word 1,$(subst :, ,$(img))) \
			TAGS=$(word 2,$(subst :, ,$(img))) ; \
	))


.PHONY: image tags push \
        release release-all \
        src src-all \
        dockerfile dockerfile-all \
        fluent.conf fluent.conf-all \
        kubernetes.conf kubernetes.conf-all\
        plugins plugins-all \
        post-push-hook post-push-hook-all
