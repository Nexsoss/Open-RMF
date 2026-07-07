# =============================================================================
# Makefile
#
# Convenience targets for the RMF backend stack.
# `docker compose push` is intentionally NOT used here — it would also try to
# push the local-only tags (open-rmf:lyrical, open-rmf:lyrical_sim) which have
# no registry. We push only the quay.io tags directly with `docker push`,
# tagging rmf-base from the local build first.
# =============================================================================

QUAY := quay.io/nexsoss/open-rmf
LOCAL := open-rmf
TAG := lyrical

.PHONY: build-all build-base build-sim build-api-server build-web-dashboard push push-base push-sim push-api-server push-web-dashboard

# Build images in the order of dependency
build-all: build-base build-sim build-api-server build-web-dashboard

build-base:
	docker compose build rmf-base

build-sim:
	docker compose build rmf-sim

build-api-server:
	docker compose build rmf-api-server

build-web-dashboard:
	docker compose build rmf-web-dashboard

# Push every quay.io tag. Local tags are left alone.
push: push-base push-sim push-api-server push-web-dashboard

# rmf-base is built locally as `open-rmf:lyrical`. Tag it with the quay name
# before pushing.
push-base:
	docker tag $(LOCAL):$(TAG) $(QUAY):$(TAG)
	docker push $(QUAY):$(TAG)

push-sim:
	docker tag $(LOCAL):$(TAG)_sim $(QUAY):$(TAG)_sim
	docker push $(QUAY):$(TAG)_sim

push-api-server:
	docker tag $(LOCAL):$(TAG)_api-server $(QUAY):$(TAG)_api-server
	docker push $(QUAY):$(TAG)_api-server

push-web-dashboard:
	docker tag $(LOCAL):$(TAG)_web-dashboard $(QUAY):$(TAG)_web-dashboard
	docker push $(QUAY):$(TAG)_web-dashboard